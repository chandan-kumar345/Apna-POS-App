import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/database/database_service.dart';
import 'chotu_voice_sheet.dart';

/// Full-screen transparent overlay for the Chotu AI Voice Assistant.
/// Launched when the assistant/power button is pressed, rendering directly
/// on top of the native Android home screen or lock screen without loading
/// the full POS dashboard or tables screen.
class ChotuAssistantOverlayScreen extends StatefulWidget {
  const ChotuAssistantOverlayScreen({super.key});

  @override
  State<ChotuAssistantOverlayScreen> createState() =>
      _ChotuAssistantOverlayScreenState();
}

class _ChotuAssistantOverlayScreenState
    extends State<ChotuAssistantOverlayScreen> {
  static const _overlayChannel =
      MethodChannel('com.apnapos.app/chotu_assist_overlay');
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _ensureServicesReady();
  }

  void _ensureServicesReady() {
    if (!DatabaseService().isInitialized) {
      unawaited(DatabaseService().init().catchError((e) {
        debugPrint('[ChotuAssistantOverlay] Database init fallback error: $e');
      }));
    }
  }

  void _close() {
    if (_closing) return;
    _closing = true;
    _overlayChannel.invokeMethod('closeAssist').catchError((e) {
      debugPrint('[ChotuAssistantOverlay] close error: $e');
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _close();
      },
      child: Material(
        color: Colors.transparent,
        child: ChotuVoiceSheet(
          autoStartListening: true,
          onClose: _close,
        ),
      ),
    );
  }
}
