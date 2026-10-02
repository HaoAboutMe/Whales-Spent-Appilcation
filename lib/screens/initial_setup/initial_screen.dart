import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../database/repositories/repositories.dart';
import '../../models/user.dart';
import '../../utils/currency_formatter.dart';
import '../../providers/currency_provider.dart';

class InitialScreen extends StatefulWidget {
  const InitialScreen({super.key});

  static Future<bool> shouldShowInitialScreen() async {
    // Lấy SharedPreferences instance
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isFirstRun') ?? true;
  }

  @override
  State<InitialScreen> createState() => _InitialScreenState();
}

class _InitialScreenState extends State<InitialScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _balanceController = TextEditingController();

  int _currentStep = 0;
  bool _isLoading = false;
  String _selectedCurrency = 'VND'; // Default currency

  // App colors according to Figma
  static const Color darkBlue = Color(0xFF0D1B2A);   // Header background
  static const Color brightBlue = Color(0xFF1E88E5);  // Body background & button text
  static const Color white = Colors.white;            // Button background & text
  static const Color activeGreen = Color(0xFF00C853); // Active dot indicator

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  /// Hàm chuyển sang bước tiếp theo
  void _nextStep() {
    // Bắt lỗi bước 1 (name input)
    if (_currentStep == 1) {
      if (_nameController.text.trim().isEmpty) {
        _showValidationSnackbar('Vui lòng nhập tên');
        return;
      }
    }

    // Bắt lỗi bước 2 (currency selection) - no validation needed

    // Bắt lỗi bước 3 (balance input)
    if (_currentStep == 3) {
      if (_balanceController.text.trim().isEmpty) {
        _showValidationSnackbar('Vui lòng nhập số dư');
        return;
      }
    }

    // Dismiss keyboard before moving to next step
    FocusScope.of(context).requestFocus(FocusNode());

    if (_currentStep < 4) {
      setState(() {
        _currentStep++;
      });

      // Update CurrencyFormatter when moving from currency selection step
      if (_currentStep == 3) {
        // Just moved to balance input step, update currency in formatter
        // This is only for input formatting; actual save happens in _completeSetup
        CurrencyFormatter.setCurrency(_selectedCurrency);
        debugPrint('💱 Updated CurrencyFormatter for balance input: $_selectedCurrency');
      }


      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeSetup();
    }
  }

  /// Hàm quay lại bước trước
  void _previousStep() {
    FocusScope.of(context).requestFocus(FocusNode());

    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  /// Hàm hiển thị snackbar lỗi (Lỗi không nhập tên hoặc số dư)
  /// Chỉ cần gọi hàm _showValidationSnackbar('Nội dung lỗi');
  void _showValidationSnackbar(String message) {
    //Gọi snackbar của context hiện tại
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: white),
        ),
        backgroundColor: Colors.red[600],
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// Hàm hoàn tất thiết lập ban đầu
  Future<void> _completeSetup() async {
    // Validate name
    if (_nameController.text.trim().isEmpty) {
      _showValidationSnackbar('Vui lòng nhập tên của bạn');
      return;
    }

    // Validate balance
    if (_balanceController.text.trim().isEmpty) {
      _showValidationSnackbar('Vui lòng nhập số dư ban đầu');
      return;
    }

    setState(() =>
      _isLoading = true
    );

    try {
      final currencyProvider =
      Provider.of<CurrencyProvider>(context, listen: false);

      // ================================
      // 1️⃣ UPDATE CURRENCY TRƯỚC KHI PARSE + CONVERT (bắt buộc)
      // ================================
      await currencyProvider.setCurrency(_selectedCurrency);
      CurrencyFormatter.setCurrencyProvider(currencyProvider);

      debugPrint("🔄 Provider currency synced = ${currencyProvider.selectedCurrency}");

      // ================================
      // 2️⃣ PARSE THEO ĐÚNG LOẠI TIỀN
      // ================================
      final parsedAmount = CurrencyFormatter.parseAmount(_balanceController.text);

      debugPrint("💰 Parsed amount: $parsedAmount $_selectedCurrency");

      if (parsedAmount <= 0) {
        _showValidationSnackbar("Số dư phải lớn hơn 0");
        return;
      }

      // ================================
      // 3️⃣ CONVERT SANG VND (luôn lưu VND trong database)
      // ================================
      double balanceVND;

      if (_selectedCurrency == 'USD') {
        balanceVND = currencyProvider.convertToVND(parsedAmount);
        debugPrint("💱 Converting USD → VND: $parsedAmount USD → $balanceVND VND");
      } else {
        balanceVND = parsedAmount;
        debugPrint("💰 Using VND directly: $balanceVND VND");
      }

      // ================================
      // 4️⃣ SAVE USER
      // ================================
      final user = User(
        name: _nameController.text.trim(),
        balance: balanceVND,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      debugPrint("💾 Saving to DB: ${user.name}, balance=${user.balance} VND");
      await UserRepository().insertUser(user);

      // Mark setup done
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isFirstRun', false);

      // Done → go home
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      }

    } catch (e) {
      debugPrint("❌ ERROR: $e");
      if (mounted) _showValidationSnackbar("Có lỗi xảy ra khi lưu thông tin");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBlue,
      resizeToAvoidBottomInset: true, // Enable automatic screen resize for keyboard
      // SafeArea để tránh bị che khuất bởi notch hoặc status bar
      body: SafeArea(
        child: Column(
          children: [
            // Header Section (co giãn linh hoạt theo tỷ lệ màn hình có giới hạn min/max)
            SizedBox(
              height: (MediaQuery.of(context).size.height * 0.22).clamp(120.0, 180.0),
              width: double.infinity,
              child: Container(
                color: darkBlue,
                child: Stack(
                  children: [
                    // Back button (only show from step 2 onwards)
                    if (_currentStep > 0)
                      Positioned(
                        left: 16,
                        top: 16,
                        child: IconButton(
                          onPressed: _previousStep,
                          icon: const Icon(
                            Icons.arrow_back_ios,
                            color: white,
                            size: 24,
                          ),
                        ),
                      ),

                    // Header text
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Text(
                          _getHeaderText(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: white,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Body Section - Tự động co giãn theo keyboard
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: brightBlue,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(40),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(40),
                  ),
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildWelcomeStep(),
                      _buildNameStep(),
                      _buildCurrencyStep(),
                      _buildBalanceStep(),
                      _buildSuccessStep(),
                    ],
                  ),
                ),
              ),
            ),

            // Footer Section - Tự động thu nhỏ khi keyboard mở
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: MediaQuery.of(context).viewInsets.bottom > 0 ? 70 : 140,
              color: brightBlue,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Continue Button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _nextStep,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: white,
                          foregroundColor: brightBlue,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(brightBlue),
                          ),
                        )
                            : Text(
                          _currentStep == 4 ? 'Hoàn tất' : 'Tiếp tục',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Dot Indicator - Ẩn khi keyboard mở để tiết kiệm không gian
                  if (MediaQuery.of(context).viewInsets.bottom == 0) ...[
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: index == _currentStep ? activeGreen : white.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                        );
                      }),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getHeaderText() {
    switch (_currentStep) {
      case 0:
        return 'Chào mừng đến với\nWhales Spent 🐋';
      case 1:
        return 'Nhập tên của bạn để cá nhân hóa trải nghiệm';
      case 2:
        return 'Chọn loại tiền tệ bạn muốn sử dụng';
      case 3:
        return 'Nhập số dư ban đầu để bắt đầu quản lý chi tiêu';
      case 4:
        return 'Hoàn tất thiết lập 🎉';
      default:
        return '';
    }
  }

  Widget _buildWelcomeStep() {
    final screenWidth = MediaQuery.of(context).size.width;
    final logoSize = (screenWidth * 0.35).clamp(100.0, 150.0);

    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Welcome illustration using the whale logo
            Container(
              width: logoSize,
              height: logoSize,
              decoration: BoxDecoration(
                color: white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(logoSize / 2),
                  child: Image.asset(
                    'assets/images/whales-spent-logo.png',
                    width: logoSize * 0.75,
                    height: logoSize * 0.75,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Updated welcome text
            Text(
              'Ứng dụng chi tiêu tốt và thông minh dành cho bạn',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                color: white.withValues(alpha: 0.9),
                fontWeight: FontWeight.w300,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameStep() {
    final screenWidth = MediaQuery.of(context).size.width;
    final iconContainerSize = (screenWidth * 0.28).clamp(70.0, 110.0);

    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // User icon illustration
            if (MediaQuery.of(context).viewInsets.bottom == 0)
              Container(
                width: iconContainerSize,
                height: iconContainerSize,
                decoration: BoxDecoration(
                  color: white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_outline,
                  size: iconContainerSize * 0.5,
                  color: white,
                ),
              ),

            const SizedBox(height: 20),

            // Descriptive text
            Text(
              'Tên của bạn sẽ được dùng để hiển thị lời chào',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: white.withValues(alpha: 0.8),
                fontWeight: FontWeight.w300,
              ),
            ),

            const SizedBox(height: 32),

            // Name input field
            Container(
              decoration: BoxDecoration(
                color: white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _nameController,
                maxLength: 30,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: 'Nhập tên của bạn',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                  prefixIcon: Icon(Icons.person_outline, color: Colors.grey[400]),
                  counterText: '',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrencyStep() {
    final screenWidth = MediaQuery.of(context).size.width;
    final iconContainerSize = (screenWidth * 0.28).clamp(70.0, 110.0);

    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Currency icon illustration
            Container(
              width: iconContainerSize,
              height: iconContainerSize,
              decoration: BoxDecoration(
                color: white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.currency_exchange,
                size: iconContainerSize * 0.5,
                color: white,
              ),
            ),

            const SizedBox(height: 20),

            // Descriptive text
            Text(
              'Chọn loại tiền tệ phù hợp với bạn',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: white.withValues(alpha: 0.8),
                fontWeight: FontWeight.w300,
              ),
            ),

            const SizedBox(height: 24),

            // VND Option
            _buildCurrencyOption(
              'VND',
              '₫',
              'Việt Nam Đồng',
              Icons.attach_money,
            ),

            const SizedBox(height: 16),

            // USD Option
            _buildCurrencyOption(
              'USD',
              '\$',
              'US Dollar',
              Icons.monetization_on,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrencyOption(
    String currencyCode,
    String symbol,
    String name,
    IconData icon,
  ) {
    final isSelected = _selectedCurrency == currencyCode;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCurrency = currencyCode;
        });
        CurrencyFormatter.setCurrency(currencyCode);

        final provider = Provider.of<CurrencyProvider>(context, listen: false);
        provider.setCurrency(currencyCode);
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? white : white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? activeGreen : white.withValues(alpha: 0.3),
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeGreen.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isSelected ? brightBlue.withValues(alpha: 0.1) : white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? brightBlue : white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            // Currency info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currencyCode,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? brightBlue : white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 14,
                      color: isSelected ? brightBlue.withValues(alpha: 0.7) : white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            // Symbol
            Text(
              symbol,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: isSelected ? brightBlue : white.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(width: 8),
            // Check icon
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: activeGreen,
                size: 28,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceStep() {
    final screenWidth = MediaQuery.of(context).size.width;
    final iconContainerSize = (screenWidth * 0.28).clamp(70.0, 110.0);
    final hintText = _selectedCurrency == 'USD'
        ? 'Nhập số dư (USD)'
        : 'Nhập số dư (VND)';

    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Money icon illustration
            if (MediaQuery.of(context).viewInsets.bottom == 0)
              Container(
                width: iconContainerSize,
                height: iconContainerSize,
                decoration: BoxDecoration(
                  color: white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.account_balance_wallet_outlined,
                  size: iconContainerSize * 0.5,
                  color: white,
                ),
              ),

            const SizedBox(height: 20),

            // Descriptive text
            Text(
              'Số dư ban đầu sẽ là mốc để theo dõi chi tiêu',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: white.withValues(alpha: 0.8),
                fontWeight: FontWeight.w300,
              ),
            ),

            const SizedBox(height: 32),

            // Balance input field
            Container(
              decoration: BoxDecoration(
                color: white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _balanceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  CurrencyInputFormatter(),
                ],
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                  prefixIcon: Icon(Icons.attach_money, color: Colors.grey[400]),
                  suffixText: _selectedCurrency,
                  suffixStyle: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessStep() {
    final screenWidth = MediaQuery.of(context).size.width;
    final iconContainerSize = (screenWidth * 0.32).clamp(90.0, 140.0);

    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Success icon illustration
            Container(
              width: iconContainerSize,
              height: iconContainerSize,
              decoration: BoxDecoration(
                color: white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_outline,
                size: iconContainerSize * 0.5,
                color: white,
              ),
            ),

            const SizedBox(height: 28),

            Text(
              'Bạn đã sẵn sàng bắt đầu\nquản lý chi tiêu thông minh!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                color: white.withValues(alpha: 0.9),
                fontWeight: FontWeight.w300,
                height: 1.4,
              ),
            ),

          const SizedBox(height: 30),

          // Summary card
          if (_nameController.text.isNotEmpty && _balanceController.text.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: white.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tên:',
                        style: TextStyle(
                          color: white.withValues(alpha: 0.8),
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        _nameController.text,
                        style: const TextStyle(
                          color: white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Số dư:',
                        style: TextStyle(
                          color: white.withValues(alpha: 0.8),
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${_balanceController.text} $_selectedCurrency',
                        style: const TextStyle(
                          color: white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    // Cho phép empty string
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Get current currency from CurrencyFormatter
    final currentCurrency = CurrencyFormatter.getCurrency();

    if (currentCurrency == 'USD') {
      // Cho USD: chỉ cho phép digits và 1 dấu chấm
      String filtered = newValue.text;

      // Loại bỏ tất cả ký tự không hợp lệ
      filtered = filtered.replaceAll(RegExp(r'[^0-9.]'), '');

      // Đảm bảo chỉ có 1 dấu chấm
      final parts = filtered.split('.');
      if (parts.length > 2) {
        filtered = parts[0] + '.' + parts.sublist(1).join('');
      }

      // Giới hạn 3 chữ số thập phân
      if (parts.length == 2 && parts[1].length > 3) {
        filtered = parts[0] + '.' + parts[1].substring(0, 3);
      }

      return newValue.copyWith(
        text: filtered,
        selection: TextSelection.collapsed(offset: filtered.length),
      );
    } else {
      // Cho VND: chỉ cho phép digits và dấu phẩy
      String filtered = newValue.text.replaceAll(RegExp(r'[^0-9,]'), '');

      // Auto-format với dấu phẩy ngăn cách hàng nghìn cho VND
      if (filtered.isNotEmpty) {
        final digitsOnly = filtered.replaceAll(',', '');
        if (digitsOnly.isNotEmpty) {
          final amount = double.tryParse(digitsOnly) ?? 0;
          if (amount > 0) {
            final formatter = NumberFormat('#,###', 'vi_VN');
            filtered = formatter.format(amount);
          }
        }
      }

      return newValue.copyWith(
        text: filtered,
        selection: TextSelection.collapsed(offset: filtered.length),
      );
    }
  }
}

