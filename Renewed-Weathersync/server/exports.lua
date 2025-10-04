-- Server-side exports for weather system
-- These exports can be called from other resources server-side

-- Basic weather information exports
exports('getCurrentWeather', function()
    return GlobalState.weather
end)

exports('getCurrentWeatherType', function()
    local currentWeather = GlobalState.weather
    return currentWeather and currentWeather.weather or nil
end)

exports('getCurrentWeatherTime', function()
    local currentWeather = GlobalState.weather
    return currentWeather and currentWeather.time or nil
end)

exports('getWindDirection', function()
    local currentWeather = GlobalState.weather
    return currentWeather and currentWeather.windDirection or nil
end)

exports('getWindSpeed', function()
    local currentWeather = GlobalState.weather
    return currentWeather and currentWeather.windSpeed or nil
end)

exports('hasSnow', function()
    local currentWeather = GlobalState.weather
    return currentWeather and currentWeather.hasSnow or false
end)

-- Weather list and system status exports
exports('getWeatherList', function()
    return weatherList or {}
end)

exports('isWeatherOverridden', function()
    return overrideWeather or false
end)

-- Player-specific exports (require player source ID)
exports('isWeatherSynced', function(source)
    if source then
        local playerState = Player(source).state
        return playerState.syncWeather or false
    end
    return nil -- No source provided
end)

exports('getPlayerWeather', function(source)
    if source then
        local playerState = Player(source).state
        return playerState.playerWeather or nil
    end
    return nil -- No source provided
end)
