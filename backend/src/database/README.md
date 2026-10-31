# PostgreSQL Database

The initial relational schema is in `migrations/001_initial_schema.sql`.

## Apply migrations

1. Copy `.env.example` to `.env`.
2. Set `DATABASE_URL` to the Supabase PostgreSQL connection string.
3. Run:

```bash
npm run db:migrate
```

The migration runner creates a `schema_migrations` table and applies each SQL migration once inside a transaction. The same SQL file can also be pasted into the Supabase SQL Editor.

## Schema conventions

- UUID primary keys are generated with PostgreSQL `pgcrypto`.
- Money is stored as integer minor units, such as cents.
- Commercial line items store product, variant, plan, tax, and discount snapshots in JSONB so historical documents do not change when catalog data changes.
- Foreign keys use restrictive deletion for financial records and cascading deletion for owned child records.
- Partial indexes support active billing, overdue invoice, pending dunning, and outbox worker queries.
- The unique subscription and billing-period constraint makes invoice generation idempotent.
