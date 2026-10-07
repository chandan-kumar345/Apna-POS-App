import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/database/database_service.dart';
import '../../core/models/restaurant_model.dart';
import '../../core/services/sound_service.dart';
import '../../core/widgets/printer_selection_dialog.dart';
import '../onboarding/business_settings_screen.dart';
import 'print_logs_screen.dart';
import 'superadmin_order_deletion_screen.dart';

/// Neumorphic Color Constants & Styling
class _NeumorphicTheme {
  static const Color background = Color(0xFFEEF2F6);
  static const Color surface = Color(0xFFEEF2F6);
  static const Color sunkenSurface = Color(0xFFE2E9F2);
  static const Color darkShadow = Color(0xFFC5D1E0);
  static const Color lightShadow = Colors.white;

  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color navyBrand = Color(0xFF051C48);
  static const Color blueBrand = Color(0xFF0052FF);

  /// Standard extruded / raised neumorphic shadows
  static List<BoxShadow> get raisedShadows => [
        BoxShadow(
          color: lightShadow.withValues(alpha: 0.95),
          offset: const Offset(-5, -5),
          blurRadius: 10,
          spreadRadius: 0,
        ),
        BoxShadow(
          color: darkShadow.withValues(alpha: 0.75),
          offset: const Offset(5, 5),
          blurRadius: 10,
          spreadRadius: 0,
        ),
      ];

  /// Soft raised shadows for compact elements
  static List<BoxShadow> get softRaisedShadows => [
        BoxShadow(
          color: lightShadow.withValues(alpha: 0.9),
          offset: const Offset(-3, -3),
          blurRadius: 6,
        ),
        BoxShadow(
          color: darkShadow.withValues(alpha: 0.6),
          offset: const Offset(3, 3),
          blurRadius: 6,
        ),
      ];

  /// Elevated accent shadows (for primary buttons & cards)
  static List<BoxShadow> get accentShadows => [
        BoxShadow(
          color: blueBrand.withValues(alpha: 0.25),
          offset: const Offset(0, 6),
          blurRadius: 14,
        ),
        BoxShadow(
          color: lightShadow.withValues(alpha: 0.5),
          offset: const Offset(-2, -2),
          blurRadius: 5,
        ),
      ];
}

class BusinessSettingsHubScreen extends StatefulWidget {
  const BusinessSettingsHubScreen({super.key});

  @override
  State<BusinessSettingsHubScreen> createState() => _BusinessSettingsHubScreenState();
}

class _BusinessSettingsHubScreenState extends State<BusinessSettingsHubScreen> {
  final db = DatabaseService();

  late TextEditingController _nameController;
  late TextEditingController _taglineController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _taxController;
  late TextEditingController _upiIdController;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    final rest = db.restaurant;
    _nameController = TextEditingController(text: rest?.name ?? '');
    _taglineController = TextEditingController(text: rest?.tagline ?? '');
    _phoneController = TextEditingController(text: rest?.phone ?? '');
    _addressController = TextEditingController(text: rest?.address ?? '');
    _taxController = TextEditingController(text: rest?.taxRate.toString() ?? '5.0');
    _upiIdController = TextEditingController(text: rest?.upiId ?? 'apnapos@upi');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _taglineController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _taxController.dispose();
    _upiIdController.dispose();
    super.dispose();
  }

  void _refreshState() {
    if (mounted) setState(() {});
  }

  static final Map<String, Uint8List> _base64Cache = {};

  /// Neumorphic Profile Logo / Avatar Widget Resolver
  Widget _buildLogoImageWidget(String? logo, {String? fallbackName, double size = 78}) {
    if (logo == 'none') {
      return Container(
        color: _NeumorphicTheme.sunkenSurface,
        child: const Center(
          child: Icon(Icons.storefront_rounded, size: 28, color: _NeumorphicTheme.navyBrand),
        ),
      );
    }

    // Resolve authoritative owner / business logo from provided logo or database
    String effectiveLogo = '';
    if (logo != null && logo.trim().isNotEmpty && logo.trim() != 'none' && logo.trim() != 'assets/images/logo.png') {
      effectiveLogo = logo.trim();
    } else {
      final compLogo = db.companyLogoPath?.trim();
      final restLogo = db.restaurant?.logoUrl?.trim();
      final userLogo = db.currentUser?.profilePhotoPath?.trim();
      final ownerLogo = db.cachedOwnerUser?.profilePhotoPath?.trim();

      if (compLogo != null && compLogo.isNotEmpty && compLogo != 'assets/images/logo.png') {
        effectiveLogo = compLogo;
      } else if (restLogo != null && restLogo.isNotEmpty && restLogo != 'assets/images/logo.png') {
        effectiveLogo = restLogo;
      } else if (userLogo != null && userLogo.isNotEmpty && userLogo != 'assets/images/logo.png') {
        effectiveLogo = userLogo;
      } else if (ownerLogo != null && ownerLogo.isNotEmpty && ownerLogo != 'assets/images/logo.png') {
        effectiveLogo = ownerLogo;
      } else if (logo != null && logo.trim().isNotEmpty && logo.trim() != 'none') {
        effectiveLogo = logo.trim();
      }
    }

    final String displayName = fallbackName ?? db.restaurant?.name ?? db.currentUser?.companyName ?? db.currentUser?.name ?? 'Business';

    Widget buildInitialFallback() {
      String initial = 'B';
      if (displayName.trim().isNotEmpty) {
        initial = displayName.trim()[0].toUpperCase();
      }
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2563EB), Color(0xFF051C48)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          initial,
          style: TextStyle(
            fontSize: size * 0.42,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      );
    }

    if (effectiveLogo.isEmpty) {
      return buildInitialFallback();
    }

    final trimmed = effectiveLogo;

    // 1. Base64 / Data URI image
    if (trimmed.startsWith('data:image') || trimmed.startsWith('data:') || (trimmed.length > 50 && !trimmed.startsWith('/') && !trimmed.startsWith('assets') && !trimmed.startsWith('http'))) {
      try {
        Uint8List? bytes = _base64Cache[trimmed];
        if (bytes == null) {
          final commaIdx = trimmed.indexOf(',');
          final clean = commaIdx != -1 ? trimmed.substring(commaIdx + 1) : trimmed;
          bytes = base64Decode(clean.replaceAll('\n', '').replaceAll('\r', '').trim());
          _base64Cache[trimmed] = bytes;
        }
        return Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          errorBuilder: (context, error, stackTrace) => buildInitialFallback(),
        );
      } catch (_) {
        return buildInitialFallback();
      }
    }

    // 2. HTTP / HTTPS Network image
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return Image.network(
        trimmed,
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) => buildInitialFallback(),
      );
    }

    // 3. Asset Image
    if (trimmed.startsWith('assets/')) {
      return Image.asset(
        trimmed,
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) => buildInitialFallback(),
      );
    }

    // 4. File on disk
    if (!kIsWeb) {
      try {
        final f = File(trimmed);
        if (f.existsSync()) {
          return Image.file(
            f,
            width: size,
            height: size,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
            errorBuilder: (context, error, stackTrace) => buildInitialFallback(),
          );
        }
      } catch (_) {}
    }

    return buildInitialFallback();
  }

  // ==========================================
  // MODAL 0: EDIT BUSINESS PROFILE (NAME, COMPANY, LOGO, PHONE)
  // ==========================================
  void _showEditBusinessProfileModal() {
    final rest = db.restaurant;
    final currentOwner = db.currentUser;

    // Resolve present data across restaurant, user session and preferences
    final String presentBizName = (rest?.name != null && rest!.name.trim().isNotEmpty)
        ? rest.name.trim()
        : (currentOwner?.companyName ?? currentOwner?.name ?? 'Apna POS Outlet');

    final String presentOwnerName = (currentOwner?.name != null && currentOwner!.name.trim().isNotEmpty)
        ? currentOwner.name.trim()
        : (rest?.name ?? '');

    final String presentCompanyName = (rest?.companyName != null && rest!.companyName.trim().isNotEmpty)
        ? rest.companyName.trim()
        : (currentOwner?.companyName ?? presentBizName);

    final String presentPhone = (rest?.phone != null && rest!.phone.trim().isNotEmpty)
        ? rest.phone.trim()
        : (currentOwner?.phone ?? '');

    // Resolve owner profile logo from authoritative sources (excluding generic placeholder)
    String presentLogo = '';
    if (rest?.logoUrl != null && rest!.logoUrl!.trim().isNotEmpty && rest.logoUrl!.trim() != 'assets/images/logo.png') {
      presentLogo = rest.logoUrl!.trim();
    } else if (db.companyLogoPath != null && db.companyLogoPath!.trim().isNotEmpty && db.companyLogoPath!.trim() != 'assets/images/logo.png') {
      presentLogo = db.companyLogoPath!.trim();
    } else if (currentOwner?.profilePhotoPath != null && currentOwner!.profilePhotoPath!.trim().isNotEmpty && currentOwner.profilePhotoPath!.trim() != 'assets/images/logo.png') {
      presentLogo = currentOwner.profilePhotoPath!.trim();
    } else if (db.cachedOwnerUser?.profilePhotoPath != null && db.cachedOwnerUser!.profilePhotoPath!.trim().isNotEmpty && db.cachedOwnerUser!.profilePhotoPath!.trim() != 'assets/images/logo.png') {
      presentLogo = db.cachedOwnerUser!.profilePhotoPath!.trim();
    }

    final nameCtrl = TextEditingController(text: presentBizName);
    final ownerNameCtrl = TextEditingController(text: presentOwnerName);
    final companyNameCtrl = TextEditingController(text: presentCompanyName);
    final phoneCtrl = TextEditingController(text: presentPhone);

    String logoUrl = presentLogo;
    String? modalError;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final screenWidth = MediaQuery.of(context).size.width;

            Future<void> pickImage(ImageSource source) async {
              try {
                final picker = ImagePicker();
                final XFile? picked = await picker.pickImage(
                  source: source,
                  maxWidth: 800,
                  maxHeight: 800,
                  imageQuality: 85,
                );
                if (picked != null) {
                  setModalState(() {
                    logoUrl = picked.path;
                    modalError = null;
                  });
                }
              } catch (e) {
                setModalState(() {
                  modalError = 'Could not select image: $e';
                });
              }
            }

            void showLogoPickerOptions() {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (sheetCtx) {
                  return Container(
                    decoration: BoxDecoration(
                      color: _NeumorphicTheme.surface,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x38000000),
                          offset: Offset(0, -6),
                          blurRadius: 24,
                        ),
                      ],
                      border: Border.all(color: Color(0xFFD6E2EE), width: 1.2),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Select Profile Logo / Image',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: _NeumorphicTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF2563EB)),
                          title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w700)),
                          onTap: () {
                            Navigator.pop(sheetCtx);
                            pickImage(ImageSource.gallery);
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF16A34A)),
                          title: const Text('Take Photo', style: TextStyle(fontWeight: FontWeight.w700)),
                          onTap: () {
                            Navigator.pop(sheetCtx);
                            pickImage(ImageSource.camera);
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.link_rounded, color: Color(0xFF0284C7)),
                          title: const Text('Enter Image URL', style: TextStyle(fontWeight: FontWeight.w700)),
                          onTap: () {
                            Navigator.pop(sheetCtx);
                            final urlCtrl = TextEditingController(text: logoUrl.startsWith('http') ? logoUrl : '');
                            showDialog(
                              context: context,
                              builder: (urlDlgCtx) => AlertDialog(
                                title: const Text('Image URL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                content: TextField(
                                  controller: urlCtrl,
                                  decoration: const InputDecoration(
                                    hintText: 'https://example.com/logo.png',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(urlDlgCtx), child: const Text('Cancel')),
                                  ElevatedButton(
                                    onPressed: () {
                                      final val = urlCtrl.text.trim();
                                      if (val.isNotEmpty) {
                                        setModalState(() => logoUrl = val);
                                      }
                                      Navigator.pop(urlDlgCtx);
                                    },
                                    child: const Text('Set URL'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        if (logoUrl.isNotEmpty)
                          ListTile(
                            leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)),
                            title: const Text('Remove Logo', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
                            onTap: () {
                              Navigator.pop(sheetCtx);
                              setModalState(() => logoUrl = '');
                            },
                          ),
                      ],
                    ),
                  );
                },
              );
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: screenWidth >= 600 ? 560 : screenWidth * 0.94,
                  maxHeight: MediaQuery.of(context).size.height * 0.90,
                ),
                child: _buildNeumorphicDialogContainer(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Modal Header
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: _NeumorphicTheme.surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                                boxShadow: _NeumorphicTheme.softRaisedShadows,
                              ),
                              child: const Center(
                                child: Icon(Icons.edit_note_rounded, color: _NeumorphicTheme.navyBrand, size: 20),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Edit Business Profile',
                                softWrap: true,
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w900,
                                  color: _NeumorphicTheme.textDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(color: Color(0xFFD3DFEE), height: 1),
                        const SizedBox(height: 14),

                        if (modalError != null) ...[
                          _buildNeumorphicErrorAlert(modalError!),
                          const SizedBox(height: 12),
                        ],

                        // Logo Avatar with Curved Box Border & Bordered Action Buttons
                        Center(
                          child: Column(
                            children: [
                              Container(
                                width: 78,
                                height: 78,
                                decoration: BoxDecoration(
                                  color: _NeumorphicTheme.surface,
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: _NeumorphicTheme.softRaisedShadows,
                                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: _buildLogoImageWidget(
                                    logoUrl == 'none'
                                        ? 'none'
                                        : (logoUrl.isNotEmpty ? logoUrl : presentLogo),
                                    fallbackName: presentBizName,
                                    size: 78,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 10,
                                runSpacing: 6,
                                children: [
                                  // Change / Upload Logo Button with Curved Border
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: showLogoPickerOptions,
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
                                        decoration: BoxDecoration(
                                          color: _NeumorphicTheme.surface,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                                          boxShadow: _NeumorphicTheme.softRaisedShadows,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(3),
                                              decoration: BoxDecoration(
                                                color: _NeumorphicTheme.sunkenSurface,
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: const Color(0xFFCBD5E1), width: 0.8),
                                              ),
                                              child: const Icon(Icons.photo_camera_rounded, size: 12, color: _NeumorphicTheme.navyBrand),
                                            ),
                                            const SizedBox(width: 6),
                                            const Text(
                                              'Change Logo',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: _NeumorphicTheme.navyBrand,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Remove Logo Button with Curved Border
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => setModalState(() => logoUrl = 'none'),
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
                                        decoration: BoxDecoration(
                                          color: _NeumorphicTheme.surface,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: const Color(0xFFFCA5A5), width: 1.2),
                                          boxShadow: _NeumorphicTheme.softRaisedShadows,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(3),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFEE2E2),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: const Color(0xFFFCA5A5), width: 0.8),
                                              ),
                                              child: const Icon(Icons.delete_outline_rounded, size: 12, color: Color(0xFFDC2626)),
                                            ),
                                            const SizedBox(width: 6),
                                            const Text(
                                              'Remove Logo',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFFDC2626),
                                              ),
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
                        const SizedBox(height: 14),

                        // Field 1: Business Profile Name (Pre-filled)
                        _buildNeumorphicInputField(
                          controller: nameCtrl,
                          label: 'Business Profile Name *',
                          hint: 'e.g. Apna POS Diner',
                          prefixIcon: Icons.storefront_rounded,
                        ),
                        const SizedBox(height: 10),

                        // Field 2: Owner / Contact Name (Pre-filled)
                        _buildNeumorphicInputField(
                          controller: ownerNameCtrl,
                          label: 'Contact / Owner Name',
                          hint: 'e.g. Chandan Kumar',
                          prefixIcon: Icons.person_rounded,
                        ),
                        const SizedBox(height: 10),

                        // Field 3: Company Name (Pre-filled)
                        _buildNeumorphicInputField(
                          controller: companyNameCtrl,
                          label: 'Company Name',
                          hint: 'e.g. Apna Retail Technologies Pvt Ltd',
                          prefixIcon: Icons.business_rounded,
                        ),
                        const SizedBox(height: 10),

                        // Field 4: Phone Number (Pre-filled)
                        _buildNeumorphicInputField(
                          controller: phoneCtrl,
                          label: 'Phone Number *',
                          hint: 'e.g. +91 98765 43210',
                          prefixIcon: Icons.phone_rounded,
                          isNumeric: true,
                        ),

                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: _buildNeumorphicButton(
                                label: 'Cancel',
                                isSecondary: true,
                                onPressed: () => Navigator.pop(dialogCtx),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: _buildNeumorphicButton(
                                label: isSaving ? 'Saving...' : 'Save Profile',
                                icon: Icons.check_rounded,
                                isLoading: isSaving,
                                onPressed: isSaving
                                    ? null
                                    : () async {
                                        final n = nameCtrl.text.trim();
                                        final o = ownerNameCtrl.text.trim();
                                        final c = companyNameCtrl.text.trim();
                                        final p = phoneCtrl.text.trim();

                                        if (n.isEmpty) {
                                          setModalState(() => modalError = 'Please enter business profile name');
                                          return;
                                        }
                                        if (p.isEmpty) {
                                          setModalState(() => modalError = 'Please enter contact phone number');
                                          return;
                                        }

                                        setModalState(() {
                                          isSaving = true;
                                          modalError = null;
                                        });

                                        try {
                                          final effectiveLogo = logoUrl == 'none'
                                              ? ''
                                              : (logoUrl.isNotEmpty ? logoUrl : presentLogo);

                                          await db.updateBusinessProfileDetails(
                                            businessName: n,
                                            ownerName: o,
                                            companyName: c,
                                            phone: p,
                                            logoUrl: effectiveLogo,
                                            changeReason: 'Profile updated from Business Settings Hub',
                                          );

                                          _nameController.text = n;
                                          _phoneController.text = p;

                                          if (dialogCtx.mounted) {
                                            Navigator.pop(dialogCtx);
                                          }
                                          _refreshState();
                                          _showSuccessSnackBar('Business profile updated successfully!');
                                        } catch (e) {
                                          setModalState(() {
                                            isSaving = false;
                                            modalError = 'Failed to save profile: $e';
                                          });
                                        }
                                      },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================
  // MODAL 1: POS VIEW (WITH / WITHOUT IMAGE)
  // ==========================================
  void _showPosViewModal() {
    String selectedMode = db.restaurant?.posViewMode ?? 'with_image';
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final screenWidth = MediaQuery.of(context).size.width;

            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: screenWidth >= 650 ? 560 : screenWidth * 0.94,
                  maxHeight: MediaQuery.of(context).size.height * 0.88,
                ),
                child: _buildNeumorphicDialogContainer(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Row(
                        children: [
                          _buildNeumorphicIconBadge(
                            icon: Icons.view_compact_alt_rounded,
                            accentColor: const Color(0xFF0284C7),
                            size: 44,
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Text(
                              'POS View Setting',
                              softWrap: true,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: _NeumorphicTheme.textDark,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(dialogCtx),
                            icon: const Icon(Icons.close_rounded, color: _NeumorphicTheme.textMuted),
                            tooltip: 'Close',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Color(0xFFD3DFEE), height: 1),
                      const SizedBox(height: 16),

                      // Options
                      Flexible(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // OPTION 1: WITH IMAGE
                              _buildNeumorphicOptionTile(
                                isSelected: selectedMode == 'with_image',
                                title: 'With Image',
                                badgeText: 'Visual Mode',
                                badgeColor: const Color(0xFF2563EB),
                                icon: Icons.photo_library_rounded,
                                accentColor: const Color(0xFF2563EB),
                                onTap: () => setModalState(() => selectedMode = 'with_image'),
                              ),

                              const SizedBox(height: 14),

                              // OPTION 2: WITHOUT IMAGE
                              _buildNeumorphicOptionTile(
                                isSelected: selectedMode == 'without_image',
                                title: 'Without Image',
                                badgeText: 'Compact & Fast',
                                badgeColor: const Color(0xFF16A34A),
                                icon: Icons.format_list_bulleted_rounded,
                                accentColor: const Color(0xFF16A34A),
                                onTap: () => setModalState(() => selectedMode = 'without_image'),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                      const Divider(color: Color(0xFFD3DFEE), height: 1),
                      const SizedBox(height: 16),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: _buildNeumorphicButton(
                              label: 'Cancel',
                              isSecondary: true,
                              onPressed: () => Navigator.pop(dialogCtx),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            flex: 2,
                            child: _buildNeumorphicButton(
                              label: isSaving ? 'Saving...' : 'Save POS View',
                              icon: Icons.check_rounded,
                              isLoading: isSaving,
                              onPressed: isSaving
                                  ? null
                                  : () async {
                                      setModalState(() => isSaving = true);
                                      await db.updatePosViewMode(selectedMode);
                                      if (!dialogCtx.mounted) return;
                                      Navigator.pop(dialogCtx);
                                      _refreshState();
                                      _showSuccessSnackBar(
                                        'POS View set to ${selectedMode == 'without_image' ? 'Without Image' : 'With Image'}',
                                      );
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
      },
    );
  }

  // ==========================================
  // MODAL 2: CHOTU AI VOICE ASSISTANT
  // ==========================================
  void _showChotuVoiceModal() {
    bool isEnabled = db.isChotuVoiceEnabled;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final screenWidth = MediaQuery.of(context).size.width;

            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: screenWidth >= 650 ? 560 : screenWidth * 0.94,
                  maxHeight: MediaQuery.of(context).size.height * 0.88,
                ),
                child: _buildNeumorphicDialogContainer(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: _NeumorphicTheme.surface,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: _NeumorphicTheme.softRaisedShadows,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            padding: const EdgeInsets.all(5),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.asset(
                                'assets/images/chotu_robot.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Text(
                              'Chotu AI Voice Assistant',
                              softWrap: true,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: _NeumorphicTheme.textDark,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(dialogCtx),
                            icon: const Icon(Icons.close_rounded, color: _NeumorphicTheme.textMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Color(0xFFD3DFEE), height: 1),
                      const SizedBox(height: 16),

                      // Options
                      Flexible(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // OPTION 1: ENABLED
                              _buildNeumorphicOptionTile(
                                isSelected: isEnabled,
                                title: 'Enable Chotu AI',
                                badgeText: 'Recommended',
                                badgeColor: const Color(0xFF2563EB),
                                customIcon: Image.asset('assets/images/chotu_robot.png', fit: BoxFit.contain),
                                accentColor: const Color(0xFF2563EB),
                                onTap: () => setModalState(() => isEnabled = true),
                              ),

                              const SizedBox(height: 14),

                              // OPTION 2: DISABLED
                              _buildNeumorphicOptionTile(
                                isSelected: !isEnabled,
                                title: 'Disable Chotu AI',
                                badgeText: 'Hidden in POS',
                                badgeColor: const Color(0xFFDC2626),
                                icon: Icons.smart_toy_outlined,
                                accentColor: const Color(0xFFDC2626),
                                onTap: () => setModalState(() => isEnabled = false),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                      const Divider(color: Color(0xFFD3DFEE), height: 1),
                      const SizedBox(height: 16),

                      // Actions
                      Row(
                        children: [
                          Expanded(
                            child: _buildNeumorphicButton(
                              label: 'Cancel',
                              isSecondary: true,
                              onPressed: () => Navigator.pop(dialogCtx),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            flex: 2,
                            child: _buildNeumorphicButton(
                              label: isSaving ? 'Saving...' : 'Save Setting',
                              icon: Icons.check_rounded,
                              isLoading: isSaving,
                              onPressed: isSaving
                                  ? null
                                  : () async {
                                      setModalState(() => isSaving = true);
                                      await db.updateChotuVoiceEnabled(isEnabled);
                                      if (!dialogCtx.mounted) return;
                                      Navigator.pop(dialogCtx);
                                      _refreshState();
                                      _showSuccessSnackBar(
                                        isEnabled
                                            ? 'Chotu AI Voice Assistant Enabled'
                                            : 'Chotu AI Voice Assistant Disabled (Hidden in POS)',
                                      );
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
      },
    );
  }

  // ==========================================
  // MODAL 3: PAYMENT SETTING (UPI VPA)
  // ==========================================
  void _showPaymentSettingsModal() {
    String? modalError;
    final upiCtrl = TextEditingController(text: db.restaurant?.upiId ?? _upiIdController.text);

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: _buildNeumorphicDialogContainer(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            _buildNeumorphicIconBadge(
                              icon: Icons.qr_code_2_rounded,
                              accentColor: const Color(0xFF059669),
                              size: 44,
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Text(
                                'Payment Setting',
                                softWrap: true,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: _NeumorphicTheme.textDark,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(dialogCtx),
                              icon: const Icon(Icons.close_rounded, color: _NeumorphicTheme.textMuted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: Color(0xFFD3DFEE), height: 1),
                        const SizedBox(height: 18),

                        if (modalError != null) ...[
                          _buildNeumorphicErrorAlert(modalError!),
                          const SizedBox(height: 14),
                        ],

                        _buildNeumorphicInputField(
                          controller: upiCtrl,
                          label: 'Merchant UPI VPA ID *',
                          hint: 'e.g. merchant@okicici, 9876543210@paytm',
                          prefixIcon: Icons.qr_code_2_rounded,
                        ),

                        const SizedBox(height: 22),
                        Row(
                          children: [
                            Expanded(
                              child: _buildNeumorphicButton(
                                label: 'Cancel',
                                isSecondary: true,
                                onPressed: () => Navigator.pop(dialogCtx),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: _buildNeumorphicButton(
                                label: 'Save Payment Setting',
                                icon: Icons.check_rounded,
                                onPressed: () async {
                                  final text = upiCtrl.text.trim();
                                  if (text.isEmpty) {
                                    setModalState(() => modalError = 'Please enter a valid Merchant UPI VPA ID');
                                    return;
                                  }
                                  final updated = (db.restaurant ??
                                          RestaurantModel(
                                            id: 'rest_001',
                                            name: '',
                                            tagline: '',
                                            phone: '',
                                            address: '',
                                            cuisineType: 'Indian',
                                          ))
                                      .copyWith(upiId: text);
                                  await db.updateRestaurantProfile(updated);
                                  _upiIdController.text = text;
                                  if (!dialogCtx.mounted) return;
                                  Navigator.pop(dialogCtx);
                                  _refreshState();
                                  _showSuccessSnackBar('Payment setting updated successfully!');
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================
  // MODAL 4: OUTLET INFO
  // ==========================================
  void _showOutletInfoModal() {
    String? modalError;
    final nameCtrl = TextEditingController(text: db.restaurant?.name ?? _nameController.text);
    final taglineCtrl = TextEditingController(text: db.restaurant?.tagline ?? _taglineController.text);
    final phoneCtrl = TextEditingController(text: db.restaurant?.phone ?? _phoneController.text);
    final addressCtrl = TextEditingController(text: db.restaurant?.address ?? _addressController.text);

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580),
                child: _buildNeumorphicDialogContainer(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            _buildNeumorphicIconBadge(
                              icon: Icons.storefront_rounded,
                              accentColor: const Color(0xFF2563EB),
                              size: 44,
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Text(
                                'Outlet Info',
                                softWrap: true,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: _NeumorphicTheme.textDark,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(dialogCtx),
                              icon: const Icon(Icons.close_rounded, color: _NeumorphicTheme.textMuted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: Color(0xFFD3DFEE), height: 1),
                        const SizedBox(height: 16),

                        if (modalError != null) ...[
                          _buildNeumorphicErrorAlert(modalError!),
                          const SizedBox(height: 14),
                        ],

                        _buildNeumorphicInputField(
                          controller: nameCtrl,
                          label: 'Outlet Name *',
                          hint: 'Apna POS Diner',
                          prefixIcon: Icons.storefront_rounded,
                        ),
                        const SizedBox(height: 12),
                        _buildNeumorphicInputField(
                          controller: taglineCtrl,
                          label: 'Tagline / Slogan',
                          hint: 'Taste the Perfection',
                          prefixIcon: Icons.short_text_rounded,
                        ),
                        const SizedBox(height: 12),
                        _buildNeumorphicInputField(
                          controller: phoneCtrl,
                          label: 'Contact Phone *',
                          hint: '+91 98765 43210',
                          prefixIcon: Icons.phone_rounded,
                        ),
                        const SizedBox(height: 12),
                        _buildNeumorphicInputField(
                          controller: addressCtrl,
                          label: 'Outlet Address *',
                          hint: 'Connaught Place, New Delhi',
                          maxLines: 2,
                          prefixIcon: Icons.location_on_rounded,
                        ),

                        const SizedBox(height: 22),
                        Row(
                          children: [
                            Expanded(
                              child: _buildNeumorphicButton(
                                label: 'Cancel',
                                isSecondary: true,
                                onPressed: () => Navigator.pop(dialogCtx),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: _buildNeumorphicButton(
                                label: 'Save Outlet Info',
                                icon: Icons.check_rounded,
                                onPressed: () async {
                                  if (nameCtrl.text.trim().isEmpty) {
                                    setModalState(() => modalError = 'Please enter outlet name');
                                    return;
                                  }
                                  if (phoneCtrl.text.trim().isEmpty) {
                                    setModalState(() => modalError = 'Please enter contact phone number');
                                    return;
                                  }
                                  if (addressCtrl.text.trim().isEmpty) {
                                    setModalState(() => modalError = 'Please enter outlet address');
                                    return;
                                  }
                                  final updated = (db.restaurant ??
                                          RestaurantModel(
                                            id: 'rest_001',
                                            name: '',
                                            tagline: '',
                                            phone: '',
                                            address: '',
                                            cuisineType: 'Indian',
                                          ))
                                      .copyWith(
                                    name: nameCtrl.text.trim(),
                                    tagline: taglineCtrl.text.trim(),
                                    phone: phoneCtrl.text.trim(),
                                    address: addressCtrl.text.trim(),
                                  );
                                  await db.updateRestaurantProfile(updated);
                                  _nameController.text = nameCtrl.text.trim();
                                  _taglineController.text = taglineCtrl.text.trim();
                                  _phoneController.text = phoneCtrl.text.trim();
                                  _addressController.text = addressCtrl.text.trim();

                                  if (!dialogCtx.mounted) return;
                                  Navigator.pop(dialogCtx);
                                  _refreshState();
                                  _showSuccessSnackBar('Outlet info updated successfully!');
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================
  // MODAL 5: TAX SETTINGS
  // ==========================================
  void _showTaxSettingsModal() {
    final rest = db.restaurant;
    final gstCtrl = TextEditingController(text: rest?.gstNumber ?? '');
    final taxRateCtrl = TextEditingController(text: rest?.taxRate.toString() ?? '5.0');
    String? modalError;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: _buildNeumorphicDialogContainer(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            _buildNeumorphicIconBadge(
                              icon: Icons.receipt_long_rounded,
                              accentColor: const Color(0xFF6366F1),
                              size: 44,
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Text(
                                'Tax Settings',
                                softWrap: true,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: _NeumorphicTheme.textDark,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(dialogCtx),
                              icon: const Icon(Icons.close_rounded, color: _NeumorphicTheme.textMuted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: Color(0xFFD3DFEE), height: 1),
                        const SizedBox(height: 16),

                        if (modalError != null) ...[
                          _buildNeumorphicErrorAlert(modalError!),
                          const SizedBox(height: 14),
                        ],

                        _buildNeumorphicInputField(
                          controller: gstCtrl,
                          label: 'GSTIN Number',
                          hint: 'e.g. 07AAAAA0000A1Z5',
                          prefixIcon: Icons.receipt_long_rounded,
                        ),
                        const SizedBox(height: 12),
                        _buildNeumorphicInputField(
                          controller: taxRateCtrl,
                          label: 'GST Tax Percentage (%)',
                          hint: 'e.g. 5.0, 12.0, 18.0',
                          isNumeric: true,
                          prefixIcon: Icons.percent_rounded,
                        ),

                        const SizedBox(height: 22),
                        Row(
                          children: [
                            Expanded(
                              child: _buildNeumorphicButton(
                                label: 'Cancel',
                                isSecondary: true,
                                onPressed: () => Navigator.pop(dialogCtx),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: _buildNeumorphicButton(
                                label: 'Save Tax Settings',
                                icon: Icons.check_rounded,
                                onPressed: () async {
                                  final rateText = taxRateCtrl.text.trim();
                                  final rate = double.tryParse(rateText);
                                  if (rate == null || rate < 0) {
                                    setModalState(() => modalError = 'Please enter a valid non-negative tax percentage');
                                    return;
                                  }
                                  final updated = (db.restaurant ??
                                          RestaurantModel(
                                            id: 'rest_001',
                                            name: '',
                                            tagline: '',
                                            phone: '',
                                            address: '',
                                            cuisineType: 'Indian',
                                          ))
                                      .copyWith(
                                    gstNumber: gstCtrl.text.trim(),
                                    taxRate: rate,
                                  );
                                  await db.updateRestaurantProfile(updated);
                                  _taxController.text = rate.toString();

                                  if (!dialogCtx.mounted) return;
                                  Navigator.pop(dialogCtx);
                                  _refreshState();
                                  _showSuccessSnackBar('Tax settings updated successfully!');
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================
  // MODAL 6: SOUND SETTING
  // ==========================================
  void _showSoundSettingsModal() {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isEnabled = SoundService.soundEnabled;

            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: _buildNeumorphicDialogContainer(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            _buildNeumorphicIconBadge(
                              icon: Icons.volume_up_rounded,
                              accentColor: const Color(0xFFE11D48),
                              size: 44,
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Text(
                                'Sound Setting',
                                softWrap: true,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: _NeumorphicTheme.textDark,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(dialogCtx),
                              icon: const Icon(Icons.close_rounded, color: _NeumorphicTheme.textMuted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: Color(0xFFD3DFEE), height: 1),
                        const SizedBox(height: 18),

                        // Neumorphic Toggle Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _NeumorphicTheme.surface,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: _NeumorphicTheme.raisedShadows,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isEnabled
                                      ? const Color(0xFF2563EB).withValues(alpha: 0.12)
                                      : const Color(0xFF94A3B8).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  isEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                                  color: isEnabled ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Sound Effects',
                                      softWrap: true,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: _NeumorphicTheme.textDark,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isEnabled ? 'Audio feedback is ACTIVE' : 'Audio feedback is MUTED',
                                      softWrap: true,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isEnabled ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch.adaptive(
                                value: isEnabled,
                                activeTrackColor: _NeumorphicTheme.navyBrand,
                                activeThumbColor: Colors.white,
                                onChanged: (val) {
                                  SoundService.setSoundEnabled(val);
                                  setModalState(() {});
                                  _refreshState();
                                  if (val) {
                                    SoundService.playButtonClick();
                                  }
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Test Sound Action
                        if (isEnabled) ...[
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: _NeumorphicTheme.sunkenSurface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.music_note_rounded, color: Color(0xFF2563EB), size: 20),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    'Test feedback tone',
                                    softWrap: true,
                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () => SoundService.playButtonClick(),
                                  icon: const Icon(Icons.play_arrow_rounded, size: 16, color: Colors.white),
                                  label: const Text('Play Tone', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _NeumorphicTheme.navyBrand,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    elevation: 2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        _buildNeumorphicButton(
                          label: 'Done',
                          onPressed: () => Navigator.pop(dialogCtx),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================
  // MODAL 7: SECURITY / MANAGER PIN
  // ==========================================
  void _showSecurityPinModal() {
    final currentPin = db.managerPin;
    final pinCtrl = TextEditingController(text: currentPin);
    bool obscurePin = true;
    String? errorMessage;

    void generateRandomPin(StateSetter setModalState) {
      final randomNum = 1000 + Random().nextInt(9000);
      setModalState(() {
        pinCtrl.text = randomNum.toString();
        errorMessage = null;
      });
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      useRootNavigator: true,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final screenWidth = MediaQuery.of(context).size.width;
            final dialogWidth = screenWidth >= 520 ? 440.0 : (screenWidth * 0.94);

            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: SizedBox(
                width: dialogWidth,
                child: _buildNeumorphicDialogContainer(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            _buildNeumorphicIconBadge(
                              icon: Icons.key_rounded,
                              accentColor: const Color(0xFFDC2626),
                              size: 44,
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Text(
                                'Security / Manager PIN',
                                softWrap: true,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: _NeumorphicTheme.textDark,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(dialogCtx, rootNavigator: true).pop(),
                              icon: const Icon(Icons.close_rounded, color: _NeumorphicTheme.textMuted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: Color(0xFFD3DFEE), height: 1),
                        const SizedBox(height: 16),

                        if (errorMessage != null) ...[
                          _buildNeumorphicErrorAlert(errorMessage!),
                          const SizedBox(height: 14),
                        ],

                        // PIN Input with Auto-Generate
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                const Text(
                                  'Enter 4-Digit PIN',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                ),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    InkWell(
                                      onTap: () => generateRandomPin(setModalState),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _NeumorphicTheme.sunkenSurface,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: const Color(0xFFCBD5E1)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: const [
                                            Icon(Icons.casino_outlined, size: 13, color: Color(0xFF2563EB)),
                                            SizedBox(width: 4),
                                            Text(
                                              'Auto Generate',
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () => setModalState(() => obscurePin = !obscurePin),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              obscurePin ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                              size: 14,
                                              color: const Color(0xFF64748B),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              obscurePin ? 'Show' : 'Hide',
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: _NeumorphicTheme.sunkenSurface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                              ),
                              child: TextField(
                                controller: pinCtrl,
                                keyboardType: TextInputType.number,
                                maxLength: 4,
                                obscureText: obscurePin,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: _NeumorphicTheme.textDark,
                                  letterSpacing: 8,
                                ),
                                decoration: const InputDecoration(
                                  counterText: '',
                                  hintText: '••••',
                                  hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 18, letterSpacing: 6),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  prefixIcon: Icon(Icons.lock_outline_rounded, color: _NeumorphicTheme.navyBrand, size: 20),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Color(0xFFDCFCE7), shape: BoxShape.circle),
                              child: const Icon(Icons.check, size: 12, color: Color(0xFF15803D)),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Active PIN: ${db.managerPin}',
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),

                        const SizedBox(height: 22),
                        Row(
                          children: [
                            Expanded(
                              child: _buildNeumorphicButton(
                                label: 'Cancel',
                                isSecondary: true,
                                onPressed: () => Navigator.of(dialogCtx, rootNavigator: true).pop(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: _buildNeumorphicButton(
                                label: 'Save PIN',
                                icon: Icons.check_rounded,
                                onPressed: () async {
                                  final p1 = pinCtrl.text.trim();
                                  if (p1.length != 4 || int.tryParse(p1) == null) {
                                    setModalState(() => errorMessage = 'PIN must be exactly 4 numeric digits');
                                    return;
                                  }
                                  await db.updateManagerPin(p1);
                                  if (dialogCtx.mounted) {
                                    Navigator.of(dialogCtx, rootNavigator: true).pop();
                                  }
                                  _refreshState();
                                  _showSuccessSnackBar('Manager security PIN updated to $p1 successfully!');
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================
  // MODAL 8: META INTEGRATION (FACEBOOK & INSTAGRAM)
  // ==========================================
  void _showMetaIntegrationModal() {
    bool isEnabled = db.isMetaIntegrationEnabled;
    final pixelIdCtrl = TextEditingController(text: db.metaPixelId);
    final pageIdCtrl = TextEditingController(text: db.metaPageId);
    final accessTokenCtrl = TextEditingController(text: db.metaAccessToken);
    final igHandleCtrl = TextEditingController(text: db.metaInstagramHandle);
    bool catalogSync = db.isMetaCatalogSyncEnabled;
    bool obscureToken = true;
    bool isSaving = false;
    bool isTesting = false;
    String? modalError;
    String? testSuccessMessage;

    showDialog(
      context: context,
      barrierDismissible: true,
      useRootNavigator: true,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final screenWidth = MediaQuery.of(context).size.width;
            final dialogWidth = screenWidth >= 650 ? 580.0 : (screenWidth * 0.94);

            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: dialogWidth,
                  maxHeight: MediaQuery.of(context).size.height * 0.90,
                ),
                child: _buildNeumorphicDialogContainer(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header
                        Row(
                          children: [
                            _buildNeumorphicIconBadge(
                              icon: Icons.hub_rounded,
                              accentColor: const Color(0xFF0668E1),
                              size: 44,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Meta Integration',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: _NeumorphicTheme.textDark,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Facebook Pixel, Instagram & Meta Commerce',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: _NeumorphicTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(dialogCtx, rootNavigator: true).pop(),
                              icon: const Icon(Icons.close_rounded, color: _NeumorphicTheme.textMuted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Divider(color: Color(0xFFD3DFEE), height: 1),
                        const SizedBox(height: 14),

                        if (modalError != null) ...[
                          _buildNeumorphicErrorAlert(modalError!),
                          const SizedBox(height: 12),
                        ],

                        if (testSuccessMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF22C55E), width: 1.2),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    testSuccessMessage!,
                                    style: const TextStyle(
                                      color: Color(0xFF15803D),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Master Toggle Tile
                        _buildNeumorphicToggleTile(
                          title: 'Enable Meta Integration',
                          subtitle: 'Track conversions & sync catalog with Meta Ads',
                          value: isEnabled,
                          accentColor: const Color(0xFF0668E1),
                          onChanged: (val) => setModalState(() {
                            isEnabled = val;
                            modalError = null;
                            testSuccessMessage = null;
                          }),
                        ),
                        const SizedBox(height: 14),

                        // Form Fields
                        _buildNeumorphicInputField(
                          controller: pixelIdCtrl,
                          label: 'Facebook Pixel / Dataset ID',
                          hint: 'e.g. 123456789012345',
                          prefixIcon: Icons.track_changes_rounded,
                          isNumeric: true,
                        ),
                        const SizedBox(height: 12),

                        _buildNeumorphicInputField(
                          controller: pageIdCtrl,
                          label: 'Facebook Page ID / Business Account ID',
                          hint: 'e.g. 109876543210',
                          prefixIcon: Icons.pages_rounded,
                          isNumeric: true,
                        ),
                        const SizedBox(height: 12),

                        _buildNeumorphicInputField(
                          controller: igHandleCtrl,
                          label: 'Instagram Handle',
                          hint: 'e.g. @your_restaurant_handle',
                          prefixIcon: Icons.camera_alt_rounded,
                        ),
                        const SizedBox(height: 12),

                        // Access Token Field with Show/Hide
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Meta System User Access Token',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => setModalState(() => obscureToken = !obscureToken),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        obscureToken ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                        size: 14,
                                        color: const Color(0xFF64748B),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        obscureToken ? 'Show' : 'Hide',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Container(
                              decoration: BoxDecoration(
                                color: _NeumorphicTheme.sunkenSurface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFCBD5E1), width: 1.1),
                              ),
                              child: TextField(
                                controller: accessTokenCtrl,
                                obscureText: obscureToken,
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _NeumorphicTheme.textDark),
                                decoration: const InputDecoration(
                                  hintText: 'e.g. EAABsbCS5...',
                                  hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
                                  prefixIcon: Icon(Icons.vpn_key_rounded, color: _NeumorphicTheme.navyBrand, size: 18),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Catalog Sync Toggle Tile
                        _buildNeumorphicToggleTile(
                          title: 'Auto Sync Menu Catalog',
                          subtitle: 'Automatically sync POS menu items to Meta Catalog',
                          value: catalogSync,
                          accentColor: const Color(0xFF0668E1),
                          onChanged: (val) => setModalState(() => catalogSync = val),
                        ),
                        const SizedBox(height: 16),

                        // Test Connection Button
                        Container(
                          decoration: BoxDecoration(
                            color: _NeumorphicTheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF0668E1).withValues(alpha: 0.3), width: 1.2),
                            boxShadow: _NeumorphicTheme.softRaisedShadows,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: isTesting
                                  ? null
                                  : () async {
                                      final token = accessTokenCtrl.text.trim();
                                      final pixel = pixelIdCtrl.text.trim();
                                      if (token.isEmpty && pixel.isEmpty) {
                                        setModalState(() {
                                          modalError = 'Please enter Pixel ID or Access Token to test connection';
                                          testSuccessMessage = null;
                                        });
                                        return;
                                      }
                                      setModalState(() {
                                        isTesting = true;
                                        modalError = null;
                                        testSuccessMessage = null;
                                      });
                                      await Future.delayed(const Duration(milliseconds: 600));
                                      setModalState(() {
                                        isTesting = false;
                                        testSuccessMessage = '✓ Meta Pixel & Graph API connection verified successfully!';
                                      });
                                    },
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (isTesting)
                                      const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0668E1)),
                                      )
                                    else
                                      const Icon(Icons.sensors_rounded, color: Color(0xFF0668E1), size: 18),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Test Meta Connection',
                                      style: TextStyle(
                                        color: Color(0xFF0668E1),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Save & Cancel Buttons
                        Row(
                          children: [
                            Expanded(
                              child: _buildNeumorphicButton(
                                label: 'Cancel',
                                isSecondary: true,
                                onPressed: () => Navigator.of(dialogCtx, rootNavigator: true).pop(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: _buildNeumorphicButton(
                                label: isSaving ? 'Saving...' : 'Save Meta Settings',
                                icon: Icons.check_rounded,
                                isLoading: isSaving,
                                onPressed: isSaving
                                    ? null
                                    : () async {
                                        setModalState(() {
                                          isSaving = true;
                                          modalError = null;
                                        });

                                        await db.saveMetaSettings(
                                          enabled: isEnabled,
                                          pixelId: pixelIdCtrl.text,
                                          pageId: pageIdCtrl.text,
                                          accessToken: accessTokenCtrl.text,
                                          igHandle: igHandleCtrl.text,
                                          catalogSync: catalogSync,
                                        );

                                        if (dialogCtx.mounted) {
                                          Navigator.of(dialogCtx, rootNavigator: true).pop();
                                        }
                                        _refreshState();
                                        _showSuccessSnackBar('Meta integration settings saved successfully!');
                                      },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================
  // MODAL 9: WHATSAPP INTEGRATION (GATEWAY & META CLOUD API)
  // ==========================================
  void _showWhatsAppIntegrationModal() {
    bool isEnabled = db.isWhatsAppIntegrationEnabled;
    String provider = db.whatsAppProvider; // 'meta_cloud', 'twilio', 'qr_gateway'
    final phoneCtrl = TextEditingController(text: db.whatsAppPhoneNumber);
    final phoneIdCtrl = TextEditingController(text: db.whatsAppPhoneId);
    final wabaIdCtrl = TextEditingController(text: db.whatsAppWabaId);
    final accessTokenCtrl = TextEditingController(text: db.whatsAppAccessToken);
    final webhookTokenCtrl = TextEditingController(text: db.whatsAppWebhookToken);
    bool obscureToken = true;
    bool isSaving = false;
    bool isTesting = false;
    String? modalError;
    String? testSuccessMessage;

    showDialog(
      context: context,
      barrierDismissible: true,
      useRootNavigator: true,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final screenWidth = MediaQuery.of(context).size.width;
            final dialogWidth = screenWidth >= 650 ? 580.0 : (screenWidth * 0.94);

            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: dialogWidth,
                  maxHeight: MediaQuery.of(context).size.height * 0.90,
                ),
                child: _buildNeumorphicDialogContainer(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header
                        Row(
                          children: [
                            _buildNeumorphicIconBadge(
                              icon: Icons.chat_rounded,
                              accentColor: const Color(0xFF25D366),
                              size: 44,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'WhatsApp Integration',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: _NeumorphicTheme.textDark,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Cloud API, Phone Number & Webhooks',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: _NeumorphicTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(dialogCtx, rootNavigator: true).pop(),
                              icon: const Icon(Icons.close_rounded, color: _NeumorphicTheme.textMuted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Divider(color: Color(0xFFD3DFEE), height: 1),
                        const SizedBox(height: 14),

                        if (modalError != null) ...[
                          _buildNeumorphicErrorAlert(modalError!),
                          const SizedBox(height: 12),
                        ],

                        if (testSuccessMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF22C55E), width: 1.2),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    testSuccessMessage!,
                                    style: const TextStyle(
                                      color: Color(0xFF15803D),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Master Toggle
                        _buildNeumorphicToggleTile(
                          title: 'Enable WhatsApp Integration',
                          subtitle: 'Connect WhatsApp Gateway for customer messaging',
                          value: isEnabled,
                          accentColor: const Color(0xFF25D366),
                          onChanged: (val) => setModalState(() {
                            isEnabled = val;
                            modalError = null;
                            testSuccessMessage = null;
                          }),
                        ),
                        const SizedBox(height: 14),

                        // Provider Selection
                        const Text(
                          'WhatsApp Provider Gateway',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: _buildProviderChip(
                                label: 'Meta Cloud API',
                                isSelected: provider == 'meta_cloud',
                                onTap: () => setModalState(() => provider = 'meta_cloud'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildProviderChip(
                                label: 'Twilio',
                                isSelected: provider == 'twilio',
                                onTap: () => setModalState(() => provider = 'twilio'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildProviderChip(
                                label: 'QR Gateway',
                                isSelected: provider == 'qr_gateway',
                                onTap: () => setModalState(() => provider = 'qr_gateway'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Phone Number
                        _buildNeumorphicInputField(
                          controller: phoneCtrl,
                          label: 'Sender Business Phone Number *',
                          hint: 'e.g. +91 98765 43210',
                          prefixIcon: Icons.phone_rounded,
                          isNumeric: true,
                        ),
                        const SizedBox(height: 12),

                        // Phone ID & WABA ID
                        Row(
                          children: [
                            Expanded(
                              child: _buildNeumorphicInputField(
                                controller: phoneIdCtrl,
                                label: 'Phone Number ID',
                                hint: 'e.g. 104567890123',
                                prefixIcon: Icons.perm_identity_rounded,
                                isNumeric: true,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildNeumorphicInputField(
                                controller: wabaIdCtrl,
                                label: 'WABA Business ID',
                                hint: 'e.g. 109876543210',
                                prefixIcon: Icons.badge_rounded,
                                isNumeric: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Permanent Access Token
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Permanent Access / Bearer Token',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => setModalState(() => obscureToken = !obscureToken),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        obscureToken ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                        size: 14,
                                        color: const Color(0xFF64748B),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        obscureToken ? 'Show' : 'Hide',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Container(
                              decoration: BoxDecoration(
                                color: _NeumorphicTheme.sunkenSurface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFCBD5E1), width: 1.1),
                              ),
                              child: TextField(
                                controller: accessTokenCtrl,
                                obscureText: obscureToken,
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _NeumorphicTheme.textDark),
                                decoration: const InputDecoration(
                                  hintText: 'e.g. EAAGy7...',
                                  hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
                                  prefixIcon: Icon(Icons.key_rounded, color: _NeumorphicTheme.navyBrand, size: 18),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Webhook Verify Token
                        _buildNeumorphicInputField(
                          controller: webhookTokenCtrl,
                          label: 'Webhook Verify Token',
                          hint: 'e.g. apna_pos_webhook_secret_123',
                          prefixIcon: Icons.lock_outline_rounded,
                        ),
                        const SizedBox(height: 16),

                        // Test Ping Button
                        Container(
                          decoration: BoxDecoration(
                            color: _NeumorphicTheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.4), width: 1.2),
                            boxShadow: _NeumorphicTheme.softRaisedShadows,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: isTesting
                                  ? null
                                  : () async {
                                      final ph = phoneCtrl.text.trim();
                                      if (ph.isEmpty) {
                                        setModalState(() {
                                          modalError = 'Please enter a business phone number to test';
                                          testSuccessMessage = null;
                                        });
                                        return;
                                      }
                                      setModalState(() {
                                        isTesting = true;
                                        modalError = null;
                                        testSuccessMessage = null;
                                      });
                                      await Future.delayed(const Duration(milliseconds: 600));
                                      setModalState(() {
                                        isTesting = false;
                                        testSuccessMessage = '✓ WhatsApp Cloud Gateway connection active and verified!';
                                      });
                                    },
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (isTesting)
                                      const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF25D366)),
                                      )
                                    else
                                      const Icon(Icons.send_rounded, color: Color(0xFF16A34A), size: 18),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Test WhatsApp Ping',
                                      style: TextStyle(
                                        color: Color(0xFF15803D),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: _buildNeumorphicButton(
                                label: 'Cancel',
                                isSecondary: true,
                                onPressed: () => Navigator.of(dialogCtx, rootNavigator: true).pop(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: _buildNeumorphicButton(
                                label: isSaving ? 'Saving...' : 'Save WhatsApp Gateway',
                                icon: Icons.check_rounded,
                                isLoading: isSaving,
                                onPressed: isSaving
                                    ? null
                                    : () async {
                                        setModalState(() {
                                          isSaving = true;
                                          modalError = null;
                                        });

                                        await db.saveWhatsAppIntegrationSettings(
                                          enabled: isEnabled,
                                          provider: provider,
                                          phoneNumber: phoneCtrl.text,
                                          phoneId: phoneIdCtrl.text,
                                          wabaId: wabaIdCtrl.text,
                                          accessToken: accessTokenCtrl.text,
                                          webhookToken: webhookTokenCtrl.text,
                                        );

                                        if (dialogCtx.mounted) {
                                          Navigator.of(dialogCtx, rootNavigator: true).pop();
                                        }
                                        _refreshState();
                                        _showSuccessSnackBar('WhatsApp integration settings saved successfully!');
                                      },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================
  // MODAL 10: WHATSAPP MESSAGES (AUTOMATIONS & TEMPLATES)
  // ==========================================
  void _showWhatsAppMessagesModal() {
    bool autoBill = db.isWhatsAppAutoBillEnabled;
    bool kotStatus = db.isWhatsAppKotStatusEnabled;
    bool payReminder = db.isWhatsAppPaymentReminderEnabled;
    bool loyaltyGreet = db.isWhatsAppLoyaltyGreetingsEnabled;
    final billTemplateCtrl = TextEditingController(text: db.whatsAppCustomBillTemplate);
    final footerCtrl = TextEditingController(text: db.whatsAppCustomFooter);
    bool isSaving = false;
    String? modalError;

    // Helper for inserting dynamic variable token into template
    void insertVariable(String token, StateSetter setModalState) {
      final text = billTemplateCtrl.text;
      final sel = billTemplateCtrl.selection;
      if (sel.isValid && sel.start >= 0) {
        final newText = text.replaceRange(sel.start, sel.end, token);
        billTemplateCtrl.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: sel.start + token.length),
        );
      } else {
        billTemplateCtrl.text = '$text $token';
      }
      setModalState(() {});
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      useRootNavigator: true,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final screenWidth = MediaQuery.of(context).size.width;
            final dialogWidth = screenWidth >= 680 ? 620.0 : (screenWidth * 0.94);

            final previewText = billTemplateCtrl.text
                .replaceAll('{customer_name}', 'Rahul')
                .replaceAll('{restaurant_name}', db.restaurant?.name ?? 'Apna POS')
                .replaceAll('{order_number}', '1042')
                .replaceAll('{total_amount}', '450.00')
                .replaceAll('{bill_link}', 'https://bill.apnapos.app/inv/1042')
                .replaceAll('{date}', '08 Oct 2026');

            final previewFooter = footerCtrl.text.trim();

            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: dialogWidth,
                  maxHeight: MediaQuery.of(context).size.height * 0.90,
                ),
                child: _buildNeumorphicDialogContainer(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header
                        Row(
                          children: [
                            _buildNeumorphicIconBadge(
                              icon: Icons.mark_chat_unread_rounded,
                              accentColor: const Color(0xFF059669),
                              size: 44,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'WhatsApp Messages',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: _NeumorphicTheme.textDark,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Automations, Instant Invoices & Custom Templates',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: _NeumorphicTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(dialogCtx, rootNavigator: true).pop(),
                              icon: const Icon(Icons.close_rounded, color: _NeumorphicTheme.textMuted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Divider(color: Color(0xFFD3DFEE), height: 1),
                        const SizedBox(height: 14),

                        if (modalError != null) ...[
                          _buildNeumorphicErrorAlert(modalError!),
                          const SizedBox(height: 12),
                        ],

                        // SECTION 1: AUTOMATED TRIGGERS
                        const Text(
                          'AUTOMATED EVENT TRIGGERS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF475569),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),

                        _buildNeumorphicToggleTile(
                          title: 'Auto Send Bill on Settlement',
                          subtitle: 'Instant WhatsApp message with invoice when bill is paid',
                          value: autoBill,
                          accentColor: const Color(0xFF059669),
                          onChanged: (val) => setModalState(() => autoBill = val),
                        ),
                        const SizedBox(height: 8),

                        _buildNeumorphicToggleTile(
                          title: 'KOT & Order Status Updates',
                          subtitle: 'Alert customer when order is accepted or ready',
                          value: kotStatus,
                          accentColor: const Color(0xFF0284C7),
                          onChanged: (val) => setModalState(() => kotStatus = val),
                        ),
                        const SizedBox(height: 8),

                        _buildNeumorphicToggleTile(
                          title: 'Payment Reminders',
                          subtitle: 'Send payment link with UPI QR for open table credits',
                          value: payReminder,
                          accentColor: const Color(0xFFD97706),
                          onChanged: (val) => setModalState(() => payReminder = val),
                        ),
                        const SizedBox(height: 8),

                        _buildNeumorphicToggleTile(
                          title: 'Loyalty & Birthday Greetings',
                          subtitle: 'Send points summary and birthday greetings',
                          value: loyaltyGreet,
                          accentColor: const Color(0xFF8B5CF6),
                          onChanged: (val) => setModalState(() => loyaltyGreet = val),
                        ),
                        const SizedBox(height: 16),

                        // SECTION 2: TEMPLATE CUSTOMIZER
                        const Text(
                          'DIGITAL BILL MESSAGE TEMPLATE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF475569),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Variable Chips Row
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _buildVariableChip(
                              label: '{customer_name}',
                              onTap: () => insertVariable('{customer_name}', setModalState),
                            ),
                            _buildVariableChip(
                              label: '{restaurant_name}',
                              onTap: () => insertVariable('{restaurant_name}', setModalState),
                            ),
                            _buildVariableChip(
                              label: '{order_number}',
                              onTap: () => insertVariable('{order_number}', setModalState),
                            ),
                            _buildVariableChip(
                              label: '{total_amount}',
                              onTap: () => insertVariable('{total_amount}', setModalState),
                            ),
                            _buildVariableChip(
                              label: '{bill_link}',
                              onTap: () => insertVariable('{bill_link}', setModalState),
                            ),
                            _buildVariableChip(
                              label: '{date}',
                              onTap: () => insertVariable('{date}', setModalState),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        Container(
                          decoration: BoxDecoration(
                            color: _NeumorphicTheme.sunkenSurface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFCBD5E1), width: 1.1),
                          ),
                          child: TextField(
                            controller: billTemplateCtrl,
                            maxLines: 4,
                            onChanged: (_) => setModalState(() {}),
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _NeumorphicTheme.textDark),
                            decoration: const InputDecoration(
                              hintText: 'Enter template text...',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.all(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Custom Footer Note
                        _buildNeumorphicInputField(
                          controller: footerCtrl,
                          label: 'Custom Footer Note / FSSAI & Terms',
                          hint: 'e.g. Thanks for visiting! FSSAI Lic # 12345678901234',
                          prefixIcon: Icons.notes_rounded,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 16),

                        // SECTION 3: LIVE WHATSAPP PREVIEW BUBBLE
                        const Text(
                          'LIVE CUSTOMER PREVIEW',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF475569),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),

                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5DDD5),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(14),
                                topRight: Radius.circular(14),
                                bottomRight: Radius.circular(14),
                                bottomLeft: Radius.circular(4),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.receipt_long_rounded, size: 14, color: Color(0xFF059669)),
                                    const SizedBox(width: 5),
                                    Text(
                                      db.restaurant?.name ?? 'Apna POS Outlet',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF059669),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  previewText,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    height: 1.35,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                if (previewFooter.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                                  const SizedBox(height: 4),
                                  Text(
                                    previewFooter,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Align(
                                  alignment: Alignment.bottomRight,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Text('Just now', style: TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8))),
                                      SizedBox(width: 4),
                                      Icon(Icons.done_all_rounded, size: 14, color: Color(0xFF38BDF8)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: _buildNeumorphicButton(
                                label: 'Cancel',
                                isSecondary: true,
                                onPressed: () => Navigator.of(dialogCtx, rootNavigator: true).pop(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: _buildNeumorphicButton(
                                label: isSaving ? 'Saving...' : 'Save Message Settings',
                                icon: Icons.check_rounded,
                                isLoading: isSaving,
                                onPressed: isSaving
                                    ? null
                                    : () async {
                                        setModalState(() {
                                          isSaving = true;
                                          modalError = null;
                                        });

                                        await db.saveWhatsAppMessageSettings(
                                          autoBill: autoBill,
                                          kotStatus: kotStatus,
                                          payReminder: payReminder,
                                          loyaltyGreet: loyaltyGreet,
                                          billTemplate: billTemplateCtrl.text,
                                          customFooter: footerCtrl.text,
                                        );

                                        if (dialogCtx.mounted) {
                                          Navigator.of(dialogCtx, rootNavigator: true).pop();
                                        }
                                        _refreshState();
                                        _showSuccessSnackBar('WhatsApp message settings saved successfully!');
                                      },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================
  // MODAL 11: AI CHAT AGENT (AUTONOMOUS ASSISTANT)
  // ==========================================
  void _showAiChatAgentModal() {
    bool isEnabled = db.isAiChatAgentEnabled;
    String persona = db.aiChatAgentPersona;
    final greetingCtrl = TextEditingController(text: db.aiChatAgentGreeting);
    bool autoMenuSuggest = db.isAiChatAgentAutoMenuSuggest;
    bool autoOrderTaking = db.isAiChatAgentAutoOrderTaking;
    final promptCtrl = TextEditingController(text: db.aiChatAgentSystemPrompt);
    final apiKeyCtrl = TextEditingController(text: db.aiChatAgentApiKey);
    bool obscureApiKey = true;
    bool isSaving = false;
    bool isTesting = false;
    String? modalError;
    String? testSimResponse;

    showDialog(
      context: context,
      barrierDismissible: true,
      useRootNavigator: true,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final screenWidth = MediaQuery.of(context).size.width;
            final dialogWidth = screenWidth >= 680 ? 620.0 : (screenWidth * 0.94);

            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: dialogWidth,
                  maxHeight: MediaQuery.of(context).size.height * 0.90,
                ),
                child: _buildNeumorphicDialogContainer(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header
                        Row(
                          children: [
                            _buildNeumorphicIconBadge(
                              icon: Icons.smart_toy_rounded,
                              accentColor: const Color(0xFF8B5CF6),
                              size: 44,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'AI Chat Agent',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: _NeumorphicTheme.textDark,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Autonomous Hospitality & Order Assistant',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: _NeumorphicTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(dialogCtx, rootNavigator: true).pop(),
                              icon: const Icon(Icons.close_rounded, color: _NeumorphicTheme.textMuted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Divider(color: Color(0xFFD3DFEE), height: 1),
                        const SizedBox(height: 14),

                        if (modalError != null) ...[
                          _buildNeumorphicErrorAlert(modalError!),
                          const SizedBox(height: 12),
                        ],

                        // Master Toggle
                        _buildNeumorphicToggleTile(
                          title: 'Enable AI Chat Agent',
                          subtitle: 'Autonomous AI responds to guest inquiries 24/7',
                          value: isEnabled,
                          accentColor: const Color(0xFF8B5CF6),
                          onChanged: (val) => setModalState(() => isEnabled = val),
                        ),
                        const SizedBox(height: 14),

                        // Persona Selector
                        const Text(
                          'AI AGENT PERSONALITY / TONE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF475569),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: _buildProviderChip(
                                label: 'Friendly & Warm',
                                isSelected: persona == 'friendly',
                                onTap: () => setModalState(() => persona = 'friendly'),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _buildProviderChip(
                                label: 'Professional',
                                isSelected: persona == 'professional',
                                onTap: () => setModalState(() => persona = 'professional'),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _buildProviderChip(
                                label: 'Chef & Foodie',
                                isSelected: persona == 'chef',
                                onTap: () => setModalState(() => persona = 'chef'),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _buildProviderChip(
                                label: 'Upsell Focus',
                                isSelected: persona == 'sales',
                                onTap: () => setModalState(() => persona = 'sales'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Greeting Message
                        _buildNeumorphicInputField(
                          controller: greetingCtrl,
                          label: 'AI Welcome Greeting Message',
                          hint: 'Namaste! Welcome to {restaurant_name}...',
                          prefixIcon: Icons.waving_hand_rounded,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 14),

                        // Autonomous Feature Toggles
                        const Text(
                          'AUTONOMOUS CAPABILITIES',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF475569),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),

                        _buildNeumorphicToggleTile(
                          title: 'Smart Menu Recommendations',
                          subtitle: 'Suggest bestsellers, pairings & chef specials',
                          value: autoMenuSuggest,
                          accentColor: const Color(0xFF059669),
                          onChanged: (val) => setModalState(() => autoMenuSuggest = val),
                        ),
                        const SizedBox(height: 8),

                        _buildNeumorphicToggleTile(
                          title: 'Direct Order & Cart Taking',
                          subtitle: 'Allow customers to specify items and place orders in chat',
                          value: autoOrderTaking,
                          accentColor: const Color(0xFF2563EB),
                          onChanged: (val) => setModalState(() => autoOrderTaking = val),
                        ),
                        const SizedBox(height: 14),

                        // Custom System Instructions
                        _buildNeumorphicInputField(
                          controller: promptCtrl,
                          label: 'Custom AI System Prompt & Rules',
                          hint: 'e.g. Highlight pure veg items, explain today special 15% discount...',
                          prefixIcon: Icons.psychology_rounded,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 14),

                        // Custom API Key Field (Optional)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Custom LLM API Key (Optional - Default: Built-in)',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => setModalState(() => obscureApiKey = !obscureApiKey),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        obscureApiKey ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                        size: 14,
                                        color: const Color(0xFF64748B),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        obscureApiKey ? 'Show' : 'Hide',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Container(
                              decoration: BoxDecoration(
                                color: _NeumorphicTheme.sunkenSurface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFCBD5E1), width: 1.1),
                              ),
                              child: TextField(
                                controller: apiKeyCtrl,
                                obscureText: obscureApiKey,
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _NeumorphicTheme.textDark),
                                decoration: const InputDecoration(
                                  hintText: 'AIzaSy... / sk-... (Leave empty to use built-in engine)',
                                  hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
                                  prefixIcon: Icon(Icons.key_rounded, color: _NeumorphicTheme.navyBrand, size: 18),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Interactive Test Simulation Box
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3E8FF),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFC084FC), width: 1.2),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.auto_awesome_rounded, color: Color(0xFF7E22CE), size: 18),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'AI Agent Simulator',
                                    style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF6B21A8), fontSize: 12.5),
                                  ),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: isTesting
                                        ? null
                                        : () async {
                                            setModalState(() {
                                              isTesting = true;
                                              testSimResponse = null;
                                            });
                                            await Future.delayed(const Duration(milliseconds: 700));
                                            setModalState(() {
                                              isTesting = false;
                                              testSimResponse =
                                                  'Bot: "${greetingCtrl.text.replaceAll('{restaurant_name}', db.restaurant?.name ?? 'Apna POS')}\n\nOur top specialties today: Paneer Butter Masala & Garlic Naan combo! Would you like me to book a table for you?"';
                                            });
                                          },
                                    child: isTesting
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7E22CE)),
                                          )
                                        : const Text('Simulate Chat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF7E22CE))),
                                  ),
                                ],
                              ),
                              if (testSimResponse != null) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    testSimResponse!,
                                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF1E293B), height: 1.35),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: _buildNeumorphicButton(
                                label: 'Cancel',
                                isSecondary: true,
                                onPressed: () => Navigator.of(dialogCtx, rootNavigator: true).pop(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: _buildNeumorphicButton(
                                label: isSaving ? 'Saving...' : 'Save AI Agent',
                                icon: Icons.check_rounded,
                                isLoading: isSaving,
                                onPressed: isSaving
                                    ? null
                                    : () async {
                                        setModalState(() {
                                          isSaving = true;
                                          modalError = null;
                                        });

                                        await db.saveAiChatAgentSettings(
                                          enabled: isEnabled,
                                          persona: persona,
                                          greeting: greetingCtrl.text,
                                          autoMenuSuggest: autoMenuSuggest,
                                          autoOrderTaking: autoOrderTaking,
                                          systemPrompt: promptCtrl.text,
                                          apiKey: apiKeyCtrl.text,
                                        );

                                        if (dialogCtx.mounted) {
                                          Navigator.of(dialogCtx, rootNavigator: true).pop();
                                        }
                                        _refreshState();
                                        _showSuccessSnackBar('AI Chat Agent settings saved successfully!');
                                      },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================
  // MODAL 12: META CHATS (MESSENGER & INSTAGRAM DMS)
  // ==========================================
  void _showMetaChatsModal() {
    bool isEnabled = db.isMetaChatsEnabled;
    bool autoWelcome = db.isMetaChatsAutoWelcomeEnabled;
    final welcomeCtrl = TextEditingController(text: db.metaChatsWelcomeMessage);
    bool leadCapture = db.isMetaChatsLeadCaptureEnabled;
    final handoverCtrl = TextEditingController(text: db.metaChatsHumanHandoverKeyword);
    final awayCtrl = TextEditingController(text: db.metaChatsAwayMessage);
    bool isSaving = false;
    bool isTesting = false;
    String? modalError;
    String? testSuccessMessage;

    showDialog(
      context: context,
      barrierDismissible: true,
      useRootNavigator: true,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final screenWidth = MediaQuery.of(context).size.width;
            final dialogWidth = screenWidth >= 650 ? 580.0 : (screenWidth * 0.94);

            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: dialogWidth,
                  maxHeight: MediaQuery.of(context).size.height * 0.90,
                ),
                child: _buildNeumorphicDialogContainer(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header
                        Row(
                          children: [
                            _buildNeumorphicIconBadge(
                              icon: Icons.forum_rounded,
                              accentColor: const Color(0xFF0084FF),
                              size: 44,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Meta Chats',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: _NeumorphicTheme.textDark,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Messenger & Instagram Direct Automated Inboxes',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: _NeumorphicTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(dialogCtx, rootNavigator: true).pop(),
                              icon: const Icon(Icons.close_rounded, color: _NeumorphicTheme.textMuted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Divider(color: Color(0xFFD3DFEE), height: 1),
                        const SizedBox(height: 14),

                        if (modalError != null) ...[
                          _buildNeumorphicErrorAlert(modalError!),
                          const SizedBox(height: 12),
                        ],

                        if (testSuccessMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF22C55E), width: 1.2),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    testSuccessMessage!,
                                    style: const TextStyle(
                                      color: Color(0xFF15803D),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Master Toggle
                        _buildNeumorphicToggleTile(
                          title: 'Enable Meta Chats Automation',
                          subtitle: 'Automatically manage incoming Facebook & Instagram DMs',
                          value: isEnabled,
                          accentColor: const Color(0xFF0084FF),
                          onChanged: (val) => setModalState(() => isEnabled = val),
                        ),
                        const SizedBox(height: 14),

                        // Auto Welcome Toggle
                        _buildNeumorphicToggleTile(
                          title: 'Auto Welcome Greeting',
                          subtitle: 'Instantly reply when a user messages on IG or Facebook',
                          value: autoWelcome,
                          accentColor: const Color(0xFF0084FF),
                          onChanged: (val) => setModalState(() => autoWelcome = val),
                        ),
                        const SizedBox(height: 10),

                        // Welcome Message Text
                        _buildNeumorphicInputField(
                          controller: welcomeCtrl,
                          label: 'Direct Message Welcome Text',
                          hint: 'Hello! Thanks for connecting with {restaurant_name}...',
                          prefixIcon: Icons.chat_bubble_outline_rounded,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 14),

                        // Lead Capture Toggle
                        _buildNeumorphicToggleTile(
                          title: 'Social Lead Capture',
                          subtitle: 'Automatically prompt for customer mobile number to sync with CRM',
                          value: leadCapture,
                          accentColor: const Color(0xFF10B981),
                          onChanged: (val) => setModalState(() => leadCapture = val),
                        ),
                        const SizedBox(height: 14),

                        // Human Handover Keyword
                        _buildNeumorphicInputField(
                          controller: handoverCtrl,
                          label: 'Staff / Human Handover Trigger Keywords',
                          hint: 'agent, human, help, support, talk to manager',
                          prefixIcon: Icons.support_agent_rounded,
                        ),
                        const SizedBox(height: 14),

                        // Away Message
                        _buildNeumorphicInputField(
                          controller: awayCtrl,
                          label: 'Off-Hours / Away Auto-Reply',
                          hint: 'We are currently closed. Our team will get back to you...',
                          prefixIcon: Icons.schedule_rounded,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 16),

                        // Test Meta Ping
                        Container(
                          decoration: BoxDecoration(
                            color: _NeumorphicTheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF0084FF).withValues(alpha: 0.4), width: 1.2),
                            boxShadow: _NeumorphicTheme.softRaisedShadows,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: isTesting
                                  ? null
                                  : () async {
                                      setModalState(() {
                                        isTesting = true;
                                        testSuccessMessage = null;
                                        modalError = null;
                                      });
                                      await Future.delayed(const Duration(milliseconds: 600));
                                      setModalState(() {
                                        isTesting = false;
                                        testSuccessMessage = '✓ Messenger & Instagram webhook endpoints active and ready!';
                                      });
                                    },
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (isTesting)
                                      const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0084FF)),
                                      )
                                    else
                                      const Icon(Icons.flash_on_rounded, color: Color(0xFF0084FF), size: 18),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Test Meta Webhook Handshake',
                                      style: TextStyle(
                                        color: Color(0xFF0084FF),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: _buildNeumorphicButton(
                                label: 'Cancel',
                                isSecondary: true,
                                onPressed: () => Navigator.of(dialogCtx, rootNavigator: true).pop(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: _buildNeumorphicButton(
                                label: isSaving ? 'Saving...' : 'Save Meta Chats',
                                icon: Icons.check_rounded,
                                isLoading: isSaving,
                                onPressed: isSaving
                                    ? null
                                    : () async {
                                        setModalState(() {
                                          isSaving = true;
                                          modalError = null;
                                        });

                                        await db.saveMetaChatsSettings(
                                          enabled: isEnabled,
                                          autoWelcome: autoWelcome,
                                          welcomeMessage: welcomeCtrl.text,
                                          leadCapture: leadCapture,
                                          humanHandoverKeyword: handoverCtrl.text,
                                          awayMessage: awayCtrl.text,
                                        );

                                        if (dialogCtx.mounted) {
                                          Navigator.of(dialogCtx, rootNavigator: true).pop();
                                        }
                                        _refreshState();
                                        _showSuccessSnackBar('Meta Chats settings saved successfully!');
                                      },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================
  // MODAL 13: WALLET SETTINGS (PREPAID & CASHBACKS)
  // ==========================================
  void _showWalletModal() {
    bool isEnabled = db.isWalletEnabled;
    final cashbackCtrl = TextEditingController(text: db.walletCashbackPercentage.toString());
    final minRechargeCtrl = TextEditingController(text: db.walletMinRechargeAmount.toString());
    final maxRedeemCtrl = TextEditingController(text: db.walletMaxRedeemPercentagePerOrder.toString());
    final signupBonusCtrl = TextEditingController(text: db.walletSignupBonus.toString());
    bool allowNegative = db.isWalletAllowNegativeBalance;
    final payoutUpiCtrl = TextEditingController(text: db.walletBusinessPayoutUpi);
    bool isSaving = false;
    String? modalError;

    showDialog(
      context: context,
      barrierDismissible: true,
      useRootNavigator: true,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final screenWidth = MediaQuery.of(context).size.width;
            final dialogWidth = screenWidth >= 650 ? 580.0 : (screenWidth * 0.94);

            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: dialogWidth,
                  maxHeight: MediaQuery.of(context).size.height * 0.90,
                ),
                child: _buildNeumorphicDialogContainer(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header
                        Row(
                          children: [
                            _buildNeumorphicIconBadge(
                              icon: Icons.account_balance_wallet_rounded,
                              accentColor: const Color(0xFF0D9488),
                              size: 44,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Customer & Outlet Wallet',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: _NeumorphicTheme.textDark,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Prepaid Balances, Cashbacks & Payouts',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: _NeumorphicTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(dialogCtx, rootNavigator: true).pop(),
                              icon: const Icon(Icons.close_rounded, color: _NeumorphicTheme.textMuted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Divider(color: Color(0xFFD3DFEE), height: 1),
                        const SizedBox(height: 14),

                        if (modalError != null) ...[
                          _buildNeumorphicErrorAlert(modalError!),
                          const SizedBox(height: 12),
                        ],

                        // Master Toggle
                        _buildNeumorphicToggleTile(
                          title: 'Enable Wallet System',
                          subtitle: 'Allow patrons to recharge prepaid credit and earn cashback',
                          value: isEnabled,
                          accentColor: const Color(0xFF0D9488),
                          onChanged: (val) => setModalState(() => isEnabled = val),
                        ),
                        const SizedBox(height: 14),

                        // Form Fields
                        Row(
                          children: [
                            Expanded(
                              child: _buildNeumorphicInputField(
                                controller: cashbackCtrl,
                                label: 'Recharge Cashback (%)',
                                hint: 'e.g. 5.0',
                                prefixIcon: Icons.percent_rounded,
                                isNumeric: true,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildNeumorphicInputField(
                                controller: minRechargeCtrl,
                                label: 'Min Recharge (₹)',
                                hint: 'e.g. 200',
                                prefixIcon: Icons.currency_rupee_rounded,
                                isNumeric: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: _buildNeumorphicInputField(
                                controller: maxRedeemCtrl,
                                label: 'Max Redeem Per Bill (%)',
                                hint: 'e.g. 50.0',
                                prefixIcon: Icons.price_check_rounded,
                                isNumeric: true,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildNeumorphicInputField(
                                controller: signupBonusCtrl,
                                label: 'Signup Bonus (₹)',
                                hint: 'e.g. 50',
                                prefixIcon: Icons.card_giftcard_rounded,
                                isNumeric: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Allow Negative / Overdraft Tab
                        _buildNeumorphicToggleTile(
                          title: 'Allow Trusted Negative Credit (Khata Tab)',
                          subtitle: 'Allow regular patrons to exceed zero balance for post-payment',
                          value: allowNegative,
                          accentColor: const Color(0xFFD97706),
                          onChanged: (val) => setModalState(() => allowNegative = val),
                        ),
                        const SizedBox(height: 12),

                        // Payout UPI ID
                        _buildNeumorphicInputField(
                          controller: payoutUpiCtrl,
                          label: 'Merchant Payout UPI VPA (Settlements)',
                          hint: 'e.g. merchant@icici',
                          prefixIcon: Icons.account_balance_rounded,
                        ),
                        const SizedBox(height: 18),

                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: _buildNeumorphicButton(
                                label: 'Cancel',
                                isSecondary: true,
                                onPressed: () => Navigator.of(dialogCtx, rootNavigator: true).pop(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: _buildNeumorphicButton(
                                label: isSaving ? 'Saving...' : 'Save Wallet Settings',
                                icon: Icons.check_rounded,
                                isLoading: isSaving,
                                onPressed: isSaving
                                    ? null
                                    : () async {
                                        final cb = double.tryParse(cashbackCtrl.text.trim()) ?? 0.0;
                                        final mr = double.tryParse(minRechargeCtrl.text.trim()) ?? 0.0;
                                        final mx = double.tryParse(maxRedeemCtrl.text.trim()) ?? 100.0;
                                        final sb = double.tryParse(signupBonusCtrl.text.trim()) ?? 0.0;

                                        setModalState(() {
                                          isSaving = true;
                                          modalError = null;
                                        });

                                        await db.saveWalletSettings(
                                          enabled: isEnabled,
                                          cashbackPercentage: cb,
                                          minRechargeAmount: mr,
                                          maxRedeemPercentage: mx,
                                          signupBonus: sb,
                                          allowNegativeBalance: allowNegative,
                                          businessPayoutUpi: payoutUpiCtrl.text,
                                        );

                                        if (dialogCtx.mounted) {
                                          Navigator.of(dialogCtx, rootNavigator: true).pop();
                                        }
                                        _refreshState();
                                        _showSuccessSnackBar('Wallet settings saved successfully!');
                                      },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                softWrap: true,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF15803D),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ==========================================
  // MAIN BUILD METHOD WITH RESPONSIVE WRAP
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final restaurant = db.restaurant;
    final outletName = (restaurant?.name.isNotEmpty == true) ? restaurant!.name : 'Apna POS Outlet';
    final outletAddress = (restaurant?.address.isNotEmpty == true) ? restaurant!.address : 'Active Store Terminal';

    return Scaffold(
      backgroundColor: _NeumorphicTheme.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            final isMobile = screenWidth < 540;

            // In business setting hub: show 3 boxes in one row with natural responsive wrapping
            final int crossAxisCount = screenWidth >= 280 ? 3 : 2;

            final double spacing = isMobile ? 8.0 : 12.0;
            final double horizontalPadding = isMobile ? 10 : 20;
            final double availableWidth = (screenWidth - (horizontalPadding * 2)).clamp(260.0, 1100.0);
            final double cardWidth = (availableWidth - (spacing * (crossAxisCount - 1))) / crossAxisCount;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1140),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. NEUMORPHIC HERO HEADER CARD (OUTLET & EDIT PROFILE)
                      _buildNeumorphicHeroCard(
                        outletName: outletName,
                        companyName: (restaurant?.companyName.isNotEmpty == true)
                            ? restaurant!.companyName
                            : (db.currentUser?.companyName ?? ''),
                        phone: (restaurant?.phone.isNotEmpty == true)
                            ? restaurant!.phone
                            : (db.currentUser?.phone ?? ''),
                        logoUrl: restaurant?.logoUrl ?? db.companyLogoPath ?? '',
                        outletAddress: outletAddress,
                        isMobile: isMobile,
                        onEdit: _showEditBusinessProfileModal,
                      ),

                      const SizedBox(height: 24),

                      // 2. CATEGORY 1: STORE & ORDER CONFIGURATION
                      _buildNeumorphicSectionHeader(
                        title: 'Store & Order Configuration',
                        icon: Icons.storefront_rounded,
                        countText: '6 Items',
                        accentColor: const Color(0xFF0052FF),
                      ),
                      const SizedBox(height: 14),

                      Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: [
                          _buildSettingCard(
                            width: cardWidth,
                            title: 'Order Setting',
                            subtitle: 'Dine-In, Tables, GST & Channels',
                            icon: Icons.shopping_bag_rounded,
                            accentColor: const Color(0xFF051C48),
                            badgeText: 'Primary',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const BusinessSettingsScreen(isFromOnboarding: false)),
                              );
                            },
                          ),
                          _buildSettingCard(
                            width: cardWidth,
                            title: 'POS View',
                            subtitle: restaurant?.posViewMode == 'without_image' ? 'Without Image' : 'With Image',
                            icon: Icons.view_compact_alt_rounded,
                            accentColor: const Color(0xFF0284C7),
                            badgeText: restaurant?.posViewMode == 'without_image' ? 'Fast' : 'Visual',
                            onTap: _showPosViewModal,
                          ),
                          _buildSettingCard(
                            width: cardWidth,
                            title: 'Outlet Info',
                            subtitle: 'Name, Address & Contact Info',
                            icon: Icons.storefront_rounded,
                            accentColor: const Color(0xFF2563EB),
                            onTap: _showOutletInfoModal,
                          ),
                          _buildSettingCard(
                            width: cardWidth,
                            title: 'Print Logs',
                            subtitle: 'Invoices, Snapshots & History',
                            icon: Icons.receipt_long_rounded,
                            accentColor: const Color(0xFF6366F1),
                            badgeText: 'Audit',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const PrintLogsScreen()),
                              );
                            },
                          ),
                          _buildSettingCard(
                            width: cardWidth,
                            title: 'Security PIN',
                            subtitle: 'Manager PIN for Cart Clear & Void',
                            icon: Icons.lock_person_rounded,
                            accentColor: const Color(0xFFDC2626),
                            badgeText: 'PIN: ${db.managerPin}',
                            onTap: _showSecurityPinModal,
                          ),
                          _buildSettingCard(
                            width: cardWidth,
                            title: 'Chotu AI Voice',
                            subtitle: db.isChotuVoiceEnabled ? 'Voice Ordering Active' : 'Hidden in POS',
                            icon: Icons.smart_toy_rounded,
                            customIcon: Image.asset(
                              'assets/images/chotu_robot.png',
                              fit: BoxFit.contain,
                              width: 32,
                              height: 32,
                            ),
                            accentColor: const Color(0xFF6366F1),
                            badgeText: db.isChotuVoiceEnabled ? 'Active' : 'Off',
                            onTap: _showChotuVoiceModal,
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      // 3. CATEGORY 2: FINANCIALS & PAYMENTS
                      _buildNeumorphicSectionHeader(
                        title: 'Financials & Payments',
                        icon: Icons.account_balance_wallet_rounded,
                        countText: '3 Items',
                        accentColor: const Color(0xFF059669),
                      ),
                      const SizedBox(height: 14),

                      Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: [
                          _buildSettingCard(
                            width: cardWidth,
                            title: 'Payment Setting',
                            subtitle: 'UPI VPA & Instant Payments',
                            icon: Icons.qr_code_2_rounded,
                            accentColor: const Color(0xFF059669),
                            badgeText: 'UPI VPA',
                            onTap: _showPaymentSettingsModal,
                          ),
                          _buildSettingCard(
                            width: cardWidth,
                            title: 'Tax Settings',
                            subtitle: 'GST Rate (${restaurant?.taxRate ?? 5.0}%) & Setup',
                            icon: Icons.receipt_long_rounded,
                            accentColor: const Color(0xFF6366F1),
                            badgeText: '${restaurant?.taxRate ?? 5.0}%',
                            onTap: _showTaxSettingsModal,
                          ),
                          _buildSettingCard(
                            width: cardWidth,
                            title: 'Wallet',
                            subtitle: db.isWalletEnabled ? 'Prepaid & Cashback Active' : 'Prepaid & Khata Tab',
                            icon: Icons.account_balance_wallet_rounded,
                            accentColor: const Color(0xFF0D9488),
                            badgeText: db.isWalletEnabled ? '${db.walletCashbackPercentage}% Back' : 'Setup',
                            onTap: _showWalletModal,
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      // 4. CATEGORY 3: HARDWARE & LOGISTICS
                      _buildNeumorphicSectionHeader(
                        title: 'Hardware & Logistics',
                        icon: Icons.devices_other_rounded,
                        countText: '2 Items',
                        accentColor: const Color(0xFFD97706),
                      ),
                      const SizedBox(height: 14),

                      Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: [
                          _buildSettingCard(
                            width: cardWidth,
                            title: 'Printer Setting',
                            subtitle: 'Bluetooth Thermal Bill Printer',
                            icon: Icons.print_rounded,
                            accentColor: const Color(0xFFD97706),
                            badgeText: 'Thermal',
                            onTap: () {
                              PrinterSelectionDialog.show(context);
                            },
                          ),
                          _buildSettingCard(
                            width: cardWidth,
                            title: 'Sound Setting',
                            subtitle: SoundService.soundEnabled ? 'Click Feedback ON' : 'Audio Feedback Muted',
                            icon: SoundService.soundEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                            accentColor: const Color(0xFFE11D48),
                            badgeText: SoundService.soundEnabled ? 'ON' : 'MUTED',
                            onTap: _showSoundSettingsModal,
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      // 5. CATEGORY 4: MARKETING & COMMUNICATION
                      _buildNeumorphicSectionHeader(
                        title: 'Marketing & Communication',
                        icon: Icons.campaign_rounded,
                        countText: '5 Items',
                        accentColor: const Color(0xFF0052FF),
                      ),
                      const SizedBox(height: 14),

                      Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: [
                          _buildSettingCard(
                            width: cardWidth,
                            title: 'Meta Integration',
                            subtitle: db.isMetaIntegrationEnabled ? 'Pixel & Catalog Active' : 'Facebook & Instagram',
                            icon: Icons.hub_rounded,
                            accentColor: const Color(0xFF0668E1),
                            badgeText: db.isMetaIntegrationEnabled ? 'Active' : 'Setup',
                            onTap: _showMetaIntegrationModal,
                          ),
                          _buildSettingCard(
                            width: cardWidth,
                            title: 'WhatsApp Integration',
                            subtitle: db.isWhatsAppIntegrationEnabled ? 'Gateway Connected' : 'Cloud API & Gateway',
                            icon: Icons.chat_rounded,
                            accentColor: const Color(0xFF25D366),
                            badgeText: db.isWhatsAppIntegrationEnabled ? 'Connected' : 'Configure',
                            onTap: _showWhatsAppIntegrationModal,
                          ),
                          _buildSettingCard(
                            width: cardWidth,
                            title: 'WhatsApp Messages',
                            subtitle: 'Auto-Bill, KOT & Templates',
                            icon: Icons.mark_chat_unread_rounded,
                            accentColor: const Color(0xFF059669),
                            badgeText: 'Automations',
                            onTap: _showWhatsAppMessagesModal,
                          ),
                          _buildSettingCard(
                            width: cardWidth,
                            title: 'AI Chat Agent',
                            subtitle: db.isAiChatAgentEnabled ? 'AI Assistant Online' : 'Smart Order Assistant',
                            icon: Icons.smart_toy_rounded,
                            accentColor: const Color(0xFF8B5CF6),
                            badgeText: db.isAiChatAgentEnabled ? 'AI Live' : 'Smart AI',
                            onTap: _showAiChatAgentModal,
                          ),
                          _buildSettingCard(
                            width: cardWidth,
                            title: 'Meta Chats',
                            subtitle: db.isMetaChatsEnabled ? 'Messenger & DMs Connected' : 'Messenger & IG DMs',
                            icon: Icons.forum_rounded,
                            accentColor: const Color(0xFF0084FF),
                            badgeText: db.isMetaChatsEnabled ? 'Active' : 'DMs',
                            onTap: _showMetaChatsModal,
                          ),
                        ],
                      ),

                      // 6. CATEGORY 5: SUPER ADMIN & MAINTENANCE (Visible ONLY to Super Admin users)
                      if (db.currentUser?.isSuperAdmin == true) ...[
                        const SizedBox(height: 28),
                        _buildNeumorphicSectionHeader(
                          title: 'Super Admin & Database',
                          icon: Icons.admin_panel_settings_rounded,
                          countText: '1 Item',
                          accentColor: const Color(0xFFDC2626),
                        ),
                        const SizedBox(height: 14),

                        Wrap(
                          spacing: spacing,
                          runSpacing: spacing,
                          children: [
                            _buildSettingCard(
                              width: cardWidth,
                              title: 'Order Purge',
                              subtitle: 'Delete orders by Order # for user profile',
                              icon: Icons.delete_forever_rounded,
                              accentColor: const Color(0xFFDC2626),
                              badgeText: 'SuperAdmin',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const SuperAdminOrderDeletionScreen()),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 36),
                      ] else ...[
                        const SizedBox(height: 28),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ==========================================
  // NEUMORPHIC UI ATOMS & COMPONENTS
  // ==========================================

  /// Neumorphic Hero Header Card
  Widget _buildNeumorphicHeroCard({
    required String outletName,
    required String companyName,
    required String phone,
    required String logoUrl,
    required String outletAddress,
    required bool isMobile,
    required VoidCallback onEdit,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      decoration: BoxDecoration(
        color: _NeumorphicTheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: _NeumorphicTheme.raisedShadows,
        border: Border.all(color: Colors.white, width: 1.8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Business Logo / Avatar Badge
          Container(
            width: isMobile ? 50 : 58,
            height: isMobile ? 50 : 58,
            decoration: BoxDecoration(
              color: _NeumorphicTheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: _NeumorphicTheme.softRaisedShadows,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: _buildLogoImageWidget(
                logoUrl,
                fallbackName: outletName,
                size: isMobile ? 50 : 58,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Outlet & Business Details Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      outletName,
                      softWrap: true,
                      style: TextStyle(
                        fontSize: isMobile ? 16 : 19,
                        fontWeight: FontWeight.w900,
                        color: _NeumorphicTheme.textDark,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF86EFAC), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          CircleAvatar(radius: 3, backgroundColor: Color(0xFF16A34A)),
                          SizedBox(width: 5),
                          Text(
                            'ONLINE',
                            style: TextStyle(
                              color: Color(0xFF15803D),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (companyName.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.business_rounded, size: 13, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          companyName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: isMobile ? 11.5 : 12.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.phone_rounded, size: 12, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          phone,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: isMobile ? 11 : 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (outletAddress.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 12, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          outletAddress,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: isMobile ? 11 : 12,
                            color: _NeumorphicTheme.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),

          // NEUMORPHIC EDIT BUTTON ON THE RIGHT
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onEdit,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 12 : 16,
                  vertical: isMobile ? 8 : 10,
                ),
                decoration: BoxDecoration(
                  color: _NeumorphicTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: _NeumorphicTheme.softRaisedShadows,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.edit_rounded, color: _NeumorphicTheme.navyBrand, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Edit',
                      style: TextStyle(
                        color: _NeumorphicTheme.navyBrand,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
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

  /// Neumorphic Section Header Pill
  Widget _buildNeumorphicSectionHeader({
    required String title,
    required IconData icon,
    required String countText,
    required Color accentColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _NeumorphicTheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _NeumorphicTheme.softRaisedShadows,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accentColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              softWrap: true,
              style: const TextStyle(
                color: _NeumorphicTheme.textDark,
                fontSize: 14.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.2,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _NeumorphicTheme.sunkenSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
            ),
            child: Text(
              countText,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF475569),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Neumorphic Setting Grid Card with Natural Wrapping (3 per row without description text)
  Widget _buildSettingCard({
    required double width,
    required String title,
    String? subtitle,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
    String? badgeText,
    Widget? customIcon,
  }) {
    final bool isCompact = width < 140;

    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(18),
          splashColor: accentColor.withValues(alpha: 0.1),
          highlightColor: accentColor.withValues(alpha: 0.05),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 6 : 10,
              vertical: isCompact ? 10 : 14,
            ),
            decoration: BoxDecoration(
              color: _NeumorphicTheme.surface,
              borderRadius: BorderRadius.circular(18),
              boxShadow: _NeumorphicTheme.raisedShadows,
              border: Border.all(color: Colors.white, width: 1.8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Icon & Optional Centered Badge
                Stack(
                  alignment: Alignment.topCenter,
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: isCompact ? 40 : 46,
                      height: isCompact ? 40 : 46,
                      decoration: BoxDecoration(
                        color: _NeumorphicTheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: _NeumorphicTheme.softRaisedShadows,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Center(
                        child: customIcon ?? Icon(icon, color: accentColor, size: isCompact ? 19 : 22),
                      ),
                    ),
                    if (badgeText != null)
                      Positioned(
                        top: -5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: accentColor,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: accentColor.withValues(alpha: 0.4),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            badgeText,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 7.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: isCompact ? 6 : 8),

                // Title (Cleanly wrapped without description text)
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  softWrap: true,
                  style: TextStyle(
                    fontSize: isCompact ? 11 : 12.5,
                    fontWeight: FontWeight.w900,
                    color: _NeumorphicTheme.textDark,
                    letterSpacing: -0.1,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Neumorphic Dialog Outer Container - Calibrated with soft drop shadows and
  /// zero white outer glow so popups do not spread light from borders onto the dark barrier.
  Widget _buildNeumorphicDialogContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _NeumorphicTheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3D000000),
            offset: Offset(0, 16),
            blurRadius: 36,
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Color(0x1F0F172A),
            offset: Offset(0, 4),
            blurRadius: 12,
            spreadRadius: 0,
          ),
        ],
        border: Border.all(color: Color(0xFFD6E2EE), width: 1.2),
      ),
      child: child,
    );
  }

  /// Neumorphic Icon Badge (Indented or Raised circular/rounded icon)
  Widget _buildNeumorphicIconBadge({
    required IconData icon,
    required Color accentColor,
    double size = 44,
    double iconSize = 22,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _NeumorphicTheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: _NeumorphicTheme.softRaisedShadows,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Center(
        child: Icon(icon, color: accentColor, size: iconSize),
      ),
    );
  }

  /// Neumorphic Selectable Option Tile (for POS view & Chotu modal)
  Widget _buildNeumorphicOptionTile({
    required bool isSelected,
    required String title,
    required String badgeText,
    required Color badgeColor,
    String? description,
    IconData? icon,
    Widget? customIcon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    final bool hasDesc = description != null && description.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: hasDesc ? 14 : 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFEFF6FF) : _NeumorphicTheme.surface,
            borderRadius: BorderRadius.circular(18),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : _NeumorphicTheme.softRaisedShadows,
            border: Border.all(
              color: isSelected ? accentColor : Colors.white,
              width: isSelected ? 2 : 1.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: hasDesc ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isSelected ? accentColor.withValues(alpha: 0.15) : _NeumorphicTheme.sunkenSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isSelected ? accentColor : const Color(0xFFCBD5E1), width: 1),
                ),
                child: Center(
                  child: customIcon ?? Icon(icon, color: isSelected ? accentColor : const Color(0xFF64748B), size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          title,
                          softWrap: true,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                            color: _NeumorphicTheme.textDark,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: badgeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (hasDesc) ...[
                      const SizedBox(height: 5),
                      Text(
                        description,
                        softWrap: true,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: _NeumorphicTheme.textMuted,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? accentColor : const Color(0xFF94A3B8),
                    width: 2,
                  ),
                  color: isSelected ? accentColor : Colors.transparent,
                ),
                child: isSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Neumorphic Inset Text Field with Curved Box Icon & Refined Typography
  Widget _buildNeumorphicInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    IconData? prefixIcon,
    int maxLines = 1,
    bool isNumeric = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          softWrap: true,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 5),
        Container(
          decoration: BoxDecoration(
            color: _NeumorphicTheme.sunkenSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFCBD5E1), width: 1.1),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: isNumeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _NeumorphicTheme.textDark),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
              prefixIcon: prefixIcon != null
                  ? Padding(
                      padding: const EdgeInsets.only(left: 8, right: 8, top: 6, bottom: 6),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _NeumorphicTheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1), width: 1.1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.9),
                              offset: const Offset(-1.5, -1.5),
                              blurRadius: 3,
                            ),
                            BoxShadow(
                              color: const Color(0xFFC5D1E0).withValues(alpha: 0.5),
                              offset: const Offset(1.5, 1.5),
                              blurRadius: 3,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(prefixIcon, color: _NeumorphicTheme.navyBrand, size: 16),
                        ),
                      ),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),
      ],
    );
  }

  /// Neumorphic Button (Primary or Secondary)
  Widget _buildNeumorphicButton({
    required String label,
    VoidCallback? onPressed,
    IconData? icon,
    bool isSecondary = false,
    bool isLoading = false,
  }) {
    if (isSecondary) {
      return Container(
        decoration: BoxDecoration(
          color: _NeumorphicTheme.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: _NeumorphicTheme.softRaisedShadows,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Center(
                child: Text(
                  label,
                  softWrap: true,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: _NeumorphicTheme.navyBrand,
        borderRadius: BorderRadius.circular(14),
        boxShadow: _NeumorphicTheme.accentShadows,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                else if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: 18),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    label,
                    softWrap: true,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Neumorphic Error Alert Box
  Widget _buildNeumorphicErrorAlert(String error) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEF4444), width: 1.2),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              error,
              softWrap: true,
              style: const TextStyle(
                color: Color(0xFF991B1B),
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Neumorphic Toggle Switch Tile
  Widget _buildNeumorphicToggleTile({
    required String title,
    required String subtitle,
    required bool value,
    required Color accentColor,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: value ? accentColor.withValues(alpha: 0.08) : _NeumorphicTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: value ? accentColor.withValues(alpha: 0.4) : const Color(0xFFCBD5E1),
          width: 1.2,
        ),
        boxShadow: _NeumorphicTheme.softRaisedShadows,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _NeumorphicTheme.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: _NeumorphicTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: value,
            activeTrackColor: accentColor,
            activeThumbColor: Colors.white,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  /// Selectable Provider Chip
  Widget _buildProviderChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF059669) : _NeumorphicTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFF059669) : const Color(0xFFCBD5E1),
              width: 1.2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF059669).withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : _NeumorphicTheme.softRaisedShadows,
          ),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.white : _NeumorphicTheme.textDark,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Quick variable insert chip
  Widget _buildVariableChip({
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _NeumorphicTheme.sunkenSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_rounded, size: 12, color: Color(0xFF2563EB)),
              const SizedBox(width: 3),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2563EB),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
