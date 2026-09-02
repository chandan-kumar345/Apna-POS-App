const nodemailer = require('nodemailer');
const env = require('../config/env');

class EmailService {
  constructor() {
    this.transporter = null;
    this._initTransporter();
  }

  _getTransporter() {
    const user = process.env.SMTP_USER || env.SMTP_USER;
    const pass = process.env.SMTP_PASS || env.SMTP_PASS;
    const host = process.env.SMTP_HOST || env.SMTP_HOST || 'smtp.gmail.com';
    const port = Number(process.env.SMTP_PORT || env.SMTP_PORT || 587);
    const secure = (process.env.SMTP_SECURE || String(env.SMTP_SECURE)) === 'true';

    if (user && pass) {
      return nodemailer.createTransport({
        host,
        port,
        secure,
        auth: { user, pass },
        tls: { rejectUnauthorized: false },
      });
    }
    return null;
  }

  _initTransporter() {
    this.transporter = this._getTransporter();
    const user = process.env.SMTP_USER || env.SMTP_USER;
    if (this.transporter) {
      console.log(`[EmailService] SMTP Transporter ready for user: ${user}`);
    } else {
      console.log(`[EmailService] SMTP credentials (SMTP_USER/SMTP_PASS) not configured in .env. Real emails require Gmail App Password.`);
    }
  }

  /**
   * Verify SMTP connection health
   */
  async testConnection() {
    const transporter = this._getTransporter();
    const recipient = process.env.LEAD_NOTIFICATION_EMAIL || env.LEAD_NOTIFICATION_EMAIL || 'sooftcode@gmail.com';
    if (!transporter) {
      return {
        configured: false,
        message: 'SMTP credentials missing. Set SMTP_USER and SMTP_PASS (Gmail 16-digit App Password) in backend/.env to receive real emails.',
        recipient,
      };
    }
    try {
      await transporter.verify();
      return {
        configured: true,
        verified: true,
        message: 'SMTP Connection Verified! Gmail SMTP is ready to deliver leads.',
        user: process.env.SMTP_USER || env.SMTP_USER,
        recipient,
      };
    } catch (err) {
      return {
        configured: true,
        verified: false,
        error: err.message,
        message: `SMTP Connection Failed: ${err.message}. Please check if 2-Step Verification is ON and you generated a 16-character Google App Password.`,
        recipient,
      };
    }
  }

  /**
   * Send Lead Notification Email to sooftcode@gmail.com
   */
  async sendLeadNotificationEmail(lead) {
    const recipientEmail = env.LEAD_NOTIFICATION_EMAIL || 'sooftcode@gmail.com';
    const cleanPhone = String(lead.phone || '').replace(/\D/g, '');
    const waPhone = cleanPhone.length === 10 ? `91${cleanPhone}` : cleanPhone;
    const receivedTime = new Date().toLocaleString('en-IN', {
      timeZone: 'Asia/Kolkata',
      dateStyle: 'full',
      timeStyle: 'medium',
    });

    const subject = `🚀 [Apna POS Lead] ${lead.restaurantName} is interested in ${lead.selectedPlan}`;

    const htmlContent = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #F1F5F9; margin: 0; padding: 24px; color: #1E293B; }
    .card { max-width: 620px; margin: 0 auto; background: #FFFFFF; border-radius: 16px; overflow: hidden; box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.1), 0 8px 10px -6px rgba(0, 0, 0, 0.1); border: 1px solid #E2E8F0; }
    .header { background: linear-gradient(135deg, #0F172A 0%, #1E3A8A 50%, #0369A1 100%); padding: 32px 28px; text-align: center; color: #FFFFFF; }
    .header h1 { margin: 0; font-size: 24px; font-weight: 800; letter-spacing: -0.5px; }
    .header p { margin: 8px 0 0; font-size: 14px; opacity: 0.9; }
    .badge { display: inline-block; background: #22C55E; color: #FFFFFF; padding: 4px 12px; border-radius: 9999px; font-size: 12px; font-weight: 700; text-transform: uppercase; margin-top: 12px; }
    .content { padding: 28px; }
    .lead-box { background: #F8FAFC; border-radius: 12px; border: 1px solid #E2E8F0; padding: 20px; margin-bottom: 24px; }
    .row { display: flex; justify-content: space-between; padding: 10px 0; border-bottom: 1px solid #E2E8F0; font-size: 14px; }
    .row:last-child { border-bottom: none; }
    .label { font-weight: 600; color: #64748B; width: 38%; }
    .val { font-weight: 700; color: #0F172A; width: 62%; text-align: right; word-break: break-word; }
    .cta-container { display: flex; gap: 12px; margin-top: 24px; }
    .btn { display: inline-block; flex: 1; text-align: center; padding: 14px 20px; border-radius: 10px; font-weight: 700; font-size: 14px; text-decoration: none; }
    .btn-wa { background: #25D366; color: #FFFFFF; }
    .btn-call { background: #0284C7; color: #FFFFFF; }
    .footer { padding: 20px 28px; background: #F8FAFC; border-top: 1px solid #E2E8F0; text-align: center; font-size: 12px; color: #94A3B8; }
  </style>
</head>
<body>
  <div class="card">
    <div class="header">
      <h1>🚀 New Subscription Inquiry!</h1>
      <p>A restaurant owner just clicked <strong>"I'm Interested"</strong> on Apna POS</p>
      <div class="badge">Hot Lead • Respond Quickly</div>
    </div>
    
    <div class="content">
      <div class="lead-box">
        <div class="row">
          <div class="label">🏢 Restaurant / Business:</div>
          <div class="val">${lead.restaurantName || 'N/A'}</div>
        </div>
        <div class="row">
          <div class="label">👤 Contact Person:</div>
          <div class="val">${lead.contactPerson || 'N/A'}</div>
        </div>
        <div class="row">
          <div class="label">📞 Mobile Number:</div>
          <div class="val"><a href="tel:${lead.phone}" style="color: #0284C7; text-decoration: none;">${lead.phone}</a></div>
        </div>
        <div class="row">
          <div class="label">✉️ Email ID:</div>
          <div class="val">${lead.email || 'Not Provided'}</div>
        </div>
        <div class="row">
          <div class="label">💎 Selected Plan:</div>
          <div class="val" style="color: #0284C7;">${lead.selectedPlan || 'Growth / Pro Plan'}</div>
        </div>
        <div class="row">
          <div class="label">🔄 Billing Cycle:</div>
          <div class="val" style="text-transform: capitalize;">${lead.billingCycle || 'Annual'}</div>
        </div>
        <div class="row">
          <div class="label">🎯 Inquired From:</div>
          <div class="val" style="text-transform: uppercase;">${lead.sourceFeature || 'SUBSCRIPTION_SCREEN'}</div>
        </div>
        ${lead.notes ? `
        <div class="row">
          <div class="label">📝 Customer Notes:</div>
          <div class="val" style="font-weight: 500;">${lead.notes}</div>
        </div>
        ` : ''}
        <div class="row">
          <div class="label">⏰ Time of Lead:</div>
          <div class="val" style="font-size: 12px; font-weight: 500;">${receivedTime}</div>
        </div>
      </div>

      <table width="100%" cellpadding="0" cellspacing="0" style="margin-top: 16px;">
        <tr>
          <td width="48%" align="center">
            <a href="https://wa.me/${waPhone}?text=Hello%20${encodeURIComponent(lead.contactPerson || lead.restaurantName)}%2C%20thank%20you%20for%20your%20interest%20in%20Apna%20POS%20${encodeURIComponent(lead.selectedPlan)}.%20How%20can%20I%20help%20you%20today%3F" style="display: block; background: #25D366; color: #FFFFFF; text-decoration: none; padding: 12px 18px; border-radius: 8px; font-weight: bold; font-size: 13px; text-align: center;">💬 WhatsApp Lead</a>
          </td>
          <td width="4%"></td>
          <td width="48%" align="center">
            <a href="tel:${lead.phone}" style="display: block; background: #0284C7; color: #FFFFFF; text-decoration: none; padding: 12px 18px; border-radius: 8px; font-weight: bold; font-size: 13px; text-align: center;">📞 Call Customer</a>
          </td>
        </tr>
      </table>
    </div>

    <div class="footer">
      This lead was automatically generated from Apna POS Application for <strong>${recipientEmail}</strong>.<br>
      © ${new Date().getFullYear()} Apna POS Technologies. All rights reserved.
    </div>
  </div>
</body>
</html>
    `;

    console.log(`[EmailService] Dispatching lead email for "${lead.restaurantName}" to: ${recipientEmail}`);

    const transporter = this._getTransporter() || this.transporter;

    if (transporter) {
      try {
        const fromAddress = process.env.SMTP_FROM || env.SMTP_FROM || `Apna POS Leads <${process.env.SMTP_USER || 'no-reply@apnapos.com'}>`;
        const info = await transporter.sendMail({
          from: fromAddress,
          to: recipientEmail,
          subject,
          html: htmlContent,
        });
        console.log(`[EmailService] Real Email sent successfully! MessageId: ${info.messageId} to ${recipientEmail}`);
        return { sent: true, messageId: info.messageId, recipient: recipientEmail };
      } catch (err) {
        console.error(`[EmailService] Failed to send email via SMTP:`, err.message);
        return { sent: false, error: err.message, recipient: recipientEmail };
      }
    } else {
      // SMTP not configured yet: log simulation
      console.log(`[EmailService] Simulated Email Dispatched (SMTP credentials not configured in .env):`);
      console.log(`To: ${recipientEmail}`);
      console.log(`Subject: ${subject}`);
      console.log(`Phone: ${lead.phone} | Plan: ${lead.selectedPlan} | Source: ${lead.sourceFeature}`);
      return { sent: true, simulated: true, recipient: recipientEmail };
    }
  }
}

module.exports = new EmailService();
