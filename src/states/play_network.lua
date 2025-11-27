local Chat          = require "src.ui.hud.chat"
local Config        = require "src.config"
local Interpolation = require "src.network.interpolation"
local EntityUtils   = require "src.utils.entity_utils"
local Client        = require "src.network.client"
local Protocol      = require "src.network.protocol"
local ShipSystem    = require "src.ecs.spawners.ship"
local Concord       = require "lib.concord.concord"

local PlayNetwork = {}

local function syncServerTime(self, server_time)
    local now = love.timer.getTime()
    if server_time then
        local offset = server_time - now
        if self.server_time_offset == nil then
            self.server_time_offset = offset
        elseif offset > self.server_time_offset then
            self.server_time_offset = offset
        else
            self.server_time_offset = self.server_time_offset * 0.99 + offset * 0.01
        end
    end
end

function PlayNetwork.handlePlayerInfo(self, player_id, name)
    if not player_id or not name or name == "" then return end

    self.player_display_names = self.player_display_names or {}
    self.player_display_names[player_id] = name

    -- If we already know which entity belongs to this player, update its name now
    local entity_id = self.player_entity_ids and self.player_entity_ids[player_id]
    if entity_id and self.world and self.world.networked_entities then
        local entity = self.world.networked_entities[entity_id]
        if entity and entity.vehicle and not entity.ai then
            if entity.name then
                entity.name.value = name
            else
                entity:give("name", name)
            end
        end
    end
end

local function reconcileLocalPlayer(self, entity, state)
    if not entity.transform then return end

    local dx = entity.transform.x - state.x
    local dy = entity.transform.y - state.y
    local dist_sq = dx * dx + dy * dy
    local snap_dist = Config.RECONCILE_SNAP_DISTANCE or 150
    local hard_threshold = snap_dist * snap_dist

    if dist_sq > hard_threshold then
        entity.transform.x, entity.transform.y = state.x, state.y
        if entity.physics and entity.physics.body and not entity.physics.body:isDestroyed() then
            entity.physics.body:setPosition(state.x, state.y)
            if state.vx and state.vy then
                entity.physics.body:setLinearVelocity(state.vx, state.vy)
            end
        end
    else
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

local function interpolateRemoteEntity(self, entity, state, server_time)
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

local function syncEntityStats(entity, state)
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

local function linkPlayerToShip(player, ship)
    if not (player and ship and ship.input) then return end
    player:give("controlling", ship)
    player.input = ship.input
end

local function spawnNetworkEntity(self, state, is_me)
    local entity

    if state.type == "vehicle" then
        local ship_def
        if state.render_type == "procedural" and state.render_seed then
            local ProceduralShip = require "src.utils.procedural_ship"
            ship_def = ProceduralShip.generate(state.render_seed)
        else
            ship_def = "starter_drone"
        end

        entity = ShipSystem.spawn(self.world, ship_def, state.x, state.y, is_me)
        if entity then
            if entity.transform then entity.transform.r = state.r end
            if entity.physics and entity.physics.body then entity.physics.body:setAngle(state.r) end

            if is_me then
                linkPlayerToShip(self.player, entity)
                self.world.local_ship = entity
                if entity.render then entity.render.color = { 0.2, 1, 0.2 } end
            end
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

        if self.world.physics_world then
            local body = love.physics.newBody(self.world.physics_world, state.x, state.y, "dynamic")
            body:setLinearDamping(Config.LINEAR_DAMPING * 2)
            body:setAngularDamping(Config.LINEAR_DAMPING * 2)
            body:setAngle(state.r or 0)

            local shape
            if vertices and #vertices >= 6 then
                local verts = (#vertices > 16) and {table.unpack(vertices, 1, 16)} or vertices
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
                local verts = (#vertices > 16) and {table.unpack(vertices, 1, 16)} or vertices
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
        if is_my_projectile then return end

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
        syncEntityStats(entity, state)
    end
end

local function removeNetworkEntity(self, net_id)
    local entity = self.world.networked_entities[net_id]
    if entity then
        EntityUtils.cleanup_physics_entity(entity)
        self.world.networked_entities[net_id] = nil
        self.world.interpolation_buffers[net_id] = nil
    end
end

local function processRemovals(self, explicit_removals, received_ids)
    if explicit_removals then
        for _, net_id in ipairs(explicit_removals) do
            if net_id ~= self.my_entity_id then
                removeNetworkEntity(self, net_id)
            end
        end
    else
        local to_remove = {}
        for net_id, _ in pairs(self.world.networked_entities) do
            if not received_ids[net_id] and net_id ~= self.my_entity_id then
                table.insert(to_remove, net_id)
            end
        end
        for _, net_id in ipairs(to_remove) do
            removeNetworkEntity(self, net_id)
        end
    end
end

local function assignPlayerName(self, entity, entity_id)
    local owner_id
    for pid, eid in pairs(self.player_entity_ids) do
        if eid == entity_id then owner_id = pid; break end
    end

    if owner_id then
        self.player_display_names = self.player_display_names or {}
        local display = self.player_display_names[owner_id]

        local label
        if type(display) == "string" and display ~= "" then
            label = display
        else
            -- Fallbacks: local player uses their Config.PLAYER_NAME, others get a generic label
            if Client.player_id and owner_id == Client.player_id then
                label = Config.PLAYER_NAME or "Player"
            else
                label = "Player " .. owner_id
            end
        end

        if entity.name then
            entity.name.value = label
        else
            entity:give("name", label)
        end
    end
end

local function syncNetworkEntity(self, state, server_time)
    local entity = self.world.networked_entities[state.id]
    local is_my_ship = (self.my_entity_id and state.id == self.my_entity_id)

    if entity then
        if is_my_ship then
            reconcileLocalPlayer(self, entity, state)
        else
            interpolateRemoteEntity(self, entity, state, server_time)
        end
        syncEntityStats(entity, state)
    else
        spawnNetworkEntity(self, state, is_my_ship)
    end

    entity = self.world.networked_entities[state.id]
    if entity and entity.vehicle and not entity.ai then
        if state.player_name and state.player_name ~= "" then
            if entity.name then
                entity.name.value = state.player_name
            else
                entity:give("name", state.player_name)
            end
        elseif not entity.name then
            assignPlayerName(self, entity, state.id)
        end
    end
end

function PlayNetwork.initNetwork(self, is_joining, join_host)
    Chat.init()
    Chat.enable()

    Chat.setSendHandler(function(message)
        if Client.connected then
            Client.sendChatMessage(message)
        elseif self.world.hosting and self.world.server then
            local Server = self.world.server
            Chat.addMessage("You: " .. message, "text")
            local packet = Protocol.createChatBroadcastPacket(0, message)
            Server.broadcast(packet)
        else
            Chat.addMessage("You: " .. message, "text")
        end
    end)

    Client.setChatCallback(function(player_id, message)
        local sender = (Client.player_id and player_id == Client.player_id) and "You" or ("Player " .. player_id)
        Chat.addMessage(sender .. ": " .. message, "text")
    end)

    -- Ensure the low-level client knows our display name
    Client.display_name = Config.PLAYER_NAME or "Player"

    Client.setWorldStateCallback(function(packet) PlayNetwork.handleWorldState(self, packet) end)
    Client.setPlayerJoinedCallback(function(...) PlayNetwork.handlePlayerJoined(self, ...) end)
    Client.setPlayerLeftCallback(function(...) PlayNetwork.handlePlayerLeft(self, ...) end)
    Client.setWelcomeCallback(function(...) PlayNetwork.handleWelcome(self, ...) end)
    Client.setPlayerInfoCallback(function(...) PlayNetwork.handlePlayerInfo(self, ...) end)

    if is_joining then
        Client.server_address = join_host
        Client.connect()
    else
        Client.server_address = "localhost"
    end
end

function PlayNetwork.handleWorldState(self, packet)
    if self.world.hosting then return end

    syncServerTime(self, packet.server_time)

    local received_ids = {}

    for _, state in ipairs(packet.entities) do
        received_ids[state.id] = true
        syncNetworkEntity(self, state, packet.server_time)
    end

    processRemovals(self, packet.removed_ids, received_ids)
end

function PlayNetwork.handlePlayerJoined(self, player_id, entity_id, player_count)
    local name = (Client.player_id and player_id == Client.player_id) and "You" or ("Player " .. player_id)
    Chat.system(string.format("%s joined the game.%s", name, (player_count and " Players online: " .. player_count) or ""))

    if entity_id and self.world.local_ship and entity_id ~= 0 then
        if not self.world.local_ship.network_id then
            self.world.local_ship.network_id = entity_id
            self.world.networked_entities[entity_id] = self.world.local_ship
        end
        self.player_entity_ids[player_id] = entity_id
    end
end

function PlayNetwork.handlePlayerLeft(self, player_id, player_count)
    local name = (Client.player_id and player_id == Client.player_id) and "You" or ("Player " .. player_id)
    Chat.system(string.format("%s left the game.%s", name, (player_count and " Players online: " .. player_count) or ""))

    local entity_id = self.player_entity_ids[player_id]
    if entity_id then
        self.player_entity_ids[player_id] = nil
        local entity = self.world.networked_entities[entity_id]
        if entity and entity ~= self.world.local_ship then
            removeNetworkEntity(self, entity_id)
        end
    end
end

function PlayNetwork.handleWelcome(self, player_id, entity_id)
    self.my_entity_id = entity_id
    if player_id and entity_id and entity_id ~= 0 then
        self.player_entity_ids[player_id] = entity_id
    end
end

function PlayNetwork.updateNetwork(self, dt)
    if self.world.hosting then
        local Server = require "src.network.server"
        Server.update(dt)
    end
    Client.update(dt)
end

function PlayNetwork.updateInterpolation(self, dt)
    local delay = Interpolation.getBaseDelay()
    if Client.connected and Client.ping and Client.ping > 0 then
        local dynamic = (Client.ping / 1000) * 0.5
        delay = math.max(delay, math.min(dynamic, 0.35))
    end

    for id, buffer in pairs(self.world.interpolation_buffers) do
        local entity = self.world.networked_entities[id]
        if entity then
            local effective_delay = delay + ((entity.vehicle and id ~= self.my_entity_id) and 0.03 or 0)
            local state = Interpolation.getInterpolatedState(buffer, effective_delay)

            if state then
                if entity.transform then
                    entity.transform.x, entity.transform.y, entity.transform.r = state.x, state.y, state.r
                end
                if entity.physics and entity.physics.body and not entity.physics.body:isDestroyed() then
                    entity.physics.body:setPosition(state.x, state.y)
                    entity.physics.body:setAngle(state.r)
                    if state.vx and state.vy then entity.physics.body:setLinearVelocity(state.vx, state.vy) end
                    if state.angular_velocity then entity.physics.body:setAngularVelocity(state.angular_velocity) end
                end
            end
        elseif Interpolation.isStale(buffer) then
            self.world.interpolation_buffers[id] = nil
        end
    end
end

function PlayNetwork.sendClientInput(self)
    if not self.world.hosting and Client.connected and self.world.local_ship and self.world.local_ship.input then
        local input = self.world.local_ship.input
        local t = self.world.local_ship.transform
        Client.sendInput(
            input.move_x or 0, input.move_y or 0, input.fire or false, input.target_angle or 0,
            t.x, t.y, t.r
        )
    end
end

function PlayNetwork.startHosting(self)
    local Server = require "src.network.server"
    if Server.start(25565, self.world) then
        self.world.hosting = true
        self.world.server = Server

        Server.setChatCallback(function(pid, msg)
            local sender = (pid == 0) and "Host" or ("Player " .. pid)
            Chat.addMessage(sender .. ": " .. msg, "text")
        end)

        if self.world.local_ship then
            self.world.local_ship.network_id = Server.next_network_id
            Server.next_network_id = Server.next_network_id + 1
        end

        for _, e in ipairs(self.world:getEntities()) do
            if (e.asteroid or e.asteroid_chunk or e.projectile or e.vehicle or e.item) and not e.network_id then
                e.network_id = Server.next_network_id
                Server.next_network_id = Server.next_network_id + 1
            end
        end
    end
end

return PlayNetwork
