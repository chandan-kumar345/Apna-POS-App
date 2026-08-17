import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/widgets/food_type_icon.dart';
import '../../core/database/database_service.dart';
import '../../core/models/menu_item_model.dart';
import 'add_product_screen.dart';

class MenuManagementScreen extends StatefulWidget {
  const MenuManagementScreen({super.key});

  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> {
  final db = DatabaseService();
  int _selectedTab = 0; // 0: Products, 1: Categories
  String _searchQuery = '';
  String _selectedCategoryFilter = 'All';

  @override
  void initState() {
    super.initState();
    db.addListener(_onDbChange);
    db.syncWithBackend();
  }

  @override
  void dispose() {
    db.removeListener(_onDbChange);
    super.dispose();
  }

  void _onDbChange() {
    if (mounted) setState(() {});
  }

  List<MenuItemModel> get filteredProducts {
    return db.menuItems.where((item) {
      final matchesCat =
          _selectedCategoryFilter == 'All' || item.category == _selectedCategoryFilter;
      final matchesSearch = item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.category.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.description.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCat && matchesSearch;
    }).toList();
  }

  /// Open full-featured POS Add Item / Edit Item screen
  void _openAddEditProductScreen([MenuItemModel? editItem]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddProductScreen(editItem: editItem),
      ),
    ).then((_) => setState(() {}));
  }

  void _showCsvImportModal() {
    bool isProcessing = false;
    String? modalError;
    String? modalSuccess;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 12,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Modal Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF051C48),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.table_chart_rounded, color: Colors.white, size: 22),
                                ),
                                const SizedBox(width: 10),
                                const Flexible(
                                  child: Text(
                                    'Import Products via CSV',
                                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Download the CSV template, fill in your product catalog, and upload to bulk add products.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 16),

                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Error Banner
                              if (modalError != null) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEE2E2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          modalError!,
                                          style: const TextStyle(color: Color(0xFF991B1B), fontSize: 12.5, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                              ],

                              // Success Banner
                              if (modalSuccess != null) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFF22C55E), width: 1.5),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.check_circle_rounded, color: Color(0xFF15803D), size: 20),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          modalSuccess!,
                                          style: const TextStyle(color: Color(0xFF14532D), fontSize: 12.5, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                              ],

                              // Step 1: Download Template Section Box
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                  boxShadow: const [
                                    BoxShadow(color: Color(0x04000000), blurRadius: 6, offset: Offset(0, 2)),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.downloading_rounded, color: Color(0xFF051C48), size: 20),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Step 1: Download CSV Sample Template',
                                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Template Format & Headers:\n• Product Name (Required)\n• Description (Optional)\n• Food Type (Veg, Non-Veg, Egg)\n• Price (Required)\n• Variant Name (Optional: Half, Full)\n• Variant Price (Optional)\n• Category (e.g. Main Course, Beverages)',
                                      style: TextStyle(fontSize: 11.5, color: Color(0xFF475569), height: 1.4),
                                    ),
                                    const SizedBox(height: 14),
                                    ElevatedButton.icon(
                                      onPressed: () async {
                                        try {
                                          Directory? targetDir;
                                          try {
                                            targetDir = await getDownloadsDirectory();
                                          } catch (_) {}
                                          targetDir ??= await getApplicationDocumentsDirectory();

                                          final filePath = '${targetDir.path}/Apna_POS_Menu_Template.csv';
                                          final sampleCsv = 
                                            'Product Name,Description,Food Type,Price,Variant Name,Variant Price,Category\n'
                                            'Paneer Butter Masala,Rich creamy gravy,Veg,280,Half,150,Main Course\n'
                                            'Paneer Butter Masala,Rich creamy gravy,Veg,280,Full,280,Main Course\n'
                                            'Chicken Biryani,Spicy Hyderabadi Biryani,Non-Veg,320,Regular,320,Biryani\n'
                                            'Veg Burger,Crispy patty with cheese,Veg,99,,0,Starters\n'
                                            'Cold Coffee,Brewed coffee with ice cream,Veg,120,,0,Beverages\n';

                                          final file = File(filePath);
                                          await file.writeAsString(sampleCsv);

                                          if (Platform.isWindows) {
                                            try {
                                              await Process.run('cmd', ['/c', 'start', '', filePath]);
                                            } catch (_) {}
                                          } else {
                                            try {
                                              final xFile = XFile(filePath, mimeType: 'text/csv');
                                              await Share.shareXFiles([xFile], text: 'Apna POS Menu CSV Template');
                                            } catch (_) {}
                                          }

                                          setModalState(() {
                                            modalSuccess = 'Sample template saved to:\n$filePath';
                                            modalError = null;
                                          });
                                        } catch (e) {
                                          setModalState(() {
                                            modalError = 'Failed to download template: ${e.toString()}';
                                          });
                                        }
                                      },
                                      icon: const Icon(Icons.download_rounded, size: 18, color: Colors.white),
                                      label: const Text('Download CSV Template', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF10B981),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        elevation: 0,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Step 2: Upload CSV File Section Box
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                  boxShadow: const [
                                    BoxShadow(color: Color(0x04000000), blurRadius: 6, offset: Offset(0, 2)),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.upload_file_rounded, color: Color(0xFF051C48), size: 20),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Step 2: Upload Filled CSV File',
                                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Select your filled CSV file from your device to import all products automatically into your menu.',
                                      style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                    ),
                                    const SizedBox(height: 14),
                                    ElevatedButton.icon(
                                      onPressed: isProcessing
                                          ? null
                                          : () async {
                                              try {
                                                setModalState(() {
                                                  isProcessing = true;
                                                  modalError = null;
                                                  modalSuccess = null;
                                                });

                                                final result = await FilePicker.platform.pickFiles(
                                                  type: FileType.custom,
                                                  allowedExtensions: ['csv'],
                                                );

                                                if (result == null || result.files.isEmpty) {
                                                  setModalState(() {
                                                    isProcessing = false;
                                                  });
                                                  return;
                                                }

                                                final file = result.files.single;
                                                String csvContent = '';

                                                if (file.path != null) {
                                                  final f = File(file.path!);
                                                  csvContent = await f.readAsString();
                                                } else if (file.bytes != null) {
                                                  csvContent = utf8.decode(file.bytes!);
                                                }

                                                if (csvContent.trim().isEmpty) {
                                                  setModalState(() {
                                                    isProcessing = false;
                                                    modalError = 'The selected CSV file is empty.';
                                                  });
                                                  return;
                                                }

                                                final lines = const LineSplitter().convert(csvContent);
                                                if (lines.length <= 1) {
                                                  setModalState(() {
                                                    isProcessing = false;
                                                    modalError = 'CSV file has no data rows besides header.';
                                                  });
                                                  return;
                                                }

                                                // Group items by product name
                                                final Map<String, Map<String, dynamic>> productMap = {};

                                                for (int i = 1; i < lines.length; i++) {
                                                  final line = lines[i].trim();
                                                  if (line.isEmpty) continue;

                                                  final cols = _parseCsvLine(line);
                                                  if (cols.isEmpty) continue;

                                                  final name = cols.length > 0 ? cols[0].trim() : '';
                                                  if (name.isEmpty) continue;

                                                  final desc = cols.length > 1 ? cols[1].trim() : '';
                                                  final foodType = cols.length > 2 ? cols[2].trim() : 'Veg';
                                                  final price = cols.length > 3 ? (double.tryParse(cols[3].trim()) ?? 0.0) : 0.0;
                                                  final varName = cols.length > 4 ? cols[4].trim() : '';
                                                  final varPrice = cols.length > 5 ? (double.tryParse(cols[5].trim()) ?? price) : price;
                                                  final category = cols.length > 6 ? cols[6].trim() : 'General';

                                                  if (!productMap.containsKey(name)) {
                                                    productMap[name] = {
                                                      'name': name,
                                                      'desc': desc,
                                                      'foodType': foodType.isEmpty ? 'Veg' : foodType,
                                                      'price': price,
                                                      'category': category.isEmpty ? 'General' : category,
                                                      'variants': <ProductVariant>[],
                                                    };
                                                  }

                                                  if (varName.isNotEmpty) {
                                                    (productMap[name]!['variants'] as List<ProductVariant>).add(
                                                      ProductVariant(name: varName, price: varPrice),
                                                    );
                                                  }
                                                }

                                                if (productMap.isEmpty) {
                                                  setModalState(() {
                                                    isProcessing = false;
                                                    modalError = 'No valid product rows could be parsed from the CSV.';
                                                  });
                                                  return;
                                                }

                                                int addedCount = 0;
                                                for (final entry in productMap.values) {
                                                  final pName = entry['name'] as String;
                                                  final pCategory = entry['category'] as String;
                                                  final pPrice = entry['price'] as double;
                                                  final pDesc = entry['desc'] as String;
                                                  final pFoodType = entry['foodType'] as String;
                                                  final pVariants = entry['variants'] as List<ProductVariant>;

                                                  if (!db.categories.contains(pCategory)) {
                                                    await db.addCategory(pCategory);
                                                  }

                                                  final newItem = MenuItemModel(
                                                    id: 'item_${DateTime.now().millisecondsSinceEpoch}_${addedCount++}',
                                                    name: pName,
                                                    category: pCategory,
                                                    price: pPrice,
                                                    description: pDesc,
                                                    itemType: pFoodType,
                                                    variants: pVariants,
                                                    isAvailable: true,
                                                  );

                                                  await db.saveMenuItem(newItem);
                                                }

                                                if (!context.mounted) return;
                                                Navigator.pop(context);
                                                setState(() {});

                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Row(
                                                      children: [
                                                        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                                        const SizedBox(width: 10),
                                                        Text(
                                                          'Successfully imported $addedCount products from CSV!',
                                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                                        ),
                                                      ],
                                                    ),
                                                    backgroundColor: const Color(0xFF15803D),
                                                    behavior: SnackBarBehavior.floating,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                    duration: const Duration(seconds: 4),
                                                  ),
                                                );
                                              } catch (e) {
                                                setModalState(() {
                                                  isProcessing = false;
                                                  modalError = 'Error parsing CSV file: ${e.toString()}';
                                                });
                                              }
                                            },
                                      icon: isProcessing
                                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                          : const Icon(Icons.file_upload_rounded, size: 16, color: Colors.white),
                                      label: Text(
                                        isProcessing ? 'Importing...' : 'Choose & Upload CSV File',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF051C48),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                        elevation: 0,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
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

  List<String> _parseCsvLine(String line) {
    final List<String> result = [];
    final StringBuffer current = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        result.add(current.toString());
        current.clear();
      } else {
        current.write(char);
      }
    }
    result.add(current.toString());
    return result;
  }

  void _showAddCategoryModal() {
    final catCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.all(20),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add New Category',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: catCtrl,
                style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13.5),
                decoration: InputDecoration(
                  labelText: 'Category Name',
                  hintText: 'e.g. Starters, Beverages',
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  labelStyle: const TextStyle(color: Color(0xFF475569), fontSize: 13),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF051C48), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      if (catCtrl.text.trim().isNotEmpty) {
                        db.addCategory(catCtrl.text.trim());
                        setState(() {});
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF051C48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                    label: const Text('Save Category', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteProduct(MenuItemModel dish) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.all(20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 32),
            ),
            const SizedBox(height: 12),
            Text(
              'Delete "${dish.name}"?',
              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Are you sure you want to delete this product from the menu?',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('Cancel', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await db.deleteMenuItem(dish.id);
                      if (!mounted) return;
                      setState(() {});
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.white),
                    label: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteCategory(String categoryName) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.all(20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 32),
            ),
            const SizedBox(height: 12),
            Text(
              'Delete Category "$categoryName"?',
              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Deleting a category will remove it from the menu filters.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('Cancel', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await db.deleteCategory(categoryName);
                      if (!mounted) return;
                      setState(() {});
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.white),
                    label: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductImage(MenuItemModel dish) {
    if (dish.imageUrl.isNotEmpty) {
      if (dish.imageUrl.startsWith('http://') || dish.imageUrl.startsWith('https://')) {
        return Image.network(
          dish.imageUrl,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallbackImage(),
        );
      } else {
        final file = File(dish.imageUrl);
        if (file.existsSync()) {
          return Image.file(
            file,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildFallbackImage(),
          );
        }
      }
    }
    return _buildFallbackImage();
  }

  Widget _buildFallbackImage() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.fastfood_rounded, color: Color(0xFF051C48), size: 18),
    );
  }

  Widget _buildProductCard(MenuItemModel dish) {
    final currency = db.restaurant?.currencySymbol ?? '₹';
    final double displayPrice = dish.variants.isNotEmpty ? dish.variants.first.price : dish.price;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Product Photo + FoodType Overlay Badge
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _buildProductImage(dish),
                  ),
                  Positioned(
                    top: 1,
                    left: 1,
                    child: FoodTypeIcon(itemType: dish.itemType, size: 11),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        FoodTypeIcon(itemType: dish.itemType, size: 11),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            dish.name,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          constraints: const BoxConstraints(maxWidth: 85),
                          decoration: BoxDecoration(
                            color: const Color(0xFF051C48).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: const Color(0xFF051C48).withValues(alpha: 0.2)),
                          ),
                          child: Text(
                            dish.category,
                            style: const TextStyle(
                              color: Color(0xFF051C48),
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dish.description.isEmpty ? 'No description' : dish.description,
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 10.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (dish.variants.isNotEmpty) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD97706).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '${dish.variants.length} Variants',
                    style: const TextStyle(
                      color: Color(0xFFD97706),
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 6),
              Text(
                '$currency${displayPrice.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Color(0xFF051C48),
                  fontWeight: FontWeight.w900,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Divider(color: Color(0xFFF1F5F9), height: 1),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: dish.stockQuantity <= 10
                              ? const Color(0xFFFEE2E2)
                              : const Color(0xFF051C48).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: dish.stockQuantity <= 10
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF051C48).withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          '${dish.stockQuantity} in stock',
                          style: TextStyle(
                            color: dish.stockQuantity <= 10
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF051C48),
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Active:',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 10.5, fontWeight: FontWeight.w500),
                      ),
                      Transform.scale(
                        scale: 0.65,
                        child: Switch(
                          value: dish.isAvailable,
                          activeThumbColor: const Color(0xFF051C48),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          onChanged: (val) {
                            db.toggleMenuItemAvailability(dish.id);
                            setState(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Edit Product Button
                  InkWell(
                    onTap: () => _openAddEditProductScreen(dish),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF051C48).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF051C48).withValues(alpha: 0.25)),
                      ),
                      child: const Icon(Icons.edit_rounded, color: Color(0xFF051C48), size: 14),
                    ),
                  ),
                  const SizedBox(width: 5),
                  // Delete Product Button
                  InkWell(
                    onTap: () => _confirmDeleteProduct(dish),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                      ),
                      child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 14),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(String cat) {
    final itemCount = db.menuItems.where((m) => m.category == cat).length;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF051C48).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.category_rounded, color: Color(0xFF051C48), size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cat, style: const TextStyle(fontSize: 13.0, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                Text('$itemCount Products in category',
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 10.5)),
              ],
            ),
          ),
          InkWell(
            onTap: () {
              final editCtrl = TextEditingController(text: cat);
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  contentPadding: const EdgeInsets.all(18),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Edit Category Name',
                          style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 10),
                      TextField(
                        controller: editCtrl,
                        style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13.5),
                        decoration: InputDecoration(
                          hintText: 'Category Name',
                          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              db.editCategory(cat, editCtrl.text.trim());
                              setState(() {});
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF051C48),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Update', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFF051C48).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF051C48).withValues(alpha: 0.25)),
              ),
              child: const Icon(Icons.edit_rounded, color: Color(0xFF051C48), size: 14),
            ),
          ),
          const SizedBox(width: 5),
          InkWell(
            onTap: () => _confirmDeleteCategory(cat),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_selectedTab == 0) {
      if (filteredProducts.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.restaurant_menu_rounded, color: Color(0xFF94A3B8), size: 40),
              const SizedBox(height: 8),
              const Text('No menu products found',
                  style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () => _openAddEditProductScreen(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF051C48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                icon: const Icon(Icons.add_rounded, size: 15, color: Colors.white),
                label: const Text('Add First Product',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
        );
      }
      return ListView.builder(
        physics: const BouncingScrollPhysics(),
        itemCount: filteredProducts.length,
        itemBuilder: (context, idx) {
          return _buildProductCard(filteredProducts[idx]);
        },
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: db.categories.length,
      itemBuilder: (context, idx) {
        return _buildCategoryCard(db.categories[idx]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriesList = ['All', ...db.categories];

    return SafeArea(
      child: Container(
        color: const Color(0xFFF8FAFC),
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            // Header & Tab Switcher Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          ChoiceChip(
                            showCheckmark: false,
                            label: Text('Products (${db.menuItems.length})', style: const TextStyle(fontSize: 11.5)),
                            selected: _selectedTab == 0,
                            selectedColor: const Color(0xFF051C48),
                            backgroundColor: const Color(0xFFF1F5F9),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            side: BorderSide.none,
                            labelStyle: TextStyle(
                              color: _selectedTab == 0 ? Colors.white : const Color(0xFF475569),
                              fontWeight: FontWeight.bold,
                            ),
                            onSelected: (_) => setState(() => _selectedTab = 0),
                          ),
                          const SizedBox(width: 6),
                          ChoiceChip(
                            showCheckmark: false,
                            label: Text('Categories (${db.categories.length})', style: const TextStyle(fontSize: 11.5)),
                            selected: _selectedTab == 1,
                            selectedColor: const Color(0xFF051C48),
                            backgroundColor: const Color(0xFFF1F5F9),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            side: BorderSide.none,
                            labelStyle: TextStyle(
                              color: _selectedTab == 1 ? Colors.white : const Color(0xFF475569),
                              fontWeight: FontWeight.bold,
                            ),
                            onSelected: (_) => setState(() => _selectedTab = 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // CSV Bulk Import Plus Icon Button
                  Tooltip(
                    message: 'Bulk Import Products via CSV',
                    child: InkWell(
                      onTap: _showCsvImportModal,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 32,
                        width: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          color: Color(0xFF051C48),
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Smaller Semi-Curved Button
                  SizedBox(
                    height: 32,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (_selectedTab == 0) {
                          _openAddEditProductScreen();
                        } else {
                          _showAddCategoryModal();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF051C48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        elevation: 1,
                      ),
                      label: Text(
                        _selectedTab == 0 ? 'Add Product' : 'Add Category',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Search Bar & Filters for Products Tab
            if (_selectedTab == 0) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x05000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12.5),
                      decoration: InputDecoration(
                        hintText: 'Search product by name ',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF051C48), size: 18),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF051C48), width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 28,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: categoriesList.length,
                        itemBuilder: (context, idx) {
                          final cat = categoriesList[idx];
                          final isSel = _selectedCategoryFilter == cat;
                          return Padding(
                            padding: const EdgeInsets.only(right: 5),
                            child: ChoiceChip(
                              showCheckmark: false,
                              label: Text(cat, style: const TextStyle(fontSize: 11.0)),
                              selected: isSel,
                              selectedColor: const Color(0xFF051C48),
                              backgroundColor: const Color(0xFFF1F5F9),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              side: BorderSide.none,
                              labelStyle: TextStyle(
                                color: isSel ? Colors.white : const Color(0xFF475569),
                                fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                              ),
                              onSelected: (_) => setState(() => _selectedCategoryFilter = cat),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Content Area
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }
}
