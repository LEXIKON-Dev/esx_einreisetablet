fx_version 'cerulean'
game 'gta5'

name 'esx_einreisetablet'
author 'Custom'
description 'ESX Einreise Tablet System mit Zone, Marker und Admin-Benachrichtigung'
version '1.0.0'

lua54 'yes'

shared_scripts {
    '@es_extended/imports.lua',
    'config.lua',
    'locales/de.lua',
    'locales/en.lua',
    'shared/locale.lua'
}

client_scripts {
    'client/notify.lua',
    'client/main.lua',
    'client/marker.lua',
    'client/zone.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/icons.css',
    'html/app.js'
}

dependencies {
    'es_extended',
    'oxmysql'
}
