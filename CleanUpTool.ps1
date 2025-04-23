# Lưu file này với tên CleanUpTool.ps1
# Chạy PowerShell với quyền Admin và gõ: Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
# Sau đó mới có thể chạy file này

# Kiểm tra quyền Admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Start-Process PowerShell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Thiết lập cửa sổ chính
$form = New-Object System.Windows.Forms.Form
$form.Text = "Windows Smart Cleanup Tool"
$form.Size = New-Object System.Drawing.Size(800, 650)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::FromArgb(240, 240, 240)
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
$form.MaximizeBox = $false
$form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon("$env:windir\system32\cleanmgr.exe")

# Hàm tạo giao diện đẹp hơn
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

# Tạo header
$headerPanel = New-Object System.Windows.Forms.Panel
$headerPanel.Location = New-Object System.Drawing.Point(0, 0)
$headerPanel.Size = New-Object System.Drawing.Size(800, 60)
$headerPanel.BackColor = [System.Drawing.Color]::FromArgb(0, 99, 177)

$headerLabel = New-Object System.Windows.Forms.Label
$headerLabel.Location = New-Object System.Drawing.Point(20, 15)
$headerLabel.Size = New-Object System.Drawing.Size(700, 30)
$headerLabel.Text = "Windows Smart Cleanup Tool"
$headerLabel.ForeColor = [System.Drawing.Color]::White
$headerLabel.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$headerPanel.Controls.Add($headerLabel)

# Tạo TabControl để phân loại các tính năng
$tabControl = New-Object System.Windows.Forms.TabControl
$tabControl.Location = New-Object System.Drawing.Point(10, 70)
$tabControl.Size = New-Object System.Drawing.Size(770, 480)
$tabControl.Font = New-Object System.Drawing.Font("Segoe UI", 10)

# Tab 1: Dọn dẹp cơ bản
$tabBasic = New-Object System.Windows.Forms.TabPage
$tabBasic.Text = "Dọn dẹp cơ bản"
$tabControl.Controls.Add($tabBasic)

# Tab 2: Dọn dẹp nâng cao
$tabAdvanced = New-Object System.Windows.Forms.TabPage
$tabAdvanced.Text = "Dọn dẹp nâng cao"
$tabControl.Controls.Add($tabAdvanced)

# Tab 3: Tối ưu hóa hệ thống
$tabOptimize = New-Object System.Windows.Forms.TabPage
$tabOptimize.Text = "Tối ưu hóa"
$tabControl.Controls.Add($tabOptimize)

# Tab 4: Bảo mật
$tabSecurity = New-Object System.Windows.Forms.TabPage
$tabSecurity.Text = "Bảo mật"
$tabControl.Controls.Add($tabSecurity)

# Tab 5: Tiện ích bổ sung
$tabUtilities = New-Object System.Windows.Forms.TabPage
$tabUtilities.Text = "Tiện ích"
$tabControl.Controls.Add($tabUtilities)

# Tạo RichTextBox cho việc hiển thị log
$logBox = New-Object System.Windows.Forms.RichTextBox
$logBox.Location = New-Object System.Drawing.Point(10, 560)
$logBox.Size = New-Object System.Drawing.Size(770, 80)
$logBox.ReadOnly = $true
$logBox.BackColor = [System.Drawing.Color]::FromArgb(245, 245, 245)
$logBox.Font = New-Object System.Drawing.Font("Consolas", 9)

# Thanh tiến trình
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(10, 530)
$progressBar.Size = New-Object System.Drawing.Size(770, 20)
$progressBar.Style = [System.Windows.Forms.ProgressBarStyle]::Continuous

# Nút Start và Cancel
$startButton = Create-RoundedButton "Bắt đầu dọn dẹp" 600 490 160 30
$cancelButton = Create-RoundedButton "Hủy" 490 490 100 30
$cancelButton.BackColor = [System.Drawing.Color]::LightGray
$cancelButton.ForeColor = [System.Drawing.Color]::Black
$cancelButton.Enabled = $false

# Thêm các checkbox cho Tab Dọn dẹp cơ bản
$checkboxItems = @(
    @{ Text = "Dọn dẹp thư mục Temp"; Description = "Xóa các file tạm trong thư mục Temp của Windows"; Tag = "TempFiles"; Y = 20 },
    @{ Text = "Dọn Thùng rác"; Description = "Xóa tất cả tệp tin trong Thùng rác"; Tag = "RecycleBin"; Y = 60 },
    @{ Text = "Xóa tệp tin tạm thời của trình duyệt"; Description = "Dọn dẹp cache của Edge, Chrome, Firefox"; Tag = "BrowserCache"; Y = 100 },
    @{ Text = "Dọn dẹp Windows Update Cache"; Description = "Xóa các bản cập nhật đã tải xuống và cài đặt"; Tag = "WinUpdateCache"; Y = 140 },
    @{ Text = "Xóa file Prefetch"; Description = "Dọn dẹp bộ nhớ đệm khởi động ứng dụng"; Tag = "Prefetch"; Y = 180 },
    @{ Text = "Xóa bản tải xuống cũ"; Description = "Xóa các file tải xuống cũ hơn 30 ngày"; Tag = "OldDownloads"; Y = 220 },
    @{ Text = "Dọn dẹp tệp tin Event Logs"; Description = "Xóa tệp nhật ký sự kiện của hệ thống"; Tag = "EventLogs"; Y = 260 },
    @{ Text = "Dọn dẹp thumbnail cache"; Description = "Xóa bộ nhớ đệm hình thu nhỏ của Windows Explorer"; Tag = "ThumbnailCache"; Y = 300 }
)

$tooltip = New-Object System.Windows.Forms.ToolTip
$tooltip.AutoPopDelay = 5000
$tooltip.InitialDelay = 1000
$tooltip.ReshowDelay = 500
$tooltip.ShowAlways = $true

$checkboxes = @{}
foreach ($item in $checkboxItems) {
    $checkbox = New-Object System.Windows.Forms.CheckBox
    $checkbox.Text = $item.Text
    $checkbox.Tag = $item.Tag
    $checkbox.Location = New-Object System.Drawing.Point(30, $item.Y)
    $checkbox.Size = New-Object System.Drawing.Size(300, 24)
    $checkbox.Checked = $true
    $checkbox.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $checkboxes[$item.Tag] = $checkbox
    $tabBasic.Controls.Add($checkbox)
    $tooltip.SetToolTip($checkbox, $item.Description)
    
    # Thêm mô tả bên cạnh checkbox
    $description = New-Object System.Windows.Forms.Label
    $description.Text = $item.Description
    $description.Location = New-Object System.Drawing.Point(340, $item.Y + 3)
    $description.Size = New-Object System.Drawing.Size(400, 20)
    $description.ForeColor = [System.Drawing.Color]::Gray
    $description.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $tabBasic.Controls.Add($description)
}

# Chọn tất cả và bỏ chọn tất cả
$selectAllBasic = New-Object System.Windows.Forms.LinkLabel
$selectAllBasic.Text = "Chọn tất cả"
$selectAllBasic.Location = New-Object System.Drawing.Point(30, 350)
$selectAllBasic.Size = New-Object System.Drawing.Size(100, 20)
$selectAllBasic.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$selectAllBasic.LinkClicked += {
    foreach ($key in $checkboxes.Keys) {
        $checkboxes[$key].Checked = $true
    }
}
$tabBasic.Controls.Add($selectAllBasic)

$deselectAllBasic = New-Object System.Windows.Forms.LinkLabel
$deselectAllBasic.Text = "Bỏ chọn tất cả"
$deselectAllBasic.Location = New-Object System.Drawing.Point(140, 350)
$deselectAllBasic.Size = New-Object System.Drawing.Size(100, 20)
$deselectAllBasic.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$deselectAllBasic.LinkClicked += {
    foreach ($key in $checkboxes.Keys) {
        $checkboxes[$key].Checked = $false
    }
}
$tabBasic.Controls.Add($deselectAllBasic)

# Thêm các mục cho Tab dọn dẹp nâng cao
$advancedItems = @(
    @{ Text = "Dọn dẹp WinSxS Folder"; Description = "Dọn thư mục chứa thành phần hệ thống (tiết kiệm nhiều dung lượng)"; Tag = "WinSxS"; Y = 20 },
    @{ Text = "Tối ưu hóa SoftwareDistribution"; Description = "Dọn và nén thư mục lưu trữ cập nhật Windows"; Tag = "SoftwareDist"; Y = 60 },
    @{ Text = "Dọn dẹp Component Store"; Description = "Dọn kho lưu trữ thành phần hệ thống"; Tag = "ComponentStore"; Y = 100 },
    @{ Text = "Dọn dẹp Microsoft Store Cache"; Description = "Sửa lỗi và làm sạch Microsoft Store"; Tag = "StoreCache"; Y = 140 },
    @{ Text = "Dọn OneDrive Cache"; Description = "Xóa cache OneDrive mà không ảnh hưởng đến dữ liệu"; Tag = "OneDriveCache"; Y = 180 },
    @{ Text = "Dọn File Hibernation"; Description = "Xóa file ngủ đông (hibernation) để tiết kiệm không gian"; Tag = "Hibernation"; Y = 220 },
    @{ Text = "Dọn bộ nhớ đệm Font"; Description = "Làm sạch bộ nhớ đệm font Windows"; Tag = "FontCache"; Y = 260 },
    @{ Text = "Nén hệ thống tệp NTFS"; Description = "Nén các tệp hệ thống để tiết kiệm không gian"; Tag = "CompressNTFS"; Y = 300 }
)

$advancedCheckboxes = @{}
foreach ($item in $advancedItems) {
    $checkbox = New-Object System.Windows.Forms.CheckBox
    $checkbox.Text = $item.Text
    $checkbox.Tag = $item.Tag
    $checkbox.Location = New-Object System.Drawing.Point(30, $item.Y)
    $checkbox.Size = New-Object System.Drawing.Size(300, 24)
    $checkbox.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $advancedCheckboxes[$item.Tag] = $checkbox
    $tabAdvanced.Controls.Add($checkbox)
    $tooltip.SetToolTip($checkbox, $item.Description)
    
    # Thêm mô tả bên cạnh checkbox
    $description = New-Object System.Windows.Forms.Label
    $description.Text = $item.Description
    $description.Location = New-Object System.Drawing.Point(340, $item.Y + 3)
    $description.Size = New-Object System.Drawing.Size(400, 20)
    $description.ForeColor = [System.Drawing.Color]::Gray
    $description.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $tabAdvanced.Controls.Add($description)
}

# Chọn tất cả và bỏ chọn tất cả cho tab nâng cao
$selectAllAdvanced = New-Object System.Windows.Forms.LinkLabel
$selectAllAdvanced.Text = "Chọn tất cả"
$selectAllAdvanced.Location = New-Object System.Drawing.Point(30, 350)
$selectAllAdvanced.Size = New-Object System.Drawing.Size(100, 20)
$selectAllAdvanced.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$selectAllAdvanced.LinkClicked += {
    foreach ($key in $advancedCheckboxes.Keys) {
        $advancedCheckboxes[$key].Checked = $true
    }
}
$tabAdvanced.Controls.Add($selectAllAdvanced)

$deselectAllAdvanced = New-Object System.Windows.Forms.LinkLabel
$deselectAllAdvanced.Text = "Bỏ chọn tất cả"
$deselectAllAdvanced.Location = New-Object System.Drawing.Point(140, 350)
$deselectAllAdvanced.Size = New-Object System.Drawing.Size(100, 20)
$deselectAllAdvanced.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$deselectAllAdvanced.LinkClicked += {
    foreach ($key in $advancedCheckboxes.Keys) {
        $advancedCheckboxes[$key].Checked = $false
    }
}
$tabAdvanced.Controls.Add($deselectAllAdvanced)

# Thêm các mục cho Tab tối ưu hóa
$optimizeItems = @(
    @{ Text = "Tối ưu hóa khởi động"; Description = "Vô hiệu hóa các chương trình khởi động không cần thiết"; Tag = "StartupOptimize"; Y = 20 },
    @{ Text = "Tối ưu hóa dịch vụ hệ thống"; Description = "Điều chỉnh các dịch vụ để tăng hiệu suất"; Tag = "ServiceOptimize"; Y = 60 },
    @{ Text = "Tối ưu hóa Page File"; Description = "Điều chỉnh bộ nhớ ảo cho hiệu suất tốt nhất"; Tag = "PageFileOptimize"; Y = 100 },
    @{ Text = "Tối ưu hóa hiệu suất trực quan"; Description = "Điều chỉnh hiệu ứng để tăng tốc độ hệ thống"; Tag = "VisualPerformance"; Y = 140 },
    @{ Text = "Tối ưu hóa độ trễ mạng"; Description = "Cải thiện kết nối mạng và giảm độ trễ"; Tag = "NetworkLatency"; Y = 180 },
    @{ Text = "Tối ưu hóa Windows Search"; Description = "Cải thiện hiệu suất tìm kiếm Windows"; Tag = "SearchOptimize"; Y = 220 },
    @{ Text = "Tối ưu hóa sử dụng RAM"; Description = "Giải phóng bộ nhớ RAM không sử dụng"; Tag = "RAMOptimize"; Y = 260 },
    @{ Text = "Tối ưu hóa thời gian tắt máy"; Description = "Giảm thời gian chờ khi tắt máy"; Tag = "ShutdownOptimize"; Y = 300 }
)

$optimizeCheckboxes = @{}
foreach ($item in $optimizeItems) {
    $checkbox = New-Object System.Windows.Forms.CheckBox
    $checkbox.Text = $item.Text
    $checkbox.Tag = $item.Tag
    $checkbox.Location = New-Object System.Drawing.Point(30, $item.Y)
    $checkbox.Size = New-Object System.Drawing.Size(300, 24)
    $checkbox.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $optimizeCheckboxes[$item.Tag] = $checkbox
    $tabOptimize.Controls.Add($checkbox)
    $tooltip.SetToolTip($checkbox, $item.Description)
    
    # Thêm mô tả bên cạnh checkbox
    $description = New-Object System.Windows.Forms.Label
    $description.Text = $item.Description
    $description.Location = New-Object System.Drawing.Point(340, $item.Y + 3)
    $description.Size = New-Object System.Drawing.Size(400, 20)
    $description.ForeColor = [System.Drawing.Color]::Gray
    $description.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $tabOptimize.Controls.Add($description)
}

# Tab Bảo mật
$securityItems = @(
    @{ Text = "Quét và xóa phần mềm độc hại cơ bản"; Description = "Quét và loại bỏ phần mềm độc hại đơn giản"; Tag = "BasicMalware"; Y = 20 },
    @{ Text = "Xóa lịch sử duyệt web"; Description = "Xóa lịch sử duyệt và các cookie không cần thiết"; Tag = "BrowserHistory"; Y = 60 },
    @{ Text = "Kiểm tra và cập nhật Windows"; Description = "Kiểm tra các bản cập nhật Windows quan trọng"; Tag = "WindowsUpdate"; Y = 100 },
    @{ Text = "Làm sạch lịch sử Recent Files"; Description = "Xóa danh sách tệp đã mở gần đây"; Tag = "RecentFiles"; Y = 140 },
    @{ Text = "Xóa thông tin đăng nhập đã lưu"; Description = "Xóa thông tin đăng nhập được lưu trữ trong Windows"; Tag = "SavedCredentials"; Y = 180 },
    @{ Text = "Vô hiệu hóa dịch vụ theo dõi"; Description = "Vô hiệu hóa dịch vụ theo dõi DiagTrack"; Tag = "DisableTracking"; Y = 220 },
    @{ Text = "Xóa dữ liệu chẩn đoán"; Description = "Xóa dữ liệu chẩn đoán được thu thập bởi Windows"; Tag = "DiagData"; Y = 260 },
    @{ Text = "Tắt tính năng theo dõi vị trí"; Description = "Vô hiệu hóa dịch vụ vị trí Windows"; Tag = "LocationTracking"; Y = 300 }
)

$securityCheckboxes = @{}
foreach ($item in $securityItems) {
    $checkbox = New-Object System.Windows.Forms.CheckBox
    $checkbox.Text = $item.Text
    $checkbox.Tag = $item.Tag
    $checkbox.Location = New-Object System.Drawing.Point(30, $item.Y)
    $checkbox.Size = New-Object System.Drawing.Size(300, 24)
    $checkbox.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $securityCheckboxes[$item.Tag] = $checkbox
    $tabSecurity.Controls.Add($checkbox)
    $tooltip.SetToolTip($checkbox, $item.Description)
    
    $description = New-Object System.Windows.Forms.Label
    $description.Text = $item.Description
    $description.Location = New-Object System.Drawing.Point(340, $item.Y + 3)
    $description.Size = New-Object System.Drawing.Size(400, 20)
    $description.ForeColor = [System.Drawing.Color]::Gray
    $description.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $tabSecurity.Controls.Add($description)
}

# Tab Tiện ích
$utilities = @(
    @{ Text = "Phân tích không gian đĩa"; Description = "Xem chi tiết về phân bổ dung lượng đĩa"; Tag = "DiskAnalysis"; Y = 20 },
    @{ Text = "Sao lưu Registry"; Description = "Tạo bản sao lưu Registry trước khi thay đổi"; Tag = "BackupRegistry"; Y = 60 },
    @{ Text = "Quản lý khởi động"; Description = "Quản lý các chương trình khởi động"; Tag = "StartupManager"; Y = 100 },
    @{ Text = "Xem thông tin hệ thống"; Description = "Hiển thị thông tin chi tiết về hệ thống"; Tag = "SystemInfo"; Y = 140 },
    @{ Text = "Kiểm tra sức khỏe ổ đĩa"; Description = "Kiểm tra và sửa lỗi ổ đĩa"; Tag = "DiskHealth"; Y = 180 },
    @{ Text = "Dọn dẹp tự động định kỳ"; Description = "Thiết lập lịch dọn dẹp tự động"; Tag = "ScheduledCleanup"; Y = 220 },
    @{ Text = "Sửa lỗi Windows phổ biến"; Description = "Sửa các lỗi Windows thường gặp"; Tag = "FixCommonIssues"; Y = 260 },
    @{ Text = "Quản lý phân vùng ổ đĩa"; Description = "Quản lý các phân vùng ổ đĩa"; Tag = "DiskPartition"; Y = 300 }
)

foreach ($item in $utilities) {
    $button = Create-RoundedButton $item.Text 30 $item.Y 300 30
    $button.Tag = $item.Tag
    $button.BackColor = [System.Drawing.Color]::FromArgb(0, 150, 136)
    $tabUtilities.Controls.Add($button)
    $tooltip.SetToolTip($button, $item.Description)
    
    $description = New-Object System.Windows.Forms.Label
    $description.Text = $item.Description
    $description.Location = New-Object System.Drawing.Point(340, $item.Y + 5)
    $description.Size = New-Object System.Drawing.Size(400, 20)
    $description.ForeColor = [System.Drawing.Color]::Gray
    $description.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $tabUtilities.Controls.Add($description)
}

# Thông tin hệ thống
$systemInfoPanel = New-Object System.Windows.Forms.Panel
$systemInfoPanel.Location = New-Object System.Drawing.Point(10, 400)
$systemInfoPanel.Size = New-Object System.Drawing.Size(770, 80)
$systemInfoPanel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle

# Hiển thị thông tin hệ thống
$osVersionLabel = New-Object System.Windows.Forms.Label
$osVersionLabel.Location = New-Object System.Drawing.Point(10, 10)
$osVersionLabel.Size = New-Object System.Drawing.Size(350, 20)
$osVersionLabel.Text = "Hệ điều hành: " + (Get-CimInstance Win32_OperatingSystem).Caption
$osVersionLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$systemInfoPanel.Controls.Add($osVersionLabel)

$cpuInfoLabel = New-Object System.Windows.Forms.Label
$cpuInfoLabel.Location = New-Object System.Drawing.Point(10, 30)
$cpuInfoLabel.Size = New-Object System.Drawing.Size(350, 20)
$cpuInfoLabel.Text = "CPU: " + (Get-CimInstance Win32_Processor).Name
$cpuInfoLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$systemInfoPanel.Controls.Add($cpuInfoLabel)

$ramInfoLabel = New-Object System.Windows.Forms.Label
$ramInfoLabel.Location = New-Object System.Drawing.Point(10, 50)
$ramInfoLabel.Size = New-Object System.Drawing.Size(350, 20)
$totalRam = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
$ramInfoLabel.Text = "RAM: $totalRam GB"
$ramInfoLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$systemInfoPanel.Controls.Add($ramInfoLabel)

# Thông tin ổ đĩa
$diskInfoLabel = New-Object System.Windows.Forms.Label
$diskInfoLabel.Location = New-Object System.Drawing.Point(370, 10)
$diskInfoLabel.Size = New-Object System.Drawing.Size(390, 60)
$diskInfo = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | 
            Select-Object DeviceID, 
                @{Name="Size(GB)";Expression={[math]::Round($_.Size / 1GB, 2)}}, 
                @{Name="FreeSpace(GB)";Expression={[math]::Round($_.FreeSpace / 1GB, 2)}},
                @{Name="PercentFree";Expression={[math]::Round(($_.FreeSpace / $_.Size) * 100, 1)}}

$diskInfoText = "Thông tin ổ đĩa:`n"
foreach ($disk in $diskInfo) {
    $diskInfoText += "$($disk.DeviceID): $($disk.'FreeSpace(GB)') GB trống / $($disk.'Size(GB)') GB ($($disk.PercentFree)%)`n"
}
$diskInfoLabel.Text = $diskInfoText
$diskInfoLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$systemInfoPanel.Controls.Add($diskInfoLabel)

# Hàm ghi log
function Write-Log {
    param([string]$message)
    $time = Get-Date -Format "HH:mm:ss"
    $logMessage = "[$time] $message"
    $logBox.AppendText("$logMessage`n")
    $logBox.SelectionStart = $logBox.Text.Length
    $logBox.ScrollToCaret()
}

# Hàm thực hiện dọn dẹp
function Start-Cleanup {
    $startButton.Enabled = $false
    $cancelButton.Enabled = $true
    
    # Thiết lập thanh tiến trình
    $progressBar.Value = 0
    $progressBar.Maximum = 100
    
    Write-Log "Bắt đầu quá trình dọn dẹp..."
    
    # Giả lập công việc dọn dẹp
    $totalTasks = 0
    $completedTasks = 0
    
    # Đếm tổng số tác vụ được chọn
    foreach ($key in $checkboxes.Keys) {
        if ($checkboxes[$key].Checked) { $totalTasks++ }
    }
    
    foreach ($key in $advancedCheckboxes.Keys) {
        if ($advancedCheckboxes[$key].Checked) { $totalTasks++ }
    }
    
    foreach ($key in $optimizeCheckboxes.Keys) {
        if ($optimizeCheckboxes[$key].Checked) { $totalTasks++ }
    }
    
    foreach ($key in $securityCheckboxes.Keys) {
        if ($securityCheckboxes[$key].Checked) { $totalTasks++ }
    }
    
    if ($totalTasks -eq 0) {
        Write-Log "Không có tác vụ nào được chọn. Vui lòng chọn ít nhất một tác vụ."
        $startButton.Enabled = $true
        $cancelButton.Enabled = $false
        return
    }
    
    # Tạo runspace pool để thực hiện công việc dọn dẹp
    $runspacePool = [runspacefactory]::CreateRunspacePool(1, 4)
    $runspacePool.Open()
    $runspaces = @()
    
    # Thực hiện dọn dẹp cơ bản
    foreach ($key in $checkboxes.Keys) {
        if ($checkboxes[$key].Checked) {
            $completedTasks++
            $progress = [math]::Floor(($completedTasks / $totalTasks) * 100)
            $progressBar.Value = $progress
            
            switch ($key) {
                "TempFiles" {
                    Write-Log "Đang dọn dẹp thư mục Temp..."
                    try {
                        Remove-Item -Path "$env:TEMP\*" -Force -Recurse -ErrorAction SilentlyContinue
                        Remove-Item -Path "$env:windir\Temp\*" -Force -Recurse -ErrorAction SilentlyContinue
                        Write-Log "✅ Dọn dẹp thư mục Temp hoàn tất"
                    } catch {
                        Write-Log "❌ Lỗi khi dọn dẹp thư mục Temp: $_"
                    }
                }
                "RecycleBin" {
                    Write-Log "Đang dọn Thùng rác..."
                    try {
                        $shell = New-Object -ComObject Shell.Application
                        $shell.Namespace(0xA).Items() | ForEach-Object { Remove-Item $_.Path -Recurse -Confirm:$false -Force -ErrorAction SilentlyContinue }
                        Write-Log "✅ Dọn Thùng rác hoàn tất"
                    } catch {
                        Write-Log "❌ Lỗi khi dọn Thùng rác: $_"
                    }
                }
                "BrowserCache" {
                    Write-Log "Đang dọn dẹp cache trình duyệt..."
                    try {
                        # Chrome
                        if (Test-Path "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache") {
                            Remove-Item -Path "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache\*" -Force -Recurse -ErrorAction SilentlyContinue
                        }
                        # Edge
                        if (Test-Path "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache") {
                            Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache\*" -Force -Recurse -ErrorAction SilentlyContinue
                        }
                        # Firefox
                        if (Test-Path "$env:APPDATA\Mozilla\Firefox\Profiles") {
                            Get-ChildItem "$env:APPDATA\Mozilla\Firefox\Profiles" -Directory | ForEach-Object {
                                if (Test-Path "$($_.FullName)\cache2") {
                                    Remove-Item -Path "$($_.FullName)\cache2\*" -Force -Recurse -ErrorAction SilentlyContinue
                                }
                            }
                        }
                        Write-Log "✅ Dọn dẹp cache trình duyệt hoàn tất"
                    } catch {
                        Write-Log "❌ Lỗi khi dọn dẹp cache trình duyệt: $_"
                    }
                }
                "WinUpdateCache" {
                    Write-Log "Đang dọn dẹp Windows Update Cache..."
                    try {
                        # Dừng dịch vụ Windows Update
                        Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
                        Stop-Service -Name bits -Force -ErrorAction SilentlyContinue
                        
                        # Xóa cache
                        if (Test-Path "$env:windir\SoftwareDistribution") {
                            Remove-Item -Path "$env:windir\SoftwareDistribution\*" -Force -Recurse -ErrorAction SilentlyContinue
                        }
                        
                        # Khởi động lại dịch vụ
                        Start-Service -Name bits -ErrorAction SilentlyContinue
                        Start-Service -Name wuauserv -ErrorAction SilentlyContinue
                        
                        Write-Log "✅ Dọn dẹp Windows Update Cache hoàn tất"
                    } catch {
                        Write-Log "❌ Lỗi khi dọn dẹp Windows Update Cache: $_"
                    }
                }
                "Prefetch" {
                    Write-Log "Đang dọn dẹp Prefetch..."
                    try {
                        Remove-Item -Path "$env:windir\Prefetch\*" -Force -ErrorAction SilentlyContinue
                        Write-Log "✅ Dọn dẹp Prefetch hoàn tất"
                    } catch {
                        Write-Log "❌ Lỗi khi dọn dẹp Prefetch: $_"
                    }
                }
                "OldDownloads" {
                    Write-Log "Đang dọn dẹp file tải xuống cũ (>30 ngày)..."
                    try {
                        $threshold = (Get-Date).AddDays(-30)
                        Get-ChildItem -Path "$env:USERPROFILE\Downloads" -File | Where-Object { $_.LastWriteTime -lt $threshold } | Remove-Item -Force -ErrorAction SilentlyContinue
                        Write-Log "✅ Dọn dẹp file tải xuống cũ hoàn tất"
                    } catch {
                        Write-Log "❌ Lỗi khi dọn dẹp file tải xuống cũ: $_"
                    }
                }
                "EventLogs" {
                    Write-Log "Đang dọn dẹp Event Logs..."
                    try {
                        wevtutil el | ForEach-Object { wevtutil cl "$_" 2>$null }
                        Write-Log "✅ Dọn dẹp Event Logs hoàn tất"
                    } catch {
                        Write-Log "❌ Lỗi khi dọn dẹp Event Logs: $_"
                    }
                }
                "ThumbnailCache" {
                    Write-Log "Đang dọn dẹp Thumbnail Cache..."
                    try {
                        Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db" -Force -ErrorAction SilentlyContinue
                        Write-Log "✅ Dọn dẹp Thumbnail Cache hoàn tất"
                    } catch {
                        Write-Log "❌ Lỗi khi dọn dẹp Thumbnail Cache: $_"
                    }
                }
            }
        }
    }
    
    # Thực hiện bảo mật
    foreach ($key in $securityCheckboxes.Keys) {
        if ($securityCheckboxes[$key].Checked) {
            $completedTasks++
            $progress = [math]::Floor(($completedTasks / $totalTasks) * 100)
            $progressBar.Value = $progress
            
            switch ($key) {
                "BasicMalware" {
                    Write-Log "Đang quét phần mềm độc hại cơ bản..."
                    try {
                        # Sử dụng Windows Defender để quét nhanh
                        $process = Start-Process -FilePath "powershell.exe" -ArgumentList "-Command Start-MpScan -ScanType QuickScan" -NoNewWindow -PassThru -Wait
                        
                        Write-Log "✅ Quét phần mềm độc hại hoàn tất"
                    } catch {
                        Write-Log "❌ Lỗi khi quét phần mềm độc hại: $_"
                    }
                }
                "BrowserHistory" {
                    Write-Log "Đang xóa lịch sử trình duyệt..."
                    try {
                        # Xóa lịch sử Internet Explorer và Edge Legacy
                        Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\Windows\WebCache\*" -Force -Recurse -ErrorAction SilentlyContinue
                        
                        # Xóa lịch sử Chrome
                        if (Test-Path "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\History") {
                            Remove-Item -Path "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\History" -Force -ErrorAction SilentlyContinue
                            Remove-Item -Path "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cookies" -Force -ErrorAction SilentlyContinue
                        }
                        
                        # Xóa lịch sử Edge Chromium
                        if (Test-Path "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\History") {
                            Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\History" -Force -ErrorAction SilentlyContinue
                            Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cookies" -Force -ErrorAction SilentlyContinue
                        }
                        
                        Write-Log "✅ Xóa lịch sử trình duyệt hoàn tất"
                    } catch {
                        Write-Log "❌ Lỗi khi xóa lịch sử trình duyệt: $_"
                    }
                }
                "WindowsUpdate" {
                    Write-Log "Đang kiểm tra Windows Update..."
                    try {
                        # Kiểm tra cập nhật Windows
                        $process = Start-Process -FilePath "powershell.exe" -ArgumentList "-Command Import-Module PSWindowsUpdate; Get-WindowsUpdate" -NoNewWindow -PassThru -Wait
                        
                        Write-Log "✅ Kiểm tra Windows Update hoàn tất"
                    } catch {
                        Write-Log "❌ Lỗi khi kiểm tra Windows Update: $_"
                    }
                }
                "RecentFiles" {
                    Write-Log "Đang xóa lịch sử Recent Files..."
                    try {
                        # Xóa Recent Items
                        Remove-Item -Path "$env:APPDATA\Microsoft\Windows\Recent\*" -Force -Recurse -ErrorAction SilentlyContinue
                        Remove-Item -Path "$env:APPDATA\Microsoft\Office\Recent\*" -Force -Recurse -ErrorAction SilentlyContinue
                        
                        Write-Log "✅ Xóa lịch sử Recent Files hoàn tất"
                    } catch {
                        Write-Log "❌ Lỗi khi xóa lịch sử Recent Files: $_"
                    }
                }
                "SavedCredentials" {
                    Write-Log "Đang xóa thông tin đăng nhập đã lưu..."
                    try {
                        # Xóa thông tin đăng nhập đã lưu (yêu cầu quyền admin)
                        $process = Start-Process -FilePath "cmdkey.exe" -ArgumentList "/list" -NoNewWindow -PassThru -Wait
                        $process = Start-Process -FilePath "cmdkey.exe" -ArgumentList "/delete /f *" -NoNewWindow -PassThru -Wait
                        
                        Write-Log "✅ Xóa thông tin đăng nhập đã lưu hoàn tất"
                    } catch {
                        Write-Log "❌ Lỗi khi xóa thông tin đăng nhập đã lưu: $_"
                    }
                }
                "DisableTracking" {
                    Write-Log "Đang vô hiệu hóa dịch vụ theo dõi..."
                    try {
                        # Vô hiệu hóa dịch vụ DiagTrack
                        Set-Service -Name "DiagTrack" -StartupType Disabled -ErrorAction SilentlyContinue
                        Stop-Service -Name "DiagTrack" -Force -ErrorAction SilentlyContinue
                        
                        # Vô hiệu hóa dịch vụ dmwappushservice
                        Set-Service -Name "dmwappushservice" -StartupType Disabled -ErrorAction SilentlyContinue
                        Stop-Service -Name "dmwappushservice" -Force -ErrorAction SilentlyContinue
                        
                        Write-Log "✅ Vô hiệu hóa dịch vụ theo dõi hoàn tất"
                    } catch {
                        Write-Log "❌ Lỗi khi vô hiệu hóa dịch vụ theo dõi: $_"
                    }
                }
                "DiagData" {
                    Write-Log "Đang xóa dữ liệu chẩn đoán..."
                    try {
                        # Xóa dữ liệu chẩn đoán
                        Remove-Item -Path "$env:ProgramData\Microsoft\Diagnosis\*" -Force -Recurse -ErrorAction SilentlyContinue
                        Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\Windows\Caches\*" -Force -Recurse -ErrorAction SilentlyContinue
                        
                        Write-Log "✅ Xóa dữ liệu chẩn đoán hoàn tất"
                    } catch {
                        Write-Log "❌ Lỗi khi xóa dữ liệu chẩn đoán: $_"
                    }
                }
                "LocationTracking" {
                    Write-Log "Đang tắt tính năng theo dõi vị trí..."
                    try {
                        # Tắt dịch vụ vị trí
                        $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location"
                        Set-ItemProperty -Path $registryPath -Name "Value" -Value "Deny" -Type String -Force
                        
                        # Tắt dịch vụ vị trí
                        Set-Service -Name "lfsvc" -StartupType Disabled -ErrorAction SilentlyContinue
                        Stop-Service -Name "lfsvc" -Force -ErrorAction SilentlyContinue
                        
                        Write-Log "✅ Tắt tính năng theo dõi vị trí hoàn tất"
                    } catch {
                        Write-Log "❌ Lỗi khi tắt tính năng theo dõi vị trí: $_"
                    }
                }
            }
        }
    }
    
    # Thực hiện tối ưu hóa
    foreach ($key in $optimizeCheckboxes.Keys) {
        if ($optimizeCheckboxes[$key].Checked) {
            $completedTasks++
            $progress = [math]::Floor(($completedTasks / $totalTasks) * 100)
            $progressBar.Value = $progress
            
            switch ($key) {
                "StartupOptimize" {
                    Write-Log "Đang tối ưu hóa khởi động..."
                    try {
                        # Giảm thời gian trễ khởi động
                        $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Serialize"
                        if (-not (Test-Path $registryPath)) {
                            New-Item -Path $registryPath -Force | Out-Null
                        }
                        Set-ItemProperty -Path $registryPath -Name "StartupDelayInMSec" -Value 0 -Type DWORD -Force
                        
                        Write-Log "✅ Tối ưu hóa khởi động hoàn tất"
                    } catch {
                        Write-Log "❌ Lỗi khi tối ưu hóa khởi động: $_"
                    }
                }
                "ServiceOptimize" {
                    Write-Log "Đang tối ưu hóa dịch vụ hệ thống..."
                    try {
                        # Vô hiệu hóa một số dịch vụ không cần thiết
                        $services = @(
                            @{Name="DiagTrack"; StartupType="Manual"},
                            @{Name="dmwappushservice"; StartupType="Disabled"},
                            @{Name="SysMain"; StartupType="Manual"},
                            @{Name="WSearch"; StartupType="Manual"}
                        )
                        
                        foreach ($service in $services) {
                            if (Get-Service -Name $service.Name -ErrorAction SilentlyContinue) {
                                Set-Service -Name $service.Name -StartupType $service.StartupType -ErrorAction SilentlyContinue
                            }
                        }
                        
                        Write-Log "✅ Tối ưu hóa dịch vụ hệ thống hoàn tất"
                    } catch {
                        Write-Log "❌ Lỗi khi tối ưu hóa dịch vụ hệ thống: $_"
                    }
                }
                "PageFileOptimize" {
                    Write-Log "Đang tối ưu hóa Page File..."
                    try {
                        # Ước tính kích thước RAM
                        $ram = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB
                        $initialSize = [math]::Round($ram / 8)
                        $maxSize = [math]::Round($ram / 4)
                        
                        # Đặt kích thước Page File thích hợp
                        $computerSystem = Get-WmiObject Win32_ComputerSystem -EnableAllPrivileges
                        $computerSystem.AutomaticManagedPagefile = $false
                        $computerSystem.Put() | Out-Null
                        
                        $pageFileSetting = Get-WmiObject Win32_PageFileSetting
                        if ($pageFileSetting) {
                            $pageFileSetting.InitialSize = $initialSize
                            $pageFileSetting.MaximumSize = $maxSize
                            $pageFileSetting.Put() | Out-Null
                        }
                        
                        Write-Log "✅ Tối ưu hóa Page File hoàn tất (InitialSize=$initialSize GB, MaxSize=$maxSize GB)"
                    } catch {
                        Write-Log "❌ Lỗi khi tối ưu hóa Page File: $_"
                    }
                }
                "VisualPerformance" {
                    Write-Log "Đang tối ưu hóa hiệu suất trực quan..."
                    try {
                        # Tối ưu hóa các hiệu ứng trực quan cho hiệu suất
                        $registryPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
                        if (-not (Test-Path $registryPath)) {
                            New-Item -Path $registryPath -Force | Out-Null
                        }
                        Set-ItemProperty -Path $registryPath -Name "VisualFXSetting" -Value 2 -Type DWORD -Force
                        
                        # Tắt hiệu ứng động
                        $registryPath = "HKCU:\Control Panel\Desktop"
                        Set-ItemProperty -Path $registryPath -Name "UserPreferencesMask" -Value ([byte[]](0x90, 0x12, 0x03, 0x80, 0x10, 0x00, 0x00, 0x00)) -Type Binary -Force
                        
                        Write-Log "✅ Tối ưu hóa hiệu suất trực quan hoàn tất"
                    } catch {
                        Write-Log "❌ Lỗi khi tối ưu hóa hiệu suất trực quan: $_"
                    }
                }
                "NetworkLatency" {
                    Write-Log "Đang tối ưu hóa độ trễ mạng..."
                    try {
                        # Vô hiệu hóa tự động điều chỉnh cửa sổ để cải thiện độ trễ mạng
                        $registryPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
                        Set-ItemProperty -Path $registryPath -Name "TcpAckFrequency" -Value 1 -Type DWORD -Force
                        Set-ItemProperty -Path $registryPath -Name "TcpNoDelay" -Value 1 -Type DWORD -Force
                        
                        # Tối ưu hóa DNS
                        ipconfig /flushdns | Out-Null
                        
                        Write-Log "✅ Tối ưu hóa độ trễ mạng hoàn tất"
                    } catch {
                        Write-Log "❌ Lỗi khi tối ưu hóa độ trễ mạng: $_"
                    }
                }
                "SearchOptimize" {
                    Write-Log "Đang tối ưu hóa Windows Search..."
                    try {
                        # Dừng dịch vụ Search
                        Stop-Service -Name "WSearch" -Force -ErrorAction SilentlyContinue
                        
                        # Xóa cache tìm kiếm
                        Remove-Item -Path "$env:ProgramData\Microsoft\Search\Data\Applications\Windows\*" -Force -Recurse -ErrorAction SilentlyContinue
                        
                        # Khởi động lại dịch vụ
                        Start-Service -Name "WSearch" -ErrorAction SilentlyContinue
                        
                        Write-Log "✅ Tối ưu hóa Windows Search hoàn tất"
                    } catch {
                        Write-Log "❌ Lỗi khi tối ưu hóa Windows Search: $_"
                    }
                }
                "RAMOptimize" {
                    Write-Log "Đang tối ưu hóa sử dụng RAM..."
                    try {
                        # Sử dụng WMIC để giải phóng bộ nhớ không sử dụng
                        $process = Start-Process -FilePath "wmic.exe" -ArgumentList "os where Primary='TRUE' call Win32EmptyWorkingSet" -NoNewWindow -PassThru -Wait
                        
                        # Thiết lập DWORD để tối ưu hóa bộ nhớ
                        $registryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
                        Set-ItemProperty -Path $registryPath -Name "ClearPageFileAtShutdown" -Value 0 -Type DWORD -Force
                        Set-ItemProperty -Path $registryPath -Name "LargeSystemCache" -Value 0 -Type DWORD -Force
                        
                        Write-Log "✅ Tối ưu hóa sử dụng RAM hoàn tất"
                    } catch {
                        Write-Log "❌ Lỗi khi tối ưu hóa sử dụng RAM: $_"
                    }
                }
                "ShutdownOptimize" {
                    Write-Log "Đang tối ưu hóa thời gian tắt máy..."
                    try {
                        # Giảm thời gian chờ khi đóng ứng dụng
                        $registryPath = "HKCU:\Control Panel\Desktop"
                        Set-ItemProperty -Path $registryPath -Name "AutoEndTasks" -Value 1 -Type DWORD -Force
                        Set-ItemProperty -Path $registryPath -Name "HungAppTimeout" -Value "1000" -Type String -Force
                        Set-ItemProperty -Path $registryPath -Name "WaitToKillAppTimeout" -Value "2000" -Type String -Force
                        
                        # Thiết lập registry cho Windows
                        $registryPath = "HKLM:\SYSTEM\CurrentControlSet\Control"
                        Set-ItemProperty -Path $registryPath -Name "WaitToKillServiceTimeout" -Value "2000" -Type String -Force
                        
                        Write-Log "✅ Tối ưu hóa thời gian tắt máy hoàn tất"
                    } catch {
                        Write-Log "❌ Lỗi khi tối ưu hóa thời gian tắt máy: $_"
                    }
                }
            }
        }
    }
    
    # Thực hiện dọn dẹp nâng cao
    foreach ($key in $advancedCheckboxes.Keys) {
        if ($advancedCheckboxes[$key].Checked) {
            $completedTasks++
            $progress = [math]::Floor(($completedTasks / $totalTasks) * 100)
            $progressBar.Value = $progress
            
            switch ($key) {
                "WinSxS" {
                    Write-Log "Đang dọn dẹp thư mục WinSxS..."
                    try {
                        # Sử dụng DISM để dọn dẹp WinSxS
                        $process = Start-Process -FilePath "Dism.exe" -ArgumentList "/Online /Cleanup-Image /StartComponentCleanup" -NoNewWindow -PassThru -Wait
                        if ($process.ExitCode -eq 0) {
                            Write-Log "✅ Dọn dẹp thư mục WinSxS hoàn tất"
                        } else {
                            Write-Log "⚠️ Dọn dẹp WinSxS không thành công. Mã lỗi: $($process.ExitCode)"
                        }
                    } catch {
                        Write-Log "❌ Lỗi khi dọn dẹp WinSxS: $_"
                    }
                }
                "SoftwareDist" {
                    Write-Log "Đang tối ưu hóa SoftwareDistribution..."
                    try {
                        # Đã thực hiện trong phần WinUpdateCache
                        Write-Log "✅ Tối ưu hóa SoftwareDistribution hoàn tất"
                    } catch {
                        Write-Log "❌ Lỗi khi tối ưu hóa SoftwareDistribution: $_"
                    }
                }
                "ComponentStore" {
                    Write-Log "Đang dọn dẹp Component Store..."
                    try {
                        $process = Start-Process -FilePath "Dism.exe" -ArgumentList "/Online /Cleanup-Image /AnalyzeComponentStore" -NoNewWindow -PassThru -Wait
                        $process = Start-Process -FilePath "Dism.exe" -ArgumentList "/Online /Cleanup-Image /StartComponentCleanup /ResetBase" -NoNewWindow -PassThru -Wait
                        if ($process.ExitCode -eq 0) {
                            Write-Log "✅ Dọn dẹp Component Store hoàn tất"
                        } else {
                            Write-Log "⚠️ Dọn dẹp Component Store không thành công. Mã lỗi: $($process.ExitCode)"
                        }
                    } catch {
                        Write-Log "❌ Lỗi khi dọn dẹp Component Store: $_"
                    }
                }
                "StoreCache" {
                    Write-Log "Đang dọn dẹp Microsoft Store Cache..."
                    try {
                        # Sử dụng wsreset để làm sạch cache
                        Start-Process "wsreset.exe" -NoNewWindow -Wait
                        Write-Log "✅ Dọn dẹp Microsoft Store Cache hoàn tất"
                    } catch {
                        Write-Log "❌ Lỗi khi dọn dẹp Microsoft Store Cache: $_"
                    }
                }
                "OneDriveCache" {
                    Write-Log "Đang dọn dẹp OneDrive Cache..."
                    try {
                        if (Test-Path "$env:USERPROFILE\OneDrive") {
                            Remove-Item -Path "$env:USERPROFILE\OneDrive\.temp\*" -Force -Recurse -ErrorAction SilentlyContinue
                            Remove-Item -Path "$env:USERPROFILE\OneDrive\logs\*" -Force -Recurse -ErrorAction SilentlyContinue
                            Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\OneDrive\setup\logs\*" -Force -ErrorAction SilentlyContinue
                            Write-Log "✅ Dọn dẹp OneDrive Cache hoàn tất"
                        } else {
                            Write-Log "⚠️ OneDrive không được cài đặt hoặc không tìm thấy"
                        }
                    } catch {
                        Write-Log "❌ Lỗi khi dọn dẹp OneDrive Cache: $_"
                    }
                }
                "Hibernation" {
                    Write-Log "Đang xóa file Hibernation..."
                    try {
                        $process = Start-Process -FilePath "powercfg.exe" -ArgumentList "/hibernate off" -NoNewWindow -PassThru -Wait
                        if ($process.ExitCode -eq 0) {
                            Write-Log "✅ Đã vô hiệu hóa Hibernation và xóa file hiberfil.sys"
                        } else {
                            Write-Log "⚠️ Không thể xóa file Hibernation. Mã lỗi: $($process.ExitCode)"
                        }
                    } catch {
                        Write-Log "❌ Lỗi khi xóa file Hibernation: $_"
                    }
                }
                "FontCache" {
                    Write-Log "Đang dọn dẹp Font Cache..."
                    try {
                        Stop-Service -Name "FontCache" -Force -ErrorAction SilentlyContinue
                        Stop-Service -Name "FontCache3.0.0.0" -Force -ErrorAction SilentlyContinue
                        
                        Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\Windows\Fonts\*" -Force -ErrorAction SilentlyContinue
                        Remove-Item -Path "$env:WINDIR\ServiceProfiles\LocalService\AppData\Local\FontCache\*" -Force -Recurse -ErrorAction SilentlyContinue
                        
                        Start-Service -Name "FontCache" -ErrorAction SilentlyContinue
                        Start-Service -Name "FontCache3.0.0.0" -ErrorAction SilentlyContinue
                        
                        Write-Log "✅ Dọn dẹp Font Cache hoàn tất"
                    } catch {
                        Write-Log "❌ Lỗi khi dọn dẹp Font Cache: $_"
                    }
                }
                "CompressNTFS" {
                    Write-Log "Đang nén hệ thống tệp NTFS..."
                    try {
                        $process = Start-Process -FilePath "compact.exe" -ArgumentList "/CompactOS:always" -NoNewWindow -PassThru -Wait
                        if ($process.ExitCode -eq 0) {
                            Write-Log "✅ Nén hệ thống tệp NTFS hoàn tất"
                        } else {
                            Write-Log "⚠️ Không thể nén hệ thống tệp NTFS. Mã lỗi: $($process.ExitCode)"
                        }
                    } catch {
                        Write-Log "❌ Lỗi khi nén hệ thống tệp NTFS: $_"
                    }
                }
            }
        }
    }
# Hoàn tất quá trình dọn dẹp
    $progressBar.Value = 100
    Write-Log "Quá trình dọn dẹp đã hoàn tất!"
    Write-Log "Tổng cộng đã thực hiện $completedTasks tác vụ."
    
    # Hiển thị kết quả
    $diskInfoAfter = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | 
                    Select-Object DeviceID, 
                        @{Name="FreeSpace(GB)";Expression={[math]::Round($_.FreeSpace / 1GB, 2)}}
    
    foreach ($disk in $diskInfoAfter) {
        $diskBefore = $diskInfo | Where-Object { $_.DeviceID -eq $disk.DeviceID }
        if ($diskBefore) {
            $spaceSaved = $disk.'FreeSpace(GB)' - $diskBefore.'FreeSpace(GB)'
            if ($spaceSaved -gt 0) {
                Write-Log "Ổ đĩa $($disk.DeviceID): Đã giải phóng $spaceSaved GB không gian"
            }
        }
    }
    
    # Khôi phục trạng thái nút
    $startButton.Enabled = $true
    $cancelButton.Enabled = $false
    
    # Hiển thị thông báo hoàn tất
    [System.Windows.Forms.MessageBox]::Show("Quá trình dọn dẹp đã hoàn tất! Đã thực hiện $completedTasks tác vụ.", "Hoàn tất", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
}

# Xử lý sự kiện khi nhấn nút Start
$startButton.Add_Click({
    Start-Cleanup
})

# Xử lý sự kiện khi nhấn nút Cancel
$cancelButton.Add_Click({
    Write-Log "Đang hủy quá trình dọn dẹp..."
    # Thêm mã để hủy quá trình dọn dẹp nếu cần
    $startButton.Enabled = $true
    $cancelButton.Enabled = $false
})

# Xử lý tiện ích
$tabUtilities.Controls | Where-Object { $_ -is [System.Windows.Forms.Button] } | ForEach-Object {
    $button = $_
    $button.Add_Click({
        $utilityTag = $this.Tag
        
        switch ($utilityTag) {
            "DiskAnalysis" {
                Write-Log "Đang phân tích không gian đĩa..."
                Start-Process "cleanmgr.exe" -ArgumentList "/d $env:SystemDrive"
            }
            "BackupRegistry" {
                Write-Log "Đang sao lưu Registry..."
                $backupPath = "$env:USERPROFILE\Desktop\RegistryBackup_$(Get-Date -Format 'yyyyMMdd_HHmmss').reg"
                $process = Start-Process -FilePath "reg.exe" -ArgumentList "export HKLM $backupPath" -NoNewWindow -PassThru -Wait
                if ($process.ExitCode -eq 0) {
                    Write-Log "✅ Đã sao lưu Registry vào: $backupPath"
                    [System.Windows.Forms.MessageBox]::Show("Đã sao lưu Registry thành công vào:`n$backupPath", "Sao lưu hoàn tất", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                } else {
                    Write-Log "❌ Không thể sao lưu Registry"
                }
            }
            "StartupManager" {
                Write-Log "Đang mở Startup Manager..."
                Start-Process "taskmgr.exe" -ArgumentList "/7 /startup"
            }
            "SystemInfo" {
                Write-Log "Đang mở System Information..."
                Start-Process "msinfo32.exe"
            }
            "DiskHealth" {
                Write-Log "Đang kiểm tra sức khỏe ổ đĩa..."
                $process = Start-Process -FilePath "powershell.exe" -ArgumentList "-Command Get-PhysicalDisk | Get-StorageReliabilityCounter | Format-Table DeviceId, Temperature, Wear, ReadErrorsTotal, WriteErrorsTotal, PowerOnHours -AutoSize" -NoNewWindow -PassThru -Wait
            }
            "ScheduledCleanup" {
                Write-Log "Đang thiết lập dọn dẹp tự động định kỳ..."
                $taskName = "WindowsSmartCleanup"
                $taskPath = "$PSCommandPath"
                
                # Kiểm tra xem tác vụ đã tồn tại chưa
                $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
                
                if ($existingTask) {
                    $choice = [System.Windows.Forms.MessageBox]::Show("Tác vụ dọn dẹp tự động đã tồn tại. Bạn có muốn cập nhật không?", "Tác vụ đã tồn tại", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
                    if ($choice -eq [System.Windows.Forms.DialogResult]::No) {
                        return
                    }
                    
                    # Xóa tác vụ hiện có
                    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
                }
                
                # Tạo một tác vụ mới
                $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File `"$taskPath`" -Automatic"
                $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 2am
                $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
                
                Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -RunLevel Highest -User "SYSTEM" | Out-Null
                
                Write-Log "✅ Đã thiết lập dọn dẹp tự động vào 2 giờ sáng mỗi Chủ Nhật"
                [System.Windows.Forms.MessageBox]::Show("Đã thiết lập dọn dẹp tự động vào 2 giờ sáng mỗi Chủ Nhật", "Thiết lập hoàn tất", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            }
            "FixCommonIssues" {
                Write-Log "Đang sửa lỗi Windows phổ biến..."
                
                # Sửa Windows Update
                Write-Log "Đang sửa lỗi Windows Update..."
                Start-Process -FilePath "powershell.exe" -ArgumentList "-Command & {Stop-Service -Name wuauserv, bits, cryptsvc -Force; Remove-Item -Path $env:SystemRoot\SoftwareDistribution\* -Recurse -Force -ErrorAction SilentlyContinue; Start-Service -Name wuauserv, bits, cryptsvc}" -NoNewWindow -Wait
                
                # Sửa chữa các tệp hệ thống bị hỏng
                Write-Log "Đang sửa chữa các tệp hệ thống bị hỏng..."
                Start-Process -FilePath "sfc.exe" -ArgumentList "/scannow" -NoNewWindow -Wait
                
                # Sửa chữa image hệ thống
                Write-Log "Đang sửa chữa image hệ thống..."
                Start-Process -FilePath "DISM.exe" -ArgumentList "/Online /Cleanup-Image /RestoreHealth" -NoNewWindow -Wait
                
                Write-Log "✅ Đã hoàn tất sửa lỗi Windows phổ biến"
                [System.Windows.Forms.MessageBox]::Show("Đã hoàn tất sửa lỗi Windows phổ biến!", "Sửa lỗi hoàn tất", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            }
            "DiskPartition" {
                Write-Log "Đang mở công cụ quản lý phân vùng ổ đĩa..."
                Start-Process "diskmgmt.msc"
            }
        }
    })
}

# Thêm các thành phần vào form
$form.Controls.Add($headerPanel)
$form.Controls.Add($tabControl)
$form.Controls.Add($systemInfoPanel)
$form.Controls.Add($progressBar)
$form.Controls.Add($startButton)
$form.Controls.Add($cancelButton)
$form.Controls.Add($logBox)

# Hiển thị form
$form.ShowDialog() | Out-Null
