function love.conf(t)
    local is_server = false
    for _, v in ipairs(arg) do
        if v == "--server" then
            is_server = true
            break
        end
    end

    if is_server then
        t.modules.window = false
        t.modules.graphics = false
        t.modules.audio = false
        t.modules.joystick = false
        t.modules.touch = false
        t.modules.video = false
    else
        t.window.title = "Novus"
        t.window.width = 1600
        t.window.height = 900
        t.window.fullscreen = false
        t.window.resizable = true
        t.window.vsync = true -- Cap at monitor refresh rate (usually 60Hz)
        t.window.msaa = 2
    end

    t.console = true
end
