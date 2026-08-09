import { MigrationInterface, QueryRunner } from 'typeorm';

// Escrito a mano: el modelo necesita constraints que TypeORM no emite. Ver ADR-0006.
export class InitialSchema1786168800000 implements MigrationInterface {
  name = 'InitialSchema1786168800000';

  public async up(q: QueryRunner): Promise<void> {
    await q.query(`CREATE EXTENSION IF NOT EXISTS btree_gist`);
    await q.query(`CREATE EXTENSION IF NOT EXISTS citext`);

    // ---------------------------------------------------------------- enums
    await q.query(`CREATE TYPE membership_role AS ENUM ('OWNER','ADMIN','FOREMAN','WORKER','ACCOUNTANT')`);
    await q.query(`CREATE TYPE membership_status AS ENUM ('INVITED','ACTIVE','INACTIVE')`);
    await q.query(`CREATE TYPE employment_type AS ENUM ('W2','CONTRACTOR_1099')`);
    await q.query(`CREATE TYPE customer_source AS ENUM ('REFERRAL','WEB','SOCIAL','REPEAT','OTHER')`);
    await q.query(`CREATE TYPE project_status AS ENUM ('LEAD','ESTIMATED','SCHEDULED','IN_PROGRESS','ON_HOLD','COMPLETED','CANCELLED')`);
    await q.query(`CREATE TYPE client_visibility_mode AS ENUM ('STAGES','PROGRESS')`);
    await q.query(`CREATE TYPE time_entry_method AS ENUM ('SELF','FOREMAN','ADMIN')`);
    await q.query(`CREATE TYPE time_entry_status AS ENUM ('PENDING','APPROVED','REJECTED')`);
    await q.query(`CREATE TYPE media_kind AS ENUM ('PHOTO','VIDEO','DOCUMENT')`);
    await q.query(`CREATE TYPE media_visibility AS ENUM ('INTERNAL','CLIENT','PUBLIC')`);
    await q.query(`CREATE TYPE upload_status AS ENUM ('PENDING','UPLOADING','READY','FAILED')`);
    await q.query(`CREATE TYPE media_tag_kind AS ENUM ('BEFORE','DURING','AFTER','DETAIL','PROBLEM','RECEIPT')`);
    await q.query(`CREATE TYPE document_kind AS ENUM ('CONTRACT','PERMIT','BLUEPRINT','INSURANCE','W9','RECEIPT','PHOTO_RELEASE','SIGNATURE','OTHER')`);
    await q.query(`CREATE TYPE service_unit AS ENUM ('HOUR','SQFT','LINEAR_FT','EACH','JOB')`);
    await q.query(`CREATE TYPE estimate_status AS ENUM ('DRAFT','SENT','VIEWED','ACCEPTED','DECLINED','EXPIRED')`);
    await q.query(`CREATE TYPE invoice_status AS ENUM ('DRAFT','SENT','PARTIAL','PAID','OVERDUE','VOID')`);
    await q.query(`CREATE TYPE payment_method AS ENUM ('CHECK','CASH','ACH','CARD','ZELLE','OTHER')`);
    await q.query(`CREATE TYPE counter_doc_type AS ENUM ('ESTIMATE','INVOICE')`);
    await q.query(`CREATE TYPE lead_status AS ENUM ('NEW','CONTACTED','CONVERTED','DISCARDED')`);
    await q.query(`CREATE TYPE social_platform AS ENUM ('INSTAGRAM','FACEBOOK','GOOGLE','TIKTOK','OTHER')`);
    await q.query(`CREATE TYPE social_post_status AS ENUM ('SUGGESTED','SCHEDULED','POSTED')`);

    // ------------------------------------------------------ tenencia y gente
    await q.query(`
      CREATE TABLE company (
        id                uuid PRIMARY KEY,
        name              text NOT NULL,
        legal_name        text,
        timezone          text NOT NULL DEFAULT 'America/New_York',
        currency          char(3) NOT NULL DEFAULT 'USD',
        address           jsonb,
        logo_asset_id     uuid,
        public_site_slug  citext UNIQUE,
        settings          jsonb NOT NULL DEFAULT '{}'::jsonb,
        created_at        timestamptz NOT NULL DEFAULT now(),
        updated_at        timestamptz NOT NULL DEFAULT now(),
        deleted_at        timestamptz
      )`);

    await q.query(`
      CREATE TABLE app_user (
        id             uuid PRIMARY KEY,
        email          citext UNIQUE,
        phone          text UNIQUE,
        password_hash  text NOT NULL,
        name           text NOT NULL,
        locale         text NOT NULL DEFAULT 'en',
        created_at     timestamptz NOT NULL DEFAULT now(),
        updated_at     timestamptz NOT NULL DEFAULT now(),
        deleted_at     timestamptz,
        CONSTRAINT app_user_needs_contact CHECK (email IS NOT NULL OR phone IS NOT NULL),
        CONSTRAINT app_user_locale_supported CHECK (locale IN ('en','es'))
      )`);

    await q.query(`
      CREATE TABLE membership (
        id               uuid PRIMARY KEY,
        company_id       uuid NOT NULL REFERENCES company(id),
        user_id          uuid NOT NULL REFERENCES app_user(id),
        role             membership_role NOT NULL,
        pay_rate_cents   bigint CHECK (pay_rate_cents IS NULL OR pay_rate_cents >= 0),
        employment_type  employment_type,
        status           membership_status NOT NULL DEFAULT 'INVITED',
        invited_at       timestamptz,
        joined_at        timestamptz,
        created_at       timestamptz NOT NULL DEFAULT now(),
        updated_at       timestamptz NOT NULL DEFAULT now(),
        deleted_at       timestamptz,
        UNIQUE (company_id, user_id)
      )`);

    await q.query(`
      CREATE TABLE crew (
        id                    uuid PRIMARY KEY,
        company_id            uuid NOT NULL REFERENCES company(id),
        name                  text NOT NULL,
        foreman_membership_id uuid REFERENCES membership(id),
        color                 text,
        created_at            timestamptz NOT NULL DEFAULT now(),
        updated_at            timestamptz NOT NULL DEFAULT now(),
        deleted_at            timestamptz
      )`);

    await q.query(`
      CREATE TABLE crew_member (
        id             uuid PRIMARY KEY,
        company_id     uuid NOT NULL REFERENCES company(id),
        crew_id        uuid NOT NULL REFERENCES crew(id),
        membership_id  uuid NOT NULL REFERENCES membership(id),
        from_date      date NOT NULL,
        to_date        date,
        created_at     timestamptz NOT NULL DEFAULT now(),
        updated_at     timestamptz NOT NULL DEFAULT now(),
        deleted_at     timestamptz,
        CONSTRAINT crew_member_range_valid CHECK (to_date IS NULL OR to_date >= from_date)
      )`);

    await q.query(`
      ALTER TABLE crew_member ADD CONSTRAINT crew_member_no_overlap
      EXCLUDE USING gist (
        membership_id WITH =,
        daterange(from_date, to_date, '[]') WITH &&
      ) WHERE (deleted_at IS NULL)`);

    // ----------------------------------------------------- clientes y obra
    await q.query(`
      CREATE TABLE customer (
        id                          uuid PRIMARY KEY,
        company_id                  uuid NOT NULL REFERENCES company(id),
        display_name                text NOT NULL,
        first_name                  text,
        last_name                   text,
        company_name                text,
        email                       citext,
        phone                       text,
        billing_address             jsonb,
        source                      customer_source,
        notes                       text,
        photo_release_granted_at    timestamptz,
        photo_release_document_id   uuid,
        created_at                  timestamptz NOT NULL DEFAULT now(),
        updated_at                  timestamptz NOT NULL DEFAULT now(),
        deleted_at                  timestamptz
      )`);

    await q.query(`
      CREATE TABLE site (
        id                 uuid PRIMARY KEY,
        company_id         uuid NOT NULL REFERENCES company(id),
        customer_id        uuid NOT NULL REFERENCES customer(id),
        address            jsonb NOT NULL,
        lat                numeric(9,6),
        lng                numeric(9,6),
        geofence_radius_m  integer CHECK (geofence_radius_m IS NULL OR geofence_radius_m > 0),
        created_at         timestamptz NOT NULL DEFAULT now(),
        updated_at         timestamptz NOT NULL DEFAULT now(),
        deleted_at         timestamptz,
        CONSTRAINT site_coords_together CHECK ((lat IS NULL) = (lng IS NULL))
      )`);

    await q.query(`
      CREATE TABLE project (
        id                     uuid PRIMARY KEY,
        company_id             uuid NOT NULL REFERENCES company(id),
        customer_id            uuid NOT NULL REFERENCES customer(id),
        site_id                uuid NOT NULL REFERENCES site(id),
        name                   text NOT NULL,
        description            text,
        service_type           text,
        status                 project_status NOT NULL DEFAULT 'LEAD',
        client_visibility_mode client_visibility_mode NOT NULL DEFAULT 'STAGES',
        start_date             date,
        target_end_date        date,
        actual_end_date        date,
        published_at           timestamptz,
        created_at             timestamptz NOT NULL DEFAULT now(),
        updated_at             timestamptz NOT NULL DEFAULT now(),
        deleted_at             timestamptz
      )`);

    await q.query(`
      CREATE TABLE project_assignment (
        id                uuid PRIMARY KEY,
        company_id        uuid NOT NULL REFERENCES company(id),
        project_id        uuid NOT NULL REFERENCES project(id),
        crew_id           uuid REFERENCES crew(id),
        membership_id     uuid REFERENCES membership(id),
        work_date         date NOT NULL,
        planned_headcount integer CHECK (planned_headcount IS NULL OR planned_headcount > 0),
        created_at        timestamptz NOT NULL DEFAULT now(),
        updated_at        timestamptz NOT NULL DEFAULT now(),
        deleted_at        timestamptz,
        CONSTRAINT assignment_crew_xor_member CHECK (num_nonnulls(crew_id, membership_id) = 1)
      )`);

    // --------------------------------------------------------------- campo
    await q.query(`
      CREATE TABLE time_entry (
        id                         uuid PRIMARY KEY,
        company_id                 uuid NOT NULL REFERENCES company(id),
        project_id                 uuid NOT NULL REFERENCES project(id),
        membership_id              uuid NOT NULL REFERENCES membership(id),
        clock_in_at                timestamptz NOT NULL,
        clock_out_at               timestamptz,
        break_minutes              integer NOT NULL DEFAULT 0 CHECK (break_minutes >= 0),
        clock_in_lat               numeric(9,6),
        clock_in_lng               numeric(9,6),
        clock_in_accuracy_m        integer,
        clock_in_distance_m        integer,
        clock_in_within_geofence   boolean,
        clock_in_photo_id          uuid,
        clock_out_lat              numeric(9,6),
        clock_out_lng              numeric(9,6),
        clock_out_accuracy_m       integer,
        clock_out_distance_m       integer,
        clock_out_within_geofence  boolean,
        clock_out_photo_id         uuid,
        method                     time_entry_method NOT NULL DEFAULT 'SELF',
        recorded_by_membership_id  uuid NOT NULL REFERENCES membership(id),
        device_id                  text,
        is_mock_location           boolean NOT NULL DEFAULT false,
        recorded_offline           boolean NOT NULL DEFAULT false,
        device_recorded_at         timestamptz NOT NULL,
        server_received_at         timestamptz NOT NULL DEFAULT now(),
        status                     time_entry_status NOT NULL DEFAULT 'PENDING',
        approved_by_membership_id  uuid REFERENCES membership(id),
        approved_at                timestamptz,
        pay_rate_cents_snapshot    bigint CHECK (pay_rate_cents_snapshot IS NULL OR pay_rate_cents_snapshot >= 0),
        flags                      text[] NOT NULL DEFAULT '{}',
        created_at                 timestamptz NOT NULL DEFAULT now(),
        updated_at                 timestamptz NOT NULL DEFAULT now(),
        deleted_at                 timestamptz,
        CONSTRAINT time_entry_out_after_in CHECK (clock_out_at IS NULL OR clock_out_at > clock_in_at),
        CONSTRAINT time_entry_rate_frozen_on_approval
          CHECK (status <> 'APPROVED' OR pay_rate_cents_snapshot IS NOT NULL),
        CONSTRAINT time_entry_approval_complete
          CHECK ((approved_by_membership_id IS NULL) = (approved_at IS NULL))
      )`);

    await q.query(`
      CREATE TABLE time_entry_edit (
        id                    uuid PRIMARY KEY,
        company_id            uuid NOT NULL REFERENCES company(id),
        time_entry_id         uuid NOT NULL REFERENCES time_entry(id),
        edited_by_membership_id uuid NOT NULL REFERENCES membership(id),
        field                 text NOT NULL,
        old_value             text,
        new_value             text,
        reason                text,
        created_at            timestamptz NOT NULL DEFAULT now()
      )`);

    // ------------------------------------------------------------ contenido
    await q.query(`
      CREATE TABLE media_asset (
        id             uuid PRIMARY KEY,
        company_id     uuid NOT NULL REFERENCES company(id),
        project_id     uuid NOT NULL REFERENCES project(id),
        kind           media_kind NOT NULL,
        document_kind  document_kind,
        storage_key    text NOT NULL,
        mime           text NOT NULL,
        bytes          bigint CHECK (bytes IS NULL OR bytes > 0),
        width          integer,
        height         integer,
        captured_at    timestamptz,
        uploaded_by_membership_id uuid REFERENCES membership(id),
        device_lat     numeric(9,6),
        device_lng     numeric(9,6),
        checksum       text NOT NULL,
        upload_status  upload_status NOT NULL DEFAULT 'PENDING',
        visibility     media_visibility NOT NULL DEFAULT 'INTERNAL',
        exif_stripped_at timestamptz,
        created_at     timestamptz NOT NULL DEFAULT now(),
        updated_at     timestamptz NOT NULL DEFAULT now(),
        deleted_at     timestamptz,
        CONSTRAINT media_asset_doc_kind_only_for_documents
          CHECK (kind = 'DOCUMENT' OR document_kind IS NULL)
      )`);

    await q.query(`
      CREATE TABLE media_tag (
        id         uuid PRIMARY KEY,
        company_id uuid NOT NULL REFERENCES company(id),
        asset_id   uuid NOT NULL REFERENCES media_asset(id),
        tag        media_tag_kind NOT NULL,
        created_at timestamptz NOT NULL DEFAULT now(),
        UNIQUE (asset_id, tag)
      )`);

    await q.query(`
      CREATE TABLE before_after_pair (
        id              uuid PRIMARY KEY,
        company_id      uuid NOT NULL REFERENCES company(id),
        project_id      uuid NOT NULL REFERENCES project(id),
        before_asset_id uuid NOT NULL REFERENCES media_asset(id),
        after_asset_id  uuid NOT NULL REFERENCES media_asset(id),
        caption         text,
        created_at      timestamptz NOT NULL DEFAULT now(),
        updated_at      timestamptz NOT NULL DEFAULT now(),
        deleted_at      timestamptz,
        CONSTRAINT before_after_distinct CHECK (before_asset_id <> after_asset_id)
      )`);

    await q.query(`ALTER TABLE time_entry ADD CONSTRAINT time_entry_in_photo_fk FOREIGN KEY (clock_in_photo_id) REFERENCES media_asset(id)`);
    await q.query(`ALTER TABLE time_entry ADD CONSTRAINT time_entry_out_photo_fk FOREIGN KEY (clock_out_photo_id) REFERENCES media_asset(id)`);
    await q.query(`ALTER TABLE customer ADD CONSTRAINT customer_release_doc_fk FOREIGN KEY (photo_release_document_id) REFERENCES media_asset(id)`);
    await q.query(`ALTER TABLE company ADD CONSTRAINT company_logo_fk FOREIGN KEY (logo_asset_id) REFERENCES media_asset(id)`);
  }

  public async down(q: QueryRunner): Promise<void> {
    await q.query(`DROP TABLE IF EXISTS before_after_pair, media_tag, media_asset, time_entry_edit, time_entry,
      project_assignment, project, site, customer, crew_member, crew, membership, app_user, company CASCADE`);
    await q.query(`DROP TYPE IF EXISTS social_post_status, social_platform, lead_status, counter_doc_type,
      payment_method, invoice_status, estimate_status, service_unit, document_kind, media_tag_kind,
      upload_status, media_visibility, media_kind, time_entry_status, time_entry_method,
      client_visibility_mode, project_status, customer_source, employment_type, membership_status, membership_role`);
  }
}
