import 'package:flutter_test/flutter_test.dart';
import 'package:apna_pos/core/models/crm_model.dart';

void main() {
  group('CRM Lead Dynamic Data & Metric Tests', () {
    test('CrmLeadModel accurately parses totalOrders, visitCount, totalSpent and normalizes Dine In source to POS', () {
      final json = {
        'id': 'lead_123',
        'name': 'Rahul Sharma',
        'phone': '9876543210',
        'email': 'rahul@example.com',
        'address': 'Sector 62, Noida',
        'source': 'Dine In',
        'stage': 'Won',
        'status': 'Won',
        'customerType': 'Regular Customer',
        'tags': ['Regular Customer', 'POS'],
        'totalOrders': 7,
        'visitCount': 5,
        'totalSpent': 3450.50,
        'returnCount': 1,
        'createdAt': '2026-09-01T10:00:00.000Z',
        'lastVisit': '2026-09-18T19:30:00.000Z',
        'recentOrders': [
          {
            'id': 'INV-1001',
            'orderNumber': '1001',
            'totalAmount': 650.0,
            'status': 'completed',
            'date': '2026-09-18T19:30:00.000Z',
          }
        ],
      };

      final lead = CrmLeadModel.fromJson(json);

      expect(lead.id, 'lead_123');
      expect(lead.name, 'Rahul Sharma');
      expect(lead.phone, '9876543210');
      expect(lead.source, 'POS'); // Dine In normalized to POS
      expect(lead.totalOrders, 7);
      expect(lead.visitCount, 5);
      expect(lead.totalSpent, 3450.50);
      expect(lead.totalSpend, 3450.50);
      expect(lead.returnCount, 1);
      expect(lead.recentOrders.length, 1);
      expect(lead.recentOrders[0]['id'], 'INV-1001');
      expect(lead.isRegularCustomer, isTrue);
    });

    test('CrmLeadModel with 0 orders and 0 visits preserves 0 and does not fake 1', () {
      final json = {
        'id': 'lead_zero',
        'name': 'New Lead User',
        'phone': '9123456789',
        'totalOrders': 0,
        'visitCount': 0,
        'totalSpent': 0.0,
        'returnCount': 0,
      };

      final lead = CrmLeadModel.fromJson(json);

      expect(lead.totalOrders, 0);
      expect(lead.visitCount, 0);
      expect(lead.totalSpent, 0.0);
      expect(lead.totalSpend, 0.0);
      expect(lead.returnCount, 0);
      expect(lead.isRegularCustomer, isFalse);
    });

    test('CrmLeadModel serialization to JSON and copyWith preserve visitCount and spend', () {
      final original = CrmLeadModel(
        id: 'lead_copy',
        name: 'Anita',
        phone: '9988776655',
        totalOrders: 3,
        visitCount: 2,
        totalSpent: 1200.0,
        createdAt: DateTime.parse('2026-09-10T12:00:00Z'),
      );

      final copy = original.copyWith(
        visitCount: 4,
        totalOrders: 5,
        totalSpent: 2100.0,
        stage: 'Won',
      );

      expect(copy.visitCount, 4);
      expect(copy.totalOrders, 5);
      expect(copy.totalSpent, 2100.0);
      expect(copy.stage, 'Won');

      final serialized = copy.toJson();
      expect(serialized['visitCount'], 4);
      expect(serialized['totalOrders'], 5);
      expect(serialized['totalSpent'], 2100.0);
      expect(serialized['stage'], 'Won');
    });

    test('CrmStatsModel parses dynamic stats and trends correctly', () {
      final json = {
        'total': 42,
        'leads': 10,
        'prospects': 8,
        'deals': 6,
        'wins': 15,
        'lost': 3,
        'trends': {
          'total': '+14% this month',
          'leads': '+5% this month',
          'prospects': '+12% this month',
          'deals': '+3% this month',
          'wins': '+25% this month',
        }
      };

      final stats = CrmStatsModel.fromJson(json);

      expect(stats.total, 42);
      expect(stats.leads, 10);
      expect(stats.prospects, 8);
      expect(stats.deals, 6);
      expect(stats.wins, 15);
      expect(stats.lost, 3);
      expect(stats.trends.total, '+14% this month');
      expect(stats.trends.wins, '+25% this month');
    });

    test('CrmStatsModel handles null and string values cleanly without throwing', () {
      final json = {
        'total': '50',
        'leads': '15',
        'prospects': null,
        'deals': '5',
        'wins': 20,
        'lost': null,
      };

      final stats = CrmStatsModel.fromJson(json);

      expect(stats.total, 50);
      expect(stats.leads, 15);
      expect(stats.prospects, 0);
      expect(stats.deals, 5);
      expect(stats.wins, 20);
      expect(stats.lost, 0);
    });

    test('CrmLeadModel parses string-encoded numbers and null counts without throwing', () {
      final json = {
        'id': 'lead_str_counts',
        'name': 'Priya Singh',
        'phone': '9876500000',
        'totalOrders': '12',
        'visitCount': '8',
        'totalSpent': '4500.75',
        'returnCount': null,
      };

      final lead = CrmLeadModel.fromJson(json);

      expect(lead.totalOrders, 12);
      expect(lead.visitCount, 8);
      expect(lead.totalSpent, 4500.75);
      expect(lead.returnCount, 0);
    });

    test('CrmLeadModel normalizes all Dine In, Takeaway, Delivery sources to POS while preserving other channels', () {
      final dineInLead = CrmLeadModel.fromJson({'name': 'A', 'phone': '1', 'source': 'Dine In'});
      final takeawayLead = CrmLeadModel.fromJson({'name': 'B', 'phone': '2', 'source': 'takeaway'});
      final deliveryLead = CrmLeadModel.fromJson({'name': 'C', 'phone': '3', 'source': 'Delivery'});
      final emptySourceLead = CrmLeadModel.fromJson({'name': 'D', 'phone': '4', 'source': ''});
      final onlineLead = CrmLeadModel.fromJson({'name': 'E', 'phone': '5', 'source': 'Online'});
      final waLead = CrmLeadModel.fromJson({'name': 'F', 'phone': '6', 'source': 'WhatsApp'});

      expect(dineInLead.source, 'POS');
      expect(takeawayLead.source, 'POS');
      expect(deliveryLead.source, 'POS');
      expect(emptySourceLead.source, 'POS');
      expect(onlineLead.source, 'Online');
      expect(waLead.source, 'WhatsApp');
    });
  });
}

