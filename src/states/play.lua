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
local TrailSystem           = require "src.ecs.systems.visual.trail"
local DefaultSector         = require "src.data.default_sector"

local PlayState             = {}
PlayState.server_time_offset = nil

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
    local spawn_x = 0
    local spawn_y = 0
    local ship_name = default_ship_name or "starter_drone"
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

    return spawn_x, spawn_y, ship_name, sector_x, sector_y
end

local function sendClientInput(self)
    local Client = require "src.network.client"
    if not self.world.hosting and Client.connected and self.world.local_ship and self.world.local_ship.input then
        local input = self.world.local_ship.input
        local transform = self.world.local_ship.transform
        Client.sendInput(
            input.move_x or 0,
            input.move_y or 0,
            input.fire or false,
            input.target_angle or 0,
            transform.x,
            transform.y,
            transform.r
        )
    end
end

function PlayState:enter(prev, param)
    local loadParams
    if type(param) == "table" then
        loadParams = param
    end

    -- Check if we're joining
    local is_joining = loadParams and loadParams.mode == "join"
    local join_host = loadParams and loadParams.host or "localhost"

    local snapshot = loadSnapshot(loadParams)

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
        hover_target = nil,
    }

    -- Init Chat
    Chat.init()
    Chat.enable()

    -- Init ENet Client
    local Client = require "src.network.client"

    -- Server hosting is disabled by default (press F5 to host)
    self.world.hosting = false

    -- Setup Chat Networking
    Chat.setSendHandler(function(message)
        local Client = require "src.network.client"
        local Protocol = require "src.network.protocol"

        -- If we're connected as a network client, send through the server
        if Client.connected then
            Client.sendChatMessage(message)
            return
        end

        -- If we're hosting but not connected as a client, broadcast directly via the server
        if self.world.hosting and self.world.server then
            local Server = self.world.server

            -- Show locally for the host
            Chat.addMessage("You: " .. message, "text")

            -- Broadcast to all connected clients as a host/system message (player_id = 0)
            local host_player_id = 0
            local packet = Protocol.createChatBroadcastPacket(host_player_id, message)
            Server.broadcast(packet)
            return
        end

        -- Singleplayer / offline: just show locally
        Chat.addMessage("You: " .. message, "text")
    end)

    Client.setChatCallback(function(player_id, message)
        -- Determine sender name
        local sender = "Player " .. player_id
        if Client.player_id and player_id == Client.player_id then
            sender = "You"
        end

        Chat.addMessage(sender .. ": " .. message, "text")
    end)

    -- Set server address
    if is_joining then
        Client.server_address = join_host
        -- Auto-connect when joining
        Client.connect()
    else
        Client.server_address = "localhost"
        -- Don't auto-connect, wait for F5 hosting or manual join
    end

    -- Track networked entities by network_id
    self.world.networked_entities = {}    -- Map of network_id -> entity
    self.world.interpolation_buffers = {} -- Map of network_id -> interpolation buffer

    -- Set up network callbacks
    Client.setWorldStateCallback(function(packet)
        -- Hosts don't process world state updates - they ARE the authoritative world!
        if self.world.hosting then
            return
        end

        local now = love.timer.getTime()
        if packet.server_time then
            local offset = now - packet.server_time
            if self.server_time_offset == nil then
                self.server_time_offset = offset
            else
                self.server_time_offset = self.server_time_offset * 0.9 + offset * 0.1
            end
        end
        local time_offset = self.server_time_offset or 0

        -- Apply world state to entities (CLIENTS ONLY)
        for _, state in ipairs(packet.entities) do
            local entity = self.world.networked_entities[state.id]

            if entity then
                -- Check if this is our own controlled ship
                local is_my_ship = (self.my_entity_id and state.id == self.my_entity_id)

                -- Update existing entity
                -- For OUR ship: only update HP, not position (client-side prediction)
                -- UNLESS we are way out of sync (e.g. big collision discrepancy)
                if is_my_ship then
                    if entity.transform then
                        local dx = entity.transform.x - state.x
                        local dy = entity.transform.y - state.y
                        local dist_sq = dx * dx + dy * dy

                        local snap_dist = Config.RECONCILE_SNAP_DISTANCE or 150
                        local threshold = snap_dist * snap_dist

                        if dist_sq > threshold then
                            -- Hard snap to server position only when error is very large
                            entity.transform.x = state.x
                            entity.transform.y = state.y

                            if entity.physics and entity.physics.body and not entity.physics.body:isDestroyed() then
                                entity.physics.body:setPosition(state.x, state.y)

                                if state.vx and state.vy then
                                    entity.physics.body:setLinearVelocity(state.vx, state.vy)
                                end
                            end
                        end
                    end
                else
                    -- For REMOTE ships and asteroids: use interpolation
                    -- Add state to interpolation buffer
                    local buffer = self.world.interpolation_buffers[state.id]
                    if not buffer then
                        buffer = Interpolation.createBuffer()
                        self.world.interpolation_buffers[state.id] = buffer
                    end

                    -- Add this state to the buffer
                    Interpolation.addState(
                        buffer,
                        (packet.server_time and (packet.server_time + time_offset)) or now,
                        state.x,
                        state.y,
                        state.r,
                        state.vx,
                        state.vy,
                        state.angular_velocity
                    )

                    -- Sector is discrete; update it immediately from latest state
                    if entity.sector then
                        entity.sector.x = state.sx
                        entity.sector.y = state.sy
                    end
                end

                -- Always update HP (even for local player)
                if entity.hp and state.hp_current then
                    entity.hp.current = state.hp_current
                end
            else
                -- Spawn new remote entity if it doesn't exist
                if state.type == "vehicle" then
                    -- Spawn remote player ship
                    local is_me = (self.my_entity_id and state.id == self.my_entity_id)
                    local ship = ShipSystem.spawn(self.world, "starter_drone", state.x, state.y, is_me)

                    if ship then
                        -- Store network ID
                        ship.network_id = state.id

                        -- Set initial state
                        if ship.transform then
                            ship.transform.r = state.r
                        end
                        if ship.sector then
                            ship.sector.x = state.sx
                            ship.sector.y = state.sy
                        end
                        if ship.physics and ship.physics.body and not ship.physics.body:isDestroyed() then
                            -- Set rotation on physics body
                            ship.physics.body:setAngle(state.r)
                            -- Set velocity
                            if state.vx and state.vy then
                                ship.physics.body:setLinearVelocity(state.vx, state.vy)
                            end
                        end
                        if ship.hp and state.hp_current then
                            ship.hp.current = state.hp_current
                        end

                        -- Track this entity
                        self.world.networked_entities[state.id] = ship

                        print("Spawned remote player ship with network_id=" .. state.id)

                        -- If this is MY ship (from WELCOME packet), link controls!
                        if is_me then
                            print("Linking controls to my authoritative ship!")
                            linkPlayerToShip(self.player, ship)
                            self.world.local_ship = ship
                            -- Ensure it's marked as host/local for rendering (green)
                            if ship.render then
                                ship.render.color = { 0.2, 1, 0.2 }
                            end
                        end
                    end
                elseif state.type == "asteroid" then
                    -- Spawn remote asteroid using server-authoritative geometry (vertices)
                    local asteroid = Concord.entity(self.world)
                    asteroid.network_id = state.id

                    asteroid:give("transform", state.x, state.y, state.r or 0)
                    asteroid:give("sector", state.sx, state.sy)

                    asteroid:give("render", {
                        type = "asteroid",
                        color = state.color or { 0.6, 0.6, 0.6, 1 },
                        radius = state.radius or 30,
                        vertices = state.vertices,
                        seed = state.seed,
                    })

                    -- Store asteroid seed for any systems that rely on it
                    if state.seed then
                        asteroid:give("asteroid", state.seed)
                    else
                        asteroid:give("asteroid")
                    end

                    if state.hp_max or state.hp_current then
                        local hp_max = state.hp_max or state.hp_current or 60
                        local hp_current = state.hp_current or state.hp_max or hp_max
                        asteroid:give("hp", hp_max, hp_current)
                    end

                    -- Physics body using server-provided polygon (clamped to Box2D 8-vertex limit)
                    if self.world.physics_world then
                        local body = love.physics.newBody(self.world.physics_world, state.x, state.y, "dynamic")
                        body:setLinearDamping(Config.LINEAR_DAMPING * 2)
                        body:setAngularDamping(Config.LINEAR_DAMPING * 2)

                        local shape
                        local verts = state.vertices
                        if type(verts) == "table" and #verts >= 6 and (#verts % 2 == 0) then
                            -- Box2D supports a maximum of 8 vertices per polygon
                            local maxCoords = 8 * 2
                            if #verts > maxCoords then
                                local truncated = {}
                                for i = 1, maxCoords do
                                    truncated[i] = verts[i]
                                end
                                verts = truncated
                            end
                            shape = love.physics.newPolygonShape(verts)
                        else
                            -- Fallback: simple circle if vertices are missing or invalid
                            shape = love.physics.newCircleShape(state.radius or 30)
                        end

                        local fixture = love.physics.newFixture(body, shape, 1.0)
                        fixture:setRestitution(0.1)
                        fixture:setUserData(asteroid)

                        asteroid:give("physics", body, shape, fixture)

                        body:setAngle(state.r or 0)
                        if state.vx and state.vy then
                            body:setLinearVelocity(state.vx, state.vy)
                        end
                        if state.angular_velocity then
                            body:setAngularVelocity(state.angular_velocity)
                        end
                    end

                    self.world.networked_entities[state.id] = asteroid
                elseif state.type == "asteroid_chunk" then
                    -- Spawn remote asteroid chunk using server-sent shape/seed
                    local chunk = Concord.entity(self.world)
                    chunk.network_id = state.id

                    chunk:give("transform", state.x, state.y, state.r or 0)
                    chunk:give("sector", state.sx, state.sy)

                    chunk:give("render", {
                        render_type = "asteroid_chunk",
                        color = state.color or { 0.7, 0.7, 0.7, 1 },
                        radius = state.radius or 10,
                        vertices = state.vertices,
                        seed = state.seed,
                    })
                    chunk:give("asteroid_chunk")

                    if state.hp_max or state.hp_current then
                        chunk:give("hp", state.hp_max or state.hp_current or 10, state.hp_current or state.hp_max or 10)
                    end

                    if self.world.physics_world and state.vertices then
                        local body = love.physics.newBody(self.world.physics_world, state.x, state.y, "dynamic")
                        body:setLinearDamping(1.0)
                        body:setAngularDamping(1.0)

                        local verts = state.vertices
                        local shape
                        if type(verts) == "table" and #verts >= 6 and (#verts % 2 == 0) then
                            -- Clamp chunk polygons to Box2D 8-vertex limit as well
                            local maxCoords = 8 * 2
                            if #verts > maxCoords then
                                local truncated = {}
                                for i = 1, maxCoords do
                                    truncated[i] = verts[i]
                                end
                                verts = truncated
                            end
                            shape = love.physics.newPolygonShape(verts)
                        else
                            shape = love.physics.newCircleShape(state.radius or 8)
                        end
                        local fixture = love.physics.newFixture(body, shape, 0.5)
                        fixture:setRestitution(0.2)
                        fixture:setUserData(chunk)

                        chunk:give("physics", body, shape, fixture)

                        if state.vx and state.vy then
                            body:setLinearVelocity(state.vx, state.vy)
                        end
                        if state.angular_velocity then
                            body:setAngularVelocity(state.angular_velocity)
                        end
                    end

                    self.world.networked_entities[state.id] = chunk
                elseif state.type == "projectile" then
                    local is_my_projectile = (self.my_entity_id and state.owner_id == self.my_entity_id)

                    -- Shooters use locally predicted projectiles; skip server projectiles owned by us.
                    if not is_my_projectile then
                        -- Spawn remote projectile
                        local projectile = Concord.entity(self.world)
                        projectile.network_id = state.id
                        projectile:give("transform", state.x, state.y, state.r or 0)
                        projectile:give("sector", state.sx, state.sy)

                        -- Resolve projectile owner on the client (if provided) so we can
                        -- avoid self-collision visuals and logic.
                        local owner_entity = nil
                        if state.owner_id then
                            owner_entity = self.world.networked_entities[state.owner_id]
                        end
                        projectile:give("projectile", state.damage or 10, state.lifetime or 1.5, owner_entity)
                        projectile:give("render", {
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

                            local radius = state.radius or 3
                            local length = state.length or (radius * 4)
                            local thickness = state.thickness or (radius * 0.7)
                            local half_length = length * 0.5
                            local half_thickness = thickness * 0.5

                            local shape = love.physics.newPolygonShape(
                                -half_length, -half_thickness,
                                half_length, -half_thickness,
                                half_length, half_thickness,
                                -half_length, half_thickness
                            )

                            local fixture = love.physics.newFixture(body, shape, 0.1)
                            fixture:setRestitution(0)
                            fixture:setSensor(true)
                            projectile:give("physics", body, shape, fixture)
                            fixture:setUserData(projectile)

                            if state.vx and state.vy then
                                body:setLinearVelocity(state.vx, state.vy)
                            end
                        end

                        self.world.networked_entities[state.id] = projectile
                    end
                end
            end
        end
    end)

    Client.setPlayerJoinedCallback(function(player_id, entity_id)
        print("Player joined: player_id=" .. player_id .. ", entity_id=" .. tostring(entity_id))

        -- If this is our own join confirmation, track our local ship
        if entity_id and self.world.local_ship then
            self.world.local_ship.network_id = entity_id
            self.world.networked_entities[entity_id] = self.world.local_ship
            print("Registered local ship with network_id=" .. entity_id)
        end
    end)

    Client.setPlayerLeftCallback(function(player_id)
        print("Player left: " .. player_id)
        -- Note: We'll need to enhance this to remove the entity from networked_entities
        -- when we have a way to map player_id to entity_id
    end)

    -- Handle WELCOME packet (Authoritative Spawning)
    self.my_entity_id = nil
    Client.setWelcomeCallback(function(player_id, entity_id)
        print("Received WELCOME: You are player " .. player_id .. ", entity " .. tostring(entity_id))
        self.my_entity_id = entity_id
    end)

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
        TrailSystem,      -- 10. Update trails
        RenderSystem,     -- 11. Draw everything
        MinimapSystem     -- 12. UI Draw
    )

    -- Player meta-entity (local user, not the ship itself)
    self.player = createLocalPlayer(self.world)

    local spawn_x, spawn_y, ship_name, sector_x, sector_y = getSpawnParamsFromSnapshot(snapshot, "starter_drone")

    local ship
    if not is_joining then
        ship = ShipSystem.spawn(self.world, ship_name, spawn_x, spawn_y, true)

        if sector_x and ship.sector then
            ship.sector.x = sector_x
            ship.sector.y = sector_y
        end

        linkPlayerToShip(self.player, ship)

        -- Track local player's ship for network updates
        -- The server will assign a network_id when the player joins
        self.world.local_ship = ship
    else
        print("PlayState: Joining game, waiting for server spawn...")
        -- Do NOT spawn a ship locally. Wait for WELCOME packet and World State.
    end

    if snapshot then
        SaveManager.apply_snapshot(self.world, self.player, ship, snapshot)
    end

    -- Spawn sector contents based on default_sector configuration
    local player_sector_x = (ship and ship.sector and ship.sector.x) or 0
    local player_sector_y = (ship and ship.sector and ship.sector.y) or 0
    local universe_seed = Config.UNIVERSE_SEED or 12345

    -- Spawn asteroids in starting sector
    if DefaultSector.asteroids.enabled and not is_joining then
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

    -- Update server if hosting (in-process, non-blocking)
    if self.world.hosting then
        local Server = require "src.network.server"
        Server.update(dt)
    end

    -- Update ENet Client
    local Client = require "src.network.client"
    Client.update(dt)

    -- 2. Controls are disabled when chat is active
    if Chat.isActive() then
        self.world.controlsEnabled = false
    else
        self.world.controlsEnabled = true
    end

    if self.world.background then
        self.world.background:update(dt)
    end

    self.world:emit("update", dt)

    -- Apply interpolation for remote entities every frame (clients only)
    if not self.world.hosting then
        for id, buffer in pairs(self.world.interpolation_buffers) do
            local entity = self.world.networked_entities[id]
            if entity then
                local interp_state = Interpolation.getInterpolatedState(buffer)
                if interp_state then
                    if entity.transform then
                        entity.transform.x = interp_state.x
                        entity.transform.y = interp_state.y
                        entity.transform.r = interp_state.r
                    end
                    if entity.physics and entity.physics.body and not entity.physics.body:isDestroyed() then
                        entity.physics.body:setPosition(interp_state.x, interp_state.y)
                        entity.physics.body:setAngle(interp_state.r)
                        if interp_state.vx and interp_state.vy then
                            entity.physics.body:setLinearVelocity(interp_state.vx, interp_state.vy)
                        end
                        if interp_state.angular_velocity then
                            entity.physics.body:setAngularVelocity(interp_state.angular_velocity)
                        end
                    end
                end
            end
        end
    end

    -- Send inputs to server (CLIENTS ONLY - hosts apply inputs locally)
    sendClientInput(self)

    if self.world and self.world.camera and self.world.ui then
        local mx, my = love.mouse.getPosition()
        local wx, wy = self.world.camera:worldCoords(mx, my)

        local player = self.player
        local ship = player and player.controlling and player.controlling.entity or nil
        local ship_sector_x = ship and ship.sector and ship.sector.x or 0
        local ship_sector_y = ship and ship.sector and ship.sector.y or 0

        local best
        local bestDist2
        for _, e in ipairs(self.world:getEntities()) do
            local t = e.transform
            local s = e.sector
            local r = e.render
            if t and s and r and r.radius and (e.asteroid or e.asteroid_chunk or e.vehicle) then
                local diff_x = (s.x or 0) - ship_sector_x
                local diff_y = (s.y or 0) - ship_sector_y

                -- Optimization: Only check entities in neighbor sectors
                if math.abs(diff_x) <= 1 and math.abs(diff_y) <= 1 then
                    local ex = t.x + diff_x * Config.SECTOR_SIZE
                    local ey = t.y + diff_y * Config.SECTOR_SIZE
                    local dx = wx - ex
                    local dy = wy - ey
                    local dist2 = dx * dx + dy * dy
                    local pickRadius = r.radius * 1.2
                    if dist2 <= pickRadius * pickRadius and (not bestDist2 or dist2 < bestDist2) then
                        best = e
                        bestDist2 = dist2
                    end
                end
            end
        end
        self.world.ui.hover_target = best
    end

    -- Update cargo window drag (if any)
    CargoPanel.update(dt, self.world)
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

    -- F5: Start hosting (like Minecraft's "Open to LAN")
    if key == "f5" and not self.world.hosting then
        local Server = require "src.network.server"
        -- Pass the host's existing world to the server!
        if Server.start(25565, self.world) then
            self.world.hosting = true
            self.world.server = Server
            print("Hosting server on port 25565 (F5 pressed)")
            print("Your world is now open for others to join!")

            -- Host sees chat from clients via server callback
            Server.setChatCallback(function(player_id, message)
                local sender = "Player " .. tostring(player_id)
                if player_id == 0 then
                    sender = "Host"
                end
                Chat.addMessage(sender .. ": " .. message, "text")
            end)

            -- Give the host's ship a network ID so it can be synced to clients
            if self.world.local_ship then
                self.world.local_ship.network_id = Server.next_network_id
                Server.next_network_id = Server.next_network_id + 1
                print("Host ship assigned network_id=" .. self.world.local_ship.network_id)
            end

            -- Retroactively assign network IDs to all existing asteroids, asteroid chunks, and projectiles
            -- This is CRITICAL: entities spawned at game start (before hosting) need IDs to be synced!
            for _, e in ipairs(self.world:getEntities()) do
                if (e.asteroid or e.asteroid_chunk or e.projectile) and not e.network_id then
                    e.network_id = Server.next_network_id
                    Server.next_network_id = Server.next_network_id + 1
                end
            end
        end
        return
    end

    -- 2. Standard Game Keys
    if key == "tab" then
        if self.world and self.world.ui then
            self.world.ui.cargo_open = not self.world.ui.cargo_open
            if not self.world.ui.cargo_open and self.world.ui.cargo_drag then
                self.world.ui.cargo_drag.active = false
            end
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
    -- Pass text input to Chat
    if Chat.textinput(t) then
        return
    end
end

function PlayState:mousepressed(x, y, button)
    if button ~= 1 then
        return
    end

    if CargoPanel.mousepressed(x, y, button, self.world) then
        return
    end
end

function PlayState:mousereleased(x, y, button)
    if button ~= 1 then
        return
    end

    if CargoPanel.mousereleased(x, y, button, self.world) then
        return
    end
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
