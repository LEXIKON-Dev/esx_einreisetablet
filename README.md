# ESX Immigration Tablet

[![GitHub](https://img.shields.io/badge/GitHub-LEXIKON--Dev-blue?logo=github)](https://github.com/LEXIKON-Dev/esx_einreisetablet)
[![FiveM](https://img.shields.io/badge/FiveM-ESX-orange)](https://github.com/esx-framework/esx_core)
[![Lua](https://img.shields.io/badge/Lua-5.4-purple)](https://www.lua.org/)

A modern **ESX immigration system** for FiveM with an iPad-style UI, waiting zone, help marker, and admin tablet. Players go through airport immigration while staff manage everything from a clean terminal interface.

**Repository:** [github.com/LEXIKON-Dev/esx_einreisetablet](https://github.com/LEXIKON-Dev/esx_einreisetablet)

---

## Features

### Tablet (Staff)
- iPad-style design with sidebar, live refresh, and statistics
- **Player management:** Search, filters (All / Waiting / Admitted), status badges
- **Immigration actions:** Send questions, give skin, admit player, revoke admission
- **Moderation:** Teleport (Go to player / Bring), freeze / unfreeze, internal notes
- **Question editor:** Editable immigration questions (stored in database)
- **Tools:** Zone announcement, optional starter money, daily statistics
- **Log:** Recent actions with filter and search

### Players
- Waiting zone with radius check (leave zone → teleport back)
- Help marker with **E** (admins get notified + optional blip)
- Immigration interview UI with questions from staff
- Custom iOS-style notify banners (no default ESX notify)

### System
- Permissions via **ESX groups** (no jobs required)
- Persistent admission status in MySQL
- Discord webhook for admissions and help requests
- Locale system: **German & English**
- Exports for other resources

---

## Requirements

| Resource | Required |
|---|---|
| [es_extended](https://github.com/esx-framework/esx_core) | Yes |
| [oxmysql](https://github.com/overextended/oxmysql) | Yes |
| esx_skin / illenium-appearance | Optional (skin system) |

- **FiveM** server with Lua 5.4
- **MySQL** / MariaDB

---

## Installation

1. Clone or download the repository:

```bash
git clone https://github.com/LEXIKON-Dev/esx_einreisetablet.git
```

2. Place the folder in your `resources` directory, e.g.:

```
resources/[esx]/esx_einreisetablet
```

3. Import the SQL file:

```sql
-- File: sql/install.sql
```

4. Add to your `server.cfg`:

```cfg
ensure oxmysql
ensure es_extended
ensure esx_einreisetablet
```

5. Edit `config.lua` (coordinates, groups, locale).

6. Restart the server.

> On first start, default questions are automatically inserted into the database (language depends on `Config.Locale`).

---

## Usage

### Staff

| Action | Description |
|---|---|
| `/einreise` | Open the tablet (default command) |
| Keybind | Optional via `Config.OpenKey` (e.g. `F6`) |

All ESX groups listed in `Config.AllowedGroups` can open the tablet.

### Players

- Non-admitted players must stay within the configured radius
- Press **E** at the help marker → staff receive a notification
- Questions are sent by staff and shown in the immigration interview UI

---

## Configuration

All settings are in `config.lua`:

```lua
Config.Locale = 'de'        -- 'de' or 'en'

Config.AllowedGroups = {    -- Who can open the tablet
    'admin', 'superadmin', 'mod',
}

Config.AdminGroups = {      -- Who receives help requests
    'admin', 'superadmin', 'mod',
}

Config.OpenCommand = 'einreise'
Config.OpenKey = false      -- e.g. 'F6' or false

Config.Zone = { ... }       -- Waiting zone (center, radius, return TP)
Config.EntryCoords = ...    -- Teleport after admission
Config.NewPlayerSpawn = ... -- Spawn for new players (false = disabled)

Config.HelpMarker = { ... } -- Help marker position & settings
Config.SkinSystem = 'esx_skin' -- 'esx_skin' | 'illenium' | 'custom'

Config.StarterMoney = {
    enabled = false,
    amount = 5000,
    account = 'money',      -- 'money' or 'bank'
}

Config.DiscordWebhook = ''  -- Empty = disabled
```

### Skin systems

| Value | Description |
|---|---|
| `esx_skin` | Default ESX skin menu |
| `illenium` | illenium-appearance |
| `custom` | Custom event via `Config.CustomSkinEvent` |

---

## Language / Locale

Set the language in `config.lua`:

```lua
Config.Locale = 'en'
```

Translation files:

- `locales/de.lua`
- `locales/en.lua`

Add new strings:

```lua
-- locales/en.lua
Locales['en'] = {
    my_key = 'My text with %s',
    ui = {
        my_ui_key = 'Button label',
    },
}
```

In Lua:

```lua
Locale('my_key', 'parameter')
```

UI strings are automatically passed to the tablet.

---

## Exports

### Server

```lua
-- Check if player is admitted
exports['esx_einreisetablet']:IsPlayerEingereist(source, function(admitted)
    print(admitted)
end)

-- Set admission status
exports['esx_einreisetablet']:SetPlayerEingereist(source, true, 'AdminName')
```

### Client

```lua
local admitted = exports['esx_einreisetablet']:IsEingereist()
```

---

## Project structure

```
esx_einreisetablet/
├── client/
│   ├── main.lua        # Tablet, NUI, teleports
│   ├── marker.lua      # Help marker
│   ├── zone.lua        # Waiting zone
│   └── notify.lua      # Custom notify
├── server/
│   └── main.lua        # Logic, DB, events
├── html/
│   ├── index.html      # Tablet UI
│   ├── app.js
│   ├── style.css
│   └── icons.css
├── locales/
│   ├── de.lua
│   └── en.lua
├── shared/
│   └── locale.lua
├── sql/
│   └── install.sql
├── config.lua
└── fxmanifest.lua
```

---

## Database

| Table | Purpose |
|---|---|
| `einreisetablet_status` | Admission status per player |
| `einreisetablet_questions` | Editable questions |
| `einreisetablet_logs` | Action log |

---

## Support & Contributing

Issues and pull requests are welcome.

When reporting bugs, please include:
- ESX version
- oxmysql version
- Error message from F8 / server console
- Steps to reproduce

---

## License

Free to use on your FiveM server. Please give credit when redistributing or publishing.

---

**Made by [LEXIKON-Dev](https://github.com/LEXIKON-Dev)**
