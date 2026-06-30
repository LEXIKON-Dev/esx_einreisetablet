local ESX = exports['es_extended']:getSharedObject()

local tabletOpen = false
local isEingereist = false

-- ─── NUI ───────────────────────────────────────────────────────

local function closeTablet()
    if not tabletOpen then return end
    tabletOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function openTablet()
    ESX.TriggerServerCallback('einreisetablet:canOpenTablet', function(canOpen)
        if not canOpen then
            Notify(Locale('no_permission'))
            return
        end

        ESX.TriggerServerCallback('einreisetablet:getDashboard', function(data)
            if not data then return end

            tabletOpen = true
            SetNuiFocus(true, true)
            SendNUIMessage({
                action = 'open',
                data = data,
                config = {
                    zoneRadius = Config.Zone.radius,
                    entryLabel = 'Los Santos',
                    starterMoney = Config.StarterMoney.enabled and Config.StarterMoney.amount or 0,
                    locale = Config.Locale
                }
            })
        end)
    end)
end

RegisterNUICallback('close', function(_, cb)
    closeTablet()
    cb('ok')
end)

RegisterNUICallback('refresh', function(_, cb)
    ESX.TriggerServerCallback('einreisetablet:getDashboard', function(data)
        cb(data or {})
    end)
end)

RegisterNUICallback('saveQuestions', function(data, cb)
    TriggerServerEvent('einreisetablet:saveQuestions', data.questions)
    cb('ok')
end)

RegisterNUICallback('sendQuestions', function(data, cb)
    local targetId = tonumber(data.targetId)
    if targetId then
        TriggerServerEvent('einreisetablet:sendQuestionsToPlayer', targetId)
    end
    cb('ok')
end)

RegisterNUICallback('giveSkin', function(data, cb)
    local targetId = tonumber(data.targetId)
    if targetId then
        TriggerServerEvent('einreisetablet:giveSkin', targetId)
    end
    cb('ok')
end)

RegisterNUICallback('processEntry', function(data, cb)
    local targetId = tonumber(data.targetId)
    if targetId then
        TriggerServerEvent('einreisetablet:processEntry', targetId)
    end
    cb('ok')
end)

RegisterNUICallback('revokeEntry', function(data, cb)
    local targetId = tonumber(data.targetId)
    if targetId then
        TriggerServerEvent('einreisetablet:revokeEntry', targetId)
    end
    cb('ok')
end)

RegisterNUICallback('tpToPlayer', function(data, cb)
    local targetId = tonumber(data.targetId)
    if targetId then
        TriggerServerEvent('einreisetablet:tpToPlayer', targetId)
    end
    cb('ok')
end)

RegisterNUICallback('bringPlayer', function(data, cb)
    local targetId = tonumber(data.targetId)
    if targetId then
        TriggerServerEvent('einreisetablet:bringPlayer', targetId)
    end
    cb('ok')
end)

RegisterNUICallback('freezePlayer', function(data, cb)
    local targetId = tonumber(data.targetId)
    if targetId then
        TriggerServerEvent('einreisetablet:freezePlayer', targetId, data.freeze == true)
    end
    cb('ok')
end)

RegisterNUICallback('saveNote', function(data, cb)
    local targetId = tonumber(data.targetId)
    if targetId and data.note then
        TriggerServerEvent('einreisetablet:saveNote', targetId, data.note)
    end
    cb('ok')
end)

RegisterNUICallback('zoneAnnounce', function(data, cb)
    if data.message then
        TriggerServerEvent('einreisetablet:zoneAnnounce', data.message)
    end
    cb('ok')
end)

RegisterNUICallback('giveStarter', function(data, cb)
    local targetId = tonumber(data.targetId)
    if targetId then
        TriggerServerEvent('einreisetablet:giveStarter', targetId)
    end
    cb('ok')
end)

-- ─── Commands / Keybind ────────────────────────────────────────

RegisterCommand(Config.OpenCommand, function()
    if tabletOpen then
        closeTablet()
    else
        openTablet()
    end
end, false)

if Config.OpenKey then
    RegisterKeyMapping(Config.OpenCommand, 'Einreise Tablet öffnen', 'keyboard', Config.OpenKey)
end

-- ─── Events ────────────────────────────────────────────────────

RegisterNetEvent('einreisetablet:setEntryStatus', function(status)
    isEingereist = status
end)

RegisterNetEvent('einreisetablet:teleportToEntry', function(coords)
    local ped = PlayerPedId()
    DoScreenFadeOut(500)
    Wait(600)
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
    SetEntityHeading(ped, coords.w)
    Wait(300)
    DoScreenFadeIn(500)
end)

RegisterNetEvent('einreisetablet:teleportToZone', function(coords)
    local ped = PlayerPedId()
    DoScreenFadeOut(400)
    Wait(500)
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
    SetEntityHeading(ped, coords.w)
    Wait(300)
    DoScreenFadeIn(400)
end)

RegisterNetEvent('einreisetablet:staffTeleport', function(coords)
    local ped = PlayerPedId()
    DoScreenFadeOut(300)
    Wait(400)
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
    SetEntityHeading(ped, coords.w)
    Wait(200)
    DoScreenFadeIn(300)
end)

RegisterNetEvent('einreisetablet:setFrozen', function(freeze)
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, freeze)
end)

RegisterNetEvent('einreisetablet:zoneMessage', function(message, staffName)
    Notify(Locale('zone_message_prefix', staffName, message))
end)

RegisterNetEvent('einreisetablet:notify', function(msg)
    Notify(msg)
end)

RegisterNetEvent('einreisetablet:showQuestions', function(questions, staffName)
    SendNUIMessage({
        action = 'showApplicantQuestions',
        questions = questions,
        staffName = staffName,
        locale = Config.Locale,
        localeUi = LocaleUI()
    })
    SetNuiFocus(true, true)
end)

RegisterNUICallback('closeApplicantView', function(_, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNetEvent('einreisetablet:createHelpBlip', function(data)
    local blip = AddBlipForCoord(data.x, data.y, data.z)
    SetBlipSprite(blip, Config.HelpMarker.blipSprite)
    SetBlipColour(blip, Config.HelpMarker.blipColor)
    SetBlipScale(blip, 1.0)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(Locale('help_blip_player', data.name))
    EndTextCommandSetBlipName(blip)

    SetTimeout((data.duration or 120) * 1000, function()
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end)
end)

-- ─── Init ──────────────────────────────────────────────────────

CreateThread(function()
    while not ESX.IsPlayerLoaded() do Wait(200) end

    ESX.TriggerServerCallback('einreisetablet:getEntryStatus', function(status)
        isEingereist = status
    end)
end)

-- ESC schließt Tablet
CreateThread(function()
    while true do
        if tabletOpen then
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            if IsControlJustReleased(0, 322) then -- ESC
                closeTablet()
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

-- Export für Zone-Check
exports('IsEingereist', function()
    return isEingereist
end)
