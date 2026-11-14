-- The ammo ledger (Gunny Debug, server): where a loose-round gun's rounds go (a gun with no magazine: the minigun, a
-- revolver). While a player has Gunny Debug on, every round of the drawn gun's ammunition is in one of four places:
--
--   on the ground   the piles of it near the player when the ledger started, and any made since
--   in the pockets  whip_core's own count (GetItemCount)
--   in the gun      its metadata
--   spent           rounds the server took for shots, and rounds the client's count let go (the 5 s sync, the holster)
--
-- A sum that moves and stays moved for a second is printed as LEAK, with the lines before it. Also printed: GUN MOVED
-- (the gun's count changed between gunny's own writes), pockets +/- (whip_core's item events for the rounds) and pile
-- (a pile on the ground that shrank, went or appeared). Moving rounds anywhere else (a stash, a car, another player)
-- reads as a leak: test with the ground, the pockets and the gun only.
--
-- /ammoledger (client/debug.lua) prints it in the console and in F8; /ammoledger reset starts again. Guns with
-- magazines are not followed.

local RANGE   = 60.0   -- metres: the piles counted
local RING    = 40     -- lines kept for the summary
local SETTLE_MS = 1000 -- a sum off for this long is a leak (a pick up or a reload is off for a moment in its middle)

local ledgers = {}   -- [source] = the ledger (newLedger)

local function say(source, L, text)
    print(('[GUNNY AMMO] player %d: %s'):format(source, text))
    L.lines[#L.lines + 1] = ('%7.1fs  %s'):format(GetGameTimer() / 1000, text)
    if #L.lines > RING then table.remove(L.lines, 1) end
end

--- The piles of the ledger's rounds: the ones known, as they are now, and any new one in range. Says each change.
local function groundNow(source, L)
    local total = 0
    for id, was in pairs(L.piles) do
        local row = exports.whip_core:GetGroundItem(id)
        local n = (row and row.item == L.ammo) and (tonumber(row.amount) or 0) or 0
        if n ~= was then
            say(source, L, ('pile #%d %d -> %d'):format(id, was, n))
            L.piles[id] = n
        end
        total = total + n
    end
    local ped = GetPlayerPed(source)
    if ped ~= 0 then
        for _, row in ipairs(exports.whip_core:GetGroundItemsNearby(GetEntityCoords(ped), RANGE) or {}) do
            if row.item == L.ammo and L.piles[row.id] == nil then
                local n = tonumber(row.amount) or 0
                L.piles[row.id] = n
                total = total + n
                if L.sum ~= nil then say(source, L, ('pile #%d appeared with %d'):format(row.id, n)) end
            end
        end
    end
    return total
end

--- The ledger's gun as it is now: its count, or the last one known once it is put away.
local function gunNow(source, L)
    local sd, equipped = GunnyDrawnWeapon(source, true)
    if sd and equipped and sd.item == L.weapon and equipped.serial == L.serial then
        return tonumber((sd.metadata or {}).ammo) or 0
    end
    return L.gun
end

local function newLedger(source, weapon, serial, ammo, rounds)
    local L = {
        ammo = ammo, weapon = weapon, serial = serial, gun = rounds,
        spent = 0, shotRounds = 0, claimed = 0, reports = 0, syncDropped = 0, holsterDropped = 0,
        reloads = 0, loaded = 0, gunMoved = 0, leaked = 0, leaks = 0,
        piles = {}, lines = {}, sum = nil, offSince = nil, startedAt = GetGameTimer(),
        batch = { reports = 0, rounds = 0, claimed = 0, at = GetGameTimer() },
    }
    ledgers[source] = L
    local ground = groundNow(source, L)
    local pockets = exports.whip_core:GetItemCount(source, ammo) or 0
    L.sum = ground + pockets + rounds
    L.start = L.sum
    say(source, L, ('started on %s (%s, serial %s): ground %d + pockets %d + gun %d = %d')
        :format(ammo, weapon, tostring(serial), ground, pockets, rounds, L.sum))
    return L
end

--- Add it all up, and say a sum that has moved and stayed moved.
local function check(source, L, why)
    local ground = groundNow(source, L)
    local pockets = exports.whip_core:GetItemCount(source, L.ammo) or 0
    local gun = gunNow(source, L)
    if gun ~= L.gun then
        say(source, L, ('GUN MOVED %d -> %d (%+d) with no write of gunny\'s (seen at %s)'):format(L.gun, gun, gun - L.gun, why))
        L.gunMoved = L.gunMoved + (gun - L.gun)
        L.gun = gun
    end
    local sum = ground + pockets + gun + L.spent
    if sum == L.sum then L.offSince = nil return end
    local now = GetGameTimer()
    if not L.offSince then L.offSince = now return end
    if now - L.offSince < SETTLE_MS then return end
    say(source, L, ('LEAK %+d: ground %d + pockets %d + gun %d + spent %d = %d, was %d (seen at %s)')
        :format(sum - L.sum, ground, pockets, gun, L.spent, sum, L.sum, why))
    L.leaked = L.leaked + (sum - L.sum)
    L.leaks = L.leaks + 1
    L.sum, L.offSince = sum, nil
end

--- The shots since the last line, as one line (a minigun reports up to ~60 a second).
local function flushShots(source, L)
    local b = L.batch
    if b.reports > 0 then
        say(source, L, ('shots: %d reports, %d rounds taken (claimed %d), gun now %d')
            :format(b.reports, b.rounds, b.claimed, L.gun))
    end
    b.reports, b.rounds, b.claimed, b.at = 0, 0, 0, GetGameTimer()
end

--- The ledger of a player with Gunny Debug on, for this gun, or nil.
local function ledgerFor(source, weapon, serial)
    if not GunnyDebugFor[source] then return nil end
    local L = ledgers[source]
    if L and L.weapon == weapon and L.serial == serial then return L end
    return nil
end

--- A gun drawn (server/weapons.lua): a gun with no magazine starts the ledger, or carries it on (the same gun again).
function GunnyLedgerDrawn(source, weapon, serial, rounds)
    if not GunnyDebugFor[source] then return end
    local cfg = Config.GetWeapon(weapon)
    if not (Config.IsFirearm(cfg) and cfg.magless) then return end
    local ammo = Config.GetAmmoItemForWeapon(weapon)
    if not ammo then return end
    local L = ledgers[source]
    if L and L.weapon == weapon and L.serial == serial then
        if rounds ~= L.gun then
            say(source, L, ('GUN MOVED %d -> %d while put away'):format(L.gun, rounds))
            L.gunMoved = L.gunMoved + (rounds - L.gun)
            L.gun = rounds
        end
        say(source, L, ('drawn again holding %d'):format(rounds))
        check(source, L, 'draw')
        return
    end
    newLedger(source, weapon, serial, ammo, rounds)
end

--- One of gunny's own writes to the drawn gun's count: `kind` 'shot', 'sync', 'holster', 'reload' or 'chamber panel',
--- the count read just before (`before`; nil: the ledger's own, for a write that does not read one) and written
--- (`after`). `claimed`: a shot's rounds as the client reported them.
function GunnyLedgerGun(source, weapon, serial, kind, before, after, claimed)
    local L = ledgerFor(source, weapon, serial)
    if not L then return end
    if before == nil then before = L.gun end
    if before ~= L.gun then
        say(source, L, ('GUN MOVED %d -> %d (%+d) before this %s: written by something else')
            :format(L.gun, before, before - L.gun, kind))
        L.gunMoved = L.gunMoved + (before - L.gun)
    end
    L.gun = after
    local down = before - after
    if kind == 'shot' then
        L.spent, L.shotRounds, L.reports, L.claimed = L.spent + down, L.shotRounds + down, L.reports + 1, L.claimed + (claimed or 0)
        local b = L.batch
        b.reports, b.rounds, b.claimed = b.reports + 1, b.rounds + down, b.claimed + (claimed or 0)
        if GetGameTimer() - b.at >= 1000 then flushShots(source, L) end
        return   -- the second's tick adds it up
    end
    flushShots(source, L)
    if kind == 'sync' then
        L.spent, L.syncDropped = L.spent + down, L.syncDropped + down
        say(source, L, ('the client\'s count let %d go (5 s sync): gun %d -> %d'):format(down, before, after))
    elseif kind == 'holster' then
        L.spent, L.holsterDropped = L.spent + down, L.holsterDropped + down
        say(source, L, ('put away, the client\'s count let %d go: gun %d -> %d'):format(down, before, after))
    elseif kind == 'reload' then
        L.reloads, L.loaded = L.reloads + 1, L.loaded + (after - before)
        say(source, L, ('reload: %d in, gun %d -> %d'):format(after - before, before, after))
    else
        say(source, L, ('%s: gun %d -> %d'):format(kind, before, after))
    end
    check(source, L, kind)
end

-- whip_core's own word on the pockets: every change to the rounds there, and why (its item events).
local function onItem(sign)
    return function(e)
        if type(e) ~= 'table' or not e.source then return end
        local L = GunnyDebugFor[e.source] and ledgers[e.source]
        if not L or e.item ~= L.ammo then return end
        say(e.source, L, ('pockets %s%d (%s%s) = %d'):format(sign, tonumber(e.amount) or 0, e.reason or 'no reason given',
            e.by and (', ' .. e.by) or '', tonumber(e.count) or -1))
    end
end
AddEventHandler('whip_core:item:added', onItem('+'))
AddEventHandler('whip_core:item:removed', onItem('-'))

-- Each second: the shots since the last line, and the sum.
CreateThread(function()
    while true do
        Wait(1000)
        for source, L in pairs(ledgers) do
            if not GunnyDebugFor[source] then
                ledgers[source] = nil
            else
                local ok, err = pcall(function()
                    flushShots(source, L)
                    check(source, L, 'tick')
                end)
                if not ok then print(('[GUNNY AMMO] check failed: %s'):format(tostring(err))) end
            end
        end
    end
end)

AddEventHandler('playerDropped', function() ledgers[source] = nil end)

--- The ledger as lines, for /ammoledger.
local function summary(source)
    local L = ledgers[source]
    if not L then return { 'No ammo ledger: draw a gun with no magazine (the minigun) with Gunny Debug on.' } end
    flushShots(source, L)
    check(source, L, 'summary')
    local ground = 0
    for _, n in pairs(L.piles) do ground = ground + n end
    local pockets = exports.whip_core:GetItemCount(source, L.ammo) or 0
    local out = {
        ('%s for %s (serial %s), %ds'):format(L.ammo, L.weapon, tostring(L.serial), (GetGameTimer() - L.startedAt) // 1000),
        ('now: ground %d + pockets %d + gun %d + spent %d = %d (started at %d)')
            :format(ground, pockets, L.gun, L.spent, ground + pockets + L.gun + L.spent, L.start),
        ('shots: %d reports took %d rounds (the client claimed %d)'):format(L.reports, L.shotRounds, L.claimed),
        ('the client\'s count let go: %d by the 5 s sync, %d at the holster'):format(L.syncDropped, L.holsterDropped),
        ('reloads: %d, %d rounds in'):format(L.reloads, L.loaded),
        ('gun moved with no write of gunny\'s: %+d   leaks: %d, %+d in all'):format(L.gunMoved, L.leaks, L.leaked),
        'last lines:',
    }
    for _, line in ipairs(L.lines) do out[#out + 1] = '  ' .. line end
    return out
end

RegisterGunnyEvent('whip_gunny:server:ammoLedger', {
    ace = 'whip.devtools',
    rateLimit = 1000,
    burst = 2,
    params = { { 'reset', 'bool' } },
}, function(source, _, reset)
    if reset then
        local L = ledgers[source]
        ledgers[source] = nil
        if L then
            local sd, equipped = GunnyDrawnWeapon(source)
            if sd and equipped and sd.item == L.weapon then
                newLedger(source, L.weapon, equipped.serial, L.ammo, tonumber((sd.metadata or {}).ammo) or 0)
            end
        end
        TriggerClientEvent('whip_gunny:client:ammoLedger', source, { 'Ammo ledger started again.' })
        return
    end
    local lines = summary(source)
    for _, line in ipairs(lines) do print(('[GUNNY AMMO] player %d: %s'):format(source, line)) end
    TriggerClientEvent('whip_gunny:client:ammoLedger', source, lines)
end)
