# Chotu technology stack

Generated: 2026-11-12. Versions below are repository constraints, not a package audit.

| Runtime/package | Repository version | Role |
| --- | --- | --- |
| Flutter / Dart | Dart `^3.12.2` | Existing POS and Chotu surface |
| Python | New planner targets 3.11+ | Standard-library workflow policy; no pip dependencies |
| Node.js | `>=18` | Existing API and child-process host |
| Express | `^4.21.2` | HTTP routes and authentication |
| Mongoose | `^8.9.5` | MongoDB persistence and tenant-scoped queries |
| @google/genai | `^2.30.0` | Optional existing language understanding |
| Dio | `^5.11.0` | Flutter HTTP client |
| shared_preferences | `^2.2.2` | Pending turn persistence |
| Jest / Supertest | `^29.7.0` / `^7.0.0` | Backend verification |
| mongodb-memory-server | `^10.1.3` | Disposable test database |
| unittest | Python standard library | Workflow policy verification |

Existing integrations include MongoDB, table/order sockets, and optional Gemini.
The order agent adds no external provider or account. See TRD.md for configuration.
