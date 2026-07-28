import 'package:flutter/material.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/glass_widgets.dart';
import '../../core/database/database_service.dart';
import '../../core/models/table_model.dart';

class TableManagementScreen extends StatefulWidget {
  const TableManagementScreen({super.key});

  @override
  State<TableManagementScreen> createState() => _TableManagementScreenState();
}

class _TableManagementScreenState extends State<TableManagementScreen> {
  final db = DatabaseService();
  String _selectedFloor = 'All Floors';

  List<String> get floors {
    final list = ['All Floors'];
    for (var t in db.tables) {
      if (!list.contains(t.floor)) {
        list.add(t.floor);
      }
    }
    return list;
  }

  List<TableModel> get filteredTables {
    if (_selectedFloor == 'All Floors') return db.tables;
    return db.tables.where((t) => t.floor == _selectedFloor).toList();
  }

  Color _getStatusColor(TableStatus status) {
    switch (status) {
      case TableStatus.free:
        return GlassTheme.statusFree;
      case TableStatus.occupied:
        return GlassTheme.statusOccupied;
      case TableStatus.billed:
        return GlassTheme.statusBilled;
      case TableStatus.reserved:
        return GlassTheme.statusReserved;
    }
  }

  void _showTableActionDialog(TableModel table) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.transparent,
        content: GlassContainer(
          padding: const EdgeInsets.all(24),
          borderRadius: 20,
          blurStrength: 24,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Manage ${table.name}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              Text(
                '${table.floor} • Capacity: ${table.capacity} Persons',
                style: const TextStyle(fontSize: 12, color: GlassTheme.textMedium),
              ),
              const SizedBox(height: 16),

              _buildStatusOption(table, TableStatus.free, 'Mark as Free / Clear Table', Icons.check_circle_outline),
              const SizedBox(height: 8),
              _buildStatusOption(table, TableStatus.occupied, 'Mark Occupied (Seated)', Icons.people_outline),
              const SizedBox(height: 8),
              _buildStatusOption(table, TableStatus.billed, 'Mark Billed (Awaiting Payment)', Icons.receipt_outlined),
              const SizedBox(height: 8),
              _buildStatusOption(table, TableStatus.reserved, 'Mark Reserved', Icons.bookmark_outline),

              const SizedBox(height: 18),
              GlassButton(
                label: 'Close',
                isPrimary: false,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusOption(TableModel table, TableStatus status, String label, IconData icon) {
    final color = _getStatusColor(status);
    final isCurrent = table.status == status;

    return InkWell(
      onTap: () {
        db.updateTableStatus(table.id, status);
        setState(() {});
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isCurrent ? color.withOpacity(0.3) : GlassTheme.glassInput,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isCurrent ? color : GlassTheme.glassBorder),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isCurrent ? Colors.white : GlassTheme.textMedium,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ),
            if (isCurrent) Icon(Icons.check, color: color, size: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final freeCount = db.tables.where((t) => t.status == TableStatus.free).length;
    final occupiedCount = db.tables.where((t) => t.status == TableStatus.occupied).length;
    final billedCount = db.tables.where((t) => t.status == TableStatus.billed).length;
    final reservedCount = db.tables.where((t) => t.status == TableStatus.reserved).length;

    return SafeArea(
      child: Column(
      children: [
        // Stats Row wrapped in Horizontal Scroll to prevent RenderFlex overflow
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              SizedBox(
                width: 220,
                child: GlassStatCard(
                  title: 'Free Tables',
                  value: '$freeCount',
                  subtitle: 'Ready for Guests',
                  icon: Icons.check_circle_rounded,
                  color: GlassTheme.statusFree,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 220,
                child: GlassStatCard(
                  title: 'Occupied',
                  value: '$occupiedCount',
                  subtitle: 'Dining in Progress',
                  icon: Icons.people_alt_rounded,
                  color: GlassTheme.statusOccupied,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 220,
                child: GlassStatCard(
                  title: 'Billed Tables',
                  value: '$billedCount',
                  subtitle: 'Payment Pending',
                  icon: Icons.receipt_long_rounded,
                  color: GlassTheme.statusBilled,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 220,
                child: GlassStatCard(
                  title: 'Reserved',
                  value: '$reservedCount',
                  subtitle: 'Advance Booking',
                  icon: Icons.bookmark_added_rounded,
                  color: GlassTheme.statusReserved,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Floor Filter Tabs
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              const Text(
                'Select Floor:',
                style: TextStyle(color: GlassTheme.textMedium, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 10),
              ...floors.map((flr) {
                final isSel = _selectedFloor == flr;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(flr),
                    labelStyle: TextStyle(color: isSel ? Colors.white : GlassTheme.textMedium, fontWeight: isSel ? FontWeight.bold : FontWeight.w500, fontSize: 12),
                    selected: isSel,
                    selectedColor: GlassTheme.primaryViolet,
                    backgroundColor: GlassTheme.glassInput,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: isSel ? GlassTheme.primaryViolet : GlassTheme.glassBorder),
                    onSelected: (_) => setState(() => _selectedFloor = flr),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Floor Tables Grid
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              childAspectRatio: 1.1,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: filteredTables.length,
            itemBuilder: (context, idx) {
              final table = filteredTables[idx];
              final statusColor = _getStatusColor(table.status);

              return GlassCard(
                padding: const EdgeInsets.all(14),
                borderColor: statusColor.withOpacity(0.6),
                hoverColor: statusColor.withOpacity(0.15),
                onTap: () => _showTableActionDialog(table),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          table.name,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        GlassBadge(
                          label: table.status.name.toUpperCase(),
                          color: statusColor,
                          fontSize: 9,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      table.floor,
                      style: const TextStyle(color: GlassTheme.textMedium, fontSize: 11),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person_outline, color: GlassTheme.textMedium, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '${table.capacity} Seats',
                              style: const TextStyle(color: Colors.white, fontSize: 11),
                            ),
                          ],
                        ),
                        if (table.occupiedSince != null)
                          Row(
                            children: [
                              const Icon(Icons.timer_outlined, color: GlassTheme.accentAmber, size: 12),
                              const SizedBox(width: 2),
                              Text(
                                table.occupiedSince!,
                                style: const TextStyle(color: GlassTheme.accentAmber, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}
}
