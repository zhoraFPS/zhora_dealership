fx_version 'cerulean'
game 'gta5'

author 'zhoraFPS'
github 'https://github.com/zhoraFPS/zhora_dealership'
description 'Dynamic Dealership Script for ESX Framework'
version '1.0.0'


shared_script '@es_extended/imports.lua'


dependency 'mysql-async'

-- UI
ui_page 'web/dist/index.html'

ui_page_blur 'yes'

files {
    'web/dist/index.html',
    'web/dist/**/*',
}


shared_scripts {
    'config.lua'
}


client_scripts {
    'client.lua'
}


server_scripts {
    '@mysql-async/lib/MySQL.lua',
    'server.lua'
}


lua54 'yes'