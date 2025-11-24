local socket = require "socket"

local Server = {
    host = "*",
    port = 12345,
    clients = {}
}

function Server.start()
    local server, err = socket.bind(Server.host, Server.port)
    if not server then
        print("Failed to bind to " .. Server.host .. ":" .. Server.port .. ": " .. err)
        return
    end

    local ip, port = server:getsockname()
    print("Server started on " .. ip .. ":" .. port)

    Server.socket = server
    Server.socket:settimeout(0) -- Non-blocking

    Server.running = true

    while Server.running do
        Server.update()
        socket.sleep(0.01)
    end
end

function Server.update()
    -- Accept new connections
    local client, err = Server.socket:accept()
    if client then
        client:settimeout(0)
        local ip, port = client:getpeername()
        print("New connection from " .. ip .. ":" .. port)
        table.insert(Server.clients, client)
        Server.broadcast("System: New user joined from " .. ip)
    end

    -- Receive messages from clients
    local toRemove = {}
    for i, client in ipairs(Server.clients) do
        local line, err = client:receive()
        if not err then
            if line then
                print("Received: " .. line)
                Server.broadcast(line)
            end
        elseif err == "closed" then
            print("Client disconnected")
            table.insert(toRemove, i)
        end
    end

    -- Remove disconnected clients
    for i = #toRemove, 1, -1 do
        table.remove(Server.clients, toRemove[i])
    end
end

function Server.broadcast(message)
    for _, client in ipairs(Server.clients) do
        client:send(message .. "\n")
    end
end

return Server
