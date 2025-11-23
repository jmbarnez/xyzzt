local Gamestate   = require "hump.gamestate"
local baton       = require "baton"
local Camera      = require "hump.camera"
local Concord     = require "concord"
local Config      = require "src.config"
local Background  = require "src.rendering.background"
local HUD         = require "src.ui.hud.hud"
local Chat        = require "src.ui.hud.chat"
local SaveManager = require "src.managers.save_manager"
local Window      = require "src.ui.hud.window"
local CargoPanel  = require "src.ui.hud.cargo_panel"

require "src.ecs.components"

-- System Imports
local PlayerControlSystem   = require "src.ecs.systems.gameplay.player_control"
local MovementSystem        = require "src.ecs.systems.core.movement"
local DeathSystem           = require "src.ecs.systems.gameplay.death"
local LootSystem            = require "src.ecs.systems.gameplay.loot"
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
local DefaultSector         = require "src.data.default_sector"

local PlayState             = {}

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
    if not (player and ship and ship.input) then
        return
    end
    player:give("controlling", ship)
    player.input = ship.input
end

function PlayState:enter(prev, param)
    local loadParams
    if type(param) == "table" then
        loadParams = param
    end

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

    self.world = Concord.world()
    self.world.background = Background.new()

    -- Camera
    self.world.camera = Camera.new()
    self.world.camera:zoomTo(Config.CAMERA_DEFAULT_ZOOM)

    -- Physics (always present; role decides authority)
    self.world.physics_world = love.physics.newWorld(0, 0, true)

    -- UI state for in-flight HUD
    self.world.ui = {
        cargo_open = false,
        cargo_window = nil,
        cargo_drag = {
            active = false,
            offset_x = 0,
            offset_y = 0,
        },
    }

    -- Init Chat
    Chat.init()
    Chat.enable()

    -- Local controls
    self.world.controls = baton.new({
        controls = {
            move_left  = { "key:a", "key:left" },
            move_right = { "key:d", "key:right" },
            move_up    = { "key:w", "key:up" },
            move_down  = { "key:s", "key:down" },
            fire       = { "mouse:1", "key:space" }
        }
    })

    -- Controls are enabled by default
    self.world.controlsEnabled = true

    -- Add Systems
    -- Order matters: Input -> Logic -> Physics -> Collision -> Gameplay -> Render
    self.world:addSystems(
        PlayerControlSystem, -- 1. Map Hardware to Input Component
        MovementSystem,      -- 2. Apply Physics based on Input
        PhysicsSystem,       -- 3. Step Box2D & Handle Sector Wrapping
        CollisionSystem,     -- 4. Resolve Collisions (Damage, etc)
        WeaponSystem,        -- 5. Fire weapons
        ProjectileSystem,    -- 6. Update projectiles
        DeathSystem,         -- 7. Handle HP <= 0
        LootSystem,          -- 8. Spawn loot from dead entities
        AsteroidChunkSystem,
        ProjectileShardSystem,
        ItemPickupSystem, -- 9. Magnet logic
        RenderSystem,     -- 10. Draw everything
        MinimapSystem     -- 11. UI Draw
    )

    -- Player meta-entity (local user, not the ship itself)
    self.player = createLocalPlayer(self.world)

    local spawn_x = 0
    local spawn_y = 0
    local ship_name = "starter_drone"
    local sector_x
    local sector_y

    if snapshot and snapshot.player and snapshot.player.ship then
        local s = snapshot.player.ship
        if s.transform then
            if s.transform.x then spawn_x = s.transform.x end
            if s.transform.y then spawn_y = s.transform.y end
        end
        if s.sector then
            sector_x = s.sector.x
            sector_y = s.sector.y
        end
        if s.ship_name then
            ship_name = s.ship_name
        end
    end

    local ship = ShipSystem.spawn(self.world, ship_name, spawn_x, spawn_y, true)

    if sector_x and ship.sector then
        ship.sector.x = sector_x
        ship.sector.y = sector_y
    end

    linkPlayerToShip(self.player, ship)

    if snapshot then
        SaveManager.apply_snapshot(self.world, self.player, ship, snapshot)
    end

    -- Spawn sector contents based on default_sector configuration
    local player_sector_x = ship.sector and ship.sector.x or 0
    local player_sector_y = ship.sector and ship.sector.y or 0
    local universe_seed = Config.UNIVERSE_SEED or 12345

    -- Spawn asteroids in starting sector
    if DefaultSector.asteroids.enabled then
        Asteroids.spawnField(
            self.world,
            player_sector_x,
            player_sector_y,
            universe_seed,
            DefaultSector.asteroids.count
        )
    end

    -- Spawn enemy ships in starting sector
    if DefaultSector.enemy_ships.enabled then
        EnemySpawner.spawnField(
            self.world,
            player_sector_x,
            player_sector_y,
            universe_seed,
            DefaultSector.enemy_ships.count,
            DefaultSector.enemy_ships
        )
    end
end

function PlayState:update(dt)
    -- 1. Update Chat
    Chat.update(dt)

    -- 2. Toggle Controls based on Chat state
    if Chat.isActive() then
        self.world.controlsEnabled = false
    else
        self.world.controlsEnabled = true
    end

    if self.world.background then
        self.world.background:update(dt)
    end

    self.world:emit("update", dt)

    -- Update cargo window drag (if any)
    local ui = self.world and self.world.ui
    if ui and ui.cargo_drag and ui.cargo_drag.active and ui.cargo_open then
        local mx, my = love.mouse.getPosition()
        local wx, wy, ww, wh = CargoPanel.getWindowRect(self.world)

        local drag = ui.cargo_drag
        local new_x = mx - drag.offset_x
        local new_y = my - drag.offset_y

        local sw, sh = love.graphics.getDimensions()
        new_x = math.max(0, math.min(new_x, sw - ww))
        new_y = math.max(0, math.min(new_y, sh - wh))

        ui.cargo_window = ui.cargo_window or {}
        ui.cargo_window.x = new_x
        ui.cargo_window.y = new_y
        ui.cargo_window.width = ww
        ui.cargo_window.height = wh
    end
end

function PlayState:draw()
    love.graphics.setBackgroundColor(0.03, 0.05, 0.16)
    self.world:emit("draw")

    love.graphics.origin()
    HUD.draw(self.world, self.player)

    -- Draw Chat Overlay
    Chat.draw()
end

function PlayState:keypressed(key)
    -- 1. Check Chat First
    if Chat.keypressed(key) then
        return -- Chat consumed the input
    end

    -- 2. Standard Game Keys
    if key == "tab" then
        if self.world and self.world.ui then
            self.world.ui.cargo_open = not self.world.ui.cargo_open
            if not self.world.ui.cargo_open and self.world.ui.cargo_drag then
                self.world.ui.cargo_drag.active = false
            end
        end
    elseif key == "f5" then
        SaveManager.save(1, self.world, self.player)
    elseif key == "f9" then
        if SaveManager.has_save(1) then
            Gamestate.switch(PlayState, { mode = "load", slot = 1 })
        end
    end
end

function PlayState:textinput(t)
    -- Pass text input to Chat
    if Chat.textinput(t) then
        return
    end
end

function PlayState:mousepressed(x, y, button)
    if button ~= 1 then
        return
    end

    if not (self.world and self.world.ui and self.world.ui.cargo_open) then
        return
    end

    local wx, wy, ww, wh = CargoPanel.getWindowRect(self.world)
    local layout = Window.getLayout({ x = wx, y = wy, width = ww, height = wh })
    local r = layout.close

    -- Close button
    if x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then
        self.world.ui.cargo_open = false
        if self.world.ui.cargo_drag then
            self.world.ui.cargo_drag.active = false
        end
        return
    end

    -- Begin dragging when clicking the title bar (excluding close button)
    local tb = layout.titleBar
    if x >= tb.x and x <= tb.x + tb.w and y >= tb.y and y <= tb.y + tb.h then
        local ui = self.world.ui
        ui.cargo_drag = ui.cargo_drag or {}
        ui.cargo_drag.active = true
        ui.cargo_drag.offset_x = x - wx
        ui.cargo_drag.offset_y = y - wy

        ui.cargo_window = ui.cargo_window or {}
        ui.cargo_window.width = ww
        ui.cargo_window.height = wh
    end
end

function PlayState:mousereleased(x, y, button)
    if button ~= 1 then
        return
    end

    if not (self.world and self.world.ui and self.world.ui.cargo_drag) then
        return
    end

    self.world.ui.cargo_drag.active = false
end

function PlayState:wheelmoved(x, y)
    if not self.world or not self.world.camera then return end

    local current_zoom = self.world.camera.scale
    local new_zoom = current_zoom

    if y > 0 then
        new_zoom = current_zoom + Config.CAMERA_ZOOM_STEP
    elseif y < 0 then
        new_zoom = current_zoom - Config.CAMERA_ZOOM_STEP
    end

    -- Clamp zoom
    new_zoom = math.max(Config.CAMERA_MIN_ZOOM, math.min(new_zoom, Config.CAMERA_MAX_ZOOM))

    self.world.camera:zoomTo(new_zoom)
end

return PlayState
