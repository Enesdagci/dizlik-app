import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../utils/app_colors.dart';

/// Termal analiz grafiğini gösteren widget
class MedicalChart extends StatelessWidget {
  final List<FlSpot> hotSpotData;
  final List<FlSpot> baseLineData;
  final Map<double, String> timeLabels;

  const MedicalChart({
    super.key,
    required this.hotSpotData,
    required this.baseLineData,
    required this.timeLabels,
  });

  @override
  Widget build(BuildContext context) {
    if (hotSpotData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.timeline, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Grafik verisi bekleniyor',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Cihaza bağlandıktan sonra\nveriler burada görünecek',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      );
    }

    double maxX = hotSpotData.last.x;
    double interval = _calculateInterval(maxX);
    double minY = _calculateMinY();
    double maxY = _calculateMaxY();

    return Column(
      children: [
        _buildLegend(),
        const SizedBox(height: 12),
        Expanded(
          child: LineChart(
            LineChartData(
              lineTouchData: LineTouchData(
                enabled: true,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (touchedSpot) =>
                      AppColors.textPrimary.withValues(alpha: 0.9),
                  tooltipRoundedRadius: 8,
                  tooltipPadding: const EdgeInsets.all(8),
                  getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                    return touchedBarSpots.map((barSpot) {
                      String saat = timeLabels[barSpot.x] ?? '--:--';
                      String temp = barSpot.y.toStringAsFixed(1);

                      if (barSpot.barIndex == 0) {
                        return LineTooltipItem(
                          '🔥 Sıcak Nokta\n$saat\n$temp°C',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      } else {
                        return LineTooltipItem(
                          '📍 Kontrol\n$saat\n$temp°C',
                          const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        );
                      }
                    }).toList();
                  },
                ),
                handleBuiltInTouches: true,
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: hotSpotData,
                  isCurved: true,
                  curveSmoothness: 0.3,
                  color: AppColors.hotSpot,
                  barWidth: 3,
                  dotData: const FlDotData(
                    show: true,
                    getDotPainter: _getHotSpotDotPainter,
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        AppColors.hotSpot.withValues(alpha: 0.2),
                        AppColors.hotSpot.withValues(alpha: 0.0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                LineChartBarData(
                  spots: baseLineData,
                  isCurved: true,
                  curveSmoothness: 0.3,
                  color: AppColors.baseline,
                  barWidth: 2,
                  dashArray: const [5, 5],
                  dotData: const FlDotData(
                    show: true,
                    getDotPainter: _getBaselineDotPainter,
                  ),
                ),
              ],
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    interval: interval,
                    getTitlesWidget: (value, meta) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          timeLabels[value] ?? '',
                          style: const TextStyle(
                            fontSize: 9,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    interval: 2,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        '${value.toInt()}°',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              gridData: const FlGridData(
                show: true,
                drawVerticalLine: true,
                horizontalInterval: 2,
                getDrawingHorizontalLine: _getHorizontalGridLine,
                getDrawingVerticalLine: _getVerticalGridLine,
              ),
              borderData: FlBorderData(
                show: true,
                border: const Border.fromBorderSide(
                  BorderSide(
                    color: AppColors.gridLine,
                    width: 1.5,
                  ),
                ),
              ),
              minY: minY,
              maxY: maxY,
              minX: 0,
              maxX: maxX,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegend() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LegendItem(label: 'Sıcak Nokta', color: AppColors.hotSpot, isSolid: true),
        SizedBox(width: 24),
        _LegendItem(label: 'Kontrol', color: AppColors.baseline, isSolid: false),
      ],
    );
  }

  static FlDotCirclePainter _getHotSpotDotPainter(
    FlSpot spot,
    double xPercentage,
    LineChartBarData bar,
    int index,
  ) {
    return FlDotCirclePainter(
      radius: 3,
      color: AppColors.hotSpot,
      strokeWidth: 2,
      strokeColor: Colors.white,
    );
  }

  static FlDotCirclePainter _getBaselineDotPainter(
    FlSpot spot,
    double xPercentage,
    LineChartBarData bar,
    int index,
  ) {
    return FlDotCirclePainter(
      radius: 2,
      color: AppColors.baseline,
      strokeWidth: 1,
      strokeColor: Colors.white,
    );
  }

  static FlLine _getHorizontalGridLine(double value) {
    return const FlLine(
      color: AppColors.gridLine,
      strokeWidth: 1,
    );
  }

  static FlLine _getVerticalGridLine(double value) {
    return const FlLine(
      color: AppColors.gridLine,
      strokeWidth: 0.5,
    );
  }

  double _calculateInterval(double maxX) {
    if (maxX <= 5) return 1.0;
    if (maxX <= 20) return 2.0;
    if (maxX <= 50) return 5.0;
    return (maxX / 10).floorToDouble();
  }

  double _calculateMinY() {
    final allTemps = [...hotSpotData, ...baseLineData].map((e) => e.y);
    if (allTemps.isEmpty) return 20;
    final minTemp = allTemps.reduce((a, b) => a < b ? a : b);
    return (minTemp - 2).floorToDouble();
  }

  double _calculateMaxY() {
    final allTemps = [...hotSpotData, ...baseLineData].map((e) => e.y);
    if (allTemps.isEmpty) return 40;
    final maxTemp = allTemps.reduce((a, b) => a > b ? a : b);
    return (maxTemp + 2).ceilToDouble();
  }
}

class _LegendItem extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSolid;

  const _LegendItem({
    required this.label,
    required this.color,
    required this.isSolid,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 3,
          decoration: BoxDecoration(
            color: isSolid ? color : null,
            border: isSolid ? null : Border.all(color: color, width: 2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}