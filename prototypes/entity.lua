-- Production building modifications
-- This file updates existing building prototypes during data-updates stage
-- Adds quality effects to various entities.

---Adds quality effect to a protoype with effect_receiver
---@param prototype data.MiningDrillPrototype | data.CraftingMachinePrototype The prototype to modify
---@param quality number The quality value to set.
local function add_quality_to_prototype(prototype, quality)
    -- Initialize effects list if it doesn't exist
    prototype.effect_receiver = prototype.effect_receiver or {}
    prototype.effect_receiver.base_effect = prototype.effect_receiver.base_effect or {}

    -- Add quality to effects
    prototype.effect_receiver.base_effect.quality = quality
end

-- Add quality to mining drills
for _, prototype in pairs(data.raw["mining-drill"]) do
    add_quality_to_prototype(prototype, 1)
end

-- Add quality to furnaces
for _, prototype in pairs(data.raw["furnace"]) do
    add_quality_to_prototype(prototype, 2/3)
end

-- Add quality to assembling machines
for _, prototype in pairs(data.raw["assembling-machine"]) do
    add_quality_to_prototype(prototype, 0.5)
end

log("[AQ] Added quality effects to mining drills")

