local Gamestate   = require "lib.hump.gamestate"
local baton       = require "lib.baton"
local Camera      = require "lib.hump.camera"
local Concord     = require "lib.concord.concord"
local Config      = require "src.config"
local Background  = require "src.rendering.background"
local HUD         = require "src.ui.hud.hud"
local Chat        = require "src.ui.hud.chat"
local SaveManager = require "src.managers.save_manager"
local Window      = require "src.ui.hud.window"
local CargoPanel  = require "src.ui.hud.cargo_panel"
local Client      = require "src.network.client"
local Protocol    = require "src.network.protocol"
local PlayNetwork = require "src.states.play_network"

require "src.ecs.components"

-- System Imports
local PlayerControlSystem   = require "src.ecs.systems.gameplay.player_control"
local MovementSystem        = require "src.ecs.systems.core.movement"
local DeathSystem           = require "src.ecs.systems.gameplay.death"
local LootSystem            = require "src.ecs.systems.gameplay.loot"
local ShipDeathSystem       = require "src.ecs.systems.gameplay.ship_death"
local CollisionSystem       = require "src.ecs.systems.core.collision"
local MinimapSystem         = require "src.ecs.systems.visual.minimap"
local PhysicsSystem         = require "src.ecs.systems.core.physics"
local RenderSystem          = require "src.ecs.systems.core.render"
local ShipSystem            = require "src.ecs.spawners.ship"
local Asteroids             = require "src.ecs.spawners.asteroid"
local EnemySpawner          = require "src.ecs.spawners.enemy"
local WeaponSystem          = require "src.ecs.systems.gameplay.weapon"
local ProjectileSystem      = require "src.ecs.systems.gameplay.projectile"
local AsteroidChunkSystem   = require "src.ecs.systems.gameplay.asteroid_chunk"
local ProjectileShardSystem = require "src.ecs.systems.visual.projectile_shard"
local ItemPickupSystem      = require "src.ecs.systems.gameplay.item_pickup"
local TrailSystem           = require "src.ecs.systems.visual.trail"
local AISystem              = require "src.ecs.systems.gameplay.ai_system"
local DefaultSector         = require "src.data.default_sector"

--
-- LOCAL HELPER FUNCTIONS
--

local function createLocalPlayer(world)
    local player = Concord.entity(world)
    player:give("wallet", 1000)
    player:give("skills")
    player:give("level")
    player:give("input")
    player:give("pilot")
    return player
end

local function linkPlayerToShip(player, ship)
    if not (player and ship and ship.input) then return end
    player:give("controlling", ship)
    player.input = ship.input
end

local function loadSnapshot(loadParams)
    local snapshot
    if loadParams and loadParams.mode == "load" then
        local slot = loadParams.slot or 1
        local loaded, err = SaveManager.load(slot)
        if loaded then
            snapshot = loaded
        elseif err then
            print("PlayState: failed to load save slot " .. tostring(slot) .. ": " .. tostring(err))
        end
    end
    return snapshot
end

local function getSpawnParamsFromSnapshot(snapshot, default_ship_name)
    local spawn_x, spawn_y = 0, 0
    local ship_name = default_ship_name or "starter_drone"
    local sector_x, sector_y

    if snapshot and snapshot.player and snapshot.player.ship then
        local s = snapshot.player.ship
        if s.transform then
            spawn_x = s.transform.x or spawn_x
            spawn_y = s.transform.y or spawn_y
        end
        if s.sector then
            sector_x = s.sector.x
            sector_y = s.sector.y
        end
        ship_name = s.ship_name or ship_name
    end

    return spawn_x, spawn_y, ship_name, sector_x, sector_y
end

--
-- PLAYSTATE DEFINITION
--

local PlayState = {}
PlayState.server_time_offset = nil

--
-- LIFECYCLE METHODS
--

function PlayState:enter(prev, param)
    local loadParams = (type(param) == "table") and param or nil
    local snapshot = loadSnapshot(loadParams)
    local is_joining = loadParams and loadParams.mode == "join"
    local join_host = loadParams and loadParams.host or "localhost"

    self:initWorld()
    self:initUI()
    self:initNetwork(is_joining, join_host)
    self:initSystems()
    self:spawnInitialEntities(is_joining, snapshot)
end

function PlayState:update(dt)
    -- 1. Network & Chat Updates
    Chat.update(dt)
    self:updateNetwork(dt)

    -- 2. Input Management
    self:updateControls()

    -- 3. World & Physics Updates
    if self.world.background then
        self.world.background:update(dt)
    end
    
    self.world:emit("update", dt)

    -- 4. Network Interpolation (Client Only)
    if not self.world.hosting then
        self:updateInterpolation(dt)
        self:sendClientInput()
    end

    -- 5. UI Updates
    self:updateHover()
    CargoPanel.update(dt, self.world)
end

function PlayState:draw()
    love.graphics.setBackgroundColor(0.03, 0.05, 0.16)
    
    self.world:emit("draw")

    love.graphics.origin()
    HUD.draw(self.world, self.player)
    Chat.draw()

    self:drawDeathOverlay()
end

function PlayState:drawDeathOverlay()
    if self.world and self.world.player_dead then
        local sw, sh = love.graphics.getDimensions()
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", 0, 0, sw, sh)

        love.graphics.setColor(1, 0.8, 0.8, 1)
        local font = love.graphics.getFont()
        local line_h = font:getHeight()
        local center_y = sh * 0.4

        love.graphics.printf("SHIP DESTROYED", 0, center_y, sw, "center")
        love.graphics.printf("Press R to respawn or ESC to return to menu", 0, center_y + line_h + 10, sw, "center")
    end
end

--
-- INPUT HANDLING
--

function PlayState:keypressed(key)
    if Chat.keypressed(key) then return end

    if self.world and self.world.player_dead then
        if key == "escape" then
            Gamestate.switch(require("src.states.menu"))
        elseif key == "r" or key == "return" or key == "space" then
            self:respawnLocalPlayer()
        end
        return
    end

    if key == "f1" and self.world then
        self.world.debug_asteroid_overlay = not self.world.debug_asteroid_overlay
        return
    end

    if key == "f5" and not self.world.hosting then
        self:startHosting()
        return
    end

    if key == "tab" and self.world and self.world.ui then
        self.world.ui.cargo_open = not self.world.ui.cargo_open
        if not self.world.ui.cargo_open and self.world.ui.cargo_drag then
            self.world.ui.cargo_drag.active = false
        end
    elseif key == "f6" then
        SaveManager.save(1, self.world, self.player)
    elseif key == "f9" then
        if SaveManager.has_save(1) then
            Gamestate.switch(PlayState, { mode = "load", slot = 1 })
        end
    end
end

function PlayState:textinput(t)
    if Chat.textinput(t) then return end
end

function PlayState:mousepressed(x, y, button)
    if button == 1 then
        CargoPanel.mousepressed(x, y, button, self.world)
    end
end

function PlayState:mousereleased(x, y, button)
    if button == 1 then
        CargoPanel.mousereleased(x, y, button, self.world)
    end
end

function PlayState:wheelmoved(x, y)
    if not self.world or not self.world.camera then return end
    local current_zoom = self.world.camera.scale
    local new_zoom = current_zoom + (y > 0 and Config.CAMERA_ZOOM_STEP or (y < 0 and -Config.CAMERA_ZOOM_STEP or 0))
    new_zoom = math.max(Config.CAMERA_MIN_ZOOM, math.min(new_zoom, Config.CAMERA_MAX_ZOOM))
    self.world.camera:zoomTo(new_zoom)
end

--
-- INITIALIZATION SUB-FUNCTIONS
--

function PlayState:initWorld()
    self.world = Concord.world()
    self.world.background = Background.new()
    self.world.debug_asteroid_overlay = false
    self.world.player_dead = false
    self.world.player_death_time = nil
    
    -- Camera
    self.world.camera = Camera.new()
    self.world.camera:zoomTo(Config.CAMERA_DEFAULT_ZOOM)

    -- Physics
    self.world.physics_world = love.physics.newWorld(0, 0, true)
    
    self.world.hosting = false
    self.server_time_offset = nil
    self.world.networked_entities = {}
    self.world.interpolation_buffers = {}
    self.player_entity_ids = {}
    self.player_display_names = {}
    self.my_entity_id = nil
end

function PlayState:initUI()
    self.world.ui = {
        cargo_open = false,
        cargo_window = nil,
        cargo_drag = { active = false, offset_x = 0, offset_y = 0 },
        hover_target = nil,
    }
end

function PlayState:initNetwork(is_joining, join_host)
    PlayNetwork.initNetwork(self, is_joining, join_host)
end

function PlayState:initSystems()
    self.world.controls = baton.new({
        controls = {
            move_left  = { "key:a", "key:left" },
            move_right = { "key:d", "key:right" },
            move_up    = { "key:w", "key:up" },
            move_down  = { "key:s", "key:down" },
            fire       = { "mouse:1" },
            boost      = { "key:space" }
        }
    })
    self.world.controlsEnabled = true

    self.world:addSystems(
        PlayerControlSystem, AISystem, MovementSystem, PhysicsSystem, CollisionSystem,
        WeaponSystem, ProjectileSystem, DeathSystem, ShipDeathSystem, LootSystem,
        AsteroidChunkSystem, ProjectileShardSystem, ItemPickupSystem, TrailSystem,
        RenderSystem, MinimapSystem
    )

    self.player = createLocalPlayer(self.world)
end

function PlayState:spawnInitialEntities(is_joining, snapshot)
    local spawn_x, spawn_y, ship_name, sector_x, sector_y = getSpawnParamsFromSnapshot(snapshot, "starter_drone")

    if not is_joining then
        local ship = ShipSystem.spawn(self.world, ship_name, spawn_x, spawn_y, true)
        if sector_x and ship.sector then
            ship.sector.x = sector_x
            ship.sector.y = sector_y
        end
        linkPlayerToShip(self.player, ship)
        self.world.local_ship = ship
        
        -- Generate Environment
        local player_sector_x = (ship.sector and ship.sector.x) or 0
        local player_sector_y = (ship.sector and ship.sector.y) or 0
        local seed = Config.UNIVERSE_SEED or 12345
        
        if DefaultSector.asteroids.enabled then
            Asteroids.spawnField(self.world, player_sector_x, player_sector_y, seed, DefaultSector.asteroids.count)
        end
        if DefaultSector.enemy_ships.enabled then
            EnemySpawner.spawnField(self.world, player_sector_x, player_sector_y, seed, DefaultSector.enemy_ships.count, DefaultSector.enemy_ships)
        end
    else
        print("PlayState: Joining game, waiting for server spawn...")
    end

    if snapshot and not is_joining then
        SaveManager.apply_snapshot(self.world, self.player, self.world.local_ship, snapshot)
    end
end
 
--
-- UPDATE LOOPS
--

function PlayState:updateNetwork(dt)
    PlayNetwork.updateNetwork(self, dt)
end

function PlayState:updateControls()
    if Chat.isActive() or (self.world and self.world.player_dead) then
        self.world.controlsEnabled = false
    else
        self.world.controlsEnabled = true
    end
end

function PlayState:updateInterpolation(dt)
    PlayNetwork.updateInterpolation(self, dt)
end

function PlayState:sendClientInput()
    PlayNetwork.sendClientInput(self)
end

function PlayState:updateHover()
    if not (self.world and self.world.camera and self.world.ui) then return end

    local mx, my = love.mouse.getPosition()
    local wx, wy = self.world.camera:worldCoords(mx, my)
    
    local ship = self.world.local_ship
    local ship_sx = (ship and ship.sector and ship.sector.x) or 0
    local ship_sy = (ship and ship.sector and ship.sector.y) or 0

    local best, bestDist2
    for _, e in ipairs(self.world:getEntities()) do
        if (e.asteroid or e.asteroid_chunk or e.vehicle) and e.transform and e.render then
            local sx, sy = (e.sector and e.sector.x or 0), (e.sector and e.sector.y or 0)
            
            if math.abs(sx - ship_sx) <= 1 and math.abs(sy - ship_sy) <= 1 then
                local ex = e.transform.x + (sx - ship_sx) * DefaultSector.SECTOR_SIZE
                local ey = e.transform.y + (sy - ship_sy) * DefaultSector.SECTOR_SIZE
                local dx, dy = wx - ex, wy - ey
                local dist2 = dx*dx + dy*dy
                local r = e.render.radius * 1.2
                
                if dist2 <= r*r and (not bestDist2 or dist2 < bestDist2) then
                    best = e
                    bestDist2 = dist2
                end
            end
        end
    end
    self.world.ui.hover_target = best
end

function PlayState:respawnLocalPlayer()
    if not self.world.hosting and not Client.connected then
        local ship = ShipSystem.spawn(self.world, "starter_drone", 0, 0, true)
        if ship then
            self.world.local_ship = ship
            linkPlayerToShip(self.player, ship)
            self.world.player_dead = false
            self.world.player_death_time = nil
        end
    end
end

function PlayState:startHosting()
    PlayNetwork.startHosting(self)
end

return PlayState