Config = {}

-- Allgemeine Einstellungen
Config.ShowRange = 200
Config.DoorLock = false
Config.CarInvincible = true
Config.Currency = "$" -- Währungssymbol
Config.BuyKey = 38 -- E-Taste zum Kaufen (Key Code)

-- UI Einstellungen
Config.UI = {
    -- React UI verwenden statt 3D Text
    useReactUI = true,
    -- Fallback auf 3D Text falls UI nicht verfügbar
    fallbackTo3DText = true,
    -- UI Animation Einstellungen
    animations = {
        modalScale = true,      -- Modal Scale Animation
        modalBlur = true,       -- Backdrop Blur
        buttonHover = true,     -- Button Hover Effekte
        purchaseWarp = true     -- Warp-Effekt beim Kauf
    }
}

Config.Performance = {
    enableSpinning = false,        -- Komplett deaktivieren für beste Performance
    spinningUpdateRate = 150,      -- Millisekunden zwischen Updates
    showroomUpdateRate = 2000,     -- Showroom Check Rate wenn weit weg
    interactionRange = 50,         -- Max Entfernung für Autohaus-Checks
}

-- Garage Einstellungen
Config.DefaultParking = 'legion_parking' -- Standard Garage Name
Config.UseAdvancedVehicleProps = true -- Erweiterte Fahrzeug-Properties verwenden

-- Discord Webhook (optional)
Config.DiscordWebhook = false -- auf true setzen wenn gewünscht
Config.WebhookURL = "" -- Discord Webhook URL

-- Verkaufsstatistiken
Config.EnableSalesStats = true -- Verkaufsstatistiken aktivieren

-- Text Konfiguration
Config.Text = {
    not_enough_money = "Du hast nicht genug Geld!",
    vehicle_purchased = "Fahrzeug erfolgreich gekauft!",
    vehicle_saved_garage = "Das Fahrzeug wurde in deiner Garage gespeichert.",
    test_drive_started = "Probefahrt gestartet!",
    test_drive_ended = "Probefahrt beendet!",
    ui_open_hint = "Drücke E um das Fahrzeug zu betrachten",
    purchase_cooldown = "Du musst warten bevor du ein weiteres Fahrzeug kaufen kannst.",
    invalid_vehicle = "Ungültiges Fahrzeug ausgewählt."
}

-- Fahrzeug Spawn Einstellungen (deaktiviert für Garage-System)
Config.SpawnVehicle = {
    enabled = false,             -- Fahrzeug nicht spawnen, nur in Garage speichern
    putPlayerInVehicle = false,  -- Deaktiviert
    teleportPlayerIfNeeded = false, -- Deaktiviert
    deleteAfterTime = 0,         -- Deaktiviert
    showBlip = false,            -- Deaktiviert
    blipTime = 0,               -- Deaktiviert
    notifyLocation = false,      -- Deaktiviert
    maxSetInVehicleAttempts = 0, -- Deaktiviert
    networkWaitTime = 0,         -- Deaktiviert
    useNetworkedVehicles = false -- Deaktiviert
}

-- Garage Benachrichtigungen
Config.GarageNotifications = {
    showGarageInfo = false,       -- Info über Garage anzeigen
    garageLocation = "Legion Square Garage", -- Name der Standard-Garage
    setWaypoint = false,          -- Wegpunkt zur Garage setzen
    waypointCoords = vector3(215.9, -810.1, 30.7) -- Legion Square Garage Koordinaten
}

-- Kennzeichen Einstellungen
Config.Plate = {
    usePrefix = true,            -- Prefix verwenden
    prefix = "NS",               -- Server-Initialen als Prefix
    randomLength = 4,            -- Anzahl zufälliger Zeichen nach Prefix
    useSpace = false,            -- Leerzeichen zwischen Prefix und Zahlen (NS 1234 vs NS1234)
    onlyNumbers = true           -- Nur Zahlen für Random-Teil (false = Zahlen + Buchstaben)
}

-- Anti-Cheat Einstellungen
Config.Security = {
    enableAntiCheat = true,      -- Anti-Cheat System aktivieren
    purchaseCooldown = 3,        -- Sekunden zwischen Käufen
    maxPurchasesPerHour = 10,    -- Maximale Käufe pro Stunde
    maxRapidAttempts = 3,        -- Maximale schnelle Kaufversuche
    logSuspiciousActivity = true, -- Verdächtige Aktivitäten loggen
    banAfterViolations = false,  -- Automatischer Ban nach Verstößen (nicht empfohlen)
    maxViolationsBeforeAlert = 3 -- Admin-Alert nach X Verstößen
}

 -- Testfahrt Einstellungen
Config.TestDrive = {
    enabled = true,
    duration = 10,              -- 2 Minuten
    plate = "PROBE",
    
    restrictions = {
        maxDistance = 1000,      -- 1000 Meter Radius vom Autohaus
    }
}


-- Autohäuser Konfiguration
Config.Dealerships = {
    ["luxus_autohaus"] = {
        name = "Luxus Autohaus",
        blip = {
            sprite = 326,
            color = 2,
            scale = 1.0,
            coords = vector3(-1174.0, -1719.0, 4.5)
        },
        -- FESTER SPAWN-PUNKT für Probefahrten (kannst du selbst festlegen!)
        testDriveSpawn = vector3(-1181.18, -1740.0, 4.0),
        
        cars = {
            {
                pos = vector3(-1181.18, -1724.65, 4.5),
                heading = 192.56,
                model = 'sc1',
                spin = false,
                price = 250000,
                label = "Pegassi SC1",
                plate = "LUXUS",
                category = "Supersport"
            },
            {
                pos = vector3(-1175.50, -1720.53, 4.5),
                heading = 191.31,
                model = 'italigtb2',
                spin = false,
                price = 300000,
                label = "Progen Itali GTB Custom",
                plate = "LUXUS",
                category = "Supersport"
            },
            {
                pos = vector3(-1169.66, -1716.91, 4.5),
                heading = 190.70,
                model = 'infernus',
                spin = false,
                price = 200000,
                label = "Pegassi Infernus",
                plate = "LUXUS",
                category = "Supersport"
            },
            {
                pos = vector3(-1163.27, -1712.13, 4.5),
                heading = 189.77,
                model = 'entity2',
                spin = false,
                price = 180000,
                label = "Overflod Entity XF",
                plate = "LUXUS",
                category = "Supersport"
            },
            {
                pos = vector3(-1156.91, -1707.65, 4.5),
                heading = 189.63,
                model = 'bullet',
                spin = false,
                price = 220000,
                label = "Vapid Bullet",
                plate = "LUXUS",
                category = "Supersport"
            }
        }
    },
    
    ["motorrad_haendler"] = {
        name = "Motorrad Händler",
        blip = {
            sprite = 348,
            color = 4,
            scale = 1.0,
            coords = vector3(-1135.0, -1710.0, 3.91)
        },
        -- FESTER SPAWN-PUNKT für Motorrad-Probefahrten
        testDriveSpawn = vector3(-1120.0, -1695.0, 4.0),
        
        cars = {
            {
                pos = vector3(-1139.38, -1714.60, 3.91),
                heading = 246.28,
                model = 'akuma',
                spin = false,
                price = 25000,
                label = "Dinka Akuma",
                plate = "BIKE",
                category = "Motorrad"
            },
            {
                pos = vector3(-1137.86, -1713.32, 3.91),
                heading = 239.74,
                model = 'bati',
                spin = false,
                price = 30000,
                label = "Pegassi Bati 801",
                plate = "BIKE",
                category = "Motorrad"
            },
            {
                pos = vector3(-1135.97, -1712.13, 3.91),
                heading = 246.37,
                model = 'daemon2',
                spin = false,
                price = 35000,
                label = "Western Daemon",
                plate = "BIKE",
                category = "Motorrad"
            },
            {
                pos = vector3(-1133.24, -1709.65, 3.91),
                heading = 252.95,
                model = 'faggio',
                spin = false,
                price = 5000,
                label = "Pegassi Faggio",
                plate = "BIKE",
                category = "Motorrad"
            }
        }
    },
    
    ["nutzfahrzeuge"] = {
        name = "Nutzfahrzeuge Handel",
        blip = {
            sprite = 67,
            color = 5,
            scale = 1.0,
            coords = vector3(-1120.0, -1724.0, 4.5)
        },
        -- FESTER SPAWN-PUNKT für Nutzfahrzeug-Probefahrten
        testDriveSpawn = vector3(-1100.0, -1710.0, 4.5),
        
        cars = {
            {
                pos = vector3(-1115.05, -1719.84, 4.43),
                heading = 260.94,
                model = 'burrito3',
                spin = false,
                price = 45000,
                label = "Declasse Burrito",
                plate = "WORK",
                category = "Van"
            },
            {
                pos = vector3(-1118.60, -1722.75, 4.73),
                heading = 261.02,
                model = 'surfer',
                spin = false,
                price = 35000,
                label = "BF Surfer",
                plate = "WORK",
                category = "Van"
            },
            {
                pos = vector3(-1124.04, -1726.83, 4.73),
                heading = 169.44,
                model = 'mesa3',
                spin = false,
                price = 55000,
                label = "Canis Mesa",
                plate = "WORK",
                category = "SUV"
            }
        }
    },

    ["guenstige_autos"] = {
        name = "Günstige Gebrauchtwagen",
        blip = {
            sprite = 225,
            color = 1,
            scale = 1.0,
            coords = vector3(-1150.0, -1742.0, 3.91)
        },
        -- FESTER SPAWN-PUNKT für günstige Auto-Probefahrten
        testDriveSpawn = vector3(-1170.0, -1760.0, 4.0),
        
        cars = {
            {
                pos = vector3(-1144.05, -1738.40, 3.91),
                heading = 36.43,
                model = 'premier',
                spin = false,
                price = 15000,
                label = "Declasse Premier",
                plate = "USED",
                category = "Limousine"
            },
            {
                pos = vector3(-1147.89, -1740.68, 3.91),
                heading = 37.42,
                model = 'asea',
                spin = false,
                price = 12000,
                label = "Declasse Asea",
                plate = "USED",
                category = "Limousine"
            },
            {
                pos = vector3(-1151.06, -1743.17, 3.91),
                heading = 35.35,
                model = 'tailgater',
                spin = false,
                price = 18000,
                label = "Obey Tailgater",
                plate = "USED",
                category = "Limousine"
            }
        }
    }
}