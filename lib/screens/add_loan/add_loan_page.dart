import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../database/repositories/repositories.dart';
import '../../models/loan.dart';
import '../../models/transaction.dart' as transaction_model;
import '../../utils/currency_formatter.dart';
import '../../providers/notification_provider.dart';
import '../../providers/currency_provider.dart';

class AddLoanPage extends StatefulWidget {
  final String? preselectedType;

  const AddLoanPage({
    super.key,
    this.preselectedType,
  });

  @override
  State<AddLoanPage> createState() => _AddLoanPageState();
}

class _AddLoanPageState extends State<AddLoanPage>
    with SingleTickerProviderStateMixin {
  final LoanRepository _loanRepository = LoanRepository();
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final _personNameController = TextEditingController();
  final _personPhoneController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Form data
  String _selectedType = 'lend';
  DateTime _loanDate = DateTime.now();
  DateTime? _dueDate;
  bool _reminderEnabled = true;
  int _reminderDays = 3;
  bool _isOldDebt = false; // New field to distinguish old vs new loans

  // Interest data
  bool _hasInterest = false;
  final _interestRateController = TextEditingController(text: '2000');
  String _interestRateType = 'vnd_per_million_per_day';
  String _interestCalculationType = 'simple';

  // UI state
  bool _isLoading = false;

  // Animation
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    // Map preselected type from quick actions
    if (widget.preselectedType == 'loan_given') {
      _selectedType = 'lend';
    } else if (widget.preselectedType == 'loan_received') {
      _selectedType = 'borrow';
    } else {
      _selectedType = widget.preselectedType ?? 'lend';
    }
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _personNameController.dispose();
    _personPhoneController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _interestRateController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onTypeChanged(String type) {
    setState(() {
      _selectedType = type;
    });
  }

  Future<void> _selectLoanDate() async {
    // Dismiss keyboard trước khi mở date picker
    FocusScope.of(context).requestFocus(FocusNode());

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _loanDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: _getTypeColor(_selectedType),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _loanDate) {
      setState(() {
        _loanDate = picked;
      });
    }
  }

  Future<void> _selectDueDate() async {
    // Dismiss keyboard trước khi mở date picker
    FocusScope.of(context).requestFocus(FocusNode());

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? _loanDate,
      firstDate: _loanDate,
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: _getTypeColor(_selectedType),
            ),
          ),
          child: child!,
        );
      },
    );

    setState(() {
      _dueDate = picked;
    });
  }

  Future<void> _saveLoan() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final inputAmount = CurrencyFormatter.parseAmount(_amountController.text);

      // Convert từ currency hiện tại về VND để lưu vào database
      final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
      final amountInVND = currencyProvider.convertToVND(inputAmount);

      // Debug log
      debugPrint('=== DEBUG LOAN AMOUNT CONVERSION ===');
      debugPrint('Input amount: $inputAmount ${currencyProvider.selectedCurrency}');
      debugPrint('Converted to VND: $amountInVND VND');
      debugPrint('===================================');

      // Validate balance for new "lend" loans (only affects balance)
      if (!_isOldDebt && _selectedType == 'lend') {
        final userRepository = UserRepository();
        final currentUserId = await userRepository.getCurrentUserId();
        final currentUser = await userRepository.getUserById(currentUserId);

        if (currentUser != null && amountInVND > currentUser.balance) {
          setState(() {
            _isLoading = false;
          });
          _showErrorSnackBar('Số tiền cho vay vượt quá số dư hiện tại (${CurrencyFormatter.formatAmount(currentUser.balance)})');
          return;
        }
      }

      final personName = _personNameController.text.trim();
      final personPhone = _personPhoneController.text.trim().isEmpty
          ? null
          : _personPhoneController.text.trim();
      final description = _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim();

      final interestRate = _hasInterest
          ? (double.tryParse(_interestRateController.text.replaceAll(',', '.')) ?? 0.0)
          : 0.0;

      final loan = Loan(
        personName: personName,
        personPhone: personPhone,
        amount: amountInVND,
        loanType: _selectedType,
        loanDate: _loanDate,
        dueDate: _dueDate,
        status: 'active',
        description: description,
        paidDate: null,
        reminderEnabled: _reminderEnabled,
        reminderDays: _reminderEnabled ? _reminderDays : null,
        lastReminderSent: null,
        isOldDebt: _isOldDebt ? 1 : 0, // Set based on toggle
        amountPaid: 0.0,
        hasInterest: _hasInterest && interestRate > 0,
        interestRate: interestRate,
        interestRateType: _interestRateType,
        interestCalculationType: _interestCalculationType,
        interestPeriod: 'monthly',
        accruedInterest: 0.0,
        interestPaid: 0.0,
        lastInterestCalculatedDate: _loanDate,
        overdueInterestMultiplier: 1.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      int createdLoanId;
      if (_isOldDebt) {
        // Khoản vay cũ: chỉ thêm loan, không tạo transaction, không ảnh hưởng số dư
        createdLoanId = await _loanRepository.insertLoan(loan);
        debugPrint('Inserted old loan with ID: $createdLoanId');
      } else {
        // Khoản vay mới: tạo loan + transaction tương ứng
        final transaction = transaction_model.Transaction(
          amount: amountInVND,
          description: description ?? 'Khoản ${_selectedType == 'lend' ? 'cho vay' : 'đi vay'}: $personName',
          date: _loanDate,
          categoryId: null, // Loans don't use categories
          loanId: null, // Will be set after loan is created
          type: _selectedType == 'lend' ? 'loan_given' : 'loan_received',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final result = await _loanRepository.createLoanWithTransaction(
          loan: loan,
          transaction: transaction,
        );
        createdLoanId = result['loanId']!;
        debugPrint('Created new loan with transaction, ID: $createdLoanId');
      }

      // Check if widget is still mounted before using context
      if (!mounted) return;

      // ✅ REALTIME: Notify provider to schedule reminders and update badge
      final notificationProvider = context.read<NotificationProvider>();
      debugPrint('🔔 Notifying provider about new loan: $createdLoanId');
      await notificationProvider.onLoanCreatedOrUpdated(createdLoanId);

      Navigator.of(context).pop(true); // Return true to indicate success
    } catch (e) {
      debugPrint('Error saving loan: $e');
      if (mounted) {
        _showErrorSnackBar('Không thể lưu khoản vay/nợ');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
      ),
    );
  }

  String _getLoanTypeText() {
    return _selectedType == 'lend' ? 'cho vay' : 'đi vay';
  }

  Color _getTypeColor(String type) {
    return type == 'lend'
        ? const Color(0xFFFFA726) // Orange for lending
        : const Color(0xFF9575CD); // Purple for borrowing
  }

  IconData _getTypeIcon(String type) {
    return type == 'lend' ? Icons.call_made : Icons.call_received;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true, // Enable automatic screen resize for keyboard
      appBar: AppBar(
        title: const Text(
          'Thêm khoản vay / nợ mới',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: _getTypeColor(_selectedType),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).padding.bottom + 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTypeSelector(),
                  const SizedBox(height: 24),
                  _buildPersonNameField(),
                  const SizedBox(height: 20),
                  _buildPersonPhoneField(),
                  const SizedBox(height: 20),
                  _buildAmountField(),
                  const SizedBox(height: 20),
                  _buildDescriptionField(),
                  const SizedBox(height: 20),
                  _buildDateSelectors(),
                  const SizedBox(height: 20),
                  _buildReminderSettings(),
                  const SizedBox(height: 20),
                  _buildOldDebtToggle(),
                  const SizedBox(height: 20),
                  _buildInterestSettings(),
                  const SizedBox(height: 32),
                  _buildSaveButton(),
                  const SizedBox(height: 20), // Extra space for better scrolling
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Loại khoản vay',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildTypeButton('lend', 'Cho vay', Icons.call_made)),
              const SizedBox(width: 12),
              Expanded(child: _buildTypeButton('borrow', 'Đi vay', Icons.call_received)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeButton(String type, String label, IconData icon) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = _selectedType == type;
    final color = _getTypeColor(type);

    return GestureDetector(
      onTap: () => _onTypeChanged(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : colorScheme.outline.withValues(alpha: 0.5),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? color : colorScheme.onSurfaceVariant,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonNameField() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _selectedType == 'lend' ? 'Tên người vay' : 'Tên người cho vay',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _personNameController,
            decoration: InputDecoration(
              hintText: 'Nhập họ tên...',
              hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
              prefixIcon: Icon(
                Icons.person,
                color: _getTypeColor(_selectedType),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _getTypeColor(_selectedType), width: 2),
              ),
              filled: true,
              fillColor: colorScheme.surface,
            ),
            style: TextStyle(color: colorScheme.onSurface),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Vui lòng nhập tên người ${_selectedType == 'lend' ? 'vay' : 'cho vay'}';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPersonPhoneField() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Số điện thoại (tùy chọn)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _personPhoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              hintText: 'Nhập số điện thoại...',
              hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
              prefixIcon: Icon(Icons.phone, color: colorScheme.onSurfaceVariant),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.primary, width: 2),
              ),
              filled: true,
              fillColor: colorScheme.surface,
            ),
            style: TextStyle(color: colorScheme.onSurface),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountField() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Số tiền',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              CurrencyInputFormatter(), // Chỉ sử dụng formatter custom
            ],
            decoration: InputDecoration(
              hintText: 'Nhập số tiền (${Provider.of<CurrencyProvider>(context, listen: false).selectedCurrency})',
              hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
              suffixText: Provider.of<CurrencyProvider>(context, listen: false).currencySymbol,
              suffixStyle: TextStyle(color: colorScheme.onSurfaceVariant),
              prefixIcon: Icon(
                Icons.attach_money,
                color: _getTypeColor(_selectedType),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _getTypeColor(_selectedType), width: 2),
              ),
              filled: true,
              fillColor: colorScheme.surface,
            ),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _getTypeColor(_selectedType),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Vui lòng nhập số tiền';
              }
              // Sử dụng CurrencyFormatter.parseAmount để validate
              final amount = CurrencyFormatter.parseAmount(value);
              if (amount <= 0) {
                return 'Số tiền phải lớn hơn 0';
              }
              return null;
            },
          ),
          // Helper text for currency conversion
          Consumer<CurrencyProvider>(
            builder: (context, currencyProvider, child) {
              if (currencyProvider.selectedCurrency == 'USD') {
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0, left: 12.0),
                  child: Text(
                    'Sẽ được chuyển đổi thành VND khi lưu (tỷ giá: 1 USD = ${currencyProvider.exchangeRate.toStringAsFixed(0)} VND)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelectors() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Thông tin thời gian',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          // Loan Date
          InkWell(
            onTap: _selectLoanDate,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.outline.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(12),
                color: colorScheme.surface,
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ngày vay',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '${_loanDate.day}/${_loanDate.month}/${_loanDate.year}',
                        style: TextStyle(
                          fontSize: 16,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_drop_down, color: colorScheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Due Date
          InkWell(
            onTap: _selectDueDate,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.outline.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(12),
                color: colorScheme.surface,
              ),
              child: Row(
                children: [
                  Icon(Icons.event, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hạn trả (tùy chọn)',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        _dueDate != null
                            ? '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}'
                            : 'Chưa đặt hạn trả',
                        style: TextStyle(
                          fontSize: 16,
                          color: _dueDate != null ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (_dueDate != null)
                    GestureDetector(
                      onTap: () => setState(() => _dueDate = null),
                      child: Icon(Icons.clear, color: colorScheme.onSurfaceVariant, size: 20),
                    ),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_drop_down, color: colorScheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionField() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mô tả (tùy chọn)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descriptionController,
            maxLines: 3,
            maxLength: 80,
            decoration: InputDecoration(
              hintText: 'Nhập mô tả cho khoản vay/nợ...',
              hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
              prefixIcon: Icon(Icons.description, color: colorScheme.onSurfaceVariant),
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.primary, width: 2),
              ),
              filled: true,
              fillColor: colorScheme.surface,
            ),
            style: TextStyle(color: colorScheme.onSurface),
          ),
        ],
      ),
    );
  }

  Widget _buildOldDebtToggle() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Loại khoản vay',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: Text(
              _isOldDebt ? 'Khoản vay cũ (trước khi dùng app)' : 'Khoản vay mới',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
            subtitle: Text(
              _isOldDebt
                  ? 'Chỉ ghi nhận, không ảnh hưởng số dư hiện tại'
                  : 'Tạo giao dịch mới và cập nhật số dư',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            value: _isOldDebt,
            thumbColor: WidgetStateProperty.all(_getTypeColor(_selectedType)),
            onChanged: (value) {
              setState(() {
                _isOldDebt = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickRateChip(String label, String value) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = _interestRateController.text == value;

    return ActionChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.amber.shade900 : colorScheme.onSurface,
        ),
      ),
      backgroundColor: isSelected ? Colors.amber.withValues(alpha: 0.25) : colorScheme.surface,
      side: BorderSide(
        color: isSelected ? Colors.amber : colorScheme.outline.withValues(alpha: 0.3),
        width: isSelected ? 1.5 : 1,
      ),
      onPressed: () {
        setState(() {
          _interestRateController.text = value;
        });
      },
    );
  }

  Widget _buildInterestSettings() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Tính thử tiền lãi dự kiến nếu người dùng đã nhập số tiền
    final enteredAmount = CurrencyFormatter.parseAmount(_amountController.text);
    final enteredRate = double.tryParse(_interestRateController.text.replaceAll(',', '.')) ?? 0.0;

    double sampleDailyInterest = 0.0;
    if (enteredAmount > 0 && enteredRate > 0) {
      if (_interestRateType == 'vnd_per_million_per_day') {
        sampleDailyInterest = (enteredAmount / 1000000.0) * enteredRate;
      } else if (_interestRateType == 'percent_per_month') {
        sampleDailyInterest = enteredAmount * (enteredRate / 100.0) / 30.0;
      } else if (_interestRateType == 'percent_per_year') {
        sampleDailyInterest = enteredAmount * (enteredRate / 100.0) / 365.0;
      } else {
        sampleDailyInterest = enteredAmount * (enteredRate / 100.0);
      }
    }
    final sampleMonthlyInterest = sampleDailyInterest * 30.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.percent, color: Colors.amber, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tính lãi suất',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Tự động tính và cập nhật mỗi khi vào app',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _hasInterest,
                activeColor: Colors.amber,
                onChanged: (val) {
                  setState(() {
                    _hasInterest = val;
                  });
                },
              ),
            ],
          ),
          if (_hasInterest) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),

            // Dropdown chọn đơn vị tính lãi
            Text(
              'Hình thức tính lãi',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outline.withValues(alpha: 0.5)),
                color: colorScheme.surface,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _interestRateType,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(
                      value: 'vnd_per_million_per_day',
                      child: Text('Đồng / triệu / ngày (Dân gian phổ biến)'),
                    ),
                    DropdownMenuItem(
                      value: 'percent_per_month',
                      child: Text('% / tháng (Vay bạn bè, tư nhân)'),
                    ),
                    DropdownMenuItem(
                      value: 'percent_per_year',
                      child: Text('% / năm (Ngân hàng, tài chính)'),
                    ),
                    DropdownMenuItem(
                      value: 'percent_per_day',
                      child: Text('% / ngày'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _interestRateType = val;
                        if (val == 'vnd_per_million_per_day' && (_interestRateController.text.isEmpty || _interestRateController.text == '1.5')) {
                          _interestRateController.text = '2000';
                        } else if (val == 'percent_per_month' && (_interestRateController.text.isEmpty || _interestRateController.text == '2000')) {
                          _interestRateController.text = '1.5';
                        } else if (val == 'percent_per_year' && (_interestRateController.text.isEmpty || _interestRateController.text == '2000')) {
                          _interestRateController.text = '12';
                        }
                      });
                    }
                  },
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Input mức lãi suất
            Text(
              _interestRateType == 'vnd_per_million_per_day'
                  ? 'Mức tiền lãi (đồng / 1 triệu / ngày)'
                  : 'Mức lãi suất (%)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _interestRateController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: _interestRateType == 'vnd_per_million_per_day' ? 'VD: 2000 (tức 2k/tr/ngày)' : 'VD: 1.5 hoặc 2',
                hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                prefixIcon: const Icon(Icons.attach_money, color: Colors.amber),
                suffixText: _interestRateType == 'vnd_per_million_per_day'
                    ? 'đ / tr / ngày'
                    : (_interestRateType == 'percent_per_month' ? '% / tháng' : (_interestRateType == 'percent_per_year' ? '% / năm' : '% / ngày')),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.amber, width: 2),
                ),
                filled: true,
                fillColor: colorScheme.surface,
              ),
            ),

            const SizedBox(height: 10),

            // Gợi ý mức lãi suất thông dụng
            Wrap(
              spacing: 8,
              children: [
                if (_interestRateType == 'vnd_per_million_per_day') ...[
                  _buildQuickRateChip('1.000đ', '1000'),
                  _buildQuickRateChip('2.000đ', '2000'),
                  _buildQuickRateChip('3.000đ', '3000'),
                  _buildQuickRateChip('5.000đ', '5000'),
                ] else if (_interestRateType == 'percent_per_month') ...[
                  _buildQuickRateChip('1%/tháng', '1'),
                  _buildQuickRateChip('1.5%/tháng', '1.5'),
                  _buildQuickRateChip('2%/tháng', '2'),
                  _buildQuickRateChip('3%/tháng', '3'),
                ] else ...[
                  _buildQuickRateChip('8%/năm', '8'),
                  _buildQuickRateChip('10%/năm', '10'),
                  _buildQuickRateChip('12%/năm', '12'),
                ],
              ],
            ),

            // Thẻ preview tiền lãi ước tính
            if (enteredAmount > 0 && sampleDailyInterest > 0) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calculate_outlined, color: Colors.amber, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ước tính tiền lãi:',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '~${CurrencyFormatter.formatAmount(sampleDailyInterest)}/ngày (${CurrencyFormatter.formatAmount(sampleMonthlyInterest)}/tháng)',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Lãi kép / Nhập gốc
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Nhập lãi vào gốc (Lãi kép)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: Text(
                'Lãi chưa trả sau mỗi chu kỳ tháng sẽ cộng dồn vào nợ gốc để tính lãi tiếp',
                style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
              ),
              value: _interestCalculationType == 'compound',
              activeColor: Colors.amber,
              onChanged: (val) {
                setState(() {
                  _interestCalculationType = val ? 'compound' : 'simple';
                });
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReminderSettings() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cài đặt nhắc nhở',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Bật nhắc nhở'),
            subtitle: Text(_reminderEnabled
                ? 'Nhắc nhở trước $_reminderDays ngày đáo hạn'
                : 'Tắt thông báo nhắc nhở'),
            value: _reminderEnabled,
            thumbColor: WidgetStateProperty.all(_getTypeColor(_selectedType)),
            onChanged: (value) {
              setState(() {
                _reminderEnabled = value;
              });
            },
          ),
          if (_reminderEnabled) ...[
            const SizedBox(height: 12),
            Text(
              'Nhắc trước (ngày):',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [1, 3, 7, 14].map((days) {
                final isSelected = _reminderDays == days;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: () => setState(() => _reminderDays = days),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _getTypeColor(_selectedType).withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? _getTypeColor(_selectedType)
                                : colorScheme.outline.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          '$days',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isSelected
                                ? _getTypeColor(_selectedType)
                                : colorScheme.onSurfaceVariant,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveLoan,
        style: ElevatedButton.styleFrom(
          backgroundColor: _getTypeColor(_selectedType),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
        ),
        child: _isLoading
            ? const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_getTypeIcon(_selectedType)),
            const SizedBox(width: 8),
            Text(
              'Lưu khoản ${_getLoanTypeText()}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
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
