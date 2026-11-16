import 'package:flutter_test/flutter_test.dart';
import 'package:apna_pos/core/services/chotu_activation_service.dart';

void main() {
  test(
    'wake phrase is exact and never includes an executable ambient order',
    () {
      for (final phrase in [
        'Hello Chotu',
        'hey chhotu!',
        'हेलो छोटू',
        'हैलो छोटु।',
      ]) {
        expect(
          ChotuActivationService.isWakePhrase(phrase),
          isTrue,
          reason: phrase,
        );
      }
      for (final phrase in [
        'Chotu',
        'hello',
        'hello chotu add two naan',
        'say hello chotu',
        'hello chotu settle cash',
      ]) {
        expect(
          ChotuActivationService.isWakePhrase(phrase),
          isFalse,
          reason: phrase,
        );
      }
    },
  );
}
