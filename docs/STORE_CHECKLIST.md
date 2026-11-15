# ROLL 36 — Checklist phát hành App Store

Nguồn: `PLAN.md` §7.4, §12, §15.3, §16, §17. Chưa làm bước nào dưới đây liên quan đến App Store Connect (ASC), developer portal hay GitHub.

## 1. Đã làm (trong repo)

- [x] App icon master `docs/brand/app-icon.svg`: 1024×1024, phẳng, không alpha, không gradient/bóng. Nền `#14120E`, dải phim `#221F1A` có lỗ sprocket, khung hình amber `#EF9F27` chứa số "36" đậm. Đọc rõ ở 60 px.
- [x] Render bằng `python3 scripts/render_app_icon.py` ra 3 icon (`AppIcon`, `AppIcon-Staging`, `AppIcon-Dev`), đã kiểm tra 1024×1024 RGB, `hasAlpha: no`.
- [x] Metadata `fastlane/metadata/{vi,en-US}`: `name`, `subtitle`, `description`, `keywords`, `promotional_text`, `release_notes`; URL (privacy/support/marketing) giữ nguyên như scaffold.
- [x] `fastlane/metadata/primary_category.txt` = `PHOTO_AND_VIDEO` (giá trị fastlane deliver/spaceship map sang Photo & Video; giá trị cũ `PRODUCTIVITY` của scaffold đã bỏ).
- [x] `fastlane/metadata/review_information/notes.txt`: giải thích quyền camera/ảnh, ảnh bị giấu đến khi tráng, 60 phút chờ là chủ đích, cách test IAP, không cần đăng nhập.

Số ký tự (giới hạn):

| Trường | en-US | vi | Giới hạn |
|---|---|---|---|
| name | 7 | 7 | 30 |
| subtitle | 24 | 27 | 30 |
| keywords | 95 | 96 | 100 |
| promotional_text | 156 | 145 | 170 |
| description | 2095 | 2080 | 4000 |
| release_notes | 181 | 174 | 4000 |

Tuân thủ: không có chữ "free" trong name/subtitle, không tên thương hiệu đối thủ (Kodak/Fuji…) trong name/subtitle/keywords. Tên film chỉ nằm trong description, kèm câu tuyên bố không liên kết với nhà sản xuất.

## 2. Việc làm tay (KHÔNG tự động hóa)

### 2.1 Tên app và ASC record

- [ ] Tên "ROLL 36" phải chưa bị ai dùng trên toàn store. Nếu trùng, đổi dạng "ROLL 36: Film Camera" (vẫn ≤ 30) rồi sửa `name.txt` cả hai ngôn ngữ.
- [ ] Tạo App ID + ASC record cho 3 môi trường (mỗi môi trường một bundle id, xem `Config/{Dev,Staging,Prod}.xcconfig`). Prod: `com.lequangtrongtai.roll36`, Staging: `com.lequangtrongtai.roll36.staging`, Dev: `com.lequangtrongtai.roll36.dev`.
- [ ] Primary language, SKU, Primary category = Photo & Video trong ASC. Không cần secondary category.
- [ ] Copyright: kiểm tra `fastlane/metadata/copyright.txt` (scaffold: `2026 iletai`), đổi nếu muốn tên khác.

### 2.2 App Privacy và Age Rating (ASC UI)

- [ ] App Privacy: chọn **Data Not Collected** (không tài khoản, không analytics, không SDK ngoài). Chỉ chọn khi build thật đúng như vậy; privacy manifest `NSPrivacyTracking = false`.
- [ ] Privacy Policy URL đã trỏ `https://apps-site-six.vercel.app/apps/roll36/privacy`; kiểm tra trang public và nêu rõ: ảnh nằm trên máy, xóa app là mất ảnh.
- [ ] Age rating **4+**. Trả lời bảng câu hỏi mới: không nội dung nhạy cảm, không quảng cáo (app không có ad SDK), không web truy cập tự do, không UGC chia sẻ, có giao dịch trong app (IAP không phải loot box/gambling).
- [ ] Export compliance: `ITSAppUsesNonExemptEncryption = false` (kiểm tra Info.plist).

### 2.3 In-App Purchase (tạo trên từng ASC record)

Mọi sản phẩm là **Non-Consumable**, không có subscription, không có consumable. Id = `<env bundle id>.full` và `<env bundle id>.film.<stockID>`. `portra400` miễn phí nên không có IAP riêng. Bảng dưới cho bundle id Prod `com.lequangtrongtai.roll36` (14 sản phẩm: 1 full + 13 film lẻ):

| Product ID | Giá (USD) | Nội dung |
|---|---|---|
| `com.lequangtrongtai.roll36.full` | $4.99 (ra mắt 14 ngày) → $9.99 | 14 stock, import không giới hạn, tráng song song, bỏ watermark |
| `com.lequangtrongtai.roll36.film.ektar100` | $1.49 | Ektar 100 |
| `com.lequangtrongtai.roll36.film.fuji400h` | $1.49 | Pro 400H |
| `com.lequangtrongtai.roll36.film.gold200` | $0.99 | Gold 200 |
| `com.lequangtrongtai.roll36.film.ultramax400` | $0.99 | UltraMax 400 |
| `com.lequangtrongtai.roll36.film.trix400` | $1.49 | Tri-X 400 |
| `com.lequangtrongtai.roll36.film.hp5` | $1.49 | HP5 Plus |
| `com.lequangtrongtai.roll36.film.acros100` | $0.99 | Acros 100 |
| `com.lequangtrongtai.roll36.film.cinestill800t` | $1.49 | Cinestill 800T |
| `com.lequangtrongtai.roll36.film.portra800` | $1.49 | Portra 800 |
| `com.lequangtrongtai.roll36.film.expiredGold` | $0.99 | Expired Gold |
| `com.lequangtrongtai.roll36.film.expiredFuji` | $0.99 | Expired Fuji |
| `com.lequangtrongtai.roll36.film.velvia50` | $1.49 | Velvia 50 |
| `com.lequangtrongtai.roll36.film.provia100` | $1.49 | Provia 100F |

Với Dev/Staging thay prefix bằng bundle id môi trường đó (Dev khớp `App/Monetization/ROLL36.storekit`).

- [ ] Mỗi sản phẩm cần: Reference Name, giá, localization vi + en (tên + mô tả hiển thị), ảnh review screenshot (paywall/library), review notes. Tên hiển thị ngắn, không dùng "unlock" mơ hồ.
- [ ] Đối chiếu giá với `ProductCatalog` trong code (đơn vị cent) trước khi lưu; giá hiển thị trong app lấy từ StoreKit nên sai giá ở ASC sẽ lộ ngay.
- [ ] Gửi IAP cùng lần submit đầu của version 1.0 (Add for Review trên version, rồi từng IAP nếu cần).
- [ ] Đổi giá `.full` từ $4.99 lên $9.99 sau 14 ngày: sửa ở ASC, không cần build mới.

### 2.4 TestFlight

- [ ] Tạo nhóm Internal (Dev/Staging) và External (Staging/Prod) theo quy ước house. Điền Beta App Description, feedback email, What to Test (nhắc tester: cần chờ 60 phút để tráng, hoặc dùng Darkroom import để thử nhanh).
- [ ] Build qua workflow CI (`deploy-*.yml`), không build local. Kiểm tra `gh secret list` trước khi chạy.

### 2.5 Screenshot

- [ ] Kích thước 6.9" (1320×2868 hoặc 1290×2796) và 6.5" (1242×2688 hoặc 1284×2778).
- [ ] 15 ảnh mẫu chụp bằng chính app, đủ 5 stock khác nhau (PLAN §16). Ảnh mẫu là công cụ marketing chính.
- [ ] Bộ đề xuất: viewfinder (EXP 12/36), darkroom đang tráng, contact sheet, thư viện film, import. Cả bản vi và en. Không lộ ảnh trước khi tráng trong màn viewfinder.
- [ ] Không dùng ảnh người thật chưa có sự đồng ý.

### 2.6 Test trên máy thật (PLAN §15.3, bắt buộc trước khi submit)

- [ ] Camera: quyền, chụp đủ 36 tấm, khóa khi hết cuộn, flash, đổi lens.
- [ ] Hiệu năng: preview ≥ 24 FPS (nếu bật live LUT), xử lý full res trên iPhone cũ (đo trên iPhone 13).
- [ ] Haptic, grain ở full res, màu thực tế.
- [ ] Tráng phim: bấm tráng, kill app, mở lại sau 60 phút vẫn đúng; thông báo khi tráng xong (nếu có).
- [ ] IAP sandbox: mua lẻ, mua full, restore, hủy giữa chừng, Ask to Buy.
- [ ] Xóa app cài lại: mất ảnh đúng như mô tả.
- [ ] Đối chiếu lại `review_information/notes.txt` và `description.txt` với bản build cuối: Import (tráng ngay, không chờ), nút Restore (Library + Settings), watermark chỉ có ở bản chưa mua.

### 2.7 Hiệu chỉnh LUT với film thật (PLAN §17, rủi ro số 1)

- [ ] So sánh từng stock với ảnh film thật cùng cảnh; chỉnh `FilmProfile`. Nếu màu không đủ thật thì không ai trả tiền. Làm xong trước khi chụp screenshot.

### 2.8 Rủi ro review cần để ý

- Review viên không thể chờ 60 phút để xem contact sheet của cuộn chụp bằng camera. Notes đã chỉ họ sang Darkroom import (tráng ngay) để xem tất cả film. Nếu bị hỏi, trả lời rằng chờ là tính năng cốt lõi (PLAN §10.4: không có skip). Cân nhắc một lối tắt chỉ có ở môi trường không phải Prod nếu cần cho TestFlight, không đưa vào bản Prod.
- Từ "free" không được xuất hiện trong tên app (đã đảm bảo). Description nói rõ free kèm giới hạn và IAP là nội dung số.
- Tên film (Portra, Tri-X, Velvia…) là nhãn hiệu của bên thứ ba. Chỉ dùng mô tả, có câu không liên kết; nếu bị phản hồi, đổi sang tên mô tả chung.

## 3. Upload metadata (khi sẵn sàng, làm tay hoặc theo lệnh riêng)

`fastlane deliver` chỉ metadata, `--skip_binary_upload true`, rồi attach build và Submit for Review trong ASC. Không push và không submit khi chưa có lệnh rõ ràng.
