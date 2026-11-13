-- whip_gunny — LOOKUPS into the items (items/*.lua), on both sides
--
-- GetWeapon, GetMagazine and GetCaliber run on every equip, shot and panel move: table indexes, never a scan.

function Config.GetWeapon(itemName)
    return Config.Weapons[itemName]
end

function Config.GetMagazine(itemName)
    return Config.Magazines[itemName]
end

function Config.GetCaliber(caliberName)
    return Config.Calibers[caliberName]
end

--- Does this magazine fit this weapon?
function Config.IsMagCompatible(weaponName, magName)
    local weapon = Config.Weapons[weaponName]
    if not weapon then return false end
    for _, compatMag in ipairs(weapon.compatibleMags or {}) do
        if compatMag == magName then return true end
    end
    return false
end

--- Every magazine component this weapon can show, its own included: all taken off before the right one goes on.
function Config.GetAllClipComponents(weaponName)
    local weapon = Config.Weapons[weaponName]
    if not weapon then return {} end
    local components = {}
    if weapon.defaultClipComponent then components[#components + 1] = weapon.defaultClipComponent end
    for _, magName in ipairs(weapon.compatibleMags or {}) do
        local mag = Config.Magazines[magName]
        if mag and mag.component then components[#components + 1] = mag.component end
    end
    return components
end

function Config.GetMagComponent(magName)
    local mag = Config.Magazines[magName]
    return mag and mag.component
end

--- The ammunition item a weapon's caliber loads.
function Config.GetAmmoItemForWeapon(weaponName)
    local weapon = Config.Weapons[weaponName]
    if not weapon then return nil end
    local caliber = Config.Calibers[weapon.caliber]
    return caliber and caliber.ammoItem
end

--- Is this config entry the jerry can (its ammunition is the fuel in it)?
---@param weapon table|nil  a Config.Weapons entry
function Config.IsFuelCan(weapon)
    return type(weapon) == 'table' and weapon.fuelCan == true
end

--- Is this config entry a throwable (a stack, and the stack is what the hand holds)?
---@param weapon table|nil  a Config.Weapons entry
function Config.IsThrowable(weapon)
    return type(weapon) == 'table' and weapon.throwable == true
end

--- Is this config entry a melee weapon (swung: no rounds, magazine, reload or attachments)?
---@param weapon table|nil  a Config.Weapons entry
function Config.IsMelee(weapon)
    return type(weapon) == 'table' and weapon.melee == true
end

--- Is this config entry a gun: fired, so it has rounds, a magazine or a chamber, reloads and an aim? Not a melee
--- weapon, the jerry can or a throwable.
---@param weapon table|nil  a Config.Weapons entry
function Config.IsFirearm(weapon)
    return type(weapon) == 'table' and not weapon.melee and not weapon.fuelCan and not weapon.throwable
end

--- What kind of weapon a config entry is, as the exports and events name it: 'gun', 'melee', 'throwable' or 'fuelCan'.
---@param weapon table  a Config.Weapons entry
---@return string
function Config.KindOf(weapon)
    if Config.IsFuelCan(weapon) then return 'fuelCan' end
    if Config.IsThrowable(weapon) then return 'throwable' end
    if Config.IsMelee(weapon) then return 'melee' end
    return 'gun'
end

-- ============================================
-- THE JERRY CAN'S FUEL AS GTA AMMUNITION
-- ============================================
--
-- The can's metadata `fuel` is how full it is (0-100%); the ped's petrol can holds up to 4500 of GTA's own units (what
-- pouring uses up). One scale, both ways: what the server gives the ped, and what the client reads back off it.

Config.FUEL_CAN_AMMO = 4500

---@param fuel number  0-100
---@return integer ammo
function Config.FuelToAmmo(fuel)
    fuel = math.max(0, math.min(100, tonumber(fuel) or 0))
    return math.floor(fuel / 100 * Config.FUEL_CAN_AMMO + 0.5)
end

---@param ammo number
---@return number fuel  0-100, to two decimals
function Config.AmmoToFuel(ammo)
    ammo = math.max(0, math.min(Config.FUEL_CAN_AMMO, tonumber(ammo) or 0))
    return math.floor(ammo / Config.FUEL_CAN_AMMO * 10000) / 100
end

-- ============================================
-- ATTACHMENTS
-- ============================================

function Config.GetAttachment(itemName)
    return Config.Attachments[itemName]
end

--- The GTA component for a weapon's slot (category) and kind (tier), or nil when it takes none.
function Config.GetWeaponAttachmentComponent(weaponName, category, tier)
    local slots = Config.WeaponAttachments[weaponName]
    local kinds = slots and slots[category]
    return kinds and kinds[tier]
end

--- The slots this weapon has.
function Config.GetWeaponAttachmentCategories(weaponName)
    local categories = {}
    for category in pairs(Config.WeaponAttachments[weaponName] or {}) do
        categories[#categories + 1] = category
    end
    return categories
end

--- Every attachment component this weapon can take: all taken off a display gun before its own go on.
function Config.GetAllAttachmentComponents(weaponName)
    local components = {}
    for _, kinds in pairs(Config.WeaponAttachments[weaponName] or {}) do
        for _, componentHash in pairs(kinds) do
            components[#components + 1] = componentHash
        end
    end
    return components
end

-- ============================================
-- WHAT EVERY ITEM MUST HAVE
-- ============================================
--
-- Checked as gunny starts, on both sides: an entry the code could not use is left out, and said. So the code reads
-- these fields without a fallback.

--- Why this magazine cannot be used as written, or nil.
---@param m table  a Config.Magazines entry
---@return string|nil
function Config.MagazineProblem(m)
    if type(m) ~= 'table' then return 'it is not a table' end
    local capacity = tonumber(m.capacity)
    if not capacity or capacity < 1 then return 'it needs a capacity (the rounds it holds)' end
    if not Config.Calibers[m.caliber] then return ('its caliber %s is not in items/calibers.lua'):format(tostring(m.caliber)) end
    return nil
end

--- Why this weapon cannot be used as written, or nil.
---@param w table  a Config.Weapons entry
---@return string|nil
function Config.WeaponProblem(w)
    if type(w) ~= 'table' then return 'it is not a table' end
    if type(w.hash) ~= 'number' then return 'it needs a hash (the GTA weapon it draws)' end
    if not Config.IsFirearm(w) then return nil end
    if not Config.Calibers[w.caliber] then return ('its caliber %s is not in items/calibers.lua'):format(tostring(w.caliber)) end
    if w.magless then
        local capacity = tonumber(w.internalCapacity)
        if not capacity or capacity < 1 then return 'magless, so it needs internalCapacity (the rounds it holds)' end
        return nil
    end
    if type(w.compatibleMags) ~= 'table' or not w.compatibleMags[1] then
        return 'it needs compatibleMags, or magless = true'
    end
    for _, magName in ipairs(w.compatibleMags) do
        if not Config.Magazines[magName] then return ('its magazine %s is not in items/magazines.lua'):format(tostring(magName)) end
    end
    return nil
end

for itemName, m in pairs(Config.Magazines) do
    local why = Config.MagazineProblem(m)
    if why then
        print(('[GUNNY] WARNING: magazine %s left out: %s'):format(itemName, why))
        Config.Magazines[itemName] = nil
    end
end
for itemName, w in pairs(Config.Weapons) do
    local why = Config.WeaponProblem(w)
    if why then
        print(('[GUNNY] WARNING: weapon %s left out: %s'):format(itemName, why))
        Config.Weapons[itemName] = nil
    end
end

-- ============================================
-- NAME LISTS (sorted, so they read the same every time)
-- ============================================

local function sortedKeys(t)
    local names = {}
    for itemName in pairs(t or {}) do names[#names + 1] = itemName end
    table.sort(names)
    return names
end

function Config.GetAllWeaponNames() return sortedKeys(Config.Weapons) end
function Config.GetAllMagazineNames() return sortedKeys(Config.Magazines) end
function Config.GetAllAttachmentNames() return sortedKeys(Config.Attachments) end

-- ============================================
-- ITEM SETTINGS: a magazine's size, a gun's reload time and rounds
-- ============================================
--
-- Each is a setting of the item itself (server/items.lua declares them with it), changed per item on /whip's Items page.
-- whip keeps the value in force on both sides; Config.FollowItemSettings writes it INTO the tables above (a magazine's
-- `capacity`, a gun's `reloadTime` and `internalCapacity`), so everything that reads them sees the admin's value.
--
-- The defaults are the item files' own, kept as each item arrives (this file loading, or a pack registering it): the
-- tables are changed in place after that, and a registration reading them again would declare the admin's value as
-- the default.

local itemDefaults = {}   -- [item] = { [field] = number }

--- Keep an item's own values as its settings' defaults (a weapon pack's item as it registers, shared/packs.lua).
---@param itemName string
function Config.NoteItemDefaults(itemName)
    local mag, gun = Config.Magazines[itemName], Config.Weapons[itemName]
    if mag then
        itemDefaults[itemName] = { capacity = tonumber(mag.capacity) }
    elseif Config.IsFirearm(gun) then
        itemDefaults[itemName] = { reloadTime = tonumber(gun.reloadTime), internalCapacity = tonumber(gun.internalCapacity) }
    else
        itemDefaults[itemName] = nil
    end
end

for itemName in pairs(Config.Magazines) do Config.NoteItemDefaults(itemName) end
for itemName in pairs(Config.Weapons) do Config.NoteItemDefaults(itemName) end

--- The item file's value of one of an item's settings: its default on the Items page. nil when it has no such setting.
---@param itemName string
---@param field string  'capacity' | 'reloadTime' | 'internalCapacity'
---@return number|nil
function Config.ItemSettingDefault(itemName, field)
    local d = itemDefaults[itemName]
    return d and d[field]
end

--- Follow whip's value of every item's settings: now, and whenever an admin changes one (Reset too). Run from
--- Whip.register on both sides, once whip_core is ready. On the server, AFTER the items are
--- registered: whip knows an item's settings only once it is.
---@param onChange function|nil  fn(itemName, field, value) after a value in force changes here
---@param only string|nil  just this item's (a pack's, as it registers)
function Config.FollowItemSettings(onChange, only)
    for itemName, fields in pairs(itemDefaults) do
        local t = Config.Magazines[itemName] or Config.Weapons[itemName]
        if t and (only == nil or only == itemName) then
            for field, default in pairs(fields) do
                -- nil (not known yet on a player's game, or no longer a setting): the item file's.
                local function put(value)
                    if value == nil then value = default end
                    if t[field] == value then return end
                    t[field] = value
                    if onChange then onChange(itemName, field, value) end
                end
                exports.whip_core:OnItemSettingChanged(itemName, field, put)
                put(exports.whip_core:GetItemSetting(itemName, field))
            end
        end
    end
end

-- A player's game follows them as whip_core is ready, and again after it restarts. (The server follows them at the
-- end of its own registration, server/items.lua.)
if not IsDuplicityVersion() then
    Whip.register(function() Config.FollowItemSettings() end)
end
