import 'dart:async';
import 'package:apna_pos/core/services/sound_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'slow native feedback does not queue more playback for rapid taps',
    () async {
      final prepared = Completer<void>();
      var starts = 0;
      final playback = ShortFeedbackPlayback(() {
        starts++;
        return prepared.future;
      });
      final first = playback.play();
      await Future.wait(List.generate(30, (_) => playback.play()));
      expect(starts, 1);
      prepared.complete();
      await first;
      await playback.play();
      expect(starts, 2);
    },
  );

  test(
    'an asynchronous audio failure is handled and later taps remain usable',
    () async {
      var starts = 0;
      final playback = ShortFeedbackPlayback(() async {
        starts++;
        throw StateError('Native audio unavailable');
      });
      await playback.play();
      await playback.play();
      expect(starts, 2);
    },
  );

  testWidgets(
    'a stuck feedback request times out without blocking the next tap',
    (tester) async {
      var starts = 0;
      final playback = ShortFeedbackPlayback(() {
        starts++;
        return Completer<void>().future;
      });
      final pending = playback.play();
      await tester.pump(const Duration(milliseconds: 1100));
      await pending;
      final next = playback.play();
      expect(starts, 2);
      await tester.pump(const Duration(milliseconds: 1100));
      await next;
    },
  );
}
