const http = require('http');
const { io: Client } = require('socket.io-client');
const express = require('express');
const mongoose = require('mongoose');
const socketService = require('../src/services/socketService');

describe('Real-Time Table Status Synchronization Multi-Device Test', () => {
  let server;
  let serverPort;
  let clientSocketA;
  let clientSocketB;
  let clientSocketC;
  const mockBusinessId = new mongoose.Types.ObjectId().toString();

  beforeAll((done) => {
    const app = express();
    server = http.createServer(app);
    socketService.init(server);

    server.listen(() => {
      const port = server.address().port;
      serverPort = port;
      done();
    });
  });

  afterAll((done) => {
    if (clientSocketA) clientSocketA.disconnect();
    if (clientSocketB) clientSocketB.disconnect();
    if (clientSocketC) clientSocketC.disconnect();
    if (server) {
      server.close(done);
    } else {
      done();
    }
  });

  test('3 Devices (A, B, C) can connect and join the same business room', (done) => {
    const serverUrl = `http://localhost:${serverPort}`;

    let connectedCount = 0;
    const onJoin = () => {
      connectedCount++;
      if (connectedCount === 3) {
        done();
      }
    };

    clientSocketA = Client(serverUrl, {
      transports: ['websocket'],
      auth: { businessId: mockBusinessId },
    });

    clientSocketB = Client(serverUrl, {
      transports: ['websocket'],
      auth: { businessId: mockBusinessId },
    });

    clientSocketC = Client(serverUrl, {
      transports: ['websocket'],
      auth: { businessId: mockBusinessId },
    });

    clientSocketA.on('joined_business', (data) => {
      expect(data.businessId).toBe(mockBusinessId);
      onJoin();
    });

    clientSocketB.on('joined_business', (data) => {
      expect(data.businessId).toBe(mockBusinessId);
      onJoin();
    });

    clientSocketC.on('joined_business', (data) => {
      expect(data.businessId).toBe(mockBusinessId);
      onJoin();
    });
  });

  test('When Device A or Backend updates Table 1 status to occupied, Device B and C receive table:updated event instantly', (done) => {
    const updatedTablePayload = {
      id: 'tbl_001',
      tableNumber: 1,
      name: 'T-1',
      floor: 'Ground Floor',
      capacity: 4,
      status: 'occupied',
      occupiedSince: new Date().toISOString(),
    };

    let receivedB = false;
    let receivedC = false;

    const checkDone = () => {
      if (receivedB && receivedC) {
        clientSocketB.off('table:updated');
        clientSocketC.off('table:updated');
        done();
      }
    };

    clientSocketB.on('table:updated', (payload) => {
      expect(payload).toBeDefined();
      expect(payload.table).toBeDefined();
      expect(payload.table.name).toBe('T-1');
      expect(payload.table.status).toBe('occupied');
      receivedB = true;
      checkDone();
    });

    clientSocketC.on('table:updated', (payload) => {
      expect(payload).toBeDefined();
      expect(payload.table).toBeDefined();
      expect(payload.table.name).toBe('T-1');
      expect(payload.table.status).toBe('occupied');
      receivedC = true;
      checkDone();
    });

    // Server emits table updated to the business
    socketService.emitTableUpdated(mockBusinessId, updatedTablePayload);
  });

  test('When Device B changes Table 1 to available, Device A and C receive table:updated event instantly', (done) => {
    const freeTablePayload = {
      id: 'tbl_001',
      tableNumber: 1,
      name: 'T-1',
      floor: 'Ground Floor',
      capacity: 4,
      status: 'free',
      occupiedSince: null,
      activeOrderTotal: 0,
      activeItemCount: 0,
    };

    let receivedA = false;
    let receivedC = false;

    const checkDone = () => {
      if (receivedA && receivedC) {
        clientSocketA.off('table:updated');
        clientSocketC.off('table:updated');
        done();
      }
    };

    clientSocketA.on('table:updated', (payload) => {
      expect(payload.table.name).toBe('T-1');
      expect(payload.table.status).toBe('free');
      receivedA = true;
      checkDone();
    });

    clientSocketC.on('table:updated', (payload) => {
      expect(payload.table.name).toBe('T-1');
      expect(payload.table.status).toBe('free');
      receivedC = true;
      checkDone();
    });

    socketService.emitTableUpdated(mockBusinessId, freeTablePayload);
  });

  test('When Table is shifted, all devices receive tables:batch_updated with updated tables', (done) => {
    const shiftedTables = [
      {
        id: 'tbl_001',
        tableNumber: 1,
        name: 'T-1',
        status: 'free',
      },
      {
        id: 'tbl_002',
        tableNumber: 2,
        name: 'T-2',
        status: 'runningKot',
        activeOrderTotal: 450,
      },
    ];

    let receivedCount = 0;
    const onBatch = (payload) => {
      expect(payload.tables).toBeDefined();
      expect(payload.tables.length).toBe(2);
      expect(payload.tables[0].status).toBe('free');
      expect(payload.tables[1].status).toBe('runningKot');
      receivedCount++;
      if (receivedCount === 3) {
        clientSocketA.off('tables:batch_updated');
        clientSocketB.off('tables:batch_updated');
        clientSocketC.off('tables:batch_updated');
        done();
      }
    };

    clientSocketA.on('tables:batch_updated', onBatch);
    clientSocketB.on('tables:batch_updated', onBatch);
    clientSocketC.on('tables:batch_updated', onBatch);

    socketService.emitTablesBatchUpdated(mockBusinessId, shiftedTables);
  });

  test('When an order is settled, all devices receive order:settled and order:updated events', (done) => {
    const settledOrderData = {
      orderId: 'ord_999',
      orderNumber: 'ORD-999',
      tableNumber: 'T-3',
      totalAmount: 650,
      status: 'completed',
      paymentStatus: 'paid',
      paymentMethod: 'cash',
    };

    let settledCount = 0;
    let updatedCount = 0;

    const checkComplete = () => {
      if (settledCount === 2 && updatedCount === 2) {
        clientSocketB.off('order:settled');
        clientSocketC.off('order:settled');
        clientSocketB.off('order:updated');
        clientSocketC.off('order:updated');
        done();
      }
    };

    clientSocketB.on('order:settled', (payload) => {
      expect(payload.orderId).toBe('ord_999');
      expect(payload.tableNumber).toBe('T-3');
      expect(payload.status).toBe('completed');
      settledCount++;
      checkComplete();
    });

    clientSocketC.on('order:settled', (payload) => {
      expect(payload.orderId).toBe('ord_999');
      expect(payload.tableNumber).toBe('T-3');
      expect(payload.status).toBe('completed');
      settledCount++;
      checkComplete();
    });

    clientSocketB.on('order:updated', (payload) => {
      expect(payload.status).toBe('completed');
      updatedCount++;
      checkComplete();
    });

    clientSocketC.on('order:updated', (payload) => {
      expect(payload.status).toBe('completed');
      updatedCount++;
      checkComplete();
    });

    socketService.emitOrderSettled(mockBusinessId, settledOrderData);
    socketService.emitOrderUpdated(mockBusinessId, settledOrderData);
  });

  test('Ping-Pong heartbeat roundtrip succeeds', (done) => {
    clientSocketA.emit('ping_sync', { client: 'Device-A' }, (response) => {
      expect(response.status).toBe('ok');
      expect(response.echo.client).toBe('Device-A');
      expect(response.serverTime).toBeDefined();
      done();
    });
  });
});
