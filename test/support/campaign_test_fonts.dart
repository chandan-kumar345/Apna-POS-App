import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';

Future<void> loadCampaignTestFonts() async {
  final config = File('.dart_tool/package_config.json');
  final packages = jsonDecode(config.readAsStringSync())['packages'] as List;
  final flutter = packages.firstWhere((p) => p['name'] == 'flutter');
  final sdk = config.absolute.uri.resolve('${flutter['rootUri']}/');
  final dir =
      Platform.environment['CAMPAIGN_TEST_FONTS'] ??
      sdk.resolve('../../bin/cache/artifacts/material_fonts/').toFilePath();
  final font = FontLoader('Roboto');
  for (final weight in ['regular', 'medium', 'bold', 'black']) {
    font.addFont(
      Future.value(
        ByteData.sublistView(File('$dir/roboto-$weight.ttf').readAsBytesSync()),
      ),
    );
  }
  await font.load();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
}
