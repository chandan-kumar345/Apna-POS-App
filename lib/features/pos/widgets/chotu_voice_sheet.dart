import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/services/chotu_service.dart';
import '../../../../core/services/chotu_tts_service.dart';
import '../../../../core/services/speech_recognition_service.dart';

enum ChotuSheetState {
  idle,
  listening,
  processing,
  executed,
  unmatchedItem,
}

class ChotuVoiceSheet extends StatefulWidget {
  final String? tableNumber;
  final VoidCallback? onTranscriptionUpdated;

  const ChotuVoiceSheet({
    super.key,
    this.tableNumber,
    this.onTranscriptionUpdated,
  });

  @override
  State<ChotuVoiceSheet> createState() => _ChotuVoiceSheetState();
}

class _ChotuVoiceSheetState extends State<ChotuVoiceSheet> with TickerProviderStateMixin {
  final ChotuService _chotuService = ChotuService();
  final SpeechRecognitionService _speechService = SpeechRecognitionService();
  final ChotuTtsService _ttsService = ChotuTtsService();

  late AnimationController _growController;
  late Animation<double> _growScale;
  late Animation<double> _growFade;

  late AnimationController _floatController;
  late AnimationController _pulseController;

  ChotuSheetState _sheetState = ChotuSheetState.idle;
  ChotuCommandItem? _unmatchedItem;
  String? _statusFeedback;

  @override
  void initState() {
    super.initState();

    // Growing entrance animation
    _growController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _growScale = Tween<double>(begin: 0.25, end: 1.0).animate(
      CurvedAnimation(parent: _growController, curve: Curves.easeOutBack),
    );
    _growFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _growController, curve: Curves.easeOut),
    );
    _growController.forward();

    // Gentle floating bobbing animation
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    // Audio pulse wave rings
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _speechService.addListener(_onSpeechStateChanged);
    _chotuService.addListener(_onChotuStateChanged);
  }

  @override
  void dispose() {
    _growController.dispose();
    _floatController.dispose();
    _pulseController.dispose();
    _speechService.removeListener(_onSpeechStateChanged);
    _chotuService.removeListener(_onChotuStateChanged);
    _speechService.stopListening();
    _ttsService.stop();
    super.dispose();
  }

  void _onSpeechStateChanged() {
    if (mounted) {
      setState(() {});
      if (_speechService.status == SpeechStatus.done && _speechService.liveTranscription.isNotEmpty) {
        _sendToChotu(_speechService.liveTranscription);
      }
    }
  }

  void _onChotuStateChanged() {
    if (mounted) setState(() {});
  }

  void _startListening() {
    setState(() {
      _sheetState = ChotuSheetState.listening;
      _unmatchedItem = null;
      _statusFeedback = null;
    });
    _speechService.startListening();
  }

  void _stopListening() {
    _speechService.stopListening();
  }

  Future<void> _sendToChotu(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _sheetState = ChotuSheetState.processing;
    });

    await _chotuService.transcribe(
      speechText: text,
      language: 'hinglish',
      tableNumber: widget.tableNumber,
    );

    final parsed = await _chotuService.parseCommand(
      speechText: text,
      tableNumber: widget.tableNumber,
    );

    // Check if any requested item is missing or out of stock
    final missing = _chotuService.checkUnmatchedOrOutOfStockItem(parsed);
    if (missing != null) {
      if (mounted) {
        setState(() {
          _sheetState = ChotuSheetState.unmatchedItem;
          _unmatchedItem = missing;
        });
      }

      final promptSpeech =
          '${missing.productName} POS mein added nahi hai ya out of stock hai. Kya ise POS mein permanently add karna hai ya temporary?';
      await _ttsService.speak(promptSpeech);
      return;
    }

    // If all items are available, execute immediately
    if (parsed.items.isNotEmpty) {
      final result = await _chotuService.executeCommand(parsed);
      final replyMsg = result['chotuMessage']?.toString() ?? parsed.chotuResponse;

      if (mounted) {
        setState(() {
          _sheetState = ChotuSheetState.executed;
          _statusFeedback = replyMsg;
        });
      }

      await _ttsService.speak(replyMsg);
      widget.onTranscriptionUpdated?.call();

      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) _closeOverlay();
      });
    } else {
      if (mounted) {
        setState(() {
          _sheetState = ChotuSheetState.idle;
        });
      }
    }
  }

  Future<void> _resolveMissingItem({required bool permanently}) async {
    final item = _unmatchedItem;
    if (item == null) return;

    setState(() {
      _sheetState = ChotuSheetState.executed;
    });

    if (permanently) {
      await _chotuService.addMissingProductPermanently(
        productName: item.productName,
        quantity: item.quantity,
        tableNumber: widget.tableNumber,
        price: item.price,
      );
      final msg = '${item.productName} permanently POS mein add kar diya gaya hai.';
      setState(() => _statusFeedback = msg);
      await _ttsService.speak(msg);
    } else {
      await _chotuService.addMissingProductTemporarily(
        productName: item.productName,
        quantity: item.quantity,
        tableNumber: widget.tableNumber,
        price: item.price,
      );
      final msg = '${item.productName} temporary is order ke liye add kar diya.';
      setState(() => _statusFeedback = msg);
      await _ttsService.speak(msg);
    }

    widget.onTranscriptionUpdated?.call();

    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) _closeOverlay();
    });
  }

  void _closeOverlay() {
    _stopListening();
    _ttsService.stop();
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isListening = _sheetState == ChotuSheetState.listening;
    final isExecuted = _sheetState == ChotuSheetState.executed;

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Blurred Background Filter + Translucent scrim
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _closeOverlay,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                color: Colors.black.withValues(alpha: 0.55),
              ),
            ),
          ),

          // 2. Chotu Robot in Big Frame + Interactive Section below
          Center(
            child: FadeTransition(
              opacity: _growFade,
              child: ScaleTransition(
                scale: _growScale,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Floating Big Robot Character
                      GestureDetector(
                        onTap: () {
                          if (_sheetState == ChotuSheetState.idle) {
                            _startListening();
                          } else if (isListening) {
                            _stopListening();
                          }
                        },
                        child: AnimatedBuilder(
                          animation: Listenable.merge([_floatController, _pulseController]),
                          builder: (context, child) {
                            final floatY = math.sin(_floatController.value * 2 * math.pi) * 8.0;

                            return Transform.translate(
                              offset: Offset(0, floatY),
                              child: SizedBox(
                                width: 270,
                                height: 300,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Glowing concentric pulse wave rings behind Chotu
                                    CustomPaint(
                                      painter: _ChotuPulseAuraPainter(
                                        pulseValue: _pulseController.value,
                                        isListening: isListening,
                                        isExecuted: isExecuted,
                                      ),
                                      size: const Size(270, 270),
                                    ),

                                    // Ultra-clear HD Big Robot Character with "Chotu" Badge
                                    Hero(
                                      tag: 'chotu_robot_hero',
                                      child: Image.asset(
                                        'assets/images/chotu_robot.png',
                                        width: 220,
                                        height: 280,
                                        fit: BoxFit.contain,
                                        filterQuality: FilterQuality.high,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Selected Section directly below the robot
                      _buildBottomActionSection(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionSection() {
    switch (_sheetState) {
      case ChotuSheetState.idle:
        return _buildStartButton();

      case ChotuSheetState.listening:
        return _buildListeningPill();

      case ChotuSheetState.processing:
        return _buildProcessingPill();

      case ChotuSheetState.unmatchedItem:
        return _buildUnmatchedResolutionCard();

      case ChotuSheetState.executed:
        return _buildSuccessPill();
    }
  }

  /// Start button in the selected section below the robot
  Widget _buildStartButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.55),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: _startListening,
        icon: const Icon(Icons.mic_rounded, color: Colors.white, size: 22),
        label: const Text(
          'Start',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6366F1),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          elevation: 0,
        ),
      ),
    );
  }

  /// Active listening indicator
  Widget _buildListeningPill() {
    return GestureDetector(
      onTap: _stopListening,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.6), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEF4444).withValues(alpha: 0.3),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mic_rounded, color: Color(0xFFFCA5A5), size: 20),
            SizedBox(width: 8),
            Text(
              'Listening... Bolie',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Processing speech
  Widget _buildProcessingPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.5)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFA5B4FC)),
          ),
          SizedBox(width: 10),
          Text(
            'Understanding command...',
            style: TextStyle(color: Color(0xFFA5B4FC), fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  /// Interactive resolution card when product is missing / out of stock
  Widget _buildUnmatchedResolutionCard() {
    final item = _unmatchedItem;
    final itemName = item?.productName ?? 'Item';

    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Warning title
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.info_outline_rounded, color: Colors.orangeAccent, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '$itemName is not added in POS / Out of stock',
                  style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Question
          const Text(
            'Should I add the product in POS permanently or for temporary?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Action Buttons: Permanent vs. Temporary
          Row(
            children: [
              // Permanent Button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _resolveMissingItem(permanently: true),
                  icon: const Icon(Icons.save_rounded, size: 16),
                  label: const Text(
                    'Permanently',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Temporary Button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _resolveMissingItem(permanently: false),
                  icon: const Icon(Icons.timer_outlined, size: 16),
                  label: const Text(
                    'Temporary',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Execution success feedback
  Widget _buildSuccessPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.3),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              _statusFeedback ?? 'Order updated successfully!',
              style: const TextStyle(
                color: Colors.greenAccent,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter to draw glowing concentric sound-wave pulse rings & soft aura behind Chotu
class _ChotuPulseAuraPainter extends CustomPainter {
  final double pulseValue;
  final bool isListening;
  final bool isExecuted;

  _ChotuPulseAuraPainter({
    required this.pulseValue,
    required this.isListening,
    this.isExecuted = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    if (isListening || isExecuted) {
      final ringColor = isExecuted ? Colors.greenAccent : const Color(0xFF6366F1);
      for (int i = 0; i < 2; i++) {
        final ringProgress = (pulseValue + (i * 0.5)) % 1.0;
        final ringRadius = 75.0 + (ringProgress * (maxRadius - 75.0));
        final opacity = (1.0 - ringProgress).clamp(0.0, 1.0) * 0.45;

        final paint = Paint()
          ..color = ringColor.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5;

        canvas.drawCircle(center, ringRadius, paint);
      }
    }

    // Soft ambient radial glow
    final glowColors = isExecuted
        ? [Colors.greenAccent.withValues(alpha: 0.35), Colors.transparent]
        : isListening
            ? [
                const Color(0xFF06B6D4).withValues(alpha: 0.30),
                const Color(0xFF6366F1).withValues(alpha: 0.18),
                Colors.transparent,
              ]
            : [
                const Color(0xFF6366F1).withValues(alpha: 0.22),
                Colors.transparent,
              ];

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: glowColors,
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius));

    canvas.drawCircle(center, maxRadius, glowPaint);
  }

  @override
  bool shouldRepaint(covariant _ChotuPulseAuraPainter oldDelegate) =>
      oldDelegate.pulseValue != pulseValue ||
      oldDelegate.isListening != isListening ||
      oldDelegate.isExecuted != isExecuted;
}
