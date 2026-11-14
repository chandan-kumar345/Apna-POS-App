import 'dart:async';
import 'dart:collection';

typedef CartMutationTransport =
    Future<Map<String, dynamic>?> Function(
      String scope,
      String path,
      Map<String, dynamic> payload,
    );

/// Combines adjacent identical quantity edits and orders writes per cart.
/// Increments and decrements remain distinct: their order matters at zero.
class CartMutationQueue {
  final CartMutationTransport transport;
  final Duration batchWindow;
  final Map<String, _CartLane> _lanes = {};

  CartMutationQueue(
    this.transport, {
    this.batchWindow = const Duration(milliseconds: 180),
  });

  Future<Map<String, dynamic>?> enqueue({
    required String scope,
    required String cart,
    required String path,
    required Map<String, dynamic> payload,
    String? mergeKey,
    bool immediate = false,
  }) {
    final laneKey = '$scope|$cart';
    final lane = _lanes.putIfAbsent(laneKey, _CartLane.new);
    final completion = Completer<Map<String, dynamic>?>();
    final last = lane.pending.isEmpty ? null : lane.pending.last;
    if (mergeKey != null && last?.mergeKey == mergeKey && last?.path == path) {
      last!.payload['quantity'] =
          (last.payload['quantity'] as int) + (payload['quantity'] as int);
      last.completions.add(completion);
    } else {
      lane.pending.add(
        _CartMutation(scope, path, Map.of(payload), mergeKey, completion),
      );
    }
    if (immediate) {
      lane.timer?.cancel();
      lane.timer = null;
      unawaited(_drain(laneKey, lane));
    } else if (!lane.running && lane.timer == null) {
      // Fixed window from the first tap; continuous tapping cannot starve sync.
      lane.timer = Timer(batchWindow, () {
        lane.timer = null;
        unawaited(_drain(laneKey, lane));
      });
    }
    return completion.future;
  }

  Future<void> _drain(String key, _CartLane lane) async {
    if (lane.running) return;
    lane.running = true;
    try {
      while (lane.pending.isNotEmpty) {
        final mutation = lane.pending.removeFirst();
        Map<String, dynamic>? result;
        try {
          result = await transport(
            mutation.scope,
            mutation.path,
            mutation.payload,
          );
        } catch (_) {
          /* Local drafts remain available when background sync fails. */
        }
        for (final completion in mutation.completions) {
          completion.complete(result);
        }
      }
    } finally {
      lane.running = false;
      lane.idle?.complete();
      if (identical(_lanes[key], lane)) _lanes.remove(key);
    }
  }

  Future<void> flush(String scope, String cart) async {
    final key = '$scope|$cart';
    final lane = _lanes[key];
    if (lane == null) return;
    lane.timer?.cancel();
    lane.timer = null;
    lane.idle ??= Completer<void>();
    unawaited(_drain(key, lane));
    await lane.idle!.future;
  }
}

class _CartLane {
  final pending = Queue<_CartMutation>();
  Timer? timer;
  bool running = false;
  Completer<void>? idle;
}

class _CartMutation {
  final String scope;
  final String path;
  final Map<String, dynamic> payload;
  final String? mergeKey;
  final List<Completer<Map<String, dynamic>?>> completions;
  _CartMutation(
    this.scope,
    this.path,
    this.payload,
    this.mergeKey,
    Completer<Map<String, dynamic>?> completion,
  ) : completions = [completion];
}
