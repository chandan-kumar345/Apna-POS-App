import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/database/database_service.dart';
import '../../core/models/menu_item_model.dart';
import '../../core/services/upload_service.dart';

class AddProductScreen extends StatefulWidget {
  final MenuItemModel? editItem;

  const AddProductScreen({
    super.key,
    this.editItem,
  });

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final db = DatabaseService();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _discountController = TextEditingController();
  final _salePriceController = TextEditingController();
  final _categoryController = TextEditingController();
  final _stockController = TextEditingController(text: '50');

  String _selectedType = 'Veg'; // 'Veg', 'Non-Veg', 'Egg', 'Beverage'
  bool _addDiscount = false;
  String _selectedCategory = 'Main Course';
  String? _selectedImagePath;
  Uint8List? _selectedImageBytes;
  String? _selectedImageFileName;
  bool _isDragging = false;
  bool _isImageLoading = false;

  // Accordion Section States
  bool _isVariantsExpanded = true;
  bool _isInventoryExpanded = false;
  bool _isGstExpanded = false;

  final List<ProductVariant> _variants = [];
  double? _selectedGstPercent;
  bool _trackInventory = true;

  @override
  void initState() {
    super.initState();
    if (db.categories.isNotEmpty) {
      _selectedCategory = db.categories.first;
    }

    // Default GST from onboarding restaurant configuration
    _selectedGstPercent = db.restaurant?.taxRate ?? 5.0;

    if (widget.editItem != null) {
      final item = widget.editItem!;
      _titleController.text = item.name;
      _descriptionController.text = item.description;
      _priceController.text = item.price > 0 ? item.price.toStringAsFixed(0) : '0';
      _selectedType = item.itemType;
      _selectedCategory = item.category;
      _selectedImagePath = item.imageUrl;
      _addDiscount = item.hasDiscount;
      _discountController.text = item.discountPercent > 0 ? item.discountPercent.toStringAsFixed(1) : '';
      if (item.hasDiscount && item.price > 0 && item.discountPercent > 0) {
        final saleP = item.price * (1 - item.discountPercent / 100);
        _salePriceController.text = saleP.toStringAsFixed(0);
      }
      _stockController.text = item.stockQuantity.toString();
      _variants.addAll(item.variants);
      if (item.gstPercent != null) {
        _selectedGstPercent = item.gstPercent;
      }
      _trackInventory = item.trackInventory;
    }

    // Add listener to auto-calculate sale price on main price or discount change
    _priceController.addListener(_recalculateSalePriceFromDiscount);
    _discountController.addListener(_recalculateSalePriceFromDiscount);
  }

  bool _isUpdatingDiscount = false;

  void _recalculateSalePriceFromDiscount() {
    if (_isUpdatingDiscount) return;
    _isUpdatingDiscount = true;

    final origPrice = double.tryParse(_priceController.text.trim()) ?? 0.0;
    final discPct = double.tryParse(_discountController.text.trim()) ?? 0.0;

    if (origPrice > 0 && discPct >= 0 && discPct <= 100) {
      final saleP = origPrice * (1 - discPct / 100);
      _salePriceController.text = saleP.toStringAsFixed(0);
    } else if (origPrice > 0 && _discountController.text.isEmpty) {
      _salePriceController.text = origPrice.toStringAsFixed(0);
    }

    _isUpdatingDiscount = false;
  }

  void _onSalePriceChanged(String val) {
    if (_isUpdatingDiscount) return;
    _isUpdatingDiscount = true;

    final origPrice = double.tryParse(_priceController.text.trim()) ?? 0.0;
    final salePrice = double.tryParse(val.trim()) ?? 0.0;

    if (origPrice > 0 && salePrice >= 0 && salePrice <= origPrice) {
      final discPct = ((origPrice - salePrice) / origPrice) * 100;
      _discountController.text = discPct.toStringAsFixed(1);
    }

    _isUpdatingDiscount = false;
  }

  @override
  void dispose() {
    _priceController.removeListener(_recalculateSalePriceFromDiscount);
    _discountController.removeListener(_recalculateSalePriceFromDiscount);
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _discountController.dispose();
    _salePriceController.dispose();
    _categoryController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
        ),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _processIncomingFile(dynamic file) async {
    try {
      Uint8List? bytes;
      String name = 'product.jpg';
      String? path;

      debugPrint('[_processIncomingFile] Received file: ${file.runtimeType}');

      if (file is XFile) {
        path = file.path;
        name = file.name;
        try {
          bytes = await file.readAsBytes();
        } catch (e) {
          debugPrint('[_processIncomingFile XFile read error]: $e');
        }
      } else if (file is PlatformFile) {
        name = file.name;
        path = file.path;
        bytes = file.bytes;
      } else if (file is File) {
        path = file.path;
        name = file.path.split(Platform.pathSeparator).last;
      }

      // Fallback: If bytes not loaded but path is valid, read from local filesystem
      if ((bytes == null || bytes.isEmpty) && path != null && path.isNotEmpty) {
        try {
          final localFile = File(path);
          if (localFile.existsSync()) {
            bytes = await localFile.readAsBytes();
          }
        } catch (e) {
          debugPrint('[_processIncomingFile direct File read error]: $e');
        }
      }

      debugPrint('[_processIncomingFile] Resolved bytes length: ${bytes?.length}, path: $path, name: $name');

      if ((bytes != null && bytes.isNotEmpty) || (path != null && path.isNotEmpty)) {
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImagePath = path;
          _selectedImageFileName = name;
        });
        _showSuccessSnackBar('Image loaded successfully!');
      } else {
        _showErrorSnackBar('Unable to read selected image file.');
      }
    } catch (e) {
      debugPrint('[_processIncomingFile] error: $e');
      _showErrorSnackBar('Failed to read image file: $e');
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      // 1. Try FilePicker for robust desktop & mobile support
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'jfif'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        await _processIncomingFile(result.files.first);
        return;
      }
    } catch (e) {
      debugPrint('[AddProductScreen] FilePicker fallback: $e');
    }

    try {
      // 2. Fallback to ImagePicker
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        await _processIncomingFile(pickedFile);
      }
    } catch (e) {
      _showErrorSnackBar('Gallery pick error: $e');
    }
  }

  void _addVariantDialog() {
    final vNameCtrl = TextEditingController();
    final vPriceCtrl = TextEditingController();
    final vDiscCtrl = TextEditingController();
    final vSalePriceCtrl = TextEditingController();
    bool vAddDiscount = false;
    bool isCalcVariant = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          void calcVariantSalePrice() {
            if (isCalcVariant) return;
            isCalcVariant = true;
            final p = double.tryParse(vPriceCtrl.text.trim()) ?? 0.0;
            final d = double.tryParse(vDiscCtrl.text.trim()) ?? 0.0;
            if (p > 0 && d >= 0 && d <= 100) {
              vSalePriceCtrl.text = (p * (1 - d / 100)).toStringAsFixed(0);
            }
            isCalcVariant = false;
          }

          void calcVariantDiscountPct(String val) {
            if (isCalcVariant) return;
            isCalcVariant = true;
            final p = double.tryParse(vPriceCtrl.text.trim()) ?? 0.0;
            final s = double.tryParse(val.trim()) ?? 0.0;
            if (p > 0 && s >= 0 && s <= p) {
              vDiscCtrl.text = (((p - s) / p) * 100).toStringAsFixed(1);
            }
            isCalcVariant = false;
          }

          final screenWidth = MediaQuery.of(context).size.width;
          final dialogWidth = screenWidth > 600 ? 520.0 : (screenWidth * 0.92).clamp(320.0, 520.0);

          return AlertDialog(
            backgroundColor: Colors.white,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 20, 16),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF051C48).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.tune_rounded, color: Color(0xFF051C48), size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Add Product Variant',
                    style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: dialogWidth,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Variant Name*', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    const SizedBox(height: 5),
                    TextField(
                      controller: vNameCtrl,
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13.5),
                      decoration: InputDecoration(
                        hintText: 'e.g. Half, Full, 500g, 1L, Regular, Large',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
                        prefixIcon: const Icon(Icons.label_outline, color: Color(0xFF051C48), size: 18),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF051C48), width: 2)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('Variant Price*', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    const SizedBox(height: 5),
                    TextField(
                      controller: vPriceCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13.5, fontWeight: FontWeight.bold),
                      onChanged: (_) {
                        if (vAddDiscount) calcVariantSalePrice();
                      },
                      decoration: InputDecoration(
                        hintText: 'Price (${db.restaurant?.currencySymbol ?? "₹"})',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
                        prefixIcon: const Icon(Icons.payments_outlined, color: Color(0xFF051C48), size: 18),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF051C48), width: 2)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Switch(
                          value: vAddDiscount,
                          activeColor: const Color(0xFF051C48),
                          onChanged: (val) {
                            setDialogState(() {
                              vAddDiscount = val;
                              if (val) calcVariantSalePrice();
                            });
                          },
                        ),
                        const SizedBox(width: 6),
                        const Text('Add Variant Discount (Optional)', style: TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    if (vAddDiscount) ...[
                      const SizedBox(height: 10),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 280;
                          final discWidget = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Discount (%)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                              const SizedBox(height: 4),
                              TextField(
                                controller: vDiscCtrl,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                                onChanged: (_) => calcVariantSalePrice(),
                                decoration: InputDecoration(
                                  hintText: '10%',
                                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                  prefixIcon: const Icon(Icons.discount_outlined, color: Color(0xFF051C48), size: 16),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2)),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF051C48), width: 2)),
                                ),
                              ),
                            ],
                          );

                          final saleWidget = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Sale Price', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                              const SizedBox(height: 4),
                              TextField(
                                controller: vSalePriceCtrl,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: Color(0xFF051C48), fontWeight: FontWeight.w900, fontSize: 13),
                                onChanged: (val) => calcVariantDiscountPct(val),
                                decoration: InputDecoration(
                                  hintText: 'Sale Price',
                                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                  prefixIcon: const Icon(Icons.sell_outlined, color: Color(0xFF051C48), size: 16),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2)),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF051C48), width: 2)),
                                ),
                              ),
                            ],
                          );

                          if (isNarrow) {
                            return Column(
                              children: [
                                discWidget,
                                const SizedBox(height: 10),
                                saleWidget,
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(child: discWidget),
                              const SizedBox(width: 10),
                              Expanded(child: saleWidget),
                            ],
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                onPressed: () {
                  final name = vNameCtrl.text.trim();
                  final price = double.tryParse(vPriceCtrl.text.trim()) ?? 0.0;
                  final discPct = double.tryParse(vDiscCtrl.text.trim()) ?? 0.0;

                  if (name.isEmpty) {
                    _showErrorSnackBar('Please enter variant name');
                    return;
                  }
                  if (price <= 0) {
                    _showErrorSnackBar('Please enter valid variant price');
                    return;
                  }

                  setState(() {
                    _variants.add(ProductVariant(
                      name: name,
                      price: price,
                      hasDiscount: vAddDiscount,
                      discountPercent: discPct,
                      salePrice: vAddDiscount && discPct > 0 ? price * (1 - discPct / 100) : null,
                    ));

                    // If variants exist, set main price to 0 and lock it!
                    _priceController.text = '0';
                  });
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF051C48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                ),
                child: const Text('Add Variant', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _addNewCategoryDialog() {
    _categoryController.clear();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        contentPadding: const EdgeInsets.all(22),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFF051C48),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.category_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Create New Category',
                    style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _categoryController,
                style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13.5, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'Category Name',
                  hintText: 'e.g. Desserts, Beverages, Starters',
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  labelStyle: const TextStyle(color: Color(0xFF475569), fontSize: 13),
                  prefixIcon: const Icon(Icons.category_outlined, color: Color(0xFF051C48), size: 18),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF051C48), width: 1.5)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      final cat = _categoryController.text.trim();
                      if (cat.isNotEmpty) {
                        await db.addCategory(cat);
                        setState(() {
                          _selectedCategory = cat;
                        });
                        if (!mounted) return;
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF051C48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                      elevation: 0,
                    ),
                    child: const Text('Create Category', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isSaving = false;

  Future<void> _saveProduct() async {
    if (_isSaving) return;

    final title = _titleController.text.trim();
    final price = double.tryParse(_priceController.text.trim()) ?? 0.0;

    if (title.isEmpty) {
      _showErrorSnackBar('Product title is required! Please enter a title.');
      return;
    }

    final String catName = _selectedCategory.trim().isNotEmpty
        ? _selectedCategory.trim()
        : (db.categories.isNotEmpty ? db.categories.first : 'Main Course');

    final String foodType = _selectedType.trim().isNotEmpty ? _selectedType.trim() : 'Veg';

    if (price <= 0 && _variants.isEmpty) {
      _showErrorSnackBar('Price is required! Please enter a valid price or add variants.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final discountVal = double.tryParse(_discountController.text.trim()) ?? 0.0;
      final stockVal = int.tryParse(_stockController.text.trim()) ?? 50;

      String finalImageUrl = _selectedImagePath ?? '';
      
      // If we have selected image bytes (from drag & drop or picker), upload to Cloudflare R2
      if (_selectedImageBytes != null && _selectedImageBytes!.isNotEmpty) {
        try {
          final uploadedUrl = await UploadService().uploadImageBytes(
            _selectedImageBytes!,
            fileName: _selectedImageFileName ?? 'product_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
          if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
            finalImageUrl = uploadedUrl;
          }
        } catch (e) {
          debugPrint('[AddProductScreen] image bytes upload fallback: $e');
        }
      } else if (_selectedImagePath != null &&
          _selectedImagePath!.isNotEmpty &&
          !_selectedImagePath!.startsWith('http') &&
          File(_selectedImagePath!).existsSync()) {
        try {
          final uploadedUrl = await UploadService().uploadImage(File(_selectedImagePath!));
          if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
            finalImageUrl = uploadedUrl;
          }
        } catch (e) {
          debugPrint('[AddProductScreen] image upload fallback to local path: $e');
        }
      }

      final uniqueProdId = widget.editItem?.productId ??
          widget.editItem?.id ??
          'PRD-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}-${1000 + (DateTime.now().microsecond % 9000)}';

      final double calculatedSalePrice = _addDiscount && discountVal > 0
          ? price * (1 - discountVal / 100)
          : (double.tryParse(_salePriceController.text.trim()) ?? price);

      final item = MenuItemModel(
        id: widget.editItem?.id ?? uniqueProdId,
        productId: uniqueProdId,
        name: title,
        category: catName,
        price: _variants.isNotEmpty ? 0.0 : price,
        salePrice: _variants.isNotEmpty ? null : (_addDiscount ? calculatedSalePrice : null),
        description: _descriptionController.text.trim(),
        emoji: '🥘',
        imageUrl: finalImageUrl,
        images: finalImageUrl.isNotEmpty ? [finalImageUrl] : [],
        itemType: foodType,
        hasDiscount: _addDiscount,
        discountPercent: discountVal,
        stockQuantity: stockVal,
        variants: List.from(_variants),
        gstPercent: _selectedGstPercent,
        trackInventory: _trackInventory,
      );

      await db.saveMenuItem(item);
      if (!mounted) return;

      _showSuccessSnackBar('Product saved successfully!');
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('[AddProductScreen] _saveProduct error: $e');
      if (mounted) {
        _showErrorSnackBar('Failed to save product: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = db.restaurant?.currencySymbol ?? '₹';
    final hasVariants = _variants.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF051C48), // Match top bar deep navy theme
      body: SafeArea(
        child: Column(
          children: [
            // Top Header Bar (NO COMPANY NAME BADGE)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF051C48), Color(0xFF0A2B66)],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Product Info',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            ),

            // White background canvas with semi-curved top-left & top-right corners
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isSmallScreen = constraints.maxWidth < 600;

                    return Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 16 : 28,
                            vertical: 20,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. TITLE FIELD
                              _buildFieldHeader('Title*', required: true),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _titleController,
                                style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'Title',
                                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                  prefixIcon: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF051C48)),
                                  filled: true,
                                  fillColor: Colors.white,
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: Color(0xFF051C48), width: 2),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text('Give your product a short and clear name', style: TextStyle(color: Color(0xFF64748B), fontSize: 11.5)),

                              const SizedBox(height: 18),

                              // 2. DESCRIPTION FIELD
                              _buildFieldHeader('Description (Optional)'),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _descriptionController,
                                maxLines: 3,
                                style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'Description',
                                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                  prefixIcon: const Icon(Icons.description_outlined, color: Color(0xFF051C48)),
                                  filled: true,
                                  fillColor: Colors.white,
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: Color(0xFF051C48), width: 2),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 18),

                              // 3. FOODTYPE (HORIZONTAL SLIDING CHIPS)
                              _buildFieldHeader('FoodType*', required: true),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 44,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  children: [
                                    _buildDietaryOption('Veg', const Color(0xFF10B981), _selectedType == 'Veg', () => setState(() => _selectedType = 'Veg')),
                                    const SizedBox(width: 8),
                                    _buildDietaryOption('Non-Veg', const Color(0xFFEF4444), _selectedType == 'Non-Veg', () => setState(() => _selectedType = 'Non-Veg')),
                                    const SizedBox(width: 8),
                                    _buildDietaryOption('Egg', const Color(0xFFB45309), _selectedType == 'Egg', () => setState(() => _selectedType = 'Egg')),
                                    const SizedBox(width: 8),
                                    _buildDietaryOption('Beverage', const Color(0xFF00A3FF), _selectedType == 'Beverage', () => setState(() => _selectedType = 'Beverage')),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 18),

                              // 4. PRICE (LOCKED IF VARIANTS ADDED)
                              _buildFieldHeader('Price*', required: true),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _priceController,
                                enabled: !hasVariants,
                                keyboardType: TextInputType.number,
                                style: TextStyle(color: hasVariants ? const Color(0xFF94A3B8) : const Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  hintText: hasVariants ? '0 (Managed by variants)' : '$currency 100',
                                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                  prefixIcon: const Icon(Icons.payments_outlined, color: Color(0xFF051C48)),
                                  filled: true,
                                  fillColor: hasVariants ? const Color(0xFFF1F5F9) : Colors.white,
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                                  ),
                                  disabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: Color(0xFF051C48), width: 2),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                                  ),
                                ),
                              ),
                              if (hasVariants) ...[
                                const SizedBox(height: 4),
                                const Text('Main price is locked to 0 because variants are added. Price is managed per variant.', style: TextStyle(color: Color(0xFF051C48), fontSize: 11, fontWeight: FontWeight.w600)),
                              ],

                              const SizedBox(height: 12),

                              // 5. DISCOUNT SWITCH TOGGLE & DUAL TEXT FIELDS (DISCOUNT % & SALE PRICE)
                              Row(
                                children: [
                                  Switch(
                                    value: _addDiscount,
                                    activeColor: const Color(0xFF051C48),
                                    onChanged: (val) => setState(() => _addDiscount = val),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('Add Discount (Optional)', style: TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.w600)),
                                ],
                              ),
                              if (_addDiscount) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    // Discount Percentage Field
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Discount (%)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                          const SizedBox(height: 4),
                                          TextField(
                                            controller: _discountController,
                                            keyboardType: TextInputType.number,
                                            style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
                                            decoration: InputDecoration(
                                              hintText: 'e.g. 15',
                                              prefixIcon: const Icon(Icons.discount_outlined, color: Color(0xFF051C48)),
                                              filled: true,
                                              fillColor: Colors.white,
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(14),
                                                borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(14),
                                                borderSide: const BorderSide(color: Color(0xFF051C48), width: 2),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    // Sale Price Field
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Sale Price (After Discount)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                          const SizedBox(height: 4),
                                          TextField(
                                            controller: _salePriceController,
                                            keyboardType: TextInputType.number,
                                            style: const TextStyle(color: Color(0xFF051C48), fontWeight: FontWeight.w900, fontSize: 14),
                                            onChanged: _onSalePriceChanged,
                                            decoration: InputDecoration(
                                              hintText: 'Sale Price',
                                              prefixIcon: const Icon(Icons.sell_outlined, color: Color(0xFF051C48)),
                                              filled: true,
                                              fillColor: Colors.white,
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(14),
                                                borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(14),
                                                borderSide: const BorderSide(color: Color(0xFF051C48), width: 2),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],

                              const SizedBox(height: 18),

                              _buildFieldHeader('Product Image (Optional)'),
                              const SizedBox(height: 8),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                    color: _isDragging ? const Color(0xFFEFF6FF) : Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: _isDragging ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                                      width: _isDragging ? 2.2 : 1.2,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      if (_isImageLoading) ...[
                                        Container(
                                          height: 160,
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(14),
                                            border: Border.all(color: const Color(0xFF93C5FD)),
                                          ),
                                          child: const Center(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                SizedBox(
                                                  width: 32,
                                                  height: 32,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 3,
                                                    color: Color(0xFF051C48),
                                                  ),
                                                ),
                                                SizedBox(height: 10),
                                                Text(
                                                  'Loading image preview...',
                                                  style: TextStyle(
                                                    color: Color(0xFF0F172A),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ] else if (_selectedImageBytes != null ||
                                          (_selectedImagePath != null && _selectedImagePath!.isNotEmpty)) ...[
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFDCFCE7),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: const Color(0xFF86EFAC)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 15),
                                                  const SizedBox(width: 5),
                                                  Text(
                                                    (_selectedImageFileName != null && _selectedImageFileName!.isNotEmpty)
                                                        ? _selectedImageFileName!
                                                        : 'Image Attached',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                      color: Color(0xFF15803D),
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const Spacer(),
                                            if (_selectedImageBytes != null)
                                              Text(
                                                '${(_selectedImageBytes!.lengthInBytes / 1024).toStringAsFixed(0)} KB',
                                                style: const TextStyle(
                                                  fontSize: 11.5,
                                                  color: Color(0xFF64748B),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Container(
                                          height: 190,
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(14),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.06),
                                                blurRadius: 8,
                                                offset: const Offset(0, 3),
                                              ),
                                            ],
                                            border: Border.all(color: const Color(0xFFCBD5E1)),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(14),
                                            child: _selectedImageBytes != null
                                                ? Image.memory(
                                                    _selectedImageBytes!,
                                                    key: ValueKey(_selectedImageBytes.hashCode),
                                                    height: 190,
                                                    width: double.infinity,
                                                    fit: BoxFit.cover,
                                                    alignment: Alignment.center,
                                                    errorBuilder: (_, __, ___) => Container(
                                                      height: 140,
                                                      color: const Color(0xFFF1F5F9),
                                                      child: const Center(
                                                        child: Icon(Icons.broken_image, size: 40, color: Color(0xFF94A3B8)),
                                                      ),
                                                    ),
                                                  )
                                                : ((_selectedImagePath!.startsWith('http://') ||
                                                        _selectedImagePath!.startsWith('https://'))
                                                    ? Image.network(
                                                        _selectedImagePath!,
                                                        key: ValueKey(_selectedImagePath!),
                                                        height: 190,
                                                        width: double.infinity,
                                                        fit: BoxFit.cover,
                                                        alignment: Alignment.center,
                                                        errorBuilder: (_, __, ___) => Container(
                                                          height: 140,
                                                          color: const Color(0xFFF1F5F9),
                                                          child: const Center(
                                                            child: Icon(Icons.broken_image, size: 40, color: Color(0xFF94A3B8)),
                                                          ),
                                                        ),
                                                      )
                                                    : Image.file(
                                                        File(_selectedImagePath!),
                                                        key: ValueKey(_selectedImagePath!),
                                                        height: 190,
                                                        width: double.infinity,
                                                        fit: BoxFit.cover,
                                                        alignment: Alignment.center,
                                                        errorBuilder: (_, __, ___) => Container(
                                                          height: 140,
                                                          color: const Color(0xFFF1F5F9),
                                                          child: const Center(
                                                            child: Icon(Icons.broken_image, size: 40, color: Color(0xFF94A3B8)),
                                                          ),
                                                        ),
                                                      )),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            ElevatedButton.icon(
                                              onPressed: _pickImageFromGallery,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF051C48),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                              ),
                                              icon: const Icon(Icons.edit, color: Colors.white, size: 16),
                                              label: const Text('Change Image',
                                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5)),
                                            ),
                                            const SizedBox(width: 10),
                                            OutlinedButton.icon(
                                              onPressed: () => setState(() {
                                                _selectedImageBytes = null;
                                                _selectedImagePath = null;
                                                _selectedImageFileName = null;
                                              }),
                                              style: OutlinedButton.styleFrom(
                                                side: const BorderSide(color: Color(0xFFEF4444)),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                              ),
                                              icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 16),
                                              label: const Text('Remove',
                                                  style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 12.5)),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        const Text(
                                          'Tip: You can also drag & drop another image here to replace',
                                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                                          textAlign: TextAlign.center,
                                        ),
                                      ] else ...[
                                        InkWell(
                                          onTap: _pickImageFromGallery,
                                          borderRadius: BorderRadius.circular(12),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                                            child: Column(
                                              children: [
                                                Icon(
                                                  _isDragging ? Icons.file_download_outlined : Icons.cloud_upload_outlined,
                                                  size: 46,
                                                  color: _isDragging ? const Color(0xFF2563EB) : const Color(0xFF051C48),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  _isDragging ? 'Drop Image Here to Upload' : 'Drag & Drop Product Image here',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    color: _isDragging ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                const Text('Supports JPG, PNG, WEBP, GIF formats', style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8))),
                                                const SizedBox(height: 12),
                                                ElevatedButton.icon(
                                                  onPressed: _pickImageFromGallery,
                                                  icon: const Icon(Icons.photo_library_outlined, size: 16, color: Colors.white),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFF051C48),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                                  ),
                                                  label: const Text('Choose Image', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),

                              const SizedBox(height: 18),

                              // 7. CATEGORY SELECTOR + PLUS ICON BUTTON FOR CREATE CATEGORY
                              _buildFieldHeader('Category*', required: true),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                                      ),
                                      child: DropdownButton<String>(
                                        isExpanded: true,
                                        dropdownColor: Colors.white,
                                        value: db.categories.contains(_selectedCategory) ? _selectedCategory : (db.categories.isNotEmpty ? db.categories.first : null),
                                        hint: const Text('Select Category', style: TextStyle(color: Color(0xFF64748B))),
                                        underline: const SizedBox(),
                                        items: db.categories.map((cat) {
                                          return DropdownMenuItem<String>(
                                            value: cat,
                                            child: Text(cat, style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
                                          );
                                        }).toList(),
                                        onChanged: (val) {
                                          if (val != null) setState(() => _selectedCategory = val);
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // PLUS ICON BUTTON FOR CREATE CATEGORY (NO TEXT!)
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF051C48),
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF051C48).withOpacity(0.2),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: IconButton(
                                      onPressed: _addNewCategoryDialog,
                                      icon: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
                                      tooltip: 'Create Category',
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 24),

                              // SECTION 2: VARIANTS
                              _buildAccordionHeader(
                                title: 'Variants (Optional) (${_variants.length})',
                                isExpanded: _isVariantsExpanded,
                                onToggle: () => setState(() => _isVariantsExpanded = !_isVariantsExpanded),
                              ),
                              if (_isVariantsExpanded) ...[
                                Container(
                                  margin: const EdgeInsets.only(top: 4, bottom: 14),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: const [
                                                Text('Variant Options', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 13)),
                                                Text('Add multiple variants (e.g. Size, Weight, Portion)', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                                              ],
                                            ),
                                          ),
                                          ElevatedButton.icon(
                                            onPressed: _addVariantDialog,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF051C48),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                            ),
                                            icon: const Icon(Icons.add_rounded, color: Colors.white, size: 16),
                                            label: const Text('Add Variant', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                          ),
                                        ],
                                      ),
                                      if (_variants.isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        const Divider(color: Color(0xFFE2E8F0), height: 1),
                                        const SizedBox(height: 8),
                                        Column(
                                          children: _variants.asMap().entries.map((entry) {
                                            final idx = entry.key;
                                            final v = entry.value;
                                            final effectivePrice = v.hasDiscount && v.discountPercent > 0
                                                ? v.price * (1 - v.discountPercent / 100)
                                                : v.price;

                                            return Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 4),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF8FAFC),
                                                  borderRadius: BorderRadius.circular(10),
                                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                                ),
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.tune, color: Color(0xFF051C48), size: 16),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(v.name, style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                                                          if (v.hasDiscount && v.discountPercent > 0)
                                                            Text('${v.discountPercent.toStringAsFixed(0)}% OFF', style: const TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold)),
                                                        ],
                                                      ),
                                                    ),
                                                    Column(
                                                      crossAxisAlignment: CrossAxisAlignment.end,
                                                      children: [
                                                        Text(
                                                          '$currency ${effectivePrice.toStringAsFixed(0)}',
                                                          style: const TextStyle(color: Color(0xFF051C48), fontWeight: FontWeight.w900, fontSize: 13),
                                                        ),
                                                        if (v.hasDiscount && v.discountPercent > 0)
                                                          Text(
                                                            '$currency ${v.price.toStringAsFixed(0)}',
                                                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10, decoration: TextDecoration.lineThrough),
                                                          ),
                                                      ],
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 18),
                                                      onPressed: () {
                                                        setState(() {
                                                          _variants.removeAt(idx);
                                                          if (_variants.isEmpty && widget.editItem != null) {
                                                            _priceController.text = widget.editItem!.price.toStringAsFixed(0);
                                                          }
                                                        });
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],

                              // GST SECTION (DEFAULT FROM ONBOARDING & HORIZONTAL SLIDING)
                              _buildAccordionHeader(
                                title: 'GST (Optional)',
                                isExpanded: _isGstExpanded,
                                onToggle: () => setState(() => _isGstExpanded = !_isGstExpanded),
                              ),
                              if (_isGstExpanded) ...[
                                Container(
                                  margin: const EdgeInsets.only(top: 4, bottom: 14),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: SizedBox(
                                    height: 42,
                                    child: ListView(
                                      scrollDirection: Axis.horizontal,
                                      physics: const BouncingScrollPhysics(),
                                      children: [null, 0.0, 5.0, 12.0, 18.0, 28.0].map((rate) {
                                        final isSel = _selectedGstPercent == rate;
                                        final label = rate == null ? 'No GST' : '$rate%';
                                        return Padding(
                                          padding: const EdgeInsets.only(right: 8),
                                          child: ChoiceChip(
                                            label: Text(label),
                                            selected: isSel,
                                            selectedColor: const Color(0xFF051C48),
                                            backgroundColor: Colors.white,
                                            labelStyle: TextStyle(color: isSel ? Colors.white : const Color(0xFF475569), fontWeight: FontWeight.bold),
                                            onSelected: (_) => setState(() => _selectedGstPercent = rate),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ],

                              // INVENTORY SECTION (VISIBLE STOCK QUANTITY TEXT)
                              _buildAccordionHeader(
                                title: 'Inventory (Optional)',
                                isExpanded: _isInventoryExpanded,
                                onToggle: () => setState(() => _isInventoryExpanded = !_isInventoryExpanded),
                              ),
                              if (_isInventoryExpanded) ...[
                                Container(
                                  margin: const EdgeInsets.only(top: 4, bottom: 24),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Switch(
                                            value: _trackInventory,
                                            activeColor: const Color(0xFF051C48),
                                            onChanged: (val) => setState(() => _trackInventory = val),
                                          ),
                                          const SizedBox(width: 8),
                                          const Text('Track Stock Inventory', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                      if (_trackInventory) ...[
                                        const SizedBox(height: 10),
                                        TextField(
                                          controller: _stockController,
                                          keyboardType: TextInputType.number,
                                          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.bold),
                                          decoration: InputDecoration(
                                            hintText: '50',
                                            hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                                            prefixIcon: const Icon(Icons.inventory_2_outlined, color: Color(0xFF051C48)),
                                            filled: true,
                                            fillColor: Colors.white,
                                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2)),
                                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF051C48), width: 2)),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],

                              const SizedBox(height: 12),

                              // SAVE PRODUCT BUTTON
                              SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: ElevatedButton(
                                  onPressed: _isSaving ? null : _saveProduct,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF051C48),
                                    disabledBackgroundColor: const Color(0xFF051C48).withOpacity(0.6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                                    elevation: 4,
                                  ),
                                  child: _isSaving
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                        )
                                      : const Text(
                                          'Save Product',
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldHeader(String label, {bool required = false}) {
    return RichText(
      text: TextSpan(
        text: label.replaceAll('*', ''),
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        children: [
          if (required)
            const TextSpan(
              text: '*',
              style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold),
            ),
        ],
      ),
    );
  }

  Widget _buildDietaryOption(String label, Color color, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.12) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFCBD5E1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                border: Border.all(color: color, width: 2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
                color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccordionHeader({
    required String title,
    required bool isExpanded,
    required VoidCallback onToggle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF051C48),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const Spacer(),
              Icon(
                isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
