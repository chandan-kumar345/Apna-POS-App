import 'package:flutter/material.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/glass_widgets.dart';
import '../../core/database/database_service.dart';
import '../../core/models/table_model.dart';
import '../../core/models/order_model.dart';

class TableManagementScreen extends StatefulWidget {
  final Function(String tableName)? onTakeOrder;

  const TableManagementScreen({super.key, this.onTakeOrder});

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

  void _showAddTableDialog() {
    final nameCtrl = TextEditingController(text: 'T-${db.tables.length + 1}');
    final floorCtrl = TextEditingController(text: _selectedFloor == 'All Floors' ? 'Ground Floor' : _selectedFloor);
    final capacityCtrl = TextEditingController(text: '4');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            child: GlassContainer(
              padding: const EdgeInsets.all(20),
              borderRadius: 20,
              blurStrength: 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.table_restaurant_rounded, color: GlassTheme.primaryCyan, size: 24),
                      SizedBox(width: 8),
                      Text('Add New Dining Table', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  GlassTextField(controller: nameCtrl, hintText: 'Table Name (e.g. T-13)', prefixIcon: Icons.chair_rounded),
                  const SizedBox(height: 10),
                  GlassTextField(controller: floorCtrl, hintText: 'Floor / Area', prefixIcon: Icons.layers_outlined),
                  const SizedBox(height: 10),
                  GlassTextField(controller: capacityCtrl, hintText: 'Seating Capacity', prefixIcon: Icons.people_outline, keyboardType: TextInputType.number),
                  const SizedBox(height: 16),
                  GlassButton(
                    label: 'Create Table',
                    icon: Icons.add,
                    onPressed: () {
                      final cap = int.tryParse(capacityCtrl.text) ?? 4;
                      db.addTable(nameCtrl.text, floorCtrl.text, cap);
                      setState(() {});
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showTableActionDialog(TableModel table) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.transparent,
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            child: GlassContainer(
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
          color: isCurrent ? color.withOpacity(0.25) : GlassTheme.glassInput,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isCurrent ? color : GlassTheme.glassBorder),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: isCurrent ? Colors.white : GlassTheme.textMedium, fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500, fontSize: 13),
              ),
            ),
            if (isCurrent) Icon(Icons.check_circle, color: color, size: 18),
          ],
        ),
      ),
    );
  }

  void _showViewTableProductsModal(TableModel table) {
    final activeOrder = db.orders.where((o) => o.tableNumber == table.name && (o.status == OrderStatus.pending || o.status == OrderStatus.preparing)).firstOrNull;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.transparent,
          contentPadding: EdgeInsets.zero,
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 550),
            child: GlassContainer(
              padding: const EdgeInsets.all(22),
              borderRadius: 22,
              blurStrength: 24,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Assigned Products — ${table.name}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: GlassTheme.textMedium),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Floor: ${table.floor} • Capacity: ${table.capacity} Persons', style: const TextStyle(color: GlassTheme.textMedium, fontSize: 12)),
                  const SizedBox(height: 12),
                  const Divider(color: GlassTheme.glassBorder, height: 1),
                  const SizedBox(height: 12),

                  Expanded(
                    child: activeOrder == null || activeOrder.items.isEmpty
                        ? const Center(
                            child: Text('Table is occupied (Order in process)', style: TextStyle(color: GlassTheme.textMedium)),
                          )
                        : ListView.builder(
                            itemCount: activeOrder.items.length,
                            itemBuilder: (context, idx) {
                              final item = activeOrder.items[idx];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: GlassContainer(
                                  padding: const EdgeInsets.all(12),
                                  borderRadius: 12,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('${item.quantity}x ${item.item.name}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                      Text('₹${item.totalPrice.toStringAsFixed(2)}', style: const TextStyle(color: GlassTheme.accentNeonGreen, fontWeight: FontWeight.bold, fontSize: 13)),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: GlassButton(
                          label: 'Add / Modify Items',
                          icon: Icons.add_shopping_cart,
                          isPrimary: false,
                          onPressed: () {
                            Navigator.pop(context);
                            if (widget.onTakeOrder != null) {
                              widget.onTakeOrder!(table.name);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GlassButton(
                          label: 'Free / Clear Table',
                          icon: Icons.cleaning_services_outlined,
                          isPrimary: true,
                          onPressed: () {
                            db.updateTableStatus(table.id, TableStatus.free);
                            Navigator.pop(context);
                            setState(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: db,
      builder: (context, _) {
        final freeCount = db.tables.where((t) => t.status == TableStatus.free).length;
        final occupiedCount = db.tables.where((t) => t.status == TableStatus.occupied).length;
        final billedCount = db.tables.where((t) => t.status == TableStatus.billed).length;
        final reservedCount = db.tables.where((t) => t.status == TableStatus.reserved).length;

        return SafeArea(
          child: Column(
            children: [
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

        // Floor Filter Tabs & Add Table Action
        Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
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
            ),
            const SizedBox(width: 8),
            GlassButton(
              label: '+ Add Table',
              icon: Icons.add_rounded,
              height: 34,
              onPressed: _showAddTableDialog,
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Floor Tables Grid
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 160,
              childAspectRatio: 0.72,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: filteredTables.length,
            itemBuilder: (context, idx) {
              final table = filteredTables[idx];
              final statusColor = _getStatusColor(table.status);

              return GlassCard(
                padding: const EdgeInsets.all(8),
                borderColor: statusColor.withOpacity(0.6),
                hoverColor: statusColor.withOpacity(0.15),
                onTap: () => _showTableActionDialog(table),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            table.name,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Dropdown Status Selector (Requirement 6)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                          decoration: BoxDecoration(
                            color: GlassTheme.glassInput,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: statusColor.withOpacity(0.6)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<TableStatus>(
                              value: table.status,
                              dropdownColor: const Color(0xFF1E1B4B),
                              isDense: true,
                              icon: const Icon(Icons.arrow_drop_down, color: Colors.white, size: 14),
                              items: TableStatus.values.map((s) {
                                return DropdownMenuItem(
                                  value: s,
                                  child: Text(
                                    s.name.toUpperCase(),
                                    style: TextStyle(color: _getStatusColor(s), fontSize: 8.5, fontWeight: FontWeight.bold),
                                  ),
                                );
                              }).toList(),
                              onChanged: (newStatus) {
                                if (newStatus != null) {
                                  db.updateTableStatus(table.id, newStatus);
                                  setState(() {});
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            table.floor,
                            style: const TextStyle(color: GlassTheme.textMedium, fontSize: 10.5),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (table.occupiedSince != null)
                          Row(
                            children: [
                              const Icon(Icons.timer_outlined, color: GlassTheme.accentAmber, size: 11),
                              const SizedBox(width: 2),
                              Text(
                                table.occupiedSince!,
                                style: const TextStyle(color: GlassTheme.accentAmber, fontSize: 9.5, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Row(
                            children: [
                              const Icon(Icons.person_outline, color: GlassTheme.textMedium, size: 13),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  '${table.capacity} Seats',
                                  style: const TextStyle(color: Colors.white, fontSize: 10.5),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Bounded View vs Cart Button (Requirement 3 & 9)
                        if (table.status == TableStatus.occupied || table.status == TableStatus.billed || table.currentOrderId != null)
                          Container(
                            decoration: BoxDecoration(
                              color: GlassTheme.primaryCyan.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: GlassTheme.primaryCyan),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.visibility_outlined, color: Colors.white, size: 15),
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(5),
                              tooltip: 'View Products on ${table.name}',
                              onPressed: () => _showViewTableProductsModal(table),
                            ),
                          )
                        else
                          Container(
                            decoration: BoxDecoration(
                              color: GlassTheme.accentNeonGreen.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: GlassTheme.accentNeonGreen),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: 15),
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(5),
                              tooltip: 'Take Order in POS',
                              onPressed: () {
                                if (widget.onTakeOrder != null) {
                                  widget.onTakeOrder!(table.name);
                                }
                              },
                            ),
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
        },
      );
    }
}
