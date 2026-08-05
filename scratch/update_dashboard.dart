import 'dart:io';

void main() {
  final file = File('lib/features/dashboard/dashboard_screen.dart');
  String content = file.readAsStringSync();

  // 1. Add _dashboardFilter and _filterOrders
  content = content.replaceFirst(
    "String _orderSummaryFilter = 'Today';",
    "String _dashboardFilter = 'Today';\n\n"
    "  List<OrderModel> _filterOrders(List<OrderModel> source, String period) {\n"
    "    if (period == 'All Time') return source;\n"
    "    final now = DateTime.now();\n"
    "    return source.where((o) {\n"
    "      if (o.createdAt == null || o.createdAt!.isEmpty) return true;\n"
    "      DateTime? dt = DateTime.tryParse(o.createdAt!);\n"
    "      if (dt == null) return period == 'Today';\n"
    "      if (period == 'Today') {\n"
    "        return dt.year == now.year && dt.month == now.month && dt.day == now.day;\n"
    "      } else if (period == 'This Week') {\n"
    "        final diff = now.difference(dt).inDays;\n"
    "        return diff >= 0 && diff <= 7;\n"
    "      } else if (period == 'This Month') {\n"
    "        return dt.year == now.year && dt.month == now.month;\n"
    "      }\n"
    "      return true;\n"
    "    }).toList();\n"
    "  }"
  );

  // Remove unused filter states
  content = content.replaceFirst("  String _userSummaryFilter = 'Today';\n", "");
  content = content.replaceFirst("  String _trendFilter = 'This Week';\n", "");
  content = content.replaceFirst("  String _topSellingFilter = 'Today';\n", "");
  content = content.replaceFirst("  String _lowSellingFilter = 'Today';\n", "");

  // 2. Update _buildDropdownPill definition
  final pillOld = '''Widget _buildDropdownPill({
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.65),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 14,
            color: Color(0xFF64748B),
          ),
        ],
      ),
    );
  }''';

  final pillNew = '''Widget _buildDropdownPill({
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return PopupMenuButton<String>(
      initialValue: value,
      onSelected: onChanged,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'Today', child: Text('Today')),
        PopupMenuItem(value: 'This Week', child: Text('This Week')),
        PopupMenuItem(value: 'This Month', child: Text('This Month')),
        PopupMenuItem(value: 'All Time', child: Text('All Time')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.65),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 14,
              color: Color(0xFF64748B),
            ),
          ],
        ),
      ),
    );
  }''';
  content = content.replaceFirst(pillOld, pillNew);

  // 3. Update Order Summary Pill
  content = content.replaceFirst("value: _orderSummaryFilter,", "value: _dashboardFilter,");
  content = content.replaceFirst("onChanged: (val) => setState(() => _orderSummaryFilter = val),", "onChanged: (val) => setState(() => _dashboardFilter = val),");

  // 4. Update Top Selling Pill
  content = content.replaceFirst("value: _topSellingFilter,", "value: _dashboardFilter,");
  content = content.replaceFirst("onChanged: (val) => setState(() => _topSellingFilter = val),", "onChanged: (val) => setState(() => _dashboardFilter = val),");

  // 5. Update _buildSectionHeader to use and update _dashboardFilter
  content = content.replaceFirst("Widget _buildSectionHeader(String title) {", "Widget _buildSectionHeader(String title, {bool showFilter = true}) {");
  content = content.replaceFirst(
'''            _buildDropdownPill(
              value: 'Today',
              onChanged: (val) {},
            ),''',
'''            if (showFilter) _buildDropdownPill(
              value: _dashboardFilter,
              onChanged: (val) => setState(() => _dashboardFilter = val),
            ),'''
  );

  // 6. Update data logic to use filtered orders
  content = content.replaceAll(
    "final paidOrders = _db.orders.where((o) => o.status == OrderStatus.completed).toList();",
    "final paidOrders = _filterOrders(_db.orders.where((o) => o.status == OrderStatus.completed).toList(), _dashboardFilter);"
  );

  // _buildOrderStatistics has its own loop:
  content = content.replaceFirst(
    "    int success = 0, cancelled = 0, comp = 0;\n    for (var o in _db.orders) {",
    "    int success = 0, cancelled = 0, comp = 0;\n    final filteredStatsOrders = _filterOrders(_db.orders, _dashboardFilter);\n    for (var o in filteredStatsOrders) {"
  );

  file.writeAsStringSync(content);
}
