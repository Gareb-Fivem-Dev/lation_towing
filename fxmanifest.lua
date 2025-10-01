fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Gareb -Torrid RD'
description 'A fun & simple towing job for QBCore/QBox with multi-job support for FiveM Based on lation\'s original script'
version '1.1'

dependencies {
    'ox_lib',
    'ox_target',
}

optional_dependencies {
    'slrn_groups'
}

client_scripts {
    'client/*.lua',
}

server_scripts {
    'server/*.lua',
}

shared_scripts {
    'config.lua',
    'locales/*.lua',
    '@ox_lib/init.lua'
}