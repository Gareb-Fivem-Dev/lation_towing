# Lation's Towing - Enhanced Edition

## Version History

### Version 2.0.0 - Enhanced Edition (Major Overhaul)
**🚨 BREAKING CHANGES - This is a complete rewrite with extensive new features**

#### **🎯 Framework & Core Changes**
- **QBCore Exclusive**: Converted from multi-framework to QBCore-only support
- **Enhanced Job System**: Multiple job support with array-based job checking
- **ox_lib Integration**: Full integration with ox_lib radial menu system
- **Improved Performance**: Optimized code structure and reduced resource usage

#### **🔧 Vehicle Disability System** (NEW)
- **Random Vehicle Issues**: Vehicles spawn with realistic mechanical problems
- **5 Disability Types**: Engine failure, flat tires, fuel leaks, broken windows, body damage
- **ox_target Integration**: Interactive repair system using vehicle bone targeting
- **Repair Bonuses**: Extra pay for fixing vehicle issues (+$150 default)
- **Item-Based Repairs**: Requires specific tools (repairkit, sparetire, etc.)
- **Multiple Disabilities**: Vehicles can have multiple issues simultaneously

#### **📱 ox_lib Radial Menu System** (NEW)
- **Job-Restricted Access**: Only shows for players with required jobs
- **Dynamic Visibility**: Automatically shows/hides based on job status
- **Submenu Structure**: Organized menu with repair, inspect, and job options
- **Real-time Updates**: Menu updates when job changes or clocking in/out

#### **🎯 Advanced Features**
- **Streak System**: Bonus pay for consecutive deliveries (up to 5x streak)
- **Time Bonuses**: Extra pay for quick deliveries under 5 minutes
- **Distance Bonuses**: Pay scales with delivery distance
- **Weather Bonuses**: Extra pay during difficult weather conditions
- **Damage Penalties**: Reduced pay if vehicle is damaged during transport
- **Vehicle Variety**: Prevents camping by requiring different vehicle types

#### **📊 Leveling System** (NEW)
- **50 Levels**: Progressive leveling with exponential XP requirements
- **Pay Multipliers**: Permanent pay increases at each milestone (5%, 10%, 15%... up to 50%)
- **Dynamic Titles**: 11 different rank titles from "Rookie Driver" to "Ultimate Tow Legend"
- **XP Bonuses**: Extra XP for repairs, weather, streaks, and quick deliveries
- **Statistics Tracking**: Comprehensive player progress tracking

#### **🛠 Enhanced Configuration**
- **Comprehensive Config**: 500+ lines of detailed configuration options
- **Debug System**: Advanced debugging with 20+ categories and color coding
- **Performance Settings**: Optimized cleanup and performance monitoring
- **Weather Integration**: Support for Renewed-Weathersync weather types

#### **🎨 User Interface Improvements**
- **Enhanced Notifications**: Detailed breakdown of earnings with all bonuses
- **Vehicle Inspection**: Detailed inspection reports showing all issues
- **Repair Menus**: Interactive menus for vehicle repairs
- **Progress Tracking**: Visual XP progress and level advancement

#### **⚡ Performance & Quality of Life**
- **Optimized Cleanup**: Smart vehicle cleanup system
- **Location Reservation**: Multi-player location management
- **Auto-Repair Tow Truck**: Spawned trucks are automatically repaired
- **Enhanced Blips**: Improved map markers and GPS integration
- **Route Display**: Show delivery routes with ETA


### Version 1.1.0 - Original Fork
- Fork of Lation's Towing
- Converted to QBCore only support
- Removed ESX and standalone framework support
- Streamlined server-side code for better performance
- Updated configuration to be QBCore specific

### Version 1.0.3 - Original Release
- Original release with multi-framework support

---

## 📋 Complete Feature Comparison

| Feature | Original | Enhanced Edition |
|---------|----------|------------------|
| Framework Support | ESX/QBCore/Standalone | QBCore Only |
| File Size | ~453 lines | ~2,967 lines |
| Config Options | ~15 settings | 500+ settings |
| Vehicle Issues | None | 5 types with repairs |
| Radial Menu | None | Full ox_lib integration |
| Leveling System | None | 50 levels with bonuses |
| Bonus Systems | Basic pay | 7 different bonus types |
| Debug System | Basic | Advanced with categories |
| Job Restrictions | Single job | Multiple jobs array |
| Vehicle Variety | Random spawn | Smart variety system |

---

## 🚀 New Features Overview

### Vehicle Disability System
Vehicles now spawn with realistic mechanical issues that players can repair for bonus pay:
- **Engine Failure**: Smoking, overheated engines requiring repair kits
- **Flat Tires**: Single or multiple tire damage requiring spare tires  
- **Fuel Leaks**: Tank damage requiring welding kits
- **Broken Windows**: Shattered glass requiring glass replacement
- **Body Damage**: Collision damage requiring plastic/body work

### Leveling & Progression
- **Experience System**: Gain XP for deliveries and repairs
- **50 Progressive Levels**: Each level increases permanent pay bonus
- **Dynamic Titles**: Rank progression from Rookie to Ultimate Legend
- **Milestone Rewards**: Major bonuses at levels 5, 10, 15, 20, etc.

### Advanced Bonus Systems
- **Delivery Streaks**: Up to 5x consecutive delivery bonuses
- **Speed Bonuses**: Extra pay for deliveries under time threshold
- **Weather Bonuses**: Up to $200 extra in difficult conditions
- **Distance Bonuses**: Pay scales with delivery distance
- **Repair Bonuses**: $150 per vehicle issue fixed

### Enhanced User Experience
- **ox_lib Integration**: Modern UI with radial menus and notifications
- **Smart Job Detection**: Automatic job checking with array support
- **Vehicle Inspection**: Detailed reports of vehicle condition
- **Interactive Repairs**: ox_target integration for realistic repairs

---

A comprehensive towing job system for FiveM with realistic vehicle breakdowns, progressive leveling, advanced bonus systems, and full ox_lib integration. Players start as rookie drivers and progress to ultimate tow legends through skill and dedication.

## 📦 Dependencies

### Required
- **[QBCore Framework](https://github.com/qbcore-framework/qb-core)** - Main framework
- **[ox_lib](https://github.com/overextended/ox_lib/releases)** - UI library for notifications, radial menus, progress bars
- **[ox_target](https://github.com/overextended/ox_target/releases)** - Vehicle interaction system for repairs
- **[ox_inventory](https://github.com/overextended/ox_inventory)** - Item system for repair tools

### Optional
- **Renewed-Weathersync** - Enhanced weather bonuses (automatically detected)
- **wasabi_carlock** - Alternative key system support

---

## 🔧 Installation

### 1. Prerequisites
```bash
# Ensure you have all required dependencies installed and running
ensure qb-core
ensure ox_lib  
ensure ox_target
ensure ox_inventory
```

### 2. Installation Steps
1. Download the enhanced edition files
2. Place `lation_towing` folder in your `resources` directory
3. Add to your `server.cfg`:
```cfg
ensure lation_towing
```

### 3. Configuration
1. Edit `config.lua` to match your server setup:
   - Set your required jobs in `Config.JobName` array
   - Adjust spawn locations and delivery points
   - Configure repair items to match your inventory
   - Customize pay rates and bonuses

### 4. Inventory Items (Add to ox_inventory)
Add these items to your `ox_inventory/data/items.lua`:
```lua
['repairkit'] = {
    label = 'Repair Kit',
    weight = 2500,
    stack = true,
    consume = 0, -- Set to 1 if you want items consumed
    client = {
        image = 'repairkit.png',
    }
},
['sparetire'] = {
    label = 'Spare Tire',
    weight = 5000,
    stack = true,
    consume = 1,
    client = {
        image = 'sparetire.png',
    }
},
['weldingkit'] = {
    label = 'Welding Kit',
    weight = 3000,
    stack = true,
    consume = 0,
    client = {
        image = 'weldingkit.png',
    }
},
['glass'] = {
    label = 'Window Glass',
    weight = 1000,
    stack = true,
    consume = 1,
    client = {
        image = 'glass.png',
    }
},
['plastic'] = {
    label = 'Plastic Sheeting',
    weight = 500,
    stack = true,
    consume = 1,
    client = {
        image = 'plastic.png',
    }
},
```

---

## 🎮 How to Use

### Getting Started
1. Go to the towing job location (marked on map)
2. Talk to the job ped to get your tow truck
3. Clock in to start receiving jobs
4. Wait for job assignments (1-2 minutes)

### Vehicle Repairs
1. **Inspect Vehicle**: Use radial menu (hold Alt) near disabled vehicles
2. **Check Issues**: Select "Inspect Vehicle" to see all problems
3. **Repair**: Use ox_target on specific vehicle parts to repair issues
4. **Earn Bonuses**: Get $150 per repair + XP bonuses

### Radial Menu Access
- **Job Requirement**: Must have one of the configured jobs
- **Activation**: Hold Alt key near vehicles to access menu
- **Options**: Repair, Inspect, Statistics, End Job

### Progression System
- **Gain XP**: Complete deliveries and repair vehicles
- **Level Up**: Unlock pay multipliers and new titles
- **Track Progress**: Use `/towstats` command or radial menu

---

## ⚙️ Configuration Guide

### Job Setup
```lua
Config.JobName = {'mechanic', 'towtruck', 'ambulance', 'police'} -- Multiple jobs supported
Config.JobLock = true -- Set to false to allow everyone
```

### Disability System
```lua
Config.EnableCarDisabilities = true -- Enable vehicle breakdowns
Config.GlobalDisabilityChance = 100 -- Chance any vehicle has issues
Config.RequireRepairTools = true -- Require items for repairs
```

### Debug System
```lua
Config.Debug.enabled = false -- Master debug toggle
Config.Debug.client.radialMenu = true -- Specific debug categories
```

---

## 🐛 Troubleshooting

### Common Issues
1. **Radial menu not showing**: Check job requirements and ox_lib installation
2. **Repairs not working**: Ensure ox_target is installed and items exist in inventory
3. **No XP gain**: Check leveling system is enabled in config
4. **Performance issues**: Disable debug mode and optimize cleanup settings

### Debug Commands
- `/towdebug` - Show current towing system status
- `/towmenu` - Force refresh radial menu
- `/towstats` - Show player statistics and level info

---

## 📊 Performance Notes

### Optimizations
- **Smart Cleanup**: Vehicles are cleaned up automatically based on distance and age
- **Efficient Targeting**: ox_target interactions are optimized for performance
- **Conditional Loading**: Debug systems only run when enabled
- **Memory Management**: Proper cleanup of events and handlers

### Resource Usage
- **Client**: ~0.02ms idle, ~0.05ms during active use
- **Server**: ~0.01ms idle, ~0.03ms during job processing
- **Memory**: ~2MB client, ~1MB server

---

## 🔄 Migration from Original

### Breaking Changes
1. **Framework**: ESX/Standalone support removed - QBCore only
2. **Config Format**: Location format changed from table to vector4
3. **Dependencies**: ox_lib, ox_target, ox_inventory now required
4. **Job Format**: Single job string now supports job arrays

### Migration Steps
1. Backup your current configuration
2. Install all new dependencies
3. Update job names to array format if needed
4. Add repair items to your inventory system
5. Test thoroughly before going live

---

## 📝 Credits & Support

### Original Script
- **Lation Scripts** - Original towing job concept and base code
- [Discord](https://discord.gg/9EbY4nM5uu) | [Store](https://lationscripts.com/?utm_source=github&utm_medium=free-script)

### Enhanced Edition - Gareb - Torrid Roleplay

- Complete rewrite with 6x more features and functionality
- Advanced disability system with realistic vehicle repairs
- Full ox_lib integration with modern UI/UX
- Progressive leveling system with 50 levels
- Multiple bonus systems and weather integration

### Support
For issues with the enhanced edition features (disability system, radial menus, leveling, etc.), please create detailed bug reports including:
- Server framework version
- Dependency versions
- Config settings
- Console errors
- Reproduction steps

---

## 📄 License
This enhanced edition maintains the original license while adding significant new functionality. See `LICENSE` file for details.
