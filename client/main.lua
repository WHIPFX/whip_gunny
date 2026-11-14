-- whip_gunny — THE CLIENT'S FOUNDATION
--
-- Asking the server, the drawn weapon, debug lines, and the one per-frame thread every gun-in-hand job runs on.
--
-- Calling whip_core, the one rule in every client file:
--   inside Whip.register (registrations) its exports are called straight: those run only while it is up;
--   so is the per-frame tick, for speed: it runs only with a weapon drawn, and gunny stops with whip_core (its
--   dependency), so the tick never outlives it;
--   so is a call behind Whip.isReady() that answers at once, with no wait between the two (a weapon pack's item
--   settings, below);
--   everything else goes through Whip.core, which answers `false, why` instead of throwing when whip_core is down,
--   and answers a wait even if whip_core stops meanwhile. Its answer is checked wherever a refusal changes what
--   happens next; a close (StopCamera, SetUIOpen false) or a load whose failure the next step already survives
--   needs no check.

--- Ask one of this resource's server callbacks by its full name ('whip_gunny:equipWeapon', server/main.lua), so the
--- name searched for here is the one on the server. Answers what the handler answered, or `false, why` when whip
--- refused the call (too far away, asked too often, no answer). Through Whip.core, so a whip_core stop mid-call
--- answers `false, 'whip_core stopped'` instead of never.
function GunnyCallback(name, ...)
    return Whip.core:Callback(name, ...)
end

--- A pocket slot as one value, for a server handler with whip's 'slot' param: whip_core checks the pocket is the
--- player's, the slot is in range, and what is in it, before the handler runs.
---@param slot number
---@param pocket string|nil  'player' (default) or 'accessory'
---@return table
function GunnySlot(slot, pocket)
    return { sub = pocket or 'player', slot = slot }
end

--- The drawn weapon, nil when none: { slot, pocket, name, hash, serial, config, ammo, metadata, magName,
--- shotsInFlight, countVersion } (client/weapons.lua).
CurrentWeapon = nil

--- Gunny Debug is on in /w (client/debug.lua).
GunnyDebugOn = false

--- Gunny Debug's numbers, written where they happen and only read by the overlay (client/debug.lua), in one place:
--- shot reports sent and answered, the server's last count and when, answers ignored as stale, counts that went up,
--- the last shot and the last reload. /gunnydebugreset zeroes them.
---
--- And the rounds themselves (client/ammo.lua roundsFired), for the ammo ledger (/ammoledger): the frames counted as
--- firing, those in which the ped's rounds did not go down at all (each still charged one), those that went down by
--- more than one report carries (10), the rounds the ped really lost, the rounds charged for them, and what an answer
--- arriving during a reload took off the count the reload gave.
---@class GunnyDebugCounts
---@field lastJump { from: number, to: number, at: number }|nil  the last count that went up (client/shooting.lua)
GunnyDebugCounts = { sent = 0, confirmed = 0, staleIgnored = 0, ammoJumps = 0, lastJump = nil,
                     serverAmmo = nil, serverAmmoAt = nil, lastShotAt = nil, lastReloadAt = nil,
                     firingFrames = 0, noRoundFrames = 0, overTenFrames = 0, gameRounds = 0, chargedRounds = 0,
                     reloadLowered = 0 }

--- A debug line, printed while Gunny Debug is on.
function GunnyDebugPrint(...)
    if GunnyDebugOn then
        print('[GUNNY]', ...)
    end
end

--- Load a model with whip_core's loader (call from a thread): true once it is in, or false, said. Release it with
--- SetModelAsNoLongerNeeded once what needs it is made.
---@return boolean
function GunnyLoadModel(model)
    if HasModelLoaded(model) then return true end
    if type(Whip.core:LoadModel(model, 5000)) == 'number' then return true end
    print('[GUNNY] WARNING: a model did not load: ' .. tostring(model))
    return false
end

--- A notification to this player: 'error' unless said.
function GunnyNotify(msg, kind)
    Whip.core:Notify(msg, kind or 'error')
end

-- A weapon pack's item arriving while whip_core runs: its Items page settings followed here too (shared/catalog.lua
-- follows the rest as whip_core is ready).
GunnyPacks.onChange(function(itemName, _, gone)
    if not gone and Whip.isReady() then Config.FollowItemSettings(nil, itemName) end
end)

-- ============================================
-- THE TICK: one thread for every per-frame job while a weapon is drawn
-- ============================================

local tickFunctions = {}

--- Run `fn(ped, now)` every frame while a weapon is drawn; `ped` and `now` are read once a frame for all of them.
---@param name string
---@param fn fun(ped: number, now: number)
function RegisterGunnyTick(name, fn)
    tickFunctions[name] = fn
end

-- Each job in its own pcall, so one error cannot stop shot counting or the control blocks. Said once per job.
local tickFailed = {}
local ticking = false

--- Start the tick: called the moment a gun is in the hand (DrawWeapon, client/weapons.lua), so its first frame is
--- counted. It ends by itself once nothing is drawn, and the next draw starts it again. A job that put the weapon
--- away ends that frame's pass, as the jobs after it read CurrentWeapon.
function GunnyStartTick()
    if ticking then return end
    ticking = true
    CreateThread(function()
        while CurrentWeapon do
            local ped, now = PlayerPedId(), GetGameTimer()
            for name, fn in pairs(tickFunctions) do
                local ok, err = pcall(fn, ped, now)
                if not ok and not tickFailed[name] then
                    tickFailed[name] = true
                    print(('[whip_gunny] tick "%s" errored: %s'):format(tostring(name), tostring(err)))
                end
                if not CurrentWeapon then break end
            end
            Wait(0)
        end
        ticking = false
    end)
end

-- ============================================
-- EXPORTS
-- ============================================

function IsWeaponDrawn()
    return CurrentWeapon ~= nil
end

--- The drawn weapon as other resources see it, a copy: { item, label, kind, serial, slot, pocket, ammo, capacity,
--- magazine, attachments }, or nil. `magazine` is the magazine item in it (nil: none, or a gun that takes none);
--- `capacity` the most it holds: the magazine's size, a gun with no magazine's own, nil for anything else.
function GetDrawnWeapon()
    local w = CurrentWeapon
    if not w then return nil end
    local attachments = {}
    for category, item in pairs(w.metadata and w.metadata.attachments or {}) do attachments[category] = item end
    local capacity = nil
    if Config.IsFirearm(w.config) then
        if w.config.magless then
            capacity = tonumber(w.config.internalCapacity)
        elseif w.magName then
            local mag = Config.GetMagazine(w.magName)
            capacity = mag and tonumber(mag.capacity) or nil
        end
    end
    return {
        item        = w.name,
        label       = w.config.label,
        kind        = Config.KindOf(w.config),
        serial      = w.serial,
        slot        = w.slot,
        pocket      = w.pocket,
        ammo        = w.ammo or 0,
        capacity    = capacity,
        magazine    = w.magName,
        attachments = attachments,
    }
end

exports('IsWeaponDrawn', IsWeaponDrawn)
exports('GetDrawnWeapon', GetDrawnWeapon)

-- ============================================
-- WHIP_CORE'S MOMENTS
-- ============================================
--
-- whip_core names moments (give mode, something needing the hands) and gunny answers them, so whip_core never needs
-- to know gunny exists. A hook may answer a number of ms for whip_core to wait; gunny needs none, as GunnyHolster
-- itself waits out the holster animation and the server's answer. Through Whip.register: whip_core forgets them when
-- it restarts.

local function RegisterClientWithWhip()
    -- Mid-reload an ordinary holster is refused ('Finish reloading first'), and FreeHands answers false until the
    -- reload ends. With the hands blocked (cuffs: whip_core runs this hook for a block of everything) the gun goes at
    -- once, as whip_core:hands:blocked puts it away in client/weapons.lua, with nothing said.
    local function holsterFirst()
        if not IsWeaponDrawn() then return end
        GunnyHolster(false, GunnyReloadUnderWay() and Whip.core:AreHandsBlocked() == true)
    end

    local ok, why = exports.whip_core:RegisterClientHook('beforeGiveMode', holsterFirst)
    if not ok then print('[GUNNY] could not register the beforeGiveMode hook: ' .. tostring(why)) end

    -- Something else needs the hands (whip_core's FreeHands: the phone coming out).
    ok, why = exports.whip_core:RegisterClientHook('freeHands', holsterFirst)
    if not ok then print('[GUNNY] could not register the freeHands hook: ' .. tostring(why)) end
end

Whip.register(RegisterClientWithWhip)
