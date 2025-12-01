# Changelog

All notable changes to WindowsCleanupTool will be documented in this file.

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
