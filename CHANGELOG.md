# Changelog

Tất cả các thay đổi quan trọng của dự án **WindowsCleanupTool** sẽ được ghi lại trong file này. 

Định dạng dựa trên [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
và dự án tuân thủ [Semantic Versioning](https://semver. org/spec/v2.0.0.html).

---

## [Unreleased]

### Planned
- [ ] Hỗ trợ đa ngôn ngữ (English, Japanese, Korean)
- [ ] Dark Mode cho giao diện
- [ ] Export report dạng HTML/PDF
- [ ] Cloud backup cho Quarantine files
- [ ] AI-powered cleanup recommendations

---

## [2.1.0] - 2025-12-02

### ✨ Added (Tính Năng Mới)

#### **Network Utilities (Tiện Ích Mạng)**
- **Xóa Cache DNS** (`FlushDnsCache`) - Làm mới bộ nhớ đệm DNS
- **Reset Network Stack** (`ResetNetworkStack`) - Reset Winsock và TCP/IP (cần khởi động lại)
- **Khởi động lại Card mạng** (`RestartActiveAdapter`) - Tự động detect và restart card mạng đang hoạt động

#### **Scheduled Cleanup (Dọn Dẹp Tự Động)**
- **Thiết lập lịch tự động** - Tạo Windows Scheduled Task chạy cleanup hàng tuần
- **Auto-run mode** - Hỗ trợ tham số `-AutoRun` để chạy từ Task Scheduler
- Task mặc định: 2:00 AM mỗi Chủ Nhật, chạy với quyền SYSTEM
- Kiểm tra task đã tồn tại và cho phép cập nhật

#### **Registry Backup (Sao Lưu Registry)**
- **Button sao lưu Registry** - Backup HKLM và HKCU vào Desktop
- Format file: `RegBackup_YYYYMMDD_HHMMSS_[HIVE].reg`
- Progress tracking trong LogBox
- Thông báo kết quả chi tiết

#### **UI/UX Improvements**
- **Select All / Deselect All** - Thêm nút "Chọn tất cả" và "Bỏ tất cả" cho 5 tabs
- **Tooltip System** - Hiển thị mô tả chi tiết khi hover vào checkbox/button
  - AutoPopDelay: 8000ms
  - Balloon style với icon Info
- Cải thiện layout buttons trong tabs

#### **Privacy Features**
- **Disable Cloud Clipboard** - Tắt đồng bộ hóa clipboard qua cloud (Registry: `HKCU:\Software\Microsoft\Clipboard`)

### 🔧 Fixed (Sửa Lỗi)

#### **Disk Health Check**
- **Sửa lỗi Out-GridView** - Không còn crash khi chạy trên Windows Sandbox/Server Core
- **Sandbox Detection** - Tự động detect Windows Sandbox (`WDAGUtilityAccount`) và hiển thị thông báo phù hợp
- **MessageBox thay Out-GridView** - Hiển thị thông tin ổ cứng trong MessageBox với format đẹp hơn
- Hiển thị chi tiết: FriendlyName, HealthStatus, Size (GB), MediaType

#### **WinSxS Cleanup**
- **Cải thiện error handling** - Phân biệt rõ exit code:
  - `0`: Thành công
  - `-2146498554` (CBS_E_PENDING): Component Store đang được sử dụng → Log INFO thay vì WARN
  - Các code khác: Ghi WARN với exit code cụ thể
- Không còn hiển thị lỗi giả (false positive)

#### **Restore Point Frequency**
- **Giảm tạo Restore Point không cần thiết** - Chỉ tạo nếu > 30 phút kể từ lần trước
- Hiển thị thời gian restore point gần nhất trong log
- Log rõ ràng khi bỏ qua tạo restore point

#### **Scheduled Task**
- **Fix duplicate task** - Kiểm tra task đã tồn tại và hỏi người dùng có muốn cập nhật không
- **Xóa task cũ** trước khi tạo mới tránh conflict
- Ghi log chi tiết khi tạo/cập nhật task

#### **Encoding Issues**
- Đảm bảo tất cả log files sử dụng UTF-8 encoding
- Sửa lỗi ký tự Trung Quốc trong log (do network adapter name)

### 📚 Changed (Thay Đổi)

#### **Logging**
- Thêm timestamp cho tất cả log entries
- Cải thiện format log cho network utilities
- Thêm log cho Scheduled Task operations
- Thêm log chi tiết cho Registry backup

#### **Error Messages**
- Cải thiện thông báo lỗi cho WinSxS cleanup
- Thêm hướng dẫn rõ ràng hơn cho reset network (cần khởi động lại)
- MessageBox thông báo đầy đủ hơn cho các utility

#### **Code Quality**
- Refactor network utilities logic
- Improve error handling với try-catch đầy đủ
- Thêm validation cho user inputs
- Code comments chi tiết hơn

### 🔒 Security
- Tất cả network operations yêu cầu xác nhận từ người dùng
- Registry backup tự động trước khi cleanup
- Quarantine system giữ nguyên (7 ngày retention)

### ⚡ Performance
- Disk Health Check chạy nhanh hơn (bỏ qua trên Sandbox)
- Registry backup tối ưu hóa (chỉ backup HKLM\SOFTWARE thay vì toàn bộ HKLM)
- Restore Point check không làm chậm UI

---

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

### ✨ Added

#### **Safety System**
- **Protected Paths** - Ngăn xóa thư mục quan trọng:
  - `C:\Windows\System32`
  - `C:\Program Files`
  - `C:\Users\[User]\Documents`
  - `C:\Users\[User]\Pictures`
  - `C:\Users\[User]\Desktop`
- **Protected File Extensions** - Không xóa: `.sys`, `.dll`, `.exe`, `. ini`, `.inf`
- **File-in-Use Detection** - Tự động skip file đang được sử dụng

#### **Quarantine System**
- **7-Day Retention** - Tất cả file xóa được giữ 7 ngày
- **Metadata Tracking** - Lưu thông tin file gốc (path, size, hash, timestamp)
- **Easy Restore** - Khôi phục file từ Quarantine dễ dàng
- Location: `%LOCALAPPDATA%\CleanupTool\Quarantine\`

#### **Plugin Architecture**
- **Modular Design** - Hỗ trợ plugin động
- **4 Sample Plugins:**
  - **Spotify** - Clean `*. file` cache (~500 MB)
  - **Discord** - Clean cache folders (~300 MB)
  - **Steam** - Clean download cache (~2 GB)
  - **VSCode** - Clean logs, CachedData > 7 days (~200 MB)
- **Auto-Discovery** - Plugins tự động load từ `Plugins/` folder
- **Enable/Disable** - Bật/tắt plugin qua metadata

#### **Health Dashboard**
- **Real-time Monitoring:**
  - CPU Usage (%)
  - RAM Usage (%)
  - Disk Space (Free GB & Used %)
  - Temp Files Size (MB)
  - Startup Apps Count
- **Health Score (0-100)** - Tính toán dựa trên các metrics
- **Recommendations** - Gợi ý tối ưu hóa dựa trên health score

#### **Registry Cleaner**
- **Scan Registry Issues:**
  - Invalid Uninstall Entries
  - Missing Shared DLLs
  - Obsolete MUI Cache
  - Missing Icons
- **Safe Cleanup** - Backup registry trước khi dọn dẹp
- **Selective Fix** - Chọn lỗi cụ thể để fix

#### **Duplicate File Finder**
- **MD5 Hash-based** - Tìm file trùng 100% chính xác
- **Configurable Min Size** - Chỉ quét file > 1 MB
- **Size Grouping** - Group theo size trước khi hash (nhanh hơn)
- **Safe Delete** - Giữ file đầu tiên, xóa các bản copy
- **Space Estimation** - Hiển thị dung lượng có thể giải phóng

#### **Advanced Uninstaller**
- **Complete Removal:**
  - Chạy uninstaller gốc (MSI/EXE)
  - Xóa install folder
  - Xóa AppData leftovers (`%LOCALAPPDATA%`, `%APPDATA%`, `%ProgramData%`)
- **Silent Mode Detection** - Tự động detect `/S`, `/qn` flags
- **Search & Filter** - Tìm kiếm app theo tên
- **App Details** - Hiển thị Publisher, Version, Size, Install Date

#### **Testing & CI/CD**
- **Automated Tests** - Pester tests cho core functions
- **GitHub Actions Workflow** - CI/CD pipeline
- **Pre-commit Hooks** - Validate code trước khi commit

### 🔧 Fixed
- Sửa UTF-8 encoding issues trong log files
- Cải thiện error handling cho Windows Sandbox
- Fix uninstaller silent mode detection
- Sửa lỗi Out-GridView trên Server Core

### 📚 Changed
- Refactor code structure: Split functions vào modules riêng
- Cải thiện UI layout: Health Dashboard lên đầu
- Tăng font size cho dễ đọc
- Thay đổi color scheme: Accent color = `#0078D7`

### ⚡ Performance
- Optimize duplicate file scan: Group by size trước
- Lazy-load installed apps: Chỉ load khi mở tab Uninstaller
- Background health monitoring: Refresh mỗi 30s

---

## [1.0. 0] - 2024-11-15

### ✨ Added

#### **Core Cleanup Features**
- **Basic Cleanup:**
  - Temp Files (User & System)
  - Recycle Bin
  - Browser Cache (Chrome, Edge, Firefox)
  - Windows Update Cache
  - Prefetch Files
  - Old Downloads (>30 days)
  - Event Logs
  - Thumbnail Cache

- **Advanced Cleanup:**
  - WinSxS Deep Clean
  - Microsoft Store Reset
  - OneDrive Cache
  - Hibernation File
  - Font Cache
  - CompactOS Compression

#### **Optimization Features**
- Startup Optimization
- Service Optimization (Disable DiagTrack, etc.)
- Page File Optimization
- Visual Effects Tuning
- High Performance Power Plan
- Game DVR Disable
- Windows Search Optimization
- Shutdown Timeout Reduction

#### **Security Features**
- Quick Virus Scan (Windows Defender)
- Firewall Check
- Show File Extensions
- Disable Remote Assistance
- Disable SMBv1
- Clear Web History
- Windows Update Check
- PUA Protection

#### **Privacy Features**
- Disable Microphone
- Disable Camera
- Disable Cortana & Copilot
- Clear Activity History
- Disable Telemetry
- Disable Advertising ID
- Disable Start Menu Suggestions
- Disable Feedback Notifications
- Disable Location Tracking

#### **Utilities**
- Disk Cleanup (Open cleanmgr)
- Disk Health Check (SMART)
- Startup Manager (Task Manager)
- System Info (msinfo32)
- Fix Common Issues (SFC /scannow)
- Disk Partition Manager (diskmgmt.msc)

#### **Winget Integration**
- Auto-update all apps via Winget
- Check for updates button

#### **UI/UX**
- Modern Windows 11 style UI
- Tabbed interface (10 tabs)
- System Info Panel (OS, CPU, RAM, Disk)
- Log Box với real-time updates
- Progress Bar
- Color-coded messages (Info, OK, Warn, Error)

### 🔧 Technical
- PowerShell 5.1+ support
- Windows Forms GUI
- Admin rights auto-elevation
- Error handling với try-catch
- Logging to Desktop (`CleanupTool_YYYYMMDD. log`)

---

## [0.9.0-beta] - 2024-10-01

### ✨ Added
- Initial beta release
- Basic cleanup functions (Temp, Cache, Recycle Bin)
- Simple console-based UI
- Manual admin elevation

### Known Issues
- No error handling
- UI freeze khi chạy tác vụ lâu
- Không có logging

---

## Định Nghĩa Phiên Bản

- **[Unreleased]** - Tính năng đang phát triển
- **[X.Y.Z]** - Phiên bản đã phát hành
  - **X (Major)** - Thay đổi lớn, breaking changes
  - **Y (Minor)** - Thêm tính năng mới, backward compatible
  - **Z (Patch)** - Bug fixes, cải tiến nhỏ

## Loại Thay Đổi

- **Added** - Tính năng mới
- **Changed** - Thay đổi tính năng hiện có
- **Deprecated** - Tính năng sắp loại bỏ
- **Removed** - Tính năng đã xóa
- **Fixed** - Bug fixes
- **Security** - Sửa lỗi bảo mật

---

## Link Tham Khảo

- [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
- [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
- [Conventional Commits](https://www.conventionalcommits.org/)

---

**Maintained by:** Hoàng Đức ([@hoangduc981998](https://github.com/hoangduc981998))  
**Repository:** https://github.com/hoangduc981998/WindowsCleanupTool