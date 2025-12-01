# CHANGELOG for WindowsCleanupTool

## Version 2.0.0 (2025-12-01)

### New Features:

- **Safety System**
  - **Protected Paths**: Users can now specify certain paths that should be excluded from cleanup operations to prevent accidental deletion.
  - **Protected Extensions**: This feature allows users to protect specific file extensions from being deleted.
  - **File-in-Use Detection**: The system can now detect files currently in use and will not attempt to delete them, preventing potential data loss.

- **Quarantine System**
  - **7-Day Retention**: Files deleted by the tool are temporarily quarantined for 7 days, allowing users to recover files if necessary.
  - **Metadata Tracking**: The system tracks metadata of quarantined files, making recovery easier by providing details about the file and its original location.
  - **Restore Mechanism**: Users can restore any quarantined files back to their original location easily.

- **Plugin Architecture**
  - Introduced a flexible plugin system allowing extension of the application's functionality. 
  - **Sample Plugins**:
    - Spotify
    - Discord
    - Steam
    - VSCode

- **Testing & CI/CD**
  - Added integration tests to ensure the tool functions correctly.
  - Implementation of GitHub Actions for continuous integration and delivery, automating build and test processes.

### Backward Compatibility Notes:
- Version 2.0.0 maintains backward compatibility with previous configurations. Ensure to review the settings if migrating from earlier versions. 

### Migration Guide:
- Follow the [Migration Guide](#) for detailed instructions on transitioning from version 1.x to 2.0.0. This includes changes in configurations and new feature setups.

### Roadmap for Future Versions:
- Future enhancements are planned, including:
  - Enhanced user interface for better usability.
  - Additional sample plugins and community contributions.
  - Advanced automation features for cleanup operations.