-- ============================================================================
-- ShopFlow V1 — Canonical Supabase / PostgreSQL fresh-install database
-- Author: QuantumCodr / ShopFlow contributors
--
-- PURPOSE
--   One authoritative database definition for the current Flutter V1 app.
--   Includes schema, indexes, row-level security, auth/profile setup, and the
--   three transactional RPCs called by Flutter:
--     - receive_stock
--     - adjust_stock
--     - complete_sale
--
-- INSTALLATION
--   Run ONLY against a new/empty Supabase project.
--   Do NOT run this file over an existing database. Use incremental migrations
--   for an existing installation so that data and live objects are preserved.
--
-- CURRENT APPLICATION CONTRACT
--   - One shop per authenticated owner in V1.
--   - Currency: SLE. Monetary fields are integer minor units (100 = SLE 1.00).
--   - Inventory is NUMERIC(14,3); POS currently sells whole-number quantities.
--   - Product units match ProductService.units in the Flutter repository.
--   - Products are related to categories through product_categories (many-many).
--   - Inventory and sales writes are RPC-only; clients cannot write those tables.
--   - No tax, customer, supplier, purchasing, expense or employee module is
--     implemented in this V1 schema. See docs/PHASE_2_DATA_MODEL.md.
-- ============================================================================

BEGIN;

-- Supabase normally has pgcrypto available, but declare it explicitly.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================================
-- 1. CORE TABLES
-- ============================================================================

CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- V1 deliberately supports one shop per owner. Multi-shop ownership and staff
-- membership require a separate authorization design before this constraint
-- is removed.
CREATE TABLE public.shops (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL UNIQUE
        REFERENCES public.profiles(id) ON DELETE RESTRICT,
    name TEXT NOT NULL
        CHECK (length(trim(name)) BETWEEN 1 AND 100),
    currency_code TEXT NOT NULL DEFAULT 'SLE'
        CHECK (currency_code ~ '^[A-Z]{3}$'),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (id, owner_id)
);

CREATE TABLE public.categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id UUID NOT NULL
        REFERENCES public.shops(id) ON DELETE RESTRICT,
    name TEXT NOT NULL
        CHECK (length(trim(name)) BETWEEN 1 AND 80),
    description TEXT
        CHECK (description IS NULL OR length(description) <= 500),
    image_path TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (shop_id, id),
    UNIQUE (shop_id, name)
);

CREATE TABLE public.products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id UUID NOT NULL
        REFERENCES public.shops(id) ON DELETE RESTRICT,
    name TEXT NOT NULL
        CHECK (length(trim(name)) BETWEEN 1 AND 150),
    sku TEXT
        CHECK (
            sku IS NULL
            OR (
                length(sku) <= 50
                AND sku = upper(trim(sku))
                AND sku <> ''
            )
        ),
    unit TEXT NOT NULL DEFAULT 'piece'
        CHECK (
            unit IN (
                'piece', 'kg', 'g', 'litre', 'ml',
                'pack', 'box', 'bottle', 'dozen'
            )
        ),
    cost_price_minor BIGINT NOT NULL DEFAULT 0
        CHECK (cost_price_minor >= 0),
    selling_price_minor BIGINT NOT NULL
        CHECK (selling_price_minor >= 0),
    -- Product model and ProductService currently use an integer reorder level.
    reorder_level BIGINT NOT NULL DEFAULT 0
        CHECK (reorder_level >= 0),
    image_path TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (shop_id, id),
    UNIQUE (shop_id, sku)
);

-- Product/category membership is many-to-many. Do not add category_id to
-- products; the Flutter CategoryRepository uses this junction table.
CREATE TABLE public.product_categories (
    shop_id UUID NOT NULL
        REFERENCES public.shops(id) ON DELETE CASCADE,
    product_id UUID NOT NULL,
    category_id UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT product_categories_pkey
        PRIMARY KEY (shop_id, product_id, category_id),
    CONSTRAINT product_categories_product_same_shop_fk
        FOREIGN KEY (shop_id, product_id)
        REFERENCES public.products(shop_id, id) ON DELETE CASCADE,
    CONSTRAINT product_categories_category_same_shop_fk
        FOREIGN KEY (shop_id, category_id)
        REFERENCES public.categories(shop_id, id) ON DELETE CASCADE
);

CREATE TABLE public.inventory (
    product_id UUID PRIMARY KEY,
    shop_id UUID NOT NULL
        REFERENCES public.shops(id) ON DELETE RESTRICT,
    quantity NUMERIC(14,3) NOT NULL DEFAULT 0
        CHECK (quantity >= 0),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (shop_id, product_id),
    CONSTRAINT inventory_product_same_shop_fk
        FOREIGN KEY (shop_id, product_id)
        REFERENCES public.products(shop_id, id) ON DELETE RESTRICT
);

CREATE TABLE public.stock_movements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id UUID NOT NULL
        REFERENCES public.shops(id) ON DELETE RESTRICT,
    product_id UUID NOT NULL,
    movement_type TEXT NOT NULL
        CHECK (
            movement_type IN (
                'opening_stock', 'stock_in', 'sale', 'adjustment_in',
                'adjustment_out', 'damaged', 'returned'
            )
        ),
    -- Positive = stock added; negative = stock removed.
    quantity_delta NUMERIC(14,3) NOT NULL
        CHECK (quantity_delta <> 0),
    reason TEXT
        CHECK (reason IS NULL OR length(reason) <= 500),
    reference_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT stock_movements_product_same_shop_fk
        FOREIGN KEY (shop_id, product_id)
        REFERENCES public.products(shop_id, id) ON DELETE RESTRICT
);

CREATE TABLE public.sales (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id UUID NOT NULL
        REFERENCES public.shops(id) ON DELETE RESTRICT,
    sale_number BIGINT GENERATED ALWAYS AS IDENTITY,
    status TEXT NOT NULL DEFAULT 'completed'
        CHECK (status IN ('completed', 'voided')),
    subtotal_minor BIGINT NOT NULL CHECK (subtotal_minor >= 0),
    discount_minor BIGINT NOT NULL DEFAULT 0
        CHECK (discount_minor >= 0 AND discount_minor <= subtotal_minor),
    total_minor BIGINT NOT NULL
        CHECK (total_minor >= 0 AND total_minor = subtotal_minor - discount_minor),
    amount_paid_minor BIGINT NOT NULL
        CHECK (amount_paid_minor >= total_minor),
    change_minor BIGINT NOT NULL
        CHECK (change_minor >= 0 AND change_minor = amount_paid_minor - total_minor),
    payment_method TEXT NOT NULL DEFAULT 'cash'
        CHECK (payment_method IN ('cash', 'mobile_money', 'card', 'other')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (shop_id, id),
    UNIQUE (shop_id, sale_number)
);

CREATE TABLE public.sale_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id UUID NOT NULL
        REFERENCES public.shops(id) ON DELETE RESTRICT,
    sale_id UUID NOT NULL,
    product_id UUID NOT NULL,
    -- Snapshot fields preserve the transaction details if product data changes.
    product_name TEXT NOT NULL,
    quantity NUMERIC(14,3) NOT NULL CHECK (quantity > 0),
    unit_price_minor BIGINT NOT NULL CHECK (unit_price_minor >= 0),
    unit_cost_minor BIGINT NOT NULL DEFAULT 0 CHECK (unit_cost_minor >= 0),
    line_total_minor BIGINT NOT NULL
        CHECK (
            line_total_minor >= 0
            AND line_total_minor = ROUND(quantity * unit_price_minor)::BIGINT
        ),
    CONSTRAINT sale_items_sale_same_shop_fk
        FOREIGN KEY (shop_id, sale_id)
        REFERENCES public.sales(shop_id, id) ON DELETE RESTRICT,
    CONSTRAINT sale_items_product_same_shop_fk
        FOREIGN KEY (shop_id, product_id)
        REFERENCES public.products(shop_id, id) ON DELETE RESTRICT
);

-- ============================================================================
-- 2. INDEXES
-- ============================================================================

CREATE INDEX categories_shop_active_idx
    ON public.categories(shop_id, is_active);

CREATE INDEX products_shop_active_name_idx
    ON public.products(shop_id, is_active, name);

CREATE INDEX product_categories_category_idx
    ON public.product_categories(shop_id, category_id, product_id);

CREATE INDEX inventory_shop_idx
    ON public.inventory(shop_id);

CREATE INDEX stock_movements_shop_created_idx
    ON public.stock_movements(shop_id, created_at DESC);

CREATE INDEX stock_movements_product_created_idx
    ON public.stock_movements(shop_id, product_id, created_at DESC);

CREATE INDEX sales_shop_created_idx
    ON public.sales(shop_id, created_at DESC);

CREATE INDEX sale_items_sale_idx
    ON public.sale_items(shop_id, sale_id);

CREATE INDEX sale_items_product_idx
    ON public.sale_items(shop_id, product_id);

-- ============================================================================
-- 3. SHOP OWNERSHIP HELPER AND ROW LEVEL SECURITY
-- ============================================================================

-- SECURITY DEFINER prevents recursive evaluation of shops RLS when ownership
-- is checked by policies on other shop-owned tables.
CREATE OR REPLACE FUNCTION public.owns_shop(p_shop_id UUID)
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
    SELECT EXISTS (
        SELECT 1
        FROM public.shops AS s
        WHERE s.id = p_shop_id
          AND s.owner_id = (SELECT auth.uid())
          AND s.is_active IS TRUE
    );
$function$;

REVOKE ALL ON FUNCTION public.owns_shop(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owns_shop(UUID) TO authenticated;

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shops ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sale_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY profiles_select_own ON public.profiles
    FOR SELECT TO authenticated
    USING (id = (SELECT auth.uid()));

CREATE POLICY profiles_insert_own ON public.profiles
    FOR INSERT TO authenticated
    WITH CHECK (id = (SELECT auth.uid()));

CREATE POLICY profiles_update_own ON public.profiles
    FOR UPDATE TO authenticated
    USING (id = (SELECT auth.uid()))
    WITH CHECK (id = (SELECT auth.uid()));

CREATE POLICY shops_select_own ON public.shops
    FOR SELECT TO authenticated
    USING (owner_id = (SELECT auth.uid()));

CREATE POLICY shops_insert_own ON public.shops
    FOR INSERT TO authenticated
    WITH CHECK (owner_id = (SELECT auth.uid()));

CREATE POLICY shops_update_own ON public.shops
    FOR UPDATE TO authenticated
    USING (owner_id = (SELECT auth.uid()))
    WITH CHECK (owner_id = (SELECT auth.uid()));

CREATE POLICY categories_select_own_shop ON public.categories
    FOR SELECT TO authenticated
    USING ((SELECT public.owns_shop(shop_id)));

CREATE POLICY categories_insert_own_shop ON public.categories
    FOR INSERT TO authenticated
    WITH CHECK ((SELECT public.owns_shop(shop_id)));

CREATE POLICY categories_update_own_shop ON public.categories
    FOR UPDATE TO authenticated
    USING ((SELECT public.owns_shop(shop_id)))
    WITH CHECK ((SELECT public.owns_shop(shop_id)));

CREATE POLICY products_select_own_shop ON public.products
    FOR SELECT TO authenticated
    USING ((SELECT public.owns_shop(shop_id)));

CREATE POLICY products_insert_own_shop ON public.products
    FOR INSERT TO authenticated
    WITH CHECK ((SELECT public.owns_shop(shop_id)));

CREATE POLICY products_update_own_shop ON public.products
    FOR UPDATE TO authenticated
    USING ((SELECT public.owns_shop(shop_id)))
    WITH CHECK ((SELECT public.owns_shop(shop_id)));

CREATE POLICY product_categories_select_own_shop
    ON public.product_categories FOR SELECT TO authenticated
    USING ((SELECT public.owns_shop(shop_id)));

CREATE POLICY product_categories_insert_own_shop
    ON public.product_categories FOR INSERT TO authenticated
    WITH CHECK ((SELECT public.owns_shop(shop_id)));

CREATE POLICY product_categories_delete_own_shop
    ON public.product_categories FOR DELETE TO authenticated
    USING ((SELECT public.owns_shop(shop_id)));

-- These tables are intentionally read-only to the authenticated client.
-- All stock and sale mutations go through SECURITY DEFINER RPC functions.
CREATE POLICY inventory_select_own_shop ON public.inventory
    FOR SELECT TO authenticated
    USING ((SELECT public.owns_shop(shop_id)));

CREATE POLICY stock_movements_select_own_shop ON public.stock_movements
    FOR SELECT TO authenticated
    USING ((SELECT public.owns_shop(shop_id)));

CREATE POLICY sales_select_own_shop ON public.sales
    FOR SELECT TO authenticated
    USING ((SELECT public.owns_shop(shop_id)));

CREATE POLICY sale_items_select_own_shop ON public.sale_items
    FOR SELECT TO authenticated
    USING ((SELECT public.owns_shop(shop_id)));

GRANT SELECT, INSERT, UPDATE ON public.profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.shops TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.categories TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.products TO authenticated;
GRANT SELECT, INSERT, DELETE ON public.product_categories TO authenticated;
GRANT SELECT ON public.inventory TO authenticated;
GRANT SELECT ON public.stock_movements TO authenticated;
GRANT SELECT ON public.sales TO authenticated;
GRANT SELECT ON public.sale_items TO authenticated;

-- ============================================================================
-- 4. AUTH PROFILE TRIGGER
-- ============================================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
    INSERT INTO public.profiles (id, full_name)
    VALUES (
        NEW.id,
        NULLIF(TRIM(NEW.raw_user_meta_data ->> 'full_name'), '')
    );

    RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.handle_new_user()
    FROM PUBLIC, anon, authenticated;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- ============================================================================
-- 5. INITIALIZE A ZERO BALANCE WHEN A PRODUCT IS CREATED
-- ============================================================================

CREATE OR REPLACE FUNCTION public.initialize_product_inventory()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $function$
BEGIN
    INSERT INTO public.inventory (product_id, shop_id, quantity)
    VALUES (NEW.id, NEW.shop_id, 0)
    ON CONFLICT (product_id) DO NOTHING;

    RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.initialize_product_inventory()
    FROM PUBLIC, anon, authenticated;

CREATE TRIGGER trg_products_initialize_inventory
    AFTER INSERT ON public.products
    FOR EACH ROW
    EXECUTE FUNCTION public.initialize_product_inventory();

-- ============================================================================
-- 6. RECEIVE STOCK RPC — called by InventoryRepository.receiveStock()
-- ============================================================================

CREATE OR REPLACE FUNCTION public.receive_stock(
    p_shop_id UUID,
    p_product_id UUID,
    p_quantity NUMERIC,
    p_reason TEXT DEFAULT NULL,
    p_reference_id UUID DEFAULT NULL
)
RETURNS TABLE (
    result_product_id UUID,
    result_shop_id UUID,
    result_new_quantity NUMERIC,
    result_movement_id UUID
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $function$
DECLARE
    v_new_quantity NUMERIC(14,3);
    v_movement_id UUID;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Authentication is required.'
            USING ERRCODE = '42501';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.shops AS s
        WHERE s.id = p_shop_id
          AND s.owner_id = auth.uid()
          AND s.is_active IS TRUE
    ) THEN
        RAISE EXCEPTION 'You do not have permission to receive stock for this shop.'
            USING ERRCODE = '42501';
    END IF;

    IF p_quantity IS NULL OR p_quantity <= 0
       OR p_quantity <> ROUND(p_quantity, 3) THEN
        RAISE EXCEPTION 'Quantity must be positive and have no more than 3 decimal places.'
            USING ERRCODE = '22023';
    END IF;

    IF p_reason IS NOT NULL AND length(p_reason) > 500 THEN
        RAISE EXCEPTION 'The reason cannot exceed 500 characters.'
            USING ERRCODE = '22023';
    END IF;

    -- Lock the product first. All stock-changing RPCs use this lock order so
    -- concurrent receipts, adjustments and sales serialize per product.
    PERFORM 1
    FROM public.products AS p
    WHERE p.id = p_product_id
      AND p.shop_id = p_shop_id
      AND p.is_active IS TRUE
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'The product is missing, inactive or belongs to another shop.'
            USING ERRCODE = '22023';
    END IF;

    INSERT INTO public.inventory (product_id, shop_id, quantity)
    VALUES (p_product_id, p_shop_id, 0)
    ON CONFLICT (product_id) DO NOTHING;

    UPDATE public.inventory AS i
    SET quantity = i.quantity + p_quantity,
        updated_at = NOW()
    WHERE i.product_id = p_product_id
      AND i.shop_id = p_shop_id
    RETURNING i.quantity INTO v_new_quantity;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'The inventory record could not be updated.';
    END IF;

    INSERT INTO public.stock_movements (
        shop_id, product_id, movement_type, quantity_delta, reason, reference_id
    )
    VALUES (
        p_shop_id,
        p_product_id,
        'stock_in',
        p_quantity,
        COALESCE(NULLIF(BTRIM(p_reason), ''), 'Stock received'),
        p_reference_id
    )
    RETURNING id INTO v_movement_id;

    RETURN QUERY
    SELECT p_product_id, p_shop_id, v_new_quantity, v_movement_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.receive_stock(UUID, UUID, NUMERIC, TEXT, UUID)
    FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.receive_stock(UUID, UUID, NUMERIC, TEXT, UUID)
    TO authenticated;

-- ============================================================================
-- 7. ADJUST STOCK RPC — called by InventoryRepository.adjustStock()
-- ============================================================================

CREATE OR REPLACE FUNCTION public.adjust_stock(
    p_shop_id UUID,
    p_product_id UUID,
    p_movement_type TEXT,
    p_quantity NUMERIC,
    p_reason TEXT,
    p_reference_id UUID DEFAULT NULL
)
RETURNS TABLE (
    result_product_id UUID,
    result_shop_id UUID,
    result_new_quantity NUMERIC,
    result_movement_id UUID
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $function$
DECLARE
    v_quantity_delta NUMERIC(14,3);
    v_new_quantity NUMERIC(14,3);
    v_existing_quantity NUMERIC(14,3);
    v_movement_id UUID;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Authentication is required.'
            USING ERRCODE = '42501';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.shops AS s
        WHERE s.id = p_shop_id
          AND s.owner_id = auth.uid()
          AND s.is_active IS TRUE
    ) THEN
        RAISE EXCEPTION 'You do not have permission to adjust stock for this shop.'
            USING ERRCODE = '42501';
    END IF;

    IF p_movement_type IS NULL OR p_movement_type NOT IN (
        'adjustment_in', 'adjustment_out', 'damaged', 'returned'
    ) THEN
        RAISE EXCEPTION 'Unsupported stock adjustment type.'
            USING ERRCODE = '22023';
    END IF;

    IF p_quantity IS NULL OR p_quantity <= 0
       OR p_quantity <> ROUND(p_quantity, 3) THEN
        RAISE EXCEPTION 'Quantity must be positive and have no more than 3 decimal places.'
            USING ERRCODE = '22023';
    END IF;

    IF p_reason IS NULL OR BTRIM(p_reason) = '' THEN
        RAISE EXCEPTION 'A reason is required for stock adjustments.'
            USING ERRCODE = '22023';
    END IF;

    IF length(BTRIM(p_reason)) > 500 THEN
        RAISE EXCEPTION 'The reason cannot exceed 500 characters.'
            USING ERRCODE = '22023';
    END IF;

    -- Inactive products may still need historical stock corrections.
    PERFORM 1
    FROM public.products AS p
    WHERE p.id = p_product_id
      AND p.shop_id = p_shop_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'The product does not belong to this shop.'
            USING ERRCODE = '22023';
    END IF;

    v_quantity_delta := CASE
        WHEN p_movement_type IN ('adjustment_in', 'returned') THEN p_quantity
        WHEN p_movement_type IN ('adjustment_out', 'damaged') THEN -p_quantity
    END;

    INSERT INTO public.inventory (product_id, shop_id, quantity)
    VALUES (p_product_id, p_shop_id, 0)
    ON CONFLICT (product_id) DO NOTHING;

    UPDATE public.inventory AS i
    SET quantity = i.quantity + v_quantity_delta,
        updated_at = NOW()
    WHERE i.product_id = p_product_id
      AND i.shop_id = p_shop_id
      AND i.quantity + v_quantity_delta >= 0
    RETURNING i.quantity INTO v_new_quantity;

    IF NOT FOUND THEN
        SELECT i.quantity INTO v_existing_quantity
        FROM public.inventory AS i
        WHERE i.product_id = p_product_id
          AND i.shop_id = p_shop_id;

        RAISE EXCEPTION 'Insufficient stock. Available quantity: %.',
            COALESCE(v_existing_quantity, 0)
            USING ERRCODE = '22023';
    END IF;

    INSERT INTO public.stock_movements (
        shop_id, product_id, movement_type, quantity_delta, reason, reference_id
    )
    VALUES (
        p_shop_id,
        p_product_id,
        p_movement_type,
        v_quantity_delta,
        BTRIM(p_reason),
        p_reference_id
    )
    RETURNING id INTO v_movement_id;

    RETURN QUERY
    SELECT p_product_id, p_shop_id, v_new_quantity, v_movement_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.adjust_stock(UUID, UUID, TEXT, NUMERIC, TEXT, UUID)
    FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.adjust_stock(UUID, UUID, TEXT, NUMERIC, TEXT, UUID)
    TO authenticated;

-- ============================================================================
-- 8. COMPLETE SALE RPC — called by PosRepository.completeSale()
-- ============================================================================

CREATE OR REPLACE FUNCTION public.complete_sale(
    p_shop_id UUID,
    p_items JSONB,
    p_amount_paid_minor BIGINT,
    p_payment_method TEXT DEFAULT 'cash',
    p_discount_minor BIGINT DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $function$
DECLARE
    v_line RECORD;
    v_item_count BIGINT;
    v_distinct_product_count BIGINT;
    v_inserted_item_count BIGINT;
    v_updated_inventory_count BIGINT;
    v_product_name TEXT;
    v_selling_price_minor BIGINT;
    v_cost_price_minor BIGINT;
    v_available_quantity NUMERIC(14,3);
    v_subtotal_minor BIGINT := 0;
    v_total_minor BIGINT;
    v_change_minor BIGINT;
    v_sale_id UUID;
    v_sale_number BIGINT;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Authentication is required.'
            USING ERRCODE = '42501';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.shops AS s
        WHERE s.id = p_shop_id
          AND s.owner_id = auth.uid()
          AND s.is_active IS TRUE
    ) THEN
        RAISE EXCEPTION 'You do not have permission to complete sales for this shop.'
            USING ERRCODE = '42501';
    END IF;

    IF p_items IS NULL THEN
        RAISE EXCEPTION 'A sale must contain at least one item.'
            USING ERRCODE = '22023';
    END IF;

    IF jsonb_typeof(p_items) IS DISTINCT FROM 'array' THEN
        RAISE EXCEPTION 'Sale items must be supplied as a JSON array.'
            USING ERRCODE = '22023';
    END IF;

    IF jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION 'A sale must contain at least one item.'
            USING ERRCODE = '22023';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM jsonb_array_elements(p_items) AS item(value)
        WHERE jsonb_typeof(item.value) IS DISTINCT FROM 'object'
           OR NOT (item.value ? 'product_id')
           OR NOT (item.value ? 'quantity')
    ) THEN
        RAISE EXCEPTION 'Each sale item must contain product_id and quantity.'
            USING ERRCODE = '22023';
    END IF;

    -- Casts also validate that product_id and quantity have the expected types.
    SELECT COUNT(*), COUNT(DISTINCT x.product_id)
    INTO v_item_count, v_distinct_product_count
    FROM jsonb_to_recordset(p_items) AS x(
        product_id UUID,
        quantity NUMERIC
    );

    IF v_item_count = 0 OR v_item_count <> v_distinct_product_count THEN
        RAISE EXCEPTION 'The sale contains missing or duplicate products.'
            USING ERRCODE = '22023';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM jsonb_to_recordset(p_items) AS x(
            product_id UUID,
            quantity NUMERIC
        )
        WHERE x.product_id IS NULL
           OR x.quantity IS NULL
           OR x.quantity <= 0
           OR x.quantity <> TRUNC(x.quantity)
    ) THEN
        RAISE EXCEPTION 'POS quantities must be positive whole numbers in V1.'
            USING ERRCODE = '22023';
    END IF;

    IF p_amount_paid_minor IS NULL OR p_amount_paid_minor < 0 THEN
        RAISE EXCEPTION 'The payment amount cannot be negative.'
            USING ERRCODE = '22023';
    END IF;

    IF p_discount_minor IS NULL OR p_discount_minor < 0 THEN
        RAISE EXCEPTION 'The discount cannot be negative.'
            USING ERRCODE = '22023';
    END IF;

    IF p_payment_method IS NULL OR p_payment_method NOT IN (
        'cash', 'mobile_money', 'card', 'other'
    ) THEN
        RAISE EXCEPTION 'Unsupported payment method.'
            USING ERRCODE = '22023';
    END IF;

    -- Lock product rows in a deterministic order. receive_stock and
    -- adjust_stock lock the same product row before changing inventory.
    -- This serializes concurrent stock mutations and reduces deadlock risk.
    FOR v_line IN
        SELECT x.product_id, x.quantity
        FROM jsonb_to_recordset(p_items) AS x(
            product_id UUID,
            quantity NUMERIC
        )
        ORDER BY x.product_id
    LOOP
        SELECT p.name, p.selling_price_minor, p.cost_price_minor
        INTO v_product_name, v_selling_price_minor, v_cost_price_minor
        FROM public.products AS p
        WHERE p.id = v_line.product_id
          AND p.shop_id = p_shop_id
          AND p.is_active IS TRUE
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'A selected product is unavailable or does not belong to this shop.'
                USING ERRCODE = '22023';
        END IF;

        INSERT INTO public.inventory (product_id, shop_id, quantity)
        VALUES (v_line.product_id, p_shop_id, 0)
        ON CONFLICT (product_id) DO NOTHING;

        SELECT i.quantity
        INTO v_available_quantity
        FROM public.inventory AS i
        WHERE i.product_id = v_line.product_id
          AND i.shop_id = p_shop_id
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Inventory could not be found for a selected product.';
        END IF;

        IF v_available_quantity < v_line.quantity THEN
            RAISE EXCEPTION 'Insufficient stock for product %. Available: %, requested: %.',
                v_product_name, v_available_quantity, v_line.quantity
                USING ERRCODE = '22023';
        END IF;

        v_subtotal_minor := v_subtotal_minor
            + (v_line.quantity * v_selling_price_minor)::BIGINT;
    END LOOP;

    IF p_discount_minor > v_subtotal_minor THEN
        RAISE EXCEPTION 'The discount cannot exceed the sale subtotal.'
            USING ERRCODE = '22023';
    END IF;

    v_total_minor := v_subtotal_minor - p_discount_minor;

    IF p_amount_paid_minor < v_total_minor THEN
        RAISE EXCEPTION 'The amount received is less than the sale total.'
            USING ERRCODE = '22023';
    END IF;

    v_change_minor := p_amount_paid_minor - v_total_minor;

    INSERT INTO public.sales (
        shop_id,
        status,
        subtotal_minor,
        discount_minor,
        total_minor,
        amount_paid_minor,
        change_minor,
        payment_method
    )
    VALUES (
        p_shop_id,
        'completed',
        v_subtotal_minor,
        p_discount_minor,
        v_total_minor,
        p_amount_paid_minor,
        v_change_minor,
        p_payment_method
    )
    RETURNING id, sale_number
    INTO v_sale_id, v_sale_number;

    -- Product rows remain locked from validation through these writes.
    INSERT INTO public.sale_items (
        shop_id,
        sale_id,
        product_id,
        product_name,
        quantity,
        unit_price_minor,
        unit_cost_minor,
        line_total_minor
    )
    SELECT
        p_shop_id,
        v_sale_id,
        p.id,
        p.name,
        x.quantity,
        p.selling_price_minor,
        p.cost_price_minor,
        (x.quantity * p.selling_price_minor)::BIGINT
    FROM jsonb_to_recordset(p_items) AS x(
        product_id UUID,
        quantity NUMERIC
    )
    JOIN public.products AS p
      ON p.id = x.product_id
     AND p.shop_id = p_shop_id;

    GET DIAGNOSTICS v_inserted_item_count = ROW_COUNT;
    IF v_inserted_item_count <> v_item_count THEN
        RAISE EXCEPTION 'Not all sale items could be recorded.';
    END IF;

    UPDATE public.inventory AS i
    SET quantity = i.quantity - x.quantity,
        updated_at = NOW()
    FROM jsonb_to_recordset(p_items) AS x(
        product_id UUID,
        quantity NUMERIC
    )
    WHERE i.product_id = x.product_id
      AND i.shop_id = p_shop_id
      AND i.quantity >= x.quantity;

    GET DIAGNOSTICS v_updated_inventory_count = ROW_COUNT;
    IF v_updated_inventory_count <> v_item_count THEN
        RAISE EXCEPTION 'Inventory changed before the sale could be completed.'
            USING ERRCODE = '40001';
    END IF;

    INSERT INTO public.stock_movements (
        shop_id,
        product_id,
        movement_type,
        quantity_delta,
        reason,
        reference_id
    )
    SELECT
        p_shop_id,
        x.product_id,
        'sale',
        -x.quantity,
        'POS sale',
        v_sale_id
    FROM jsonb_to_recordset(p_items) AS x(
        product_id UUID,
        quantity NUMERIC
    );

    -- The Flutter PosRepository normalizes these response keys and the
    -- PosReceipt model reads sale_id, sale_number, subtotal, total, payment,
    -- and change. Keep both canonical *_minor and expected receipt keys.
    RETURN jsonb_build_object(
        'sale_id', v_sale_id,
        'sale_number', v_sale_number,
        'subtotal', v_subtotal_minor,
        'subtotal_minor', v_subtotal_minor,
        'discount_minor', p_discount_minor,
        'total', v_total_minor,
        'total_minor', v_total_minor,
        'payment', p_amount_paid_minor,
        'amount_paid_minor', p_amount_paid_minor,
        'change', v_change_minor,
        'change_minor', v_change_minor,
        'payment_method', p_payment_method
    );
END;
$function$;

REVOKE ALL ON FUNCTION public.complete_sale(UUID, JSONB, BIGINT, TEXT, BIGINT)
    FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.complete_sale(UUID, JSONB, BIGINT, TEXT, BIGINT)
    TO authenticated;

COMMIT;

-- ============================================================================
-- 9. POST-INSTALL VERIFICATION (READ ONLY)
-- These queries run after the schema transaction commits. They confirm that
-- the expected V1 tables, RLS settings, RPC functions and key columns exist.
-- They do not insert, update or delete application data.
-- ============================================================================

-- 9.1 Confirm all expected V1 tables exist.
SELECT expected.table_name,
       (actual.table_name IS NOT NULL) AS table_exists
FROM (VALUES
    ('profiles'), ('shops'), ('categories'), ('products'),
    ('product_categories'), ('inventory'), ('stock_movements'),
    ('sales'), ('sale_items')
) AS expected(table_name)
LEFT JOIN information_schema.tables AS actual
  ON actual.table_schema = 'public'
 AND actual.table_name = expected.table_name
ORDER BY expected.table_name;

-- 9.2 Confirm Row Level Security is enabled on every V1 table.
SELECT c.relname AS table_name,
       c.relrowsecurity AS rls_enabled
FROM pg_class AS c
JOIN pg_namespace AS n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relkind = 'r'
  AND c.relname IN (
      'profiles', 'shops', 'categories', 'products',
      'product_categories', 'inventory', 'stock_movements',
      'sales', 'sale_items'
  )
ORDER BY c.relname;

-- 9.3 Confirm the ownership helper and business RPCs exist.
SELECT p.proname AS function_name,
       pg_get_function_identity_arguments(p.oid) AS arguments,
       has_function_privilege('authenticated', p.oid, 'EXECUTE')
           AS authenticated_can_execute
FROM pg_proc AS p
JOIN pg_namespace AS n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN (
      'owns_shop', 'receive_stock', 'adjust_stock', 'complete_sale'
  )
ORDER BY p.proname;

-- 9.4 Confirm important columns used by the Flutter application exist.
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND (
      (table_name = 'products' AND column_name IN (
          'id', 'shop_id', 'name', 'unit', 'cost_price_minor',
          'selling_price_minor', 'reorder_level', 'is_active'
      ))
      OR (table_name = 'inventory' AND column_name IN (
          'product_id', 'shop_id', 'quantity', 'updated_at'
      ))
      OR (table_name = 'stock_movements' AND column_name IN (
          'product_id', 'movement_type', 'quantity_delta', 'reason', 'reference_id'
      ))
      OR (table_name = 'sales' AND column_name IN (
          'id', 'sale_number', 'subtotal_minor', 'discount_minor',
          'total_minor', 'amount_paid_minor', 'change_minor', 'payment_method'
      ))
      OR (table_name = 'sale_items' AND column_name IN (
          'sale_id', 'product_id', 'product_name', 'quantity',
          'unit_price_minor', 'unit_cost_minor', 'line_total_minor'
      ))
  )
ORDER BY table_name, ordinal_position;

-- These checks confirm database structure only. They do not replace testing
-- authenticated ownership, stock receipt/adjustment, POS checkout or rollback
-- behaviour through the Flutter app or a disposable Supabase test project.