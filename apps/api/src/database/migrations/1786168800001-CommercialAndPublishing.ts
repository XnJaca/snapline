import { MigrationInterface, QueryRunner } from 'typeorm';

// Las líneas copian nombre, unidad y precio; service_item_id queda solo para reportes.
export class CommercialAndPublishing1786168800001 implements MigrationInterface {
  name = 'CommercialAndPublishing1786168800001';

  public async up(q: QueryRunner): Promise<void> {
    // ------------------------------------------------------------ comercial
    await q.query(`
      CREATE TABLE service_item (
        id               uuid PRIMARY KEY,
        company_id       uuid NOT NULL REFERENCES company(id),
        code             text,
        name             text NOT NULL,
        description      text,
        unit             service_unit NOT NULL,
        unit_price_cents bigint NOT NULL CHECK (unit_price_cents >= 0),
        cost_cents       bigint CHECK (cost_cents IS NULL OR cost_cents >= 0),
        taxable          boolean NOT NULL DEFAULT false,
        category         text,
        active           boolean NOT NULL DEFAULT true,
        created_at       timestamptz NOT NULL DEFAULT now(),
        updated_at       timestamptz NOT NULL DEFAULT now(),
        deleted_at       timestamptz,
        UNIQUE (company_id, code)
      )`);

    await q.query(`
      CREATE TABLE tax_rate (
        id         uuid PRIMARY KEY,
        company_id uuid NOT NULL REFERENCES company(id),
        name       text NOT NULL,
        rate_bps   integer NOT NULL CHECK (rate_bps >= 0 AND rate_bps <= 10000),
        active     boolean NOT NULL DEFAULT true,
        created_at timestamptz NOT NULL DEFAULT now(),
        updated_at timestamptz NOT NULL DEFAULT now(),
        deleted_at timestamptz
      )`);

    await q.query(`
      CREATE TABLE document_counter (
        company_id  uuid NOT NULL REFERENCES company(id),
        doc_type    counter_doc_type NOT NULL,
        next_number bigint NOT NULL DEFAULT 1 CHECK (next_number > 0),
        PRIMARY KEY (company_id, doc_type)
      )`);

    await q.query(`
      CREATE TABLE estimate (
        id                          uuid PRIMARY KEY,
        company_id                  uuid NOT NULL REFERENCES company(id),
        customer_id                 uuid NOT NULL REFERENCES customer(id),
        project_id                  uuid REFERENCES project(id),
        number                      text,
        status                      estimate_status NOT NULL DEFAULT 'DRAFT',
        issued_at                   timestamptz,
        expires_at                  timestamptz,
        subtotal_cents              bigint NOT NULL DEFAULT 0 CHECK (subtotal_cents >= 0),
        tax_cents                   bigint NOT NULL DEFAULT 0 CHECK (tax_cents >= 0),
        total_cents                 bigint NOT NULL DEFAULT 0 CHECK (total_cents >= 0),
        terms                       text,
        accepted_at                 timestamptz,
        accepted_signature_asset_id uuid REFERENCES media_asset(id),
        accepted_ip                 inet,
        created_at                  timestamptz NOT NULL DEFAULT now(),
        updated_at                  timestamptz NOT NULL DEFAULT now(),
        deleted_at                  timestamptz,
        UNIQUE (company_id, number),
        CONSTRAINT estimate_numbered_once_sent CHECK (status = 'DRAFT' OR number IS NOT NULL),
        CONSTRAINT estimate_accepted_has_date CHECK (status <> 'ACCEPTED' OR accepted_at IS NOT NULL)
      )`);

    await q.query(`
      CREATE TABLE estimate_line (
        id                        uuid PRIMARY KEY,
        company_id                uuid NOT NULL REFERENCES company(id),
        estimate_id               uuid NOT NULL REFERENCES estimate(id) ON DELETE CASCADE,
        position                  integer NOT NULL,
        service_item_id           uuid REFERENCES service_item(id),
        name_snapshot             text NOT NULL,
        description_snapshot      text,
        unit_snapshot             service_unit NOT NULL,
        taxable_snapshot          boolean NOT NULL,
        unit_price_cents_snapshot bigint NOT NULL CHECK (unit_price_cents_snapshot >= 0),
        qty                       numeric(12,3) NOT NULL CHECK (qty > 0),
        amount_cents              bigint NOT NULL CHECK (amount_cents >= 0),
        created_at                timestamptz NOT NULL DEFAULT now(),
        updated_at                timestamptz NOT NULL DEFAULT now(),
        UNIQUE (estimate_id, position)
      )`);

    await q.query(`
      CREATE TABLE invoice (
        id             uuid PRIMARY KEY,
        company_id     uuid NOT NULL REFERENCES company(id),
        customer_id    uuid NOT NULL REFERENCES customer(id),
        project_id     uuid REFERENCES project(id),
        estimate_id    uuid REFERENCES estimate(id),
        number         text,
        status         invoice_status NOT NULL DEFAULT 'DRAFT',
        issued_at      timestamptz,
        due_at         timestamptz,
        subtotal_cents bigint NOT NULL DEFAULT 0 CHECK (subtotal_cents >= 0),
        tax_cents      bigint NOT NULL DEFAULT 0 CHECK (tax_cents >= 0),
        total_cents    bigint NOT NULL DEFAULT 0 CHECK (total_cents >= 0),
        balance_cents  bigint NOT NULL DEFAULT 0 CHECK (balance_cents >= 0),
        voided_at      timestamptz,
        created_at     timestamptz NOT NULL DEFAULT now(),
        updated_at     timestamptz NOT NULL DEFAULT now(),
        deleted_at     timestamptz,
        UNIQUE (company_id, number),
        CONSTRAINT invoice_numbered_once_sent CHECK (status = 'DRAFT' OR number IS NOT NULL),
        CONSTRAINT invoice_balance_within_total CHECK (balance_cents <= total_cents),
        CONSTRAINT invoice_paid_has_zero_balance CHECK (status <> 'PAID' OR balance_cents = 0)
      )`);

    await q.query(`
      CREATE TABLE invoice_line (
        id                        uuid PRIMARY KEY,
        company_id                uuid NOT NULL REFERENCES company(id),
        invoice_id                uuid NOT NULL REFERENCES invoice(id) ON DELETE CASCADE,
        position                  integer NOT NULL,
        service_item_id           uuid REFERENCES service_item(id),
        name_snapshot             text NOT NULL,
        description_snapshot      text,
        unit_snapshot             service_unit NOT NULL,
        taxable_snapshot          boolean NOT NULL,
        unit_price_cents_snapshot bigint NOT NULL CHECK (unit_price_cents_snapshot >= 0),
        qty                       numeric(12,3) NOT NULL CHECK (qty > 0),
        amount_cents              bigint NOT NULL CHECK (amount_cents >= 0),
        created_at                timestamptz NOT NULL DEFAULT now(),
        updated_at                timestamptz NOT NULL DEFAULT now(),
        UNIQUE (invoice_id, position)
      )`);

    await q.query(`
      CREATE TABLE payment (
        id           uuid PRIMARY KEY,
        company_id   uuid NOT NULL REFERENCES company(id),
        invoice_id   uuid NOT NULL REFERENCES invoice(id),
        amount_cents bigint NOT NULL CHECK (amount_cents > 0),
        method       payment_method NOT NULL,
        received_at  timestamptz NOT NULL,
        reference    text,
        recorded_by_membership_id uuid REFERENCES membership(id),
        idempotency_key text,
        created_at   timestamptz NOT NULL DEFAULT now(),
        updated_at   timestamptz NOT NULL DEFAULT now(),
        deleted_at   timestamptz,
        UNIQUE (company_id, idempotency_key)
      )`);

    // -------------------------------------------------------- portal cliente
    await q.query(`
      CREATE TABLE client_access (
        id              uuid PRIMARY KEY,
        company_id      uuid NOT NULL REFERENCES company(id),
        customer_id     uuid NOT NULL REFERENCES customer(id),
        project_id      uuid REFERENCES project(id),
        token_hash      text NOT NULL UNIQUE,
        expires_at      timestamptz NOT NULL,
        last_seen_at    timestamptz,
        claimed_user_id uuid REFERENCES app_user(id),
        revoked_at      timestamptz,
        created_at      timestamptz NOT NULL DEFAULT now(),
        updated_at      timestamptz NOT NULL DEFAULT now()
      )`);

    await q.query(`
      CREATE TABLE project_update (
        id                        uuid PRIMARY KEY,
        company_id                uuid NOT NULL REFERENCES company(id),
        project_id                uuid NOT NULL REFERENCES project(id),
        author_membership_id      uuid NOT NULL REFERENCES membership(id),
        body                      text NOT NULL,
        visibility                media_visibility NOT NULL DEFAULT 'INTERNAL',
        approved_by_membership_id uuid REFERENCES membership(id),
        published_at              timestamptz,
        created_at                timestamptz NOT NULL DEFAULT now(),
        updated_at                timestamptz NOT NULL DEFAULT now(),
        deleted_at                timestamptz,
        CONSTRAINT update_published_needs_approval
          CHECK (published_at IS NULL OR approved_by_membership_id IS NOT NULL)
      )`);

    await q.query(`
      CREATE TABLE project_update_asset (
        update_id uuid NOT NULL REFERENCES project_update(id) ON DELETE CASCADE,
        asset_id  uuid NOT NULL REFERENCES media_asset(id),
        position  integer NOT NULL DEFAULT 0,
        PRIMARY KEY (update_id, asset_id)
      )`);

    await q.query(`
      CREATE TABLE service_offer (
        id              uuid PRIMARY KEY,
        company_id      uuid NOT NULL REFERENCES company(id),
        service_item_id uuid REFERENCES service_item(id),
        title           text NOT NULL,
        pitch           text,
        target          jsonb,
        active          boolean NOT NULL DEFAULT true,
        created_at      timestamptz NOT NULL DEFAULT now(),
        updated_at      timestamptz NOT NULL DEFAULT now(),
        deleted_at      timestamptz
      )`);

    await q.query(`
      CREATE TABLE lead (
        id                   uuid PRIMARY KEY,
        company_id           uuid NOT NULL REFERENCES company(id),
        customer_id          uuid NOT NULL REFERENCES customer(id),
        offer_id             uuid REFERENCES service_offer(id),
        source_project_id    uuid REFERENCES project(id),
        status               lead_status NOT NULL DEFAULT 'NEW',
        converted_project_id uuid REFERENCES project(id),
        notes                text,
        created_at           timestamptz NOT NULL DEFAULT now(),
        updated_at           timestamptz NOT NULL DEFAULT now(),
        deleted_at           timestamptz,
        CONSTRAINT lead_converted_has_project
          CHECK (status <> 'CONVERTED' OR converted_project_id IS NOT NULL)
      )`);

    // ----------------------------------------------------------- publicación
    await q.query(`
      CREATE TABLE testimonial (
        id           uuid PRIMARY KEY,
        company_id   uuid NOT NULL REFERENCES company(id),
        customer_id  uuid NOT NULL REFERENCES customer(id),
        project_id   uuid NOT NULL REFERENCES project(id),
        rating       integer CHECK (rating IS NULL OR (rating BETWEEN 1 AND 5)),
        body         text NOT NULL,
        approved_at  timestamptz,
        published_at timestamptz,
        created_at   timestamptz NOT NULL DEFAULT now(),
        updated_at   timestamptz NOT NULL DEFAULT now(),
        deleted_at   timestamptz,
        CONSTRAINT testimonial_published_needs_approval
          CHECK (published_at IS NULL OR approved_at IS NOT NULL)
      )`);

    await q.query(`
      CREATE TABLE published_project (
        id             uuid PRIMARY KEY,
        company_id     uuid NOT NULL REFERENCES company(id),
        project_id     uuid NOT NULL REFERENCES project(id),
        slug           citext NOT NULL,
        title          text NOT NULL,
        summary        text,
        hero_asset_id  uuid NOT NULL REFERENCES media_asset(id),
        service_type   text,
        city           text,
        testimonial_id uuid REFERENCES testimonial(id),
        published_at   timestamptz NOT NULL DEFAULT now(),
        unpublished_at timestamptz,
        created_at     timestamptz NOT NULL DEFAULT now(),
        updated_at     timestamptz NOT NULL DEFAULT now(),
        UNIQUE (company_id, slug)
      )`);

    await q.query(`
      CREATE TABLE published_project_asset (
        published_project_id uuid NOT NULL REFERENCES published_project(id) ON DELETE CASCADE,
        asset_id             uuid NOT NULL REFERENCES media_asset(id),
        position             integer NOT NULL DEFAULT 0,
        PRIMARY KEY (published_project_id, asset_id)
      )`);

    await q.query(`
      CREATE TABLE social_post (
        id                uuid PRIMARY KEY,
        company_id        uuid NOT NULL REFERENCES company(id),
        source_project_id uuid REFERENCES project(id),
        platform          social_platform NOT NULL,
        content           text,
        status            social_post_status NOT NULL DEFAULT 'SUGGESTED',
        scheduled_for     timestamptz,
        posted_at         timestamptz,
        created_at        timestamptz NOT NULL DEFAULT now(),
        updated_at        timestamptz NOT NULL DEFAULT now(),
        deleted_at        timestamptz
      )`);

    await q.query(`
      CREATE TABLE social_post_asset (
        social_post_id uuid NOT NULL REFERENCES social_post(id) ON DELETE CASCADE,
        asset_id       uuid NOT NULL REFERENCES media_asset(id),
        position       integer NOT NULL DEFAULT 0,
        PRIMARY KEY (social_post_id, asset_id)
      )`);

    // ----------------------------------------------------------- transversal
    await q.query(`
      CREATE TABLE audit_log (
        id            uuid PRIMARY KEY,
        company_id    uuid NOT NULL REFERENCES company(id),
        actor_membership_id uuid REFERENCES membership(id),
        entity        text NOT NULL,
        entity_id     uuid NOT NULL,
        action        text NOT NULL,
        old_value     jsonb,
        new_value     jsonb,
        created_at    timestamptz NOT NULL DEFAULT now()
      )`);
  }

  public async down(q: QueryRunner): Promise<void> {
    await q.query(`DROP TABLE IF EXISTS audit_log, social_post_asset, social_post, published_project_asset,
      published_project, testimonial, lead, service_offer, project_update_asset, project_update,
      client_access, payment, invoice_line, invoice, estimate_line, estimate, document_counter,
      tax_rate, service_item CASCADE`);
  }
}
