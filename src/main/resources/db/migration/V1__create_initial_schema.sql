-- USERS TABLE
CREATE TABLE users
(
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    phone      TEXT        NOT NULL UNIQUE,
    name       TEXT,
    cohort     TEXT        NOT NULL DEFAULT 'pilot',
    consent_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT users_cohort_check
        CHECK (cohort IN ('pilot', 'organic'))
);

-- VENDORS TABLE

CREATE TABLE vendors
(
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email         TEXT        NOT NULL,
    password_hash TEXT        NOT NULL,
    business_name TEXT        NOT NULL,
    owner_phone   TEXT,
    logo_url      TEXT,
    brand_color   TEXT,
    status        TEXT        NOT NULL DEFAULT 'pending',
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT vendors_email_uk
        UNIQUE (email),

    CONSTRAINT vendors_status_ck
        CHECK (status IN ('pending', 'approved', 'suspended'))
);

-- STORES TABLE

CREATE TABLE stores
(
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    vendor_id   BIGINT      NOT NULL,
    name        TEXT        NOT NULL,
    address     TEXT        NOT NULL,
    category    TEXT        NOT NULL,
    hmac_secret TEXT        NOT NULL,
    active      BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT stores_vendor_id_fk
        FOREIGN KEY (vendor_id)
            REFERENCES vendors (id)
            ON DELETE RESTRICT,
    CONSTRAINT stores_category_ck
        CHECK (category IN ('salon', 'food', 'fitness', 'retail', 'spa'))
);

CREATE INDEX stores_vendor_id_ix
    ON stores (vendor_id);


-- SERVICES TABLE

CREATE TABLE services
(
    id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    store_id         BIGINT         NOT NULL,
    name             TEXT           NOT NULL,
    base_price       NUMERIC(12, 2) NOT NULL,
    duration_minutes INTEGER,
    active           BOOLEAN        NOT NULL DEFAULT TRUE,
    created_at       TIMESTAMPTZ    NOT NULL DEFAULT NOW(),

    CONSTRAINT services_store_id_fk
        FOREIGN KEY (store_id)
            REFERENCES stores (id)
            ON DELETE RESTRICT,

    CONSTRAINT services_base_price_ck
        CHECK (base_price >= 0),

    CONSTRAINT services_duration_ck
        CHECK (duration_minutes > 0)
);

CREATE INDEX services_store_id_ix
    ON services (store_id);


-- OFFERS TABLE

CREATE TABLE offers
(
    id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    vendor_id        BIGINT         NOT NULL,
    title            TEXT           NOT NULL,
    description      TEXT,

    discount_type    TEXT           NOT NULL,
    discount_value   NUMERIC(12, 2) NOT NULL,

    valid_from       TIMESTAMPTZ    NOT NULL,
    valid_to         TIMESTAMPTZ    NOT NULL,

    max_redemptions  INTEGER,
    redeemed_count   BIGINT         NOT NULL DEFAULT 0,

    status           TEXT           NOT NULL DEFAULT 'draft',

    created_at       TIMESTAMPTZ    NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ    NOT NULL DEFAULT now(),

    badge            TEXT,
    terms            TEXT,
    display_priority INTEGER        NOT NULL DEFAULT 0,

    CONSTRAINT offers_badge_ck
        CHECK (badge IN ('featured','limited','popular')),

    CONSTRAINT offers_vendor_id_fk
        FOREIGN KEY (vendor_id)
            REFERENCES vendors (id)
            ON DELETE RESTRICT,

    CONSTRAINT offers_valid_window_ck
        CHECK (valid_to > valid_from),

    CONSTRAINT offers_discount_value_ck
        CHECK (discount_value > 0),

    CONSTRAINT offers_percent_range_ck
        CHECK (
            discount_type <> 'percent'
                OR discount_value BETWEEN 0 AND 100
            ),

    CONSTRAINT offers_discount_type_ck
        CHECK (discount_type IN ('percent', 'flat')),

    CONSTRAINT offers_status_ck
        CHECK (status IN ('draft', 'live', 'paused', 'ended')),

    CONSTRAINT offers_redeemed_count_ck
        CHECK (redeemed_count >= 0)

);

CREATE INDEX offers_vendor_id_ix
    ON offers (vendor_id);

CREATE INDEX offers_status_validity_ix
    ON offers (status, valid_from, valid_to);


-- OFFER_SERVICES TABLE

CREATE TABLE offer_services
(
    offer_id   BIGINT NOT NULL,
    service_id BIGINT NOT NULL,

    CONSTRAINT offer_services_pk
        PRIMARY KEY (offer_id, service_id),

    CONSTRAINT offer_services_offer_id_fk
        FOREIGN KEY (offer_id)
            REFERENCES offers (id)
            ON DELETE CASCADE,

    CONSTRAINT offer_services_service_id_fk
        FOREIGN KEY (service_id)
            REFERENCES services (id)
            ON DELETE CASCADE
);

CREATE INDEX offer_services_service_id_ix
    ON offer_services (service_id);


-- OFFER_STORES TABLE

CREATE TABLE offer_stores
(
    offer_id BIGINT NOT NULL,
    store_id BIGINT NOT NULL,

    CONSTRAINT offer_stores_pk
        PRIMARY KEY (offer_id, store_id),

    CONSTRAINT offer_stores_offer_id_fk
        FOREIGN KEY (offer_id)
            REFERENCES offers (id)
            ON DELETE CASCADE,

    CONSTRAINT offer_stores_store_id_fk
        FOREIGN KEY (store_id)
            REFERENCES stores (id)
            ON DELETE CASCADE
);

CREATE INDEX offer_stores_store_id_ix
    ON offer_stores (store_id);

-- CLAIMS TABLE

CREATE TABLE claims
(
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id     BIGINT      NOT NULL,
    offer_id    BIGINT      NOT NULL,
    claim_token TEXT        NOT NULL,
    status      TEXT        NOT NULL DEFAULT 'active',
    claimed_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at  TIMESTAMPTZ NOT NULL,

    CONSTRAINT claims_user_id_fk
        FOREIGN KEY (user_id)
            REFERENCES users (id)
            ON DELETE RESTRICT,

    CONSTRAINT claims_offer_id_fk
        FOREIGN KEY (offer_id)
            REFERENCES offers (id)
            ON DELETE RESTRICT,

    CONSTRAINT claims_claim_token_uk
        UNIQUE (claim_token),

    CONSTRAINT claims_user_offer_uk
        UNIQUE (user_id, offer_id),

    CONSTRAINT claims_expiry_ck
        CHECK (expires_at > claimed_at),

    CONSTRAINT claims_status_ck
        CHECK (status IN ('active', 'redeemed', 'expired'))
);

CREATE INDEX claims_offer_id_ix
    ON claims (offer_id);

-- REDEMPTIONS TABLE

CREATE TABLE redemptions
(
    id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    claim_id       BIGINT         NOT NULL,
    store_id       BIGINT         NOT NULL,
    service_id     BIGINT         NOT NULL,
    original_price NUMERIC(12, 2) NOT NULL,
    final_price    NUMERIC(12, 2) NOT NULL,
    redeemed_at    TIMESTAMPTZ    NOT NULL DEFAULT NOW(),

    CONSTRAINT redemptions_claim_id_fk
        FOREIGN KEY (claim_id)
            REFERENCES claims (id)
            ON DELETE RESTRICT,

    CONSTRAINT redemptions_store_id_fk
        FOREIGN KEY (store_id)
            REFERENCES stores (id)
            ON DELETE RESTRICT,

    CONSTRAINT redemptions_service_id_fk
        FOREIGN KEY (service_id)
            REFERENCES services (id)
            ON DELETE RESTRICT,

    CONSTRAINT redemptions_claim_id_uk
        UNIQUE (claim_id)
);

CREATE INDEX redemptions_store_id_ix
    ON redemptions (store_id);

CREATE INDEX redemptions_service_id_ix
    ON redemptions (service_id);

CREATE INDEX redemptions_redeemed_at_ix
    ON redemptions (redeemed_at);

--EVENTS TABLE

CREATE TABLE events
(
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    event_type  TEXT        NOT NULL,

    user_id     BIGINT,

    entity_type TEXT        NOT NULL,
    entity_id   BIGINT      NOT NULL,

    payload     JSONB,

    occurred_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT events_event_type_ck
        CHECK (
            event_type IN (
                           'offer_viewed',
                           'claim_created',
                           'message_delivered',
                           'link_opened',
                           'code_attempted',
                           'code_verified',
                           'service_selected',
                           'redemption_completed'
                )
            ),

    CONSTRAINT events_entity_type_ck
        CHECK (
            entity_type IN (
                            'offer',
                            'claim',
                            'redemption'
                )
            )
);

CREATE INDEX events_occurred_at_ix
    ON events (occurred_at);

CREATE INDEX events_event_type_ix
    ON events (event_type);

CREATE INDEX events_user_id_ix
    ON events (user_id);

CREATE INDEX events_entity_ix
    ON events (entity_type, entity_id);


-- WEBHOOK_INBOX TABLE

CREATE TABLE webhook_inbox
(
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    provider            TEXT        NOT NULL,
    provider_message_id TEXT        NOT NULL,
    event_type          TEXT,
    payload             JSONB       NOT NULL,
    status              TEXT        NOT NULL DEFAULT 'received',
    received_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    processed_at        TIMESTAMPTZ,
    error_message       TEXT,

    CONSTRAINT webhook_inbox_provider_message_uk
        UNIQUE (provider, provider_message_id),

    CONSTRAINT webhook_inbox_status_ck
        CHECK (status IN ('received', 'processed', 'failed'))
);

CREATE INDEX webhook_inbox_status_ix
    ON webhook_inbox (status);

