local ESX = exports['es_extended']:getSharedObject()

local isEingereist = false
local lastReturnTime = 0

RegisterNetEvent('einreisetablet:setEntryStatus', function(status)
    isEingereist = status
end)

CreateThread(function()
    while not ESX.IsPlayerLoaded() do Wait(200) end

    ESX.TriggerServerCallback('einreisetablet:getEntryStatus', function(status)
        isEingereist = status
    end)
end)

local function teleportBack()
    local now = GetGameTimer()
    if now - lastReturnTime < 3000 then return end
    lastReturnTime = now

    local coords = Config.Zone.returnCoords
    local ped = PlayerPedId()

    if Config.RemoveWeaponsOnZoneReturn then
        RemoveAllPedWeapons(ped, true)
    end

    Notify(Locale('zone_return'))

    DoScreenFadeOut(300)
    Wait(400)
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
    SetEntityHeading(ped, coords.w)
    Wait(200)
    DoScreenFadeIn(300)
end

CreateThread(function()
    local zone = Config.Zone

    while true do
        local sleep = 1500

        if not isEingereist then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local dist = #(coords - zone.center)

            if Config.ShowZoneBoundary then
                sleep = 0
                DrawMarker(
                    1,
                    zone.center.x, zone.center.y, zone.center.z - 50.0,
                    0.0, 0.0, 0.0,
                    0.0, 0.0, 0.0,
                    zone.radius * 2.0, zone.radius * 2.0, 100.0,
                    255, 50, 50, 30,
                    false, false, 2, false, nil, nil, false
                )
            end

            if dist > zone.radius then
                sleep = 0
                teleportBack()
            else
                sleep = 500
            end
        end

        Wait(sleep)
    end
end)
