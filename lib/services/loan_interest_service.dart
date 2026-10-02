import 'dart:developer';
import 'dart:math' as math;
import '../database/database_helper.dart';
import '../models/loan.dart';
import '../models/loan_payment.dart';

/// Dịch vụ tính toán và đồng bộ lãi suất cho các khoản vay mượn
class LoanInterestService {
  static final LoanInterestService _instance = LoanInterestService._internal();
  factory LoanInterestService() => _instance;
  LoanInterestService._internal();

  final DatabaseHelper _db = DatabaseHelper();

  /// Làm tròn số tiền về hàng nghìn (1.000 VND) theo chuẩn tiền tệ Việt Nam
  double roundToVndThousand(num amount) {
    if (amount <= 0) return 0.0;
    final rounded = (amount / 1000.0).round() * 1000.0;
    return rounded > 0 ? rounded : 1000.0;
  }

  /// Tính toán số tiền lãi phát sinh mỗi ngày
  /// [principal]: Số nợ gốc hiện tại đang tính lãi
  /// [rate]: Mức lãi suất
  /// [rateType]: Đơn vị lãi ('vnd_per_million_per_day', 'percent_per_month', 'percent_per_year', 'percent_per_day')
  double calculateDailyInterest({
    required double principal,
    required double rate,
    required String rateType,
  }) {
    if (principal <= 0 || rate <= 0) return 0.0;

    switch (rateType) {
      case 'vnd_per_million_per_day':
        // Ví dụ: 2.000đ / 1 triệu / ngày
        return (principal / 1000000.0) * rate;

      case 'percent_per_month':
        // Ví dụ: 1.5% / tháng (chuẩn 30 ngày/tháng)
        return principal * (rate / 100.0) / 30.0;

      case 'percent_per_year':
        // Ví dụ: 12% / năm (chuẩn 365 ngày/năm)
        return principal * (rate / 100.0) / 365.0;

      case 'percent_per_day':
        // Ví dụ: 0.1% / ngày
        return principal * (rate / 100.0);

      default:
        return principal * (rate / 100.0) / 30.0;
    }
  }

  /// Đồng bộ tính lại lãi suất cho tất cả các khoản vay đang hoạt động hoặc quá hạn
  /// Được gọi tự động mỗi khi người dùng mở lại ứng dụng (Lifecycle Resumed & App Startup)
  Future<int> syncAllActiveLoansInterest({DateTime? currentDate}) async {
    final now = currentDate ?? DateTime.now();
    int updatedCount = 0;

    try {
      final db = await _db.database;

      // Lấy tất cả các khoản vay có tính lãi suất và chưa thanh toán xong
      final loanMaps = await db.query(
        'loans',
        where: 'hasInterest = 1 AND status IN (?, ?)',
        whereArgs: ['active', 'overdue'],
      );

      if (loanMaps.isEmpty) {
        log('ℹ️ Không có khoản vay nào cần tính lại lãi');
        return 0;
      }

      for (final map in loanMaps) {
        final loan = Loan.fromMap(map);
        final updated = await recalculateLoanInterest(loan, now: now);
        if (updated) updatedCount++;
      }

      log('✅ Đã đồng bộ lãi suất thành công cho $updatedCount/${loanMaps.length} khoản vay');
      return updatedCount;
    } catch (e) {
      log('❌ Lỗi khi đồng bộ lãi suất khoản vay: $e');
      return 0;
    }
  }

  /// Tính toán và cập nhật lãi cho một khoản vay cụ thể
  Future<bool> recalculateLoanInterest(Loan loan, {DateTime? now}) async {
    if (!loan.hasInterest || loan.isPaid) return false;

    final currentTime = now ?? DateTime.now();
    final db = await _db.database;

    // Mốc bắt đầu tính lãi: Lần tính cuối hoặc ngày tạo khoản vay
    final lastCalc = loan.lastInterestCalculatedDate ?? loan.loanDate;

    // Tính số ngày chênh lệch
    final diffSeconds = currentTime.difference(lastCalc).inSeconds;
    if (diffSeconds < 60) {
      // Chưa qua ít nhất 1 phút, không cần tính lại
      return false;
    }

    final diffDays = diffSeconds / 86400.0;
    final remainingPrincipal = loan.remainingPrincipal;
    if (remainingPrincipal <= 0) return false;

    // Kiểm tra quá hạn
    bool isOverdue = false;
    double overdueMultiplier = 1.0;
    if (loan.dueDate != null && currentTime.isAfter(loan.dueDate!)) {
      isOverdue = true;
      overdueMultiplier = loan.overdueInterestMultiplier > 0 ? loan.overdueInterestMultiplier : 1.0;
    }

    // Tính lãi suất cơ bản 1 ngày
    final dailyInterest = calculateDailyInterest(
      principal: remainingPrincipal,
      rate: loan.interestRate,
      rateType: loan.interestRateType,
    );

    // Tính tiền lãi phát sinh trong khoảng diffDays
    final rawNewInterest = dailyInterest * diffDays * overdueMultiplier;
    if (rawNewInterest <= 0) return false;

    // Lãi lũy kế mới
    final newAccruedInterest = loan.accruedInterest + rawNewInterest;

    // Làm tròn lãi lũy kế về hàng nghìn VND
    final roundedAccruedInterest = roundToVndThousand(newAccruedInterest);

    final newStatus = isOverdue ? 'overdue' : loan.status;

    // Cập nhật DB
    await db.update(
      'loans',
      {
        'accruedInterest': roundedAccruedInterest,
        'lastInterestCalculatedDate': currentTime.toIso8601String(),
        'status': newStatus,
        'updatedAt': currentTime.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [loan.id],
    );

    log('📈 Đã cập nhật lãi khoản vay ID ${loan.id} (${loan.personName}): +${rawNewInterest.toStringAsFixed(0)}đ -> Lãi tích lũy: ${roundedAccruedInterest.toStringAsFixed(0)}đ');
    return true;
  }

  /// Lấy lịch sử các lần thanh toán nợ của một khoản vay
  Future<List<LoanPayment>> getPaymentHistory(int loanId) async {
    try {
      final db = await _db.database;
      final maps = await db.query(
        'loan_payments',
        where: 'loanId = ?',
        whereArgs: [loanId],
        orderBy: 'paymentDate DESC, id DESC',
      );
      return maps.map((m) => LoanPayment.fromMap(m)).toList();
    } catch (e) {
      log('Lỗi lấy lịch sử thanh toán: $e');
      return [];
    }
  }

  /// Xem trước phân bổ tiền thanh toán: Bao nhiêu trả lãi, bao nhiêu trả gốc
  Map<String, double> previewPaymentAllocation({
    required Loan loan,
    required double paymentAmount,
  }) {
    if (paymentAmount <= 0) {
      return {
        'interestPaid': 0.0,
        'principalPaid': 0.0,
        'remainingInterestAfter': loan.remainingInterest,
        'remainingPrincipalAfter': loan.remainingPrincipal,
      };
    }

    if (!loan.hasInterest) {
      final principalPaid = paymentAmount.clamp(0.0, loan.remainingPrincipal);
      return {
        'interestPaid': 0.0,
        'principalPaid': principalPaid,
        'remainingInterestAfter': 0.0,
        'remainingPrincipalAfter': loan.remainingPrincipal - principalPaid,
      };
    }

    // Ưu tiên 1: Cấn trừ tiền lãi trước
    final unpaidInterest = loan.remainingInterest;
    final interestPaid = math.min(unpaidInterest, paymentAmount);

    // Ưu tiên 2: Tiền còn lại trừ vào nợ gốc
    final remainingForPrincipal = paymentAmount - interestPaid;
    final principalPaid = math.min(loan.remainingPrincipal, remainingForPrincipal);

    return {
      'interestPaid': interestPaid,
      'principalPaid': principalPaid,
      'remainingInterestAfter': unpaidInterest - interestPaid,
      'remainingPrincipalAfter': loan.remainingPrincipal - principalPaid,
    };
  }
}
