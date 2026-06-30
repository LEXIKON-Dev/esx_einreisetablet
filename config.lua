Config = {}

-- Sprache: 'de' oder 'en'
Config.Locale = 'de'

-- ═══════════════════════════════════════════════════════════════
--  BEREchtigungen
-- ═══════════════════════════════════════════════════════════════

-- ESX-Gruppen die das Tablet öffnen dürfen
Config.AllowedGroups = {
    'admin',
    'superadmin',
    'mod',
}

-- Gruppen die bei Hilfe-Anfrage (Marker) benachrichtigt werden
Config.AdminGroups = {
    'admin',
    'superadmin',
    'mod',
}

-- ═══════════════════════════════════════════════════════════════
--  TABLET ÖFFNEN
-- ═══════════════════════════════════════════════════════════════

Config.OpenCommand = 'einreise'
Config.OpenKey = false -- false zum Deaktivieren

-- ═══════════════════════════════════════════════════════════════
--  KOORDINATEN
-- ═══════════════════════════════════════════════════════════════

-- Wartebereich: Spieler die noch nicht eingereist sind müssen hier bleiben
Config.Zone = {
    center = vector3(-1082.0, -2825.0, 27.0),   -- Flughafen Einreise (Beispiel)
    radius = 120.0,
    returnCoords = vector4(-1082.0, -2825.0, 27.0, 240.0), -- Zurück-TP bei Radius-Verlassen
}

-- Ziel nach erfolgreicher Einreise
Config.EntryCoords = vector4(-1037.0, -2737.0, 20.0, 330.0)

-- Spawn für neue / nicht eingereiste Spieler (optional, false = deaktiviert)
Config.NewPlayerSpawn = vector4(-1070.0, -2815.0, 27.0, 240.0)

-- ═══════════════════════════════════════════════════════════════
--  HILFE-MARKER (Spieler drückt E → Admins werden informiert)
-- ═══════════════════════════════════════════════════════════════

Config.HelpMarker = {
    coords = vector3(-1075.0, -2820.0, 27.0),
    type = 1,
    scale = vector3(1.5, 1.5, 0.8),
    color = { r = 0, g = 150, b = 255, a = 180 },
    drawDistance = 25.0,
    interactDistance = 2.0,
    cooldown = 60, -- Sekunden zwischen Anfragen pro Spieler
    blipForAdmins = true,
    blipSprite = 480,
    blipColor = 3,
    blipDuration = 120, -- Sekunden bis Blip verschwindet
}

-- ═══════════════════════════════════════════════════════════════
--  SKIN / AUSSEHEN
-- ═══════════════════════════════════════════════════════════════

-- 'esx_skin' | 'illenium' | 'custom'
Config.SkinSystem = 'esx_skin'

Config.CustomSkinEvent = 'myresource:openSkinMenu' -- nur bei SkinSystem = 'custom'

-- ═══════════════════════════════════════════════════════════════
--  EXTRAS
-- ═══════════════════════════════════════════════════════════════

Config.RemoveWeaponsOnZoneReturn = true
Config.ShowZoneBoundary = false -- Debug: Zone-Kreis anzeigen

-- Startgeld bei Einreise-Werkzeug (Bank oder Cash)
Config.StarterMoney = {
    enabled = false,
    amount = 5000,
    account = 'money' -- 'money' oder 'bank'
}

-- Discord Webhook (leer = deaktiviert)
Config.DiscordWebhook = ''

Config.DiscordBotName = 'Einreise System'
Config.DiscordColor = 3447003
