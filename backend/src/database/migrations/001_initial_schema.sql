CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TYPE user_role AS ENUM ('ADMIN', 'STAFF', 'CUSTOMER');
CREATE TYPE user_status AS ENUM ('ACTIVE', 'INACTIVE', 'SUSPENDED');
CREATE TYPE product_type AS ENUM ('SUBSCRIPTION', 'ADD_ON', 'PRODUCT');
CREATE TYPE billing_cycle AS ENUM ('DAILY', 'WEEKLY', 'MONTHLY', 'YEARLY');
CREATE TYPE quotation_status AS ENUM ('DRAFT', 'QUOTATION', 'CONFIRMED', 'ACTIVE', 'CLOSED');
CREATE TYPE subscription_status AS ENUM ('DRAFT', 'QUOTATION', 'CONFIRMED', 'ACTIVE', 'PAUSED', 'CANCELLED', 'CLOSED');
CREATE TYPE lifecycle_action AS ENUM ('RENEW', 'PAUSE', 'CLOSE');
CREATE TYPE lifecycle_event_type AS ENUM ('CREATED', 'QUOTED', 'CONFIRMED', 'ACTIVATED', 'BILLED', 'PAUSED', 'RESUMED', 'RENEWED', 'UPGRADED', 'DOWNGRADED', 'CANCELLED', 'CLOSED');
CREATE TYPE discount_type AS ENUM ('FIXED', 'PERCENTAGE');
CREATE TYPE tax_type AS ENUM ('PERCENTAGE', 'FIXED');
CREATE TYPE invoice_status AS ENUM ('DRAFT', 'CONFIRMED', 'PARTIALLY_PAID', 'PAID', 'OVERDUE', 'VOID');
CREATE TYPE payment_method AS ENUM ('CASH', 'BANK_TRANSFER', 'CARD', 'UPI', 'CHEQUE', 'OTHER');
CREATE TYPE dunning_status AS ENUM ('PENDING', 'PROCESSING', 'SENT', 'FAILED', 'SKIPPED');
CREATE TYPE outbox_event_type AS ENUM ('EMAIL', 'WEBHOOK');
CREATE TYPE outbox_status AS ENUM ('PENDING', 'PROCESSING', 'SENT', 'FAILED');
CREATE TYPE churn_risk_level AS ENUM ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL');

CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(320) NOT NULL,
  password_hash TEXT NOT NULL,
  role user_role NOT NULL DEFAULT 'CUSTOMER',
  status user_status NOT NULL DEFAULT 'ACTIVE',
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_login_at TIMESTAMPTZ,
  CONSTRAINT users_email_unique UNIQUE (email),
  CONSTRAINT users_email_lowercase CHECK (email = LOWER(email))
);

CREATE TABLE password_reset_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL UNIQUE,
  expires_at TIMESTAMPTZ NOT NULL,
  used_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE customers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID UNIQUE REFERENCES users(id) ON DELETE SET NULL,
  legal_name VARCHAR(200) NOT NULL,
  display_name VARCHAR(200) NOT NULL,
  tax_id VARCHAR(100),
  billing_email VARCHAR(320),
  phone VARCHAR(50),
  billing_address JSONB NOT NULL DEFAULT '{}'::JSONB,
  shipping_address JSONB NOT NULL DEFAULT '{}'::JSONB,
  metadata JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE customer_contacts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL,
  email VARCHAR(320) NOT NULL,
  phone VARCHAR(50),
  job_title VARCHAR(150),
  is_primary BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(200) NOT NULL,
  sku VARCHAR(100) UNIQUE,
  product_type product_type NOT NULL,
  sales_price_minor BIGINT NOT NULL DEFAULT 0,
  cost_price_minor BIGINT NOT NULL DEFAULT 0,
  currency CHAR(3) NOT NULL DEFAULT 'USD',
  notes TEXT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT products_sales_price_non_negative CHECK (sales_price_minor >= 0),
  CONSTRAINT products_cost_price_non_negative CHECK (cost_price_minor >= 0),
  CONSTRAINT products_currency_format CHECK (currency ~ '^[A-Z]{3}$')
);

CREATE TABLE product_variants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  name VARCHAR(200) NOT NULL,
  sku VARCHAR(100) UNIQUE,
  price_adjustment_minor BIGINT NOT NULL DEFAULT 0,
  cost_adjustment_minor BIGINT NOT NULL DEFAULT 0,
  metadata JSONB NOT NULL DEFAULT '{}'::JSONB,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT product_variants_name_unique UNIQUE (product_id, name)
);

CREATE TABLE plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(200) NOT NULL,
  code VARCHAR(100) NOT NULL UNIQUE,
  description TEXT,
  billing_cycle billing_cycle NOT NULL,
  billing_interval INTEGER NOT NULL DEFAULT 1,
  minimum_quantity INTEGER NOT NULL DEFAULT 1,
  price_minor BIGINT NOT NULL,
  currency CHAR(3) NOT NULL DEFAULT 'USD',
  available_from DATE,
  available_until DATE,
  auto_renew BOOLEAN NOT NULL DEFAULT TRUE,
  auto_pause BOOLEAN NOT NULL DEFAULT FALSE,
  auto_close BOOLEAN NOT NULL DEFAULT FALSE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT plans_interval_positive CHECK (billing_interval > 0),
  CONSTRAINT plans_minimum_quantity_positive CHECK (minimum_quantity > 0),
  CONSTRAINT plans_price_non_negative CHECK (price_minor >= 0),
  CONSTRAINT plans_availability_range CHECK (available_until IS NULL OR available_from IS NULL OR available_until >= available_from),
  CONSTRAINT plans_currency_format CHECK (currency ~ '^[A-Z]{3}$')
);

CREATE TABLE plan_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id UUID NOT NULL REFERENCES plans(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
  variant_id UUID REFERENCES product_variants(id) ON DELETE RESTRICT,
  quantity INTEGER NOT NULL DEFAULT 1,
  unit_price_minor BIGINT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT plan_items_quantity_positive CHECK (quantity > 0),
  CONSTRAINT plan_items_price_non_negative CHECK (unit_price_minor >= 0)
);

CREATE TABLE quotation_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(200) NOT NULL,
  description TEXT,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE quotations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  quotation_number VARCHAR(50) NOT NULL UNIQUE,
  customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
  template_id UUID REFERENCES quotation_templates(id) ON DELETE SET NULL,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  status quotation_status NOT NULL DEFAULT 'DRAFT',
  valid_until DATE,
  currency CHAR(3) NOT NULL DEFAULT 'USD',
  subtotal_minor BIGINT NOT NULL DEFAULT 0,
  discount_minor BIGINT NOT NULL DEFAULT 0,
  tax_minor BIGINT NOT NULL DEFAULT 0,
  total_minor BIGINT NOT NULL DEFAULT 0,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT quotations_totals_non_negative CHECK (subtotal_minor >= 0 AND discount_minor >= 0 AND tax_minor >= 0 AND total_minor >= 0),
  CONSTRAINT quotations_currency_format CHECK (currency ~ '^[A-Z]{3}$')
);

CREATE TABLE quotation_lines (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  quotation_id UUID NOT NULL REFERENCES quotations(id) ON DELETE CASCADE,
  product_id UUID REFERENCES products(id) ON DELETE SET NULL,
  variant_id UUID REFERENCES product_variants(id) ON DELETE SET NULL,
  plan_id UUID REFERENCES plans(id) ON DELETE SET NULL,
  description TEXT NOT NULL,
  quantity INTEGER NOT NULL,
  unit_price_minor BIGINT NOT NULL,
  product_snapshot JSONB NOT NULL DEFAULT '{}'::JSONB,
  variant_snapshot JSONB NOT NULL DEFAULT '{}'::JSONB,
  plan_snapshot JSONB NOT NULL DEFAULT '{}'::JSONB,
  line_total_minor BIGINT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT quotation_lines_quantity_positive CHECK (quantity > 0),
  CONSTRAINT quotation_lines_price_non_negative CHECK (unit_price_minor >= 0 AND line_total_minor >= 0),
  CONSTRAINT quotation_lines_source_present CHECK (product_id IS NOT NULL OR plan_id IS NOT NULL)
);

CREATE TABLE subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  subscription_number VARCHAR(50) NOT NULL UNIQUE,
  customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
  quotation_id UUID UNIQUE REFERENCES quotations(id) ON DELETE SET NULL,
  plan_id UUID REFERENCES plans(id) ON DELETE RESTRICT,
  status subscription_status NOT NULL DEFAULT 'DRAFT',
  billing_cycle billing_cycle NOT NULL,
  billing_interval INTEGER NOT NULL DEFAULT 1,
  currency CHAR(3) NOT NULL DEFAULT 'USD',
  start_date DATE NOT NULL,
  end_date DATE,
  next_billing_at TIMESTAMPTZ,
  auto_renew BOOLEAN NOT NULL DEFAULT TRUE,
  auto_pause BOOLEAN NOT NULL DEFAULT FALSE,
  auto_close BOOLEAN NOT NULL DEFAULT FALSE,
  cancelled_at TIMESTAMPTZ,
  cancellation_reason TEXT,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT subscriptions_interval_positive CHECK (billing_interval > 0),
  CONSTRAINT subscriptions_date_range CHECK (end_date IS NULL OR end_date >= start_date),
  CONSTRAINT subscriptions_currency_format CHECK (currency ~ '^[A-Z]{3}$')
);

CREATE TABLE subscription_lines (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  subscription_id UUID NOT NULL REFERENCES subscriptions(id) ON DELETE CASCADE,
  product_id UUID REFERENCES products(id) ON DELETE SET NULL,
  variant_id UUID REFERENCES product_variants(id) ON DELETE SET NULL,
  plan_id UUID REFERENCES plans(id) ON DELETE SET NULL,
  description TEXT NOT NULL,
  quantity INTEGER NOT NULL,
  unit_price_minor BIGINT NOT NULL,
  product_snapshot JSONB NOT NULL DEFAULT '{}'::JSONB,
  variant_snapshot JSONB NOT NULL DEFAULT '{}'::JSONB,
  plan_snapshot JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT subscription_lines_quantity_positive CHECK (quantity > 0),
  CONSTRAINT subscription_lines_price_non_negative CHECK (unit_price_minor >= 0),
  CONSTRAINT subscription_lines_source_present CHECK (product_id IS NOT NULL OR plan_id IS NOT NULL)
);

CREATE TABLE subscription_lifecycle_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  subscription_id UUID NOT NULL REFERENCES subscriptions(id) ON DELETE CASCADE,
  event_type lifecycle_event_type NOT NULL,
  from_status subscription_status,
  to_status subscription_status,
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  actor_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  metadata JSONB NOT NULL DEFAULT '{}'::JSONB
);

CREATE TABLE discount_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(200) NOT NULL,
  code VARCHAR(100) NOT NULL UNIQUE,
  discount_type discount_type NOT NULL,
  value_minor BIGINT,
  percentage_basis_points INTEGER,
  minimum_quantity INTEGER NOT NULL DEFAULT 1,
  valid_from TIMESTAMPTZ,
  valid_until TIMESTAMPTZ,
  usage_limit INTEGER,
  usage_count INTEGER NOT NULL DEFAULT 0,
  per_customer_limit INTEGER,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT discount_rules_quantity_positive CHECK (minimum_quantity > 0),
  CONSTRAINT discount_rules_fixed_value_valid CHECK (discount_type <> 'FIXED' OR (value_minor IS NOT NULL AND value_minor >= 0)),
  CONSTRAINT discount_rules_percentage_valid CHECK (discount_type <> 'PERCENTAGE' OR (percentage_basis_points IS NOT NULL AND percentage_basis_points BETWEEN 0 AND 10000)),
  CONSTRAINT discount_rules_usage_valid CHECK (usage_limit IS NULL OR (usage_limit >= 0 AND usage_count <= usage_limit)),
  CONSTRAINT discount_rules_date_range CHECK (valid_until IS NULL OR valid_from IS NULL OR valid_until >= valid_from)
);

CREATE TABLE discount_applications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  discount_rule_id UUID NOT NULL REFERENCES discount_rules(id) ON DELETE RESTRICT,
  customer_id UUID REFERENCES customers(id) ON DELETE SET NULL,
  quotation_id UUID REFERENCES quotations(id) ON DELETE CASCADE,
  subscription_id UUID REFERENCES subscriptions(id) ON DELETE CASCADE,
  invoice_id UUID,
  discount_amount_minor BIGINT NOT NULL,
  applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT discount_applications_amount_non_negative CHECK (discount_amount_minor >= 0),
  CONSTRAINT discount_applications_document_present CHECK (quotation_id IS NOT NULL OR subscription_id IS NOT NULL OR invoice_id IS NOT NULL)
);

CREATE TABLE tax_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(200) NOT NULL,
  code VARCHAR(100) NOT NULL UNIQUE,
  tax_type tax_type NOT NULL,
  rate_basis_points INTEGER,
  fixed_amount_minor BIGINT,
  country_code CHAR(2),
  region_code VARCHAR(20),
  valid_from TIMESTAMPTZ,
  valid_until TIMESTAMPTZ,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT tax_rules_percentage_valid CHECK (tax_type <> 'PERCENTAGE' OR (rate_basis_points IS NOT NULL AND rate_basis_points BETWEEN 0 AND 10000)),
  CONSTRAINT tax_rules_fixed_valid CHECK (tax_type <> 'FIXED' OR (fixed_amount_minor IS NOT NULL AND fixed_amount_minor >= 0)),
  CONSTRAINT tax_rules_date_range CHECK (valid_until IS NULL OR valid_from IS NULL OR valid_until >= valid_from)
);

CREATE TABLE tax_snapshots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tax_rule_id UUID REFERENCES tax_rules(id) ON DELETE SET NULL,
  invoice_id UUID,
  quotation_id UUID REFERENCES quotations(id) ON DELETE CASCADE,
  tax_name VARCHAR(200) NOT NULL,
  tax_code VARCHAR(100) NOT NULL,
  rate_basis_points INTEGER,
  tax_amount_minor BIGINT NOT NULL,
  captured_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT tax_snapshots_amount_non_negative CHECK (tax_amount_minor >= 0),
  CONSTRAINT tax_snapshots_document_present CHECK (invoice_id IS NOT NULL OR quotation_id IS NOT NULL)
);

CREATE TABLE invoices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_number VARCHAR(50) NOT NULL UNIQUE,
  customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
  subscription_id UUID REFERENCES subscriptions(id) ON DELETE RESTRICT,
  status invoice_status NOT NULL DEFAULT 'DRAFT',
  billing_period_start DATE NOT NULL,
  billing_period_end DATE NOT NULL,
  issued_at TIMESTAMPTZ,
  due_at TIMESTAMPTZ,
  currency CHAR(3) NOT NULL DEFAULT 'USD',
  subtotal_minor BIGINT NOT NULL DEFAULT 0,
  discount_minor BIGINT NOT NULL DEFAULT 0,
  tax_minor BIGINT NOT NULL DEFAULT 0,
  total_minor BIGINT NOT NULL DEFAULT 0,
  amount_paid_minor BIGINT NOT NULL DEFAULT 0,
  balance_due_minor BIGINT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT invoices_period_range CHECK (billing_period_end >= billing_period_start),
  CONSTRAINT invoices_amounts_non_negative CHECK (subtotal_minor >= 0 AND discount_minor >= 0 AND tax_minor >= 0 AND total_minor >= 0 AND amount_paid_minor >= 0 AND balance_due_minor >= 0),
  CONSTRAINT invoices_currency_format CHECK (currency ~ '^[A-Z]{3}$'),
  CONSTRAINT invoices_subscription_period_unique UNIQUE (subscription_id, billing_period_start, billing_period_end)
);

ALTER TABLE discount_applications
  ADD CONSTRAINT discount_applications_invoice_fk
  FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE;

ALTER TABLE tax_snapshots
  ADD CONSTRAINT tax_snapshots_invoice_fk
  FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE;

CREATE TABLE invoice_lines (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_id UUID NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
  product_id UUID REFERENCES products(id) ON DELETE SET NULL,
  variant_id UUID REFERENCES product_variants(id) ON DELETE SET NULL,
  plan_id UUID REFERENCES plans(id) ON DELETE SET NULL,
  description TEXT NOT NULL,
  quantity INTEGER NOT NULL,
  unit_price_minor BIGINT NOT NULL,
  discount_minor BIGINT NOT NULL DEFAULT 0,
  tax_minor BIGINT NOT NULL DEFAULT 0,
  line_total_minor BIGINT NOT NULL,
  product_snapshot JSONB NOT NULL DEFAULT '{}'::JSONB,
  variant_snapshot JSONB NOT NULL DEFAULT '{}'::JSONB,
  plan_snapshot JSONB NOT NULL DEFAULT '{}'::JSONB,
  tax_snapshot JSONB NOT NULL DEFAULT '{}'::JSONB,
  discount_snapshot JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT invoice_lines_quantity_positive CHECK (quantity > 0),
  CONSTRAINT invoice_lines_amounts_non_negative CHECK (unit_price_minor >= 0 AND discount_minor >= 0 AND tax_minor >= 0 AND line_total_minor >= 0)
);

CREATE TABLE payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
  payment_method payment_method NOT NULL,
  amount_minor BIGINT NOT NULL,
  currency CHAR(3) NOT NULL DEFAULT 'USD',
  paid_at TIMESTAMPTZ NOT NULL,
  reference VARCHAR(200),
  notes TEXT,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT payments_amount_positive CHECK (amount_minor > 0),
  CONSTRAINT payments_currency_format CHECK (currency ~ '^[A-Z]{3}$')
);

CREATE TABLE payment_allocations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_id UUID NOT NULL REFERENCES payments(id) ON DELETE CASCADE,
  invoice_id UUID NOT NULL REFERENCES invoices(id) ON DELETE RESTRICT,
  amount_minor BIGINT NOT NULL,
  allocated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT payment_allocations_amount_positive CHECK (amount_minor > 0),
  CONSTRAINT payment_invoice_unique UNIQUE (payment_id, invoice_id)
);

CREATE TABLE dunning_attempts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_id UUID NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
  attempt_number INTEGER NOT NULL,
  scheduled_at TIMESTAMPTZ NOT NULL,
  attempted_at TIMESTAMPTZ,
  status dunning_status NOT NULL DEFAULT 'PENDING',
  channel VARCHAR(50) NOT NULL DEFAULT 'EMAIL',
  error_message TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT dunning_attempt_number_positive CHECK (attempt_number > 0),
  CONSTRAINT dunning_invoice_attempt_unique UNIQUE (invoice_id, attempt_number)
);

CREATE TABLE outbox_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_key VARCHAR(200) NOT NULL UNIQUE,
  event_type outbox_event_type NOT NULL,
  aggregate_type VARCHAR(100) NOT NULL,
  aggregate_id UUID NOT NULL,
  payload JSONB NOT NULL,
  status outbox_status NOT NULL DEFAULT 'PENDING',
  attempts INTEGER NOT NULL DEFAULT 0,
  available_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  processed_at TIMESTAMPTZ,
  last_error TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT outbox_attempts_non_negative CHECK (attempts >= 0)
);

CREATE TABLE subscription_health_scores (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  subscription_id UUID NOT NULL REFERENCES subscriptions(id) ON DELETE CASCADE,
  score INTEGER NOT NULL,
  risk_level churn_risk_level NOT NULL,
  contributing_factors JSONB NOT NULL DEFAULT '[]'::JSONB,
  model_version VARCHAR(50) NOT NULL,
  calculated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT subscription_health_score_range CHECK (score BETWEEN 0 AND 100)
);

CREATE TABLE churn_predictions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  subscription_id UUID NOT NULL REFERENCES subscriptions(id) ON DELETE CASCADE,
  probability_basis_points INTEGER NOT NULL,
  risk_level churn_risk_level NOT NULL,
  predicted_for_date DATE NOT NULL,
  contributing_factors JSONB NOT NULL DEFAULT '[]'::JSONB,
  model_version VARCHAR(50) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT churn_probability_range CHECK (probability_basis_points BETWEEN 0 AND 10000)
);

CREATE TABLE audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  action VARCHAR(100) NOT NULL,
  entity_type VARCHAR(100) NOT NULL,
  entity_id UUID,
  before_data JSONB,
  after_data JSONB,
  ip_address INET,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX password_reset_tokens_user_idx ON password_reset_tokens (user_id, expires_at);
CREATE INDEX customer_contacts_customer_idx ON customer_contacts (customer_id);
CREATE INDEX products_active_type_idx ON products (is_active, product_type);
CREATE INDEX plans_available_idx ON plans (is_active, available_from, available_until);
CREATE INDEX quotations_customer_status_idx ON quotations (customer_id, status, created_at DESC);
CREATE INDEX quotation_lines_quotation_idx ON quotation_lines (quotation_id);
CREATE INDEX subscriptions_customer_status_idx ON subscriptions (customer_id, status);
CREATE INDEX subscriptions_billing_idx ON subscriptions (status, next_billing_at) WHERE status = 'ACTIVE';
CREATE INDEX subscription_lines_subscription_idx ON subscription_lines (subscription_id);
CREATE INDEX subscription_events_timeline_idx ON subscription_lifecycle_events (subscription_id, occurred_at DESC);
CREATE INDEX discount_rules_active_dates_idx ON discount_rules (is_active, valid_from, valid_until);
CREATE INDEX discount_applications_customer_idx ON discount_applications (customer_id, applied_at DESC);
CREATE INDEX tax_rules_active_dates_idx ON tax_rules (is_active, valid_from, valid_until);
CREATE INDEX invoices_customer_status_idx ON invoices (customer_id, status, due_at DESC);
CREATE INDEX invoices_overdue_idx ON invoices (due_at, balance_due_minor) WHERE status IN ('CONFIRMED', 'PARTIALLY_PAID', 'OVERDUE');
CREATE INDEX invoices_billing_batch_idx ON invoices (subscription_id, billing_period_start, billing_period_end);
CREATE INDEX invoice_lines_invoice_idx ON invoice_lines (invoice_id);
CREATE INDEX payments_customer_date_idx ON payments (customer_id, paid_at DESC);
CREATE INDEX payment_allocations_invoice_idx ON payment_allocations (invoice_id);
CREATE INDEX dunning_pending_idx ON dunning_attempts (status, scheduled_at) WHERE status = 'PENDING';
CREATE INDEX outbox_pending_idx ON outbox_events (status, available_at) WHERE status IN ('PENDING', 'FAILED');
CREATE INDEX health_scores_subscription_date_idx ON subscription_health_scores (subscription_id, calculated_at DESC);
CREATE INDEX churn_predictions_risk_idx ON churn_predictions (risk_level, created_at DESC);
CREATE INDEX audit_logs_entity_idx ON audit_logs (entity_type, entity_id, created_at DESC);
