local ESX = nil
local PlayerData = {}
local showroomVehicles = {}
local blips = {}
local isUIOpen = false

-- Debug Flag
local DEBUG = false

local function DebugPrint(message)
    if DEBUG then
        print("[AUTOHAUS DEBUG] " .. tostring(message))
    end
end

-- ESX Framework initialisieren
Citizen.CreateThread(function()
    DebugPrint("Initialisiere ESX Framework...")
    
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        Citizen.Wait(0)
    end
    
    DebugPrint("ESX Framework geladen!")
    
    while ESX.GetPlayerData().job == nil do
        Citizen.Wait(10)
    end
    
    PlayerData = ESX.GetPlayerData()
    DebugPrint("Spielerdaten geladen: " .. PlayerData.name)
end)

-- UI Setup
Citizen.CreateThread(function()
    DebugPrint("UI Setup gestartet")
    SetNuiFocus(false, false)
end)

-- Showroom Fahrzeuge spawnen/despawnen
Citizen.CreateThread(function()
    DebugPrint("Showroom Thread gestartet")
    
    while true do
        if ESX ~= nil then
            local playerCoords = GetEntityCoords(PlayerPedId())
            local nearAnyDealership = false
            
            for dealershipId, dealership in pairs(Config.Dealerships) do
                -- Prüfe erstmal Entfernung zum Autohaus
                local dealershipDistance = #(playerCoords - dealership.blip.coords)
                
                if dealershipDistance < Config.ShowRange * 1.5 then -- 1.5x als Buffer
                    nearAnyDealership = true
                    
                    for carIndex, car in pairs(dealership.cars) do
                        local distance = #(playerCoords - car.pos)
                        local vehicleKey = dealershipId .. "_" .. carIndex
                        
                        if distance < Config.ShowRange then
                            if not showroomVehicles[vehicleKey] then
                                DebugPrint("Spawne Showroom Fahrzeug: " .. car.label .. " (Entfernung: " .. math.floor(distance) .. "m)")
                                SpawnShowroomVehicle(dealershipId, carIndex, car)
                            end
                        else
                            if showroomVehicles[vehicleKey] then
                                DebugPrint("Entferne Showroom Fahrzeug: " .. car.label)
                                DeleteEntity(showroomVehicles[vehicleKey])
                                showroomVehicles[vehicleKey] = nil
                            end
                        end
                    end
                end
            end
            
            -- ✅ SMART WAIT: Länger warten wenn weit weg von Autohäusern
            if nearAnyDealership then
                Citizen.Wait(1000) -- Normal wenn in der Nähe
            else
                Citizen.Wait(3000) -- ✅ 3x länger wenn weit weg
            end
        else
            Citizen.Wait(1000)
        end
    end
end)


-- 3D Text und Interaktion (jetzt mit UI)
Citizen.CreateThread(function()
    DebugPrint("Interaktions-Thread gestartet")
    
    while true do
        if ESX ~= nil and not isUIOpen then
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local sleep = true
            local foundInteraction = false
            
            for dealershipId, dealership in pairs(Config.Dealerships) do
                -- ✅ FRÜHER AUSGANG: Prüfe Autohaus-Entfernung zuerst
                local dealershipDistance = #(playerCoords - dealership.blip.coords)
                if dealershipDistance < 50 then -- Nur wenn nah am Autohaus
                    
                    for carIndex, car in pairs(dealership.cars) do
                        local distance = #(playerCoords - car.pos)
                        
                        if distance < 5.0 then
                            sleep = false
                            foundInteraction = true
                            
                            -- 3D Text anzeigen
                            Draw3DText(
                                car.pos.x, car.pos.y, car.pos.z + 1.0,
                                car.label,
                                4, 0.25, 0.25
                            )
                            
                            -- Interaktion mit E-Taste
                            if distance < 2.0 then
                                Draw3DText(
                                    car.pos.x, car.pos.y, car.pos.z + 0.5,
                                    string.format("~g~%s%s~w~ - Drücke ~INPUT_CONTEXT~", Config.Currency, FormatMoney(car.price)),
                                    4, 0.2, 0.2
                                )
                                
                                if IsControlJustPressed(0, Config.BuyKey) then
                                    DebugPrint("E-Taste gedrückt bei Fahrzeug: " .. car.label)
                                    DebugPrint("Dealership ID: " .. dealershipId .. ", Car Index: " .. carIndex)
                                    OpenVehicleUI(dealershipId, carIndex, car)
                                end
                            end
                        end
                    end
                end
            end
            
            -- ✅ SMART WAIT: Unterschiedliche Waits basierend auf Situation
            if sleep then
                if foundInteraction then
                    Citizen.Wait(250) -- Kurzes Wait wenn Interaktion in der Nähe war
                else
                    Citizen.Wait(1000) -- Längeres Wait wenn weit weg
                end
            end
        else
            Citizen.Wait(1000)
        end
        
        if not sleep then
            Citizen.Wait(0) -- Nur wenn aktive Interaktion
        end
    end
end)

-- ESC Key Handler
Citizen.CreateThread(function()
    while true do
        if isUIOpen then
            if IsControlJustPressed(0, 322) then -- ESC Key
                DebugPrint("ESC Taste gedrückt - schließe UI")
                CloseVehicleUI()
            end
            Citizen.Wait(100) -- ✅ Weniger frequent checking
        else
            Citizen.Wait(500) -- ✅ Längere Pause wenn UI geschlossen
        end
    end
end)

-- UI Funktionen
local lastUIAction = 0
local UI_COOLDOWN = 1000 -- 1 Sekunde zwischen Aktionen

function CheckUICooldown()
    local now = GetGameTimer()
    if (now - lastUIAction) < UI_COOLDOWN then
        DebugPrint("UI Cooldown aktiv - Aktion blockiert")
        ESX.ShowNotification('Zu schnell! Warte einen Moment.', "error")
        return false
    end
    lastUIAction = now
    return true
end

-- ✅ SICHERE OpenVehicleUI mit zusätzlichen Checks:
function OpenVehicleUI(dealershipId, carIndex, car)
    -- ✅ COOLDOWN CHECK
    if not CheckUICooldown() then
        return
    end
    
    DebugPrint("OpenVehicleUI aufgerufen")
    
    if isUIOpen then 
        DebugPrint("UI bereits offen - Abbruch")
        return 
    end
    
    -- ✅ PARAMETER VALIDATION
    if not dealershipId or not carIndex or not car then
        DebugPrint("FEHLER: Fehlende OpenVehicleUI Parameter")
        return
    end
    
    -- ✅ CONFIG DOUBLE-CHECK
    local configCar = Config.Dealerships[dealershipId] and Config.Dealerships[dealershipId].cars[carIndex]
    if not configCar then
        DebugPrint("FEHLER: Fahrzeug nicht in Config gefunden")
        return
    end
    
    -- ✅ DATA INTEGRITY CHECK
    if configCar.model ~= car.model or configCar.price ~= car.price then
        DebugPrint("FEHLER: Fahrzeugdaten stimmen nicht mit Config überein!")
        return
    end
    
    isUIOpen = true
    SetNuiFocus(true, true)
    
    -- Kategorie bestimmen
    local category = car.category or GetVehicleCategory(car.model)
    
    -- ✅ SICHERE UI Daten (nur was nötig ist)
    local uiData = {
        model = car.model,
        displayName = car.label,
        price = car.price,
        category = category,
        dealershipId = dealershipId,
        dealershipName = Config.Dealerships[dealershipId].name,
        carIndex = carIndex
    }
    
    SendNUIMessage({
        type = 'openVehicleModal',
        data = uiData
    })
    
    DebugPrint("Sichere UI geöffnet")
end

function CloseVehicleUI()
    DebugPrint("CloseVehicleUI aufgerufen")
    
    if not isUIOpen then 
        DebugPrint("UI bereits geschlossen")
        return 
    end
    
    isUIOpen = false
    SetNuiFocus(false, false)
    DebugPrint("NUI Focus entfernt")
    
    SendNUIMessage({
        type = 'closeVehicleModal'
    })
    
    DebugPrint("Close NUI Message gesendet")
end

-- Delayed UI Close - Lässt das React UI seine Animation abspielen
function DelayedCloseVehicleUI(delay)
    DebugPrint("DelayedCloseVehicleUI aufgerufen mit " .. delay .. "ms Verzögerung")
    
    Citizen.SetTimeout(delay or 1000, function()
        DebugPrint("Verzögertes Schließen wird ausgeführt")
        CloseVehicleUI()
    end)
end

-- NUI Callbacks
RegisterNUICallback('closeUI', function(data, cb)
    DebugPrint("NUI Callback: closeUI")
    CloseVehicleUI()
    cb('ok')
end)

RegisterNUICallback('buyVehicle', function(data, cb)
    DebugPrint("NUI Callback: buyVehicle")
    
    -- ✅ INPUT VALIDATION
    local dealershipId = data.dealershipId
    local carIndex = data.carIndex
    
    if not dealershipId or not carIndex then
        DebugPrint("FEHLER: Fehlende buyVehicle Parameter")
        cb('error')
        return
    end
    
    -- ✅ TYPE VALIDATION
    if type(dealershipId) ~= "string" or type(carIndex) ~= "number" then
        DebugPrint("FEHLER: Ungültige buyVehicle Parameter-Typen")
        cb('error')
        return
    end
    
    -- ✅ RANGE VALIDATION
    if carIndex < 1 or carIndex > 100 then
        DebugPrint("FEHLER: carIndex außerhalb gültigem Bereich")
        cb('error')
        return
    end
    
    -- ✅ CONFIG VALIDATION
    if not Config.Dealerships[dealershipId] or not Config.Dealerships[dealershipId].cars[carIndex] then
        DebugPrint("FEHLER: Fahrzeug existiert nicht in Config")
        cb('error')
        return
    end
    
    DebugPrint("Sende sichere Kaufanfrage: " .. dealershipId .. " / " .. carIndex)
    
    -- ✅ SICHER: Nur IDs senden, KEINE Fahrzeugdaten
    TriggerServerEvent('autohaus:buyVehicle', dealershipId, carIndex)
    cb('success')
end)

local currentTestDrive = nil

RegisterNUICallback('testDrive', function(data, cb)
    DebugPrint("NUI Callback: testDrive")
    
    -- ✅ INPUT VALIDATION
    local dealershipId = data.dealershipId
    local carIndex = data.carIndex
    
    if not dealershipId or not carIndex then
        DebugPrint("FEHLER: Fehlende testDrive Parameter")
        cb('error')
        return
    end
    
    -- ✅ TYPE VALIDATION
    if type(dealershipId) ~= "string" or type(carIndex) ~= "number" then
        DebugPrint("FEHLER: Ungültige testDrive Parameter-Typen")
        cb('error')
        return
    end
    
    -- ✅ CONFIG VALIDATION
    if not Config.Dealerships[dealershipId] or not Config.Dealerships[dealershipId].cars[carIndex] then
        DebugPrint("FEHLER: Testfahrzeug existiert nicht in Config")
        cb('error')
        return
    end
    
    -- Prüfe ob bereits eine Probefahrt aktiv ist
    if currentTestDrive and DoesEntityExist(currentTestDrive.vehicle) then
        ESX.ShowNotification('Du bist bereits auf einer Probefahrt!', "error")
        cb('error')
        return
    end
    
    DebugPrint("Sende sichere Testfahrt-Anfrage: " .. dealershipId .. " / " .. carIndex)
    
    -- ✅ SICHER: Nur IDs senden, KEIN Model
    TriggerServerEvent('autohaus:startTestDrive', dealershipId, carIndex)
    cb('success')
end)

-- Showroom Fahrzeug spawnen
function SpawnShowroomVehicle(dealershipId, carIndex, car)
    local vehicleKey = dealershipId .. "_" .. carIndex
    
    Citizen.CreateThread(function()
        local hash = GetHashKey(car.model)
        RequestModel(hash)
        
        DebugPrint("Lade Model: " .. car.model .. " (Hash: " .. hash .. ")")
        
        local timeout = 0
        while not HasModelLoaded(hash) and timeout < 5000 do
            timeout = timeout + 100
            Citizen.Wait(100)
        end
        
        if HasModelLoaded(hash) then
            local vehicle = CreateVehicle(hash, car.pos.x, car.pos.y, car.pos.z - 1.0, car.heading, false, false)
            
            if DoesEntityExist(vehicle) then
                DebugPrint("Fahrzeug erfolgreich gespawnt: " .. car.label)
                
                -- Fahrzeug Eigenschaften setzen
                SetVehicleEngineOn(vehicle, false, false, true)
                SetVehicleBrakeLights(vehicle, false)
                SetVehicleLights(vehicle, 0)
                SetVehicleLightsMode(vehicle, 0)
                SetVehicleOnGroundProperly(vehicle)
                FreezeEntityPosition(vehicle, true)
                SetVehicleCanBreak(vehicle, false)
                SetVehicleDirtLevel(vehicle, 0.0)
                
                -- Zufällige Farben
                local primaryColor = math.random(0, 159)
                local secondaryColor = math.random(0, 159)
                SetVehicleColours(vehicle, primaryColor, secondaryColor)
                
                -- Unverwundbarkeit
                if Config.CarInvincible then
                    SetEntityInvincible(vehicle, true)
                    SetVehicleCanBeVisiblyDamaged(vehicle, false)
                end
                
                -- Türen verschließen
                if Config.DoorLock then
                    SetVehicleDoorsLocked(vehicle, 2)
                end
                
                SetVehicleNumberPlateText(vehicle, car.plate)
                showroomVehicles[vehicleKey] = vehicle
            else
                DebugPrint("FEHLER: Fahrzeug konnte nicht gespawnt werden!")
            end
        else
            DebugPrint("FEHLER: Model konnte nicht geladen werden: " .. car.model)
        end
        
        SetModelAsNoLongerNeeded(hash)
    end)
end

-- Spinning Fahrzeuge (falls aktiviert)
Citizen.CreateThread(function()
    while true do
        local hasSpinningVehicles = false
        
        for dealershipId, dealership in pairs(Config.Dealerships) do
            for carIndex, car in pairs(dealership.cars) do
                if car.spin then
                    hasSpinningVehicles = true
                    local vehicleKey = dealershipId .. "_" .. carIndex
                    if showroomVehicles[vehicleKey] then
                        local currentHeading = GetEntityHeading(showroomVehicles[vehicleKey])
                        SetEntityHeading(showroomVehicles[vehicleKey], currentHeading + 0.75) -- Etwas schneller für weniger Updates
                    end
                end
            end
        end
        
        -- SMART WAIT: Nur kurz warten wenn Spinning-Fahrzeuge aktiv sind
        if hasSpinningVehicles then
            Citizen.Wait(150) -- ✅ 3x langsamer als vorher
        else
            Citizen.Wait(1000) -- Viel länger wenn keine Spinning-Fahrzeuge
        end
    end
end)

-- Server Events
RegisterNetEvent('autohaus:vehiclePurchased')
AddEventHandler('autohaus:vehiclePurchased', function(car, plate, dealershipId)
    DebugPrint("Fahrzeug erfolgreich gekauft: " .. car.label .. " (" .. plate .. ")")
    
    -- ✅ WICHTIG: UI wird NICHT hier geschlossen!
    -- Das React UI übernimmt das komplette Schließen mit Animation
    
    -- Zeige nur die ESX Benachrichtigung
    ESX.ShowNotification(string.format('🚗 Fahrzeug gekauft! %s (Kennzeichen: %s) wurde in deine Garage gespeichert.', 
        car.label, plate), "success")
    
    -- Optional: Wegpunkt zur Garage setzen
    if Config.GarageNotifications and Config.GarageNotifications.setWaypoint then
        SetNewWaypoint(Config.GarageNotifications.waypointCoords.x, Config.GarageNotifications.waypointCoords.y)
        ESX.ShowNotification(string.format('📍 Wegpunkt zu %s gesetzt!', 
            Config.GarageNotifications.garageLocation or "deiner Garage"), "info")
    end
end)

-- Probefahrt Event
RegisterNetEvent('autohaus:startTestDrive')
AddEventHandler('autohaus:startTestDrive', function(model, spawnCoords)
    DebugPrint("Starte Probefahrt mit: " .. model)
    
    local playerPed = PlayerPedId()
    local coords = spawnCoords or GetEntityCoords(playerPed)
    
    -- Speichere Start-Koordinaten für Teleport-zurück
    local startCoords = GetEntityCoords(playerPed)
    
    -- Verbesserte Spawn-Punkt Suche
    local spawnPoint = GetSafeTestDriveSpawnPoint(coords)
    
    local hash = GetHashKey(model)
    RequestModel(hash)
    
    -- Verbesserte Model Loading mit Timeout
    local timeout = 0
    local maxTimeout = 10000 -- 10 Sekunden
    
    while not HasModelLoaded(hash) and timeout < maxTimeout do
        timeout = timeout + 100
        Citizen.Wait(100)
    end
    
    if HasModelLoaded(hash) then
        local vehicle = CreateVehicle(hash, spawnPoint.x, spawnPoint.y, spawnPoint.z, 0.0, true, false)
        
        if DoesEntityExist(vehicle) then
            DebugPrint("Probefahrt-Fahrzeug gespawnt!")
            
            -- Fahrzeug Setup
            SetVehicleNumberPlateText(vehicle, "PROBE")
            SetEntityAsMissionEntity(vehicle, true, true)
            SetVehicleEngineOn(vehicle, true, true, false)
            SetVehicleDoorsLocked(vehicle, 1)
            SetVehicleFuelLevel(vehicle, 100.0) -- Volltanken
            
            -- Fahrzeug-Eigenschaften für bessere Performance
            SetVehicleModKit(vehicle, 0)
            SetVehicleMod(vehicle, 11, 3, false) -- Engine
            SetVehicleMod(vehicle, 12, 2, false) -- Brakes
            SetVehicleMod(vehicle, 13, 2, false) -- Transmission
            
            -- Spieler ins Fahrzeug setzen
            TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
            
            -- Testdrive Daten speichern (ERWEITERT mit startCoords)
            currentTestDrive = {
                vehicle = vehicle,
                model = model,
                startTime = GetGameTimer(),
                duration = Config.TestDrive.duration * 1000, -- In Millisekunden
                startCoords = startCoords, -- NEU: Start-Position für Teleport
                spawnCoords = spawnPoint   -- NEU: Spawn-Position des Fahrzeugs
            }
            
            -- UI für aktive Probefahrt
            ShowTestDriveUI()
            
            ESX.ShowNotification('🚗 Probefahrt gestartet! Entferne dich nicht zu weit vom Autohaus!', "success")
            
            -- Timer für automatisches Entfernen
            Citizen.SetTimeout(Config.TestDrive.duration * 1000, function()
                EndTestDrive()
            end)
            
            -- Thread für Probefahrt-Überwachung
            StartTestDriveMonitoring()
        else
            DebugPrint("FEHLER: Probefahrt-Fahrzeug konnte nicht gespawnt werden!")
            ESX.ShowNotification('❌ Fahrzeug konnte nicht gespawnt werden!', "error")
        end
        
        SetModelAsNoLongerNeeded(hash)
    else
        DebugPrint("FEHLER: Probefahrt-Model konnte nicht geladen werden!")
        ESX.ShowNotification('❌ Fahrzeug konnte nicht geladen werden!', "error")
    end
end)

-- Blips erstellen
Citizen.CreateThread(function()
    DebugPrint("Erstelle Blips...")
    
    for dealershipId, dealership in pairs(Config.Dealerships) do
        local blip = AddBlipForCoord(dealership.blip.coords.x, dealership.blip.coords.y, dealership.blip.coords.z)
        SetBlipSprite(blip, dealership.blip.sprite)
        SetBlipColour(blip, dealership.blip.color)
        SetBlipScale(blip, dealership.blip.scale)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName(dealership.name)
        EndTextCommandSetBlipName(blip)
        
        blips[dealershipId] = blip
        DebugPrint("Blip erstellt für: " .. dealership.name)
    end
end)

-- Resource Stop Event
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        -- UI schließen
        if isUIOpen then
            CloseVehicleUI()
        end
        
        -- Probefahrt beenden
        if currentTestDrive then
            EndTestDrive()
        end
        
        -- Alle Showroom Fahrzeuge löschen
        for _, vehicle in pairs(showroomVehicles) do
            if DoesEntityExist(vehicle) then
                DeleteEntity(vehicle)
            end
        end
        
        -- Alle Blips entfernen
        for _, blip in pairs(blips) do
            if DoesBlipExist(blip) then
                RemoveBlip(blip)
            end
        end
        
        DebugPrint("Resource sauber gestoppt")
    end
end)

-- Debug Command
RegisterCommand('autohaus_debug', function()
    DebugPrint("=== AUTOHAUS DEBUG INFO ===")
    DebugPrint("ESX geladen: " .. tostring(ESX ~= nil))
    DebugPrint("UI Status: " .. (isUIOpen and "OFFEN" or "GESCHLOSSEN"))
    DebugPrint("Showroom Fahrzeuge: " .. #showroomVehicles)
    DebugPrint("Config Autohäuser: " .. #Config.Dealerships)
    
    local playerCoords = GetEntityCoords(PlayerPedId())
    DebugPrint("Spieler Position: " .. playerCoords.x .. ", " .. playerCoords.y .. ", " .. playerCoords.z)
    
    -- Nächstes Fahrzeug finden
    local closestDistance = 999999
    local closestCar = nil
    for dealershipId, dealership in pairs(Config.Dealerships) do
        for carIndex, car in pairs(dealership.cars) do
            local distance = #(playerCoords - car.pos)
            if distance < closestDistance then
                closestDistance = distance
                closestCar = car.label
            end
        end
    end
    
    if closestCar then
        DebugPrint("Nächstes Fahrzeug: " .. closestCar .. " (Entfernung: " .. math.floor(closestDistance) .. "m)")
    end
    
    DebugPrint("=== ENDE DEBUG INFO ===")
end, false)

-- Hilfsfunktionen
function Draw3DText(x, y, z, textInput, fontId, scaleX, scaleY)
    local px, py, pz = table.unpack(GetGameplayCamCoords())
    local dist = GetDistanceBetweenCoords(px, py, pz, x, y, z, 1)
    
    local scale = (1 / dist) * 8
    local fov = (1 / GetGameplayCamFov()) * 100
    scale = scale * fov
    
    if scale > 1.0 then scale = 1.0 end
    if scale < 0.3 then scale = 0.3 end
    
    SetTextScale(scaleX * scale, scaleY * scale)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 230)
    SetTextDropshadow(1, 0, 0, 0, 180)
    SetTextOutline()
    SetTextEntry("STRING")
    SetTextCentre(1)
    AddTextComponentString(textInput)
    SetDrawOrigin(x, y, z, 0)
    DrawText(0.0, 0.0)
    ClearDrawOrigin()
end

function FormatMoney(amount)
    local formatted = tostring(amount)
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    return formatted
end

function GetVehicleCategory(model)
    local vehicleClass = GetVehicleClassFromName(GetHashKey(model))
    local categories = {
        [0] = "Kompaktwagen",
        [1] = "Limousine",
        [2] = "SUV",
        [3] = "Coupé",
        [4] = "Muscle",
        [5] = "Sport Classic",
        [6] = "Sport",
        [7] = "Super",
        [8] = "Motorrad",
        [9] = "Offroad",
        [10] = "Industriell",
        [11] = "Nutzfahrzeug",
        [12] = "Van",
        [13] = "Fahrrad",
        [14] = "Boot",
        [15] = "Helikopter",
        [16] = "Flugzeug",
        [17] = "Service",
        [18] = "Notfall",
        [19] = "Militär",
        [20] = "Kommerziell",
        [21] = "Zug"
    }
    return categories[vehicleClass] or "Unbekannt"
end

function GetSafeTestDriveSpawnPoint(coords)
    local testOffsets = {
        {x = 10, y = 0, z = 0},
        {x = -10, y = 0, z = 0},
        {x = 0, y = 10, z = 0},
        {x = 0, y = -10, z = 0},
        {x = 15, y = 15, z = 0},
        {x = -15, y = -15, z = 0},
        {x = 20, y = 0, z = 0},
        {x = 0, y = 20, z = 0}
    }
    
    for _, offset in pairs(testOffsets) do
        local testCoords = vector3(coords.x + offset.x, coords.y + offset.y, coords.z + offset.z)
        
        -- Prüfe Ground Level
        local groundZ = GetGroundZFor_3dCoord(testCoords.x, testCoords.y, testCoords.z, false)
        if groundZ and groundZ > 0 then
            testCoords = vector3(testCoords.x, testCoords.y, groundZ + 1.0)
        end
        
        -- Prüfe auf andere Fahrzeuge in der Nähe
        local vehicles = ESX.Game.GetVehiclesInArea(testCoords, 5.0)
        if #vehicles == 0 then
            -- Prüfe auf freien Raum
            local clear = IsPositionOccupied(testCoords.x, testCoords.y, testCoords.z, 3.0, false, true, true, false, false, 0, false)
            if not clear then
                return testCoords
            end
        end
    end
    
    -- Fallback: Ursprüngliche Koordinaten
    return coords
end

-- Neue Funktion: Probefahrt-Überwachung
function StartTestDriveMonitoring()
    if not currentTestDrive then return end
    
    Citizen.CreateThread(function()
        while currentTestDrive and DoesEntityExist(currentTestDrive.vehicle) do
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            
            -- Prüfe Entfernung zum Start-Punkt (Autohaus)
            local distanceToStart = #(playerCoords - currentTestDrive.startCoords)
            local maxDistance = Config.TestDrive.restrictions.maxDistance or 1500
            
            DebugPrint("Aktuelle Entfernung zum Autohaus: " .. math.floor(distanceToStart) .. "m (Max: " .. maxDistance .. "m)")
            
            -- Wenn zu weit weg - SOFORT teleportieren
            if distanceToStart > maxDistance then
                DebugPrint("Spieler zu weit weg - teleportiere zurück!")
                ESX.ShowNotification('⚠️ Du bist zu weit vom Autohaus entfernt! Du wirst zurück teleportiert!', "warning")
                
                TeleportBackToStart()
                
                -- Kurze Pause nach Teleport
                Citizen.Wait(2000)
            end
            
            Citizen.Wait(5000) -- ✅ 5 Sekunden statt 3
        end
        
        DebugPrint("TestDrive Monitoring beendet")
    end)
end

-- NEUE FUNKTION: Teleportiere Spieler zurück zum Start
function TeleportBackToStart()
    if not currentTestDrive then 
        DebugPrint("Kein currentTestDrive gefunden!")
        return 
    end
    
    local playerPed = PlayerPedId()
    local vehicle = currentTestDrive.vehicle
    local startCoords = currentTestDrive.startCoords
    
    DebugPrint("Teleportiere zurück zu: " .. startCoords.x .. ", " .. startCoords.y .. ", " .. startCoords.z)
    
    if DoesEntityExist(vehicle) then
        DebugPrint("Fahrzeug existiert - teleportiere mit Fahrzeug")
        
        -- 1. Fahrzeug teleportieren
        SetEntityCoords(vehicle, startCoords.x, startCoords.y, startCoords.z, false, false, false, true)
        SetEntityHeading(vehicle, 0.0)
        
        -- 2. Spieler ins Fahrzeug setzen falls nicht drin
        local currentVehicle = GetVehiclePedIsIn(playerPed, false)
        if currentVehicle ~= vehicle then
            DebugPrint("Setze Spieler ins Fahrzeug")
            TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
        end
        
        -- 3. Fahrzeug auf Boden setzen und stabilisieren
        Citizen.SetTimeout(500, function()
            if DoesEntityExist(vehicle) then
                SetVehicleOnGroundProperly(vehicle)
                SetVehicleEngineOn(vehicle, true, true, false)
                DebugPrint("Fahrzeug stabilisiert")
            end
        end)
        
    else
        DebugPrint("Fahrzeug existiert nicht - teleportiere nur Spieler")
        
        -- Nur Spieler teleportieren
        SetEntityCoords(playerPed, startCoords.x, startCoords.y, startCoords.z, false, false, false, true)
        
        -- Alternative mit ESX.Game.Teleport (falls verfügbar)
        if ESX.Game and ESX.Game.Teleport then
            ESX.Game.Teleport(playerPed, startCoords)
            DebugPrint("Teleport mit ESX.Game.Teleport")
        end
    end
    
    ESX.ShowNotification('📍 Du wurdest zurück zum Autohaus teleportiert!', "info")
    DebugPrint("Teleport abgeschlossen")
end

-- Neue Funktion: Probefahrt beenden
function EndTestDrive()
    if not currentTestDrive then 
        DebugPrint("EndTestDrive: Kein currentTestDrive aktiv")
        return 
    end
    
    DebugPrint("Beende Probefahrt...")
    
    local playerPed = PlayerPedId()
    local vehicle = currentTestDrive.vehicle
    local startCoords = currentTestDrive.startCoords
    
    if DoesEntityExist(vehicle) then
        DebugPrint("Fahrzeug existiert - entferne Spieler und lösche Fahrzeug")
        
        -- Spieler aus Fahrzeug nehmen falls drin
        if GetVehiclePedIsIn(playerPed, false) == vehicle then
            TaskLeaveVehicle(playerPed, vehicle, 0)
            
            -- Warte bis Spieler ausgestiegen ist
            local timeout = 0
            while GetVehiclePedIsIn(playerPed, false) == vehicle and timeout < 50 do
                Citizen.Wait(100)
                timeout = timeout + 1
            end
        end
        
        -- Spieler zum Autohaus teleportieren
        DebugPrint("Teleportiere Spieler zurück zum Autohaus")
        SetEntityCoords(playerPed, startCoords.x, startCoords.y, startCoords.z, false, false, false, true)
        
        -- Alternative Teleport-Methode
        if ESX.Game and ESX.Game.Teleport then
            ESX.Game.Teleport(playerPed, startCoords)
        end
        
        -- Fahrzeug löschen
        Citizen.SetTimeout(1000, function()
            if DoesEntityExist(vehicle) then
                ESX.Game.DeleteVehicle(vehicle)
                DebugPrint("Fahrzeug gelöscht")
            end
        end)
        
    else
        DebugPrint("Fahrzeug existiert nicht mehr - teleportiere nur Spieler")
        SetEntityCoords(playerPed, startCoords.x, startCoords.y, startCoords.z, false, false, false, true)
    end
    
    -- UI verstecken
    HideTestDriveUI()
    
    -- Server benachrichtigen
    TriggerServerEvent('autohaus:endTestDrive')
    
    -- Cleanup
    currentTestDrive = nil
    
    ESX.ShowNotification('🚗 Probefahrt beendet!', "info")
    DebugPrint("Probefahrt vollständig beendet")
end

-- Neue Funktion: Probefahrt UI anzeigen
function ShowTestDriveUI()
    if not currentTestDrive then return end
    
    SendNUIMessage({
        type = 'showTestDriveUI',
        data = {
            model = currentTestDrive.model,
            duration = Config.TestDrive.duration,
            startTime = currentTestDrive.startTime
        }
    })
end

-- Neue Funktion: Probefahrt UI aktualisieren
function UpdateTestDriveUI()
    if not currentTestDrive then return end
    
    local elapsed = (GetGameTimer() - currentTestDrive.startTime) / 1000
    local remaining = math.max(0, Config.TestDrive.duration - elapsed)
    
    -- Berechne Entfernung zum Autohaus
    local playerCoords = GetEntityCoords(PlayerPedId())
    local distance = math.floor(#(playerCoords - currentTestDrive.startCoords))
    local maxDistance = Config.TestDrive.restrictions.maxDistance or 2000
    
    SendNUIMessage({
        type = 'updateTestDriveUI',
        data = {
            remaining = remaining,
            distance = distance,
            maxDistance = maxDistance,
            distanceWarning = distance > (maxDistance * 0.8) -- Warnung bei 80% der max Entfernung
        }
    })
end

-- Neue Funktion: Probefahrt UI verstecken
function HideTestDriveUI()
    SendNUIMessage({
        type = 'hideTestDriveUI'
    })
end

-- Command zum manuellen Beenden der Probefahrt
RegisterCommand('testdrive_end', function()
    if currentTestDrive then
        EndTestDrive()
    else
        ESX.ShowNotification('Du bist nicht auf einer Probefahrt!', "error")
    end
end, false)

-- Event Handler für erzwungenes Beenden (Admin)
RegisterNetEvent('autohaus:forceEndTestDrive')
AddEventHandler('autohaus:forceEndTestDrive', function()
    if currentTestDrive then
        EndTestDrive()
    end
end)