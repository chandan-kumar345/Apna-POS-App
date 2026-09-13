const request = require('supertest');
const app = require('../src/app');
const Product = require('../src/models/Product');
const Cart = require('../src/models/Cart');
const Table = require('../src/models/Table');
const ChotuActionLog = require('../src/models/ChotuActionLog');
require('./setup');

describe('Chotu AI Voice Assistant - Automated Order Flow (/api/v1/chotu)', () => {
  let token;
  let businessId;
  let butterNaan;
  let paneerTikka;
  let dalMakhani;
  let coke750;

  beforeEach(async () => {
    // 1. Register restaurant owner
    const res = await request(app)
      .post('/api/v1/auth/register')
      .send({
        email: `chotu_pos_${Date.now()}@example.com`,
        password: 'Password@123',
        restaurantName: 'Chotu Express Dhaba',
      });

    token = res.body.data.accessToken;

    // 2. Seed test products
    const p1 = await request(app)
      .post('/api/v1/products')
      .set('Authorization', `Bearer ${token}`)
      .send({
        name: 'Butter Naan',
        category: 'Breads',
        price: 40,
        aliases: ['naan', 'butter nan', 'nan butter'],
      });
    butterNaan = p1.body.data.product;

    const p2 = await request(app)
      .post('/api/v1/products')
      .set('Authorization', `Bearer ${token}`)
      .send({
        name: 'Paneer Tikka',
        category: 'Starters',
        price: 240,
        aliases: ['paneer tikka ji', 'tikka paneer'],
      });
    paneerTikka = p2.body.data.product;

    const p3 = await request(app)
      .post('/api/v1/products')
      .set('Authorization', `Bearer ${token}`)
      .send({
        name: 'Dal Makhani',
        category: 'Main Course',
        price: 260,
      });
    dalMakhani = p3.body.data.product;

    const p4 = await request(app)
      .post('/api/v1/products')
      .set('Authorization', `Bearer ${token}`)
      .send({
        name: 'Coca Cola 750ml',
        category: 'Beverages',
        price: 60,
        aliases: ['coke', 'coca cola', 'cola', 'coke 750'],
      });
    coke750 = p4.body.data.product;
  });

  describe('Product Alias Management (PUT /api/v1/chotu/products/:id/aliases)', () => {
    it('should allow restaurant admins to update product aliases', async () => {
      const res = await request(app)
        .put(`/api/v1/chotu/products/${dalMakhani.id}/aliases`)
        .set('Authorization', `Bearer ${token}`)
        .send({
          aliases: ['makhani dal', 'dal', 'special dal'],
        });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.product.aliases).toContain('makhani dal');
      expect(res.body.data.product.aliases).toContain('special dal');
    });
  });

  describe('AI Command Engine Parsing (POST /api/v1/chotu/parse)', () => {
    it('should parse natural Hinglish ADD_ITEM command with multiple quantities', async () => {
      const res = await request(app)
        .post('/api/v1/chotu/parse')
        .set('Authorization', `Bearer ${token}`)
        .send({
          text: 'Table 5 pe do butter naan aur ek paneer tikka laga do',
          sessionId: 'test_session_flow_1',
        });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);

      const cmd = res.body.data.command;
      expect(cmd.intent).toBe('ADD_ITEM');
      expect(cmd.table_number).toBe('5');
      expect(cmd.items.length).toBe(2);

      const naanItem = cmd.items.find((i) => i.product_name === 'Butter Naan');
      expect(naanItem).toBeDefined();
      expect(naanItem.quantity).toBe(2);
      expect(naanItem.matched).toBe(true);

      const paneerItem = cmd.items.find((i) => i.product_name === 'Paneer Tikka');
      expect(paneerItem).toBeDefined();
      expect(paneerItem.quantity).toBe(1);
      expect(paneerItem.matched).toBe(true);

      expect(cmd.chotu_response).toContain('Table 5');
    });

    it('should match products by alias (spoken "coke" -> "Coca Cola 750ml")', async () => {
      const res = await request(app)
        .post('/api/v1/chotu/parse')
        .set('Authorization', `Bearer ${token}`)
        .send({
          text: 'Table 12 mein ek coke aur add karo',
        });

      expect(res.status).toBe(200);
      const cmd = res.body.data.command;
      expect(cmd.intent).toBe('ADD_ITEM');
      expect(cmd.table_number).toBe('12');

      const cokeItem = cmd.items.find((i) => i.product_name === 'Coca Cola 750ml');
      expect(cokeItem).toBeDefined();
      expect(cokeItem.quantity).toBe(1);
      expect(cokeItem.matched).toBe(true);
    });

    it('should distinguish UPDATE_QUANTITY ("Butter naan ko 4 kar do") from ADD_ITEM', async () => {
      const res = await request(app)
        .post('/api/v1/chotu/parse')
        .set('Authorization', `Bearer ${token}`)
        .send({
          text: 'Butter naan ko 4 kar do',
          currentTableContext: '5',
        });

      expect(res.status).toBe(200);
      const cmd = res.body.data.command;
      expect(cmd.intent).toBe('UPDATE_QUANTITY');
      expect(cmd.quantity).toBe(4);
      expect(cmd.item.product_name).toBe('Butter Naan');
      expect(cmd.table_number).toBe('5');
    });

    it('should parse REMOVE_ITEM command ("Table 4 se ek butter naan hata do")', async () => {
      const res = await request(app)
        .post('/api/v1/chotu/parse')
        .set('Authorization', `Bearer ${token}`)
        .send({
          text: 'Table 4 se ek butter naan hata do',
        });

      expect(res.status).toBe(200);
      const cmd = res.body.data.command;
      expect(cmd.intent).toBe('REMOVE_ITEM');
      expect(cmd.table_number).toBe('4');
      expect(cmd.quantity).toBe(1);
      expect(cmd.item.product_name).toBe('Butter Naan');
    });

    it('should parse CHECK_ITEM_AVAILABILITY command', async () => {
      const res = await request(app)
        .post('/api/v1/chotu/parse')
        .set('Authorization', `Bearer ${token}`)
        .send({
          text: 'Kya dal makhani available hai?',
        });

      expect(res.status).toBe(200);
      const cmd = res.body.data.command;
      expect(cmd.intent).toBe('CHECK_ITEM_AVAILABILITY');
      expect(cmd.product.name).toBe('Dal Makhani');
      expect(cmd.product.isAvailable).toBe(true);
      expect(cmd.chotu_response).toContain('Dal Makhani available hai');
    });

    it('should maintain short-term table context across turns (Turn 1 -> Turn 2)', async () => {
      const sessionId = `context_session_${Date.now()}`;

      // Turn 1: Staff specifies table 8
      const turn1 = await request(app)
        .post('/api/v1/chotu/parse')
        .set('Authorization', `Bearer ${token}`)
        .send({
          text: 'Table 8 pe ek paneer tikka',
          sessionId,
        });

      expect(turn1.body.data.command.table_number).toBe('8');

      // Turn 2: Staff says "Ek coke bhi" without mentioning table
      const turn2 = await request(app)
        .post('/api/v1/chotu/parse')
        .set('Authorization', `Bearer ${token}`)
        .send({
          text: 'Ek coke bhi',
          sessionId,
        });

      expect(turn2.body.data.command.table_number).toBe('8');
      expect(turn2.body.data.command.items[0].product_name).toBe('Coca Cola 750ml');
    });

    it('should detect ambiguity when multiple sizes match ("Coke 300ml" vs "Coke 750ml")', async () => {
      // Add second Coke size
      await request(app)
        .post('/api/v1/products')
        .set('Authorization', `Bearer ${token}`)
        .send({
          name: 'Coca Cola 300ml',
          category: 'Beverages',
          price: 35,
          aliases: ['coke 300', 'coke small', 'cola'],
        });

      const res = await request(app)
        .post('/api/v1/chotu/parse')
        .set('Authorization', `Bearer ${token}`)
        .send({
          text: 'Table 5 pe ek cola add karo',
        });

      expect(res.status).toBe(200);
      const cmd = res.body.data.command;
      expect(cmd.ambiguity).toBe(true);
      expect(cmd.question).toContain('Kaunsa add karna hai?');
    });
  });

  describe('Automated POS Command Execution (POST /api/v1/chotu/execute)', () => {
    it('should execute ADD_ITEM command and mutate cart via existing CartService', async () => {
      // 1. Parse command first
      const parseRes = await request(app)
        .post('/api/v1/chotu/parse')
        .set('Authorization', `Bearer ${token}`)
        .send({
          text: 'Table 5 pe do butter naan aur ek paneer tikka laga do',
        });

      const parsedCmd = parseRes.body.data.command;

      // 2. Execute parsed command
      const execRes = await request(app)
        .post('/api/v1/chotu/execute')
        .set('Authorization', `Bearer ${token}`)
        .send({
          commandId: `cmd_${Date.now()}`,
          command: parsedCmd,
        });

      expect(execRes.status).toBe(200);
      expect(execRes.body.success).toBe(true);
      expect(execRes.body.data.addedItems.length).toBe(2);
      expect(execRes.body.data.cart).toBeDefined();

      // Check authoritative cart in database
      const cart = await Cart.findOne({
        tableNumber: 'T-5',
        orderType: 'dineIn',
      });
      expect(cart).not.toBeNull();
      expect(cart.items.length).toBe(2);

      const naanInCart = cart.items.find((i) => i.name === 'Butter Naan');
      expect(naanInCart.quantity).toBe(2);

      // Verify audit log recorded actionStatus = executed
      const logs = await ChotuActionLog.find({ actionStatus: 'executed' });
      expect(logs.length).toBeGreaterThanOrEqual(1);
    });

    it('should enforce idempotency and prevent duplicate command execution', async () => {
      const fixedCmdId = `cmd_idempotency_${Date.now()}`;
      const cmd = {
        intent: 'ADD_ITEM',
        table_number: '7',
        items: [
          {
            product_id: butterNaan.id,
            product_name: 'Butter Naan',
            quantity: 2,
          },
        ],
      };

      // First execution
      const res1 = await request(app)
        .post('/api/v1/chotu/execute')
        .set('Authorization', `Bearer ${token}`)
        .send({
          commandId: fixedCmdId,
          command: cmd,
        });
      expect(res1.status).toBe(200);
      expect(res1.body.data.isDuplicate).toBeFalsy();

      // Second identical execution with same commandId
      const res2 = await request(app)
        .post('/api/v1/chotu/execute')
        .set('Authorization', `Bearer ${token}`)
        .send({
          commandId: fixedCmdId,
          command: cmd,
        });
      expect(res2.status).toBe(200);
      expect(res2.body.data.isDuplicate).toBe(true);
      expect(res2.body.data.message).toContain('idempotent');
    });
  });
});
