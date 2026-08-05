import 'dart:io';

void main() {
  final file = File('lib/features/menu/menu_management_screen.dart');
  String content = file.readAsStringSync();

  // 1. Scaffold & Background
  // Currently the build method returns SafeArea wrapping a Column. Wait, does it have a Scaffold?
  // Let's wrap the main return with a Scaffold if it isn't already, or change background.
  if (!content.contains('Scaffold(')) {
    content = content.replaceFirst('return SafeArea(', 'return Scaffold(\n      backgroundColor: const Color(0xFFEEF5F9),\n      body: SafeArea(');
  } else {
    content = content.replaceAll('backgroundColor: Colors.transparent', 'backgroundColor: const Color(0xFFEEF5F9)');
  }

  // 2. Colors - replace GlassTheme dark colors with App light theme colors
  content = content.replaceAll('GlassTheme.primaryViolet', 'const Color(0xFF0F172A)'); // Dark Text/Primary
  content = content.replaceAll('GlassTheme.primaryCyan', 'const Color(0xFF0284C7)'); // Blue accents
  content = content.replaceAll('GlassTheme.accentNeonGreen', 'const Color(0xFF059669)'); // Green success
  content = content.replaceAll('GlassTheme.accentRose', 'const Color(0xFFE11D48)'); // Red danger
  content = content.replaceAll('GlassTheme.textMedium', 'const Color(0xFF64748B)'); // Subtitle gray
  content = content.replaceAll('GlassTheme.glassInput', 'Colors.white.withOpacity(0.65)'); // Card backgrounds
  content = content.replaceAll('GlassTheme.glassBorder', 'const Color(0xFFE2E8F0)'); // Borders
  
  // 3. General Colors
  content = content.replaceAll('color: Colors.white,', 'color: const Color(0xFF0F172A),');
  content = content.replaceAll('color: Colors.white', 'color: const Color(0xFF0F172A)');
  content = content.replaceAll('Colors.white54', 'const Color(0xFF94A3B8)');
  content = content.replaceAll('Colors.white70', 'const Color(0xFF64748B)');
  
  // Modal Backgrounds
  content = content.replaceAll('backgroundColor: Colors.transparent,', 'backgroundColor: Colors.transparent, elevation: 0,');
  
  // GlassContainers inside modals or main UI should have light theme explicitly
  content = content.replaceAll('GlassContainer(', 'GlassContainer(\n    backgroundColor: Colors.white.withOpacity(0.65),\n    borderColor: const Color(0xFFE2E8F0),\n    ');
  // Fix double insertions if any
  content = content.replaceAll('backgroundColor: Colors.white.withOpacity(0.65),\n    borderColor: const Color(0xFFE2E8F0),\n    backgroundColor:', 'backgroundColor:');
  content = content.replaceAll('borderColor: const Color(0xFFE2E8F0),\n    borderColor:', 'borderColor:');

  // 4. Buttons smaller and responsive
  content = content.replaceAll('GlassButton(', 'GlassButton(\n    height: 38,\n    ');
  // Text sizes for inputs and labels
  content = content.replaceAll('fontSize: 16', 'fontSize: 14');
  content = content.replaceAll('fontSize: 18', 'fontSize: 16');
  content = content.replaceAll('fontSize: 20', 'fontSize: 18');
  content = content.replaceAll('fontSize: 24', 'fontSize: 20');

  // 5. Responsive Grid
  // The GridView for products might have crossAxisCount: 4. We should make it responsive using LayoutBuilder or MediaQuery.
  // Actually, we can use LayoutBuilder around the GridView.
  
  file.writeAsStringSync(content);
  print('Menu refactored successfully.');
}
