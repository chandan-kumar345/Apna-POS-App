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

---

## 10. Sales & Order Parity, Lifecycle & Counting Rules (Permanent Standard)

### 10.1 Zero-Drop Order Inclusion Rule
* **Requirement 10.1.1 (Immutable Transaction Record):** Every order created via POS (Dine-In, Takeaway, Delivery, Quick Billing, Save & Print, KOT) represents an active, valid business transaction for that business date unless explicitly cancelled (`OrderStatus.cancelled` or `status === 'cancelled'`).
* **Requirement 10.1.2 (Total Order Count Parity):** Total Order count displayed on Dashboard metrics, Sales Reports, and Order History must count **ALL non-cancelled placed orders** (`pending`, `preparing`, `ready`, `completed`, `paid`). Active or in-kitchen orders must NEVER be hidden or excluded from order counts.
* **Requirement 10.1.3 (Revenue Separation):** Settled Revenue aggregates all completed and paid orders, while gross placed value and active in-kitchen order counts remain visible to provide a 100% complete picture of store operations.

### 10.2 Identity-Only Deduplication Standard
* **Requirement 10.2.1 (Unique ID & Order Number Deduplication):** Orders must be deduplicated strictly and exclusively by non-empty database `id` or unique `orderNumber`.
* **Requirement 10.2.2 (Prohibition of Heuristic Proximity Collapse):** The system must NEVER collapse or discard distinct orders based on timestamp proximity, matching table numbers, or matching total amounts. Separate legitimate orders placed in rapid succession must all be preserved.

### 10.3 Timezone-Aware Local Date Range Boundaries
* **Requirement 10.3.1 (Local Start and End Boundaries):** All date filters (`Today`, `Yesterday`, `This Week`, `This Month`, `This Year`, `Custom Date Range`) must calculate exact local timezone boundaries (`00:00:00.000` to `23:59:59.999` in store local time, e.g. IST / UTC+5:30).
* **Requirement 10.3.2 (Timezone-Safe Cloud Querying):** Date range filters passed to MongoDB or backend APIs must convert local start-of-day and end-of-day to UTC ISO strings, ensuring midnight date rollovers do not bleed or truncate orders across dates.
* **Requirement 10.3.3 (Order Model DateTime Conversion):** `OrderModel.createdDateTime` must always parse ISO strings to local system timezone (`.toLocal()`) before evaluating date ranges.

### 10.4 Orders Management & History Screen Visibility
* **Requirement 10.4.1 (Omnipresent 'All' Filter):** The Orders & History screen must provide an `'All'` option for Order Types (`All`, `DineIn`, `TakeAway`, `Delivery`) and an `'All'` pill for Statuses (`All`, `Pending`, `Preparing`, `Ready`, `Completed`, `Cancelled`).
* **Requirement 10.4.2 (Default Overview Mode):** The Orders screen defaults to `'All'` Order Types and `'All'` Statuses to immediately display all orders placed on the selected date without requiring manual tab switches.

---

## 11. CRM Leads & Customer Metrics Standards

### 11.1 Dynamic Customer Aggregation
* **Requirement 11.1.1 (Visit and Order Count Accuracy):** Customer `visitCount`, `totalOrders`, and `totalSpent` must calculate from real transaction history and store databases.
* **Requirement 11.1.2 (Normalized Source):** In the CRM customer overview and orders tab, all orders processed directly through the POS terminal (Dine In, Takeaway, Counter Delivery) display their source channel as `"POS"` rather than internal order type tags.

---

## 12. Staff Management, Dynamic Permissions & Staff Settings Architecture

### 12.1 Local Storage & Dual-Layer Persistence
* **Requirement 12.1.1 (User-Scoped Persistence):** All newly created, updated, and deleted staff members persist immediately into `SharedPreferences` under active user-scoped storage (`staff_list_${userId}`) with fallback to guest storage.
* **Requirement 12.1.2 (Offline & Cloud Resilience):** If the cloud backend is offline or returns an empty array, `StaffService.fetchStaff()` falls back to locally persisted records to ensure staff members are never hidden or wiped out.
* **Requirement 12.1.3 (Auto-Load on Startup):** Staff data is automatically loaded during app startup (`init()`) and whenever the active authenticated user switches.

### 12.2 Staff Settings & Profile Editing Screen
* **Requirement 12.2.1 (Row Tap Navigation):** Tapping anywhere on a staff row or card in `StaffManagementScreen` directly navigates to `StaffSettingsScreen` for comprehensive profile and permission editing.
* **Requirement 12.2.2 (Top Bar & Hero Card):** Displays back navigation, screen title, "+ Save Changes" CTA, user avatar with photo upload badge, active status pill, role pill, EMP ID, email, phone, and reporting supervisor.
* **Requirement 12.2.3 (5-Tab Structure):**
  - **Tab 0: Profile:** Personal Information, Work Information, Preferences, Login & PIN modal, Account Status, and Delete Staff card.
  - **Tab 1: Permissions:** Dynamic Permissions Matrix across POS & Orders, Products & Menu, Inventory, Customers & CRM, Reports & Analytics, Settings & Business, and System & Others, with granular switches and quick Role Presets (Admin, Manager, Cashier, Waiter, Chef).
  - **Tab 2: Work Settings:** Shift assignment, salary compensation, joining date picker, and internal notes.
  - **Tab 3: Security:** 4-digit PIN access manager, force password change switch, and welcome email credentials switch.
  - **Tab 4: Activity:** Live staff audit trail and event activity timeline.

