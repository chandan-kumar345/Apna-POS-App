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

class _TableManagementScreenState extends State<TableManagementScreen> with AutomaticKeepAliveClientMixin {
  final db = DatabaseService();
  String _selectedFloor = 'All Floors';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Non-blocking sync if table list is empty
    if (db.tables.isEmpty) {
      db.syncWithBackend();
    }
  }

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

    // Sequence tables strictly in natural numerical order
    list.sort((a, b) {
      final numA = a.tableNumber > 0
          ? a.tableNumber
          : (int.tryParse(a.name.replaceAll(RegExp(r'[^0-9]'), '')) ?? 9999);
      final numB = b.tableNumber > 0
          ? b.tableNumber
          : (int.tryParse(b.name.replaceAll(RegExp(r'[^0-9]'), '')) ?? 9999);
      if (numA != numB) {
        return numA.compareTo(numB);
      }
      return a.name.compareTo(b.name);
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
      );
    }
  }

  void _showAddTableDialog() {
    final nameCtrl = TextEditingController(text: 'T-${db.tables.length + 1}');
    final floorCtrl = TextEditingController(text: _selectedFloor == 'All Floors' ? 'Ground Floor' : _selectedFloor);
    final existingFloors = floors.where((f) => f != 'All Floors').toList();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final screenWidth = MediaQuery.of(context).size.width;

            return Dialog(
              backgroundColor: Colors.white,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              elevation: 12,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: screenWidth >= 650 ? 580 : screenWidth * 0.94,
                  minWidth: 320,
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF051C48).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.table_restaurant_rounded, color: Color(0xFF051C48), size: 24),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Add Dining Table',
                                  style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w900, fontSize: 18),
                                ),
                                Text(
                                  'Enter table name and assign a dining floor or area',
                                  style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(dialogCtx),
                            icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                            tooltip: 'Close',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Color(0xFFE2E8F0), height: 1),
                      const SizedBox(height: 16),

                      // Scrollable Wrapped Content
                      Flexible(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Table Name / Number Field
                              const Text(
                                'Table Name / Number*',
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: nameCtrl,
                                style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.w600),
                                decoration: InputDecoration(
                                  hintText: 'e.g. T-13, Table 13, VIP-1',
                                  prefixIcon: const Icon(Icons.chair_rounded, color: Color(0xFF051C48), size: 20),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF051C48), width: 2)),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Floor / Area Field & Quick Select Pills
                              const Text(
                                'Floor / Dining Area*',
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(height: 6),
                              if (existingFloors.isNotEmpty) ...[
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: existingFloors.map((fl) {
                                    final isSel = floorCtrl.text.trim().toLowerCase() == fl.toLowerCase();
                                    return ChoiceChip(
                                      label: Text(fl),
                                      selected: isSel,
                                      selectedColor: const Color(0xFF051C48),
                                      labelStyle: TextStyle(
                                        color: isSel ? Colors.white : const Color(0xFF334155),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      onSelected: (_) {
                                        setDialogState(() => floorCtrl.text = fl);
                                      },
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 8),
                              ],
                              TextField(
                                controller: floorCtrl,
                                style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.w600),
                                decoration: InputDecoration(
                                  hintText: 'e.g. Ground Floor, Terrace, 1st Floor, Rooftop',
                                  prefixIcon: const Icon(Icons.layers_outlined, color: Color(0xFF051C48), size: 20),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF051C48), width: 2)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Color(0xFFE2E8F0), height: 1),
                      const SizedBox(height: 16),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(dialogCtx),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final name = nameCtrl.text.trim();
                                final floor = floorCtrl.text.trim().isEmpty ? 'Ground Floor' : floorCtrl.text.trim();
                                await db.addTable(name, floor, 4, count: 1);
                                if (dialogCtx.mounted) {
                                  Navigator.pop(dialogCtx);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF051C48),
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 2,
                              ),
                              icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                              label: const Text(
                                'Create Table',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
                                : db.orders.where((o) => isSameTable(o.tableNumber, table.name) && (o.status == OrderStatus.pending || o.status == OrderStatus.preparing)).firstOrNull;
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
