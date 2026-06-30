local ESX = exports['es_extended']:getSharedObject()
local helpBlip = nil

CreateThread(function()
    local marker = Config.HelpMarker

    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local dist = #(coords - marker.coords)

        if dist < marker.drawDistance then
            sleep = 0

            DrawMarker(
                marker.type,
                marker.coords.x, marker.coords.y, marker.coords.z - 1.0,
                0.0, 0.0, 0.0,
                0.0, 0.0, 0.0,
                marker.scale.x, marker.scale.y, marker.scale.z,
                marker.color.r, marker.color.g, marker.color.b, marker.color.a,
                false, true, 2, false, nil, nil, false
            )

            if dist < marker.interactDistance then
                ESX.ShowHelpNotification(Locale('help_marker_prompt'))

                if IsControlJustReleased(0, 38) then -- E
                    TriggerServerEvent('einreisetablet:requestHelp')
                    Wait(500)
                end
            end
        end

        Wait(sleep)
    end
end)

-- Permanenter Blip am Hilfe-Marker (optional sichtbar für alle)
CreateThread(function()
    local marker = Config.HelpMarker
    helpBlip = AddBlipForCoord(marker.coords.x, marker.coords.y, marker.coords.z)
    SetBlipSprite(helpBlip, 480)
    SetBlipColour(helpBlip, 3)
    SetBlipScale(helpBlip, 0.7)
    SetBlipAsShortRange(helpBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(Locale('help_blip_name'))
    EndTextCommandSetBlipName(helpBlip)
end)
