import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../services/file_storage.dart';

class LineChartWidget extends StatelessWidget {
  final List<DataEntry> entries;

  const LineChartWidget({Key? key, required this.entries}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(child: Text('No data to display.'));
    }
    
    // Sort entries in chronological order (least recent to most recent)
    final sortedEntries = List<DataEntry>.from(entries)
      ..sort((a, b) => a.date.compareTo(b.date));

    // Map sorted entries to FlSpot; use index as x value
    final spots = sortedEntries.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.value);
    }).toList();

    // Determine y-axis bounds based on glucose values
    final yValues = sortedEntries.map((e) => e.value).toList();
    final minDataY = yValues.reduce((a, b) => a < b ? a : b);
    final maxDataY = yValues.reduce((a, b) => a > b ? a : b);
    final displayMinY = minDataY - 5;
    final displayMaxY = maxDataY + 5;

    // Compute a safe horizontal interval.
    final double rawInterval = maxDataY - minDataY;
    final double safeInterval = (rawInterval == 0) ? 2.0 : rawInterval / 5;

    // x-axis runs from 0 to last index.
    double minX = 0;
    double maxX = spots.isNotEmpty ? spots.last.x : 0;
    // If there's only one data point, adjust x-axis range.
    if (spots.length < 2) {
      maxX = 1;
    }

    return Container(
      height: 300,
      padding: const EdgeInsets.all(12),
      child: LineChart(
        LineChartData(
          minX: minX,
          maxX: maxX,
          minY: displayMinY,
          maxY: displayMaxY,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.blueAccent,
              barWidth: 3,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.blueAccent.withOpacity(0.3),
              ),
            ),
          ],
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false, // Remove vertical grid lines.
            drawHorizontalLine: true,
            horizontalInterval: safeInterval,
          ),
          borderData: FlBorderData(show: true),
          // Configure only the left y-axis.
          titlesData: FlTitlesData(
            show: true,
            topTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: false, // x-axis is unlabeled as requested.
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: safeInterval,
                getTitlesWidget: (value, meta) {
                  // Remove top and bottom labels (i.e. the chart bounds).
                  if ((value - displayMinY).abs() < 0.001 || 
                      (value - displayMaxY).abs() < 0.001) {
                    return Container();
                  }
                  return Text(
                    value.toStringAsFixed(0),
                    style: const TextStyle(fontSize: 12),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
} 