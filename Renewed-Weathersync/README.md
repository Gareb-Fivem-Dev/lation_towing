# Renewed Weathersync - Made For Lation's Towing - Enhanced Edition

## 📋 Description
Renewed Weathersync is a high-performance weather and time synchronization system for FiveM servers. This resource eliminates the need to worry about syncing time and weather across your server while providing extensive customization options and administrative controls.

## ✨ Key Features

### 🌤️ Weather System
- **Custom Weather Sequences** - Pre-configured weather patterns with probability-based selection
- **Static Weather Support** - Define specific weather type probabilities
- **Scheduled Weather Events** - Automatic weather changes before server restarts (requires txAdmin)
- **Advanced Weather Queue** - Pre-render entire weather sequences for optimal performance
- **Real-time Weather Modification** - Admins can change weather sequences while in-game
- **Seasonal Weather** - December snow mode for festive atmosphere
- **Wind System** - Configurable wind speed and direction for each weather type

### ⏰ Time Management
- **Flexible Time Scaling** - Customizable time progression (short/long days)
- **Dynamic Night Scaling** - Different time scales for day/night cycles
- **Real-time Sync Option** - Use server's actual time if preferred
- **Custom Startup Time** - Set specific time on resource start

### 🎮 Administrative Tools
- **In-game Weather Command** - `/weather` command for admins to view and modify weather
- **Interactive Weather Management** - Real-time weather queue editing
- **Ace Permissions Integration** - Secure admin controls with proper permissions
- **Weather Event Removal** - Remove specific weather events from the queue

### 🔧 Compatibility & Performance
- **QB-Core Compatible** - Drop-in replacement for qb-weathersync
- **CD Easy Time Compatible** - Support for existing CD Easy Time setups
- **Ox_lib Integration** - Modern FiveM framework support
- **High Performance** - Optimized code for minimal server impact
- **Framework Agnostic** - Works with any FiveM framework

### 📡 Export Functions
#### Server Exports
- `getCurrentWeather()` - Get current weather object
- `getCurrentWeatherType()` - Get current weather type string
- `getCurrentWeatherTime()` - Get remaining time for current weather
- `getWindDirection()` - Get current wind direction
- `getWindSpeed()` - Get current wind speed
- `hasSnow()` - Check if current weather has snow effects
- `getWeatherList()` - Get complete weather queue
- `isWeatherOverridden()` - Check if weather system is overridden
- `isWeatherSynced(source)` - Check if player has weather sync enabled

#### Client Exports
- `getCurrentWeather()` - Get current weather data (client-side)
- `getCurrentWeatherType()` - Get current weather type
- `getCurrentWeatherTime()` - Get remaining weather time
- `getWindDirection()` - Get wind direction
- `getWindSpeed()` - Get wind speed
- `hasSnow()` - Check for snow effects
- `isWeatherSynced()` - Check client weather sync status
- `getPlayerWeather()` - Get player-specific weather data

## 📦 Installation

### Standard Installation
1. Download or clone the repository: `git clone https://github.com/Renewed-Scripts/Renewed-Weathersync.git`
2. Copy the `Renewed-Weathersync` folder to your `resources` directory
3. Add `ensure Renewed-Weathersync` to your `server.cfg` file
4. Ensure `ox_lib` is installed and started before this resource

### Dependencies
- **ox_lib** - Required for modern FiveM functionality
- **FiveM Server** - Artifact 4752 or higher recommended

## ⚙️ Configuration

### Weather Configuration (`config/weather.lua`)
```lua
return {
    useScheduledWeather = true,        -- Enable txAdmin scheduled weather
    serverDuration = 14,               -- Server runtime hours before restart
    weatherCycletimer = 30,            -- Minutes between weather changes
    timeBetweenRain = 180,            -- Minutes between rain events  
    rainAfterRestart = 60,            -- Minutes after restart before rain
    decemberSnow = true,              -- Snow-only mode in December
    
    -- Static weather probabilities
    useStaticWeather = true,
    staticWeather = {
        ['EXTRASUNNY'] = 0.4,         -- 40% chance
        ['CLEAR'] = 0.1,              -- 10% chance
        -- ... more weather types
    },
    
    -- Custom weather sequences
    useWeatherSequences = true,
    weatherSequences = {
        -- Define custom weather patterns
    }
}
```

### Time Configuration (`config/time.lua`)
```lua
return {
    timeScale = 4000,                 -- Milliseconds per GTA minute
    useNightScale = false,            -- Enable different night scaling
    timeScaleNight = 8000,           -- Night time scaling
    nightTime = {
        beginning = 22,               -- Night starts at 10 PM
        ending = 6                    -- Night ends at 6 AM
    },
    useRealTime = false,             -- Use server's real time
    startUpTime = {
        hour = 12,
        minute = 0
    }
}
```

## 🎯 Usage

### Admin Commands
- `/weather` - Open weather management interface (requires admin permissions)

### For Developers
```lua
-- Get current weather information
local weather = exports['Renewed-Weathersync']:getCurrentWeather()
local weatherType = exports['Renewed-Weathersync']:getCurrentWeatherType()

-- Check weather conditions
local hasSnow = exports['Renewed-Weathersync']:hasSnow()
local windSpeed = exports['Renewed-Weathersync']:getWindSpeed()
```

## 🔧 Compatibility Setup

### Disabling CD Easy Time Compatibility
If you've never used cd_easytime, disable it by adding this to your `server.cfg`:
```
setr weather_disablecd true
```

### QB-Core Integration
This resource automatically provides compatibility with QB-Core and can be used as a drop-in replacement for qb-weathersync.

## 🆚 Version Differences

This repository contains both the **Legacy Version** (in nested folder) and the **Enhanced Version** (root level):

### Enhanced Version (Current/Root Level)
- ✅ Full export system with 10+ functions
- ✅ Advanced admin interface with real-time editing
- ✅ Comprehensive weather sequences
- ✅ Player-specific weather controls
- ✅ Extended compatibility options
- ✅ Modern ox_lib integration

### Legacy Version (Nested Folder)
- ❌ Basic weather sync only
- ❌ Limited export functions
- ❌ No advanced admin tools
- ❌ Minimal configuration options

## 🤝 Support & Contributing

- **GitHub**: [Renewed-Scripts/Renewed-Weathersync](https://github.com/Renewed-Scripts/Renewed-Weathersync)
- **Discord**: Join the Renewed Scripts community for support
- **Issues**: Report bugs and request features on GitHub

## 📄 License

This project is licensed under the terms specified in the LICENSE file.

---

**Created by FjamZoo - Renewed Scripts**  
**Version**: 1.1.6
Once the resource is installed and configured, it will automatically sync the weather and time, the entire weather synchronization is handled upon resource start.

## Contributing
Contributions are welcome! If you find any issues or have suggestions for improvements, please open an issue or submit a pull request.

## Credits
- I took a lot of inspiration from https://github.com/JnKTechstuff/ParadoxWorldSync so a big thanks to them for their work on that resource.
