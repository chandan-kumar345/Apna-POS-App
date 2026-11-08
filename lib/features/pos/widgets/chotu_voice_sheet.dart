import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/database/database_service.dart';
import '../../../../core/services/chotu_service.dart';
import '../../../../core/services/chotu_tts_service.dart';
import '../../../../core/services/speech_recognition_service.dart';

enum ChotuSheetState {
  idle,
  greeting,
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
  String _lastUserQuery = '';
  String? _statusFeedback;
  Timer? _autoCloseTimer;

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
    _chotuService.checkBackendHealth();

    // Automatically initiate greeting & start listening
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _startGreetingFlow();
      }
    });
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
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
      if (_sheetState == ChotuSheetState.listening &&
          _speechService.status == SpeechStatus.done &&
          _speechService.liveTranscription.trim().isNotEmpty) {
        final text = _speechService.liveTranscription.trim();
        _sendToChotu(text);
      }
    }
  }

  void _onChotuStateChanged() {
    if (mounted) setState(() {});
  }

  /// Initial Hindi Greeting Flow: Chotu speaks "Kya hua sir?" then starts listening
  Future<void> _startGreetingFlow() async {
    if (!mounted) return;
    setState(() {
      _sheetState = ChotuSheetState.greeting;
      _unmatchedItem = null;
      _statusFeedback = null;
    });

    // Speak Hindi greeting aloud
    await _ttsService.speakGreeting('Kya hua sir?');

    if (mounted && _sheetState == ChotuSheetState.greeting) {
      _startListening();
    }
  }

  void _startListening() {
    if (!mounted) return;
    _autoCloseTimer?.cancel();
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

  void _resetAutoCloseTimer([int seconds = 12]) {
    _autoCloseTimer?.cancel();
    _autoCloseTimer = Timer(Duration(seconds: seconds), () {
      if (mounted && (_sheetState == ChotuSheetState.executed || _sheetState == ChotuSheetState.idle)) {
        _closeOverlay();
      }
    });
  }

  Future<void> _sendToChotu(String text) async {
    // Strip accidental trigger/filler words if present
    final clean = text
        .replaceAll(RegExp(r'\b(understand|understood|samjhe|samajh\s*gaye|samjh\s*gaye|samjha|samjh)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (clean.isEmpty) return;

    setState(() {
      _lastUserQuery = clean;
      _sheetState = ChotuSheetState.processing;
    });

    // Hybrid Edge + Cloud parsing (Gemini AI direct/backend, with instant local fallback)
    final parsed = await _chotuService.parseCommand(
      speechText: clean,
      tableNumber: widget.tableNumber,
    );

    // If item could not be understood at all, prompt user and re-listen
    if (parsed.intent == 'ADD_ITEM' && parsed.items.isEmpty) {
      const prompt = 'Item samajh nahi aaya sir. Kripya dobara boliye.';
      if (mounted) {
        setState(() {
          _sheetState = ChotuSheetState.listening;
          _statusFeedback = prompt;
        });
      }
      _ttsService.speak(prompt).catchError((_) {});
      _speechService.startListening();
      return;
    }

    // Check if any requested item is missing or out of stock (for ADD_ITEM)
    final missing = _chotuService.checkUnmatchedOrOutOfStockItem(parsed);
    if (missing != null) {
      if (mounted) {
        setState(() {
          _sheetState = ChotuSheetState.unmatchedItem;
          _unmatchedItem = missing;
        });
      }

      final promptSpeech =
          '${missing.productName} POS menu mein nahi mila sir. Kya ise permanently add karna hai ya temporary?';
      await _ttsService.speak(promptSpeech);
      return;
    }

    // Execute the command in POS immediately (instant mutation or conversation chat)
    final result = await _chotuService.executeCommand(parsed);
    final replyMsg = result['chotuMessage']?.toString() ??
        (result['message']?.toString()) ??
        parsed.chotuResponse;

    if (mounted) {
      setState(() {
        _sheetState = ChotuSheetState.executed;
        _statusFeedback = replyMsg;
      });
    }

    _ttsService.speak(replyMsg).catchError((_) {});
    widget.onTranscriptionUpdated?.call();

    // Keep Chotu available for conversational follow-ups & next orders!
    _resetAutoCloseTimer(14);
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
      final msg = '${item.productName} permanently POS mein add kar diya gaya hai sir.';
      setState(() {
        _statusFeedback = msg;
      });
      await _ttsService.speak(msg);
    } else {
      await _chotuService.addMissingProductTemporarily(
        productName: item.productName,
        quantity: item.quantity,
        tableNumber: widget.tableNumber,
        price: item.price,
      );
      final msg = '${item.productName} temporary is order ke liye add kar diya sir.';
      setState(() {
        _statusFeedback = msg;
      });
      await _ttsService.speak(msg);
    }

    widget.onTranscriptionUpdated?.call();
    _resetAutoCloseTimer(10);
  }

  void _closeOverlay() {
    _autoCloseTimer?.cancel();
    _stopListening();
    _ttsService.stop();
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  /// Opens dialog to view or update Google Gemini API key directly from Chotu
  void _showGeminiKeyDialog() {
    final db = DatabaseService();
    final ctrl = TextEditingController(text: db.chotuGeminiApiKey);
    bool obscure = true;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            final hasKey = ctrl.text.trim().isNotEmpty;
            return Dialog(
              backgroundColor: const Color(0xFF1E1E2E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                width: 440,
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.auto_awesome, color: Color(0xFFA5B4FC), size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Chotu Gemini AI Setup',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Google AI for smart orders & conversation',
                                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white60, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Enter your Google Gemini API Key. Chotu will use it to understand natural voice orders, answer customer questions, and converse naturally in Hindi/English.',
                      style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12, height: 1.4),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: ctrl,
                      obscureText: obscure,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'AIzaSy...',
                        hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                        filled: true,
                        fillColor: const Color(0xFF11111B),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF334155)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF334155)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                        ),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                size: 18,
                                color: Colors.white54,
                              ),
                              onPressed: () => setDlgState(() => obscure = !obscure),
                            ),
                            IconButton(
                              icon: const Icon(Icons.paste_rounded, size: 18, color: Color(0xFFA5B4FC)),
                              tooltip: 'Paste',
                              onPressed: () async {
                                final data = await Clipboard.getData('text/plain');
                                if (data?.text != null && data!.text!.isNotEmpty) {
                                  ctrl.text = data.text!.trim();
                                  setDlgState(() {});
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Row(
                      children: [
                        Icon(Icons.info_outline, size: 13, color: Color(0xFF94A3B8)),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Free key at aistudio.google.com or in backend/.env',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        if (hasKey)
                          TextButton(
                            onPressed: () async {
                              await db.saveChotuGeminiApiKey('');
                              if (mounted) setState(() {});
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                            child: const Text('Clear Key', style: TextStyle(color: Colors.redAccent, fontSize: 12.5)),
                          ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: () async {
                            final newKey = ctrl.text.trim();
                            await db.saveChotuGeminiApiKey(newKey);
                            if (mounted) setState(() {});
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    newKey.isNotEmpty
                                        ? '✨ Gemini API Key activated for Chotu AI!'
                                        : 'Gemini API Key removed. Using offline fallback.',
                                  ),
                                  backgroundColor: newKey.isNotEmpty ? const Color(0xFF10B981) : const Color(0xFF64748B),
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Save & Activate', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isListening = _sheetState == ChotuSheetState.listening || _sheetState == ChotuSheetState.greeting;
    final isExecuted = _sheetState == ChotuSheetState.executed;
    final hasGeminiKey = DatabaseService().chotuGeminiApiKey.isNotEmpty || _chotuService.isGeminiActive;

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
                color: Colors.black.withValues(alpha: 0.70),
              ),
            ),
          ),

          // 2. Top Bar (Gemini Key Badge on Left, Close on Right)
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: SafeArea(
              child: Row(
                children: [
                  // Gemini Key Status Badge
                  InkWell(
                    onTap: _showGeminiKeyDialog,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: hasGeminiKey
                            ? const Color(0xFF10B981).withValues(alpha: 0.18)
                            : const Color(0xFFF59E0B).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: hasGeminiKey ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            hasGeminiKey ? Icons.auto_awesome : Icons.key_rounded,
                            size: 14,
                            color: hasGeminiKey ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            hasGeminiKey ? 'Gemini AI Active' : 'Set Gemini Key',
                            style: TextStyle(
                              color: hasGeminiKey ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Close Button
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 28),
                    onPressed: _closeOverlay,
                    tooltip: 'Close Chotu',
                  ),
                ],
              ),
            ),
          ),

          // 3. Main Center Content: Robot + Live Speech Display + Controls
          Center(
            child: FadeTransition(
              opacity: _growFade,
              child: ScaleTransition(
                scale: _growScale,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 480),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Floating Robot Avatar
                      GestureDetector(
                        onTap: () {
                          if (_sheetState == ChotuSheetState.idle || _sheetState == ChotuSheetState.executed) {
                            _startListening();
                          } else if (isListening) {
                            _stopListening();
                          }
                        },
                        child: AnimatedBuilder(
                          animation: Listenable.merge([_floatController, _pulseController]),
                          builder: (context, child) {
                            final floatY = math.sin(_floatController.value * 2 * math.pi) * 6.0;

                            return Transform.translate(
                              offset: Offset(0, floatY),
                              child: SizedBox(
                                width: 190,
                                height: 200,
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
                                      size: const Size(190, 190),
                                    ),

                                    // Chotu Robot Character
                                    Hero(
                                      tag: 'chotu_robot_hero',
                                      child: Image.asset(
                                        'assets/images/chotu_robot.png',
                                        width: 150,
                                        height: 170,
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

                      const SizedBox(height: 18),

                      // Live Speech & Response Section (Replaces static chat window)
                      _buildLiveSpeechCard(isListening),

                      const SizedBox(height: 18),

                      // Main Action Status & Controls
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

  /// Live speech display card - shows transcribed words in real-time as user speaks
  Widget _buildLiveSpeechCard(bool isListening) {
    final hasSpokenWords = _speechService.liveTranscription.trim().isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      constraints: const BoxConstraints(minHeight: 100, maxHeight: 160),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF13131F).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isListening
              ? const Color(0xFF6366F1).withValues(alpha: hasSpokenWords ? 0.85 : 0.45)
              : const Color(0xFF2E2E48),
          width: isListening && hasSpokenWords ? 1.5 : 1.0,
        ),
        boxShadow: [
          if (isListening && hasSpokenWords)
            BoxShadow(
              color: const Color(0xFF6366F1).withValues(alpha: 0.22),
              blurRadius: 18,
              spreadRadius: 2,
            ),
        ],
      ),
      child: Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: _buildSpeechDisplayContent(isListening, hasSpokenWords),
        ),
      ),
    );
  }

  /// Content inside the live speech card based on current state
  Widget _buildSpeechDisplayContent(bool isListening, bool hasSpokenWords) {
    switch (_sheetState) {
      case ChotuSheetState.greeting:
        return const Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: TextAlign.center == TextAlign.center ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            Icon(Icons.record_voice_over_rounded, color: Color(0xFF5EEAD4), size: 22),
            SizedBox(width: 10),
            Flexible(
              child: Text(
                'Chotu: "क्या हुआ सर?"',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        );

      case ChotuSheetState.listening:
        if (hasSpokenWords) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Listening...',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _speechService.liveTranscription.trim(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                  height: 1.35,
                ),
              ),
            ],
          );
        } else {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF38BDF8),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Listening...',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Boliye sir, main sun raha hoon...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.70),
                  fontSize: 15.5,
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          );
        }

      case ChotuSheetState.processing:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_lastUserQuery.isNotEmpty) ...[
              Text(
                '"$_lastUserQuery"',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
            ],
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFA5B4FC)),
                ),
                SizedBox(width: 8),
                Text(
                  'Chotu soch raha hai...',
                  style: TextStyle(color: Color(0xFFA5B4FC), fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        );

      case ChotuSheetState.executed:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_lastUserQuery.isNotEmpty) ...[
              Text(
                '"$_lastUserQuery"',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.60),
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
            ],
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF34D399), size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _statusFeedback ?? 'Done!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF34D399),
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold,
                      height: 1.35,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        );

      case ChotuSheetState.unmatchedItem:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_lastUserQuery.isNotEmpty) ...[
              Text(
                '"$_lastUserQuery"',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
            ],
            Text(
              '${_unmatchedItem?.productName ?? "Item"} menu mein nahi mila',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFFBBF24),
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );

      case ChotuSheetState.idle:
        return Text(
          'Chotu ready hai. Boliye ya mic tap kijiye.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.70),
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
          ),
        );
    }
  }

  Widget _buildBottomActionSection() {
    switch (_sheetState) {
      case ChotuSheetState.idle:
        return _buildStartButton();

      case ChotuSheetState.greeting:
        return const SizedBox(height: 48);

      case ChotuSheetState.listening:
        return _buildListeningPill();

      case ChotuSheetState.processing:
        return _buildProcessingPill();

      case ChotuSheetState.unmatchedItem:
        return _buildUnmatchedResolutionCard();

      case ChotuSheetState.executed:
        return _buildExecutedControls();
    }
  }

  /// Prominent Start button
  Widget _buildStartButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.55),
            blurRadius: 22,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: _startListening,
        icon: const Icon(Icons.mic_rounded, color: Colors.white, size: 24),
        label: const Text(
          'Speak to Chotu',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6366F1),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          elevation: 0,
        ),
      ),
    );
  }

  /// Active listening indicator with Google Voice equalizer dots and Done button
  Widget _buildListeningPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFF4285F4).withValues(alpha: 0.8), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4285F4).withValues(alpha: 0.35),
            blurRadius: 18,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildGoogleVoiceWaveDots(),
          const SizedBox(width: 12),
          const Text(
            'Listening...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: () {
              _stopListening();
              if (_speechService.liveTranscription.trim().isNotEmpty) {
                _sendToChotu(_speechService.liveTranscription.trim());
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF334155),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('Done', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  /// Google Voice Search style 4-dot animated voice equalizer
  Widget _buildGoogleVoiceWaveDots() {
    final level = _speechService.audioLevel;
    const colors = [
      Color(0xFF4285F4), // Google Blue
      Color(0xFFEA4335), // Google Red
      Color(0xFFFBBC05), // Google Yellow
      Color(0xFF34A853), // Google Green
    ];

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(4, (i) {
            final wave = (math.sin((_pulseController.value * 2 * math.pi) + (i * 0.9)) + 1.0) / 2.0;
            final dynamicHeight = 7.0 + (level > 0.05 ? (level * 16.0 * (0.5 + wave * 0.5)) : (wave * 6.0));
            return Container(
              width: 5,
              height: dynamicHeight.clamp(5.0, 24.0),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: colors[i],
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        );
      },
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
            'Chotu soch raha hai...',
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
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.help_outline_rounded, color: Color(0xFFF59E0B), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '"$itemName" menu mein nahi hai',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Kaise add karna chahte hain?',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Two Action Buttons: Permanent vs Temporary
          Row(
            children: [
              // Permanent Button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _resolveMissingItem(permanently: true),
                  icon: const Icon(Icons.inventory_2_outlined, size: 16),
                  label: const Text(
                    'Permanent',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A86B),
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

  /// Execution feedback + Interactive Talk/Continue controls
  Widget _buildExecutedControls() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton.icon(
          onPressed: _startListening,
          icon: const Icon(Icons.mic_rounded, color: Colors.white, size: 18),
          label: const Text(
            'Aur Boliye',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            elevation: 4,
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: _closeOverlay,
          icon: const Icon(Icons.check_rounded, color: Colors.white70, size: 18),
          label: const Text(
            'Done',
            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFF475569)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          ),
        ),
      ],
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

    Color auraColor;
    if (isExecuted) {
      auraColor = const Color(0xFF10B981); // Emerald
    } else if (isListening) {
      auraColor = const Color(0xFF4285F4); // Google Blue
    } else {
      auraColor = const Color(0xFF6366F1); // Indigo
    }

    // Outer soft ambient glow
    final auraPaint = Paint()
      ..color = auraColor.withValues(alpha: isListening ? 0.35 : 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);
    canvas.drawCircle(center, maxRadius * 0.65, auraPaint);

    // Dynamic concentric pulse rings when active
    if (isListening) {
      for (int i = 0; i < 3; i++) {
        final ringProgress = (pulseValue + (i * 0.33)) % 1.0;
        final ringRadius = (maxRadius * 0.45) + (maxRadius * 0.55 * ringProgress);
        final ringAlpha = (1.0 - ringProgress).clamp(0.0, 1.0) * 0.45;

        final ringPaint = Paint()
          ..color = auraColor.withValues(alpha: ringAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;

        canvas.drawCircle(center, ringRadius, ringPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ChotuPulseAuraPainter oldDelegate) {
    return oldDelegate.pulseValue != pulseValue ||
        oldDelegate.isListening != isListening ||
        oldDelegate.isExecuted != isExecuted;
  }
}
