/**
 * In-Memory Database Store Fallback
 * Used automatically when MongoDB service is not running locally.
 */

const memoryStore = {
  users: new Map(),
  sessions: new Map(),
  otps: new Map(),
};

class MemoryUser {
  static findOne(query) {
    const exec = async () => {
      for (const user of memoryStore.users.values()) {
        if (query.email && user.email === query.email.toLowerCase()) return new MemoryUser(user);
        if (query.phone && user.phone === query.phone) return new MemoryUser(user);
        if (query.$or) {
          for (const cond of query.$or) {
            if (cond.email && user.email === cond.email.toLowerCase()) return new MemoryUser(user);
            if (cond.phone && user.phone === cond.phone) return new MemoryUser(user);
          }
        }
      }
      return null;
    };

    const promise = exec();
    promise.select = () => promise;
    return promise;
  }

  static async findById(id) {
    const user = memoryStore.users.get(id.toString());
    return user ? new MemoryUser(user) : null;
  }

  static async create(data) {
    const id = `user_mem_${Date.now()}_${Math.floor(Math.random() * 1000)}`;
    const userDoc = {
      _id: id,
      id: id,
      name: data.name,
      email: data.email ? data.email.toLowerCase() : undefined,
      phone: data.phone,
      passwordHash: data.passwordHash,
      businessName: data.businessName || '',
      isVerified: data.isVerified ?? false,
      role: data.role || 'owner',
      createdAt: new Date(),
      updatedAt: new Date(),
    };
    memoryStore.users.set(id, userDoc);
    return new MemoryUser(userDoc);
  }

  constructor(doc) {
    Object.assign(this, doc);
  }

  select(fields) {
    return this;
  }

  async save() {
    this.updatedAt = new Date();
    memoryStore.users.set(this._id, { ...this });
    return this;
  }
}

class MemorySession {
  static async findOne(query) {
    for (const session of memoryStore.sessions.values()) {
      if (
        session.userId.toString() === query.userId.toString() &&
        session.deviceId === query.deviceId
      ) {
        return new MemorySession(session);
      }
    }
    return null;
  }

  static async find(query) {
    const results = [];
    for (const session of memoryStore.sessions.values()) {
      if (session.userId.toString() === query.userId.toString()) {
        results.push(new MemorySession(session));
      }
    }
    return results;
  }

  static async findOneAndUpdate(filter, update, options) {
    let key = `${filter.userId}_${filter.deviceId}`;
    let session = memoryStore.sessions.get(key);

    if (!session) {
      session = {
        _id: `sess_mem_${Date.now()}_${Math.floor(Math.random() * 1000)}`,
        userId: filter.userId,
        deviceId: filter.deviceId,
        createdAt: new Date(),
      };
    }

    Object.assign(session, update, { lastActiveAt: new Date() });
    memoryStore.sessions.set(key, session);
    return new MemorySession(session);
  }

  static async deleteOne(query) {
    let deletedCount = 0;
    for (const [key, session] of memoryStore.sessions.entries()) {
      if (
        session.userId.toString() === query.userId.toString() &&
        session.deviceId === query.deviceId
      ) {
        memoryStore.sessions.delete(key);
        deletedCount++;
      }
    }
    return { deletedCount };
  }

  static async deleteMany(query) {
    let deletedCount = 0;
    for (const [key, session] of memoryStore.sessions.entries()) {
      if (session.userId.toString() === query.userId.toString()) {
        memoryStore.sessions.delete(key);
        deletedCount++;
      }
    }
    return { deletedCount };
  }

  constructor(doc) {
    Object.assign(this, doc);
  }

  async save() {
    let key = `${this.userId}_${this.deviceId}`;
    this.updatedAt = new Date();
    memoryStore.sessions.set(key, { ...this });
    return this;
  }

  sort() {
    return Array.from(memoryStore.sessions.values()).filter(
      (s) => s.userId.toString() === this.userId.toString()
    );
  }
}


class MemoryOtp {
  static async deleteMany(query) {
    for (const [key, otp] of memoryStore.otps.entries()) {
      if (otp.phone === query.phone) {
        memoryStore.otps.delete(key);
      }
    }
  }

  static async create(data) {
    const key = `${data.phone}_${data.purpose || 'login'}`;
    const otpDoc = {
      _id: `otp_mem_${Date.now()}`,
      phone: data.phone,
      otpHash: data.otpHash,
      purpose: data.purpose || 'login',
      attempts: 0,
      expiresAt: data.expiresAt,
      createdAt: new Date(),
    };
    memoryStore.otps.set(key, otpDoc);
    return new MemoryOtp(otpDoc);
  }

  static findOne(query) {
    return {
      sort: () => {
        for (const otp of memoryStore.otps.values()) {
          if (otp.phone === query.phone) {
            return new MemoryOtp(otp);
          }
        }
        return null;
      },
    };
  }

  static async deleteOne(query) {
    for (const [key, otp] of memoryStore.otps.entries()) {
      if (otp._id === query._id) {
        memoryStore.otps.delete(key);
      }
    }
  }

  constructor(doc) {
    Object.assign(this, doc);
  }

  async save() {
    const key = `${this.phone}_${this.purpose || 'login'}`;
    memoryStore.otps.set(key, { ...this });
    return this;
  }
}

module.exports = {
  MemoryUser,
  MemorySession,
  MemoryOtp,
};
