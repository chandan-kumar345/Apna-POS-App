import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CalendarPopupCard extends StatefulWidget {
  final DateTime initialStartDate;
  final DateTime initialEndDate;
  final ValueChanged<DateTimeRange> onRangeSelected;
  final VoidCallback? onApply;

  const CalendarPopupCard({
    super.key,
    required this.initialStartDate,
    required this.initialEndDate,
    required this.onRangeSelected,
    this.onApply,
  });

  @override
  State<CalendarPopupCard> createState() => _CalendarPopupCardState();
}

class _CalendarPopupCardState extends State<CalendarPopupCard> {
  late DateTime _month;
  late DateTime _fromDate;
  late DateTime _toDate;
  bool _isSelectingFrom = true;

  @override
  void initState() {
    super.initState();
    _fromDate = DateTime(widget.initialStartDate.year, widget.initialStartDate.month, widget.initialStartDate.day);
    _toDate = DateTime(widget.initialEndDate.year, widget.initialEndDate.month, widget.initialEndDate.day);
    _month = DateTime(_fromDate.year, _fromDate.month, 1);
  }

  void _onDayTapped(DateTime date) {
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

    final range = DateTimeRange(
      start: DateTime(_fromDate.year, _fromDate.month, _fromDate.day, 0, 0, 0),
      end: DateTime(_toDate.year, _toDate.month, _toDate.day, 23, 59, 59, 999),
    );
    widget.onRangeSelected(range);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 295,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1E000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Month Header Navigation: < September 2026 >
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 20, color: Color(0xFF334155)),
                onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1, 1)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    DateFormat('MMMM yyyy').format(_month),
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFF334155)),
                onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1, 1)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Days of Week Row: Su Mo Tu We Th Fr Sa
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

          // Days Grid (Image 1)
          ..._buildMonthGrid(_month),

          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 8),

          // Bottom Action Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${DateFormat('dd MMM').format(_fromDate)} - ${DateFormat('dd MMM yyyy').format(_toDate)}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              if (widget.onApply != null)
                ElevatedButton(
                  onPressed: widget.onApply,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    minimumSize: const Size(54, 26),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: const Text('Apply', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMonthGrid(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final prevMonthDays = DateTime(month.year, month.month, 0).day;

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
        final day = prevMonthDays - leadingCount + 1 + i;
        cellDate = DateTime(month.year, month.month - 1, day);
        isCurrentMonth = false;
      } else if (i < leadingCount + daysInMonth) {
        final day = i - leadingCount + 1;
        cellDate = DateTime(month.year, month.month, day);
      } else {
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
    } else {
      textColor = const Color(0xFF0F172A);
    }

    return InkWell(
      onTap: () => _onDayTapped(date),
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Light Blue Connected Band (Image 1)
          if (isBetween)
            Container(
              height: 30,
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
                      height: 30,
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
                      height: 30,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEFF6FF),
                      ),
                    ),
                  ),
                  const Expanded(child: SizedBox()),
                ],
              ),
            ),

          // Date Node Badge
          Container(
            width: 30,
            height: 30,
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
