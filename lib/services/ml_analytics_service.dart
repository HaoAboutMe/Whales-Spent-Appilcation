import 'dart:developer';
import 'dart:math' as math;
import '../database/repositories/repositories.dart';
import '../models/transaction.dart';
import '../models/ml_prediction.dart';

/// Service xử lý các thuật toán Machine Learning nhẹ cho phân tích chi tiêu
class MLAnalyticsService {
  final TransactionRepository _transactionRepo = TransactionRepository();
  final CategoryRepository _categoryRepo = CategoryRepository();
  final BudgetRepository _budgetRepo = BudgetRepository();

  // ==================== DỰ ĐOÁN CHI TIÊU ====================

  /// Dự đoán chi tiêu tháng tới sử dụng kết hợp Weighted Moving Average và Linear Trend
  Future<SpendingPrediction> predictNextMonthSpending({
    required DateTime currentMonth,
    int monthsToAnalyze = 6,
  }) async {
    try {
      final now = DateTime.now();
      final totalDaysInCurrentMonth = DateTime(currentMonth.year, currentMonth.month + 1, 0).day;

      // Tính số ngày đã trôi qua trong tháng khảo sát
      final isCurrentCalendarMonth = (now.year == currentMonth.year && now.month == currentMonth.month);
      final daysElapsed = isCurrentCalendarMonth
          ? math.max(1, math.min(now.day, totalDaysInCurrentMonth))
          : totalDaysInCurrentMonth;

      // 1. Lấy chi tiêu thực tế đã phát sinh trong tháng hiện tại tính đến nay
      final currentMonthStart = DateTime(currentMonth.year, currentMonth.month, 1);
      final currentMonthEnd = DateTime(currentMonth.year, currentMonth.month + 1, 0, 23, 59, 59);
      final currentMonthTxs = await _transactionRepo.getTransactionsByDateRange(currentMonthStart, currentMonthEnd);
      final currentMonthSpentSoFar = currentMonthTxs
          .where((t) => t.type == 'expense')
          .fold(0.0, (sum, t) => sum + t.amount);

      // Dự phóng chi tiêu hết tháng hiện tại (Current Month Run-rate Projection)
      final currentMonthDailyAvg = daysElapsed > 0 ? (currentMonthSpentSoFar / daysElapsed) : 0.0;
      final rawCurrentMonthProjected = isCurrentCalendarMonth
          ? (currentMonthDailyAvg * totalDaysInCurrentMonth)
          : currentMonthSpentSoFar;
      final currentMonthProjected = _roundToVndThousand(rawCurrentMonthProjected);

      // 2. Lấy dữ liệu các tháng trước ĐÃ HOÀN CHỈNH (không gom tháng dở dang vào chuỗi quá khứ)
      final completedHistory = await _getCompletedMonthlySpendingHistory(
        currentMonth: currentMonth,
        monthsBack: monthsToAnalyze,
      );

      final nextMonth = DateTime(currentMonth.year, currentMonth.month + 1);

      // Trường hợp 1: Không có dữ liệu lịch sử và tháng này cũng chưa chi gì
      if (completedHistory.isEmpty && currentMonthSpentSoFar == 0) {
        return SpendingPrediction(
          month: _formatMonth(nextMonth),
          predictedAmount: 0,
          confidence: 0,
          trend: 'stable',
          changeRate: 0,
          lowerBound: 0,
          upperBound: 0,
          currentMonthProjected: 0,
          currentMonthSpentSoFar: 0,
          daysElapsedInCurrentMonth: daysElapsed,
          totalDaysInCurrentMonth: totalDaysInCurrentMonth,
        );
      }

      // Trường hợp 2: Người dùng mới (chưa có tháng hoàn chỉnh trước đó, chỉ có tháng này)
      if (completedHistory.isEmpty) {
        final predicted = _roundToVndThousand(currentMonthProjected);
        final confidence = (daysElapsed / totalDaysInCurrentMonth * 0.5).clamp(0.2, 0.5);
        final margin = predicted * 0.25;

        return SpendingPrediction(
          month: _formatMonth(nextMonth),
          predictedAmount: predicted,
          confidence: confidence,
          trend: 'stable',
          changeRate: 0,
          lowerBound: _roundToVndThousand(math.max(0, predicted - margin)),
          upperBound: _roundToVndThousand(predicted + margin),
          currentMonthProjected: currentMonthProjected,
          currentMonthSpentSoFar: currentMonthSpentSoFar,
          daysElapsedInCurrentMonth: daysElapsed,
          totalDaysInCurrentMonth: totalDaysInCurrentMonth,
        );
      }

      // Trường hợp 3: Có các tháng hoàn chỉnh trong quá khứ
      final pastAmounts = completedHistory.map((e) => e['amount'] as double).toList();

      // Tính Weighted Moving Average trên các tháng đã hoàn chỉnh (trọng số tăng dần về tháng gần nhất)
      double wma = 0.0;
      int weightSum = 0;
      for (int i = 0; i < pastAmounts.length; i++) {
        final weight = i + 1; // 1, 2, 3...
        wma += pastAmounts[i] * weight;
        weightSum += weight;
      }
      wma = weightSum > 0 ? (wma / weightSum) : pastAmounts.last;

      // Tính xu hướng Linear Trend trên toàn bộ chuỗi (kèm run-rate tháng này)
      final allSeries = [...pastAmounts, currentMonthProjected];
      final linearPrediction = _computeLinearForecast(allSeries);

      // Kết hợp WMA và Linear Trend: 65% WMA + 35% Linear Forecast để tránh biến động sốc
      double rawPrediction = (0.65 * wma + 0.35 * linearPrediction);
      if (rawPrediction < 0) rawPrediction = wma;
      final prediction = _roundToVndThousand(rawPrediction);

      // Tính xu hướng (trend) và tốc độ thay đổi so với dự phóng tháng này
      final baselineCompare = currentMonthProjected > 0 ? currentMonthProjected : wma;
      final changeRate = baselineCompare > 0 ? ((prediction - baselineCompare) / baselineCompare) * 100 : 0.0;

      String trend = 'stable';
      if (changeRate > 5.0) {
        trend = 'increasing';
      } else if (changeRate < -5.0) {
        trend = 'decreasing';
      }

      // Tính độ tin cậy dựa trên tính ổn định và số lượng dữ liệu
      final confidence = _calculateConfidence(allSeries);

      // Tính dải dao động kỳ vọng (Confidence Interval)
      final uncertainty = (1.0 - confidence).clamp(0.1, 0.4);
      final rawLower = math.max(0.0, prediction * (1.0 - uncertainty * 0.7));
      final rawUpper = prediction * (1.0 + uncertainty * 0.7);
      final lowerBound = _roundToVndThousand(rawLower);
      final upperBound = _roundToVndThousand(rawUpper);

      return SpendingPrediction(
        month: _formatMonth(nextMonth),
        predictedAmount: prediction,
        confidence: confidence,
        trend: trend,
        changeRate: changeRate,
        lowerBound: lowerBound,
        upperBound: upperBound,
        currentMonthProjected: currentMonthProjected,
        currentMonthSpentSoFar: currentMonthSpentSoFar,
        daysElapsedInCurrentMonth: daysElapsed,
        totalDaysInCurrentMonth: totalDaysInCurrentMonth,
      );
    } catch (e) {
      log('Lỗi dự đoán chi tiêu: $e');
      rethrow;
    }
  }

  /// Tính dự báo tuyến tính an toàn chống chia cho 0
  double _computeLinearForecast(List<double> y) {
    final n = y.length;
    if (n < 2) return y.isNotEmpty ? y.last : 0.0;

    final x = List.generate(n, (i) => i.toDouble());
    final sumX = x.reduce((a, b) => a + b);
    final sumY = y.reduce((a, b) => a + b);
    final sumXY = List.generate(n, (i) => x[i] * y[i]).reduce((a, b) => a + b);
    final sumX2 = x.map((e) => e * e).reduce((a, b) => a + b);

    final denom = n * sumX2 - sumX * sumX;
    if (denom.abs() < 1e-6) {
      return sumY / n;
    }

    final slope = (n * sumXY - sumX * sumY) / denom;
    final intercept = (sumY - slope * sumX) / n;

    final forecast = slope * n.toDouble() + intercept;
    return math.max(0.0, forecast);
  }

  /// Tính độ tin cậy của dự đoán
  double _calculateConfidence(List<double> amounts) {
    if (amounts.length < 2) return 0.4;

    final mean = amounts.reduce((a, b) => a + b) / amounts.length;
    if (mean <= 0) return 0.3;

    final variance = amounts.map((e) => math.pow(e - mean, 2)).reduce((a, b) => a + b) / amounts.length;
    final stdDev = math.sqrt(variance);

    // Coefficient of Variation
    final cv = stdDev / mean;

    // Nhiều dữ liệu thì tăng thêm độ tin cậy
    final dataPointsBonus = math.min(0.2, (amounts.length - 2) * 0.05);

    // Độ tin cậy cao khi CV thấp (dữ liệu ổn định)
    final baseConfidence = (1.0 - math.min(0.7, cv * 0.8)).clamp(0.35, 0.85);

    return (baseConfidence + dataPointsBonus).clamp(0.3, 0.95);
  }

  /// Lấy lịch sử chi tiêu các tháng trước ĐÃ HOÀN CHỈNH
  Future<List<Map<String, dynamic>>> _getCompletedMonthlySpendingHistory({
    required DateTime currentMonth,
    required int monthsBack,
  }) async {
    final results = <Map<String, dynamic>>[];

    for (var i = monthsBack; i >= 1; i--) {
      final targetMonth = DateTime(currentMonth.year, currentMonth.month - i);
      final startDate = DateTime(targetMonth.year, targetMonth.month, 1);
      final endDate = DateTime(targetMonth.year, targetMonth.month + 1, 0, 23, 59, 59);

      final transactions = await _transactionRepo.getTransactionsByDateRange(startDate, endDate);

      final totalExpense = transactions
          .where((t) => t.type == 'expense')
          .fold(0.0, (sum, t) => sum + t.amount);

      results.add({
        'month': targetMonth,
        'amount': totalExpense,
      });
    }

    // Không cắt ngắn tháng 0đ nếu nằm giữa khoảng thời gian có giao dịch,
    // chỉ lọc bỏ các tháng phía trước khi tài khoản chưa từng có bất kỳ giao dịch nào.
    final allTxs = await _transactionRepo.getAllTransactions();
    if (allTxs.isEmpty) return [];

    final earliestDate = allTxs.map((t) => t.date).reduce((a, b) => a.isBefore(b) ? a : b);
    final earliestMonth = DateTime(earliestDate.year, earliestDate.month);

    return results.where((e) {
      final m = e['month'] as DateTime;
      return !m.isBefore(earliestMonth);
    }).toList();
  }

  // ==================== PHÂN TÍCH THÓI QUEN ====================

  /// Phân tích thói quen chi tiêu
  Future<SpendingHabit> analyzeSpendingHabits({
    required DateTime currentMonth,
  }) async {
    final startDate = DateTime(currentMonth.year, currentMonth.month, 1);
    final endDate = DateTime(currentMonth.year, currentMonth.month + 1, 0, 23, 59, 59);

    final transactions = await _transactionRepo.getTransactionsByDateRange(startDate, endDate);
    final expenses = transactions.where((t) => t.type == 'expense').toList();
    final incomes = transactions.where((t) => t.type == 'income').toList();
    final totalIncome = incomes.fold(0.0, (sum, t) => sum + t.amount);

    if (expenses.isEmpty) {
      return const SpendingHabit(
        topSpendingDays: ['Chưa có dữ liệu'],
        topCategories: [],
        preferredTime: 'Chưa có dữ liệu',
        avgDailySpending: 0,
        spendingStyle: 'Chưa xác định',
      );
    }

    // ===== PHÂN TÍCH NGÀY CHI TIÊU NHIỀU NHẤT (Lấy nhiều ngày nếu gần bằng nhau) =====
    final daySpending = <String, double>{};
    for (var expense in expenses) {
      final dayName = _getDayName(expense.date.weekday);
      daySpending[dayName] = (daySpending[dayName] ?? 0) + expense.amount;
    }

    final topSpendingDays = <String>[];
    if (daySpending.isNotEmpty) {
      // Tìm ngày chi tiêu cao nhất
      final maxSpending = daySpending.values.reduce(math.max);
      final threshold = maxSpending * 0.9; // Lấy các ngày >= 90% mức cao nhất

      // Lấy tất cả ngày có chi tiêu >= threshold
      topSpendingDays.addAll(
          daySpending.entries
              .where((e) => e.value >= threshold)
              .map((e) => e.key)
              .toList()
      );
    }

    if (topSpendingDays.isEmpty) {
      topSpendingDays.add('Chưa xác định');
    }

    // ===== PHÂN TÍCH DANH MỤC CHI TIÊU HÀNG ĐẦU (Top 2-3 categories) =====
    final categorySpending = <int, double>{};
    for (var expense in expenses) {
      if (expense.categoryId != null) {
        categorySpending[expense.categoryId!] =
            (categorySpending[expense.categoryId!] ?? 0) + expense.amount;
      }
    }

    final totalSpending = expenses.fold(0.0, (sum, e) => sum + e.amount);
    final topCategories = <TopCategoryInfo>[];

    if (categorySpending.isNotEmpty) {
      // Sắp xếp theo số tiền giảm dần
      final sortedCategories = categorySpending.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // Lấy top 3 hoặc các danh mục có giá trị >= 10% tổng chi tiêu
      final minThreshold = totalSpending * 0.1; // Ít nhất 10% tổng chi
      var count = 0;

      for (var entry in sortedCategories) {
        if (count >= 3 && entry.value < minThreshold) break; // Tối đa 3, trừ khi có nhiều hơn đạt 10%

        final category = await _categoryRepo.getCategoryById(entry.key);
        if (category != null) {
          final percentage = (entry.value / totalSpending) * 100;

          // Tạo màu sắc động dựa trên tên danh mục
          final color = _generateCategoryColor(category.name);

          topCategories.add(TopCategoryInfo(
            name: category.name,
            icon: category.icon,
            color: color,
            percentage: percentage,
            amount: entry.value,
          ));

          count++;
          if (count >= 3) break; // Giới hạn tối đa 3 danh mục
        }
      }
    }

    // ===== PHÂN TÍCH THỜI GIAN TRONG NGÀY =====
    final timeSpending = <String, double>{};
    for (var expense in expenses) {
      final period = _getTimePeriod(expense.date.hour);
      timeSpending[period] = (timeSpending[period] ?? 0) + expense.amount;
    }

    final preferredTime = timeSpending.isNotEmpty
        ? timeSpending.entries.reduce((a, b) => a.value > b.value ? a : b).key
        : 'Chưa xác định';

    // ===== TÍNH CHI TIÊU TRUNG BÌNH HÀNG NGÀY =====
    final daysInMonth = DateTime(currentMonth.year, currentMonth.month + 1, 0).day;
    final avgDailySpending = totalSpending / daysInMonth;

    // ===== XÁC ĐỊNH PHONG CÁCH CHI TIÊU =====
    final spendingStyle = _determineSpendingStyle(expenses, totalIncome, currentMonth);

    return SpendingHabit(
      topSpendingDays: topSpendingDays,
      topCategories: topCategories,
      preferredTime: preferredTime,
      avgDailySpending: avgDailySpending,
      spendingStyle: spendingStyle,
    );
  }

  /// Xác định phong cách chi tiêu dựa trên tỷ lệ chi tiêu/thu nhập hoặc mức độ chi tiêu
  String _determineSpendingStyle(List<Transaction> expenses, double totalIncome, DateTime month) {
    if (expenses.isEmpty) return 'Chưa xác định';

    final totalSpending = expenses.fold(0.0, (sum, e) => sum + e.amount);

    if (totalIncome > 0) {
      final ratio = totalSpending / totalIncome;
      if (ratio < 0.6) {
        return 'Tiết kiệm';
      } else if (ratio > 0.85) {
        return 'Thoải mái';
      } else {
        return 'Cân đối';
      }
    }

    // Nếu chưa ghi nhận thu nhập: phân loại dựa trên tần suất giao dịch
    if (expenses.length <= 15) {
      return 'Tiết kiệm';
    } else if (expenses.length >= 45) {
      return 'Thoải mái';
    } else {
      return 'Cân đối';
    }
  }

  // ==================== CẢNH BÁO NGÂN SÁCH ====================

  /// Phát hiện cảnh báo vượt ngân sách
  Future<List<BudgetAlert>> detectBudgetAlerts({
    required DateTime currentMonth,
  }) async {
    final alerts = <BudgetAlert>[];
    final now = DateTime.now();

    // ===== 1. KIỂM TRA NGÂN SÁCH TỔNG (Overall Budget) =====
    try {
      final overallProgress = await _budgetRepo.getOverallBudgetProgress();
      log('📊 Overall Budget Progress: $overallProgress');

      // Chỉ kiểm tra nếu ngân sách tổng chưa hết hạn
      if (overallProgress != null && (overallProgress['isExpired'] != true)) {
        final budgetAmount = (overallProgress['budgetAmount'] as num).toDouble();
        final spent = (overallProgress['totalSpent'] as num).toDouble();

        // Lấy ngày bắt đầu và kết thúc từ ngân sách
        final startDate = DateTime.parse(overallProgress['startDate'] as String);
        final endDate = DateTime.parse(overallProgress['endDate'] as String);

        // Tính số ngày dựa trên khoảng thời gian thực của ngân sách
        final totalDays = endDate.difference(startDate).inDays + 1;
        final daysElapsed = now.difference(startDate).inDays + 1;
        final timeElapsedPercentage = (daysElapsed / totalDays) * 100;

        log('💰 Ngân sách tổng: ${budgetAmount.toStringAsFixed(0)} VND');
        log('💸 Đã chi: ${spent.toStringAsFixed(0)} VND');
        log('📅 Thời gian: ${startDate.day}/${startDate.month} - ${endDate.day}/${endDate.month} ($totalDays ngày)');
        log('📆 Đã qua: $daysElapsed/$totalDays ngày (${timeElapsedPercentage.toStringAsFixed(1)}%)');

        if (budgetAmount > 0) {
          // Tính % đã sử dụng
          final usedPercentage = (spent / budgetAmount) * 100;

          // Tính tốc độ chi tiêu
          final expectedUsage = timeElapsedPercentage;
          final spendingRate = expectedUsage > 0 ? usedPercentage / expectedUsage : 0.0;

          // Dự đoán số tiền vượt nếu tiếp tục chi tiêu
          final projectedTotal = daysElapsed > 0 ? (spent / daysElapsed) * totalDays : spent;
          final projectedOverage = math.max(0.0, projectedTotal - budgetAmount);

          // Xác định mức độ nghiêm trọng (giảm ngưỡng để dễ cảnh báo hơn)
          String severity;
          if (usedPercentage >= 100) {
            severity = 'high';
          } else if (usedPercentage >= 90) {
            severity = 'high';
          } else if (spendingRate >= 1.5 && usedPercentage >= 40) {
            severity = 'high';
          } else if (spendingRate >= 1.3 && usedPercentage >= 30) {
            severity = 'medium';
          } else if (usedPercentage >= 70) {
            severity = 'medium';
          } else if (spendingRate >= 1.1) {
            severity = 'medium';
          } else if (usedPercentage >= 50) {
            severity = 'low';
          } else {
            severity = 'low'; // Luôn hiển thị để người dùng theo dõi
          }

          log('⚠️ Thêm cảnh báo ngân sách tổng: severity=$severity, used=$usedPercentage%');

          alerts.add(BudgetAlert(
            categoryName: '💰 Ngân sách tổng', // Đánh dấu đặc biệt
            usedPercentage: usedPercentage,
            daysElapsed: daysElapsed,
            totalDays: totalDays,
            timeElapsedPercentage: timeElapsedPercentage,
            spendingRate: spendingRate,
            projectedOverage: projectedOverage,
            severity: severity,
            budgetAmount: budgetAmount,
            spentAmount: spent,
          ));
        }
      } else if (overallProgress != null && overallProgress['isExpired'] == true) {
        log('⏭️ Bỏ qua ngân sách tổng đã hết hạn');
      } else {
        log('⚠️ Không tìm thấy ngân sách tổng đang hoạt động');
      }
    } catch (e) {
      log('❌ Lỗi kiểm tra ngân sách tổng: $e');
    }

    // ===== 2. KIỂM TRA NGÂN SÁCH THEO DANH MỤC =====
    try {
      final budgetProgress = await _budgetRepo.getBudgetProgress();

      for (var item in budgetProgress) {
        // Bỏ qua ngân sách đã hết hạn
        if (item['isExpired'] == true) {
          log('⏭️ Bỏ qua ngân sách hết hạn: ${item['categoryName']}');
          continue;
        }

        final budgetAmount = (item['budgetAmount'] as num).toDouble();
        final spent = (item['totalSpent'] as num).toDouble();
        final categoryName = item['categoryName'] as String? ?? 'Tổng chi tiêu';

        if (budgetAmount <= 0) continue;

        // Lấy ngày bắt đầu và kết thúc từ ngân sách
        final startDate = DateTime.parse(item['startDate'] as String);
        final endDate = DateTime.parse(item['endDate'] as String);

        // Tính số ngày dựa trên khoảng thời gian thực của ngân sách
        final totalDays = endDate.difference(startDate).inDays + 1;
        final daysElapsed = now.difference(startDate).inDays + 1;
        final timeElapsedPercentage = (daysElapsed / totalDays) * 100;

        // Tính % đã sử dụng
        final usedPercentage = (spent / budgetAmount) * 100;

        // Tính tốc độ chi tiêu
        final expectedUsage = timeElapsedPercentage;
        final spendingRate = expectedUsage > 0 ? usedPercentage / expectedUsage : 0.0;

        // Dự đoán số tiền vượt nếu tiếp tục chi tiêu
        final dailyAverage = daysElapsed > 0 ? (spent / daysElapsed) : 0.0;
        final projectedTotal = _roundToVndThousand(dailyAverage * totalDays);
        final projectedOverage = _roundToVndThousand(math.max(0.0, projectedTotal - budgetAmount));

        log('📋 [$categoryName] Budget: ${budgetAmount.toStringAsFixed(0)}, Spent: ${spent.toStringAsFixed(0)}');
        log('📅 Thời gian: ${startDate.day}/${startDate.month} - ${endDate.day}/${endDate.month} ($totalDays ngày)');
        log('📆 Ngày đã qua: $daysElapsed/$totalDays ngày (${timeElapsedPercentage.toStringAsFixed(1)}%)');
        log('💸 Chi TB/ngày: ${dailyAverage.toStringAsFixed(0)} VND');
        log('🔮 Dự đoán cuối kỳ: ${projectedTotal.toStringAsFixed(0)} VND');
        log('⚠️ Dự kiến vượt: ${projectedOverage.toStringAsFixed(0)} VND');

        // ===== LUÔN HIỂN THỊ TẤT CẢ NGÂN SÁCH, CHỈ PHÂN LOẠI MÀU =====
        String severity;

        // ĐỎ (high) - Nguy hiểm
        if (usedPercentage >= 100) {
          severity = 'high'; // Đã vượt ngân sách
        } else if (usedPercentage >= 90) {
          severity = 'high'; // Sắp hết (≥90%)
        } else if (spendingRate >= 1.5 && usedPercentage >= 40) {
          severity = 'high'; // Chi nhanh gấp 1.5x và đã dùng ≥40%
        }
        // CAM (medium) - Cảnh báo
        else if (usedPercentage >= 70) {
          severity = 'medium'; // Đã dùng ≥70%
        } else if (spendingRate >= 1.3) {
          severity = 'medium'; // Chi nhanh gấp 1.3x
        } else if (projectedOverage > 0) {
          severity = 'medium'; // Có dự kiến vượt
        }
        // XANH (low) - An toàn
        else {
          severity = 'low'; // Còn an toàn
        }

        log('✅ Thêm ngân sách [$categoryName]: severity=$severity, used=${usedPercentage.toStringAsFixed(1)}%');

        alerts.add(BudgetAlert(
          categoryName: categoryName,
          usedPercentage: usedPercentage,
          daysElapsed: daysElapsed,
          totalDays: totalDays,
          timeElapsedPercentage: timeElapsedPercentage,
          spendingRate: spendingRate,
          projectedOverage: projectedOverage,
          severity: severity,
          budgetAmount: budgetAmount,
          spentAmount: spent,
        ));
      }
    } catch (e) {
      log('Lỗi kiểm tra ngân sách từ bảng budgets: $e');
    }

    // ===== KIỂM TRA HẠN MỨC TỪ CATEGORIES (Backup) =====
    try {
      final categories = await _categoryRepo.getAllCategories();
      final startDate = DateTime(currentMonth.year, currentMonth.month, 1);
      final endDate = DateTime(currentMonth.year, currentMonth.month + 1, 0, 23, 59, 59);

      // Tính số ngày trong tháng cho phần backup này
      final daysInMonth = DateTime(currentMonth.year, currentMonth.month + 1, 0).day;
      final daysElapsed = now.day;
      final timeElapsedPercentage = (daysElapsed / daysInMonth) * 100;

      for (var category in categories) {
        if (category.type != 'expense' || category.budget == null || category.budget! <= 0) {
          continue;
        }

        // Kiểm tra xem category này đã có trong alerts từ budgets chưa
        final existingAlert = alerts.any((alert) => alert.categoryName == category.name);
        if (existingAlert) continue; // Skip nếu đã có từ budgets

        // Lấy chi tiêu của danh mục này trong tháng
        final transactions = await _transactionRepo.getTransactionsByDateRange(startDate, endDate);
        final categorySpending = transactions
            .where((t) => t.type == 'expense' && t.categoryId == category.id)
            .fold(0.0, (sum, t) => sum + t.amount);

        final budget = (category.budget! as num).toDouble();
        final usedPercentage = (categorySpending / budget) * 100;

        // Tính tốc độ chi tiêu
        final expectedUsage = timeElapsedPercentage;
        final spendingRate = expectedUsage > 0 ? usedPercentage / expectedUsage : 0.0;

        // Dự đoán số tiền vượt nếu tiếp tục chi tiêu
        final rawProjectedTotal = daysElapsed > 0 ? (categorySpending / daysElapsed) * daysInMonth : categorySpending;
        final projectedTotal = _roundToVndThousand(rawProjectedTotal);
        final projectedOverage = _roundToVndThousand(math.max(0.0, projectedTotal - budget));

        // Tạo cảnh báo nếu vượt hoặc có nguy cơ vượt
        String? severity;
        if (usedPercentage >= 100) {
          severity = 'high';
        } else if (spendingRate >= 1.5 && usedPercentage >= 50) {
          severity = 'high';
        } else if (spendingRate >= 1.2 && usedPercentage >= 40) {
          severity = 'medium';
        } else if (spendingRate >= 1.1 && usedPercentage >= 60) {
          severity = 'medium';
        }

        if (severity != null) {
          alerts.add(BudgetAlert(
            categoryName: category.name,
            usedPercentage: usedPercentage,
            daysElapsed: daysElapsed,
            totalDays: daysInMonth,
            timeElapsedPercentage: timeElapsedPercentage,
            spendingRate: spendingRate,
            projectedOverage: projectedOverage,
            severity: severity,
            budgetAmount: budget,
            spentAmount: categorySpending,
          ));
        }
      }
    } catch (e) {
      log('Lỗi kiểm tra hạn mức từ categories: $e');
    }

    // Sắp xếp theo mức độ nghiêm trọng
    alerts.sort((a, b) {
      final severityOrder = {'high': 0, 'medium': 1, 'low': 2};
      return severityOrder[a.severity]!.compareTo(severityOrder[b.severity]!);
    });

    return alerts;
  }

  // ==================== GỢI Ý NGÂN SÁCH ====================

  /// Đề xuất ngân sách hợp lý cho tháng mới
  Future<List<BudgetSuggestion>> suggestBudgets({
    required DateTime currentMonth,
  }) async {
    final suggestions = <BudgetSuggestion>[];

    final categories = await _categoryRepo.getAllCategories();

    for (var category in categories) {
      if (category.type != 'expense') continue;

      // Tính chi tiêu trung bình 3 tháng gần nhất
      final monthlySpending = <double>[];

      for (var i = 1; i <= 3; i++) {
        final targetMonth = DateTime(currentMonth.year, currentMonth.month - i);
        final startDate = DateTime(targetMonth.year, targetMonth.month, 1);
        final endDate = DateTime(targetMonth.year, targetMonth.month + 1, 0, 23, 59, 59);

        final transactions = await _transactionRepo.getTransactionsByDateRange(startDate, endDate);
        final spending = transactions
            .where((t) => t.type == 'expense' && t.categoryId == category.id)
            .fold(0.0, (sum, t) => sum + t.amount);

        if (spending > 0) {
          monthlySpending.add(spending);
        }
      }

      if (monthlySpending.isEmpty) continue;

      // Tính trung bình và thêm buffer 10%
      final avg3Months = monthlySpending.reduce((a, b) => a + b) / monthlySpending.length;
      final suggestedBudget = _roundToVndThousand(avg3Months * 1.1); // Thêm 10% buffer và làm tròn hàng nghìn VND

      final currentBudget = category.budget ?? 0;

      String reason;
      if (currentBudget == 0) {
        reason = 'Dựa trên chi tiêu trung bình 3 tháng gần nhất';
      } else if (suggestedBudget > currentBudget * 1.2) {
        reason = 'Chi tiêu thực tế cao hơn ngân sách hiện tại';
      } else if (suggestedBudget < currentBudget * 0.8) {
        reason = 'Bạn đang chi tiêu thấp hơn ngân sách, có thể giảm';
      } else {
        reason = 'Ngân sách phù hợp với thói quen chi tiêu';
      }

      suggestions.add(BudgetSuggestion(
        categoryName: category.name,
        currentBudget: currentBudget,
        suggestedBudget: suggestedBudget,
        reason: reason,
        avg3MonthsSpending: avg3Months,
      ));
    }

    return suggestions;
  }

  // ==================== DỮ LIỆU CHO BIỂU ĐỒ ====================

  /// Lấy dữ liệu cho biểu đồ dự đoán
  Future<List<MonthlySpendingData>> getPredictionChartData({
    required DateTime currentMonth,
    int monthsToShow = 6,
  }) async {
    final chartData = <MonthlySpendingData>[];

    // Lấy dữ liệu thực tế các tháng trước
    for (var i = monthsToShow - 1; i >= 1; i--) {
      final targetMonth = DateTime(currentMonth.year, currentMonth.month - i);
      final startDate = DateTime(targetMonth.year, targetMonth.month, 1);
      final endDate = DateTime(targetMonth.year, targetMonth.month + 1, 0, 23, 59, 59);

      final transactions = await _transactionRepo.getTransactionsByDateRange(startDate, endDate);
      final totalExpense = transactions
          .where((t) => t.type == 'expense')
          .fold(0.0, (sum, t) => sum + t.amount);

      chartData.add(MonthlySpendingData(
        month: targetMonth,
        actualAmount: totalExpense,
        isActual: true,
      ));
    }

    // Thêm tháng hiện tại
    final currentStartDate = DateTime(currentMonth.year, currentMonth.month, 1);
    final currentEndDate = DateTime(currentMonth.year, currentMonth.month + 1, 0, 23, 59, 59);
    final currentTransactions = await _transactionRepo.getTransactionsByDateRange(currentStartDate, currentEndDate);
    final currentExpense = currentTransactions
        .where((t) => t.type == 'expense')
        .fold(0.0, (sum, t) => sum + t.amount);

    chartData.add(MonthlySpendingData(
      month: currentMonth,
      actualAmount: currentExpense,
      isActual: true,
    ));

    // Thêm dự đoán tháng sau
    final prediction = await predictNextMonthSpending(currentMonth: currentMonth);
    final nextMonth = DateTime(currentMonth.year, currentMonth.month + 1);

    chartData.add(MonthlySpendingData(
      month: nextMonth,
      actualAmount: 0,
      predictedAmount: prediction.predictedAmount,
      isActual: false,
    ));

    return chartData;
  }

  // ==================== PHÂN TÍCH THEO THỜI GIAN TRONG NGÀY ====================

  /// Phân tích chi tiêu theo thời gian trong ngày (Sáng/Trưa/Chiều/Tối)
  Future<List<TimeBasedSpending>> analyzeTimeBasedSpending({
    required DateTime currentMonth,
  }) async {
    final startDate = DateTime(currentMonth.year, currentMonth.month, 1);
    final endDate = DateTime(currentMonth.year, currentMonth.month + 1, 0, 23, 59, 59);

    final transactions = await _transactionRepo.getTransactionsByDateRange(startDate, endDate);
    final expenses = transactions.where((t) => t.type == 'expense').toList();

    if (expenses.isEmpty) {
      return const [];
    }

    // Phân loại theo thời gian
    final periodSpending = <String, double>{};
    final periodCount = <String, int>{};

    for (var expense in expenses) {
      final period = _getTimePeriod(expense.date.hour);
      periodSpending[period] = (periodSpending[period] ?? 0) + expense.amount;
      periodCount[period] = (periodCount[period] ?? 0) + 1;
    }

    final totalSpending = expenses.fold(0.0, (sum, e) => sum + e.amount);

    // Tạo danh sách kết quả
    final results = <TimeBasedSpending>[];
    final periods = ['Sáng', 'Trưa', 'Chiều', 'Tối'];

    for (var period in periods) {
      final amount = periodSpending[period] ?? 0;
      final count = periodCount[period] ?? 0;
      final percentage = totalSpending > 0 ? (amount / totalSpending) * 100 : 0;

      results.add(TimeBasedSpending(
        period: period,
        amount: amount.toDouble(),
        transactionCount: count,
        percentage: percentage.toDouble(),
      ));
    }

    // Sắp xếp theo số tiền giảm dần
    results.sort((a, b) => b.amount.compareTo(a.amount));

    return results;
  }

  /// Xác định thời gian trong ngày dựa trên giờ
  String _getTimePeriod(int hour) {
    if (hour >= 5 && hour < 11) {
      return 'Sáng'; // 5h-11h
    } else if (hour >= 11 && hour < 14) {
      return 'Trưa'; // 11h-14h
    } else if (hour >= 14 && hour < 18) {
      return 'Chiều'; // 14h-18h
    } else {
      return 'Tối'; // 18h-5h
    }
  }

  // ==================== PHÂN CỤM HÀNH VI (K-MEANS) ====================

  /// Phân cụm hành vi chi tiêu bằng K-means clustering
  Future<SpendingCluster> clusterSpendingBehavior({
    required DateTime currentMonth,
  }) async {
    try {
      // Lấy dữ liệu 3 tháng gần nhất để phân tích
      final data = await _getSpendingFeatures(currentMonth: currentMonth, monthsBack: 3);

      if (data['avgMonthlySpending'] == 0) {
        return const SpendingCluster(
          clusterName: 'Chưa xác định',
          description: 'Chưa đủ dữ liệu để phân tích',
          avgMonthlySpending: 0,
          spendingToIncomeRatio: 0,
          highValueTransactionCount: 0,
        );
      }

      // Áp dụng quy tắc phân loại đơn giản (thay cho K-means phức tạp)
      // Có thể nâng cấp sau bằng ml_algo nếu cần

      final avgSpending = data['avgMonthlySpending'] as double;
      final ratio = data['spendingToIncomeRatio'] as double;
      final highValueCount = data['highValueTransactionCount'] as int;

      String clusterName;
      String description;

      // Phân loại dựa trên tỷ lệ chi/thu và hành vi giao dịch lớn
      if (ratio > 0 && ratio < 0.6) {
        // Tỉ lệ chi/thu thấp dưới 60%
        clusterName = 'Tiết kiệm';
        description = 'Bạn chi tiêu cẩn trọng, tích lũy tốt với tỉ lệ chi/thu dưới 60%.';
      } else if (ratio >= 0.85 || (avgSpending > 0 && highValueCount >= 8)) {
        // Tỉ lệ chi/thu cao hoặc nhiều giao dịch vượt ngưỡng trung bình
        clusterName = 'Thoải mái';
        description = 'Bạn chi tiêu tương đối thoải mái. Nên theo dõi sát ngân sách để tối ưu tích lũy.';
      } else {
        // Cân đối
        clusterName = 'Cân đối';
        description = 'Bạn có phong cách chi tiêu cân đối, hài hòa giữa chi tiêu sinh hoạt và tiết kiệm.';
      }

      return SpendingCluster(
        clusterName: clusterName,
        description: description,
        avgMonthlySpending: avgSpending,
        spendingToIncomeRatio: ratio,
        highValueTransactionCount: highValueCount,
      );
    } catch (e) {
      log('Lỗi phân cụm hành vi: $e');
      return const SpendingCluster(
        clusterName: 'Lỗi',
        description: 'Không thể phân tích hành vi',
        avgMonthlySpending: 0,
        spendingToIncomeRatio: 0,
        highValueTransactionCount: 0,
      );
    }
  }

  /// Lấy các đặc trưng để phân cụm
  Future<Map<String, dynamic>> _getSpendingFeatures({
    required DateTime currentMonth,
    required int monthsBack,
  }) async {
    final monthlySpending = <double>[];
    final monthlyIncome = <double>[];
    var totalHighValueTx = 0;

    for (var i = 0; i < monthsBack; i++) {
      final targetMonth = DateTime(currentMonth.year, currentMonth.month - i);
      final startDate = DateTime(targetMonth.year, targetMonth.month, 1);
      final endDate = DateTime(targetMonth.year, targetMonth.month + 1, 0, 23, 59, 59);

      final transactions = await _transactionRepo.getTransactionsByDateRange(startDate, endDate);

      final totalExpense = transactions
          .where((t) => t.type == 'expense')
          .fold(0.0, (sum, t) => sum + t.amount);

      final totalIncome = transactions
          .where((t) => t.type == 'income')
          .fold(0.0, (sum, t) => sum + t.amount);

      final expensesList = transactions.where((t) => t.type == 'expense').toList();
      final avgTx = expensesList.isNotEmpty ? (totalExpense / expensesList.length) : 0.0;
      final dynamicThreshold = math.max(10.0, avgTx * 2.0);

      final highValue = expensesList
          .where((t) => t.amount >= dynamicThreshold)
          .length;

      if (totalExpense > 0) {
        monthlySpending.add(totalExpense);
      }
      if (totalIncome > 0) {
        monthlyIncome.add(totalIncome);
      }
      totalHighValueTx += highValue;
    }

    final avgSpending = monthlySpending.isEmpty
        ? 0.0
        : monthlySpending.reduce((a, b) => a + b) / monthlySpending.length;

    final avgIncome = monthlyIncome.isEmpty
        ? 0.0
        : monthlyIncome.reduce((a, b) => a + b) / monthlyIncome.length;

    final ratio = avgIncome > 0 ? avgSpending / avgIncome : 0.0;

    return {
      'avgMonthlySpending': avgSpending,
      'avgMonthlyIncome': avgIncome,
      'spendingToIncomeRatio': ratio,
      'highValueTransactionCount': totalHighValueTx,
    };
  }

  // ==================== HELPER METHODS ====================

  /// Làm tròn số tiền về bội số của 1.000 VND vì tiền Việt Nam không lưu hành tiền lẻ dưới 1.000đ
  double _roundToVndThousand(num amount) {
    if (amount <= 0) return 0.0;
    final rounded = (amount / 1000.0).round() * 1000.0;
    return rounded > 0 ? rounded : 1000.0;
  }

  String _formatMonth(DateTime date) {
    final months = ['', 'Tháng 1', 'Tháng 2', 'Tháng 3', 'Tháng 4', 'Tháng 5',
      'Tháng 6', 'Tháng 7', 'Tháng 8', 'Tháng 9', 'Tháng 10', 'Tháng 11', 'Tháng 12'];
    return '${months[date.month]}/${date.year}';
  }

  String _getDayName(int weekday) {
    final days = ['', 'Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ nhật'];
    return days[weekday];
  }

  /// Tạo màu sắc động cho danh mục dựa trên tên
  int _generateCategoryColor(String categoryName) {
    // Danh sách màu sắc đẹp và dễ phân biệt
    final colors = [
      0xFFE53935, // Red
      0xFFD81B60, // Pink
      0xFF8E24AA, // Purple
      0xFF5E35B1, // Deep Purple
      0xFF3949AB, // Indigo
      0xFF1E88E5, // Blue
      0xFF039BE5, // Light Blue
      0xFF00ACC1, // Cyan
      0xFF00897B, // Teal
      0xFF43A047, // Green
      0xFF7CB342, // Light Green
      0xFFC0CA33, // Lime
      0xFFFDD835, // Yellow
      0xFFFFB300, // Amber
      0xFFFB8C00, // Orange
      0xFFF4511E, // Deep Orange
      0xFF6D4C41, // Brown
      0xFF757575, // Grey
      0xFF546E7A, // Blue Grey
    ];

    // Sử dụng hashCode của tên để chọn màu nhất quán
    final hash = categoryName.hashCode.abs();
    final colorIndex = hash % colors.length;

    return colors[colorIndex];
  }
}

