## DISCONTINUED



# 🚗 FiveM Vehicle Dealership System

A modern, secure, and performant vehicle dealership system for FiveM servers with React UI and comprehensive anti-cheat system.

## ✨ Features

### 🎨 Modern User Interface
- **React-based UI** with modern animations
- **Transparent background** for seamless integration
- **Responsive design** for all screen sizes
- **3D Text fallback** for maximum compatibility
- **Animations**: Modal Scale, Backdrop Blur, Button Hover, Purchase Warp

### 🏪 Dealership System
- **Multiple dealerships** with different vehicle categories
- **Automatic showroom management** (spawning/despawning based on distance)
- **Intelligent performance optimization** with smart wait systems
- **Vehicle categorization** (Luxury, Motorcycles, Commercial, Used Cars)
- **Customizable blips** for each dealership

### 🚙 Vehicle Features
- **Test drives** with time and distance restrictions
- **Direct garage integration** (vehicles automatically saved to garage)
- **Random license plate generation** with customizable prefixes
- **Vehicle properties** (color, condition, etc.)
- **Spinning vehicles** (optional, disableable for better performance)

### 🛡️ Security System
- **Comprehensive anti-cheat system**
- **Rate limiting** (purchase attempts, test drives)
- **Input validation** of all client data
- **Distance checks** (player must be near dealership)
- **Suspicious activity logging** with admin notifications
- **Server-side data validation**

### ⚡ Performance Optimization
- **Smart wait systems** (longer waits during inactivity)
- **Conditional thread execution**
- **Optimized update rates** for different systems
- **Early exits** on distance checks
- **Memory-efficient vehicle management**

### 📊 Admin Features
- **Sales statistics** with revenue overview
- **Vehicle management** commands
- **Test drive monitoring** and control
- **Security status** dashboard
- **Discord webhook** integration for sale logs

## 📋 Requirements

- **ESX Framework** (Legacy or Final)
- **MySQL-async or oxmysql** for database operations

## 🚀 Installation

1. **Download** and extract the script to your `resources` folder
```bash
cd resources
git clone https://github.com/zhoraFPS/zhora_dealership.git zhora_dealership
```



2. **Add resource** to your `server.cfg`:
```cfg
ensure zhora_dealership
```

3. **Ensure dependencies**:
```cfg
ensure es_extended
ensure mysql-async
```

## ⚙️ Configuration

### Basic Settings (`config.lua`)
```lua
Config.ShowRange = 200              -- Showroom visibility range
Config.Currency = "$"               -- Currency symbol
Config.BuyKey = 38                  -- E key for interaction
```

### Adding a Dealership
```lua
Config.Dealerships["my_dealership"] = {
    name = "My Dealership",
    blip = {
        sprite = 326,
        color = 2,
        scale = 1.0,
        coords = vector3(x, y, z)
    },
    testDriveSpawn = vector3(x, y, z), -- Spawn point for test drives
    cars = {
        {
            pos = vector3(x, y, z),
            heading = 0.0,
            model = 'adder',
            price = 1000000,
            label = "Truffade Adder",
            category = "Supersport"
        }
    }
}
```

### Security Settings
```lua
Config.Security = {
    enableAntiCheat = true,
    purchaseCooldown = 3,           -- Seconds between purchases
    maxPurchasesPerHour = 10,       -- Max purchases per hour
    maxRapidAttempts = 3,           -- Max rapid attempts
    logSuspiciousActivity = true
}
```

### Test Drive Settings
```lua
Config.TestDrive = {
    enabled = true,
    duration = 120,                 -- Seconds
    restrictions = {
        maxDistance = 1000          -- Meters from dealership
    }
}
```

## 🎮 Usage

### For Players
1. **View vehicle**: Go to a showroom vehicle and press `E`
2. **Buy vehicle**: Click "Purchase" in the UI modal
3. **Test drive**: Click "Test Drive" for a test ride
4. **Garage**: Purchased vehicles are automatically saved to your garage


### Adding New Vehicles
Add vehicles to `config.lua`:
```lua
{
    pos = vector3(x, y, z),
    heading = 180.0,
    model = 'vehicle_spawn_name',
    price = 50000,
    label = "Vehicle Display Name",
    category = "Category"
}
```

### Discord Integration
```lua
Config.DiscordWebhook = true
Config.WebhookURL = "YOUR_WEBHOOK_URL"
```

## 🐛 Troubleshooting

### Vehicles not spawning
- Check `Config.ShowRange` setting
- Ensure vehicle models exist
- Check server console for errors

### UI not opening
- Check browser console (F12)
- Ensure `ui_page` is set correctly
- Check NUI focus status

### Test drives not working
- Check `testDriveSpawn` coordinates
- Ensure `Config.TestDrive.enabled = true`
- Check admin logs for errors


**Important**: Always check `config.lua` for new options after updates.

## 📝 Changelog

### v1.0.0
- Initial Release
- React UI Implementation
- Anti-Cheat System
- Multiple Dealership Support
- Test Drive System
- Performance Optimizations

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## 📄 License

This project is licensed under the MIT License - see [LICENSE](LICENSE) file for details.

## 🆘 Support

- **GitHub Issues**: For bug reports and feature requests

## ⭐ Credits

- **Developed for**: FiveM Community
- **Framework**: ESX Framework
- **UI**: React + Vite
- **Icons**: Lucide React

---

**⚠️ Important Note**: This script is intended for educational purposes and private use. For commercial use, please contact the developer.
