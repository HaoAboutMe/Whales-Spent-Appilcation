import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/loan.dart';
import '../../utils/currency_formatter.dart';
import '../../database/repositories/loan_repository.dart';
import '../../providers/currency_provider.dart';
import '../../services/loan_interest_service.dart';

/// Custom TextInputFormatter for currency input
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
        filtered = '${parts[0]}.${parts.sublist(1).join('')}';
      }

      // Giới hạn 3 chữ số thập phân
      if (parts.length == 2 && parts[1].length > 3) {
        filtered = '${parts[0]}.${parts[1].substring(0, 3)}';
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

/// Màn hình thanh toán từng phần cho khoản vay
class PartialPaymentScreen extends StatefulWidget {
  final Loan loan;

  const PartialPaymentScreen({
    super.key,
    required this.loan,
  });

  @override
  State<PartialPaymentScreen> createState() => _PartialPaymentScreenState();
}

class _PartialPaymentScreenState extends State<PartialPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final LoanRepository _loanRepository = LoanRepository();

  bool _isProcessing = false;
  double? _paymentAmount;

  double get _maxPayable => widget.loan.hasInterest ? widget.loan.totalDebtAmount : widget.loan.remainingAmount;

  @override
  void initState() {
    super.initState();
    // Set default description
    final actionText = widget.loan.loanType == 'lend' ? 'Thu nợ từ' : 'Trả nợ cho';
    _descriptionController.text = '$actionText ${widget.loan.personName}';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _onAmountChanged(String value) {
    if (value.isEmpty) {
      setState(() => _paymentAmount = null);
      return;
    }

    final raw = CurrencyFormatter.parseAmount(value);
    final currencyProvider = context.read<CurrencyProvider>();

    final amountVND = currencyProvider.convertToVND(raw);

    setState(() {
      _paymentAmount = amountVND > 0 ? amountVND : null;
    });
  }

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_paymentAmount == null || _paymentAmount! <= 0) {
      _showErrorDialog('Số tiền phải lớn hơn 0');
      return;
    }

    if (_paymentAmount! > _maxPayable + 1.0) {
      _showErrorDialog(
        'Số tiền thanh toán (${CurrencyFormatter.formatAmount(_paymentAmount!)}) '
        'vượt quá số tiền còn lại (${CurrencyFormatter.formatAmount(_maxPayable)})',
      );
      return;
    }

    // Show confirmation
    final confirmed = await _showConfirmationDialog();
    if (!confirmed) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final isFullyPaid = await _loanRepository.makePartialPayment(
        loanId: widget.loan.id!,
        paymentAmount: _paymentAmount!,
        description: _descriptionController.text.trim(),
      );

      if (!mounted) return;

      // Show success message
      final message = isFullyPaid
          ? '✅ Đã thanh toán hoàn tất khoản vay!'
          : '✅ Đã thanh toán ${CurrencyFormatter.formatAmount(_paymentAmount!)}';

      // Return success
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isProcessing = false;
      });

      _showErrorDialog('Lỗi: ${e.toString()}');
    }
  }

  Future<bool> _showConfirmationDialog() async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Map<String, double>? allocation;
    if (widget.loan.hasInterest && _paymentAmount != null) {
      allocation = LoanInterestService().previewPaymentAllocation(
        loan: widget.loan,
        paymentAmount: _paymentAmount!,
      );
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '💰 Xác nhận thanh toán',
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
              'Bạn sẽ thanh toán:',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.attach_money,
                    color: Color(0xFF4CAF50),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    CurrencyFormatter.formatAmount(_paymentAmount!),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4CAF50),
                    ),
                  ),
                ],
              ),
            ),
            if (allocation != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Phân bổ trừ tiền:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• Trừ vào lãi: ${CurrencyFormatter.formatAmount(allocation['interestPaid']!)}',
                      style: const TextStyle(fontSize: 12, color: Colors.amber, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '• Trừ vào gốc: ${CurrencyFormatter.formatAmount(allocation['principalPaid']!)}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF4CAF50), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Số dư sẽ ${widget.loan.loanType == 'lend' ? 'tăng' : 'giảm'} ${CurrencyFormatter.formatAmount(_paymentAmount!)}',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Dư nợ còn lại sau thanh toán: ${CurrencyFormatter.formatAmount((_maxPayable - _paymentAmount!).clamp(0.0, double.infinity))}',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
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
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Xác nhận',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    return confirmed ?? false;
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('❌ Lỗi'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _setFullAmount() {
    final currencyProvider = context.read<CurrencyProvider>();
    final amount = _maxPayable;

    // Convert to current currency for display
    final displayAmount = currencyProvider.selectedCurrency == 'USD'
        ? currencyProvider.convertFromVND(amount)
        : amount;

    // Set as plain number, let formatter handle formatting
    if (currencyProvider.selectedCurrency == 'USD') {
      _amountController.text = displayAmount.toStringAsFixed(2);
    } else {
      _amountController.text = displayAmount.toStringAsFixed(0);
    }

    setState(() {
      _paymentAmount = amount; // Store as VND internally
    });
  }

  void _setHalfAmount() {
    final currencyProvider = context.read<CurrencyProvider>();
    final halfAmount = _maxPayable / 2;

    // Convert to current currency for display
    final displayAmount = currencyProvider.selectedCurrency == 'USD'
        ? currencyProvider.convertFromVND(halfAmount)
        : halfAmount;

    // Set as plain number, let formatter handle formatting
    if (currencyProvider.selectedCurrency == 'USD') {
      _amountController.text = displayAmount.toStringAsFixed(2);
    } else {
      _amountController.text = displayAmount.toStringAsFixed(0);
    }

    setState(() {
      _paymentAmount = halfAmount; // Store as VND internally
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final loanColor = widget.loan.loanType == 'lend'
        ? const Color(0xFFFFA726) // Orange for lending
        : const Color(0xFF9575CD); // Purple for borrowing

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: loanColor,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Thanh toán từng phần',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _isProcessing
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Đang xử lý thanh toán...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Loan info card
                    _buildLoanInfoCard(loanColor),
                    const SizedBox(height: 24),

                    // Payment amount input
                    _buildAmountInput(colorScheme),
                    const SizedBox(height: 16),

                    // Quick amount buttons
                    _buildQuickAmountButtons(),
                    const SizedBox(height: 24),

                    // Description input
                    _buildDescriptionInput(colorScheme),
                    const SizedBox(height: 32),

                    // Submit button
                    _buildSubmitButton(loanColor),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLoanInfoCard(Color loanColor) {
    final currencyProvider = Provider.of<CurrencyProvider>(context);
    final isUsd = currencyProvider.selectedCurrency == 'USD';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: loanColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: loanColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                widget.loan.loanType == 'lend'
                    ? Icons.arrow_upward
                    : Icons.arrow_downward,
                color: loanColor,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.loan.personName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: loanColor,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _buildInfoRow(
            widget.loan.hasInterest ? 'Nợ gốc ban đầu' : 'Tổng số tiền',
            CurrencyFormatter.formatAmount(widget.loan.amount),
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            widget.loan.hasInterest ? 'Gốc đã trả' : 'Đã trả',
            CurrencyFormatter.formatAmount(widget.loan.amountPaid),
            color: Colors.green,
          ),
          if (widget.loan.hasInterest) ...[
            const SizedBox(height: 8),
            _buildInfoRow(
              'Gốc còn lại',
              CurrencyFormatter.formatAmount(widget.loan.remainingPrincipal),
              color: Colors.blueGrey,
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              'Lãi tích lũy phát sinh',
              '+${CurrencyFormatter.formatAmount(widget.loan.accruedInterest)}',
              color: Colors.amber,
            ),
            if (widget.loan.interestPaid > 0) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                'Lãi đã trả',
                CurrencyFormatter.formatAmount(widget.loan.interestPaid),
                color: Colors.green,
              ),
            ],
            const SizedBox(height: 8),
            _buildInfoRow(
              'Lãi còn nợ',
              CurrencyFormatter.formatAmount(widget.loan.remainingInterest),
              color: Colors.amber.shade800,
            ),
            const Divider(height: 16),
            _buildInfoRow(
              'Tổng dư nợ cần thanh toán',
              CurrencyFormatter.formatAmount(widget.loan.totalDebtAmount),
              color: Colors.orange,
              isBold: true,
            ),
          ] else ...[
            const SizedBox(height: 8),
            _buildInfoRow(
              'Còn lại',
              CurrencyFormatter.formatAmount(widget.loan.remainingAmount),
              color: Colors.orange,
              isBold: true,
            ),
          ],
          // Show USD equivalent if in USD mode
          if (isUsd) ...[
            const SizedBox(height: 4),
            Text(
              '≈ ${currencyProvider.convertFromVND(_maxPayable).toStringAsFixed(2)} USD cần trả',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange[700],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: widget.loan.paymentProgress / 100,
              minHeight: 8,
              backgroundColor: Colors.grey.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(loanColor),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Đã hoàn thành ${widget.loan.paymentProgress.toStringAsFixed(1)}%',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? color, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildAmountInput(ColorScheme colorScheme) {
    final currencyProvider = Provider.of<CurrencyProvider>(context);
    final currencySymbol = currencyProvider.currencySymbol;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Số tiền thanh toán',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            hintText: 'Nhập số tiền ($currencySymbol)',
            suffixText: currencySymbol,
            suffixStyle: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
            prefixIcon: const Icon(Icons.attach_money, size: 28),
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: colorScheme.primary,
                width: 2,
              ),
            ),
          ),
          inputFormatters: [
            CurrencyInputFormatter(),
            LengthLimitingTextInputFormatter(20), // Increased to accommodate formatted text
          ],
          onChanged: _onAmountChanged,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Vui lòng nhập số tiền';
            }
            return null;
          },
        ),
        // Helper text for currency conversion
        if (currencyProvider.selectedCurrency == 'USD') ...[
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 12.0),
            child: Text(
              'Sẽ được chuyển đổi thành VND khi lưu (tỷ giá: 1 USD = ${currencyProvider.exchangeRate.toStringAsFixed(0)} VND)',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
        _buildAllocationPreview(colorScheme),
      ],
    );
  }

  Widget _buildAllocationPreview(ColorScheme colorScheme) {
    if (!widget.loan.hasInterest || _paymentAmount == null || _paymentAmount! <= 0) {
      return const SizedBox.shrink();
    }

    final allocation = LoanInterestService().previewPaymentAllocation(
      loan: widget.loan,
      paymentAmount: _paymentAmount!,
    );

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pie_chart_outline, size: 16, color: Colors.amber),
              const SizedBox(width: 6),
              Text(
                'Phân bổ thanh toán:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('• Trừ vào lãi:', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
              Text(
                CurrencyFormatter.formatAmount(allocation['interestPaid']!),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('• Trừ vào gốc:', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
              Text(
                CurrencyFormatter.formatAmount(allocation['principalPaid']!),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4CAF50)),
              ),
            ],
          ),
          const Divider(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Nợ gốc còn lại:', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
              Text(
                CurrencyFormatter.formatAmount(allocation['remainingPrincipalAfter']!),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
              ),
            ],
          ),
          if (allocation['remainingInterestAfter']! > 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Lãi còn lại:', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                Text(
                  CurrencyFormatter.formatAmount(allocation['remainingInterestAfter']!),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.orange),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildQuickAmountButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _setHalfAmount,
            icon: const Icon(Icons.exposure_plus_1),
            label: const Text('50%'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _setFullAmount,
            icon: const Icon(Icons.done_all),
            label: const Text('Toàn bộ'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionInput(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ghi chú (tùy chọn)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _descriptionController,
          maxLines: 3,
          maxLength: 80,
          decoration: InputDecoration(
            hintText: 'Nhập ghi chú...',
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: colorScheme.primary,
                width: 2,
              ),
            ),
            counterText: ''
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(Color loanColor) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _submitPayment,
        style: ElevatedButton.styleFrom(
          backgroundColor: loanColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: const Text(
          'Xác nhận thanh toán',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

