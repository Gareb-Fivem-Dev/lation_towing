-- Client-side exports for weather system
-- These exports can be called from other resources client-side

-- Basic weather information exports
exports('getCurrentWeather', function()
    return serverWeather or GlobalState.weather
end)

exports('getCurrentWeatherType', function()
    local weather = serverWeather or GlobalState.weather
    return weather and weather.weather or GetPrevWeatherTypeHashName()
end)

exports('getCurrentWeatherTime', function()
    local weather = serverWeather or GlobalState.weather
    return weather and weather.time or nil
end)

exports('getWindDirection', function()
    local weather = serverWeather or GlobalState.weather
    return weather and weather.windDirection or nil
end)

exports('getWindSpeed', function()
    local weather = serverWeather or GlobalState.weather
    return weather and weather.windSpeed or nil
end)

exports('hasSnow', function()
    local weather = serverWeather or GlobalState.weather
    return weather and weather.hasSnow or false
end)

-- Player-specific client exports
exports('isWeatherSynced', function()
    return playerState and playerState.syncWeather or false
end)

exports('getPlayerWeather', function()
    return playerState and playerState.playerWeather or nil
end)