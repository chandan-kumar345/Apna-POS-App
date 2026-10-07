import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_win/video_player_win.dart';
import 'package:path_provider/path_provider.dart';
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
  final String? initialCategory;

  const AddProductScreen({
    super.key,
    this.editItem,
    this.initialCategory,
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
    if (widget.initialCategory != null && widget.initialCategory!.isNotEmpty) {
      _selectedCategory = widget.initialCategory!;
    } else if (db.categories.isNotEmpty) {
      _selectedCategory = db.categories.first;
    }

    // Default GST from onboarding restaurant configuration
    final bool isNonGstRestaurant = db.restaurant?.billingType == 'Non-GST';
    _selectedGstPercent = isNonGstRestaurant ? 0.0 : (db.restaurant?.taxRate ?? 5.0);

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
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
        ),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _pickImagesFromGallery() async {
    setState(() => _isImageLoading = true);
    try {
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

  Future<void> _initPreviewVideo(String source, {bool isFile = false}) async {
    final cleanSource = source.trim();
    if (cleanSource.isEmpty) return;

    setState(() {
      _isVideoLoading = true;
      _isVideoInitialized = false;
    });

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      try {
        WindowsVideoPlayer.registerWith();
      } catch (_) {}
    }

    try {
      _previewVideoController?.dispose();
      _previewVideoController = null;

      if (YouTubeService.isYouTubeUrl(cleanSource)) {
        final vidId = YouTubeService.extractVideoId(cleanSource);
        if (vidId != null && vidId.isNotEmpty && _selectedImages.isEmpty) {
          final thumbUrl = YouTubeService.getThumbnailUrl(vidId);
          _selectedImages.add(ProductImageItem(
            remoteUrl: thumbUrl,
            path: thumbUrl,
            name: 'YouTube Cover Thumbnail',
          ));
        }
      }

      final playablePath = await YouTubeService.getPlayableVideoPath(cleanSource);
      if (playablePath == null || playablePath.isEmpty) {
        throw Exception('Could not resolve playable video: $cleanSource');
      }

      if (!kIsWeb && File(playablePath).existsSync()) {
        _previewVideoController = VideoPlayerController.file(
          File(playablePath),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
      } else if (playablePath.startsWith('assets/')) {
        _previewVideoController = VideoPlayerController.asset(
          playablePath,
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
      } else if (playablePath.startsWith('http://') || playablePath.startsWith('https://')) {
        var netUrl = playablePath;
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows && netUrl.contains('localhost:')) {
          netUrl = netUrl.replaceAll('localhost:', '127.0.0.1:');
        }
        _previewVideoController = VideoPlayerController.networkUrl(
          Uri.parse(netUrl),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
      } else {
        if (kIsWeb) {
          _previewVideoController = VideoPlayerController.networkUrl(
            Uri.parse(playablePath),
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          );
        } else {
          _previewVideoController = VideoPlayerController.file(
            File(playablePath),
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          );
        }
      }

      await _previewVideoController!.initialize();
      await _previewVideoController!.setVolume(_isVideoMuted ? 0.0 : 1.0);
      await _previewVideoController!.setLooping(true);
      _previewVideoController!.addListener(() {
        if (mounted) setState(() {});
      });
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

  Future<String?> _persistVideoLocally(String? sourcePath, Uint8List? bytes, String fileName) async {
    if (kIsWeb) return sourcePath;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final videosDir = Directory('${appDir.path}${Platform.pathSeparator}saved_product_videos');
      if (!videosDir.existsSync()) {
        videosDir.createSync(recursive: true);
      }
      final cleanExt = fileName.contains('.') ? '.${fileName.split('.').last}' : '.mp4';
      final cleanName = 'vid_${DateTime.now().millisecondsSinceEpoch}$cleanExt';
      final targetFile = File('${videosDir.path}${Platform.pathSeparator}$cleanName');

      if (sourcePath != null && sourcePath.isNotEmpty && File(sourcePath).existsSync()) {
        await File(sourcePath).copy(targetFile.path);
        return targetFile.path;
      } else if (bytes != null && bytes.isNotEmpty) {
        await targetFile.writeAsBytes(bytes);
        return targetFile.path;
      }
    } catch (e) {
      debugPrint('[_persistVideoLocally] note: $e');
    }
    return sourcePath;
  }

  Future<void> _pickVideo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final persistentPath = await _persistVideoLocally(file.path, file.bytes, file.name) ?? file.path;
        setState(() {
          _selectedVideoPath = persistentPath;
          _selectedVideoBytes = file.bytes;
          _selectedVideoFileName = file.name;
          _remoteVideoUrl = null;
          _videoUrlController.clear();
        });
        if (persistentPath != null && persistentPath.isNotEmpty) {
          _initPreviewVideo(persistentPath, isFile: true);
        }
        _showSuccessSnackBar('Video selected: ${file.name}');
        return;
      }
    } catch (e) {
      debugPrint('[_pickVideo] FilePicker fallback: $e');
    }

    try {
      final picker = ImagePicker();
      final pickedVideo = await picker.pickVideo(source: ImageSource.gallery);
      if (pickedVideo != null) {
        final bytes = await pickedVideo.readAsBytes();
        final persistentPath = await _persistVideoLocally(pickedVideo.path, bytes, pickedVideo.name) ?? pickedVideo.path;
        setState(() {
          _selectedVideoPath = persistentPath;
          _selectedVideoBytes = bytes;
          _selectedVideoFileName = pickedVideo.name;
          _remoteVideoUrl = null;
          _videoUrlController.clear();
        });
        _initPreviewVideo(persistentPath, isFile: true);
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
          color: const Color(0xFFE5EDF6),
          child: const Center(child: Icon(Icons.broken_image_rounded, color: Color(0xFF94A3B8), size: 20)),
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
      color: const Color(0xFFE5EDF6),
      child: const Center(child: Icon(Icons.broken_image_rounded, color: Color(0xFF94A3B8), size: 20)),
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
          final dialogWidth = screenWidth > 600 ? 460.0 : (screenWidth * 0.9).clamp(300.0, 460.0);

          return AlertDialog(
            backgroundColor: const Color(0xFFF0F4F8),
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Colors.white, width: 1.5),
            ),
            titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            contentPadding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            title: const Text(
              'Add Variant',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w900, fontSize: 16),
            ),
            content: SizedBox(
              width: dialogWidth,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Variant Name*', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                    const SizedBox(height: 5),
                    _buildNeumorphicInputField(
                      controller: vNameCtrl,
                      hintText: 'e.g. Half, Full, 500g, Regular',
                    ),
                    const SizedBox(height: 10),
                    Text('Variant Price (${db.restaurant?.currencySymbol ?? "₹"})*', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                    const SizedBox(height: 5),
                    _buildNeumorphicInputField(
                      controller: vPriceCtrl,
                      hintText: 'Price',
                      keyboardType: TextInputType.number,
                      onChanged: (_) {
                        if (vAddDiscount) calcVariantSalePrice();
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Transform.scale(
                          scale: 0.8,
                          child: Switch(
                            value: vAddDiscount,
                            activeTrackColor: const Color(0xFF021B54),
                            activeThumbColor: Colors.white,
                            inactiveTrackColor: const Color(0xFFCBD5E1),
                            onChanged: (val) {
                              setDialogState(() {
                                vAddDiscount = val;
                                if (val) calcVariantSalePrice();
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text('Add Discount', style: TextStyle(color: Color(0xFF0F172A), fontSize: 12.5, fontWeight: FontWeight.w800)),
                      ],
                    ),
                    if (vAddDiscount) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Discount (%)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                                const SizedBox(height: 4),
                                _buildNeumorphicInputField(
                                  controller: vDiscCtrl,
                                  hintText: '10%',
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => calcVariantSalePrice(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Sale Price', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                                const SizedBox(height: 4),
                                _buildNeumorphicInputField(
                                  controller: vSalePriceCtrl,
                                  hintText: 'Sale Price',
                                  keyboardType: TextInputType.number,
                                  onChanged: (val) => calcVariantDiscountPct(val),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700, fontSize: 12.5)),
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
                    _priceController.text = '0';
                  });
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF021B54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: const Text('Add Variant', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5)),
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
        backgroundColor: const Color(0xFFF0F4F8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.white, width: 1.5),
        ),
        contentPadding: const EdgeInsets.all(18),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text(
                  'New Category',
                  style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Category Name*', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
              const SizedBox(height: 5),
              _buildNeumorphicInputField(
                controller: _categoryController,
                hintText: 'e.g. Desserts, Beverages, Starters',
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700, fontSize: 12.5)),
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
                      backgroundColor: const Color(0xFF021B54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: const Text('Create', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5)),
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
      _showErrorSnackBar('Product title is required!');
      return;
    }

    final String catName = _selectedCategory.trim().isNotEmpty
        ? _selectedCategory.trim()
        : (db.categories.isNotEmpty ? db.categories.first : 'Main Course');

    final String foodType = _selectedType.trim().isNotEmpty ? _selectedType.trim() : 'Veg';

    if (price <= 0 && _variants.isEmpty) {
      _showErrorSnackBar('Price is required! Please enter a price or add variants.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final discountVal = double.tryParse(_discountController.text.trim()) ?? 0.0;
      final stockVal = int.tryParse(_stockController.text.trim()) ?? 50;

      // 1. Process & Upload All Images
      List<String> finalImageUrls = [];
      for (int i = 0; i < _selectedImages.length; i++) {
        final img = _selectedImages[i];
        if (img.remoteUrl != null && img.remoteUrl!.isNotEmpty) {
          finalImageUrls.add(ApiEndpoints.resolveMediaUrl(img.remoteUrl!));
        } else if (img.bytes != null && img.bytes!.isNotEmpty) {
          String? uploadedUrl;
          try {
            uploadedUrl = await UploadService().uploadImageBytes(
              img.bytes!,
              fileName: (img.name != null && img.name!.isNotEmpty) ? img.name! : 'product_${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
            );
          } catch (e) {
            debugPrint('[AddProductScreen] image bytes upload error: $e');
          }
          if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
            finalImageUrls.add(ApiEndpoints.resolveMediaUrl(uploadedUrl));
          } else {
            final base64Data = 'data:image/jpeg;base64,${base64Encode(img.bytes!)}';
            finalImageUrls.add(base64Data);
          }
        } else if (img.path != null && img.path!.isNotEmpty) {
          if (img.path!.startsWith('http://') || img.path!.startsWith('https://') || img.path!.startsWith('data:')) {
            finalImageUrls.add(img.path!);
          } else {
            String? uploadedUrl;
            Uint8List? localBytes;
            try {
              final file = File(img.path!);
              if (file.existsSync()) {
                localBytes = await file.readAsBytes();
                uploadedUrl = await UploadService().uploadImage(file);
              }
            } catch (e) {
              debugPrint('[AddProductScreen] image file upload error: $e');
            }

            if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
              finalImageUrls.add(ApiEndpoints.resolveMediaUrl(uploadedUrl));
            } else if (localBytes != null && localBytes.isNotEmpty) {
              final base64Data = 'data:image/jpeg;base64,${base64Encode(localBytes)}';
              finalImageUrls.add(base64Data);
            } else {
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

      if (_selectedVideoPath != null &&
          _selectedVideoPath!.isNotEmpty &&
          !_selectedVideoPath!.startsWith('http')) {
        try {
          final file = File(_selectedVideoPath!);
          if (file.existsSync()) {
            final uploadedVideo = await UploadService().uploadVideo(file, folder: 'products/videos');
            if (uploadedVideo != null && uploadedVideo.isNotEmpty) {
              finalVideoUrl = ApiEndpoints.resolveMediaUrl(uploadedVideo);
            }
          }
        } catch (e) {
          debugPrint('[AddProductScreen] video file upload error: $e');
        }
      } else if (_selectedVideoBytes != null && _selectedVideoBytes!.isNotEmpty) {
        try {
          final uploadedVideo = await UploadService().uploadVideoBytes(
            _selectedVideoBytes!,
            fileName: _selectedVideoFileName ?? 'video_${DateTime.now().millisecondsSinceEpoch}.mp4',
            folder: 'products/videos',
          );
          if (uploadedVideo != null && uploadedVideo.isNotEmpty) {
            finalVideoUrl = ApiEndpoints.resolveMediaUrl(uploadedVideo);
          }
        } catch (e) {
          debugPrint('[AddProductScreen] video bytes upload error: $e');
        }
      }

      // Fallback thumbnail from YouTube
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
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFF021B54),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Column(
            children: [
              // Top Header Bar
              _buildTopHeader(),

              // Curved Neumorphic Sheet Container
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF0F4F8),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x30001C55),
                        blurRadius: 18,
                        offset: Offset(0, -4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    child: Column(
                      children: [
                        // Scrollable Content
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 1. Basic Info Card (Title, Description, Category)
                                _buildBasicInfoCard(),

                                // 2. Food Type Selector Card
                                _buildFoodTypeCard(),

                                // 3. Pricing & Discount Card
                                _buildPricingCard(),

                                // 4. Images Gallery Card
                                _buildImagesCard(),

                                // 5. Video Card (Optional)
                                _buildVideoCard(),

                                // 6. Variants Accordion Card
                                _buildVariantsAccordion(),

                                // 7. GST Accordion Card
                                _buildGstAccordion(),

                                // 8. Inventory Accordion Card
                                _buildInventoryAccordion(),

                                const SizedBox(height: 10),
                              ],
                            ),
                          ),
                        ),

                        // Sticky Bottom Save Action Bar
                        _buildStickyBottomBar(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Top Header ---
  Widget _buildTopHeader() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              widget.editItem != null ? 'Edit Product' : 'Add Product',
              style: const TextStyle(
                fontSize: 17.5,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),
            const Spacer(),
            if (widget.editItem != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0066FF).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF0066FF).withValues(alpha: 0.5), width: 1),
                ),
                child: const Text(
                  'Editing',
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --- Sticky Bottom Save Button ---
  Widget _buildStickyBottomBar() {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        bottomPadding > 0 ? bottomPadding + 6 : 12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [
              Color(0xFF021B54),
              Color(0xFF002B7A),
              Color(0xFF003D9E),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF021B54).withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isSaving ? null : _saveProduct,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                )
              : Text(
                  widget.editItem != null ? 'Update Product' : 'Save Product',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
        ),
      ),
    );
  }

  // --- Helper: Neumorphic Outer Card ---
  Widget _buildNeumorphicCard({required Widget child, EdgeInsetsGeometry? padding, EdgeInsetsGeometry? margin}) {
    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: 10),
      padding: padding ?? const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF5FB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x16002870),
            blurRadius: 7,
            offset: Offset(2, 3),
          ),
          BoxShadow(
            color: Colors.white,
            blurRadius: 5,
            offset: Offset(-2, -2),
          ),
        ],
      ),
      child: child,
    );
  }

  // --- Helper: Neumorphic Input Field (Left-Aligned, Vertically Centered) ---
  Widget _buildNeumorphicInputField({
    required TextEditingController controller,
    required String hintText,
    bool enabled = true,
    TextInputType? keyboardType,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
    Widget? suffix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: enabled ? const Color(0xFFE5EDF6) : const Color(0xFFDCE5EE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12002870),
            blurRadius: 4,
            offset: Offset(1, 2),
          ),
          BoxShadow(
            color: Colors.white,
            blurRadius: 3,
            offset: Offset(-1, -1),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        textAlign: TextAlign.start,
        textAlignVertical: TextAlignVertical.center,
        maxLines: maxLines,
        keyboardType: keyboardType,
        onChanged: onChanged,
        style: TextStyle(
          color: enabled ? const Color(0xFF0F172A) : const Color(0xFF64748B),
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5, fontWeight: FontWeight.w500),
          suffixIcon: suffix,
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: maxLines > 1 ? 10 : 11),
          border: InputBorder.none,
          isDense: true,
        ),
      ),
    );
  }

  // --- Helper: Section Title Header (NO ICONS, INCREASED FONT SIZE) ---
  Widget _buildSectionTitle(String title, {Widget? trailing}) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
            letterSpacing: 0.1,
          ),
        ),
        if (trailing != null) ...[
          const Spacer(),
          trailing,
        ],
      ],
    );
  }

  // 1. Basic Info Card
  Widget _buildBasicInfoCard() {
    return _buildNeumorphicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // _buildSectionTitle('Basic Info'),
          // const SizedBox(height: 10),

          // Title Field
          const Text('Title*', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
          const SizedBox(height: 5),
          _buildNeumorphicInputField(
            controller: _titleController,
            hintText: 'Product Name',
          ),

          const SizedBox(height: 10),

          // Description Field
          const Text('Description (Optional)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
          const SizedBox(height: 5),
          _buildNeumorphicInputField(
            controller: _descriptionController,
            hintText: 'Product Description',
            maxLines: 2,
          ),

          const SizedBox(height: 10),

          // Category Selector Row
          const Text('Category*', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final currentCat = db.categories.contains(_selectedCategory)
                        ? _selectedCategory
                        : (db.categories.isNotEmpty ? db.categories.first : null);
                    return Theme(
                      data: Theme.of(context).copyWith(
                        hoverColor: Colors.transparent,
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                      ),
                      child: PopupMenuButton<String>(
                        position: PopupMenuPosition.under,
                        offset: const Offset(0, 4),
                        elevation: 6,
                        shadowColor: const Color(0x25002870),
                        color: const Color(0xFFEFF5FB),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: Colors.white, width: 1.2),
                        ),
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth,
                          maxWidth: constraints.maxWidth,
                          maxHeight: 250,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        onSelected: (val) {
                          setState(() => _selectedCategory = val);
                        },
                        itemBuilder: (context) {
                          return db.categories.map((cat) {
                            final isSelected = cat == currentCat;
                            return PopupMenuItem<String>(
                              value: cat,
                              height: 38,
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF021B54) : const Color(0xFFE5EDF6),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF021B54) : Colors.white.withValues(alpha: 0.9),
                                    width: 1,
                                  ),
                                  boxShadow: isSelected
                                      ? const [
                                          BoxShadow(
                                            color: Color(0x30021B54),
                                            blurRadius: 4,
                                            offset: Offset(0, 2),
                                          ),
                                        ]
                                      : const [
                                          BoxShadow(
                                            color: Color(0x10002870),
                                            blurRadius: 2,
                                            offset: Offset(1, 1),
                                          ),
                                          BoxShadow(
                                            color: Colors.white,
                                            blurRadius: 2,
                                            offset: Offset(-1, -1),
                                          ),
                                        ],
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        cat,
                                        style: TextStyle(
                                          color: isSelected ? Colors.white : const Color(0xFF0F172A),
                                          fontSize: 12,
                                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }).toList();
                        },
                        child: Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5EDF6),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white, width: 1.2),
                            boxShadow: const [
                              BoxShadow(color: Color(0x12002870), blurRadius: 4, offset: Offset(1, 2)),
                              BoxShadow(color: Colors.white, blurRadius: 3, offset: Offset(-1, -1)),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  currentCat ?? 'Select Category',
                                  style: const TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Color(0xFF021B54),
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _addNewCategoryDialog,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF021B54),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(color: Color(0x20002870), blurRadius: 4, offset: Offset(0, 2)),
                    ],
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 2. Food Type Selector Card
  Widget _buildFoodTypeCard() {
    return _buildNeumorphicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Food Type*', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                _buildDietaryOption('Veg', const Color(0xFF10B981), _selectedType == 'Veg', () => setState(() => _selectedType = 'Veg')),
                const SizedBox(width: 8),
                _buildDietaryOption('Non-Veg', const Color(0xFFEF4444), _selectedType == 'Non-Veg', () => setState(() => _selectedType = 'Non-Veg')),
                const SizedBox(width: 8),
                _buildDietaryOption('Egg', const Color(0xFFD97706), _selectedType == 'Egg', () => setState(() => _selectedType = 'Egg')),
                const SizedBox(width: 8),
                _buildDietaryOption('Beverage', const Color(0xFF0284C7), _selectedType == 'Beverage', () => setState(() => _selectedType = 'Beverage')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDietaryOption(String label, Color color, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? color : const Color(0xFFE5EDF6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? color : Colors.white, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: isSelected ? color.withValues(alpha: 0.35) : const Color(0x12002870),
              blurRadius: isSelected ? 5 : 3,
              offset: const Offset(1, 2),
            ),
            if (!isSelected)
              const BoxShadow(
                color: Colors.white,
                blurRadius: 3,
                offset: Offset(-1, -1),
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.transparent,
                border: Border.all(color: isSelected ? Colors.white : color, width: 1.5),
                borderRadius: BorderRadius.circular(3.5),
              ),
              child: Center(
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
                color: isSelected ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 3. Pricing & Discount Card
  Widget _buildPricingCard() {
    final currency = db.restaurant?.currencySymbol ?? '₹';
    final hasVariants = _variants.isNotEmpty;

    return _buildNeumorphicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // _buildSectionTitle('Pricing & Discount'),
          // const SizedBox(height: 10),

          // Price Field
          Text('Price ($currency)*', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
          const SizedBox(height: 5),
          _buildNeumorphicInputField(
            controller: _priceController,
            enabled: !hasVariants,
            hintText: hasVariants ? '0 (Managed by variants)' : '$currency 100',
            keyboardType: TextInputType.number,
          ),
          if (hasVariants) ...[
            const SizedBox(height: 3),
            const Text(
              'Price is locked to 0 because variants are active.',
              style: TextStyle(color: Color(0xFF0284C7), fontSize: 10.5, fontWeight: FontWeight.w700),
            ),
          ],

          const SizedBox(height: 10),

          // Discount Switch Row
          Row(
            children: [
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: _addDiscount,
                  activeTrackColor: const Color(0xFF021B54),
                  activeThumbColor: Colors.white,
                  inactiveTrackColor: const Color(0xFFCBD5E1),
                  onChanged: (val) => setState(() => _addDiscount = val),
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'Add Discount',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),

          if (_addDiscount) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Discount (%)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                      const SizedBox(height: 4),
                      _buildNeumorphicInputField(
                        controller: _discountController,
                        hintText: 'e.g. 15%',
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Sale Price', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                      const SizedBox(height: 4),
                      _buildNeumorphicInputField(
                        controller: _salePriceController,
                        hintText: 'Sale Price',
                        keyboardType: TextInputType.number,
                        onChanged: _onSalePriceChanged,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // 4. Images Gallery Card
  Widget _buildImagesCard() {
    return _buildNeumorphicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            'Images (${_selectedImages.length})',
            trailing: _selectedImages.isNotEmpty
                ? InkWell(
                    onTap: _pickImagesFromGallery,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF021B54),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('+ Add', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 8),

          if (_isImageLoading) ...[
            Container(
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFE5EDF6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white, width: 1.2),
              ),
              child: const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF021B54)),
                ),
              ),
            ),
          ] else if (_selectedImages.isNotEmpty) ...[
            // Main Preview Box
            Builder(builder: (context) {
              final safeIndex = _activeImagePreviewIndex < _selectedImages.length ? _activeImagePreviewIndex : 0;
              final activeItem = _selectedImages[safeIndex];
              final bool isCover = safeIndex == 0;

              return Stack(
                children: [
                  Container(
                    height: 140,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5EDF6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white, width: 1.2),
                      boxShadow: const [
                        BoxShadow(color: Color(0x10002870), blurRadius: 4, offset: Offset(0, 2)),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: _buildProductImageItem(activeItem),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: isCover ? const Color(0xFF16A34A) : Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isCover ? 'PRIMARY COVER' : 'Image ${safeIndex + 1} of ${_selectedImages.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              );
            }),

            const SizedBox(height: 8),

            // Thumbnail Strip
            SizedBox(
              height: 60,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _selectedImages.length + 1,
                separatorBuilder: (context, index) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  if (index == _selectedImages.length) {
                    return InkWell(
                      onTap: _pickImagesFromGallery,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5EDF6),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white, width: 1.2),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_rounded, color: Color(0xFF021B54), size: 18),
                            SizedBox(height: 2),
                            Text('+ Add', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF021B54))),
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
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF021B54) : Colors.white,
                              width: isSelected ? 2 : 1.2,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
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
                            child: const Text('Cover', style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold)),
                          ),
                        ),
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
                                  padding: const EdgeInsets.all(1),
                                  margin: const EdgeInsets.only(right: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.65),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.star, color: Colors.amber, size: 10),
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
                                padding: const EdgeInsets.all(1),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.85),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, color: Colors.white, size: 10),
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
          ] else ...[
            // Empty Upload Card
            InkWell(
              onTap: _pickImagesFromGallery,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5EDF6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white, width: 1.2),
                  boxShadow: const [
                    BoxShadow(color: Color(0x10002870), blurRadius: 4, offset: Offset(1, 2)),
                    BoxShadow(color: Colors.white, blurRadius: 3, offset: Offset(-1, -1)),
                  ],
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined, color: Color(0xFF021B54), size: 28),
                    SizedBox(height: 4),
                    Text(
                      'Upload Product Images',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'JPG, PNG, WEBP',
                      style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 5. Video Card (Optional)
  Widget _buildVideoCard() {
    final bool hasVideo = (_selectedVideoBytes != null && _selectedVideoBytes!.isNotEmpty) ||
        (_selectedVideoPath != null && _selectedVideoPath!.isNotEmpty) ||
        (_remoteVideoUrl != null && _remoteVideoUrl!.trim().isNotEmpty);

    return _buildNeumorphicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Video (Optional)'),
          const SizedBox(height: 8),

          if (_isVideoLoading) ...[
            Container(
              height: 90,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFE5EDF6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white, width: 1.2),
              ),
              child: const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF021B54)),
                ),
              ),
            ),
          ] else if (hasVideo) ...[
            if (_previewVideoController != null && _isVideoInitialized) ...[
              // Video Player Preview
              Stack(
                children: [
                  Container(
                    height: 140,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
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
                  Positioned(
                    bottom: 6,
                    left: 6,
                    right: 6,
                    child: Row(
                      children: [
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
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _previewVideoController!.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _isVideoMuted = !_isVideoMuted;
                              _previewVideoController!.setVolume(_isVideoMuted ? 0.0 : 1.0);
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isVideoMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () {
                            _previewVideoController!.seekTo(Duration.zero);
                            _previewVideoController!.play();
                            setState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.replay_rounded, color: Colors.white, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5EDF6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white, width: 1.2),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _selectedVideoFileName ?? _remoteVideoUrl ?? 'Video Attached',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                InkWell(
                  onTap: _pickVideo,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF021B54),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('Change', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: _removeVideo,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('Remove', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: _buildNeumorphicInputField(
                    controller: _videoUrlController,
                    hintText: 'YouTube or Video link',
                    onChanged: (val) {},
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () {
                    final url = _videoUrlController.text.trim();
                    if (url.isNotEmpty) {
                      _remoteVideoUrl = url;
                      _initPreviewVideo(url, isFile: false);
                    }
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: const Color(0xFF021B54),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text('Link', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: _pickVideo,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5EDF6),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white, width: 1.2),
                    ),
                    child: const Icon(Icons.file_upload_outlined, color: Color(0xFF021B54), size: 16),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // 6. Variants Accordion Card
  Widget _buildVariantsAccordion() {
    final currency = db.restaurant?.currencySymbol ?? '₹';

    return Column(
      children: [
        _buildAccordionHeader(
          title: 'Variants (Optional) (${_variants.length})',
          isExpanded: _isVariantsExpanded,
          onToggle: () => setState(() => _isVariantsExpanded = !_isVariantsExpanded),
        ),
        if (_isVariantsExpanded)
          _buildNeumorphicCard(
            margin: const EdgeInsets.only(top: 4, bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Variant Options', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w800, fontSize: 13)),
                    InkWell(
                      onTap: _addVariantDialog,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF021B54),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_rounded, color: Colors.white, size: 14),
                            SizedBox(width: 2),
                            Text('Add', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (_variants.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Column(
                    children: _variants.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final v = entry.value;
                      final effectivePrice = v.hasDiscount && v.discountPercent > 0
                          ? v.price * (1 - v.discountPercent / 100)
                          : v.price;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5EDF6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white, width: 1.2),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(v.name, style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w800, fontSize: 12)),
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
                                  style: const TextStyle(color: Color(0xFF021B54), fontWeight: FontWeight.w900, fontSize: 12.5),
                                ),
                                if (v.hasDiscount && v.discountPercent > 0)
                                  Text(
                                    '$currency ${v.price.toStringAsFixed(0)}',
                                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10, decoration: TextDecoration.lineThrough),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _variants.removeAt(idx);
                                  if (_variants.isEmpty && widget.editItem != null) {
                                    _priceController.text = widget.editItem!.price.toStringAsFixed(0);
                                  }
                                });
                              },
                              child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 17),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  // 7. GST Accordion Card
  Widget _buildGstAccordion() {
    return Column(
      children: [
        _buildAccordionHeader(
          title: 'GST Tax (Optional)',
          isExpanded: _isGstExpanded,
          onToggle: () => setState(() => _isGstExpanded = !_isGstExpanded),
        ),
        if (_isGstExpanded)
          _buildNeumorphicCard(
            margin: const EdgeInsets.only(top: 4, bottom: 10),
            child: SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                children: [0.0, 5.0, 12.0, 18.0, 28.0].map((rate) {
                  final bool isNonGst = db.restaurant?.billingType == 'Non-GST';
                  final isSel = _selectedGstPercent == rate ||
                      (_selectedGstPercent == null && rate == (isNonGst ? 0.0 : (db.restaurant?.taxRate ?? 5.0)));
                  final label = rate == 0.0 ? '0% GST' : '$rate%';

                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      onTap: () => setState(() => _selectedGstPercent = rate),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSel ? const Color(0xFF021B54) : const Color(0xFFE5EDF6),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isSel ? const Color(0xFF021B54) : Colors.white, width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: isSel ? const Color(0x25002870) : const Color(0x12002870),
                              blurRadius: 3,
                              offset: const Offset(1, 1),
                            ),
                            if (!isSel)
                              const BoxShadow(
                                color: Colors.white,
                                blurRadius: 3,
                                offset: Offset(-1, -1),
                              ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            label,
                            style: TextStyle(
                              color: isSel ? Colors.white : const Color(0xFF0F172A),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  // 8. Inventory Accordion Card
  Widget _buildInventoryAccordion() {
    return Column(
      children: [
        _buildAccordionHeader(
          title: 'Inventory Stock (Optional)',
          isExpanded: _isInventoryExpanded,
          onToggle: () => setState(() => _isInventoryExpanded = !_isInventoryExpanded),
        ),
        if (_isInventoryExpanded)
          _buildNeumorphicCard(
            margin: const EdgeInsets.only(top: 4, bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        value: _trackInventory,
                        activeTrackColor: const Color(0xFF021B54),
                        activeThumbColor: Colors.white,
                        inactiveTrackColor: const Color(0xFFCBD5E1),
                        onChanged: (val) => setState(() => _trackInventory = val),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Track Stock Inventory',
                      style: TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                if (_trackInventory) ...[
                  const SizedBox(height: 8),
                  const Text('Initial Stock Quantity', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                  const SizedBox(height: 5),
                  _buildNeumorphicInputField(
                    controller: _stockController,
                    hintText: '50',
                    keyboardType: TextInputType.number,
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  // --- Accordion Header Bar (NO ICONS, INCREASED FONT SIZE) ---
  Widget _buildAccordionHeader({
    required String title,
    required bool isExpanded,
    required VoidCallback onToggle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: isExpanded ? const Color(0xFF021B54) : const Color(0xFFE5EDF6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isExpanded ? const Color(0xFF021B54) : Colors.white, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: isExpanded ? const Color(0x20002870) : const Color(0x12002870),
                blurRadius: 4,
                offset: const Offset(1, 2),
              ),
              if (!isExpanded)
                const BoxShadow(
                  color: Colors.white,
                  blurRadius: 3,
                  offset: Offset(-1, -1),
                ),
            ],
          ),
          child: Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: isExpanded ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              Icon(
                isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                color: isExpanded ? Colors.white : const Color(0xFF021B54),
                size: 19,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
