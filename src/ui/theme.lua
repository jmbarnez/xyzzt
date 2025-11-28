local Theme = {}

-- Core palette for the custom UI / HUD library.
Theme.colors = {
    -- Deep space blue with subtle teal tint
    background = { 0.02, 0.02, 0.02, 1.0 },

    -- Primary readable text (slightly bluish white)
    textPrimary = { 0.90, 0.90, 0.90, 1.0 },

    -- Muted / secondary text
    textMuted = { 0.60, 0.60, 0.60, 1.0 },

    -- Generic button styling
    button = {
        -- Subtle glassy fills
        fill        = { 0.08, 0.08, 0.08, 0.80 },
        fillHover   = { 0.16, 0.16, 0.16, 0.90 },
        fillActive  = { 0.24, 0.24, 0.24, 1.00 },

        -- Neon-ish outlines (cyan / teal)
        outline        = { 0.60, 0.60, 0.60, 0.85 },
        outlineHover   = { 0.80, 0.80, 0.80, 1.00 },
        outlineActive  = { 1.00, 1.00, 1.00, 1.00 },
    },

    -- Cargo UI styling
    cargo = {
        -- Bar background: darker, slightly purple
        barBackground   = { 0.03, 0.03, 0.03, 0.96 },

        -- Normal fill: bright cyan / teal
        barFill         = { 0.85, 0.85, 0.85, 0.98 },

        -- Warning: amber
        barFillWarning  = { 0.60, 0.60, 0.60, 0.98 },

        -- Critical: saturated red
        barFillCritical = { 0.35, 0.35, 0.35, 0.98 },

        -- Outline: cool steel blue
        barOutline      = { 0.55, 0.55, 0.55, 0.94 },

        -- Slot visuals: faint glowing panels
        slotBackground  = { 0.05, 0.05, 0.05, 0.70 },
        slotOutline     = { 0.45, 0.45, 0.45, 0.90 },

        -- Numbers for stack counts
        textCount       = { 0.90, 0.90, 0.90, 1.0 },

        -- Item names
        textName        = { 0.80, 0.80, 0.80, 1.0 },
    },

    -- HUD / health bar styling
    health = {
        shieldFill   = { 0.20, 0.95, 1.00, 0.95 },
        shieldBg     = { 0.04, 0.08, 0.14, 0.90 },
        hullFill     = { 0.95, 0.25, 0.25, 0.95 },
        hullBg       = { 0.08, 0.05, 0.07, 0.90 },
        hpFill       = { 0.95, 0.25, 0.25, 0.95 },
        hpBg         = { 0.08, 0.05, 0.07, 0.90 },
        energyFill   = { 1.00, 0.90, 0.30, 0.95 },
        energyBg     = { 0.10, 0.08, 0.02, 0.90 },
        ringBg       = { 0.06, 0.08, 0.16, 1.00 },
        xpFill       = { 0.25, 0.95, 0.55, 1.00 },
        border       = { 0.00, 0.00, 0.00, 0.85 },
    },

    -- Window chrome styling
    window = {
        titleBar    = { 0.06, 0.08, 0.16, 1.00 },
        bottomBar   = { 0.06, 0.08, 0.16, 1.00 },
        closeBg     = { 0.16, 0.18, 0.24, 1.00 },
        closeAccent = { 1.00, 0.35, 0.35, 1.00 },
    },

    -- Chat window colors
    chat = {
        background      = { 0.00, 0.00, 0.00, 0.50 },
        inputBackground = { 0.10, 0.10, 0.10, 0.90 },
        text            = { 1.00, 1.00, 1.00, 1.00 },
        system          = { 1.00, 1.00, 0.00, 1.00 },
        error           = { 1.00, 0.20, 0.20, 1.00 },
        debug           = { 0.70, 0.70, 0.70, 1.00 },
    },

    -- Full-screen overlay tinting (pause, death, etc.)
    overlay = {
        screenDim = { 0.00, 0.00, 0.00, 0.70 },
    },

    -- Misc HUD accents
    accents = {
        hudInfo = { 0.70, 0.90, 1.00, 0.90 },
        hudFps  = { 0.20, 1.00, 0.20, 1.00 },
    },
}

-- Shape and spacing tokens used by controls.
Theme.shapes = {
    -- Slight rounding for a sleeker sci‑fi look
    buttonRounding = 3,
    outlineWidth = 1.2,

    -- Generic panel/window rounding
    panelCornerRadius = 4,
    targetPanelCornerRadius = 6,
    slotCornerRadius = 2,
    closeButtonCornerRadius = 3,
    healthBarCornerRadius = 3,

    -- Shared shadow offsets for HUD panels
    shadowOffsetX = 3,
    shadowOffsetY = 4,
}

Theme.spacing = {
    buttonWidth = 220,
    buttonHeight = 42,
    buttonSpacing = 20,
    menuVerticalOffset = 70,

    -- HUD status panel
    hudMargin = 16,
    panelContentPadding = 10,
    statusPanelWidth = 300,
    statusPanelHeight = 80,
    hudLevelRadius = 18,
    hudBarHeight = 12,
    hudBarGap = 7,

    -- Target panel
    targetPanelWidth = 260,
    targetPanelHeight = 64,
    targetPanelOffsetY = 16,
    targetPanelContentPadding = 10,
    targetPanelBarHeight = 12,
    targetPanelBarGap = 4,

    -- Cargo window
    cargoWindowWidth = 720,
    cargoWindowHeight = 420,
    cargoSlotSize = 64,
    cargoSlotGap = 8,
    cargoCapacityBarWidth = 150,
    cargoCapacityBarHeight = 14,

    -- Chat layout
    chatMarginX = 20,
    chatWidth = 600,
    chatHeight = 300,
    chatInputHeight = 30,
}

-- Typeface configuration
Theme.fonts = {
    -- Big, bold title for splash / logo screens
    title   = { path = "assets/fonts/Orbitron-Regular.ttf", size = 128 },

    -- Primary button labels
    button  = { path = "assets/fonts/Orbitron-Regular.ttf", size = 20 },

    -- Chat / small HUD text
    chat    = { path = "assets/fonts/Orbitron-Regular.ttf", size = 14 },

    -- Section headers in HUD / windows
    header  = { path = "assets/fonts/Orbitron-Regular.ttf", size = 18 },

    -- Default fallback
    default = { path = "assets/fonts/Orbitron-Regular.ttf", size = 13 },
}

local fontCache = {}

local function loadFont(def)
    if def == nil then
        return love.graphics.newFont(14)
    end

    local info = love.filesystem.getInfo(def.path)
    if info then
        return love.graphics.newFont(def.path, def.size)
    end

    return love.graphics.newFont(def.size)
end

---Retrieves and caches a named font defined in Theme.fonts.
---@param key string
---@return love.Font
function Theme.getFont(key)
    if not fontCache[key] then
        fontCache[key] = loadFont(Theme.fonts[key])
    end
    return fontCache[key]
end

---Returns the fill/outline colors for a button state.
---@param state 'default'|'hover'|'active'
---@return table fill
---@return table outline
function Theme.getButtonColors(state)
    local palette = Theme.colors.button
    if state == "active" then
        return palette.fillActive, palette.outlineActive
    elseif state == "hover" then
        return palette.fillHover, palette.outlineHover
    end
    return palette.fill, palette.outline
end

---Returns the primary text color adjusted for button state if desired.
---@param state 'default'|'hover'|'active'
---@return table
function Theme.getButtonTextColor(state)
    -- Could later dim text when disabled / inactive.
    return Theme.colors.textPrimary
end

function Theme.getBackgroundColor()
    return Theme.colors.background
end

return Theme
