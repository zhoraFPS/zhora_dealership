local ESX = nil

TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

-- Debug Flag und Funktion hinzufügen
local DEBUG = false  -- Auf true setzen für Debug-Ausgaben

local function DebugPrint(message)
    if DEBUG then
        print("[AUTOHAUS DEBUG] " .. tostring(message))
    end
end

local activeTestDrives = {}

-- Anti-Cheat Variablen
local purchaseCooldowns = {}
local purchaseHistory = {}
local suspiciousActivity = {}


-- Callback: Kann Spieler sich das Fahrzeug leisten?
ESX.RegisterServerCallback('autohaus:canAfford', function(source, cb, price)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then
        cb(false)
        return
    end
    
    -- Anti-Cheat: Cooldown prüfen
    if Config.Security and Config.Security.enableAntiCheat then
        local identifier = xPlayer.identifier
        local currentTime = os.time()
        
        if purchaseCooldowns[identifier] and (currentTime - purchaseCooldowns[identifier]) < Config.Security.purchaseCooldown then
            LogSuspiciousActivity(source, "Purchase cooldown violation")
            cb(false)
            return
        end
    end
    
    if xPlayer.getMoney() >= price then
        cb(true)
    else
        cb(false)
    end
end)

-- Event: Fahrzeug kaufen
-- ERSETZE DIESE FUNKTIONEN IN DEINER SERVER.LUA:

-- ✅ 1. SICHERE INPUT VALIDATION FUNKTION (NEU HINZUFÜGEN):
function ValidateInputData(dealershipId, carIndex)
    -- NIL CHECK
    if not dealershipId or not carIndex then
        return false, "Missing parameters"
    end
    
    -- TYPE VALIDATION
    if type(dealershipId) ~= "string" or type(carIndex) ~= "number" then
        return false, "Invalid parameter types"
    end
    
    -- RANGE VALIDATION
    if carIndex < 1 or carIndex > 100 then
        return false, "Index out of range"
    end
    
    -- CONFIG VALIDATION
    if not Config.Dealerships[dealershipId] then
        return false, "Dealership not found"
    end
    
    if not Config.Dealerships[dealershipId].cars[carIndex] then
        return false, "Car not found"
    end
    
    return true, "Valid"
end

-- ✅ 2. RATE LIMITING SYSTEM (NEU HINZUFÜGEN):
local playerActions = {}

function CheckRateLimit(playerId, action, maxPerMinute)
    local now = os.time()
    local key = playerId .. "_" .. action
    
    if not playerActions[key] then
        playerActions[key] = {}
    end
    
    -- Entferne alte Einträge (älter als 1 Minute)
    for i = #playerActions[key], 1, -1 do
        if (now - playerActions[key][i]) > 60 then
            table.remove(playerActions[key], i)
        end
    end
    
    -- Prüfe Limit
    if #playerActions[key] >= maxPerMinute then
        return false
    end
    
    table.insert(playerActions[key], now)
    return true
end

-- ✅ 3. DISTANCE CHECK FUNKTION (NEU HINZUFÜGEN):
function CheckPlayerDistance(playerId, dealershipId, maxDistance)
    local playerCoords = GetEntityCoords(GetPlayerPed(playerId))
    local dealership = Config.Dealerships[dealershipId]
    
    if dealership and dealership.blip then
        local distance = #(playerCoords - dealership.blip.coords)
        return distance <= maxDistance, distance
    end
    
    return true, 0 -- Fallback: erlauben wenn keine Blip-Coords
end

-- ✅ 4. ERSETZE DEN UNSICHEREN buyVehicle EVENT:
RegisterNetEvent('autohaus:buyVehicle')
AddEventHandler('autohaus:buyVehicle', function(dealershipId, carIndex) -- ⚠️ GEÄNDERT: Entferne 'car' Parameter
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    
    if not xPlayer then 
        DebugPrint("SECURITY: Ungültiger Spieler für buyVehicle")
        return 
    end
    
    -- ✅ RATE LIMITING
    if not CheckRateLimit(_source, "buyVehicle", 3) then -- Max 3 Käufe pro Minute
        LogSuspiciousActivity(_source, "Purchase rate limit exceeded")
        TriggerClientEvent('esx:showNotification', _source, 'Zu viele Kaufversuche! Warte einen Moment.', 'error')
        return
    end
    
    -- ✅ INPUT VALIDATION
    local isValid, errorMsg = ValidateInputData(dealershipId, carIndex)
    if not isValid then
        LogSuspiciousActivity(_source, "Invalid purchase data: " .. errorMsg)
        DebugPrint("SECURITY: " .. errorMsg .. " von Spieler " .. _source)
        return
    end
    
    -- ✅ DISTANCE CHECK - Spieler muss in der Nähe des Autohauses sein
    local withinDistance, distance = CheckPlayerDistance(_source, dealershipId, 50) -- 50 Meter Maximum
    if not withinDistance then
        LogSuspiciousActivity(_source, "Purchase attempt from distance: " .. math.floor(distance) .. "m")
        TriggerClientEvent('esx:showNotification', _source, 'Du bist zu weit vom Autohaus entfernt!', 'error')
        return
    end
    
    -- ✅ SICHERE Fahrzeugdaten aus Config holen (NIEMALS vom Client!)
    local car = Config.Dealerships[dealershipId].cars[carIndex]
    if not car then
        LogSuspiciousActivity(_source, "Car config not found after validation")
        return
    end
    
    -- Bestehende Anti-Cheat Prüfungen
    if Config.Security and Config.Security.enableAntiCheat then
        local identifier = xPlayer.identifier
        local currentTime = os.time()
        
        if purchaseCooldowns[identifier] and (currentTime - purchaseCooldowns[identifier]) < Config.Security.purchaseCooldown then
            LogSuspiciousActivity(_source, "Purchase cooldown violation")
            return
        end
        
        -- Purchase History initialisieren
        if not purchaseHistory[identifier] then
            purchaseHistory[identifier] = {}
        end
        
        -- Stündliche Käufe prüfen
        local hourlyPurchases = 0
        for _, purchaseTime in pairs(purchaseHistory[identifier]) do
            if (currentTime - purchaseTime) < 3600 then
                hourlyPurchases = hourlyPurchases + 1
            end
        end
        
        if hourlyPurchases >= Config.Security.maxPurchasesPerHour then
            LogSuspiciousActivity(_source, "Too many purchases per hour")
            TriggerClientEvent('esx:showNotification', _source, 'Du hast zu viele Fahrzeuge in kurzer Zeit gekauft. Warte etwas.', 'error')
            return
        end
        
        -- Fahrzeugdaten double-check
        if not ValidateVehicleData(dealershipId, carIndex, car) then
            LogSuspiciousActivity(_source, "Vehicle data validation failed")
            return
        end
        
        purchaseCooldowns[identifier] = currentTime
        table.insert(purchaseHistory[identifier], currentTime)
    end
    
    -- ✅ SICHERE Kaufabwicklung (bestehender Code)
    if xPlayer.getMoney() >= car.price then
        xPlayer.removeMoney(car.price)
        
        local vehicleProps = {
            model = GetHashKey(car.model),
            plate = GenerateRandomPlate(),
            color1 = math.random(0, 159),
            color2 = math.random(0, 159)
        }
        
        MySQL.Async.execute('INSERT INTO owned_vehicles (owner, plate, vehicle, type, job, stored) VALUES (@owner, @plate, @vehicle, @type, @job, @stored)', {
            ['@owner'] = xPlayer.identifier,
            ['@plate'] = vehicleProps.plate,
            ['@vehicle'] = json.encode(vehicleProps),
            ['@type'] = 'car',
            ['@job'] = '',
            ['@stored'] = 1
        }, function(rowsChanged)
            if rowsChanged > 0 then
                TriggerClientEvent('autohaus:vehiclePurchased', _source, car, vehicleProps.plate, dealershipId)
                
                -- Sicheres Logging
                print(string.format("[AUTOHAUS SECURE] %s (%s) kaufte %s für $%s (Kennzeichen: %s)", 
                    xPlayer.getName(), xPlayer.identifier, car.label, car.price, vehicleProps.plate))
                
                if Config.DiscordWebhook then
                    SendDiscordMessage(xPlayer, car, vehicleProps.plate, dealershipId)
                end
                
                if Config.EnableSalesStats then
                    UpdateSalesStats(dealershipId, car.model, car.price)
                end
            else
                xPlayer.addMoney(car.price)
                TriggerClientEvent('esx:showNotification', _source, 'Fehler beim Fahrzeugkauf. Geld wurde zurückerstattet.', 'error')
            end
        end)
    else
        TriggerClientEvent('esx:showNotification', _source, 'Du hast nicht genug Geld!', 'error')
    end
end)

-- Event: Probefahrt starten

-- Improved Test Drive Event
RegisterNetEvent('autohaus:startTestDrive')
AddEventHandler('autohaus:startTestDrive', function(dealershipId, carIndex) -- ⚠️ GEÄNDERT: Statt 'model' jetzt IDs
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    
    if not xPlayer then return end
    
    -- ✅ RATE LIMITING
    if not CheckRateLimit(_source, "testDrive", 2) then -- Max 2 Testfahrten pro Minute
        LogSuspiciousActivity(_source, "Testdrive rate limit exceeded")
        TriggerClientEvent('esx:showNotification', _source, 'Zu viele Testfahrt-Versuche!', 'error')
        return
    end
    
    -- ✅ INPUT VALIDATION
    local isValid, errorMsg = ValidateInputData(dealershipId, carIndex)
    if not isValid then
        LogSuspiciousActivity(_source, "Invalid testdrive data: " .. errorMsg)
        return
    end
    
    -- ✅ AKTIVE TESTDRIVE CHECK
    if activeTestDrives[_source] then
        TriggerClientEvent('esx:showNotification', _source, 'Du hast bereits eine aktive Probefahrt!', "error")
        return
    end
    
    -- ✅ DISTANCE CHECK
    local withinDistance, distance = CheckPlayerDistance(_source, dealershipId, 50)
    if not withinDistance then
        LogSuspiciousActivity(_source, "Testdrive attempt from distance: " .. math.floor(distance) .. "m")
        TriggerClientEvent('esx:showNotification', _source, 'Du bist zu weit vom Autohaus entfernt!', 'error')
        return
    end
    
    -- ✅ SICHERE Fahrzeugdaten aus Config holen
    local car = Config.Dealerships[dealershipId].cars[carIndex]
    if not car then
        LogSuspiciousActivity(_source, "Testdrive car not found in config")
        return
    end
    
    local model = car.model -- Server bestimmt das Model!
    
    -- ✅ MODEL VALIDATION
    if not IsValidVehicleModel(model) then
        LogSuspiciousActivity(_source, "Invalid vehicle model for testdrive: " .. model)
        return
    end
    
    -- Bestimme Spawn-Koordinaten
    local spawnCoords = GetTestDriveSpawnCoords(_source)
    
    -- Registriere aktive Probefahrt
    activeTestDrives[_source] = {
        model = model,
        startTime = os.time(),
        player = xPlayer.identifier,
        dealershipId = dealershipId,
        carIndex = carIndex
    }
    
    -- Starte Probefahrt auf Client
    TriggerClientEvent('autohaus:startTestDrive', _source, model, spawnCoords)
    
    -- Sicheres Logging
    print(string.format("[AUTOHAUS SECURE] %s startet Testfahrt mit %s von %s", 
        xPlayer.getName(), model, dealershipId))
    
    -- Auto-Cleanup
    Citizen.SetTimeout((Config.TestDrive.duration + 30) * 1000, function()
        if activeTestDrives[_source] then
            activeTestDrives[_source] = nil
        end
    end)
end)

-- Zufälliges Kennzeichen generieren mit Verfügbarkeitsprüfung
function GenerateRandomPlate()
    local plate = ""
    
    if Config.Plate.usePrefix then
        -- Prefix hinzufügen
        plate = Config.Plate.prefix
        
        -- Leerzeichen hinzufügen falls gewünscht
        if Config.Plate.useSpace then
            plate = plate .. " "
        end
        
        -- Zufällige Zeichen generieren
        for i = 1, Config.Plate.randomLength do
            if Config.Plate.onlyNumbers then
                -- Nur Zahlen (0-9)
                plate = plate .. math.random(0, 9)
            else
                -- Zahlen und Buchstaben
                local charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
                local rand = math.random(#charset)
                plate = plate .. string.sub(charset, rand, rand)
            end
        end
    else
        -- Altes System: 8 zufällige Zeichen
        local charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        for i = 1, 8 do
            local rand = math.random(#charset)
            plate = plate .. string.sub(charset, rand, rand)
        end
    end
    
    -- Prüfe ob Kennzeichen bereits existiert
    local plateExists = MySQL.Sync.fetchAll('SELECT plate FROM owned_vehicles WHERE plate = @plate', {
        ['@plate'] = plate
    })
    
    if #plateExists > 0 then
        -- Kennzeichen bereits vorhanden, neues generieren
        return GenerateRandomPlate()
    end
    
    return plate
end

-- Fahrzeugdaten validieren (Anti-Cheat)
function ValidateVehicleData(dealershipId, carIndex, car)
    if not Config.Dealerships[dealershipId] then
        return false
    end
    
    local configCar = Config.Dealerships[dealershipId].cars[carIndex]
    if not configCar then
        return false
    end
    
    -- Prüfe ob die wichtigsten Daten übereinstimmen
    if configCar.model ~= car.model or 
       configCar.price ~= car.price or 
       configCar.label ~= car.label then
        return false
    end
    
    return true
end

function ValidateInputData(dealershipId, carIndex)
    -- NIL CHECK
    if not dealershipId or not carIndex then
        return false, "Missing parameters"
    end
    
    -- TYPE VALIDATION
    if type(dealershipId) ~= "string" or type(carIndex) ~= "number" then
        return false, "Invalid parameter types"
    end
    
    -- RANGE VALIDATION
    if carIndex < 1 or carIndex > 100 then
        return false, "Index out of range"
    end
    
    -- CONFIG VALIDATION
    if not Config.Dealerships[dealershipId] then
        return false, "Dealership not found"
    end
    
    if not Config.Dealerships[dealershipId].cars[carIndex] then
        return false, "Car not found"
    end
    
    return true, "Valid"
end

-- ✅ 2. RATE LIMITING SYSTEM (NEU HINZUFÜGEN):
local playerActions = {}

function CheckRateLimit(playerId, action, maxPerMinute)
    local now = os.time()
    local key = playerId .. "_" .. action
    
    if not playerActions[key] then
        playerActions[key] = {}
    end
    
    -- Entferne alte Einträge (älter als 1 Minute)
    for i = #playerActions[key], 1, -1 do
        if (now - playerActions[key][i]) > 60 then
            table.remove(playerActions[key], i)
        end
    end
    
    -- Prüfe Limit
    if #playerActions[key] >= maxPerMinute then
        return false
    end
    
    table.insert(playerActions[key], now)
    return true
end

-- ✅ 3. DISTANCE CHECK FUNKTION (NEU HINZUFÜGEN):
function CheckPlayerDistance(playerId, dealershipId, maxDistance)
    local playerCoords = GetEntityCoords(GetPlayerPed(playerId))
    local dealership = Config.Dealerships[dealershipId]
    
    if dealership and dealership.blip then
        local distance = #(playerCoords - dealership.blip.coords)
        return distance <= maxDistance, distance
    end
    
    return true, 0 -- Fallback: erlauben wenn keine Blip-Coords
end

-- Verdächtige Aktivitäten loggen
function LogSuspiciousActivity(playerId, reason)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer then return end
    
    local identifier = xPlayer.identifier
    local currentTime = os.time()
    
    if not suspiciousActivity[identifier] then
        suspiciousActivity[identifier] = {}
    end
    
    table.insert(suspiciousActivity[identifier], {
        time = currentTime,
        reason = reason
    })
    
    -- Erweiterte Logs
    print(string.format("[AUTOHAUS-SECURITY] ⚠️ Verdächtige Aktivität von %s (%s): %s", 
        xPlayer.getName(), identifier, reason))
    
    -- Admin Alert bei wiederholten Verstößen
    if #suspiciousActivity[identifier] >= 3 then
        local admins = ESX.GetPlayers()
        for _, adminId in pairs(admins) do
            local admin = ESX.GetPlayerFromId(adminId)
            if admin and (admin.getGroup() == 'admin' or admin.getGroup() == 'superadmin') then
                TriggerClientEvent('esx:showNotification', adminId, 
                    string.format('🚨 AUTOHAUS SECURITY: Verdächtige Aktivität von %s (%s)', 
                    xPlayer.getName(), reason), 'error')
            end
        end
        
        -- Bei 5+ Verstößen: Temporäres Verbot
        if #suspiciousActivity[identifier] >= 5 then
            TriggerClientEvent('esx:showNotification', playerId, 
                'Du wurdest temporär vom Autohaus-System ausgeschlossen wegen verdächtiger Aktivitäten.', 'error')
            
            -- Optional: Kick Spieler (auskommentiert)
            -- DropPlayer(playerId, "Verdächtige Aktivität im Autohaus-System")
        end
    end
end

-- Discord Webhook senden
function SendDiscordMessage(xPlayer, car, plate, dealershipId)
    if not Config.WebhookURL or Config.WebhookURL == "" then return end
    
    local dealershipName = Config.Dealerships[dealershipId] and Config.Dealerships[dealershipId].name or "Unbekanntes Autohaus"
    
    local embed = {
        {
            ["color"] = 3066993, -- Grün
            ["title"] = "🚗 Fahrzeugkauf",
            ["description"] = string.format("**Spieler:** %s\n**Fahrzeug:** %s\n**Preis:** $%s\n**Kennzeichen:** %s\n**Autohaus:** %s", 
                xPlayer.getName(), car.label, FormatMoney(car.price), plate, dealershipName),
            ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            ["footer"] = {
                ["text"] = "Autohaus System"
            }
        }
    }
    
    PerformHttpRequest(Config.WebhookURL, function(err, text, headers) end, 'POST', json.encode({
        username = "Autohaus Bot",
        embeds = embed
    }), { ['Content-Type'] = 'application/json' })
end

-- Verkaufsstatistiken aktualisieren
function UpdateSalesStats(dealershipId, model, price)
    local currentDate = os.date("%Y-%m-%d")
    
    MySQL.Async.execute('INSERT INTO autohaus_sales (dealership_id, vehicle_model, price, sale_date) VALUES (@dealership, @model, @price, @date) ON DUPLICATE KEY UPDATE sales_count = sales_count + 1', {
        ['@dealership'] = dealershipId,
        ['@model'] = model,
        ['@price'] = price,
        ['@date'] = currentDate
    })
end

-- Fahrzeug aus Garage holen (für ESX Garage Kompatibilität)
ESX.RegisterServerCallback('autohaus:getOwnedVehicles', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    local vehicles = MySQL.Sync.fetchAll('SELECT * FROM owned_vehicles WHERE owner = @owner AND type = @type AND stored = 1', {
        ['@owner'] = xPlayer.identifier,
        ['@type'] = 'car'
    })
    
    cb(vehicles)
end)

-- Event: Fahrzeug Status setzen (ausgefahren/eingefahren)
RegisterNetEvent('autohaus:setVehicleState')
AddEventHandler('autohaus:setVehicleState', function(plate, state, coords)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if state == 1 then -- Fahrzeug einparken
        MySQL.Async.execute('UPDATE owned_vehicles SET stored = @stored, parking = @parking WHERE owner = @owner AND plate = @plate', {
            ['@stored'] = state,
            ['@parking'] = coords and json.encode(coords) or Config.DefaultParking,
            ['@owner'] = xPlayer.identifier,
            ['@plate'] = plate
        })
    else -- Fahrzeug ausfahren
        MySQL.Async.execute('UPDATE owned_vehicles SET stored = @stored WHERE owner = @owner AND plate = @plate', {
            ['@stored'] = state,
            ['@owner'] = xPlayer.identifier,
            ['@plate'] = plate
        })
    end
end)

-- Admin Commands
ESX.RegisterCommand('bringcar', 'admin', function(xPlayer, args, showError)
    local targetPlayerId = tonumber(args.target)
    local plate = args.plate
    
    if not targetPlayerId or not plate then
        return xPlayer.showNotification('Verwendung: /bringcar [player_id] [kennzeichen]', 'error')
    end
    
    local targetPlayer = ESX.GetPlayerFromId(targetPlayerId)
    if not targetPlayer then
        return xPlayer.showNotification('Spieler nicht gefunden!', 'error')
    end
    
    -- Prüfen ob Fahrzeug existiert
    local vehicle = MySQL.Sync.fetchAll('SELECT * FROM owned_vehicles WHERE plate = @plate', {
        ['@plate'] = plate
    })
    
    if #vehicle == 0 then
        return xPlayer.showNotification('Fahrzeug nicht gefunden!', 'error')
    end
    
    -- Fahrzeug zum Spieler spawnen
    local targetCoords = GetEntityCoords(GetPlayerPed(targetPlayerId))
    local spawnCoords = vector3(targetCoords.x + 3.0, targetCoords.y + 3.0, targetCoords.z)
    
    TriggerClientEvent('autohaus:adminSpawnVehicle', targetPlayerId, {
        model = json.decode(vehicle[1].vehicle).model,
        plate = plate,
        props = json.decode(vehicle[1].vehicle),
        spawnCoords = spawnCoords,
        spawnHeading = 0.0
    })
    
    xPlayer.showNotification(string.format('Fahrzeug %s zu %s teleportiert.', plate, targetPlayer.getName()), 'success')
    targetPlayer.showNotification('Ein Admin hat dir ein Fahrzeug gebracht.', 'info')
    
end, false, {help = 'Fahrzeug zu Spieler teleportieren', validate = true, arguments = {
    {name = 'target', help = 'Spieler ID', type = 'player'},
    {name = 'plate', help = 'Fahrzeug Kennzeichen', type = 'string'}
}})

-- Admin Command: Autohaus neuladen
ESX.RegisterCommand('reloadautohaus', 'admin', function(xPlayer, args, showError)
    TriggerClientEvent('chat:addMessage', xPlayer.source, {
        color = {0, 255, 0},
        multiline = true,
        args = {"AUTOHAUS", "Konfiguration wurde neugeladen!"}
    })
    
    -- Client neustarten
    TriggerClientEvent('autohaus:reload', xPlayer.source)
end, false, {help = 'Autohaus Konfiguration neuladen'})

-- Admin Command: Verkaufsstatistiken anzeigen
ESX.RegisterCommand('autohausstats', 'admin', function(xPlayer, args, showError)
    MySQL.Async.fetchAll('SELECT dealership_id, vehicle_model, COUNT(*) as sales_count, SUM(price) as total_revenue FROM autohaus_sales GROUP BY dealership_id, vehicle_model ORDER BY sales_count DESC LIMIT 10', {}, function(results)
        if #results > 0 then
            local message = "📊 **Autohaus Verkaufsstatistiken:**\n"
            for _, row in pairs(results) do
                local dealershipName = Config.Dealerships[row.dealership_id] and Config.Dealerships[row.dealership_id].name or row.dealership_id
                message = message .. string.format("• %s - %s: %d Verkäufe ($%s)\n", 
                    dealershipName, row.vehicle_model, row.sales_count, FormatMoney(row.total_revenue))
            end
            
            TriggerClientEvent('chat:addMessage', xPlayer.source, {
                color = {0, 255, 255},
                multiline = true,
                args = {"AUTOHAUS", message}
            })
        else
            xPlayer.showNotification('Keine Verkaufsstatistiken verfügbar.', 'info')
        end
    end)
end, false, {help = 'Autohaus Verkaufsstatistiken anzeigen'})

-- Event für Client Reload
RegisterNetEvent('autohaus:reload')
AddEventHandler('autohaus:reload', function()
    -- Hier könntest du zusätzliche Server-seitige Reload-Logik hinzufügen
    print("[AUTOHAUS] Resource wird für Spieler " .. source .. " neugeladen")
end)

-- Hilfsfunktionen
function FormatMoney(amount)
    local formatted = tostring(amount)
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    return formatted
end

-- Database Setup (beim Start der Resource)
MySQL.ready(function()
    -- Tabelle für Verkaufsstatistiken erstellen (falls nicht vorhanden)
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `autohaus_sales` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `dealership_id` varchar(50) NOT NULL,
            `vehicle_model` varchar(50) NOT NULL,
            `price` int(11) NOT NULL,
            `sale_date` date NOT NULL,
            `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `dealership_date` (`dealership_id`, `sale_date`),
            KEY `vehicle_model` (`vehicle_model`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]], {})
    
    print("[AUTOHAUS] Database Setup abgeschlossen")
end)

RegisterNetEvent('autohaus:endTestDrive')
AddEventHandler('autohaus:endTestDrive', function()
    local _source = source
    
    if activeTestDrives[_source] then
        activeTestDrives[_source] = nil
        DebugPrint("Probefahrt für Spieler " .. _source .. " beendet")
    end
end)

-- Funktion: Prüfe ob Fahrzeugmodell gültig ist
-- ✅ 7. ERWEITERTE IsValidVehicleModel FUNKTION (ERSETZE DIE BESTEHENDE):
function IsValidVehicleModel(model)
    -- Prüfe ob Model in Config existiert
    for _, dealership in pairs(Config.Dealerships) do
        for _, car in pairs(dealership.cars) do
            if car.model == model then
                return true
            end
        end
    end
    
    -- Blacklist für gefährliche Fahrzeuge
    local blacklist = {
        'hydra', 'lazer', 'rhino', 'insurgent', 'technical',
        'oppressor', 'oppressor2', 'deluxo', 'vigilante'
    }
    
    for _, forbidden in pairs(blacklist) do
        if string.find(string.lower(model), forbidden) then
            return false
        end
    end
    
    -- GTA Model Check
    local hash = GetHashKey(model)
    return IsModelInCdimage(hash) and IsModelAVehicle(hash)
end

-- ✅ 8. CLEANUP FÜR RATE LIMITING (NEU HINZUFÜGEN):
AddEventHandler('esx:playerDropped', function(playerId, reason)
    -- Cleanup aktive Testfahrten
    if activeTestDrives[playerId] then
        activeTestDrives[playerId] = nil
        DebugPrint("Probefahrt für disconnected Spieler " .. playerId .. " entfernt")
    end
    
    -- Cleanup Rate Limiting Daten
    for key, _ in pairs(playerActions) do
        if string.find(key, "^" .. playerId .. "_") then
            playerActions[key] = nil
        end
    end
end)

-- ✅ 9. ADMIN COMMAND FÜR SECURITY STATUS (NEU HINZUFÜGEN):
ESX.RegisterCommand('autohaus_security', 'admin', function(xPlayer, args, showError)
    local stats = {
        activeTestDrives = 0,
        suspiciousPlayers = 0,
        rateLimitedActions = 0
    }
    
    for _ in pairs(activeTestDrives) do
        stats.activeTestDrives = stats.activeTestDrives + 1
    end
    
    for _ in pairs(suspiciousActivity) do
        stats.suspiciousPlayers = stats.suspiciousPlayers + 1
    end
    
    for _ in pairs(playerActions) do
        stats.rateLimitedActions = stats.rateLimitedActions + 1
    end
    
    local message = string.format([[
🛡️ AUTOHAUS SECURITY STATUS:
• Aktive Testfahrten: %d
• Verdächtige Spieler: %d  
• Rate-limitierte Aktionen: %d
• System Status: AKTIV ✅
    ]], stats.activeTestDrives, stats.suspiciousPlayers, stats.rateLimitedActions)
    
    TriggerClientEvent('chat:addMessage', xPlayer.source, {
        color = {255, 165, 0},
        multiline = true,
        args = {"AUTOHAUS SECURITY", message}
    })
    
end, false, {help = 'Autohaus Sicherheitsstatus anzeigen'})

-- Funktion: Bestimme Spawn-Koordinaten für Probefahrt
function GetTestDriveSpawnCoords(playerId)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer then return vector3(-1200.0, -1740.0, 4.0) end -- Fallback
    
    local playerCoords = GetEntityCoords(GetPlayerPed(playerId))
    
    -- EINFACHE Logik: Finde das nächstgelegene Autohaus
    local closestSpawn = nil
    local closestDistance = math.huge
    
    for dealershipId, dealership in pairs(Config.Dealerships) do
        if dealership.testDriveSpawn then
            local distance = #(playerCoords - dealership.testDriveSpawn)
            if distance < closestDistance then
                closestDistance = distance
                closestSpawn = dealership.testDriveSpawn
            end
        end
    end
    
    -- Verwende den nächstgelegenen Spawn-Punkt
    if closestSpawn then
        DebugPrint("Verwende Testdrive-Spawn: " .. closestSpawn.x .. ", " .. closestSpawn.y .. ", " .. closestSpawn.z)
        return closestSpawn
    else
        -- Fallback falls kein Spawn-Punkt definiert
        DebugPrint("WARNUNG: Kein testDriveSpawn definiert, verwende Fallback")
        return vector3(-1200.0, -1740.0, 4.0)
    end
end

-- Admin Command: Aktive Probefahrten anzeigen
ESX.RegisterCommand('testdrives', 'admin', function(xPlayer, args, showError)
    local count = 0
    local message = "🚗 **Aktive Probefahrten:**\n"
    
    for playerId, testDrive in pairs(activeTestDrives) do
        local player = ESX.GetPlayerFromId(playerId)
        if player then
            local duration = os.time() - testDrive.startTime
            message = message .. string.format("• %s - %s (seit %d Sekunden)\n", 
                player.getName(), testDrive.model, duration)
            count = count + 1
        end
    end
    
    if count == 0 then
        message = message .. "Keine aktiven Probefahrten."
    end
    
    TriggerClientEvent('chat:addMessage', xPlayer.source, {
        color = {0, 255, 255},
        multiline = true,
        args = {"AUTOHAUS", message}
    })
end, false, {help = 'Zeigt alle aktiven Probefahrten an'})

-- Admin Command: Probefahrt eines Spielers beenden
ESX.RegisterCommand('endtestdrive', 'admin', function(xPlayer, args, showError)
    local targetId = tonumber(args.target)
    
    if not targetId or not activeTestDrives[targetId] then
        return xPlayer.showNotification('Spieler hat keine aktive Probefahrt!', 'error')
    end
    
    local targetPlayer = ESX.GetPlayerFromId(targetId)
    if targetPlayer then
        -- Beende Probefahrt auf Client
        TriggerClientEvent('autohaus:forceEndTestDrive', targetId)
        
        -- Entferne aus Tracking
        activeTestDrives[targetId] = nil
        
        xPlayer.showNotification(string.format('Probefahrt von %s beendet.', targetPlayer.getName()), 'success')
        targetPlayer.showNotification('Deine Probefahrt wurde von einem Admin beendet.', 'info')
    end
end, false, {help = 'Beendet die Probefahrt eines Spielers', validate = true, arguments = {
    {name = 'target', help = 'Spieler ID', type = 'player'}
}})

-- Cleanup bei Spieler Disconnect
AddEventHandler('esx:playerDropped', function(playerId)
    if activeTestDrives[playerId] then
        activeTestDrives[playerId] = nil
        DebugPrint("Probefahrt für disconnected Spieler " .. playerId .. " entfernt")
    end
end)

function GetTestDriveSpawnCoords(playerId)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer then return vector3(0, 0, 0) end
    
    local playerCoords = GetEntityCoords(GetPlayerPed(playerId))
    
    -- Finde das nächstgelegene Autohaus mit dessen spezifischen Einstellungen
    local nearestDealership = nil
    local nearestDistance = math.huge
    local dealershipId = nil
    
    for id, dealership in pairs(Config.Dealerships) do
        if dealership.testDriveSpawn then
            local distance = #(playerCoords - dealership.testDriveSpawn)
            if distance < nearestDistance then
                nearestDistance = distance
                nearestDealership = dealership
                dealershipId = id
            end
        end
    end
    
    -- Speichere Autohaus-Info für späteren Zugriff
    if nearestDealership and activeTestDrives[playerId] then
        activeTestDrives[playerId].dealershipId = dealershipId
        activeTestDrives[playerId].dealershipName = nearestDealership.name
        activeTestDrives[playerId].maxDistance = nearestDealership.testDriveSettings and 
                                               nearestDealership.testDriveSettings.maxDistance or 
                                               (Config.TestDrive.restrictions and Config.TestDrive.restrictions.maxDistance) or 1500
    end
    
    -- Verwende spezifischen Spawn-Punkt oder Fallback
    if nearestDealership and nearestDealership.testDriveSpawn then
        return nearestDealership.testDriveSpawn
    else
        -- Fallback: 50 Meter vor dem Spieler
        local heading = GetEntityHeading(GetPlayerPed(playerId))
        local offsetX = math.sin(math.rad(heading)) * 50
        local offsetY = math.cos(math.rad(heading)) * 50
        
        return vector3(
            playerCoords.x + offsetX,
            playerCoords.y + offsetY,
            playerCoords.z
        )
    end
end

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        -- Alle aktiven Probefahrten beenden
        for playerId, _ in pairs(activeTestDrives) do
            TriggerClientEvent('autohaus:forceEndTestDrive', playerId)
        end
        
        activeTestDrives = {}
        DebugPrint("Alle Probefahrten bei Resource Stop beendet")
    end
end)