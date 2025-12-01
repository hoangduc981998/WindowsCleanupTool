Tốt!  Đây là nội dung HOÀN CHỈNH cho file `HUONG_DAN_SU_DUNG.md`:

---

```markdown
# 📖 Hướng Dẫn Sử Dụng WindowsCleanupTool v2.0

## 🎯 Dành cho người dùng cuối (không cần kiến thức kỹ thuật)

---

## 📋 Mục Lục

1. [Giới Thiệu](#giới-thiệu)
2.  [Tải Về và Cài Đặt](#tải-về-và-cài-đặt)
3. [Hướng Dẫn Sử Dụng](#hướng-dẫn-sử-dụng)
4. [Các Tính Năng](#các-tính-năng)
5. [Cách Khôi Phục File](#cách-khôi-phục-file)
6.  [Câu Hỏi Thường Gặp](#câu-hỏi-thường-gặp)
7. [Lưu Ý Quan Trọng](#lưu-ý-quan-trọng)

---

## Giới Thiệu

**WindowsCleanupTool** là công cụ dọn dẹp máy tính Windows **MIỄN PHÍ**, giúp:
- ✅ Giải phóng dung lượng ổ cứng (2-5 GB)
- ✅ Tăng tốc độ máy tính
- ✅ Xóa file rác, cache không cần thiết
- ✅ **AN TOÀN 100%** - Có thể hoàn tác trong 7 ngày

### 🛡️ Tại Sao An Toàn? 
- ❌ KHÔNG xóa file hệ thống quan trọng
- ❌ KHÔNG xóa file cá nhân (Documents, Pictures, Videos...)
- ✅ File xóa được **LƯU TRỮ** trong 7 ngày (có thể khôi phục)
- ✅ Tự động tạo điểm khôi phục hệ thống

---

## Tải Về và Cài Đặt

### 📥 Bước 1: Tải Về

**Click vào link này để tải:**
👉 **[Tải WindowsCleanupTool (ZIP)](https://github.com/hoangduc981998/WindowsCleanupTool/archive/refs/heads/main.zip)**

Hoặc:
1. Truy cập: https://github.com/hoangduc981998/WindowsCleanupTool
2. Click nút **"Code"** (màu xanh lá)
3. Chọn **"Download ZIP"**

### 📂 Bước 2: Giải Nén

1. Tìm file **`WindowsCleanupTool-main. zip`** vừa tải (thường trong thư mục Downloads)
2. **Click chuột phải** vào file ZIP
3. Chọn **"Extract All..."** hoặc **"Giải nén tất cả..."**
4. Chọn vị trí lưu (ví dụ: `C:\CleanupTool`)

### 🚀 Bước 3: Chạy Công Cụ

1.  Mở thư mục vừa giải nén
2. Tìm file **`CleanUpTool.ps1`** 
   - File có icon PowerShell (màu xanh)
   - **KHÔNG PHẢI file .exe**
3. **Click chuột phải** vào file `CleanUpTool.ps1`
4. Chọn **"Run with PowerShell"** (Chạy với PowerShell)
5. Click **"Yes"** khi Windows hỏi quyền Administrator

**⚠️ Lưu ý:** Nếu không thấy tùy chọn "Run with PowerShell":
- Click chuột phải → **"Open with"** → Chọn **"Windows PowerShell"**

---

## Hướng Dẫn Sử Dụng

### 📌 Bước 1: Chọn Mục Cần Dọn

Sau khi mở công cụ, bạn sẽ thấy giao diện với nhiều tab:

#### Tab "Dọn Dẹp Cơ Bản" ⭐ (Khuyến nghị)

Đánh dấu ✅ vào các mục sau:

| Mục | Mô Tả | Nên Chọn?  | Dung Lượng |
|-----|-------|-----------|------------|
| ✅ **Temp Files** | File tạm Windows | **NÊN** | ~1-3 GB |
| ✅ **Browser Cache** | Cache Chrome, Edge | **NÊN** | ~500 MB-2 GB |
| ✅ **Recycle Bin** | Thùng rác | **NÊN** | Tùy thuộc |
| ✅ **Windows Update Cache** | File cập nhật cũ | **NÊN** | ~500 MB-1 GB |
| ✅ **Thumbnail Cache** | Ảnh xem trước | **NÊN** | ~100-500 MB |

**⚠️ Không khuyến nghị (dùng khi hiểu rõ):**
- ❌ WinSxS Cleanup
- ❌ Hibernation File

### 📌 Bước 2: Chạy Dọn Dẹp

1. Click nút **"BẮT ĐẦU THỰC HIỆN"** (màu xanh lá, to)
2. Công cụ sẽ:
   - ✅ Tạo điểm khôi phục hệ thống
   - ✅ Ước tính dung lượng sẽ giải phóng
   - ✅ Bắt đầu dọn dẹp
3. Xem tiến trình trong **LogBox** (ô trắng bên dưới)

### 📌 Bước 3: Kiểm Tra Kết Quả

- ✅ Xem **LogBox** để biết file nào đã xóa
- ✅ File log chi tiết lưu tại: **Desktop\CleanupTool_[ngày]. log**
- ✅ Kiểm tra dung lượng ổ đĩa đã tăng (mở File Explorer → This PC)

---

## Các Tính Năng

### 1. 🧹 Dọn Dẹp Cơ Bản

**Các loại file được xóa:**
- File tạm (Temp Files)
- Cache trình duyệt (Browser Cache)
- Thùng rác (Recycle Bin)
- Cache Windows Update
- Thumbnail cache

**Thời gian:** ~1-3 phút  
**Dung lượng giải phóng:** ~500 MB - 5 GB

---

### 2. 🛡️ Hệ Thống An Toàn (Tự Động)

**Bảo vệ tự động:**
- ✅ File trong **Documents, Pictures, Desktop, Videos** KHÔNG bị xóa
- ✅ File hệ thống (`. dll`, `.exe`, `.sys`) KHÔNG bị xóa
- ✅ File đang mở/sử dụng KHÔNG bị xóa

**Bạn KHÔNG cần làm gì** - Hệ thống tự động bảo vệ! 

---

### 3. 📦 Hệ Thống Hoàn Tác (Quarantine)

**Tất cả file xóa được LƯU 7 NGÀY! **

#### 📍 Vị Trí Lưu File:
```
C:\Users\[TênBạn]\AppData\Local\CleanupTool\Quarantine\
```

---

### 4. 🔌 Dọn Cache Ứng Dụng (Tự Động)

Công cụ tự động dọn cache của:

| Ứng Dụng | Mục Dọn | Dung Lượng | Có Mất Dữ Liệu?  |
|----------|---------|------------|-----------------|
| **Spotify** | Cache nhạc | ~500 MB | ❌ Playlist an toàn |
| **Discord** | Cache hình ảnh | ~300 MB | ❌ Tin nhắn an toàn |
| **Steam** | Cache tải game | ~2 GB | ❌ Game an toàn |
| **VSCode** | Logs cũ (>7 ngày) | ~200 MB | ❌ Code an toàn |

---

## Cách Khôi Phục File

### 🔄 Phương Pháp 1: Thủ Công (Dễ Nhất)

1.  Mở **File Explorer** (Windows + E)
2. Copy-paste vào thanh địa chỉ:
   ```
   %LOCALAPPDATA%\CleanupTool\Quarantine
   ```
3. Tìm thư mục có tên **ngày giờ** (ví dụ: `20251201_140530`)
4. Tìm file cần khôi phục
5. **Copy** file về vị trí cũ hoặc Desktop

### 🔄 Phương Pháp 2: Dùng PowerShell

```powershell
# Xem danh sách file trong Quarantine
Get-ChildItem "$env:LOCALAPPDATA\CleanupTool\Quarantine" -Recurse -File

# Khôi phục file (thay đường dẫn thực tế)
Restore-FromQuarantine -QuarantinePath "C:\Users\.. .\Quarantine\.. .\file.tmp"
```

**⚠️ LƯU Ý:** File chỉ lưu **7 NGÀY**, sau đó tự động xóa vĩnh viễn!

---

## Câu Hỏi Thường Gặp

### ❓ Công cụ này có an toàn không? 

✅ **HOÀN TOÀN AN TOÀN! **
- Không xóa file hệ thống
- Không xóa file cá nhân
- File xóa được lưu 7 ngày (có thể khôi phục)

### ❓ File chạy là gì? 

👉 File **`CleanUpTool.ps1`** (PowerShell script)  
❌ **KHÔNG PHẢI** file `. exe`

### ❓ Có cần cài đặt không? 

❌ **KHÔNG CẦN! **
- Chỉ cần tải ZIP và chạy file `.ps1`
- Windows 10/11 đã có sẵn PowerShell

### ❓ Nếu xóa nhầm file quan trọng? 

👉 **Khôi phục trong 7 ngày:**
1. Mở: `%LOCALAPPDATA%\CleanupTool\Quarantine`
2. Tìm file trong thư mục ngày giờ
3. Copy về vị trí cũ

### ❓ Bao lâu nên chạy 1 lần? 

📅 **Khuyến nghị:**
- **Hàng tuần:** Nếu dùng máy nhiều
- **Hàng tháng:** Nếu dùng máy ít

### ❓ Có làm mất dữ liệu không?

❌ **KHÔNG** làm mất:
- File cá nhân (Documents, Pictures...)
- Ứng dụng đã cài
- Cài đặt Windows
- Email, danh bạ, bookmark

✅ **CHỈ XÓA:**
- File rác (Temp)
- Cache trình duyệt (tải lại được)
- Thùng rác

### ❓ Tôi có thể dùng ở công ty không? 

✅ **CÓ! **
- Miễn phí hoàn toàn
- Không cần Internet
- Không thu thập dữ liệu

---

## Lưu Ý Quan Trọng

### ⚠️ TRƯỚC KHI CHẠY:

1. ✅ **Đóng tất cả ứng dụng** (Chrome, Discord, Spotify...)
2. ✅ **Lưu công việc** đang làm
3. ✅ **Kiểm tra Recycle Bin** - File trong thùng rác sẽ bị xóa vĩnh viễn

### ⚠️ SAU KHI CHẠY:

1. ✅ **Khởi động lại máy** (khuyến nghị)
2. ✅ **Kiểm tra log** tại Desktop
3. ✅ **Trong 7 ngày** - File có thể khôi phục

### ⚠️ KHÔNG NÊN:

- ❌ Chạy khi đang **tải file lớn**
- ❌ Chạy khi đang **cài phần mềm**
- ❌ Chạy khi **pin < 20%**
- ❌ Chạy **nhiều lần liên tục** trong ngày

---

## Ví Dụ Thực Tế

### 📝 Tình Huống 1: Máy Chạy Chậm

**Vấn đề:**
- Máy khởi động lâu
- Ổ C: gần đầy (< 10 GB)

**Giải pháp:**
1. Chạy WindowsCleanupTool
2. Chọn: ✅ Temp, ✅ Browser Cache, ✅ Windows Update
3. Click "BẮT ĐẦU THỰC HIỆN"

**Kết quả:**
- Giải phóng ~2-5 GB
- Máy nhanh hơn

---

### 📝 Tình Huống 2: Xóa Nhầm File

**Vấn đề:**
- File quan trọng bị mất sau khi dọn

**Giải pháp:**
1. Mở: `%LOCALAPPDATA%\CleanupTool\Quarantine`
2. Tìm thư mục ngày gần nhất
3. Copy file về Desktop

---

## Liên Hệ Hỗ Trợ

### 📧 Email
**hoangduc981998@gmail. com**

### 🐛 Báo Lỗi
https://github.com/hoangduc981998/WindowsCleanupTool/issues

### 📚 Tài Liệu
- **Hướng dẫn kỹ thuật:** [DOCUMENTATION.md](https://github.com/hoangduc981998/WindowsCleanupTool/blob/main/DOCUMENTATION.md)
- **Lịch sử phiên bản:** [CHANGELOG.md](https://github.com/hoangduc981998/WindowsCleanupTool/blob/main/CHANGELOG.md)

---

## Quy Trình Sử Dụng (Tóm Tắt)

```
1. Tải ZIP từ GitHub
   ↓
2. Giải nén
   ↓
3. Click chuột phải CleanUpTool.ps1 → Run with PowerShell
   ↓
4. Đánh dấu ✅ mục cần dọn
   ↓
5. Click "BẮT ĐẦU THỰC HIỆN"
   ↓
6. Đợi 1-3 phút
   ↓
7. Khởi động lại máy
   ↓
8.  XONG!  Máy nhanh hơn
```

---

**Phiên bản:** 2.0.0  
**Ngày cập nhật:** 01/12/2025  
**Tác giả:** Hoàng Đức

---

## ⭐ Nếu Thấy Hữu Ích

Chia sẻ cho bạn bè và đồng nghiệp!   
**GitHub:** https://github.com/hoangduc981998/WindowsCleanupTool
```
