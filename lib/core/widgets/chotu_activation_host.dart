import 'dart:async';
import 'package:flutter/material.dart';
import '../database/database_service.dart';
import '../services/chotu_activation_service.dart';
import '../../features/pos/widgets/chotu_voice_sheet.dart';

final chotuRouteObserver = RouteObserver<ModalRoute<dynamic>>();

/// Exists only inside the authenticated main layout. No launch can bypass login.
class ChotuActivationHost extends StatefulWidget {
  const ChotuActivationHost({super.key, required this.child});
  final Widget child;
  @override
  State<ChotuActivationHost> createState() => _ChotuActivationHostState();
}

class _ChotuActivationHostState extends State<ChotuActivationHost>
    with WidgetsBindingObserver, RouteAware {
  final _activation = ChotuActivationService();
  ModalRoute<dynamic>? _route;
  bool _foreground = true;
  bool _open = false;
  bool _pendingLaunch = false;
  String _scope = '';

  @override
  void initState() {
    super.initState();
    _scope = _currentScope;
    WidgetsBinding.instance.addObserver(this);
    _activation.attach(_activate);
    _activation.addListener(_changed);
    DatabaseService().addListener(_accessChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (_route != route && route != null) {
      chotuRouteObserver.unsubscribe(this);
      _route = route;
      chotuRouteObserver.subscribe(this, route);
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  bool get _allowed {
    final db = DatabaseService();
    final user = db.currentUser;
    return user != null &&
        db.isChotuVoiceEnabled &&
        (user.isOwner || user.isAdmin || user.hasPermission('pos'));
  }

  void _accessChanged() {
    if (!_allowed || _scope != _currentScope) _activation.disarm();
    _scope = _currentScope;
  }

  String get _currentScope =>
      '${DatabaseService().currentBusinessId}|${DatabaseService().currentUser?.id ?? ''}';

  void _resume() {
    _activation.suspend(!_foreground || _route?.isCurrent != true || !_allowed);
    if (_foreground && _route?.isCurrent == true) {
      if (_pendingLaunch) _activate();
      unawaited(_activation.consumeAssistantRequest());
    }
  }

  @override
  void didPush() => _resume();
  @override
  void didPushNext() => _activation.suspend(true);
  @override
  void didPopNext() => _resume();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground && state != AppLifecycleState.inactive) {
      _activation.disarm();
    }
    _resume();
  }

  void _activate() {
    if (!_allowed || !mounted) return;
    if (!_foreground || _route?.isCurrent != true) {
      _pendingLaunch = true;
      return;
    }
    if (_open) return;
    _pendingLaunch = false;
    _open = true;
    _activation.disarm();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await Navigator.of(context).push(
        PageRouteBuilder<void>(
          opaque: false,
          barrierColor: Colors.transparent,
          pageBuilder: (_, _, _) => const ChotuVoiceSheet(),
        ),
      );
      _open = false;
      _resume();
    });
  }

  @override
  void dispose() {
    chotuRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    DatabaseService().removeListener(_accessChanged);
    _activation.removeListener(_changed);
    _activation.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      widget.child,
      if (_activation.isArmed)
        Positioned(
          right: 16,
          bottom: MediaQuery.paddingOf(context).bottom + 16,
          child: Material(
            color: const Color(0xEE102B48),
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              onTap: _activation.disarm,
              borderRadius: BorderRadius.circular(24),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.mic, size: 16, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'Hello Chotu · Stop',
                      style: TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
    ],
  );
}
