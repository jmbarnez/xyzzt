local Gamestate     = require "lib.hump.gamestate"
local baton         = require "lib.baton"
local Camera        = require "lib.hump.camera"
local Concord       = require "lib.concord.concord"
local Config        = require "src.config"
local Background    = require "src.rendering.background"
local HUD           = require "src.ui.hud.hud"
local Chat          = require "src.ui.hud.chat"
local SaveManager   = require "src.managers.save_manager"
local Window        = require "src.ui.hud.window"
local CargoPanel    = require "src.ui.hud.cargo_panel"
local Interpolation = require "src.network.interpolation"
local EntityUtils   = require "src.utils.entity_utils"
local Client        = require "src.network.client"
local Protocol      = require "src.network.protocol"
local PlayNetwork   = require "src.states.play_network"

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
            fire       = { "mouse:1", "key:space" }
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
-- NETWORK HANDLERS
--

function PlayState:handleWorldState(packet)
    if self.world.hosting then return end

    -- 1. Sync Time
    self:syncServerTime(packet.server_time)

    -- 2. Track received entities to detect removals
    local received_ids = {}

    -- 3. Update or Spawn Entities
    for _, state in ipairs(packet.entities) do
        received_ids[state.id] = true
        self:syncNetworkEntity(state, packet.server_time)
    end

    -- 4. Handle Removals
    self:processRemovals(packet.removed_ids, received_ids)
end

function PlayState:syncServerTime(server_time)
    local now = love.timer.getTime()
    if server_time then
        local offset = server_time - now
        if self.server_time_offset == nil then
            self.server_time_offset = offset
        elseif offset > self.server_time_offset then
            self.server_time_offset = offset
        else
            -- Slowly drift to avoid jitter
            self.server_time_offset = self.server_time_offset * 0.99 + offset * 0.01
        end
    end
end

function PlayState:syncNetworkEntity(state, server_time)
    local entity = self.world.networked_entities[state.id]
    local is_my_ship = (self.my_entity_id and state.id == self.my_entity_id)

    if entity then
        -- UPDATE EXISTING
        if is_my_ship then
            self:reconcileLocalPlayer(entity, state)
        else
            self:interpolateRemoteEntity(entity, state, server_time)
        end
        self:syncEntityStats(entity, state)
    else
        -- SPAWN NEW
        self:spawnNetworkEntity(state, is_my_ship)
    end
    
    -- Update Name Tag if applicable
    entity = self.world.networked_entities[state.id] -- Fetch again just in case
    if entity and entity.vehicle and not entity.ai and not entity.name then
       self:assignPlayerName(entity, state.id)
    end
end

function PlayState:reconcileLocalPlayer(entity, state)
    if not entity.transform then return end
    
    local dx = entity.transform.x - state.x
    local dy = entity.transform.y - state.y
    local dist_sq = dx * dx + dy * dy
    local snap_dist = Config.RECONCILE_SNAP_DISTANCE or 150
    local hard_threshold = snap_dist * snap_dist

    if dist_sq > hard_threshold then
        -- Hard Snap
        entity.transform.x, entity.transform.y = state.x, state.y
        if entity.physics and entity.physics.body and not entity.physics.body:isDestroyed() then
            entity.physics.body:setPosition(state.x, state.y)
            if state.vx and state.vy then
                entity.physics.body:setLinearVelocity(state.vx, state.vy)
            end
        end
    else
        -- Soft Reconcile
        local blend = 0.1
        entity.transform.x = entity.transform.x + (state.x - entity.transform.x) * blend
        entity.transform.y = entity.transform.y + (state.y - entity.transform.y) * blend
        
        if entity.physics and entity.physics.body and not entity.physics.body:isDestroyed() then
            local b = entity.physics.body
            local bx, by = b:getPosition()
            b:setPosition(bx + (state.x - bx) * blend, by + (state.y - by) * blend)
            
            if state.vx and state.vy then
                local bvx, bvy = b:getLinearVelocity()
                b:setLinearVelocity(bvx + (state.vx - bvx) * blend, bvy + (state.vy - bvy) * blend)
            end
        end
    end
end

function PlayState:interpolateRemoteEntity(entity, state, server_time)
    -- 1. Drift Check & Snap
    local snap_threshold = Config.RECONCILE_ASTEROID or 50
    if state.type == "vehicle" then snap_threshold = Config.RECONCILE_REMOTE_SHIP or 100 end
    if state.type == "projectile" then snap_threshold = Config.RECONCILE_PROJECTILE or 25 end

    local should_snap = false
    if entity.transform then
        local dx = entity.transform.x - state.x
        local dy = entity.transform.y - state.y
        if (dx * dx + dy * dy) > (snap_threshold * snap_threshold) then
            should_snap = true
        end
    end

    if should_snap then
        if entity.transform then
            entity.transform.x, entity.transform.y, entity.transform.r = state.x, state.y, state.r
        end
        if entity.physics and entity.physics.body and not entity.physics.body:isDestroyed() then
            entity.physics.body:setPosition(state.x, state.y)
            entity.physics.body:setAngle(state.r)
            if state.vx and state.vy then entity.physics.body:setLinearVelocity(state.vx, state.vy) end
            if state.angular_velocity then entity.physics.body:setAngularVelocity(state.angular_velocity) end
        end
        self.world.interpolation_buffers[state.id] = nil
    end

    -- 2. Add to Buffer
    local buffer = self.world.interpolation_buffers[state.id]
    if not buffer then
        buffer = Interpolation.createBuffer()
        self.world.interpolation_buffers[state.id] = buffer
    end

    local now = love.timer.getTime()
    local time_offset = self.server_time_offset or 0
    local packet_time = (server_time and (server_time + time_offset)) or now

    Interpolation.addState(buffer, packet_time, state.x, state.y, state.r, state.vx, state.vy, state.angular_velocity)

    if entity.sector then
        entity.sector.x = state.sx
        entity.sector.y = state.sy
    end
end

function PlayState:syncEntityStats(entity, state)
    if entity.hp and state.hp_current then entity.hp.current = state.hp_current end
    if entity.hull and state.hull_current then
        entity.hull.current = state.hull_current
        if state.hull_max then entity.hull.max = state.hull_max end
    end
    if entity.shield and state.shield_current then
        entity.shield.current = state.shield_current
        if state.shield_max then entity.shield.max = state.shield_max end
    end
end

function PlayState:spawnNetworkEntity(state, is_me)
    local entity

    if state.type == "vehicle" then
        local ship_def = "starter_drone"
        if state.render_type == "procedural" and state.render_seed then
            local ProceduralShip = require "src.utils.procedural_ship"
            ship_def = ProceduralShip.generate(state.render_seed)
        end
        
        -- Pass table or string to spawn
        entity = ShipSystem.spawn(self.world, ship_def, state.x, state.y, is_me)
        if entity then
            if entity.transform then entity.transform.r = state.r end
            if entity.physics and entity.physics.body then entity.physics.body:setAngle(state.r) end
            
            if is_me then
                print("Linking controls to my authoritative ship!")
                linkPlayerToShip(self.player, entity)
                self.world.local_ship = entity
                if entity.render then entity.render.color = { 0.2, 1, 0.2 } end
            end
            print("Spawned remote vehicle id=" .. state.id)
        end

    elseif state.type == "asteroid" then
        entity = Concord.entity(self.world)
        entity:give("transform", state.x, state.y, state.r or 0)
        entity:give("sector", state.sx, state.sy)
        
        local vertices = state.vertices
        if not vertices and state.vertices_str then
            vertices = {}
            for num in string.gmatch(state.vertices_str, "[^,]+") do table.insert(vertices, tonumber(num)) end
        end

        entity:give("render", {
            type = "asteroid",
            color = state.color or { 0.6, 0.6, 0.6, 1 },
            radius = state.radius or 30,
            vertices = vertices,
            seed = state.seed,
        })
        entity:give("asteroid", state.seed)
        
        local hp = state.hp_max or state.hp_current or 60
        entity:give("hp", hp, state.hp_current or hp)

        -- Physics
        if self.world.physics_world then
            local body = love.physics.newBody(self.world.physics_world, state.x, state.y, "dynamic")
            body:setLinearDamping(Config.LINEAR_DAMPING * 2)
            body:setAngularDamping(Config.LINEAR_DAMPING * 2)
            body:setAngle(state.r or 0)

            local shape
            if vertices and #vertices >= 6 then
                 -- Clamp to Box2D limit
                local verts = ( #vertices > 16 ) and {unpack(vertices, 1, 16)} or vertices
                pcall(function() shape = love.physics.newPolygonShape(verts) end)
            end
            if not shape then shape = love.physics.newCircleShape(state.radius or 30) end
            
            local fixture = love.physics.newFixture(body, shape, 1.0)
            fixture:setRestitution(0.1)
            fixture:setUserData(entity)
            entity:give("physics", body, shape, fixture)
            
            if state.vx and state.vy then body:setLinearVelocity(state.vx, state.vy) end
            if state.angular_velocity then body:setAngularVelocity(state.angular_velocity) end
        end

    elseif state.type == "asteroid_chunk" then
         entity = Concord.entity(self.world)
         entity:give("transform", state.x, state.y, state.r or 0)
         entity:give("sector", state.sx, state.sy)
         
         local vertices = state.vertices
         if not vertices and state.vertices_str then
             vertices = {}
             for num in string.gmatch(state.vertices_str, "[^,]+") do table.insert(vertices, tonumber(num)) end
         end
         
         entity:give("render", {
             render_type = "asteroid_chunk",
             color = state.color or { 0.7, 0.7, 0.7, 1 },
             radius = state.radius or 10,
             vertices = vertices,
             seed = state.seed
         })
         entity:give("asteroid_chunk")
         entity:give("hp", state.hp_max or 10, state.hp_current or 10)
         
         if self.world.physics_world then
             local body = love.physics.newBody(self.world.physics_world, state.x, state.y, "dynamic")
             body:setLinearDamping(1)
             body:setAngularDamping(1)
             
             local shape
             if vertices and #vertices >= 6 then
                 local verts = ( #vertices > 16 ) and {unpack(vertices, 1, 16)} or vertices
                 pcall(function() shape = love.physics.newPolygonShape(verts) end)
             end
             if not shape then shape = love.physics.newCircleShape(state.radius or 8) end
             
             local fixture = love.physics.newFixture(body, shape, 0.5)
             fixture:setRestitution(0.2)
             fixture:setUserData(entity)
             entity:give("physics", body, shape, fixture)
             
             if state.vx and state.vy then body:setLinearVelocity(state.vx, state.vy) end
             if state.angular_velocity then body:setAngularVelocity(state.angular_velocity) end
         end

    elseif state.type == "projectile" then
        local is_my_projectile = (self.my_entity_id and state.owner_id == self.my_entity_id)
        if is_my_projectile then return end -- Skip local projectiles

        entity = Concord.entity(self.world)
        entity:give("transform", state.x, state.y, state.r or 0)
        entity:give("sector", state.sx, state.sy)
        
        local owner = state.owner_id and self.world.networked_entities[state.owner_id]
        entity:give("projectile", state.damage or 10, state.lifetime or 1.5, owner)
        entity:give("render", {
            type = "projectile",
            color = state.color or { 1, 0.5, 0 },
            radius = state.radius or 3,
            length = state.length,
            thickness = state.thickness,
            shape = state.shape or "beam"
        })
        
        if self.world.physics_world then
            local body = love.physics.newBody(self.world.physics_world, state.x, state.y, "dynamic")
            body:setBullet(true)
            body:setAngle(state.r or 0)
            local r = state.radius or 3
            local l = state.length or (r * 4)
            local t = state.thickness or (r * 0.7)
            local shape = love.physics.newPolygonShape(-l/2, -t/2, l/2, -t/2, l/2, t/2, -l/2, t/2)
            local fixture = love.physics.newFixture(body, shape, 0.1)
            fixture:setRestitution(0)
            fixture:setSensor(true)
            fixture:setGroupIndex(-1)
            fixture:setUserData(entity)
            entity:give("physics", body, shape, fixture)
            if state.vx and state.vy then body:setLinearVelocity(state.vx, state.vy) end
        end

    elseif state.type == "item" then
        entity = Concord.entity(self.world)
        entity:give("transform", state.x, state.y, state.r or 0)
        entity:give("sector", state.sx, state.sy)
        entity:give("render", { render_type = "item", color = state.color, shape = state.shape })
        entity:give("item", state.item_type, state.item_name, state.item_volume)
        
        if self.world.physics_world then
            local body = love.physics.newBody(self.world.physics_world, state.x, state.y, "kinematic")
            body:setLinearDamping(2)
            body:setAngularDamping(2)
            entity:give("physics", body, nil, nil)
             if state.vx and state.vy then body:setLinearVelocity(state.vx, state.vy) end
             if state.angular_velocity then body:setAngularVelocity(state.angular_velocity) end
        end
    end

    if entity then
        entity.network_id = state.id
        self.world.networked_entities[state.id] = entity
        self:syncEntityStats(entity, state)
    end
end

function PlayState:processRemovals(explicit_removals, received_ids)
    if explicit_removals then
        for _, net_id in ipairs(explicit_removals) do
            if net_id ~= self.my_entity_id then
                self:removeNetworkEntity(net_id)
            end
        end
    else
        -- Infer removals from full snapshot (missing IDs)
        local to_remove = {}
        for net_id, _ in pairs(self.world.networked_entities) do
            if not received_ids[net_id] and net_id ~= self.my_entity_id then
                table.insert(to_remove, net_id)
            end
        end
        for _, net_id in ipairs(to_remove) do
            self:removeNetworkEntity(net_id)
        end
    end
end

function PlayState:removeNetworkEntity(net_id)
    local entity = self.world.networked_entities[net_id]
    if entity then
        EntityUtils.cleanup_physics_entity(entity)
        self.world.networked_entities[net_id] = nil
        self.world.interpolation_buffers[net_id] = nil
    end
end

function PlayState:handlePlayerJoined(player_id, entity_id, player_count)
    local name = (Client.player_id and player_id == Client.player_id) and "You" or ("Player " .. player_id)
    Chat.system(string.format("%s joined the game.%s", name, (player_count and " Players online: " .. player_count) or ""))

    if entity_id and self.world.local_ship and entity_id ~= 0 then
        if not self.world.local_ship.network_id then -- If we haven't been assigned one yet
            self.world.local_ship.network_id = entity_id
            self.world.networked_entities[entity_id] = self.world.local_ship
            print("Registered local ship with network_id=" .. entity_id)
        end
        self.player_entity_ids[player_id] = entity_id
    end
end

function PlayState:handlePlayerLeft(player_id, player_count)
    local name = (Client.player_id and player_id == Client.player_id) and "You" or ("Player " .. player_id)
    Chat.system(string.format("%s left the game.%s", name, (player_count and " Players online: " .. player_count) or ""))
    
    local entity_id = self.player_entity_ids[player_id]
    if entity_id then
        self.player_entity_ids[player_id] = nil
        local entity = self.world.networked_entities[entity_id]
        if entity and entity ~= self.world.local_ship then
             self:removeNetworkEntity(entity_id)
        end
    end
end

function PlayState:handleWelcome(player_id, entity_id)
    self.my_entity_id = entity_id
    if player_id and entity_id and entity_id ~= 0 then
        self.player_entity_ids[player_id] = entity_id
    end
end

function PlayState:assignPlayerName(entity, entity_id)
    local owner_id
    for pid, eid in pairs(self.player_entity_ids) do
        if eid == entity_id then owner_id = pid; break end
    end
    
    if owner_id then
        local label = (Client.player_id and owner_id == Client.player_id) and (Config.PLAYER_NAME or "Player") or ("Player " .. owner_id)
        entity:give("name", label)
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