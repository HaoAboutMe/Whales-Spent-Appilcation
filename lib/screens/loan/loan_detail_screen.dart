import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/loan.dart';
import '../../models/loan_payment.dart';
import '../../models/transaction.dart' as transaction_model;
import '../../utils/currency_formatter.dart';
import '../../database/repositories/repositories.dart';
import '../../providers/notification_provider.dart';
import '../../services/loan_interest_service.dart';
import 'edit_loan_screen.dart';
import 'partial_payment_screen.dart';
import '../main_navigation_wrapper.dart';

/// LoanDetailScreen - Màn hình chi tiết khoản vay/đi vay
/// Features: Hiển thị đầy đủ thông tin, nút chỉnh sửa, layout đẹp với Ocean Blue theme
class LoanDetailScreen extends StatefulWidget {
  final int loanId;
  final Loan? loan;

  const LoanDetailScreen({
    super.key,
    required this.loanId,
    this.loan,
  });

  @override
  State<LoanDetailScreen> createState() => _LoanDetailScreenState();
}

class _LoanDetailScreenState extends State<LoanDetailScreen> {
  final LoanRepository _loanRepository = LoanRepository();
  Loan? _loan;
  List<LoanPayment> _paymentHistory = [];
  bool _isLoading = true;
  bool _dataWasModified = false; // Track if loan was edited/deleted

  @override
  void initState() {
    super.initState();
    _loadLoanData();
  }

  Future<void> _loadLoanData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      Loan? loadedLoan;

      if (widget.loan != null) {
        // Use provided loan if available
        loadedLoan = widget.loan;
      } else if (widget.loanId > 0) {
        // Load from database using loanId
        loadedLoan = await _loanRepository.getLoanById(widget.loanId);
      }

      List<LoanPayment> loadedPayments = [];
      if (loadedLoan != null && loadedLoan.id != null) {
        loadedPayments = await LoanInterestService().getPaymentHistory(loadedLoan.id!);
      }

      setState(() {
        _loan = loadedLoan;
        _paymentHistory = loadedPayments;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading loan data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getTypeText() {
    if (_loan == null) return '';
    return _loan!.loanType == 'lend' ? 'Cho vay' : 'Đi vay';
  }

  String _getStatusText() {
    if (_loan == null) return '';

    // ✅ Kiểm tra trạng thái thanh toán TRƯỚC (đồng bộ với loan_list_screen)
    if (_loan!.status == 'completed' || _loan!.status == 'paid') {
      return 'Đã thanh toán';
    }

    final now = DateTime.now();
    if (_loan!.dueDate == null) return 'Đang hoạt động';
    if (_loan!.dueDate!.isBefore(now)) return 'Quá hạn';
    if (_loan!.dueDate!.difference(now).inDays <= 7) return 'Sắp hết hạn';
    return 'Đang hoạt động';
  }

  Color _getStatusColor() {
    if (_loan == null) return Colors.grey;
    final status = _getStatusText();
    if (status == 'Quá hạn') return Colors.red;
    if (status == 'Sắp hết hạn') return Colors.orange;
    if (status == 'Đã thanh toán') return const Color(0xFF4CAF50); // Green for completed
    return const Color(0xFF4CAF50); // Green for active
  }

  String _getBadgeText() {
    if (_loan == null) return '';
    return _loan!.isOldDebt == 0 ? 'MỚI' : 'CŨ';
  }

  Color _getLoanColor() {
    if (_loan == null) return const Color(0xFF00A8CC); // Default blue
    return _loan!.loanType == 'lend'
        ? const Color(0xFFFFA726)  // Orange for lending
        : const Color(0xFF9575CD); // Purple for borrowing
  }

  Future<void> _navigateToEditLoan() async {
    if (_loan == null) return;

    // Check if loan is already paid
    if (_loan!.status == 'completed' || _loan!.status == 'paid') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('🔒 Không thể chỉnh sửa khoản vay đã thanh toán'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
        ),
      );
      return;
    }

    // Check if loan has any partial payment
    if (_loan!.amountPaid > 0) {
      return;
    }

    debugPrint('🚀 Navigating to EditLoanScreen...');

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => EditLoanScreen(loan: _loan!),
      ),
    );

    debugPrint('🔄 Returned from EditLoanScreen with result: $result');

    // ✅ REALTIME: Reload loan data if changes were made
    if (result == true) {
      await _loadLoanData();
      _dataWasModified = true; // Mark that data was modified

      // ✅ REALTIME: Trigger HomePage reload to update balance
      mainNavigationKey.currentState?.refreshHomePage();


      // DON'T pop here - stay on detail screen to show updated data
      // The data will be returned when user manually goes back
    }
  }

  Future<void> _deleteLoan() async {
    if (_loan == null) return;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Xác nhận xóa',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bạn có chắc chắn muốn xóa khoản vay "${_loan!.personName}"?',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Không thể xóa nếu khoản vay đã thanh toán hoặc có giao dịch liên quan',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Hủy',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF44336),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Xóa', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show loading
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Đang xóa...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      await _loanRepository.deleteLoan(_loan!.id!);

      debugPrint('✅ Loan deleted successfully');

      // Close loading dialog
      if (!mounted) return;
      Navigator.of(context).pop();

      // ✅ REALTIME: Notify provider to cancel reminders and update badge
      final notificationProvider = context.read<NotificationProvider>();
      debugPrint('🔔 Notifying provider about deleted loan: ${_loan!.id}');
      await notificationProvider.onLoanDeleted(_loan!.id!);

      // Trigger HomePage reload
      mainNavigationKey.currentState?.refreshHomePage();

      // Pop back to previous screen with success flag
      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('❌ Error deleting loan: $e');

      if (!mounted) return;

      // Close loading dialog
      Navigator.of(context).pop();

      // Show appropriate error message
      String errorMessage = '❌ Không thể xóa khoản vay';
      if (e.toString().contains('LOAN_ALREADY_PAID')) {
        errorMessage = '⚠️ Không thể xóa khoản vay đã thanh toán';
      } else if (e.toString().contains('LOAN_HAS_TRANSACTIONS')) {
        errorMessage = '⚠️ Không thể xóa khoản vay vì đang được sử dụng trong giao dịch';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  Future<void> _markLoanAsPaid() async {
    if (_loan == null || _loan!.status == 'completed' || _loan!.status == 'paid') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('⚠️ Khoản vay này đã được thanh toán rồi!'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    // Show confirmation dialog
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final totalPayAmount = _loan!.hasInterest ? _loan!.totalDebtAmount : _loan!.remainingAmount;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '💰 Xác nhận tất toán',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _loan!.loanType == 'lend'
                  ? 'Xác nhận rằng ${_loan!.personName} đã tất toán toàn bộ khoản vay?'
                  : 'Xác nhận rằng bạn đã tất toán toàn bộ khoản nợ cho ${_loan!.personName}?',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getLoanColor().withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.attach_money,
                        color: _getLoanColor(),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Tổng tất toán: ${CurrencyFormatter.formatAmount(totalPayAmount)}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: _getLoanColor(),
                        ),
                      ),
                    ],
                  ),
                  if (_loan!.hasInterest && _loan!.remainingInterest > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      '• Nợ gốc còn lại: ${CurrencyFormatter.formatAmount(_loan!.remainingPrincipal)}',
                      style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                    ),
                    Text(
                      '• Tiền lãi phát sinh: ${CurrencyFormatter.formatAmount(_loan!.remainingInterest)}',
                      style: const TextStyle(fontSize: 12, color: Colors.amber, fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _loan!.loanType == 'lend'
                  ? '✅ Số dư sẽ được cộng thêm ${CurrencyFormatter.formatAmount(totalPayAmount)}'
                  : '⚠️ Số dư sẽ bị trừ ${CurrencyFormatter.formatAmount(totalPayAmount)}',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Hủy',
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50), // Green for success
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Xác nhận tất toán',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show loading
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Đang xử lý tất toán...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final description = _loan!.loanType == 'lend'
          ? 'Tất toán toàn bộ khoản cho vay từ ${_loan!.personName}'
          : 'Tất toán toàn bộ khoản nợ cho ${_loan!.personName}';

      // Mark loan as fully paid via makePartialPayment
      await _loanRepository.makePartialPayment(
        loanId: _loan!.id!,
        paymentAmount: totalPayAmount,
        description: description,
      );

      debugPrint('✅ Loan marked as paid successfully');

      // Close loading dialog first
      if (!mounted) return;
      Navigator.of(context).pop();

      // ✅ REALTIME: Notify provider to cancel reminders and update badge
      final notificationProvider = context.read<NotificationProvider>();
      debugPrint('🔔 Notifying provider about paid loan: ${_loan!.id}');
      await notificationProvider.onLoanPaid(_loan!.id!);

      // Reload loan data to show updated status
      await _loadLoanData();
      _dataWasModified = true; // Mark that data was modified

      // Trigger HomePage reload
      mainNavigationKey.currentState?.refreshHomePage();


      // ✅ STAY on detail screen to show updated status
      // User can see the "Đã thanh toán" badge and paid date
      // User can manually go back when they want
    } catch (e) {
      debugPrint('❌ Error marking loan as paid: $e');

      if (!mounted) return;

      // Close loading dialog
      Navigator.of(context).pop();

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Lỗi: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  Future<void> _navigateToPartialPayment() async {
    if (_loan == null) return;

    // Check if loan is already paid
    if (_loan!.status == 'completed' || _loan!.status == 'paid') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('⚠️ Khoản vay này đã được thanh toán đầy đủ!'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    debugPrint('🚀 Navigating to PartialPaymentScreen...');

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => PartialPaymentScreen(loan: _loan!),
      ),
    );

    debugPrint('🔄 Returned from PartialPaymentScreen with result: $result');

    // ✅ REALTIME: Reload loan data if payment was made
    if (result == true) {
      await _loadLoanData();
      _dataWasModified = true; // Mark that data was modified

      // ✅ REALTIME: Trigger HomePage reload to update balance
      mainNavigationKey.currentState?.refreshHomePage();

      // Check if loan is now fully paid and handle notifications
      if (_loan?.status == 'paid') {
        final notificationProvider = context.read<NotificationProvider>();
        debugPrint('🔔 Notifying provider about fully paid loan: ${_loan!.id}');
        await notificationProvider.onLoanPaid(_loan!.id!);
      }
    }
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    TextStyle? valueStyle,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: valueStyle ??
                  TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? colorScheme.onSurface,
                  ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData titleIcon,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
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
              Icon(titleIcon, color: colorScheme.primary, size: 24),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildPaymentHistorySection() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_paymentHistory.isEmpty) return const SizedBox.shrink();

    return _buildSection(
      title: 'Lịch sử thanh toán (${_paymentHistory.length})',
      titleIcon: Icons.history,
      children: [
        ..._paymentHistory.map((payment) {
          final isLend = _loan?.loanType == 'lend';
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outline.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isLend ? Icons.arrow_downward : Icons.arrow_upward,
                          size: 16,
                          color: const Color(0xFF4CAF50),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${payment.paymentDate.day.toString().padLeft(2, '0')}/${payment.paymentDate.month.toString().padLeft(2, '0')}/${payment.paymentDate.year} ${payment.paymentDate.hour.toString().padLeft(2, '0')}:${payment.paymentDate.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      CurrencyFormatter.formatAmount(payment.totalAmount),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4CAF50),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      'Trừ gốc: ${CurrencyFormatter.formatAmount(payment.principalPaid)}',
                      style: TextStyle(fontSize: 12, color: colorScheme.onSurface),
                    ),
                    if (payment.interestPaid > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        '• Trừ lãi: ${CurrencyFormatter.formatAmount(payment.interestPaid)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.amber,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Nợ gốc sau trả: ${CurrencyFormatter.formatAmount(payment.remainingPrincipalAfter)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                if (payment.notes != null && payment.notes!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    payment.notes!,
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (!didPop) {
          // Return the modified flag when popping
          Navigator.of(context).pop(_dataWasModified);
        }
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
            onPressed: () {
              Navigator.of(context).pop(_dataWasModified);
            },
          ),
          title: Text(
            'Chi tiết khoản vay',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          backgroundColor: theme.scaffoldBackgroundColor,
          foregroundColor: colorScheme.onSurface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: colorScheme.onSurface),
        actions: [
          IconButton(
            icon: Icon(
              (_loan?.status == 'completed' || _loan?.status == 'paid' || (_loan?.amountPaid ?? 0) > 0)
                ? Icons.lock
                : Icons.edit,
              color: colorScheme.onSurface,
            ),
            onPressed: _navigateToEditLoan,
            tooltip: (_loan?.status == 'completed' || _loan?.status == 'paid')
                ? 'Không thể chỉnh sửa khoản vay đã thanh toán'
                : (_loan?.amountPaid ?? 0) > 0
                    ? 'Không thể chỉnh sửa khoản vay đã có thanh toán một phần'
                    : 'Chỉnh sửa',
          ),
          IconButton(
            icon: Icon(Icons.delete, color: colorScheme.onSurface),
            onPressed: _deleteLoan,
            tooltip: 'Xóa',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Đang tải dữ liệu...',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : _loan == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Không tìm thấy thông tin khoản vay',
                        style: TextStyle(
                          fontSize: 18,
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Card - ID và Badge
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _getLoanColor(),
                              _getLoanColor().withValues(alpha: 0.7),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: _getLoanColor().withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'ID: ${_loan!.id}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _getBadgeText(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _getLoanColor(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _loan!.personName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              CurrencyFormatter.formatAmount(
                                (_loan!.status == 'completed' || _loan!.status == 'paid')
                                    ? (_loan!.hasInterest ? (_loan!.amount + _loan!.accruedInterest) : _loan!.amount)
                                    : (_loan!.hasInterest ? _loan!.totalDebtAmount : _loan!.remainingPrincipal),
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_loan!.hasInterest) ...[
                              const SizedBox(height: 4),
                              Text(
                                (_loan!.status == 'completed' || _loan!.status == 'paid')
                                    ? 'Đã tất toán (Gốc: ${CurrencyFormatter.formatAmount(_loan!.amount)} + Lãi: ${CurrencyFormatter.formatAmount(_loan!.accruedInterest)})'
                                    : 'Tổng dư nợ (Gốc: ${CurrencyFormatter.formatAmount(_loan!.remainingPrincipal)} + Lãi: ${CurrencyFormatter.formatAmount(_loan!.remainingInterest)})',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _loan!.loanType == 'lend'
                                            ? Icons.arrow_upward_rounded
                                            : Icons.arrow_downward_rounded,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _getTypeText(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_loan!.hasInterest)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withValues(alpha: 0.9),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.percent, color: Colors.black87, size: 14),
                                        const SizedBox(width: 4),
                                        Text(
                                          _loan!.interestRateDescription,
                                          style: const TextStyle(
                                            color: Colors.black87,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Thông tin liên hệ
                      _buildSection(
                        title: 'Thông tin liên hệ',
                        titleIcon: Icons.person_outline,
                        children: [
                          _buildInfoRow(
                            icon: Icons.person,
                            label: 'Tên người',
                            value: _loan!.personName,
                          ),
                          if (_loan!.personPhone != null && _loan!.personPhone!.isNotEmpty)
                            _buildInfoRow(
                              icon: Icons.phone,
                              label: 'Số điện thoại',
                              value: _loan!.personPhone!,
                              valueColor: colorScheme.primary,
                            ),
                        ],
                      ),

                      // Chi tiết lãi suất (nếu có tính lãi)
                      if (_loan!.hasInterest)
                        _buildSection(
                          title: 'Chi tiết lãi suất',
                          titleIcon: Icons.percent,
                          children: [
                            _buildInfoRow(
                              icon: Icons.tune,
                              label: 'Mức lãi suất',
                              value: _loan!.interestRateDescription,
                              valueColor: Colors.amber.shade800,
                              valueStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.amber),
                            ),
                            _buildInfoRow(
                              icon: Icons.calculate,
                              label: 'Hình thức tính',
                              value: _loan!.interestCalculationType == 'compound'
                                  ? 'Lãi kép (nhập gốc)'
                                  : 'Lãi đơn',
                            ),
                            _buildInfoRow(
                              icon: Icons.trending_up,
                              label: 'Tổng lãi tích lũy',
                              value: CurrencyFormatter.formatAmount(_loan!.accruedInterest),
                              valueStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.amber),
                            ),
                            _buildInfoRow(
                              icon: Icons.done_all,
                              label: 'Tiền lãi đã trả',
                              value: CurrencyFormatter.formatAmount(_loan!.interestPaid),
                              valueColor: const Color(0xFF4CAF50),
                            ),
                            _buildInfoRow(
                              icon: Icons.hourglass_bottom,
                              label: 'Tiền lãi còn nợ',
                              value: CurrencyFormatter.formatAmount(_loan!.remainingInterest),
                              valueStyle: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _loan!.remainingInterest > 0 ? Colors.orange : colorScheme.onSurface,
                              ),
                            ),
                            if (_loan!.lastInterestCalculatedDate != null)
                              _buildInfoRow(
                                icon: Icons.access_time,
                                label: 'Lãi cập nhật lúc',
                                value: '${_loan!.lastInterestCalculatedDate!.hour.toString().padLeft(2, '0')}:${_loan!.lastInterestCalculatedDate!.minute.toString().padLeft(2, '0')} - ${_loan!.lastInterestCalculatedDate!.day}/${_loan!.lastInterestCalculatedDate!.month}/${_loan!.lastInterestCalculatedDate!.year}',
                              ),
                            const Divider(height: 20),
                            _buildInfoRow(
                              icon: Icons.price_check,
                              label: 'Tổng dư nợ cần thanh toán',
                              value: CurrencyFormatter.formatAmount(_loan!.totalDebtAmount),
                              valueStyle: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _getLoanColor(),
                              ),
                            ),
                          ],
                        ),

                      // Thông tin khoản vay
                      _buildSection(
                        title: 'Thông tin khoản vay',
                        titleIcon: Icons.account_balance_wallet_outlined,
                        children: [
                          _buildInfoRow(
                            icon: Icons.attach_money,
                            label: _loan!.hasInterest ? 'Nợ gốc ban đầu' : 'Số tiền',
                            value: CurrencyFormatter.formatAmount(_loan!.amount),
                            valueStyle: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _getLoanColor(),
                            ),
                          ),
                          // Show partial payment progress if there's any payment
                          if (_loan!.amountPaid > 0 || _loan!.interestPaid > 0) ...[
                            const SizedBox(height: 12),
                            _buildInfoRow(
                              icon: Icons.payments,
                              label: _loan!.hasInterest ? 'Gốc đã trả' : 'Đã trả',
                              value: CurrencyFormatter.formatAmount(_loan!.amountPaid),
                              valueStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4CAF50),
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildInfoRow(
                              icon: Icons.pending_actions,
                              label: _loan!.hasInterest ? 'Gốc còn lại' : 'Còn lại',
                              value: CurrencyFormatter.formatAmount(_loan!.remainingPrincipal),
                              valueStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Progress bar
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Tiến độ thanh toán',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      '${_loan!.paymentProgress.toStringAsFixed(1)}%',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _getLoanColor(),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    value: _loan!.paymentProgress / 100,
                                    minHeight: 8,
                                    backgroundColor: Colors.grey.withValues(alpha: 0.2),
                                    valueColor: AlwaysStoppedAnimation<Color>(_getLoanColor()),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 12),
                          _buildInfoRow(
                            icon: Icons.calendar_today,
                            label: 'Ngày cho vay',
                            value: '${_loan!.loanDate.day}/${_loan!.loanDate.month}/${_loan!.loanDate.year}',
                          ),
                          if (_loan!.dueDate != null)
                            _buildInfoRow(
                              icon: Icons.event,
                              label: 'Ngày hết hạn',
                              value: '${_loan!.dueDate!.day}/${_loan!.dueDate!.month}/${_loan!.dueDate!.year}',
                              valueColor: _getStatusColor(),
                            ),
                          _buildInfoRow(
                            icon: Icons.info_outline,
                            label: 'Trạng thái',
                            value: _getStatusText(),
                            valueColor: _getStatusColor(),
                            valueStyle: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(),
                            ),
                          ),
                        ],
                      ),

                      // Lịch sử thanh toán
                      _buildPaymentHistorySection(),

                      // Thông tin bổ sung (nếu có)
                      if (_loan!.description != null && _loan!.description!.isNotEmpty ||
                          _loan!.paidDate != null)
                        _buildSection(
                          title: 'Thông tin bổ sung',
                          titleIcon: Icons.notes,
                          children: [
                            if (_loan!.description != null && _loan!.description!.isNotEmpty)
                              _buildInfoRow(
                                icon: Icons.note_alt_outlined,
                                label: 'Ghi chú',
                                value: _loan!.description!,
                              ),
                            if (_loan!.paidDate != null)
                              _buildInfoRow(
                                icon: Icons.check_circle,
                                label: 'Ngày thanh toán',
                                value: '${_loan!.paidDate!.day}/${_loan!.paidDate!.month}/${_loan!.paidDate!.year}',
                                valueColor: const Color(0xFF4CAF50),
                                valueStyle: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF4CAF50),
                                ),
                              ),
                          ],
                        ),

                      const SizedBox(height: 100), // Space for FABs
                    ],
                  ),
                ),
      floatingActionButton: _loan != null && _loan!.status != 'completed' && _loan!.status != 'paid'
          ? Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Partial payment button
                FloatingActionButton.extended(
                  onPressed: _navigateToPartialPayment,
                  backgroundColor: _getLoanColor(),
                  heroTag: 'partialPayment',
                  icon: const Icon(Icons.payments, color: Colors.white),
                  label: const Text(
                    'Trả 1 phần',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            )
          : null,
      ), // Close PopScope
    );
  }
}

