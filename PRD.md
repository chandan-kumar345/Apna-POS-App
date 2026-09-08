# Product Requirements Document (PRD)

**Product Name:** Apna POS (Point of Sale & Restaurant Management System)  
**Document Version:** 2.0.0  
**Target Platforms:** Android (Mobile / Tablet) & Windows (Desktop / Tablet)  
**Author:** Apna POS Product & Engineering Team  
**Date:** September 2026  
**Status:** Approved / Implemented  

---

## 1. Executive Summary & Vision

Apna POS is a comprehensive, cross-platform Point of Sale and Restaurant Management System engineered to provide restaurant staff, cashiers, and managers with an intuitive, ultra-fast ordering, billing, table management, and kitchen fulfillment workflow. 

This document outlines the product requirements and operational specifications for the major redesign and feature enhancements deployed across **Android** and **Windows** platforms, encompassing:
1. **Unified Navigation & Modern Side Panel**: Harmonized navigation experience across desktop and mobile form factors.
2. **KOT (Kitchen Order Ticket) Processing Engine**: Single-printer architecture with incremental differential printing and non-blocking print dispatch.
3. **Dynamic Table Shift & Auto-Free Lifecycle**: Reliable floor-wise table management with automated state migration and table release.
4. **Platform-Optimized POS Workspace & Mobile Cart UX**: Tailored viewport adaptations, mobile ergonomics, and pixel-perfect layouts.
5. **Orders & History Management**: Responsive order cards, action controls, and real-time status tracking.

---

## 2. Target Personas & Core Use Cases

| Persona | Primary Platform | Key Objectives | Critical Pain Points Solved |
| :--- | :--- | :--- | :--- |
| **Floor Waiter / Server** | Android Smartphone | Fast table-side order taking, instant KOT firing, fast table switching. | No bulky UI, single-tap table shift, responsive cart sheet with clear actions. |
| **Cashier / Counter Operator** | Windows Desktop / All-in-One POS | High-speed billing, item scanning, split payments, receipt printing. | Side panel accessibility, keyboard-friendly POS, real-time table status overview. |
| **Kitchen Master / Chef** | Thermal KOT Printer Output | Clear, sequential, incremental item tickets without duplicate printing. | Only new/modified quantities are printed; zero duplicate orders. |
| **Store Manager** | Windows Desktop / Tablet | Real-time floor occupancy, sales monitoring, shift reports, inventory oversight. | Clear occupancy metrics, floor filtering, fast audit trail. |

---

## 3. Platform-Specific Feature Requirements

### 3.1 Android Mobile Application

```
+-------------------------------------------------------------+
| [Logo] [Restaurant Name Badge]            [Online] [Bell]   | <- Top Header (Deep Navy)
+-------------------------------------------------------------+
|                                                             |
| +-------------------------+ +-----------------------------+ |
| | Category Chips (All...) | | Search & Scan Bar           | |
| +-------------------------+ +-----------------------------+ |
|                                                             |
| +---------------------------------------------------------+ |
| | [ Product Grid - Clean Image / Name / Price ]           | |
| | (Category labels omitted for clutter-free card design)  | |
| +---------------------------------------------------------+ |
|                                                             |
| +---------------------------------------------------------+ |
| | [ Cart Bottom Sheet (Height: 0.78 Viewport) ]           | |
| | Items: Biryani x2, Coke x1 | Subtotal: Rs. 350          | |
| | [ Table: T-1 (Change) ]                                 | |
| | [ KOT Order ]   [ Save & Print ]   [ Pay & Settle ]     | |
| +---------------------------------------------------------+ |
+-------------------------------------------------------------+
```

#### 3.1.1 Header & Sidebar Navigation
* **Requirement 3.1.1.1 (Hamburger Removal):** The legacy 3-line hamburger menu button (`Icons.menu_rounded`) must be **hidden** on Android / mobile viewports to prevent UI clutter and accidental touches.
* **Requirement 3.1.1.2 (Profile/Company Avatar Trigger):** Tapping anywhere on the top header's profile avatar or the semi-curved company name badge must smoothly toggle the navigation drawer.
* **Requirement 3.1.1.3 (Header-Anchored Drawer):** The sliding navigation drawer and its backdrop must open **below the top header** (`top: 58dp`), keeping the deep navy header bar visible.
* **Requirement 3.1.1.4 (Backdrop & Gesture Dismissal):** Tapping the backdrop overlay or swiping left must dismiss the drawer with an animated fade & slide transition.

#### 3.1.2 POS Workspace & Product Cards
* **Requirement 3.1.2.1 (Clutter-Free Product Cards):** Category tag chips inside individual product grid tiles are removed on mobile to maximize title readability and eliminate text truncation.
* **Requirement 3.1.2.2 (Compact Cart Bottom Sheet):** The cart modal height is set to `0.78 * screen height`, providing an ergonomic bottom-sheet experience that keeps background context partially visible.
* **Requirement 3.1.2.3 (Action Buttons Accessibility):** The primary cart action bar (`KOT Order`, `Save & Print`, `Pay & Settle`) must remain fixed and accessible at the bottom of the modal without horizontal overflow.

#### 3.1.3 Change Table Modal & Migration
* **Requirement 3.1.3.1 (Floor-Wise Organization):** The mobile Change Table modal displays floor filter tabs (`All`, `Ground Floor`, `First Floor`, `Rooftop`) with responsive 3-column table cards.
* **Requirement 3.1.3.2 (Table Status Visuals):** Each table card displays its current status badge (`Free` [Green], `Occupied` [Blue], `Running KOT` [Orange], `Billed` [Purple]) and active order total.
* **Requirement 3.1.3.3 (Single-Tap Shift Execution):** Selecting a target table (Table B) when Table A has items in cart or an active KOT executes an immediate table data migration:
  * Table A's cart items, discounts, customer metadata, and KOT orders migrate to Table B.
  * Table A transitions to `Free` (`TableStatus.free`).
  * Table B transitions to `Running KOT` or `Occupied`.
  * The modal dismisses and loads Table B's cart in the POS screen with a confirmation SnackBar.

#### 3.1.4 Orders & History Responsive Layout
* **Requirement 3.1.4.1 (Wrapped Content & Scaled Typography):** Order card text, timestamps, table chips, and price totals utilize responsive typography (`11.5sp` to `13sp`) to prevent pixel overflow on small screens.
* **Requirement 3.1.4.2 (Action Button Layout):** Order action buttons (`View Details`, `Print Receipt`, `Print KOT`) are contained in flexible scrollable rows preventing overflow on narrow devices.
* **Requirement 3.1.4.3 (Dashboard-Style Date Filter on Mobile):** On Android/mobile screens, the bulky horizontal date filter row is removed and replaced by a compact date filter dropdown pill in the top header bar (matching Dashboard design 1:1) supporting `Today`, `Yesterday`, `This Week`, `This Month`, `This Year`, `All Time`, and a custom Date Range modal with FROM/TO pickers and quick presets.

---

### 3.2 Windows Desktop & Tablet Application

```
+----------------------------------------------------------------------------------------------------+
| [Logo] [Company Name Badge]                                           [Online] [Notifications]     |
+----------------------------------------------------------------------------------------------------+
| [ Modern Side Panel ]  | [ POS Menu & Category Grid (65% Width) ]      | [ Sticky Cart Panel 35% ] |
|  - Dashboard           |  - Floor & Category Pills                     |  - Customer Phone / Name  |
|  - POS Register (*)    |  - Search & Barcode Input                     |  - Table: T-4 (Change)    |
|  - Tables Management   |  - Product Media Grid (Images, Food Type Icon)|  - Live Cart Items List   |
|  - Orders History      |    with Instant Add / Quantity Counter        |  - Discount / Promo Code  |
|  - Menu Management     |                                               |  - Bill Summary (Tax/Tip) |
|  - Inventory (👑 Pro)  |                                               |  ------------------------ |
|  - Reports & Analytics |                                               |  [ KOT ] [ Save & Print ] |
|  - CRM & Leads         |                                               |  [ Pay & Settle (Rs 420)] |
|  - Loyalty (👑 Pro)    |                                               |                           |
|  - Settings            |                                               |                           |
|  - [ Profile / Logout] |                                               |                           |
+----------------------------------------------------------------------------------------------------+
```

#### 3.2.1 Redesigned Desktop Side Panel
* **Requirement 3.2.1.1 (Modern Aesthetic):** A continuous white card container with rounded corners (`22px`), 1px border (`#E2E8F0`), and soft drop shadow (`#0A000000`).
* **Requirement 3.2.1.2 (11 Navigation Modules):**
  1. `Dashboard` (Icon: Home, Soft Blue Squircle)
  2. `POS` (Icon: Point of Sale, Soft Royal Blue Squircle with dynamic item count badge)
  3. `Tables` (Icon: Table Restaurant, Soft Green Squircle with occupied count badge)
  4. `Orders` (Icon: Receipt Long, Soft Amber Squircle with pending orders badge)
  5. `Menu Management` (Icon: Restaurant Menu, Soft Purple Squircle)
  6. `Inventory` (Icon: Inventory 2, Soft Cyan Squircle with `👑` Pro badge)
  7. `Reports` (Icon: Bar Chart, Soft Emerald Squircle)
  8. `CRM Leads` (Icon: People, Soft Indigo Squircle)
  9. `Loyalty Program` (Icon: Card Giftcard, Soft Violet Squircle with `👑` Pro badge)
  10. `Campaigns` (Icon: Campaign, Soft Pink Squircle with `👑` Pro badge)
  11. `Settings` (Icon: Settings, Soft Slate Squircle)
* **Requirement 3.2.1.3 (Selected State Indicator):** Active module displays a light blue container (`#EBF2FE`), deep blue text (`#1D4ED8`, weight 900), and a vertical left indicator bar (`width: 4px`, `#1D4ED8`).
* **Requirement 3.2.1.4 (User Account Footer):** Bottom section includes the active user's circular avatar, full name, role badge (`Admin`/`Cashier`), and a dedicated Logout button.

#### 3.2.2 Dual-Pane POS Register & Sticky Cart Panel
* **Requirement 3.2.2.1 (Split Layout):** 65% width allocated to menu catalog, category tabs, search bar, and product tiles; 35% width dedicated to sticky order cart, customer lookup, discounts, and payment controls.
* **Requirement 3.2.2.2 (Desktop Change Table Dialog):** Full modal with search filter, floor tabs, and shift mode confirmation displaying previous and target table states.

---

## 4. Kitchen Order Ticket (KOT) System Requirements

### 4.1 Single KOT Printer Architecture Rule
* **Mandatory Constraint:** The system operates strictly with **ONE** physical KOT printer.
* **Prohibited:** No multi-printer routing, category-based printer splits, department routing (e.g., Kitchen vs. Bar), or printer selection modals during order placement.

### 4.2 Differential (Incremental) Printing Logic
* **Initial Order Placement:**
  * Order contains: `Biryani x 2`, `Coke x 1`.
  * Printed Ticket: `Biryani x 2`, `Coke x 1`.
  * System State: `Biryani.kotQuantity = 2`, `Coke.kotQuantity = 1`.
* **Order Editing / Item Modification:**
  * User adds `1 Coke` (Total: 2) and `1 Butter Naan`.
  * Printed Ticket contains **ONLY**: `Coke x 1` (differential: 2 - 1 = 1), `Butter Naan x 1`.
  * System State: `Biryani.kotQuantity = 2`, `Coke.kotQuantity = 2`, `Butter Naan.kotQuantity = 1`.
* **Order Deletions / Reductions:**
  * Deletions do not print negative tickets unless explicitly configured; active KOT quantity adjusts to reflect retained quantity.

### 4.3 Resilient / Non-Blocking Print Dispatch
* **Requirement 4.3.1:** Order creation and table status progression (`TableStatus.runningKot`) must **never be blocked** by printer connection timeouts, Bluetooth reconnect delays, or out-of-paper warnings.
* **Requirement 4.3.2:** If the printer is offline, the table status immediately updates to `Running KOT` in local state, active order ID is assigned, and a background print retry or user notification is dispatched.

---

## 5. Non-Functional & Performance Requirements

| Category | Requirement | Target Metric |
| :--- | :--- | :--- |
| **Responsiveness** | UI frame rate during drawer transitions, modal bottom sheets, and tab switching. | 60 fps (no frame drops). |
| **Offline Reliability** | POS operations, cart modifications, table shifts, and KOT generation function offline. | 100% functionality with automatic cloud sync upon reconnection. |
| **Print Dispatch Latency**| Time from clicking "KOT Order" to receipt generation & printer payload dispatch. | $< 250\text{ ms}$. |
| **Database Sync** | Table shift migration consistency between local Hive/Prefs and REST API. | Eventual consistency $< 1\text{ s}$ on network availability. |
| **Accessibility & Touch**| Minimum tap target size for mobile buttons and table chips. | $\ge 44 \times 44\text{ dp}$. |

---

## 6. Acceptance Criteria

1. **Android Navigation:**
   - [x] No hamburger menu icon visible on screens $< 900\text{ dp}$.
   - [x] Tapping the profile logo or company badge opens the sidebar.
   - [x] Sidebar top starts below the header bar (`top: 58\text{ dp}`).
2. **Android Cart Screen:**
   - [x] Cart bottom sheet height matches `0.78 * screen height`.
   - [x] `KOT Order`, `Save & Print`, and `Pay & Settle` buttons are fully visible and functional.
   - [x] Product catalog tiles display clean image, title, and price without category badges.
3. **Change Table Shift Flow:**
   - [x] Shifting Table A with cart/KOT items to Table B transfers all items, active orders, and status.
   - [x] Table A is freed (`TableStatus.free`) immediately.
   - [x] Table B becomes `TableStatus.runningKot` or `TableStatus.occupied`.
4. **KOT Printing:**
   - [x] Differential quantity calculation prints only new items/quantities.
   - [x] KOT orders transition table to `runningKot` even if printer is disconnected.
5. **Cross-Platform Compatibility:**
   - [x] Zero compilation errors across Android, Windows, Web, and iOS builds.
