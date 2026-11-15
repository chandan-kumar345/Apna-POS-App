import 'dart:async';

import 'package:apna_pos/core/models/menu_item_model.dart';
import 'package:apna_pos/features/pos/widgets/pos_product_media_box.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

class _VideoPlatform extends VideoPlayerPlatform {
  Size videoSize = const Size(320, 180);
  final streams = <int, StreamController<VideoEvent>>{};
  final disposed = <int>[];
  final played = <int>[];
  final paused = <int>[];
  final failed = <int>{};
  final pending = <int>{};

  @override
  Future<void> init() async {}
  @override
  Future<int?> create(DataSource dataSource) async {
    final id = streams.length;
    final stream = StreamController<VideoEvent>();
    streams[id] = stream;
    if (failed.contains(id)) {
      stream.addError(
        PlatformException(code: 'invalid-video', message: 'Invalid video'),
      );
    } else if (!pending.contains(id)) {
      stream.add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          duration: const Duration(seconds: 30),
          size: videoSize,
        ),
      );
    }
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => streams[playerId]!.stream;
  @override
  Future<void> dispose(int playerId) async {
    disposed.add(playerId);
  }

  @override
  Future<void> play(int playerId) async {
    played.add(playerId);
  }

  @override
  Future<void> pause(int playerId) async { paused.add(playerId); }
  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> setVolume(int playerId, double volume) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
  @override
  Future<void> setPreventsDisplaySleepDuringVideoPlayback(
    int playerId,
    bool value,
  ) async {}
  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;
  @override
  Widget buildView(int playerId) =>
      ColoredBox(key: ValueKey('video-$playerId'), color: Colors.blue);
}

MenuItemModel _item(String id) => MenuItemModel(
  id: id,
  name: id,
  description: '',
  price: 10,
  category: 'Food',
  videoUrl: 'assets/$id.mp4',
);

Widget _card(String id, {bool priority = false, bool independent = false}) => SizedBox(
  width: 200,
  height: 150,
  child: PosProductMediaBox(
    key: ValueKey(id),
    item: _item(id),
    autoPlayVideo: !priority,
    priorityPlayback: priority,
    independentPlayback: independent,
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _VideoPlatform platform;
  late VideoPlayerPlatform previous;
  setUp(() {
    previous = VideoPlayerPlatform.instance;
    platform = _VideoPlatform();
    VideoPlayerPlatform.instance = platform;
  });
  tearDown(() {
    VideoPlayerPlatform.instance = previous;
  });

  Future<void> pumpCards(WidgetTester tester, List<Widget> cards) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Row(children: cards)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }

  Future<void> cleanUp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 20));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }

  testWidgets('hidden POS tab pauses all videos and resumes without recreating decoders', (tester) async {
    Widget host(bool enabled) => MaterialApp(home: TickerMode(enabled: enabled,
      child: Scaffold(body: Row(children: [
        _card('one', independent: true), _card('two', independent: true),
      ]))));
    await tester.pumpWidget(host(true));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();
    expect(platform.played.toSet(), containsAll([0, 1]));
    platform.paused.clear();
    await tester.pumpWidget(host(false));
    await tester.pump();
    expect(platform.paused.toSet(), containsAll([0, 1]));
    final playCount = platform.played.length;
    await tester.pump(const Duration(seconds: 1));
    expect(platform.played.length, playCount);
    await tester.pumpWidget(host(true));
    await tester.pump();
    expect(platform.played.length, greaterThan(playCount));
    expect(platform.streams.length, 2);
    expect(platform.disposed, isEmpty);
    await cleanUp(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('initially hidden tab does not allocate a video decoder', (tester) async {
    await tester.pumpWidget(MaterialApp(home: TickerMode(enabled: false,
      child: Scaffold(body: _card('hidden', independent: true)))));
    await tester.pump(const Duration(seconds: 1));
    expect(platform.streams, isEmpty);
    await cleanUp(tester);
  });

  testWidgets('all POS product videos play together without evicting each other', (tester) async {
    await pumpCards(tester, [
      _card('first', independent: true),
      _card('second', independent: true),
      _card('third', independent: true),
    ]);
    expect(platform.played.toSet(), containsAll([0, 1, 2]));
    expect(platform.disposed, isEmpty);
    await cleanUp(tester);
    expect(platform.disposed.toSet(), containsAll([0, 1, 2]));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('a priority preview does not stop independent POS videos', (tester) async {
    await pumpCards(tester, [_card('first', independent: true), _card('second', independent: true)]);
    await pumpCards(tester, [_card('first', independent: true), _card('second', independent: true), _card('preview', priority: true)]);
    expect(platform.played.toSet(), containsAll([0, 1, 2]));
    expect(platform.disposed, isEmpty);
    await cleanUp(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('failed native initialization disposes its allocated decoder', (
    tester,
  ) async {
    platform.failed.add(0);
    await pumpCards(tester, [_card('broken')]);
    expect(platform.disposed, contains(0));
    await cleanUp(tester);
  });

  testWidgets('removing a loading card releases its native decoder', (
    tester,
  ) async {
    platform.pending.add(0);
    await pumpCards(tester, [_card('loading')]);
    await cleanUp(tester);
    expect(platform.disposed, contains(0));
  });

  testWidgets('a timed out video gives the decoder to the next visible card', (
    tester,
  ) async {
    platform.pending.add(0);
    await pumpCards(tester, [_card('loading'), _card('next')]);
    await tester.pump(const Duration(seconds: 16));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(platform.disposed, contains(0));
    expect(platform.played, contains(1));
    await cleanUp(tester);
  });

  testWidgets('closing a priority preview resumes the waiting grid video', (
    tester,
  ) async {
    await pumpCards(tester, [_card('grid')]);
    expect(platform.played, contains(0));
    await pumpCards(tester, [_card('grid'), _card('detail', priority: true)]);
    expect(platform.disposed, contains(0));
    expect(platform.played, contains(1));
    await pumpCards(tester, [_card('grid')]);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();
    expect(platform.played, contains(2));
    await cleanUp(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('an old initialization error cannot stop the replacement video', (
    tester,
  ) async {
    platform.pending.add(0);
    Widget card(String source) => SizedBox(
      width: 200,
      height: 150,
      child: PosProductMediaBox(
        key: const ValueKey('same-card'),
        item: _item(source),
        autoPlayVideo: true,
      ),
    );
    await pumpCards(tester, [card('old')]);
    await pumpCards(tester, [card('new')]);
    expect(platform.played, contains(1));
    platform.streams[0]!.addError(
      PlatformException(code: 'late-old-error', message: 'Old video failed'),
    );
    await tester.pump();
    expect(platform.disposed, isNot(contains(1)));
    expect(find.byKey(const ValueKey('video-1')), findsOneWidget);
    await cleanUp(tester);
  });

  for (final size in [const Size(1920, 1080), const Size(1080, 1920)]) {
    testWidgets('contained preview keeps the full video frame at $size', (tester) async {
      platform.videoSize = size;
      await pumpCards(tester, [SizedBox(
        width: 300, height: 180,
        child: PosProductMediaBox(
          item: _item('full-frame'), fit: BoxFit.contain,
          priorityPlayback: true, independentPlayback: true,
        ),
      )]);
      final video = find.byKey(const ValueKey('video-0'));
      expect(video, findsOneWidget);
      final frame = tester.getRect(video);
      final canvas = tester.getRect(find.byType(PosProductMediaBox));
      expect(frame.width / frame.height, closeTo(size.width / size.height, .001));
      expect(frame.left, greaterThanOrEqualTo(canvas.left - .1));
      expect(frame.top, greaterThanOrEqualTo(canvas.top - .1));
      expect(frame.right, lessThanOrEqualTo(canvas.right + .1));
      expect(frame.bottom, lessThanOrEqualTo(canvas.bottom + .1));
      expect(platform.played, contains(0));
      expect(tester.takeException(), isNull);
      await cleanUp(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  }
}
