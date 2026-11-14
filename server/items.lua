-- whip_gunny — THE ITEMS, REGISTERED WITH WHIP_CORE
--
-- Every weapon, magazine, round and attachment in items/*.lua becomes a whip_core item: its name, weight, card, menu
-- and settings, and the metadata a new one starts with. Through Whip.register, so all of it is declared once whip_core
-- is ready (it keeps items in memory). A whip_core restart stops gunny first and starts it again (its dependency).

-- Where gunny's options sit on an item's right-click menu (above whip's Give, Place and Split, lowest first).
local MENU_ORDER = { equip = 1, load = 2, unload = 3, open = 4 }

-- On the ground, a weapon's prompt offers Equip after Pick up: picked up as Pick up does, then drawn from the slot
-- it landed in.
local GROUND_EQUIP = { { action = 'whip_gunny:equip_weapon', label = 'Equip', icon = 'target' } }

-- A gun's or a magazine's card: its serial, its ammo type, then `more`. The ammo type is the model's, the same for
-- every copy, so it is a fixed `value` rather than metadata stamped on each.
local function cardRows(caliber, more)
    local rows = { { key = 'serial', label = 'Serial' } }
    if caliber and caliber ~= '' then rows[#rows + 1] = { key = 'caliber', label = 'Ammo Type', value = caliber } end
    for _, row in ipairs(more or {}) do rows[#rows + 1] = row end
    return rows
end

-- A gun's settings on whip's Items page (shared/catalog.lua writes the values into its table): its reload time, and
-- the rounds a gun with no magazine holds.
local function gunSettings(itemName)
    local list = {}
    local reload = Config.ItemSettingDefault(itemName, 'reloadTime')
    if reload then
        list[#list + 1] = { key = 'reloadTime', type = 'int', min = 100, max = 10000, step = 50, unit = 'ms', default = reload,
            label = 'Reload time',
            help = 'How long a reload takes, and the least one takes from a seat, where the game may play no animation.' }
    end
    local internal = Config.ItemSettingDefault(itemName, 'internalCapacity')
    if internal then
        -- At most 250, or the gun's own size where that is more (the minigun's 9999): whip refuses an item whose
        -- default is past its setting's limit.
        list[#list + 1] = { key = 'internalCapacity', type = 'int', min = 1, max = math.max(250, internal), default = internal,
            label = 'Rounds it holds',
            help = 'How many rounds it takes, loaded straight in (it has no magazine). Lowered, a gun holding more gives the extra rounds back to the pockets the next time it is drawn, but never goes below its standard size.' }
    end
    return list[1] and list or nil
end

--- A weapon pack's item (shared/packs.lua): its icon in the pack, html/img/items/<item>.webp or .png, as whip_core's
--- '@pack/path'. nil for gunny's own (whip_core finds those in gunny's folder) or a pack's with none.
---@param itemName string
---@return string|nil
local function packImage(itemName)
    local pack = GunnyPacks.owner[itemName]
    if not pack then return nil end
    for _, ext in ipairs({ 'webp', 'png' }) do
        local path = ('html/img/items/%s.%s'):format(itemName, ext)
        if LoadResourceFile(pack, path) then return ('@%s/%s'):format(pack, path) end
    end
    return nil
end

--- A weapon's item, and the metadata a new one starts with (nil: none, so stacks of it merge).
---@param itemName string
---@param w table  its Config.Weapons entry
---@return table def
---@return function|nil newMeta
local function weaponDef(itemName, w)
    local def = {
        name     = w.label or itemName,
        desc     = w.description or w.label or itemName,
        type     = 'weapon',
        stack    = false,
        maxStack = 1,
        usable   = false,
        prop     = w.prop,
        image    = packImage(itemName),
        defaultAction  = 'whip_gunny:equip_weapon',
        contextOptions = { { action = 'whip_gunny:equip_weapon', label = 'Equip', order = MENU_ORDER.equip } },
        groundOptions  = GROUND_EQUIP,
    }
    if Config.IsFuelCan(w) then
        -- The jerry can: its fuel on the card. `fuelCapacity` rides on the item for whip_fuel (whip_fuel's
        -- server/jerry_can.lua).
        def.weight = w.weight or 3.0
        def.fuelCapacity = w.fuelCapacity
        def.metaFields = { { key = 'fuel', label = 'Fuel', format = 'percent' } }
        return def, function() return { serial = GunnyNewSerial(), fuel = 0 } end
    elseif Config.IsThrowable(w) then
        -- A stack, with no metadata, so stacks merge; the drawn one is known by its slot and item.
        def.weight = w.weight or 0.5
        def.stack, def.maxStack = true, w.maxStack or 25
        return def, nil
    elseif Config.IsMelee(w) then
        -- No card rows. The serial is still stamped: it is how the drawn weapon is known (GunnyDrawnWeapon).
        def.weight = w.weight or 1.0
        return def, function() return { serial = GunnyNewSerial() } end
    end
    -- A gun: Open shows its magazine slot (server/magpanel.lua), and its card its serial and ammo type.
    def.desc = w.description or ''
    def.weight = w.weight or 2.0
    def.contextOptions[2] = { action = 'whip_gunny:open_weapon', label = 'Open', order = MENU_ORDER.open }
    def.metaFields = cardRows(w.caliber)
    def.settings = gunSettings(itemName)
    return def, function() return { serial = GunnyNewSerial(), attachments = {} } end
end

--- A magazine's item. Built again when its size changes on the Items page: Load Bullets stops at the size in force.
---@param itemName string
---@param magData table  its Config.Magazines entry, as in force
---@return table
local function magazineDef(itemName, magData)
    local capacity = tonumber(magData.capacity)
    local baseCapacity = Config.ItemSettingDefault(itemName, 'capacity')
    return {
        name     = magData.label or itemName,
        desc     = magData.description or '',
        weight   = magData.weight or 0.3,
        type     = 'weapon',
        stack    = false,
        maxStack = 1,
        usable   = false,
        prop     = magData.prop,
        image    = packImage(itemName),
        defaultAction = 'whip_gunny:load_mag',
        contextOptions = {
            -- With room in it. No ammo field is empty (default = 0), as the load and unload read it (`meta.ammo or 0`).
            { action = 'whip_gunny:load_mag', label = 'Load Bullets', order = MENU_ORDER.load,
              when = capacity and { ammo = { below = capacity, default = 0 } } or nil,
              whyNot = 'Magazine is full' },
            { action = 'whip_gunny:unload_mag', label = 'Unload', order = MENU_ORDER.unload,
              when = { ammo = { above = 0 } }, whyNot = 'The magazine is empty' },
        },
        metaFields = cardRows(magData.caliber, { { key = 'ammo', label = 'Ammo' } }),
        settings = baseCapacity and {
            { key = 'capacity', type = 'int', min = 1, max = math.max(250, baseCapacity), default = baseCapacity,
              label = 'Rounds it holds',
              help = 'How many rounds one magazine takes. One already holding more keeps them until they are fired or unloaded.' },
        } or nil,
    }
end

--- RegisterItem answers (ok, err): a refusal is said. Answers whether it landed, and why not. A refused new-item
--- metadata (the serial a new one starts with) is said too, but the item stays: GiveWeapon sets its own, and a gun
--- without one still draws.
local function regItem(itemName, def, newMeta)
    local ok, err = exports.whip_core:RegisterItem(itemName, def)
    if not ok then
        GunnyWarn('item "%s" refused: %s', tostring(itemName), tostring(err))
        return false, err
    end
    if newMeta then
        local metaOk, metaWhy = exports.whip_core:RegisterItemDefaultMeta(itemName, newMeta)
        if not metaOk then GunnyWarn('item "%s": its new-item metadata refused: %s', tostring(itemName), tostring(metaWhy)) end
    end
    return true
end

local function registerWeapon(itemName)
    return regItem(itemName, weaponDef(itemName, Config.Weapons[itemName]))
end

local function newMagazineMeta() return { serial = GunnyNewSerial(), ammo = 0 } end

local function registerMagazine(itemName)
    return regItem(itemName, magazineDef(itemName, Config.Magazines[itemName]), newMagazineMeta)
end

--- An item setting changed on the Items page: a magazine whose size changes is registered again, so Load Bullets
--- stops at the new size.
local function onSettingChanged(itemName, field)
    if field ~= 'capacity' then return end
    local magData = Config.Magazines[itemName]
    if not magData then return end
    local ok, err = exports.whip_core:RegisterItem(itemName, magazineDef(itemName, magData))
    if not ok then GunnyWarn('magazine "%s" was not registered again at its new size: %s', itemName, tostring(err)) end
end

local function registerWithWhip()
    local registered = 0
    local function count(ok) if ok then registered = registered + 1 end end

    -- A weapon pack's item whip_core refuses (its name is another resource's item) leaves gunny's tables, after the
    -- loops: nothing may draw or load it (shared/packs.lua).
    local refused = {}
    local function countItem(itemName, ok, why)
        count(ok)
        if not ok and GunnyPacks.owner[itemName] then refused[itemName] = why end
    end

    for itemName in pairs(Config.Weapons) do countItem(itemName, registerWeapon(itemName)) end
    for itemName in pairs(Config.Magazines) do countItem(itemName, registerMagazine(itemName)) end
    for itemName, why in pairs(refused) do GunnyPacks.refused(itemName, why) end

    local registeredAmmo = {}
    for _, caliberData in pairs(Config.Calibers or {}) do
        if caliberData.ammoItem and not registeredAmmo[caliberData.ammoItem] then
            count(regItem(caliberData.ammoItem, {
                name     = caliberData.label and (caliberData.label .. ' Round') or caliberData.ammoItem,
                desc     = caliberData.label and (caliberData.label .. ' ammunition') or 'Ammunition',
                weight   = caliberData.ammoWeight or 0.01,
                type     = 'ammo',
                stack    = true,
                maxStack = 999,
                prop     = caliberData.prop,
            }))
            registeredAmmo[caliberData.ammoItem] = true
        end
    end

    for itemName, attData in pairs(Config.Attachments or {}) do
        count(regItem(itemName, {
            name     = attData.label or itemName,
            desc     = attData.description or (attData.label .. ' weapon attachment'),
            weight   = attData.weight or 0.2,
            type     = 'weapon',
            stack    = false,
            maxStack = 1,
            prop     = attData.prop,
        }))
    end

    -- Every gun's magazine slot, after the items: a panel naming an item whip_core has never heard of is refused.
    local slots = 0
    for itemName in pairs(Config.Weapons) do
        if RegisterGunnyMagPanel(itemName) then slots = slots + 1 end
    end

    -- The right-click actions. whip hands each the item's address (addr.sub is the pocket). Action names are
    -- server-wide, first come first served, so they carry this resource's name. ('whip_gunny:open_weapon' is the
    -- magazine slot's, server/magpanel.lua.)
    local function action(name, fn)
        local ok, why = exports.whip_core:RegisterContextAction(name, fn)
        if not ok then print(('[GUNNY] ERROR: context action %s refused: %s'):format(name, tostring(why))) end
    end

    -- From a pile's prompt (`how.from == 'ground'`): straight into the hand, no draw animation.
    action('whip_gunny:equip_weapon', function(source, _, _, addr, how)
        TriggerClientEvent('whip_gunny:client:useWeapon', source, addr.slot, addr.sub, type(how) == 'table' and how.from == 'ground')
    end)

    -- The load waits for its bar (server/magazines.lua): its own thread, so the action's handler does not wait.
    action('whip_gunny:load_mag', function(source, _, slotData, addr)
        if not Config.GetMagazine(slotData.item) then return end
        CreateThread(function() GunnyLoadMagazine(source, addr) end)
    end)

    -- A refusal is answered `false, why`: whip_core shows the player why, and records it.
    action('whip_gunny:unload_mag', function(source, _, slotData, addr)
        if not Config.GetMagazine(slotData.item) then return false, 'That is not a magazine' end
        local ok, why, unloaded = GunnyUnloadMagazine(source, addr)
        if not ok then return false, why end
        exports.whip_core:NotifyPlayer(source, ('Unloaded %d rounds from magazine'):format(unloaded), 'success')
    end)

    print(('[GUNNY] %d items and %d magazine slots registered with whip_core'):format(registered, slots))

    -- The sizes and reload times set on the Items page, into gunny's tables: now, and at each change.
    Config.FollowItemSettings(onSettingChanged)
end

Whip.register(registerWithWhip)

-- A weapon pack's item arriving while whip_core runs: registered now, with its magazine slot and settings. (Before
-- whip_core is up, registerWithWhip takes it in with the rest. One that goes stays an item: players carry it.)
GunnyPacks.onChange(function(itemName, kind, gone)
    if gone or not Whip.isReady() then return end
    local ok, why
    if kind == 'magazine' then ok, why = registerMagazine(itemName) else ok, why = registerWeapon(itemName) end
    -- Refused (its name is another resource's item): out of gunny's tables, and the pack's export answers false.
    if not ok then GunnyPacks.refused(itemName, why) return end
    if kind == 'weapon' then RegisterGunnyMagPanel(itemName) end
    Config.FollowItemSettings(onSettingChanged, itemName)
end)

-- ============================================
-- EXPORTS
-- ============================================

--- Rounds asked for, as a whole number from 0 to `cap`.
local function rounds(n, cap)
    return math.max(0, math.min(cap or 0, math.floor(tonumber(n) or 0)))
end

--- Give a player a weapon with fresh metadata. `reason` is for the activity log ('shop purchase', 'admin spawn').
--- whip_core's own AddItem gives the same weapon, empty: this is for the options.
---
--- `overrides`: `serial`, `attachments` ({ [category] = attachment item }), and by kind:
--- - a gun with magazines: `magazine` (the magazine item in it, one the gun takes) with `ammo` rounds in it;
--- - a gun with none: `ammo`, the rounds in it;
--- - either: `loaded = true` fills it (with its first magazine when none is named);
--- - the jerry can: `fuel`, 0-100; a throwable: `amount`, the stack (1 if none). A throwable carries no metadata.
--- Rounds are held to what the gun or the magazine holds. Answers true and where it went, as AddItem does:
--- 'inventory', or 'ground' at their feet when it did not fit; and its serial, to find it again with whip_core's
--- FindItemByMeta('serial', serial) (a throwable has none: a stack is not one thing).
exports('GiveWeapon', function(source, weaponName, overrides, reason)
    local weaponConfig = Config.GetWeapon(weaponName)
    if not weaponConfig then return false, 'Unknown weapon: ' .. tostring(weaponName) end

    overrides = type(overrides) == 'table' and overrides or {}

    if Config.IsThrowable(weaponConfig) then
        local amount = math.max(1, math.floor(tonumber(overrides.amount) or 1))
        local where, err = Whip.call('AddItem', source, weaponName, amount, nil, reason)
        if not where then return false, err end
        return true, where
    end

    local meta = {
        serial = type(overrides.serial) == 'string' and overrides.serial ~= '' and overrides.serial or GunnyNewSerial(),
        attachments = {},
    }
    -- Each attachment one this gun takes in that slot, as the bench would fit it.
    for category, attName in pairs(type(overrides.attachments) == 'table' and overrides.attachments or {}) do
        local att = Config.GetAttachment(attName)
        if not (att and att.category == category and Config.GetWeaponAttachmentComponent(weaponName, category, att.tier)) then
            return false, ('%s does not take %s in its %s slot'):format(weaponName, tostring(attName), tostring(category))
        end
        meta.attachments[category] = attName
    end

    if Config.IsFuelCan(weaponConfig) then
        -- Its serial and how full it is (0-100%): `overrides.fuel`, empty if none.
        meta = { serial = meta.serial, fuel = math.max(0, math.min(100, tonumber(overrides.fuel) or 0)) }
    elseif Config.IsMelee(weaponConfig) then
        meta = { serial = meta.serial }
    elseif weaponConfig.magless then
        local cap = tonumber(weaponConfig.internalCapacity) or 0
        meta.ammo = overrides.loaded and cap or rounds(overrides.ammo, cap)
    else
        local magName = overrides.magazine
        if magName == nil and overrides.loaded then magName = (weaponConfig.compatibleMags or {})[1] end
        if magName ~= nil then
            local magConfig = Config.GetMagazine(magName)
            if not magConfig then return false, 'Unknown magazine: ' .. tostring(magName) end
            if not Config.IsMagCompatible(weaponName, magName) then
                return false, ('%s does not take %s'):format(weaponName, magName)
            end
            local cap = tonumber(magConfig.capacity) or 0
            meta.magazine = GunnyMagazineIn(magName, { ammo = overrides.loaded and cap or rounds(overrides.ammo, cap) })
        end
    end

    -- AddItem answers where it went ('inventory' or 'ground'), or false and why. Through Whip.call, as it can wait
    -- (full pockets drop it on the ground; server/main.lua says when gunny calls whip_core which way).
    local where, err = Whip.call('AddItem', source, weaponName, 1, meta, reason)
    if not where then return false, err end
    return true, where, meta.serial
end)

--- Give a player a magazine with `ammo` rounds in it, held to what it holds (so any number past its size fills it).
--- `reason` and the answer as GiveWeapon, its serial too.
exports('GiveMagazine', function(source, magName, ammo, reason)
    local magConfig = Config.GetMagazine(magName)
    if not magConfig then return false, 'Unknown magazine: ' .. tostring(magName) end
    local meta = { serial = GunnyNewSerial(), ammo = rounds(ammo, tonumber(magConfig.capacity)) }
    local where, err = Whip.call('AddItem', source, magName, 1, meta, reason)
    if not where then return false, err end
    return true, where, meta.serial
end)
