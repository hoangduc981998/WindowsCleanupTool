# Changelog

All notable changes to WindowsCleanupTool will be documented in this file.

## [2.1.0] - 2025-12-01

### Features from CleanUpTool_old.ps1 Integration

### Added

#### Network Utilities (Tab Tiện Ích)
- **Xóa Cache DNS** - Flush DNS resolver cache with `ipconfig /flushdns`
- **Đặt lại cài đặt mạng** - Reset Winsock and TCP/IP stack (requires restart)
- **Khởi động lại Card mạng** - Disable/Enable active network adapter automatically

#### Scheduled Cleanup (Dọn dẹp tự động)
- **⏰ Thiết lập dọn dẹp tự động** button in Tiện Ích tab
- Creates Windows Scheduled Task `WindowsCleanupTool_Auto`
- Runs at 2:00 AM every Sunday with SYSTEM privileges
- **`-AutoRun` parameter** - Run cleanup automatically without UI (for scheduled tasks)

#### Registry Backup (Sao lưu Registry)
- **💾 Sao lưu Registry** - Improved backup functionality
- Backs up both HKLM\SOFTWARE and HKCU
- File naming: `RegBackup_YYYYMMDD_HHMMSS_HKLM.reg` and `RegBackup_YYYYMMDD_HHMMSS_HKCU.reg`
- Progress display in logBox

#### Cloud Clipboard (Tab Riêng Tư)
- **Tắt Cloud Clipboard** checkbox added to Privacy tab
- Sets `EnableClipboardHistory` = 0
- Sets `CloudClipboardEnabled` = 0

#### Disk Health Check Fix
- Fixed to use MessageBox instead of Out-GridView
- Windows Sandbox detection - shows appropriate message
- Formatted output with FriendlyName, HealthStatus, Size (GB), MediaType

### Existing Features (Already Implemented in v2.0)
- Select All / Deselect All buttons - Already present via Add-TaskItem function
- Tooltip System - Already present ($tooltip object with IsBalloon, AutoPopDelay, etc.)

## [2.0.0] - 2025-12-01

### Major Release - Plugin System & Safety Features

### Added

#### Safety System
- Protected Paths Validation - Prevents deletion of critical system folders
- Protected File Extensions - Blocks deletion of system files (.sys, .dll, .exe, .ini, .inf)
- File-in-Use Detection - Checks if files are locked before attempting deletion
- New Functions: Test-SafeToDelete, $global:ProtectedPaths, $global:ProtectedExtensions

#### Quarantine System
- Automatic Quarantine - Files moved to quarantine instead of permanent deletion
- 7-Day Retention Policy - Auto-cleanup of old quarantined files
- Metadata Tracking - JSON metadata for each quarantined file
- Easy Restore Mechanism - One-click restore from quarantine
- New Functions: Move-ToQuarantine, Restore-FromQuarantine, Clear-OldQuarantine

#### Plugin Architecture
- Extensible Plugin System - Support for app-specific cleanup plugins
- Auto-Loading - Plugins automatically loaded from Plugins/ folder on startup
- 4 Sample Plugins: Spotify, Discord, Steam, VSCode
- Plugin Template - Ready-to-use template (PluginTemplate.ps1)
- New Functions: Load-CleanupPlugins, $global:LoadedPlugins

#### Testing & CI/CD
- Integration Test Suite (Tests/IntegrationTest.ps1)
- GitHub Actions Workflow (.github/workflows/test.yml)
- Automated testing on every push/PR

#### Documentation
- Plugin Development Guide (Plugins/README.md)
- Plugin Template with full documentation

### Changed
- CleanUpTool.ps1 - Updated to integrate new safety and plugin systems

### Security
- Protected Paths - Critical system folders protected from accidental deletion
- Protected Extensions - System files cannot be deleted outside temp folders
- File Lock Detection - Prevents deletion of files currently in use

## [1.0.0] - 2025-11-27

### Added
- Initial release of WindowsCleanupTool
- Basic cleanup features
- Windows optimization features
- Vietnamese language support
