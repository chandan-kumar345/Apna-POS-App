import 'dart:io';

void main() {
  var file = File('lib/features/dashboard/dashboard_screen.dart');
  var lines = file.readAsLinesSync();
  var out = <String>[];
  
  for (int i = 0; i < lines.length; i++) {
    if (lines[i].contains('return true;')) {
      out.add(lines[i]);
      if (i + 1 < lines.length && lines[i + 1].contains('}).toList();')) {
        out.add(lines[i + 1]);
        out.add('  }');
        out.add('');
        out.add('  @override');
        out.add('  Widget build(BuildContext context) {');
        out.add('    // Determine screen size for responsiveness');
        out.add('    final size = MediaQuery.of(context).size;');
        out.add('    final isMobile = size.width < 768;');
        out.add('');
        out.add('    return Scaffold(');
        out.add('      backgroundColor: const Color(0xFFEEF5F9), // Light liquid glass canvas background');
        out.add('      body: Stack(');
        out.add('        children: [');
        out.add('          // 1. Ambient Liquid Background Blobs');
        out.add('          _buildLiquidBackground(size),');
        out.add('');
        out.add('          // 2. Main Scrollable Content');
        out.add('          SafeArea(');
        out.add('            child: SingleChildScrollView(');
        out.add('              padding: EdgeInsets.fromLTRB(');
        out.add('                isMobile ? 16 : 24,');
        out.add('                isMobile ? 12 : 20,');
        
        // Skip ahead to the remaining isMobile lines in the damaged file
        i += 2;
        while (i < lines.length && !lines[i].contains('isMobile ? 16 : 24,')) {
          i++;
        }
        out.add(lines[i]); // first `isMobile ? 16 : 24,`
        continue;
      }
    }
    out.add(lines[i]);
  }
  
  file.writeAsStringSync(out.join('\n'));
}
