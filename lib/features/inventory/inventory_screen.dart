import 'package:flutter/material.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/glass_widgets.dart';
import '../../core/database/database_service.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final db = DatabaseService();

  void _showReorderDialog(String itemId, String itemName) {
    final qtyCtrl = TextEditingController(text: '10');

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
                'Restock $itemName',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 16),
              GlassTextField(
                controller: qtyCtrl,
                labelText: 'Quantity to Add',
                hintText: '10',
                keyboardType: TextInputType.number,
                prefixIcon: Icons.add_shopping_cart,
              ),
              const SizedBox(height: 20),
              GlassButton(
                label: 'Confirm Restock',
                icon: Icons.check,
                onPressed: () {
                  final added = double.tryParse(qtyCtrl.text) ?? 10.0;
                  db.addInventoryStock(itemId, added);
                  setState(() {});
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lowStockItems = db.inventoryItems.where((i) => i.isLowStock).toList();

    return SafeArea(
      child: Column(
      children: [
        if (lowStockItems.isNotEmpty) ...[
          GlassContainer(
            padding: const EdgeInsets.all(16),
            backgroundColor: GlassTheme.accentRose.withOpacity(0.18),
            borderColor: GlassTheme.accentRose.withOpacity(0.5),
            borderRadius: 16,
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: GlassTheme.accentRose, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Attention Needed: ${lowStockItems.length} Ingredients are Low in Stock!',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        lowStockItems.map((e) => '${e.name} (${e.quantity} ${e.unit})').join(', '),
                        style: const TextStyle(color: GlassTheme.textMedium, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 280,
              childAspectRatio: 1.1,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
            itemCount: db.inventoryItems.length,
            itemBuilder: (context, idx) {
              final inv = db.inventoryItems[idx];
              final isLow = inv.isLowStock;

              return GlassCard(
                padding: const EdgeInsets.all(16),
                borderColor: isLow ? GlassTheme.accentRose : GlassTheme.glassBorder,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            inv.name,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        GlassBadge(
                          label: inv.category,
                          color: isLow ? GlassTheme.accentRose : GlassTheme.primaryCyan,
                          fontSize: 10,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Min Threshold: ${inv.minThreshold} ${inv.unit}',
                      style: const TextStyle(color: GlassTheme.textMedium, fontSize: 11),
                    ),
                    const Spacer(),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Current Stock', style: TextStyle(color: GlassTheme.textMedium, fontSize: 11)),
                            Text(
                              '${inv.quantity} ${inv.unit}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: isLow ? GlassTheme.accentRose : GlassTheme.accentNeonGreen,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_box_rounded, color: GlassTheme.primaryViolet, size: 28),
                          tooltip: 'Add Stock',
                          onPressed: () => _showReorderDialog(inv.id, inv.name),
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
