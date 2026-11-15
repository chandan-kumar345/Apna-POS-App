import 'dart:convert';

/// Consistent order data across socket envelopes, push data and saved alerts.
class IncomingOrderPayload {
  static Map<String, dynamic> decodeMap(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      try {
        value = jsonDecode(value);
      } catch (_) {
        return {};
      }
    }
    return value is Map ? Map<String, dynamic>.from(value) : {};
  }

  static bool _hasValue(dynamic value) =>
      value != null &&
      (value is! List || value.isNotEmpty) &&
      (value is! Map || value.isNotEmpty) &&
      (value is! String ||
          (value.trim().isNotEmpty &&
              !['null', 'undefined'].contains(value.trim().toLowerCase())));

  static List<Map<String, dynamic>> _layers(Map<String, dynamic> payload) {
    final layers = <Map<String, dynamic>>[payload];
    var start = 0;
    for (var depth = 0; depth < 3; depth++) {
      final end = layers.length;
      for (var i = start; i < end; i++) {
        for (final key in ['metadata', 'order', 'data']) {
          final nested = decodeMap(layers[i][key]);
          if (nested.isNotEmpty) layers.add(nested);
        }
      }
      if (end == layers.length) break;
      start = end;
    }
    return layers;
  }

  static Map<String, dynamic> normalize(Map<String, dynamic> payload) {
    final result = <String, dynamic>{};
    for (final layer in _layers(payload)) {
      for (final entry in layer.entries) {
        if (_hasValue(entry.value) && !_hasValue(result[entry.key])) {
          result[entry.key] = entry.value;
        }
      }
    }
    final table = tableNumber(payload);
    if (table != null) result['tableNumber'] = table;
    if (result.containsKey('metadata')) {
      result['metadata'] = Map<String, dynamic>.fromEntries(
        decodeMap(
          result['metadata'],
        ).entries.where((entry) => _hasValue(entry.value)),
      );
    }
    return result;
  }

  static String? normalizeTableNumber(dynamic value) {
    if (value is Map) {
      for (final key in [
        'tableNumber',
        'number',
        'tableNo',
        'tableCode',
        'code',
        'tableName',
        'name',
      ]) {
        final table = normalizeTableNumber(value[key]);
        if (table != null) return table;
      }
      return null;
    }
    if (value is! String && value is! num) return null;
    var text = value.toString().trim();
    if (text.isEmpty ||
        [
          'null',
          'undefined',
          'none',
          'n/a',
          'table',
          'dine-in',
          'dine in',
          'dinein',
        ].contains(text.toLowerCase())) {
      return null;
    }
    text = text
        .replaceFirst(
          RegExp(r'^(?:table|tbl)\s*[-:#]?\s*', caseSensitive: false),
          '',
        )
        .trim();
    final numeric = RegExp(
      r'^(?:t[\s_-]*)?(\d+)$',
      caseSensitive: false,
    ).firstMatch(text);
    if (numeric != null) {
      final number = int.tryParse(numeric.group(1)!);
      return number != null && number > 0 ? '$number' : null;
    }
    if (text.isEmpty ||
        ['dine-in', 'dine in', 'dinein'].contains(text.toLowerCase())) {
      return null;
    }
    return text;
  }

  /// Only explicit table markers are inferred from free text, never a street's T.
  static String? tableFromText(String text) {
    final match = RegExp(
      r'\b(?:table|tbl)\s*[-:#]?\s*(t?[\s_-]*\d+[a-z]?|[a-z]\d+)\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (match != null) return normalizeTableNumber(match.group(1));
    final parenthesized = RegExp(
      r'\(\s*(t[\s_-]*\d+)\s*\)',
      caseSensitive: false,
    ).firstMatch(text);
    return parenthesized == null
        ? null
        : normalizeTableNumber(parenthesized.group(1));
  }

  static String? tableNumber(Map<String, dynamic> payload, {bool preserveFormat = false}) {
    final layers = _layers(payload);
    for (final layer in layers) {
      for (final key in [
        'tableNumber',
        'tableNo',
        'table_no',
        'table_number',
        'tableCode',
        'table_code',
        'tableName',
        'T',
        't',
        'table',
      ]) {
        final raw = layer[key];
        final value = normalizeTableNumber(raw);
        if (value != null) {
          return preserveFormat && (raw is String || raw is num) ? raw.toString().trim() : value;
        }
      }
    }
    for (final layer in layers) {
      for (final key in ['deliveryAddress', 'address', 'customerName']) {
        final value = layer[key];
        if (value is String) {
          final table = tableFromText(value);
          if (table != null) return table;
        }
      }
    }
    return null;
  }
}
