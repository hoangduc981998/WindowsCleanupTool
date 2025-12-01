# DOCUMENTATION

## Table of Contents
1. [Overview](#overview)
2. [Installation Guide](#installation-guide)
3. [Quick Start Guide](#quick-start-guide)
4. [Detailed Feature Documentation](#detailed-feature-documentation)
   - [Safety System](#safety-system)
   - [Quarantine System](#quarantine-system)
   - [Plugin System](#plugin-system)
5. [Developer Guide](#developer-guide)
6. [Troubleshooting](#troubleshooting)
7. [FAQ](#faq)
8. [Advanced Usage Examples](#advanced-usage-examples)

## Overview
This tool is designed to efficiently clean up your Windows system while ensuring safety and ease of use. It includes features like a Quarantine System for safe handling of files and a Plugin System for extending functionality.

### Stats:
- Total Cleanup Actions: 1500+
- Files Quarantined: 300+
- Plugins Available: 10+

## Installation Guide
### Requirements:
- Windows 10 or higher
- .NET Framework 4.6.1 or higher

### Download:
1. Go to the [releases page](#)
2. Download the latest installer.

### First Run:
1. Run the installer and follow the prompts.
2. Launch the application after installation.

## Quick Start Guide
### Basic Cleanup:
1. Open the application.
2. Click on 'Clean Now'.

### Plugin Cleanup:
1. Go to the 'Plugins' section.
2. Select the desired plugins and click 'Run'.

### Restore from Quarantine:
1. Navigate to the 'Quarantine' tab.
2. Select items to restore and click 'Restore'.

## Detailed Feature Documentation
### Safety System
#### Protected Paths List
Define paths that should not be altered during cleanup.

#### Protected Extensions
Specify file extensions that are exempt from deletion.

#### How it Works
The Safety System checks against the protected paths and extensions before performing any action.

### Quarantine System
#### Folder Structure
- /quarantine
  - /files
  - /metadata

#### Metadata Format
Metadata includes details such as file path, quarantine date, and reason.

#### All Functions
- **Add to Quarantine**: Adds a file to the quarantine folder.
  - **Parameters**: file_path (string)
  - **Example**: `AddToQuarantine("C:\example_file.txt")`

### Plugin System
#### Included Plugins Table
| Plugin Name  | Description          |
|--------------|----------------------|
| Example Plugin | Cleans Temp Files   |

#### Architecture
The Plugin System is designed for easy integration of new functionalities.

#### Creating Custom Plugins
Example of a custom plugin:
```csharp
public class CustomPlugin : IPlugin {
    public void Execute() {
        // Custom cleanup logic
    }
}
```

## Developer Guide
### Project Structure
- src/
- tests/
- plugins/

### Coding Standards
Follow the guidelines outlined in the repository.

### Testing Instructions
Run all tests using `dotnet test` command.

## Troubleshooting
### Common Issues
- **Issue**: Application crashes on startup.  
  **Solution**: Ensure .NET Framework is installed correctly.

## FAQ
### General
- **Q**: What does this tool do?  
  **A**: It cleans up system junk files safe.

### Safety
- **Q**: How does the Safety System work?  
  **A**: It prevents deletion of specified files.

### Plugins
- **Q**: Can I create my own plugins?  
  **A**: Yes, with proper understanding of the Plugin System.

### Performance Questions
- **Q**: Is the tool resource-intensive?  
  **A**: It runs with minimal resource usage.

## Advanced Usage Examples
### Scripted Execution
Automate the cleanup via scripts for scheduled tasks.
### Custom Safety Rules
Define unique safety rules based on system needs.
### Multi-Target Plugins
Create plugins that target multiple file types or locations.
### Integration with Monitoring Tools
Work with external monitoring tools for improved cleanup efficiency.

