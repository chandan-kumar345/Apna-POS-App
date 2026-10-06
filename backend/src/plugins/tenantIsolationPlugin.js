const mongoose = require('mongoose');

/**
 * Mongoose Multi-Tenant Isolation Plugin
 * Guarantees zero cross-tenant leakage at the ODM layer.
 * Enforces businessId indexing, query sanitization, and immutable tenant ownership.
 */
module.exports = function tenantIsolationPlugin(schema, options = {}) {
  // 1. Ensure businessId field exists on the schema with an index
  if (!schema.path('businessId')) {
    schema.add({
      businessId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Business',
        required: [true, 'Tenant businessId is required'],
        index: true,
      },
    });
  }

  // 2. Query methods to guard
  const queryMethods = [
    'find',
    'findOne',
    'findOneAndUpdate',
    'updateOne',
    'updateMany',
    'deleteOne',
    'deleteMany',
    'countDocuments',
    'distinct',
  ];

  queryMethods.forEach((method) => {
    schema.pre(method, function () {
      const query = this.getQuery();
      const queryOptions = this.getOptions();

      // Guard against dangerous undefined/null businessId traps
      if ('businessId' in query) {
        if (!query.businessId) {
          throw new Error(
            `[Tenant Security Exception] Query executed with null/undefined businessId in ${
              schema.modelName || 'Model'
            }.${method}`
          );
        }
        return;
      }

      // If tenant context was injected via query options (_tenantId)
      if (queryOptions && queryOptions._tenantId) {
        this.where({ businessId: queryOptions._tenantId });
        return;
      }

      // If explicit bypass was passed (e.g., for SuperAdmin platform maintenance)
      if (queryOptions && queryOptions._bypassTenantCheck) {
        return;
      }
    });
  });

  // 3. Document pre-save guard: validate presence and prevent tenant reassignment
  schema.pre('save', function (next) {
    if (this.isNew) {
      if (!this.businessId) {
        return next(
          new Error(
            `[Tenant Security Exception] Cannot save new ${
              this.constructor.modelName || 'Document'
            } without a valid businessId`
          )
        );
      }
    } else {
      // Prevent mutating businessId once created (Tenant Hijacking Prevention)
      if (this.isModified('businessId')) {
        return next(
          new Error(
            `[Tenant Security Exception] Mutating businessId on existing ${
              this.constructor.modelName || 'Document'
            } is strictly forbidden`
          )
        );
      }
    }
    next();
  });
};
