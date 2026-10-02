# Whales Spent (renew_whales_spent)

<p align="center">
  <img src="assets/images/logo.png" alt="Whales Spent Logo" width="130" />
</p>

<p align="center">
  <strong>Ứng dụng quản lý tài chính cá nhân thông minh, toàn diện và bảo mật cao trên nền tảng Flutter.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white" alt="Dart" />
  <img src="https://img.shields.io/badge/Android-Java-%23ED8B00.svg?style=for-the-badge&logo=openjdk&logoColor=white" alt="Android Java" />
  <img src="https://img.shields.io/badge/SQLite-Offline--First-003B57?style=for-the-badge&logo=sqlite&logoColor=white" alt="SQLite" />
  <img src="https://img.shields.io/badge/License-Private-red.svg?style=for-the-badge" alt="License" />
</p>

---

## 📖 Giới thiệu Tổng quan

**Whales Spent** là giải pháp quản lý tài chính cá nhân được thiết kế hiện đại, tinh gọn và thực tế, giúp người dùng làm chủ dòng tiền:
- Theo dõi thu chi hàng ngày chi tiết và trực quan.
- **Quản lý cho vay - đi vay chuyên nghiệp có tính lãi suất** (theo phong cách thực tế tại Việt Nam).
- Hoạch định ngân sách theo từng hạng mục chi tiêu.
- Nhận diện hóa đơn thông minh bằng trí tuệ nhân tạo (Google ML Kit OCR).
- Dự báo chi tiêu tương lai dựa trên mô hình máy học (Machine Learning).
- Tương tác nhanh từ màn hình chính thông qua **Android Home Screen Widget**.

Ứng dụng hoạt động theo cơ chế **Offline-first**, dữ liệu được lưu trữ an toàn, bảo mật trên thiết bị với hệ quản trị cơ sở dữ liệu SQLite cục bộ.

---

## 🌟 Hệ thống Tính năng Nổi bật

### 1. 🤝 Cho Vay & Đi Vay Có Tính Lãi Suất (Loan & Debt with Interest)
> *Tính năng nổi bật mô phỏng chính xác nghiệp vụ vay/mượn ngoài đời thực tại Việt Nam.*
- **4 Hình thức tính lãi linh hoạt:**
  - **Đồng / triệu / ngày** (Ví dụ: `2.000đ / 1 triệu / ngày` - phổ biến trong dân gian).
  - **% / tháng** (Ví dụ: `1.5%/tháng` - vay bạn bè, người thân, tư nhân).
  - **% / năm** (Ví dụ: `8%/năm` - vay trả góp, ngân hàng).
  - **% / ngày** (Tính lãi ngắn hạn).
- **Cơ chế tính lãi thông minh:**
  - Hỗ trợ cả **Lãi đơn** (tính trên nợ gốc ban đầu) và **Lãi kép / Nhập gốc** (tiền lãi chưa trả định kỳ cộng dồn vào gốc để tính lãi tiếp).
  - **Tự động đồng bộ lãi suất theo thời gian thực:** Mỗi khi mở lại ứng dụng hoặc chuyển từ background về foreground, hệ thống tự động quét và cập nhật số tiền lãi phát sinh chính xác theo số ngày trôi qua.
  - **Chuẩn hóa tiền tệ VND:** Tự động làm tròn số tiền lãi phát sinh theo bội số hàng nghìn đồng (`1.000 VND`), loại bỏ triệt để số tiền lẻ không thực tế.
- **Quản lý trả nợ & Tất toán chuyên sâu:**
  - **Ưu tiên phân bổ thông minh:** Khi trả nợ, hệ thống tự động cấn trừ vào tiền lãi tích lũy trước, phần tiền dư tiếp tục khấu trừ vào nợ gốc.
  - **Xem trước phân bổ thời gian thực:** Hỗ trợ tính toán ngay khi người dùng nhập số tiền trả, hiển thị rõ ràng bao nhiêu tiền trừ vào lãi, bao nhiêu trừ vào gốc.
  - **Lịch sử thanh toán chi tiết (`loan_payments`):** Ghi nhận từng lần trả (ngày giờ, số tiền, phần trừ gốc, phần trừ lãi, nợ gốc còn lại sau trả, ghi chú).
  - **Thông báo nhắc nợ tự động:** Đặt lịch nhắc hạn trả/thu nợ hàng ngày lúc 9:00 sáng.

### 2. 💵 Quản lý Giao dịch Thu - Chi (Transactions)
- Ghi chép thu chi nhanh chóng với bàn phím số tùy chỉnh và gợi ý danh mục thông minh.
- Phân loại rõ ràng 4 dòng tiền: **Khoản chi**, **Thu nhập**, **Cho vay** và **Thu nợ**.
- Bộ lọc đa chiều theo mốc thời gian (Hôm nay, Tuần này, Tháng này, Năm nay, Tùy chỉnh), lọc theo danh mục hoặc tìm kiếm theo từ khóa ghi chú.
- Xem số dư khả dụng tức thì sau mỗi biến động giao dịch.

### 3. 🎯 Hoạch định & Kiểm soát Ngân sách (Budgeting)
- Thiết lập ngân sách chi tiêu cho từng danh mục riêng lẻ hoặc ngân sách tổng thể trong tháng.
- Theo dõi thanh tiến độ chi tiêu trực quan theo thời gian thực.
- Cảnh báo màu sắc thông minh khi chi tiêu vượt ngưỡng an toàn (màu vàng khi đạt 80%, cảnh báo đỏ khi chạm 100% hạn mức).

### 4. 📷 Quét Hóa đơn Thông minh (Smart Receipt OCR)
- Ứng dụng công nghệ **Google ML Kit Text Recognition** trực tiếp trên Camera hoặc ảnh chụp có sẵn.
- Tự động phân tích, bóc tách số tiền thanh toán và ngày giao dịch từ hóa đơn siêu thị, nhà hàng, cây xăng,...
- Tự động điền biểu mẫu giao dịch, tiết kiệm tối đa thời gian nhập liệu thủ công.

### 5. 🤖 Dự báo Chi tiêu Tương lai bằng ML (Machine Learning Predictions)
- Mô hình Machine Learning phân tích lịch sử biến động chi tiêu theo chuỗi thời gian.
- Tính toán tốc độ chi tiêu trung bình ngày (burn rate) và dự báo chính xác tổng chi tiêu cuối tháng.
- Chuẩn hóa số liệu làm tròn hàng nghìn đồng (`.000 VND`) thân thiện với thói quen tiêu dùng tiền Việt.
- Biểu đồ thống kê danh mục và xu hướng tài chính mượt mà với thư viện **fl_chart**.

### 6. 📱 Android Home Screen Widget & Phím tắt Nhanh
- **Widget màn hình chính Android:** Theo dõi nhanh số dư hiện tại và tổng chi tiêu trong tháng mà không cần mở ứng dụng.
- **Quick Action Shortcuts:** Nhấn giữ biểu tượng ứng dụng hoặc widget để mở nhanh màn hình tạo khoản chi, thu nhập hoặc quét hóa đơn chỉ với 1 chạm.

### 7. 🔔 Nhắc nhở & Tác vụ Ngầm (Background Workers)
- Kết hợp **Flutter Local Notifications** và **Android Alarm Manager Plus**.
- Tác vụ chạy nền độc lập quét hạn các khoản nợ, phát chuông cảnh báo đúng lịch trình ngay cả khi ứng dụng đã đóng hoàn toàn.

### 8. 💾 Sao lưu & Phục hồi Dữ liệu Toàn diện
- Xuất toàn bộ cơ sở dữ liệu và cấu hình ra file sao lưu ngoại tuyến an toàn.
- Khôi phục nhanh chóng khi đổi thiết bị hoặc cài đặt lại hệ điều hành.

### 9. 💱 Hỗ trợ Đa Tiền tệ & Tỷ giá
- Hỗ trợ hiển thị và quy đổi linh hoạt giữa các đơn vị tiền tệ: VND, USD, EUR, JPY, GBP,...
- Cập nhật tỷ giá hối đoái tự động qua API trực tuyến.

### 10. 🌓 Giao diện Đại dương Whales Tối ưu (Modern UI/UX)
- Giao diện Dark Mode & Light Mode sang trọng, dịu mắt.
- Thiết kế responsive co giãn linh hoạt theo tỷ lệ màn hình (tránh tràn khung viền).

---

## 🏗️ Cấu trúc Thư mục Dự án

```text
lib/
├── config/                  # Cấu hình Theme, Màu sắc, Hằng số toàn cục
│   └── app_theme.dart
├── database/                # SQLite Database Helper & Migration System
│   ├── database_helper.dart # Schema v6 (Quản lý loans, loan_payments, transactions, budgets)
│   └── repositories/        # Data Access Objects (Loan, Transaction, Category, Budget,...)
├── models/                  # Các Data Models
│   ├── loan.dart            # Model Khoản vay & Logic tính toán nợ/lãi
│   ├── loan_payment.dart    # Model Lịch sử thanh toán từng đợt
│   ├── transaction.dart     # Model Giao dịch thu/chi
│   ├── category.dart        # Model Danh mục
│   └── budget.dart          # Model Ngân sách
├── providers/               # Quản lý State bằng Provider (Theme, Currency, Notification)
├── screens/                 # Các màn hình chức năng
│   ├── add_loan/            # Form tạo khoản vay mới (tích hợp thiết lập lãi suất)
│   ├── loan/                # Danh sách khoản vay, chi tiết lãi & trả từng phần
│   │   ├── widgets/         # LoanCardWidget, LoanPaymentProgress
│   │   ├── edit_loan_screen.dart
│   │   ├── loan_detail_screen.dart
│   │   └── partial_payment_screen.dart
│   ├── add_transaction/     # Màn hình tạo giao dịch thu chi
│   ├── transaction/         # Quản lý & tra cứu lịch sử giao dịch
│   ├── budget/              # Màn hình quản lý ngân sách
│   ├── receipt_scan/        # Quét và nhận diện hóa đơn OCR
│   ├── machine_learning_statistics/ # Dự báo chi tiêu bằng AI/ML
│   ├── statistics/          # Báo cáo & Biểu đồ trực quan
│   ├── backup/              # Sao lưu & Phục hồi dữ liệu
│   └── main_navigation_wrapper.dart # Bottom Navigation Bar chính
├── services/                # Các dịch vụ hệ thống & Logic nghiệp vụ
│   ├── loan_interest_service.dart # Service tính toán & đồng bộ lãi suất tự động
│   ├── ml_analytics_service.dart   # Service thuật toán dự báo chi tiêu
│   ├── receipt_ocr_service.dart    # Xử lý bóc tách văn bản Google ML Kit
│   ├── notification_service.dart   # Quản lý thông báo cục bộ
│   ├── backup_service.dart         # Xử lý sao lưu dữ liệu
│   └── widget_service.dart         # Tương tác với Android Home Widget
├── utils/                   # Định dạng tiền tệ, xử lý ngày tháng, helpers
└── widgets/                 # Các UI Component dùng chung
```

---

## 🛠️ Công nghệ & Thư viện Sử dụng

| Thành phần | Phiên bản / Thư viện | Vai trò |
| :--- | :--- | :--- |
| **Framework** | **Flutter SDK** (^3.24+) | Nền tảng phát triển ứng dụng di động đa nền tảng |
| **Ngôn ngữ** | **Dart SDK** (^3.9.0) & **Java** | Logic ứng dụng & Mã nguồn Android Native |
| **Cơ sở dữ liệu** | `sqflite: ^2.4.2` | Cơ sở dữ liệu SQLite lưu trữ dữ liệu offline |
| **Quản lý trạng thái** | `provider: ^6.1.2` | Quản lý state toàn cục nhẹ nhàng, hiệu năng cao |
| **Thị giác máy tính (AI)** | `google_mlkit_text_recognition: ^0.13.1` | Nhận diện ký tự quang học (OCR) trên hóa đơn |
| **Camera** | `camera: ^0.11.4` | Chụp ảnh hóa đơn trực tiếp trong app |
| **Biểu đồ** | `fl_chart: ^0.68.0` | Vẽ biểu đồ tài chính tương tác cao |
| **Thông báo & Lịch trình** | `flutter_local_notifications: ^17.2.4` | Bắn thông báo nhắc nhở nợ và ngân sách |
| **Tác vụ nền Android** | `android_alarm_manager_plus: ^4.0.8` | Chạy worker định kỳ kiểm tra hạn nợ |
| **Widget màn hình chính** | `home_widget: ^0.8.1` | Tương tác giữa Flutter và Android AppWidget |
| **Định dạng & Tiện ích** | `intl: ^0.19.0`, `shared_preferences: ^2.4.23` | Định dạng tiền tệ, ngày giờ, lưu trữ cấu hình |

---

## 🚀 Hướng dẫn Cài đặt & Khởi chạy

### 1. Yêu cầu Môi trường
- **Flutter SDK**: Phiên bản 3.24 trở lên (khuyến nghị Flutter 3.29+).
- **Android SDK & Build Tools**: Compile SDK 34+.
- **Java Development Kit (JDK)**: JDK 17 (tương thích Gradle 8.x).

### 2. Các bước Cài đặt
```bash
# 1. Di chuyển vào thư mục dự án
cd d:/My_Workspace/Flutter_Project/renew-whales-spent

# 2. Tải toàn bộ các dependencies
flutter pub get

# 3. Kiểm tra chất lượng mã nguồn
flutter analyze

# 4. Chạy ứng dụng trên thiết bị Android hoặc máy ảo
flutter run
```

### 3. Đóng gói Ứng dụng (Build APK)
```bash
# Đóng gói bản cài đặt Debug APK (kiểm thử nhanh)
flutter build apk --debug

# Đóng gói bản phát hành Release APK
flutter build apk --release
```
*Tệp tin APK sau khi biên dịch hoàn tất sẽ nằm tại:* `build/app/outputs/flutter-apk/app-debug.apk`.

---

## ⚙️ Điểm Cấu hình Android Native Quan trọng

Dự án được cấu hình kỹ lưỡng để vận hành ổn định trên mọi phiên bản Android:
1. **Android Native Java**: `MainActivity.java` được cấu hình chuẩn mực, tối ưu hóa quá trình biên dịch và khả năng tương thích.
2. **Core Library Desugaring**: Kích hoạt `desugar_jdk_libs:2.1.4` trong `android/app/build.gradle.kts` nhằm hỗ trợ đầy đủ các API thời gian của Java 8+ trên Android phiên bản cũ.
3. **Đồng bộ JVM Target**: Thiết lập thống nhất `JavaVersion.VERSION_11` xuyên suốt các subproject.
4. **Quyền hạn cần thiết (`AndroidManifest.xml`)**:
   - `CAMERA`: Dành cho tính năng quét hóa đơn OCR.
   - `RECEIVE_BOOT_COMPLETED` & `SCHEDULE_EXACT_ALARM`: Đảm bảo tác vụ nhắc nợ luôn được kích hoạt lại khi thiết bị khởi động lại.
   - `POST_NOTIFICATIONS`: Cấp phép hiển thị thông báo đẩy trên Android 13+.

---

## 📄 Bản quyền & Đóng góp

- Dự án được phát triển và sở hữu bởi **HaoAboutMe**.
- Mọi ý kiến đóng góp, báo cáo lỗi hoặc đề xuất tính năng mới vui lòng gửi qua mục **Issues** hoặc tạo **Pull Request** trên repository của dự án.
