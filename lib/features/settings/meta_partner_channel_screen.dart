import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/meta_partner_service.dart';

class MetaPartnerChannelScreen extends StatefulWidget {
  final MetaPartnerService? service;
  const MetaPartnerChannelScreen({super.key, this.service});

  @override
  State<MetaPartnerChannelScreen> createState() =>
      _MetaPartnerChannelScreenState();
}

class _MetaPartnerChannelScreenState extends State<MetaPartnerChannelScreen>
    with WidgetsBindingObserver {
  static const _ink = Color(0xFF152641);
  static const _muted = Color(0xFF53657D);
  static const _blue = Color(0xFF075DF2);
  static const _line = Color(0xFFE5EBF3);
  late final MetaPartnerService _service =
      widget.service ?? MetaPartnerService();
  MetaPartnerStatus? _status;
  List<MetaChannelItem> _channels = [];
  List<MetaTemplateItem> _templates = [];
  MetaPartnerAnalytics? _analytics;
  String? _error, _notice;
  bool _loading = true, _busy = false;
  int _tab = 0;

  MetaChannelItem? get _primary => _channels
      .where(
        (c) =>
            c.phoneNumberId.isNotEmpty &&
            c.phoneNumberId == _status?.phoneNumberId,
      )
      .firstOrNull;
  bool get _connected => _status?.phoneNumberId.isNotEmpty == true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_busy) _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait([
        _service.getStatus(),
        _service.getChannels(),
      ]);
      if (!mounted) return;
      final status = results[0] as MetaPartnerStatus?;
      if (status == null) {
        throw StateError('Could not load the WhatsApp connection.');
      }
      setState(() {
        _status = status;
        _channels = results[1] as List<MetaChannelItem>;
      });
      if (_tab == 1) await _loadTemplates();
      if (_tab == 0 && status.canSend) {
        try {
          final analytics = await _service.getAnalytics();
          if (mounted) setState(() => _analytics = analytics);
        } catch (_) {
          if (mounted) setState(() => _analytics = null);
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _status = null;
          _channels = [];
          _analytics = null;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadTemplates() async {
    final templates = await _service.getTemplates();
    if (mounted) setState(() => _templates = templates);
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await action();
      if (!mounted) return;
      setState(() => _notice = success);
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signup() => _run(() async {
    final uri = await _service.startSignup();
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw StateError('Could not open Meta. Try again from your browser.');
    }
  }, 'Finish signup in Meta, then return here and refresh.');

  ThemeData _pageTheme(BuildContext context) {
    final family = Theme.of(context).textTheme.bodyMedium?.fontFamily;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: _blue,
          brightness: Brightness.light,
          surface: Colors.white,
        ).copyWith(
          primary: _blue,
          onPrimary: Colors.white,
          onSurface: _ink,
          onSurfaceVariant: _muted,
          outline: const Color(0xFFB8C4D5),
        );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: family,
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(bodyColor: _ink, displayColor: _ink),
      iconTheme: const IconThemeData(color: _ink),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        surfaceTintColor: Colors.transparent,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _blue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFE9EEF5),
          disabledForegroundColor: const Color(0xFF526178),
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: TextStyle(
            fontFamily: family,
            fontSize: 14,
            height: 1.3,
            fontWeight: FontWeight.w700,
          ),
          shape: shape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _blue,
          disabledForegroundColor: const Color(0xFF526178),
          minimumSize: const Size(48, 46),
          side: const BorderSide(color: Color(0xFFBDCEE8)),
          textStyle: TextStyle(
            fontFamily: family,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          shape: shape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _blue,
          disabledForegroundColor: const Color(0xFF526178),
          textStyle: TextStyle(
            fontFamily: family,
            fontSize: 14,
            height: 1.3,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: TextStyle(
          fontFamily: family,
          color: _ink,
          fontSize: 21,
          height: 1.25,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(
          fontFamily: family,
          color: _ink,
          fontSize: 15,
          height: 1.5,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF4F7FB),
        labelStyle: TextStyle(
          fontFamily: family,
          color: Color(0xFF465873),
          fontSize: 15,
        ),
        hintStyle: TextStyle(fontFamily: family, color: _muted, fontSize: 15),
        errorStyle: TextStyle(
          fontFamily: family,
          color: Color(0xFFB42335),
          fontSize: 14,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFBDCADB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _blue, width: 1.5),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: _pageTheme(context),
    child: Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        toolbarHeight: MediaQuery.textScalerOf(context).scale(19) > 25
            ? MediaQuery.textScalerOf(context).scale(19) * 2.4 + 16
            : kToolbarHeight,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'WhatsApp Business',
          maxLines: 2,
          softWrap: true,
          style: TextStyle(
            color: _ink,
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh connection',
            onPressed: _loading || _busy ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840),
            child: ListView(
              padding: EdgeInsets.all(
                MediaQuery.sizeOf(context).width < 600 ? 16 : 28,
              ),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const Text(
                  'Connect with your customers',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Manage WhatsApp chats, orders and receipts.',
                  style: TextStyle(color: _muted, height: 1.5, fontSize: 15),
                ),
                const SizedBox(height: 20),
                if (_busy || _loading)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: LinearProgressIndicator(minHeight: 3),
                  ),
                if (_error != null) _message(_error!, error: true),
                if (_notice != null) _message(_notice!),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in [
                      'Connection',
                      'Templates',
                      'Business profile',
                    ].asMap().entries)
                      ChoiceChip(
                        label: Text(entry.value),
                        selected: _tab == entry.key,
                        showCheckmark: false,
                        selectedColor: const Color(0xFFE6EFFF),
                        side: BorderSide(
                          color: _tab == entry.key
                              ? const Color(0xFFB7D0FF)
                              : _line,
                        ),
                        labelStyle: TextStyle(
                          color: _tab == entry.key ? _blue : _muted,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        onSelected: _busy
                            ? null
                            : (_) async {
                                setState(() {
                                  _tab = entry.key;
                                  _error = null;
                                });
                                if (_tab == 1) {
                                  try {
                                    await _loadTemplates();
                                  } catch (error) {
                                    if (mounted) {
                                      setState(() => _error = error.toString());
                                    }
                                  }
                                }
                              },
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                if (_status != null) ...[
                  if (_tab == 0) ..._connection(),
                  if (_tab == 1) _templateList(),
                  if (_tab == 2) _profile(),
                ] else if (!_loading)
                  _card(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Connection unavailable',
                          style: TextStyle(
                            color: _ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Check your connection and try again.',
                          style: TextStyle(color: _muted),
                        ),
                        TextButton(
                          onPressed: _load,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _connectionCard(MetaPartnerStatus status, String label, bool ready) =>
      _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF1FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: _blue,
                    size: 25,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Business number',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        label,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 18,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (ready)
                  const Icon(
                    Icons.check_circle,
                    color: Color(0xFF087B57),
                    size: 24,
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              status.phoneNumber.isEmpty
                  ? 'Add your WhatsApp number'
                  : status.phoneNumber,
              style: TextStyle(
                color: _ink,
                fontSize: status.phoneNumber.isEmpty ? 20 : 25,
                height: 1.3,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              status.verifiedName.isEmpty
                  ? 'Use the number your customers know.'
                  : status.verifiedName,
              style: const TextStyle(
                color: Color(0xFF475A74),
                fontSize: 15,
                height: 1.4,
              ),
            ),
            if (status.healthMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: _message(status.healthMessage, error: true),
              ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : _signup,
                icon: Icon(
                  _connected ? Icons.link_rounded : Icons.add_rounded,
                  size: 20,
                ),
                label: Text(
                  _connected ? 'Reconnect with Meta' : 'Continue with Facebook',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            if (ready) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _testMessage,
                  icon: const Icon(Icons.send_outlined, size: 18),
                  label: const Text('Test connection'),
                ),
              ),
            ],
          ],
        ),
      );

  List<Widget> _connection() {
    final status = _status!;
    final ready = status.canSend;
    final label = switch (status.partnerStatus) {
      'ACTIVE' => 'Connected',
      'SETUP_REQUIRED' => 'Finish setup',
      'RECONNECT_REQUIRED' => 'Reconnect required',
      'CHECK_FAILED' => 'Could not verify connection',
      _ => 'Not connected',
    };
    return [
      _connectionCard(status, label, ready),
      const SizedBox(height: 16),
      _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Setup checklist',
              style: TextStyle(
                color: _ink,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${[_connected && status.metaPartnerVerified, status.pinRegistered, status.webhookSubscribed].where((complete) => complete).length} of 3 steps complete',
              style: const TextStyle(color: _muted, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 20),
            _step(
              1,
              'Connect your Meta account',
              'Choose your business and WhatsApp number.',
              _connected && status.metaPartnerVerified,
              'Connect',
              _signup,
            ),
            const Divider(color: _line, height: 30),
            _step(
              2,
              'Register your number',
              'Secure your number with a six-digit PIN.',
              status.pinRegistered,
              'Register',
              _primary == null ? null : _register,
            ),
            const Divider(color: _line, height: 30),
            _step(
              3,
              'Enable incoming messages',
              'Receive customer chats and delivery updates.',
              status.webhookSubscribed,
              'Enable',
              _primary == null
                  ? null
                  : () => _run(() async {
                      if (!await _service.subscribeWebhook(
                        channelId: _primary!.channelId,
                      )) {
                        throw StateError('Could not enable incoming messages.');
                      }
                    }, 'Incoming messages enabled.'),
            ),
          ],
        ),
      ),
      if (_analytics != null && ready) ...[
        const SizedBox(height: 16),
        _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Today’s chat activity',
                style: TextStyle(
                  color: _ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 32,
                runSpacing: 16,
                children: [
                  _metric('Sent', '${_analytics!.sentToday}'),
                  _metric('Delivered', _analytics!.deliveredRate),
                  _metric('Failed', '${_analytics!.failedCount}'),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Recorded Apna POS chats · India time',
                style: TextStyle(color: _muted, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 14),
      ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 4),
        title: const Text(
          'Advanced connection',
          style: TextStyle(color: _muted, fontSize: 14),
        ),
        children: [
          const Text(
            'For administrators with existing WhatsApp Cloud API credentials.',
            style: TextStyle(color: _muted, fontSize: 14),
          ),
          TextButton(
            onPressed: _busy ? null : _manualConnect,
            child: const Text('Connect using account IDs'),
          ),
        ],
      ),
      if (_connected)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _busy ? null : _disconnect,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFB83F47),
            ),
            child: const Text('Disconnect this number'),
          ),
        ),
    ];
  }

  Widget _step(
    int number,
    String title,
    String detail,
    bool done,
    String action,
    VoidCallback? callback,
  ) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      CircleAvatar(
        radius: 16,
        backgroundColor: done
            ? const Color(0xFFE3F6EE)
            : const Color(0xFFEDF2FA),
        child: done
            ? const Icon(
                Icons.check_rounded,
                size: 18,
                color: Color(0xFF158662),
              )
            : Text(
                '$number',
                style: const TextStyle(
                  color: _muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: _ink,
                fontSize: 15,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              detail,
              style: const TextStyle(color: _muted, fontSize: 14, height: 1.4),
            ),
            if (!done)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: OutlinedButton(
                  onPressed: _busy ? null : callback,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    minimumSize: const Size(92, 44),
                  ),
                  child: Text(action),
                ),
              ),
          ],
        ),
      ),
    ],
  );

  Widget _metric(String title, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: const TextStyle(
          color: _ink,
          fontWeight: FontWeight.w800,
          fontSize: 23,
        ),
      ),
      Text(title, style: const TextStyle(color: _muted, fontSize: 14)),
    ],
  );

  Widget _templateList() => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Message templates',
          style: TextStyle(
            color: _ink,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Meta approval is required before a template can be used.',
          style: TextStyle(color: _muted, fontSize: 14),
        ),
        const SizedBox(height: 16),
        if (_templates.isEmpty)
          const Text('No templates loaded.', style: TextStyle(color: _muted)),
        for (final template in _templates)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.description_outlined, color: _blue, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        template.displayName,
                        style: const TextStyle(
                          color: _ink,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${template.language} · ${template.status.replaceAll('_', ' ').toLowerCase()}',
                        style: const TextStyle(color: _muted, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                if (template.isLiveSynced && template.status == 'APPROVED')
                  const Icon(
                    Icons.check_circle_outline,
                    color: Color(0xFF158662),
                    size: 20,
                  ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: !_connected || _busy
              ? null
              : () => _run(
                  () async {
                    if (!await _service.syncTemplates()) {
                      throw StateError('Template submission failed.');
                    }
                  },
                  'Templates submitted for review. Refresh to check their status.',
                ),
          child: const Text('Submit starter templates'),
        ),
      ],
    ),
  );

  Widget _profile() => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Business profile',
          style: TextStyle(
            color: _ink,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        _detail('Business name', _status!.verifiedName),
        _detail('Phone', _status!.phoneNumber),
        _detail('About', _status!.aboutBio),
        _detail('Address', _status!.address),
        _detail('Website', _status!.website),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: _connected && !_busy ? _editProfile : null,
          child: const Text('Edit business profile'),
        ),
      ],
    ),
  );

  Widget _detail(String name, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: const TextStyle(color: _muted, fontSize: 14)),
        const SizedBox(height: 3),
        SelectableText(
          value.isEmpty ? 'Not provided' : value,
          style: const TextStyle(color: _ink, fontSize: 14),
        ),
      ],
    ),
  );

  Widget _card(Widget child) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _line),
    ),
    child: child,
  );

  Widget _message(String message, {bool error = false}) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: error ? const Color(0xFFFFF0F0) : const Color(0xFFE9F6F0),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      message,
      style: TextStyle(
        color: error ? const Color(0xFFA83842) : const Color(0xFF16694C),
        fontSize: 14,
        height: 1.5,
      ),
    ),
  );

  Future<Map<String, String>?> _form(
    String title,
    Map<String, String> fields, {
    String? secret,
    String? help,
  }) async {
    final values = Map<String, String>.from(fields);
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => Theme(
        data: _pageTheme(this.context),
        child: AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (help != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          help,
                          style: const TextStyle(color: _muted, fontSize: 14),
                        ),
                      ),
                    for (final entry in fields.entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: TextFormField(
                          initialValue: entry.value,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 16,
                            height: 1.4,
                          ),
                          cursorColor: _blue,
                          onChanged: (value) => values[entry.key] = value,
                          obscureText: entry.key == secret,
                          autocorrect: false,
                          keyboardType: entry.key == 'PIN'
                              ? TextInputType.number
                              : TextInputType.text,
                          decoration: InputDecoration(
                            labelText: entry.key,
                            border: const OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return [
                                    'About',
                                    'Address',
                                    'Website',
                                  ].contains(entry.key)
                                  ? null
                                  : 'Required';
                            }
                            if (entry.key == 'Website' &&
                                ![
                                  'http',
                                  'https',
                                ].contains(Uri.tryParse(value)?.scheme)) {
                              return 'Use a full https:// website address';
                            }
                            if (entry.key == 'PIN' &&
                                !RegExp(r'^\d{6}$').hasMatch(value)) {
                              return 'Enter six digits';
                            }
                            if (entry.key.endsWith('ID') &&
                                !RegExp(r'^\d+$').hasMatch(value)) {
                              return 'Use the numeric Meta ID';
                            }
                            if (entry.key == 'Recipient' &&
                                !RegExp(
                                  r'^\+?[1-9]\d{7,14}$',
                                ).hasMatch(value.replaceAll(' ', ''))) {
                              return 'Include the country code';
                            }
                            return null;
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(
                    context,
                    values.map((key, value) => MapEntry(key, value.trim())),
                  );
                }
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
    return result;
  }

  Future<void> _manualConnect() async {
    final values = await _form(
      'Connect Cloud API',
      {'WABA ID': '', 'Phone Number ID': '', 'Access token': ''},
      secret: 'Access token',
      help:
          'Use credentials belonging to this business. Apna POS verifies the number with Meta.',
    );
    if (values == null || !mounted) return;
    await _run(() async {
      final result = await _service.connectWaba(
        wabaId: values['WABA ID']!,
        phoneNumberId: values['Phone Number ID']!,
        phoneNumber: '',
        accessToken: values['Access token']!,
        onboardingType: 'direct',
      );
      if (result == null || result['success'] == false) {
        throw StateError('Connection could not be verified.');
      }
    }, 'Account verified. Complete the remaining setup steps.');
  }

  Future<void> _register() async {
    final values = await _form(
      'Register your number',
      {'PIN': ''},
      secret: 'PIN',
      help:
          'Enter or choose the six-digit two-step verification PIN for this number.',
    );
    if (values == null || !mounted || _primary == null) return;
    await _run(() async {
      if (!await _service.registerPin(
        channelId: _primary!.channelId,
        pin: values['PIN']!,
      )) {
        throw StateError('Meta did not confirm registration.');
      }
    }, 'Number registered.');
  }

  Future<void> _testMessage() async {
    final values = await _form(
      'Test connection',
      {'Recipient': ''},
      help:
          'Use your own number with country code. Message the business on WhatsApp first to open a 24-hour reply window.',
    );
    if (values == null || !mounted) return;
    await _run(
      () async {
        final result = await _service.sendTestMessage(
          recipientPhone: values['Recipient']!,
        );
        if (result == null) {
          throw StateError('Meta did not confirm the test message.');
        }
      },
      'Test accepted by Meta. Delivery is confirmed by incoming status updates.',
    );
  }

  Future<void> _editProfile() async {
    final values = await _form('Business profile', {
      'About': _status!.aboutBio,
      'Address': _status!.address,
      'Website': _status!.website,
    });
    if (values == null || !mounted) return;
    await _run(() async {
      if (!await _service.updateProfile(
        aboutBio: values['About'],
        address: values['Address'],
        website: values['Website'],
      )) {
        throw StateError('Profile update failed.');
      }
    }, 'Profile updated with Meta.');
  }

  Future<void> _disconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Theme(
        data: _pageTheme(this.context),
        child: AlertDialog(
          title: const Text('Disconnect WhatsApp?'),
          content: const Text(
            'Chats and automated sends from this number will stop. Existing conversation history is kept.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep connected'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Disconnect'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() async {
      if (!await _service.disconnect()) {
        throw StateError('Could not disconnect.');
      }
    }, 'WhatsApp disconnected.');
  }
}
