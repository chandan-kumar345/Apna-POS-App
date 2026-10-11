# Apna POS — Restaurant Inventory Management System
## Complete User & Operational Manual

> **Module Version:** 2.0 (Dynamic Backend & Neumorphic Design)  
> **Applicable Platforms:** Mobile (Android / iOS), Windows Desktop EXE, and Web  
> **Target Audience:** Restaurant Owners, Cashiers, Kitchen Managers, Store In-Charges  

---

## 1. Executive Summary & Core Concept

The **Apna POS Inventory Management System** is a complete, enterprise-grade restaurant inventory and recipe management engine. It eliminates manual ingredient calculations, minimizes kitchen food wastage, protects profit margins, and prevents ingredient theft or shrinkage.

The system is engineered around **Two Operational Modes**:

```
                       ┌────────────────────────────────────────────────────────┐
                       │          APNA POS INVENTORY SYSTEM                     │
                       └────────────────────────────────────────────────────────┘
                                   │                                │
                 Mode A: Automatic Recipe Deduction        Mode B: Manual Stock Management
                 ─────────────────────────────────        ───────────────────────────────
                 • Connects POS Menu Items to Recipes     • For standalone / packaged items
                 • Auto-deducts grams/ml on each sale     • Direct stock in / stock out entries
                 • Calculates real-time Food Cost %       • Periodic physical shelf audits
                 • Zero manual effort during billing      • Full immutable transaction ledger
```

---

## 2. Navigating to the Inventory Section

1. Log in to your **Apna POS** account.
2. From the main application sidebar or bottom navigation bar, tap or click **Inventory**.
3. You will enter the Inventory workspace styled in the **Neumorphism Design System**, featuring:
   - **Segmented Top Tabs:** `Overview`, `Raw Materials`, `Recipes`, `Stock Operations`, and `Reports`.
   - **Subscription Crown Badge:** View your active plan tier.
   - **Real-Time Cloud Sync Button (`🔄`):** Manually re-sync all live data with backend APIs at any time.

---

## 3. Step 1: Setting Up Raw Materials (The Foundation)

Before you can create recipes or track consumption, you must register the raw materials that your kitchen purchases and uses.

### Understanding Unit Conversion
Restaurants purchase in bulk (e.g., Kilograms, Litres, Boxes) but prepare recipes in smaller units (e.g., Grams, Millilitres, Pieces).

| Raw Material | Purchase Unit | Canonical Base Unit | Conversion Factor |
| :--- | :--- | :--- | :--- |
| **Fresh Paneer** | Kilogram (`kg`) | Gram (`g`) | `1 kg = 1000 g` |
| **Cooking Oil / Milk** | Litre (`L`) | Millilitre (`ml`) | `1 L = 1000 ml` |
| **Burger Buns / Eggs** | Box (`box` of 24) | Piece (`pcs`) | `1 box = 24 pcs` |
| **Takeaway Containers** | Pack (`pack` of 50) | Piece (`pcs`) | `1 pack = 50 pcs` |

---

### How to Add a New Raw Material

1. Navigate to the **Raw Materials** tab (or tap **`+ Add Material`** from the Overview tab).
2. Click the **`+ Add Material`** button.
3. Fill in the material parameters in the dialog:
   - **Material Name:** e.g., `Fresh Paneer`, `Basmati Rice`, `Amul Butter`.
   - **SKU Code:** Unique identifier (e.g., `RM-0001` or auto-generated).
   - **Category:** Select from `Dairy`, `Vegetables`, `Meat & Poultry`, `Spices`, `Grains & Flour`, `Beverages`, `Packaging`, or `Essentials`.
   - **Base Unit (Canonical):** Choose `Gram (g)`, `Millilitre (ml)`, or `Piece (pcs)`.
   - **Purchase Unit:** Choose `Kilogram (kg)`, `Litre (L)`, `Pieces (pcs)`, `Box`, `Bag`, or `Pack`.
   - **Conversion Factor:** Number of base units in one purchase unit (e.g., `1000` for kg → g).
   - **Opening Stock:** Current quantity physically in your store (in base units, e.g., `10000` g = 10 kg).
   - **Minimum Alert Level:** Threshold below which a low-stock alert triggers (e.g., `2500` g = 2.5 kg).
   - **Average Unit Cost (₹):** Purchase price per purchase unit (e.g., `₹340` per kg).
   - **Inventory Mode:** 
     - **Mode A (Automatic):** Stock will be automatically consumed when recipe-linked menu items are sold.
     - **Mode B (Manual):** Stock is adjusted manually or counted physically.
   - **Preferred Supplier (Optional):** e.g., `Amul Dairy Distributors`.
4. Click **`Save Material`**.
   - The material will immediately appear in your materials catalog, complete with on-hand balance, valuation, and live status badge (`In Stock`, `Low Stock`, or `Out of Stock`).

---

## 4. Step 2: Creating Recipes & Food Costing (Connecting Menu to Materials)

Recipe creation connects your existing **POS Menu Items** to the raw materials you just configured. This unlocks automatic deduction upon checkout.

### Step-by-Step Recipe Creation

1. Navigate to the **Recipes** tab.
2. Click **`+ Create Recipe`**.
3. Configure the recipe details:
   - **Select Menu Item:** Choose the corresponding dish from your POS menu (e.g., `Paneer Butter Masala`).
   - **Recipe Name:** Name of the recipe version (e.g., `Standard Portion`).
   - **Serving Portion:** Default is `1.0` serving.
   - **Selling Price:** Displays the menu item's selling price (e.g., `₹280.00`).
4. **Add Ingredients:**
   - Tap **`+ Add Ingredient`** for each component of the dish.
   - Select the raw material from the dropdown (e.g., `Fresh Paneer`).
   - Enter **Quantity per portion** (e.g., `200` g).
   - Enter **Preparation Loss %** (shrinkage/cooking reduction, e.g., `0%` or `5%`).
   - Tap **`+ Add Ingredient`** again to add supporting ingredients:
     - `Cooking Butter`: `40 g`
     - `Fresh Cream`: `30 ml`
     - `Tomato Gravy Base`: `150 g`
5. **Analyze the Live Food Cost Breakdown:**
   - The system automatically calculates:
     $$\text{Total Food Cost} = \sum (\text{Ingredient Quantity} \times \text{Cost per Base Unit})$$
     $$\text{Food Cost Percentage (\%)} = \left(\frac{\text{Total Food Cost}}{\text{Selling Price}}\right) \times 100$$
   - **Target Benchmark:**
     - `≤ 30%`: **Healthy & High Profit Margin** (Green badge)
     - `31% – 40%`: **Moderate Food Cost** (Amber badge)
     - `> 40%`: **High Cost Alert / Low Profit** (Red badge — consider adjusting portions or repricing)
6. Click **`Save Recipe`**.
   - The recipe is now active. Any subsequent sale of this menu item will automatically trigger ingredient deduction.

---

## 5. Step 3: How POS Billing Automatically Deducts Stock (Mode A in Action)

Once recipes are configured, **cashiers do not need to do anything extra during billing**. The workflow is completely automated and idempotent:

```
Cashier takes Order at POS ──> Adds "Paneer Butter Masala" (Qty: 2) ──> Taps "Save & eBill" / Settle
                                              │
                                              ▼
                             Apna POS Backend Order Hook Triggered
                                              │
                      ┌───────────────────────┴───────────────────────┐
                      ▼                                               ▼
         Calculates Total Ingredients:                     Idempotency Protection:
         • Paneer: 200g × 2 = 400g deducted                • Checks order._id + settle token
         • Butter: 40g  × 2 = 80g deducted                 • Prevents duplicate deductions
         • Cream:  30ml × 2 = 60ml deducted                  if receipt is reprinted/synced
                      │                                               │
                      └───────────────────────┬───────────────────────┘
                                              ▼
                             Stock Ledger Entry Recorded:
                             • Type: "order_deduction"
                             • Order Reference ID: Attached
                             • New Balances & Valuations Updated Instantly
```

> [!NOTE]
> **Zero Delay for Cashiers:** Stock deduction operates efficiently in the background during bill generation. It will never freeze or slow down the checkout screen or thermal receipt printing.

---

## 6. Step 4: Recording Stock Purchases (Stock-In / Invoices)

When a new shipment or purchase invoice arrives from your supplier, record it to update on-hand quantities and recompute costs.

### Weighted Average Cost (WAC) Principle
Apna POS uses industry-standard Weighted Average Costing so your financial valuation accurately reflects changing wholesale market prices:

$$\text{New Average Unit Cost} = \frac{(\text{Current Stock} \times \text{Old Cost}) + (\text{Received Quantity} \times \text{Invoice Cost})}{\text{Current Stock} + \text{Received Quantity}}$$

### How to Record Stock-In:
1. Tap **`Stock Operations`** tab → **`Stock In (Purchase)`** (or tap **`+ Stock In`** on the Overview tab).
2. Fill in the purchase details:
   - **Supplier Name:** e.g., `Amul Dairy Dist.`, `Metro Cash & Carry`.
   - **Invoice / Challan No.:** e.g., `INV-2026-981`.
   - **Select Raw Material:** e.g., `Fresh Paneer`.
   - **Purchase Quantity:** e.g., `10` kg.
   - **Unit Cost (₹):** Price per purchase unit on the invoice (e.g., `₹330/kg`).
3. View the **Total Invoice Amount** auto-calculated.
4. Click **`Confirm Stock-In`**.
   - Material balance increases instantly (e.g., +10,000 g).
   - Average unit cost is recalculated automatically.
   - A permanent `purchase_in` transaction is saved to the ledger.

---

## 7. Step 5: Recording Kitchen Issues, Spoilage, & Wastage (Stock-Out)

Not all raw materials leave the store through sales. Spoilage, accidental drops, staff lunches, or quality testing must be recorded to keep ledger balances accurate.

### How to Record Stock-Out:
1. Tap **`Stock Operations`** tab → **`Stock Out (Wastage)`** (or tap **`− Stock Out`** on the Overview tab).
2. Fill in the removal details:
   - **Select Raw Material:** e.g., `Cooking Butter`.
   - **Quantity to Deduct:** e.g., `1.5` kg.
   - **Reason / Category:**
     - `Kitchen Prep Usage`: Issued directly to chef / preparation station.
     - `Spoilage / Expired`: Perishable items damaged or past expiry date.
     - `Spillage / Breakage / Damage`: Spilled liquids or dropped containers.
     - `Staff Meal Consumption`: Ingredients used for internal staff cooking.
     - `Quality Sampling / Tasting`: Head chef inspection.
3. Click **`Deduct Stock`**.
   - Quantity is immediately subtracted from active stock.
   - Movement is logged under `wastage` or `stock_out` with the selected reason for audit compliance.

---

## 8. Step 6: Physical Stock Counting & Variance Audits (Reconciliation)

At the end of each week or month, the store manager should perform a physical shelf count to compare what is actually on shelves versus what the system records.

```
       [ Physical Shelf Count ]  VS  [ System Recorded Balance ]
                                   │
                                   ▼
                              Variance (Δ)
                 ┌─────────────────┴─────────────────┐
                 ▼                                   ▼
          Negative Variance                   Positive Variance
         (Actual < System)                   (Actual > System)
         • Possible unrecorded wastage       • Possible unrecorded purchase
         • Over-portioning in kitchen        • Under-portioning during cooking
         • Potential theft or leakage
```

### How to Perform a Physical Count Audit:
1. Tap **`Stock Operations`** tab → **`Physical Count (Audit)`** (or tap **`⚖️ Physical Count`** on Overview).
2. Select the material you are counting (e.g., `Fresh Paneer`).
3. The system shows the **System Expected Balance** (e.g., `12,000 g`).
4. Enter the **Actual Physical Count** counted on your kitchen scale (e.g., `11,400 g`).
5. The system immediately displays:
   - **Variance:** `-600 g` (Shortage of 600 g / ~5%).
6. Click **`Adjust to Count`**.
   - System updates the material's balance directly to `11,400 g`.
   - An audit adjustment ledger entry is generated with timestamps to preserve historical accountability.

---

## 9. Understanding the Overview Dashboard

The **Overview** dashboard is optimized for mobile screens (arranged **2 boxes per row**) and desktop view:

```
┌─────────────────────────────────┐   ┌─────────────────────────────────┐
│ 💳 Stock Valuation              │   │ ⚠️ Low Stock Alert              │
│ ₹42,850.00                      │   │ 2 Items                         │
│ 14 materials on hand            │   │ Below reorder point             │
└─────────────────────────────────┘   └─────────────────────────────────┘
┌─────────────────────────────────┐   ┌─────────────────────────────────┐
│ 🛒 Out of Stock                 │   │ 🚚 Today's Stock-In             │
│ 0 Items                         │   │ ₹5,200                          │
│ Needs immediate restock         │   │ Goods purchases received        │
└─────────────────────────────────┘   └─────────────────────────────────┘
┌─────────────────────────────────┐   ┌─────────────────────────────────┐
│ 🍲 Today's Consumption          │   │ 📖 Active Recipes               │
│ ₹3,410                          │   │ 18 Recipes                      │
│ Kitchen cooking & sales         │   │ Menu auto-deductions            │
└─────────────────────────────────┘   └─────────────────────────────────┘
```

### Additional Dashboard Widgets:
- **⚡ Quick Operations Bar:** 1-tap shortcut buttons to `+ Add Material`, `+ Stock In`, `− Stock Out`, `Create Recipe`, and `Physical Count`.
- **🚨 Attention Needed Banner:** Appears automatically if any ingredients fall below minimum stock or reach 0, highlighting the exact items with a quick **"Restock Now"** button.
- **🔥 Top Consumed Ingredients:** Shows the highest turnover ingredients by total grams/ml consumed today.
- **🕒 Recent Transactions:** Live feed of the latest stock-in, order sales deductions, and wastage entries.

---

## 10. Reports & Profitability Analytics

Navigate to the **Reports** tab to inspect store performance:

### 1. Stock Valuation Report
- Itemized breakdown of all ingredients on hand.
- Current quantity in both base units (e.g., grams) and purchase units (e.g., kg).
- Average unit cost and total financial valuation of stock on shelves.
- Helps with monthly accounting and tax audits.

### 2. Stock Movement Ledger
- Full audit trail of every stock change.
- Filter by date, raw material, or transaction type (`purchase_in`, `order_deduction`, `wastage`, `physical_adjustment`).
- Displays delta quantity (`+` in green, `−` in red) and closing balance after each event.

### 3. Menu Item Profitability & Food Cost Analytics
- Displays each recipe's calculated food cost versus POS selling price.
- Highlights margin health:
  - Identifies dishes with excessive food costs (> 40%) that are eating into restaurant profits.
  - Suggests portion revisions or price adjustments to maintain target 30% food cost.

---

## 11. Restaurant Owner's Daily Best Practices Checklist

| Timing | Action | System Step |
| :--- | :--- | :--- |
| **Morning (Store Opening)** | Inspect Low Stock & Out of Stock | Check Overview Dashboard KPI boxes. If items are in warning state, order from suppliers. |
| **Mid-Day (Deliveries Arrive)** | Record Incoming Stock Purchases | Tap `+ Stock In`, enter supplier invoice and quantity. Verifies vendor bills against actual weights. |
| **During Operating Hours** | Run Regular POS Billing | Cashiers take orders and settle bills. Mode A auto-deducts recipe ingredients seamlessly. |
| **Kitchen Spoilage / Spill** | Record Kitchen Wastage | Tap `− Stock Out`, select reason `Spoilage` or `Damage` to prevent false theft alarms. |
| **Night (Store Closing)** | Quick Physical Spot Check | Tap `⚖️ Physical Count` on top 3 expensive ingredients (Paneer, Cheese, Meat) to ensure shelf counts match system stock. |

---

## 12. Frequently Asked Questions (FAQ)

#### Q1: What happens if an ingredient stock goes to zero or negative?
> **Answer:** POS sales will **never be blocked**. The system allows order settlement to continue without interrupting cashiers, while the inventory dashboard triggers a prominent red **Out of Stock Alert** so the manager can restock immediately.

#### Q2: Can I sell items like bottled water or canned soda that don't need a recipe?
> **Answer:** Yes! For packaged goods, add them as Raw Materials with **Mode B: Manual**. You can track their stock in units (`pcs` or `box`) and log stock-in/stock-out directly.

#### Q3: Does reprinting a bill or re-saving an order deduct ingredients twice?
> **Answer:** **No.** Every order deduction uses database **idempotency keys** linked to the unique order ID. If an order is refreshed, edited, or reprinted, the deduction engine verifies whether ingredients were already deducted and prevents duplicate subtractions.

#### Q4: How do I change an ingredient's price when market rates fluctuate?
> **Answer:** You don't need to manually edit the price! Whenever you record a purchase invoice in **Stock-In**, the system automatically recalibrates the **Weighted Average Cost (WAC)** based on the new invoice price.

---

*Documentation maintained by the Apna POS Development Team.*
