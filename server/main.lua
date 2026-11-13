-- whip_gunny — THE SERVER'S FOUNDATION
--
-- How gunny declares what the client may ask, the shapes every handler shares, and the drawn-weapon record. The
-- items themselves are registered in server/items.lua.
--
-- CALLING WHIP_CORE, on the server: the docs' one rule (docs.html#patterns-calling) — exports.whip_core:X straight
-- inside a handler whip_core runs (it is up then), Whip.call outside one (a console command). gunny goes one step
-- further than the rule needs: inside a handler too, a call that can wait (AddItem: full pockets drop the item on the
-- ground; Progress: a bar) and everything after such a wait (an undo: GunnyStillThere, below) go through Whip.call,
-- so a failure answers false and why instead of throwing, and the half-made change can be undone or said lost. (The
-- client's rule is at the top of client/main.lua.)

--- Every declaration, kept to be made again when a weapon pack changes the item lists the schemas name (the bottom of
--- this file). Most resources need no such list: they make their SecureCallback / SecureEvent calls inside
--- Whip.register and are done. gunny keeps one only because a pack's guns change which items its 'slot' params accept.
local declarations = {}

local function declare(fn)
    declarations[#declarations + 1] = fn
    Whip.register(fn)
end

--- Declare a callback by its full name ('whip_gunny:equipWeapon'), the name the client's GunnyCallback asks for.
---
--- Through SecureCallback: whip_core checks the params against the schema, rate-limits, and logs, before the handler
--- runs with (source, player, ...). Through Whip.register, so it is declared once whip_core is ready, and again when
--- a weapon pack changes the item lists (SecureCallback replaces its entry and binds the net handler once).
---@param name string
---@param schema table
---@param handler function
function RegisterGunnyCallback(name, schema, handler)
    if type(schema) ~= 'table' or type(handler) ~= 'function' then
        error(('RegisterGunnyCallback(%s): a schema and a handler are both required'):format(tostring(name)), 2)
    end
    -- A floor for callbacks that declare no rateLimit (a declared one wins), with a burst: a player's own quick
    -- presses (draw, holster, draw again) are not refused.
    if schema.rateLimit == nil then
        schema.rateLimit = 150
        schema.burst     = schema.burst or 8
    end
    declare(function()
        exports.whip_core:SecureCallback(name, schema, handler)
    end)
end

--- Declare a client → server event by its full name ('whip_gunny:server:shotFired'), the same way.
---@param name string
---@param schema table
---@param handler function
function RegisterGunnyEvent(name, schema, handler)
    if type(schema) ~= 'table' or type(handler) ~= 'function' then
        error(('RegisterGunnyEvent(%s): a schema and a handler are both required'):format(tostring(name)), 2)
    end
    declare(function()
        exports.whip_core:SecureEvent(name, schema, handler)
    end)
end

--- A rollback that fired (an item handed back after a half-failed change) or a lost write: always printed, for the
--- server owner.
---@param fmt string
function GunnyWarn(fmt, ...)
    local ok, msg = pcall(string.format, fmt, ...)
    print(('[GUNNY] WARNING: %s'):format(ok and msg or fmt))
end

--- An undo: give back what a half-done change already took. Through Whip.call, as AddItem may wait (full pockets
--- drop it on the ground) and an answer must come even if whip_core stops meanwhile. Answers whether it landed; when
--- it did not, the item is lost, and that is said.
---@return boolean
function GunnyGiveBack(source, item, amount, metadata, reason)
    local where, why = Whip.call('AddItem', source, item, amount, metadata, reason)
    if where then return true end
    GunnyWarn('%d x %s LOST: %s, and it could not be given back (%s)', amount, item, reason, tostring(why))
    return false
end

--- Read a slot again after a wait (AddItem, a bar): what is in it, if it is still `item` with `serial`, or nil (moved,
--- replaced, or whip_core gone meanwhile). The read before an undo, so the undo lands on the thing it took from.
--- Through Whip.call: it comes after a wait, and an answer must come even if whip_core stopped during it.
---@param addr table      the slot (GunnyPocket)
---@param item string     the item it held
---@param serial string|nil  the serial it had
---@return table|nil slotData  { item, amount, metadata }
function GunnyStillThere(addr, item, serial)
    local sd = Whip.call('GetItemAt', addr)
    if type(sd) == 'table' and sd.item == item and (sd.metadata or {}).serial == serial then return sd end
    return nil
end

--- A magazine going into a gun: the gun's `magazine` record, which is the magazine's whole metadata (its rounds,
--- serial, uid, anything else on it) and its item name. Whole, so it comes out as it went in.
---@param item string       the magazine item
---@param metadata table|nil its metadata
---@return table record  { item, ammo, serial, ... }
function GunnyMagazineIn(item, metadata)
    local record = {}
    for k, v in pairs(type(metadata) == 'table' and metadata or {}) do record[k] = v end
    record.item   = item
    record.ammo   = tonumber(record.ammo) or 0
    -- Magazines get a serial when made (server/items.lua); one without is given one as it goes in.
    record.serial = record.serial or GunnyNewSerial()
    return record
end

--- A gun's `magazine` record coming out: the magazine item, and its metadata as it went in, with the rounds left.
---@param record table
---@return string item
---@return table metadata
function GunnyMagazineOut(record)
    local metadata = {}
    for k, v in pairs(record) do if k ~= 'item' then metadata[k] = v end end
    return record.item, metadata
end

--- [source] = true for each player with Gunny Debug on in /w (server/debug.lua).
GunnyDebugFor = {}

--- A debug line, printed while anyone has Gunny Debug on.
function GunnyDebugPrint(...)
    if next(GunnyDebugFor) then
        print('[GUNNY]', ...)
    end
end

--- The whip ADDRESS of one of a player's pocket slots, which whip's slot calls take (GetItemAt, SetItemMetadata,
--- StoreTake).
---@param source number
---@param pocket string  'player' or 'accessory'
---@param slot number
---@return table addr
function GunnyPocket(source, pocket, slot)
    return { kind = 'player', id = source, sub = pocket or 'player', slot = slot }
end

--- The items a handler's 'slot' param may name. A handler acting on a slot the client names declares
--- { 'weapon', 'slot', { item = GunnyWeaponItems } } and the client sends GunnySlot(slot, pocket): whip_core checks
--- the pocket is the player's, the slot is in range and not empty, and holds one of these, and the handler gets
--- { addr, item, amount, metadata } (a copy).
GunnyWeaponItems     = Config.GetAllWeaponNames()
GunnyMagazineItems   = Config.GetAllMagazineNames()
GunnyAttachmentItems = Config.GetAllAttachmentNames()

-- A weapon pack's item arrived or went (shared/packs.lua): the lists again, in place (the schemas hold these tables),
-- and every declaration made again with them, once for a burst of a pack's items. whip_core not up: Whip.register
-- declares them when it is.
local function refill(list, names)
    for i = #list, 1, -1 do list[i] = nil end
    for i, n in ipairs(names) do list[i] = n end
end
local redeclaring = false
GunnyPacks.onChange(function()
    if redeclaring then return end
    redeclaring = true
    SetTimeout(0, function()
        redeclaring = false
        refill(GunnyWeaponItems, Config.GetAllWeaponNames())
        refill(GunnyMagazineItems, Config.GetAllMagazineNames())
        if not Whip.isReady() then return end
        for _, fn in ipairs(declarations) do fn() end
    end)
end)

--- The weapon each player has drawn: [source] = { slot, pocket, weapon, serial, countVersion, fuel?, count?, taken? }
--- (server/weapons.lua).
EquippedWeapons = {}

--- The record of a gun just put away, kept LATE_COUNT_MS: a shot fired in the frame the holster read its count is sent
--- just behind the holster, and is still charged to that gun (GunnyDrawnWeapon's `lateToo`, server/shooting.lua).
--- Only a put-away keeps one; any other end, or the next draw, forgets it.
local justHolstered = {}   -- [source] = { record, at }
local LATE_COUNT_MS = 2000

--- The record put away less than LATE_COUNT_MS ago, or nil.
---@param source number
---@return table|nil record
function GunnyJustHolstered(source)
    local j = justHolstered[source]
    if j and GetGameTimer() - j.at <= LATE_COUNT_MS then return j.record end
    return nil
end

--- The record ends, whichever way it went, and other resources hear it once: whip_gunny:weapon:holstered with
--- `reason` 'holstered' (put away), 'moved' (it left its slot), 'replaced', 'logout' or 'dropped'.
---@param source number
---@param reason string
function GunnyEndDrawn(source, reason)
    local e = EquippedWeapons[source]
    justHolstered[source] = nil   -- before the check: a new draw ends no record, and still forgets the last one
    if not e then return end
    EquippedWeapons[source] = nil
    if reason == 'holstered' then justHolstered[source] = { record = e, at = GetGameTimer() } end
    TriggerEvent('whip_gunny:weapon:holstered', { source = source, item = e.weapon, serial = e.serial,
        slot = e.slot, pocket = e.pocket, reason = reason })
end

AddEventHandler('playerDropped', function()
    GunnyEndDrawn(source, 'dropped')
end)

-- A logout keeps the connection (no playerDropped): cleared here, or the next character on this source inherits it.
-- (whip_core stopping stops gunny first, its dependency, so the record goes with it and nothing is left over.)
AddEventHandler('whip_core:player:logout', function(e)
    GunnyEndDrawn(e.source, 'logout')
end)

math.randomseed(os.time())

--- A new weapon's or magazine's serial: 12 letters and digits.
function GunnyNewSerial()
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local parts = {}
    for _ = 1, 12 do
        local idx = math.random(1, #chars)
        parts[#parts + 1] = chars:sub(idx, idx)
    end
    return table.concat(parts)
end
