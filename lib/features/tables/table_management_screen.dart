import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/database/database_service.dart';
import '../../core/models/table_model.dart';
import '../../core/models/order_model.dart';
import '../pos/pos_register_screen.dart';

class TableManagementScreen extends StatefulWidget {
  final Function(String tableName)? onTakeOrder;
  final Function(OrderType orderType)? onTakeOrderForType;

  const TableManagementScreen({
    super.key,
    this.onTakeOrder,
    this.onTakeOrderForType,
  });

  @override
  State<TableManagementScreen> createState() => _TableManagementScreenState();
}

class _TableManagementScreenState extends State<TableManagementScreen> with AutomaticKeepAliveClientMixin {
  final db = DatabaseService();
  String _selectedFloor = 'All Floors';
  final Set<String> _collapsedFloors = <String>{};

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

  @override
  void dispose() {
    super.dispose();
  }

  List<String> get floors {
    final list = ['All Floors'];
    for (var f in db.allFloors) {
      if (!list.contains(f)) {
        list.add(f);
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
        return const Color(0xFF2563EB); // Royal Blue
      case TableStatus.runningKot:
        return const Color(0xFFEF4444); // Red/Coral
      case TableStatus.reserved:
        return const Color(0xFF8B5CF6); // Purple
    }
  }

  Color _getStatusBg(TableStatus? status) {
    if (status == null) return const Color(0xFFE8FAF3);
    switch (status) {
      case TableStatus.free:
        return const Color(0xFFE8FAF3);
      case TableStatus.occupied:
        return const Color(0xFFEFF6FF);
      case TableStatus.runningKot:
        return const Color(0xFFFFF1F2);
      case TableStatus.reserved:
        return const Color(0xFFFAF5FF);
    }
  }

  Color _getStatusBorder(TableStatus? status) {
    if (status == null) return const Color(0xFFC7F3E2);
    switch (status) {
      case TableStatus.free:
        return const Color(0xFFC7F3E2);
      case TableStatus.occupied:
        return const Color(0xFFBFDBFE);
      case TableStatus.runningKot:
        return const Color(0xFFFECDD3);
      case TableStatus.reserved:
        return const Color(0xFFE9D5FF);
    }
  }

  IconData _getStatusIcon(TableStatus? status) {
    if (status == null) return Icons.chair_rounded;
    switch (status) {
      case TableStatus.free:
        return Icons.chair_rounded;
      case TableStatus.occupied:
        return Icons.people_alt_rounded;
      case TableStatus.runningKot:
        return Icons.soup_kitchen_rounded;
      case TableStatus.reserved:
        return Icons.calendar_today_rounded;
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

  void _openPosForOrderType(OrderType orderType) {
    if (widget.onTakeOrderForType != null) {
      widget.onTakeOrderForType!(orderType);
    } else if (widget.onTakeOrder != null) {
      widget.onTakeOrder!(orderType == OrderType.takeaway ? 'Takeaway' : 'Delivery');
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PosRegisterScreen(initialOrderType: orderType),
        ),
      );
    }
  }

  void _promptCreateNewFloor(BuildContext parentCtx, Function(String newFloor) onCreated) {
    final newFloorCtrl = TextEditingController();
    showDialog(
      context: parentCtx,
      builder: (promptCtx) {
        return Dialog(
          backgroundColor: const Color(0xFFEFF4FA),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 12,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2EDFB),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFCBD5E1).withValues(alpha: 0.7),
                              blurRadius: 4,
                              offset: const Offset(1.5, 2),
                            ),
                            const BoxShadow(
                              color: Colors.white,
                              blurRadius: 4,
                              offset: Offset(-1.5, -1.5),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.table_restaurant_rounded, color: Color(0xFF0B2253), size: 17),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Create New Floor',
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD6E2F0).withValues(alpha: 0.6),
                          blurRadius: 4,
                          offset: const Offset(1, 2),
                        ),
                        const BoxShadow(
                          color: Colors.white,
                          blurRadius: 4,
                          offset: Offset(-1, -1),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: newFloorCtrl,
                      autofocus: true,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A)),
                      decoration: const InputDecoration(
                        hintText: 'e.g. 2nd Floor, Rooftop, Garden',
                        hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => Navigator.pop(promptCtx),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFD6E2F0).withValues(alpha: 0.7),
                                  blurRadius: 4,
                                  offset: const Offset(1.5, 2),
                                ),
                                const BoxShadow(
                                  color: Colors.white,
                                  blurRadius: 4,
                                  offset: Offset(-1.5, -1.5),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final name = newFloorCtrl.text.trim();
                            if (name.isNotEmpty) {
                              await db.addCustomFloor(name);
                              onCreated(name);
                              if (promptCtx.mounted) {
                                Navigator.pop(promptCtx);
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0B2253),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                            elevation: 2,
                          ),
                          child: const Text('Create Floor', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
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

  void _showAddTableDialog() {
    final nextNum = db.tables.isEmpty
        ? 1
        : ((db.tables.map((t) => t.tableNumber).reduce((a, b) => a > b ? a : b)) + 1);
    final nameCtrl = TextEditingController(text: 'T-$nextNum');
    String selectedFloor = _selectedFloor == 'All Floors'
        ? (db.allFloors.isNotEmpty ? db.allFloors.first : 'Ground Floor')
        : _selectedFloor;
    final editFloorCtrl = TextEditingController(text: selectedFloor);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final screenWidth = MediaQuery.of(context).size.width;
            final availableFloors = db.allFloors;

            return Dialog(
              backgroundColor: const Color(0xFFEFF4FA),
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
              elevation: 16,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: screenWidth >= 650 ? 400 : screenWidth * 0.90,
                  minWidth: 280,
                  maxHeight: MediaQuery.of(context).size.height * 0.88,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Neumorphic Top Header
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2EDFB),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFCBD5E1).withValues(alpha: 0.7),
                                  blurRadius: 5,
                                  offset: const Offset(1.5, 2.5),
                                ),
                                const BoxShadow(
                                  color: Colors.white,
                                  blurRadius: 5,
                                  offset: Offset(-1.5, -1.5),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.table_restaurant_rounded, color: Color(0xFF0B2253), size: 20),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Add Dining Table',
                                  style: TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15.5,
                                  ),
                                ),
                                SizedBox(height: 1.5),
                                Text(
                                  'Enter table name and assign a dining floor or area',
                                  style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: () => Navigator.pop(dialogCtx),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFEFF4FA),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFCBD5E1).withValues(alpha: 0.7),
                                    blurRadius: 4,
                                    offset: const Offset(1.5, 2),
                                  ),
                                  const BoxShadow(
                                    color: Colors.white,
                                    blurRadius: 4,
                                    offset: Offset(-1.5, -1.5),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 16),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Content
                      Flexible(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. Table Name / Number Field
                              Row(
                                children: const [
                                  Text(
                                    'Table Name / Number',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                  ),
                                  Text(
                                    ' *',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFD6E2F0).withValues(alpha: 0.6),
                                      blurRadius: 4,
                                      offset: const Offset(1, 2),
                                    ),
                                    const BoxShadow(
                                      color: Colors.white,
                                      blurRadius: 4,
                                      offset: Offset(-1, -1),
                                    ),
                                  ],
                                ),
                                child: TextField(
                                  controller: nameCtrl,
                                  style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w700),
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                    prefixIcon: Container(
                                      margin: const EdgeInsets.only(left: 6, right: 8, top: 6, bottom: 6),
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE2EDFB),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.table_restaurant_rounded, color: Color(0xFF0B2253), size: 15),
                                    ),
                                    prefixIconConstraints: const BoxConstraints(minWidth: 38, maxHeight: 36),
                                    hintText: 'e.g. T-21',
                                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),

                              // 2. Floor / Dining Area Field & Selectable Cards (Horizontal Single-Row Layout)
                              Row(
                                children: const [
                                  Text(
                                    'Floor / Dining Area',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                  ),
                                  Text(
                                    ' *',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),

                              // Floor Cards Row + Plus button in the same line on the right
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                child: Row(
                                  children: [
                                    ...availableFloors.map((fl) {
                                      final isSel = selectedFloor.trim().toLowerCase() == fl.trim().toLowerCase();
                                      return Padding(
                                        padding: const EdgeInsets.only(right: 6),
                                        child: InkWell(
                                          onTap: () {
                                            setDialogState(() {
                                              selectedFloor = fl;
                                              editFloorCtrl.text = fl;
                                            });
                                          },
                                          borderRadius: BorderRadius.circular(14),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                            decoration: BoxDecoration(
                                              color: isSel ? const Color(0xFF0B2253) : const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(14),
                                              border: Border.all(
                                                color: isSel ? const Color(0xFF0B2253) : const Color(0xFFE2E8F0),
                                                width: 1,
                                              ),
                                              boxShadow: isSel
                                                  ? [
                                                      BoxShadow(
                                                        color: const Color(0xFF0B2253).withValues(alpha: 0.35),
                                                        blurRadius: 6,
                                                        offset: const Offset(1.5, 3),
                                                      ),
                                                    ]
                                                  : [
                                                      BoxShadow(
                                                        color: const Color(0xFFD6E2F0).withValues(alpha: 0.7),
                                                        blurRadius: 4,
                                                        offset: const Offset(1.5, 2.5),
                                                      ),
                                                      const BoxShadow(
                                                        color: Colors.white,
                                                        blurRadius: 4,
                                                        offset: Offset(-1.5, -1.5),
                                                      ),
                                                    ],
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.table_restaurant_rounded,
                                                  color: isSel ? Colors.white : const Color(0xFF0B2253),
                                                  size: 15,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  fl,
                                                  style: TextStyle(
                                                    color: isSel ? Colors.white : const Color(0xFF0F172A),
                                                    fontWeight: isSel ? FontWeight.bold : FontWeight.w700,
                                                    fontSize: 11.5,
                                                  ),
                                                ),
                                                if (isSel) ...[
                                                  const SizedBox(width: 6),
                                                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 14),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                    // Plus button placed on the right of the floor chips in the same line
                                    InkWell(
                                      key: const ValueKey('add_floor_button'),
                                      onTap: () => _promptCreateNewFloor(context, (newFloor) {
                                        setDialogState(() {
                                          selectedFloor = newFloor;
                                          editFloorCtrl.text = newFloor;
                                        });
                                      }),
                                      borderRadius: BorderRadius.circular(14),
                                      child: Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFFD6E2F0).withValues(alpha: 0.7),
                                              blurRadius: 4,
                                              offset: const Offset(1.5, 2.5),
                                            ),
                                            const BoxShadow(
                                              color: Colors.white,
                                              blurRadius: 4,
                                              offset: Offset(-1.5, -1.5),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(Icons.add_rounded, color: Color(0xFF0F172A), size: 20),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),

                              // 3. Edit Selected Floor Field (Full-width neumorphic field)
                              Row(
                                children: const [
                                  Icon(Icons.edit_note_rounded, size: 14, color: Color(0xFF64748B)),
                                  SizedBox(width: 3),
                                  Text(
                                    'Edit Selected Floor Name',
                                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Container(
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFD6E2F0).withValues(alpha: 0.5),
                                      blurRadius: 3,
                                      offset: const Offset(1, 1.5),
                                    ),
                                    const BoxShadow(
                                      color: Colors.white,
                                      blurRadius: 3,
                                      offset: Offset(-1, -1),
                                    ),
                                  ],
                                ),
                                child: TextField(
                                  key: const ValueKey('edit_floor_name_field'),
                                  controller: editFloorCtrl,
                                  style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12.5, fontWeight: FontWeight.w700),
                                  onChanged: (newName) async {
                                    final clean = newName.trim();
                                    if (clean.isNotEmpty && clean != selectedFloor) {
                                      final oldName = selectedFloor;
                                      await db.renameFloor(oldName, clean);
                                      setDialogState(() {
                                        selectedFloor = clean;
                                      });
                                    }
                                  },
                                  onSubmitted: (newName) async {
                                    final clean = newName.trim();
                                    if (clean.isNotEmpty && clean != selectedFloor) {
                                      final oldName = selectedFloor;
                                      await db.renameFloor(oldName, clean);
                                      setDialogState(() {
                                        selectedFloor = clean;
                                      });
                                    }
                                  },
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                                    prefixIcon: Icon(Icons.edit_rounded, size: 14, color: Color(0xFF64748B)),
                                    prefixIconConstraints: BoxConstraints(minWidth: 32, maxHeight: 36),
                                    hintText: 'Edit floor name',
                                    hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 4. Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => Navigator.pop(dialogCtx),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFD6E2F0).withValues(alpha: 0.7),
                                      blurRadius: 4,
                                      offset: const Offset(1.5, 2.5),
                                    ),
                                    const BoxShadow(
                                      color: Colors.white,
                                      blurRadius: 4,
                                      offset: Offset(-1.5, -1.5),
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 12.5),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              key: const ValueKey('create_table_submit_button'),
                              onTap: () async {
                                final name = nameCtrl.text.trim().isEmpty ? 'T-$nextNum' : nameCtrl.text.trim();
                                final floor = selectedFloor.trim().isEmpty ? 'Ground Floor' : selectedFloor.trim();
                                await db.addTable(name, floor, 4, count: 1);
                                if (dialogCtx.mounted) {
                                  Navigator.pop(dialogCtx);
                                }
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0B2253),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF0B2253).withValues(alpha: 0.35),
                                      blurRadius: 6,
                                      offset: const Offset(1.5, 3),
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.check_circle_rounded, color: Colors.white, size: 15),
                                    SizedBox(width: 4),
                                    Text(
                                      'Create Table',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
                                    ),
                                  ],
                                ),
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

  Widget _buildNeumorphicStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required Color valueColor,
    double? width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD6E2F0).withValues(alpha: 0.7),
            blurRadius: 6,
            offset: const Offset(1, 2),
          ),
          const BoxShadow(
            color: Colors.white,
            blurRadius: 5,
            offset: Offset(-1, -1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: width != null ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1.5),
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 0.5),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: iconColor.withValues(alpha: 0.12),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Icon(icon, color: iconColor, size: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildNeumorphicKpiRow(int freeCount, int runningKotCount, int occupiedCount, int reservedCount) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        // On mobile / narrow screens (< 520px), give each card an equal generous width
        // and allow smooth horizontal sliding! On wider screens, expand equally.
        final isNarrow = availableWidth < 520;
        final cardWidth = isNarrow ? ((availableWidth - 24) / 3.1).clamp(112.0, 135.0) : null;

        final cards = [
          _buildNeumorphicStatCard(
            title: 'Available',
            value: '$freeCount',
            subtitle: 'Ready',
            icon: Icons.chair_rounded,
            iconColor: const Color(0xFF10B981),
            iconBg: const Color(0xFFE6FDF4),
            valueColor: const Color(0xFF10B981),
            width: cardWidth,
          ),
          _buildNeumorphicStatCard(
            title: 'KOT Running',
            value: '$runningKotCount',
            subtitle: 'Kitchen',
            icon: Icons.soup_kitchen_rounded,
            iconColor: const Color(0xFFEF4444),
            iconBg: const Color(0xFFFFF1F2),
            valueColor: const Color(0xFFEF4444),
            width: cardWidth,
          ),
          _buildNeumorphicStatCard(
            title: 'Occupied',
            value: '$occupiedCount',
            subtitle: 'Dining',
            icon: Icons.people_alt_rounded,
            iconColor: const Color(0xFF2563EB),
            iconBg: const Color(0xFFEFF6FF),
            valueColor: const Color(0xFF2563EB),
            width: cardWidth,
          ),
          _buildNeumorphicStatCard(
            title: 'Reserved',
            value: '$reservedCount',
            subtitle: 'Upcoming',
            icon: Icons.calendar_today_rounded,
            iconColor: const Color(0xFF8B5CF6),
            iconBg: const Color(0xFFFAF5FF),
            valueColor: const Color(0xFF8B5CF6),
            width: cardWidth,
          ),
        ];

        if (isNarrow) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                for (int i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  cards[i],
                ],
              ],
            ),
          );
        }

        return Row(
          children: [
            for (int i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(child: cards[i]),
            ],
          ],
        );
      },
    );
  }

  Widget _buildViewAndFloorBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          const Text(
            'View:',
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 6),
          ...floors.map((flr) {
            final isSel = _selectedFloor == flr;
            final isAll = flr == 'All Floors';
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InkWell(
                onTap: () => setState(() => _selectedFloor = flr),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSel ? const Color(0xFF0B2253) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: isSel
                        ? [
                            BoxShadow(
                              color: const Color(0xFF0B2253).withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: const Color(0xFFD6E2F0).withValues(alpha: 0.6),
                              blurRadius: 5,
                              offset: const Offset(0, 1.5),
                            ),
                          ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isAll ? Icons.grid_view_rounded : Icons.table_restaurant_rounded,
                        color: isSel ? Colors.white : const Color(0xFF334155),
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        flr,
                        style: TextStyle(
                          color: isSel ? Colors.white : const Color(0xFF334155),
                          fontSize: 11,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          // + Add Table button (Preserves ElevatedButton semantic compatibility for testing)
          ElevatedButton.icon(
            key: const ValueKey('add_table_top_button'),
            onPressed: _showAddTableDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0B2253),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 1.5,
              minimumSize: const Size(0, 32),
            ),
            icon: const Icon(Icons.add_rounded, color: Colors.white, size: 14),
            label: const Text(
              'Add Table',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderTypeBar() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          // Dine In (Active on this screen)
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1D4ED8).withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/dinein.png',
                    width: 13,
                    height: 13,
                    color: Colors.white,
                    errorBuilder: (ctx, err, stack) => const Icon(Icons.restaurant_rounded, color: Colors.white, size: 13),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Dine In',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Takeaway
          Expanded(
            child: InkWell(
              onTap: () => _openPosForOrderType(OrderType.takeaway),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD6E2F0).withValues(alpha: 0.7),
                      blurRadius: 5,
                      offset: const Offset(0, 1.5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/takeaway.png',
                      width: 13,
                      height: 13,
                      errorBuilder: (ctx, err, stack) => const Icon(Icons.shopping_bag_outlined, color: Color(0xFF0F172A), size: 13),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Takeaway',
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Delivery
          Expanded(
            child: InkWell(
              onTap: () => _openPosForOrderType(OrderType.delivery),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD6E2F0).withValues(alpha: 0.7),
                      blurRadius: 5,
                      offset: const Offset(0, 1.5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/delivery.png',
                      width: 13,
                      height: 13,
                      errorBuilder: (ctx, err, stack) => const Icon(Icons.two_wheeler_rounded, color: Color(0xFF0F172A), size: 13),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Delivery',
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloorSectionHeader(String floorName, int tableCount, bool isCollapsed) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, right: 2, bottom: 6, top: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD6E2F0).withValues(alpha: 0.6),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: const Icon(Icons.table_restaurant_rounded, color: Color(0xFF0B2253), size: 14),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    floorName,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  '($tableCount Tables)',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // Collapse Toggle Button
          InkWell(
            onTap: () {
              setState(() {
                if (_collapsedFloors.contains(floorName)) {
                  _collapsedFloors.remove(floorName);
                } else {
                  _collapsedFloors.add(floorName);
                }
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD6E2F0).withValues(alpha: 0.6),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Icon(
                isCollapsed ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded,
                color: const Color(0xFF64748B),
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Plus Button to add table/floor
          InkWell(
            onTap: _showAddTableDialog,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD6E2F0).withValues(alpha: 0.6),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: const Icon(Icons.add_rounded, color: Color(0xFF0F172A), size: 16),
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<TableStatus> _buildStatusPopupItem(TableStatus status, TableStatus currentStatus, {bool isEnabled = true}) {
    final isSelected = status == currentStatus;
    final color = _getStatusColor(status);
    final icon = _getStatusIcon(status);
    final label = _getStatusLabel(status);

    return PopupMenuItem<TableStatus>(
      value: status,
      enabled: isEnabled,
      height: 34,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: _getStatusBg(status),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Icon(icon, color: color, size: 12),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isEnabled ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
          if (isSelected)
            Icon(Icons.check_rounded, color: color, size: 14),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListenableBuilder(
      listenable: db,
      builder: (context, _) {
        final freeCount = db.tables.where((t) => t.status == TableStatus.free).length;
        final runningKotCount = db.tables.where((t) => t.status == TableStatus.runningKot).length;
        final occupiedCount = db.tables.where((t) => t.status == TableStatus.occupied).length;
        final reservedCount = db.tables.where((t) => t.status == TableStatus.reserved).length;

        final Map<String, List<TableModel>> tablesByFloor = {};
        for (var t in filteredTables) {
          tablesByFloor.putIfAbsent(t.floor, () => []).add(t);
        }

        return Scaffold(
          backgroundColor: const Color(0xFFEFF5FB),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Column(
                children: [
                  // 1. Top Neumorphic KPI Stats Row
                  _buildNeumorphicKpiRow(freeCount, runningKotCount, occupiedCount, reservedCount),
                  const SizedBox(height: 8),

                  // 2. View / Floor Filter Bar + Add Table Button
                  _buildViewAndFloorBar(),
                  const SizedBox(height: 8),

                  // 3. Order Type Segment Bar (Dine In / Takeaway / Delivery)
                  _buildOrderTypeBar(),
                  const SizedBox(height: 8),

                  // 4. Floor-wise Sequenced Tables Grid View (Wrapped & 3 tables in one row on mobile)
                  Expanded(
                    child: ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: tablesByFloor.keys.length,
                      itemBuilder: (context, floorIdx) {
                        final floorName = tablesByFloor.keys.elementAt(floorIdx);
                        final floorTables = tablesByFloor[floorName]!;
                        final isCollapsed = _collapsedFloors.contains(floorName);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Floor Header
                            _buildFloorSectionHeader(floorName, floorTables.length, isCollapsed),

                            if (!isCollapsed)
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final width = constraints.maxWidth;
                                  // In mobile view (width < 600), show exactly 3 tables in one row
                                  final cols = width >= 1400
                                      ? 8
                                      : width >= 1100
                                          ? 6
                                          : width >= 800
                                              ? 5
                                              : width >= 600
                                                  ? 4
                                                  : 3;

                                  final isMobileGrid = width < 600;

                                  return GridView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: cols,
                                      childAspectRatio: isMobileGrid ? 0.80 : (width < 900 ? 0.90 : 0.98),
                                      crossAxisSpacing: isMobileGrid ? 6 : 8,
                                      mainAxisSpacing: isMobileGrid ? 6 : 8,
                                    ),
                                    itemCount: floorTables.length,
                                    itemBuilder: (context, idx) {
                                      final table = floorTables[idx];
                                      final validStatus = TableStatus.values.contains(table.status) ? table.status : TableStatus.free;
                                      final isRunningKot = validStatus == TableStatus.runningKot;
                                      final statusColor = _getStatusColor(validStatus);
                                      final statusBg = _getStatusBg(validStatus);
                                      final statusBorder = _getStatusBorder(validStatus);
                                      final statusIcon = _getStatusIcon(validStatus);
                                      final statusLabel = _getStatusLabel(validStatus);

                                      // Cart value calculation
                                       // Cart value calculation
                                       final activeOrder = validStatus == TableStatus.free
                                           ? null
                                           : db.orders.where((o) =>
                                               (isSameTable(o.tableNumber, table.name) || (table.currentOrderId != null && o.id == table.currentOrderId)) &&
                                               (o.status != OrderStatus.completed && o.status != OrderStatus.cancelled)).firstOrNull;
                                       final confirmedAmount = activeOrder?.totalAmount ?? 0.0;
                                       final liveAmount = db.getLiveCartTotal(table.name);
                                       final activeAmount = confirmedAmount > 0 ? confirmedAmount : (liveAmount > 0 ? liveAmount : table.activeOrderTotal);
                                       final hasCartValue = activeAmount > 0;

                                       return InkWell(
                                         onTap: () => _openPosForTable(table.name),
                                         borderRadius: BorderRadius.circular(16),
                                         child: Container(
                                           decoration: BoxDecoration(
                                             color: Colors.white,
                                             borderRadius: BorderRadius.circular(16),
                                             border: Border.all(
                                               color: validStatus == TableStatus.free
                                                   ? const Color(0xFFE2E8F0)
                                                   : statusColor.withValues(alpha: 0.75),
                                               width: validStatus == TableStatus.free ? 1.0 : 1.5,
                                             ),
                                             boxShadow: [
                                               BoxShadow(
                                                 color: validStatus == TableStatus.free
                                                     ? const Color(0xFFD6E2F0).withValues(alpha: 0.7)
                                                     : statusColor.withValues(alpha: 0.18),
                                                 blurRadius: 8,
                                                 offset: const Offset(1.5, 3),
                                               ),
                                               const BoxShadow(
                                                 color: Colors.white,
                                                 blurRadius: 6,
                                                 offset: Offset(-1.5, -1.5),
                                               ),
                                             ],
                                           ),
                                           padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
                                           child: Column(
                                             crossAxisAlignment: CrossAxisAlignment.start,
                                             children: [
                                               // Top: Status Selection / Dropdown Section (Full width matching table box)
                                               SizedBox(
                                                 width: double.infinity,
                                                 child: PopupMenuButton<TableStatus>(
                                                   enabled: !isRunningKot,
                                                   tooltip: 'Change Status',
                                                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                                   color: Colors.white,
                                                   elevation: 8,
                                                   onSelected: (newStatus) {
                                                     if (newStatus != TableStatus.runningKot) {
                                                       db.updateTableStatus(table.id, newStatus);
                                                       setState(() {});
                                                     }
                                                   },
                                                   itemBuilder: (ctx) => [
                                                     _buildStatusPopupItem(TableStatus.free, validStatus),
                                                     _buildStatusPopupItem(TableStatus.occupied, validStatus),
                                                     _buildStatusPopupItem(TableStatus.runningKot, validStatus, isEnabled: false),
                                                     _buildStatusPopupItem(TableStatus.reserved, validStatus),
                                                   ],
                                                   child: Container(
                                                     height: 25,
                                                     width: double.infinity,
                                                     padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                     decoration: BoxDecoration(
                                                       color: statusBg,
                                                       borderRadius: BorderRadius.circular(8),
                                                       border: Border.all(color: statusBorder, width: 0.9),
                                                     ),
                                                     alignment: Alignment.center,
                                                     child: FittedBox(
                                                       fit: BoxFit.scaleDown,
                                                       child: Row(
                                                         mainAxisAlignment: MainAxisAlignment.center,
                                                         mainAxisSize: MainAxisSize.min,
                                                         children: [
                                                           Icon(statusIcon, color: statusColor, size: 11),
                                                           const SizedBox(width: 3.5),
                                                           Text(
                                                             statusLabel,
                                                             style: TextStyle(
                                                               color: statusColor,
                                                               fontSize: 9.5,
                                                               fontWeight: FontWeight.w800,
                                                             ),
                                                           ),
                                                           const SizedBox(width: 1.5),
                                                           Icon(Icons.keyboard_arrow_down_rounded, color: statusColor, size: 12),
                                                         ],
                                                       ),
                                                     ),
                                                   ),
                                                 ),
                                               ),
                                              const Spacer(),

                                              // Middle: Stylized Chair & Table Info + Cart Value
                                              Row(
                                                children: [
                                                  Container(
                                                    width: 28,
                                                    height: 28,
                                                    decoration: BoxDecoration(
                                                      color: statusBg,
                                                      borderRadius: BorderRadius.circular(9),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: statusColor.withValues(alpha: 0.12),
                                                          blurRadius: 3,
                                                          offset: const Offset(0, 1.5),
                                                        ),
                                                      ],
                                                    ),
                                                    child: Icon(Icons.chair_rounded, color: statusColor, size: 15),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          table.name,
                                                          style: const TextStyle(
                                                            color: Color(0xFF0F172A),
                                                            fontSize: 11.5,
                                                            fontWeight: FontWeight.w900,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                        Text(
                                                          table.floor,
                                                          style: const TextStyle(
                                                            color: Color(0xFF94A3B8),
                                                            fontSize: 8,
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                        if (hasCartValue) ...[
                                                          const SizedBox(height: 1.5),
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                            decoration: BoxDecoration(
                                                              color: statusBg,
                                                              borderRadius: BorderRadius.circular(5),
                                                              border: Border.all(color: statusBorder, width: 0.7),
                                                            ),
                                                            child: Row(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                Icon(Icons.shopping_bag_outlined, size: 8, color: statusColor),
                                                                const SizedBox(width: 2),
                                                                Flexible(
                                                                  child: Text(
                                                                    '${db.restaurant?.currencySymbol ?? "₹"}${activeAmount.toStringAsFixed(0)}',
                                                                    style: TextStyle(
                                                                      color: statusColor,
                                                                      fontSize: 9,
                                                                      fontWeight: FontWeight.w900,
                                                                    ),
                                                                    maxLines: 1,
                                                                    overflow: TextOverflow.ellipsis,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const Spacer(),

                                              // Bottom: Actions per status & Reserved Box
                                               if (validStatus == TableStatus.free)
                                                 Center(
                                                   child: Material(
                                                     color: Colors.transparent,
                                                     child: InkWell(
                                                       key: ValueKey('add_to_cart_${table.name}'),
                                                       onTap: () => _openPosForTable(table.name),
                                                       customBorder: const CircleBorder(),
                                                       child: Container(
                                                         width: 32,
                                                         height: 32,
                                                         decoration: BoxDecoration(
                                                           shape: BoxShape.circle,
                                                           color: const Color(0xFFEFFDF5),
                                                           border: Border.all(color: const Color(0xFFC7F3E2), width: 1.2),
                                                           boxShadow: [
                                                             BoxShadow(
                                                               color: const Color(0xFF10B981).withValues(alpha: 0.25),
                                                               blurRadius: 5,
                                                               offset: const Offset(0, 2),
                                                             ),
                                                             const BoxShadow(
                                                               color: Colors.white,
                                                               blurRadius: 3,
                                                               offset: Offset(-1, -1),
                                                             ),
                                                           ],
                                                         ),
                                                         padding: const EdgeInsets.all(2.5),
                                                         child: Container(
                                                           decoration: const BoxDecoration(
                                                             shape: BoxShape.circle,
                                                             gradient: LinearGradient(
                                                               colors: [Color(0xFF10B981), Color(0xFF059669)],
                                                               begin: Alignment.topCenter,
                                                               end: Alignment.bottomCenter,
                                                             ),
                                                           ),
                                                           alignment: Alignment.center,
                                                           child: const Icon(
                                                             Icons.shopping_cart_rounded,
                                                             color: Colors.white,
                                                             size: 14.5,
                                                           ),
                                                         ),
                                                       ),
                                                     ),
                                                   ),
                                                 )
                                              else if (validStatus == TableStatus.occupied)
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: LiveTableDurationBadge(
                                                        table: table,
                                                        activeOrderCreatedAt: activeOrder?.createdAt,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 3),
                                                    InkWell(
                                                      onTap: () => _openPosForTable(table.name),
                                                      borderRadius: BorderRadius.circular(8),
                                                      child: Container(
                                                        height: 22,
                                                        padding: const EdgeInsets.symmetric(horizontal: 5),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFFF1F5F9),
                                                          borderRadius: BorderRadius.circular(8),
                                                          border: Border.all(color: const Color(0xFFE2E8F0)),
                                                        ),
                                                        child: FittedBox(
                                                          fit: BoxFit.scaleDown,
                                                          child: Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: const [
                                                              Icon(Icons.receipt_long_outlined, color: Color(0xFF0F172A), size: 10),
                                                              SizedBox(width: 2),
                                                              Text(
                                                                'View',
                                                                style: TextStyle(
                                                                  color: Color(0xFF0F172A),
                                                                  fontSize: 9,
                                                                  fontWeight: FontWeight.bold,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                )
                                               else if (validStatus == TableStatus.runningKot)
                                                 Row(
                                                   children: [
                                                     Expanded(
                                                       child: LiveTableDurationBadge(
                                                         table: table,
                                                         activeOrderCreatedAt: activeOrder?.createdAt,
                                                       ),
                                                     ),
                                                     const SizedBox(width: 3),
                                                     InkWell(
                                                       onTap: () => _openPosForTable(table.name),
                                                       borderRadius: BorderRadius.circular(8),
                                                       child: Container(
                                                         height: 22,
                                                         padding: const EdgeInsets.symmetric(horizontal: 5),
                                                         decoration: BoxDecoration(
                                                           color: const Color(0xFFFFF1F2),
                                                           borderRadius: BorderRadius.circular(8),
                                                           border: Border.all(color: const Color(0xFFFECDD3)),
                                                         ),
                                                         child: FittedBox(
                                                           fit: BoxFit.scaleDown,
                                                           child: Row(
                                                             mainAxisAlignment: MainAxisAlignment.center,
                                                             children: const [
                                                               Icon(Icons.receipt_long_outlined, color: Color(0xFFEF4444), size: 10),
                                                               SizedBox(width: 2),
                                                               Text(
                                                                 'View',
                                                                 style: TextStyle(
                                                                   color: Color(0xFFEF4444),
                                                                   fontSize: 9,
                                                                   fontWeight: FontWeight.bold,
                                                                 ),
                                                               ),
                                                             ],
                                                           ),
                                                         ),
                                                       ),
                                                     ),
                                                   ],
                                                 )
                                              else // Reserved Box
                                                InkWell(
                                                  onTap: () => _openPosForTable(table.name),
                                                  borderRadius: BorderRadius.circular(8),
                                                  child: Container(
                                                    height: 22,
                                                    padding: const EdgeInsets.symmetric(horizontal: 5),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFFAF5FF),
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(color: const Color(0xFFE9D5FF)),
                                                    ),
                                                    child: FittedBox(
                                                      fit: BoxFit.scaleDown,
                                                      child: Row(
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        children: const [
                                                          Icon(Icons.visibility_outlined, color: Color(0xFF8B5CF6), size: 10),
                                                          SizedBox(width: 2.5),
                                                          Text(
                                                            'View',
                                                            style: TextStyle(
                                                              color: Color(0xFF8B5CF6),
                                                              fontSize: 9,
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            const SizedBox(height: 8),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// An isolated self-ticking running duration badge that updates every 1s locally
class LiveTableDurationBadge extends StatefulWidget {
  final TableModel table;
  final String? activeOrderCreatedAt;

  const LiveTableDurationBadge({
    super.key,
    required this.table,
    this.activeOrderCreatedAt,
  });

  @override
  State<LiveTableDurationBadge> createState() => _LiveTableDurationBadgeState();
}

class _LiveTableDurationBadgeState extends State<LiveTableDurationBadge> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimerIfNeeded();
  }

  @override
  void didUpdateWidget(covariant LiveTableDurationBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    _startTimerIfNeeded();
  }

  void _startTimerIfNeeded() {
    if (widget.table.status != TableStatus.free) {
      if (_timer == null || !_timer!.isActive) {
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() {});
        });
      }
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.table.status == TableStatus.free) return const SizedBox.shrink();

    final duration = widget.table.getRunningDuration(activeOrderCreatedAt: widget.activeOrderCreatedAt) ?? Duration.zero;

    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFFDE68A),
          width: 0.8,
        ),
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.access_time_rounded,
              size: 9.5,
              color: Color(0xFFD97706),
            ),
            const SizedBox(width: 2.5),
            Text(
              formatRunningDuration(duration),
              style: const TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFFD97706),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
