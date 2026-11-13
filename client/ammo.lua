-- whip_gunny — AMMUNITION, and the one place it is written
--
-- One number lives in four places: the ped's clip (SetAmmoInClip), the ped's total (SetPedAmmo),
-- CurrentWeapon.ammo, and the weapon's metadata on the server (the authoritative copy). Write the
-- ped's ammunition only through this file so they can't disagree.
--
-- The rule: SetPedAmmo sets the TOTAL, not the reserve (reserve = total - clip). Write the total
-- before the clip, or SetPedAmmo overwrites the clip. Gunny keeps no reserve (magazines are items),
-- so total and clip are the same number; only playReloadAnimation briefly creates one, and a
-- shell-at-a-time reload keeps one while it plays (below).

GunnyAmmo = {}

--- Set what the weapon holds, everywhere at once: the ped's total, its clip, and the tracked count.
---@param rounds number
function GunnyAmmo.set(rounds)
    if not CurrentWeapon then return end

    rounds = math.max(0, math.floor(tonumber(rounds) or 0))
    local ped = PlayerPedId()
    local hash = CurrentWeapon.hash

    -- Only when the ped holds something else. Every shot comes here after the game has already counted the
    -- round, and SetPedAmmo knocks out the clip that SetAmmoInClip then has to put back: no rewrite every shot.
    -- (GetAmmoInClip answers (found, ammo): the count is the second value.)
    local _, clip = GetAmmoInClip(ped, hash)
    if GetAmmoInPedWeapon(ped, hash) ~= rounds or clip ~= rounds then
        SetPedAmmo(ped, hash, rounds)      -- total FIRST
        SetAmmoInClip(ped, hash, rounds)   -- then the clip out of it
    end

    CurrentWeapon.ammo = rounds
    -- What the ped holds now, as the game took it. The game keeps no more than its most for the weapon (250 for every gun
    -- at the default shooting skill), so a minigun holding 3000 has 250 on the ped, topped up after every shot. Its shots
    -- are counted from this (roundsFired), never from `rounds`.
    CurrentWeapon.pedAmmo = GetAmmoInPedWeapon(ped, hash)
end

--- Spend rounds, clamped at zero.
---@param n number|nil  defaults to 1
function GunnyAmmo.spend(n)
    if not CurrentWeapon then return end
    GunnyAmmo.set((CurrentWeapon.ammo or 0) - (n or 1))
end

--- What whip_gunny believes the weapon holds.
---@return number
function GunnyAmmo.count()
    return CurrentWeapon and CurrentWeapon.ammo or 0
end

-- Borrowed reload animations under way (below): while any is, the ped's ammunition is not its real count. A number:
-- two can overlap (the magazine slot changed during an ammo check).
local borrowing = 0

--- The rounds GTA took in a frame the ped shot: what the ped held after gunny last set it, against what it holds now.
--- At least one (the frame fired), at most 10 (one report, server/shooting.lua). GTA can fire more than one round in a
--- frame (a minigun at a low frame rate): counted as one, the rest would be free, as GunnyAmmo.set puts the count back
--- on the ped. Never from the tracked count: past the game's most (GunnyAmmo.set) the ped holds less than it, and every
--- frame of fire would be charged 10. While a borrowed animation holds the ped's ammunition, one.
---@param ped number
---@return integer
function GunnyAmmo.roundsFired(ped)
    local dbg = GunnyDebugCounts   -- the ammo ledger's numbers (client/main.lua)
    dbg.firingFrames = dbg.firingFrames + 1
    if borrowing > 0 or not CurrentWeapon then
        dbg.chargedRounds = dbg.chargedRounds + 1
        return 1
    end
    local held = CurrentWeapon.pedAmmo or CurrentWeapon.ammo or 0
    local spent = held - GetAmmoInPedWeapon(ped, CurrentWeapon.hash)
    local rounds = math.max(1, math.min(spent, 10))
    if spent <= 0 then dbg.noRoundFrames = dbg.noRoundFrames + 1 else dbg.gameRounds = dbg.gameRounds + spent end
    if spent > 10 then dbg.overTenFrames = dbg.overTenFrames + 1 end
    dbg.chargedRounds = dbg.chargedRounds + rounds
    return rounds
end

--- A drawn throwable's stack: the ped's count of it, and the tracked one. A stack has no clip.
---@param count number
function GunnyAmmo.setStack(count)
    if not CurrentWeapon then return end
    count = math.max(0, math.floor(tonumber(count) or 0))
    SetPedAmmo(PlayerPedId(), CurrentWeapon.hash, count)
    CurrentWeapon.ammo = count
end

-- ============================================
-- THE RELOAD ANIMATION
-- ============================================
--
-- The engine only plays a reload with ammunition to reload from, and gunny keeps the reserve empty.
-- So every reload-style animation (reloads, magazine in/out, chamber, check ammo) briefly gives the
-- ped a fake reserve, asks the engine to reload, and takes it back. Always through here.

local FAKE_RESERVE   = 100   -- enough for the engine to agree there is something to load
local SETTLE_MS      = 100   -- time for the reload task to actually take hold
local ANIM_TIMEOUT_MS = 10000

--- Play the engine's reload animation, then leave the weapon holding CurrentWeapon.ammo: set it first. Read as the
--- animation ends, not as it starts, so a count the server sent meanwhile (the magazine slot changed mid-reload) is the
--- one the gun is left with.
---
--- Blocks until the animation ends when `waitForEnd` is set; check-ammo and panel inserts skip it.
---
---@param opts table
---   waitForEnd  boolean?  wait for the animation to actually end (default false)
---   settleMs    number?   override the settle delay
---   onSettled   function? runs once the task has taken hold, before the wait
---   minMs       number?   return no sooner than this after the start (a seat may play no animation)
function GunnyAmmo.playReloadAnimation(opts)
    if not CurrentWeapon then return end
    GunnyEndDrawAnim(PlayerPedId())   -- or the draw's animation ending later restarts this one
    if not CurrentWeapon then return end

    opts = opts or {}
    local startedAt = GetGameTimer()
    local ped   = PlayerPedId()
    local hash  = CurrentWeapon.hash

    -- Empty clip + a reserve is the state the engine reloads from.
    borrowing = borrowing + 1
    SetPedAmmo(ped, hash, FAKE_RESERVE)
    SetAmmoInClip(ped, hash, 0)
    MakePedReload(ped)

    Wait(opts.settleMs or SETTLE_MS)

    -- Remove the fake reserve as soon as the task has hold, so the player never has ammo we didn't give.
    SetPedAmmo(ped, hash, 0)
    SetAmmoInClip(ped, hash, 0)

    if opts.onSettled then
        local ok, err = pcall(opts.onSettled)
        if not ok then
            print(('[GUNNY] reload animation onSettled failed: %s'):format(tostring(err)))
        end
    end

    if opts.waitForEnd then
        local elapsed = 0
        while IsPedReloading(ped) and elapsed < ANIM_TIMEOUT_MS do
            Wait(50)
            elapsed = elapsed + 50
        end
        GunnyDebugPrint('Reload animation finished after', elapsed + (opts.settleMs or SETTLE_MS), 'ms')
    end

    if opts.minMs then
        local left = opts.minMs - (GetGameTimer() - startedAt)
        if left > 0 then Wait(left) end
    end

    borrowing = borrowing - 1
    -- The weapon can be gone by now — death, holster, a resource restart during the wait.
    if not CurrentWeapon then return end

    GunnyAmmo.set(CurrentWeapon.ammo)
end

-- ============================================
-- A SHELL AT A TIME
-- ============================================
--
-- A gun with `loopedReload` (the pump) loads one shell per loop from the reserve, and the player can
-- stop partway by firing or running. So here the reserve is real: the shells that may go in, kept for
-- the whole reload, with the clip starting at what the gun holds. When it ends, total - clip is the
-- shells that did NOT go in; a shot in that same frame lowers both, so the count holds either way.

local LOOPED_SETTLE_MS  = 1000    -- the game's reload not begun by then: it played none, and the gun is filled
local LOOPED_STALL_MS   = 4000    -- reloading, but no shell in for this long: the game is stuck, and it is ended
local LOOPED_TIMEOUT_MS = 15000

local looped = nil   -- while one plays: { hash, room, full, at, seen, clip, movedAt }

--- Start a shell-at-a-time reload: up to `room` shells on top of what the gun holds now.
---@param room number
function GunnyAmmo.startLoopedReload(room)
    if not CurrentWeapon then return end
    GunnyEndDrawAnim(PlayerPedId())   -- as playReloadAnimation
    if not CurrentWeapon then return end
    local ped, hash = PlayerPedId(), CurrentWeapon.hash
    local now = GunnyAmmo.count()
    local at = GetGameTimer()
    looped = { hash = hash, room = room, full = now + room, at = at, seen = false, clip = now, movedAt = at }
    SetPedAmmo(ped, hash, now + room)   -- total FIRST: the shells to load are the reserve
    SetAmmoInClip(ped, hash, now)
    MakePedReload(ped)
end

--- Is one playing?
function GunnyAmmo.loopedReloading()
    return looped ~= nil
end

--- Every frame while one plays (client/reload.lua). In the frame it ends (the game's reload over, a shot
--- that cut it short, or the time out), the reserve goes and the gun holds what was loaded.
---@return number|nil loaded  shells that went in, in the frame it ended
---@return boolean|nil cutShort  fewer than room
---@return boolean|nil timedOut
function GunnyAmmo.loopedReloadFrame(ped, now)
    local l = looped
    if not l then return nil end
    if not CurrentWeapon or CurrentWeapon.hash ~= l.hash then looped = nil; return nil end
    local reloading = IsPedReloading(ped)
    local _, clipNow = GetAmmoInClip(ped, l.hash)
    if reloading then l.seen = true end
    if clipNow ~= l.clip then l.clip, l.movedAt = clipNow, now end
    local waited = now - l.at
    local stalled = reloading and now - l.movedAt >= LOOPED_STALL_MS
    local timedOut = waited >= LOOPED_TIMEOUT_MS or stalled
    local shooting = IsPedShooting(ped)
    if not timedOut and not shooting and (reloading or (not l.seen and waited < LOOPED_SETTLE_MS)) then
        return nil
    end
    looped = nil
    local loaded = l.room
    if l.seen then
        local notLoaded = math.max(0, GetAmmoInPedWeapon(ped, l.hash) - clipNow)
        loaded = math.max(0, l.room - notLoaded)
    end
    -- The shot that cut it short has left the clip already; shooting.lua spends it from this count.
    GunnyAmmo.set(l.full - l.room + loaded)
    return loaded, loaded < l.room, timedOut
end

--- Stop following one: the gun went away mid-reload, and it took the reserve with it.
function GunnyAmmo.dropLoopedReload()
    looped = nil
end

--- End a borrowed reload animation and put the gun back in the hand. Seated, or getting into a seat, no task is
--- cleared: the seat is the ped's task, and clearing it would stop them getting in.
---@param ped number
---@param inCover boolean|nil  as it was when the animation started; nil reads it now
function GunnyAmmo.endAnimation(ped, inCover)
    if not CurrentWeapon then return end
    if not IsPedInAnyVehicle(ped, false) and not IsPedGettingIntoAVehicle(ped) then
        if inCover == nil then inCover = IsPedInCover(ped, false) end
        if inCover then ClearPedSecondaryTask(ped) else ClearPedTasks(ped) end
    end
    SetCurrentPedWeapon(ped, CurrentWeapon.hash, true)
end
