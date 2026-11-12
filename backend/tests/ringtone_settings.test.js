jest.mock('../src/services/notificationService', () => ({}));
jest.mock('../src/services/pushNotificationService', () => ({}));
jest.mock('../src/services/cronService', () => ({}));
jest.mock('../src/utils/storageService', () => ({ uploadMedia: jest.fn() }));
const controller = require('../src/controllers/notificationController');
const Setting = require('../src/models/NotificationSetting');
const storage = require('../src/utils/storageService');

describe('custom ringtone settings', () => {
  const req = () => ({ user: { _id: 'user-1', businessId: 'business-1' }, body: {}, params: {}, headers: {} });
  const response = () => ({ status: jest.fn().mockReturnThis(), json: jest.fn().mockReturnThis() });
  afterEach(() => jest.restoreAllMocks());

  test('uploaded sound is registered in the current user library', async () => {
    const request = req();
    request.body = { name: 'Kitchen Bell', type: 'notification' };
    request.file = { originalname: 'bell.mp3', mimetype: 'audio/mpeg', buffer: Buffer.from('audio'), size: 5 };
    storage.uploadMedia.mockResolvedValue('https://example.com/bell.mp3');
    const update = jest.spyOn(Setting, 'findOneAndUpdate').mockResolvedValue({});
    const res = response();
    const next = jest.fn();
    await controller.uploadRingtone(request, res, next);
    expect(next).not.toHaveBeenCalled();
    expect(update.mock.calls[0][0]).toEqual({ businessId: 'business-1', userId: 'user-1' });
    expect(res.json.mock.calls[0][0].data.ringtone).toMatchObject({ name: 'Kitchen Bell', type: 'notification', url: 'https://example.com/bell.mp3' });
  });

  test('deleting shared active audio restores both defaults on the server', async () => {
    const request = req(); request.params.id = 'rt_1';
    jest.spyOn(Setting, 'findOne').mockReturnValue({ lean: async () => ({
      customRingtones: [{ id: 'rt_1', url: 'https://example.com/bell.mp3' }],
      orderRingtoneUrl: 'https://example.com/bell.mp3',
      notificationSoundUrl: 'https://example.com/bell.mp3',
    }) });
    const update = jest.spyOn(Setting, 'findOneAndUpdate').mockResolvedValue({});
    const next = jest.fn();
    await controller.deleteCustomRingtone(request, response(), next);
    expect(next).not.toHaveBeenCalled();
    expect(update.mock.calls[0][1].$set).toMatchObject({
      orderRingtone: 'default', orderRingtoneType: 'default',
      orderRingtoneUrl: 'sounds/order_recieve_ringtone.mp3',
      notificationSound: 'default', notificationSoundType: 'default',
      notificationSoundUrl: 'sounds/Notification_sound.mp3',
    });
  });

  test('custom type is valid for persisted order and notification sounds', () => {
    const setting = new Setting({ businessId: '507f1f77bcf86cd799439011', userId: '507f1f77bcf86cd799439012', orderRingtoneType: 'custom', notificationSoundType: 'custom' });
    expect(setting.validateSync()).toBeUndefined();
  });
});
