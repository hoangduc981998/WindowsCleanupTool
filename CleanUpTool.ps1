# CleanUpTool.ps1 - Phiên bản đã tối ưu, sửa lỗi, giữ đầy đủ chức năng
# Tác giả: hoangduc981998
# Cập nhật: 2025

# Lưu file này với tên CleanUpTool.ps1
# Chạy PowerShell với quyền Admin và gõ: Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
# Sau đó mới có thể chạy file này

# -- 1. Kiểm tra quyền Admin --
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Start-Process PowerShell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# -- 2. Load các thư viện --
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# -- 3. Định nghĩa các hàm dùng chung --
function Set-CheckboxesState {
    param($checkboxes, [bool]$state)
    foreach ($checkbox in $checkboxes.Values) {
        $checkbox.Checked = $state
    }
}

function Create-RoundedButton {
    param($text, $x, $y, $width, $height)
    $button = New-Object System.Windows.Forms.Button
    $button.Location = New-Object System.Drawing.Point($x, $y)
    $button.Size = New-Object System.Drawing.Size($width, $height)
    $button.Text = $text
    $button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $button.FlatAppearance.BorderSize = 0
    $button.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
    $button.ForeColor = [System.Drawing.Color]::White
    $button.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)
    $button.Cursor = [System.Windows.Forms.Cursors]::Hand
    return $button
}

function Safe-RestartExplorer {
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    
    # Đợi explorer đóng hoàn toàn với timeout
    $timeout = 10 # seconds
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    
    while (Get-Process explorer -ErrorAction SilentlyContinue) {
        if ($timer.Elapsed.TotalSeconds -gt $timeout) {
            Write-Log "Cảnh báo: Không thể đóng explorer.exe sau $timeout giây"
            break
        }
        Start-Sleep -Milliseconds 200
    }
    
    Start-Sleep -Seconds 1
    Start-Process explorer
}

function Write-Log {
    param([string]$message)
    $time = Get-Date -Format "HH:mm:ss"
    $logMessage = "[$time] $message"

    if ($logBox -ne $null -and $logBox.IsHandleCreated) {
        try {
            $logBox.Invoke([Action]{
                $logBox.AppendText("$logMessage`n")
                $logBox.SelectionStart = $logBox.Text.Length
                $logBox.ScrollToCaret()
            })
        } catch {
            Write-Host "$logMessage (Lỗi khi ghi vào log box: $($_.Exception.Message))"
        }
    } else {
        Write-Host $logMessage
    }
}

function Remove-FileWithErrorHandling {
    param([string]$FilePath)
    
    try {
        Remove-Item -Path $FilePath -Force -ErrorAction Stop
        Write-Log "✅ Đã xóa thành công: $FilePath"
        return $true
    } 
    catch [System.UnauthorizedAccessException] {
        Write-Log "❌ Quyền truy cập bị từ chối: $FilePath"
    } 
    catch [System.IO.IOException] {
        Write-Log "❌ File đang được sử dụng: $FilePath"
    } 
    catch {
        Write-Log "❌ Lỗi khi xóa file ${FilePath}: $($_.Exception.Message)"
    }
    return $false
}

# Hàm phân tích dịch vụ Windows và đưa ra gợi ý
$script:CriticalServices = @(
    "wuauserv",      # Windows Update - Cần thiết cho cập nhật bảo mật
    "WinDefend",     # Windows Defender - Bảo vệ hệ thống khỏi phần mềm độc hại
    "Dhcp",          # DHCP Client - Cần thiết cho kết nối mạng
    "Dnscache",      # DNS Client - Cần cho phân giải tên miền
    "nsi",           # Network Store Interface Service - Yêu cầu cho kết nối mạng
    "LanmanWorkstation", # Workstation - Cần thiết để truy cập mạng
    "wscsvc",        # Security Center - Theo dõi bảo mật
    "netprofm",      # Network List Service - Quản lý kết nối mạng
    "DcomLaunch",    # DCOM Server Process Launcher - Khởi chạy các ứng dụng COM
    "RpcSs",         # Remote Procedure Call - Giao tiếp giữa các quy trình
    "LSM",           # Local Session Manager - Quản lý phiên đăng nhập
    "CoreMessagingRegistrar", # CoreMessaging - Giao tiếp ứng dụng nội bộ
    "SystemEventsBroker" # System Events Broker - Quản lý sự kiện hệ thống
)

$script:SafeToDisableServices = @{
    "DiagTrack" = @{
        Description = "Connected User Experiences and Telemetry - Thu thập dữ liệu sử dụng"
        DefaultRecommendation = "Có thể tắt"
        Level = "Safe"
    }
    "dmwappushservice" = @{
        Description = "Device Management Wireless Application Protocol - Chỉ cần cho WAP Push Message Routing Service"
        DefaultRecommendation = "Có thể tắt"
        Level = "Safe"
    }
    "HomeGroupListener" = @{
        Description = "HomeGroup Listener - Không cần nếu không dùng HomeGroup"
        DefaultRecommendation = "Có thể tắt"
        Level = "Safe"
    }
    "HomeGroupProvider" = @{
        Description = "HomeGroup Provider - Không cần nếu không dùng HomeGroup"
        DefaultRecommendation = "Có thể tắt"
        Level = "Safe"
    }
    "SysMain" = @{
        Description = "SysMain/Superfetch - Trên SSD không cần thiết"
        DefaultRecommendation = "Tùy thuộc vào loại ổ đĩa"
        Level = "Safe"
    }
    "WSearch" = @{
        Description = "Windows Search - Có thể tắt nếu không thường xuyên tìm kiếm"
        DefaultRecommendation = "Có thể tắt"
        Level = "Safe"
    }
    "XblAuthManager" = @{
        Description = "Xbox Live Auth Manager - Chỉ cần nếu dùng Xbox app"
        DefaultRecommendation = "Có thể tắt"
        Level = "Safe"
    }
    "XblGameSave" = @{
        Description = "Xbox Live Game Save - Chỉ cần nếu lưu game Xbox"
        DefaultRecommendation = "Có thể tắt"
        Level = "Safe"
    }
    "XboxNetApiSvc" = @{
        Description = "Xbox Live Networking - Chỉ cần nếu chơi game Xbox"
        DefaultRecommendation = "Có thể tắt"
        Level = "Safe"
    }
    "lfsvc" = @{
        Description = "Geolocation Service - Dịch vụ định vị"
        DefaultRecommendation = "Có thể tắt"
        Level = "Safe"
    }
    "MapsBroker" = @{
        Description = "Downloaded Maps Manager - Chỉ cần nếu dùng Maps offline"
        DefaultRecommendation = "Có thể tắt"
        Level = "Safe"
    }
    "PcaSvc" = @{
        Description = "Program Compatibility Assistant - Có thể tắt sau khi cài đặt các phần mềm"
        DefaultRecommendation = "Có thể tắt"
        Level = "Safe"
    }
    "RemoteRegistry" = @{
        Description = "Remote Registry - Chỉ cần khi quản trị từ xa"
        DefaultRecommendation = "Có thể tắt"
        Level = "Safe"
    }
    "RetailDemo" = @{
        Description = "Retail Demo Service - Chỉ dùng cho máy trưng bày"
        DefaultRecommendation = "Có thể tắt"
        Level = "Safe"
    }
    "TrkWks" = @{
        Description = "Distributed Link Tracking Client - Theo dõi liên kết file trên mạng"
        DefaultRecommendation = "Có thể tắt"
        Level = "Safe"
    }
    "WbioSrvc" = @{
        Description = "Windows Biometric Service - Chỉ cần nếu dùng nhận dạng sinh trắc học"
        DefaultRecommendation = "Có thể tắt"
        Level = "Safe"
    }
    "wisvc" = @{
        Description = "Windows Insider Service - Chỉ cần cho Windows Insider"
        DefaultRecommendation = "Có thể tắt" 
        Level = "Safe"
    }
    "WMPNetworkSvc" = @{
        Description = "Windows Media Player Network Sharing - Chia sẻ thư viện media"
        DefaultRecommendation = "Có thể tắt"
        Level = "Safe"
    }
}
$script:CriticalServices = @(
    "wuauserv",      # Windows Update - Cần thiết cho cập nhật bảo mật
    "WinDefend",     # Windows Defender - Bảo vệ hệ thống khỏi phần mềm độc hại
    "Dhcp",          # DHCP Client - Cần thiết cho kết nối mạng
    "Dnscache",      # DNS Client - Cần cho phân giải tên miền
    "nsi",           # Network Store Interface Service - Yêu cầu cho kết nối mạng
    "LanmanWorkstation", # Workstation - Cần thiết để truy cập mạng
    "wscsvc",        # Security Center - Theo dõi bảo mật
    "netprofm",      # Network List Service - Quản lý kết nối mạng
    "DcomLaunch",    # DCOM Server Process Launcher - Khởi chạy các ứng dụng COM
    "RpcSs",         # Remote Procedure Call - Giao tiếp giữa các quy trình
    "LSM",           # Local Session Manager - Quản lý phiên đăng nhập
    "CoreMessagingRegistrar", # CoreMessaging - Giao tiếp ứng dụng nội bộ
    "SystemEventsBroker" # System Events Broker - Quản lý sự kiện hệ thống
)
$script:CarefulServices = @{
    "Spooler" = @{
        Description = "Print Spooler - Cần thiết cho in ấn"
        Recommendation = "Không nên tắt"
        Level = "Dangerous"
    }
    "LanmanServer" = @{
        Description = "Server - Cần thiết cho chia sẻ file và máy in"
        Recommendation = "Không nên tắt"
        Level = "Dangerous"
    }
    "BITS" = @{
        Description = "Background Intelligent Transfer Service - Cần cho Windows Update"
        Recommendation = "Không nên tắt"
        Level = "Dangerous"
    }
    "wuauserv" = @{
        Description = "Windows Update - Cần cho cập nhật hệ thống"
        Recommendation = "Không nên tắt"
        Level = "Dangerous"
    }
    "EventLog" = @{
        Description = "Windows Event Log - Ghi nhật ký hệ thống quan trọng"
        Recommendation = "Không nên tắt"
        Level = "Dangerous"
    }
    "AppXSvc" = @{
        Description = "AppX Deployment Service - Cần cho ứng dụng Microsoft Store"
        Recommendation = "Không nên tắt"
        Level = "Dangerous"
    }
}

function Get-ServiceInfo {
    param(
        [string]$ServiceName
    )
    
    try {
        $service = Get-Service -Name $ServiceName -ErrorAction Stop
        return [PSCustomObject]@{
            Name = $service.Name
            DisplayName = $service.DisplayName
            Status = $service.Status
            StartType = $service.StartType
        }
    }
    catch {
        Write-Log "Không thể lấy thông tin dịch vụ ${ServiceName}: $($_.Exception.Message)"
        return $null
    }
}

function Test-IsSSD {
    try {
        # Phương pháp 1: Kiểm tra tên model có chứa "SSD"
        $diskDrive = Get-CimInstance -ClassName Win32_DiskDrive -ErrorAction Stop | 
                    Where-Object { $_.Model -like "*SSD*" }
        if ($diskDrive) {
            return $true
        }
        
        # Phương pháp 2: Kiểm tra thông qua MSFT_PhysicalDisk (Windows 8+ và Server 2012+)
        try {
            $physicalDisks = Get-CimInstance -Namespace "root\Microsoft\Windows\Storage" -ClassName MSFT_PhysicalDisk -ErrorAction Stop
            foreach ($disk in $physicalDisks) {
                if ($disk.MediaType -eq 4) { # 4 = SSD
                    return $true
                }
            }
        }
        catch {
            # MSFT_PhysicalDisk có thể không có trên một số phiên bản Windows cũ
            Write-Log "Không thể sử dụng MSFT_PhysicalDisk để xác định SSD: $($_.Exception.Message)"
        }
        
        # Phương pháp 3: Kiểm tra thời gian truy cập ngẫu nhiên (nếu dưới 1ms, có thể là SSD)
        $diskPerf = Get-CimInstance -ClassName Win32_DiskDrive | 
                   Get-CimAssociatedInstance -ResultClassName Win32_PerfFormattedData_PerfDisk_PhysicalDisk -ErrorAction SilentlyContinue
        foreach ($disk in $diskPerf) {
            if ($disk.AvgDiskSecPerRead -lt 0.001) { # Dưới 1ms
                return $true
            }
        }
        
        return $false
    }
    catch {
        Write-Log "Lỗi khi kiểm tra loại ổ đĩa: $($_.Exception.Message)"
        return $false
    }
}

# Tách dữ liệu tĩnh dịch vụ ra khỏi hàm để dễ bảo trì
$script:CriticalServices = @(
    "wuauserv",      # Windows Update - Cần thiết cho cập nhật bảo mật
    "WinDefend",     # Windows Defender - Bảo vệ hệ thống khỏi phần mềm độc hại
    "Dhcp",          # DHCP Client - Cần thiết cho kết nối mạng
    "Dnscache",      # DNS Client - Cần cho phân giải tên miền
    "nsi",           # Network Store Interface Service - Yêu cầu cho kết nối mạng
    "LanmanWorkstation", # Workstation - Cần thiết để truy cập mạng
    "wscsvc",        # Security Center - Theo dõi bảo mật
    "netprofm",      # Network List Service - Quản lý kết nối mạng
    "DcomLaunch",    # DCOM Server Process Launcher - Khởi chạy các ứng dụng COM
    "RpcSs",         # Remote Procedure Call - Giao tiếp giữa các quy trình
    "LSM",           # Local Session Manager - Quản lý phiên đăng nhập
    "CoreMessagingRegistrar", # CoreMessaging - Giao tiếp ứng dụng nội bộ
    "SystemEventsBroker" # System Events Broker - Quản lý sự kiện hệ thống
)

$script:SafeToDisableServices = @{
    "DiagTrack" = @{
        Description = "Connected User Experiences and Telemetry - Thu thập dữ liệu sử dụng"
        DefaultRecommendation = "Có thể tắt"
        Level = "Safe"
    }
    "dmwappushservice" = @{
        Description = "Device Management Wireless Application Protocol - Chỉ cần cho WAP Push Message Routing Service"
        DefaultRecommendation = "Có thể tắt"
        Level = "Safe"
    }
    "HomeGroupListener" = @{
        Description = "HomeGroup Listener - Không cần nếu không dùng HomeGroup"
        DefaultRecommendation = "Có thể tắt"
        Level = "Safe"
    }
    "HomeGroupProvider" = @{
        Description = "HomeGroup Provider - Không cần nếu không dùng HomeGroup"
        DefaultRecommendation = "Có thể tắt"
        Level = "Safe"
    }
    "SysMain" = @{
        Description = "SysMain/Superfetch - Trên SSD không cần thiết"
        DefaultRecommendation = "Tùy thuộc vào loại ổ đĩa"
        Level = "Safe"
    }
    "WSearch" = @{
        Description = "Windows Search - Có thể tắt nếu không thường xuyên tìm kiếm"
        DefaultRecommendation = "Có thể tắt"
        Level = "Safe"
    }
    "XblAuthManager" = @{
        Description = "Xbox Live Auth Manager - Chỉ cần nếu dùng Xbox app"
        DefaultRecommendation = "Có thể tắt"
        Level = "Safe"
    }
    "XblGameSave" = @{
        Description = "Xbox Live Game Save - Chỉ cần nếu lưu game Xbox"
        DefaultRecommendation = "Có thể tắt"
        Level = "Safe"
    }
    "XboxNetApiSvc" = @{
        Description = "Xbox Live Networking - Chỉ cần nếu chơi game Xbox"
        DefaultRecommendation = "Có thể tắt"
        Level = "Safe"
    }
    "lfsvc" = @{
        Description = "Geolocation Service - Dịch vụ định vị"
        DefaultRecommendation = "Có thể tắt"
        Level = "Safe"
    }
    "MapsBroker" = @{
        Description = "Downloaded Maps Manager - Chỉ cần nếu dùng Maps offline"
        DefaultRecommendation = "Có thể tắt"
        Level = "Safe"
    }
    "PcaSvc" = @{
        Description = "Program Compatibility Assistant - Có thể tắt sau khi cài đặt các phần mềm"
        DefaultRecommendation = "Có thể tắt"
        Level = "Safe"
    }
    "RemoteRegistry" = @{
        Description = "Remote Registry - Chỉ cần khi quản trị từ xa"
        DefaultRecommendation = "Có thể tắt"
        Level = "Safe"
    }
    "RetailDemo" = @{
        Description = "Retail Demo Service - Chỉ dùng cho máy trưng bày"
        DefaultRecommendation = "Có thể tắt"
        Level = "Safe"
    }
    "TrkWks" = @{
        Description = "Distributed Link Tracking Client - Theo dõi liên kết file trên mạng"
        DefaultRecommendation = "Có thể tắt"
        Level = "Safe"
    }
    "WbioSrvc" = @{
        Description = "Windows Biometric Service - Chỉ cần nếu dùng nhận dạng sinh trắc học"
        DefaultRecommendation = "Có thể tắt"
        Level = "Safe"
    }
    "wisvc" = @{
        Description = "Windows Insider Service - Chỉ cần cho Windows Insider"
        DefaultRecommendation = "Có thể tắt" 
        Level = "Safe"
    }
    "WMPNetworkSvc" = @{
        Description = "Windows Media Player Network Sharing - Chia sẻ thư viện media"
        DefaultRecommendation = "Có thể tắt"
        Level = "Safe"
    }
}

$script:CriticalServices = @(
    "wuauserv",      # Windows Update - Cần thiết cho cập nhật bảo mật
    "WinDefend",     # Windows Defender - Bảo vệ hệ thống khỏi phần mềm độc hại
    "Dhcp",          # DHCP Client - Cần thiết cho kết nối mạng
    "Dnscache",      # DNS Client - Cần cho phân giải tên miền
    "nsi",           # Network Store Interface Service - Yêu cầu cho kết nối mạng
    "LanmanWorkstation", # Workstation - Cần thiết để truy cập mạng
    "wscsvc",        # Security Center - Theo dõi bảo mật
    "netprofm",      # Network List Service - Quản lý kết nối mạng
    "DcomLaunch",    # DCOM Server Process Launcher - Khởi chạy các ứng dụng COM
    "RpcSs",         # Remote Procedure Call - Giao tiếp giữa các quy trình
    "LSM",           # Local Session Manager - Quản lý phiên đăng nhập
    "CoreMessagingRegistrar", # CoreMessaging - Giao tiếp ứng dụng nội bộ
    "SystemEventsBroker" # System Events Broker - Quản lý sự kiện hệ thống
)
$script:CarefulServices = @{
    "Spooler" = @{
        Description = "Print Spooler - Cần thiết cho in ấn"
        Recommendation = "Không nên tắt"
        Level = "Dangerous"
    }
    "LanmanServer" = @{
        Description = "Server - Cần thiết cho chia sẻ file và máy in"
        Recommendation = "Không nên tắt"
        Level = "Dangerous"
    }
    "BITS" = @{
        Description = "Background Intelligent Transfer Service - Cần cho Windows Update"
        Recommendation = "Không nên tắt"
        Level = "Dangerous"
    }
    "wuauserv" = @{
        Description = "Windows Update - Cần cho cập nhật hệ thống"
        Recommendation = "Không nên tắt"
        Level = "Dangerous"
    }
    "EventLog" = @{
        Description = "Windows Event Log - Ghi nhật ký hệ thống quan trọng"
        Recommendation = "Không nên tắt"
        Level = "Dangerous"
    }
    "AppXSvc" = @{
        Description = "AppX Deployment Service - Cần cho ứng dụng Microsoft Store"
        Recommendation = "Không nên tắt"
        Level = "Dangerous"
    }
}

function Get-ServiceInfo {
    param(
        [string]$ServiceName
    )
    
    try {
        $service = Get-Service -Name $ServiceName -ErrorAction Stop
        return [PSCustomObject]@{
            Name = $service.Name
            DisplayName = $service.DisplayName
            Status = $service.Status
            StartType = $service.StartType
        }
    }
    catch {
        Write-Log "Không thể lấy thông tin dịch vụ ${ServiceName}: $($_.Exception.Message)"
        return $null
    }
}

function Test-IsSSD {
    # Tạo CimSession để quản lý tài nguyên tốt hơn
    $cimSession = $null
    
    try {
        $cimSession = New-CimSession -ErrorAction Stop
        
        # Phương pháp 1: Kiểm tra tên model có chứa "SSD"
        $diskDrive = Get-CimInstance -CimSession $cimSession -ClassName Win32_DiskDrive -ErrorAction Stop | 
                    Where-Object { $_.Model -like "*SSD*" }
        if ($diskDrive) {
            return $true
        }
        
        # Phương pháp 2: Kiểm tra thông qua MSFT_PhysicalDisk (Windows 8+ và Server 2012+)
        try {
            $physicalDisks = Get-CimInstance -CimSession $cimSession -Namespace "root\Microsoft\Windows\Storage" -ClassName MSFT_PhysicalDisk -ErrorAction Stop
            foreach ($disk in $physicalDisks) {
                if ($disk.MediaType -eq 4) { # 4 = SSD
                    return $true
                }
            }
        }
        catch {
            # MSFT_PhysicalDisk có thể không có trên một số phiên bản Windows cũ
            Write-Log "Không thể sử dụng MSFT_PhysicalDisk để xác định SSD: $($_.Exception.Message)"
        }
        
        # Phương pháp 3: Kiểm tra thời gian truy cập ngẫu nhiên (nếu dưới 1ms, có thể là SSD)
        $diskPerf = Get-CimInstance -CimSession $cimSession -ClassName Win32_DiskDrive | 
                   Get-CimAssociatedInstance -ResultClassName Win32_PerfFormattedData_PerfDisk_PhysicalDisk -ErrorAction SilentlyContinue
        foreach ($disk in $diskPerf) {
            if ($disk.AvgDiskSecPerRead -lt 0.001) { # Dưới 1ms
                return $true
            }
        }
        
        return $false
    }
    catch {
        Write-Log "Lỗi khi kiểm tra loại ổ đĩa: $($_.Exception.Message)"
        return $false
    }
    finally {
        # Đóng và giải phóng CimSession
        if ($cimSession) {
            $cimSession.Close()
            $cimSession.Dispose()
            Remove-Variable -Name cimSession -ErrorAction SilentlyContinue
        }
    }
}

function Get-ServiceRecommendations {
    # Tạo CimSession để quản lý tài nguyên tốt hơn
    $cimSession = $null
    
    try {
        Write-Log "Đang phân tích cấu hình hệ thống..."
        $cimSession = New-CimSession -ErrorAction SilentlyContinue
        
        # Thu thập thông tin phần cứng để đưa ra gợi ý phù hợp
        $ramInfo = $null
        $totalRam = 0
        $isSSD = $false
        
        try {
            if ($cimSession) {
                $ramInfo = Get-CimInstance -CimSession $cimSession -ClassName Win32_ComputerSystem -ErrorAction Stop
                $totalRam = [math]::Round($ramInfo.TotalPhysicalMemory / 1GB, 0)
                Write-Log "Đã phát hiện: $totalRam GB RAM"
            } else {
                $ramInfo = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
                $totalRam = [math]::Round($ramInfo.TotalPhysicalMemory / 1GB, 0)
                Write-Log "Đã phát hiện: $totalRam GB RAM"
            }
            
            $isSSD = Test-IsSSD
            if ($isSSD) {
                Write-Log "Đã phát hiện: SSD"
            } else {
                Write-Log "Đã phát hiện: HDD"
            }
        }
        catch {
            Write-Log "Cảnh báo: Không thể lấy đầy đủ thông tin phần cứng: $($_.Exception.Message)"
        }

        # Tạo bản sao của các khuyến nghị cơ bản
        $recommendations = @{}
        foreach ($service in $script:SafeToDisableServices.Keys) {
            $recommendations[$service] = @{
                Description = $script:SafeToDisableServices[$service].Description
                Recommendation = $script:SafeToDisableServices[$service].DefaultRecommendation
                Level = $script:SafeToDisableServices[$service].Level
            }
        }

        # Điều chỉnh đề xuất dựa trên phần cứng
        if ($isSSD) {
            $recommendations["SysMain"].Recommendation = "Nên tắt (SSD đã nhanh)"
        } else {
            $recommendations["SysMain"].Recommendation = "Nên để nếu RAM < 8GB"
            $recommendations["SysMain"].Level = "Careful"
        }

        # Nếu RAM ít, tắt một số dịch vụ không cần thiết
        if ($totalRam -lt 8) {
            $recommendations["XblAuthManager"].Recommendation = "Nên tắt (tiết kiệm RAM)"
            $recommendations["XblGameSave"].Recommendation = "Nên tắt (tiết kiệm RAM)"
            $recommendations["XboxNetApiSvc"].Recommendation = "Nên tắt (tiết kiệm RAM)"
            
            # Thêm các dịch vụ khác nên tắt khi RAM ít
            if ($totalRam -lt 4) {
                $recommendations["WSearch"].Recommendation = "Nên tắt (tiết kiệm RAM quan trọng)"
                $recommendations["WSearch"].Level = "Safe"
            }
        }

        # Lấy danh sách dịch vụ hiện tại
        Write-Log "Đang lấy thông tin dịch vụ..."
        $servicesList = @()
        
        # Lấy thông tin dịch vụ và xử lý lỗi riêng lẻ
        foreach ($serviceName in ($recommendations.Keys + $script:CarefulServices.Keys | Sort-Object -Unique)) {
            $serviceInfo = Get-ServiceInfo -ServiceName $serviceName
            if ($serviceInfo) {
                $servicesList += $serviceInfo
            }
        }

        # Kết hợp thông tin dịch vụ với đề xuất
        Write-Log "Đang tạo khuyến nghị cho các dịch vụ..."
        $results = @()
        foreach ($svc in $servicesList) {
            if ($svc -ne $null -and $svc.Name -ne $null) { 
                $info = [PSCustomObject]@{
                    Name = $svc.Name
                    DisplayName = $svc.DisplayName
                    Status = $svc.Status
                    StartType = $svc.StartType
                    Description = ""
                    Recommendation = ""
                    Level = ""
                }
                if ($recommendations.ContainsKey($svc.Name)) {
                    $info.Description = $recommendations[$svc.Name].Description
                    $info.Recommendation = $recommendations[$svc.Name].Recommendation
                    $info.Level = $recommendations[$svc.Name].Level
                } 
                elseif ($script:CarefulServices.ContainsKey($svc.Name)) {
                    $info.Description = $script:CarefulServices[$svc.Name].Description
                    $info.Recommendation = $script:CarefulServices[$svc.Name].Recommendation
                    $info.Level = $script:CarefulServices[$svc.Name].Level
                }
                
                $results += $info
            } else {
                Write-Log "Cảnh báo: Bỏ qua một dịch vụ không hợp lệ hoặc không có tên trong quá trình tạo khuyến nghị."
           }
        }
        
        Write-Log "Phân tích dịch vụ hoàn tất: Đã tìm thấy $($results.Count) dịch vụ có thể điều chỉnh"
        return $results
    }
    catch {
        Write-Log "❌ Lỗi khi phân tích dịch vụ: $($_.Exception.Message)"
        return @()
    }
    finally {
        # Đóng và giải phóng CimSession
        if ($cimSession) {
            $cimSession.Close()
            $cimSession.Dispose()
        }
        
        # Giải phóng tài nguyên CIM/WMI
        $cimVariables = @('ramInfo', 'diskInfo', 'diskDrive', 'physicalDisks', 'diskPerf')
        foreach ($var in $cimVariables) {
            if (Get-Variable -Name $var -ErrorAction SilentlyContinue) {
                Remove-Variable -Name $var -ErrorAction SilentlyContinue
            }
        }
    
        # Gọi hàm dọn dẹp của .NET Garbage Collector
        [System.GC]::Collect()
    }
}

# Hàm quản lý startup items
function Get-StartupItems {
    $startupLocations = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"
    )
    
    $startupFolders = @(
        "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup",
        "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp"
    )
    
    $startupItems = @()
    
    # Lấy từ Registry
    foreach ($location in $startupLocations) {
        if (Test-Path $location) {
            $keys = Get-ItemProperty -Path $location
            foreach ($key in $keys.PSObject.Properties) {
                if ($key.Name -notin @('PSPath', 'PSParentPath', 'PSChildName', 'PSDrive', 'PSProvider')) {
                    $item = New-Object PSObject
                    $item | Add-Member -MemberType NoteProperty -Name "Name" -Value $key.Name
                    $item | Add-Member -MemberType NoteProperty -Name "Command" -Value $key.Value
                    $item | Add-Member -MemberType NoteProperty -Name "Location" -Value $location
                    $item | Add-Member -MemberType NoteProperty -Name "Type" -Value "Registry"
                    $startupItems += $item
                }
            }
        }
    }
    
    # Lấy từ thư mục Startup
    foreach ($folder in $startupFolders) {
        if (Test-Path $folder) {
            $files = Get-ChildItem -Path $folder -File
            foreach ($file in $files) {
                $item = New-Object PSObject
                $item | Add-Member -MemberType NoteProperty -Name "Name" -Value $file.BaseName
                $item | Add-Member -MemberType NoteProperty -Name "Command" -Value $file.FullName
                $item | Add-Member -MemberType NoteProperty -Name "Location" -Value $folder
                $item | Add-Member -MemberType NoteProperty -Name "Type" -Value "Folder"
                $startupItems += $item
            }
        }
    }
    
    return $startupItems
}

# Hàm sửa lỗi hệ thống
function Start-SystemRepair {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("SFC", "DISM_CheckHealth", "DISM_ScanHealth", "DISM_RestoreHealth", 
                    "CheckDisk", "ResetNetworkStack", "FixWindowsUpdates", "RepairSystemFiles")]
        [string]$RepairType,
        [System.Windows.Forms.ProgressBar]$ProgressBar = $null,
        [System.Windows.Forms.Label]$StatusLabel = $null
    )
    
    function Update-Status {
        param([string]$Message, [int]$Progress = -1)
        
        Write-Log $Message
        
        if ($StatusLabel -ne $null) {
            $StatusLabel.Invoke([Action]{
                $StatusLabel.Text = $Message
            })
        }
        
        if ($ProgressBar -ne $null -and $Progress -ge 0) {
            $ProgressBar.Invoke([Action]{
                $ProgressBar.Value = $Progress
            })
        }
    }
    
    switch ($RepairType) {
        "SFC" {
            Update-Status "Đang bắt đầu quá trình kiểm tra và sửa file hệ thống..." 5
            $sfcProcess = Start-Process -FilePath "sfc.exe" -ArgumentList "/scannow" -NoNewWindow -PassThru -Wait
            
            if ($sfcProcess.ExitCode -eq 0) {
                Update-Status "✅ Quá trình kiểm tra và sửa file hệ thống đã hoàn tất." 100
                return $true
            } else {
                Update-Status "❌ Quá trình kiểm tra gặp lỗi. Mã lỗi: $($sfcProcess.ExitCode)" 100
                return $false
            }
        }
        
        "DISM_CheckHealth" {
            Update-Status "Đang kiểm tra tính toàn vẹn của hình ảnh hệ thống..." 10
            $dismProcess = Start-Process -FilePath "DISM.exe" -ArgumentList "/Online /Cleanup-Image /CheckHealth" -NoNewWindow -PassThru -Wait
            
            if ($dismProcess.ExitCode -eq 0) {
                Update-Status "✅ Kiểm tra hình ảnh hệ thống hoàn tất." 100
                return $true
            } else {
                Update-Status "❌ Kiểm tra hình ảnh hệ thống gặp lỗi. Mã lỗi: $($dismProcess.ExitCode)" 100
                return $false
            }
        }
        
        "DISM_ScanHealth" {
            Update-Status "Đang quét hình ảnh hệ thống để tìm lỗi..." 10
            $dismProcess = Start-Process -FilePath "DISM.exe" -ArgumentList "/Online /Cleanup-Image /ScanHealth" -NoNewWindow -PassThru -Wait
            
            if ($dismProcess.ExitCode -eq 0) {
                Update-Status "✅ Quét hình ảnh hệ thống hoàn tất." 100
                return $true
            } else {
                Update-Status "❌ Quét hình ảnh hệ thống gặp lỗi. Mã lỗi: $($dismProcess.ExitCode)" 100
                return $false
            }
        }
        
        "DISM_RestoreHealth" {
            Update-Status "Đang khôi phục hình ảnh hệ thống (có thể mất vài phút)..." 10
            $dismProcess = Start-Process -FilePath "DISM.exe" -ArgumentList "/Online /Cleanup-Image /RestoreHealth" -NoNewWindow -PassThru -Wait
            
            if ($dismProcess.ExitCode -eq 0) {
                Update-Status "✅ Khôi phục hình ảnh hệ thống hoàn tất." 100
                return $true
            } else {
                Update-Status "❌ Khôi phục hình ảnh hệ thống gặp lỗi. Mã lỗi: $($dismProcess.ExitCode)" 100
                return $false
            }
        }
        
        "CheckDisk" {
            Update-Status "Chuẩn bị kiểm tra và sửa lỗi ổ đĩa..." 10
            
            # Hiển thị hộp thoại chọn ổ đĩa
            $drives = Get-WmiObject Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 } | Select-Object -ExpandProperty DeviceID
            $selectedDrive = $drives[0].Substring(0, 1) # Mặc định chọn ổ đĩa đầu tiên
            
            $driveForm = New-Object System.Windows.Forms.Form
            $driveForm.Text = "Chọn ổ đĩa cần kiểm tra"
            $driveForm.Size = New-Object System.Drawing.Size(300, 150)
            $driveForm.StartPosition = "CenterScreen"
            
            $driveLabel = New-Object System.Windows.Forms.Label
            $driveLabel.Location = New-Object System.Drawing.Point(10, 20)
            $driveLabel.Size = New-Object System.Drawing.Size(280, 20)
            $driveLabel.Text = "Chọn ổ đĩa cần kiểm tra:"
            $driveForm.Controls.Add($driveLabel)
            
            $driveCombo = New-Object System.Windows.Forms.ComboBox
            $driveCombo.Location = New-Object System.Drawing.Point(10, 40)
            $driveCombo.Size = New-Object System.Drawing.Size(100, 20)
            foreach ($drive in $drives) {
                [void]$driveCombo.Items.Add($drive.Substring(0, 1))
            }
            $driveCombo.SelectedIndex = 0
            $driveForm.Controls.Add($driveCombo)
            
            $okButton = New-Object System.Windows.Forms.Button
            $okButton.Location = New-Object System.Drawing.Point(120, 70)
            $okButton.Size = New-Object System.Drawing.Size(75, 23)
            $okButton.Text = "OK"
            $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
            $driveForm.AcceptButton = $okButton
            $driveForm.Controls.Add($okButton)
            
            $cancelButton = New-Object System.Windows.Forms.Button
            $cancelButton.Location = New-Object System.Drawing.Point(200, 70)
            $cancelButton.Size = New-Object System.Drawing.Size(75, 23)
            $cancelButton.Text = "Hủy"
            $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
            $driveForm.CancelButton = $cancelButton
            $driveForm.Controls.Add($cancelButton)
            
            $result = $driveForm.ShowDialog()
            
            if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
                $selectedDrive = $driveCombo.SelectedItem
                Update-Status "Đang kiểm tra ổ đĩa $selectedDrive..." 30
                
                $confirmSchedule = [System.Windows.Forms.MessageBox]::Show(
                    "CHKDSK cần chạy khi khởi động lại hệ thống. Bạn có muốn lên lịch kiểm tra khi khởi động lại không?",
                    "Xác nhận lên lịch CHKDSK",
                    [System.Windows.Forms.MessageBoxButtons]::YesNo,
                    [System.Windows.Forms.MessageBoxIcon]::Question
                )
                
                if ($confirmSchedule -eq [System.Windows.Forms.DialogResult]::Yes) {
                    $chkdskProcess = Start-Process -FilePath "chkdsk.exe" -ArgumentList "$($selectedDrive): /f /r /x" -NoNewWindow -PassThru -Wait
                    Update-Status "✅ Đã lên lịch kiểm tra ổ đĩa $selectedDrive khi khởi động lại." 100
                    [System.Windows.Forms.MessageBox]::Show(
                        "Đã lên lịch kiểm tra ổ đĩa $selectedDrive khi khởi động lại.`nVui lòng lưu công việc và khởi động lại máy tính.",
                        "CHKDSK đã được lên lịch",
                        [System.Windows.Forms.MessageBoxButtons]::OK,
                        [System.Windows.Forms.MessageBoxIcon]::Information
                    )
                    return $true
                } else {
                    Update-Status "❌ Đã hủy kiểm tra ổ đĩa." 100
                    return $false
                }
            } else {
                Update-Status "❌ Đã hủy kiểm tra ổ đĩa." 100
                return $false
            }
        }
        
        "ResetNetworkStack" {
            Update-Status "Đang đặt lại cấu trúc mạng..." 10
            
            try {
                Update-Status "Đang xóa cấu hình TCP/IP..." 30
                $netshReset = Start-Process -FilePath "netsh.exe" -ArgumentList "int ip reset" -NoNewWindow -PassThru -Wait -ErrorAction Stop
                
                Update-Status "Đang đặt lại cấu hình Winsock..." 60
                $netshWinsock = Start-Process -FilePath "netsh.exe" -ArgumentList "winsock reset" -NoNewWindow -PassThru -Wait -ErrorAction Stop
                
                Update-Status "Đang đặt lại cấu hình DNS..." 80
                ipconfig /flushdns | Out-Null
                
                Update-Status "✅ Đặt lại cấu trúc mạng hoàn tất. Vui lòng khởi động lại máy tính." 100
                [System.Windows.Forms.MessageBox]::Show(
                    "Đã đặt lại cấu trúc mạng thành công.`nVui lòng khởi động lại máy tính để hoàn tất quá trình.",
                    "Đặt lại mạng thành công",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                )
                return $true
            } catch {
                Update-Status "❌ Đặt lại cấu trúc mạng thất bại: $($_.Exception.Message)" 100
                return $false
            }
        }
        
        "FixWindowsUpdates" {
            Update-Status "Đang sửa lỗi Windows Update..." 10
            
            try {
                # Dừng các dịch vụ liên quan đến Windows Update
                Update-Status "Đang dừng các dịch vụ Windows Update..." 20
                Stop-Service -Name wuauserv, bits, cryptsvc -Force -ErrorAction Stop
                
                # Xóa thư mục SoftwareDistribution
                Update-Status "Đang xóa cache Windows Update..." 40
                if (Test-Path "$env:windir\SoftwareDistribution.bak") {
                    Remove-Item -Path "$env:windir\SoftwareDistribution.bak" -Force -Recurse -ErrorAction SilentlyContinue
                }
                
                if (Test-Path "$env:windir\SoftwareDistribution") {
                    Rename-Item -Path "$env:windir\SoftwareDistribution" -NewName "SoftwareDistribution.bak" -Force -ErrorAction Stop
                }
                
                # Đặt lại thư viện Winsock
                Update-Status "Đang đặt lại Winsock..." 60
                $netshWinsock = Start-Process -FilePath "netsh.exe" -ArgumentList "winsock reset" -NoNewWindow -PassThru -Wait -ErrorAction Stop
                
                # Đăng ký lại các DLL Windows Update
                Update-Status "Đang đăng ký lại các file DLL..." 80
                $dllFiles = @(
                    "atl.dll", "urlmon.dll", "mshtml.dll", "shdocvw.dll", "browseui.dll",
                    "jscript.dll", "vbscript.dll", "scrrun.dll", "msxml.dll", "msxml3.dll",
                    "msxml6.dll", "actxprxy.dll", "softpub.dll", "wintrust.dll", "dssenh.dll",
                    "rsaenh.dll", "gpkcsp.dll", "sccbase.dll", "slbcsp.dll", "cryptdlg.dll",
                    "oleaut32.dll", "ole32.dll", "shell32.dll", "wuapi.dll", "wuaueng.dll",
                    "wuaueng1.dll", "wucltui.dll", "wups.dll", "wups2.dll", "wuweb.dll",
                    "qmgr.dll", "qmgrprxy.dll"
                )
                
                foreach ($dll in $dllFiles) {
                    $dllPath = "$env:windir\System32\$dll"
                    if (Test-Path $dllPath) {
                        Start-Process -FilePath "regsvr32.exe" -ArgumentList "/s `"$dllPath`"" -NoNewWindow -Wait -ErrorAction SilentlyContinue
                    }
                }
                
                # Khởi động lại các dịch vụ
                Update-Status "Đang khởi động lại các dịch vụ..." 90
                Start-Service -Name cryptsvc, bits, wuauserv -ErrorAction Stop
                
                Update-Status "✅ Đã sửa lỗi Windows Update thành công." 100
                return $true
            } catch {
                Update-Status "❌ Sửa lỗi Windows Update thất bại: $($_.Exception.Message)" 100
                return $false
            }
        }
        
        "RepairSystemFiles" {
            # Quy trình sửa chữa tự động kết hợp nhiều công cụ
            Update-Status "Bắt đầu quy trình sửa chữa hệ thống tự động..." 5
            
            # Bước 1: Kiểm tra hình ảnh bằng DISM CheckHealth
            Update-Status "Bước 1/4: Kiểm tra tính toàn vẹn của hình ảnh..." 10
            $dismCheck = Start-Process -FilePath "DISM.exe" -ArgumentList "/Online /Cleanup-Image /CheckHealth" -NoNewWindow -PassThru -Wait
            
            # Bước 2: Quét hình ảnh bằng DISM ScanHealth
            Update-Status "Bước 2/4: Quét hình ảnh hệ thống để tìm lỗi..." 25
            $dismScan = Start-Process -FilePath "DISM.exe" -ArgumentList "/Online /Cleanup-Image /ScanHealth" -NoNewWindow -PassThru -Wait
            
            # Bước 3: Khôi phục hình ảnh bằng DISM RestoreHealth
            Update-Status "Bước 3/4: Khôi phục hình ảnh hệ thống (có thể mất 10-20 phút)..." 40
            $dismRestore = Start-Process -FilePath "DISM.exe" -ArgumentList "/Online /Cleanup-Image /RestoreHealth" -NoNewWindow -PassThru -Wait
            
            if ($dismRestore.ExitCode -ne 0) {
                Update-Status "⚠️ Khôi phục hình ảnh hệ thống không hoàn tất, nhưng sẽ tiếp tục quy trình..." 70
            } else {
                Update-Status "✅ Khôi phục hình ảnh hệ thống thành công." 70
            }
            
            # Bước 4: Kiểm tra và sửa file hệ thống bằng SFC
            Update-Status "Bước 4/4: Kiểm tra và sửa file hệ thống..." 75
            $sfcProcess = Start-Process -FilePath "sfc.exe" -ArgumentList "/scannow" -NoNewWindow -PassThru -Wait
            
            if ($sfcProcess.ExitCode -eq 0) {
                Update-Status "✅ Quy trình sửa chữa hệ thống hoàn tất thành công." 100
                return $true
            } else {
                Update-Status "⚠️ Quy trình sửa chữa đã hoàn tất nhưng có thể không hoàn hảo." 100
                return $false
            }
        }
        
        default {
            Update-Status "❌ Không tìm thấy loại sửa chữa được chỉ định." 100
            return $false
        }
    }
}



# -- 4. Xây dựng giao diện --
# 4.1 Form chính 
$form = New-Object System.Windows.Forms.Form
$form.Text = "Công cụ dọn dẹp hàng Nỏ :))"
$form.Size = New-Object System.Drawing.Size(805, 765)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::FromArgb(240, 240, 240)
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
$form.MaximizeBox = $false
try {
    $form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon("$env:windir\system32\cleanmgr.exe")
} catch {
    Write-Warning "Không thể tải icon từ cleanmgr.exe. Sử dụng icon mặc định."
}

# 4.2 Header
$headerPanel = New-Object System.Windows.Forms.Panel
$headerPanel.Location = New-Object System.Drawing.Point(0, 0)
$headerPanel.Size = New-Object System.Drawing.Size(800, 60)
$headerPanel.BackColor = [System.Drawing.Color]::FromArgb(0, 99, 177)

$headerLabel = New-Object System.Windows.Forms.Label
$headerLabel.Location = New-Object System.Drawing.Point(20, 15)
$headerLabel.Size = New-Object System.Drawing.Size(700, 30)
$headerLabel.Text = "Công cụ dọn dẹp hàng Nỏ :))"
$headerLabel.ForeColor = [System.Drawing.Color]::White
$headerLabel.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$headerPanel.Controls.Add($headerLabel)

# 4.3 TabControl

$tabControl = New-Object System.Windows.Forms.TabControl
$tabControl.Location = New-Object System.Drawing.Point(10, 70)
$tabControl.Size = New-Object System.Drawing.Size(770, 400)
$tabControl.Font = New-Object System.Drawing.Font("Segoe UI", 10)

$tabBasic = New-Object System.Windows.Forms.TabPage
$tabBasic.Text = "Dọn dẹp cơ bản"

$tabAdvanced = New-Object System.Windows.Forms.TabPage
$tabAdvanced.Text = "Dọn dẹp nâng cao"

$tabOptimize = New-Object System.Windows.Forms.TabPage
$tabOptimize.Text = "Tối ưu hóa"

$tabSecurity = New-Object System.Windows.Forms.TabPage
$tabSecurity.Text = "Bảo mật"

$tabPrivacy = New-Object System.Windows.Forms.TabPage
$tabPrivacy.Text = "Quyền riêng tư"

$tabServices = New-Object System.Windows.Forms.TabPage
$tabServices.Text = "Dịch vụ & Startup"

$tabSystemRepair = New-Object System.Windows.Forms.TabPage
$tabSystemRepair.Text = "Sửa lỗi hệ thống"

$tabUtilities = New-Object System.Windows.Forms.TabPage
$tabUtilities.Text = "Tiện ích"

$tabControl.Controls.AddRange(@($tabBasic, $tabAdvanced, $tabOptimize, $tabSecurity, $tabPrivacy, $tabUtilities, $tabServices, $tabSystemRepair))

# 1. Sửa hoàn toàn phần hiển thị ListView dịch vụ
# Thêm hàm mới này vào script của bạn
function Update-ServicesListView {
    param(
        [System.Windows.Forms.ListView]$ListView
    )

    if ($ListView -eq $null) {
        Write-Log "Lỗi: ListView không được khởi tạo"
        return
    }

    # Xóa dữ liệu cũ
    $ListView.Items.Clear()
    
    Write-Log "Đang phân tích thông tin dịch vụ..."
    
    try {
        # Lấy danh sách dịch vụ
        $services = Get-ServiceRecommendations
        
        if ($services -eq $null -or $services.Count -eq 0) {
            Write-Log "Không tìm thấy thông tin dịch vụ nào để hiển thị."
            return
        }
        
        # Thêm từng dịch vụ vào ListView với kiểm tra lỗi
        foreach ($service in $services) {
            try {
                # Kiểm tra service có hợp lệ không
                if ($service -eq $null) { continue }
                
                # Tạo item mới với giá trị đầu tiên
                $name = if ([string]::IsNullOrEmpty($service.Name)) { "Unknown" } else { $service.Name }
                $listItem = New-Object System.Windows.Forms.ListViewItem($name)
                
                # Tạo và thêm các subitem với kiểm tra giá trị
                $displayNameSubItem = New-Object System.Windows.Forms.ListViewItem.ListViewSubItem
                $displayNameSubItem.Text = if ([string]::IsNullOrEmpty($service.DisplayName)) { "N/A" } else { $service.DisplayName }
                [void]$listItem.SubItems.Add($displayNameSubItem)
                
                $statusSubItem = New-Object System.Windows.Forms.ListViewItem.ListViewSubItem
                $statusSubItem.Text = if ($service.Status -eq $null) { "Unknown" } else { $service.Status.ToString() }
                [void]$listItem.SubItems.Add($statusSubItem)
                
                $startTypeSubItem = New-Object System.Windows.Forms.ListViewItem.ListViewSubItem
                $startTypeSubItem.Text = if ($service.StartType -eq $null) { "Unknown" } else { $service.StartType.ToString() }
                [void]$listItem.SubItems.Add($startTypeSubItem)
                
                $descriptionSubItem = New-Object System.Windows.Forms.ListViewItem.ListViewSubItem
                $descriptionSubItem.Text = if ([string]::IsNullOrEmpty($service.Description)) { "" } else { $service.Description }
                [void]$listItem.SubItems.Add($descriptionSubItem)
                
                $recommendationSubItem = New-Object System.Windows.Forms.ListViewItem.ListViewSubItem
                $recommendationSubItem.Text = if ([string]::IsNullOrEmpty($service.Recommendation)) { "" } else { $service.Recommendation }
                [void]$listItem.SubItems.Add($recommendationSubItem)
                
                # Thêm item vào ListView
                [void]$ListView.Items.Add($listItem)
            }
            catch {
                Write-Log "Lỗi khi xử lý dịch vụ: $($_.Exception.Message)"
            }
        }
        
        Write-Log "Đã hoàn tất phân tích dịch vụ."
    }
    catch {
        Write-Log "Lỗi phân tích dịch vụ: $($_.Exception.Message)"
    }
}

# 2. Triển khai tính năng thay đổi kích thước TabControl
# Biến toàn cục cho tính năng điều chỉnh kích thước TabControl
$script:defaultTabControlSize = New-Object System.Drawing.Size(770, 390)
$script:expandedTabControlSize = New-Object System.Drawing.Size(770, 535)
$script:isTabExpanded = $false
$script:controlsToHide = @()

# Hàm khởi tạo tính năng thay đổi kích thước
function Initialize-DynamicTabControl {
    param(
        [System.Windows.Forms.TabControl]$TabControl,
        [System.Windows.Forms.Form]$ParentForm,
        [int[]]$ExpandedTabIndexes
    )
    
    if ($TabControl -eq $null -or $ParentForm -eq $null) {
        Write-Log "Lỗi: TabControl hoặc Form không hợp lệ để khởi tạo thay đổi kích thước"
        return
    }
    
    # Lưu thông tin các control cần ẩn/hiện
    foreach ($control in $ParentForm.Controls) {
        if ($control -ne $TabControl -and $control.Location.Y -gt $TabControl.Location.Y + $script:defaultTabControlSize.Height) {
            $script:controlsToHide += @{
                Control = $control
                OriginalLocation = $control.Location
                OriginalVisible = $control.Visible
            }
        }
    }
    
    # Thêm sự kiện xử lý thay đổi tab
    $TabControl.add_SelectedIndexChanged({
        Write-Log "Tab được chọn: $($TabControl.SelectedIndex)" # Log để debug
        
        if ($ExpandedTabIndexes -contains $TabControl.SelectedIndex) {
            # Mở rộng khi chọn tab đặc biệt
            Write-Log "Mở rộng TabControl cho tab $($TabControl.SelectedIndex)"
            if (-not $script:isTabExpanded) {
                $script:isTabExpanded = $true
                
                # Ẩn các control phía dưới
                foreach ($controlInfo in $script:controlsToHide) {
                    $controlInfo.Control.Visible = $false
                }
                
                # Mở rộng TabControl
                $TabControl.Size = $script:expandedTabControlSize
                $TabControl.Refresh()
            }
        } 
        else {
            # Thu nhỏ khi chọn các tab khác
            if ($script:isTabExpanded) {
                Write-Log "Thu nhỏ TabControl cho tab $($TabControl.SelectedIndex)"
                $script:isTabExpanded = $false
                
                # Thu nhỏ TabControl
                $TabControl.Size = $script:defaultTabControlSize
                $TabControl.Refresh()
                
                # Hiện lại các control phía dưới
                foreach ($controlInfo in $script:controlsToHide) {
                    $controlInfo.Control.Visible = $controlInfo.OriginalVisible
                }
            }
        }
    })
    
    Write-Log "Đã khởi tạo tính năng thay đổi kích thước TabControl"
}

# Thay thế toàn bộ tính năng bằng cách tiếp cận đơn giản hơn
function Setup-TabSizeChange {
    # Lưu kích thước và vị trí ban đầu
    $script:normalTabSize = $tabControl.Size
    $script:normalTabBottom = $tabControl.Bottom
    
    # Xác định các control nằm dưới TabControl
    $script:controlsBelowTab = @()
    foreach ($ctrl in $form.Controls) {
        if ($ctrl -ne $tabControl -and $ctrl.Top -gt $script:normalTabBottom) {
            $script:controlsBelowTab += @{
                Control = $ctrl
                OriginalTop = $ctrl.Top
                OriginalVisible = $ctrl.Visible
            }
        }
    }
    
    # Thêm sự kiện
    $tabControl.add_SelectedIndexChanged({
        # Xác định tab nào cần mở rộng (tab 6 và 7)
        $expandTabs = @(6, 7)
        
        if ($expandTabs -contains $tabControl.SelectedIndex) {
            # Mở rộng TabControl
            $tabControl.Height = 535 # Kích thước mở rộng
            
            # Ẩn các control bên dưới
            foreach ($ctrlInfo in $script:controlsBelowTab) {
                $ctrlInfo.Control.Visible = $false
            }
        } else {
            # Trả về kích thước thông thường
            $tabControl.Size = $script:normalTabSize
            
            # Hiện lại các control
            foreach ($ctrlInfo in $script:controlsBelowTab) {
                $ctrlInfo.Control.Visible = $ctrlInfo.OriginalVisible
            }
        }
        
        # Đảm bảo form được vẽ lại
        $form.Refresh()
    })
}

# Gọi hàm này sau khi khởi tạo form và các control
Setup-TabSizeChange
# 4.4 ToolTip
$tooltip = New-Object System.Windows.Forms.ToolTip
$tooltip.AutoPopDelay = 5000
$tooltip.InitialDelay = 1000
$tooltip.ReshowDelay = 500
$tooltip.ShowAlways = $true

# 4.5 Định nghĩa danh sách các chức năng cho từng tab
# Tab Dọn dẹp cơ bản
$checkboxItems = @(
    @{ Text = "Dọn dẹp thư mục Temp"; Description = "Xóa các file tạm trong thư mục Temp của Windows"; Tag = "TempFiles"; Y = 20 },
    @{ Text = "Dọn Thùng rác"; Description = "Xóa tất cả tệp tin trong Thùng rác"; Tag = "RecycleBin"; Y = 50 },
    @{ Text = "Xóa tệp tin tạm thời của trình duyệt"; Description = "Dọn dẹp cache của Edge, Chrome, Firefox"; Tag = "BrowserCache"; Y = 80 },
    @{ Text = "Dọn dẹp Windows Update Cache"; Description = "Xóa các bản cập nhật đã tải xuống và cài đặt"; Tag = "WinUpdateCache"; Y = 110 },
    @{ Text = "Xóa file Prefetch"; Description = "Dọn dẹp bộ nhớ đệm khởi động ứng dụng"; Tag = "Prefetch"; Y = 140 },
    @{ Text = "Xóa bản tải xuống cũ"; Description = "Xóa các file tải xuống cũ hơn 3 ngày"; Tag = "OldDownloads"; Y = 170 },
    @{ Text = "Dọn dẹp tệp tin Event Logs"; Description = "Xóa tệp nhật ký sự kiện của hệ thống"; Tag = "EventLogs"; Y = 200 },
    @{ Text = "Dọn dẹp thumbnail cache"; Description = "Xóa bộ nhớ đệm hình thu nhỏ của Windows Explorer"; Tag = "ThumbnailCache"; Y = 230 }
)

# Tab Dọn dẹp nâng cao
$advancedItems = @(
    @{ Text = "Dọn dẹp WinSxS Folder"; Description = "Dọn thư mục chứa thành phần hệ thống"; Tag = "WinSxS"; Y = 20 },
    @{ Text = "Tối ưu hóa SoftwareDistribution"; Description = "Dọn và nén thư mục lưu trữ cập nhật Windows"; Tag = "SoftwareDist"; Y = 50 },
    @{ Text = "Dọn dẹp Component Store"; Description = "Dọn kho lưu trữ thành phần hệ thống"; Tag = "ComponentStore"; Y = 80 },
    @{ Text = "Dọn dẹp Microsoft Store Cache"; Description = "Sửa lỗi và làm sạch Microsoft Store"; Tag = "StoreCache"; Y = 110 },
    @{ Text = "Dọn OneDrive Cache"; Description = "Xóa cache OneDrive mà không ảnh hưởng đến dữ liệu"; Tag = "OneDriveCache"; Y = 140 },
    @{ Text = "Dọn File Hibernation"; Description = "Xóa file ngủ đông (hibernation)"; Tag = "Hibernation"; Y = 170 },
    @{ Text = "Dọn bộ nhớ đệm Font"; Description = "Làm sạch bộ nhớ đệm font Windows"; Tag = "FontCache"; Y = 200 },
    @{ Text = "Nén hệ thống tệp NTFS"; Description = "Nén các tệp hệ thống để tiết kiệm không gian"; Tag = "CompressNTFS"; Y = 230 }
)

# Tab tối ưu hóa
$optimizeItems = @(
    @{ Text = "Tối ưu hóa khởi động"; Description = "Vô hiệu hóa chương trình khởi động không cần thiết"; Tag = "StartupOptimize"; Y = 20 },
    @{ Text = "Tối ưu hóa dịch vụ hệ thống"; Description = "Điều chỉnh dịch vụ để tăng hiệu suất"; Tag = "ServiceOptimize"; Y = 50 },
    @{ Text = "Tối ưu hóa Page File"; Description = "Điều chỉnh bộ nhớ ảo cho hiệu suất tốt nhất"; Tag = "PageFileOptimize"; Y = 80 },
    @{ Text = "Tối ưu hóa hiệu suất trực quan"; Description = "Điều chỉnh hiệu ứng để tăng tốc độ hệ thống"; Tag = "VisualPerformance"; Y = 110 },
    @{ Text = "Tối ưu hóa độ trễ mạng"; Description = "Cải thiện kết nối mạng và giảm độ trễ"; Tag = "NetworkLatency"; Y = 140 },
    @{ Text = "Tối ưu hóa Windows Search"; Description = "Cải thiện hiệu suất tìm kiếm Windows"; Tag = "SearchOptimize"; Y = 170 },
    @{ Text = "Tối ưu hóa sử dụng RAM"; Description = "Giải phóng bộ nhớ RAM không sử dụng"; Tag = "RAMOptimize"; Y = 200 },
    @{ Text = "Tối ưu hóa thời gian tắt máy"; Description = "Giảm thời gian chờ khi tắt máy"; Tag = "ShutdownOptimize"; Y = 230 }
)

# Tab Bảo mật
$securityItems = @(
    @{ Text = "Quét và xóa phần mềm độc hại cơ bản"; Description = "Quét nhanh hệ thống bằng Windows Defender"; Tag = "BasicMalware"; Y = 20 },
    @{ Text = "Xóa lịch sử duyệt web"; Description = "Xóa lịch sử duyệt và cache cơ bản (không xóa cookie)"; Tag = "BrowserHistory"; Y = 50 },
    @{ Text = "Kiểm tra và cập nhật Windows"; Description = "Kiểm tra các bản cập nhật Windows quan trọng"; Tag = "WindowsUpdate"; Y = 80 },
    @{ Text = "Làm sạch lịch sử Recent Files"; Description = "Xóa danh sách tệp đã mở gần đây và Jump Lists"; Tag = "RecentFiles"; Y = 110 },
    @{ Text = "Xóa dữ liệu chẩn đoán"; Description = "Xóa dữ liệu chẩn đoán được thu thập bởi Windows"; Tag = "DiagData"; Y = 140 },
    @{ Text = "Tắt tính năng theo dõi vị trí"; Description = "Vô hiệu hóa dịch vụ vị trí Windows"; Tag = "LocationTracking"; Y = 170 },
    @{ Text = "Kiểm tra & Bật Tường lửa"; Description = "Đảm bảo Tường lửa Windows Defender đang bật"; Tag = "EnsureFirewallEnabled"; Y = 200 },
    @{ Text = "Kiểm tra Bảo vệ Thời gian thực"; Description = "Kiểm tra Windows Defender Real-time Protection"; Tag = "CheckRealTimeProtection"; Y = 230 },
    @{ Text = "Bật Bảo vệ chống PUA/PUP"; Description = "Bật tính năng chặn ứng dụng không mong muốn"; Tag = "EnablePUAProtection"; Y = 260 },
    @{ Text = "Chạy Quét Toàn bộ hệ thống"; Description = "Quét virus toàn bộ máy (Rất chậm)"; Tag = "RunFullScan"; Y = 290 }
)

# Tab Quyền riêng tư
$privacyItems = @(
    @{ Text = "Tắt Micro (Chống nghe lén)"; Description = "Vô hiệu hóa tất cả thiết bị Micro trong Device Manager"; Tag = "DisableMicrophone"; Y = 20 },
    @{ Text = "Tắt Camera (Chống quay lén)"; Description = "Vô hiệu hóa tất cả thiết bị Camera trong Device Manager"; Tag = "DisableCamera"; Y = 50 },
    @{ Text = "Vô hiệu hóa ID Quảng cáo"; Description = "Ngăn ứng dụng sử dụng ID để theo dõi quảng cáo"; Tag = "DisableAdvertisingID"; Y = 80 },
    @{ Text = "Vô hiệu hóa Telemetry"; Description = "Tắt các dịch vụ thu thập dữ liệu chẩn đoán chính"; Tag = "DisableTelemetryServices"; Y = 110 },
    @{ Text = "Xóa Lịch sử Hoạt động"; Description = "Xóa dữ liệu Activity History được lưu trữ (nếu có)"; Tag = "ClearActivityHistory"; Y = 140 },
    @{ Text = "Tắt Cloud Clipboard"; Description = "Ngăn đồng bộ hóa lịch sử clipboard qua cloud"; Tag = "DisableCloudClipboard"; Y = 170 },
    @{ Text = "Tắt Theo dõi Vị trí"; Description = "Vô hiệu hóa dịch vụ vị trí Windows"; Tag = "DisableLocationTracking"; Y = 200 }
)

# Tab Tiện ích
$utilities = @(
    @{ Text = "Phân tích không gian đĩa"; Description = "Xem chi tiết về phân bổ dung lượng đĩa"; Tag = "DiskAnalysis"; Y = 20 },
    @{ Text = "Sao lưu Registry"; Description = "Tạo bản sao lưu Registry trước khi thay đổi"; Tag = "BackupRegistry"; Y = 50 },
    @{ Text = "Quản lý khởi động"; Description = "Quản lý các chương trình khởi động"; Tag = "StartupManager"; Y = 80 },
    @{ Text = "Xem thông tin hệ thống"; Description = "Hiển thị thông tin chi tiết về hệ thống"; Tag = "SystemInfo"; Y = 110 },
    @{ Text = "Kiểm tra sức khỏe ổ đĩa"; Description = "Kiểm tra và sửa lỗi ổ đĩa"; Tag = "DiskHealth"; Y = 140 },
    @{ Text = "Dọn dẹp tự động định kỳ"; Description = "Thiết lập lịch dọn dẹp tự động"; Tag = "ScheduledCleanup"; Y = 170 },
    @{ Text = "Sửa lỗi Windows phổ biến"; Description = "Sửa các lỗi Windows thường gặp"; Tag = "FixCommonIssues"; Y = 200 },
    @{ Text = "Quản lý phân vùng ổ đĩa"; Description = "Quản lý các phân vùng ổ đĩa"; Tag = "DiskPartition"; Y = 230 },
    @{ Text = "Xóa Cache DNS"; Description = "Xóa bộ nhớ đệm phân giải tên miền"; Tag = "FlushDnsCache"; Y = 260 },
    @{ Text = "Đặt lại cài đặt mạng"; Description = "Reset TCP/IP và Winsock (Yêu cầu khởi động lại)"; Tag = "ResetNetworkStack"; Y = 290 },
    @{ Text = "Khởi động lại Card mạng"; Description = "Tắt và bật lại card mạng đang hoạt động"; Tag = "RestartActiveAdapter"; Y = 320 }
)

# 4.6 Tạo các checkbox, label, nút tương ứng cho từng tab
# Các Dictionary để lưu trữ các checkbox
$checkboxes = @{}
$advancedCheckboxes = @{}
$optimizeCheckboxes = @{}
$securityCheckboxes = @{}
$privacyCheckboxes = @{} # Đã sửa từ $PrivacyCheckboxes thành $privacyCheckboxes

# Hàm tạo checkbox và label mô tả
function Add-CheckboxesWithDescriptions {
    param($tab, $items, [ref]$checkboxDict)
    
    foreach ($item in $items) {
        $checkbox = New-Object System.Windows.Forms.CheckBox
        $checkbox.Text = $item.Text
        $checkbox.Tag = $item.Tag
        $checkbox.Location = New-Object System.Drawing.Point(30, $item.Y)
        $checkbox.Size = New-Object System.Drawing.Size(300, 24)
        $checkbox.Font = New-Object System.Drawing.Font("Segoe UI", 9)
        $checkboxDict.Value[$item.Tag] = $checkbox
        $tab.Controls.Add($checkbox)
        $tooltip.SetToolTip($checkbox, $item.Description)

        $description = New-Object System.Windows.Forms.Label
        $description.Text = $item.Description
        $description.Location = New-Object System.Drawing.Point(340, [int]($item.Y + 3))
        $description.Size = New-Object System.Drawing.Size(400, 20)
        $description.ForeColor = [System.Drawing.Color]::Gray
        $description.Font = New-Object System.Drawing.Font("Segoe UI", 8)
        $tab.Controls.Add($description)
    }
}

# Hàm tạo nút "Chọn tất cả" và "Bỏ chọn tất cả"
function Add-SelectButtons {
    param($tab, $dict, $y)
    
    $selectAllButton = New-Object System.Windows.Forms.Button
    $selectAllButton.Text = "Chọn tất cả"
    $selectAllButton.Size = New-Object System.Drawing.Size(100, 30)
    $selectAllButton.Location = New-Object System.Drawing.Point(30, $y)
    $selectAllButton.Add_Click({ Set-CheckboxesState $dict $true })
    $tab.Controls.Add($selectAllButton)

    $deselectAllButton = New-Object System.Windows.Forms.Button
    $deselectAllButton.Text = "Bỏ chọn tất cả"
    $deselectAllButton.Size = New-Object System.Drawing.Size(100, 30)
    $deselectAllButton.Location = New-Object System.Drawing.Point(140, $y)
    $deselectAllButton.Add_Click({ Set-CheckboxesState $dict $false })
    $tab.Controls.Add($deselectAllButton)
}

# Tạo checkbox và nút cho Tab Dọn dẹp cơ bản
Add-CheckboxesWithDescriptions $tabBasic $checkboxItems ([ref]$checkboxes)
Add-SelectButtons $tabBasic $checkboxes 270

# Tạo checkbox và nút cho Tab Dọn dẹp nâng cao
Add-CheckboxesWithDescriptions $tabAdvanced $advancedItems ([ref]$advancedCheckboxes)
Add-SelectButtons $tabAdvanced $advancedCheckboxes 270

# Tạo checkbox và nút cho Tab Tối ưu hóa
Add-CheckboxesWithDescriptions $tabOptimize $optimizeItems ([ref]$optimizeCheckboxes)
Add-SelectButtons $tabOptimize $optimizeCheckboxes 270

# Tạo checkbox và nút cho Tab Bảo mật
Add-CheckboxesWithDescriptions $tabSecurity $securityItems ([ref]$securityCheckboxes)
Add-SelectButtons $tabSecurity $securityCheckboxes 330

# Tạo checkbox và nút cho Tab Quyền riêng tư
Add-CheckboxesWithDescriptions $tabPrivacy $privacyItems ([ref]$privacyCheckboxes) 
Add-SelectButtons $tabPrivacy $privacyCheckboxes 300

# Thêm nút mở cài đặt Quyền riêng tư
$privacySettingsButton = Create-RoundedButton "Mở Cài đặt Quyền riêng tư Windows" 30 240 300 30
$privacySettingsButton.BackColor = [System.Drawing.Color]::FromArgb(100, 100, 100)
$privacySettingsButton.Add_Click({ Start-Process "ms-settings:privacy" })
$tabPrivacy.Controls.Add($privacySettingsButton)

# Tạo các nút tiện ích cho Tab Tiện ích
foreach ($item in $utilities) {
    $button = Create-RoundedButton $item.Text 30 $item.Y 280 25
    $button.Tag = $item.Tag
    $button.BackColor = [System.Drawing.Color]::FromArgb(0, 150, 136)
    $tabUtilities.Controls.Add($button)
    $tooltip.SetToolTip($button, $item.Description)

    $description = New-Object System.Windows.Forms.Label
    $description.Text = $item.Description
    $description.Location = New-Object System.Drawing.Point(340, [int]($item.Y + 5))
    $description.Size = New-Object System.Drawing.Size(400, 20)
    $description.ForeColor = [System.Drawing.Color]::Gray
    $description.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    $tabUtilities.Controls.Add($description)
    
    # Thêm chức năng cho các nút tiện ích
    switch ($item.Tag) {
        "DiskAnalysis" { 
            $button.Add_Click({ Start-Process "cleanmgr.exe" })
        }
        "BackupRegistry" { 
            $button.Add_Click({
                $file = "$env:USERPROFILE\Desktop\RegistryBackup_$(Get-Date -Format 'yyyyMMdd_HHmmss').reg"
                reg export HKLM $file /y
                Write-Log "Đã sao lưu Registry ra $file"
            })
        }
        "StartupManager" { 
            $button.Add_Click({ Start-Process "taskmgr.exe" -ArgumentList "/startup" })
        }
        "SystemInfo" { 
            $button.Add_Click({ Start-Process "msinfo32.exe" })
        }
        "DiskHealth" { 
            $button.Add_Click({
                $drive = Read-Host "Nhập ký tự ổ đĩa muốn kiểm tra (vd: C)"
                Write-Log "Đang kiểm tra ổ đĩa $drive"
                Start-Process "chkdsk.exe" -ArgumentList "$($drive):" -Verb RunAs
            })
        }
        "DiskPartition" { 
            $button.Add_Click({ Start-Process "diskmgmt.msc" })
        }
        "FlushDnsCache" { 
            $button.Add_Click({
                ipconfig /flushdns
                Write-Log "Đã xóa DNS Cache."
            })
        }
        "ResetNetworkStack" { 
            $button.Add_Click({
                Write-Log "Đang đặt lại TCP/IP và Winsock. Yêu cầu khởi động lại."
                netsh int ip reset
                netsh winsock reset
                Write-Log "Hoàn tất! Vui lòng khởi động lại máy tính."
            })
        }
        "RestartActiveAdapter" { 
            $button.Add_Click({
                $adapters = Get-NetAdapter | Where-Object Status -eq 'Up'
                foreach ($adapter in $adapters) {
                    Write-Log "Đang khởi động lại adapter $($adapter.Name)"
                    Restart-NetAdapter -Name $adapter.Name
                }
                Write-Log "Đã khởi động lại card mạng."
            })
        }
        "FixCommonIssues" {
            $button.Add_Click({
                Write-Log "Đang chạy tiện ích khắc phục sự cố Windows..."
                Start-Process "control.exe" -ArgumentList "/name Microsoft.Troubleshooting"
            })
        }
    }
}

# --- Tạo giao diện tab Dịch vụ ---
# ListView cho dịch vụ
$servicesListView = New-Object System.Windows.Forms.ListView
$servicesListView.Location = New-Object System.Drawing.Point(10, 50)
$servicesListView.Size = New-Object System.Drawing.Size(740, 180)
$servicesListView.View = [System.Windows.Forms.View]::Details
$servicesListView.FullRowSelect = $true
$servicesListView.GridLines = $true
$servicesListView.Columns.Add("Tên dịch vụ", 150) | Out-Null
$servicesListView.Columns.Add("Tên hiển thị", 150) | Out-Null
$servicesListView.Columns.Add("Trạng thái", 70) | Out-Null
$servicesListView.Columns.Add("Kiểu khởi động", 100) | Out-Null
$servicesListView.Columns.Add("Mô tả", 150) | Out-Null
$servicesListView.Columns.Add("Đề xuất", 120) | Out-Null
$tabServices.Controls.Add($servicesListView)

# Label cho dịch vụ
$servicesLabel = New-Object System.Windows.Forms.Label
$servicesLabel.Location = New-Object System.Drawing.Point(10, 20)
$servicesLabel.Size = New-Object System.Drawing.Size(540, 25)
$servicesLabel.Text = "Dịch vụ được đề xuất tắt dựa trên cấu hình máy tính của bạn:"
$servicesLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$tabServices.Controls.Add($servicesLabel)

# Nút Load dịch vụ
$loadServicesButton = Create-RoundedButton "Phân tích dịch vụ" 610 20 130 25
$loadServicesButton.Add_Click({
    try {
		Add-Type -AssemblyName System.Windows.Forms
        Write-Log "Button Click: Đang phân tích dịch vụ hệ thống..."
        $servicesListView.Items.Clear()
        
        # Bước 1: Thu thập TẤT CẢ output từ hàm vào một mảng một cách tường minh
        $rawReturnedItems = @(Get-ServiceRecommendations) 

        $servicesToDisplay = @() # Khởi tạo mảng rỗng để chứa các dịch vụ hợp lệ

        Write-Log "DEBUG: \$rawReturnedItems - Là Mảng (IsArray): $($rawReturnedItems -is [System.Array]), Số lượng (Count): $($rawReturnedItems.Count)"

        if ($rawReturnedItems.Count -eq 0) {
            Write-Log "DEBUG: Get-ServiceRecommendations không trả về hoặc không output bất cứ thứ gì (mảng rỗng sau khi thu thập)."
        } else {
            # Lọc trực tiếp $rawReturnedItems để tìm các PSCustomObject dịch vụ hợp lệ
            # Điều này sẽ bỏ qua bất kỳ mục "rác" nào có thể đã được output ra pipeline
            Write-Log "DEBUG: Đang lọc \$rawReturnedItems trực tiếp để tìm các PSCustomObject dịch vụ hợp lệ."
            $servicesToDisplay = $rawReturnedItems | Where-Object {
                $_ -ne $null -and 
                $_ -is [PSCustomObject] -and 
                $_.PSObject.Properties["Name"] -ne $null -and # Đảm bảo có thuộc tính Name
                $_.PSObject.Properties["DisplayName"] -ne $null # Đảm bảo có thuộc tính DisplayName
            }
            
            Write-Log "DEBUG: Sau khi lọc, có $($servicesToDisplay.Count) dịch vụ hợp lệ được tìm thấy trong \$rawReturnedItems."

            # Nếu số lượng dịch vụ hợp lệ ít hơn số lượng mục thô, ghi log các mục không hợp lệ
            if ($servicesToDisplay.Count -lt $rawReturnedItems.Count) {
                $otherItemsCount = $rawReturnedItems.Count - $servicesToDisplay.Count
                Write-Log "DEBUG: Phát hiện $($otherItemsCount) mục không phải là dịch vụ hợp lệ trong output của Get-ServiceRecommendations."
                
                $itemsToLog = $rawReturnedItems | Where-Object {
                    $_ -eq $null -or
                    $_ -isnot [PSCustomObject] -or
                    $_.PSObject.Properties["Name"] -eq $null -or
                    $_.PSObject.Properties["DisplayName"] -eq $null
                } | Select-Object -First 5 # Chỉ log 5 mục đầu tiên để tránh quá nhiều log

                $itemsToLog | ForEach-Object -Begin { $i = 1 } -Process {
                    $itemValue = if ($_ -eq $null) { "\$null" } else { $_.ToString() }
                    $itemType = if ($_ -eq $null) { "NullType" } else { $_.GetType().FullName }
                    Write-Log "DEBUG ITEM BẤT THƯỜNG #$($i++): '$($itemValue)' (Kiểu: $($itemType))"
                }
            }
        }

        # Bước 2: Kiểm tra số lượng dịch vụ hợp lệ sau khi lọc
        if ($servicesToDisplay.Count -eq 0) {
            Write-Log "Button Click: Không có dịch vụ hợp lệ nào để hiển thị sau khi kiểm tra và lọc."
            return
        }

        # Bước 3: Điền dữ liệu vào ListView (giữ nguyên phần này từ các phiên bản trước)
        Write-Log "Button Click: Bắt đầu điền ListView với $($servicesToDisplay.Count) dịch vụ hợp lệ."
        foreach ($service in $servicesToDisplay) {
            try {
                $name = $service.Name 
                $listItem = New-Object System.Windows.Forms.ListViewItem($name)
                
                $displayNameSubItem = New-Object System.Windows.Forms.ListViewItem.ListViewSubItem
                $displayNameSubItem.Text = if ([string]::IsNullOrEmpty($service.DisplayName)) { "N/A" } else { $service.DisplayName }
                [void]$listItem.SubItems.Add($displayNameSubItem)
                
                $statusSubItem = New-Object System.Windows.Forms.ListViewItem.ListViewSubItem
                $statusSubItem.Text = if ($service.Status -eq $null) { "Unknown" } else { $service.Status.ToString() }
                [void]$listItem.SubItems.Add($statusSubItem)
                
                $startTypeSubItem = New-Object System.Windows.Forms.ListViewItem.ListViewSubItem
                $startTypeSubItem.Text = if ($service.StartType -eq $null) { "Unknown" } else { $service.StartType.ToString() }
                [void]$listItem.SubItems.Add($startTypeSubItem)
                
                $descriptionSubItem = New-Object System.Windows.Forms.ListViewItem.ListViewSubItem
                $descriptionSubItem.Text = if ([string]::IsNullOrEmpty($service.Description)) { "" } else { $service.Description }
                [void]$listItem.SubItems.Add($descriptionSubItem)
                
                $recommendationSubItem = New-Object System.Windows.Forms.ListViewItem.ListViewSubItem
                $recommendationSubItem.Text = if ([string]::IsNullOrEmpty($service.Recommendation)) { "" } else { $service.Recommendation }
                [void]$listItem.SubItems.Add($recommendationSubItem)
                
                if ($service.Level -eq "Safe") {
                    $listItem.BackColor = [System.Drawing.Color]::FromArgb(230, 255, 230)
                } elseif ($service.Level -eq "Careful") {
                    $listItem.BackColor = [System.Drawing.Color]::FromArgb(255, 255, 220)
                } elseif ($service.Level -eq "Dangerous") {
                    $listItem.BackColor = [System.Drawing.Color]::FromArgb(255, 230, 230)
                }
                
                [void]$servicesListView.Items.Add($listItem)
            }
            catch {
                Write-Log "Lỗi khi xử lý dịch vụ '$($service.Name)' để thêm vào ListView: $($_.Exception.Message)"
            }
        }
        Write-Log "Đã hoàn tất điền dữ liệu dịch vụ vào ListView."
    }
    catch {
        Write-Log "Lỗi nghiêm trọng trong sự kiện Click của nút Load Services: $($_.Exception.Message)"
    }
})
$tabServices.Controls.Add($loadServicesButton)

# Nút Vô hiệu hóa dịch vụ đã chọn
$disableServiceButton = Create-RoundedButton "Vô hiệu hóa" 10 240 120 25
$disableServiceButton.BackColor = [System.Drawing.Color]::IndianRed
$disableServiceButton.Add_Click({
    if ($servicesListView.SelectedItems.Count -gt 0) {
        $serviceName = $servicesListView.SelectedItems[0].Text
        $displayName = $servicesListView.SelectedItems[0].SubItems[1].Text
        
        # Kiểm tra xem có phải là dịch vụ cực kỳ quan trọng không
        if ($script:CriticalServices -contains $serviceName) {
            $warningResult = [System.Windows.Forms.MessageBox]::Show(
                "CẢNH BÁO NGHIÊM TRỌNG!`n`n" + 
                "Dịch vụ '$displayName' là dịch vụ CỐT LÕI của Windows. Vô hiệu hóa nó có thể gây ra:`n" + 
                "- Mất kết nối mạng`n" + 
                "- Lỗi khởi động Windows`n" + 
                "- Các vấn đề bảo mật nghiêm trọng`n`n" + 
                "Bạn có THỰC SỰ muốn vô hiệu hóa dịch vụ này không?`n" +
                "(Không đề xuất cho hầu hết người dùng)",
                "CẢNH BÁO - Dịch vụ Cốt lõi",
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
            
            if ($warningResult -ne [System.Windows.Forms.DialogResult]::Yes) {
                return
            }
            
            # Yêu cầu xác nhận thứ hai
            $confirmResult = [System.Windows.Forms.MessageBox]::Show(
                "Đây là xác nhận cuối cùng!`n`n" +
                "Gõ 'ĐỒNG Ý' (viết hoa) vào hộp thoại tiếp theo để xác nhận rằng bạn hiểu rủi ro và vẫn muốn tiếp tục.",
                "Xác nhận Cuối cùng",
                [System.Windows.Forms.MessageBoxButtons]::OKCancel,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            
            if ($confirmResult -ne [System.Windows.Forms.DialogResult]::OK) {
                return
            }
            
            # Yêu cầu nhập "ĐỒNG Ý" để xác nhận
            $verificationForm = New-Object System.Windows.Forms.Form
            $verificationForm.Text = "Xác minh Thao tác"
            $verificationForm.Size = New-Object System.Drawing.Size(400, 150)
            $verificationForm.StartPosition = "CenterScreen"
            $verificationForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
            
            $verificationLabel = New-Object System.Windows.Forms.Label
            $verificationLabel.Location = New-Object System.Drawing.Point(10, 20)
            $verificationLabel.Size = New-Object System.Drawing.Size(380, 20)
            $verificationLabel.Text = "Nhập 'ĐỒNG Ý' để xác nhận vô hiệu hóa dịch vụ quan trọng:"
            $verificationForm.Controls.Add($verificationLabel)
            
            $verificationTextBox = New-Object System.Windows.Forms.TextBox
            $verificationTextBox.Location = New-Object System.Drawing.Point(10, 50)
            $verificationTextBox.Size = New-Object System.Drawing.Size(280, 20)
            $verificationForm.Controls.Add($verificationTextBox)
            
            $verificationButton = New-Object System.Windows.Forms.Button
            $verificationButton.Location = New-Object System.Drawing.Point(300, 49)
            $verificationButton.Size = New-Object System.Drawing.Size(75, 23)
            $verificationButton.Text = "Xác nhận"
            $verificationButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
            $verificationForm.AcceptButton = $verificationButton
            $verificationForm.Controls.Add($verificationButton)
            
            $verificationResult = $verificationForm.ShowDialog()
            
            if ($verificationResult -ne [System.Windows.Forms.DialogResult]::OK -or $verificationTextBox.Text -ne "ĐỒNG Ý") {
                Write-Log "❌ Đã hủy việc vô hiệu hóa dịch vụ cốt lõi '$displayName'"
                return
            }
        }
        # Dịch vụ được đánh dấu là "cần thận trọng"
        elseif ($script:CarefulServices.ContainsKey($serviceName)) {
            $result = [System.Windows.Forms.MessageBox]::Show(
                "Dịch vụ '$displayName' được đánh dấu là QUAN TRỌNG.`n`n" +
                "Vô hiệu hóa dịch vụ này có thể ảnh hưởng đến các tính năng sau:`n" +
                "- " + $script:CarefulServices[$serviceName].Description + "`n`n" +
                "Bạn có chắc chắn muốn vô hiệu hóa nó không?",
                "Xác nhận vô hiệu hóa dịch vụ quan trọng",
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            
            if ($result -ne [System.Windows.Forms.DialogResult]::Yes) {
                return
            }
        }
        # Dịch vụ thông thường - xác nhận đơn giản
        else {
            $result = [System.Windows.Forms.MessageBox]::Show(
                "Bạn có chắc chắn muốn vô hiệu hóa dịch vụ '$displayName'?",
                "Xác nhận vô hiệu hóa dịch vụ",
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Question
            )
            
            if ($result -ne [System.Windows.Forms.DialogResult]::Yes) {
                return
            }
        }
        
        # Thực hiện vô hiệu hóa sau khi đã xác nhận
        try {
            Stop-Service -Name $serviceName -Force -ErrorAction Stop
            Set-Service -Name $serviceName -StartupType Disabled -ErrorAction Stop
            Write-Log "✅ Đã vô hiệu hóa dịch vụ '$displayName'"
            
            # Cập nhật ListView
            $loadServicesButton.PerformClick()
        } catch {
            Write-Log "❌ Không thể vô hiệu hóa dịch vụ '$displayName': $($_.Exception.Message)"
        }
    } else {
        [System.Windows.Forms.MessageBox]::Show(
            "Vui lòng chọn một dịch vụ để vô hiệu hóa",
            "Không có dịch vụ nào được chọn",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
    }
})
$tabServices.Controls.Add($disableServiceButton)

# Nút Bật dịch vụ đã chọn
$enableServiceButton = Create-RoundedButton "Bật lại" 140 240 120 25
$enableServiceButton.BackColor = [System.Drawing.Color]::LightGreen
$enableServiceButton.Add_Click({
    if ($servicesListView.SelectedItems.Count -gt 0) {
        $serviceName = $servicesListView.SelectedItems[0].Text
        $displayName = $servicesListView.SelectedItems[0].SubItems[1].Text
        
        try {
            Set-Service -Name $serviceName -StartupType Automatic -ErrorAction Stop
            Start-Service -Name $serviceName -ErrorAction Stop
            Write-Log "✅ Đã bật lại dịch vụ '$displayName'"
            
            # Cập nhật ListView
            $loadServicesButton.PerformClick()
        } catch {
            Write-Log "❌ Không thể bật dịch vụ '$displayName': $($_.Exception.Message)"
        }
    } else {
        [System.Windows.Forms.MessageBox]::Show(
            "Vui lòng chọn một dịch vụ để bật lại",
            "Không có dịch vụ nào được chọn",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
    }
})
$tabServices.Controls.Add($enableServiceButton)

# ListView cho các ứng dụng khởi động
$startupLabel = New-Object System.Windows.Forms.Label
$startupLabel.Location = New-Object System.Drawing.Point(10, 280)
$startupLabel.Size = New-Object System.Drawing.Size(540, 25)
$startupLabel.Text = "Ứng dụng khởi động cùng Windows:"
$startupLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$tabServices.Controls.Add($startupLabel)

$startupListView = New-Object System.Windows.Forms.ListView
$startupListView.Location = New-Object System.Drawing.Point(10, 310)
$startupListView.Size = New-Object System.Drawing.Size(740, 150)
$startupListView.View = [System.Windows.Forms.View]::Details
$startupListView.FullRowSelect = $true
$startupListView.GridLines = $true
$startupListView.Columns.Add("Tên", 150) | Out-Null
$startupListView.Columns.Add("Đường dẫn", 370) | Out-Null
$startupListView.Columns.Add("Loại", 100) | Out-Null
$startupListView.Columns.Add("Vị trí", 120) | Out-Null
$tabServices.Controls.Add($startupListView)

# Nút load startup items
$loadStartupButton = Create-RoundedButton "Hiển thị khởi động" 610 280 130 25
$loadStartupButton.Add_Click({
    $startupListView.Items.Clear()
    $startupItems = Get-StartupItems

    foreach ($item in $startupItems) {
        $listItem = New-Object System.Windows.Forms.ListViewItem($item.Name)
        $listItem.SubItems.Add($item.Command)
        $listItem.SubItems.Add($item.Type)
        $listItem.SubItems.Add($item.Location)
        $startupListView.Items.Add($listItem)
    }
})
$tabServices.Controls.Add($loadStartupButton)

# Nút xóa startup item
$removeStartupButton = Create-RoundedButton "Xóa khỏi khởi động" 10 470 130 25
$removeStartupButton.BackColor = [System.Drawing.Color]::IndianRed
$removeStartupButton.Add_Click({
    if ($startupListView.SelectedItems.Count -gt 0) {
        $itemName = $startupListView.SelectedItems[0].Text
        $itemType = $startupListView.SelectedItems[0].SubItems[2].Text
        $itemLocation = $startupListView.SelectedItems[0].SubItems[3].Text
        
        $result = [System.Windows.Forms.MessageBox]::Show(
            "Bạn có chắc chắn muốn xóa '$itemName' khỏi danh sách khởi động?",
            "Xác nhận xóa",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        
        if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
            try {
                if ($itemType -eq "Registry") {
                    Remove-ItemProperty -Path $itemLocation -Name $itemName -ErrorAction Stop
                    Write-Log "✅ Đã xóa '$itemName' khỏi khởi động (Registry)"
                } else {
                    $filePath = "$itemLocation\$itemName.lnk"
                    if (Test-Path $filePath) {
                        Remove-Item -Path $filePath -Force -ErrorAction Stop
                        Write-Log "✅ Đã xóa '$itemName' khỏi khởi động (Shortcut)"
                    }
                }
                
                # Cập nhật ListView
                $loadStartupButton.PerformClick()
            } catch {
                Write-Log "❌ Không thể xóa '$itemName' khỏi khởi động: $($_.Exception.Message)"
            }
        }
    } else {
        [System.Windows.Forms.MessageBox]::Show(
            "Vui lòng chọn một mục để xóa",
            "Không có mục nào được chọn",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
    }
})
$tabServices.Controls.Add($removeStartupButton)

# --- Tạo giao diện tab Sửa lỗi hệ thống ---
$repairLabel = New-Object System.Windows.Forms.Label
$repairLabel.Location = New-Object System.Drawing.Point(10, 15)
$repairLabel.Size = New-Object System.Drawing.Size(750, 40)
$repairLabel.Text = "Công cụ này giúp khôi phục và sửa chữa các thành phần quan trọng của Windows. Chọn một trong các công cụ sửa chữa bên dưới để bắt đầu."
$repairLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$tabSystemRepair.Controls.Add($repairLabel)

# GroupBox cho các công cụ sửa chữa hệ thống
$repairGroupBox = New-Object System.Windows.Forms.GroupBox
$repairGroupBox.Location = New-Object System.Drawing.Point(10, 60)
$repairGroupBox.Size = New-Object System.Drawing.Size(750, 190)
$repairGroupBox.Text = "Công cụ sửa chữa hệ thống"
$repairGroupBox.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$tabSystemRepair.Controls.Add($repairGroupBox)

# Tạo các nút công cụ sửa chữa
$buttonSFC = Create-RoundedButton "SFC Scan" 20 30 150 35
$buttonSFC.Parent = $repairGroupBox
$buttonSFC.BackColor = [System.Drawing.Color]::FromArgb(70, 130, 180)
$buttonSFC.Add_Click({
    Start-SystemRepair -RepairType "SFC" -ProgressBar $repairProgressBar -StatusLabel $repairStatusLabel
})
$tooltip.SetToolTip($buttonSFC, "Kiểm tra và sửa chữa các file hệ thống Windows bị hỏng")

$buttonDISMCheck = Create-RoundedButton "DISM CheckHealth" 190 30 150 35
$buttonDISMCheck.Parent = $repairGroupBox
$buttonDISMCheck.BackColor = [System.Drawing.Color]::FromArgb(70, 130, 180)
$buttonDISMCheck.Add_Click({
    Start-SystemRepair -RepairType "DISM_CheckHealth" -ProgressBar $repairProgressBar -StatusLabel $repairStatusLabel
})
$tooltip.SetToolTip($buttonDISMCheck, "Kiểm tra tính toàn vẹn của bộ cài Windows")

$buttonDISMScan = Create-RoundedButton "DISM ScanHealth" 360 30 150 35
$buttonDISMScan.Parent = $repairGroupBox
$buttonDISMScan.BackColor = [System.Drawing.Color]::FromArgb(70, 130, 180)
$buttonDISMScan.Add_Click({
    Start-SystemRepair -RepairType "DISM_ScanHealth" -ProgressBar $repairProgressBar -StatusLabel $repairStatusLabel
})
$tooltip.SetToolTip($buttonDISMScan, "Quét để tìm lỗi trong bộ cài Windows")

$buttonDISMRestore = Create-RoundedButton "DISM RestoreHealth" 530 30 150 35
$buttonDISMRestore.Parent = $repairGroupBox
$buttonDISMRestore.BackColor = [System.Drawing.Color]::FromArgb(70, 130, 180)
$buttonDISMRestore.Add_Click({
    Start-SystemRepair -RepairType "DISM_RestoreHealth" -ProgressBar $repairProgressBar -StatusLabel $repairStatusLabel
})
$tooltip.SetToolTip($buttonDISMRestore, "Khôi phục các file hệ thống Windows bị hỏng (Quá trình có thể mất 10-20 phút)")

$buttonCheckDisk = Create-RoundedButton "Kiểm tra ổ đĩa" 20 85 150 35
$buttonCheckDisk.Parent = $repairGroupBox
$buttonCheckDisk.BackColor = [System.Drawing.Color]::FromArgb(255, 140, 0)
$buttonCheckDisk.Add_Click({
    Start-SystemRepair -RepairType "CheckDisk" -ProgressBar $repairProgressBar -StatusLabel $repairStatusLabel
})
$tooltip.SetToolTip($buttonCheckDisk, "Kiểm tra và sửa lỗi ổ đĩa (cần khởi động lại)")

$buttonResetNetwork = Create-RoundedButton "Đặt lại cấu trúc mạng" 190 85 150 35
$buttonResetNetwork.Parent = $repairGroupBox
$buttonResetNetwork.BackColor = [System.Drawing.Color]::FromArgb(255, 140, 0)
$buttonResetNetwork.Add_Click({
    Start-SystemRepair -RepairType "ResetNetworkStack" -ProgressBar $repairProgressBar -StatusLabel $repairStatusLabel
})
$tooltip.SetToolTip($buttonResetNetwork, "Đặt lại cấu hình mạng và Winsock (giải quyết các vấn đề về kết nối)")

$buttonFixWindowsUpdates = Create-RoundedButton "Sửa Windows Update" 360 85 150 35
$buttonFixWindowsUpdates.Parent = $repairGroupBox
$buttonFixWindowsUpdates.BackColor = [System.Drawing.Color]::FromArgb(255, 140, 0)
$buttonFixWindowsUpdates.Add_Click({
    Start-SystemRepair -RepairType "FixWindowsUpdates" -ProgressBar $repairProgressBar -StatusLabel $repairStatusLabel
})
$tooltip.SetToolTip($buttonFixWindowsUpdates, "Sửa lỗi không thể cập nhật Windows")

$buttonFullSystemRepair = Create-RoundedButton "Sửa chữa hệ thống tự động" 190 140 320 35
$buttonFullSystemRepair.Parent = $repairGroupBox
$buttonFullSystemRepair.BackColor = [System.Drawing.Color]::FromArgb(144, 238, 144)
$buttonFullSystemRepair.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$buttonFullSystemRepair.Add_Click({
    $confirmFullRepair = [System.Windows.Forms.MessageBox]::Show(
        "Quá trình này kết hợp nhiều công cụ sửa chữa và có thể mất 30-60 phút để hoàn tất.`n`nBạn có muốn tiếp tục không?",
        "Xác nhận sửa chữa hệ thống tự động",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    
    if ($confirmFullRepair -eq [System.Windows.Forms.DialogResult]::Yes) {
        Start-SystemRepair -RepairType "RepairSystemFiles" -ProgressBar $repairProgressBar -StatusLabel $repairStatusLabel
    }
})
$tooltip.SetToolTip($buttonFullSystemRepair, "Quy trình sửa chữa tự động kết hợp tất cả công cụ trên (mất 30-60 phút)")

# Progress bar và status label
$repairProgressBar = New-Object System.Windows.Forms.ProgressBar
$repairProgressBar.Location = New-Object System.Drawing.Point(10, 270)
$repairProgressBar.Size = New-Object System.Drawing.Size(750, 25)
$repairProgressBar.Style = [System.Windows.Forms.ProgressBarStyle]::Continuous
$tabSystemRepair.Controls.Add($repairProgressBar)

$repairStatusLabel = New-Object System.Windows.Forms.Label
$repairStatusLabel.Location = New-Object System.Drawing.Point(10, 300)
$repairStatusLabel.Size = New-Object System.Drawing.Size(750, 20)
$repairStatusLabel.Text = "Chọn một công cụ sửa chữa để bắt đầu..."
$repairStatusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$tabSystemRepair.Controls.Add($repairStatusLabel)

# GroupBox cho thông tin sửa chữa
$repairInfoGroupBox = New-Object System.Windows.Forms.GroupBox
$repairInfoGroupBox.Location = New-Object System.Drawing.Point(10, 330)
$repairInfoGroupBox.Size = New-Object System.Drawing.Size(750, 60)
$repairInfoGroupBox.Text = "Trạng thái hệ thống"
$repairInfoGroupBox.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$tabSystemRepair.Controls.Add($repairInfoGroupBox)

$systemHealthLabel = New-Object System.Windows.Forms.Label
$systemHealthLabel.Location = New-Object System.Drawing.Point(10, 25)
$systemHealthLabel.Size = New-Object System.Drawing.Size(730, 25)
$systemHealthLabel.Text = "Vui lòng chạy một công cụ kiểm tra để xem trạng thái hệ thống."
$systemHealthLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$repairInfoGroupBox.Controls.Add($systemHealthLabel)


# Sự kiện khi chuyển tab (để tự động bỏ chọn các checkbox trên tab khác)
$tabControl.Add_SelectedIndexChanged({
    $newSelectedTab = $tabControl.SelectedTab
    foreach ($tabPage in $tabControl.TabPages) {
        if ($tabPage -ne $newSelectedTab) {
            foreach ($control in $tabPage.Controls) {
                if ($control -is [System.Windows.Forms.CheckBox]) {
                    $control.Checked = $false
                }
            }
        }
    }
})

# 4.7 Panel thông tin hệ thống
$systemInfoPanel = New-Object System.Windows.Forms.Panel
$systemInfoPanel.Location = New-Object System.Drawing.Point(10, 480)
$systemInfoPanel.Size = New-Object System.Drawing.Size(770, 70)
$systemInfoPanel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$systemInfoPanel.BackColor = [System.Drawing.Color]::FromArgb(230, 230, 230)

$osVersionLabel = New-Object System.Windows.Forms.Label
$osVersionLabel.Location = New-Object System.Drawing.Point(10, 5)
$osVersionLabel.Size = New-Object System.Drawing.Size(350, 18)
$osVersionLabel.Text = "Hệ điều hành: " + (Get-CimInstance Win32_OperatingSystem).Caption
$osVersionLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$systemInfoPanel.Controls.Add($osVersionLabel)

$cpuInfoLabel = New-Object System.Windows.Forms.Label
$cpuInfoLabel.Location = New-Object System.Drawing.Point(10, 25)
$cpuInfoLabel.Size = New-Object System.Drawing.Size(350, 18)
$cpuInfoLabel.Text = "CPU: " + (Get-CimInstance Win32_Processor).Name
$cpuInfoLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$systemInfoPanel.Controls.Add($cpuInfoLabel)

$ramInfoLabel = New-Object System.Windows.Forms.Label
$ramInfoLabel.Location = New-Object System.Drawing.Point(10, 45)
$ramInfoLabel.Size = New-Object System.Drawing.Size(350, 18)
$totalRam = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
$ramInfoLabel.Text = "RAM: $totalRam GB"
$ramInfoLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$systemInfoPanel.Controls.Add($ramInfoLabel)

$diskInfoLabel = New-Object System.Windows.Forms.Label
$diskInfoLabel.Location = New-Object System.Drawing.Point(370, 5)
$diskInfoLabel.Size = New-Object System.Drawing.Size(390, 60)
$diskInfo = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" |
            Select-Object DeviceID,
                @{Name="Size(GB)";Expression={[math]::Round($_.Size / 1GB, 2)}},
                @{Name="FreeSpace(GB)";Expression={[math]::Round($_.FreeSpace / 1GB, 2)}},
                @{Name="PercentFree";Expression={[math]::Round(($_.FreeSpace / $_.Size) * 100, 1)}}

$diskInfoText = "Thông tin ổ đĩa:`n"
foreach ($disk in $diskInfo) {
    $diskInfoText += "$($disk.DeviceID) $($disk.'FreeSpace(GB)') GB trống / $($disk.'Size(GB)') GB ($($disk.PercentFree)%)`n"
}
$diskInfoLabel.Text = $diskInfoText.TrimEnd("`n")
$diskInfoLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$systemInfoPanel.Controls.Add($diskInfoLabel)

# 4.8 Panel điều khiển (progress bar, log, nút bắt đầu/hủy)
$controlPanel = New-Object System.Windows.Forms.Panel
$controlPanel.Location = New-Object System.Drawing.Point(10, 695) # ĐÃ ĐIỀU CHỈNH Y
$controlPanel.Size = New-Object System.Drawing.Size(775, 160)

# --- Panel điều khiển cải tiến ---
$controlPanel = New-Object System.Windows.Forms.Panel
$controlPanel.Location = New-Object System.Drawing.Point(10, 555)
$controlPanel.Size = New-Object System.Drawing.Size(775, 160)

# Progress bar chính
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(0, 5)
$progressBar.Size = New-Object System.Drawing.Size(480, 25)
$progressBar.Style = [System.Windows.Forms.ProgressBarStyle]::Continuous
$controlPanel.Controls.Add($progressBar)

# Progress bar phụ cho tác vụ con
$subProgressBar = New-Object System.Windows.Forms.ProgressBar
$subProgressBar.Location = New-Object System.Drawing.Point(0, 35)
$subProgressBar.Size = New-Object System.Drawing.Size(480, 15)
$subProgressBar.Visible = $false
$controlPanel.Controls.Add($subProgressBar)

# Label hiển thị tác vụ hiện tại
$currentTaskLabel = New-Object System.Windows.Forms.Label
$currentTaskLabel.Location = New-Object System.Drawing.Point(490, 35)
$currentTaskLabel.Size = New-Object System.Drawing.Size(270, 15)
$currentTaskLabel.Text = ""
$currentTaskLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$controlPanel.Controls.Add($currentTaskLabel)

# Nút Bắt đầu và Hủy
$startButton = Create-RoundedButton "Bắt đầu dọn dẹp" 600 5 160 25
$cancelButton = Create-RoundedButton "Hủy" 490 5 100 25
$cancelButton.BackColor = [System.Drawing.Color]::LightGray
$cancelButton.ForeColor = [System.Drawing.Color]::Black
$cancelButton.Enabled = $false
$controlPanel.Controls.Add($startButton)
$controlPanel.Controls.Add($cancelButton)

# Log box
$logBox = New-Object System.Windows.Forms.RichTextBox
$logBox.Location = New-Object System.Drawing.Point(0, 55)
$logBox.Size = New-Object System.Drawing.Size(770, 100)
$logBox.ReadOnly = $true
$logBox.BackColor = [System.Drawing.Color]::FromArgb(245, 245, 245)
$logBox.Font = New-Object System.Drawing.Font("Consolas", 9)
$controlPanel.Controls.Add($logBox)

# Hàm cập nhật thông tin tác vụ con
function Update-SubTask {
    param(
        [string]$TaskName,
        [int]$Progress = -1
    )
    
    if ($Progress -ge 0) {
        $form.Invoke([Action]{
            $subProgressBar.Visible = $true
            $subProgressBar.Value = $Progress
            $currentTaskLabel.Text = $TaskName
        })
    } else {
        $form.Invoke([Action]{
            $currentTaskLabel.Text = $TaskName
        })
    }
}

# Cập nhật hàm Write-Log để thêm màu sắc
function Write-Log {
    param(
        [string]$message,
        [System.Drawing.Color]$color = [System.Drawing.Color]::Black
    )
    
    $time = Get-Date -Format "HH:mm:ss"
    $logMessage = "[$time] $message"
    
    if ($logBox -ne $null -and $logBox.IsHandleCreated) {
        try {
            $logBox.Invoke([Action]{
                $logBox.SelectionStart = $logBox.TextLength
                $logBox.SelectionLength = 0
                $logBox.SelectionColor = $color
                $logBox.AppendText("$logMessage`n")
                $logBox.SelectionStart = $logBox.Text.Length
                $logBox.ScrollToCaret()
            })
        } catch {
            Write-Host "$logMessage (Lỗi khi ghi vào log box: $($_.Exception.Message))"
        }
    } else {
        Write-Host $logMessage
    }
}

$controlPanel.Controls.Add($logBox)

# 4.9 Thêm tất cả vào form
$form.Controls.Add($headerPanel)
$form.Controls.Add($tabControl)
$form.Controls.Add($systemInfoPanel)
$form.Controls.Add($controlPanel)

# -- 5. Chức năng dọn dẹp chính --
function Start-Cleanup {
    # Khởi tạo các biến dịch vụ ở đây để truy cập được từ mọi case
    $services = @{
        "DiagTrack" = "Disabled"
        "dmwappushservice" = "Disabled"
        "SysMain" = "Disabled"
        "WSearch" = "Disabled"
    }

    # Khóa nút và bật nút hủy
    $form.Invoke([Action]{
        $startButton.Enabled = $false
        $cancelButton.Enabled = $true
        $progressBar.Value = 0
        $subProgressBar.Visible = $false   # THÊM DÒNG NÀY
        $currentTaskLabel.Text = ""        # THÊM DÒNG NÀY
    })

    Write-Log "Bắt đầu quá trình dọn dẹp..." -color ([System.Drawing.Color]::Blue)

    # Lấy danh sách các tác vụ được chọn
    $selectedTasks = @{}
    $checkboxes.Keys | ForEach-Object { if ($checkboxes[$_].Checked) { $selectedTasks[$_] = $checkboxes[$_].Text } }
    $advancedCheckboxes.Keys | ForEach-Object { if ($advancedCheckboxes[$_].Checked) { $selectedTasks[$_] = $advancedCheckboxes[$_].Text } }
    $optimizeCheckboxes.Keys | ForEach-Object { if ($optimizeCheckboxes[$_].Checked) { $selectedTasks[$_] = $optimizeCheckboxes[$_].Text } }
    $securityCheckboxes.Keys | ForEach-Object { if ($securityCheckboxes[$_].Checked) { $selectedTasks[$_] = $securityCheckboxes[$_].Text } }
    $privacyCheckboxes.Keys | ForEach-Object { if ($privacyCheckboxes[$_].Checked) { $selectedTasks[$_] = $privacyCheckboxes[$_].Text } }

    $totalTasks = $selectedTasks.Count
    $completedTasks = 0

    # Thiết lập progress bar
    $form.Invoke([Action]{
        $progressBar.Maximum = [Math]::Max($totalTasks, 1)
        $progressBar.Value = 0
		$subProgressBar.Maximum = 100
		 $subProgressBar.Value = 0
    })

    # Lưu thông tin ổ đĩa trước khi dọn dẹp
    $diskInfoBefore = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" |
                      Select-Object DeviceID, @{Name="FreeSpace(GB)";Expression={[math]::Round($_.FreeSpace / 1GB, 2)}}

    # Các biến theo dõi tác vụ
    $skippedTasks = @()
    $failedTasks = @()
	$successTasks = @()

    # Định nghĩa hàm cập nhật tác vụ con
    function Update-SubTask {
        param(
            [string]$TaskName,
            [int]$Progress = -1
        )
        
        if ($Progress -ge 0) {
            $form.Invoke([Action]{
                $subProgressBar.Visible = $true
                $subProgressBar.Value = $Progress
                $currentTaskLabel.Text = $TaskName
            })
        } else {
            $form.Invoke([Action]{
                $currentTaskLabel.Text = $TaskName
            })
        }
    }
	
    # Thực hiện các tác vụ
    foreach ($key in $selectedTasks.Keys) {
        $completedTasks++
        $form.Invoke([Action]{
            $progressBar.Value = $completedTasks
            $currentTaskLabel.Text = "Tác vụ $completedTasks/$totalTasks"   # THÊM DÒNG NÀY
        })
        
        $taskText = $selectedTasks[$key]
        Write-Log "Đang thực hiện ($completedTasks/$totalTasks): $taskText..." -color [System.Drawing.Color]::DarkBlue
        $success = $true

        try {
            # Đặt subProgressBar thành 0 cho mỗi tác vụ mới  # THÊM ĐOẠN CODE SAU
            $form.Invoke([Action]{
                $subProgressBar.Visible = $true
                $subProgressBar.Value = 0
            })
			
            switch ($key) {
                # --- Dọn dẹp cơ bản ---
                "TempFiles" {
					Update-SubTask "Đang xóa thư mục Temp của Windows..." 0
                    try {
                        Remove-Item -Path "$env:TEMP\*" -Force -Recurse -ErrorAction Stop
						Update-SubTask "Đang xóa thư mục Temp của hệ thống..." 50
                        Remove-Item -Path "$env:windir\Temp\*" -Force -Recurse -ErrorAction Stop
						Update-SubTask "Đã xóa xong các thư mục Temp" 100
                    } catch {
                        Write-Log "❌ Không thể xóa file tạm: $($_.Exception.Message)" -color [System.Drawing.Color]::Red
                        $success = $false
                    }
                }
                "RecycleBin" {
                    $shell = New-Object -ComObject Shell.Application
                    $recycleBin = $shell.Namespace(0xA)
                    if ($recycleBin.Items().Count -gt 0) {
                        $recycleBin.Items() | ForEach-Object {
                            if ($_.PSObject.Properties['Path']) {
                                try {
                                    Remove-Item -LiteralPath $_.Path -Recurse -Force -Confirm:$false -ErrorAction Stop
                                } catch {
                                    Write-Log "❌ Không thể xóa mục trong Thùng rác: $($_.Exception.Message)"
                                    $success = $false
                                }
                            } else {
                                Write-Log "⚠️ Không thể lấy đường dẫn cho một mục trong Thùng rác."
                            }
                        }
                    } else {
                        Write-Log "ℹ️ Thùng rác đã trống."
                        $success = "Skip"
                    }
                }
                "BrowserCache" {
                    try {
                        # Chrome
                        $chromeCache = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache"
                        if (Test-Path $chromeCache) { Remove-Item -Path "$chromeCache\*" -Force -Recurse -ErrorAction Stop }
                        
                        # Edge
                        $edgeCache = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache"
                        if (Test-Path $edgeCache) { Remove-Item -Path "$edgeCache\*" -Force -Recurse -ErrorAction Stop }
                        
                        # Firefox
                        $firefoxProfiles = "$env:APPDATA\Mozilla\Firefox\Profiles"
                        if (Test-Path $firefoxProfiles) {
                            Get-ChildItem $firefoxProfiles -Directory | ForEach-Object {
                                $ffCache = "$($_.FullName)\cache2"
                                if (Test-Path $ffCache) { Remove-Item -Path "$ffCache\*" -Force -Recurse -ErrorAction Stop }
                            }
                        }
                    } catch {
                        Write-Log "❌ Không thể xóa cache trình duyệt: $($_.Exception.Message)"
                        $success = $false
                    }
                }
                "WinUpdateCache" {
                    try {
                        Stop-Service -Name wuauserv, bits -Force -ErrorAction SilentlyContinue
                        $softwareDist = "$env:windir\SoftwareDistribution"
                        if (Test-Path $softwareDist) { 
                            Remove-Item -Path "$softwareDist\*" -Force -Recurse -ErrorAction Stop 
                        }
                        Start-Service -Name bits, wuauserv -ErrorAction SilentlyContinue
                    } catch {
                        Write-Log "❌ Không thể xóa Windows Update Cache: $($_.Exception.Message)"
                        $success = $false
                    }
                }
                "Prefetch" {
                    try {
                        Remove-Item -Path "$env:windir\Prefetch\*" -Force -ErrorAction Stop
                    } catch {
                        Write-Log "❌ Không thể xóa Prefetch: $($_.Exception.Message)"
                        $success = $false
                    }
                }
                "OldDownloads" {
                    try {
                        $threshold = (Get-Date).AddDays(-3)
                        Get-ChildItem -Path "$env:USERPROFILE\Downloads" -File | 
                            Where-Object { $_.LastWriteTime -lt $threshold } | 
                            Remove-Item -Force -ErrorAction Stop
                    } catch {
                        Write-Log "❌ Không thể xóa bản tải xuống cũ: $($_.Exception.Message)"
                        $success = $false
                    }
                }
                "EventLogs" {
                    try {
                        wevtutil el | ForEach-Object { 
                            wevtutil cl "$_" /q:$true 
                        }
                    } catch {
                        Write-Log "❌ Không thể xóa Event Logs: $($_.Exception.Message)"
                        $success = $false
                    }
                }
                "ThumbnailCache" {
                    try {
                        Safe-RestartExplorer # Dùng hàm an toàn để đóng/mở explorer
                        Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db" -Force -ErrorAction Stop
                    } catch {
                        Write-Log "❌ Không thể xóa Thumbnail Cache: $($_.Exception.Message)"
                        $success = $false
                    }
                }
                # --- Dọn dẹp nâng cao ---
                "WinSxS" {
                    try {
                        $process = Start-Process -FilePath "Dism.exe" -ArgumentList "/Online /Cleanup-Image /StartComponentCleanup" -NoNewWindow -PassThru -Wait -ErrorAction Stop
                        if ($process.ExitCode -ne 0) { 
                            $success = $false
                            Write-Log "⚠️ DISM WinSxS lỗi mã: $($process.ExitCode)" 
                        }
                    } catch {
                        Write-Log "❌ Không thể dọn WinSxS: $($_.Exception.Message)"
                        $success = $false
                    }
                }
                "SoftwareDist" {
                    # Đã xử lý trong WinUpdateCache, có thể coi là thành công nếu WinUpdateCache thành công
                    Write-Log "ℹ️ SoftwareDistribution được xử lý cùng Windows Update Cache."
                    $success = "Skip"
                }
                "ComponentStore" {
                    try {
                        Start-Process -FilePath "Dism.exe" -ArgumentList "/Online /Cleanup-Image /AnalyzeComponentStore" -NoNewWindow -PassThru -Wait -ErrorAction Stop
                        $process = Start-Process -FilePath "Dism.exe" -ArgumentList "/Online /Cleanup-Image /StartComponentCleanup /ResetBase" -NoNewWindow -PassThru -Wait -ErrorAction Stop
                        if ($process.ExitCode -ne 0) { 
                            $success = $false
                            Write-Log "⚠️ DISM Component Store lỗi mã: $($process.ExitCode)" 
                        }
                    } catch {
                        Write-Log "❌ Không thể dọn Component Store: $($_.Exception.Message)"
                        $success = $false
                    }
                }
                "StoreCache" {
                    try {
                        Start-Process "wsreset.exe" -NoNewWindow -Wait -ErrorAction Stop
                    } catch {
                        Write-Log "❌ Không thể dọn Microsoft Store Cache: $($_.Exception.Message)"
                        $success = $false
                    }
                }
                "OneDriveCache" {
                    if (Test-Path "$env:USERPROFILE\OneDrive") {
                        try {
                            $pathsToRemove = @(
                                "$env:USERPROFILE\OneDrive\.temp",
                                "$env:USERPROFILE\OneDrive\logs",
                                "$env:LOCALAPPDATA\Microsoft\OneDrive\setup\logs"
                            )
                            foreach ($path in $pathsToRemove) {
                                if (Test-Path $path) {
                                    Remove-Item -Path "$path\*" -Force -Recurse -ErrorAction Stop
                                }
                            }
                        } catch {
                            Write-Log "❌ Không thể dọn OneDrive Cache: $($_.Exception.Message)"
                            $success = $false
                        }
                    } else {
                        Write-Log "⚠️ OneDrive không được cài đặt hoặc không tìm thấy."
                        $success = "Skip"
                    }
                }
                "Hibernation" {
                    try {
                        $process = Start-Process -FilePath "powercfg.exe" -ArgumentList "/hibernate off" -NoNewWindow -PassThru -Wait -ErrorAction Stop
                        if ($process.ExitCode -ne 0) { 
                            $success = $false
                            Write-Log "⚠️ Powercfg hibernate off lỗi mã: $($process.ExitCode)" 
                        }
                    } catch {
                        Write-Log "❌ Không thể tắt Hibernation: $($_.Exception.Message)"
                        $success = $false
                    }
                }
                "FontCache" {
                    try {
                        Stop-Service -Name "FontCache", "FontCache3.0.0.0" -Force -ErrorAction SilentlyContinue
                        Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\Windows\Fonts\*" -Force -ErrorAction Stop
                        Remove-Item -Path "$env:WINDIR\ServiceProfiles\LocalService\AppData\Local\FontCache\*" -Force -Recurse -ErrorAction Stop
                        Start-Service -Name "FontCache", "FontCache3.0.0.0" -ErrorAction SilentlyContinue
                    } catch {
                        Write-Log "❌ Không thể dọn Font Cache: $($_.Exception.Message)"
                        $success = $false
                    }
                }
                "CompressNTFS" {
                    try {
                        $process = Start-Process -FilePath "compact.exe" -ArgumentList "/CompactOS:always" -NoNewWindow -PassThru -Wait -ErrorAction Stop
                        if ($process.ExitCode -ne 0) { 
                            $success = $false
                            Write-Log "⚠️ CompactOS lỗi mã: $($process.ExitCode)" 
                        }
                    } catch {
                        Write-Log "❌ Không thể nén hệ thống tệp NTFS: $($_.Exception.Message)"
                        $success = $false
                    }
                }
                # --- Tối ưu hóa ---
                "StartupOptimize" {
                    try {
                        # Giảm thời gian trễ khởi động
                        $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Serialize"
                        if (-not (Test-Path $registryPath)) { 
                            New-Item -Path $registryPath -Force | Out-Null 
                        }
                        Set-ItemProperty -Path $registryPath -Name "StartupDelayInMSec" -Value 0 -Type DWORD -Force -ErrorAction Stop
                    } catch {
                        Write-Log "❌ Không thể tối ưu hóa khởi động: $($_.Exception.Message)"
                        $success = $false
                    }
                }
                "ServiceOptimize" {
                    try {
                        # Vô hiệu hóa một số dịch vụ không cần thiết
                        foreach ($name in $services.Keys) {
                            if (Get-Service -Name $name -ErrorAction SilentlyContinue) {
                                Set-Service -Name $name -StartupType $services[$name] -ErrorAction Stop
                                Stop-Service -Name $name -Force -ErrorAction SilentlyContinue
                            }
                        }
                    } catch {
                        Write-Log "❌ Không thể tối ưu hóa dịch vụ: $($_.Exception.Message)"
                        $success = $false
                    }
                }
                "PageFileOptimize" {
                    try {
                        # Tự động quản lý pagefile
                        $computerSystem = Get-WmiObject Win32_ComputerSystem -EnableAllPrivileges
                        if (-not $computerSystem.AutomaticManagedPagefile) {
                            $computerSystem.AutomaticManagedPagefile = $true
                            $computerSystem.Put() | Out-Null
                            Write-Log "ℹ️ Đã bật lại tự động quản lý Page File."
                        } else {
                            Write-Log "ℹ️ Page File đang được quản lý tự động."
                        }
                        $success = "Skip"
                    } catch {
                        Write-Log "❌ Không thể tối ưu hóa Page File: $($_.Exception.Message)"
                        $success = $false
                    }
                }
                "VisualPerformance" {
                    # Tạm thời bỏ qua tự động hóa hoàn toàn bước này vì khả năng gây lỗi
                    Write-Log "ℹ️ Vui lòng tự điều chỉnh hiệu suất trực quan trong System Properties > Advanced > Performance Settings."
                    $success = "Skip"
                }
                "NetworkLatency" {
                    # Các cài đặt này có thể gây hại nhiều hơn lợi trên các kết nối hiện đại
                    Write-Log "ℹ️ Tối ưu hóa mạng nâng cao thường không cần thiết và có thể gây sự cố. Bỏ qua."
                    $success = "Skip"
                }
                "SearchOptimize" {
                    try {
                        # Tắt dịch vụ nếu được chọn trong ServiceOptimize
                        if ($selectedTasks.ContainsKey("ServiceOptimize") -and $services.ContainsKey("WSearch") -and $services["WSearch"] -eq "Disabled") {
                            Write-Log "ℹ️ Windows Search đã được tắt trong tối ưu hóa dịch vụ."
                            $success = "Skip"
                        } else {
                            # Chỉ rebuild index nếu dịch vụ đang chạy
                            if ((Get-Service WSearch).Status -eq 'Running') {
                                Write-Log "Đang rebuild Windows Search index..."
                                Stop-Service -Name "WSearch" -Force -ErrorAction Stop
                                Remove-Item -Path "$env:ProgramData\Microsoft\Search\Data\Applications\Windows\Windows.edb" -Force -ErrorAction SilentlyContinue
                                Start-Service -Name "WSearch" -ErrorAction Stop
                            } else {
                                Write-Log "ℹ️ Windows Search service không chạy. Bỏ qua rebuild index."
                                $success = "Skip"
                            }
                        }
                    } catch {
                        Write-Log "❌ Không thể tối ưu hóa Windows Search: $($_.Exception.Message)"
                        $success = $false
                    }
                }
                "RAMOptimize" {
                    # Việc giải phóng RAM thủ công thường không hiệu quả
                    Write-Log "ℹ️ Windows quản lý RAM hiệu quả. Việc giải phóng thủ công thường không cần thiết. Bỏ qua."
                    $success = "Skip"
                }
                "ShutdownOptimize" {
                    try {
                        # Giảm thời gian chờ khi đóng ứng dụng
                        $desktopPath = "HKCU:\Control Panel\Desktop"
                        Set-ItemProperty -Path $desktopPath -Name "AutoEndTasks" -Value "1" -Type String -Force -ErrorAction Stop
                        Set-ItemProperty -Path $desktopPath -Name "HungAppTimeout" -Value "1000" -Type String -Force -ErrorAction Stop
                        Set-ItemProperty -Path $desktopPath -Name "WaitToKillAppTimeout" -Value "2000" -Type String -Force -ErrorAction Stop
                        
                        # Giảm thời gian chờ service
                        $controlPath = "HKLM:\SYSTEM\CurrentControlSet\Control"
                        Set-ItemProperty -Path $controlPath -Name "WaitToKillServiceTimeout" -Value "2000" -Type String -Force -ErrorAction Stop
                    } catch {
                        Write-Log "❌ Không thể tối ưu hóa thời gian tắt máy: $($_.Exception.Message)"
                        $success = $false
                    }
                }
                # --- Bảo mật ---
                "BasicMalware" {
                    try {
                        # Sử dụng Windows Defender để quét nhanh
                        if (Get-Command Start-MpScan -ErrorAction SilentlyContinue) {
                            Start-MpScan -ScanType QuickScan -ErrorAction Stop
                        } else {
                            Write-Log "⚠️ Không tìm thấy lệnh Start-MpScan (Windows Defender)."
                            $success = "Skip"
                        }
                    } catch {
                        Write-Log "❌ Không thể quét phần mềm độc hại: $($_.Exception.Message)"
                        $success = $false
                    }
                }
                "BrowserHistory" {
                    try {
                        # IE/Edge Legacy Cache
                        Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\Windows\WebCache\*" -Force -Recurse -ErrorAction SilentlyContinue
                        
                        # Chrome History & Cache (không xóa Cookies)
                        $chromeUserDir = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default"
                        if(Test-Path $chromeUserDir){
                            Remove-Item -Path "$chromeUserDir\History" -Force -ErrorAction SilentlyContinue
                            Remove-Item -Path "$chromeUserDir\Cache\*" -Force -Recurse -ErrorAction SilentlyContinue
                        }
                        
                        # Edge Chromium History & Cache (không xóa Cookies)
                        $edgeUserDir = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default"
                        if(Test-Path $edgeUserDir){
                            Remove-Item -Path "$edgeUserDir\History" -Force -ErrorAction SilentlyContinue
                            Remove-Item -Path "$edgeUserDir\Cache\*" -Force -Recurse -ErrorAction SilentlyContinue
                        }
                        
                        # Firefox History & Cache (không xóa Cookies)
                        $firefoxProfiles = "$env:APPDATA\Mozilla\Firefox\Profiles"
                        if (Test-Path $firefoxProfiles) {
                            Get-ChildItem $firefoxProfiles -Directory | ForEach-Object {
                                $ffProfile = $_.FullName
                                Remove-Item -Path "$ffProfile\places.sqlite" -Force -ErrorAction SilentlyContinue
                                Remove-Item -Path "$ffProfile\cache2\*" -Force -Recurse -ErrorAction SilentlyContinue
                            }
                        }
                    } catch {
                        Write-Log "❌ Không thể xóa lịch sử duyệt web: $($_.Exception.Message)"
                        $success = $false
                    }
                }
                "WindowsUpdate" {
                    try {
                        # Kiểm tra cập nhật Windows
                        if (Get-Module -ListAvailable -Name PSWindowsUpdate) {
                            Import-Module PSWindowsUpdate -Force
                            Write-Log "Đang kiểm tra bản cập nhật Windows..."
                            $updates = Get-WindowsUpdate -MicrosoftUpdate
                            if ($updates) {
                                Write-Log "Các bản cập nhật có sẵn:"
                                $updates | ForEach-Object { Write-Log "- $($_.Title)" }
                            } else {
                                Write-Log "✅ Hệ thống đã được cập nhật."
                            }
                        } else {
                            Write-Log "⚠️ Module PSWindowsUpdate không được cài đặt. Không thể kiểm tra cập nhật tự động."
                            Write-Log "ℹ️ Đang mở Windows Update Settings..."
                            Start-Process "ms-settings:windowsupdate"
                            $success = "Skip"
                        }
                    } catch {
                        Write-Log "❌ Không thể kiểm tra Windows Update: $($_.Exception.Message)"
                        $success = $false
                    }
                }
                "RecentFiles" {
                    try {
                        Remove-Item -Path "$env:APPDATA\Microsoft\Windows\Recent\*" -Force -Recurse -ErrorAction Stop
                        
                        # Xóa Jump Lists (cần đóng explorer)
                        Safe-RestartExplorer
                        Remove-Item -Path "$env:APPDATA\Microsoft\Windows\Recent\AutomaticDestinations\*" -Force -Recurse -ErrorAction Stop
                        Remove-Item -Path "$env:APPDATA\Microsoft\Windows\Recent\CustomDestinations\*" -Force -Recurse -ErrorAction Stop
                    } catch {
                        Write-Log "❌ Không thể xóa Recent Files: $($_.Exception.Message)"
                        $success = $false
                    }
                }
                "DiagData" {
                    try {
                        Remove-Item -Path "$env:ProgramData\Microsoft\Diagnosis\*" -Force -Recurse -ErrorAction Stop
                        # Các cache khác có thể liên quan
                        Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\Windows\Caches\*" -Force -Recurse -ErrorAction SilentlyContinue
                    } catch {
                        Write-Log "❌ Không thể xóa dữ liệu chẩn đoán: $($_.Exception.Message)"
                        $success = $false
                    }
                }
                "LocationTracking" {
                    try {
                        $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location"
                        if (Test-Path $registryPath) {
                            Set-ItemProperty -Path $registryPath -Name "Value" -Value "Deny" -Type String -Force -ErrorAction Stop
                        }
                        
                        # Tắt dịch vụ vị trí
                        if (Get-Service -Name "lfsvc" -ErrorAction SilentlyContinue) {
                            Set-Service -Name "lfsvc" -StartupType Disabled -ErrorAction Stop
                            Stop-Service -Name "lfsvc" -Force -ErrorAction SilentlyContinue
                        }
                    } catch {
                        Write-Log "❌ Không thể tắt theo dõi vị trí: $($_.Exception.Message)"
                        $success = $false
                    }
                }
                "EnsureFirewallEnabled" {
                    try {
                        Write-Log "Đang kiểm tra trạng thái Tường lửa Windows..."
                        $profiles = Get-NetFirewallProfile -ErrorAction Stop
                        $profiles | Select-Object Name, Enabled | Format-Table -AutoSize | Out-String | Write-Log

                        $disabledProfiles = $profiles | Where-Object {$_.Enabled -eq $false} | Select-Object -ExpandProperty Name
                        if ($disabledProfiles) {
                            Write-Log "⚠️ Phát hiện Tường lửa đang TẮT cho các profile: $($disabledProfiles -join ', ')"
                            Write-Log "Đang bật Tường lửa cho các profile này..."
                            Set-NetFirewallProfile -Profile $disabledProfiles -Enabled True -ErrorAction Stop
                            Write-Log "✅ Đã bật Tường lửa cho các profile: $($disabledProfiles -join ', ')"
                        } else {
                            Write-Log "✅ Tường lửa đã được bật cho tất cả các profile."
                            $success = "Skip"
                        }
                    } catch {
                        Write-Log "❌ Không thể kiểm tra/bật Tường lửa: $($_.Exception.Message)"
                        $success = $false
                    }
                }
                "CheckRealTimeProtection" {
                    try {
                        Write-Log "Đang kiểm tra trạng thái Bảo vệ thời gian thực..."
                        $RealTimeStatus = $null # Reset biến trước khi kiểm tra
                        # Lấy trạng thái, nếu Defender không chạy sẽ lỗi hoặc trả về $null
                        $RealTimeStatus = Get-MpComputerStatus -ErrorAction Stop | Select-Object -ExpandProperty RealTimeProtectionEnabled
                        if ($RealTimeStatus -eq $true) {
                            Write-Log "✅ Bảo vệ thời gian thực của Windows Defender đang BẬT."
                            $success = "Skip" # Chỉ kiểm tra, không thay đổi
                        } else { # Bao gồm cả trường hợp $false
                            Write-Log "⚠️ Bảo vệ thời gian thực của Windows Defender đang TẮT."
                            # Bật lại nếu cần nhưng phải cẩn thận - có thể người dùng đang dùng AV khác
                            # Write-Log "Đang thử kích hoạt lại bảo vệ thời gian thực..."
                            # Set-MpPreference -DisableRealtimeMonitoring $false
                        }
                    } catch {
                        Write-Log "❓ Không thể kiểm tra trạng thái Bảo vệ thời gian thực: $($_.Exception.Message)"
                        $success = "Skip" # Không thể kiểm tra
                    }
                }
                "EnablePUAProtection" {
                    try {
                        Write-Log "Đang kiểm tra và bật Bảo vệ chống PUA/PUP..."
                        # Giá trị PUAProtection: 0=Off, 1=On, 2=AuditMode
                        $CurrentPUAState = Get-MpPreference -ErrorAction Stop | Select-Object -ExpandProperty PUAProtection
                        Write-Log "Trạng thái bảo vệ PUA hiện tại: $CurrentPUAState"
                        if ($CurrentPUAState -eq 0) { # Chỉ bật nếu đang là 0 (Off)
                            Set-MpPreference -PUAProtection Enabled -ErrorAction Stop
                            Write-Log "✅ Đã bật bảo vệ chống PUA/PUP (Mode: Enabled)."
                        } else {
                            Write-Log "ℹ️ Bảo vệ chống PUA/PUP đã được bật (Mode: $CurrentPUAState) hoặc đang ở chế độ Audit."
                            $success = "Skip" # Không thay đổi
                        }
                    } catch {
                        Write-Log "❌ Lỗi khi kiểm tra/bật bảo vệ PUA: $($_.Exception.Message)"
                        $success = $false # Đánh dấu là lỗi
                    }
                }
                "RunFullScan" {
                    try {
                        Write-Log "Chuẩn bị chạy Quét Toàn bộ hệ thống..."
                        $confirmScan = [System.Windows.Forms.MessageBox]::Show(
                            "Quét toàn bộ hệ thống bằng Windows Defender có thể mất RẤT NHIỀU THỜI GIAN (vài giờ hoặc hơn)." + "`n" +
                            "Tiến trình quét sẽ chạy trong nền và bạn có thể theo dõi trong Windows Security." + "`n`n" +
                            "Bạn có muốn bắt đầu quét không?",
                            "Xác nhận Quét Toàn bộ",
                            [System.Windows.Forms.MessageBoxButtons]::YesNo,
                            [System.Windows.Forms.MessageBoxIcon]::Warning
                        )

                        if ($confirmScan -eq [System.Windows.Forms.DialogResult]::Yes) {
                            Write-Log "Đang yêu cầu Windows Defender bắt đầu Quét Toàn bộ..."
                            Start-MpScan -ScanType FullScan -AsJob -ErrorAction Stop
                            Write-Log "✅ Quét Toàn bộ hệ thống đã được bắt đầu trong nền."
                        } else {
                            Write-Log "ℹ️ Đã hủy Quét Toàn bộ hệ thống."
                            $success = "Skip"
                        }
                    } catch {
                        Write-Log "❌ Không thể bắt đầu quét toàn bộ: $($_.Exception.Message)"
                        $success = $false
                    }
                }
                # --- Quyền riêng tư ---
                "DisableMicrophone" {
                    Write-Log "ℹ️ Việc tắt Micro cần thực hiện trong Device Manager để không ảnh hưởng đến phần cứng."
                    Start-Process "ms-settings:privacy-microphone"
                    Write-Log "✅ Đã mở cài đặt quyền riêng tư Microphone. Bạn có thể kiểm soát quyền truy cập cho từng ứng dụng ở đây."
                    $success = "Skip"
                }
                "DisableCamera" {
                    Write-Log "ℹ️ Việc tắt Camera cần thực hiện trong Device Manager để không ảnh hưởng đến phần cứng."
                    Start-Process "ms-settings:privacy-webcam"
                    Write-Log "✅ Đã mở cài đặt quyền riêng tư Camera. Bạn có thể kiểm soát quyền truy cập cho từng ứng dụng ở đây."
                    $success = "Skip"
                }
                "DisableAdvertisingID" {
                    try {
                        $adPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo"
                        if (-not (Test-Path $adPath)) { New-Item -Path $adPath -Force | Out-Null }
                        Set-ItemProperty -Path $adPath -Name "Enabled" -Value 0 -Type DWORD -Force -ErrorAction Stop
                        Write-Log "✅ Đã vô hiệu hóa ID Quảng cáo."
                    } catch {
                        Write-Log "❌ Không thể vô hiệu hóa ID Quảng cáo: $($_.Exception.Message)"
                        $success = $false
                    }
                }
                "DisableTelemetryServices" {
                    try {
                        $telemetryServices = @("DiagTrack", "dmwappushservice")
                        foreach ($service in $telemetryServices) {
                            if (Get-Service -Name $service -ErrorAction SilentlyContinue) {
                                Stop-Service -Name $service -Force -ErrorAction Stop
                                Set-Service -Name $service -StartupType Disabled -ErrorAction Stop
                                Write-Log "✅ Đã vô hiệu hóa dịch vụ telemetry: $service"
                            }
                        }
                        
                        # Vô hiệu hóa task thu thập dữ liệu
                        $tasks = @(
                            "Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
                            "Microsoft\Windows\Application Experience\ProgramDataUpdater",
                            "Microsoft\Windows\Autochk\Proxy",
                            "Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
                            "Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
                            "Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector"
                        )
                        
                        foreach ($task in $tasks) {
                            $taskObj = Get-ScheduledTask -TaskName $task.Split('\')[-1] -TaskPath ($task | Split-Path) -ErrorAction SilentlyContinue
                            if ($taskObj) {
                                Disable-ScheduledTask -InputObject $taskObj -ErrorAction Stop | Out-Null
                                Write-Log "✅ Đã vô hiệu hóa task telemetry: $task"
                            }
                        }
                    } catch {
                        Write-Log "❌ Không thể vô hiệu hóa Telemetry: $($_.Exception.Message)"
                        $success = $false
                    }
                }
                "ClearActivityHistory" {
                    try {
                        # Xóa Activity History
                        $actvPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
                        if (-not (Test-Path $actvPath)) { New-Item -Path $actvPath -Force | Out-Null }
                        Set-ItemProperty -Path $actvPath -Name "EnableActivityFeed" -Value 0 -Type DWORD -Force -ErrorAction Stop
                        Set-ItemProperty -Path $actvPath -Name "PublishUserActivities" -Value 0 -Type DWORD -Force -ErrorAction Stop
                        Set-ItemProperty -Path $actvPath -Name "UploadUserActivities" -Value 0 -Type DWORD -Force -ErrorAction Stop
                        Write-Log "✅ Đã xóa và vô hiệu hóa Activity History."
                    } catch {
                        Write-Log "❌ Không thể xóa Activity History: $($_.Exception.Message)"
                        $success = $false
                    }
                }
                "DisableCloudClipboard" {
                    try {
                        $clipboardPath = "HKCU:\Software\Microsoft\Clipboard"
                        if (-not (Test-Path $clipboardPath)) { New-Item -Path $clipboardPath -Force | Out-Null }
                        Set-ItemProperty -Path $clipboardPath -Name "EnableClipboardHistory" -Value 0 -Type DWORD -Force -ErrorAction Stop
                        Set-ItemProperty -Path $clipboardPath -Name "CloudClipboardAutomaticUpload" -Value 0 -Type DWORD -Force -ErrorAction Stop
                        Write-Log "✅ Đã vô hiệu hóa Cloud Clipboard."
                    } catch {
                        Write-Log "❌ Không thể vô hiệu hóa Cloud Clipboard: $($_.Exception.Message)"
                        $success = $false
                    }
                }
                "DisableLocationTracking" {
                    try {
                        # Đã xử lý trong LocationTracking
                        if ($selectedTasks.ContainsKey("LocationTracking")) {
                            Write-Log "ℹ️ Tracking vị trí đã được xử lý trong phần Bảo mật."
                            $success = "Skip"
                        } else {
                            # Logic để tắt location tracking giống như tác vụ LocationTracking
                            $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location"
                            if (Test-Path $registryPath) {
                                Set-ItemProperty -Path $registryPath -Name "Value" -Value "Deny" -Type String -Force -ErrorAction Stop
                            }
                            
                            # Tắt dịch vụ vị trí
                            if (Get-Service -Name "lfsvc" -ErrorAction SilentlyContinue) {
                                Set-Service -Name "lfsvc" -StartupType Disabled -ErrorAction Stop
                                Stop-Service -Name "lfsvc" -Force -ErrorAction SilentlyContinue
                            }
                            Write-Log "✅ Đã vô hiệu hóa dịch vụ vị trí."
                        }
                    } catch {
                        Write-Log "❌ Không thể vô hiệu hóa theo dõi vị trí: $($_.Exception.Message)"
                        $success = $false
                    }
                }
                default {
                    Write-Log "⚠️ Tác vụ $key không được xử lý."
                    $success = "Skip"
                }
            }
        } catch {
            Write-Log "❌ Lỗi không xác định khi chạy tác vụ ${taskText}: $($_.Exception.Message)" -color [System.Drawing.Color]::Red
            $success = $false
        }
        
        # Ghi lại tình trạng tác vụ
        if ($success -eq "Skip") { $skippedTasks += $taskText }
        elseif ($success -eq $false) { $failedTasks += $taskText }
		else { $successTasks += $taskText }
		}
		

    # Ẩn progress bar phụ khi hoàn tất
    $form.Invoke([Action]{
        $subProgressBar.Visible = $false
        $currentTaskLabel.Text = ""
    })

    # Tổng kết các tác vụ
    if ($skippedTasks.Count -gt 0) {
        Write-Log "Tác vụ bị bỏ qua: $($skippedTasks -join ', ')" -color [System.Drawing.Color]::Orange
    }
    if ($failedTasks.Count -gt 0) {
        Write-Log "Tác vụ lỗi: $($failedTasks -join ', ')" -color [System.Drawing.Color]::Red
    }
    if ($successTasks.Count -gt 0) {  # THÊM ĐOẠN NÀY
        Write-Log "Tác vụ thành công: $($successTasks -join ', ')" -color [System.Drawing.Color]::Green
    }

    # Thêm tham số -color cho các Write-Log và thêm colors cho kết quả
    Write-Log "`nKết quả dọn dẹp:" -color [System.Drawing.Color]::Blue
    foreach ($disk in $diskInfoBefore) {
        $diskAfter = $diskInfoAfter | Where-Object { $_.DeviceID -eq $disk.DeviceID }
        if ($diskAfter) {
            $freed = [math]::Round($diskAfter.'FreeSpace(GB)' - $disk.'FreeSpace(GB)', 2)
            $sign = if ($freed -ge 0) { "+" } else { "" }
            $color = if ($freed -gt 0) { [System.Drawing.Color]::Green } 
                     elseif ($freed -lt 0) { [System.Drawing.Color]::Red } 
                     else { [System.Drawing.Color]::Black }
            Write-Log "  Ổ đĩa $($disk.DeviceID): ${sign}${freed} GB (từ $($disk.'FreeSpace(GB)') GB đến $($diskAfter.'FreeSpace(GB)') GB)" -color $color
        }
    }
    
    Write-Log "`nHoàn tất quá trình dọn dẹp!" -color [System.Drawing.Color]::Blue
    $form.Invoke([Action]{
        $startButton.Enabled = $true
        $cancelButton.Enabled = $false
    })
}

# Gán sự kiện cho nút Bắt đầu
$startButton.Add_Click({ Start-Cleanup })

# Gán sự kiện cho nút Hủy (có thể thêm chức năng dừng tiến trình nếu cần)
$cancelButton.Add_Click({
    Write-Log "⚠️ Đã yêu cầu hủy tiến trình dọn dẹp."
    # Thêm code để dừng tiến trình dọn dẹp nếu cần
    $form.Invoke([Action]{
        $startButton.Enabled = $true
        $cancelButton.Enabled = $false
    })
})

# Hiển thị form và bắt đầu chạy ứng dụng
Write-Log "Ứng dụng đã sẵn sàng. Vui lòng chọn các tác vụ và nhấn nút Bắt đầu dọn dẹp."
[void]$form.ShowDialog()
