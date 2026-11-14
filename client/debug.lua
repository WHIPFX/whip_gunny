-- whip_gunny — GUNNY DEBUG: the drawn weapon's numbers on screen
--
-- Switched from /w (Debug → Gunny Debug, developer mode). While it is on, this game and the server print
-- gunny's GunnyDebugPrint lines too.
--
-- Three kinds of number, each at its own rate:
--   CLIENT     read every frame: the game's clip and gunny's own count.
--   SERVER     pushed after every shot (whip_gunny:client:syncAmmo, client/shooting.lua): live, at no cost.
--   INVENTORY  needs a round trip, so it is asked every 100 frames and its age is shown.
-- Shots SENT against shots CONFIRMED is what shows a shot lost on the way, which no ammo reading can.

local overlayOn = false

-- Slow-polled, needs a server round trip.
local invData, invPolledAt = {}, 0
local isPolling = false

-- The last server-confirmed counts, newest last: a count going backwards or repeating shows here.
local ammoHistory, AMMO_HISTORY_MAX = {}, 12
local lastRecordedServerAmmo = nil

--- The ammo ledger's counters (GunnyDebugCounts, client/main.lua) back to zero.
local function zeroRounds(dbg)
    dbg.firingFrames, dbg.noRoundFrames, dbg.overTenFrames, dbg.gameRounds, dbg.chargedRounds = 0, 0, 0, 0, 0
    dbg.reloadLowered = 0
end

--- Reset the counters, so a test run starts from zero.
RegisterCommand('gunnydebugreset', function()
    if Whip.core:HasDevTools() ~= true then
        GunnyNotify('That needs developer mode on (/w)', 'error')
        return
    end
    local dbg = GunnyDebugCounts   -- client/main.lua
    dbg.sent, dbg.confirmed, dbg.ammoJumps, dbg.staleIgnored = 0, 0, 0, 0
    dbg.lastJump, lastRecordedServerAmmo = nil, nil
    zeroRounds(dbg)
    ammoHistory = {}
    GunnyNotify('Debug counters reset', 'info')
end, false)

-- /ammoledger: where the rounds went, this game's half (the rounds the ped really lost against the rounds charged) in
-- F8, then the server's ledger (server/ledger.lua) in F8 and its console. /ammoledger reset starts both again.
RegisterCommand('ammoledger', function(_, args)
    if Whip.core:HasDevTools() ~= true then
        GunnyNotify('That needs developer mode on (/w)', 'error')
        return
    end
    local dbg = GunnyDebugCounts
    local reset = args[1] == 'reset'
    if reset then
        zeroRounds(dbg)
    else
        print('[GUNNY AMMO] this game:')
        print(('  firing frames %d: %d with no round off the ped (each charged 1), %d with more than 10')
            :format(dbg.firingFrames, dbg.noRoundFrames, dbg.overTenFrames))
        print(('  rounds the ped really lost %d, rounds charged %d (%+d)')
            :format(dbg.gameRounds, dbg.chargedRounds, dbg.chargedRounds - dbg.gameRounds))
        print(('  shot reports sent %d, answered %d; answers during a reload took %d off the reload\'s count')
            :format(dbg.sent, dbg.confirmed, dbg.reloadLowered))
        if not GunnyDebugOn then print('  (Gunny Debug is off in /w: the server keeps no ledger)') end
    end
    TriggerServerEvent('whip_gunny:server:ammoLedger', reset)
end, false)

RegisterNetEvent('whip_gunny:client:ammoLedger', function(lines)
    if type(lines) ~= 'table' then return end
    print('[GUNNY AMMO] the server:')
    for _, line in ipairs(lines) do print('  ' .. tostring(line)) end
    GunnyNotify('Ammo ledger printed in F8', 'info')
end)

local function drawText(x, y, text, scale)
    SetTextFont(4)
    SetTextProportional(false)
    SetTextScale(scale or 0.32, scale or 0.32)
    SetTextColour(255, 255, 255, 255)
    SetTextDropshadow(1, 0, 0, 0, 255)
    SetTextEdge(1, 0, 0, 0, 255)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

--- The slow half: what needs the server.
local function pollInventory()
    if isPolling or not CurrentWeapon then return end
    isPolling = true
    local name = CurrentWeapon.name   -- now: the thread starts a frame later, when the gun may be gone
    CreateThread(function()
        local ok, mags = GunnyCallback('whip_gunny:countInventoryMags', name)
        if ok then invData = mags end
        invPolledAt = GetGameTimer()
        isPolling = false
    end)
end

local function drawFrame(now)
    local dbg         = GunnyDebugCounts   -- client/main.lua
    local ped         = PlayerPedId()
    local hasWeapon   = CurrentWeapon ~= nil
    local trackedAmmo = hasWeapon and (CurrentWeapon.ammo or 0) or 0

    -- GetAmmoInClip answers (found, ammo): two values, so not inline in an and/or.
    local clipAmmo = 0
    if hasWeapon then
        local ok, inClip = GetAmmoInClip(ped, CurrentWeapon.hash)
        clipAmmo = (ok and inClip) or 0
    end

    if dbg.serverAmmo and dbg.serverAmmo ~= lastRecordedServerAmmo then
        lastRecordedServerAmmo = dbg.serverAmmo
        ammoHistory[#ammoHistory + 1] = dbg.serverAmmo
        while #ammoHistory > AMMO_HISTORY_MAX do table.remove(ammoHistory, 1) end
    end

    local x, y, lh = 0.008, 0.26, 0.020
    local function line(text, scale) drawText(x, y, text, scale); y = y + lh end

    line('~y~=== GUNNY DEBUG ===~s~   ~b~/gunnydebugreset~s~ zeroes the counters', 0.36)

    if not hasWeapon then
        line('~o~No weapon equipped~s~')
        return
    end

    line(('~g~%s~s~  slot ~c~%s~s~ (%s)  ~w~%s~s~')
        :format(CurrentWeapon.name, tostring(CurrentWeapon.slot), tostring(CurrentWeapon.pocket),
                CurrentWeapon.serial or '?'))

    -- AMMO: the game's clip, gunny's count, the server's. Game and gunny apart is a different fault from
    -- the server apart.
    y = y + lh * 0.4
    line('~y~AMMO~s~')
    local clipMatches = (clipAmmo == trackedAmmo)
    line(('  game clip   %s%d~s~     tracked  %s%d~s~')
        :format(clipMatches and '~g~' or '~r~', clipAmmo, clipMatches and '~g~' or '~r~', trackedAmmo))

    if dbg.serverAmmo then
        -- Its age is the lag: a number that stops while you fire is the server falling behind.
        local age = now - (dbg.serverAmmoAt or now)
        local ageColor = age < 250 and '~g~' or (age < 1000 and '~y~' or '~r~')
        local agrees   = (dbg.serverAmmo == trackedAmmo)
        line(('  server     %s%d~s~     %s%dms ago~s~   %s')
            :format(agrees and '~g~' or '~r~', dbg.serverAmmo, ageColor, age,
                    agrees and '' or ('~r~DELTA ' .. (dbg.serverAmmo - trackedAmmo) .. '~s~')))
    else
        line('  server     ~o~no confirmation yet~s~')
    end

    if #ammoHistory > 0 then
        line('  ~w~history~s~  ' .. table.concat(ammoHistory, ' '), 0.28)
    end

    -- SHOTS. In flight for a frame or two is normal; staying up means the server is not answering.
    y = y + lh * 0.4
    line('~y~SHOTS~s~')
    local inFlight  = CurrentWeapon.shotsInFlight or 0   -- the drawn gun's own count, which the ammo sync goes by
    local flightColor = inFlight == 0 and '~g~' or (inFlight < 4 and '~y~' or '~r~')
    line(('  sent ~c~%d~s~   confirmed ~c~%d~s~   in flight %s%d~s~'):format(dbg.sent, dbg.confirmed, flightColor, inFlight))
    -- The ped's real rounds against the rounds charged for them (client/ammo.lua roundsFired): apart is a count fault.
    local over = dbg.chargedRounds - dbg.gameRounds
    line(('  game fired ~c~%d~s~   charged %s%d~s~   frames %d, %s%d~s~ with no round')
        :format(dbg.gameRounds, over > 0 and '~r~' or '~g~', dbg.chargedRounds, dbg.firingFrames,
                dbg.noRoundFrames > 0 and '~r~' or '~g~', dbg.noRoundFrames), 0.28)

    if dbg.lastShotAt then
        line(('  last shot ~w~%dms ago~s~'):format(now - dbg.lastShotAt), 0.28)
    end

    -- Stale replies are expected in automatic fire (each reply is a few rounds behind); climbing on single
    -- shots is the problem.
    if dbg.staleIgnored > 0 then
        line(('  ~w~stale replies ignored ~c~%d~s~'):format(dbg.staleIgnored), 0.28)
    end

    y = y + lh * 0.4
    if dbg.ammoJumps > 0 then
        line(('~r~AMMO WENT UP x%d~s~'):format(dbg.ammoJumps))
        if dbg.lastJump then
            line(('  ~r~%d -> %d, %ds ago~s~')
                :format(dbg.lastJump.from, dbg.lastJump.to, math.floor((now - dbg.lastJump.at) / 1000)), 0.28)
        end
    else
        line('~g~no ammo jumps~s~')
    end

    y = y + lh * 0.4
    local pollAge = invPolledAt > 0 and math.floor((now - invPolledAt) / 1000) or -1
    line(('~y~INVENTORY~s~ ~w~(polled, %s)~s~'):format(pollAge >= 0 and (pollAge .. 's ago') or 'never'), 0.28)
    line(('  mags ~c~%d~s~   rounds in them ~c~%d~s~'):format(invData.count or 0, invData.totalAmmo or 0), 0.28)
end

--- On or off: the overlay, and gunny's debug prints here and on the server.
local function setOverlay(on)
    on = on == true
    if on == overlayOn then return end
    overlayOn = on
    GunnyDebugOn = on
    TriggerServerEvent('whip_gunny:server:debug', on)
    if not on then return end
    CreateThread(function()
        local frames = 0
        while overlayOn do
            frames = frames + 1
            if frames >= 100 then frames = 0; pollInventory() end
            drawFrame(GetGameTimer())
            Wait(0)
        end
    end)
end

Whip.register(function()
    local ok, why = exports.whip_core:RegisterDebugTool('gunny', {
        label    = 'Gunny Debug',
        desc     = 'The drawn weapon\'s rounds as the game, gunny and the server count them, the shots sent and confirmed, and the magazines carried. Also prints gunny\'s debug lines.',
        onToggle = setOverlay,
    })
    if not ok then print('[GUNNY] no Gunny Debug in /w: ' .. tostring(why)) end
end)
