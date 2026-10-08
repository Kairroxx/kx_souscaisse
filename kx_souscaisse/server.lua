-- netId -> source / source -> netId
local byNet, bySrc = {}, {}

local function release(src)
    local netId = bySrc[src]
    if not netId then return end
    bySrc[src], byNet[netId] = nil, nil
    local veh = NetworkGetEntityFromNetworkId(netId)
    if veh ~= 0 and DoesEntityExist(veh) then
        Entity(veh).state:set('bw_souscaisse_occupe', nil, true)
    end
    Player(src).state:set('bw_souscaisse', nil, true)
end

lib.callback.register('bw_souscaisse:claim', function(src, netId)
    if type(netId) ~= 'number' then return false end
    if bySrc[src] then release(src) end

    local veh = NetworkGetEntityFromNetworkId(netId)
    if veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then return false end

    local ped = GetPlayerPed(src)
    if #(GetEntityCoords(ped) - GetEntityCoords(veh)) > 8.0 then return false end

    local holder = byNet[netId]
    if holder and GetPlayerName(holder) then return false end

    byNet[netId], bySrc[src] = src, netId
    Entity(veh).state:set('bw_souscaisse_occupe', src, true)
    Player(src).state:set('bw_souscaisse', netId, true)
    return true
end)

RegisterNetEvent('bw_souscaisse:release', function()
    release(source)
end)

AddEventHandler('playerDropped', function()
    release(source)
end)

AddEventHandler('entityRemoved', function(entity)
    if GetEntityType(entity) ~= 2 then return end
    local netId = NetworkGetNetworkIdFromEntity(entity)
    local src = byNet[netId]
    if src then
        bySrc[src], byNet[netId] = nil, nil
        Player(src).state:set('bw_souscaisse', nil, true)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for src in pairs(bySrc) do release(src) end
end)

-- exports.bw_souscaisse:IsHidden(src) -> bool, netId
exports('IsHidden', function(src)
    return bySrc[src] ~= nil, bySrc[src]
end)