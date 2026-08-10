# Apna POS - Design System & UI Generation Specification (`design.md`)

This document serves as the authoritative UI/UX Design System specification for the **Apna POS** application. All new screens, components, widgets, and user flows generated in this project MUST strictly follow the design tokens, component guidelines, layout rules, and code patterns specified here.

---

## 1. Design System Overview & Philosophy

### Core Aesthetic Principles
1. **Modern Enterprise & Premium Feel**: Clean, futuristic, and high-performance POS interface.
2. **Glassmorphism & Vibrant Micro-Glows**: Subtle translucent glass fills combined with logo electric blue (`#0052FF`) and cyan (`#00C2FF`) ambient glows.
3. **Ergonomic Semi-Circle Pill Controls**: Inputs, primary buttons, badges, and action items feature semi-circle pill borders (`BorderRadius.circular(26)`).
4. **High Contrast & Readability**: Crisp text hierarchy on dark/light surfaces optimized for restaurant and retail environments.
5. **Fluid Motion & Transitions**: Native-feeling slide-up and fade animations (`Curves.easeOutCubic`).

---

## 2. Color Palette & Design Tokens

### Brand & Accent Colors
| Token Name | Hex Code | Purpose / Usage |
| :--- | :--- | :--- |
| `primaryBlue` | `#0052FF` | Logo Electric Blue, primary buttons, selected tabs, main brand accents |
| `primaryNavy` | `#0A1435` | Deep Navy, headers, dark snackbars, contrast containers |
| `primaryCyan` | `#00C2FF` | Highlight borders, OTP pill box borders, active input outlines |
| `accentNeonGreen` | `#10B981` | Success states, free table status, completed order badges |
| `accentAmber` | `#F59E0B` | Warning states, occupied table status, pending orders |
| `accentRose` | `#F43F5E` | Error banners, cancelled orders, reserved table status |
| `statusBilled` | `#06B6D4` | Billed table status, invoice details |

### Text Colors
| Token Name | Hex Code | Purpose / Usage |
| :--- | :--- | :--- |
| `textHigh` | `#0F172A` / `#F8FAFC` | Primary titles, input text, prominent headers |
| `textMedium` | `#64748B` / `#94A3B8` | Subtitles, labels, secondary descriptions |
| `textLow` | `#94A3B8` / `#CBD5E1` | Placeholder text, disabled text, dividers |

### Backgrounds & Gradients
- **Midnight Hero Radial Glow**:
  ```dart
  RadialGradient(
    center: Alignment(0.0, -0.35),
    radius: 1.25,
    colors: [Color(0x550052FF), Color(0xFF071126), Color(0xFF03060F)],
    stops: [0.0, 0.6, 1.0],
  )
  ```
- **Primary Button Gradient**:
  ```dart
  LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0052FF), Color(0xFF0038E0)],
  )
  ```
- **Cyan Highlight Gradient**:
  ```dart
  LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00C2FF), Color(0xFF0088FF)],
  )
  ```

---

## 3. Typography Hierarchy

| Style Name | Font Size | Font Weight | Color | Line Height / Letter Spacing |
| :--- | :--- | :--- | :--- | :--- |
| **Hero Title** | `24px` - `28px` | `FontWeight.w800` | `#0F172A` / `#F8FAFC` | Spacing `-0.5px` |
| **Section Title** | `18px` - `20px` | `FontWeight.w700` | `#0F172A` / `#F8FAFC` | Spacing `-0.3px` |
| **Subheading** | `14px` - `16px` | `FontWeight.w600` | `#334155` / `#94A3B8` | Normal |
| **Body Text** | `13px` - `14px` | `FontWeight.w500` | `#64748B` / `#CBD5E1` | Height `1.4` |
| **Caption / Label** | `11px` - `12px` | `FontWeight.w600` | `#94A3B8` | Spacing `0.3px` |

---

## 4. Component Design Specifications

### 4.1 Input Fields (Semi-Circle Pill Inputs)
- **Container Height**: `52px`
- **Border Radius**: `BorderRadius.circular(26)` (Semi-circle pill shape)
- **Border**: `Border.all(color: Color(0xFF00C2FF), width: 1.5)` (Cyan Highlight)
- **Box Shadow**:
  ```dart
  BoxShadow(
    color: Color(0x1400C2FF),
    blurRadius: 10,
    offset: Offset(0, 4),
  )
  ```
- **Code Template**:
  ```dart
  Widget buildInputField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    bool obscureText = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
        const SizedBox(height: 6),
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xFF00C2FF), width: 1.5),
            boxShadow: const [BoxShadow(color: Color(0x1400C2FF), blurRadius: 10, offset: Offset(0, 4))],
          ),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF0052FF), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: obscureText,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFCBD5E1)),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  ```

---

### 4.2 Primary Action Buttons
- **Height**: `52px`
- **Shape**: `BorderRadius.circular(26)` Pill Button
- **Gradient**: `GlassTheme.primaryButtonGradient`
- **Shadow**: `BoxShadow(color: Color(0x590052FF), blurRadius: 14, offset: Offset(0, 6))`
- **Code Template**:
  ```dart
  Container(
    width: double.infinity,
    height: 52,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(26),
      gradient: const LinearGradient(colors: [Color(0xFF0052FF), Color(0xFF0038E0)]),
      boxShadow: [BoxShadow(color: const Color(0xFF0052FF).withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 6))],
    ),
    child: ElevatedButton(
      onPressed: () {},
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      ),
      child: const Text(
        'Submit Action',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
      ),
    ),
  );
  ```

---

### 4.3 Dialogs & Popup Modals
- **Shape**: `BorderRadius.circular(28)`
- **Border**: `Border.all(color: Color(0xFF00C2FF), width: 1.5)`
- **Header Icon**: `60px x 60px` Circle with `Color(0xFF0052FF).withOpacity(0.1)` fill and `Color(0xFF00C2FF)` border.
- **Close Button**: Top-right corner or bottom action button.

---

### 4.4 Status Badges & Table Cards
- **Table Card States**:
  - **Free**: Emerald Green (`#10B981`)
  - **Occupied**: Amber (`#F59E0B`)
  - **Billed**: Cyan (`#06B6D4`)
  - **Reserved**: Rose Red (`#F43F5E`)
- **Badge Shape**: Semi-circle pill (`BorderRadius.circular(12-16)`)

---

## 5. Motion & Page Route Transitions

### 5.1 Slide-Up Route Transition
- **Duration**: `450ms` forward, `350ms` reverse
- **Curve**: `Curves.easeOutCubic`
- **Usage**: Opening login, modal forms, onboarding, detail screens

```dart
class SlideUpPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  SlideUpPageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 450),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(begin: const Offset(0.0, 1.0), end: Offset.zero).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
              child: child,
            );
          },
        );
}
```

---

## 6. Code Generation Guidelines for New Features

When writing any new screen or feature in Apna POS:
1. **Always import GlassTheme**: `import '../../core/theme/glass_theme.dart';`
2. **Use semi-circle pill inputs & buttons**: Standard height `52px`, `BorderRadius.circular(26)`.
3. **Use cyan highlight borders**: `Color(0xFF00C2FF)` for focus and active states.
4. **Use error banners**: Light red container (`#FEF2F2`) with red border (`#FCA5A5`) and icon.
5. **Obey Clean Architecture**: Keep presentation widgets modular and decoupled from repository logic.
