import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/services/chotu_service.dart';
import '../../../../core/services/chotu_tts_service.dart';
import '../../../../core/services/speech_recognition_service.dart';
import '../../../../core/services/chotu_activation_service.dart';

class ChotuVoiceSheet extends StatefulWidget {
  final String? tableNumber;
  final VoidCallback? onTranscriptionUpdated;
  final bool autoStartListening;
  final VoidCallback? onClose;
  final Future<void> Function()? prepare;

  const ChotuVoiceSheet({
    super.key,
    this.tableNumber,
    this.onTranscriptionUpdated,
    this.autoStartListening = true,
    this.onClose,
    this.prepare,
  });

  @override
  State<ChotuVoiceSheet> createState() => _ChotuVoiceSheetState();
}

class _ChotuVoiceSheetState extends State<ChotuVoiceSheet>
    with WidgetsBindingObserver {
  static const _ink = Color(0xFF102B48);
  static const _muted = Color(0xFF52687F);
  static const _blue = Color(0xFF225EC6);
  final _chotu = ChotuService();
  final _speech = SpeechRecognitionService();
  final _tts = ChotuTtsService();
  final _input = TextEditingController();
  bool _checking = true;
  bool _sending = false;
  bool _needsAttention = false;
  bool _appActive = true;
  String _query = '';
  String? _reply;
  String? _startupError;

  bool get _ready => _chotu.availability == ChotuAvailability.ready;
  bool get _busy => _sending || _chotu.isProcessing;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ChotuActivationService().suspend(true);
    _chotu.startConversation(tableNumber: widget.tableNumber);
    _speech.reset();
    _chotu.addListener(_onChotuChanged);
    _speech.addListener(_onSpeechChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_connect());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _chotu.removeListener(_onChotuChanged);
    _speech.removeListener(_onSpeechChanged);
    _speech.reset();
    _tts.stop();
    _input.dispose();
    super.dispose();
  }

  void _onChotuChanged() {
    if (mounted) setState(() {});
  }

  void _onSpeechChanged() {
    if (!mounted) return;
    setState(() {});
    if (_appActive &&
        !ChotuActivationService().isScreenLocked &&
        !_busy &&
        _speech.status == SpeechStatus.done &&
        _speech.liveTranscription.trim().isNotEmpty) {
      unawaited(_send(_speech.liveTranscription));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    if (!_appActive) {
      // Do not cancel a first permission grant merely because its system
      // dialog briefly removes focus. A true background transition cancels it.
      if (state != AppLifecycleState.inactive || _speech.isListening) {
        _speech.reset();
      }
      _tts.stop();
    }
  }

  Future<void> _connect() async {
    setState(() {
      _checking = true;
      _reply = null;
      _startupError = null;
    });
    try {
      await widget.prepare?.call();
    } catch (_) {
      if (mounted) {
        setState(() {
          _checking = false;
          _startupError = 'Session could not load. Please retry.';
        });
      }
      return;
    }
    if (!mounted) return;
    await _chotu.checkBackendHealth();
    if (!mounted) return;
    setState(() => _checking = false);
    if (_ready && widget.autoStartListening) await _listen();
  }

  Future<void> _listen() async {
    if (!_ready ||
        _busy ||
        !_appActive ||
        ChotuActivationService().isScreenLocked ||
        _startupError != null) {
      return;
    }
    _tts.stop();
    setState(() {
      _reply = null;
      _query = '';
    });
    await _speech.startListening();
  }

  Future<void> _activationOption(String value) async {
    _speech.reset();
    _tts.stop();
    try {
      final activation = ChotuActivationService();
      if (value == 'assistant') {
        await activation.openAssistantSettings();
      } else if (await activation.arm()) {
        if (mounted) Navigator.of(context).pop();
      } else if (mounted) {
        setState(
          () => _reply =
              'Voice standby needs Chotu access and microphone permission.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _reply = 'Assistant settings are unavailable on this device.',
        );
      }
    }
  }

  Future<void> _send(String text) async {
    final command = text.trim();
    if (command.isEmpty || _busy || _checking || _startupError != null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _tts.stop();
    setState(() {
      _sending = true;
      _query = command;
      _reply = null;
      _needsAttention = false;
    });
    _speech.reset();
    _input.clear();
    try {
      final result = await _chotu.processAutomationTurn(
        speechText: command,
        tableNumber: _chotu.currentTableContext ?? widget.tableNumber,
      );
      if (!mounted) return;
      final message =
          result?['chotuMessage']?.toString() ??
          'Chotu could not complete that instruction. Please retry.';
      final status = result?['status'];
      setState(() {
        _reply = message;
        _needsAttention = status != 'completed' && status != 'answered';
      });
      if (status == 'completed' || status == 'answered') {
        widget.onTranscriptionUpdated?.call();
      }
      if (_ready && _appActive && !ChotuActivationService().isScreenLocked) {
        unawaited(_tts.speak(message).catchError((_) {}));
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _reply = 'Chotu could not finish. Check the order before retrying.';
          _needsAttention = true;
        });
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _close() {
    _speech.reset();
    _tts.stop();
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  String get _message {
    if (_startupError != null) return _startupError!;
    if (_checking) return 'Connecting…';
    if (_reply != null) return _reply!;
    if (!_ready) {
      return _chotu.accessMessage.isNotEmpty
          ? _chotu.accessMessage
          : 'Connection changed. Please retry.';
    }
    if (_busy) return 'Working on it…';
    if (_speech.status == SpeechStatus.error) return _speech.errorMessage;
    if (_speech.isListening) {
      return _speech.liveTranscription.isNotEmpty
          ? _speech.liveTranscription
          : 'Listening…';
    }
    return 'Tap the mic or type an order.';
  }

  @override
  Widget build(BuildContext context) {
    final table = (_chotu.currentTableContext ?? widget.tableNumber ?? '')
        .trim();
    final tableLabel = table.isEmpty
        ? 'No table selected'
        : 'Table ${table.replaceFirst(RegExp(r'^(?:table\s*|t[-\s]*)', caseSensitive: false), '')}';
    return Theme(
      data: ThemeData.light(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _blue,
          brightness: Brightness.light,
        ),
        textTheme: ThemeData.light().textTheme.apply(
          bodyColor: _ink,
          displayColor: _ink,
        ),
      ),
      child: Material(
        key: const ValueKey('chotu-transparent-overlay'),
        color: Colors.transparent,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
              child: const ColoredBox(color: Color(0x33000000)),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: SafeArea(
                  minimum: const EdgeInsets.all(16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 420,
                      maxHeight:
                          (MediaQuery.sizeOf(context).height -
                                  MediaQuery.viewInsetsOf(context).bottom -
                                  48)
                              .clamp(160.0, 520.0),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                    child: RepaintBoundary(
                        child: DecoratedBox(
                          key: const ValueKey('chotu-glass-panel'),
                          decoration: BoxDecoration(
                            color: const Color(0xF5FFFFFF),
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.graphic_eq_rounded,
                                      color: _blue,
                                      size: 26,
                                    ),
                                    const SizedBox(width: 10),
                                    const Expanded(
                                      child: Text(
                                        'Chotu AI',
                                        style: TextStyle(
                                          color: _ink,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Close Chotu',
                                      onPressed: _close,
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        color: _muted,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.table_restaurant_outlined,
                                      size: 15,
                                      color: _muted,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        tableLabel,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelMedium
                                            ?.copyWith(
                                              color: _muted,
                                              fontSize: 12,
                                            ),
                                      ),
                                    ),
                                    PopupMenuButton<String>(
                                      enabled: _ready && !_busy,
                                      tooltip: 'Voice activation',
                                      icon: const Icon(
                                        Icons.tune_rounded,
                                        size: 18,
                                        color: _muted,
                                      ),
                                      onSelected: (value) =>
                                          unawaited(_activationOption(value)),
                                      itemBuilder: (_) => const [
                                        PopupMenuItem(
                                          value: 'standby',
                                          child: Text(
                                            'Hello Chotu · 2 min in app',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'assistant',
                                          child: Text(
                                            'Android assistant settings',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                    DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _speech.currentLocale,
                                        isDense: true,
                                        dropdownColor: const Color(0xFFF6F9FE),
                                        icon: const Icon(
                                          Icons.expand_more_rounded,
                                          size: 18,
                                          color: _muted,
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelMedium
                                            ?.copyWith(
                                              color: _muted,
                                              fontSize: 12,
                                            ),
                                        items: const [
                                          DropdownMenuItem(
                                            value: 'hinglish',
                                            child: Text('Hinglish'),
                                          ),
                                          DropdownMenuItem(
                                            value: 'hi_IN',
                                            child: Text('हिन्दी'),
                                          ),
                                          DropdownMenuItem(
                                            value: 'en_IN',
                                            child: Text('English'),
                                          ),
                                        ],
                                        onChanged: _busy
                                            ? null
                                            : (value) {
                                                if (value == null) return;
                                                _speech.reset();
                                                _speech.setLocale(value);
                                              },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 22),
                                if (_query.isNotEmpty) ...[
                                  Text(
                                    _query,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: _muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    _message,
                                    key: const ValueKey(
                                      'chotu-current-message',
                                    ),
                                    style: TextStyle(
                                      color:
                                          _needsAttention ||
                                              !_ready && !_checking
                                          ? const Color(0xFF8B4825)
                                          : _ink,
                                      height: 1.45,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                if (_checking || _busy)
                                  const Center(
                                    child: SizedBox.square(
                                      dimension: 32,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: _blue,
                                      ),
                                    ),
                                  )
                                else if (!_ready || _startupError != null)
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: OutlinedButton.icon(
                                      onPressed: _connect,
                                      icon: const Icon(
                                        Icons.refresh_rounded,
                                        size: 17,
                                      ),
                                      label: const Text('Retry'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: _blue,
                                      ),
                                    ),
                                  )
                                else
                                  Center(
                                    child: Tooltip(
                                      message: _speech.isListening
                                          ? 'Finish speaking'
                                          : 'Start listening',
                                      child: AnimatedScale(
                                        scale: _speech.isListening
                                            ? 1 + _speech.audioLevel * 0.04
                                            : 1,
                                        duration: const Duration(
                                          milliseconds: 120,
                                        ),
                                        child: IconButton.filled(
                                          key: const ValueKey(
                                            'chotu-microphone',
                                          ),
                                          onPressed: () {
                                            if (_speech.isListening) {
                                              _speech.stopListening();
                                            } else {
                                              unawaited(_listen());
                                            }
                                          },
                                          iconSize: 28,
                                          padding: const EdgeInsets.all(16),
                                          style: IconButton.styleFrom(
                                            backgroundColor: _blue,
                                            foregroundColor: Colors.white,
                                          ),
                                          icon: Icon(
                                            _speech.isListening
                                                ? Icons.stop_rounded
                                                : Icons.mic_rounded,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 18),
                                TextField(
                                  key: const ValueKey('chotu-order-input'),
                                  controller: _input,
                                  enabled:
                                      !_checking &&
                                      !_busy &&
                                      _ready &&
                                      _startupError == null,
                                  textInputAction: TextInputAction.send,
                                  style: const TextStyle(
                                    color: _ink,
                                    fontSize: 14,
                                  ),
                                  onSubmitted: (value) =>
                                      unawaited(_send(value)),
                                  onTap: () {
                                    _speech.reset();
                                    _tts.stop();
                                  },
                                  decoration: InputDecoration(
                                    hintText: 'Type an order…',
                                    hintStyle: const TextStyle(
                                      color: _muted,
                                      fontSize: 14,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white.withValues(
                                      alpha: 0.6,
                                    ),
                                    contentPadding: const EdgeInsets.fromLTRB(
                                      14,
                                      14,
                                      6,
                                      14,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                    suffixIcon: IconButton(
                                      tooltip: 'Send order',
                                      onPressed:
                                          _checking ||
                                              _busy ||
                                              !_ready ||
                                              _startupError != null
                                          ? null
                                          : () => unawaited(_send(_input.text)),
                                      icon: const Icon(
                                        Icons.arrow_upward_rounded,
                                      ),
                                      color: _blue,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
