import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:hr_payroll_smartkidz/components/color_app.dart';

class EmployeeDetailScreen extends StatelessWidget {
  const EmployeeDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenTypeLayout.builder(
      mobile: (context) => buildMainContent(context, 14, 12),
      tablet: (context) => buildMainContent(context, 16, 24),
      desktop: (context) => buildMainContent(context, 18, 32),
    );
  }

  Widget buildMainContent(BuildContext context, double fontSize, double padding) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.notifications_none, color: Colors.white),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(bottom: padding),
          child: Column(
            children: [
              Container(
                color: Theme.of(context).primaryColor,
                padding: EdgeInsets.symmetric(vertical: padding, horizontal: padding),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person, color: Colors.deepPurple),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Shaidul Islam Details',
                          style: TextStyle(color: Colors.white, fontSize: fontSize, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Designer',
                          style: TextStyle(color: Colors.white70, fontSize: fontSize * 0.9),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Working Hours
              Container(
                margin: EdgeInsets.all(padding),
                padding: EdgeInsets.all(padding),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Working Hours', style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('6 h 30 m', style: TextStyle(fontSize: fontSize + 6, fontWeight: FontWeight.bold)),
                        Text('Today', style: TextStyle(color: Colors.grey, fontSize: fontSize * 0.9)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 150,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: 8,
                          barTouchData: BarTouchData(enabled: false),
                          titlesData: FlTitlesData(
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  final days = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
                                  return Text(days[value.toInt()], style: TextStyle(fontSize: fontSize * 0.8));
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: 2,
                                getTitlesWidget: (value, meta) => Text('${value.toInt()}h', style: TextStyle(fontSize: fontSize * 0.8)),
                              ),
                            ),
                            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          gridData: FlGridData(show: false),
                          borderData: FlBorderData(show: false),
                          barGroups: [
                            BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 5.5, color: Colors.blueAccent)]),
                            BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: 6.5, color: Colors.blueAccent)]),
                            BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: 4.5, color: Colors.blueAccent)]),
                            BarChartGroupData(x: 3, barRods: [BarChartRodData(toY: 6, color: Colors.blueAccent)]),
                            BarChartGroupData(x: 4, barRods: [BarChartRodData(toY: 7.5, color: Colors.blueAccent)]),
                            BarChartGroupData(x: 5, barRods: [BarChartRodData(toY: 6.3, color: Colors.blueAccent)]),
                            BarChartGroupData(x: 6, barRods: [BarChartRodData(toY: 0, color: Colors.transparent)]),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Attendance Summary
              Container(
                margin: EdgeInsets.symmetric(horizontal: padding),
                padding: EdgeInsets.all(padding),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Attendance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize)),
                        Text('30 May 2021', style: TextStyle(color: Colors.grey, fontSize: fontSize * 0.9)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: const [
                        StatBox(count: '13', label: 'Present', color: Colors.blue),
                        StatBox(count: '0', label: 'Absent', color: Colors.orange),
                        StatBox(count: '4', label: 'Holiday', color: Colors.green),
                        StatBox(count: '6', label: 'Half Day', color: Colors.amber),
                        StatBox(count: '4', label: 'Week Off', color: Colors.purple),
                        StatBox(count: '3', label: 'Leave', color: Colors.teal),
                      ],
                    ),
                  ],
                ),
              ),

              // Buttons
              Padding(
                padding: EdgeInsets.symmetric(horizontal: padding, vertical: padding / 2),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade200,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {},
                        child: Text('Delete', style: TextStyle(fontSize: fontSize)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3A7AFE),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {},
                        child: Text('Edit', style: TextStyle(fontSize: fontSize)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StatBox extends StatelessWidget {
  final String count;
  final String label;
  final Color color;

  const StatBox({super.key, required this.count, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(count, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.black)),
        ],
      ),
    );
  }
}
