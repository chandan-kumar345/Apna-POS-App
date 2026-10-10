const mongoose = require('mongoose');
const Wallet = require('../models/Wallet');
const WalletTransaction = require('../models/WalletTransaction');
const whatsappConfig = require('../config/whatsapp.config');
const ApiError = require('../utils/ApiError');

class WalletService {
  /**
   * Get or automatically initialize business wallet
   */
  async getOrCreateWallet(businessId) {
    if (!businessId) {
      throw ApiError.badRequest('Business ID is required to access wallet', 'BUSINESS_ID_REQUIRED');
    }

    const bId = mongoose.Types.ObjectId.isValid(businessId)
      ? new mongoose.Types.ObjectId(businessId)
      : businessId;

    let wallet = await Wallet.findOne({ businessId: bId });
    if (!wallet) {
      try {
        wallet = await Wallet.create({
          businessId: bId,
          balance: 100.0, // Default promotional starter messaging balance
          currency: 'INR',
          isActive: true,
        });
      } catch (err) {
        // Handle concurrent creation race condition
        if (err.code === 11000) {
          wallet = await Wallet.findOne({ businessId: bId });
        } else {
          throw err;
        }
      }
    }
    return wallet;
  }

  /**
   * Retrieve active eBill fee for this business (from custom business config or platform default)
   */
  async getEbillFee(businessId) {
    const wallet = await this.getOrCreateWallet(businessId);
    if (wallet.ebillCharge !== null && wallet.ebillCharge !== undefined && wallet.ebillCharge >= 0) {
      return wallet.ebillCharge;
    }
    return whatsappConfig.defaultEbillCharge || 2.00;
  }

  /**
   * Check if business wallet has sufficient funds to send an eBill
   */
  async checkEligibility(businessId) {
    const wallet = await this.getOrCreateWallet(businessId);
    const fee = await this.getEbillFee(businessId);
    const hasSufficientBalance = wallet.isActive && wallet.balance >= fee;

    return {
      eligible: hasSufficientBalance,
      balance: wallet.balance,
      ebillCharge: fee,
      currency: wallet.currency || 'INR',
      isActive: wallet.isActive,
      remainingAfterSend: Math.max(0, wallet.balance - fee),
    };
  }

  /**
   * Atomically reserve / deduct eBill fee from business wallet
   * Ensures zero race-condition overspending and strictly idempotent transaction recording
   */
  async deductWalletAtomic({
    businessId,
    amount,
    category = 'EBILL',
    referenceType = 'EBILL',
    referenceId = '',
    idempotencyKey = '',
    description = 'WhatsApp eBill charge',
  }) {
    const bId = mongoose.Types.ObjectId.isValid(businessId)
      ? new mongoose.Types.ObjectId(businessId)
      : businessId;

    // 1. Idempotency Check: if transaction with this key already succeeded, return it safely
    if (idempotencyKey) {
      const existingTx = await WalletTransaction.findOne({
        businessId: bId,
        idempotencyKey,
      });
      if (existingTx && existingTx.status === 'SUCCESS') {
        const currentWallet = await this.getOrCreateWallet(bId);
        return {
          transaction: existingTx,
          wallet: currentWallet,
          isDuplicate: true,
        };
      }
    }

    const feeAmount = Number(amount);
    if (isNaN(feeAmount) || feeAmount <= 0) {
      throw ApiError.badRequest('Invalid deduction amount', null, 'INVALID_AMOUNT');
    }

    // 2. Atomic MongoDB balance deduction with condition balance >= amount
    const updatedWallet = await Wallet.findOneAndUpdate(
      {
        businessId: bId,
        balance: { $gte: feeAmount },
        isActive: true,
      },
      {
        $inc: { balance: -feeAmount },
      },
      {
        new: true,
      }
    );

    if (!updatedWallet) {
      // Wallet either doesn't exist, is inactive, or has insufficient balance
      const currentWallet = await this.getOrCreateWallet(bId);
      if (!currentWallet.isActive) {
        throw ApiError.forbidden('Business messaging wallet is inactive or suspended', 'WALLET_INACTIVE');
      }
      throw ApiError.badRequest(
        `Insufficient wallet balance. Current balance is ₹${currentWallet.balance.toFixed(2)}, but eBill requires ₹${feeAmount.toFixed(2)}.`,
        null,
        'INSUFFICIENT_WALLET_BALANCE'
      );
    }


    // 3. Create auditable transaction record
    let transaction;
    try {
      transaction = await WalletTransaction.create({
        businessId: bId,
        walletId: updatedWallet._id,
        type: 'DEBIT',
        category,
        amount: feeAmount,
        currency: updatedWallet.currency || 'INR',
        referenceType,
        referenceId: referenceId ? referenceId.toString() : '',
        idempotencyKey: idempotencyKey || undefined,
        status: 'SUCCESS',
        description,
      });
    } catch (txErr) {
      // In case of unique idempotency violation or db error, reverse the atomic deduction!
      await Wallet.updateOne({ _id: updatedWallet._id }, { $inc: { balance: feeAmount } });
      if (txErr.code === 11000 && idempotencyKey) {
        const existingTx = await WalletTransaction.findOne({ businessId: bId, idempotencyKey });
        if (existingTx) {
          const revertedWallet = await this.getOrCreateWallet(bId);
          return { transaction: existingTx, wallet: revertedWallet, isDuplicate: true };
        }
      }
      throw txErr;
    }

    return {
      transaction,
      wallet: updatedWallet,
      isDuplicate: false,
    };
  }

  /**
   * Recharge business wallet
   */
  async rechargeWallet({
    businessId,
    amount,
    referenceId = '',
    description = 'Wallet Recharge',
  }) {
    const bId = mongoose.Types.ObjectId.isValid(businessId)
      ? new mongoose.Types.ObjectId(businessId)
      : businessId;

    const rechargeAmount = Number(amount);
    if (isNaN(rechargeAmount) || rechargeAmount <= 0) {
      throw ApiError.badRequest('Recharge amount must be greater than zero', 'INVALID_AMOUNT');
    }

    await this.getOrCreateWallet(bId);

    const updatedWallet = await Wallet.findOneAndUpdate(
      { businessId: bId },
      { $inc: { balance: rechargeAmount } },
      { new: true }
    );

    const transaction = await WalletTransaction.create({
      businessId: bId,
      walletId: updatedWallet._id,
      type: 'CREDIT',
      category: 'RECHARGE',
      amount: rechargeAmount,
      currency: updatedWallet.currency || 'INR',
      referenceType: 'RECHARGE',
      referenceId: referenceId ? referenceId.toString() : '',
      status: 'SUCCESS',
      description,
    });

    return { wallet: updatedWallet, transaction };
  }

  /**
   * Refund / reverse a previous deduction
   */
  async refundWalletAtomic({
    businessId,
    amount,
    referenceType = 'EBILL',
    referenceId = '',
    description = 'eBill delivery failure refund',
  }) {
    const bId = mongoose.Types.ObjectId.isValid(businessId)
      ? new mongoose.Types.ObjectId(businessId)
      : businessId;

    const refundAmount = Number(amount);
    if (isNaN(refundAmount) || refundAmount <= 0) return null;

    const updatedWallet = await Wallet.findOneAndUpdate(
      { businessId: bId },
      { $inc: { balance: refundAmount } },
      { new: true }
    );

    const transaction = await WalletTransaction.create({
      businessId: bId,
      walletId: updatedWallet._id,
      type: 'CREDIT',
      category: 'REFUND',
      amount: refundAmount,
      currency: updatedWallet.currency || 'INR',
      referenceType,
      referenceId: referenceId ? referenceId.toString() : '',
      status: 'SUCCESS',
      description,
    });

    return { wallet: updatedWallet, transaction };
  }

  /**
   * Fetch recent wallet transactions
   */
  async getTransactions(businessId, { limit = 20, page = 1 } = {}) {
    const bId = mongoose.Types.ObjectId.isValid(businessId)
      ? new mongoose.Types.ObjectId(businessId)
      : businessId;

    const skip = (Math.max(1, page) - 1) * limit;
    const [transactions, total] = await Promise.all([
      WalletTransaction.find({ businessId: bId })
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit),
      WalletTransaction.countDocuments({ businessId: bId }),
    ]);

    return {
      transactions,
      pagination: {
        total,
        page: Number(page),
        limit: Number(limit),
        totalPages: Math.ceil(total / limit),
      },
    };
  }
}

module.exports = new WalletService();
