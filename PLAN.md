# ROLL 36 — Kế hoạch triển khai

> Tài liệu này là nguồn sự thật duy nhất cho việc implement. Đọc hết trước khi viết dòng code đầu tiên.
> Ngôn ngữ code: tiếng Anh. Ngôn ngữ UI: tiếng Việt + tiếng Anh (String Catalog).
> Ngôn ngữ tài liệu: tiếng Việt.

---

## 1. Sản phẩm là gì

**ROLL 36** — máy ảnh film analog cho iOS. Người dùng chụp vào một cuộn 36 tấm hữu hạn; ảnh **không** hiện ra ngay mà phải "tráng" và chờ. Sau khi tráng xong mới xem được. Ngoài ra có phòng rửa (Darkroom) cho phép áp film stock lên ảnh đã có trong thư viện.

**Hào cạnh tranh không phải filter.** Filter thì app nào cũng có. Hào là **sự khan hiếm và chờ đợi**: cuộn phim hữu hạn, ảnh bị giữ lại, mỗi lần bấm máy có trọng lượng. Mọi quyết định kỹ thuật dưới đây phục vụ cơ chế đó. Nếu một tính năng làm mất đi sự chờ đợi, đừng làm.

**Bối cảnh thị trường** (đã nghiên cứu, xem `research.md`):
- 6 app camera analog cùng nằm trong Top Paid 50 của App Store US → thị trường phân mảnh, người dùng sưu tầm film stock chứ không trung thành một app.
- `ism` bán **$7.99/tuần** và bị người dùng phản đối công khai → giá một lần là vũ khí.
- `mood.camera` ($14.99 trọn đời) **không cho import ảnh**, không live preview → khoảng trống rõ ràng.
- `Flipcorder` bán $4.99 một lần, không IAP, vẫn được báo chí đưa → mô hình giá đã được chứng minh.

---

## 2. Giả định cần xác nhận trước khi bắt đầu

Mấy điểm này tôi đã chọn mặc định. **Nếu sai, sửa ngay ở M0, đừng để lan ra code.**

| Hạng mục | Giá trị mặc định | Ghi chú |
|---|---|---|
| Tên app | `ROLL 36` | Display name. Không dấu cách trong bundle id |
| Bundle ID | `com.lequangtrongtai.roll36` | Đổi được, nhưng phải đổi cả StoreKit config + product ID |
| Product ID prefix | `com.lequangtrongtai.roll36.` | |
| Deployment target | **iOS 18.0** | Đủ reach, vẫn dùng được SwiftData + StoreKit 2 |
| Swift | **6.0 language mode**, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` | Xem mục 4.2 |
| Thiết bị test | iPhone 17 Pro (simulator), iPhone thật để test camera | Simulator **không có camera** — xem 11.6 |
| Giá | $4.99 ra mắt 14 ngày → $9.99 vĩnh viễn | Đổi giá chỉ cần sửa App Store Connect, không sửa code |
| Team ID | *(trống — ký tay)* | Claude Code không tự set signing |

---

## 3. Phạm vi v1

### 3.1 Có trong v1

- Chụp ảnh qua camera, áp film stock, lưu vào cuộn 36 tấm
- Đếm số tấm còn lại, khoá chụp khi hết cuộn
- Tráng phim theo thời gian thực (60 phút mặc định), tiến trình sống sót khi kill app
- Xem contact sheet 36 tấm sau khi tráng
- Áp film stock lên ảnh import từ thư viện (giới hạn 5 ảnh free)
- Thư viện 14 film stock, mua lẻ hoặc mua trọn bộ
- StoreKit 2: mua, restore, đồng bộ entitlement
- Dark mode only (app này cố tình chỉ có dark)
- Song ngữ Việt / Anh

### 3.2 KHÔNG làm trong v1 — và vì sao

| Không làm | Lý do |
|---|---|
| Quay video | Đẩy lịch từ 30 ngày lên 90. Để v1.1. Đây là khoảng trống lớn thứ ba nhưng không phải bây giờ |
| Subscription | Cố tình. Đây chính là điểm tấn công `ism` |
| Mua credit để tráng nhanh | Phá vỡ cơ chế chờ — tức là phá vỡ hào. Nếu sau này retention tệ mới cân nhắc |
| Cloud sync / tài khoản | Không server → margin 100%, không lo privacy. Ảnh mất khi xoá app, ghi rõ trong onboarding |
| Social feed / chia sẻ nội bộ | Chia sẻ ra ngoài (Instagram, TikTok) mới là vòng lặp tăng trưởng, không phải feed trong app |
| Analytics bên thứ ba | Không SDK ngoài. Giữ Privacy Manifest sạch. Dùng MetricKit nếu cần |
| Widget, Live Activity | Không cần cho v1 |
| iPad layout riêng | Chạy được ở compatibility mode, chưa tối ưu |

---

## 4. Tech stack & build

### 4.1 Stack

- **SwiftUI** cho toàn bộ UI. Không UIKit trừ `UIViewRepresentable` bọc `AVCaptureVideoPreviewLayer`.
- **SwiftData** cho metadata (Roll, Shot). Ảnh lưu file, không lưu blob trong DB.
- **AVFoundation** cho capture, **Core Image** cho xử lý ảnh, **Metal** chỉ gián tiếp qua `CIContext(mtlDevice:)`.
- **StoreKit 2** cho IAP. Không dùng StoreKit 1.
- **Không có dependency bên thứ ba.** Không SPM package nào. Nếu thấy mình cần một package, dừng lại và đọc lại mục này.
- **XcodeGen** sinh project từ `project.yml`. Không commit `.xcodeproj` bằng tay, không sửa file project trực tiếp.

### 4.2 Build settings quan trọng

```
IPHONEOS_DEPLOYMENT_TARGET = 18.0
SWIFT_VERSION = 6.0
SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor
SWIFT_APPROACHABLE_CONCURRENCY = YES
SWIFT_STRICT_CONCURRENCY = complete
SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES
ENABLE_USER_SCRIPT_SANDBOXING = YES
```

**Quy tắc concurrency** (đọc kỹ, đây là chỗ dễ hỏng nhất):

- Mặc định mọi thứ là `@MainActor`. UI và view model không cần đánh dấu gì.
- `FilmEngine`, `ImagePipeline`, `CameraService` là nơi duy nhất chạy nặng. Chúng là `actor` hoặc `final class ... : Sendable` với `nonisolated` method.
- `CIContext` và `AVCaptureSession` **không** phải `Sendable`. Bọc trong một actor riêng, không truyền ra ngoài.
- Không dùng `Task.detached` trừ khi thực sự cần. `Task { }` từ MainActor là đủ.
- Nếu compiler báo lỗi Sendable mà cách sửa là `@unchecked Sendable`, **dừng lại** — gần như luôn có cách đúng hơn.

### 4.3 Lệnh build & test

```bash
# Sinh project (chạy lại mỗi khi thêm/xoá file hoặc sửa project.yml)
xcodegen generate

# Build
xcodebuild -project ROLL36.xcodeproj -scheme ROLL36 \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -configuration Debug build

# Test
xcodebuild -project ROLL36.xcodeproj -scheme ROLL36 \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test

# Format + lint (chạy trước mỗi commit)
swiftformat . --config .swiftformat
swiftlint --strict
```

---

## 5. Cấu trúc thư mục

```
roll36/
├── project.yml                      # XcodeGen spec
├── PLAN.md                          # tài liệu này
├── research.md                      # nghiên cứu thị trường (đã có)
├── design/                          # screenshot từ Stitch (đã có)
│   ├── 01-viewfinder.png
│   ├── 02-darkroom.png
│   ├── 03-library.png
│   └── 04-import.png
├── .swiftformat
├── .swiftlint.yml
└── ROLL36/
    ├── App/
    │   ├── ROLL36App.swift
    │   ├── RootView.swift
    │   └── AppEnvironment.swift       # DI container, khởi tạo service
    ├── DesignSystem/
    │   ├── Theme.swift                # màu, spacing, radius
    │   ├── Typography.swift
    │   ├── Components/
    │   │   ├── FilmCard.swift
    │   │   ├── ShutterButton.swift
    │   │   ├── RollCounter.swift
    │   │   ├── ProgressBar.swift
    │   │   └── PrimaryButton.swift
    │   └── Haptics.swift
    ├── Models/
    │   ├── Roll.swift                 # @Model
    │   ├── Shot.swift                 # @Model
    │   ├── FilmProfile.swift          # struct, 14 stock
    │   ├── FilmCatalog.swift
    │   └── RollState.swift            # enum + derivation
    ├── FilmEngine/
    │   ├── ColorCubeBuilder.swift     # profile → CIColorCube data
    │   ├── FilmEngine.swift           # actor, pipeline chính
    │   ├── GrainRenderer.swift
    │   ├── HalationRenderer.swift
    │   └── LUTCache.swift             # cache cube data ra disk
    ├── Camera/
    │   ├── CameraService.swift        # protocol
    │   ├── LiveCameraService.swift    # AVCapture thật
    │   ├── MockCameraService.swift    # cho simulator
    │   ├── CameraPreviewView.swift    # UIViewRepresentable
    │   └── CameraViewModel.swift
    ├── Storage/
    │   ├── ImageStore.swift           # ghi/đọc JPEG, thumbnail
    │   └── RollRepository.swift       # CRUD trên SwiftData
    ├── Monetization/
    │   ├── ProductCatalog.swift       # product ID constants
    │   ├── EntitlementStore.swift     # @Observable, nguồn sự thật
    │   ├── PurchaseService.swift
    │   └── PaywallView.swift
    ├── Features/
    │   ├── Viewfinder/
    │   │   ├── ViewfinderView.swift
    │   │   └── ViewfinderViewModel.swift
    │   ├── Darkroom/
    │   │   ├── DarkroomView.swift
    │   │   ├── RollCard.swift
    │   │   └── DevelopingTicker.swift
    │   ├── ContactSheet/
    │   │   ├── ContactSheetView.swift
    │   │   └── ShotDetailView.swift
    │   ├── Library/
    │   │   ├── FilmLibraryView.swift
    │   │   └── FilmDetailSheet.swift
    │   ├── Import/
    │   │   ├── ImportView.swift
    │   │   └── ImportViewModel.swift
    │   └── Settings/
    │       ├── SettingsView.swift
    │       └── OnboardingView.swift
    ├── Resources/
    │   ├── Assets.xcassets
    │   ├── Localizable.xcstrings
    │   ├── PrivacyInfo.xcprivacy
    │   └── ROLL36.storekit          # StoreKit config cho local test
    └── Tests/
        ├── ColorCubeBuilderTests.swift
        ├── RollStateTests.swift
        ├── FilmCatalogTests.swift
        └── ImportLimitTests.swift
```

---

## 6. Design system

Lấy từ 4 screenshot trong `design/`. Đây là token chính thức, **không tự thêm màu mới**.

### 6.1 Màu

```swift
enum Theme {
    static let bg        = Color(hex: 0x0F0D0A)  // nền ngoài cùng
    static let surface   = Color(hex: 0x17140F)  // nền phụ
    static let card      = Color(hex: 0x221F1A)  // card, input
    static let line      = Color(hex: 0x332E25)  // viền 0.5pt
    static let text      = Color(hex: 0xF4F1EA)  // chữ chính
    static let muted     = Color(hex: 0x9C948A)  // chữ phụ
    static let amber     = Color(hex: 0xEF9F27)  // accent duy nhất
    static let green     = Color(hex: 0x7FB07A)  // trạng thái "ready"
    static let red       = Color(hex: 0xE0765F)  // lỗi, hết phim
}
```

Quy tắc: amber là **accent duy nhất**. Không dùng amber cho khối lớn, chỉ cho số liệu, viền, CTA. Nền luôn là `bg` hoặc `card`.

### 6.2 Typography

- **Display / số liệu / nhãn kỹ thuật**: monospaced, uppercase, letterSpacing 0.12em. Dùng `Font.system(.caption, design: .monospaced)`.
- **Nội dung**: `Font.system`, weight 400/500. **Không dùng weight 600/700** — phá vỡ cảm giác mảnh, nhẹ của thiết kế.
- **Không dùng font tuỳ chỉnh.** Giữ bundle nhẹ và tránh vấn đề license.

### 6.3 Hình khối

- Card: `RoundedRectangle(cornerRadius: 10)`, fill `card`, viền `line` 0.5pt.
- Nút chính: fill `amber`, chữ `bg`, radius 9, height 52.
- **Không gradient, không shadow, không blur, không glassmorphism.** Đây là yêu cầu thiết kế, không phải sở thích. Nếu thấy mình đang viết `LinearGradient`, dừng lại.
- Ảnh thumbnail trong contact sheet có viền trắng 2pt — mô phỏng bản in film.

### 6.4 Chuyển động

- Chụp ảnh: màn trập đen flash 120ms + haptic `.impact(.rigid)`.
- Counter giảm: số nhảy, không animate vị trí.
- Tráng xong: cross-fade 400ms, haptic `.notification(.success)`.
- Tôn trọng `accessibilityReduceMotion` — tắt flash và cross-fade, giữ haptic.

---

## 7. Data model

### 7.1 SwiftData

```swift
@Model
final class Roll {
    @Attribute(.unique) var id: UUID
    var stockID: String              // FilmProfile.id
    var capacity: Int                // 36 mặc định
    var createdAt: Date
    var finishedAt: Date?            // khi đủ tấm hoặc finish sớm
    var developStartedAt: Date?      // nil = chưa tráng
    var developDuration: TimeInterval // giây, 3600 mặc định
    var developedAt: Date?           // set khi tráng xong thực tế

    @Relationship(deleteRule: .cascade, inverse: \Shot.roll)
    var shots: [Shot] = []
}

@Model
final class Shot {
    @Attribute(.unique) var id: UUID
    var index: Int                   // 0..<capacity, thứ tự trong cuộn
    var capturedAt: Date
    var imageFilename: String        // chỉ tên file, không phải absolute path
    var thumbnailFilename: String
    var isImported: Bool             // true = áp film lên ảnh có sẵn
    var roll: Roll?
}
```

**Quy tắc:**
- `RollState` **không lưu vào DB**. Nó là computed property suy ra từ các field. Lý do: tránh state lệch khi app bị kill, tránh migration.
- Ảnh **không** lưu trong SwiftData. Chỉ lưu tên file. Đường dẫn gốc resolve qua `ImageStore`.
- Đường dẫn tuyệt đối **không** được lưu — container path đổi giữa các lần cài.

### 7.2 RollState

```swift
enum RollState: Equatable {
    case active(remaining: Int)
    case exposed                     // đầy hoặc finish sớm, chờ tráng
    case developing(progress: Double, readyAt: Date)
    case developed
}
```

Suy ra như sau — thứ tự kiểm tra rất quan trọng:

```swift
extension Roll {
    func state(now: Date = .now) -> RollState {
        if let developedAt, now >= developedAt { return .developed }
        if let start = developStartedAt {
            let readyAt = start.addingTimeInterval(developDuration)
            if now >= readyAt { return .developed }
            let p = now.timeIntervalSince(start) / developDuration
            return .developing(progress: min(max(p, 0), 1), readyAt: readyAt)
        }
        if finishedAt != nil || shots.count >= capacity { return .exposed }
        return .active(remaining: capacity - shots.count)
    }
}
```

Chỗ dễ sai: `developedAt` chỉ được set **lazy** khi view đọc trạng thái, không có timer chạy nền. Nghĩa là app bị kill 3 ngày, mở lại vẫn đúng — vì `readyAt` tính từ `developStartedAt`.

### 7.3 FilmProfile

Đây là **tài sản kỹ thuật quan trọng nhất** của app. Mỗi stock là một bộ tham số, không phải file `.cube` đi kèm (lý do ở mục 8.1).

```swift
struct FilmProfile: Identifiable, Codable, Hashable, Sendable {
    let id: String                  // "portra400"
    let displayName: String         // "Portra 400"
    let iso: Int
    let process: Process            // .c41, .e6, .bw
    let isMonochrome: Bool
    let isFree: Bool                // true = có sẵn, không cần mua

    // Tone
    var contrast: Double            // 0.80...1.40, pivot 0.18
    var saturation: Double          // 0.0...1.40
    var lift: SIMD3<Double>         // cộng vào shadow, ~ -0.02...0.03
    var gain: SIMD3<Double>         // nhân highlight, ~ 0.96...1.04
    var fade: Double                // 0...0.12, nâng black point (film hết hạn)

    // Split tone
    var shadowTint: SIMD3<Double>   // màu vùng tối, đã normalize
    var highlightTint: SIMD3<Double>
    var tintStrength: Double        // 0...1

    // Texture
    var grainIntensity: Double      // 0...1
    var grainSize: Double           // px ở chiều rộng 1000px
    var halationThreshold: Double   // 0.60...0.95
    var halationRadius: Double      // px ở chiều rộng 1000px
    var halationTint: SIMD3<Double>
    var bloomIntensity: Double      // 0...0.5
    var vignetteIntensity: Double   // 0...1
}
```

### 7.4 Danh mục 14 stock

Chia 4 nhóm. **`portra400` là stock free duy nhất.** Con số dưới đây là điểm khởi đầu hợp lý, **phải tinh chỉnh bằng ảnh film thật** (xem 14.1).

| id | Tên | ISO | Process | Nhóm | Giá |
|---|---|---|---|---|---|
| `portra400` | Portra 400 | 400 | C-41 | Chân dung | **Free** |
| `ektar100` | Ektar 100 | 100 | C-41 | Chân dung | $1.49 |
| `fuji400h` | Fuji Pro 400H | 400 | C-41 | Chân dung | $1.49 |
| `gold200` | Gold 200 | 200 | C-41 | Chân dung | $0.99 |
| `ultramax400` | UltraMax 400 | 400 | C-41 | Chân dung | $0.99 |
| `trix400` | Tri-X 400 | 400 | B&W | Đơn sắc | $1.49 |
| `hp5` | HP5 Plus | 400 | B&W | Đơn sắc | $1.49 |
| `acros100` | Acros 100 | 100 | B&W | Đơn sắc | $0.99 |
| `cinestill800t` | Cinestill 800T | 800 | C-41 | Đêm | $1.49 |
| `portra800` | Portra 800 | 800 | C-41 | Đêm | $1.49 |
| `expiredGold` | Expired Gold | 200 | C-41 | Hết hạn | $0.99 |
| `expiredFuji` | Expired Fuji | 400 | C-41 | Hết hạn | $0.99 |
| `velvia50` | Velvia 50 | 50 | E-6 | Slide | $1.49 |
| `provia100` | Provia 100F | 100 | E-6 | Slide | $1.49 |

Bốn stock tiêu biểu, dùng làm test fixture:

```swift
// Chân dung, da ấm, contrast mềm
static let portra400 = FilmProfile(
    id: "portra400", displayName: "Portra 400", iso: 400,
    process: .c41, isMonochrome: false, isFree: true,
    contrast: 0.92, saturation: 0.94,
    lift: SIMD3(0.010, 0.004, -0.006),
    gain: SIMD3(1.020, 1.000, 0.975),
    fade: 0.02,
    shadowTint: SIMD3(0.96, 0.99, 1.04),
    highlightTint: SIMD3(1.04, 1.00, 0.95),
    tintStrength: 0.45,
    grainIntensity: 0.30, grainSize: 1.6,
    halationThreshold: 0.86, halationRadius: 9,
    halationTint: SIMD3(1.0, 0.55, 0.40), bloomIntensity: 0.10,
    vignetteIntensity: 0.16
)

// Đơn sắc, grain đậm, contrast mạnh
static let trix400 = FilmProfile(
    id: "trix400", displayName: "Tri-X 400", iso: 400,
    process: .bw, isMonochrome: true, isFree: false,
    contrast: 1.18, saturation: 0.0,
    lift: SIMD3(0, 0, 0), gain: SIMD3(1.0, 1.0, 1.0),
    fade: 0.03,
    shadowTint: SIMD3(1, 1, 1), highlightTint: SIMD3(1, 1, 1), tintStrength: 0,
    grainIntensity: 0.62, grainSize: 2.4,
    halationThreshold: 0.92, halationRadius: 5,
    halationTint: SIMD3(1, 1, 1), bloomIntensity: 0.04,
    vignetteIntensity: 0.22
)

// Đêm, tungsten, halation đỏ rất mạnh — đặc trưng của Cinestill
static let cinestill800t = FilmProfile(
    id: "cinestill800t", displayName: "Cinestill 800T", iso: 800,
    process: .c41, isMonochrome: false, isFree: false,
    contrast: 1.02, saturation: 0.90,
    lift: SIMD3(0.004, 0.000, 0.018),
    gain: SIMD3(0.985, 1.000, 1.035),
    fade: 0.01,
    shadowTint: SIMD3(0.94, 0.98, 1.10),
    highlightTint: SIMD3(1.06, 0.98, 0.94),
    tintStrength: 0.60,
    grainIntensity: 0.42, grainSize: 1.9,
    halationThreshold: 0.72, halationRadius: 14,
    halationTint: SIMD3(1.0, 0.35, 0.30), bloomIntensity: 0.22,
    vignetteIntensity: 0.18
)

// Hết hạn, black bị nâng, contrast bạc màu
static let expiredGold = FilmProfile(
    id: "expiredGold", displayName: "Expired Gold", iso: 200,
    process: .c41, isMonochrome: false, isFree: false,
    contrast: 0.80, saturation: 0.78,
    lift: SIMD3(0.030, 0.022, 0.030),
    gain: SIMD3(0.96, 0.97, 0.92),
    fade: 0.10,
    shadowTint: SIMD3(1.02, 0.98, 1.06),
    highlightTint: SIMD3(1.05, 1.02, 0.88),
    tintStrength: 0.55,
    grainIntensity: 0.55, grainSize: 2.8,
    halationThreshold: 0.88, halationRadius: 8,
    halationTint: SIMD3(1.0, 0.70, 0.45), bloomIntensity: 0.08,
    vignetteIntensity: 0.26
)
```

---

## 8. Film engine

Đây là phần quyết định app có bán được hay không. Làm cẩn thận, đừng vội.

### 8.1 Vì sao sinh LUT bằng code, không ship file `.cube`

Ba lý do, theo thứ tự quan trọng:

1. **Không có rủi ro license.** LUT giả lập film thương mại thường có nguồn gốc mờ. Ship file lạ là rủi ro pháp lý cho một app bán tiền.
2. **Tinh chỉnh được bằng số.** Muốn Portra bớt vàng hơn 10%? Sửa một float. Với file `.cube` phải dựng lại trong DaVinci.
3. **Không phình bundle.** 14 LUT 33³ = ~8MB. Sinh lúc chạy thì chỉ tốn CPU một lần rồi cache.

Đánh đổi: chất lượng phụ thuộc vào việc bạn tinh chỉnh tham số đúng. Đó là lý do mục 14.1 tồn tại.

### 8.2 Pipeline

Thứ tự áp dụng **cố định**, không đổi:

```
CIImage gốc (sRGB)
  → 1. ColorCube (tone + split tone + saturation + lift/gain + fade + monochrome)
  → 2. Halation (threshold highlight → blur → tint → screen blend)
  → 3. Bloom (highlight blur → add)
  → 4. Grain (random noise → luminance-modulated → overlay blend)
  → 5. Vignette
  → 6. Sharpen nhẹ (CISharpenLuminance 0.3) — bù mềm do blur
  → JPEG
```

Lý do thứ tự này: halation và grain phải nằm **sau** color grading để giống vật lý thật (ánh sáng tán xạ trong nhũ tương, hạt bạc phủ lên ảnh đã tráng). Làm grain trước sẽ bị LUT nhuộm màu hạt — sai.

### 8.3 ColorCubeBuilder

```swift
enum ColorCubeBuilder {
    static let dimension = 33

    /// Sinh data cho CIColorCube. Output là RGBA float32, alpha = 1.
    static func makeCube(for profile: FilmProfile) -> Data
}
```

Cách làm: lặp 33³ lần trên grid `[0,1]`, với mỗi điểm gọi `transform(r,g,b,profile)`, ghi 4 float. Tổng 35.937 điểm.

`transform` chi tiết:

```swift
static func transform(_ rgb: SIMD3<Double>, _ p: FilmProfile) -> SIMD3<Double> {
    var c = rgb

    // 1. Contrast quanh pivot 0.18 (giữ midtone ổn định)
    c = (c - 0.18) * p.contrast + 0.18

    // 2. Lift / Gain
    c = c * p.gain + p.lift

    // 3. Fade — nâng black point, nén white point
    c = c * (1.0 - p.fade) + p.fade * 0.55

    // 4. Split tone theo luminance
    let luma = 0.2126 * c.x + 0.7152 * c.y + 0.0722 * c.z
    let w = smoothstep(0.15, 0.85, luma)          // 0 = tối, 1 = sáng
    let tint = p.shadowTint * (1 - w) + p.highlightTint * w
    c = c * (1 + (tint - 1) * p.tintStrength)

    // 5. Saturation (hoặc desaturate nếu monochrome)
    let l = 0.2126 * c.x + 0.7152 * c.y + 0.0722 * c.z
    let sat = p.isMonochrome ? 0.0 : p.saturation
    c = SIMD3(l, l, l) + (c - SIMD3(l, l, l)) * sat

    // 6. Clamp
    return c.clamped(lowerBound: 0, upperBound: 1)
}
```

`CIColorCube` yêu cầu dữ liệu **premultiplied** — với alpha = 1 thì không khác gì, nhưng phải set alpha rõ ràng là 1.0, đừng để 0.

Cache: `LUTCache` ghi `Data` ra `Caches/lut/<stockID>-d33.bin`. Key phải gồm hash của `FilmProfile` để sửa tham số là cache tự invalidate.

### 8.4 Grain

```swift
// Bắt buộc: grain phải scale theo kích thước ảnh
let scale = imageExtent.width / 1000.0
let size = max(0.6, profile.grainSize * scale)
```

Cách dựng:
1. `CIRandomGenerator` → crop về extent ảnh
2. Chuyển sang monochrome (`CIColorMatrix` lấy luma)
3. `CIGaussianBlur(radius: size)` để hạt không bị sắc như noise số
4. Trộn bằng `CISoftLightBlendMode` với `grainIntensity` làm alpha

**Grain phải deterministic.** Dùng seed từ `shot.id` để tráng lại cho ra cùng kết quả. Cách: thay vì `CIRandomGenerator` (luôn ngẫu nhiên), dùng `CIColorMatrix` trên một noise texture sinh từ seed cố định — hoặc đơn giản hơn, chấp nhận random và **không** cho tráng lại ảnh đã tráng. Chọn cách sau cho v1, ghi chú lại.

### 8.5 Halation

Đặc trưng nhất của film. Làm sai là mất chất ngay.

1. Trích vùng sáng: `CIColorMatrix` với bias âm để chỉ giữ > threshold, hoặc dùng `CIColorClamp` sau khi trừ threshold.
2. `CIGaussianBlur(radius: halationRadius * scale)`
3. Nhân với `halationTint`
4. `CIScreenBlendMode` lên ảnh gốc, alpha khoảng 0.5–0.7

Cinestill 800T có halation đỏ rất mạnh (`radius 14`, `threshold 0.72`) — đây là điểm nhận dạng của stock đó, đừng làm yếu đi.

### 8.6 Hiệu năng

Mục tiêu: **< 1.2s cho ảnh 12MP trên iPhone 17 Pro**.

- Dùng `CIContext(mtlDevice: MTLCreateSystemDefaultDevice())` — nhanh hơn context CPU nhiều lần.
- Xử lý ở full res nhưng **downscale grain/halation theo tỷ lệ** như trên.
- Không tạo `CIContext` mới cho mỗi ảnh. Một instance, giữ trong `FilmEngine` actor.
- Xử lý ảnh chạy trong actor, không block MainActor. Có progress callback để UI hiện trạng thái "đang tráng".

Nếu vượt 2s: giảm dimension cube xuống 17 cho preview, giữ 33 cho ảnh cuối.

---

## 9. Camera

### 9.1 Trách nhiệm

- Xin quyền camera (`NSCameraUsageDescription`), xử lý từ chối
- Cấu hình session: preset `.photo`, ảnh full res
- Preview layer
- Chụp, trả `CIImage` cho `FilmEngine`
- Xử lý interruption (cuộc gọi đến), app background

### 9.2 Protocol — bắt buộc, vì simulator không có camera

```swift
protocol CameraService: AnyObject, Sendable {
    func start() async throws
    func stop() async
    func capture() async throws -> Data   // JPEG gốc từ sensor
    var isAvailable: Bool { get }
}
```

- `LiveCameraService` — AVCapture thật
- `MockCameraService` — trả ảnh gradient tổng hợp, cho phép build và test toàn bộ UI trên simulator

**Đây không phải chi tiết phụ.** Nếu không có mock, Claude Code không thể tự verify UI trên simulator và sẽ phải hỏi bạn bật máy thật liên tục. Chọn implementation dựa trên `#if targetEnvironment(simulator)`.

### 9.3 Live preview có LUT — quyết định pha

`mood.camera` **không có live preview** và đó là điểm yếu bị chê. Ta làm được tốt hơn, nhưng đây là phần rủi ro nhất về hiệu năng.

Chiến lược 2 pha:

- **M2:** preview hiển thị ảnh sensor thô + overlay tint nhẹ theo stock (một `Color` với opacity thấp phủ lên). Rẻ, an toàn, đủ để ship.
- **M3:** thêm real-time LUT preview. Dùng `AVCaptureVideoDataOutput` ở 720p, áp `CIColorCube` (dimension 17) qua `CIContext(mtlDevice:)`, render vào `MTKView`. Đo FPS.

**Điều kiện giữ tính năng:** FPS ≥ 24 trên iPhone 17 Pro. Nếu thấp hơn, giữ overlay tint và ghi lại lý do. Không được ship preview giật — tệ hơn không có preview.

Đặt sau feature flag `liveLUTPreview` trong `AppEnvironment` để tắt được từ xa nếu có lỗi.

### 9.4 Chụp

```swift
// ViewfinderViewModel
func shutter() async {
    guard case .active(let remaining) = roll.state(), remaining > 0 else { return }
    Haptics.shutter()
    do {
        let raw = try await camera.capture()
        let processed = try await filmEngine.process(raw, profile: stock)
        try await repository.appendShot(processed, to: roll)
        flashOverlay()
    } catch {
        present(error)
    }
}
```

Chụp xong phải **không** cho xem ảnh. Đây là điểm cốt lõi của sản phẩm. Thumbnail ở góc dưới chỉ hiện **số tấm đã chụp**, không hiện ảnh.

---

## 10. Darkroom & tráng phim

### 10.1 Luồng

1. Cuộn đầy 36 tấm (hoặc người dùng bấm "Kết thúc cuộn sớm") → state `.exposed`
2. Người dùng bấm "Tráng" → set `developStartedAt = .now`, `developDuration = 3600`
3. Trong lúc tráng, hiện progress + thời gian còn lại
4. Hết giờ → state `.developed`, xem được contact sheet

### 10.2 Ticker

Không dùng `Timer` chạy liên tục. Dùng `TimelineView(.periodic(from: .now, by: 1))` trong SwiftUI — chỉ chạy khi view hiện, tự dừng khi biến mất. Rẻ và không rò rỉ.

### 10.3 Giới hạn số cuộn tráng đồng thời

- Free: **1 cuộn** đang tráng tại một thời điểm. Cuộn khác phải chờ.
- Đã mua (bất kỳ stock nào hoặc trọn bộ): **không giới hạn**.

Đây là lý do tự nhiên để mua, và nó không phá vỡ cơ chế chờ — chỉ là cho phép chờ song song.

### 10.4 Không có skip

Không bán quyền tráng nhanh. Ghi rõ trong code comment để lần sau không ai "tối ưu" thêm vào.

---

## 11. Import

### 11.1 Luồng

1. `PhotosPicker` chọn ảnh
2. Chọn film stock
3. Preview kết quả (chạy `FilmEngine` ở res thấp để preview nhanh)
4. Bấm "Develop frame" → chạy full res → lưu vào một pseudo-roll tên "Darkroom imports"

### 11.2 Giới hạn

- Free: **5 ảnh** trọn đời (đếm trong `UserDefaults`, key `importsUsed`)
- Đã mua: không giới hạn

Ảnh import **không** tiêu tốn exposure của cuộn. Chúng vào pseudo-roll riêng, không có khái niệm 36 tấm.

### 11.3 Quyền

`NSPhotoLibraryUsageDescription` — dùng `PhotosPicker` (không cần full library access), nhưng vẫn phải khai báo chuỗi này.

---

## 12. Monetization

### 12.1 Sản phẩm

| Product ID | Loại | Giá | Nội dung |
|---|---|---|---|
| `com.lequangtrongtai.roll36.full` | Non-consumable | $4.99 → $9.99 | Toàn bộ 14 stock + import không giới hạn + tráng song song |
| `com.lequangtrongtai.roll36.film.<stockID>` | Non-consumable | $0.99 / $1.49 | Một stock lẻ |

**Không có subscription. Không có consumable.** Nếu ai đó thêm subscription vào, đó là quyết định sản phẩm, không phải kỹ thuật.

### 12.2 EntitlementStore

```swift
@Observable
@MainActor
final class EntitlementStore {
    private(set) var ownedStockIDs: Set<String> = []
    private(set) var hasFullUnlock = false
    private(set) var isLoading = true

    var unlockedStocks: [FilmProfile] { ... }
    func isUnlocked(_ profile: FilmProfile) -> Bool
    func purchase(_ productID: String) async throws
    func restore() async throws
}
```

**Nguồn sự thật là `Transaction.currentEntitlements`, không phải UserDefaults.** UserDefaults chỉ là cache để UI không nhấp nháy lúc khởi động. Khi có `Transaction.updates`, cập nhật lại và ghi cache.

Bắt đầu listen `Transaction.updates` trong `init` hoặc task đầu tiên, **không** dừng cho đến khi app chết.

### 12.3 Gating

| Tính năng | Free | Đã mua |
|---|---|---|
| Stock `portra400` | ✓ | ✓ |
| 13 stock còn lại | ✗ (xem trước, có watermark khi export) | ✓ |
| Số cuộn tráng song song | 1 | ∞ |
| Import | 5 ảnh trọn đời | ∞ |
| Watermark trên ảnh export | Có (góc dưới, nhỏ) | Không |

Watermark free: chữ `ROLL 36` monospaced, góc dưới phải, opacity 0.35, cao 2% chiều rộng ảnh. Đây là lý do chính để mua — ảnh sạch.

### 12.4 StoreKit config local

`Resources/ROLL36.storekit` chứa toàn bộ 15 product để test không cần App Store Connect. Scheme phải set `StoreKitConfiguration` trỏ vào file này ở cấu hình Debug.

---

## 13. Màn hình — spec chi tiết

### 13.1 Viewfinder

Tham chiếu `design/01-viewfinder.png`.

- Preview full-bleed, **không** có safe area inset
- Trên cùng: `EXP 12/36` (mono, trái) + nút flash (phải) + thông số `1/500s · f/2.8 · ISO 400`
- Dưới cùng: chip film stock, nút shutter tròn 76pt, nút đổi lens, số tấm đã chụp
- Khi hết cuộn: preview mờ đi, overlay "Cuộn đã đầy" + nút "Tráng ngay"
- Khi không có quyền camera: màn hình hướng dẫn mở Settings

**Trạng thái cần xử lý:** đang tải, không có quyền, hết cuộn, đang lưu ảnh, lỗi capture, cuộn đang tráng (không cho chụp).

### 13.2 Darkroom

Tham chiếu `design/02-darkroom.png`.

- Header "Darkroom" + số cuộn đang tráng
- Danh sách cuộn: tên stock, trạng thái, progress bar, thời gian còn lại
- Cuộn `.exposed` có nút "Tráng"
- Cuộn `.developed` hiện "Ready" màu green, bấm vào xem contact sheet
- Nếu free và đã có 1 cuộn đang tráng: cuộn khác hiện "Chờ cuộn trước" + nút mở paywall

### 13.3 Contact sheet

- Grid 3 cột, ảnh có viền trắng 2pt, radius 2
- Tap → full screen, swipe qua lại
- Nút share (`ShareLink`), nút save về Photos
- Nút "Chụp cuộn mới" ở cuối

### 13.4 Film library

Tham chiếu `design/03-library.png`.

- Grid 2 cột, mỗi card có swatch màu đại diện, tên, mã process, giá
- Stock đã mở: nhãn "Owned" màu green
- Stock khoá: giá amber
- CTA dưới cùng: `Mở khoá cả 14 stock · $4.99`
- Tap stock khoá → paywall (không phải mua ngay, để có ngữ cảnh)

### 13.5 Import

Tham chiếu `design/04-import.png`.

- Ảnh trong khung âm bản có lỗ sprocket
- Hàng swatch film stock, chọn một
- Nút `Develop frame` amber
- Hiện `còn N lượt` nếu free

### 13.6 Paywall

- Tiêu đề nêu lợi ích cụ thể, không dùng từ "unlock" chung chung
- 3 bullet: 14 stock, import không giới hạn, ảnh không watermark
- Giá, nút mua, nút restore, link điều khoản
- **Không** dùng countdown giả, không dark pattern

### 13.7 Settings

- Restore purchases
- Ngôn ngữ
- Điều khoản, chính sách riêng tư
- Phiên bản app
- Xoá toàn bộ dữ liệu (có confirm)

### 13.8 Onboarding

Một màn hình duy nhất, 3 dòng: chụp 36 tấm / tráng và chờ / ảnh mất khi xoá app. Nút "Bắt đầu". Không carousel 5 trang.

---

## 14. Milestones

Mỗi milestone phải build xanh **và** test xanh trước khi sang milestone sau. Không gộp.

### M0 — Khung dự án (nửa ngày)

- [ ] `project.yml` cho XcodeGen, target `ROLL36` + `ROLL36Tests`
- [ ] `xcodegen generate` chạy được
- [ ] App build và chạy trên simulator, hiện "Hello"
- [ ] `.swiftformat`, `.swiftlint.yml`
- [ ] `PrivacyInfo.xcprivacy` (camera, photo library, no tracking)
- [ ] Info.plist: usage descriptions, `UIUserInterfaceStyle = Dark`

**Done khi:** `xcodebuild build` exit 0 trên iPhone 17 Pro simulator.

### M1 — Design system + điều hướng (1 ngày)

- [ ] `Theme`, `Typography`, `Haptics`
- [ ] `ShutterButton`, `RollCounter`, `ProgressBar`, `PrimaryButton`, `FilmCard`
- [ ] `RootView` với 3 tab: Camera / Darkroom / Library
- [ ] Mỗi tab là placeholder dùng component thật
- [ ] Snapshot check bằng mắt trên simulator

**Done khi:** 3 tab điều hướng được, component hiện đúng màu, không có gradient/shadow nào trong code.

### M2 — Camera + lưu ảnh thô (2 ngày)

- [ ] `CameraService` protocol, `LiveCameraService`, `MockCameraService`
- [ ] `CameraPreviewView`
- [ ] `ImageViewStore` ghi JPEG + thumbnail
- [ ] `Roll`, `Shot`, `RollRepository`
- [ ] `ViewfinderView` chụp được, counter giảm, hết 36 thì khoá
- [ ] Xử lý quyền camera (chưa cấp / từ chối / đã cấp)
- [ ] Overlay tint theo stock (chưa có LUT thật)

**Done khi:** trên simulator (mock) chụp 36 lần, counter về 0, nút shutter disable, ảnh ghi ra disk.

### M3 — Film engine (3 ngày) ← **milestone quan trọng nhất**

- [ ] `FilmProfile` + `FilmCatalog` đủ 14 stock
- [ ] `ColorCubeBuilder` + unit test (cube đúng kích thước, điểm trắng vẫn trắng, điểm đen không âm)
- [ ] `FilmEngine` actor: cube → halation → bloom → grain → vignette → sharpen
- [ ] `LUTCache`
- [ ] Áp vào luồng chụp thật
- [ ] Đo thời gian xử lý ảnh 12MP, log ra
- [ ] (Tuỳ chọn) real-time LUT preview sau feature flag, chỉ giữ nếu FPS ≥ 24

**Done khi:** ảnh chụp ra có màu khác nhau rõ rệt giữa 4 stock fixture, thời gian xử lý < 1.2s, unit test xanh.

### M4 — Cuộn phim + Darkroom (2 ngày)

- [ ] `RollState` + derivation + unit test đủ 4 trạng thái và edge case (app kill giữa lúc tráng)
- [ ] `DarkroomView` với `TimelineView`
- [ ] Tráng: set `developStartedAt`, đếm ngược, tự chuyển `.developed`
- [ ] Giới hạn 1 cuộn tráng song song cho free
- [ ] `ContactSheetView`, `ShotDetailView`
- [ ] Share và save to Photos

**Done khi:** tráng một cuộn, kill app, mở lại sau khi hết giờ → hiện đúng `.developed`.

### M5 — Import (1.5 ngày)

- [ ] `PhotosPicker` + `ImportView`
- [ ] Preview res thấp trước khi develop
- [ ] Đếm `importsUsed`, chặn ở 5
- [ ] Pseudo-roll "Darkroom imports"

**Done khi:** import 5 ảnh free, ảnh thứ 6 mở paywall.

### M6 — StoreKit (2 ngày)

- [ ] `ROLL36.storekit` với 15 product
- [ ] `EntitlementStore` + `PurchaseService`
- [ ] Listen `Transaction.updates` suốt vòng đời app
- [ ] `PaywallView`, `FilmDetailSheet`
- [ ] Restore purchases
- [ ] Gating: stock, tráng song song, import, watermark
- [ ] UI test: tap stock khoá → paywall hiện

**Done khi:** mua thử trong simulator bằng StoreKit config, entitlement cập nhật ngay, restore hoạt động sau khi xoá app.

### M7 — Hoàn thiện + App Store (2 ngày)

- [ ] Onboarding
- [ ] Settings
- [ ] String Catalog Việt + Anh, không hardcode string
- [ ] Dynamic Type tới accessibility3, VoiceOver cho shutter và counter
- [ ] `accessibilityReduceMotion`
- [ ] App icon (dùng tông `#14120E` + amber)
- [ ] Screenshot 6.9" và 6.5" từ simulator
- [ ] Metadata: tên, mô tả, keywords, privacy policy URL
- [ ] TestFlight build

**Done khi:** archive không warning, TestFlight cài được trên máy thật.

---

## 15. Testing

### 15.1 Unit test bắt buộc

```swift
// ColorCubeBuilderTests
func testCubeSize()                    // 33³ × 4 floats
func testWhiteStaysWhite()             // (1,1,1) → gần (1,1,1), sai số 0.02
func testBlackNotNegative()            // (0,0,0) → >= 0 mọi kênh
func testMonochromeIsGray()            // trix400: r == g == b
func testContrastMonotonic()           // contrast > 1 làm dải rộng ra

// RollStateTests
func testActiveCountsRemaining()
func testExposedWhenFull()
func testDevelopingProgressClamps()
func testDevelopedAfterElapsed()
func testKilledAppResumesCorrectly()   // start = now-90min, duration = 60min → .developed

// ImportLimitTests
func testFreeLimitFive()
func testPaidUnlimited()

// FilmCatalogTests
func testAllFourteenStocksPresent()
func testUniqueIDs()
func testOnlyPortraIsFree()
func testAllPricesMatchProductCatalog()
```

### 15.2 Không test

- Không snapshot test (brittle, không đáng ở giai đoạn này)
- Không test `AVCaptureSession` thật trong CI (cần thiết bị)
- Không E2E

### 15.3 Test tay trên máy thật — bắt buộc trước khi submit

Camera, grain ở full res, hiệu năng, haptic, màu thực tế. Simulator không thay được.

---

## 16. App Store readiness

- **Privacy Manifest:** khai báo `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`. Không thu thập dữ liệu. `NSPrivacyTracking = false`.
- **Age rating:** 4+
- **Category:** Photo & Video
- **Metadata:** mô tả phải nói rõ IAP là nội dung số, không dùng "unlock" mơ hồ.
- **Ảnh mẫu:** 15 ảnh chụp bằng chính app, đủ 5 stock khác nhau. Ảnh mẫu chính là công cụ marketing — đầu tư thời gian.
- **Không** dùng từ "free" trong tên app.
- **Subscription:** không có, nên không cần disclosure bổ sung.

---

## 17. Rủi ro & cách xử lý

| Rủi ro | Mức | Cách xử lý |
|---|---|---|
| Màu LUT không đủ thật → không ai trả tiền | **Cao** | M3 phải có bước so sánh với ảnh film thật. Đây là rủi ro số một |
| Real-time preview tụt FPS | Trung bình | Feature flag, fallback về overlay tint |
| Xử lý ảnh chậm trên máy cũ | Trung bình | Cube 17 cho preview, 33 cho final; đo trên iPhone 13 |
| Người dùng bỏ app vì phải chờ 60 phút | Trung bình | Onboarding nói rõ. Nếu D7 retention < 15%, cân nhắc giảm còn 30 phút |
| SwiftData migration khi thêm field | Thấp | Chỉ thêm field optional, không đổi kiểu |
| Apple reject vì IAP | Thấp | Mô tả rõ, dùng StoreKit 2 đúng chuẩn |
| Không có ngân sách marketing | **Cao** | Ảnh xuất ra phải đủ đẹp để tự lan truyền. Đây là lý do M3 quan trọng nhất |

---

## 18. Quy tắc làm việc cho Claude Code

Đọc kỹ, đây là các ràng buộc cứng.

1. **Không thêm dependency.** Không SPM, không CocoaPods, không Carthage. Chỉ Apple framework.
2. **Không tạo file `.cube`.** LUT sinh bằng code (mục 8.1).
3. **Không sửa `.xcodeproj` bằng tay.** Sửa `project.yml` rồi `xcodegen generate`.
4. **Không thêm subscription, không thêm consumable IAP.** Quyết định sản phẩm đã chốt.
5. **Không cho xem ảnh trước khi tráng.** Đây là cơ chế cốt lõi, không phải hạn chế kỹ thuật.
6. **Không dùng `@unchecked Sendable`.** Nếu compiler bắt bí, refactor cho đúng.
7. **Không hardcode string hiển thị.** Dùng String Catalog từ M7, nhưng đặt tên key từ đầu.
8. **Không dùng gradient/shadow/blur** trong UI. Vi phạm thiết kế.
9. **Không commit khi test đỏ.** Không skip test bằng `.disabled`.
10. **Mỗi milestone một commit** (hoặc vài commit nhỏ), message theo Conventional Commits.
11. **Nếu một quyết định trong plan có vẻ sai**, viết lý do vào `DECISIONS.md` rồi hỏi, đừng tự đổi im lặng.
12. **Chạy `swiftformat` và `swiftlint --strict` trước mỗi commit.**

### Thứ tự thực hiện

```
M0 → M1 → M2 → M3 → M4 → M5 → M6 → M7
```

Không nhảy cóc. M3 không xong thì M4 vô nghĩa vì không có ảnh để tráng.

### Khi bị kẹt

Nếu một bước không qua được sau 3 lần thử: dừng, ghi lại cụ thể lỗi gì, đã thử gì, rồi hỏi. Đừng thử mò thêm.

---

## 19. Câu hỏi mở — cần chốt trước M0

1. **Bundle ID** có đúng `com.lequangtrongtai.roll36` không? Nếu bạn có Apple Developer account với prefix riêng thì đổi.
2. **Team ID** để ký — Claude Code không tự set được, bạn phải điền vào Xcode lần đầu.
3. **Giá ra mắt** $4.99 trong 14 ngày — giữ hay đổi?
4. **Thời gian tráng** 60 phút — giữ hay đổi? (Ảnh hưởng trực tiếp retention)
5. **Ngôn ngữ chính** trên App Store — Việt hay Anh? (Quyết định thị trường bạn nhắm)

---

## 20. Tham chiếu

- `research.md` — phân tích đối thủ và giá, có trích dẫn
- `design/01-viewfinder.png` … `04-import.png` — 4 màn hình từ Google Stitch
- Stitch canvas: https://stitch.google.com/projects/208101431842791838
- Bảng xếp hạng gốc: Apple Marketing Tools RSS, App Store US, 15/11/2026
