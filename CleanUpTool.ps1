# --- 0. TU DONG KIEM TRA QUYEN ADMIN ---
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = "powershell.exe"
    $processInfo.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    $processInfo.Verb = "runas"
    try { [System.Diagnostics.Process]::Start($processInfo) } catch {}
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# --- 1. CAU HINH UI ---
$Color_Bg       = [System.Drawing.Color]::WhiteSmoke
$Color_Panel    = [System.Drawing.Color]::White
$Color_Accent   = [System.Drawing.Color]::FromArgb(0, 120, 215)
$Color_Green    = [System.Drawing.Color]::SeaGreen
$Color_Text     = [System.Drawing.Color]::FromArgb(20, 20, 20)
$Color_Desc     = [System.Drawing.Color]::FromArgb(80, 80, 80)

$Font_Header    = New-Object System.Drawing.Font("Segoe UI", 20, [System.Drawing.FontStyle]::Bold)
$Font_Title     = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$Font_Normal    = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)
$Font_Desc      = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)

# --- 2. KHOI TAO FORM ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "System Maintenance Tool v11.0 (High Performance)"
$form.Size = New-Object System.Drawing.Size(1000, 760)
$form.StartPosition = "CenterScreen"
$form.BackColor = $Color_Bg
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false
try { $form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon("$env:windir\system32\cleanmgr.exe") } catch {}

$tooltip = New-Object System.Windows.Forms.ToolTip; $tooltip.AutoPopDelay = 30000; $tooltip.InitialDelay = 500; $tooltip.ReshowDelay = 200; $tooltip.IsBalloon = $true; $tooltip.ToolTipIcon = "Info"; $tooltip.ToolTipTitle = "Chi tiết"

# --- 3. HEADER ---
$headerPanel = New-Object System.Windows.Forms.Panel
$headerPanel.Size = New-Object System.Drawing.Size(1000, 90)
$headerPanel.BackColor = $Color_Accent; $headerPanel.Dock = "Top"

$lblHead = New-Object System.Windows.Forms.Label
$lblHead.Text = "SYSTEM CLEANER & OPTIMIZER"
$lblHead.Font = $Font_Header; $lblHead.ForeColor = [System.Drawing.Color]::White
$lblHead.Location = New-Object System.Drawing.Point(20, 10); $lblHead.AutoSize = $true
$headerPanel.Controls.Add($lblHead)

$lblSub = New-Object System.Windows.Forms.Label
$lblSub.Text = "Phiên bản v11.0 - Fix lỗi Nút chạy nhanh & Chống treo máy & Lỗi Font"
$lblSub.Font = $Font_Normal; $lblSub.ForeColor = [System.Drawing.Color]::WhiteSmoke
$lblSub.Location = New-Object System.Drawing.Point(25, 50); $lblSub.AutoSize = $true
$headerPanel.Controls.Add($lblSub)
$form.Controls.Add($headerPanel)

# --- 4. TAB CONTROL ---
$tabControl = New-Object System.Windows.Forms.TabControl
$tabControl.Location = New-Object System.Drawing.Point(10, 100)
$tabControl.Size = New-Object System.Drawing.Size(965, 410)
$tabControl.Font = $Font_Normal

$tabBasic = New-Object System.Windows.Forms.TabPage "Dọn Dẹp Cơ Bản"
$tabAdv = New-Object System.Windows.Forms.TabPage "Nâng Cao"
$tabOpt = New-Object System.Windows.Forms.TabPage "Tối Ưu"
$tabSec = New-Object System.Windows.Forms.TabPage "Bảo Mật"
$tabPriv = New-Object System.Windows.Forms.TabPage "Riêng Tư"
$tabWinget = New-Object System.Windows.Forms.TabPage "Cập Nhật App"
$tabUtils = New-Object System.Windows.Forms.TabPage "Tiện Ích"

$tabs = @($tabBasic, $tabAdv, $tabOpt, $tabSec, $tabPriv, $tabWinget, $tabUtils)
foreach ($t in $tabs) { $t.BackColor = $Color_Panel; $t.UseVisualStyleBackColor = $true; $t.AutoScroll = $true; $tabControl.Controls.Add($t) }
$form.Controls.Add($tabControl)

# --- 5. CORE LOGIC (TACH RIENG DE NUT NAO CUNG GOI DUOC) ---
# Ham chay lenh an toan (Chong treo giao dien)
function Run-Safe($cmd, $args, $timeoutSeconds = 300) {
    $p = Start-Process $cmd $args -PassThru -NoNewWindow -ErrorAction SilentlyContinue
    if ($p) {
        $timeout = [datetime]::Now.AddSeconds($timeoutSeconds)
        
        while (-not $p.HasExited) {
            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 100
            
            # ✅ Timeout protection
            if ([datetime]::Now -gt $timeout) {
                $p.Kill()
                throw "Timeout sau $timeoutSeconds giây"
            }
        }
        
        # ✅ Kiểm tra exit code
        if ($p.ExitCode -ne 0) {
            throw "Lệnh thất bại với mã lỗi: $($p.ExitCode)"
        }
    }
}

# Logic xu ly chinh (Dung chung cho ca Nut to va Nut nho)
$CoreLogic = {
    param($taskList)
    
    $btnRun.Enabled = $false
    $prog.Value = 0
    
    if($taskList.Count -eq 0){ [System.Windows.Forms.MessageBox]::Show("Chưa chọn mục nào!"); $btnRun.Enabled=$true; return }

    $i=0
    foreach($k in $taskList.Keys){
        $i++
        $prog.Value=[int](($i/$taskList.Count)*100)
        # Cap nhat giao dien ngay lap tuc
        $logBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] Đang xử lý: $($taskList[$k])...`n"); $logBox.ScrollToCaret(); $form.Refresh()
        [System.Windows.Forms.Application]::DoEvents() # Chong treo
        
        try{
            switch($k){
                "TempFiles"{Remove-Item "$env:TEMP\*" -Recurse -Force -EA 0; Remove-Item "$env:windir\Temp\*" -Recurse -Force -EA 0}
                "RecycleBin"{Clear-RecycleBin -Force -EA 0}
                "BrowserCache"{Stop-Process -Name chrome,msedge,firefox -Force -EA 0; Start-Sleep 1; Remove-Item "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache\*" -Recurse -Force -EA 0}
                "WinUpdateCache"{Stop-Service wuauserv -EA 0; Remove-Item "$env:windir\SoftwareDistribution\Download\*" -Recurse -Force -EA 0; Start-Service wuauserv}
                "ThumbnailCache"{Stop-Process -Name explorer -Force -EA 0; Start-Sleep 1; Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db" -Force -EA 0; Start-Process explorer}
                
                # --- CAC TAC VU NANG (Dung Run-Safe de chong treo) ---
                "WinSxS"{ 
					try {
						Run-Safe "dism. exe" "/Online /Cleanup-Image /StartComponentCleanup /ResetBase" 600
					} catch {
						throw $_
					}
				}
                "StoreCache"{ Run-Safe "wsreset" "" }
                "Hibernation"{ 
					Start-Process "powercfg. exe" -ArgumentList "/hibernate off" -Wait -NoNewWindow
				}
                "CompressNTFS"{ Run-Safe "compact" "/CompactOS:always" }
                
                "StartupOptimize"{Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Serialize" -Name "StartupDelayInMSec" -Value 0 -Type DWORD -Force -EA 0}
                "ServiceOptimize"{Stop-Service "DiagTrack" -EA 0; Set-Service "DiagTrack" -StartupType Disabled -EA 0}
                "BasicMalware"{ 
					Start-MpScan -ScanType QuickScan -AsJob | Out-Null
				}
                "EnsureFirewallEnabled"{Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True}
                "EnablePUAProtection"{Set-MpPreference -PUAProtection Enabled}
                "DisableMicrophone"{Disable-PnpDevice -Class 'AudioEndpoint' -Confirm:$false -EA 0}
                "DisableAdvertisingID"{Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Enabled" -Value 0 -Type DWord -Force -EA 0}
                "DisableTelemetryServices"{Stop-Service "DiagTrack","dmwappushservice" -EA 0}
                
                "HighPerfPlan"{ 
					$guid = (powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61)
					if ($guid -match '\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b') {
						powercfg /setactive $matches[0]
					}
				}
                "DisableGameDVR"{ Set-ItemProperty "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -Value 0 -Type DWord -Force -EA 0 }
                "DisableStickyKeys"{ Set-ItemProperty "HKCU:\Control Panel\Accessibility\StickyKeys" -Name "Flags" -Value 506 -Type String -Force -EA 0 }
                "ShowExtensions"{ Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0 -Type DWord -Force -EA 0; Stop-Process -Name explorer -Force -EA 0; Start-Process explorer }
                "DisableRemoteAssist"{ Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance" -Name "fAllowToGetHelp" -Value 0 -Type DWord -Force -EA 0 }
                "DisableSMB1"{ Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force -EA 0 }
                "DisableCortana"{ Set-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "AllowCortana" -Value 0 -Type DWord -Force -EA 0 }
                "DisableStartSugg"{ Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SystemPaneSuggestionsEnabled" -Value 0 -Type DWord -Force -EA 0 }
                "DisableFeedback"{ Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Siuf\Rules" -Name "NumberOfSIUFInPeriod" -Value 0 -Type DWord -Force -EA 0 }
            }
            $logBox.AppendText("-> [OK]`n"); $logBox.ScrollToCaret()
        }catch{
            $logBox.AppendText("-> [SKIP/ERROR]`n"); $logBox.ScrollToCaret()
        }
    }
    $logBox.AppendText("=== HOÀN TẤT ===`n"); $logBox.ScrollToCaret()
    [System.Windows.Forms.MessageBox]::Show("Đã hoàn thành tác vụ!", "Thông báo")
    $btnRun.Enabled=$true
}

# --- 6. HAM TAO UI (DA GAN LOGIC CHO NUT CHAY NHANH) ---
function Add-TaskItem($tab, $items, $hasQuickAction=$false) {
    $y = 20
    $dict = @{}
    
    $btnAll = New-Object System.Windows.Forms.Button
    $btnAll.Text = "Chọn Tất Cả"; $btnAll.Location = New-Object System.Drawing.Point(30, $y); $btnAll.Size = New-Object System.Drawing.Size(120, 35)
    $btnAll.Add_Click({ $this.Parent.Controls | Where {$_.GetType() -eq [System.Windows.Forms.CheckBox]} | ForEach { $_.Checked = $true } })
    $tab.Controls.Add($btnAll)
    
    $btnNone = New-Object System.Windows.Forms.Button
    $btnNone.Text = "Bỏ Chọn"; $btnNone.Location = New-Object System.Drawing.Point(160, $y); $btnNone.Size = New-Object System.Drawing.Size(120, 35)
    $btnNone.Add_Click({ $this.Parent.Controls | Where {$_.GetType() -eq [System.Windows.Forms.CheckBox]} | ForEach { $_.Checked = $false } })
    $tab.Controls.Add($btnNone)

    if ($hasQuickAction) {
        $btnQuick = New-Object System.Windows.Forms.Button
        $btnQuick.Text = "CHẠY NHANH TAB NÀY"; $btnQuick.Location = New-Object System.Drawing.Point(700, $y); $btnQuick.Size = New-Object System.Drawing.Size(200, 35)
        $btnQuick.BackColor = $Color_Green; $btnQuick.ForeColor = [System.Drawing.Color]::White; $btnQuick.FlatStyle = "Flat"
        
        # FIX: Gan su kien Click cho nut chay nhanh
		$btnQuick.Add_Click({
			# ✅ Ngăn click nhiều lần
			if (-not $this.Enabled) { return }
			$this.Enabled = $false
    
			$currentTasks = @{}
			$this.Parent.Controls | Where-Object {
				$_.GetType() -eq [System.Windows.Forms.CheckBox] -and $_.Checked
			} | ForEach-Object { 
				$currentTasks[$_.Tag] = $_.Text 
			}
    
			& $CoreLogic $currentTasks
    
			# ✅ Bật lại nút sau khi chạy xong
			$this.Enabled = $true
		}. GetNewClosure())  # ✅ QUAN TRỌNG: Tránh scope leak
        
        $tab.Controls.Add($btnQuick)
    }
    
    $y += 50

    foreach ($i in $items) {
        $chk = New-Object System.Windows.Forms.CheckBox
        $chk.Text = $i.T; $chk.Tag = $i.Tag
        $chk.Location = New-Object System.Drawing.Point(30, $y); $chk.Size = New-Object System.Drawing.Size(320, 25)
        $chk.Font = $Font_Title; $chk.ForeColor = $Color_Text; $chk.Cursor = "Hand"
        $tooltip.SetToolTip($chk, $i.D)
        
        $lbl = New-Object System.Windows.Forms.Label
        $lbl.Text = $i.D; $lbl.Location = New-Object System.Drawing.Point(360, $y+3); $lbl.Size = New-Object System.Drawing.Size(580, 25)
        $lbl.ForeColor = $Color_Desc; $lbl.Font = $Font_Desc
        $tooltip.SetToolTip($lbl, $i.D)

        $tab.Controls.Add($chk); $tab.Controls.Add($lbl)
        $dict[$i.Tag] = $chk
        $y += 35
    }
    return $dict
}

# --- 7. NOI DUNG (GIU NGUYEN NHU CU) ---
$chkBasic = Add-TaskItem $tabBasic @(
    @{T="Dọn thư mục Temp"; Tag="TempFiles"; D="Xóa các file rác (.tmp, .log) do phần mềm tạo ra khi chạy."},
    @{T="Dọn Thùng rác"; Tag="RecycleBin"; D="Làm sạch hoàn toàn các file đang nằm trong Thùng rác."},
    @{T="Xóa cache trình duyệt"; Tag="BrowserCache"; D="Xóa bộ nhớ đệm Chrome/Edge/Firefox (Giữ Pass)."},
    @{T="Dọn Windows Update Cache"; Tag="WinUpdateCache"; D="Xóa các file Update cũ (Giải phóng 5-10GB)."},
    @{T="Xóa file Prefetch"; Tag="Prefetch"; D="Xóa bộ đệm khởi động cũ."},
    @{T="Xóa bản tải xuống cũ"; Tag="OldDownloads"; D="Xóa file trong Downloads cũ hơn 30 ngày."},
    @{T="Dọn Event Logs"; Tag="EventLogs"; D="Xóa nhật ký lỗi hệ thống."},
    @{T="Dọn thumbnail cache"; Tag="ThumbnailCache"; D="Sửa lỗi icon bị trắng."}
) $true

$chkAdv = Add-TaskItem $tabAdv @(
    @{T="Dọn dẹp WinSxS (Sâu)"; Tag="WinSxS"; D="Phân tích sâu và xóa thành phần Win thừa (Rất lâu, Anti-Freeze ON)."},
    @{T="Reset Microsoft Store"; Tag="StoreCache"; D="Sửa lỗi không tải được ứng dụng Store."},
    @{T="Dọn OneDrive Cache"; Tag="OneDriveCache"; D="Xóa file log và setup tạm của OneDrive."},
    @{T="Tắt Ngủ Đông (Hibernation)"; Tag="Hibernation"; D="Tắt ngủ đông, lấy lại dung lượng ổ C."},
    @{T="Dọn Cache Font"; Tag="FontCache"; D="Sửa lỗi hiển thị font chữ."},
    @{T="Nén hệ thống (CompactOS)"; Tag="CompressNTFS"; D="Nén Win, tiết kiệm 2-4GB (Lâu)."}
) $true

$chkOpt = Add-TaskItem $tabOpt @(
    @{T="Tối ưu hóa khởi động"; Tag="StartupOptimize"; D="Tắt độ trễ khởi động."},
    @{T="Bật chế độ Hiệu suất cao"; Tag="HighPerfPlan"; D="Kích hoạt Ultimate Performance Plan."},
    @{T="Tắt Game DVR (Tăng FPS)"; Tag="DisableGameDVR"; D="Tắt quay phim nền Xbox."},
    @{T="Tắt Phím dính (Sticky Keys)"; Tag="DisableStickyKeys"; D="Tắt hộp thoại Shift 5 lần."},
    @{T="Tối ưu hóa dịch vụ"; Tag="ServiceOptimize"; D="Tắt Fax, Print Spooler, Telemetry..."},
    @{T="Tối ưu hóa Page File"; Tag="PageFileOptimize"; D="Reset bộ nhớ ảo tự động."},
    @{T="Tối ưu hóa Hiệu ứng ảnh"; Tag="VisualPerformance"; D="Tắt hiệu ứng mờ để máy nhanh hơn."},
    @{T="Tối ưu hóa Windows Search"; Tag="SearchOptimize"; D="Rebuild Index tìm kiếm."},
    @{T="Tối ưu hóa Tắt máy"; Tag="ShutdownOptimize"; D="Giảm thời gian chờ ứng dụng treo."}
) $true

$chkSec = Add-TaskItem $tabSec @(
    @{T="Quét Virus Nhanh"; Tag="BasicMalware"; D="Windows Defender Quick Scan."},
    @{T="Hiện đuôi file (Extension)"; Tag="ShowExtensions"; D="Hiển thị .exe, .pdf tránh virus giả mạo."},
    @{T="Tắt Hỗ trợ từ xa"; Tag="DisableRemoteAssist"; D="Chặn Remote Assistance."},
    @{T="Tắt giao thức SMBv1"; Tag="DisableSMB1"; D="Chặn lỗ hổng WannaCry."},
    @{T="Xóa Lịch sử Web"; Tag="BrowserHistory"; D="Xóa lịch sử web đã truy cập."},
    @{T="Kiểm tra Cập nhật Win"; Tag="WindowsUpdate"; D="Mở trình cập nhật Windows."},
    @{T="Kiểm tra Tường lửa"; Tag="EnsureFirewallEnabled"; D="Bật lại Windows Firewall."},
    @{T="Bật Chống phần mềm rác"; Tag="EnablePUAProtection"; D="Chặn ứng dụng tiềm ẩn nguy hiểm (PUA)."}
) $true

$chkPriv = Add-TaskItem $tabPriv @(
    @{T="Tắt Micro (Toàn hệ thống)"; Tag="DisableMicrophone"; D="Vô hiệu hóa Driver Micro."},
    @{T="Tắt Camera (Toàn hệ thống)"; Tag="DisableCamera"; D="Vô hiệu hóa Driver Webcam."},
    @{T="Tắt Cortana & Copilot"; Tag="DisableCortana"; D="Tắt trợ lý ảo AI."},
    @{T="Tắt Gợi ý Start Menu"; Tag="DisableStartSugg"; D="Tắt quảng cáo trong Start Menu."},
    @{T="Tắt Thông báo Feedback"; Tag="DisableFeedback"; D="Chặn cửa sổ hỏi ý kiến người dùng."},
    @{T="Tắt ID Quảng cáo"; Tag="DisableAdvertisingID"; D="Ngăn theo dõi quảng cáo."},
    @{T="Tắt Telemetry (Theo dõi)"; Tag="DisableTelemetryServices"; D="Chặn gửi dữ liệu chẩn đoán."},
    @{T="Xóa Lịch sử Hoạt động"; Tag="ClearActivityHistory"; D="Xóa Timeline hoạt động."},
    @{T="Tắt Theo dõi Vị trí"; Tag="DisableLocationTracking"; D="Vô hiệu hóa GPS."}
) $true

# Winget & Utilities (Giu nguyen)
$lblW = New-Object System.Windows.Forms.Label; $lblW.Text = "CÔNG CỤ CẬP NHẬT PHẦN MỀM TỰ ĐỘNG (WINGET)"; $lblW.Font = $Font_Title; $lblW.AutoSize = $true; $lblW.Location = New-Object System.Drawing.Point(30, 30)
$btnW = New-Object System.Windows.Forms.Button; $btnW.Text = "KIỂM TRA VÀ CẬP NHẬT TẤT CẢ"; $btnW.Size = New-Object System.Drawing.Size(350, 60); $btnW.Location = New-Object System.Drawing.Point(30, 80); $btnW.BackColor = $Color_Green; $btnW.ForeColor = [System.Drawing.Color]::White; $btnW.Font = $Font_Title
$btnW.Add_Click({ Start-Process "winget" -ArgumentList "upgrade --all --include-unknown --accept-source-agreements" -Wait; [System.Windows.Forms.MessageBox]::Show("Đã cập nhật xong!", "Winget") })
$tabWinget.Controls.Add($lblW); $tabWinget.Controls.Add($btnW)

$col1_X = 40; $col2_X = 500; $yStart = 40; $yStep = 85
$utils = @(@{T="Disk Cleanup"; Tag="DiskMgr"; D="Mở công cụ dọn dẹp Windows."}, @{T="Xóa Cache DNS"; Tag="FlushDnsCache"; D="Sửa lỗi mạng."}, @{T="Sức khỏe Ổ cứng"; Tag="ChkDsk"; D="Xem SMART ổ cứng."}, @{T="Quản lý Khởi động"; Tag="StartupManager"; D="Mở Task Manager."}, @{T="Backup Registry"; Tag="RegBack"; D="Sao lưu Registry."}, @{T="Phân vùng Ổ đĩa"; Tag="DiskPart"; D="Mở Disk Management."}, @{T="Reset Mạng"; Tag="ResetNetworkStack"; D="Cài lại Driver mạng."}, @{T="Sửa lỗi Win (SFC)"; Tag="FixCommonIssues"; D="Chạy SFC Scannow."})
for ($i=0; $i -lt $utils.Count; $i++) {
    $u = $utils[$i]; $row = [math]::Floor($i / 2); $isCol2 = ($i % 2 -eq 1); $posX = if ($isCol2) { $col2_X } else { $col1_X }; $posY = $yStart + ($row * $yStep)
    $b = New-Object System.Windows.Forms.Button; $b.Text = $u.T; $b.Location = New-Object System.Drawing.Point($posX, $posY); $b.Size = New-Object System.Drawing.Size(250, 40); $b.Tag = $u.Tag; $b.FlatStyle = "Standard"; $b.BackColor = [System.Drawing.Color]::White; $b.Font = $Font_Title
    $l = New-Object System.Windows.Forms.Label; $l.Text = $u.D; $l.Location = New-Object System.Drawing.Point($posX, $posY+42); $l.AutoSize = $true; $l.ForeColor = $Color_Desc; $l.Font = $Font_Desc
    $tabUtils.Controls.Add($b); $tabUtils.Controls.Add($l)
    $b.Add_Click({ $t=$this.Tag; switch($t){ "DiskMgr"{Start-Process cleanmgr}; "FlushDnsCache"{Invoke-Expression "ipconfig /flushdns"}; "RegBack"{Start-Process reg -ArgumentList "export HKCU `"$env:USERPROFILE\Desktop\Backup.reg`""}; "ChkDsk"{Get-PhysicalDisk|Select FriendlyName,HealthStatus|Out-GridView}; "ResetNetworkStack"{Start-Process netsh -ArgumentList "int ip reset" -Wait; [System.Windows.Forms.MessageBox]::Show("Xong! Restart máy.")}; "StartupManager"{Start-Process taskmgr}; "FixCommonIssues"{Start-Process sfc -ArgumentList "/scannow"}; "DiskPart"{Start-Process diskmgmt.msc} } })
}

# --- SYSTEM INFO ---
$infoPanel = New-Object System.Windows.Forms.Panel; $infoPanel.Size = New-Object System.Drawing.Size(965, 80); $infoPanel.Location = New-Object System.Drawing.Point(10, 520); $infoPanel.BackColor = [System.Drawing.Color]::WhiteSmoke; $infoPanel.BorderStyle = "FixedSingle"
$os = (Get-CimInstance Win32_OperatingSystem).Caption; $cpu = (Get-CimInstance Win32_Processor).Name; $ram = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" | Select @{N='Free';E={[math]::Round($_.FreeSpace/1GB,2)}}, @{N='Total';E={[math]::Round($_.Size/1GB,2)}}
$lblLeft = New-Object System.Windows.Forms.Label; $lblLeft.Text = "HỆ ĐIỀU HÀNH: $os`nCPU: $cpu`nRAM: $ram GB"; $lblLeft.Location = New-Object System.Drawing.Point(10, 10); $lblLeft.Size = New-Object System.Drawing.Size(450, 60); $lblLeft.Font = $Font_Normal; $infoPanel.Controls.Add($lblLeft)
$lblRight = New-Object System.Windows.Forms.Label; $lblRight.Text = "Ổ C (HỆ THỐNG):`nTrống: $($disk.Free) GB / Tổng: $($disk.Total) GB"; $lblRight.Location = New-Object System.Drawing.Point(500, 10); $lblRight.Size = New-Object System.Drawing.Size(450, 60); $lblRight.Font = $Font_Title; $lblRight.TextAlign = "TopRight"; $infoPanel.Controls.Add($lblRight)
$form.Controls.Add($infoPanel)

# --- FOOTER ---
$footerPanel = New-Object System.Windows.Forms.Panel; $footerPanel.Size = New-Object System.Drawing.Size(1000, 110); $footerPanel.Location = New-Object System.Drawing.Point(0, 610); $footerPanel.BackColor = [System.Drawing.Color]::White
$logBox = New-Object System.Windows.Forms.RichTextBox; $logBox.Location = New-Object System.Drawing.Point(15, 10); $logBox.Size = New-Object System.Drawing.Size(700, 90); $logBox.Font = New-Object System.Drawing. Font("Consolas", 10, [System.Drawing.FontStyle]::Regular); $logBox.ReadOnly = $true; $logBox.BorderStyle = "FixedSingle"; $logBox.DetectUrls = $false; $footerPanel.Controls.Add($logBox)
$btnRun = New-Object System.Windows.Forms.Button; $btnRun.Text = "BẮT ĐẦU THỰC HIỆN"; $btnRun.Location = New-Object System.Drawing.Point(730, 10); $btnRun.Size = New-Object System.Drawing.Size(240, 50); $btnRun.BackColor = $Color_Accent; $btnRun.ForeColor = [System.Drawing.Color]::White; $btnRun.Font = $Font_Title; $btnRun.FlatStyle = "Flat"; $footerPanel.Controls.Add($btnRun)
$prog = New-Object System.Windows.Forms.ProgressBar; $prog.Location = New-Object System.Drawing.Point(730, 70); $prog.Size = New-Object System.Drawing.Size(240, 20); $footerPanel.Controls.Add($prog)
$form.Controls.Add($footerPanel)

# --- LINK MAIN BUTTON ---
$btnRun. Add_Click({ 
    $allTasks = @{}
    $tabControl.TabPages | ForEach-Object { 
        $_.Controls | Where-Object {
            $_.GetType() -eq [System.Windows.Forms.CheckBox] -and $_.Checked
        } | ForEach-Object { 
            $allTasks[$_.Tag] = $_.Text 
        } 
    }
    & $CoreLogic $allTasks 
})

$form.ShowDialog() | Out-Null
