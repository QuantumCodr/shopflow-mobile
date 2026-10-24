-- ============================================================================
-- ShopFlow V1 — Canonical Supabase / PostgreSQL database bootstrap
-- Author: QuantumCodr / ShopFlow contributors
-- Purpose: Fresh-install schema, indexes, RLS, triggers, and stock receiving.
--
-- IMPORTANT
--   1. Run this file ONLY in a fresh Supabase project/database.
--   2. Do not rerun it against an existing database as a migration. Existing
--      installations need incremental migrations so data is preserved.
--   3. This file includes the verified receive_stock transaction. The complete
--      POS sale transaction must be implemented and aligned with the Flutter
--      PosRepository before production; direct client writes to sales,
--      sale_items, inventory, and stock_movements are intentionally not granted.
--   4. Money is stored as integer minor units: SLE 8,000.00 = 800000.
--   5. Category membership is many-to-many through product_categories. There
--      is NO category_id column on products in this canonical schema.
-- ============================================================================

BEGIN;

-- Supabase normally provides pgcrypto, but declare the dependency explicitly.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================================
-- 1. TABLES
-- ============================================================================

-- Profiles: one application profile per authenticated Supabase user.
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Shops: V1 supports one shop per owner.
CREATE TABLE public.shops (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL UNIQUE
        REFERENCES public.profiles(id) ON DELETE RESTRICT,
    name TEXT NOT NULL
        CHECK (length(trim(name)) BETWEEN 1 AND 120),
    currency_code TEXT NOT NULL DEFAULT 'SLE'
        CHECK (currency_code ~ '^[A-Z]{3}$'),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Categories belong to a shop. A category can contain many products.
CREATE TABLE public.categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id UUID NOT NULL
        REFERENCES public.shops(id) ON DELETE RESTRICT,
    name TEXT NOT NULL
        CHECK (length(trim(name)) BETWEEN 1 AND 80),
    description TEXT,
    image_path TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (shop_id, id),
    UNIQUE (shop_id, name)
);

-- Products: do not add category_id here. See product_categories below.
-- Money columns are integer minor units, not whole SLE values.
CREATE TABLE public.products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id UUID NOT NULL
        REFERENCES public.shops(id) ON DELETE RESTRICT,
    name TEXT NOT NULL
        CHECK (length(trim(name)) BETWEEN 1 AND 160),
    sku TEXT,
    unit TEXT NOT NULL DEFAULT 'piece'
        CHECK (
            unit IN (
                'piece', 'pack', 'bottle', 'kg', 'g',
                'litre', 'ml', 'box', 'bag'
            )
        ),
    cost_price_minor BIGINT NOT NULL DEFAULT 0
        CHECK (cost_price_minor >= 0),
    selling_price_minor BIGINT NOT NULL
        CHECK (selling_price_minor >= 0),
    reorder_level NUMERIC(14,3) NOT NULL DEFAULT 0
        CHECK (reorder_level >= 0),
    image_path TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (shop_id, id),
    UNIQUE (shop_id, sku)
);

-- Junction table: products and categories form a many-to-many relationship.
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

-- One inventory balance per product. Inventory quantity may be fractional.
CREATE TABLE public.inventory (
    product_id UUID NOT NULL,
    shop_id UUID NOT NULL
        REFERENCES public.shops(id) ON DELETE RESTRICT,
    quantity NUMERIC(14,3) NOT NULL DEFAULT 0
        CHECK (quantity >= 0),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT inventory_pkey PRIMARY KEY (product_id),
    UNIQUE (shop_id, product_id),
    CONSTRAINT inventory_product_same_shop_fk
        FOREIGN KEY (shop_id, product_id)
        REFERENCES public.products(shop_id, id) ON DELETE RESTRICT
);

-- Stock movement ledger. Every quantity change should have a movement record.
-- Convention: stock additions use positive quantity_delta; reductions use
-- negative quantity_delta (sale, adjustment_out, damaged).
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
    quantity_delta NUMERIC(14,3) NOT NULL
        CHECK (quantity_delta <> 0),
    reason TEXT,
    reference_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT stock_movements_product_same_shop_fk
        FOREIGN KEY (shop_id, product_id)
        REFERENCES public.products(shop_id, id) ON DELETE RESTRICT
);

-- Sales totals and payment amounts are stored in minor currency units.
CREATE TABLE public.sales (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id UUID NOT NULL
        REFERENCES public.shops(id) ON DELETE RESTRICT,
    sale_number BIGINT GENERATED ALWAYS AS IDENTITY,
    status TEXT NOT NULL DEFAULT 'completed'
        CHECK (status IN ('completed', 'voided')),
    subtotal_minor BIGINT NOT NULL CHECK (subtotal_minor >= 0),
    discount_minor BIGINT NOT NULL DEFAULT 0
        CHECK (discount_minor >= 0),
    total_minor BIGINT NOT NULL CHECK (total_minor >= 0),
    amount_paid_minor BIGINT NOT NULL CHECK (amount_paid_minor >= 0),
    change_minor BIGINT NOT NULL DEFAULT 0 CHECK (change_minor >= 0),
    payment_method TEXT NOT NULL DEFAULT 'cash'
        CHECK (payment_method IN ('cash', 'mobile_money', 'card', 'other')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (shop_id, id),
    UNIQUE (shop_id, sale_number)
);

-- Sale-item prices and product names are snapshots from the sale time.
CREATE TABLE public.sale_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id UUID NOT NULL
        REFERENCES public.shops(id) ON DELETE RESTRICT,
    sale_id UUID NOT NULL,
    product_id UUID NOT NULL,
    product_name TEXT NOT NULL,
    quantity NUMERIC(14,3) NOT NULL CHECK (quantity > 0),
    unit_price_minor BIGINT NOT NULL CHECK (unit_price_minor >= 0),
    unit_cost_minor BIGINT NOT NULL DEFAULT 0 CHECK (unit_cost_minor >= 0),
    line_total_minor BIGINT NOT NULL CHECK (line_total_minor >= 0),
    CONSTRAINT sale_items_sale_same_shop_fk
        FOREIGN KEY (shop_id, sale_id)
        REFERENCES public.sales(shop_id, id) ON DELETE RESTRICT,
    CONSTRAINT sale_items_product_same_shop_fk
        FOREIGN KEY (shop_id, product_id)
        REFERENCES public.products(shop_id, id) ON DELETE RESTRICT
);

-- ============================================================================
-- 2. INDEXES
-- Unique constraints above already create indexes for their key columns.
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
-- 3. SHOP OWNERSHIP HELPER AND ROW-LEVEL SECURITY
-- ============================================================================

-- SECURITY DEFINER avoids recursive evaluation of shops RLS when checking
-- ownership. Keep search_path empty and schema-qualify referenced objects.
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

-- Profiles: a user can manage only their own profile.
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

-- Shops: owners can select, create, and update their own shop.
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

-- Categories: owners can select, insert, and update their shop categories.
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

-- Products: owners can select, insert, and update their shop products.
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

-- Product/category assignments: assign/unassign only within the owner's shop.
CREATE POLICY product_categories_select_own_shop
    ON public.product_categories FOR SELECT TO authenticated
    USING ((SELECT public.owns_shop(shop_id)));
CREATE POLICY product_categories_insert_own_shop
    ON public.product_categories FOR INSERT TO authenticated
    WITH CHECK ((SELECT public.owns_shop(shop_id)));
CREATE POLICY product_categories_delete_own_shop
    ON public.product_categories FOR DELETE TO authenticated
    USING ((SELECT public.owns_shop(shop_id)));

-- Inventory and stock movements are read-only to clients. Writes use
-- SECURITY DEFINER database functions so balances and ledger rows cannot be
-- modified independently by the client.
CREATE POLICY inventory_select_own_shop ON public.inventory
    FOR SELECT TO authenticated
    USING ((SELECT public.owns_shop(shop_id)));
CREATE POLICY stock_movements_select_own_shop ON public.stock_movements
    FOR SELECT TO authenticated
    USING ((SELECT public.owns_shop(shop_id)));

-- Sales data is readable by the shop owner. Direct table writes are withheld
-- until the atomic complete_sale RPC is implemented and tested against the
-- Flutter POS repository. Do not solve checkout by granting table-wide writes.
CREATE POLICY sales_select_own_shop ON public.sales
    FOR SELECT TO authenticated
    USING ((SELECT public.owns_shop(shop_id)));
CREATE POLICY sale_items_select_own_shop ON public.sale_items
    FOR SELECT TO authenticated
    USING ((SELECT public.owns_shop(shop_id)));

-- Minimum table privileges for the policies above.
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
-- Create a profile row when Supabase Auth creates a user.
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

REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- ============================================================================
-- 5. INITIALIZE INVENTORY WHEN A PRODUCT IS CREATED
-- New products start at zero; product creation must not invent stock.
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
    ON CONFLICT ON CONSTRAINT inventory_pkey DO NOTHING;

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
-- 6. ATOMIC STOCK-RECEIVING TRANSACTION
-- Fixes incorporated here:
--   * output columns use result_* names to avoid PL/pgSQL name ambiguity;
--   * ON CONFLICT uses the explicit inventory primary-key constraint;
--   * real schema columns: stock_movements.quantity_delta and reason;
--   * owner and active-product checks occur in the database;
--   * inventory update and movement insert commit/rollback together.
-- ============================================================================

CREATE FUNCTION public.receive_stock(
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
    v_authorized_shop UUID;
    v_product_active BOOLEAN;
    v_new_quantity NUMERIC(14,3);
    v_movement_id UUID;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Authentication is required.'
            USING ERRCODE = '42501';
    END IF;

    IF p_quantity IS NULL OR p_quantity <= 0 THEN
        RAISE EXCEPTION 'Quantity must be greater than zero.'
            USING ERRCODE = '22023';
    END IF;

    IF p_quantity <> ROUND(p_quantity, 3) THEN
        RAISE EXCEPTION
            'Quantity cannot have more than 3 decimal places.'
            USING ERRCODE = '22023';
    END IF;

    SELECT s.id
    INTO v_authorized_shop
    FROM public.shops AS s
    WHERE s.id = p_shop_id
      AND s.owner_id = auth.uid()
      AND s.is_active IS TRUE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'You do not have permission to receive stock for this shop.'
            USING ERRCODE = '42501';
    END IF;

    SELECT p.is_active
    INTO v_product_active
    FROM public.products AS p
    WHERE p.id = p_product_id
      AND p.shop_id = p_shop_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'The product does not belong to this shop.'
            USING ERRCODE = '22023';
    END IF;

    IF v_product_active IS NOT TRUE THEN
        RAISE EXCEPTION 'Stock cannot be received for an inactive product.'
            USING ERRCODE = '22023';
    END IF;

    INSERT INTO public.inventory AS inv (product_id, shop_id, quantity)
    VALUES (p_product_id, p_shop_id, 0)
    ON CONFLICT ON CONSTRAINT inventory_pkey DO NOTHING;

    UPDATE public.inventory AS inv
    SET quantity = inv.quantity + p_quantity,
        updated_at = NOW()
    WHERE inv.product_id = p_product_id
      AND inv.shop_id = p_shop_id
    RETURNING inv.quantity INTO v_new_quantity;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'The inventory record could not be updated.';
    END IF;

    INSERT INTO public.stock_movements (
        shop_id,
        product_id,
        movement_type,
        quantity_delta,
        reason,
        reference_id
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

REVOKE ALL ON FUNCTION public.receive_stock(
    UUID, UUID, NUMERIC, TEXT, UUID
) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.receive_stock(
    UUID, UUID, NUMERIC, TEXT, UUID
) TO authenticated;

COMMIT;

-- ============================================================================
-- 7. VERIFICATION QUERIES (run manually after installation)
-- These are read-only; they do not change stock.
-- ============================================================================

-- Products and their inventory balances:
-- SELECT p.id, p.name, p.is_active, p.unit, i.quantity, p.reorder_level
-- FROM public.products AS p
-- LEFT JOIN public.inventory AS i
--   ON i.product_id = p.id AND i.shop_id = p.shop_id
-- ORDER BY p.name;

-- Recent stock movement ledger:
-- SELECT sm.created_at, p.name, sm.movement_type,
--        sm.quantity_delta, sm.reason, sm.reference_id
-- FROM public.stock_movements AS sm
-- JOIN public.products AS p
--   ON p.id = sm.product_id AND p.shop_id = sm.shop_id
-- ORDER BY sm.created_at DESC
-- LIMIT 50;

-- Confirm RLS is enabled on all application tables:
-- SELECT tablename, rowsecurity
-- FROM pg_tables
-- WHERE schemaname = 'public'
-- ORDER BY tablename;

-- ============================================================================
-- KNOWN V1 NOTES / MISTAKES PREVENTED
--   * Do not query `shop`; the table is `public.shops`.
--   * Use is_active, cost_price_minor, selling_price_minor.
--   * Stock ledger columns are quantity_delta and reason, not quantity.
--   * sales uses subtotal_minor/total_minor/amount_paid_minor/change_minor;
--     sale_items uses product_name/unit_price_minor/unit_cost_minor/
--     line_total_minor. There is no sale_date, payment, or tax column here.
--   * sale_number is generated by PostgreSQL; clients must not provide it.
--   * The composite sale_items FK requires UNIQUE (shop_id, id) on sales.
--   * Product/category membership belongs in product_categories, not products.
--   * Duplicate names are still allowed by design; the app should warn about
--     possible active duplicates. A nullable SKU does not prevent duplicates.
--   * Checkout still needs a single, tested complete_sale transaction that
--     validates prices/payment, inserts sale and items, deducts stock, and
--     inserts negative sale movements atomically. Keep direct writes blocked
--     until that function is implemented and aligned with the Flutter code.
-- ============================================================================
