# Product Requirements Document (PRD)

**Product Name:** Apna POS (Point of Sale & Restaurant Management System)  
**Document Version:** 2.1.0  
**Target Platforms:** Android (Mobile / Tablet) & Windows (Desktop / Tablet)  
**Author:** Apna POS Product & Engineering Team  
**Date:** September 2026  
**Status:** Approved / Implemented  

---

## 1. Executive Summary & Vision

Apna POS is a comprehensive, cross-platform Point of Sale and Restaurant Management System engineered to provide restaurant staff, cashiers, and managers with an intuitive, ultra-fast ordering, billing, table management, and kitchen fulfillment workflow. 

This document outlines the product requirements and operational specifications for the major redesign and feature enhancements deployed across **Android** and **Windows** platforms, encompassing:
1. **Real-Time Table Status Synchronization & POS Lifecycle**: Central authoritative table status model synchronized in real-time across all connected devices via WebSockets and cloud DB.
2. **Unified Navigation & Modern Side Panel**: Harmonized navigation experience across desktop and mobile form factors.
3. **KOT (Kitchen Order Ticket) Processing Engine**: Single-printer architecture with incremental differential printing and non-blocking print dispatch.
4. **Dynamic Table Shift & Auto-Free Lifecycle**: Reliable floor-wise table management with automated state migration and table release.
5. **Redesigned Payment Method Screen**: Compact, responsive wrapped payment modal with frosted backdrop blur and 4 pastel payment methods.
6. **Platform-Optimized POS Workspace & View Modes**: Flexible grid cards with/without images, centered typography in compact view, mobile cart bottom sheet, and desktop dual-pane.
7. **Orders & History Management**: Responsive order cards, action controls, and real-time status tracking.

---

## 2. Target Personas & Core Use Cases

| Persona | Primary Platform | Key Objectives | Critical Pain Points Solved |
| :--- | :--- | :--- | :--- |
| **Floor Waiter / Server** | Android Smartphone | Fast table-side order taking, instant KOT firing, fast table switching. | No bulky UI, single-tap table shift, responsive cart sheet with clear actions. |
| **Cashier / Counter Operator** | Windows Desktop / All-in-One POS | High-speed billing, item scanning, split payments, receipt printing. | Side panel accessibility, keyboard-friendly POS, real-time table status overview. |
| **Kitchen Master / Chef** | Thermal KOT Printer Output | Clear, sequential, incremental item tickets without duplicate printing. | Only new/modified quantities are printed; zero duplicate orders. |
| **Store Manager** | Windows Desktop / Tablet | Real-time floor occupancy, sales monitoring, shift reports, inventory oversight. | Clear occupancy metrics, floor filtering, fast audit trail. |

---

## 3. Real-Time Table Status Synchronization & POS Lifecycle

### 3.1 Central Source of Truth & Real-Time Architecture
* **Requirement 3.1.1 (Central Truth):** The backend database is the single central authoritative source of truth for table occupancy and order state. Connected devices do NOT maintain isolated, un-synced table states.
* **Requirement 3.1.2 (Instant Multi-Device Sync):** Any table state change made on Device A (e.g., Table 5 ➔ Occupied) immediately broadcasts via Socket.IO room to Device B, Device C, and Device D without requiring manual pull-to-refresh or page reloads.

### 3.2 Table Status Lifecycle Rules
```
                 +----------------------------------------------------+
                 |                                                    |
                 v                                                    |
         +---------------+    User Adds Items      +----------------+ |
         |     FREE      | ----------------------> |    OCCUPIED    | |
         | (Emerald #10) |                         |  (Navy #051C)  | |
         +---------------+                         +----------------+ |
                 ^                                         |          |
                 |                                         |          |
                 | Settle Bill / Clear Cart                | Print KOT|
                 |                                         v          |
                 |                                 +----------------+ |
                 +-------------------------------- |   KOT RUNNING  | |
                                                   |  (Vivid #EF44) | |
                                                   +----------------+ |
                                                           |          |
                                                           +----------+
```

1. **State: `Free` (Available - `#10B981` Emerald Green)**
   * **Definition:** Table has **zero products** in its draft cart and **no active pending/preparing KOT orders**.
   * **Visual Indicator:** Emerald Green border/badge with label `"Free"`.
   * **Card Content:** Displays `"No Order"` and `₹0`.
   * **Action Icon:** Emerald Green `+` / Add-to-cart button.
   * **Transition Trigger:** Automatically returns to `Free` when:
     - An active order is completed and settled via Payment Modal.
     - All items are removed from the cart.
     - The cart is cleared/voided via Manager PIN.

2. **State: `Occupied` (Seated & Ordering - `#051C48` Deep Navy Blue)**
   * **Definition:** A table is selected and **1 or more products are added to the cart**, but KOT has **NOT** yet been sent to the kitchen (draft state).
   * **Visual Indicator:** Deep Navy Blue border/badge with label `"Occupied"`.
   * **Card Content:** Displays live cart subtotal/total (e.g. `₹420`).
   * **Action Icon:** Visibility eye icon (`Icons.visibility_outlined`) allowing staff to view or modify draft cart items.
   * **Transition Trigger:**
     - First product added to an empty/free table cart ➔ transitions to `Occupied`.
     - Reducing cart items back to 0 ➔ table reverts to `Free`.

3. **State: `KOT Running` (In Kitchen Prep - `#EF4444` Vivid Red)**
   * **Definition:** Staff clicks **"Print KOT"** or **"Save & Print"**; an active kitchen order is generated (`OrderStatus.preparing`).
   * **Visual Indicator:** Vivid Red border/badge with label `"KOT Running"`.
   * **Card Content:** Displays confirmed order total (e.g. `₹850`).
   * **Dropdown Lock:** Status dropdown on table card is disabled/locked to prevent accidental cancellation without Manager PIN.
   * **Transition Trigger:**
     - Clicking "Print KOT" in POS or KOT Dialog ➔ immediately transitions to `KOT Running`.
     - Completing bill settlement ➔ transitions to `Free`.
     - Voiding KOT via Manager PIN ➔ transitions to `Free`.

4. **State: `Reserved` (Advance Booking - `#8B5CF6` Purple)**
   * **Definition:** Table reserved in advance by management.

---

## 4. Payment Method Screen Redesign

```
+-------------------------------------------------------------+
| [Backdrop: Frosted Blur sigma 6.0]                          |
|                                                             |
|   +-----------------------------------------------------+   |
|   | Payment Method                            [Close X] |   |
|   +-----------------------------------------------------+   |
|   | Total Payable: Rs. 540.00                           |   |
|   | Bill: #20260912-1430-T2 | Table: T-2                |   |
|   +-----------------------------------------------------+   |
|   |                                                     |   |
|   |  +--------------------+    +---------------------+  |   |
|   |  | [Cash Icon]        |    | [UPI QR Icon]       |  |   |
|   |  | Cash Payment       |    | UPI Dynamic / QR    |  |   |
|   |  | (Soft Pastel Blue) |    | (Soft Pastel Green) |  |   |
|   |  +--------------------+    +---------------------+  |   |
|   |  | [Card Icon]        |    | [Split Icon]        |  |   |
|   |  | Card (Debit/Credit)|    | Split Payment       |  |   |
|   |  | (Soft Pastel Purple|    | (Soft Pastel Orange)|  |   |
|   |  +--------------------+    +---------------------+  |   |
|   |                                                     |   |
|   | [ Security PIN / Non-Chargeable (NC) Toggle ]       |   |
|   +-----------------------------------------------------+   |
+-------------------------------------------------------------+
```

### 4.1 Visual & Ergonomic Specifications
* **Requirement 4.1.1 (Compact & Wrapped Layout):** The payment modal is sized compactly (`maxWidth: 480dp`) with auto-wrapping grid cards, rendering seamlessly across both Android mobile screens and Windows desktop monitors.
* **Requirement 4.1.2 (Frosted Glass Backdrop Blur):** When opened, the background is softly blurred using `BackdropFilter` with `sigmaX: 6.0, sigmaY: 6.0` and semi-transparent overlay (`Color(0x66000000)`), giving a premium, focused view.
* **Requirement 4.1.3 (4 Pastel Quick Payment Cards):**
  1. **Cash Payment Card:** Pastel Blue container (`#EBF3FE`), Navy border (`#2563EB`), Cash icon.
  2. **UPI Payment Card:** Pastel Green container (`#EBF8F2`), Green border (`#059669`), QR code icon.
  3. **Card Payment Card:** Pastel Purple container (`#F5EBFB`), Purple border (`#7C3AED`), Credit card icon.
  4. **Split Payment Card:** Pastel Orange container (`#FEF3EB`), Amber border (`#D97706`), Call-split icon.
* **Requirement 4.1.4 (Instant Settlement & Table Freeing):** Selecting a payment method executes settlement, logs the final print log, clears table cart, and marks the table `Free` across all devices.

---

## 5. POS Product View Modes (With / Without Images)

### 5.1 "Without Images" Compact & Wrapped View Mode
* **Requirement 5.1.1 (Android Wrapped Product Boxes):** On Android / mobile form factors, product boxes are rendered inside a responsive `Wrap` container (`SingleChildScrollView` + `Wrap(spacing: 8, runSpacing: 8)`). Item width dynamically adapts to screen width (2 columns on mobile phones, 3 columns on phablets `≥ 460px`, and 4 columns on tablets `≥ 680px`), allowing boxes to wrap naturally without overflowing or cramped letter spacing.
* **Requirement 5.1.2 (Decreased Box Height):** Product box heights are reduced to `64px` on mobile and `72px` on desktop, maximizing visible catalog items.
* **Requirement 5.1.3 (Centered Typography):** The product name and price tag are vertically and horizontally centered with bold, high-contrast typography (`#0F172A`), food type dot, and clean text truncation.
* **Requirement 5.1.4 (Integrated Top Badges):** Displays food type dot on top-left, and cart quantity / variant count / discount percentage on top-right.

---

## 6. Platform-Specific Feature Requirements

### 6.1 Android Mobile Application

#### 6.1.1 Header & Sidebar Navigation
* **Requirement 6.1.1.1 (Hamburger Removal):** The legacy 3-line hamburger menu button (`Icons.menu_rounded`) is hidden on mobile viewports.
* **Requirement 6.1.1.2 (Profile/Company Avatar Trigger):** Tapping the top header's profile avatar or company badge smoothly opens the navigation drawer.
* **Requirement 6.1.1.3 (Header-Anchored Drawer):** The sliding navigation drawer opens below the top header (`top: 58dp`).

#### 6.1.2 Mobile Cart Bottom Sheet
* **Requirement 6.1.2.1 (Ergonomic Viewport):** Cart bottom sheet height set to `0.78 * screen height`.
* **Requirement 6.1.2.2 (Action Buttons Accessibility):** Fixed action buttons (`KOT`, `Save & Print`, `Settle`) at the bottom of the modal.

### 6.2 Windows Desktop Application

#### 6.2.1 Redesigned Desktop Side Panel
* Continuous white card container with rounded corners (`22px`), 1px border (`#E2E8F0`), soft drop shadow, and 11 navigation modules.

#### 6.2.2 Dual-Pane POS Register & Sticky Cart Panel
* 65% width allocated to menu catalog and search; 35% width dedicated to sticky order cart, customer lookup, discounts, and payment controls.

---

## 7. Kitchen Order Ticket (KOT) System Requirements

### 7.1 Single KOT Printer Architecture Rule
* The system operates strictly with **ONE** physical KOT printer. No multi-printer routing or printer selection modals.

### 7.2 Differential (Incremental) Printing Logic
* System calculates differential quantity: $\Delta Q(i) = \max(0, Q_{\text{total}}(i) - Q_{\text{printed}}(i))$.
* Only newly added or incremented items are printed; previously sent items are omitted.

### 7.3 Non-Blocking Print Dispatch
* Order creation and table status progression (`TableStatus.runningKot`) are never blocked by printer connectivity delays or offline state.

---

## 8. Non-Functional & Performance Requirements

| Category | Requirement | Target Metric |
| :--- | :--- | :--- |
| **Real-Time Sync Latency** | WebSocket table status broadcast across devices | $< 100\text{ ms}$ |
| **Responsiveness** | UI frame rate during drawer transitions, modal bottom sheets, and tab switching | 60 fps (no frame drops) |
| **Offline Reliability** | POS operations, cart modifications, table shifts, and KOT generation function offline | 100% functionality with automatic cloud sync upon reconnection |
| **Print Dispatch Latency**| Time from clicking "KOT Order" to receipt generation & printer payload dispatch | $< 250\text{ ms}$ |
| **Database Sync** | Table shift migration consistency between local Hive/Prefs and REST API | Eventual consistency $< 1\text{ s}$ on network availability |

---

## 9. Acceptance Criteria

1. **Table Status Lifecycle:**
   - [x] Adding products to a free table sets status to `Occupied` (`TableStatus.occupied`).
   - [x] Clicking "Print KOT" sets table status to `KOT Running` (`TableStatus.runningKot`).
   - [x] When table cart is emptied or bill is settled, table status returns to `Free` (`TableStatus.free`).
   - [x] Status changes sync across all connected devices in real time without refreshing.
2. **Payment Method Modal:**
   - [x] Responsive wrapped layout for mobile and desktop screens.
   - [x] Frosted backdrop blur (`sigmaX: 6, sigmaY: 6`).
   - [x] 4 Pastel quick payment cards (Cash, UPI, Card, Split).
3. **POS Product Cards (Without Images View):**
   - [x] Decreased box height with centered item name and price.
4. **Change Table Shift Flow:**
   - [x] Shifting Table A with cart/KOT items to Table B transfers all items, active orders, and status.
   - [x] Table A is freed immediately; Table B becomes `runningKot` or `occupied`.
5. **Cross-Platform Compatibility:**
   - [x] 100% test pass rate across unit, widget, and integration tests.

