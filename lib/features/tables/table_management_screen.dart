import 'package:flutter/material.dart';
import '../../core/database/database_service.dart';
import '../../core/models/table_model.dart';
import '../../core/models/order_model.dart';
import '../pos/pos_register_screen.dart';

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
    List<TableModel> list = _selectedFloor == 'All Floors'
        ? List.from(db.tables)
        : db.tables.where((t) => t.floor == _selectedFloor).toList();

    // Sequence tables strictly floor-wise then table number wise
    list.sort((a, b) {
      int c = a.floor.compareTo(b.floor);
      if (c != 0) return c;
      return a.tableNumber.compareTo(b.tableNumber);
    });

    return list;
  }

  Color _getStatusColor(TableStatus? status) {
    if (status == null) return const Color(0xFF10B981);
    switch (status) {
      case TableStatus.free:
        return const Color(0xFF10B981); // Emerald Green
      case TableStatus.occupied:
        return const Color(0xFF051C48); // Deep Navy
      case TableStatus.runningKot:
        return const Color(0xFFEF4444); // Red Color for Running KOT!
      case TableStatus.reserved:
        return const Color(0xFF8B5CF6); // Purple
      default:
        return const Color(0xFF10B981);
    }
  }

  String _getStatusLabel(TableStatus? status) {
    if (status == null) return 'Free';
    switch (status) {
      case TableStatus.free:
        return 'Free';
      case TableStatus.occupied:
        return 'Occupied';
      case TableStatus.runningKot:
        return 'KOT Running';
      case TableStatus.reserved:
        return 'Reserved';
      default:
        return 'Free';
    }
  }

  void _openPosForTable(String tableName) {
    if (widget.onTakeOrder != null) {
      widget.onTakeOrder!(tableName);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PosRegisterScreen(initialTable: tableName),
        ),
      ).then((_) => setState(() {}));
    }
  }

  void _showAddTableDialog() {
    final nameCtrl = TextEditingController(text: 'T-${db.tables.length + 1}');
    final floorCtrl = TextEditingController(text: _selectedFloor == 'All Floors' ? 'Ground Floor' : _selectedFloor);
    final capacityCtrl = TextEditingController(text: '4');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.table_restaurant_rounded, color: Color(0xFF051C48), size: 24),
            SizedBox(width: 8),
            Text('Add New Dining Table', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Table Name*', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 4),
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Table Name (e.g. T-13)',
                prefixIcon: const Icon(Icons.chair_rounded, color: Color(0xFF051C48)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF051C48), width: 2)),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Floor / Area*', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 4),
            TextField(
              controller: floorCtrl,
              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Floor / Area (e.g. Ground Floor, Terrace)',
                prefixIcon: const Icon(Icons.layers_outlined, color: Color(0xFF051C48)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF051C48), width: 2)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () {
              final cap = int.tryParse(capacityCtrl.text) ?? 4;
              db.addTable(nameCtrl.text, floorCtrl.text, cap);
              setState(() {});
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF051C48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Create Table', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: db,
      builder: (context, _) {
        final freeCount = db.tables.where((t) => t.status == TableStatus.free).length;
        final occupiedCount = db.tables.where((t) => t.status == TableStatus.occupied).length;
        final kotCount = db.tables.where((t) => t.status == TableStatus.runningKot).length;
        final reservedCount = db.tables.where((t) => t.status == TableStatus.reserved).length;

        final Map<String, List<TableModel>> tablesByFloor = {};
        for (var t in filteredTables) {
          tablesByFloor.putIfAbsent(t.floor, () => []).add(t);
        }

        return Material(
          color: Colors.transparent,
          child: SafeArea(
            child: Column(
            children: [
              // Stats Bar
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildStatCard('Free Tables', '$freeCount', 'Ready for Guests', Icons.check_circle_rounded, const Color(0xFF10B981)),
                    const SizedBox(width: 8),
                    _buildStatCard('Occupied', '$occupiedCount', 'Seated & Ordering', Icons.people_alt_rounded, const Color(0xFF051C48)),
                    const SizedBox(width: 8),
                    _buildStatCard('Running KOT', '$kotCount', 'In Kitchen Prep', Icons.soup_kitchen_rounded, const Color(0xFFEF4444)),
                    const SizedBox(width: 8),
                    _buildStatCard('Reserved', '$reservedCount', 'Advance Booking', Icons.bookmark_added_rounded, const Color(0xFF8B5CF6)),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Floor Filter Tabs & DECREASED WIDTH "+ Add Table" Button
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          const Text(
                            'Floor:',
                            style: TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 6),
                          ...floors.map((flr) {
                            final isSel = _selectedFloor == flr;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(flr),
                                labelStyle: TextStyle(color: isSel ? Colors.white : const Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 12),
                                selected: isSel,
                                selectedColor: const Color(0xFF051C48),
                                backgroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                side: BorderSide(color: isSel ? const Color(0xFF051C48) : const Color(0xFFCBD5E1)),
                                onSelected: (_) => setState(() => _selectedFloor = flr),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // DECREASED WIDTH "+ ADD TABLE" BUTTON
                  SizedBox(
                    height: 38,
                    child: ElevatedButton.icon(
                      onPressed: _showAddTableDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF051C48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        elevation: 2,
                      ),
                      icon: const Icon(Icons.add_rounded, color: Colors.white, size: 16),
                      label: const Text('Add Table', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.5)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Floor-wise Sequenced Tables Grid View
              Expanded(
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: tablesByFloor.keys.length,
                  itemBuilder: (context, floorIdx) {
                    final floorName = tablesByFloor.keys.elementAt(floorIdx);
                    final floorTables = tablesByFloor[floorName]!;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Floor Section Header
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF051C48),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                floorName,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '(${floorTables.length} Tables)',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),

                        // Tables Grid for this Floor — Responsive column count
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final width = constraints.maxWidth;
                            final cols = width >= 600 ? 5 : width >= 420 ? 4 : 3;
                            return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cols,
                            childAspectRatio: 1.0,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemCount: floorTables.length,
                          itemBuilder: (context, idx) {
                            final table = floorTables[idx];

                            // Safely validate status against TableStatus values to prevent Dropdown assertion errors
                            final validStatus = TableStatus.values.contains(table.status) ? table.status : TableStatus.free;
                            final statusColor = _getStatusColor(validStatus);
                            final isRunningKot = validStatus == TableStatus.runningKot;

                            // Active order cart total amount (confirmed) or live pre-KOT cart total (FREE tables NEVER show amount)
                            final activeOrder = validStatus == TableStatus.free
                                ? null
                                : db.orders.where((o) => ((o.tableNumber?.trim().toLowerCase() ?? '') == table.name.trim().toLowerCase() || 'T-${o.tableNumber}'.toLowerCase() == table.name.trim().toLowerCase()) && (o.status == OrderStatus.pending || o.status == OrderStatus.preparing)).firstOrNull;
                            final confirmedAmount = activeOrder?.totalAmount ?? 0.0;
                            final liveAmount = validStatus == TableStatus.free ? 0.0 : db.getLiveCartTotal(table.name);
                            final activeAmount = validStatus == TableStatus.free ? 0.0 : (confirmedAmount > 0 ? confirmedAmount : liveAmount);
                            final hasProductsInCart = validStatus != TableStatus.free && activeAmount > 0;

                            return InkWell(
                              onTap: () => _openPosForTable(table.name),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16), // SEMI CURVED CORNERS BOX
                                  border: Border.all(color: statusColor, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: statusColor.withOpacity(0.15),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(7),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 1) DROPDOWN SELECTOR AT THE VERY TOP OF TABLE BOX (DISABLED IF RUNNING KOT)
                                    Container(
                                      height: 26,
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: statusColor.withOpacity(0.5)),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<TableStatus>(
                                          value: validStatus,
                                          dropdownColor: Colors.white,
                                          isDense: true,
                                          isExpanded: true,
                                          icon: Icon(Icons.arrow_drop_down, color: isRunningKot ? const Color(0xFFEF4444) : statusColor, size: 16),
                                          items: TableStatus.values.map((s) {
                                            final isKotOption = s == TableStatus.runningKot;
                                            return DropdownMenuItem(
                                              value: s,
                                              enabled: !isKotOption,
                                              child: Text(
                                                _getStatusLabel(s),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                softWrap: false,
                                                style: TextStyle(
                                                  color: _getStatusColor(s),
                                                  fontSize: 11, // LARGER FONT SIZE FOR RUNNING KOT TEXT
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 0.2,
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                          // DISABLE DROPDOWN COMPLETELY WHEN ORDER HAS RUNNING KOT
                                          onChanged: isRunningKot
                                              ? null
                                              : (newStatus) {
                                                  if (newStatus != null && newStatus != TableStatus.runningKot) {
                                                    db.updateTableStatus(table.id, newStatus);
                                                    setState(() {});
                                                  }
                                                },
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),

                                    // 2) TABLE NAME & FLOOR (NO GUEST NO)
                                    Text(
                                      table.name,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      table.floor,
                                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 9.5, fontWeight: FontWeight.w500),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),

                                    const Spacer(),

                                    // 3) CART AMOUNT MENTION & ONLY VIEW ICON / ADD TO CART ICON BUTTON
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        if (activeAmount > 0)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: statusColor.withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: statusColor.withOpacity(0.4)),
                                            ),
                                            child: Text(
                                              '${db.restaurant?.currencySymbol ?? "₹"}${activeAmount.toStringAsFixed(0)}',
                                              style: TextStyle(color: statusColor, fontWeight: FontWeight.w900, fontSize: 10),
                                            ),
                                          )
                                        else
                                          const Text(
                                            'No Order',
                                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 9.5, fontWeight: FontWeight.w600),
                                          ),

                                        // IF PRODUCTS IN CART: SHOW ONLY VIEW ICON. ELSE: SHOW GREEN ADD TO CART ICON
                                        if (hasProductsInCart)
                                          InkWell(
                                            onTap: () => _openPosForTable(table.name),
                                            borderRadius: BorderRadius.circular(8),
                                            child: Container(
                                              width: 26,
                                              height: 26,
                                              decoration: BoxDecoration(
                                                color: statusColor,
                                                borderRadius: BorderRadius.circular(8),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: statusColor.withOpacity(0.3),
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: const Icon(Icons.visibility_outlined, color: Colors.white, size: 16),
                                            ),
                                          )
                                        else
                                          InkWell(
                                            onTap: () => _openPosForTable(table.name),
                                            borderRadius: BorderRadius.circular(8),
                                            child: Container(
                                              width: 26,
                                              height: 26,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF10B981), // Emerald Green
                                                borderRadius: BorderRadius.circular(8),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: const Color(0xFF10B981).withOpacity(0.3),
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: 16),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                          },
                        ),
                        const SizedBox(height: 10),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  }

  Widget _buildStatCard(String title, String value, String subtitle, IconData icon, Color color) {
    return Container(
      width: 155,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16), // SEMI CURVED CORNERS BOX
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11.5, fontWeight: FontWeight.bold)),
              Icon(icon, color: color, size: 16),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 9.5)),
        ],
      ),
    );
  }
}
