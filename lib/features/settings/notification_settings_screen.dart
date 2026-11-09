import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/database/database_service.dart';
import '../../core/models/notification_setting_model.dart';
import '../../core/services/sound_service.dart';

/// Clean Neumorphic Theme styling
class _NeumorphicStyle {
  static const Color background = Color(0xFFF1F5F9);
  static const Color surface = Colors.white;
  static const Color sunken = Color(0xFFF8FAFC);
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderActive = Color(0xFF0052FF);

  static const Color textDark = Color(0xFF0F172A);
  static const Color textMedium = Color(0xFF334155);
  static const Color textMuted = Color(0xFF64748B);

  static const Color primaryBlue = Color(0xFF0052FF);
  static const Color indigoAccent = Color(0xFF6366F1);
  static const Color successGreen = Color(0xFF10B981);
  static const Color dangerRed = Color(0xFFEF4444);

  static List<BoxShadow> get cardShadows => [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.04),
          offset: const Offset(0, 2),
          blurRadius: 8,
        ),
      ];

  static List<BoxShadow> get softShadows => [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.03),
          offset: const Offset(0, 1),
          blurRadius: 4,
        ),
      ];
}

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final DatabaseService _db = DatabaseService();
  final ScrollController _scrollController = ScrollController();

  final GlobalKey _orderSectionKey = GlobalKey();
  final GlobalKey _notifSectionKey = GlobalKey();
  final GlobalKey _prefSectionKey = GlobalKey();

  late NotificationSettingModel _currentSetting;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingOrderAudio = false;
  bool _isUploadingNotifAudio = false;
  bool _overlayGranted = false;

  String? _previewingSource;
  bool _isPreviewActive = false;

  // Preset Audio Catalog
  final List<Map<String, String>> _orderPresets = [
    {
      'id': 'default',
      'name': 'Apna POS Urgency (Default)',
      'url': 'sounds/order_recieve_ringtone.mp3',
      'type': 'default',
    },
    {
      'id': 'preset_bell',
      'name': 'Kitchen Alert Chime',
      'url': 'sounds/Notification_sound.mp3',
      'type': 'preset',
    },
    {
      'id': 'preset_click',
      'name': 'Cash Register Ding',
      'url': 'sounds/button_click.mp3',
      'type': 'preset',
    },
  ];

  final List<Map<String, String>> _notifPresets = [
    {
      'id': 'default',
      'name': 'Apna POS Alert (Default)',
      'url': 'sounds/Notification_sound.mp3',
      'type': 'default',
    },
    {
      'id': 'preset_ringtone',
      'name': 'Urgent Alert',
      'url': 'sounds/order_recieve_ringtone.mp3',
      'type': 'preset',
    },
    {
      'id': 'preset_click',
      'name': 'Soft Tick',
      'url': 'sounds/button_click.mp3',
      'type': 'preset',
    },
  ];

  @override
  void initState() {
    super.initState();
    _currentSetting = _db.notificationSetting;
    _loadSettings();
    _checkOverlayPermission();
  }

  @override
  void dispose() {
    SoundService.stopPreview();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkOverlayPermission() async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final status = await Permission.systemAlertWindow.status;
        if (mounted) {
          setState(() {
            _overlayGranted = status.isGranted;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final fetched = await _db.fetchNotificationSettings(forceRefresh: true);
      if (mounted) {
        setState(() {
          _currentSetting = fetched;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentSetting = _db.notificationSetting;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveSettings({bool showToast = true}) async {
    setState(() => _isSaving = true);
    await SoundService.stopPreview();
    _previewingSource = null;
    _isPreviewActive = false;

    final success = await _db.updateNotificationSettings(_currentSetting);

    if (mounted) {
      setState(() => _isSaving = false);
      if (showToast) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: success ? _NeumorphicStyle.textDark : _NeumorphicStyle.dangerRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            content: Row(
              children: [
                Icon(
                  success ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                  color: success ? _NeumorphicStyle.successGreen : Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    success ? 'Notification settings saved and synced!' : 'Saved locally. Sync error.',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _togglePreview({
    required String source,
    required bool isLooping,
    required double volume,
  }) async {
    if (_isPreviewActive && _previewingSource == source) {
      await SoundService.stopPreview();
      if (mounted) {
        setState(() {
          _isPreviewActive = false;
          _previewingSource = null;
        });
      }
    } else {
      await SoundService.stopPreview();
      if (mounted) {
        setState(() {
          _previewingSource = source;
          _isPreviewActive = true;
        });
      }
      await SoundService.startPreview(
        source: source,
        isLooping: isLooping,
        volume: volume,
        onComplete: () {
          if (mounted) {
            setState(() {
              _isPreviewActive = false;
              _previewingSource = null;
            });
          }
        },
      );
    }
  }

  Future<void> _pickAndUploadAudio({required String type}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'opus', 'flac'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final pickedFile = result.files.first;
      final fileName = pickedFile.name;
      final baseName = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');

      final nameController = TextEditingController(text: baseName);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Name Custom Ringtone',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _NeumorphicStyle.textDark),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: _NeumorphicStyle.sunken,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _NeumorphicStyle.border),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  controller: nameController,
                  autofocus: true,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _NeumorphicStyle.textDark),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'e.g. Kitchen Siren',
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'File: $fileName (${(pickedFile.size / 1024).toStringAsFixed(1)} KB)',
                style: const TextStyle(fontSize: 11, color: _NeumorphicStyle.textMuted),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: _NeumorphicStyle.textMuted)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _NeumorphicStyle.primaryBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Save Audio', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      final customName = nameController.text.trim().isNotEmpty ? nameController.text.trim() : baseName;

      if (mounted) {
        setState(() {
          if (type == 'order') {
            _isUploadingOrderAudio = true;
          } else {
            _isUploadingNotifAudio = true;
          }
        });
      }

      dynamic fileOrBytes;
      if (pickedFile.bytes != null) {
        fileOrBytes = pickedFile.bytes;
      } else if (pickedFile.path != null) {
        fileOrBytes = File(pickedFile.path!);
      }

      final uploaded = await _db.uploadCustomRingtone(
        fileOrBytes: fileOrBytes,
        fileName: fileName,
        type: type,
        name: customName,
      );

      if (mounted) {
        setState(() {
          if (type == 'order') {
            _isUploadingOrderAudio = false;
          } else {
            _isUploadingNotifAudio = false;
          }
        });

        if (uploaded != null) {
          setState(() {
            if (type == 'order') {
              _currentSetting = _currentSetting.copyWith(
                orderRingtone: uploaded.url,
                orderRingtoneName: uploaded.name,
                orderRingtoneUrl: uploaded.url,
                orderRingtoneType: 'custom_${uploaded.id}',
              );
            } else {
              _currentSetting = _currentSetting.copyWith(
                notificationSound: uploaded.url,
                notificationSoundName: uploaded.name,
                notificationSoundUrl: uploaded.url,
                notificationSoundType: 'custom_${uploaded.id}',
              );
            }
          });
          await _saveSettings(showToast: false);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: _NeumorphicStyle.textDark,
              behavior: SnackBarBehavior.floating,
              content: Text('Ringtone "$customName" uploaded & selected!'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploadingOrderAudio = false;
          _isUploadingNotifAudio = false;
        });
      }
    }
  }

  Future<void> _deleteRingtone(CustomRingtone ringtone) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Delete Ringtone?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _NeumorphicStyle.textDark),
        ),
        content: Text(
          'Remove "${ringtone.name}"?',
          style: const TextStyle(fontSize: 13, color: _NeumorphicStyle.textMedium),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: _NeumorphicStyle.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _NeumorphicStyle.dangerRed),
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (_previewingSource == ringtone.url) {
      await SoundService.stopPreview();
      _previewingSource = null;
      _isPreviewActive = false;
    }

    final success = await _db.deleteCustomRingtone(ringtone.id);
    if (mounted && success) {
      setState(() {
        _currentSetting = _db.notificationSetting;
      });
    }
  }

  void _scrollTo(GlobalKey key) {
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final business = _db.restaurant;
    final user = _db.currentUser;

    return Scaffold(
      backgroundColor: _NeumorphicStyle.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: false,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _NeumorphicStyle.textDark, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Ringtones & Alerts',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: _NeumorphicStyle.textDark,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _NeumorphicStyle.successGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_done_rounded, color: _NeumorphicStyle.successGreen, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Synced',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _NeumorphicStyle.successGreen),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _NeumorphicStyle.primaryBlue))
          : SafeArea(
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Sleek Profile Chip
                    _buildCompactProfilePill(
                      businessName: business?.name ?? 'Pizza 47',
                      userName: user?.name ?? 'User',
                      role: user?.role?.toUpperCase() ?? 'OWNER',
                    ),

                    const SizedBox(height: 10),

                    // Quick Jump Segmented Chips
                    _buildQuickJumpChips(),

                    const SizedBox(height: 14),

                    // SECTION 1: INCOMING ORDER RINGTONE
                    _buildOrderRingtoneSection(),

                    const SizedBox(height: 16),

                    // SECTION 2: NOTIFICATION SOUND
                    _buildNotificationSoundSection(),

                    const SizedBox(height: 16),

                    // SECTION 3: PREFERENCES & PERMISSIONS
                    _buildPreferencesSection(),

                    const SizedBox(height: 24),

                    // SAVE BUTTON
                    _buildSaveButton(),
                  ],
                ),
              ),
            ),
    );
  }

  // =========================================================================
  // SUB-COMPONENTS
  // =========================================================================

  Widget _buildCompactProfilePill({
    required String businessName,
    required String userName,
    required String role,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _NeumorphicStyle.border),
        boxShadow: _NeumorphicStyle.softShadows,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: _NeumorphicStyle.primaryBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.storefront_rounded, color: _NeumorphicStyle.primaryBlue, size: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$businessName • $userName ($role)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: _NeumorphicStyle.textDark,
              ),
            ),
          ),
          const Icon(Icons.verified_rounded, color: _NeumorphicStyle.primaryBlue, size: 14),
        ],
      ),
    );
  }

  Widget _buildQuickJumpChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildChip('🔔 Order Ringtone', () => _scrollTo(_orderSectionKey)),
          const SizedBox(width: 8),
          _buildChip('💬 Alert Sound', () => _scrollTo(_notifSectionKey)),
          const SizedBox(width: 8),
          _buildChip('⚙️ Preferences', () => _scrollTo(_prefSectionKey)),
        ],
      ),
    );
  }

  Widget _buildChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _NeumorphicStyle.border),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: _NeumorphicStyle.textMedium,
          ),
        ),
      ),
    );
  }

  Widget _buildOrderRingtoneSection() {
    final activeUrl = _currentSetting.orderRingtoneUrl;
    final activeType = _currentSetting.orderRingtoneType;

    return Container(
      key: _orderSectionKey,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _NeumorphicStyle.border),
        boxShadow: _NeumorphicStyle.cardShadows,
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _NeumorphicStyle.dangerRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.notifications_active_rounded, color: _NeumorphicStyle.dangerRed, size: 16),
              ),
              const SizedBox(width: 8),
              const Text(
                'Incoming Order Ringtone',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _NeumorphicStyle.textDark,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Volume Slider
          _buildVolumeSlider(
            value: _currentSetting.orderVolume,
            color: _NeumorphicStyle.dangerRed,
            onChanged: (val) {
              setState(() {
                _currentSetting = _currentSetting.copyWith(orderVolume: val);
              });
            },
          ),

          const SizedBox(height: 10),

          // Built-in presets
          ..._orderPresets.map((preset) {
            final isSelected = (activeType == preset['type'] && activeUrl == preset['url']) ||
                (preset['id'] == 'default' && (activeUrl.isEmpty || activeUrl == 'sounds/order_recieve_ringtone.mp3'));
            return _buildAudioRow(
              name: preset['name']!,
              isSelected: isSelected,
              source: preset['url']!,
              isLooping: true,
              volume: _currentSetting.orderVolume,
              onSelect: () {
                setState(() {
                  _currentSetting = _currentSetting.copyWith(
                    orderRingtone: preset['url']!,
                    orderRingtoneName: preset['name']!,
                    orderRingtoneUrl: preset['url']!,
                    orderRingtoneType: preset['type']!,
                  );
                });
                _saveSettings(showToast: false);
              },
            );
          }),

          // Custom uploaded ringtones
          if (_currentSetting.customRingtones.isNotEmpty) ...[
            const SizedBox(height: 6),
            ..._currentSetting.customRingtones.map((ringtone) {
              final isSelected = activeUrl == ringtone.url;
              return _buildAudioRow(
                name: ringtone.name,
                isCustom: true,
                isSelected: isSelected,
                source: ringtone.url,
                isLooping: true,
                volume: _currentSetting.orderVolume,
                onSelect: () {
                  setState(() {
                    _currentSetting = _currentSetting.copyWith(
                      orderRingtone: ringtone.url,
                      orderRingtoneName: ringtone.name,
                      orderRingtoneUrl: ringtone.url,
                      orderRingtoneType: 'custom_${ringtone.id}',
                    );
                  });
                  _saveSettings(showToast: false);
                },
                onDelete: () => _deleteRingtone(ringtone),
              );
            }),
          ],

          const SizedBox(height: 8),

          // Upload Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isUploadingOrderAudio ? null : () => _pickAndUploadAudio(type: 'order'),
              icon: _isUploadingOrderAudio
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.add_rounded, size: 16),
              label: Text(
                _isUploadingOrderAudio ? 'Uploading...' : 'Add Custom Ringtone',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _NeumorphicStyle.dangerRed,
                side: BorderSide(color: _NeumorphicStyle.dangerRed.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationSoundSection() {
    final activeUrl = _currentSetting.notificationSoundUrl;
    final activeType = _currentSetting.notificationSoundType;

    return Container(
      key: _notifSectionKey,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _NeumorphicStyle.border),
        boxShadow: _NeumorphicStyle.cardShadows,
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _NeumorphicStyle.indigoAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.campaign_rounded, color: _NeumorphicStyle.indigoAccent, size: 16),
              ),
              const SizedBox(width: 8),
              const Text(
                'Notification Alert Sound',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _NeumorphicStyle.textDark,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Volume Slider
          _buildVolumeSlider(
            value: _currentSetting.notificationVolume,
            color: _NeumorphicStyle.indigoAccent,
            onChanged: (val) {
              setState(() {
                _currentSetting = _currentSetting.copyWith(notificationVolume: val);
              });
            },
          ),

          const SizedBox(height: 10),

          // Built-in presets
          ..._notifPresets.map((preset) {
            final isSelected = (activeType == preset['type'] && activeUrl == preset['url']) ||
                (preset['id'] == 'default' && (activeUrl.isEmpty || activeUrl == 'sounds/Notification_sound.mp3'));
            return _buildAudioRow(
              name: preset['name']!,
              isSelected: isSelected,
              source: preset['url']!,
              isLooping: false,
              volume: _currentSetting.notificationVolume,
              onSelect: () {
                setState(() {
                  _currentSetting = _currentSetting.copyWith(
                    notificationSound: preset['url']!,
                    notificationSoundName: preset['name']!,
                    notificationSoundUrl: preset['url']!,
                    notificationSoundType: preset['type']!,
                  );
                });
                _saveSettings(showToast: false);
              },
            );
          }),

          // Custom uploaded sounds
          if (_currentSetting.customRingtones.isNotEmpty) ...[
            const SizedBox(height: 6),
            ..._currentSetting.customRingtones.map((ringtone) {
              final isSelected = activeUrl == ringtone.url;
              return _buildAudioRow(
                name: ringtone.name,
                isCustom: true,
                isSelected: isSelected,
                source: ringtone.url,
                isLooping: false,
                volume: _currentSetting.notificationVolume,
                onSelect: () {
                  setState(() {
                    _currentSetting = _currentSetting.copyWith(
                      notificationSound: ringtone.url,
                      notificationSoundName: ringtone.name,
                      notificationSoundUrl: ringtone.url,
                      notificationSoundType: 'custom_${ringtone.id}',
                    );
                  });
                  _saveSettings(showToast: false);
                },
                onDelete: () => _deleteRingtone(ringtone),
              );
            }),
          ],

          const SizedBox(height: 8),

          // Upload Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isUploadingNotifAudio ? null : () => _pickAndUploadAudio(type: 'notification'),
              icon: _isUploadingNotifAudio
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.add_rounded, size: 16),
              label: Text(
                _isUploadingNotifAudio ? 'Uploading...' : 'Add Custom Sound',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _NeumorphicStyle.indigoAccent,
                side: BorderSide(color: _NeumorphicStyle.indigoAccent.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesSection() {
    return Container(
      key: _prefSectionKey,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _NeumorphicStyle.border),
        boxShadow: _NeumorphicStyle.cardShadows,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _NeumorphicStyle.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.tune_rounded, color: _NeumorphicStyle.primaryBlue, size: 16),
              ),
              const SizedBox(width: 8),
              const Text(
                'Alert Preferences',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _NeumorphicStyle.textDark,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Sound Effects Switch
          _buildCompactSwitch(
            title: 'Sound Effects',
            value: _currentSetting.soundEnabled,
            activeColor: _NeumorphicStyle.primaryBlue,
            onChanged: (val) {
              setState(() {
                _currentSetting = _currentSetting.copyWith(soundEnabled: val);
              });
              SoundService.setSoundEnabled(val);
              _saveSettings(showToast: false);
            },
          ),

          const Divider(height: 16, thickness: 0.7, color: _NeumorphicStyle.border),

          // Vibration Switch
          _buildCompactSwitch(
            title: 'Vibrate on New Orders',
            value: _currentSetting.vibrationEnabled,
            activeColor: _NeumorphicStyle.indigoAccent,
            onChanged: (val) {
              setState(() {
                _currentSetting = _currentSetting.copyWith(vibrationEnabled: val);
              });
              _saveSettings(showToast: false);
            },
          ),

          const Divider(height: 16, thickness: 0.7, color: _NeumorphicStyle.border),

          // Auto-Open Switch
          _buildCompactSwitch(
            title: 'Auto-Open Order Dialog',
            value: _currentSetting.autoOpenOrderScreen,
            activeColor: _NeumorphicStyle.successGreen,
            onChanged: (val) {
              setState(() {
                _currentSetting = _currentSetting.copyWith(autoOpenOrderScreen: val);
              });
              _saveSettings(showToast: false);
            },
          ),

          const Divider(height: 16, thickness: 0.7, color: _NeumorphicStyle.border),

          // Overlay Permission Row
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Display Over Other Apps',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _NeumorphicStyle.textDark),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: (_overlayGranted ? _NeumorphicStyle.successGreen : _NeumorphicStyle.dangerRed).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _overlayGranted ? 'Allowed' : 'Needed',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: _overlayGranted ? _NeumorphicStyle.successGreen : _NeumorphicStyle.dangerRed,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () async {
                    try {
                      await openAppSettings();
                    } catch (_) {}
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Text(
                      'Manage',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _NeumorphicStyle.primaryBlue,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioRow({
    required String name,
    required bool isSelected,
    required String source,
    required bool isLooping,
    required double volume,
    required VoidCallback onSelect,
    bool isCustom = false,
    VoidCallback? onDelete,
  }) {
    final isThisPlaying = _isPreviewActive && _previewingSource == source;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isSelected ? _NeumorphicStyle.primaryBlue.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? _NeumorphicStyle.primaryBlue : _NeumorphicStyle.border,
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: isSelected ? _NeumorphicStyle.primaryBlue : _NeumorphicStyle.textMuted,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? _NeumorphicStyle.textDark : _NeumorphicStyle.textMedium,
                        ),
                      ),
                    ),
                    if (isCustom) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: _NeumorphicStyle.indigoAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Custom',
                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: _NeumorphicStyle.indigoAccent),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              InkWell(
                onTap: () => _togglePreview(source: source, isLooping: isLooping, volume: volume),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: isThisPlaying ? _NeumorphicStyle.dangerRed : _NeumorphicStyle.sunken,
                    shape: BoxShape.circle,
                    border: Border.all(color: _NeumorphicStyle.border),
                  ),
                  child: Icon(
                    isThisPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                    color: isThisPlaying ? Colors.white : _NeumorphicStyle.textDark,
                    size: 16,
                  ),
                ),
              ),
              if (onDelete != null) ...[
                const SizedBox(width: 4),
                InkWell(
                  onTap: onDelete,
                  borderRadius: BorderRadius.circular(16),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close_rounded, color: _NeumorphicStyle.textMuted, size: 16),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVolumeSlider({
    required double value,
    required Color color,
    required ValueChanged<double> onChanged,
  }) {
    final int pct = (value * 100).round();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _NeumorphicStyle.sunken,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _NeumorphicStyle.border),
      ),
      child: Row(
        children: [
          Icon(Icons.volume_down_rounded, color: _NeumorphicStyle.textMuted, size: 16),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                value: value.clamp(0.0, 1.0),
                min: 0.0,
                max: 1.0,
                activeColor: color,
                inactiveColor: _NeumorphicStyle.border,
                onChanged: onChanged,
              ),
            ),
          ),
          Icon(Icons.volume_up_rounded, color: color, size: 16),
          const SizedBox(width: 6),
          SizedBox(
            width: 34,
            child: Text(
              '$pct%',
              textAlign: TextAlign.end,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactSwitch({
    required String title,
    required bool value,
    required Color activeColor,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _NeumorphicStyle.textDark),
        ),
        Transform.scale(
          scale: 0.85,
          child: Switch(
            value: value,
            activeColor: activeColor,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      height: 46,
      child: ElevatedButton(
        onPressed: _isSaving ? null : () => _saveSettings(showToast: true),
        style: ElevatedButton.styleFrom(
          backgroundColor: _NeumorphicStyle.primaryBlue,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 1,
        ),
        child: _isSaving
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                  SizedBox(width: 10),
                  Text('Saving...', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              )
            : const Text(
                'Save Settings',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }
}
