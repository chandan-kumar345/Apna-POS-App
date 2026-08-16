const { S3Client, PutObjectCommand, DeleteObjectCommand } = require('@aws-sdk/client-s3');
const path = require('path');
const crypto = require('crypto');
const fs = require('fs');

class StorageService {
  constructor() {
    this.accountId = process.env.CLOUDFLARE_ACCOUNT_ID;
    this.accessKeyId = process.env.R2_ACCESS_KEY_ID;
    this.secretAccessKey = process.env.R2_SECRET_ACCESS_KEY;
    this.bucketName = process.env.R2_BUCKET_NAME || 'apna-pos-media';
    this.publicDomain = process.env.R2_PUBLIC_DOMAIN; // e.g. https://pub-xxxx.r2.dev or https://media.yourdomain.com

    if (this.accountId && this.accessKeyId && this.secretAccessKey) {
      this.client = new S3Client({
        region: 'auto',
        endpoint: `https://${this.accountId}.r2.cloudflarestorage.com`,
        credentials: {
          accessKeyId: this.accessKeyId,
          secretAccessKey: this.secretAccessKey,
        },
      });
      this.isConfigured = true;
      console.log('[StorageService] Cloudflare R2 client initialized successfully');
    } else {
      this.isConfigured = false;
      console.warn('[StorageService] Cloudflare R2 credentials not fully set. Falling back to local storage.');
    }
  }

  /**
   * Upload an image buffer to Cloudflare R2 (or local fallback)
   * @param {Buffer} fileBuffer
   * @param {string} originalName
   * @param {string} mimeType
   * @param {string} folder e.g. 'products', 'profiles', 'receipts'
   * @returns {Promise<string>} Public URL of uploaded image
   */
  async uploadImage(fileBuffer, originalName, mimeType, folder = 'products') {
    const ext = path.extname(originalName) || '.jpg';
    const cleanFileName = `${Date.now()}_${crypto.randomBytes(4).toString('hex')}${ext}`;
    const key = `${folder}/${cleanFileName}`;

    if (this.isConfigured) {
      const command = new PutObjectCommand({
        Bucket: this.bucketName,
        Key: key,
        Body: fileBuffer,
        ContentType: mimeType,
      });

      await this.client.send(command);

      if (this.publicDomain) {
        const cleanBase = this.publicDomain.endsWith('/')
          ? this.publicDomain.slice(0, -1)
          : this.publicDomain;
        return `${cleanBase}/${key}`;
      }

      // Default public dev URL format if public domain not set
      return `https://${this.bucketName}.${this.accountId}.r2.cloudflarestorage.com/${key}`;
    }

    // Local fallback: save to public/uploads
    const uploadDir = path.join(__dirname, '../../public/uploads', folder);
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
    }
    const localFilePath = path.join(uploadDir, cleanFileName);
    fs.writeFileSync(localFilePath, fileBuffer);

    return `/uploads/${folder}/${cleanFileName}`;
  }

  /**
   * Delete an image from storage
   * @param {string} fileUrl
   */
  async deleteImage(fileUrl) {
    if (!fileUrl) return;

    if (this.isConfigured) {
      try {
        const urlObj = new URL(fileUrl);
        const key = urlObj.pathname.startsWith('/') ? urlObj.pathname.slice(1) : urlObj.pathname;
        const command = new DeleteObjectCommand({
          Bucket: this.bucketName,
          Key: key,
        });
        await this.client.send(command);
      } catch (err) {
        console.error('[StorageService.deleteImage] Error deleting R2 object:', err.message);
      }
    }
  }
}

module.exports = new StorageService();
