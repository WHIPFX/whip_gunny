-- whip_gunny — RELOADING (server)
--
-- R swaps the gun's magazine for the fullest one carried; a gun with no magazine takes loose rounds, all at once or (the
-- pump) a shell at a time. Take before give, and a half-done change is put back.

-- Find the best compatible magazine in player inventory (highest ammo). Each one found is
-- whip's `{ item, amount, metadata, addr }` — `addr` is where it is, for GetItemAt / StoreTake.
local function bestMagazine(source, weaponConfig)
    local best, bestAmmo = nil, -1
    local count = 0
    local totalAmmo = 0

    for _, compatMag in ipairs(weaponConfig.compatibleMags or {}) do
        local allMags = exports.whip_core:FindAllItems(source, compatMag)
        for _, found in ipairs(allMags or {}) do
            local magAmmo = found.metadata and found.metadata.ammo or 0
            count = count + 1
            totalAmmo = totalAmmo + magAmmo
            if magAmmo > bestAmmo then
                bestAmmo = magAmmo
                best = found
            end
        end
    end

    return best, bestAmmo, count, totalAmmo
end

-- R on a gun with magazines: the fullest one carried goes in, and the one in it comes out. Every refusal is a
-- sentence the client shows as it is. The gun arrives as whip's 'slot' param (server/main.lua says what that checks).
RegisterGunnyCallback('whip_gunny:performReload', { params = { { 'weapon', 'slot', { item = GunnyWeaponItems } } } },
function(source, _, weapon)
    local weaponAddr = weapon.addr
    local weaponConfig = Config.GetWeapon(weapon.item)
    -- Only a modified client asks for anything but a gun: client/reload.lua stands down for the rest.
    if not Config.IsFirearm(weaponConfig) then return false, 'That weapon is not reloaded' end
    if weaponConfig.magless then return false, 'That weapon is loaded with rounds, not magazines' end

    local meta = weapon.metadata or {}
    local bestMag, bestAmmo = bestMagazine(source, weaponConfig)
    if not bestMag then return false, 'No magazines for this weapon on you' end
    if bestAmmo <= 0 then return false, 'All your magazines for this weapon are empty' end
    GunnyDebugPrint('Reloading - Current mag:', meta.magazine and meta.magazine.ammo or 0, 'rounds, Best mag:', bestAmmo, 'rounds')

    -- Take before give: the new magazine out of the pockets first.
    local removed, takeWhy = exports.whip_core:StoreTake(bestMag.addr, 1, { reason = 'loaded into a weapon' })
    if not removed then return false, takeWhy or 'Could not take the magazine, try again' end

    -- Into the gun, with the old one off it before it is handed back: a second reload during that give cannot hand
    -- it out twice. Its whole metadata goes in (GunnyMagazineIn: its uid and the rest), and comes out the same.
    local oldMag = meta.magazine
    local newMagMeta = bestMag.metadata or {}
    meta.magazine = GunnyMagazineIn(bestMag.item, newMagMeta)
    if not exports.whip_core:SetItemMetadata(weaponAddr, meta) then
        GunnyWarn('reload: the weapon could not be written, so the magazine goes back to the pockets')
        GunnyGiveBack(source, bestMag.item, 1, newMagMeta, 'reload undone')
        return false, 'Could not reload, the magazine is back in your pockets'
    end
    -- The new magazine is in: a count the client sent for the old one is ignored from here (the old one's give below
    -- can wait).
    local countVersion = GunnyCountChanged(source, weaponAddr, meta.serial)

    if oldMag then
        -- To the pockets, or the ground when they are full. Through Whip.core: the reload is half done until it lands.
        local oldItem, oldMeta = GunnyMagazineOut(oldMag)
        local where = Whip.core:AddItem(source, oldItem, 1, oldMeta, 'swapped out of a weapon')
        if not where then
            -- Nowhere at all: the reload is undone rather than the old magazine lost. Read again: AddItem waited, and
            -- the new magazine goes back as it is now (shots fired meanwhile came out of it).
            local now = GunnyStillThere(weaponAddr, weapon.item, meta.serial)
            local inIt = now and (now.metadata or {}).magazine
            if now and inIt and inIt.serial == meta.magazine.serial then
                local newItem, newMeta = GunnyMagazineOut(now.metadata.magazine)
                now.metadata.magazine = oldMag
                if Whip.core:SetItemMetadata(weaponAddr, now.metadata) == true then
                    GunnyGiveBack(source, newItem, 1, newMeta, 'reload undone')
                    -- The gun's count changed again: the client takes it, and the version raised above, with no
                    -- gesture (client/weapons.lua). Its counts would be ignored from here otherwise.
                    TriggerClientEvent('whip_gunny:client:countRestored', source, weaponAddr.slot, oldMag.ammo or 0,
                        countVersion, oldMag.item)
                else
                    GunnyWarn('reload: %s LOST (nowhere to put it, and the weapon could not take it back)', oldMag.item)
                end
            else
                GunnyWarn('reload: %s LOST (nowhere to put it, and the weapon moved meanwhile)', oldMag.item)
            end
            return false, 'No room for the old magazine'
        end
    end

    GunnyDebugPrint('Reload complete - new magazine has', bestAmmo, 'rounds, mag:', bestMag.item)
    return true, { ammo = bestAmmo, magazine = bestMag.item, countVersion = countVersion }
end)

-- ============================================
-- A GUN WITH NO MAGAZINE: loose rounds, all at once
-- ============================================

-- R on a revolver or a tube-fed shotgun: as many rounds as it has room for and the player carries.
RegisterGunnyCallback('whip_gunny:performMaglessReload', { params = { { 'weapon', 'slot', { item = GunnyWeaponItems } } } },
function(source, _, weapon)
    local weaponAddr = weapon.addr
    local weaponConfig = Config.GetWeapon(weapon.item)
    if not (Config.IsFirearm(weaponConfig) and weaponConfig.magless) then return false, 'That weapon takes magazines' end

    local meta = weapon.metadata or {}
    local ammoItemName = Config.GetAmmoItemForWeapon(weapon.item)
    if not ammoItemName then return false, 'This weapon has no ammunition set up' end
    local currentAmmo = meta.ammo or 0
    local room = weaponConfig.internalCapacity - currentAmmo
    if room <= 0 then return false, 'Already fully loaded' end

    local have = exports.whip_core:GetItemCount(source, ammoItemName) or 0
    if have <= 0 then return false, 'No ammunition for this weapon on you' end
    local toLoad = math.min(room, have)

    -- Take before give: the rounds out of the pockets, then into the gun; given back if the gun cannot record them.
    if not exports.whip_core:RemoveItem(source, ammoItemName, toLoad, nil, { reason = 'loaded into a weapon' }) then
        return false, 'Could not take the rounds, try again'
    end
    meta.ammo = currentAmmo + toLoad
    local wrote, why = exports.whip_core:SetItemMetadata(weaponAddr, meta)
    if not wrote then
        GunnyGiveBack(source, ammoItemName, toLoad, nil, 'reload undone')
        -- Too heavy: the rounds weigh the same in the gun as in the pockets, so only someone already carrying more
        -- than they may meets it (whip_core holds a heavier item to the pockets' limit).
        if why == 'Too heavy' then return false, 'You are carrying too much to load it. Put something down first' end
        GunnyWarn('reload: the weapon could not be written, so %d rounds go back to the pockets', toLoad)
        return false, 'Could not reload, the rounds are back in your pockets'
    end

    GunnyDebugPrint('Magless reload complete - loaded', toLoad, 'rounds, total:', meta.ammo)
    GunnyLedgerGun(source, weapon.item, meta.serial, 'reload', currentAmmo, meta.ammo)   -- server/ledger.lua
    return true, { ammo = meta.ammo, loaded = toLoad, countVersion = GunnyCountChanged(source, weaponAddr, meta.serial) }
end)

-- ============================================
-- A SHELL AT A TIME
-- ============================================
--
-- A gun with `loopedReload` (the pump) loads one shell per loop, and the player may stop partway. So
-- nothing is taken when the reload starts: beginLoopedReload says how many may go in, and the client
-- says how many did when it ends. Only those are taken. A reload that never says (a death, a drop, the
-- gun put away) takes nothing, and the gun keeps what it had.

local loopedReloads = {}   -- [source] = { item, serial, pocket, slot, room, ammoItem, at }
local LOOPED_REPORT_MS = 30000

--- Is a shell-at-a-time reload under way on this player's gun in this slot? Its magazine slot waits for it
--- (server/magpanel.lua): the client counts the shells going in, and a change made meanwhile would not be in its count.
---@param source number
---@param slot number
---@param pocket string
---@return boolean
function GunnyLoopedReloadOpen(source, slot, pocket)
    local r = loopedReloads[source]
    return r ~= nil and r.slot == slot and r.pocket == pocket and GetGameTimer() - r.at <= LOOPED_REPORT_MS
end

RegisterGunnyCallback('whip_gunny:beginLoopedReload', { params = { { 'weapon', 'slot', { item = GunnyWeaponItems } } } },
function(source, _, weapon)
    local weaponConfig = Config.GetWeapon(weapon.item)
    if not weaponConfig or not weaponConfig.magless or not weaponConfig.loopedReload then
        return false, 'That weapon is not loaded a shell at a time'
    end
    local meta = weapon.metadata or {}
    local ammoItemName = Config.GetAmmoItemForWeapon(weapon.item)
    if not ammoItemName then return false, 'This weapon has no ammunition set up' end

    local room = weaponConfig.internalCapacity - (meta.ammo or 0)
    if room <= 0 then return false, 'Already fully loaded' end
    local have = exports.whip_core:GetItemCount(source, ammoItemName) or 0
    if have <= 0 then return false, 'No ammunition for this weapon on you' end
    room = math.min(room, have)

    loopedReloads[source] = { item = weapon.item, serial = meta.serial, pocket = weapon.addr.sub,
                              slot = weapon.addr.slot, room = room, ammoItem = ammoItemName, at = GetGameTimer() }
    return true, room
end)

-- The shells that went in. Taken now, as many as are still on the player (some may have left the pockets
-- mid-reload), and never more than the gun has room for.
RegisterGunnyEvent('whip_gunny:server:loopedReloadEnded', {
    rateLimit = 200,
    burst     = 3,   -- an end: never refused for coming close behind the last
    params = { {'loaded', 'int', 0, 250} },
}, function(source, _, loaded)
    local r = loopedReloads[source]
    loopedReloads[source] = nil
    if not r or GetGameTimer() - r.at > LOOPED_REPORT_MS then return end
    loaded = math.min(loaded, r.room)
    if loaded <= 0 then return end

    local addr = GunnyPocket(source, r.pocket, r.slot)
    local sd = GunnyStillThere(addr, r.item, r.serial)
    if not sd then return end
    local weaponConfig = Config.GetWeapon(r.item)
    if not weaponConfig then return end
    local space = weaponConfig.internalCapacity - ((sd.metadata or {}).ammo or 0)
    local have = exports.whip_core:GetItemCount(source, r.ammoItem) or 0
    local take = math.max(0, math.min(loaded, space, have))
    if take > 0 and not exports.whip_core:RemoveItem(source, r.ammoItem, take, nil, { reason = 'loaded into a weapon' }) then
        take = 0
    end

    -- Read again after the take: the slot as it is now, never what was read before it (a shot counted since has lowered
    -- the count, and stays). The take on the pockets does not wait today (their save comes later), but nothing here
    -- depends on that.
    sd = GunnyStillThere(addr, r.item, r.serial)
    if take > 0 and not sd then
        GunnyWarn('looped reload: the weapon moved during the take, so %d rounds go back to the pockets', take)
        GunnyGiveBack(source, r.ammoItem, take, nil, 'reload undone')
        return
    end
    local meta = sd and sd.metadata or {}
    if take > 0 then
        meta.ammo = (meta.ammo or 0) + take
        if not exports.whip_core:SetItemMetadata(addr, meta) then
            GunnyWarn('looped reload: the weapon could not be written, so %d rounds go back to the pockets', take)
            GunnyGiveBack(source, r.ammoItem, take, nil, 'reload undone')
            meta.ammo = meta.ammo - take
            take = 0
        end
    end
    if take < loaded and sd then
        TriggerClientEvent('whip_gunny:client:reloadShort', source, r.slot, r.pocket, meta.ammo or 0)
    end
    GunnyDebugPrint('Looped reload - loaded', take, 'of', loaded, 'shells, total:', meta.ammo)
    if take > 0 then
        GunnyLedgerGun(source, r.item, r.serial, 'reload', (meta.ammo or 0) - take, meta.ammo or 0)   -- server/ledger.lua
    end
end)

AddEventHandler('playerDropped', function() loopedReloads[source] = nil end)
AddEventHandler('whip_core:player:logout', function(e) loopedReloads[e.source] = nil end)
-- Put away mid-reload: the client reports nothing (the gun keeps what it had), and its magazine slot is free again.
AddEventHandler('whip_gunny:weapon:holstered', function(e) loopedReloads[e.source] = nil end)

-- What the player carries for a gun, for Gunny Debug (client/debug.lua): its magazines and their rounds, or loose
-- rounds for a gun with none. Developer mode only, as the overlay is. Answers true and { count, totalAmmo, magless }.
-- Here, not in server/debug.lua, as it counts with this file's bestMagazine.
RegisterGunnyCallback('whip_gunny:countInventoryMags', { ace = 'whip.devtools', params = { { 'weaponName', 'key', 64 } } },
function(source, _, weaponName)
    local weaponConfig = Config.GetWeapon(weaponName)
    if not weaponConfig then return false, 'Not one of gunny\'s weapons' end

    if weaponConfig.magless then
        local ammoItemName = Config.GetAmmoItemForWeapon(weaponName)
        if not ammoItemName then return true, { count = 0, totalAmmo = 0, magless = true } end
        local totalAmmo = exports.whip_core:GetItemCount(source, ammoItemName) or 0
        return true, { count = totalAmmo > 0 and 1 or 0, totalAmmo = totalAmmo, magless = true }
    end

    local _, _, count, totalAmmo = bestMagazine(source, weaponConfig)
    return true, { count = count, totalAmmo = totalAmmo, magless = false }
end)
