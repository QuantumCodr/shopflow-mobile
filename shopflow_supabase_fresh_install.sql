-- ShopFlow Supabase SQL bundle
-- Intended for a FRESH / EMPTY Supabase project only.
-- For real deployments, prefer applying the files in supabase/migrations/ via version control.

-- =====================================================================
-- BEGIN FILE: 20261023000100_core_schema.sql
-- =====================================================================
-- ShopFlow V1 core schema
-- PostgreSQL / Supabase
-- Fresh-install baseline. Apply this migration once to an empty project.
-- Money is stored in integer minor units: 100 minor units = SLE 1.00.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. Profiles: one application profile per authenticated user.
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Shops: V1 supports one shop per owner.
CREATE TABLE public.shops (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL UNIQUE
        REFERENCES public.profiles(id) ON DELETE RESTRICT,
    name TEXT NOT NULL CHECK (length(trim(name)) BETWEEN 1 AND 120),
    currency_code TEXT NOT NULL DEFAULT 'SLE'
        CHECK (currency_code ~ '^[A-Z]{3}$'),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. Categories.
CREATE TABLE public.categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id UUID NOT NULL
        REFERENCES public.shops(id) ON DELETE RESTRICT,
    name TEXT NOT NULL CHECK (length(trim(name)) BETWEEN 1 AND 80),
    description TEXT,
    image_path TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (shop_id, id),
    UNIQUE (shop_id, name)
);

-- 4. Products.
-- category_id is intentionally omitted. Product/category membership is
-- represented by the product_categories junction table below.
CREATE TABLE public.products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id UUID NOT NULL
        REFERENCES public.shops(id) ON DELETE RESTRICT,
    name TEXT NOT NULL CHECK (length(trim(name)) BETWEEN 1 AND 160),
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
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (shop_id, id),
    UNIQUE (shop_id, sku)
);

-- 5. Many-to-many product/category relationship.
CREATE TABLE public.product_categories (
    shop_id UUID NOT NULL,
    product_id UUID NOT NULL,
    category_id UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT product_categories_pkey
        PRIMARY KEY (shop_id, product_id, category_id),
    CONSTRAINT product_categories_shop_fkey
        FOREIGN KEY (shop_id)
        REFERENCES public.shops(id) ON DELETE CASCADE,
    CONSTRAINT product_categories_product_fkey
        FOREIGN KEY (shop_id, product_id)
        REFERENCES public.products(shop_id, id) ON DELETE CASCADE,
    CONSTRAINT product_categories_category_fkey
        FOREIGN KEY (shop_id, category_id)
        REFERENCES public.categories(shop_id, id) ON DELETE CASCADE
);

-- 6. Inventory: one balance per product. Quantities support 3 decimals.
CREATE TABLE public.inventory (
    product_id UUID PRIMARY KEY
        REFERENCES public.products(id) ON DELETE RESTRICT,
    shop_id UUID NOT NULL
        REFERENCES public.shops(id) ON DELETE RESTRICT,
    quantity NUMERIC(14,3) NOT NULL DEFAULT 0
        CHECK (quantity >= 0),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (shop_id, product_id),
    CONSTRAINT inventory_product_same_shop_fk
        FOREIGN KEY (shop_id, product_id)
        REFERENCES public.products(shop_id, id) ON DELETE RESTRICT
);

-- 7. Stock movement ledger. quantity_delta is signed:
-- receipts/adjustment-in/returns are positive; sale/damage/adjustment-out
-- should be negative in the completed transaction functions.
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
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT stock_movements_product_same_shop_fk
        FOREIGN KEY (shop_id, product_id)
        REFERENCES public.products(shop_id, id) ON DELETE RESTRICT
);

-- 8. Sales. All monetary values use integer minor units.
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
    change_minor BIGINT NOT NULL DEFAULT 0
        CHECK (change_minor >= 0),
    payment_method TEXT NOT NULL DEFAULT 'cash'
        CHECK (payment_method IN ('cash', 'mobile_money', 'card', 'other')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (shop_id, id),
    UNIQUE (shop_id, sale_number)
);

-- 9. Sale items retain product name and price/cost snapshots from sale time.
CREATE TABLE public.sale_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id UUID NOT NULL
        REFERENCES public.shops(id) ON DELETE RESTRICT,
    sale_id UUID NOT NULL,
    product_id UUID NOT NULL,
    product_name TEXT NOT NULL,
    quantity NUMERIC(14,3) NOT NULL CHECK (quantity > 0),
    unit_price_minor BIGINT NOT NULL CHECK (unit_price_minor >= 0),
    unit_cost_minor BIGINT NOT NULL DEFAULT 0
        CHECK (unit_cost_minor >= 0),
    line_total_minor BIGINT NOT NULL CHECK (line_total_minor >= 0),
    CONSTRAINT sale_items_sale_same_shop_fk
        FOREIGN KEY (shop_id, sale_id)
        REFERENCES public.sales(shop_id, id) ON DELETE RESTRICT,
    CONSTRAINT sale_items_product_same_shop_fk
        FOREIGN KEY (shop_id, product_id)
        REFERENCES public.products(shop_id, id) ON DELETE RESTRICT
);

-- 10. Indexes for common shop queries.
CREATE INDEX categories_shop_active_idx
    ON public.categories(shop_id, is_active);
CREATE INDEX products_shop_active_name_idx
    ON public.products(shop_id, is_active, name);
CREATE INDEX product_categories_category_idx
    ON public.product_categories(shop_id, category_id, product_id);
CREATE INDEX product_categories_product_idx
    ON public.product_categories(shop_id, product_id, category_id);
CREATE INDEX inventory_shop_idx
    ON public.inventory(shop_id);
CREATE INDEX stock_movements_shop_created_idx
    ON public.stock_movements(shop_id, created_at DESC);
CREATE INDEX stock_movements_product_created_idx
    ON public.stock_movements(product_id, created_at DESC);
CREATE INDEX sales_shop_created_idx
    ON public.sales(shop_id, created_at DESC);
CREATE INDEX sale_items_sale_idx
    ON public.sale_items(sale_id);
CREATE INDEX sale_items_product_idx
    ON public.sale_items(shop_id, product_id);

-- 11. Enable Row Level Security. Policies are defined in the next migration.
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shops ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sale_items ENABLE ROW LEVEL SECURITY;


-- =====================================================================
-- BEGIN FILE: 20261023000200_security_policies.sql
-- =====================================================================
-- ShopFlow V1 row-level security and least-privilege grants.
-- Inventory balances and the stock movement ledger are read-only to clients.
-- Mutations must go through trusted database functions/transactions.

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

-- Helper for rerunning this migration in a development database.
DROP POLICY IF EXISTS profiles_select_own ON public.profiles;
DROP POLICY IF EXISTS profiles_insert_own ON public.profiles;
DROP POLICY IF EXISTS profiles_update_own ON public.profiles;
DROP POLICY IF EXISTS shops_select_own ON public.shops;
DROP POLICY IF EXISTS shops_insert_own ON public.shops;
DROP POLICY IF EXISTS shops_update_own ON public.shops;
DROP POLICY IF EXISTS categories_select_own_shop ON public.categories;
DROP POLICY IF EXISTS categories_insert_own_shop ON public.categories;
DROP POLICY IF EXISTS categories_update_own_shop ON public.categories;
DROP POLICY IF EXISTS products_select_own_shop ON public.products;
DROP POLICY IF EXISTS products_insert_own_shop ON public.products;
DROP POLICY IF EXISTS products_update_own_shop ON public.products;
DROP POLICY IF EXISTS product_categories_select_own_shop ON public.product_categories;
DROP POLICY IF EXISTS product_categories_insert_own_shop ON public.product_categories;
DROP POLICY IF EXISTS product_categories_delete_own_shop ON public.product_categories;
DROP POLICY IF EXISTS inventory_select_own_shop ON public.inventory;
DROP POLICY IF EXISTS inventory_insert_own_shop ON public.inventory;
DROP POLICY IF EXISTS inventory_update_own_shop ON public.inventory;
DROP POLICY IF EXISTS inventory_select_shop_owner ON public.inventory;
DROP POLICY IF EXISTS stock_movements_select_own_shop ON public.stock_movements;
DROP POLICY IF EXISTS stock_movements_insert_own_shop ON public.stock_movements;
DROP POLICY IF EXISTS stock_movements_select_shop_owner ON public.stock_movements;
DROP POLICY IF EXISTS sales_select_own_shop ON public.sales;
DROP POLICY IF EXISTS sales_insert_own_shop ON public.sales;
DROP POLICY IF EXISTS sales_update_own_shop ON public.sales;
DROP POLICY IF EXISTS sale_items_select_own_shop ON public.sale_items;
DROP POLICY IF EXISTS sale_items_insert_own_shop ON public.sale_items;

-- Profiles: each user sees/edits their own profile.
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

-- Shops: owners may access their own shop.
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

-- Categories.
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

-- Products.
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

-- Product/category assignments: use insert/delete rather than changing key columns.
CREATE POLICY product_categories_select_own_shop ON public.product_categories
FOR SELECT TO authenticated
USING ((SELECT public.owns_shop(shop_id)));

CREATE POLICY product_categories_insert_own_shop ON public.product_categories
FOR INSERT TO authenticated
WITH CHECK ((SELECT public.owns_shop(shop_id)));

CREATE POLICY product_categories_delete_own_shop ON public.product_categories
FOR DELETE TO authenticated
USING ((SELECT public.owns_shop(shop_id)));

-- Inventory balances are readable by the owner. Clients cannot directly
-- insert/update/delete quantities; trusted database functions do that.
CREATE POLICY inventory_select_own_shop ON public.inventory
FOR SELECT TO authenticated
USING ((SELECT public.owns_shop(shop_id)));

-- Stock movements are an audit ledger. Clients may read but should not
-- directly create, modify, or delete ledger entries.
CREATE POLICY stock_movements_select_own_shop ON public.stock_movements
FOR SELECT TO authenticated
USING ((SELECT public.owns_shop(shop_id)));

-- Sales are readable by the shop owner. A transactional RPC should create
-- sales and sale_items atomically; direct client inserts are not granted here.
CREATE POLICY sales_select_own_shop ON public.sales
FOR SELECT TO authenticated
USING ((SELECT public.owns_shop(shop_id)));

CREATE POLICY sale_items_select_own_shop ON public.sale_items
FOR SELECT TO authenticated
USING ((SELECT public.owns_shop(shop_id)));

-- Explicit table grants. RLS remains responsible for row-level ownership.
REVOKE ALL ON TABLE
    public.profiles,
    public.shops,
    public.categories,
    public.products,
    public.product_categories,
    public.inventory,
    public.stock_movements,
    public.sales,
    public.sale_items
FROM PUBLIC, anon, authenticated;

GRANT SELECT, INSERT, UPDATE
ON public.profiles, public.shops, public.categories, public.products
TO authenticated;

GRANT SELECT, INSERT, DELETE
ON public.product_categories
TO authenticated;

GRANT SELECT
ON public.inventory, public.stock_movements, public.sales, public.sale_items
TO authenticated;


-- =====================================================================
-- BEGIN FILE: 20261023000300_triggers.sql
-- =====================================================================
-- ShopFlow V1 triggers.
-- 1. Create a profile when an auth user registers.
-- 2. Create a zero-quantity inventory row when a product is inserted.

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
        NULLIF(trim(NEW.raw_user_meta_data ->> 'full_name'), '')
    );

    RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.handle_new_user();

CREATE OR REPLACE FUNCTION public.initialize_product_inventory()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
    INSERT INTO public.inventory (product_id, shop_id, quantity)
    VALUES (NEW.id, NEW.shop_id, 0)
    ON CONFLICT ON CONSTRAINT inventory_pkey DO NOTHING;

    RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_products_initialize_inventory ON public.products;
CREATE TRIGGER trg_products_initialize_inventory
AFTER INSERT ON public.products
FOR EACH ROW
EXECUTE FUNCTION public.initialize_product_inventory();

-- Backfill existing products without inventory rows; preserve any quantity.
INSERT INTO public.inventory (product_id, shop_id, quantity)
SELECT p.id, p.shop_id, 0
FROM public.products AS p
WHERE NOT EXISTS (
    SELECT 1
    FROM public.inventory AS i
    WHERE i.product_id = p.id
      AND i.shop_id = p.shop_id
)
ON CONFLICT ON CONSTRAINT inventory_pkey DO NOTHING;


-- =====================================================================
-- BEGIN FILE: 20261023000400_receive_stock.sql
-- =====================================================================
-- Atomically receive stock and create the corresponding stock movement.
-- Result columns are deliberately prefixed to avoid PL/pgSQL ambiguity.

DROP FUNCTION IF EXISTS public.receive_stock(UUID, UUID, NUMERIC, TEXT, UUID);

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
SET search_path = ''
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

    -- Serialize receipts for a single product by locking its product row.
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
        RAISE EXCEPTION
            'Stock cannot be received for an inactive product.'
            USING ERRCODE = '22023';
    END IF;

    INSERT INTO public.inventory AS inv (product_id, shop_id, quantity)
    VALUES (p_product_id, p_shop_id, 0)
    ON CONFLICT ON CONSTRAINT inventory_pkey DO NOTHING;

    UPDATE public.inventory AS inv
    SET quantity = inv.quantity + p_quantity,
        updated_at = now()
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

REVOKE ALL ON FUNCTION public.receive_stock(UUID, UUID, NUMERIC, TEXT, UUID)
FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.receive_stock(UUID, UUID, NUMERIC, TEXT, UUID)
TO authenticated;

