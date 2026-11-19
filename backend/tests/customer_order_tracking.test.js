jest.mock('../src/services/notificationService', () => ({}));
const Order = require('../src/models/Order');
const Business = require('../src/models/Business');
const Table = require('../src/models/Table');
const controller = require('../src/controllers/storefrontController');

describe('public receipt status', () => {
  const id = 'aaaaaaaaaaaaaaaaaaaaaaaa';
  const request = () => ({ params: {slug:'tracking-cafe', orderId:id}, query: {orderNumber:'QR-001'} });
  const response = () => ({ set: jest.fn(), status: jest.fn().mockReturnThis(), json: jest.fn().mockReturnThis() });
  const query = value => ({ select: () => ({ lean: async () => value }) });
  afterEach(() => jest.restoreAllMocks());

  test('receipt lookup returns only status and recognizes the running KOT', async () => {
    jest.spyOn(Order, 'findOne').mockReturnValue(query({
      businessId: id, orderNumber: 'QR-001', status:'preparing', kotStatus:'not_sent',
      whatsappDetails: {acceptanceStatus:'accepted'}, customerPhone:'private',
    }));
    jest.spyOn(Business, 'findById').mockReturnValue(query({profile:{slug:'tracking-cafe'}}));
    jest.spyOn(Table, 'findOne').mockReturnValue(query({status:'runningKot'}));
    const res = response(), next = jest.fn();
    await controller.getOrderStatus(request(), res, next);
    expect(next).not.toHaveBeenCalled();
    const data = res.json.mock.calls[0][0].data;
    expect(data).toMatchObject({status:'preparing', kotStatus:'running', acceptanceStatus:'accepted'});
    expect(data.customerPhone).toBeUndefined();
    expect(res.set).toHaveBeenCalledWith('Cache-Control', 'no-store');
  });

  test('missing receipt identifier is rejected before reading any order', async () => {
    const read = jest.spyOn(Order, 'findOne');
    const req = request(); req.query = {};
    const next = jest.fn();
    await controller.getOrderStatus(req, response(), next);
    expect(next).toHaveBeenCalled();
    expect(read).not.toHaveBeenCalled();
  });

  test('another restaurant cannot expose the receipt status', async () => {
    jest.spyOn(Order, 'findOne').mockReturnValue(query({businessId:id,status:'cancelled'}));
    jest.spyOn(Business, 'findById').mockReturnValue(query({profile:{slug:'different-cafe'}}));
    const next = jest.fn();
    await controller.getOrderStatus(request(), response(), next);
    expect(next).toHaveBeenCalled();
  });
});
