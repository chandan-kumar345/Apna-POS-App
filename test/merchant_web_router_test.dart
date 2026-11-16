import 'package:apna_pos/core/navigation/merchant_section.dart';
import 'package:apna_pos/core/navigation/merchant_web_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _BrowserHistory extends RouteInformationProvider with ChangeNotifier {
  _BrowserHistory(String initial) : _entries = [Uri.parse(initial)];

  final List<Uri> _entries;
  int _position = 0;

  Uri get current => _entries[_position];

  @override
  RouteInformation get value => RouteInformation(uri: current);

  @override
  void routerReportsNewRouteInformation(
    RouteInformation routeInformation, {
    RouteInformationReportingType type = RouteInformationReportingType.none,
  }) {
    final uri = routeInformation.uri;
    if (type == RouteInformationReportingType.neglect) {
      _entries[_position] = uri;
    } else if (type == RouteInformationReportingType.navigate ||
        uri != current) {
      _entries.removeRange(_position + 1, _entries.length);
      _entries.add(uri);
      _position++;
    }
  }

  void back() {
    _position--;
    notifyListeners();
  }

  void forward() {
    _position++;
    notifyListeners();
  }
}

class _FakeShell extends StatefulWidget {
  const _FakeShell();

  @override
  State<_FakeShell> createState() => _FakeShellState();
}

class _FakeShellState extends State<_FakeShell> {
  MerchantWebRouterDelegate? _router;
  MerchantSection _section = MerchantSection.pos;
  int _counter = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_router != null) return;
    final router = _router = MerchantWebRouterDelegate.maybeOf(context)!;
    _section = router.consumeRequestedSection() ?? MerchantSection.pos;
    router.attach(_onBrowserSection);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && router.currentConfiguration.path != _section.path) {
        Router.neglect(context, () => router.reportSection(_section));
      }
    });
  }

  void _onBrowserSection(MerchantSection section) {
    setState(() => _section = section);
  }

  @override
  void dispose() {
    _router?.detach(_onBrowserSection);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        Text(_section.path),
        TextButton(
          onPressed: () => setState(() => _counter++),
          child: Text('State: $_counter'),
        ),
        TextButton(
          onPressed: () => Router.navigate(context, () {
            setState(() => _section = MerchantSection.pos);
            _router!.reportSection(_section);
          }),
          child: const Text('Open POS'),
        ),
      ],
    ),
  );
}

void main() {
  test(
    'route parser retains legacy address until shell canonicalizes it',
    () async {
      final uri = await const MerchantRouteParser().parseRouteInformation(
        RouteInformation(
          uri: Uri.parse('https://apnaposs.vercel.app/#/my-orders'),
        ),
      );
      expect(uri.toString(), '/#/my-orders');
      expect(MerchantSection.fromUri(uri), MerchantSection.orders);
    },
  );

  testWidgets(
    'login restores section, then browser Back/Forward reuses shell',
    (tester) async {
      final history = _BrowserHistory('/#/dashboard');
      final navigatorKey = GlobalKey<NavigatorState>();
      final router = MerchantWebRouterDelegate(
        navigatorKey: navigatorKey,
        initialUri: history.current,
        initialHome: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  Navigator.of(context).pushReplacement<void, void>(
                    MaterialPageRoute(builder: (_) => const _FakeShell()),
                  ),
              child: const Text('Sign in'),
            ),
          ),
        ),
        onGenerateRoute: (_) => null,
      );
      await tester.pumpWidget(
        MaterialApp.router(
          routeInformationProvider: history,
          routeInformationParser: const MerchantRouteParser(),
          routerDelegate: router,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(_FakeShell), findsNothing);
      expect(history.current.toString(), '/#/dashboard');

      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(history.current.path, '/dashboard');
      expect(history.current.hasFragment, isFalse);
      expect(find.text('/dashboard'), findsOneWidget);
      final shell = tester.state(find.byType(_FakeShell));
      await tester.tap(find.text('State: 0'));
      await tester.tap(find.text('Open POS'));
      await tester.pumpAndSettle();
      expect(history.current.path, '/pos');
      expect(find.text('/pos'), findsOneWidget);

      history.back();
      await tester.pumpAndSettle();
      expect(find.text('/dashboard'), findsOneWidget);
      expect(find.text('State: 1'), findsOneWidget);
      expect(tester.state(find.byType(_FakeShell)), same(shell));

      history.forward();
      await tester.pumpAndSettle();
      expect(find.text('/pos'), findsOneWidget);
      expect(tester.state(find.byType(_FakeShell)), same(shell));
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      history.dispose();
    },
  );
}
