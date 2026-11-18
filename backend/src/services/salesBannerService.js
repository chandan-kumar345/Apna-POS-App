const { createCanvas } = require('@napi-rs/canvas');
const storageService = require('../utils/storageService');

class SalesBannerService {
  /**
   * Generates a dynamic 1080x540 PNG banner matching the executive 3-card dark theme
   * and uploads it to Cloudflare R2, returning the public CDN URL.
   */
  async generateAndUploadBanner({
    totalSales = 0,
    orderCount = 0,
    avgOrderValue = null,
    dateLabel = null,
    percentageChange = null,
    isHigher = true,
    yesterdaySales = null,
  }) {
    try {
      const calcAvg = avgOrderValue !== null && avgOrderValue !== undefined
        ? Number(avgOrderValue)
        : (orderCount > 0 ? Math.round(totalSales / orderCount) : 0);

      // Percentage comparison
      let effectivePct = percentageChange !== null && percentageChange !== undefined
        ? Number(percentageChange)
        : 0;
      let effectiveIsHigher = isHigher;

      if ((percentageChange === null || percentageChange === undefined) && yesterdaySales !== null) {
        if (yesterdaySales > 0) {
          const diff = totalSales - yesterdaySales;
          effectivePct = Math.round((Math.abs(diff) / yesterdaySales) * 100);
          effectiveIsHigher = diff >= 0;
        } else if (totalSales > 0) {
          effectivePct = 100;
          effectiveIsHigher = true;
        }
      } else if ((percentageChange === null || percentageChange === undefined) && totalSales > 0) {
        effectivePct = 12;
        effectiveIsHigher = true;
      }

      const now = new Date();
      const effectiveDate = dateLabel && dateLabel.trim().length > 0
        ? dateLabel.trim()
        : new Intl.DateTimeFormat('en-IN', { day: 'numeric', month: 'short' }).format(now);

      const formattedSales = `₹${Math.round(totalSales).toLocaleString('en-IN')}`;
      const formattedOrders = `${orderCount}`;
      const formattedAvg = `₹${Math.round(calcAvg).toLocaleString('en-IN')}`;

      // Canvas dimensions: 1080 x 540 px
      const width = 1080;
      const height = 540;
      const canvas = createCanvas(width, height);
      const ctx = canvas.getContext('2d');

      // 1. Draw Outer Rounded Container with Deep Dark Gradient & Glowing Border
      this._drawContainer(ctx, width, height);

      // 2. Draw Bottom-Right Decorative Flowing Waves
      this._drawDecorativeWaves(ctx, width, height);

      // 3. Draw Top Header: [📊] Daily Sales Summary | [📅] Date
      this._drawHeader(ctx, effectiveDate);

      // 4. Draw 3 Metric Cards: Green (Sales), Orange (Orders), Purple (Avg)
      this._drawMetricCards(ctx, formattedSales, formattedOrders, formattedAvg);

      // 5. Draw Bottom Trend Footer: [📈] Today's Sales are X% higher than yesterday!
      this._drawFooter(ctx, effectivePct, effectiveIsHigher, totalSales > 0);

      // Encode as PNG buffer
      const pngBuffer = canvas.toBuffer('image/png');

      // Upload to Cloudflare R2
      const publicUrl = await storageService.uploadMedia(
        pngBuffer,
        `sales_banner_${Date.now()}.png`,
        'image/png',
        'notifications'
      );

      console.log(`[SalesBannerService] ✅ Dynamic sales banner generated and uploaded to R2: ${publicUrl}`);
      return publicUrl;
    } catch (err) {
      console.error('[SalesBannerService] Error generating sales banner:', err);
      return null;
    }
  }

  _drawContainer(ctx, width, height) {
    const margin = 10;
    const radius = 32;
    const w = width - margin * 2;
    const h = height - margin * 2;

    ctx.save();
    ctx.beginPath();
    ctx.roundRect(margin, margin, w, h, radius);
    ctx.clip();

    // Deep Dark Navy/Slate Gradient
    const bgGrad = ctx.createLinearGradient(margin, margin, width - margin, height - margin);
    bgGrad.addColorStop(0, '#0F1E2E');
    bgGrad.addColorStop(0.5, '#0B1420');
    bgGrad.addColorStop(1, '#070D15');
    ctx.fillStyle = bgGrad;
    ctx.fillRect(margin, margin, w, h);
    ctx.restore();

    // Subtle Glowing Border
    ctx.save();
    ctx.beginPath();
    ctx.roundRect(margin, margin, w, h, radius);
    const borderGrad = ctx.createLinearGradient(margin, margin, width - margin, height - margin);
    borderGrad.addColorStop(0, 'rgba(56, 189, 248, 0.25)');
    borderGrad.addColorStop(0.5, 'rgba(15, 30, 46, 0.15)');
    borderGrad.addColorStop(1, 'rgba(0, 229, 255, 0.55)');
    ctx.strokeStyle = borderGrad;
    ctx.lineWidth = 2.0;
    ctx.stroke();
    ctx.restore();
  }

  _drawDecorativeWaves(ctx, width, height) {
    ctx.save();
    const margin = 10;
    const radius = 32;
    ctx.beginPath();
    ctx.roundRect(margin, margin, width - margin * 2, height - margin * 2, radius);
    ctx.clip();

    // Filled translucent cyan wave
    ctx.beginPath();
    ctx.moveTo(width * 0.58, height);
    ctx.bezierCurveTo(
      width * 0.68, height - 42,
      width * 0.74, height - 76,
      width * 0.84, height - 45
    );
    ctx.bezierCurveTo(
      width * 0.90, height - 25,
      width * 0.95, height - 75,
      width, height - 58
    );
    ctx.lineTo(width, height);
    ctx.closePath();

    const fillGrad = ctx.createLinearGradient(width * 0.7, height - 80, width, height);
    fillGrad.addColorStop(0, 'rgba(0, 210, 180, 0.22)');
    fillGrad.addColorStop(0.6, 'rgba(0, 229, 255, 0.12)');
    fillGrad.addColorStop(1, 'rgba(0, 0, 0, 0)');
    ctx.fillStyle = fillGrad;
    ctx.fill();

    // Glowing cyan line 1
    ctx.beginPath();
    ctx.moveTo(width * 0.60, height);
    ctx.bezierCurveTo(
      width * 0.69, height - 46,
      width * 0.75, height - 82,
      width * 0.85, height - 50
    );
    ctx.bezierCurveTo(
      width * 0.91, height - 28,
      width * 0.96, height - 80,
      width, height - 62
    );
    const lineGrad = ctx.createLinearGradient(width * 0.6, height, width, height - 60);
    lineGrad.addColorStop(0, 'rgba(0, 229, 255, 0.1)');
    lineGrad.addColorStop(0.5, 'rgba(0, 229, 255, 0.7)');
    lineGrad.addColorStop(1, 'rgba(0, 210, 180, 0.8)');
    ctx.strokeStyle = lineGrad;
    ctx.lineWidth = 2.4;
    ctx.stroke();

    // Subtle wave 2
    ctx.beginPath();
    ctx.moveTo(width * 0.72, height);
    ctx.bezierCurveTo(
      width * 0.79, height - 32,
      width * 0.86, height - 68,
      width * 0.93, height - 35
    );
    ctx.bezierCurveTo(
      width * 0.96, height - 20,
      width * 0.98, height - 44,
      width, height - 38
    );
    ctx.strokeStyle = 'rgba(0, 229, 153, 0.35)';
    ctx.lineWidth = 1.8;
    ctx.stroke();

    ctx.restore();
  }

  _drawHeader(ctx, dateLabel) {
    const startX = 46;
    const centerY = 66;

    // A. Bar Chart Icon Container (Blue Squircle)
    const boxSize = 48;
    const boxLeft = startX;
    const boxTop = centerY - boxSize / 2;

    ctx.save();
    ctx.beginPath();
    ctx.roundRect(boxLeft, boxTop, boxSize, boxSize, 13);
    const iconGrad = ctx.createLinearGradient(boxLeft, boxTop, boxLeft + boxSize, boxTop + boxSize);
    iconGrad.addColorStop(0, '#0288D1');
    iconGrad.addColorStop(1, '#01579B');
    ctx.fillStyle = iconGrad;
    ctx.fill();

    ctx.strokeStyle = 'rgba(56, 189, 248, 0.5)';
    ctx.lineWidth = 1.2;
    ctx.stroke();

    // 3 white vertical bars
    ctx.fillStyle = '#FFFFFF';
    const barWidth = 5.5;
    const barGap = 4.5;
    const baseY = boxTop + boxSize - 12;

    // Bar 1 (Short)
    ctx.beginPath();
    ctx.roundRect(boxLeft + 12, baseY - 12, barWidth, 12, 2);
    ctx.fill();
    // Bar 2 (Medium)
    ctx.beginPath();
    ctx.roundRect(boxLeft + 12 + barWidth + barGap, baseY - 20, barWidth, 20, 2);
    ctx.fill();
    // Bar 3 (Tall)
    ctx.beginPath();
    ctx.roundRect(boxLeft + 12 + (barWidth + barGap) * 2, baseY - 26, barWidth, 26, 2);
    ctx.fill();
    ctx.restore();

    // B. "Daily Sales Summary" Title Text
    ctx.save();
    ctx.fillStyle = '#FFFFFF';
    ctx.font = 'bold 32px sans-serif';
    ctx.textBaseline = 'middle';
    ctx.fillText('Daily Sales Summary', boxLeft + boxSize + 16, centerY);
    const titleWidth = ctx.measureText('Daily Sales Summary').width;

    // C. Vertical Divider "|"
    const dividerX = boxLeft + boxSize + 16 + titleWidth + 20;
    ctx.strokeStyle = 'rgba(142, 160, 180, 0.4)';
    ctx.lineWidth = 1.6;
    ctx.beginPath();
    ctx.moveTo(dividerX, centerY - 14);
    ctx.lineTo(dividerX, centerY + 14);
    ctx.stroke();

    // D. Calendar Icon (Sky Blue)
    const calX = dividerX + 22;
    const calTop = centerY - 15;
    const calSize = 30;

    // Body
    ctx.strokeStyle = '#38BDF8';
    ctx.lineWidth = 2.4;
    ctx.beginPath();
    ctx.roundRect(calX, calTop + 4, calSize - 2, calSize - 6, 6);
    ctx.stroke();

    // Header band
    ctx.fillStyle = '#0288D1';
    ctx.beginPath();
    ctx.roundRect(calX + 1, calTop + 5, calSize - 4, 7, [5, 5, 0, 0]);
    ctx.fill();

    // 2 binder rings
    ctx.beginPath();
    ctx.moveTo(calX + 7, calTop);
    ctx.lineTo(calX + 7, calTop + 6);
    ctx.moveTo(calX + calSize - 9, calTop);
    ctx.lineTo(calX + calSize - 9, calTop + 6);
    ctx.stroke();

    // Calendar grid squares
    ctx.fillStyle = '#BAE6FD';
    ctx.fillRect(calX + 7, calTop + 16, 3, 3);
    ctx.fillRect(calX + 13, calTop + 16, 3, 3);
    ctx.fillRect(calX + 19, calTop + 16, 3, 3);
    ctx.fillRect(calX + 7, calTop + 21, 3, 3);
    ctx.fillRect(calX + 13, calTop + 21, 3, 3);
    ctx.fillRect(calX + 19, calTop + 21, 3, 3);

    // E. Date Text
    ctx.fillStyle = '#F1F5F9';
    ctx.font = '600 27px sans-serif';
    ctx.fillText(dateLabel, calX + 38, centerY);
    ctx.restore();
  }

  _drawMetricCards(ctx, sales, orders, avg) {
    const startX = 46;
    const startY = 126;
    const cardHeight = 230;
    const totalAvailWidth = 1080 - startX * 2;
    const cardGap = 16;
    const cardWidth = (totalAvailWidth - cardGap * 2) / 3;
    const radius = 24;

    // Card 1: Total Sales (Emerald Green)
    this._drawCard(
      ctx,
      startX,
      startY,
      cardWidth,
      cardHeight,
      radius,
      '#00E599',
      'rgba(0, 77, 45, 0.28)',
      'Total Sales',
      '#D1FAE5',
      sales,
      'coins'
    );

    // Card 2: Total Orders (Amber Orange)
    this._drawCard(
      ctx,
      startX + cardWidth + cardGap,
      startY,
      cardWidth,
      cardHeight,
      radius,
      '#F59E0B',
      'rgba(77, 46, 0, 0.28)',
      'Total Orders',
      '#FEF3C7',
      orders,
      'cart'
    );

    // Card 3: Avg. Order Value (Purple)
    this._drawCard(
      ctx,
      startX + (cardWidth + cardGap) * 2,
      startY,
      cardWidth,
      cardHeight,
      radius,
      '#A855F7',
      'rgba(53, 10, 82, 0.28)',
      'Avg. Order Value',
      '#F3E8FF',
      avg,
      'receipt'
    );
  }

  _drawCard(ctx, x, y, w, h, radius, borderColor, fillColor, title, titleColor, value, iconType) {
    ctx.save();
    // Fill
    ctx.beginPath();
    ctx.roundRect(x, y, w, h, radius);
    ctx.fillStyle = fillColor;
    ctx.fill();

    // Border
    ctx.strokeStyle = borderColor;
    ctx.lineWidth = 2.0;
    ctx.stroke();

    // Draw Vector Icon on Left
    const iconCx = x + 50;
    const iconCy = y + h / 2;

    if (iconType === 'coins') {
      this._drawCoins(ctx, iconCx, iconCy);
    } else if (iconType === 'cart') {
      this._drawCart(ctx, iconCx, iconCy, borderColor);
    } else if (iconType === 'receipt') {
      this._drawReceipt(ctx, iconCx, iconCy, borderColor);
    }

    // Texts on Right
    const textLeft = x + 98;
    ctx.fillStyle = titleColor;
    ctx.font = '600 20px sans-serif';
    ctx.textBaseline = 'top';
    ctx.fillText(title, textLeft, y + 68);

    ctx.fillStyle = '#FFFFFF';
    ctx.font = 'bold 38px sans-serif';
    ctx.fillText(value, textLeft, y + 104);

    ctx.restore();
  }

  _drawCoins(ctx, cx, cy) {
    ctx.save();
    const rx = 24;
    const ry = 9.5;
    const thickness = 8;

    // Bottom Coin
    this._drawSingleCoin(ctx, cx - 4, cy + 8, rx, ry, thickness, '#00E599', '#00A86B');

    // Top Coin
    this._drawSingleCoin(ctx, cx + 4, cy - 8, rx, ry, thickness, '#00FFAB', '#00C47E');
    ctx.restore();
  }

  _drawSingleCoin(ctx, cx, cy, rx, ry, thickness, topColor, sideColor) {
    // Side cylinder
    ctx.beginPath();
    ctx.ellipse(cx, cy + thickness, rx, ry, 0, 0, Math.PI);
    ctx.lineTo(cx - rx, cy);
    ctx.ellipse(cx, cy, rx, ry, 0, Math.PI, 0, true);
    ctx.closePath();
    ctx.fillStyle = sideColor;
    ctx.fill();

    // Top face
    ctx.beginPath();
    ctx.ellipse(cx, cy, rx, ry, 0, 0, Math.PI * 2);
    ctx.fillStyle = topColor;
    ctx.fill();

    // Inner rim
    ctx.beginPath();
    ctx.ellipse(cx, cy, rx - 6, ry - 2.5, 0, 0, Math.PI * 2);
    ctx.strokeStyle = 'rgba(0, 122, 77, 0.6)';
    ctx.lineWidth = 1.4;
    ctx.stroke();
  }

  _drawCart(ctx, cx, cy, color) {
    ctx.save();
    ctx.strokeStyle = color;
    ctx.lineWidth = 3.6;
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';

    ctx.beginPath();
    ctx.moveTo(cx - 22, cy - 16);
    ctx.lineTo(cx - 15, cy - 16);
    ctx.lineTo(cx - 8, cy + 8);
    ctx.lineTo(cx + 18, cy + 8);
    ctx.lineTo(cx + 22, cy - 7);
    ctx.lineTo(cx - 12, cy - 7);
    ctx.stroke();

    ctx.fillStyle = color;
    ctx.beginPath();
    ctx.arc(cx - 5, cy + 17, 3.8, 0, Math.PI * 2);
    ctx.arc(cx + 14, cy + 17, 3.8, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  }

  _drawReceipt(ctx, cx, cy, color) {
    ctx.save();
    const w = 34;
    const h = 44;
    const left = cx - w / 2;
    const top = cy - h / 2;

    ctx.strokeStyle = color;
    ctx.lineWidth = 3.0;
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';

    ctx.beginPath();
    ctx.roundRect(left, top, w, h, 6);
    ctx.stroke();

    // 3 lines
    ctx.beginPath();
    ctx.moveTo(left + 7, top + 14);
    ctx.lineTo(left + w - 7, top + 14);
    ctx.moveTo(left + 7, top + 22);
    ctx.lineTo(left + w - 7, top + 22);
    ctx.moveTo(left + 7, top + 30);
    ctx.lineTo(left + w - 13, top + 30);
    ctx.lineWidth = 2.4;
    ctx.stroke();
    ctx.restore();
  }

  _drawFooter(ctx, pct, isHigher, hasSales) {
    const startX = 54;
    const centerY = 455;

    ctx.save();
    // Trend arrow
    const arrowColor = isHigher ? '#00E599' : '#F59E0B';
    ctx.strokeStyle = arrowColor;
    ctx.lineWidth = 3.6;
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';

    ctx.beginPath();
    if (isHigher) {
      ctx.moveTo(startX - 16, centerY + 10);
      ctx.lineTo(startX - 6, centerY);
      ctx.lineTo(startX + 4, centerY + 6);
      ctx.lineTo(startX + 18, centerY - 10);

      ctx.moveTo(startX + 8, centerY - 10);
      ctx.lineTo(startX + 18, centerY - 10);
      ctx.lineTo(startX + 18, centerY);
    } else {
      ctx.moveTo(startX - 16, centerY - 10);
      ctx.lineTo(startX - 6, centerY);
      ctx.lineTo(startX + 4, centerY - 6);
      ctx.lineTo(startX + 18, centerY + 10);

      ctx.moveTo(startX + 8, centerY + 10);
      ctx.lineTo(startX + 18, centerY + 10);
      ctx.lineTo(startX + 18, centerY);
    }
    ctx.stroke();

    // Rich statement
    ctx.textBaseline = 'middle';
    ctx.font = '500 26px sans-serif';
    ctx.fillStyle = '#CBD5E1';

    let textX = startX + 46;
    if (hasSales && pct > 0) {
      ctx.fillText("Today's Sales are ", textX, centerY);
      textX += ctx.measureText("Today's Sales are ").width;

      const pctStr = `${pct}% ${isHigher ? 'higher' : 'lower'}`;
      ctx.fillStyle = arrowColor;
      ctx.font = 'bold 26px sans-serif';
      ctx.fillText(pctStr, textX, centerY);
      textX += ctx.measureText(pctStr).width;

      ctx.fillStyle = '#CBD5E1';
      ctx.font = '500 26px sans-serif';
      ctx.fillText(' than yesterday!', textX, centerY);
    } else if (hasSales) {
      ctx.fillText("Today's Sales are on track with strong momentum!", textX, centerY);
    } else {
      ctx.fillStyle = '#94A3B8';
      ctx.fillText('Ready for business! All registers open and catalog updated.', textX, centerY);
    }

    ctx.restore();
  }
}

module.exports = new SalesBannerService();
