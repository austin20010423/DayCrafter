import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider.dart';
import '../styles.dart';
import 'calendar/day_view.dart';
import 'calendar/week_view.dart';
import 'calendar/month_view.dart';

/// Main Calendar View container that switches between Day, Week, and Month views
class CalendarView extends StatelessWidget {
  const CalendarView({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DayCrafterProvider>();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppStyles.mBackground.withValues(alpha: 0.5),
      ),
      child: _buildCurrentView(provider.currentCalendarView),
    );
  }

  Widget _buildCurrentView(CalendarViewType viewType) {
    switch (viewType) {
      case CalendarViewType.day:
        return const DayView();
      case CalendarViewType.week:
        return const WeekView();
      case CalendarViewType.month:
        return const MonthView();
    }
  }
}
