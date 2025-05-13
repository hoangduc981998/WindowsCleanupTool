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
$form.Text = "Công cụ dọn dẹp hàng Nỏ :))"
$form.Size = New-Object System.Drawing.Size(800, 770)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::FromArgb(240, 240, 240)
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
$form.MaximizeBox = $false
# Sửa lỗi tiềm ẩn nếu cleanmgr.exe không tồn tại hoặc không có icon
try {
    $form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon("$env:windir\system32\cleanmgr.exe")
} catch {
    Write-Warning "Không thể tải icon từ cleanmgr.exe. Sử dụng icon mặc định."
}


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
$headerLabel.Text = "Công cụ dọn dẹp hàng Nỏ :))"
$headerLabel.ForeColor = [System.Drawing.Color]::White
$headerLabel.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$headerPanel.Controls.Add($headerLabel)

# Tạo TabControl để phân loại các tính năng
$tabControl = New-Object System.Windows.Forms.TabControl
$tabControl.Location = New-Object System.Drawing.Point(10, 70)
$tabControl.Size = New-Object System.Drawing.Size(770, 400) # Giảm chiều cao để vừa với panel thông tin hệ thống
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

# Tab 5: Quyền riêng tư
$tabPrivacy = New-Object System.Windows.Forms.TabPage
$tabPrivacy.Text = "Quyền riêng tư"
$tabControl.Controls.Add($tabPrivacy) # Thêm tab mới vào TabControl

# Tab 6: Tiện ích bổ sung
$tabUtilities = New-Object System.Windows.Forms.TabPage
$tabUtilities.Text = "Tiện ích"
$tabControl.Controls.Add($tabUtilities)

# Biến lưu trữ tab đang được chọn để tránh bỏ chọn trong chính nó
$currentSelectedTab = $tabControl.SelectedTab

# Thêm sự kiện khi chuyển tab
$tabControl.Add_SelectedIndexChanged({
    # Lấy tab mới được chọn
    $newSelectedTab = $tabControl.SelectedTab

    # Duyệt qua tất cả các tab
    foreach ($tabPage in $tabControl.TabPages) {
        # Nếu tab này KHÔNG phải là tab mới được chọn
        if ($tabPage -ne $newSelectedTab) {
            # Duyệt qua tất cả các control trong tab không được chọn
            foreach ($control in $tabPage.Controls) {
                # Nếu control là một CheckBox
                if ($control -is [System.Windows.Forms.CheckBox]) {
                    # Bỏ chọn checkbox đó
                    $control.Checked = $false
                }
            }
        }
    }
    # Cập nhật tab hiện tại
    $currentSelectedTab = $newSelectedTab
})

# Panel chứa các nút và progress bar
$controlPanel = New-Object System.Windows.Forms.Panel
$controlPanel.Location = New-Object System.Drawing.Point(10, 555) # Vị trí mới
$controlPanel.Size = New-Object System.Drawing.Size(775, 160)
#$controlPanel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle # Tùy chọn: thêm viền để dễ nhìn

# Tạo RichTextBox cho việc hiển thị log
$logBox = New-Object System.Windows.Forms.RichTextBox
$logBox.Location = New-Object System.Drawing.Point(0, 35) # Vị trí trong controlPanel
$logBox.Size = New-Object System.Drawing.Size(770, 120) # Kích thước mới
$logBox.ReadOnly = $true
$logBox.BackColor = [System.Drawing.Color]::FromArgb(245, 245, 245)
$logBox.Font = New-Object System.Drawing.Font("Consolas", 9)
$controlPanel.Controls.Add($logBox)

# Thanh tiến trình
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(0, 5) # Vị trí trong controlPanel
$progressBar.Size = New-Object System.Drawing.Size(480, 25) # Kích thước mới
$progressBar.Style = [System.Windows.Forms.ProgressBarStyle]::Continuous
$controlPanel.Controls.Add($progressBar)


# Nút Start và Cancel
$startButton = Create-RoundedButton "Bắt đầu dọn dẹp" 600 5 160 25 # Vị trí trong controlPanel
$cancelButton = Create-RoundedButton "Hủy" 490 5 100 25 # Vị trí trong controlPanel
$cancelButton.BackColor = [System.Drawing.Color]::LightGray
$cancelButton.ForeColor = [System.Drawing.Color]::Black
$cancelButton.Enabled = $false
$controlPanel.Controls.Add($startButton)
$controlPanel.Controls.Add($cancelButton)


# Thêm các checkbox cho Tab Dọn dẹp cơ bản
$checkboxItems = @(
    @{ Text = "Dọn dẹp thư mục Temp"; Description = "Xóa các file tạm trong thư mục Temp của Windows"; Tag = "TempFiles"; Y = 20 },
    @{ Text = "Dọn Thùng rác"; Description = "Xóa tất cả tệp tin trong Thùng rác"; Tag = "RecycleBin"; Y = 50 }, # Giảm khoảng cách Y
    @{ Text = "Xóa tệp tin tạm thời của trình duyệt"; Description = "Dọn dẹp cache của Edge, Chrome, Firefox"; Tag = "BrowserCache"; Y = 80 },
    @{ Text = "Dọn dẹp Windows Update Cache"; Description = "Xóa các bản cập nhật đã tải xuống và cài đặt"; Tag = "WinUpdateCache"; Y = 110 },
    @{ Text = "Xóa file Prefetch"; Description = "Dọn dẹp bộ nhớ đệm khởi động ứng dụng"; Tag = "Prefetch"; Y = 140 },
    @{ Text = "Xóa bản tải xuống cũ"; Description = "Xóa các file tải xuống cũ hơn 3 ngày"; Tag = "OldDownloads"; Y = 170 },
    @{ Text = "Dọn dẹp tệp tin Event Logs"; Description = "Xóa tệp nhật ký sự kiện của hệ thống"; Tag = "EventLogs"; Y = 200 },
    @{ Text = "Dọn dẹp thumbnail cache"; Description = "Xóa bộ nhớ đệm hình thu nhỏ của Windows Explorer"; Tag = "ThumbnailCache"; Y = 230 }
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
    $checkbox.Font = New-Object System.Drawing.Font("Segoe UI", 9) # Giảm cỡ font một chút
    $checkboxes[$item.Tag] = $checkbox
    $tabBasic.Controls.Add($checkbox)
    $tooltip.SetToolTip($checkbox, $item.Description)

    # Thêm mô tả bên cạnh checkbox
    $description = New-Object System.Windows.Forms.Label
    $description.Text = $item.Description
    # *** SỬA LỖI POINT ***
    $yCoord = [int]($item.Y + 3)
    $description.Location = New-Object System.Drawing.Point(340, $yCoord)
    # *** KẾT THÚC SỬA LỖI ***
    $description.Size = New-Object System.Drawing.Size(400, 20)
    $description.ForeColor = [System.Drawing.Color]::Gray
    $description.Font = New-Object System.Drawing.Font("Segoe UI", 8) # Giảm cỡ font mô tả
    $tabBasic.Controls.Add($description)
}

# Tạo nút "Chọn tất cả" cho Tab 1 - Dọn dẹp cơ bản
$selectAllBasicButton = New-Object System.Windows.Forms.Button
$selectAllBasicButton.Text = "Chọn tất cả"
$selectAllBasicButton.Size = New-Object System.Drawing.Size(100, 30)
$selectAllBasicButton.Location = New-Object System.Drawing.Point(30, 270)
$selectAllBasicButton.Add_Click({
    foreach ($checkbox in $checkboxes.Values) {
        $checkbox.Checked = $true
    }
})
$tabBasic.Controls.Add($selectAllBasicButton)

# Tạo nút "Bỏ chọn tất cả" cho Tab 1 - Dọn dẹp cơ bản
$deselectAllBasicButton = New-Object System.Windows.Forms.Button
$deselectAllBasicButton.Text = "Bỏ chọn tất cả"
$deselectAllBasicButton.Size = New-Object System.Drawing.Size(100, 30)
$deselectAllBasicButton.Location = New-Object System.Drawing.Point(140, 270)
$deselectAllBasicButton.Add_Click({
    foreach ($checkbox in $checkboxes.Values) {
        $checkbox.Checked = $false
    }
})
$tabBasic.Controls.Add($deselectAllBasicButton)



# Thêm các mục cho Tab dọn dẹp nâng cao
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

$advancedCheckboxes = @{}
foreach ($item in $advancedItems) {
    $checkbox = New-Object System.Windows.Forms.CheckBox
    $checkbox.Text = $item.Text
    $checkbox.Tag = $item.Tag
    $checkbox.Location = New-Object System.Drawing.Point(30, $item.Y)
    $checkbox.Size = New-Object System.Drawing.Size(300, 24)
    $checkbox.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $advancedCheckboxes[$item.Tag] = $checkbox
    $tabAdvanced.Controls.Add($checkbox)
    $tooltip.SetToolTip($checkbox, $item.Description)

    # Thêm mô tả bên cạnh checkbox
    $description = New-Object System.Windows.Forms.Label
    $description.Text = $item.Description
    # *** SỬA LỖI POINT ***
    $yCoord = [int]($item.Y + 3)
    $description.Location = New-Object System.Drawing.Point(340, $yCoord)
    # *** KẾT THÚC SỬA LỖI ***
    $description.Size = New-Object System.Drawing.Size(400, 20)
    $description.ForeColor = [System.Drawing.Color]::Gray
    $description.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    $tabAdvanced.Controls.Add($description)
}

# Tạo nút "Chọn tất cả" cho Tab 2 - Dọn dẹp nâng cao
$selectAllAdvancedButton = New-Object System.Windows.Forms.Button
$selectAllAdvancedButton.Text = "Chọn tất cả"
$selectAllAdvancedButton.Size = New-Object System.Drawing.Size(100, 30)
$selectAllAdvancedButton.Location = New-Object System.Drawing.Point(30, 270)
$selectAllAdvancedButton.Add_Click({
    foreach ($checkbox in $advancedCheckboxes.Values) {
        $checkbox.Checked = $true
    }
})
$tabAdvanced.Controls.Add($selectAllAdvancedButton)

# Tạo nút "Bỏ chọn tất cả" cho Tab 2 - Dọn dẹp nâng cao
$deselectAllAdvancedButton = New-Object System.Windows.Forms.Button
$deselectAllAdvancedButton.Text = "Bỏ chọn tất cả"
$deselectAllAdvancedButton.Size = New-Object System.Drawing.Size(100, 30)
$deselectAllAdvancedButton.Location = New-Object System.Drawing.Point(140, 270)
$deselectAllAdvancedButton.Add_Click({
    foreach ($checkbox in $advancedCheckboxes.Values) {
        $checkbox.Checked = $false
    }
})
$tabAdvanced.Controls.Add($deselectAllAdvancedButton)

# Thêm các mục cho Tab tối ưu hóa
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

$optimizeCheckboxes = @{}
foreach ($item in $optimizeItems) {
    $checkbox = New-Object System.Windows.Forms.CheckBox
    $checkbox.Text = $item.Text
    $checkbox.Tag = $item.Tag
    $checkbox.Location = New-Object System.Drawing.Point(30, $item.Y)
    $checkbox.Size = New-Object System.Drawing.Size(300, 24)
    $checkbox.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $optimizeCheckboxes[$item.Tag] = $checkbox
    $tabOptimize.Controls.Add($checkbox)
    $tooltip.SetToolTip($checkbox, $item.Description)

    # Thêm mô tả bên cạnh checkbox
    $description = New-Object System.Windows.Forms.Label
    $description.Text = $item.Description
    # *** SỬA LỖI POINT ***
    $yCoord = [int]($item.Y + 3)
    $description.Location = New-Object System.Drawing.Point(340, $yCoord)
    # *** KẾT THÚC SỬA LỖI ***
    $description.Size = New-Object System.Drawing.Size(400, 20)
    $description.ForeColor = [System.Drawing.Color]::Gray
    $description.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    $tabOptimize.Controls.Add($description)
}
# Tạo nút "Chọn tất cả"
$selectAllOptimizeButton = New-Object System.Windows.Forms.Button
$selectAllOptimizeButton.Text = "Chọn tất cả"
$selectAllOptimizeButton.Size = New-Object System.Drawing.Size(100, 30)
$selectAllOptimizeButton.Location = New-Object System.Drawing.Point(30, 270)
$selectAllOptimizeButton.Add_Click({
    foreach ($checkbox in $optimizeCheckboxes.Values) {
        $checkbox.Checked = $true
    }
})
$tabOptimize.Controls.Add($selectAllOptimizeButton)

# Tạo nút "Bỏ tất cả"
$deselectAllOptimizeButton = New-Object System.Windows.Forms.Button
$deselectAllOptimizeButton.Text = "Bỏ tất cả"
$deselectAllOptimizeButton.Size = New-Object System.Drawing.Size(100, 30)
$deselectAllOptimizeButton.Location = New-Object System.Drawing.Point(140, 270)
$deselectAllOptimizeButton.Add_Click({
    foreach ($checkbox in $optimizeCheckboxes.Values) {
        $checkbox.Checked = $false
    }
})
$tabOptimize.Controls.Add($deselectAllOptimizeButton)


# Tab Bảo mật
$securityItems = @(
    # --- Các mục cũ - Điều chỉnh lại Y ---
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

$securityCheckboxes = @{}
foreach ($item in $securityItems) {
    $checkbox = New-Object System.Windows.Forms.CheckBox
    $checkbox.Text = $item.Text
    $checkbox.Tag = $item.Tag
    $checkbox.Location = New-Object System.Drawing.Point(30, $item.Y)
    $checkbox.Size = New-Object System.Drawing.Size(300, 24)
    $checkbox.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $securityCheckboxes[$item.Tag] = $checkbox
    $tabSecurity.Controls.Add($checkbox)
    $tooltip.SetToolTip($checkbox, $item.Description)

    $description = New-Object System.Windows.Forms.Label
    $description.Text = $item.Description
    # *** SỬA LỖI POINT ***
    $yCoord = [int]($item.Y + 3)
    $description.Location = New-Object System.Drawing.Point(340, $yCoord)
    # *** KẾT THÚC SỬA LỖI ***
    $description.Size = New-Object System.Drawing.Size(400, 20)
    $description.ForeColor = [System.Drawing.Color]::Gray
    $description.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    $tabSecurity.Controls.Add($description)
}
# Tạo nút "Chọn tất cả" cho tab Bảo mật
$selectAllSecurityButton = New-Object System.Windows.Forms.Button
$selectAllSecurityButton.Text = "Chọn tất cả"
$selectAllSecurityButton.Size = New-Object System.Drawing.Size(100, 30)
$selectAllSecurityButton.Location = New-Object System.Drawing.Point(30, 330)
$selectAllSecurityButton.Add_Click({
    foreach ($checkbox in $securityCheckboxes.Values) {
        $checkbox.Checked = $true
    }
})
$tabSecurity.Controls.Add($selectAllSecurityButton)

# Tạo nút "Bỏ tất cả" cho tab Bảo mật
$deselectAllSecurityButton = New-Object System.Windows.Forms.Button
$deselectAllSecurityButton.Text = "Bỏ tất cả"
$deselectAllSecurityButton.Size = New-Object System.Drawing.Size(100, 30)
$deselectAllSecurityButton.Location = New-Object System.Drawing.Point(140, 330)
$deselectAllSecurityButton.Add_Click({
    foreach ($checkbox in $securityCheckboxes.Values) {
        $checkbox.Checked = $false
    }
})
$tabSecurity.Controls.Add($deselectAllSecurityButton)

# Tab Quyền riêng tư
$privacyItems = @(
    @{ Text = "Tắt Micro (Chống nghe lén)"; Description = "Vô hiệu hóa tất cả thiết bị Micro trong Device Manager"; Tag = "DisableMicrophone"; Y = 20 },
    @{ Text = "Tắt Camera (Chống quay lén)"; Description = "Vô hiệu hóa tất cả thiết bị Camera trong Device Manager"; Tag = "DisableCamera"; Y = 50 },
    @{ Text = "Vô hiệu hóa ID Quảng cáo"; Description = "Ngăn ứng dụng sử dụng ID để theo dõi quảng cáo"; Tag = "DisableAdvertisingID"; Y = 80 },
    @{ Text = "Vô hiệu hóa Telemetry"; Description = "Tắt các dịch vụ thu thập dữ liệu chẩn đoán chính"; Tag = "DisableTelemetryServices"; Y = 110 },
    @{ Text = "Xóa Lịch sử Hoạt động"; Description = "Xóa dữ liệu Activity History được lưu trữ (nếu có)"; Tag = "ClearActivityHistory"; Y = 140 },
    @{ Text = "Tắt Cloud Clipboard"; Description = "Ngăn đồng bộ hóa lịch sử clipboard qua cloud"; Tag = "DisableCloudClipboard"; Y = 170 },
    @{ Text = "Tắt Theo dõi Vị trí"; Description = "Vô hiệu hóa dịch vụ vị trí Windows"; Tag = "DisableLocationTracking"; Y = 200 } # Giữ Tag giống cũ nếu muốn gom logic
    # Bạn có thể thêm các mục khác ở đây
)

$privacyCheckboxes = @{} # Tạo Hashtable riêng cho tab này
# Vòng lặp tạo CheckBox và Label (Tương tự các tab khác, nhưng dùng $tabPrivacy và $privacyCheckboxes)
foreach ($item in $privacyItems) {
    $checkbox = New-Object System.Windows.Forms.CheckBox
    $checkbox.Text = $item.Text
    $checkbox.Tag = $item.Tag
    $checkbox.Location = New-Object System.Drawing.Point(30, $item.Y)
    $checkbox.Size = New-Object System.Drawing.Size(300, 24)
    $checkbox.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $privacyCheckboxes[$item.Tag] = $checkbox
    $tabPrivacy.Controls.Add($checkbox)
    $tooltip.SetToolTip($checkbox, $item.Description)

    # Thêm mô tả bên cạnh checkbox
    $description = New-Object System.Windows.Forms.Label
    $description.Text = $item.Description
    $yCoord = [int]($item.Y + 3)
    $description.Location = New-Object System.Drawing.Point(340, $yCoord)
    $description.Size = New-Object System.Drawing.Size(400, 20)
    $description.ForeColor = [System.Drawing.Color]::Gray
    $description.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    $tabPrivacy.Controls.Add($description)
}

# Tạo nút "Chọn tất cả" cho tab Quyền riêng tư
$selectAllPrivacyButton = New-Object System.Windows.Forms.Button
$selectAllPrivacyButton.Text = "Chọn tất cả"
$selectAllPrivacyButton.Size = New-Object System.Drawing.Size(100, 30)
$selectAllPrivacyButton.Location = New-Object System.Drawing.Point(30, 300)
$selectAllPrivacyButton.Add_Click({
    foreach ($checkbox in $PrivacyCheckboxes.Values) {
        $checkbox.Checked = $true
    }
})
$tabPrivacy.Controls.Add($selectAllPrivacyButton)

# Tạo nút "Bỏ tất cả" cho tab Quyền riêng tư
$deselectAllPrivacyButton = New-Object System.Windows.Forms.Button
$deselectAllPrivacyButton.Text = "Bỏ tất cả"
$deselectAllPrivacyButton.Size = New-Object System.Drawing.Size(100, 30)
$deselectAllPrivacyButton.Location = New-Object System.Drawing.Point(140, 300)
$deselectAllPrivacyButton.Add_Click({
    foreach ($checkbox in $PrivacyCheckboxes.Values) {
        $checkbox.Checked = $false
    }
})
$tabPrivacy.Controls.Add($deselectAllPrivacyButton)

# Thêm nút mở cài đặt Quyền riêng tư
$privacySettingsButton = Create-RoundedButton "Mở Cài đặt Quyền riêng tư Windows" 30 240 300 30 # Điều chỉnh Y
$privacySettingsButton.BackColor = [System.Drawing.Color]::FromArgb(100, 100, 100) # Màu khác
$privacySettingsButton.Add_Click({ Start-Process "ms-settings:privacy" })
$tabPrivacy.Controls.Add($privacySettingsButton)


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

foreach ($item in $utilities) {
    $button = Create-RoundedButton $item.Text 30 $item.Y 280 25 # Giảm width, height
    $button.Tag = $item.Tag
    $button.BackColor = [System.Drawing.Color]::FromArgb(0, 150, 136)
    $tabUtilities.Controls.Add($button)
    $tooltip.SetToolTip($button, $item.Description)

    $description = New-Object System.Windows.Forms.Label
    $description.Text = $item.Description
    # *** SỬA LỖI POINT ***
    $yCoord = [int]($item.Y + 5) # Lưu ý +5 ở đây
    $description.Location = New-Object System.Drawing.Point(340, $yCoord)
    # *** KẾT THÚC SỬA LỖI ***
    $description.Size = New-Object System.Drawing.Size(400, 20)
    $description.ForeColor = [System.Drawing.Color]::Gray
    $description.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    $tabUtilities.Controls.Add($description)
}

# Thông tin hệ thống
$systemInfoPanel = New-Object System.Windows.Forms.Panel
$systemInfoPanel.Location = New-Object System.Drawing.Point(10, 480) # Điều chỉnh vị trí Y
$systemInfoPanel.Size = New-Object System.Drawing.Size(770, 70) # Giảm chiều cao
$systemInfoPanel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$systemInfoPanel.BackColor = [System.Drawing.Color]::FromArgb(230, 230, 230) # Màu nền khác một chút


# Hiển thị thông tin hệ thống
$osVersionLabel = New-Object System.Windows.Forms.Label
$osVersionLabel.Location = New-Object System.Drawing.Point(10, 5) # Điều chỉnh vị trí Y
$osVersionLabel.Size = New-Object System.Drawing.Size(350, 18) # Giảm chiều cao
$osVersionLabel.Text = "Hệ điều hành: " + (Get-CimInstance Win32_OperatingSystem).Caption
$osVersionLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8) # Giảm cỡ font
$systemInfoPanel.Controls.Add($osVersionLabel)

$cpuInfoLabel = New-Object System.Windows.Forms.Label
$cpuInfoLabel.Location = New-Object System.Drawing.Point(10, 25) # Điều chỉnh vị trí Y
$cpuInfoLabel.Size = New-Object System.Drawing.Size(350, 18)
$cpuInfoLabel.Text = "CPU: " + (Get-CimInstance Win32_Processor).Name
$cpuInfoLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$systemInfoPanel.Controls.Add($cpuInfoLabel)

$ramInfoLabel = New-Object System.Windows.Forms.Label
$ramInfoLabel.Location = New-Object System.Drawing.Point(10, 45) # Điều chỉnh vị trí Y
$ramInfoLabel.Size = New-Object System.Drawing.Size(350, 18)
$totalRam = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
$ramInfoLabel.Text = "RAM: $totalRam GB"
$ramInfoLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$systemInfoPanel.Controls.Add($ramInfoLabel)

# Thông tin ổ đĩa
$diskInfoLabel = New-Object System.Windows.Forms.Label
$diskInfoLabel.Location = New-Object System.Drawing.Point(370, 5) # Điều chỉnh vị trí Y
$diskInfoLabel.Size = New-Object System.Drawing.Size(390, 60) # Giảm chiều cao
$diskInfo = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" |
            Select-Object DeviceID,
                @{Name="Size(GB)";Expression={[math]::Round($_.Size / 1GB, 2)}},
                @{Name="FreeSpace(GB)";Expression={[math]::Round($_.FreeSpace / 1GB, 2)}},
                @{Name="PercentFree";Expression={[math]::Round(($_.FreeSpace / $_.Size) * 100, 1)}}

$diskInfoText = "Thông tin ổ đĩa:`n"
foreach ($disk in $diskInfo) {
    $diskInfoText += "$($disk.DeviceID) $($disk.'FreeSpace(GB)') GB trống / $($disk.'Size(GB)') GB ($($disk.PercentFree)%)`n"
}
$diskInfoLabel.Text = $diskInfoText.TrimEnd("`n") # Xóa dấu xuống dòng thừa cuối cùng
$diskInfoLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$systemInfoPanel.Controls.Add($diskInfoLabel)

# Hàm ghi log đã sửa đổi
function Write-Log {
    param([string]$message)
    $time = Get-Date -Format "HH:mm:ss"
    $logMessage = "[$time] $message"

    # Kiểm tra xem logBox đã được tạo và handle đã sẵn sàng chưa
    if ($logBox -ne $null -and $logBox.IsHandleCreated) {
        try {
            # Sử dụng Invoke để cập nhật UI từ thread khác nếu cần
            $logBox.Invoke([Action]{
                $logBox.AppendText("$logMessage`n")
                # Tự động cuộn xuống dòng cuối cùng
                $logBox.SelectionStart = $logBox.Text.Length
                $logBox.ScrollToCaret()
            })
        } catch {
            # Nếu Invoke thất bại (trường hợp hiếm), ghi ra host
            Write-Host "$logMessage (Lỗi khi ghi vào log box: $($_.Exception.Message))"
        }
    } else {
        # Nếu logBox chưa sẵn sàng, ghi ra host console
        Write-Host $logMessage
    }
}
# Hàm thực hiện dọn dẹp
function Start-Cleanup {
    # Khóa nút và bật nút hủy
    $form.Invoke([Action]{
        $startButton.Enabled = $false
        $cancelButton.Enabled = $true
        $progressBar.Value = 0
        $progressBar.Maximum = 100
    })

    Write-Log "Bắt đầu quá trình dọn dẹp..."

    # Lấy danh sách các tác vụ được chọn
    $selectedTasks = @{}
    $checkboxes.Keys | ForEach-Object { if ($checkboxes[$_].Checked) { $selectedTasks[$_] = $checkboxes[$_].Text } }
    $advancedCheckboxes.Keys | ForEach-Object { if ($advancedCheckboxes[$_].Checked) { $selectedTasks[$_] = $advancedCheckboxes[$_].Text } }
    $optimizeCheckboxes.Keys | ForEach-Object { if ($optimizeCheckboxes[$_].Checked) { $selectedTasks[$_] = $optimizeCheckboxes[$_].Text } }
    $securityCheckboxes.Keys | ForEach-Object { if ($securityCheckboxes[$_].Checked) { $selectedTasks[$_] = $securityCheckboxes[$_].Text } }
	$privacyCheckboxes.Keys | ForEach-Object { if ($privacyCheckboxes[$_].Checked) { $selectedTasks[$_] = $privacyCheckboxes[$_].Text } }

    $totalTasks = $selectedTasks.Count
    $completedTasks = 0

    # Ngay sau khi tính $totalTasks và trước vòng lặp foreach
    if ($totalTasks -gt 0) {
        $form.Invoke([Action]{
            $progressBar.Maximum = $totalTasks # Đặt Maximum bằng tổng số tác vụ
            $progressBar.Value = 0          # Reset Value về 0
        })
    } else {
         $form.Invoke([Action]{
            $progressBar.Maximum = 1 # Tránh lỗi nếu totalTasks = 0
            $progressBar.Value = 0
        })
    }

    # Lưu thông tin ổ đĩa trước khi dọn dẹp
    $diskInfoBefore = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" |
                      Select-Object DeviceID, @{Name="FreeSpace(GB)";Expression={[math]::Round($_.FreeSpace / 1GB, 2)}}

    # Thực hiện các tác vụ
    foreach ($key in $selectedTasks.Keys) {
        $completedTasks++
        $form.Invoke([Action]{ $progressBar.Value = $completedTasks }) 
        $taskText = $selectedTasks[$key] # Lấy tên tác vụ để ghi log

        Write-Log "Đang thực hiện ($completedTasks/$totalTasks): $taskText..."
        $success = $true # Biến cờ để theo dõi thành công

        try {
            switch ($key) {
                # --- Dọn dẹp cơ bản ---
                "TempFiles" {
                    Remove-Item -Path "$env:TEMP\*" -Force -Recurse -ErrorAction Stop -ErrorVariable removeError
                    Remove-Item -Path "$env:windir\Temp\*" -Force -Recurse -ErrorAction Stop -ErrorVariable removeError
                }
                "RecycleBin" {
                    $shell = New-Object -ComObject Shell.Application
                    $recycleBin = $shell.Namespace(0xA)
                    if ($recycleBin.Items().Count -gt 0) {
                        $recycleBin.Items() | ForEach-Object {
                            # Thêm kiểm tra xem đối tượng có thuộc tính Path không
                            if ($_.PSObject.Properties['Path']) {
                                Remove-Item -LiteralPath $_.Path -Recurse -Force -Confirm:$false -ErrorAction Stop -ErrorVariable removeError
                            } else {
                                Write-Log "⚠️ Không thể lấy đường dẫn cho một mục trong Thùng rác."
                            }
                        }
                    } else {
                         Write-Log "ℹ️ Thùng rác đã trống."
                         $success = "Skip" # Đánh dấu là bỏ qua vì không có gì để xóa
                    }
                }
                "BrowserCache" {
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
                }
                "WinUpdateCache" {
                    Stop-Service -Name wuauserv, bits -Force -ErrorAction SilentlyContinue
                    $softwareDist = "$env:windir\SoftwareDistribution"
                    if (Test-Path $softwareDist) { Remove-Item -Path "$softwareDist\*" -Force -Recurse -ErrorAction Stop }
                    Start-Service -Name bits, wuauserv -ErrorAction SilentlyContinue
                }
                "Prefetch" {
                    Remove-Item -Path "$env:windir\Prefetch\*" -Force -ErrorAction Stop
                }
                "OldDownloads" {
                    $threshold = (Get-Date).AddDays(-3)
                    Get-ChildItem -Path "$env:USERPROFILE\Downloads" -File | Where-Object { $_.LastWriteTime -lt $threshold } | Remove-Item -Force -ErrorAction Stop
                }
                "EventLogs" {
                    wevtutil el | ForEach-Object { wevtutil cl "$_" /q:$true } # /q:$true để không báo lỗi nếu log trống
                }
                "ThumbnailCache" {
                    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue # Cần đóng explorer để xóa cache
                    Start-Sleep -Seconds 2 # Chờ explorer đóng hoàn toàn
                    Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db" -Force -ErrorAction Stop
                    Start-Process explorer # Khởi động lại explorer
                }
                # --- Dọn dẹp nâng cao ---
                "WinSxS" {
                    $process = Start-Process -FilePath "Dism.exe" -ArgumentList "/Online /Cleanup-Image /StartComponentCleanup" -NoNewWindow -PassThru -Wait -ErrorAction Stop
                    if ($process.ExitCode -ne 0) { $success = $false; Write-Log "⚠️ DISM WinSxS lỗi mã: $($process.ExitCode)" }
                }
                "SoftwareDist" {
                    # Đã xử lý trong WinUpdateCache, có thể coi là thành công nếu WinUpdateCache thành công
                    Write-Log "ℹ️ SoftwareDistribution được xử lý cùng Windows Update Cache."
                    $success = "Skip"
                }
                "ComponentStore" {
                    Start-Process -FilePath "Dism.exe" -ArgumentList "/Online /Cleanup-Image /AnalyzeComponentStore" -NoNewWindow -PassThru -Wait -ErrorAction Stop
                    $process = Start-Process -FilePath "Dism.exe" -ArgumentList "/Online /Cleanup-Image /StartComponentCleanup /ResetBase" -NoNewWindow -PassThru -Wait -ErrorAction Stop
                    if ($process.ExitCode -ne 0) { $success = $false; Write-Log "⚠️ DISM Component Store lỗi mã: $($process.ExitCode)" }
                }
                "StoreCache" {
                    Start-Process "wsreset.exe" -NoNewWindow -Wait -ErrorAction Stop
                }
                "OneDriveCache" {
                    if (Test-Path "$env:USERPROFILE\OneDrive") {
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
                    } else {
                        Write-Log "⚠️ OneDrive không được cài đặt hoặc không tìm thấy."
                        $success = "Skip"
                    }
                }
                "Hibernation" {
                    $process = Start-Process -FilePath "powercfg.exe" -ArgumentList "/hibernate off" -NoNewWindow -PassThru -Wait -ErrorAction Stop
                    if ($process.ExitCode -ne 0) { $success = $false; Write-Log "⚠️ Powercfg hibernate off lỗi mã: $($process.ExitCode)" }
                }
                "FontCache" {
                    Stop-Service -Name "FontCache", "FontCache3.0.0.0" -Force -ErrorAction SilentlyContinue
                    Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\Windows\Fonts\*" -Force -ErrorAction Stop
                    Remove-Item -Path "$env:WINDIR\ServiceProfiles\LocalService\AppData\Local\FontCache\*" -Force -Recurse -ErrorAction Stop
                    Start-Service -Name "FontCache", "FontCache3.0.0.0" -ErrorAction SilentlyContinue
                }
                "CompressNTFS" {
                    $process = Start-Process -FilePath "compact.exe" -ArgumentList "/CompactOS:always" -NoNewWindow -PassThru -Wait -ErrorAction Stop
                    if ($process.ExitCode -ne 0) { $success = $false; Write-Log "⚠️ CompactOS lỗi mã: $($process.ExitCode)" }
                }
                # --- Tối ưu hóa ---
                "StartupOptimize" {
                     # Giảm thời gian trễ khởi động
                     $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Serialize"
                     if (-not (Test-Path $registryPath)) { New-Item -Path $registryPath -Force | Out-Null }
                     Set-ItemProperty -Path $registryPath -Name "StartupDelayInMSec" -Value 0 -Type DWORD -Force -ErrorAction Stop
                }
                "ServiceOptimize" {
                     # Vô hiệu hóa một số dịch vụ không cần thiết
                     $services = @{
                         "DiagTrack" = "Disabled" # Tắt hẳn thay vì Manual
                         "dmwappushservice" = "Disabled"
                         "SysMain" = "Disabled"  # Superfetch/SysMain thường không cần thiết trên SSD
                         "WSearch" = "Disabled" # Nếu không dùng Windows Search nhiều
                     }
                     foreach ($name in $services.Keys) {
                         if (Get-Service -Name $name -ErrorAction SilentlyContinue) {
                             Set-Service -Name $name -StartupType $services[$name] -ErrorAction Stop
                             Stop-Service -Name $name -Force -ErrorAction SilentlyContinue # Cố gắng dừng dịch vụ
                         }
                     }
                }
                "PageFileOptimize" {
                     # Tự động quản lý pagefile thường là tốt nhất cho hầu hết người dùng
                     # Đặt lại về tự động quản lý nếu trước đó đã tắt
                     $computerSystem = Get-WmiObject Win32_ComputerSystem -EnableAllPrivileges
                     if (-not $computerSystem.AutomaticManagedPagefile) {
                         $computerSystem.AutomaticManagedPagefile = $true
                         $computerSystem.Put() | Out-Null
                         Write-Log "ℹ️ Đã bật lại tự động quản lý Page File."
                     } else {
                         Write-Log "ℹ️ Page File đang được quản lý tự động."
                     }
                     $success = "Skip" # Đánh dấu là không có thay đổi lớn
                }
                "VisualPerformance" {
                    # Tối ưu hóa các hiệu ứng trực quan cho hiệu suất (Best Performance)
                    $perfOptions = Get-CimInstance -ClassName Win32_OperatingSystem | Select-Object -ExpandProperty OSLanguage
                    # Sử dụng sysdm.cpl để đặt Best Performance - cách này đáng tin cậy hơn registry
                    # Lưu ý: Cách này cần tương tác người dùng hoặc có thể không hoạt động trong mọi ngữ cảnh script
                    # Tạm thời bỏ qua tự động hóa hoàn toàn bước này vì độ phức tạp và khả năng gây lỗi
                    # Start-Process "SystemPropertiesPerformance.exe" # Mở cửa sổ Performance Options
                    Write-Log "ℹ️ Vui lòng tự điều chỉnh hiệu suất trực quan trong System Properties > Advanced > Performance Settings."
                    $success = "Skip"
                }
                "NetworkLatency" {
                    # Các cài đặt này có thể gây hại nhiều hơn lợi trên các kết nối hiện đại
                    # Netsh int tcp set global autotuninglevel=normal # Đặt lại về mặc định nếu cần
                    Write-Log "ℹ️ Tối ưu hóa mạng nâng cao thường không cần thiết và có thể gây sự cố. Bỏ qua."
                    $success = "Skip"
                }
                "SearchOptimize" {
                    # Tắt dịch vụ nếu được chọn trong ServiceOptimize
                    if ($selectedTasks.ContainsKey("ServiceOptimize") -and $services.ContainsKey("WSearch") -and $services["WSearch"] -eq "Disabled") {
                        Write-Log "ℹ️ Windows Search đã được tắt trong tối ưu hóa dịch vụ."
                        $success = "Skip"
                    } else {
                        # Chỉ rebuild index nếu dịch vụ đang chạy
                        if ((Get-Service WSearch).Status -eq 'Running') {
                            Write-Log "Đang rebuild Windows Search index..."
                            # Cách này phức tạp, cần script riêng. Tạm thời chỉ xóa cache.
                            Stop-Service -Name "WSearch" -Force -ErrorAction Stop
                            Remove-Item -Path "$env:ProgramData\Microsoft\Search\Data\Applications\Windows\Windows.edb" -Force -ErrorAction SilentlyContinue # Cố gắng xóa file index
                            Start-Service -Name "WSearch" -ErrorAction Stop
                        } else {
                             Write-Log "ℹ️ Windows Search service không chạy. Bỏ qua rebuild index."
                             $success = "Skip"
                        }
                    }
                }
                 "RAMOptimize" {
                     # Việc giải phóng RAM thủ công thường không hiệu quả và có thể làm chậm hệ thống sau đó
                     Write-Log "ℹ️ Windows quản lý RAM hiệu quả. Việc giải phóng thủ công thường không cần thiết. Bỏ qua."
                     # $process = Start-Process -FilePath "wmic.exe" -ArgumentList "os where Primary='TRUE' call Win32EmptyWorkingSet" -NoNewWindow -PassThru -Wait
                     $success = "Skip"
                 }
                 "ShutdownOptimize" {
                     # Giảm thời gian chờ khi đóng ứng dụng
                     $desktopPath = "HKCU:\Control Panel\Desktop"
                     Set-ItemProperty -Path $desktopPath -Name "AutoEndTasks" -Value "1" -Type String -Force -ErrorAction Stop
                     Set-ItemProperty -Path $desktopPath -Name "HungAppTimeout" -Value "1000" -Type String -Force -ErrorAction Stop
                     Set-ItemProperty -Path $desktopPath -Name "WaitToKillAppTimeout" -Value "2000" -Type String -Force -ErrorAction Stop
                     # Giảm thời gian chờ service
                     $controlPath = "HKLM:\SYSTEM\CurrentControlSet\Control"
                     Set-ItemProperty -Path $controlPath -Name "WaitToKillServiceTimeout" -Value "2000" -Type String -Force -ErrorAction Stop
                 }
                 # --- Bảo mật ---
                 "BasicMalware" {
                    # Sử dụng Windows Defender để quét nhanh
                    if (Get-Command Start-MpScan -ErrorAction SilentlyContinue) {
                        Start-MpScan -ScanType QuickScan -ErrorAction Stop
                    } else {
                        Write-Log "⚠️ Không tìm thấy lệnh Start-MpScan (Windows Defender)."
                        $success = "Skip"
                    }
                 }
                 "BrowserHistory" {
                    # Chỉ xóa history/cache cơ bản, không xóa cookies/passwords trừ khi người dùng yêu cầu rõ ràng
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
                             Remove-Item -Path "$ffProfile\places.sqlite" -Force -ErrorAction SilentlyContinue # History & Bookmarks
                             Remove-Item -Path "$ffProfile\cache2\*" -Force -Recurse -ErrorAction SilentlyContinue
                         }
                     }
                 }
                 "WindowsUpdate" {
                    # Kiểm tra cập nhật Windows qua module PSWindowsUpdate nếu có
                    if (Get-Module -ListAvailable -Name PSWindowsUpdate) {
                        Import-Module PSWindowsUpdate -Force
                        Write-Log "Đang kiểm tra bản cập nhật Windows..."
                        $updates = Get-WindowsUpdate -MicrosoftUpdate # Tìm cả update cho sản phẩm MS khác
                        if ($updates) {
                            Write-Log "Các bản cập nhật có sẵn:"
                            $updates | ForEach-Object { Write-Log "- $($_.Title)" }
                            # Cân nhắc: Tự động cài đặt? $updates | Install-WindowsUpdate -AcceptAll -MicrosoftUpdate
                        } else {
                            Write-Log "✅ Hệ thống đã được cập nhật."
                        }
                    } else {
                        Write-Log "⚠️ Module PSWindowsUpdate không được cài đặt. Không thể kiểm tra cập nhật tự động."
                        Write-Log "ℹ️ Đang mở Windows Update Settings..."
                        Start-Process "ms-settings:windowsupdate" # Mở trang cài đặt Windows Update
                        $success = "Skip"
                    }
                 }
                 "RecentFiles" {
                    Remove-Item -Path "$env:APPDATA\Microsoft\Windows\Recent\*" -Force -Recurse -ErrorAction Stop
                    # Xóa Jump Lists (cần đóng explorer)
                    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 2
                    Remove-Item -Path "$env:APPDATA\Microsoft\Windows\Recent\AutomaticDestinations\*" -Force -Recurse -ErrorAction Stop
                    Remove-Item -Path "$env:APPDATA\Microsoft\Windows\Recent\CustomDestinations\*" -Force -Recurse -ErrorAction Stop
                    Start-Process explorer
                 }
                 "SavedCredentials" {
                     # Hiển thị danh sách trước khi xóa?
                     Write-Log "ℹ️ Việc xóa tất cả thông tin đăng nhập đã lưu có thể gây bất tiện. Bỏ qua bước này."
                     # cmdkey /list # Hiển thị
                     # cmdkey /delete * # Xóa tất cả (nguy hiểm)
                     $success = "Skip"
                 }
                 "DisableTracking" {
                     # Đã xử lý trong ServiceOptimize
                     if ($selectedTasks.ContainsKey("ServiceOptimize") -and $services.ContainsKey("DiagTrack") -and $services["DiagTrack"] -eq "Disabled") {
                         Write-Log "ℹ️ Dịch vụ theo dõi đã được tắt trong tối ưu hóa dịch vụ."
                         $success = "Skip"
                     } else {
                         Write-Log "ℹ️ Dịch vụ theo dõi không được chọn để tắt trong Tối ưu hóa Dịch vụ. Bỏ qua."
                         $success = "Skip"
                     }
                 }
                 "DiagData" {
                     Remove-Item -Path "$env:ProgramData\Microsoft\Diagnosis\*" -Force -Recurse -ErrorAction Stop
                     # Các cache khác có thể liên quan
                     Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\Windows\Caches\*" -Force -Recurse -ErrorAction SilentlyContinue
                 }
                 "LocationTracking" {
                     $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location"
                     if (Test-Path $registryPath) {
                         Set-ItemProperty -Path $registryPath -Name "Value" -Value "Deny" -Type String -Force -ErrorAction Stop
                     }
                     # Tắt dịch vụ vị trí
                     if (Get-Service -Name "lfsvc" -ErrorAction SilentlyContinue) {
                         Set-Service -Name "lfsvc" -StartupType Disabled -ErrorAction Stop
                         Stop-Service -Name "lfsvc" -Force -ErrorAction SilentlyContinue
                     }
                 }
				 
				 "EnsureFirewallEnabled" {
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
                        $success = "Skip" # Đánh dấu là không có thay đổi
                    }
                }

                "CheckRealTimeProtection" {
                     Write-Log "Đang kiểm tra trạng thái Bảo vệ thời gian thực..."
                     $RealTimeStatus = $null # Reset biến trước khi kiểm tra
                     try {
                        # Lấy trạng thái, nếu Defender không chạy sẽ lỗi hoặc trả về $null
                        $RealTimeStatus = Get-MpComputerStatus -ErrorAction Stop | Select-Object -ExpandProperty RealTimeProtectionEnabled
                        if ($RealTimeStatus -eq $true) {
                            Write-Log "✅ Bảo vệ thời gian thực của Windows Defender đang BẬT."
                            $success = "Skip" # Chỉ kiểm tra, không thay đổi
                        } else { # Bao gồm cả trường hợp $false
                            Write-Log "⚠️ Bảo vệ thời gian thực của Windows Defender đang TẮT."
                            # Bạn có thể thêm tùy chọn bật lại ở đây nếu muốn, ví dụ:
                            # Set-MpPreference -DisableRealtimeMonitoring $false
                        }
                     } catch {
                         # Bắt lỗi nếu Get-MpComputerStatus không thành công
                         Write-Log "❓ Không thể kiểm tra trạng thái Bảo vệ thời gian thực. Lý do: $($_.Exception.Message)"
                         $success = "Skip" # Không thể kiểm tra
                     }
                 }

                 "EnablePUAProtection" {
                     Write-Log "Đang kiểm tra và bật Bảo vệ chống PUA/PUP..."
                     try {
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
                     Write-Log "Chuẩn bị chạy Quét Toàn bộ hệ thống..."
                      $confirmScan = [System.Windows.Forms.MessageBox]::Show(
                         "Quét toàn bộ hệ thống bằng Windows Defender có thể mất RẤT NHIỀU THỜI GIAN (vài giờ hoặc hơn)." + "`n" +
                         "Tiến trình quét sẽ chạy trong nền và bạn có thể theo dõi trong Windows Security."+ "`n`n" +
                         "Bạn có muốn bắt đầu quét không?",
                         "Xác nhận Quét Toàn bộ",
                         [System.Windows.Forms.MessageBoxButtons]::YesNo,
                         [System.Windows.Forms.MessageBoxIcon]::Warning
                     )

                     if ($confirmScan -eq [System.Windows.Forms.DialogResult]::Yes) {
                         try {
                             Write-Log "Đang yêu cầu Windows Defender bắt đầu Quét Toàn bộ..."
                             Start-MpScan -ScanType FullScan -ErrorAction Stop
                             Write-Log "✅ Đã gửi yêu cầu Quét Toàn bộ. Vui lòng theo dõi tiến trình trong Windows Security."
                             # Không thể chờ lệnh này hoàn thành trong script GUI một cách dễ dàng.
                             $success = "Skip" # Đánh dấu là đã bắt đầu, không phải hoàn thành ngay lập tức
                         } catch {
                             $errorMessage = $_.Exception.Message
                             Write-Log "❌ Lỗi khi bắt đầu Quét Toàn bộ: $errorMessage"
                             $success = $false
                         }
                     } else {
                         Write-Log "ℹ️ Đã hủy thao tác Quét Toàn bộ hệ thống."
                         $success = "Skip" # Người dùng hủy
                     }
                 }
                "DisableMicrophone" {
                    Write-Log "Đang tìm và vô hiệu hóa các thiết bị Micro..."
                    $microphones = Get-PnpDevice -Class 'AudioEndpoint' -Status 'OK' | Where-Object {$_.FriendlyName -match 'Microphone|Mic|Array'}
                    # $microphones += Get-PnpDevice -Class 'MEDIA' -Status 'OK' | Where-Object {$_.FriendlyName -match 'Microphone|Mic'}
                    if ($microphones) {
                        foreach ($mic in $microphones) {
                            try {
                                Write-Log "Đang vô hiệu hóa: $($mic.FriendlyName) ($($mic.InstanceId))"
                                Disable-PnpDevice -InstanceId $mic.InstanceId -Confirm:$false -ErrorAction Stop
                                Write-Log "✅ Đã vô hiệu hóa: $($mic.FriendlyName)"
                            } catch { Write-Log "❌ Lỗi khi vô hiệu hóa $($mic.FriendlyName): $($_.Exception.Message)"; $success = $false }
                        }
                    } else { Write-Log "ℹ️ Không tìm thấy thiết bị Micro nào đang hoạt động để vô hiệu hóa."; $success = "Skip" }
                }
                "DisableCamera" {
                    Write-Log "Đang tìm và vô hiệu hóa các thiết bị Camera..."
                    $cameras = Get-PnpDevice -Class 'Camera' -Status 'OK' -ErrorAction SilentlyContinue
                    if (-not $cameras) { $cameras = Get-PnpDevice -Class 'Image' -Status 'OK' | Where-Object {$_.FriendlyName -match 'Camera|Webcam|Integrated'} }
                    if ($cameras) {
                        foreach ($cam in $cameras) {
                            try {
                                Write-Log "Đang vô hiệu hóa: $($cam.FriendlyName) ($($cam.InstanceId))"
                                Disable-PnpDevice -InstanceId $cam.InstanceId -Confirm:$false -ErrorAction Stop
                                Write-Log "✅ Đã vô hiệu hóa: $($cam.FriendlyName)"
                            } catch { Write-Log "❌ Lỗi khi vô hiệu hóa $($cam.FriendlyName): $($_.Exception.Message)"; $success = $false }
                        }
                    } else { Write-Log "ℹ️ Không tìm thấy thiết bị Camera nào đang hoạt động để vô hiệu hóa."; $success = "Skip" }
                }
                "DisableAdvertisingID" {
                    Write-Log "Đang vô hiệu hóa ID Quảng cáo..."
                    $RegPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo"
                    try {
                        if (-not (Test-Path $RegPath)) { New-Item -Path $RegPath -Force | Out-Null }
                        Set-ItemProperty -Path $RegPath -Name "Enabled" -Value 0 -Type DWord -Force -ErrorAction Stop
                        Write-Log "✅ Đã vô hiệu hóa ID Quảng cáo cho người dùng hiện tại."
                    } catch { Write-Log "❌ Lỗi khi vô hiệu hóa ID Quảng cáo: $($_.Exception.Message)"; $success = $false }
                }
                "DisableTelemetryServices" {
                    Write-Log "Đang vô hiệu hóa các dịch vụ Telemetry chính..."
                    $telemetryServices = @("DiagTrack", "dmwappushservice")
                    foreach ($svcName in $telemetryServices) {
                        if (Get-Service -Name $svcName -ErrorAction SilentlyContinue) {
                            try {
                                Set-Service -Name $svcName -StartupType Disabled -ErrorAction Stop
                                Stop-Service -Name $svcName -Force -ErrorAction SilentlyContinue
                                Write-Log "✅ Đã vô hiệu hóa dịch vụ: $svcName"
                            } catch { Write-Log "❌ Lỗi khi vô hiệu hóa dịch vụ ${svcName}: $($_.Exception.Message)"; $success = $false }
                        } else { Write-Log "ℹ️ Không tìm thấy dịch vụ: $svcName" }
                    }
                }
                "ClearActivityHistory" {
                    Write-Log "Đang cố gắng xóa Lịch sử Hoạt động..."
                    # Việc xóa programmatically rất phức tạp và không được hỗ trợ trực tiếp
                    # Cách tốt nhất là hướng dẫn người dùng hoặc mở trang cài đặt
                    Write-Log "ℹ️ Việc xóa Lịch sử Hoạt động cần thực hiện thủ công trong Cài đặt Windows > Quyền riêng tư > Lịch sử hoạt động."
                    Start-Process "ms-settings:activityhistory" # Mở trang cài đặt
                    $success = "Skip"
                }
                "DisableCloudClipboard" {
                    Write-Log "Đang vô hiệu hóa Cloud Clipboard..."
                    $RegPath = "HKCU:\Software\Microsoft\Clipboard"
                    try {
                        if (-not (Test-Path $RegPath)) { New-Item -Path $RegPath -Force | Out-Null }
                        Set-ItemProperty -Path $RegPath -Name "EnableClipboardHistory" -Value 0 -Type DWord -Force -ErrorAction Stop # Tắt lịch sử clipboard cục bộ luôn
                        Set-ItemProperty -Path $RegPath -Name "CloudClipboardEnabled" -Value 0 -Type DWord -Force -ErrorAction Stop # Tắt đồng bộ cloud
                        Write-Log "✅ Đã vô hiệu hóa Cloud Clipboard và Lịch sử Clipboard."
                    } catch { Write-Log "❌ Lỗi khi vô hiệu hóa Cloud Clipboard: $($_.Exception.Message)"; $success = $false }
                }
                "DisableLocationTracking" { # Chuyển logic từ tab Bảo mật cũ sang đây nếu muốn
                    Write-Log "Đang tắt tính năng theo dõi vị trí..."
                    $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location";
                    if (Test-Path $registryPath) { Set-ItemProperty -Path $registryPath -Name "Value" -Value "Deny" -Type String -Force -ErrorAction Stop };
                    if (Get-Service -Name "lfsvc" -ErrorAction SilentlyContinue) { Set-Service -Name "lfsvc" -StartupType Disabled -ErrorAction Stop; Stop-Service -Name "lfsvc" -Force -ErrorAction SilentlyContinue }
                }
				default {
                     Write-Log "⚠️ Tác vụ không xác định: $key"
                     $success = $false
                }
            } # Kết thúc switch

            # Ghi log thành công hoặc bỏ qua
            if ($success -eq $true) {
                Write-Log "✅ Hoàn thành: $taskText"
            } elseif ($success -eq "Skip") {
                Write-Log "ℹ️ Bỏ qua: $taskText"
            }

        } catch {
            # Ghi log lỗi chi tiết
            $errorMessage = $_.Exception.Message
            $scriptStackTrace = $_.ScriptStackTrace
            Write-Log "❌ Lỗi khi thực hiện '$taskText': $errorMessage"
            Write-Log "   Chi tiết: $scriptStackTrace"
            $success = $false # Đánh dấu là lỗi
        }
    } # Kết thúc foreach task

    # Hoàn tất quá trình
    # Đảm bảo thanh chạy đầy khi kết thúc
    $form.Invoke([Action]{ $progressBar.Value = $progressBar.Maximum })
    Write-Log "Quá trình dọn dẹp đã hoàn tất!"
    Write-Log "Tổng cộng đã xử lý $($selectedTasks.Count) tác vụ được chọn."

    # Hiển thị kết quả dung lượng giải phóng
    $diskInfoAfter = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" |
                     Select-Object DeviceID, @{Name="FreeSpace(GB)";Expression={[math]::Round($_.FreeSpace / 1GB, 2)}}

    foreach ($diskAfter in $diskInfoAfter) {
        $diskBefore = $diskInfoBefore | Where-Object { $_.DeviceID -eq $diskAfter.DeviceID }
        if ($diskBefore) {
            $spaceSaved = $diskAfter.'FreeSpace(GB)' - $diskBefore.'FreeSpace(GB)'
            if ($spaceSaved -gt 0.01) { # Chỉ hiển thị nếu giải phóng được ít nhất 10MB
                Write-Log "Ổ đĩa $($diskAfter.DeviceID): Đã giải phóng $([math]::Round($spaceSaved, 2)) GB không gian"
            }
        }
    }

    # Khôi phục trạng thái nút
    $form.Invoke([Action]{
        $startButton.Enabled = $true
        $cancelButton.Enabled = $false
		$progressBar.Maximum = $totalTasks
		$progressBar.Value = 0
    })

    # Hiển thị thông báo hoàn tất
    [System.Windows.Forms.MessageBox]::Show("Quá trình dọn dẹp đã hoàn tất! Đã xử lý $($selectedTasks.Count) tác vụ được chọn. Kiểm tra log để xem chi tiết.", "Hoàn tất", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
}







# Xử lý sự kiện khi nhấn nút Start
$startButton.Add_Click({
    # Chạy hàm dọn dẹp trong một luồng khác để UI không bị treo
    $scriptBlock = {
        # Truyền các biến cần thiết vào scope của scriptblock
        param($checkboxes, $advancedCheckboxes, $optimizeCheckboxes, $securityCheckboxes, $logBoxRef, $progressBarRef, $startButtonRef, $cancelButtonRef, $formRef, $diskInfoRef)

        # Hàm Write-Log nội bộ cho thread
        function Write-LogInternal {
            param([string]$message)
            $time = Get-Date -Format "HH:mm:ss"
            $logMessage = "[$time] $message"
            $logBoxRef.Invoke([Action]{
                 $logBoxRef.AppendText("$logMessage`n")
                 $logBoxRef.SelectionStart = $logBoxRef.Text.Length
                 $logBoxRef.ScrollToCaret()
            })
        }

        # Gọi hàm Start-Cleanup với các tham chiếu UI
        # Lưu ý: Start-Cleanup cần được điều chỉnh để nhận các tham chiếu này hoặc bạn phải định nghĩa lại nó trong scriptblock này.
        # Cách đơn giản hơn là bỏ qua chạy nền nếu Start-Cleanup đã được sửa để dùng Invoke

        # *** TẠM THỜI CHẠY TRÊN LUỒNG CHÍNH ĐỂ TRÁNH PHỨC TẠP ***
        # Start-Cleanup # Gọi trực tiếp vì đã dùng Invoke trong Start-Cleanup
    }

    # *** CHẠY TRỰC TIẾP TRÊN LUỒNG CHÍNH ***
    Start-Cleanup

    # Nếu muốn chạy nền (cần sửa Start-Cleanup để tương thích hoàn toàn):
    # $ps = [PowerShell]::Create().AddScript($scriptBlock).AddArgument($checkboxes).AddArgument($advancedCheckboxes).AddArgument($optimizeCheckboxes).AddArgument($securityCheckboxes).AddArgument($logBox).AddArgument($progressBar).AddArgument($startButton).AddArgument($cancelButton).AddArgument($form).AddArgument($diskInfo)
    # $job = $ps.BeginInvoke()
    # Gắn job vào form để quản lý (ví dụ: để có thể cancel)
    # $form.Tag = $job
})


# Xử lý sự kiện khi nhấn nút Cancel (Cần phức tạp hơn nếu chạy nền)
$cancelButton.Add_Click({
    Write-Log "Hủy quá trình dọn dẹp không được hỗ trợ trong phiên bản này."
    # Nếu chạy nền, cần dừng PowerShell instance:
    # if ($form.Tag -is [System.IAsyncResult]) {
    #     $jobHandle = $form.Tag
    #     $psInstance = $jobHandle.AsyncState
    #     if ($psInstance -is [System.Management.Automation.PowerShell]) {
    #         $psInstance.Stop()
    #         Write-Log "Đã gửi yêu cầu dừng tác vụ."
    #     }
    # }
    # $startButton.Enabled = $true
    # $cancelButton.Enabled = $false
})

# Xử lý tiện ích
$tabUtilities.Controls | Where-Object { $_ -is [System.Windows.Forms.Button] } | ForEach-Object {
    $button = $_
    $button.Add_Click({
        $utilityTag = $this.Tag # $this tham chiếu đến button được click

        try {
             Write-Log "Đang chạy tiện ích: $($this.Text)..."
             switch ($utilityTag) {
                 "DiskAnalysis" {
                     Write-Log "Mở Disk Cleanup cho ổ C:..."
                     Start-Process "cleanmgr.exe" -ArgumentList "/d C:" -ErrorAction Stop
                 }
                 "BackupRegistry" {
                     $backupPath = "$env:USERPROFILE\Desktop\RegistryBackup_$(Get-Date -Format 'yyyyMMdd_HHmmss').reg"
                     Write-Log "Đang sao lưu Registry vào $backupPath ..."
                     # Sao lưu các nhánh chính
                     $hives = @("HKLM", "HKCU", "HKCR", "HKU", "HKCC")
                     $successCount = 0
                     foreach ($hive in $hives) {
                         $hivePath = $backupPath -replace '.reg', "_$hive.reg"
                         $process = Start-Process -FilePath "reg.exe" -ArgumentList "export $hive `"$hivePath`"" -NoNewWindow -PassThru -Wait -ErrorAction Stop
                         if ($process.ExitCode -eq 0) {
                             Write-Log "✅ Đã sao lưu $hive thành công."
                             $successCount++
                         } else {
                             Write-Log "❌ Lỗi khi sao lưu $hive. Mã lỗi: $($process.ExitCode)"
                         }
                     }
                     if ($successCount -gt 0) {
                         [System.Windows.Forms.MessageBox]::Show("Đã sao lưu $successCount nhánh Registry vào Desktop.", "Sao lưu hoàn tất", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                     } else {
                         [System.Windows.Forms.MessageBox]::Show("Không thể sao lưu Registry.", "Sao lưu thất bại", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                     }
                 }
                 "StartupManager" {
                     Write-Log "Mở Task Manager - tab Startup..."
                     # Cách mới hơn để mở trực tiếp tab Startup
                     Start-Process "ms-settings:startupapps"
                     # Start-Process "taskmgr.exe" -ArgumentList "/7 /startup" # Cách cũ hơn
                 }
                 "SystemInfo" {
                     Write-Log "Mở System Information..."
                     Start-Process "msinfo32.exe" -ErrorAction Stop
                 }
                 "DiskHealth" {
                     Write-Log "Kiểm tra sức khỏe ổ đĩa (S.M.A.R.T.)..."
                     if (Get-Command Get-PhysicalDisk -ErrorAction SilentlyContinue) {
                         Get-PhysicalDisk | Select-Object DeviceID, Model, MediaType, HealthStatus, Size | Format-Table -AutoSize | Out-String | Write-Log
                         # Lấy thông tin SMART chi tiết hơn (có thể cần quyền Admin)
                         Get-CimInstance -Namespace root\wmi –ClassName MSStorageDriver_ATAPISmartData | Select-Object InstanceName, VendorSpecific | Format-List | Out-String | Write-Log
                         Get-CimInstance -Namespace root\wmi –ClassName MSStorageDriver_FailurePredictStatus | Select-Object InstanceName, PredictFailure, Reason | Format-List | Out-String | Write-Log
                     } else {
                         Write-Log "⚠️ Lệnh Get-PhysicalDisk không khả dụng."
                     }
                 }
                 "ScheduledCleanup" {
                      Write-Log "Thiết lập dọn dẹp tự động định kỳ..."
                      $taskName = "WindowsSmartCleanupScheduled" # Đổi tên để tránh trùng
                      $taskPath = $PSCommandPath
                      $taskActionArg = "-NoProfile -ExecutionPolicy Bypass -File `"$taskPath`" -ScheduledRun" # Thêm cờ để script biết nó chạy tự động

                      # Kiểm tra xem tác vụ đã tồn tại chưa
                      $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

                      if ($existingTask) {
                          $choice = [System.Windows.Forms.MessageBox]::Show("Tác vụ dọn dẹp tự động '$taskName' đã tồn tại. Bạn có muốn cập nhật không?", "Tác vụ đã tồn tại", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
                          if ($choice -eq [System.Windows.Forms.DialogResult]::No) {
                              Write-Log "ℹ️ Giữ nguyên tác vụ hiện có."
                              return
                          }
                          Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction Stop
                          Write-Log "Đã xóa tác vụ cũ."
                      }

                      # Tạo một tác vụ mới chạy hàng tuần
                      $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $taskActionArg
                      $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At "2am"
                      $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 2) # Giới hạn thời gian chạy
                      $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

                      Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description "Tự động chạy Windows Smart Cleanup Tool hàng tuần." | Out-Null
                      Write-Log "✅ Đã thiết lập/cập nhật tác vụ '$taskName' chạy vào 2 giờ sáng mỗi Chủ Nhật."
                      [System.Windows.Forms.MessageBox]::Show("Đã thiết lập/cập nhật tác vụ '$taskName' chạy vào 2 giờ sáng mỗi Chủ Nhật.", "Thiết lập hoàn tất", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                  }
                 "FixCommonIssues" {
                     Write-Log "Sửa lỗi Windows phổ biến..."
                     $confirm = [System.Windows.Forms.MessageBox]::Show("Hành động này sẽ cố gắng sửa chữa các vấn đề hệ thống và có thể mất nhiều thời gian. Bạn có muốn tiếp tục?", "Xác nhận sửa lỗi", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
                     if ($confirm -eq [System.Windows.Forms.DialogResult]::No) {
                         Write-Log "ℹ️ Đã hủy sửa lỗi."
                         return
                     }

                     # Sử dụng Troubleshooter tích hợp (khuyến nghị)
                     Write-Log "Mở Windows Update Troubleshooter..."
                     Start-Process "msdt.exe" -ArgumentList "/id WindowsUpdateDiagnostic" -Wait

                     Write-Log "Mở System File Checker..."
                     Start-Process "cmd.exe" -ArgumentList "/c sfc /scannow" -Wait -Verb RunAs

                     Write-Log "Mở DISM RestoreHealth..."
                     Start-Process "cmd.exe" -ArgumentList "/c DISM /Online /Cleanup-Image /RestoreHealth" -Wait -Verb RunAs

                     Write-Log "✅ Đã chạy các công cụ sửa lỗi Windows phổ biến."
                     [System.Windows.Forms.MessageBox]::Show("Đã chạy các công cụ sửa lỗi Windows phổ biến. Kiểm tra kết quả của từng công cụ.", "Sửa lỗi hoàn tất", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                 }
                 "DiskPartition" {
                     Write-Log "Mở Disk Management..."
                     Start-Process "diskmgmt.msc" -ErrorAction Stop
                 }
				 
				 "FlushDnsCache" {
                     Write-Log "Đang xóa Cache DNS..."
                     try {
                         # Chạy ipconfig /flushdns và kiểm tra output
                         $output = ipconfig /flushdns | Out-String
                         Write-Log $output.Trim() # Ghi lại output của lệnh
                         if ($output -match "Successfully flushed the DNS Resolver Cache") {
                             Write-Log "✅ Đã xóa Cache DNS thành công."
                             [System.Windows.Forms.MessageBox]::Show("Đã xóa Cache DNS thành công!", "Hoàn tất", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                         } else {
                             Write-Log "⚠️ Có thể đã xảy ra lỗi khi xóa Cache DNS (Kiểm tra output ở trên)."
                             [System.Windows.Forms.MessageBox]::Show("Lệnh xóa Cache DNS đã chạy, nhưng không thể xác nhận thành công hoàn toàn. Vui lòng kiểm tra log.", "Cảnh báo", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
                         }
                     } catch {
                         $errorMessage = $_.Exception.Message
                         Write-Log "❌ Lỗi khi chạy ipconfig /flushdns: $errorMessage"
                         [System.Windows.Forms.MessageBox]::Show("Lỗi khi chạy lệnh xóa Cache DNS:`n$errorMessage", "Lỗi", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                     }
                 }

                 "ResetNetworkStack" {
                     Write-Log "Chuẩn bị đặt lại cài đặt mạng..."
                     $confirmReset = [System.Windows.Forms.MessageBox]::Show(
                         "Hành động này sẽ đặt lại cài đặt TCP/IP và Winsock về mặc định." + "`n" +
                         "Bạn SẼ CẦN KHỞI ĐỘNG LẠI MÁY TÍNH để hoàn tất." + "`n`n" +
                         "Bạn có chắc chắn muốn tiếp tục?",
                         "Xác nhận Đặt lại Mạng",
                         [System.Windows.Forms.MessageBoxButtons]::YesNo,
                         [System.Windows.Forms.MessageBoxIcon]::Warning
                     )

                     if ($confirmReset -eq [System.Windows.Forms.DialogResult]::Yes) {
                         Write-Log "Đang đặt lại Winsock..."
                         $process1 = Start-Process -FilePath "netsh" -ArgumentList "winsock reset" -Wait -PassThru -Verb RunAs -ErrorAction SilentlyContinue
                         if ($process1.ExitCode -eq 0) {
                             Write-Log "✅ Đặt lại Winsock thành công (Cần khởi động lại)."
                         } else {
                             Write-Log "❌ Lỗi khi đặt lại Winsock. Mã lỗi: $($process1.ExitCode)"
                             # Không dừng lại hẳn, thử chạy lệnh tiếp theo
                         }

                         Write-Log "Đang đặt lại TCP/IP..."
                         $process2 = Start-Process -FilePath "netsh" -ArgumentList "int ip reset" -Wait -PassThru -Verb RunAs -ErrorAction SilentlyContinue
                          if ($process2.ExitCode -eq 0) {
                             Write-Log "✅ Đặt lại TCP/IP thành công (Cần khởi động lại)."
                         } else {
                             Write-Log "❌ Lỗi khi đặt lại TCP/IP. Mã lỗi: $($process2.ExitCode)"
                         }

                         Write-Log "ℹ️ Yêu cầu khởi động lại máy tính để hoàn tất việc đặt lại mạng."
                         [System.Windows.Forms.MessageBox]::Show(
                             "Đã thực hiện lệnh đặt lại cài đặt mạng." + "`n" +
                             "Vui lòng KHỞI ĐỘNG LẠI MÁY TÍNH của bạn ngay bây giờ.",
                             "Yêu cầu Khởi động lại",
                             [System.Windows.Forms.MessageBoxButtons]::OK,
                             [System.Windows.Forms.MessageBoxIcon]::Information
                         )
                     } else {
                         Write-Log "ℹ️ Đã hủy thao tác đặt lại cài đặt mạng."
                     }
                 }

                 "RestartActiveAdapter" {
                     Write-Log "Đang tìm và khởi động lại card mạng đang hoạt động..."
                     $ActiveAdapter = $null
                     try {
                         # Cố gắng tìm card mạng có default gateway
                         $ActiveAdapterConfig = Get-NetIPConfiguration | Where-Object {$_.IPv4DefaultGateway -ne $null -or $_.IPv6DefaultGateway -ne $null} | Select-Object -First 1
                         if ($ActiveAdapterConfig) {
                            $ActiveAdapter = Get-NetAdapter | Where-Object {$_.InterfaceIndex -eq $ActiveAdapterConfig.InterfaceIndex} | Select-Object -First 1
                         }
                         
                         # Nếu không tìm thấy qua gateway, thử tìm card Ethernet hoặc Wi-Fi đang 'Up' đầu tiên
                         if (-not $ActiveAdapter) {
                             $ActiveAdapter = Get-NetAdapter | Where-Object {$_.Status -eq 'Up' -and ($_.MediaType -match 'Ethernet' -or $_.MediaType -match 'Native 802.11') -and $_.InterfaceDescription -notmatch 'Loopback|Virtual|VPN|Bluetooth'} | Select-Object -First 1
                         }

                         if ($ActiveAdapter) {
                             $adapterName = $ActiveAdapter.Name
                             Write-Log "Tìm thấy card mạng: $adapterName. Đang khởi động lại..."
                              $confirmRestart = [System.Windows.Forms.MessageBox]::Show(
                                "Bạn có muốn khởi động lại card mạng '$adapterName' không?" + "`n" +
                                "(Kết nối mạng sẽ tạm thời bị gián đoạn)",
                                "Xác nhận Khởi động lại Card mạng",
                                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                                [System.Windows.Forms.MessageBoxIcon]::Question
                              )
                              if ($confirmRestart -eq [System.Windows.Forms.DialogResult]::No) {
                                  Write-Log "ℹ️ Đã hủy thao tác khởi động lại card mạng."
                                  return # Thoát khỏi case này
                              }

                             Disable-NetAdapter -Name $adapterName -Confirm:$false -ErrorAction Stop
                             Write-Log "Đã tắt $adapterName. Chờ 3 giây..."
                             Start-Sleep -Seconds 3
                             Enable-NetAdapter -Name $adapterName -ErrorAction Stop
                             Write-Log "✅ Đã bật lại $adapterName."
                             [System.Windows.Forms.MessageBox]::Show("Đã khởi động lại card mạng '$adapterName' thành công!", "Hoàn tất", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                         } else {
                             Write-Log "⚠️ Không thể tự động xác định card mạng đang hoạt động để khởi động lại."
                             [System.Windows.Forms.MessageBox]::Show("Không thể tự động xác định card mạng đang hoạt động.", "Không tìm thấy", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
                         }
                     } catch {
                         $errorMessage = $_.Exception.Message
                         Write-Log "❌ Lỗi khi khởi động lại card mạng: $errorMessage"
                         [System.Windows.Forms.MessageBox]::Show("Lỗi khi khởi động lại card mạng:`n$errorMessage", "Lỗi", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                     }
                 }
                 default {
                     Write-Log "⚠️ Tiện ích không xác định: $utilityTag"
                 }
             } # End Switch
        } catch {
             $errorMessage = $_.Exception.Message
             Write-Log "❌ Lỗi khi chạy tiện ích '$($this.Text)': $errorMessage"
             [System.Windows.Forms.MessageBox]::Show("Đã xảy ra lỗi khi chạy tiện ích '$($this.Text)':`n$errorMessage", "Lỗi tiện ích", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        }
    })
}


# Thêm các thành phần vào form
$form.Controls.Add($headerPanel)
$form.Controls.Add($tabControl)
$form.Controls.Add($systemInfoPanel)
$form.Controls.Add($controlPanel) # Thêm panel chứa log, progress, buttons

# Xử lý khi form đóng
$form.Add_FormClosing({
    # Dọn dẹp nếu có tác vụ nền đang chạy
    # if ($form.Tag -is [System.IAsyncResult] -and -not $form.Tag.IsCompleted) {
    #     $psInstance = $form.Tag.AsyncState
    #     if ($psInstance -is [System.Management.Automation.PowerShell]) {
    #         Write-Host "Đang dừng tác vụ nền..."
    #         $psInstance.Stop()
    #         $psInstance.Dispose()
    #     }
    # }
})


# Kiểm tra xem script có chạy tự động không
if ($args -contains "-ScheduledRun") {
    Write-Log "Chạy tự động theo lịch..."
    # Chọn các tác vụ mặc định cho chạy tự động (ví dụ: dọn dẹp cơ bản)
    foreach ($key in $checkboxes.Keys) { $checkboxes[$key].Checked = $true }
    foreach ($key in $advancedCheckboxes.Keys) { $advancedCheckboxes[$key].Checked = $false } # Không chạy nâng cao tự động
    foreach ($key in $optimizeCheckboxes.Keys) { $optimizeCheckboxes[$key].Checked = $false } # Không chạy tối ưu hóa tự động
    foreach ($key in $securityCheckboxes.Keys) { $securityCheckboxes[$key].Checked = $false } # Không chạy bảo mật tự động
    Start-Cleanup
    Write-Log "Hoàn thành chạy tự động."
    Exit # Thoát sau khi chạy tự động
} else {
    # Hiển thị form cho người dùng tương tác
    Write-Log "Khởi chạy giao diện người dùng..."
    $form.ShowDialog() | Out-Null
    Write-Log "Đã đóng ứng dụng."
}
