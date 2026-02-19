import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../core/theme/app_colors.dart';
import '../services/fee_service.dart';

class FeeCalendarScreen extends StatefulWidget {
  final String coachingId;

  const FeeCalendarScreen({super.key, required this.coachingId});

  @override
  State<FeeCalendarScreen> createState() => _FeeCalendarScreenState();
}

class _FeeCalendarScreenState extends State<FeeCalendarScreen> {
  final _feeService = FeeService();

  // Map date string (YYYY-MM-DD) to stats
  Map<String, Map<String, dynamic>> _calendarData = {};

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchMonthData(_focusedDay);
  }

  Future<void> _fetchMonthData(DateTime date) async {
    try {
      // Fetch for the whole month (with some buffer if needed, but service takes exact dates)
      final start = DateTime(date.year, date.month, 1);
      final end = DateTime(date.year, date.month + 1, 0); // Last day of month

      final data = await _feeService.getFeeCalendarStats(
        widget.coachingId,
        start,
        end,
      );

      final newMap = <String, Map<String, dynamic>>{};
      for (var item in data) {
        // item = {date: "2025-05-12", collected: 100, due: 500}
        newMap[item['date']] = item;
      }

      setState(() {
        _calendarData = newMap;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading calendar: $e')));
    } finally {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fee Calendar'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: const TextStyle(
          color: AppColors.darkOlive,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: const IconThemeData(color: AppColors.darkOlive),
      ),
      body: Column(
        children: [
          _buildCalendar(),
          const Divider(),
          Expanded(child: _buildDayDetails()),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    return TableCalendar(
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: _focusedDay,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });
      },
      onPageChanged: (focusedDay) {
        _focusedDay = focusedDay;
        _fetchMonthData(focusedDay);
      },
      calendarStyle: const CalendarStyle(
        todayDecoration: BoxDecoration(
          color: AppColors.mutedOlive,
          shape: BoxShape.circle,
        ),
        selectedDecoration: BoxDecoration(
          color: AppColors.darkOlive,
          shape: BoxShape.circle,
        ),
      ),
      calendarBuilders: CalendarBuilders(
        markerBuilder: (context, date, events) {
          final key = DateFormat('yyyy-MM-dd').format(date);
          final data = _calendarData[key];
          if (data == null) return null;

          final collected = (data['collected'] as num?)?.toDouble() ?? 0;
          final due = (data['due'] as num?)?.toDouble() ?? 0;

          if (collected == 0 && due == 0) return null;

          return Positioned(
            bottom: 1,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (due > 0)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                if (collected > 0)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: const BoxDecoration(
                      color: AppColors.primaryGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDayDetails() {
    if (_selectedDay == null) return const SizedBox();

    final key = DateFormat('yyyy-MM-dd').format(_selectedDay!);
    final data = _calendarData[key];

    if (data == null ||
        ((data['collected'] ?? 0) == 0 && (data['due'] ?? 0) == 0)) {
      return Center(
        child: Text(
          'No activity on ${DateFormat.yMMMd().format(_selectedDay!)}',
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    final collected = (data['collected'] as num?)?.toDouble() ?? 0;
    final due = (data['due'] as num?)?.toDouble() ?? 0;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat.yMMMMEEEEd().format(_selectedDay!),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.darkOlive,
            ),
          ),
          const SizedBox(height: 20),
          _buildStatCard('Collected', collected, AppColors.primaryGreen),
          const SizedBox(height: 12),
          _buildStatCard('Due', due, Colors.redAccent),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
