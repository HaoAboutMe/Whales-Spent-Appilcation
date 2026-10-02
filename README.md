# Whales Spent (renew_whales_spent)

<p align="center">
  <img src="assets/images/logo.png" alt="Whales Spent Logo" width="120" />
</p>

<p align="center">
  <strong>Ứng dụng quản lý tài chính cá nhân thông minh, hiện đại và bảo mật trên nền tảng Flutter.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-%2302569B.svg?style=flat&logo=Flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-%230175C2.svg?style=flat&logo=dart&logoColor=white" alt="Dart" />
  <img src="https://img.shields.io/badge/Android-Java-%23ED8B00.svg?style=flat&logo=openjdk&logoColor=white" alt="Android Java" />
  <img src="https://img.shields.io/badge/License-Private-red.svg?style=flat" alt="License" />
</p>

---

## 📖 Giới thiệu

**Whales Spent** là ứng dụng theo dõi và tối ưu hóa tài chính cá nhân toàn diện, hỗ trợ người dùng kiểm soát thu chi hàng ngày, quản lý các khoản vay nợ, lập kế hoạch ngân sách và phân tích xu hướng tài chính một cách trực quan, khoa học.

Dự án được xây dựng trên nền tảng **Flutter** với phần native Android được thiết lập bằng **Java**, mang lại sự ổn định cao, tương thích mạnh mẽ với các thiết bị Android từ phiên bản cũ đến mới nhất.

---

## ✨ Tính năng nổi bật

### 1. 💵 Quản lý Thu - Chi (Transactions)
- Ghi chép chi tiêu và thu nhập nhanh chóng, chi tiết theo danh mục, thời gian, số tiền và ghi chú.
- Phân loại rõ ràng 4 loại hình: Chi tiêu, Thu nhập, Cho vay, Thu nợ.
- Bộ lọc nâng cao theo khoảng thời gian (ngày, tuần, tháng, năm), danh mục hoặc tìm kiếm theo từ khóa.

### 2. 🤝 Quản lý Khoản Vay & Nợ (Loans & Debts)
- Ghi nhận chi tiết: người vay/cho vay, số tiền, ngày vay, hạn trả nợ, lãi suất (nếu có).
- Theo dõi tiến độ trả nợ từng phần hoặc thanh toán dứt điểm.
- Tự động kiểm tra và gửi **thông báo nhắc nhở hạn trả/thu nợ vào 9:00 sáng mỗi ngày** qua hệ thống chạy nền.

### 3. 🎯 Quản lý Ngân sách (Budgeting)
- Thiết lập ngân sách chi tiêu tổng thể hoặc theo từng danh mục cụ thể (ăn uống, giải trí, hóa đơn,...).
- Thanh tiến độ trực quan, cảnh báo màu sắc khi chi tiêu chạm ngưỡng giới hạn (80%, 100%).

### 4. 📷 Quét Hóa đơn Thông minh bằng AI (Smart Receipt OCR)
- Tích hợp **Google ML Kit Text Recognition** phân tích văn bản hóa đơn trực tiếp từ Camera hoặc Thư viện ảnh.
- Tự động nhận diện và bóc tách số tiền, ngày tháng giao dịch giúp giảm thiểu thao tác nhập liệu thủ công.

### 5. 📊 Thống kê & Phân tích Xu hướng (Analytics & Predictions)
- Biểu đồ tròn và biểu đồ cột trực quan với thư viện **fl_chart**.
- Phân tích chi tiết tỷ trọng chi tiêu theo từng danh mục trong tháng.
- Mô hình Machine Learning phân tích xu hướng và đưa ra dự báo chi tiêu trong tương lai.

### 6. 📱 Android Home Screen Widget
- Hỗ trợ Widget ngay trên màn hình chính của điện thoại Android.
- Hiển thị nhanh số dư hiện tại, tổng thu/chi trong tháng mà không cần mở ứng dụng.
- Phím tắt (Quick Action Shortcuts) giúp tạo giao dịch nhanh chỉ với 1 chạm từ màn hình chính.

### 7. 🔔 Thông báo & Tác vụ Chạy nền (Background Tasks)
- Kết hợp **Flutter Local Notifications** và **Android Alarm Manager Plus**.
- Chạy tác vụ ngầm định kỳ đảm bảo không bao giờ bỏ lỡ các kỳ thanh toán quan trọng.

### 8. 💾 Sao lưu & Phục hồi Dữ liệu (Backup & Restore)
- Lưu trữ hoàn toàn ngoại tuyến (offline-first) trên cơ sở dữ liệu **SQLite**.
- Xuất và nhập toàn bộ dữ liệu an toàn dưới dạng file backup.

### 9. 💱 Đa Tiền tệ & Tỷ giá Trực tuyến
- Hỗ trợ nhiều đơn vị tiền tệ phổ biến (VND, USD, EUR, JPY, GBP,...).
- Cập nhật tỷ giá quy đổi ngoại tệ qua HTTP API.

### 10. 🌓 Giao diện Hiện đại (Whales Theme)
- Hỗ trợ chế độ Sáng (Light Mode) và Tối (Dark Mode) chuẩn phong cách hiện đại.
- Hiệu ứng chuyển động mượt mà, thân thiện với người dùng.

---

## 🏗️ Cấu trúc Thư mục

```text
lib/
├── config/                  # Cấu hình Theme, Màu sắc, Constants
│   └── app_theme.dart
├── database/                # SQLite Database Helper & Repositories
│   ├── app_database.dart
│   └── repositories/
├── models/                  # Các Data Models (Transaction, Category, Loan, Budget,...)
├── providers/               # Quản lý State bằng Provider (Theme, Currency, Notifications)
├── screens/                 # Giao diện ứng dụng theo từng Module
│   ├── add_loan/            # Thêm/sửa khoản vay
│   ├── add_transaction/     # Thêm/sửa giao dịch
│   ├── backup/              # Sao lưu & khôi phục dữ liệu
│   ├── budget/              # Quản lý ngân sách
│   ├── category/            # Quản lý danh mục thu chi
│   ├── home/                # Trang chủ tổng quan
│   ├── initial_setup/       # Màn hình khởi tạo lần đầu (Onboarding)
│   ├── loan/                # Danh sách & chi tiết khoản vay
│   ├── machine_learning_statistics/ # Dự báo chi tiêu bằng ML
│   ├── notification/        # Danh sách thông báo
│   ├── profile/             # Cài đặt người dùng, hướng dẫn sử dụng
│   ├── receipt_scan/        # Quét hóa đơn OCR bằng camera
│   ├── settings/            # Cài đặt ứng dụng & phím tắt Widget
│   ├── statistics/          # Biểu đồ & phân tích tài chính
│   ├── transaction/         # Lịch sử giao dịch & bộ lọc
│   └── main_navigation_wrapper.dart # Điều hướng chính (Bottom Navigation)
├── services/                # Các dịch vụ xử lý nền & ngoại vi
│   ├── backup_service.dart
│   ├── ml_analytics_service.dart
│   ├── notification_service.dart
│   ├── quick_action_service.dart
│   ├── receipt_ocr_service.dart
│   └── widget_service.dart
├── utils/                   # Hàm tiện ích (Formatter, Helpers)
└── widgets/                 # Các UI Component tái sử dụng
```

---

## 🛠️ Công nghệ Sử dụng

| Thành phần | Công nghệ / Thư viện |
| :--- | :--- |
| **Framework** | Flutter (Dart SDK ^3.9.0) |
| **Android Native** | Java (`MainActivity.java`), Gradle Plugin 8.11+, JVM Target 11 |
| **State Management** | `provider: ^6.1.2` |
| **Cơ sở dữ liệu** | `sqflite: ^2.3.0`, `path: ^1.8.3` |
| **AI / OCR** | `google_mlkit_text_recognition: ^0.13.0`, `camera: ^0.11.0` |
| **Biểu đồ** | `fl_chart: ^0.68.0` |
| **Thông báo & Background** | `flutter_local_notifications: ^17.1.2`, `android_alarm_manager_plus: ^4.0.3` |
| **Home Screen Widget** | `home_widget: ^0.8.0`, `androidx.glance:glance-appwidget:1.1.1` |
| **Định dạng & Tiện ích** | `intl: ^0.19.0`, `shared_preferences: ^2.3.2`, `http: ^1.1.0` |

---

## 🚀 Hướng dẫn Cài đặt & Chạy Dự án

### Yêu cầu tiên quyết
- **Flutter SDK**: Phiên bản 3.24 trở lên (khuyến nghị Flutter 3.29+).
- **Android SDK & Build Tools**: Hỗ trợ compileSdk 34+.
- **Java Development Kit (JDK)**: JDK 17.

### Các bước thực hiện

1. **Clone hoặc mở thư mục dự án:**
   ```bash
   cd d:/My_Workspace/Flutter_Project/renew-whales-spent
   ```

2. **Cài đặt các gói phụ thuộc (Dependencies):**
   ```bash
   flutter pub get
   ```

3. **Kiểm tra mã nguồn:**
   ```bash
   flutter analyze
   ```

4. **Chạy ứng dụng ở chế độ Debug:**
   - Kết nối điện thoại Android (đã bật USB Debugging) hoặc khởi động máy ảo Android:
   ```bash
   flutter run
   ```

5. **Đóng gói file cài đặt (APK):**
   ```bash
   # Build APK Debug
   flutter build apk --debug

   # Build APK Release
   flutter build apk --release
   ```
   File APK hoàn thiện sẽ được xuất tại thư mục: `build/app/outputs/flutter-apk/`.

---

## ⚙️ Lưu ý Cấu hình Android Đặc biệt

Dự án đã được cấu hình tối ưu để tránh các lỗi xung đột phiên bản phổ biến:
1. **Core Library Desugaring**: Đã bật trong `android/app/build.gradle.kts` (`desugar_jdk_libs:2.1.4`) để hỗ trợ đầy đủ các hàm Java 8+ trên các phiên bản Android cũ cho thư viện thông báo.
2. **Đồng bộ JVM Target**: Thiết lập đồng nhất `JVM 11` giữa Java và Kotlin trên tất cả module và subproject để đảm bảo tính tương thích khi biên dịch.
3. **AndroidX Glance Fix**: Đã ghim phiên bản ổn định `androidx.glance:glance-appwidget:1.1.1` giúp widget màn hình chính hoạt động trơn tru với Android Gradle Plugin hiện tại.
4. **Quyền truy cập (Permissions)**: Khai báo đầy đủ quyền trong `AndroidManifest.xml` (`CAMERA`, `INTERNET`, `POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`, `RECEIVE_BOOT_COMPLETED`,...).

---

## 👥 Đóng góp & Bản quyền

Dự án thuộc sở hữu cá nhân phục vụ cho mục đích quản lý tài chính thông minh và hiệu quả.
Mọi đóng góp, cải tiến vui lòng tạo Issue hoặc gửi Pull Request.
