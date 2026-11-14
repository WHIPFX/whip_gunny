-- whip_gunny — WEAPON PACKS: weapons and magazines from another resource
--
-- A pack is a resource of its own. It streams its weapons (their metas and models, in its own fxmanifest), ships
-- their icons (html/img/items/<item>.webp, in its `files`), and tells gunny about each item on both sides, in the
-- shape items/weapons.lua and items/magazines.lua use, magazines first:
--
--     shared_script '@whip_gunny/lib/pack.lua'
--     shared_script 'gunny.lua'   -- Gunny.register(function() exports.whip_gunny:RegisterMagazine(...) ... end)
--
-- Gunny.register runs it whenever gunny is up, and again each time gunny starts. A weapon may bring its attachment
-- components as `attachments` (items/attachments.lua's Config.WeaponAttachments shape). When the pack stops, its
-- items leave gunny's tables; players keep them, and they work again when it is back.

GunnyPacks = { owner = {} }   -- owner[item] = the pack resource that registered it

local listeners = {}

--- fn(itemName, kind, gone) after a pack's item arrives or changes, or goes (gone = true): kind 'weapon' or 'magazine'.
function GunnyPacks.onChange(fn)
    listeners[#listeners + 1] = fn
end

local function changed(itemName, kind, gone)
    for _, fn in ipairs(listeners) do
        local ok, err = pcall(fn, itemName, kind, gone)
        if not ok then Whip.startProblem('taking in pack item %s errored: %s', itemName, tostring(err)) end
    end
end

--- May `owner` register `itemName` as `kind`? Not one of gunny's own, another running pack's, or another kind's.
local function claim(itemName, owner, kind)
    if type(itemName) ~= 'string' or #itemName > 50 or not itemName:match('^[%w_%-]+$') then
        return false, 'an item name is letters, digits, _ and -, 50 at most'
    end
    local holder = GunnyPacks.owner[itemName]
    if holder and holder ~= owner then return false, ('%s belongs to %s'):format(itemName, holder) end
    local other = kind == 'weapon' and Config.Magazines or Config.Weapons
    local own = kind == 'weapon' and Config.Weapons or Config.Magazines
    if other[itemName] or Config.Attachments[itemName] then return false, ('%s is already another kind of item'):format(itemName) end
    for _, caliber in pairs(Config.Calibers) do
        if caliber.ammoItem == itemName then return false, ('%s is one of whip_gunny\'s rounds'):format(itemName) end
    end
    if own[itemName] and not holder then return false, ('%s is one of whip_gunny\'s own'):format(itemName) end
    return true
end

--- Why a weapon's attachment components cannot be used, or nil: { [category] = { [tier] = component hash } }.
local function attachmentsProblem(att)
    if type(att) ~= 'table' then return 'attachments is { [category] = { [tier] = component } }' end
    for category, kinds in pairs(att) do
        if not Config.AttachmentCategories[category] then return ('attachments: %s is not a slot in items/attachments.lua'):format(tostring(category)) end
        if type(kinds) ~= 'table' then return ('attachments.%s is { [tier] = component }'):format(category) end
        for tier, component in pairs(kinds) do
            if type(component) ~= 'number' then return ('attachments.%s.%s is a component hash'):format(category, tostring(tier)) end
        end
    end
    return nil
end

--- A kind (tier) no attachment item has can never be fitted: said, as it is most likely a typing slip. The weapon
--- still registers.
local function warnUnknownTiers(itemName, att, owner)
    for category, kinds in pairs(att) do
        for tier in pairs(kinds) do
            local known = false
            for _, a in pairs(Config.Attachments) do
                if a.category == category and a.tier == tier then known = true break end
            end
            if not known then
                Whip.startProblem('%s\'s weapon %s: no attachment in items/attachments.lua is a %s %s, so that one never fits',
                    owner, itemName, tostring(tier), category)
            end
        end
    end
end

--- A pack's item out of gunny's tables: its pack stopped, or whip_core refused it.
local function forget(itemName)
    local kind = Config.Weapons[itemName] and 'weapon' or 'magazine'
    Config.Weapons[itemName] = nil
    Config.Magazines[itemName] = nil
    Config.WeaponAttachments[itemName] = nil
    GunnyPacks.owner[itemName] = nil
    Config.NoteItemDefaults(itemName)
    changed(itemName, kind, true)
end

local refusals = {}   -- [item] = why whip_core refused it, for the export's answer

--- whip_core refused a pack's item (server/items.lua): most likely its name is another resource's item. Left out of
--- gunny's tables, so nothing draws or loads it, and said. A refused magazine comes off the pack's guns too, and a gun
--- left with none is left out as well: a gun's magazine list names items gunny takes into it.
---@param itemName string
---@param why string|nil
function GunnyPacks.refused(itemName, why)
    local owner = GunnyPacks.owner[itemName]
    if not owner then return end
    refusals[itemName] = tostring(why or 'refused')
    Whip.startProblem('%s\'s item %s left out: whip_core refused it (%s)', owner, itemName, refusals[itemName])
    local wasMagazine = Config.Magazines[itemName] ~= nil
    forget(itemName)
    if not wasMagazine then return end
    for name, w in pairs(Config.Weapons) do
        local mags = GunnyPacks.owner[name] and w.compatibleMags
        if type(mags) == 'table' then
            for i = #mags, 1, -1 do
                if mags[i] == itemName then table.remove(mags, i) end
            end
            if #mags == 0 and not w.magless then
                GunnyPacks.refused(name, ('its magazine %s was refused'):format(itemName))
            end
        end
    end
end

--- The export's answer once the item has been taken in: whip_core may have refused it meanwhile.
local function answer(itemName)
    local why = refusals[itemName]
    if why then return false, ('%s: whip_core refused it (%s)'):format(itemName, why) end
    return true
end

--- The pack calling, or nil and why.
local function packCaller(what)
    local owner = GetInvokingResource()
    if not owner or owner == GetCurrentResourceName() then
        return nil, what .. ' is for other resources: whip_gunny\'s own items are in items/'
    end
    return owner
end

--- A pack's magazine. Answers true, or false and why.
exports('RegisterMagazine', function(itemName, def)
    local owner, why = packCaller('RegisterMagazine')
    if not owner then return false, why end
    local ok
    ok, why = claim(itemName, owner, 'magazine')
    if not ok then return false, why end
    why = Config.MagazineProblem(def)
    if why then return false, ('magazine %s: %s'):format(itemName, why) end
    Config.Magazines[itemName] = def
    GunnyPacks.owner[itemName] = owner
    refusals[itemName] = nil
    Config.NoteItemDefaults(itemName)
    changed(itemName, 'magazine')
    return answer(itemName)
end)

--- A pack's weapon. Its magazines (compatibleMags) must be registered first. Answers true, or false and why.
exports('RegisterWeapon', function(itemName, def)
    local owner, why = packCaller('RegisterWeapon')
    if not owner then return false, why end
    local ok
    ok, why = claim(itemName, owner, 'weapon')
    if not ok then return false, why end
    why = Config.WeaponProblem(def)
    if why then return false, ('weapon %s: %s'):format(itemName, why) end
    local attachments = def and def.attachments
    if attachments ~= nil then
        why = attachmentsProblem(attachments)
        if why then return false, ('weapon %s: %s'):format(itemName, why) end
        warnUnknownTiers(itemName, attachments, owner)
        def.attachments = nil
    end
    Config.Weapons[itemName] = def
    Config.WeaponAttachments[itemName] = attachments
    GunnyPacks.owner[itemName] = owner
    refusals[itemName] = nil
    Config.NoteItemDefaults(itemName)
    changed(itemName, 'weapon')
    return answer(itemName)
end)

-- A pack stopping: its items leave the tables.
AddEventHandler('onResourceStop', function(res)
    local gone = {}
    for itemName, owner in pairs(GunnyPacks.owner) do
        if owner == res then gone[#gone + 1] = itemName end
    end
    for _, itemName in ipairs(gone) do forget(itemName) end
end)

-- Packs register once every file of gunny has loaded, and again each time it starts: lib/pack.lua hears this.
CreateThread(function() TriggerEvent('whip_gunny:packs:ready', {}) end)
