-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- ===== LIGHT RANDOMIZATION MODULE =====
-- Handles all light randomization functionality including color/brightness variations

local M = {}

-- ===== RANDOMIZATION CONFIGURATION =====

-- Randomization configuration
local lightRandomization = {
    enabled = true,
    
    -- Brightness randomization
    brightnessVariation = 0.25,  -- ±25% variation in brightness
    brightnessGain = 1.0,        -- Overall brightness multiplier
    
    -- Color randomization (warm yellowish bias)
    colorVariation = 0.15,       -- ±15% variation per color channel
    colorGain = 1.0,             -- Overall color intensity multiplier
    
    -- Warm color bias (pushes lights toward warm yellow)
    warmBias = {
        red = 1.02,      -- Slightly boost red (1.02 = +2%)
        green = 0.98,    -- Slightly reduce green (0.98 = -2%)
        blue = 0.85      -- Reduce blue more for warmth (0.85 = -15%)
    }
}

-- ===== COLOR PARSING FUNCTIONS =====

local function parseColorString(colorStr)
    -- Parse color string "r g b a" into individual components
    local r, g, b, a = colorStr:match("([%d%.%-]+)%s+([%d%.%-]+)%s+([%d%.%-]+)%s+([%d%.%-]+)")
    return {
        r = tonumber(r) or 1.0,
        g = tonumber(g) or 1.0, 
        b = tonumber(b) or 1.0,
        a = tonumber(a) or 1.0
    }
end

local function formatColorString(color)
    -- Format color components back into "r g b a" string
    return string.format("%.6f %.6f %.6f %.6f", color.r, color.g, color.b, color.a)
end

-- ===== RANDOMIZATION FUNCTIONS =====

local function randomizeColorComponent(baseValue, variation, bias, gain)
    -- Apply random variation
    local randomFactor = 1.0 + (math.random() * 2.0 - 1.0) * variation
    
    -- Apply bias and gain
    local result = baseValue * randomFactor * bias * gain
    
    -- Clamp to valid range [0, 1]
    return math.max(0.0, math.min(1.0, result))
end

local function randomizeLightProperties(templateBrightness, templateColor, index)
    if not lightRandomization.enabled then
        return templateBrightness, templateColor
    end
    
    -- Use index as seed for consistent randomization per light
    math.randomseed(os.time() + index * 137) -- 137 is just a prime number for good distribution
    
    -- Parse template values
    local baseBrightness = tonumber(templateBrightness) or 1.0
    local baseColor = parseColorString(templateColor)
    
    -- Randomize brightness
    local brightnessFactor = 1.0 + (math.random() * 2.0 - 1.0) * lightRandomization.brightnessVariation
    local newBrightness = baseBrightness * brightnessFactor * lightRandomization.brightnessGain
    newBrightness = math.max(0.0, math.min(10.0, newBrightness)) -- Clamp brightness to reasonable range
    
    -- Randomize color with warm bias
    local newColor = {
        r = randomizeColorComponent(baseColor.r, lightRandomization.colorVariation, 
                                  lightRandomization.warmBias.red, lightRandomization.colorGain),
        g = randomizeColorComponent(baseColor.g, lightRandomization.colorVariation, 
                                  lightRandomization.warmBias.green, lightRandomization.colorGain),
        b = randomizeColorComponent(baseColor.b, lightRandomization.colorVariation, 
                                  lightRandomization.warmBias.blue, lightRandomization.colorGain),
        a = baseColor.a -- Keep alpha unchanged
    }
    
    -- Reset random seed to avoid affecting other random operations
    math.randomseed(os.time())
    
    return tostring(newBrightness), formatColorString(newColor)
end

-- ===== CONFIGURATION FUNCTIONS =====

-- Function to adjust randomization parameters on the fly
local function setLightRandomization(config)
    if config.enabled ~= nil then lightRandomization.enabled = config.enabled end
    if config.brightnessVariation then lightRandomization.brightnessVariation = config.brightnessVariation end
    if config.brightnessGain then lightRandomization.brightnessGain = config.brightnessGain end
    if config.colorVariation then lightRandomization.colorVariation = config.colorVariation end
    if config.colorGain then lightRandomization.colorGain = config.colorGain end
    if config.warmBias then
        if config.warmBias.red then lightRandomization.warmBias.red = config.warmBias.red end
        if config.warmBias.green then lightRandomization.warmBias.green = config.warmBias.green end
        if config.warmBias.blue then lightRandomization.warmBias.blue = config.warmBias.blue end
    end
    log("I", "alexkidd_light_randomization", "Light randomization updated: " .. dumps(lightRandomization))
end

-- Function to get current randomization settings
local function getLightRandomization()
    return lightRandomization
end

-- Convenience functions for quick adjustments
local function setWarmth(warmthLevel)
    -- warmthLevel: 0.0 = neutral, 1.0 = very warm
    warmthLevel = math.max(0.0, math.min(1.0, warmthLevel))
    lightRandomization.warmBias.red = 1.0 + warmthLevel * 0.1
    lightRandomization.warmBias.green = 1.0 - warmthLevel * 0.05
    lightRandomization.warmBias.blue = 1.0 - warmthLevel * 0.3
    log("I", "alexkidd_light_randomization", "Light warmth set to: " .. warmthLevel)
end

local function setVariation(variation)
    -- variation: 0.0 = no variation, 1.0 = maximum variation
    variation = math.max(0.0, math.min(1.0, variation))
    lightRandomization.brightnessVariation = variation * 0.3  -- Up to 30% brightness variation
    lightRandomization.colorVariation = variation * 0.15      -- Up to 15% color variation
    log("I", "alexkidd_light_randomization", "Light variation set to: " .. variation)
end

-- ===== MODULE EXPORTS =====

M.randomizeLightProperties = randomizeLightProperties
M.setLightRandomization = setLightRandomization
M.getLightRandomization = getLightRandomization
M.setWarmth = setWarmth
M.setVariation = setVariation

-- Export internal functions for advanced usage
M.parseColorString = parseColorString
M.formatColorString = formatColorString
M.randomizeColorComponent = randomizeColorComponent

return M