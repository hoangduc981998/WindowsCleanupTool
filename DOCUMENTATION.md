```markdown
# WindowsCleanupTool v2.0 - Complete Documentation

## Table of Contents
1. [Overview](#overview)
2. [Installation](#installation)
3. [Quick Start](#quick-start)
4. [Features](#features)
5. [Safety System](#safety-system)
6. [Quarantine System](#quarantine-system)
7. [Plugin System](#plugin-system)
8.  [Developer Guide](#developer-guide)
9. [Troubleshooting](#troubleshooting)
10. [FAQ](#faq)

---

## Overview

**WindowsCleanupTool v2.0** is an enterprise-grade Windows system cleanup tool. 

### Key Features
- 🛡️ **Safety First** - Protects system files
- 📦 **Quarantine System** - Undo within 7 days
- 🔌 **Plugin Architecture** - Easy to extend
- 🧪 **Automated Testing** - CI/CD ensures quality

### Requirements
- **OS:** Windows 10/11 (64-bit)
- **PowerShell:** 5.1 or later
- **Permissions:** Administrator rights

---

## Installation

```powershell
git clone https://github.com/hoangduc981998/WindowsCleanupTool.git
cd WindowsCleanupTool
.\CleanUpTool.ps1
```

---

## Quick Start

1. Launch: `.\CleanUpTool.ps1`
2. Select tasks in "Dọn Dẹp Cơ Bản" tab
3. Click "BẮT ĐẦU THỰC HIỆN"

---

## Safety System

### Protected Paths
```powershell
$global:ProtectedPaths = @(
    "$env:SystemRoot",
    "$env:SystemRoot\System32",
    "$env:ProgramFiles",
    "$env:USERPROFILE\Documents"
)
```

### Protected Extensions
```powershell
$global:ProtectedExtensions = @('. sys', '.dll', '.exe', '.ini', '.inf')
```

---

## Quarantine System

### Folder Structure
```
%LOCALAPPDATA%\CleanupTool\Quarantine\
├── 20251201_120000\
│   ├── abc123-file.tmp
│   └── abc123-file.tmp.meta. json
```

### Functions

```powershell
# Move to quarantine
Move-ToQuarantine -FilePath "C:\path\file.tmp" -TaskSource "Manual"

# Restore
Restore-FromQuarantine -QuarantinePath "C:\Users\.. .\Quarantine\.. .\file.tmp"

# Cleanup old
Clear-OldQuarantine -DaysOld 7
```

---

## Plugin System

### Included Plugins
- **Spotify** - Cache cleaner (~500 MB)
- **Discord** - Cache folders (~300 MB)
- **Steam** - Download cache (~2 GB)
- **VSCode** - Logs & cache (~200 MB)

### Creating Custom Plugin

```powershell
# 1. Copy template
Copy-Item PluginTemplate.ps1 Plugins/Plugin_MyApp.ps1

# 2.  Implement 4 functions:
# - Get-PluginMetadata
# - Get-CleanupTargets
# - Invoke-PluginCleanup
# - Get-EstimatedSpace

# 3.  Restart tool
.\CleanUpTool.ps1
```

---

## Developer Guide

### Project Structure
```
WindowsCleanupTool/
├── CleanUpTool.ps1
├── PluginTemplate.ps1
├── Plugins/
├── Tests/
└── . github/workflows/
```

### Testing
```powershell
.\Tests\IntegrationTest.ps1
```

---

## Troubleshooting

### Execution Policy Error
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Plugin Not Loading
- Check file starts with `Plugin_`
- Verify `Export-ModuleMember -Function *` at end
- Set `Enabled = $true` in metadata

---

## FAQ

**Q: Is it safe? **  
A: Yes! Protected paths, quarantine system, file-in-use detection. 

**Q: How to restore files?**  
A: Use `Restore-FromQuarantine` function.

**Q: Can I disable quarantine?**  
A: Yes, but not recommended. 

---

## Support

- 🐛 Issues: https://github.com/hoangduc981998/WindowsCleanupTool/issues
- 📧 Email: hoangduc981998@gmail.com

---

**Version:** 2.0.0  
**Author:** Hoàng Đức
```
