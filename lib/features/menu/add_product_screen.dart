import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_win/video_player_win.dart';
import '../../core/database/database_service.dart';
import '../../core/models/menu_item_model.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/services/upload_service.dart';
import '../../core/services/youtube_service.dart';

class ProductImageItem {
  final String? path;
  final Uint8List? bytes;
  final String? name;
  final String? remoteUrl;

  ProductImageItem({
    this.path,
    this.bytes,
    this.name,
    this.remoteUrl,
  });

  bool get isRemote =>
      remoteUrl != null &&
      remoteUrl!.isNotEmpty &&
      (remoteUrl!.startsWith('http://') || remoteUrl!.startsWith('https://'));
}

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

  // Multi-Image State
  final List<ProductImageItem> _selectedImages = [];
  int _activeImagePreviewIndex = 0;
  bool _isDragging = false;
  bool _isImageLoading = false;

  // Video State
  final _videoUrlController = TextEditingController();
  String? _selectedVideoPath;
  Uint8List? _selectedVideoBytes;
  String? _selectedVideoFileName;
  String? _remoteVideoUrl;
  VideoPlayerController? _previewVideoController;
  bool _isVideoInitialized = false;
  bool _isVideoLoading = false;
  bool _isVideoMuted = true;

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

      // Populate Images
      if (item.images.isNotEmpty) {
        for (int i = 0; i < item.images.length; i++) {
          final img = item.images[i].trim();
          if (img.isNotEmpty) {
            _selectedImages.add(ProductImageItem(
              remoteUrl: img,
              path: img,
              name: 'Image ${i + 1}',
            ));
          }
        }
      } else if (item.imageUrl.trim().isNotEmpty) {
        _selectedImages.add(ProductImageItem(
          remoteUrl: item.imageUrl.trim(),
          path: item.imageUrl.trim(),
          name: 'Cover Image',
        ));
      }

      // Populate Video
      if (item.videoUrl.trim().isNotEmpty) {
        _remoteVideoUrl = item.videoUrl.trim();
        _videoUrlController.text = item.videoUrl.trim();
        _initPreviewVideo(item.videoUrl.trim());
      }

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
    _videoUrlController.dispose();
    _previewVideoController?.dispose();
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

  Future<void> _pickImagesFromGallery() async {
    setState(() => _isImageLoading = true);
    try {
      // 1. Try FilePicker with allowMultiple
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'jfif'],
        allowMultiple: true,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        int count = 0;
        for (final file in result.files) {
          Uint8List? bytes = file.bytes;
          if ((bytes == null || bytes.isEmpty) && file.path != null && file.path!.isNotEmpty) {
            try {
              final localFile = File(file.path!);
              if (localFile.existsSync()) {
                bytes = await localFile.readAsBytes();
              }
            } catch (_) {}
          }
          if ((bytes != null && bytes.isNotEmpty) || (file.path != null && file.path!.isNotEmpty)) {
            _selectedImages.add(ProductImageItem(
              path: file.path,
              bytes: bytes,
              name: file.name,
            ));
            count++;
          }
        }
        setState(() {
          _isImageLoading = false;
          _activeImagePreviewIndex = _selectedImages.length - 1;
        });
        _showSuccessSnackBar('$count image(s) added successfully!');
        return;
      }
    } catch (e) {
      debugPrint('[AddProductScreen] FilePicker multiple: $e');
    }

    try {
      // 2. Fallback to ImagePicker multiImage
      final picker = ImagePicker();
      final pickedFiles = await picker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (pickedFiles.isNotEmpty) {
        for (final pf in pickedFiles) {
          final bytes = await pf.readAsBytes();
          _selectedImages.add(ProductImageItem(
            path: pf.path,
            bytes: bytes,
            name: pf.name,
          ));
        }
        setState(() {
          _isImageLoading = false;
          _activeImagePreviewIndex = _selectedImages.length - 1;
        });
        _showSuccessSnackBar('${pickedFiles.length} image(s) added successfully!');
        return;
      }
    } catch (e) {
      _showErrorSnackBar('Gallery pick error: $e');
    } finally {
      if (mounted) setState(() => _isImageLoading = false);
    }
  }

  // --- Video Management Methods ---
  Future<void> _initPreviewVideo(String source, {bool isFile = false}) async {
    final cleanSource = source.trim();
    if (cleanSource.isEmpty) return;

    setState(() {
      _isVideoLoading = true;
      _isVideoInitialized = false;
    });

    if (!kIsWeb && Platform.isWindows) {
      try {
        WindowsVideoPlayer.registerWith();
      } catch (_) {}
    }

    try {
      _previewVideoController?.dispose();
      _previewVideoController = null;

      if (isFile) {
        _previewVideoController = VideoPlayerController.file(File(cleanSource));
      } else {
        String streamUrl = cleanSource;
        if (YouTubeService.isYouTubeUrl(cleanSource)) {
          final resolved = await YouTubeService.resolveStreamUrl(cleanSource);
          if (resolved != null && resolved.isNotEmpty) {
            streamUrl = resolved;
          }
          // If no images selected yet, auto-populate with high quality YouTube thumbnail
          final vidId = YouTubeService.extractVideoId(cleanSource);
          if (vidId != null && vidId.isNotEmpty && _selectedImages.isEmpty) {
            final thumbUrl = YouTubeService.getThumbnailUrl(vidId);
            _selectedImages.add(ProductImageItem(
              remoteUrl: thumbUrl,
              path: thumbUrl,
              name: 'YouTube Cover Thumbnail',
            ));
          }
        } else {
          streamUrl = ApiEndpoints.resolveMediaUrl(cleanSource);
        }

        final uri = Uri.tryParse(streamUrl);
        if (uri != null && (uri.isScheme('http') || uri.isScheme('https'))) {
          _previewVideoController = VideoPlayerController.networkUrl(uri);
        } else {
          final file = File(streamUrl);
          if (file.existsSync()) {
            _previewVideoController = VideoPlayerController.file(file);
          } else {
            final resolvedUri = Uri.tryParse(ApiEndpoints.resolveMediaUrl(streamUrl));
            if (resolvedUri != null && (resolvedUri.isScheme('http') || resolvedUri.isScheme('https'))) {
              _previewVideoController = VideoPlayerController.networkUrl(resolvedUri);
            } else {
              _previewVideoController = VideoPlayerController.networkUrl(Uri.parse(streamUrl));
            }
          }
        }
      }

      await _previewVideoController!.initialize();
      await _previewVideoController!.setVolume(_isVideoMuted ? 0.0 : 1.0);
      await _previewVideoController!.setLooping(true);
      await _previewVideoController!.play();

      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
          _isVideoLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[_initPreviewVideo] Video preview note: $e');
      if (mounted) {
        setState(() {
          _isVideoInitialized = false;
          _isVideoLoading = false;
        });
      }
    }
  }

  Future<void> _pickVideo() async {
    try {
      // 1. FilePicker video pick
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _selectedVideoPath = file.path;
          _selectedVideoBytes = file.bytes;
          _selectedVideoFileName = file.name;
          _remoteVideoUrl = null;
          _videoUrlController.clear();
        });
        if (file.path != null && file.path!.isNotEmpty) {
          _initPreviewVideo(file.path!, isFile: true);
        }
        _showSuccessSnackBar('Video selected: ${file.name}');
        return;
      }
    } catch (e) {
      debugPrint('[_pickVideo] FilePicker fallback: $e');
    }

    try {
      // 2. ImagePicker fallback
      final picker = ImagePicker();
      final pickedVideo = await picker.pickVideo(source: ImageSource.gallery);
      if (pickedVideo != null) {
        final bytes = await pickedVideo.readAsBytes();
        setState(() {
          _selectedVideoPath = pickedVideo.path;
          _selectedVideoBytes = bytes;
          _selectedVideoFileName = pickedVideo.name;
          _remoteVideoUrl = null;
          _videoUrlController.clear();
        });
        _initPreviewVideo(pickedVideo.path, isFile: true);
        _showSuccessSnackBar('Video selected: ${pickedVideo.name}');
      }
    } catch (e) {
      _showErrorSnackBar('Error picking video: $e');
    }
  }

  void _removeVideo() {
    _previewVideoController?.pause();
    _previewVideoController?.dispose();
    _previewVideoController = null;
    setState(() {
      _selectedVideoPath = null;
      _selectedVideoBytes = null;
      _selectedVideoFileName = null;
      _remoteVideoUrl = null;
      _videoUrlController.clear();
      _isVideoInitialized = false;
      _isVideoLoading = false;
    });
  }

  Widget _buildProductImageItem(ProductImageItem item) {
    if (item.bytes != null && item.bytes!.isNotEmpty) {
      return Image.memory(item.bytes!, fit: BoxFit.cover, width: double.infinity, height: double.infinity);
    }
    final resolvedUrl = ApiEndpoints.resolveMediaUrl(item.remoteUrl ?? item.path);
    if (resolvedUrl.startsWith('http://') || resolvedUrl.startsWith('https://')) {
      return Image.network(
        resolvedUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => Container(
          color: const Color(0xFFF1F5F9),
          child: const Center(child: Icon(Icons.broken_image, color: Color(0xFF94A3B8))),
        ),
      );
    }
    if (item.path != null && item.path!.isNotEmpty) {
      final f = File(item.path!);
      if (f.existsSync()) {
        return Image.file(f, fit: BoxFit.cover, width: double.infinity, height: double.infinity);
      }
    }
    return Container(
      color: const Color(0xFFF1F5F9),
      child: const Center(child: Icon(Icons.broken_image, color: Color(0xFF94A3B8))),
    );
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

      // 1. Process & Upload All Images concurrently
      List<String> finalImageUrls = [];
      for (int i = 0; i < _selectedImages.length; i++) {
        final img = _selectedImages[i];
        if (img.remoteUrl != null && img.remoteUrl!.isNotEmpty) {
          finalImageUrls.add(ApiEndpoints.resolveMediaUrl(img.remoteUrl!));
        } else if (img.bytes != null && img.bytes!.isNotEmpty) {
          try {
            final uploadedUrl = await UploadService().uploadImageBytes(
              img.bytes!,
              fileName: (img.name != null && img.name!.isNotEmpty) ? img.name! : 'product_${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
            );
            if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
              finalImageUrls.add(ApiEndpoints.resolveMediaUrl(uploadedUrl));
            } else if (img.path != null && img.path!.isNotEmpty) {
              finalImageUrls.add(img.path!);
            }
          } catch (e) {
            debugPrint('[AddProductScreen] image bytes upload fallback: $e');
            if (img.path != null && img.path!.isNotEmpty) {
              finalImageUrls.add(img.path!);
            }
          }
        } else if (img.path != null && img.path!.isNotEmpty) {
          if (img.path!.startsWith('http://') || img.path!.startsWith('https://')) {
            finalImageUrls.add(img.path!);
          } else {
            try {
              final file = File(img.path!);
              if (file.existsSync()) {
                final uploadedUrl = await UploadService().uploadImage(file);
                if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
                  finalImageUrls.add(ApiEndpoints.resolveMediaUrl(uploadedUrl));
                } else {
                  finalImageUrls.add(img.path!);
                }
              } else {
                finalImageUrls.add(img.path!);
              }
            } catch (e) {
              finalImageUrls.add(img.path!);
            }
          }
        }
      }

      // 2. Process & Upload Video
      String finalVideoUrl = '';
      if (_remoteVideoUrl != null && _remoteVideoUrl!.trim().isNotEmpty) {
        final rawVid = _remoteVideoUrl!.trim();
        finalVideoUrl = YouTubeService.isYouTubeUrl(rawVid) ? rawVid : ApiEndpoints.resolveMediaUrl(rawVid);
      } else if (_videoUrlController.text.trim().isNotEmpty) {
        final rawVid = _videoUrlController.text.trim();
        finalVideoUrl = YouTubeService.isYouTubeUrl(rawVid) ? rawVid : ApiEndpoints.resolveMediaUrl(rawVid);
      } else if (_selectedVideoPath != null && _selectedVideoPath!.trim().isNotEmpty) {
        finalVideoUrl = _selectedVideoPath!.trim();
      }

      if (_selectedVideoBytes != null && _selectedVideoBytes!.isNotEmpty) {
        try {
          final uploadedVideo = await UploadService().uploadVideoBytes(
            _selectedVideoBytes!,
            fileName: _selectedVideoFileName ?? 'video_${DateTime.now().millisecondsSinceEpoch}.mp4',
          );
          if (uploadedVideo != null && uploadedVideo.isNotEmpty) {
            finalVideoUrl = ApiEndpoints.resolveMediaUrl(uploadedVideo);
          }
        } catch (e) {
          debugPrint('[AddProductScreen] video bytes upload error: $e');
        }
      } else if (_selectedVideoPath != null &&
          _selectedVideoPath!.isNotEmpty &&
          !_selectedVideoPath!.startsWith('http')) {
        try {
          final file = File(_selectedVideoPath!);
          if (file.existsSync()) {
            final uploadedVideo = await UploadService().uploadVideo(file);
            if (uploadedVideo != null && uploadedVideo.isNotEmpty) {
              finalVideoUrl = ApiEndpoints.resolveMediaUrl(uploadedVideo);
            } else {
              finalVideoUrl = _selectedVideoPath!;
            }
          }
        } catch (e) {
          debugPrint('[AddProductScreen] video file upload fallback: $e');
          finalVideoUrl = _selectedVideoPath!;
        }
      }

      // 3. Fallback to YouTube thumbnail if no image was selected but YouTube video was provided
      if (finalImageUrls.isEmpty && finalVideoUrl.isNotEmpty && YouTubeService.isYouTubeUrl(finalVideoUrl)) {
        final vidId = YouTubeService.extractVideoId(finalVideoUrl);
        if (vidId != null && vidId.isNotEmpty) {
          final thumbUrl = YouTubeService.getThumbnailUrl(vidId);
          finalImageUrls.add(thumbUrl);
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
        imageUrl: finalImageUrls.isNotEmpty ? finalImageUrls.first : '',
        images: finalImageUrls,
        videoUrl: finalVideoUrl,
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

                              const SizedBox(height: 20),

                              // --- 6A. MULTI-IMAGE GALLERY SECTION ---
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildFieldHeader('Product Images (${_selectedImages.length})'),
                                  if (_selectedImages.isNotEmpty)
                                    TextButton.icon(
                                      onPressed: _pickImagesFromGallery,
                                      icon: const Icon(Icons.add_photo_alternate_outlined, size: 15, color: Color(0xFF051C48)),
                                      label: const Text(
                                        '+ Add Images',
                                        style: TextStyle(color: Color(0xFF051C48), fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Add 1 or more images. When multiple images exist, POS items auto-slide smoothly. First image is the cover.',
                                style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 8),

                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
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
                                        height: 140,
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
                                                width: 30,
                                                height: 30,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 3,
                                                  color: Color(0xFF051C48),
                                                ),
                                              ),
                                              SizedBox(height: 10),
                                              Text(
                                                'Loading images...',
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
                                    ] else if (_selectedImages.isNotEmpty) ...[
                                      // Large Main Preview
                                      Builder(builder: (context) {
                                        final safeIndex = _activeImagePreviewIndex < _selectedImages.length
                                            ? _activeImagePreviewIndex
                                            : 0;
                                        final activeItem = _selectedImages[safeIndex];
                                        final bool isCover = safeIndex == 0;

                                        return Stack(
                                          children: [
                                            Container(
                                              height: 180,
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
                                                child: _buildProductImageItem(activeItem),
                                              ),
                                            ),
                                            Positioned(
                                              top: 8,
                                              left: 8,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: isCover ? const Color(0xFF16A34A) : Colors.black.withOpacity(0.65),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  isCover ? 'PRIMARY COVER' : 'Image ${safeIndex + 1} of ${_selectedImages.length}',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      }),
                                      const SizedBox(height: 12),

                                      // Thumbnail Gallery Strip
                                      SizedBox(
                                        height: 80,
                                        child: ListView.separated(
                                          scrollDirection: Axis.horizontal,
                                          itemCount: _selectedImages.length + 1,
                                          separatorBuilder: (context, index) => const SizedBox(width: 8),
                                          itemBuilder: (context, index) {
                                            if (index == _selectedImages.length) {
                                              // "+ Add More" card
                                              return InkWell(
                                                onTap: _pickImagesFromGallery,
                                                borderRadius: BorderRadius.circular(10),
                                                child: Container(
                                                  width: 76,
                                                  height: 76,
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFF1F5F9),
                                                    borderRadius: BorderRadius.circular(10),
                                                    border: Border.all(color: const Color(0xFF94A3B8), style: BorderStyle.solid),
                                                  ),
                                                  child: const Column(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Icon(Icons.add_photo_alternate, color: Color(0xFF051C48), size: 24),
                                                      SizedBox(height: 2),
                                                      Text('+ Add', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF051C48))),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            }

                                            final item = _selectedImages[index];
                                            final isSelected = index == _activeImagePreviewIndex;
                                            final isCover = index == 0;

                                            return Stack(
                                              clipBehavior: Clip.none,
                                              children: [
                                                GestureDetector(
                                                  onTap: () => setState(() => _activeImagePreviewIndex = index),
                                                  child: Container(
                                                    width: 76,
                                                    height: 76,
                                                    decoration: BoxDecoration(
                                                      borderRadius: BorderRadius.circular(10),
                                                      border: Border.all(
                                                        color: isSelected ? const Color(0xFF051C48) : const Color(0xFFCBD5E1),
                                                        width: isSelected ? 2.5 : 1,
                                                      ),
                                                    ),
                                                    child: ClipRRect(
                                                      borderRadius: BorderRadius.circular(8),
                                                      child: _buildProductImageItem(item),
                                                    ),
                                                  ),
                                                ),
                                                if (isCover)
                                                  Positioned(
                                                    top: 2,
                                                    left: 2,
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFF16A34A),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: const Text(
                                                        'Cover',
                                                        style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                                      ),
                                                    ),
                                                  ),
                                                // Mini actions (Cover / Delete)
                                                Positioned(
                                                  bottom: 2,
                                                  right: 2,
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      if (!isCover)
                                                        GestureDetector(
                                                          onTap: () {
                                                            setState(() {
                                                              final selected = _selectedImages.removeAt(index);
                                                              _selectedImages.insert(0, selected);
                                                              _activeImagePreviewIndex = 0;
                                                            });
                                                            _showSuccessSnackBar('Set as primary cover image!');
                                                          },
                                                          child: Container(
                                                            padding: const EdgeInsets.all(2),
                                                            margin: const EdgeInsets.only(right: 2),
                                                            decoration: BoxDecoration(
                                                              color: Colors.black.withOpacity(0.65),
                                                              shape: BoxShape.circle,
                                                            ),
                                                            child: const Icon(Icons.star, color: Colors.amber, size: 12),
                                                          ),
                                                        ),
                                                      GestureDetector(
                                                        onTap: () {
                                                          setState(() {
                                                            _selectedImages.removeAt(index);
                                                            if (_activeImagePreviewIndex >= _selectedImages.length) {
                                                              _activeImagePreviewIndex = _selectedImages.isNotEmpty ? _selectedImages.length - 1 : 0;
                                                            }
                                                          });
                                                        },
                                                        child: Container(
                                                          padding: const EdgeInsets.all(2),
                                                          decoration: BoxDecoration(
                                                            color: Colors.red.withOpacity(0.85),
                                                            shape: BoxShape.circle,
                                                          ),
                                                          child: const Icon(Icons.close, color: Colors.white, size: 12),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          OutlinedButton.icon(
                                            onPressed: () => setState(() {
                                              _selectedImages.clear();
                                              _activeImagePreviewIndex = 0;
                                            }),
                                            style: OutlinedButton.styleFrom(
                                              side: const BorderSide(color: Color(0xFFEF4444)),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                            ),
                                            icon: const Icon(Icons.delete_sweep_outlined, color: Color(0xFFEF4444), size: 16),
                                            label: const Text('Clear All Images', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 12)),
                                          ),
                                        ],
                                      ),
                                    ] else ...[
                                      InkWell(
                                        onTap: _pickImagesFromGallery,
                                        borderRadius: BorderRadius.circular(12),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 14.0),
                                          child: Column(
                                            children: [
                                              Icon(
                                                _isDragging ? Icons.file_download_outlined : Icons.add_photo_alternate_outlined,
                                                size: 46,
                                                color: _isDragging ? const Color(0xFF2563EB) : const Color(0xFF051C48),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                _isDragging ? 'Drop Images Here to Upload' : 'Upload Product Images (Multiple Allowed)',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: _isDragging ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              const Text('Supports JPG, PNG, WEBP, GIF formats (Multiple selection supported)', style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8))),
                                              const SizedBox(height: 12),
                                              ElevatedButton.icon(
                                                onPressed: _pickImagesFromGallery,
                                                icon: const Icon(Icons.photo_library_outlined, size: 16, color: Colors.white),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFF051C48),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                                ),
                                                label: const Text('Choose Images', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              const SizedBox(height: 20),

                              // --- 6B. PRODUCT VIDEO SECTION (OPTIONAL) ---
                              _buildFieldHeader('Product Video (Optional)'),
                              const SizedBox(height: 4),
                              const Text(
                                'Add a video to showcase this item. In the POS screen, the video plays first, and when completed, automatically slides to images.',
                                style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 8),

                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (_isVideoLoading) ...[
                                      Container(
                                        height: 140,
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
                                                width: 30,
                                                height: 30,
                                                child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF051C48)),
                                              ),
                                              SizedBox(height: 10),
                                              Text('Loading video...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ] else if ((_selectedVideoBytes != null && _selectedVideoBytes!.isNotEmpty) ||
                                        (_selectedVideoPath != null && _selectedVideoPath!.isNotEmpty) ||
                                        (_remoteVideoUrl != null && _remoteVideoUrl!.trim().isNotEmpty)) ...[
                                      // Video is attached!
                                      if (_previewVideoController != null && _isVideoInitialized) ...[
                                        // Active Video Player Preview
                                        Stack(
                                          children: [
                                            Container(
                                              height: 200,
                                              width: double.infinity,
                                              decoration: BoxDecoration(
                                                color: Colors.black,
                                                borderRadius: BorderRadius.circular(14),
                                              ),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(14),
                                                child: FittedBox(
                                                  fit: BoxFit.contain,
                                                  child: SizedBox(
                                                    width: _previewVideoController!.value.size.width > 0 ? _previewVideoController!.value.size.width : 300,
                                                    height: _previewVideoController!.value.size.height > 0 ? _previewVideoController!.value.size.height : 200,
                                                    child: VideoPlayer(_previewVideoController!),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            // Video Controls Overlay
                                            Positioned(
                                              bottom: 8,
                                              left: 8,
                                              right: 8,
                                              child: Row(
                                                children: [
                                                  // Play / Pause
                                                  InkWell(
                                                    onTap: () {
                                                      setState(() {
                                                        if (_previewVideoController!.value.isPlaying) {
                                                          _previewVideoController!.pause();
                                                        } else {
                                                          _previewVideoController!.play();
                                                        }
                                                      });
                                                    },
                                                    child: Container(
                                                      padding: const EdgeInsets.all(6),
                                                      decoration: BoxDecoration(
                                                        color: Colors.black.withValues(alpha: 0.65),
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: Icon(
                                                        _previewVideoController!.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                                        color: Colors.white,
                                                        size: 20,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  // Mute / Unmute
                                                  InkWell(
                                                    onTap: () {
                                                      setState(() {
                                                        _isVideoMuted = !_isVideoMuted;
                                                        _previewVideoController!.setVolume(_isVideoMuted ? 0.0 : 1.0);
                                                      });
                                                    },
                                                    child: Container(
                                                      padding: const EdgeInsets.all(6),
                                                      decoration: BoxDecoration(
                                                        color: Colors.black.withValues(alpha: 0.65),
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: Icon(
                                                        _isVideoMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                                                        color: Colors.white,
                                                        size: 20,
                                                      ),
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  // Replay from start
                                                  InkWell(
                                                    onTap: () {
                                                      _previewVideoController!.seekTo(Duration.zero);
                                                      _previewVideoController!.play();
                                                      setState(() {});
                                                    },
                                                    child: Container(
                                                      padding: const EdgeInsets.all(6),
                                                      decoration: BoxDecoration(
                                                        color: Colors.black.withValues(alpha: 0.65),
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: const Icon(Icons.replay_rounded, color: Colors.white, size: 20),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // Badge
                                            Positioned(
                                              top: 8,
                                              left: 8,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: YouTubeService.isYouTubeUrl(_remoteVideoUrl ?? '')
                                                      ? const Color(0xFFDC2626)
                                                      : const Color(0xFF0284C7),
                                                  borderRadius: BorderRadius.circular(6),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black.withValues(alpha: 0.3),
                                                      blurRadius: 4,
                                                      offset: const Offset(0, 1),
                                                    ),
                                                  ],
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      YouTubeService.isYouTubeUrl(_remoteVideoUrl ?? '')
                                                          ? Icons.play_circle_fill_rounded
                                                          : Icons.videocam_rounded,
                                                      color: Colors.white,
                                                      size: 13,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      YouTubeService.isYouTubeUrl(_remoteVideoUrl ?? '')
                                                          ? 'YouTube Video'
                                                          : (_selectedVideoFileName ?? 'Video Attached'),
                                                      style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ] else ...[
                                        // Video Attached Info Box
                                        Container(
                                          padding: const EdgeInsets.all(14),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(14),
                                            border: Border.all(
                                              color: YouTubeService.isYouTubeUrl(_remoteVideoUrl ?? '')
                                                  ? const Color(0xFFFCA5A5)
                                                  : const Color(0xFF93C5FD),
                                              width: 1.2,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 48,
                                                height: 48,
                                                decoration: BoxDecoration(
                                                  color: YouTubeService.isYouTubeUrl(_remoteVideoUrl ?? '')
                                                      ? const Color(0xFFFEE2E2)
                                                      : const Color(0xFFE0F2FE),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Icon(
                                                  YouTubeService.isYouTubeUrl(_remoteVideoUrl ?? '')
                                                      ? Icons.play_circle_fill_rounded
                                                      : Icons.videocam_rounded,
                                                  color: YouTubeService.isYouTubeUrl(_remoteVideoUrl ?? '')
                                                      ? const Color(0xFFDC2626)
                                                      : const Color(0xFF0284C7),
                                                  size: 26,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: YouTubeService.isYouTubeUrl(_remoteVideoUrl ?? '')
                                                                ? const Color(0xFFDC2626)
                                                                : const Color(0xFF0284C7),
                                                            borderRadius: BorderRadius.circular(4),
                                                          ),
                                                          child: Text(
                                                            YouTubeService.isYouTubeUrl(_remoteVideoUrl ?? '')
                                                                ? 'YouTube Attached'
                                                                : 'Video Attached',
                                                            style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      _selectedVideoFileName ?? _remoteVideoUrl ?? 'Product Video',
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    const Text(
                                                      'Video is attached and ready. Will stream in POS cards.',
                                                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 10),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          ElevatedButton.icon(
                                            onPressed: _pickVideo,
                                            icon: const Icon(Icons.movie_edit, size: 15, color: Colors.white),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF051C48),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                            ),
                                            label: const Text('Change Video', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                          ),
                                          const SizedBox(width: 8),
                                          OutlinedButton.icon(
                                            onPressed: _removeVideo,
                                            icon: const Icon(Icons.delete_outline, size: 15, color: Color(0xFFEF4444)),
                                            style: OutlinedButton.styleFrom(
                                              side: const BorderSide(color: Color(0xFFEF4444)),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                            ),
                                            label: const Text('Remove Video', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 12)),
                                          ),
                                        ],
                                      ),
                                    ] else ...[
                                      // Options to pick video or enter URL
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed: _pickVideo,
                                              icon: const Icon(Icons.video_library_outlined, size: 16, color: Colors.white),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF051C48),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                padding: const EdgeInsets.symmetric(vertical: 12),
                                              ),
                                              label: const Text('Upload Video File', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5)),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              controller: _videoUrlController,
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                              decoration: InputDecoration(
                                                hintText: 'Enter YouTube link or video URL (e.g. youtu.be/...)',
                                                hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                                                prefixIcon: const Icon(Icons.smart_display_rounded, size: 18, color: Color(0xFFDC2626)),
                                                filled: true,
                                                fillColor: const Color(0xFFF8FAFC),
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                enabledBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(10),
                                                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                                ),
                                                focusedBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(10),
                                                  borderSide: const BorderSide(color: Color(0xFF051C48), width: 1.5),
                                                ),
                                              ),
                                              onSubmitted: (val) {
                                                final url = val.trim();
                                                if (url.isNotEmpty) {
                                                  _remoteVideoUrl = url;
                                                  _initPreviewVideo(url, isFile: false);
                                                }
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton(
                                            onPressed: () {
                                              final url = _videoUrlController.text.trim();
                                              if (url.isNotEmpty) {
                                                _remoteVideoUrl = url;
                                                _initPreviewVideo(url, isFile: false);
                                              }
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF0284C7),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                            ),
                                            child: const Text('Add Video', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                          ),
                                        ],
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
