fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_fxv2_oal 'yes'

name 'Renewed Weather Sync'
author 'FjamZoo - Renewed Scripts'
version '1.1.6'

shared_scripts{
    '@ox_lib/init.lua',
}

client_scripts {
    'client/time.lua',
    'client/weather.lua',
    'client/admin.lua',
    'compatability/**/client.lua',
    'client/exports.lua', -- Load exports AFTER other client files
}

server_scripts {
    'server/time.lua',
    'server/weather.lua',
    'compatability/**/server.lua',
    'server/exports.lua', -- Load exports AFTER weather.lua to access global variables
}

provide 'qb-weathersync'
provide 'cd_easytime'

export 'getCurrentWeather'
export 'getCurrentWeatherType'
export 'getCurrentWeatherTime'
export 'getWindDirection'
export 'getWindSpeed'
export 'hasSnow'
export 'getWeatherList'
export 'isWeatherOverridden'
export 'isWeatherSynced'
export 'getPlayerWeather'