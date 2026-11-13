-- whip_gunny's helper for a weapon pack: `shared_script '@whip_gunny/lib/pack.lua'` in the pack's fxmanifest.
--
-- Gunny.register(fn): fn runs once whip_gunny is up, and again every time it starts (it forgets packs when it stops).
-- Put the pack's RegisterMagazine and RegisterWeapon calls in it, in a file both sides load. See whip's docs, whip_gunny
-- → Weapon System → Weapon packs.

Gunny = Gunny or {}

local fns = {}

local function run(fn)
    local ok, err = pcall(fn)
    if not ok then print(('[%s] Gunny.register errored: %s'):format(GetCurrentResourceName(), tostring(err))) end
end

---@param fn function
function Gunny.register(fn)
    fns[#fns + 1] = fn
    if GetResourceState('whip_gunny') == 'started' then run(fn) end
end

AddEventHandler('whip_gunny:packs:ready', function()
    for _, fn in ipairs(fns) do run(fn) end
end)
