const http = require('http');
const { io } = require('socket.io-client');
const service = require('../src/services/socketService');

describe('table order decisions across devices', () => {
  let server;
  const clients = [];
  beforeAll(async () => {
    server = http.createServer();
    service.init(server);
    await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  });
  afterAll(async () => {
    clients.forEach((client) => client.disconnect());
    await new Promise((resolve) => service.io.close(resolve));
    service.io = null;
  });
  async function connect(business) {
    const client = io(`http://127.0.0.1:${server.address().port}`, {
      auth: { businessId: business }, transports: ['websocket'], forceNew: true,
    });
    clients.push(client);
    await new Promise((resolve, reject) => {
      client.once('connect', resolve);
      client.once('connect_error', reject);
    });
    return client;
  }
  for (const action of ['accepted', 'rejected']) {
    test(`${action} reaches all devices in the same business`, async () => {
      const a = await connect('table-business');
      const b = await connect('table-business');
      const other = await connect('other-business');
      const wrongTenant = jest.fn();
      other.on('whatsapp:order:dismiss', wrongTenant);
      const receive = (client) => new Promise((resolve) =>
        client.once('whatsapp:order:dismiss', resolve));
      const received = Promise.all([receive(a), receive(b)]);
      const order = { _id: 'order-T01', orderNumber: 'QR-001', status: action === 'accepted' ? 'preparing' : 'cancelled' };
      if (action === 'accepted') service.emitWhatsAppOrderAccepted('table-business', { order, prepTimeMinutes: 20 });
      else service.emitWhatsAppOrderRejected('table-business', { order, reason: 'Kitchen closed' });
      for (const payload of await received) {
        expect(payload).toMatchObject({ orderId: order._id, orderNumber: order.orderNumber, action });
      }
      await new Promise((resolve) => setTimeout(resolve, 30));
      expect(wrongTenant).not.toHaveBeenCalled();
      a.disconnect(); b.disconnect(); other.disconnect();
    });
  }
});
