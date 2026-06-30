local ESX = exports['es_extended']:getSharedObject()

local helpCooldowns = {}
local activeHelpBlips = {}

-- ─── Hilfsfunktionen ───────────────────────────────────────────

local function getIdentifier(xPlayer)
    return xPlayer.identifier
end

local function hasTabletAccess(xPlayer)
    local group = xPlayer.getGroup()
    for _, g in ipairs(Config.AllowedGroups) do
        if group == g then return true end
    end
    return false
end

local function isAdminNotifyTarget(xPlayer)
    local group = xPlayer.getGroup()
    for _, g in ipairs(Config.AdminGroups) do
        if group == g then return true end
    end
    return false
end

local function notifyPlayer(source, msg)
    TriggerClientEvent('einreisetablet:notify', source, msg)
end

local function getAllExtendedPlayers()
    if ESX.GetExtendedPlayers then
        return ESX.GetExtendedPlayers()
    end

    local list = {}
    for _, id in ipairs(ESX.GetPlayers()) do
        local xp = ESX.GetPlayerFromId(id)
        if xp then
            list[#list + 1] = xp
        end
    end
    return list
end

local function sendDiscord(title, description, color)
    if not Config.DiscordWebhook or Config.DiscordWebhook == '' then return end

    local embed = {
        {
            ['title'] = title,
            ['description'] = description,
            ['color'] = color or Config.DiscordColor,
            ['footer'] = { ['text'] = os.date('%d.%m.%Y %H:%M:%S') }
        }
    }

    PerformHttpRequest(Config.DiscordWebhook, function() end, 'POST', json.encode({
        username = Config.DiscordBotName,
        embeds = embed
    }), { ['Content-Type'] = 'application/json' })
end

local function logAction(staffPlayer, targetPlayer, action)
    local staffId = getIdentifier(staffPlayer)
    local targetId = getIdentifier(targetPlayer)

    MySQL.insert('INSERT INTO einreisetablet_logs (target_identifier, target_name, staff_identifier, staff_name, action) VALUES (?, ?, ?, ?, ?)', {
        targetId,
        targetPlayer.getName(),
        staffId,
        staffPlayer.getName(),
        action
    })
end

local function normalizeEingereist(value)
    return value == 1 or value == true or value == '1'
end

local function getPlayerEntryStatus(identifier, cb)
    MySQL.scalar('SELECT eingereist FROM einreisetablet_status WHERE identifier = ?', { identifier }, function(result)
        cb(normalizeEingereist(result))
    end)
end

local function setPlayerEntryStatus(identifier, eingereist, staffName, cb)
    MySQL.query([[
        INSERT INTO einreisetablet_status (identifier, eingereist, eingereist_at, eingereist_by)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE eingereist = VALUES(eingereist), eingereist_at = VALUES(eingereist_at), eingereist_by = VALUES(eingereist_by)
    ]], {
        identifier,
        eingereist and 1 or 0,
        eingereist and os.date('%Y-%m-%d %H:%M:%S') or nil,
        staffName
    }, function()
        if cb then cb() end
    end)
end

-- ─── Fragen initialisieren ─────────────────────────────────────

local function initQuestions()
    MySQL.scalar('SELECT COUNT(*) FROM einreisetablet_questions', {}, function(count)
        if count and count > 0 then return end

        for i, q in ipairs(LocaleDefaultQuestions()) do
            MySQL.insert('INSERT INTO einreisetablet_questions (question, sort_order) VALUES (?, ?)', { q, i })
        end
    end)
end

MySQL.ready(function()
    initQuestions()
end)

-- ─── Callbacks ─────────────────────────────────────────────────

ESX.RegisterServerCallback('einreisetablet:canOpenTablet', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb(false) end
    cb(hasTabletAccess(xPlayer))
end)

ESX.RegisterServerCallback('einreisetablet:getDashboard', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or not hasTabletAccess(xPlayer) then return cb(nil) end

    MySQL.query('SELECT question, sort_order FROM einreisetablet_questions ORDER BY sort_order ASC', {}, function(questions)
        MySQL.query([[
            SELECT target_name, staff_name, action, created_at
            FROM einreisetablet_logs
            ORDER BY created_at DESC
            LIMIT 30
        ]], {}, function(logs)
            MySQL.query('SELECT identifier, eingereist, eingereist_by FROM einreisetablet_status', {}, function(statusRows)
                local statusMap = {}
                for _, row in ipairs(statusRows or {}) do
                    statusMap[row.identifier] = row
                end

                MySQL.scalar('SELECT COUNT(*) FROM einreisetablet_status WHERE eingereist = 1', {}, function(totalEntry)
                    MySQL.scalar('SELECT COUNT(*) FROM einreisetablet_status WHERE eingereist = 1 AND DATE(eingereist_at) = CURDATE()', {}, function(todayEntry)
                        local onlinePlayers = {}
                        local pendingOnline = 0

                        for _, xp in pairs(getAllExtendedPlayers()) do
                            local ident = getIdentifier(xp)
                            local status = statusMap[ident]
                            local eingereist = status and normalizeEingereist(status.eingereist)

                            if not eingereist then
                                pendingOnline = pendingOnline + 1
                            end

                            onlinePlayers[#onlinePlayers + 1] = {
                                id = xp.source,
                                name = xp.getName(),
                                eingereist = eingereist,
                                eingereist_by = status and status.eingereist_by or nil
                            }
                        end

                        table.sort(onlinePlayers, function(a, b)
                            if a.eingereist ~= b.eingereist then
                                return not a.eingereist
                            end
                            return a.id < b.id
                        end)

                        cb({
                            questions = questions or {},
                            logs = logs or {},
                            players = onlinePlayers,
                            staffName = xPlayer.getName(),
                            locale = Config.Locale,
                            localeUi = LocaleUI(),
                            stats = {
                                totalEntry = totalEntry or 0,
                                todayEntry = todayEntry or 0,
                                pendingOnline = pendingOnline
                            }
                        })
                    end)
                end)
            end)
        end)
    end)
end)

ESX.RegisterServerCallback('einreisetablet:getEntryStatus', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb(true) end

    getPlayerEntryStatus(getIdentifier(xPlayer), function(eingereist)
        cb(eingereist)
    end)
end)

-- ─── Events ────────────────────────────────────────────────────

RegisterNetEvent('einreisetablet:saveQuestions', function(questions)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or not hasTabletAccess(xPlayer) then return end
    if type(questions) ~= 'table' then return end

    MySQL.query('DELETE FROM einreisetablet_questions', {}, function()
        for i, q in ipairs(questions) do
            local text = type(q) == 'table' and q.question or q
            if text and text ~= '' then
                MySQL.insert('INSERT INTO einreisetablet_questions (question, sort_order) VALUES (?, ?)', { text, i })
            end
        end
    end)

    notifyPlayer(source, Locale('questions_saved'))
end)

RegisterNetEvent('einreisetablet:sendQuestionsToPlayer', function(targetId)
    local source = source
    local xStaff = ESX.GetPlayerFromId(source)
    local xTarget = ESX.GetPlayerFromId(targetId)

    if not xStaff or not hasTabletAccess(xStaff) then return end
    if not xTarget then
        notifyPlayer(source, Locale('player_not_found'))
        return
    end

    MySQL.query('SELECT question FROM einreisetablet_questions ORDER BY sort_order ASC', {}, function(questions)
        local list = {}
        for _, row in ipairs(questions or {}) do
            list[#list + 1] = row.question
        end

        TriggerClientEvent('einreisetablet:showQuestions', targetId, list, xStaff.getName())
        notifyPlayer(source, Locale('questions_sent', xTarget.getName()))
    end)
end)

RegisterNetEvent('einreisetablet:giveSkin', function(targetId)
    local source = source
    local xStaff = ESX.GetPlayerFromId(source)
    local xTarget = ESX.GetPlayerFromId(targetId)

    if not xStaff or not hasTabletAccess(xStaff) then return end
    if not xTarget then
        notifyPlayer(source, Locale('player_not_found'))
        return
    end

    if Config.SkinSystem == 'esx_skin' then
        TriggerClientEvent('esx_skin:openSaveableMenu', targetId)
    elseif Config.SkinSystem == 'illenium' then
        TriggerClientEvent('illenium-appearance:client:openClothingShopMenu', targetId)
    elseif Config.SkinSystem == 'custom' then
        TriggerClientEvent(Config.CustomSkinEvent, targetId)
    end

    logAction(xStaff, xTarget, 'skin_gegeben')
    notifyPlayer(source, Locale('skin_given'))
    notifyPlayer(targetId, Locale('skin_opened'))
end)

RegisterNetEvent('einreisetablet:processEntry', function(targetId)
    local source = source
    local xStaff = ESX.GetPlayerFromId(source)
    local xTarget = ESX.GetPlayerFromId(targetId)

    if not xStaff or not hasTabletAccess(xStaff) then return end
    if not xTarget then
        notifyPlayer(source, Locale('player_not_found'))
        return
    end

    local identifier = getIdentifier(xTarget)
    setPlayerEntryStatus(identifier, true, xStaff.getName(), function()
        TriggerClientEvent('einreisetablet:setEntryStatus', targetId, true)
        TriggerClientEvent('einreisetablet:teleportToEntry', targetId, {
            x = Config.EntryCoords.x,
            y = Config.EntryCoords.y,
            z = Config.EntryCoords.z,
            w = Config.EntryCoords.w
        })

        notifyPlayer(targetId, Locale('entry_success'))
        notifyPlayer(source, Locale('entry_done_staff', targetId))

        logAction(xStaff, xTarget, 'eingereist')
        sendDiscord(Locale('discord_entry_title'), Locale('discord_entry_desc',
            xTarget.getName(), identifier, xStaff.getName()
        ), 3066993)
    end)
end)

RegisterNetEvent('einreisetablet:revokeEntry', function(targetId)
    local source = source
    local xStaff = ESX.GetPlayerFromId(source)
    local xTarget = ESX.GetPlayerFromId(targetId)

    if not xStaff or not hasTabletAccess(xStaff) then return end
    if not xTarget then
        notifyPlayer(source, Locale('player_not_found'))
        return
    end

    local identifier = getIdentifier(xTarget)
    setPlayerEntryStatus(identifier, false, nil, function()
        TriggerClientEvent('einreisetablet:setEntryStatus', targetId, false)
        TriggerClientEvent('einreisetablet:teleportToZone', targetId, {
            x = Config.Zone.returnCoords.x,
            y = Config.Zone.returnCoords.y,
            z = Config.Zone.returnCoords.z,
            w = Config.Zone.returnCoords.w
        })

        logAction(xStaff, xTarget, 'einreise_entzogen')
        notifyPlayer(source, Locale('entry_revoked_staff', xTarget.getName()))
        notifyPlayer(targetId, Locale('entry_revoked_target'))
    end)
end)

RegisterNetEvent('einreisetablet:tpToPlayer', function(targetId)
    local source = source
    local xStaff = ESX.GetPlayerFromId(source)
    local xTarget = ESX.GetPlayerFromId(targetId)

    if not xStaff or not hasTabletAccess(xStaff) then return end
    if not xTarget then
        notifyPlayer(source, Locale('player_not_found'))
        return
    end

    local targetPed = GetPlayerPed(targetId)
    local coords = GetEntityCoords(targetPed)

    TriggerClientEvent('einreisetablet:staffTeleport', source, {
        x = coords.x,
        y = coords.y,
        z = coords.z,
        w = GetEntityHeading(targetPed)
    })

    notifyPlayer(source, Locale('tp_to_player', xTarget.getName()))
end)

RegisterNetEvent('einreisetablet:bringPlayer', function(targetId)
    local source = source
    local xStaff = ESX.GetPlayerFromId(source)
    local xTarget = ESX.GetPlayerFromId(targetId)

    if not xStaff or not hasTabletAccess(xStaff) then return end
    if not xTarget then
        notifyPlayer(source, Locale('player_not_found'))
        return
    end

    local staffPed = GetPlayerPed(source)
    local coords = GetEntityCoords(staffPed)

    TriggerClientEvent('einreisetablet:staffTeleport', targetId, {
        x = coords.x,
        y = coords.y,
        z = coords.z,
        w = GetEntityHeading(staffPed)
    })

    notifyPlayer(source, Locale('bring_player_staff', xTarget.getName()))
    notifyPlayer(targetId, Locale('bring_player_target'))
end)

RegisterNetEvent('einreisetablet:freezePlayer', function(targetId, freeze)
    local source = source
    local xStaff = ESX.GetPlayerFromId(source)
    local xTarget = ESX.GetPlayerFromId(targetId)

    if not xStaff or not hasTabletAccess(xStaff) then return end
    if not xTarget then
        notifyPlayer(source, Locale('player_not_found'))
        return
    end

    TriggerClientEvent('einreisetablet:setFrozen', targetId, freeze == true)

    local action = freeze and 'freeze' or 'unfreeze'
    logAction(xStaff, xTarget, action)

    notifyPlayer(source, freeze and Locale('player_frozen') or Locale('player_unfrozen'))
    if freeze then
        notifyPlayer(targetId, Locale('frozen_target'))
    else
        notifyPlayer(targetId, Locale('unfrozen_target'))
    end
end)

RegisterNetEvent('einreisetablet:saveNote', function(targetId, note)
    local source = source
    local xStaff = ESX.GetPlayerFromId(source)
    local xTarget = ESX.GetPlayerFromId(targetId)

    if not xStaff or not hasTabletAccess(xStaff) then return end
    if not xTarget or not note or note == '' then return end

    MySQL.insert('INSERT INTO einreisetablet_logs (target_identifier, target_name, staff_identifier, staff_name, action) VALUES (?, ?, ?, ?, ?)', {
        getIdentifier(xTarget),
        xTarget.getName() .. ' — ' .. note,
        getIdentifier(xStaff),
        xStaff.getName(),
        'notiz'
    })

    notifyPlayer(source, Locale('note_saved'))
end)

RegisterNetEvent('einreisetablet:zoneAnnounce', function(message)
    local source = source
    local xStaff = ESX.GetPlayerFromId(source)

    if not xStaff or not hasTabletAccess(xStaff) then return end
    if not message or message == '' then return end

    local zoneCenter = Config.Zone.center
    local zoneRadius = Config.Zone.radius

    MySQL.query('SELECT identifier FROM einreisetablet_status WHERE eingereist = 1', {}, function(rows)
        local eingereistMap = {}
        for _, row in ipairs(rows or {}) do
            eingereistMap[row.identifier] = true
        end

        for _, xp in pairs(getAllExtendedPlayers()) do
            if not eingereistMap[getIdentifier(xp)] then
                local ped = GetPlayerPed(xp.source)
                local coords = GetEntityCoords(ped)
                if #(coords - zoneCenter) <= zoneRadius then
                    TriggerClientEvent('einreisetablet:zoneMessage', xp.source, message, xStaff.getName())
                end
            end
        end
    end)

    notifyPlayer(source, Locale('zone_announce_sent'))
end)

RegisterNetEvent('einreisetablet:giveStarter', function(targetId)
    local source = source
    local xStaff = ESX.GetPlayerFromId(source)
    local xTarget = ESX.GetPlayerFromId(targetId)

    if not xStaff or not hasTabletAccess(xStaff) then return end
    if not xTarget then
        notifyPlayer(source, Locale('player_not_found'))
        return
    end

    if not Config.StarterMoney.enabled then
        notifyPlayer(source, Locale('starter_disabled'))
        return
    end

    local account = Config.StarterMoney.account == 'bank' and 'bank' or 'money'
    xTarget.addAccountMoney(account, Config.StarterMoney.amount, Locale('starter_money_reason'))

    logAction(xStaff, xTarget, 'startgeld')
    notifyPlayer(source, Locale('starter_given_staff', Config.StarterMoney.amount, xTarget.getName()))
    notifyPlayer(targetId, Locale('starter_given_target', Config.StarterMoney.amount))
end)

RegisterNetEvent('einreisetablet:requestHelp', function()
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end

    local now = os.time()
    if helpCooldowns[source] and (now - helpCooldowns[source]) < Config.HelpMarker.cooldown then
        local remaining = Config.HelpMarker.cooldown - (now - helpCooldowns[source])
        notifyPlayer(source, Locale('help_cooldown', remaining))
        return
    end

    helpCooldowns[source] = now

    local playerName = xPlayer.getName()
    local playerCoords = GetEntityCoords(GetPlayerPed(source))
    local msg = Locale('help_request', playerName, source)

    for _, xp in pairs(getAllExtendedPlayers()) do
        if isAdminNotifyTarget(xp) then
            notifyPlayer(xp.source, msg)
            if Config.HelpMarker.blipForAdmins then
                TriggerClientEvent('einreisetablet:createHelpBlip', xp.source, {
                    x = playerCoords.x,
                    y = playerCoords.y,
                    z = playerCoords.z,
                    name = playerName,
                    duration = Config.HelpMarker.blipDuration
                })
            end
        end
    end

    notifyPlayer(source, Locale('help_sent'))
    sendDiscord(Locale('discord_help_title'), Locale('discord_help_desc',
        playerName, source, playerCoords.x, playerCoords.y, playerCoords.z
    ), 15158332)
end)

-- ─── Spieler joinen ────────────────────────────────────────────

AddEventHandler('esx:playerLoaded', function(playerId, xPlayer)
    getPlayerEntryStatus(getIdentifier(xPlayer), function(eingereist)
        TriggerClientEvent('einreisetablet:setEntryStatus', playerId, eingereist)

        if not eingereist and Config.NewPlayerSpawn then
            Wait(1500)
            TriggerClientEvent('einreisetablet:teleportToZone', playerId, {
                x = Config.NewPlayerSpawn.x,
                y = Config.NewPlayerSpawn.y,
                z = Config.NewPlayerSpawn.z,
                w = Config.NewPlayerSpawn.w
            })
        end
    end)
end)

AddEventHandler('playerDropped', function()
    helpCooldowns[source] = nil
end)

-- Export für andere Resources
exports('IsPlayerEingereist', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb(false) end
    getPlayerEntryStatus(getIdentifier(xPlayer), cb)
end)

exports('SetPlayerEingereist', function(source, status, staffName)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end
    setPlayerEntryStatus(getIdentifier(xPlayer), status, staffName)
    TriggerClientEvent('einreisetablet:setEntryStatus', source, status)
    return true
end)
