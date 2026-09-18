import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CustomDateRangePickerDialog extends StatefulWidget {
  final DateTime initialStartDate;
  final DateTime initialEndDate;

  const CustomDateRangePickerDialog({
    super.key,
    required this.initialStartDate,
    required this.initialEndDate,
  });

  static Future<DateTimeRange?> show(
    BuildContext context, {
    required DateTime initialStartDate,
    required DateTime initialEndDate,
  }) {
    return showDialog<DateTimeRange>(
      context: context,
      builder: (ctx) => CustomDateRangePickerDialog(
        initialStartDate: initialStartDate,
        initialEndDate: initialEndDate,
      ),
    );
  }

  @override
  State<CustomDateRangePickerDialog> createState() => _CustomDateRangePickerDialogState();
}

class _CustomDateRangePickerDialogState extends State<CustomDateRangePickerDialog> {
  late DateTime _fromDate;
  late DateTime _toDate;
  late DateTime _month1;
  late DateTime _month2;
  bool _isSelectingFrom = true;

  @override
  void initState() {
    super.initState();
    _fromDate = DateTime(
      widget.initialStartDate.year,
      widget.initialStartDate.month,
      widget.initialStartDate.day,
    );
    _toDate = DateTime(
      widget.initialEndDate.year,
      widget.initialEndDate.month,
      widget.initialEndDate.day,
    );

    _month1 = DateTime(_fromDate.year, _fromDate.month, 1);
    if (_toDate.year == _fromDate.year && _toDate.month == _fromDate.month) {
      _month2 = DateTime(_fromDate.year, _fromDate.month + 1, 1);
    } else {
      _month2 = DateTime(_toDate.year, _toDate.month, 1);
    }
  }

  void _onDateTapped(DateTime date) {
    setState(() {
      final cleanDate = DateTime(date.year, date.month, date.day);
      if (_isSelectingFrom) {
        _fromDate = cleanDate;
        if (_toDate.isBefore(_fromDate)) {
          _toDate = _fromDate;
        }
        _isSelectingFrom = false;
      } else {
        if (cleanDate.isBefore(_fromDate)) {
          _fromDate = cleanDate;
          _isSelectingFrom = false;
        } else {
          _toDate = cleanDate;
          _isSelectingFrom = true;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 700;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24, vertical: 20),
      child: Container(
        width: isMobile ? screenWidth - 24 : 680,
        padding: EdgeInsets.all(isMobile ? 14 : 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top From Date & To Date Input Boxes (Image 1)
              _buildFromToHeader(isMobile: isMobile),
              const SizedBox(height: 16),

              // Calendars Section
              if (isMobile)
                _buildSingleCalendarPanel(_month1, (newMonth) => setState(() => _month1 = newMonth))
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildCalendarPanel(
                        _month1,
                        onPrev: () => setState(() => _month1 = DateTime(_month1.year, _month1.month - 1, 1)),
                        onNext: () => setState(() => _month1 = DateTime(_month1.year, _month1.month + 1, 1)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildCalendarPanel(
                        _month2,
                        onPrev: () => setState(() => _month2 = DateTime(_month2.year, _month2.month - 1, 1)),
                        onNext: () => setState(() => _month2 = DateTime(_month2.year, _month2.month + 1, 1)),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 18),

              // Action Buttons Row: Cancel and Apply
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {
                      final range = DateTimeRange(
                        start: DateTime(_fromDate.year, _fromDate.month, _fromDate.day, 0, 0, 0),
                        end: DateTime(_toDate.year, _toDate.month, _toDate.day, 23, 59, 59, 999),
                      );
                      Navigator.of(context).pop(range);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Apply Range', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFromToHeader({required bool isMobile}) {
    final fromBox = InkWell(
      onTap: () => setState(() => _isSelectingFrom = true),
      borderRadius: BorderRadius.circular(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'From Date',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _isSelectingFrom ? const Color(0xFFEFF6FF) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _isSelectingFrom ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                width: _isSelectingFrom ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_rounded, size: 16, color: Color(0xFF2563EB)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    DateFormat('dd MMM yyyy').format(_fromDate),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final toBox = InkWell(
      onTap: () => setState(() => _isSelectingFrom = false),
      borderRadius: BorderRadius.circular(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'To Date',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: !_isSelectingFrom ? const Color(0xFFEFF6FF) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: !_isSelectingFrom ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                width: !_isSelectingFrom ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_rounded, size: 16, color: Color(0xFF2563EB)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    DateFormat('dd MMM yyyy').format(_toDate),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (isMobile) {
      return Column(
        children: [
          fromBox,
          const SizedBox(height: 8),
          toBox,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: fromBox),
        const SizedBox(width: 14),
        Expanded(child: toBox),
      ],
    );
  }

  Widget _buildSingleCalendarPanel(DateTime month, ValueChanged<DateTime> onMonthChanged) {
    return _buildCalendarPanel(
      month,
      onPrev: () => onMonthChanged(DateTime(month.year, month.month - 1, 1)),
      onNext: () => onMonthChanged(DateTime(month.year, month.month + 1, 1)),
    );
  }

  Widget _buildCalendarPanel(
    DateTime month, {
    required VoidCallback onPrev,
    required VoidCallback onNext,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          // Month Header with Navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 20, color: Color(0xFF475569)),
                onPressed: onPrev,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    DateFormat('MMMM yyyy').format(month),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFF475569)),
                onPressed: onNext,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Day of Week Header Row (Su Mo Tu We Th Fr Sa)
          Row(
            children: const [
              Expanded(child: Center(child: Text('Su', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))))),
              Expanded(child: Center(child: Text('Mo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))))),
              Expanded(child: Center(child: Text('Tu', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))))),
              Expanded(child: Center(child: Text('We', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))))),
              Expanded(child: Center(child: Text('Th', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))))),
              Expanded(child: Center(child: Text('Fr', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))))),
              Expanded(child: Center(child: Text('Sa', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))))),
            ],
          ),
          const SizedBox(height: 6),

          // Days Grid (6 rows of 7 days)
          ..._buildMonthGrid(month),
        ],
      ),
    );
  }

  List<Widget> _buildMonthGrid(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final prevMonthDays = DateTime(month.year, month.month, 0).day;

    // Sunday = 0, Monday = 1, ..., Saturday = 6
    final leadingCount = firstDay.weekday % 7;
    final totalDaysShown = leadingCount + daysInMonth;
    final trailingCount = (7 - (totalDaysShown % 7)) % 7;
    final totalCells = totalDaysShown + trailingCount;

    final List<Widget> rows = [];
    List<Widget> currentRow = [];

    for (int i = 0; i < totalCells; i++) {
      DateTime cellDate;
      bool isCurrentMonth = true;

      if (i < leadingCount) {
        // Leading day from previous month
        final day = prevMonthDays - leadingCount + 1 + i;
        cellDate = DateTime(month.year, month.month - 1, day);
        isCurrentMonth = false;
      } else if (i < leadingCount + daysInMonth) {
        // Current month day
        final day = i - leadingCount + 1;
        cellDate = DateTime(month.year, month.month, day);
      } else {
        // Trailing day from next month
        final day = i - (leadingCount + daysInMonth) + 1;
        cellDate = DateTime(month.year, month.month + 1, day);
        isCurrentMonth = false;
      }

      currentRow.add(Expanded(child: _buildDayCell(cellDate, isCurrentMonth: isCurrentMonth)));

      if (currentRow.length == 7) {
        rows.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(children: currentRow),
          ),
        );
        currentRow = [];
      }
    }

    return rows;
  }

  Widget _buildDayCell(DateTime date, {required bool isCurrentMonth}) {
    final isSameFrom = _fromDate.year == date.year && _fromDate.month == date.month && _fromDate.day == date.day;
    final isSameTo = _toDate.year == date.year && _toDate.month == date.month && _toDate.day == date.day;
    final isBetween = date.isAfter(_fromDate) && date.isBefore(_toDate);

    final isStart = isSameFrom;
    final isEnd = isSameTo;
    final isSinglePoint = isStart && isEnd;

    Color textColor;
    if (isStart || isEnd) {
      textColor = Colors.white;
    } else if (!isCurrentMonth) {
      textColor = const Color(0xFFCBD5E1);
    } else if (isBetween) {
      textColor = const Color(0xFF1E293B);
    } else {
      textColor = const Color(0xFF1E293B);
    }

    return InkWell(
      onTap: () => _onDateTapped(date),
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Range Band Background Strip
          if (isBetween)
            Container(
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFFEFF6FF),
              ),
            ),

          if (isStart && !isSinglePoint)
            Positioned.fill(
              child: Row(
                children: [
                  const Expanded(child: SizedBox()),
                  Expanded(
                    child: Container(
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEFF6FF),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (isEnd && !isSinglePoint)
            Positioned.fill(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEFF6FF),
                      ),
                    ),
                  ),
                  const Expanded(child: SizedBox()),
                ],
              ),
            ),

          // Date Cell Node / Button
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: (isStart || isEnd) ? const Color(0xFF2563EB) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: (isStart || isEnd || isBetween) ? FontWeight.w800 : FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
