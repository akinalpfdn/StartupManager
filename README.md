# StartupManager

A native macOS application for managing startup items, launch agents, launch daemons, and login items. Built with SwiftUI and featuring a modern Liquid Glass design.

## Features

### Core Functionality
- **Login Items Management** - View and manage applications that launch at login
- **Launch Agents** - Control user-level background services
- **Launch Daemons** - Monitor system-level background services
- **Toggle On/Off** - Enable or disable startup items with a single click
- **Drag & Drop** - Add applications to Login Items by dragging them into the app
- **Remove Items** - Delete unwanted startup items (user files only, system files protected)

### Performance Analytics
- **Startup Time Estimation** - See estimated impact on boot time for each item
- **Impact Indicator** - Visual Low/Medium/High indicators based on service configuration
- **Total Startup Impact** - Real-time calculation accounting for parallel startup processes

### Data Management
- **Backup** - Create JSON backups of your startup configuration
- **Export** - Export current startup items list
- **Import** - Restore configurations from backup files
- **Batch Operations** - Disable or remove multiple items at once

### User Experience
- **Search & Filter** - Quickly find specific startup items
- **Alphabetic Sorting** - All lists automatically sorted for easy navigation
- **Detailed Error Messages** - Technical error output for troubleshooting
- **Real-time Updates** - Changes reflected immediately without full refresh
- **Liquid Glass UI** - Modern, translucent macOS design

## Requirements

- macOS 13.0 (Ventura) or later
- Apple Silicon or Intel Mac

## Installation

### For Users (Recommended)

**Download the latest release:**

1. Go to [Releases](https://github.com/akinalpfdn/StartupManager/releases)
2. Download `StartupManager.dmg`
3. Open the DMG file
4. Drag **StartupManager.app** to your **Applications** folder
5. Launch from Applications (Right-click → Open for first launch)

### For Developers

1. Clone the repository
```bash
git clone https://github.com/yourusername/StartupManager.git
cd StartupManager
```

2. Open in Xcode
```bash
open StartupManager.xcodeproj
```

3. Build and run (⌘R)

## Permissions

StartupManager requires the following permissions:

- **AppleScript Automation** - To manage Login Items via System Events
- **File Access** - To read Launch Agent/Daemon plist files

The app will request these permissions on first launch.

## Usage

### Managing Login Items
- View all login items in the "Login Items" category
- Toggle items on/off using the switch
- Drag .app files directly into the window to add new login items
- Remove items using the context menu or batch remove

### Managing Launch Agents/Daemons
- Browse user and system launch agents/daemons
- View startup impact and estimated time
- Toggle user agents (system agents require admin privileges)
- See detailed error messages for troubleshooting

### System vs User Files
- **User files** (`~/Library/LaunchAgents`) - Can be toggled and removed
- **System files** (`/Library/*`, `/System/Library/*`) - Read-only, terminal commands provided

## Technical Details

### Architecture
- **SwiftUI** - Modern declarative UI framework
- **Async/Await** - Concurrent data loading for responsive UI
- **AppleScript Bridge** - Integration with macOS System Events
- **launchctl Integration** - Direct control over launch services

### Performance Optimization
- **Service Cache** - Single `launchctl list` call cached for 5 seconds
- **Parallel Loading** - Login Items, Launch Agents, and Daemons load concurrently
- **Local State Updates** - No refresh needed after toggle operations

### Startup Impact Calculation
The app estimates startup impact based on:
- `RunAtLoad` - Items that run immediately at startup
- `KeepAlive` - Items that stay running continuously
- Parallel execution model - Most items start simultaneously
- Formula: `max_time + (sum_time * 0.3)` to account for serial portions

### Data Persistence
- **Login Items** - Local UserDefaults database for disabled state persistence
- **Launch Agents/Daemons** - Direct plist file parsing with validation

## Limitations

- System Launch Agents/Daemons require admin privileges to toggle (terminal commands provided)
- Background Items (macOS 13+) require Full Disk Access (not implemented)
- Startup impact is estimated, not measured from actual boot times
- Priority changes via Nice values are not supported (startup order cannot be modified)

## Security

- Validates plist files for malicious patterns before parsing
- Prevents modification/deletion of system-protected files
- No elevated privileges requested - runs entirely in user space
- Sandbox disabled for file system access (required for plist reading)

## Troubleshooting

### "Permission Denied" errors
Grant AppleScript automation permission in:
System Settings → Privacy & Security → Automation

### System files won't toggle
This is expected. Use the provided terminal command:
```bash
sudo launchctl load/unload <path>
```

### Changes not persisting
- Login Items use local database - disable state is preserved
- Launch Agents require the plist file to exist

## Contributing

Contributions are welcome! This app is designed for technical users who understand macOS startup processes.

## License

MIT License - feel free to use and modify

## Credits

Built with SwiftUI and native macOS frameworks. No third-party dependencies.

---

**Note:** This is a technical utility for advanced users. Always be cautious when modifying system startup items.
