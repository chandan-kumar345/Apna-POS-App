const chotuService = require('../services/chotu/chotuService');
const productService = require('../services/productService');
const ApiResponse = require('../utils/ApiResponse');

class ChotuController {
  /**
   * Transcribe spoken audio or speech text
   */
  async transcribe(req, res, next) {
    try {
      const result = await chotuService.transcribeVoice(req.businessId, {
        ...req.body,
        userId: req.user?._id,
      });
      return ApiResponse.success(res, result, result.message || 'Transcription successful', 200);
    } catch (error) {
      next(error);
    }
  }

  /**
   * Parse natural speech command into structured POS command
   */
  async parse(req, res, next) {
    try {
      const result = await chotuService.parseVoiceCommand(req.businessId, {
        text: req.body.text || req.body.audio,
        sessionId: req.body.sessionId,
        currentTableContext: req.body.currentTableContext || req.body.tableNumber,
        userId: req.user?._id,
      });
      return ApiResponse.success(res, result, 'Voice command parsed successfully', 200);
    } catch (error) {
      next(error);
    }
  }

  /**
   * Execute validated POS command through existing POS services
   */
  async execute(req, res, next) {
    try {
      const result = await chotuService.executeVoiceCommand(req.businessId, {
        commandId: req.body.commandId,
        sessionId: req.body.sessionId,
        command: req.body.command,
        userId: req.user?._id,
        userRole: req.user?.role || 'owner',
      });
      return ApiResponse.success(res, result, result.chotuMessage || 'Command executed successfully', 200);
    } catch (error) {
      next(error);
    }
  }

  /**
   * Update product aliases for voice matching
   */
  async updateProductAliases(req, res, next) {
    try {
      const product = await productService.updateAliases(
        req.businessId,
        req.params.id,
        req.body.aliases
      );
      return ApiResponse.success(res, { product }, 'Product aliases updated successfully', 200);
    } catch (error) {
      next(error);
    }
  }

  /**
   * Health and status check for Chotu AI voice service
   */
  async health(req, res, next) {
    try {
      return ApiResponse.success(res, {
        status: 'active',
        assistantName: 'Chotu',
        version: '2.0.0',
        currentPhase: 3,
        supportedLanguages: ['English', 'Hindi', 'Hinglish'],
        orderFlowAutomationEnabled: true,
        posMutationsEnabled: true,
      }, 'Chotu AI Voice Assistant is online');
    } catch (error) {
      next(error);
    }
  }

  /**
   * Fetch Chotu audit logs
   */
  async getLogs(req, res, next) {
    try {
      const result = await chotuService.getActionLogs(req.businessId, req.query);
      return ApiResponse.success(res, result, 'Chotu logs retrieved successfully', 200);
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new ChotuController();
