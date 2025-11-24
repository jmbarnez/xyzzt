-- main.lua
-- This sets up the path so you can require 'hump.gamestate' or 'game' easily
local function extend_paths()
    local folder = love.filesystem.getSource()
    local additions = {
        "src/?.lua",
        "src/?/init.lua",
        "lib/?.lua",
        "lib/?/init.lua",
        "lib/?/?.lua"
    }

    local final_path = package.path
    for _, add in ipairs(additions) do
        final_path = final_path .. ";" .. folder .. "/" .. add
    end
    package.path = final_path
end

extend_paths()

function love.load()
    -- Check for server mode
    local args = love.arg.parseGameArguments(arg)
    for i, v in ipairs(arg) do
        if v == "--server" then
            require("src.network.server").start()
            return -- Stop normal game load
        end
    end

    -- Load the actual game logic
    require("game")
    -- Forward the love.load call to the game state
    if love.load then love.load() end
end
