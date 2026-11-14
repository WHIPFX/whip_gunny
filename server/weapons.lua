-- whip_gunny — DRAWING AND PUTTING AWAY (server)
--
-- The server's record of the drawn weapon (EquippedWeapons, server/main.lua): where it was drawn from, and its serial.
-- Everything a drawn gun does afterwards (shots, throws, the holster) goes by this record, never by a slot the client
-- names.

--- The weapon this player has drawn, read fresh, or nil if it is no longer where it was drawn from.
---
--- The inventory stays usable while a gun is out (dragged, stashed, handed over), so the item in that slot must still
--- be the same item with the same serial: the slot number alone would charge shots to whatever sits there now.
---
--- `lateToo`: with nothing drawn now, the gun put away a moment ago (GunnyJustHolstered, server/main.lua), for a count
--- that was on its way as it went. The third answer says it is that one: nothing is in the hand to tell or take back.
---@param source number
---@param lateToo boolean|nil
---@return table|nil slotData  the drawn weapon, still in place
---@return table|nil equipped  the record, whether or not the weapon is still there
---@return boolean late        the record is the one just put away
function GunnyDrawnWeapon(source, lateToo)
    local equipped, late = EquippedWeapons[source], false
    if not equipped and lateToo then equipped, late = GunnyJustHolstered(source), true end
    if not equipped then return nil, nil, false end
    local sd = exports.whip_core:GetItemAt(GunnyPocket(source, equipped.pocket, equipped.slot))
    if sd and sd.item == equipped.weapon and (sd.metadata or {}).serial == equipped.serial then
        return sd, equipped, late
    end
    return nil, equipped, late
end

--- Tell whip_core what is in the hand: the drawn weapon is the player's held item, so whip_core can act on it (a pump
--- fills the jerry can in hand, a car's doors pour it). whip_core clears it at logout and on a drop.
---@param source number
---@param addr table|nil  the drawn weapon's slot, or nil
local function setHeld(source, addr)
    local ok, why = exports.whip_core:SetHeldItem(source, addr)
    if not ok then GunnyDebugPrint('SetHeldItem refused:', why) end
end

--- The drawn weapon left the slot it was drawn from: put it away on both sides.
---@param source number
function GunnyForceHolster(source)
    GunnyEndDrawn(source, 'moved')
    setHeld(source, nil)
    TriggerClientEvent('whip_gunny:client:forceHolster', source)
end

--- The server changed the drawn gun's rounds itself (a reload, its magazine slot): the count's version goes up, and the
--- client is told it with the new count. A count the client sends with an older version was counted before that change
--- (a sync already on its way, a holster as the player dies mid-reload) and is ignored: lowered onto the new magazine,
--- it would empty it. Answers the new version, or nil when this is not the drawn gun.
---@param source number
---@param addr table          the gun's slot
---@param serial string|nil   the gun's serial
---@return number|nil countVersion
function GunnyCountChanged(source, addr, serial)
    local e = EquippedWeapons[source]
    if not (e and e.slot == addr.slot and e.pocket == (addr.sub or 'player') and e.serial == serial) then return nil end
    e.countVersion = e.countVersion + 1
    return e.countVersion
end

--- A shot, throw or count for a draw this server has no record of: the hand holds something nothing counts (a
--- forceHolster lost on its way). Put it away there, at most once a second per player.
local noRecordAt = {}
---@param source number
function GunnyNoDrawRecord(source)
    local now = GetGameTimer()
    if noRecordAt[source] and now - noRecordAt[source] < 1000 then return end
    noRecordAt[source] = now
    TriggerClientEvent('whip_gunny:client:forceHolster', source)
end
AddEventHandler('playerDropped', function() noRecordAt[source] = nil end)

-- Any pocket change (whip_core:inventory:changed): the drawn weapon is looked at right then. Gone from its slot (moved,
-- dropped, stashed, handed over), it is put away.
AddEventHandler('whip_core:inventory:changed', function(e)
    local src = type(e) == 'table' and e.source or nil
    if not src or not EquippedWeapons[src] then return end
    local slotData, equipped = GunnyDrawnWeapon(src)
    if not equipped then return end   -- (the record checked just above: always there)
    if not slotData then
        GunnyDebugPrint('Drawn weapon left its slot - holstering', src)
        GunnyForceHolster(src)
        return
    end
    -- The jerry can in hand, filled or poured by whip_fuel: the ped's petrol to the new level. Our own fuel writes note
    -- the level first, so they arrive as no change. Its own event: syncAmmo counts as a confirmed shot on the client.
    -- The server changed the count, so its version goes up (GunnyCountChanged): a level the client sent before it hears
    -- this (a holster just after a paid fill) is ignored, and cannot put the old level back.
    if slotData and equipped.fuel ~= nil then
        local fuel = tonumber((slotData.metadata or {}).fuel) or 0
        if fuel ~= equipped.fuel then
            equipped.fuel = fuel
            equipped.countVersion = equipped.countVersion + 1
            TriggerClientEvent('whip_gunny:client:syncFuel', src, Config.FuelToAmmo(fuel), equipped.countVersion)
        end
    end
    -- A throwable in hand whose stack changed (more dragged onto it, some split off): the new count, with the throws
    -- taken so far (client/throwables.lua). Our own takes note the count first, so they arrive as no change.
    if slotData and equipped.count ~= nil then
        local n = tonumber(slotData.amount) or 0
        if n ~= equipped.count then
            equipped.count = n
            TriggerClientEvent('whip_gunny:client:syncThrown', src, n, equipped.taken or 0)
        end
    end
end)

--- The jerry can in hand poured some out (from the client's count): its new level, written quietly, and only ever down
--- (a client cannot fill its can by saying so). Answers whether it was written.
---@param source number
---@param slotData table  the drawn can, resolved
---@param equipped table  its EquippedWeapons record
---@param ammo number     what the ped's petrol can holds now
---@return boolean
function GunnySyncFuelCan(source, slotData, equipped, ammo)
    local meta = slotData.metadata or {}
    local fuel = Config.AmmoToFuel(ammo)
    if fuel >= (tonumber(meta.fuel) or 0) then return false end
    meta.fuel = fuel
    equipped.fuel = fuel   -- first: the write below must read as no change
    if not exports.whip_core:SetItemMetadata(GunnyPocket(source, equipped.pocket, equipped.slot), meta, { quiet = true }) then
        GunnyWarn('jerry can fuel sync FAILED - level not persisted')
        return false
    end
    GunnyDebugPrint('Jerry can poured down to', fuel)
    return true
end

-- Draw: the weapon arrives as whip's 'slot' param (this player's own pocket, holding one of gunny's weapons). Answers
-- true and { hash, ammo, magazine, attachments, serial, countVersion }, or false and why.
RegisterGunnyCallback('whip_gunny:equipWeapon', { params = { { 'weapon', 'slot', { item = GunnyWeaponItems } } } },
function(source, _, weapon)
    local slotData = weapon   -- whip's copy of the slot: { addr, item, amount, metadata }

    local weaponConfig = Config.GetWeapon(slotData.item)
    if not weaponConfig then return false, 'Invalid weapon' end

    -- The server's own blocks (whip_core's BlockHands(source, ...)): jail, an arrest. The game checks its own.
    local blocked, why = exports.whip_core:AreHandsBlocked(source, 'weapon')
    if blocked then return false, why end

    local meta = slotData.metadata or {}

    -- A jerry can with no serial gets one, once: the serial is how a drawn weapon is known to be still in its slot.
    local fuelCan = Config.IsFuelCan(weaponConfig)
    if fuelCan and not meta.serial then
        meta.serial = GunnyNewSerial()
        if not exports.whip_core:SetItemMetadata(weapon.addr, meta) then return false, 'Could not get the can ready' end
    end

    local throwable = Config.IsThrowable(weaponConfig)

    -- A gun with no magazine holding more than it holds now (its size went down in items/weapons.lua, or "Rounds it
    -- holds" on the Items page): trimmed to that size as it is drawn, and the extra rounds go back to the pockets. Never
    -- below the item file's own size, so a gun loaded to the standard size keeps every round whatever the page says.
    if weaponConfig.magless and not fuelCan and not throwable then
        local setting = tonumber(weaponConfig.internalCapacity)
        local builtIn = tonumber(Config.ItemSettingDefault(slotData.item, 'internalCapacity'))
        local cap = setting and math.max(setting, builtIn or setting)
        local held = tonumber(meta.ammo) or 0
        if cap and held > cap then
            meta.ammo = cap
            if exports.whip_core:SetItemMetadata(weapon.addr, meta) then
                -- Through Whip.core: the gun is lowered and the rounds in nobody's pockets until they land.
                local ammoItem = Config.GetAmmoItemForWeapon(slotData.item)
                local back = ammoItem and Whip.core:AddItem(source, ammoItem, held - cap, nil,
                    'more than the gun holds now')
                if not back then
                    -- Nowhere to put them: left in the gun rather than lost, if it is still the gun lowered (AddItem
                    -- can wait, and another item may sit in that slot by now).
                    local now = GunnyStillThere(weapon.addr, slotData.item, meta.serial)
                    local nowMeta = now and now.metadata or {}
                    nowMeta.ammo = (tonumber(nowMeta.ammo) or 0) + (held - cap)
                    if now and Whip.core:SetItemMetadata(weapon.addr, nowMeta) == true then
                        meta.ammo = nowMeta.ammo   -- the draw goes on with what the gun holds now
                    else
                        GunnyWarn('%d rounds of %s LOST (nowhere to put them, and the gun could not keep them)', held - cap, slotData.item)
                    end
                end
            else
                meta.ammo = held   -- not written: left as it was
            end
        end
    end

    -- The client puts one away before drawing another, so a record still here is a stale one.
    GunnyEndDrawn(source, 'replaced')
    EquippedWeapons[source] = {
        slot = weapon.addr.slot,
        pocket = weapon.addr.sub,
        weapon = slotData.item,
        serial = meta.serial,   -- its identity (GunnyDrawnWeapon); a throwable has none: its slot and item
        fuel = fuelCan and (tonumber(meta.fuel) or 0) or nil,              -- the jerry can's level as the hand has it
        count = throwable and (tonumber(slotData.amount) or 0) or nil,     -- a throwable's stack as the hand has it
        countVersion = 1,   -- GunnyCountChanged
    }
    setHeld(source, weapon.addr)
    TriggerEvent('whip_gunny:weapon:drawn', { source = source, item = slotData.item, kind = Config.KindOf(weaponConfig),
        serial = meta.serial, slot = weapon.addr.slot, pocket = weapon.addr.sub })

    local ammo = 0
    local magName = nil

    if fuelCan then
        ammo = Config.FuelToAmmo(meta.fuel)
        GunnyDebugPrint('Player', source, 'took out a jerry can at', meta.fuel or 0, '%')
    elseif throwable then
        ammo = tonumber(slotData.amount) or 0   -- the hand holds the whole stack
        GunnyDebugPrint('Player', source, 'took out', ammo, slotData.item)
    elseif weaponConfig.magless then
        ammo = meta.ammo or 0
        GunnyDebugPrint('Player', source, 'equipped magless weapon', slotData.item, 'with', ammo, 'rounds')
        GunnyLedgerDrawn(source, slotData.item, meta.serial, ammo)   -- server/ledger.lua
    else
        if meta.magazine then
            ammo = meta.magazine.ammo or 0
            magName = meta.magazine.item
        end
        GunnyDebugPrint('Player', source, 'equipped', slotData.item, 'with', ammo, 'rounds, mag:', magName or 'none')
    end

    return true, { hash = weaponConfig.hash, ammo = ammo, magazine = magName, attachments = meta.attachments or {},
                   serial = meta.serial, countVersion = 1 }
end)

--- Put away: the rounds left as the client counts them, written to the gun in its slot, only when lower (firing only
--- lowers a count), as the ammo sync is (server/shooting.lua). A failed write loses only the count until the next one
--- (nothing moved): said, no rollback.
local function keepCount(source, slotData, equipped, rounds)
    local weaponConfig = Config.GetWeapon(slotData.item)
    -- A throwable: nothing to write, each one thrown was taken as it went (server/throwables.lua).
    if not weaponConfig or Config.IsThrowable(weaponConfig) then return end
    if Config.IsFuelCan(weaponConfig) then return GunnySyncFuelCan(source, slotData, equipped, rounds) end
    local meta = slotData.metadata or {}
    local before = meta.ammo or 0
    if weaponConfig.magless then
        if rounds >= (meta.ammo or 0) then return end
        meta.ammo = rounds
    else
        if not meta.magazine or rounds >= (meta.magazine.ammo or 0) then return end
        meta.magazine.ammo = rounds
    end
    if not exports.whip_core:SetItemMetadata(GunnyPocket(source, equipped.pocket, equipped.slot), meta) then
        GunnyWarn('holster: the count of %s could not be written', slotData.item)
    elseif weaponConfig.magless then
        GunnyLedgerGun(source, slotData.item, equipped.serial, 'holster', before, rounds)   -- server/ledger.lua
    end
end

RegisterGunnyCallback('whip_gunny:holsterWeapon', {
    whileDead = true,   -- dying puts the gun away
    -- A release: a burst, so one is never refused for coming close behind another (a forced holster as the player
    -- dies), which would leave the gun drawn here.
    rateLimit = 200,
    burst     = 3,
    params = {
        {'remainingAmmo', 'int', 0, 9999},
        {'countVersion',  'int', 0, 2147483647, 0},   -- GunnyCountChanged
    },
}, function(source, _, remainingAmmo, countVersion)
    local slotData, equipped = GunnyDrawnWeapon(source)
    if not equipped then return false, 'No weapon drawn' end
    -- A gun that has left its slot is still put away; there is just no count to write back. Nor is there for a count
    -- from before the server's last change to it (put away as the player dies mid-reload): every shot was taken as it
    -- went, and none is fired during a reload.
    if slotData and countVersion == equipped.countVersion then
        keepCount(source, slotData, equipped, remainingAmmo)
    elseif slotData then
        GunnyDebugPrint('Holster count from before the last change ignored', source, countVersion, equipped.countVersion)
    end

    GunnyEndDrawn(source, 'holstered')
    setHeld(source, nil)
    GunnyDebugPrint('Player', source, 'holstered weapon')

    return true
end)
