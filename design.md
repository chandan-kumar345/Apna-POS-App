# Apna POS - Comprehensive Design System & Screen Specification (`design.md`)

This document serves as the authoritative UI/UX Design System and Screen Specification for the **Apna POS** application. All screens, components, layout grids, modal flows, and interactive elements generated in this project MUST strictly follow the design tokens, visual architecture, component guidelines, and screen specifications outlined herein.

---

## 1. Design System Overview & Philosophy

### Core Aesthetic Principles
1. **Modern Enterprise & Premium Touch**: A clean, high-performance, dark-mode optimized Point of Sale interface designed for high-volume retail & restaurant environments.
2. **Glassmorphism & Electric Ambient Glows**: Translucent frosted containers (`Color(0x1A0052FF)`) paired with signature electric blue (`#0052FF`) and cyan (`#00C2FF`) glows for depth and focus.
3. **Ergonomic Semi-Circle Pill Controls**: Inputs, action buttons, filter tags, and status pills feature smooth pill borders (`BorderRadius.circular(26)`).
4. **High Contrast Typography & Information Architecture**: High readability under varying lighting conditions, with touch-first target sizes (`>= 48px`).
5. **Fluid Motion & Route Transitions**: Hardware-accelerated slide-up modal transitions (`Curves.easeOutCubic`) and real-time state feedback micro-animations.

---

## 2. Color Palette & Design Tokens

### 2.1 Brand & Accent Colors
| Token Name | Hex Code | Purpose / Usage |
| :--- | :--- | :--- |
| `primaryBlue` | `#0052FF` | Main brand electric blue, primary action buttons, active tab indicators |
| `primaryNavy` | `#0A1435` | Dark surface background, header bars, card containers |
| `primaryCyan` | `#00C2FF` | Active input borders, focused item outlines, highlight glows |
| `accentNeonGreen` | `#10B981` | Success state, free table status, completed orders, online indicator |
| `accentAmber` | `#F59E0B` | Warning state, occupied table status, pending KDS orders, low stock |
| `accentRose` | `#F43F5E` | Error state, reserved table status, cancelled orders, void item |
| `statusBilled` | `#06B6D4` | Billed table status, generated invoice indicator |
| `surfaceDark` | `#071126` | Main background surface for POS dark mode |
| `surfaceCard` | `#0F1E3D` | Card container background with sub-border |

### 2.2 Typography Scale
| Style Name | Size | Weight | Color (Dark/Light) | Purpose / Usage |
| :--- | :--- | :--- | :--- | :--- |
| **Hero Title** | `26px` - `30px` | `FontWeight.w800` | `#F8FAFC` / `#0F172A` | Screen headers, cart total display, key metrics |
| **Section Header**| `18px` - `22px` | `FontWeight.w700` | `#F8FAFC` / `#0F172A` | Category names, table headers, modal titles |
| **Subheading** | `14px` - `16px` | `FontWeight.w600` | `#94A3B8` / `#334155` | Form section titles, table status labels |
| **Body Bold** | `13px` - `15px` | `FontWeight.w700` | `#F8FAFC` / `#0F172A` | Item titles, button text, user names |
| **Body Regular** | `13px` - `14px` | `FontWeight.w500` | `#CBD5E1` / `#64748B` | Descriptions, input text, table details |
| **Caption / Label**| `11px` - `12px` | `FontWeight.w600` | `#94A3B8` / `#64748B` | Timestamps, badge text, sub-labels |

### 2.3 Background Gradients & Glows
- **Hero Background Radial Glow**:
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
- **Cyan Highlight Border Glow**:
  ```dart
  BoxShadow(
    color: Color(0x3300C2FF),
    blurRadius: 12,
    spreadRadius: 1,
    offset: Offset(0, 2),
  )
  ```

---

## 3. Core Reusable Component Library

### 3.1 Semi-Circle Pill Input (`PillTextField`)
- **Height**: `52px` | **Border Radius**: `26px`
- **Border**: `1.5px` Cyan (`#00C2FF`) on focus, `#1E293B` default.
- **Icon Accent**: `#0052FF` lead icon.

```dart
Widget buildPillInput({
  required String label,
  required String hint,
  required IconData icon,
  required TextEditingController controller,
  bool obscureText = false,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
      const SizedBox(height: 6),
      Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1E3D),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFF00C2FF), width: 1.5),
          boxShadow: const [BoxShadow(color: Color(0x1400C2FF), blurRadius: 10, offset: Offset(0, 4))],
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF0052FF), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: controller,
                obscureText: obscureText,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  border: InputBorder.none,
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

### 3.2 Gradient Action Pill Button (`PillButton`)
- **Height**: `52px` | **Border Radius**: `26px`
- **Fill**: Gradient `#0052FF` to `#0038E0`
- **Glow Shadow**: `BoxShadow(color: Color(0x590052FF), blurRadius: 14, offset: Offset(0, 6))`

---

## 4. Separate Screen Specifications & Visual Anatomy

This section defines the exact UI structure, visual wireframe layout, components, and user flows for every screen in the **Apna POS** application.

---

### Screen 1: Welcome & Onboarding Walkthrough (`OnboardingScreen`)
- **Purpose**: First screen presented to new users, introducing Apna POS core features (Speed Billing, Live KDS, Analytics, Multi-Device Sync).
- **Layout Architecture**:
  - **Header**: Top Bar with logo, language selector, and "Skip" action button.
  - **Center**: PageView displaying high-resolution illustration cards with animated indicator dots (`#0052FF`).
  - **Footer**: Sticky bottom navigation container featuring "Get Started" primary pill button and "Sign In" link.
- **Key Visual Elements**:
  - Full-screen Radial Glow background (`#071126`).
  - Smooth page swipe indicator pills (`Active: 24px width, Inactive: 8px width`).
  - CTA Button: "Get Started" gradient pill button with right arrow icon.

---

### Screen 2: Store Login & PIN Entry (`LoginScreen` / `PinEntryScreen`)
- **Purpose**: Authenticates store staff using Email/Password or quick 4-Digit Security PIN for rapid cashier shifts.
- **Layout Architecture**:
  - **Top Banner**: Brand header with glowing POS logo and Store Selector dropdown.
  - **Toggle View**: Tab selector switching between **"Email Login"** and **"Quick Staff PIN"**.
  - **Email Form**:
    - Semi-Circle Pill Email Field
    - Semi-Circle Pill Password Field (with eye toggle icon)
    - "Forgot Password?" link right-aligned
  - **PIN Entry View**:
    - Avatar & Staff Name Header ("Cashier Shift: Rahul S.")
    - 4 Circular PIN Indicator Dots (`#00C2FF` filled on entry)
    - 3x4 On-Screen Numeric Keypad with tactile glow feedback buttons (`64px` height).
  - **Footer**: "Register New Business" link button.

---

### Screen 3: Business Setup & Registration Wizard (`RegistrationWizardScreen`)
- **Purpose**: Multi-step setup wizard for newly registered businesses to configure store name, tax settings, currency, and business type (Restaurant, QSR, Retail, Grocery).
- **Layout Architecture**:
  - **Top Header**: Step Progress Bar (Step 1: Store Info ➔ Step 2: Tax & Currency ➔ Step 3: Counter Setup).
  - **Step 1 Container**: Store Name input, Business Category Grid Cards (Dine-In, Takeaway, Retail), Phone Number input with OTP verify badge.
  - **Step 2 Container**: GSTIN input, Tax Percentage slider (`0% - 28%`), Currency Picker (₹ INR default), Receipt Header/Footer text.
  - **Step 3 Container**: Terminal Name ("POS Counter 1"), Default Printer Picker, Table Count input.
  - **Navigation Bar**: Bottom sticky bar with "Back" outline pill button and "Complete Setup" gradient pill button.

---

### Screen 4: Owner / Manager Overview Dashboard (`DashboardScreen`)
- **Purpose**: Real-time business overview screen showing live sales stats, order counts, active tables, top items, and system health.
- **Layout Architecture**:
  - **Top Navigation Bar**: Store selector, Real-time Clock, Quick Action Bar (New Sale, Add Expense, KDS View, Lock Screen), User Profile Badge.
  - **Metrics Summary Cards (4-Grid)**:
    1. **Today's Revenue**: `₹48,250.00` (+14.2% badge green)
    2. **Total Orders**: `184 Orders` (12 pending)
    3. **Active Tables**: `14 / 20 Occupied` (70% capacity pill)
    4. **Average Order Value**: `₹262.00`
  - **Middle Charts & Split View**:
    - **Left (60% width)**: Hourly Sales Bar Chart with cyan gradient bars and peak-hour indicator.
    - **Right (40% width)**: Live Activity Stream showing latest orders, payment types (UPI, Cash, Card), and status badges.
  - **Bottom Row**: Top Selling Items List & Low Stock Alerts Card.

---

### Screen 5: POS Billing Terminal (`PosTerminalScreen` - Cashier Main View)
- **Purpose**: Core high-speed point-of-sale billing screen for cashiers to browse items, apply discounts, select table/order type, and generate bills.
- **Layout Architecture**:
  - **Header Bar**: Shift Status, Search Bar (`Ctrl+F`), Order Type Toggle Pills (**Dine-In**, **Takeaway**, **Delivery**), Customer Selection Pill ("+ Add Customer").
  - **Left Section (65% width) - Item Catalog**:
    - **Category Bar**: Horizontal scrollable pill tags (All Items, Starters, Main Course, Beverages, Desserts, Combos).
    - **Item Grid**: Responsive cards with item image thumbnail, title, price tag (`₹180`), stock badge, and quick "+" tap button.
  - **Right Section (35% width) - Active Cart & Billing Panel**:
    - **Cart Header**: Selected Table / Order #ID, Clear Cart button.
    - **Item List**: Scrollable list with title, quantity increment/decrement (`- 1 +`), price, and modifier sub-labels.
    - **Summary Calculation**:
      - Subtotal: `₹540.00`
      - GST (5%): `₹27.00`
      - Discount Pill: `- ₹50.00`
      - **Grand Total**: `₹517.00` (Large Hero font `24px`)
    - **Action Buttons**: "Hold Order", "KOT Print", and "PAY NOW" (`₹517.00`) full-width gradient button (`#0052FF`).

---

### Screen 6: Floor Plan & Table Management (`TableManagementScreen`)
- **Purpose**: Visual table layout management screen for restaurants to view table status, allocate seating, generate bills, and transfer/merge tables.
- **Layout Architecture**:
  - **Top Action Bar**: Floor Zone Selector (Ground Floor, First Floor, Rooftop, AC Hall), Filter Status Pills (All, Free, Occupied, Billed, Reserved), "Add Table" Button.
  - **Main Canvas Grid (Interactive Floor Layout)**:
    - **Free Tables**: Emerald Green border (`#10B981`), white background, "Table 04 (4 Seats)" label, "FREE" pill.
    - **Occupied Tables**: Amber glowing border (`#F59E0B`), elapsed timer ("42 mins"), current order value (`₹1,240`), items count.
    - **Billed Tables**: Cyan glowing border (`#06B6D4`), "BILLED - Awaiting Payment" badge, print invoice icon.
    - **Reserved Tables**: Rose Red border (`#F43F5E`), customer name & reservation time.
  - **Table Tap Context Drawer**: Bottom modal displaying Order Summary, KOT Items, "Transfer Table", "Merge Table", "Add Items", and "Settle Bill".

---

### Screen 7: Kitchen Display System (`KdsScreen` - Live KDS Board)
- **Purpose**: Touch-screen kitchen order management display for chefs to view live incoming KOTs, track prep timers, and mark items as ready.
- **Layout Architecture**:
  - **Top Status Bar**: Live KDS Clock, Filter by Station (Main Kitchen, Bar, Grill, Bakery), Order Status Counters (New: 4, Cooking: 3, Ready: 2), Sound Alert Toggle.
  - **Multi-Column Order Grid**:
    - **KOT Card**:
      - Header: Order #ID (`KOT #108`), Table Number (`T-06`), Order Type (`Dine-In`), Live Prep Timer (`08:45 min` - turns red if > 15 mins).
      - Item List: Checkbox list with quantity highlight (`2x Butter Chicken`, `4x Naan`, `Special Note: Less Spicy`).
      - Footer Action Buttons: "Start Cooking" (Yellow) ➔ "Mark Ready" (Green) ➔ "Serve".

---

### Screen 8: Live Orders & Order History (`OrdersScreen`)
- **Purpose**: Searchable and filterable master order repository to view active orders, search past receipts, process refunds, and reprint bills.
- **Layout Architecture**:
  - **Top Controls**: Date Range Picker (Today, Yesterday, This Week, Custom), Search Bar (Search Order ID, Customer Phone, Receipt #), Status Filters.
  - **Orders Table / List View**:
    - Columns: Order ID, Date & Time, Customer Info, Order Type, Items Count, Payment Method (UPI/Cash/Card), Total Amount, Status Badge, Actions.
  - **Order Detail Drawer**: Side panel showing full digital receipt breakdown, tax split, payment breakdown, audit log, "Reprint Receipt", and "Void/Refund Order".

---

### Screen 9: Inventory & Stock Management (`InventoryScreen`)
- **Purpose**: Manage raw materials, stock levels, low-stock alerts, recipe batch management, and purchase order tracking.
- **Layout Architecture**:
  - **Header Stat Cards**: Total Items, Low Stock Warnings, Out of Stock, Total Inventory Valuation.
  - **Action Bar**: Search Material, Category Filter, "Stock In", "Stock Adjustment", "Add New Material".
  - **Stock Data Table**:
    - Columns: SKU, Item Name, Category, Current Level, Min Reorder Level, Unit (Kg, Ltr, Pcs), Last Updated, Status Badge (`Low Stock` Amber alert).
  - **Quick Stock Update Modal**: Tap item to increment stock, record vendor reference, and update cost price.

---

### Screen 10: Menu & Category Management (`MenuManagementScreen`)
- **Purpose**: Configure menu items, price rules, item availability toggles, modifier groups, and category sorting.
- **Layout Architecture**:
  - **Left Column (30%) - Categories**: Draggable category list (Appetizers, Mains, Drinks) with item count badge and "+ Category" button.
  - **Right Column (70%) - Menu Items**:
    - Search & Filter by Veg/Non-Veg/EGG tags.
    - Menu Item Cards: Thumbnail image, Item Name, Price (`₹220`), Food Type Icon (Green dot for Veg, Red triangle for Non-Veg), Online Availability Toggle (ON/OFF switch), Modifier count.
  - **Add/Edit Item Sheet**: Form modal with Name, Price, Tax Rate, SKU/Barcode, Kitchen Station mapping, Modifier Attachment (e.g., Size, Extra Cheese).

---

### Screen 11: Sales Reports & Financial Analytics (`ReportsScreen`)
- **Purpose**: Deep financial insight reports including Daily Sales, Category-wise Breakdown, Tax/GST Summary, Payment Method Split, and Staff Sales Performance.
- **Layout Architecture**:
  - **Report Tabs**: Revenue Summary, Product Performance, GST Tax Report, Payment Breakdown, Discount Audit.
  - **Controls Bar**: Date Filter, Export PDF / Excel button, Print Summary button.
  - **Visual Widgets**:
    - Large Financial Summary Cards (Gross Sales, Discounts, Taxes, Net Sales).
    - Payment Split Pie Chart (UPI 62%, Card 24%, Cash 14%).
    - Category Sales Bar Chart.
    - Exportable GSTR-1 Tax Table Breakdown.

---

### Screen 12: Staff & Access Control (`UserManagementScreen`)
- **Purpose**: Manage store employees, assign roles (Owner, Manager, Cashier, Waiter, Kitchen Staff), configure 4-digit PINs, and set permissions.
- **Layout Architecture**:
  - **Header Bar**: Active Staff Count, Shift Status, "Add New Employee" Button.
  - **Staff Cards Grid**:
    - Avatar thumbnail with online status indicator dot.
    - Name & Designation ("Rahul Sharma - Senior Cashier").
    - Shift Time ("09:00 AM - 06:00 PM").
    - Quick Actions: "Edit Access", "Reset PIN", "Deactivate".
  - **Role & Permission Matrix Modal**: Checkbox matrix controlling access rights (e.g., Can Void Order?, Can View Reports?, Can Apply Discount?).

---

### Screen 13: Settings & Hardware Integration (`SettingsScreen`)
- **Purpose**: Hardware setup (Thermal Printers, Barcode Scanners, Cash Drawers, Customer Display), store profile, receipt format, and cloud sync settings.
- **Layout Architecture**:
  - **Left Navigation Drawer**:
    1. **General Store Settings** (Logo, Address, Tax Number)
    2. **Printer Setup** (Thermal Receipt Printers, KOT Printers, Bluetooth/USB/LAN Discovery)
    3. **Receipt Customizer** (Header Text, Footer Message, Show Tax Breakdown toggle)
    4. **Payment Gateways** (UPI QR Code setup, POS Terminal integration)
    5. **Backup & Cloud Sync** (Offline DB Status, Sync Now button)
  - **Main Details Panel**: Dynamic settings view based on active tab with test print triggers (`"Test Print Receipt"`).

---

## 5. Modal & Overlay Specifications

All popups and dialog overlays in Apna POS follow standard glassmorphism containers with cyan borders.

### 5.1 Payment Processing Overlay (`PaymentModal`)
- **Header**: Payable Amount `₹517.00` (Hero Font).
- **Payment Method Tabs**: **UPI Quick QR**, **Cash**, **Card / POS Machine**, **Split Payment**.
- **UPI Tab View**: Auto-generated dynamic UPI QR Code with store UPI ID, copy link button, and auto-detect payment listener.
- **Cash Tab View**: Quick Tendered Cash Buttons (`₹500`, `₹1000`, `Exact`), Change Due Display (`₹83.00`).
- **Complete Transaction Button**: Full-width `#10B981` Green Gradient Pill Button ("CONFIRM & PRINT RECEIPT").

### 5.2 Split Bill Modal (`SplitBillModal`)
- **Split Modes**: **Split Equally** (2, 3, 4 ways) or **Split by Items**.
- **Item Assignment Columns**: Side-by-side column cards for Person 1, Person 2 with drag-and-drop item movement.
- **Action**: "Generate Separate Bills" pill button.

---

## 6. Motion, Route Transitions & Accessibility

### 6.1 Slide-Up Route Transition Code Specification
```dart
class SlideUpPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  SlideUpPageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 450),
          reverseTransitionDuration: const Duration(milliseconds: 350),
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

### 6.2 Ergonomic Touch Targets & Contrast Rules
- **Minimum Touch Target**: `48px x 48px` for all interactive buttons and grid items.
- **Visual Haptic Feedback**: Scale compression (`0.96x`) and subtle glow expansion on button tap.
- **Contrast Compliance**: Minimum `4.5:1` contrast ratio for all text elements against midnight navy background.

---

## 7. Code Generation Guidelines for Engineers

When generating code for any feature or screen in Apna POS:
1. **Always import GlassTheme**: `import '../../core/theme/glass_theme.dart';`
2. **Obey Semi-Circle Pill Controls**: Inputs, search fields, and buttons must use `BorderRadius.circular(26)`.
3. **Use Cyan Highlight Outlines**: `Color(0xFF00C2FF)` for focused states and key highlights.
4. **Follow Clean Architecture**: Keep presentation widgets decoupled from business logic and data providers.
5. **Enforce Screen Anatomy**: Adhere strictly to the layout structure defined in Section 4 for each respective screen.
