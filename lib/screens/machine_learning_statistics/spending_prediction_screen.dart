import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/ml_analytics_service.dart';
import '../../models/ml_prediction.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/icon_helper.dart';

/// Màn hình hiển thị dự đoán chi tiêu và phân tích thông minh
class SpendingPredictionScreen extends StatefulWidget {
  const SpendingPredictionScreen({super.key});

  @override
  State<SpendingPredictionScreen> createState() => _SpendingPredictionScreenState();
}

class _SpendingPredictionScreenState extends State<SpendingPredictionScreen> {
  final MLAnalyticsService _mlService = MLAnalyticsService();

  bool _isLoading = true;

  // Data
  SpendingPrediction? _prediction;
  SpendingHabit? _habit;
  List<BudgetAlert> _alerts = [];
  List<MonthlySpendingData> _chartData = [];
  List<TimeBasedSpending> _timeBasedData = [];
  SpendingCluster? _cluster;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final currentMonth = DateTime(now.year, now.month);

      final results = await Future.wait([
        _mlService.predictNextMonthSpending(currentMonth: currentMonth),
        _mlService.analyzeSpendingHabits(currentMonth: currentMonth),
        _mlService.detectBudgetAlerts(currentMonth: currentMonth),
        _mlService.getPredictionChartData(currentMonth: currentMonth),
        _mlService.analyzeTimeBasedSpending(currentMonth: currentMonth),
        _mlService.clusterSpendingBehavior(currentMonth: currentMonth),
      ]);

      setState(() {
        _prediction = results[0] as SpendingPrediction;
        _habit = results[1] as SpendingHabit;
        _alerts = results[2] as List<BudgetAlert>;
        _chartData = results[3] as List<MonthlySpendingData>;
        _timeBasedData = results[4] as List<TimeBasedSpending>;
        _cluster = results[5] as SpendingCluster;
        _isLoading = false;
      });
    } catch (e) {
      log('Lỗi tải dữ liệu ML: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Phân tích thông minh',
          style: TextStyle(
            color: colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? theme.scaffoldBackgroundColor : colorScheme.primary,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(
          color: colorScheme.onPrimary,
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: colorScheme.onPrimary,
            ),
            onPressed: _loadData,
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadData,
        color: theme.colorScheme.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              const SizedBox(height: 16),

              // Dự đoán chi tiêu tháng tới
              if (_prediction != null) _buildPredictionCard(),

              // Biểu đồ xu hướng
              if (_chartData.isNotEmpty) _buildTrendChart(),

              // Cảnh báo ngân sách
              if (_alerts.isNotEmpty) _buildAlertsSection(),

              // Hồ sơ tài chính & Phân tích thói quen
              if (_habit != null) _buildHabitAnalysis(),

              // Phân tích theo thời gian trong ngày
              if (_timeBasedData.isNotEmpty) _buildTimeBasedSection(),

              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== PREDICTION CARD ====================

  Widget _buildPredictionCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final prediction = _prediction!;

    // Icon và màu theo xu hướng
    IconData trendIcon;
    Color trendColor;
    String trendText;

    switch (prediction.trend) {
      case 'increasing':
        trendIcon = Icons.trending_up;
        trendColor = Colors.red;
        trendText = 'Tăng';
        break;
      case 'decreasing':
        trendIcon = Icons.trending_down;
        trendColor = Colors.green;
        trendText = 'Giảm';
        break;
      default:
        trendIcon = Icons.trending_flat;
        trendColor = Colors.blue;
        trendText = 'Ổn định';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E3A8A), const Color(0xFF3B82F6)]
              : [const Color(0xFF3B82F6), const Color(0xFF60A5FA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.psychology,
                  color: Colors.white,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Dự đoán chi tiêu',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    prediction.month,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Số tiền dự đoán
            FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                CurrencyFormatter.formatAmount(prediction.predictedAmount),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (prediction.lowerBound != null && prediction.upperBound != null && prediction.predictedAmount > 0) ...[
              const SizedBox(height: 4),
              Text(
                'Khoảng ước tính: ${CurrencyFormatter.formatAmount(prediction.lowerBound!)} ~ ${CurrencyFormatter.formatAmount(prediction.upperBound!)}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 12),

            // Xu hướng và độ tin cậy
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: trendColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(trendIcon, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '$trendText ${prediction.changeRate.abs().toStringAsFixed(1)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Độ tin cậy ${(prediction.confidence * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Thẻ dự phóng tiến độ tháng hiện tại (Current Month Run-rate)
            if (prediction.currentMonthProjected != null && prediction.currentMonthSpentSoFar != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.timelapse, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Dự phóng tháng này (${prediction.daysElapsedInCurrentMonth ?? 0}/${prediction.totalDaysInCurrentMonth ?? 30} ngày):',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Đã chi: ${CurrencyFormatter.formatAmount(prediction.currentMonthSpentSoFar!)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Dự kiến cả tháng: ~${CurrencyFormatter.formatAmount(prediction.currentMonthProjected!)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),

            // Mô tả
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white.withValues(alpha: 0.8), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Dự báo thông minh kết hợp Trung bình động có trọng số (WMA) & Xu hướng tuyến tính.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== TREND CHART ====================

  String _formatYAxisLabel(double value) {
    if (value <= 0) return '0';
    if (value >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(1)}B';
    }
    if (value >= 1000000) {
      final m = value / 1000000;
      return m == m.roundToDouble() ? '${m.toInt()}M' : '${m.toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      final k = value / 1000;
      return k == k.roundToDouble() ? '${k.toInt()}k' : '${k.toStringAsFixed(1)}k';
    }
    return value.toStringAsFixed(0);
  }

  Widget _buildTrendChart() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_chartData.isEmpty) return const SizedBox.shrink();

    // Tính toán min / max an toàn cho trục Y để không bao giờ bị cắt vát
    double maxVal = 0.0;
    for (var item in _chartData) {
      if (item.actualAmount > maxVal) maxVal = item.actualAmount;
      if ((item.predictedAmount ?? 0) > maxVal) maxVal = item.predictedAmount!;
    }
    if (maxVal <= 0) maxVal = 100000.0;
    final maxY = maxVal * 1.25;
    final horizontalInterval = (maxY / 4).clamp(1.0, double.infinity);
    final maxX = (_chartData.length - 1).toDouble().clamp(1.0, double.infinity);

    // Tách các điểm thực tế
    final actualSpots = _chartData
        .asMap()
        .entries
        .where((e) => e.value.isActual)
        .map((e) => FlSpot(e.key.toDouble(), e.value.actualAmount))
        .toList();

    // Điểm bắt đầu của dự đoán là điểm thực tế cuối cùng
    final lastActualEntry = _chartData
        .asMap()
        .entries
        .lastWhere((e) => e.value.isActual, orElse: () => _chartData.asMap().entries.first);

    final forecastEntries = _chartData
        .asMap()
        .entries
        .where((e) => !e.value.isActual)
        .toList();

    final forecastSpots = [
      FlSpot(lastActualEntry.key.toDouble(), lastActualEntry.value.actualAmount),
      ...forecastEntries.map((e) => FlSpot(e.key.toDouble(), e.value.predictedAmount ?? 0)),
    ];

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.show_chart,
                color: theme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Xu hướng chi tiêu',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          SizedBox(
            height: (MediaQuery.of(context).size.height * 0.32).clamp(200.0, 320.0),
            child: LineChart(
              LineChartData(
                clipData: const FlClipData.all(),
                minY: 0,
                maxY: maxY,
                minX: 0,
                maxX: maxX,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: horizontalInterval,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.grey.withValues(alpha: 0.2),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 48,
                      interval: horizontalInterval,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          _formatYAxisLabel(value),
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 1.0,
                      getTitlesWidget: (value, meta) {
                        final index = value.round();
                        if (index >= 0 && index < _chartData.length) {
                          final data = _chartData[index];
                          final isForecast = !data.isActual;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              isForecast ? 'Dự kiến' : 'T${data.month.month}',
                              style: TextStyle(
                                color: isForecast
                                    ? Colors.orange
                                    : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                fontSize: 11,
                                fontWeight: isForecast ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  // Line cho dữ liệu thực tế
                  LineChartBarData(
                    spots: actualSpots,
                    isCurved: actualSpots.length > 1,
                    preventCurveOverShooting: true,
                    color: theme.colorScheme.primary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: theme.colorScheme.primary,
                          strokeWidth: 2,
                          strokeColor: theme.colorScheme.surface,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    ),
                  ),
                  // Line cho dự đoán (nối liền mạch từ tháng hiện tại sang dự đoán)
                  if (forecastSpots.length > 1)
                    LineChartBarData(
                      spots: forecastSpots,
                      isCurved: true,
                      preventCurveOverShooting: true,
                      color: Colors.orange,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dashArray: [5, 5],
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: Colors.orange,
                            strokeWidth: 2,
                            strokeColor: theme.colorScheme.surface,
                          );
                        },
                      ),
                    ),
                ],
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final idx = spot.x.round();
                        String label = '';
                        if (idx >= 0 && idx < _chartData.length) {
                          label = _chartData[idx].isActual
                              ? 'Thực tế T${_chartData[idx].month.month}: '
                              : 'Dự kiến T${_chartData[idx].month.month}: ';
                        }
                        return LineTooltipItem(
                          '$label${CurrencyFormatter.formatAmount(spot.y)}',
                          const TextStyle(color: Colors.white, fontSize: 12),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('Thực tế', theme.colorScheme.primary, false),
              const SizedBox(width: 20),
              _buildLegendItem('Dự kiến tháng tới', Colors.orange, true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, bool isDashed) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
          child: isDashed
              ? CustomPaint(
            painter: DashedLinePainter(color: color),
          )
              : null,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  // ==================== ALERTS SECTION ====================

  Widget _buildAlertsSection() {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange[700],
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Cảnh báo ngân sách',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          ..._alerts.map((alert) => _buildAlertItem(alert)),
        ],
      ),
    );
  }

  Widget _buildAlertItem(BudgetAlert alert) {
    final theme = Theme.of(context);

    Color severityColor;
    IconData severityIcon;

    switch (alert.severity) {
      case 'high':
        severityColor = Colors.red;
        severityIcon = Icons.error;
        break;
      case 'medium':
        severityColor = Colors.orange;
        severityIcon = Icons.warning;
        break;
      default: // 'low'
        severityColor = Colors.green;
        severityIcon = Icons.check_circle;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: severityColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(severityIcon, color: severityColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  alert.categoryName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: severityColor,
                  ),
                ),
              ),
              Text(
                '${alert.usedPercentage.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: severityColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (alert.usedPercentage / 100).clamp(0.0, 1.0),
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(severityColor),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),

          Text(
            'Đã sử dụng ${alert.usedPercentage.toStringAsFixed(1)}% ngân sách '
                'trong ${alert.daysElapsed}/${alert.totalDays} ngày '
                '(${alert.timeElapsedPercentage.toStringAsFixed(0)}% thời gian).',
            style: theme.textTheme.bodySmall,
          ),

          // Hiển thị thông điệp theo mức độ cảnh báo
          const SizedBox(height: 8),
          _buildAlertMessage(alert, severityColor, theme),
        ],
      ),
    );
  }

  /// Hiển thị thông điệp cảnh báo theo mức độ
  Widget _buildAlertMessage(BudgetAlert alert, Color severityColor, ThemeData theme) {
    String message;
    IconData icon;

    switch (alert.severity) {
      case 'high': // Đỏ - Nguy hiểm
        message = 'Cảnh báo! Bạn đã chi ${CurrencyFormatter.formatAmount(alert.spentAmount)} '
            '(${alert.usedPercentage.toStringAsFixed(1)}% trong ngân sách hiện tại). '
            '\nDự kiến bạn sẽ vượt ${CurrencyFormatter.formatAmount(alert.projectedOverage)} trong những ngày còn lại của ngân sách nếu tiếp tục với tốc độ này.'
            'Hãy giảm chi tiêu ngay!';
        icon = Icons.trending_up;
        break;

      case 'medium': // Cam - Cảnh báo
        message = 'Bạn đã chi tiêu ${CurrencyFormatter.formatAmount(alert.spentAmount)} '
            '(~${alert.usedPercentage.toStringAsFixed(1)}% ngân sách). '
            'Hãy tiết kiệm lại một chút để tránh vượt ngân sách này nhé!';
        icon = Icons.savings;
        break;

      default: // Xanh - An toàn
        message = 'Tuyệt vời! Bạn đang chi tiêu rất hợp lý. '
            'Đã chi ${CurrencyFormatter.formatAmount(alert.spentAmount)} '
            '(${alert.usedPercentage.toStringAsFixed(1)}% ngân sách). '
            'Tiếp tục duy trì nhé!';
        icon = Icons.thumb_up;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: severityColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: severityColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: severityColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== HABIT ANALYSIS ====================

  Widget _buildHabitAnalysis() {
    final theme = Theme.of(context);
    final habit = _habit!;

    // Icon cho spending style - Sử dụng IconHelper
    IconData styleIcon;
    Color styleColor;

    switch (habit.spendingStyle) {
      case 'Tiết kiệm':
        styleIcon = IconHelper.getCategoryIcon('savings');
        styleColor = Colors.green;
        break;
      case 'Thoải mái':
        styleIcon = IconHelper.getCategoryIcon('shopping_bag');
        styleColor = Colors.orange;
        break;
      default:
        styleIcon = IconHelper.getCategoryIcon('balance');
        styleColor = Colors.blue;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.psychology_alt,
                color: Colors.amber[700],
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Hồ sơ & Thói quen chi tiêu',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Spending style badge with description
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: styleColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: styleColor.withValues(alpha: 0.3),
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(styleIcon, color: styleColor, size: 30),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Phong cách chi tiêu',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            habit.spendingStyle,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: styleColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_cluster?.description != null && _cluster!.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _cluster!.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3 thông số tài chính chính
          Row(
            children: [
              Expanded(
                child: _buildCompactInsightCard(
                  icon: Icons.percent,
                  label: 'Tỉ lệ chi/thu',
                  value: _cluster != null && _cluster!.spendingToIncomeRatio > 0
                      ? '${(_cluster!.spendingToIncomeRatio * 100).toStringAsFixed(0)}%'
                      : '—',
                  color: Colors.purpleAccent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactInsightCard(
                  icon: Icons.today,
                  label: 'Chi TB/ngày',
                  value: CurrencyFormatter.formatAmount(habit.avgDailySpending),
                  color: Colors.blueAccent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactInsightCard(
                  icon: Icons.diamond_outlined,
                  label: 'Giao dịch lớn',
                  value: '${_cluster?.highValueTransactionCount ?? 0} lần',
                  color: Colors.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ===== DANH MỤC HÀNG ĐẦU (Nhiều categories) =====
          if (habit.topCategories.isNotEmpty) ...[
            Text(
              'Danh mục chi tiêu hàng đầu',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: habit.topCategories.map((category) {
                return _buildCategoryBadge(
                  name: category.name,
                  icon: category.icon,
                  color: Color(category.color),
                  percentage: category.percentage,
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],

          // ===== NGÀY CHI TIÊU NHIỀU (Nhiều ngày) =====
          Text(
            'Ngày chi tiêu nhiều nhất',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: habit.topSpendingDays.map((day) {
              return _buildDayChip(day);
            }).toList(),
          ),
          const SizedBox(height: 20),

          // ===== INSIGHTS KHÁC =====
          Row(
            children: [
              Expanded(
                child: _buildCompactInsightCard(
                  icon: Icons.access_time,
                  label: 'Thời gian ưa thích',
                  value: habit.preferredTime,
                  color: Colors.greenAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCompactInsightCard(
                  icon: Icons.today,
                  label: 'Chi TB/ngày',
                  value: CurrencyFormatter.formatAmount(habit.avgDailySpending),
                  color: Colors.blueAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Widget hiển thị badge danh mục với icon từ IconHelper
  Widget _buildCategoryBadge({
    required String name,
    required String icon,
    required Color color,
    required double percentage,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            IconHelper.getCategoryIcon(icon),
            color: color,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            name,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: color.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Text(
              '${percentage.toStringAsFixed(0)}%',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Widget hiển thị chip ngày
  Widget _buildDayChip(String day) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_today,
            color: colorScheme.onSurface,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            day,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  /// Widget insight card nhỏ gọn
  Widget _buildCompactInsightCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }




  // ==================== TIME BASED SECTION ====================

  Widget _buildTimeBasedSection() {
    final theme = Theme.of(context);

    // Icon cho từng thời gian
    final periodIcons = {
      'Sáng': Icons.wb_sunny,
      'Trưa': Icons.wb_sunny_outlined,
      'Chiều': Icons.wb_twilight,
      'Tối': Icons.nights_stay,
    };

    final periodColors = {
      'Sáng': Colors.amber,
      'Trưa': Colors.orange,
      'Chiều': Colors.deepOrange,
      'Tối': Colors.indigo,
    };

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.schedule,
                color: Colors.teal[700],
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Chi tiêu theo giờ',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Phân tích chi tiêu trong ngày',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),

          // List các thời gian
          ..._timeBasedData.map((data) {
            final color = periodColors[data.period] ?? Colors.blue;
            final icon = periodIcons[data.period] ?? Icons.access_time;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: color.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              data.period,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${data.percentage.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          CurrencyFormatter.formatAmount(data.amount),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${data.transactionCount} giao dịch',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

// ==================== BUDGET SUGGESTIONS ====================
}

// Custom painter for dashed line
class DashedLinePainter extends CustomPainter {
  final Color color;

  DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3;

    const dashWidth = 5;
    const dashSpace = 5;
    var startX = 0.0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset(startX + dashWidth, size.height / 2),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

