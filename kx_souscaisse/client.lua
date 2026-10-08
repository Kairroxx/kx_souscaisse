local hiding = nil
local busy = false

local function notify(key, kind)
    local msg = Config.Messages[key]
    if type(msg) == 'table' then msg = msg[math.random(#msg)] end
    lib.notify({
        title = Config.NotifyTitle,
        description = msg,
        type = kind or 'inform',
        icon = Config.NotifyIcon,
        position = Config.NotifyPosition,
    })
end

local function clamp(v, a, b) return math.max(a, math.min(b, v)) end
local function lerp(a, b, t) return a + (b - a) * t end
local function ease(t) return t < 0.5 and 2 * t * t or 1 - (-2 * t + 2) ^ 2 / 2 end

local function probe(from, to, flags, ignore)
    local h = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z, flags, ignore or 0, 7)
    local _, hit, pos, _, ent = GetShapeTestResult(h)
    return hit == 1, pos, ent
end

local function capsule(from, to, radius, flags, ignore)
    local h = StartShapeTestCapsule(from.x, from.y, from.z, to.x, to.y, to.z, radius, flags, ignore or 0, 7)
    local status, hit, pos
    repeat
        status, hit, pos = GetShapeTestResult(h)
        if status == 1 then Wait(0) end
    until status ~= 1
    return hit == 1, pos
end

local function dims(veh)
    local min, max = GetModelDimensions(GetEntityModel(veh))
    return math.max(math.abs(min.x), math.abs(max.x)), (min.y + max.y) / 2, min, max
end

local function engineOn(veh) return GetIsVehicleEngineRunning(veh) end

local function basicChecks(veh)
    if not DoesEntityExist(veh) then return false end
    if Config.BlacklistedClasses[GetVehicleClass(veh)] then return false, 'notAllowed' end
    if GetEntitySpeed(veh) > Config.MaxSpeed then return false, 'moving' end
    if Config.RequireEngineOff and engineOn(veh) then return false, 'engineOn' end
    if Entity(veh).state.bw_souscaisse_occupe then return false, 'occupied' end
    return true
end

-- garde au sol (3 points)
local function measureClearance(veh)
    local _, cy, min, max = dims(veh)
    local len = max.y - min.y
    local lowest, groundZ
    for _, f in ipairs({ 0.0, 0.25, -0.25 }) do
        local top = GetOffsetFromEntityInWorldCoords(veh, 0.0, cy + f * len, 0.0)
        local hitG, ground = probe(top, top - vector3(0.0, 0.0, 4.0), 1 | 16, veh)
        if not hitG then return nil end
        if f == 0.0 then groundZ = ground.z end
        local start = vector3(top.x, top.y, ground.z + 0.02)
        local hitV, under, ent = probe(start, top, 2, PlayerPedId())
        local c = (hitV and ent == veh) and (under.z - ground.z) or (top.z - ground.z)
        if not lowest or c < lowest then lowest = c end
    end
    return lowest, groundZ
end

-- côté de sortie le plus libre
local function bestExitSide(veh)
    local halfW, cy = dims(veh)
    local h = hiding
    local baseZ = h and (GetOffsetFromEntityInWorldCoords(veh, 0.0, 0.0, h.oz - Config.PedGroundOffset).z) or GetEntityCoords(veh).z
    local best, bestDist, bestFree = 1, -1, false
    for _, side in ipairs({ h and h.side or 1, h and -h.side or -1 }) do
        local from = GetOffsetFromEntityInWorldCoords(veh, side * halfW * 0.6, cy, 0.0)
        local to = GetOffsetFromEntityInWorldCoords(veh, side * (halfW + Config.ExitDistance), cy, 0.0)
        from = vector3(from.x, from.y, baseZ + 0.5)
        to = vector3(to.x, to.y, baseZ + 0.5)
        local total = #(to - from)
        local hit, pos = capsule(from, to, 0.3, 1 | 2 | 16, veh)
        if not hit then
            for _, other in ipairs(GetGamePool('CPed')) do
                if other ~= PlayerPedId() and not IsPedInAnyVehicle(other, true)
                    and #(GetEntityCoords(other).xy - to.xy) < 0.7 then
                    hit, pos = true, GetEntityCoords(other)
                    break
                end
            end
        end
        local dist = hit and #(pos - from) or total
        local okGround, g = probe(to, to - vector3(0.0, 0.0, 3.0), 1 | 16, veh)
        if not okGround or math.abs(g.z - baseZ) > 1.0 then dist = dist * 0.3 end
        local free = (not hit) and okGround and math.abs(g.z - baseZ) <= 1.0
        if free and not bestFree then
            best, bestDist, bestFree = side, dist, true
        elseif free == bestFree and dist > bestDist then
            best, bestDist = side, dist
        end
    end
    return best, bestFree
end

local function attach(ped, veh, x, y, z, rot)
    AttachEntityToEntity(ped, veh, 0, x, y, z, 0.0, 0.0, rot, false, false, false, true, 2, true)
end

local function slide(ped, veh, fromX, toX, ms)
    local h = hiding
    local t0 = GetGameTimer()
    while true do
        if not DoesEntityExist(veh) then return false end
        local t = clamp((GetGameTimer() - t0) / ms, 0.0, 1.0)
        attach(ped, veh, lerp(fromX, toX, ease(t)), h.cy, h.oz, h.rot)
        if t >= 1.0 then return true end
        Wait(0)
    end
end

local function loadDict(dict)
    if not dict or not DoesAnimDictExist(dict) then
        if dict then print(('[bw_souscaisse] anim introuvable : %s'):format(dict)) end
        return false
    end
    return pcall(lib.requestAnimDict, dict)
end

local function playAnim(ped, dict, name, flag, blend)
    if not loadDict(dict) then return 0 end
    local dur = math.floor(GetAnimDuration(dict, name) * 1000)
    TaskPlayAnim(ped, dict, name, blend or 8.0, -8.0, -1, flag, 0.0, false, false, false)
    RemoveAnimDict(dict)
    return dur
end

local function startCam()
    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamFov(cam, Config.Camera.Fov)
    RenderScriptCams(true, true, 600, true, false)
    hiding.cam, hiding.camYaw, hiding.camPitch = cam, 0.0, 4.0
end

local function updateCam()
    local h = hiding
    if not h or not h.cam then return end
    local c = Config.Camera
    h.camYaw = clamp(h.camYaw - GetDisabledControlNormal(0, 1) * c.Sensitivity, -c.MaxYaw, c.MaxYaw)
    h.camPitch = clamp(h.camPitch - GetDisabledControlNormal(0, 2) * c.Sensitivity, c.MinPitch, c.MaxPitch)
    local pos = GetOffsetFromEntityInWorldCoords(h.veh, h.side * h.halfW * c.SideFactor, h.cy,
        h.oz - Config.PedGroundOffset + c.Height)
    local baseYaw = GetEntityHeading(h.veh) + (h.side == 1 and -90.0 or 90.0)
    SetCamCoord(h.cam, pos.x, pos.y, pos.z)
    SetCamRot(h.cam, h.camPitch, 0.0, baseYaw + h.camYaw, 2)
end

local function stopCam()
    if hiding and hiding.cam then
        RenderScriptCams(false, true, 600, true, false)
        DestroyCam(hiding.cam, false)
        hiding.cam = nil
    end
end

local function cleanup()
    stopCam()
    lib.hideTextUI()
    TriggerServerEvent('bw_souscaisse:release')
    hiding = nil
    busy = false
end

local function leave(reason)
    local h = hiding
    if not h or (busy and reason == 'normal') then return end
    local ped = PlayerPedId()
    local veh = h.veh

    if reason == 'gone' or not DoesEntityExist(veh) then
        DetachEntity(ped, true, false)
        ClearPedTasks(ped)
        cleanup()
        notify('gone', 'warning')
        return
    end

    if reason == 'eject' then
        busy = true
        local side = bestExitSide(veh)
        local out = GetOffsetFromEntityInWorldCoords(veh, side * (h.halfW + Config.StandOffset + 0.3), h.cy, h.oz)
        DetachEntity(ped, true, false)
        FreezeEntityPosition(ped, false)
        SetEntityCoords(ped, out.x, out.y, out.z, false, false, false, false)
        ClearPedTasksImmediately(ped)
        SetPedToRagdoll(ped, Config.EjectRagdoll, Config.EjectRagdoll, 0, false, false, false)
        local dir = out - GetEntityCoords(veh)
        dir = vector3(dir.x, dir.y, 0.0)
        dir = dir / math.max(#dir, 0.01)
        ApplyForceToEntity(ped, 1, dir.x * Config.EjectForce, dir.y * Config.EjectForce, 1.0, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
        if Config.EjectDamage > 0 then
            SetEntityHealth(ped, math.max(101, GetEntityHealth(ped) - Config.EjectDamage))
        end
        cleanup()
        notify('ejected', 'error')
        return
    end

    local side, free = bestExitSide(veh)
    if not free then return notify('blocked', 'warning') end
    busy = true
    lib.hideTextUI()

    local depthX = h.side * Config.HideDepth
    if side ~= h.side then
        h.side, h.rot = side, (side == 1 and -90.0 or 90.0) + (Config.Anims.BaseRotOffset or 0.0)
        depthX = side * Config.HideDepth
        attach(ped, veh, depthX, h.cy, h.oz, h.rot)
    end

    stopCam()
    if not slide(ped, veh, depthX, side * (h.halfW + Config.StandOffset), Config.SlideOutTime) then
        return leave('gone')
    end

    -- on détache seulement une fois debout
    local exitMs = playAnim(ped, Config.Anims.dictExit, Config.Anims.exit, 2, 8.0)
    Wait(math.max(0, exitMs - 50))
    local p = GetOffsetFromEntityInWorldCoords(veh, side * (h.halfW + Config.StandOffset), h.cy, h.oz)
    DetachEntity(ped, false, false)
    SetEntityCoordsNoOffset(ped, p.x, p.y, p.z, false, false, false)
    SetEntityHeading(ped, GetEntityHeading(veh) + h.rot)
    StopAnimTask(ped, Config.Anims.dictExit, Config.Anims.exit, 2.0)
    cleanup()
    notify('leave', 'success')
end

local function runLoops()
    CreateThread(function()
        while hiding do
            DisableAllControlActions(0)
            EnableControlAction(0, 245, true) -- chat
            EnableControlAction(0, 249, true) -- push-to-talk
            EnableControlAction(0, 199, true) -- pause
            EnableControlAction(0, 200, true)
            if not hiding.cam then
                EnableControlAction(0, 1, true)
                EnableControlAction(0, 2, true)
            end
            if hiding.cam then
                updateCam()
                if Config.Camera.HideOwnPed then SetEntityLocallyInvisible(PlayerPedId()) end
            end
            if not busy and not hiding.exiting and IsDisabledControlJustPressed(0, Config.ExitKey) then
                hiding.exiting = true
                CreateThread(function()
                    leave('normal')
                    if hiding then hiding.exiting = false end
                end)
            end
            Wait(0)
        end
    end)

    CreateThread(function()
        while hiding do
            local h = hiding
            local ped = PlayerPedId()
            if not DoesEntityExist(h.veh) then leave('gone') break end
            if IsEntityDead(ped) then
                DetachEntity(ped, true, false)
                cleanup()
                break
            end
            if engineOn(h.veh) or GetEntitySpeed(h.veh) > Config.EjectSpeed then
                leave('eject')
                break
            end
            if not busy and not IsEntityPlayingAnim(ped, Config.Anims.dictBase, Config.Anims.base, 3) then
                playAnim(ped, Config.Anims.dictBase, Config.Anims.base, 1)
            end
            Wait(Config.WatchInterval)
        end
    end)
end

local function hide(veh)
    if hiding or busy then return end
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, true) then return notify('inVehicle', 'error') end

    local ok, why = basicChecks(veh)
    if not ok then return notify(why or 'cantUse', 'error') end

    local clearance, groundZ = measureClearance(veh)
    if not clearance then return notify('noGround', 'error') end
    if clearance < Config.MinClearance then return notify('tooLow', 'error') end

    if not NetworkGetEntityIsNetworked(veh) then NetworkRegisterEntityAsNetworked(veh) end
    if not NetworkGetEntityIsNetworked(veh) then return notify('cantUse', 'error') end

    busy = true
    if not lib.callback.await('bw_souscaisse:claim', false, VehToNet(veh)) then
        busy = false
        return notify('occupied', 'error')
    end

    local halfW, cy = dims(veh)
    cy = cy + Config.HideOffsetY
    local rel = GetOffsetFromEntityGivenWorldCoords(veh, GetEntityCoords(ped))
    local side = rel.x >= 0 and 1 or -1
    local rot = side == 1 and -90.0 or 90.0
    local oz = (groundZ + Config.PedGroundOffset) - GetEntityCoords(veh).z

    hiding = { veh = veh, side = side, rot = rot, halfW = halfW, cy = cy, oz = oz }

    local stand = GetOffsetFromEntityInWorldCoords(veh, side * (halfW + Config.StandOffset), cy, 0.0)
    local heading = GetEntityHeading(veh) + rot
    TaskGoStraightToCoord(ped, stand.x, stand.y, groundZ + 1.0, 1.0, 3000, heading, 0.1)
    local t0 = GetGameTimer()
    while #(GetEntityCoords(ped).xy - stand.xy) > 0.25 and GetGameTimer() - t0 < 3000 do Wait(0) end
    SetEntityHeading(ped, heading)

    local standX = side * (halfW + Config.StandOffset)
    local here = GetOffsetFromEntityGivenWorldCoords(veh, GetEntityCoords(ped))
    attach(ped, veh, here.x, here.y, oz, rot)

    local A = Config.Anims
    local function settle(t)
        local e = ease(math.min(1.0, t * 2.0))
        attach(ped, veh, lerp(here.x, standX, e), lerp(here.y, cy, e), oz, rot)
        if not DoesEntityExist(veh) then return false end
    end
    if A.dictEnter then
        local ms = playAnim(ped, A.dictEnter, A.enter, 2, 8.0)
        local t0 = GetGameTimer()
        while GetGameTimer() - t0 < ms - 150 do settle((GetGameTimer() - t0) / math.max(ms, 1)) Wait(0) end
    end
    settle(1.0)

    if not DoesEntityExist(veh) or engineOn(veh) or GetEntitySpeed(veh) > Config.EjectSpeed then
        DetachEntity(ped, false, false)
        ClearPedTasks(ped)
        cleanup()
        return notify('moving', 'error')
    end

    rot = rot + (A.BaseRotOffset or 0.0)
    hiding.rot = rot
    attach(ped, veh, standX, cy, oz, rot)
    playAnim(ped, A.dictBase, A.base, 1, 1000.0)
    if not slide(ped, veh, side * (halfW + Config.StandOffset), side * Config.HideDepth, Config.SlideInTime) then
        return leave('gone')
    end

    startCam()
    lib.showTextUI(Config.TextUI, { position = 'right-center', icon = 'car-side' })
    notify('hidden', 'success')
    busy = false
    runLoops()
end

exports.ox_target:addGlobalVehicle({
    {
        name = 'bw_souscaisse:hide',
        icon = Config.TargetIcon,
        label = Config.TargetLabel,
        distance = Config.TargetDistance,
        canInteract = function(entity)
            if hiding or busy then return false end
            if IsPedInAnyVehicle(PlayerPedId(), true) then return false end
            if Config.BlacklistedClasses[GetVehicleClass(entity)] then return false end
            return not Entity(entity).state.bw_souscaisse_occupe
        end,
        onSelect = function(data)
            hide(data.entity)
        end,
    },
})

exports('IsHidden', function() return hiding ~= nil end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() or not hiding then return end
    local ped = PlayerPedId()
    DetachEntity(ped, true, false)
    FreezeEntityPosition(ped, false)
    ClearPedTasksImmediately(ped)
    stopCam()
    lib.hideTextUI()
end)