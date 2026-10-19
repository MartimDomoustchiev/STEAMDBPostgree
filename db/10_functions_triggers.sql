-- =============================================================================
-- 10  Business logic: triggers and stored functions
-- =============================================================================
--  Every function in the schema gets "SET search_path = steam, public" at the end of
--  this file, so triggers keep working whatever search_path the client connects with.
--
--  Locking rule used by the functions below: lock the "money" row (wallet / listing /
--  trade) first, then the items it touches, always in primary-key order.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- generic helpers
-- ---------------------------------------------------------------------------
CREATE FUNCTION set_updated_at() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END $$;

CREATE FUNCTION forbid_change() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION '% on % is not allowed (append-only table)', TG_OP, TG_TABLE_NAME;
END $$;

-- Is the user currently under one of the given ban types?
CREATE FUNCTION has_active_ban(p_user_id BIGINT, p_types ban_type[]) RETURNS boolean LANGUAGE sql STABLE AS $$
    SELECT EXISTS (
        SELECT 1 FROM user_bans
         WHERE user_id = p_user_id
           AND ban_type = ANY (p_types)
           AND (expires_at IS NULL OR expires_at > now()));
$$;

CREATE FUNCTION notify_user(p_user_id BIGINT, p_type notification_type, p_payload JSONB) RETURNS void LANGUAGE sql AS $$
    INSERT INTO notifications (user_id, type, payload) VALUES (p_user_id, p_type, p_payload);
$$;

-- updated_at only moves on real content edits, not when trigger-maintained counters change
CREATE TRIGGER trg_users_updated          BEFORE UPDATE ON users            FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_user_profiles_updated  BEFORE UPDATE ON user_profiles    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_groups_updated         BEFORE UPDATE ON groups           FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_posts_updated          BEFORE UPDATE ON discussion_posts FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_workshop_items_updated BEFORE UPDATE ON workshop_items   FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_apps_updated
    BEFORE UPDATE OF parent_app_id, app_type, name, slug, short_description, about, status, release_date,
                     is_free, age_rating, metacritic_score, website_url ON apps
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_reviews_updated
    BEFORE UPDATE OF is_recommended, body ON reviews
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------------
-- new user  ->  wallet (currency of their country) + empty profile
-- ---------------------------------------------------------------------------
CREATE FUNCTION init_new_user() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO user_wallets (user_id, currency_code)
    SELECT NEW.user_id, c.default_currency FROM countries c WHERE c.country_code = NEW.country_code;

    INSERT INTO user_profiles (user_id, display_name) VALUES (NEW.user_id, NEW.username);
    RETURN NEW;
END $$;

CREATE TRIGGER trg_users_init AFTER INSERT ON users FOR EACH ROW EXECUTE FUNCTION init_new_user();

-- ---------------------------------------------------------------------------
-- friends
-- ---------------------------------------------------------------------------
CREATE FUNCTION friend_request_before() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'UPDATE' AND NEW.status <> OLD.status AND OLD.status <> 'pending' THEN
        RAISE EXCEPTION 'friend request % is already %', OLD.request_id, OLD.status;
    END IF;

    IF NEW.status IN ('pending', 'accepted') AND (TG_OP = 'INSERT' OR NEW.status <> OLD.status) THEN
        IF EXISTS (SELECT 1 FROM user_blocks
                    WHERE (blocker_id = NEW.sender_id   AND blocked_id = NEW.receiver_id)
                       OR (blocker_id = NEW.receiver_id AND blocked_id = NEW.sender_id)) THEN
            RAISE EXCEPTION 'users % and % cannot become friends: one has blocked the other', NEW.sender_id, NEW.receiver_id;
        END IF;
        IF TG_OP = 'INSERT' AND EXISTS (
            SELECT 1 FROM friendships
             WHERE user_id_low = LEAST(NEW.sender_id, NEW.receiver_id)
               AND user_id_high = GREATEST(NEW.sender_id, NEW.receiver_id)) THEN
            RAISE EXCEPTION 'users % and % are already friends', NEW.sender_id, NEW.receiver_id;
        END IF;
    END IF;

    IF NEW.status <> 'pending' AND NEW.responded_at IS NULL THEN
        NEW.responded_at := now();
    END IF;
    RETURN NEW;
END $$;

CREATE FUNCTION friend_request_after() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.status = 'accepted' AND (TG_OP = 'INSERT' OR OLD.status <> 'accepted') THEN
        INSERT INTO friendships (user_id_low, user_id_high, since)
        VALUES (LEAST(NEW.sender_id, NEW.receiver_id), GREATEST(NEW.sender_id, NEW.receiver_id), COALESCE(NEW.responded_at, now()))
        ON CONFLICT DO NOTHING;
    ELSIF TG_OP = 'INSERT' AND NEW.status = 'pending' THEN
        PERFORM notify_user(NEW.receiver_id, 'friend_request',
                            jsonb_build_object('request_id', NEW.request_id, 'from_user_id', NEW.sender_id));
    END IF;
    RETURN NULL;
END $$;

CREATE TRIGGER trg_friend_request_before BEFORE INSERT OR UPDATE OF status ON friend_requests
    FOR EACH ROW EXECUTE FUNCTION friend_request_before();
CREATE TRIGGER trg_friend_request_after  AFTER  INSERT OR UPDATE OF status ON friend_requests
    FOR EACH ROW EXECUTE FUNCTION friend_request_after();

-- blocking someone ends the friendship and any pending request
CREATE FUNCTION user_block_after_insert() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM friendships
     WHERE user_id_low = LEAST(NEW.blocker_id, NEW.blocked_id) AND user_id_high = GREATEST(NEW.blocker_id, NEW.blocked_id);
    UPDATE friend_requests SET status = 'cancelled'
     WHERE status = 'pending'
       AND LEAST(sender_id, receiver_id) = LEAST(NEW.blocker_id, NEW.blocked_id)
       AND GREATEST(sender_id, receiver_id) = GREATEST(NEW.blocker_id, NEW.blocked_id);
    RETURN NULL;
END $$;

CREATE TRIGGER trg_user_block_after_insert AFTER INSERT ON user_blocks
    FOR EACH ROW EXECUTE FUNCTION user_block_after_insert();

-- ---------------------------------------------------------------------------
-- groups: the owner is always a member with role 'owner'
-- ---------------------------------------------------------------------------
CREATE FUNCTION group_owner_membership() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'UPDATE' THEN
        UPDATE group_members SET role = 'officer'
         WHERE group_id = NEW.group_id AND user_id = OLD.owner_id AND role = 'owner';
    END IF;
    INSERT INTO group_members (group_id, user_id, role) VALUES (NEW.group_id, NEW.owner_id, 'owner')
    ON CONFLICT (group_id, user_id) DO UPDATE SET role = 'owner';
    RETURN NULL;
END $$;

CREATE TRIGGER trg_group_owner AFTER INSERT OR UPDATE OF owner_id ON groups
    FOR EACH ROW EXECUTE FUNCTION group_owner_membership();

-- ---------------------------------------------------------------------------
-- wallet: every transaction updates the balance and records balance_after.
-- The CHECK (balance_minor >= 0) on user_wallets rejects overdrafts; the UPDATE
-- takes a row lock, so concurrent spends on one wallet are serialised.
-- ---------------------------------------------------------------------------
CREATE FUNCTION apply_wallet_transaction() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    UPDATE user_wallets
       SET balance_minor = balance_minor + NEW.amount_minor,
           updated_at    = now()
     WHERE user_id = NEW.user_id AND currency_code = NEW.currency_code
    RETURNING balance_minor INTO NEW.balance_after_minor;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'user % has no % wallet', NEW.user_id, NEW.currency_code;
    END IF;
    RETURN NEW;
END $$;

CREATE TRIGGER trg_wallet_txn_apply BEFORE INSERT ON wallet_transactions
    FOR EACH ROW EXECUTE FUNCTION apply_wallet_transaction();
CREATE TRIGGER trg_wallet_txn_immutable BEFORE UPDATE OR DELETE ON wallet_transactions
    FOR EACH ROW EXECUTE FUNCTION forbid_change();

-- ---------------------------------------------------------------------------
-- orders
--   pending -> completed | failed | cancelled
--   completed | partially_refunded -> partially_refunded | refunded
-- An order can only complete when its totals match its items; once it has left
-- 'pending' its items are frozen (except refunded_at) and it cannot be deleted.
-- ---------------------------------------------------------------------------
CREATE FUNCTION order_before_status_change() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    v_items     INT;
    v_subtotal  BIGINT;
    v_discount  BIGINT;
BEGIN
    IF NEW.status = OLD.status THEN
        RETURN NEW;
    END IF;

    IF NOT (   (OLD.status = 'pending' AND NEW.status IN ('completed', 'failed', 'cancelled'))
            OR (OLD.status IN ('completed', 'partially_refunded') AND NEW.status IN ('partially_refunded', 'refunded'))) THEN
        RAISE EXCEPTION 'order %: status cannot change from % to %', OLD.order_id, OLD.status, NEW.status;
    END IF;

    IF NEW.status = 'completed' THEN
        SELECT count(*), COALESCE(sum(list_price_minor), 0), COALESCE(sum(list_price_minor - final_price_minor), 0)
          INTO v_items, v_subtotal, v_discount
          FROM order_items WHERE order_id = NEW.order_id;

        IF v_items = 0 THEN
            RAISE EXCEPTION 'order % has no items', NEW.order_id;
        END IF;
        IF v_subtotal <> NEW.subtotal_minor OR v_discount <> NEW.discount_minor THEN
            RAISE EXCEPTION 'order % totals (% / %) do not match its items (% / %)',
                            NEW.order_id, NEW.subtotal_minor, NEW.discount_minor, v_subtotal, v_discount;
        END IF;
        NEW.completed_at := COALESCE(NEW.completed_at, now());
    END IF;
    RETURN NEW;
END $$;

CREATE FUNCTION order_after_status_change() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.status = 'completed' AND OLD.status <> 'completed' THEN
        INSERT INTO library_entries (user_id, app_id, source, order_item_id, acquired_at)
        SELECT COALESCE(NEW.gift_recipient_id, NEW.user_id),
               oi.app_id,
               CASE WHEN NEW.gift_recipient_id IS NULL THEN 'purchase'::ownership_source ELSE 'gift'::ownership_source END,
               oi.order_item_id,
               NEW.completed_at
          FROM order_items oi
         WHERE oi.order_id = NEW.order_id
        ON CONFLICT (user_id, app_id) DO NOTHING;

        IF NEW.gift_recipient_id IS NOT NULL THEN
            PERFORM notify_user(NEW.gift_recipient_id, 'gift_received',
                jsonb_build_object('order_id', NEW.order_id, 'from_user_id', NEW.user_id,
                                   'app_ids', (SELECT jsonb_agg(app_id ORDER BY app_id) FROM order_items WHERE order_id = NEW.order_id)));
        END IF;
    END IF;
    RETURN NULL;
END $$;

CREATE FUNCTION order_before_delete() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF OLD.status NOT IN ('pending', 'failed', 'cancelled') THEN
        RAISE EXCEPTION 'order % is % and cannot be deleted (financial record)', OLD.order_id, OLD.status;
    END IF;
    RETURN OLD;
END $$;

CREATE FUNCTION order_items_guard() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    v_order_id  BIGINT := CASE WHEN TG_OP = 'INSERT' THEN NEW.order_id ELSE OLD.order_id END;
    v_status    order_status;
BEGIN
    SELECT status INTO v_status FROM orders WHERE order_id = v_order_id;

    IF v_status IS NULL OR v_status = 'pending'                     -- NULL: the parent order is being deleted
       OR (TG_OP = 'UPDATE'
           AND (NEW.order_id, NEW.app_id, NEW.bundle_id, NEW.list_price_minor, NEW.discount_pct, NEW.final_price_minor)
               IS NOT DISTINCT FROM
               (OLD.order_id, OLD.app_id, OLD.bundle_id, OLD.list_price_minor, OLD.discount_pct, OLD.final_price_minor)) THEN
        RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
    END IF;

    RAISE EXCEPTION 'order % is %; its items can no longer be changed', v_order_id, v_status;
END $$;

CREATE TRIGGER trg_orders_before_status BEFORE UPDATE OF status ON orders
    FOR EACH ROW EXECUTE FUNCTION order_before_status_change();
CREATE TRIGGER trg_orders_after_status  AFTER  UPDATE OF status ON orders
    FOR EACH ROW EXECUTE FUNCTION order_after_status_change();
CREATE TRIGGER trg_orders_before_delete BEFORE DELETE ON orders
    FOR EACH ROW EXECUTE FUNCTION order_before_delete();
CREATE TRIGGER trg_order_items_guard    BEFORE INSERT OR UPDATE OR DELETE ON order_items
    FOR EACH ROW EXECUTE FUNCTION order_items_guard();

-- once owned, a game leaves the wishlist and the cart
CREATE FUNCTION library_cleanup_wishlist() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM wishlists  WHERE user_id = NEW.user_id AND app_id = NEW.app_id;
    DELETE FROM cart_items WHERE user_id = NEW.user_id AND app_id = NEW.app_id;
    RETURN NULL;
END $$;

CREATE TRIGGER trg_library_cleanup AFTER INSERT ON library_entries
    FOR EACH ROW EXECUTE FUNCTION library_cleanup_wishlist();

-- ---------------------------------------------------------------------------
-- playtime: session duration + running total on the library entry.
-- Sessions are append-only so the running total can never drift.
-- ---------------------------------------------------------------------------
CREATE FUNCTION playtime_before_insert() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    NEW.duration_minutes := GREATEST(0, floor(extract(epoch FROM (NEW.ended_at - NEW.started_at)) / 60))::int;
    RETURN NEW;
END $$;

CREATE FUNCTION playtime_after_insert() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    UPDATE library_entries
       SET total_playtime_minutes = total_playtime_minutes + NEW.duration_minutes,
           last_played_at         = GREATEST(COALESCE(last_played_at, NEW.ended_at), NEW.ended_at)
     WHERE user_id = NEW.user_id AND app_id = NEW.app_id;
    RETURN NULL;
END $$;

CREATE TRIGGER trg_playtime_before    BEFORE INSERT ON playtime_sessions
    FOR EACH ROW EXECUTE FUNCTION playtime_before_insert();
CREATE TRIGGER trg_playtime_after     AFTER  INSERT ON playtime_sessions
    FOR EACH ROW EXECUTE FUNCTION playtime_after_insert();
CREATE TRIGGER trg_playtime_immutable BEFORE UPDATE ON playtime_sessions
    FOR EACH ROW EXECUTE FUNCTION forbid_change();

-- achievements may only be unlocked by owners of the game
CREATE FUNCTION user_achievement_check() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM achievements a
          JOIN library_entries le ON le.app_id = a.app_id AND le.user_id = NEW.user_id
         WHERE a.achievement_id = NEW.achievement_id
    ) THEN
        RAISE EXCEPTION 'user % does not own the game for achievement %', NEW.user_id, NEW.achievement_id;
    END IF;
    RETURN NEW;
END $$;

CREATE TRIGGER trg_user_achievement_check BEFORE INSERT ON user_achievements
    FOR EACH ROW EXECUTE FUNCTION user_achievement_check();

-- ---------------------------------------------------------------------------
-- reviews: owners only, playtime snapshot, cached counters on apps / reviews.
-- Counters are maintained incrementally (+1 / -1) instead of being recounted.
-- ---------------------------------------------------------------------------
CREATE FUNCTION review_before_insert() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    v_playtime INT;
BEGIN
    SELECT total_playtime_minutes INTO v_playtime
      FROM library_entries WHERE user_id = NEW.user_id AND app_id = NEW.app_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'user % must own app % to review it', NEW.user_id, NEW.app_id;
    END IF;
    NEW.playtime_at_review_minutes := v_playtime;
    NEW.votes_helpful := 0;
    NEW.votes_funny   := 0;
    RETURN NEW;
END $$;

CREATE FUNCTION review_before_update() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.user_id <> OLD.user_id OR NEW.app_id <> OLD.app_id THEN
        RAISE EXCEPTION 'a review cannot be moved to another user or app';
    END IF;
    RETURN NEW;
END $$;

CREATE FUNCTION review_after_change() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP IN ('UPDATE', 'DELETE') AND OLD.is_visible THEN
        UPDATE apps
           SET positive_reviews = positive_reviews - CASE WHEN OLD.is_recommended THEN 1 ELSE 0 END,
               negative_reviews = negative_reviews - CASE WHEN OLD.is_recommended THEN 0 ELSE 1 END
         WHERE app_id = OLD.app_id;
    END IF;
    IF TG_OP IN ('INSERT', 'UPDATE') AND NEW.is_visible THEN
        UPDATE apps
           SET positive_reviews = positive_reviews + CASE WHEN NEW.is_recommended THEN 1 ELSE 0 END,
               negative_reviews = negative_reviews + CASE WHEN NEW.is_recommended THEN 0 ELSE 1 END
         WHERE app_id = NEW.app_id;
    END IF;
    RETURN NULL;
END $$;

-- repair utility: recount from scratch (e.g. after a bulk import with triggers disabled)
CREATE FUNCTION refresh_app_review_counts(p_app_id BIGINT) RETURNS void LANGUAGE sql AS $$
    UPDATE apps a
       SET positive_reviews = (SELECT count(*) FROM reviews r WHERE r.app_id = a.app_id AND r.is_visible AND r.is_recommended),
           negative_reviews = (SELECT count(*) FROM reviews r WHERE r.app_id = a.app_id AND r.is_visible AND NOT r.is_recommended)
     WHERE a.app_id = p_app_id;
$$;

CREATE TRIGGER trg_review_before_insert BEFORE INSERT ON reviews
    FOR EACH ROW EXECUTE FUNCTION review_before_insert();
CREATE TRIGGER trg_review_before_update BEFORE UPDATE OF user_id, app_id ON reviews
    FOR EACH ROW EXECUTE FUNCTION review_before_update();
CREATE TRIGGER trg_review_after_change  AFTER INSERT OR DELETE OR UPDATE OF is_recommended, is_visible ON reviews
    FOR EACH ROW EXECUTE FUNCTION review_after_change();

CREATE FUNCTION review_vote_before_insert() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM reviews WHERE review_id = NEW.review_id AND user_id = NEW.user_id) THEN
        RAISE EXCEPTION 'users cannot vote on their own review';
    END IF;
    RETURN NEW;
END $$;

CREATE FUNCTION review_vote_after_change() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP IN ('UPDATE', 'DELETE') THEN
        UPDATE reviews
           SET votes_helpful = votes_helpful - CASE WHEN OLD.vote = 'helpful' THEN 1 ELSE 0 END,
               votes_funny   = votes_funny   - CASE WHEN OLD.vote = 'funny'   THEN 1 ELSE 0 END
         WHERE review_id = OLD.review_id;
    END IF;
    IF TG_OP IN ('INSERT', 'UPDATE') THEN
        UPDATE reviews
           SET votes_helpful = votes_helpful + CASE WHEN NEW.vote = 'helpful' THEN 1 ELSE 0 END,
               votes_funny   = votes_funny   + CASE WHEN NEW.vote = 'funny'   THEN 1 ELSE 0 END
         WHERE review_id = NEW.review_id;
    END IF;
    RETURN NULL;
END $$;

CREATE TRIGGER trg_review_vote_before BEFORE INSERT OR UPDATE OF user_id, review_id ON review_votes
    FOR EACH ROW EXECUTE FUNCTION review_vote_before_insert();
CREATE TRIGGER trg_review_vote_after  AFTER INSERT OR UPDATE OR DELETE ON review_votes
    FOR EACH ROW EXECUTE FUNCTION review_vote_after_change();

-- ---------------------------------------------------------------------------
-- refunds: Steam rules - within 14 days of purchase and under 2 hours played.
--   pending -> approved | denied   (final)
-- Approved refunds are paid back into the Steam wallet.
-- ---------------------------------------------------------------------------
CREATE FUNCTION is_refund_eligible(p_order_item_id BIGINT) RETURNS boolean LANGUAGE sql STABLE AS $$
    SELECT COALESCE((
        SELECT o.status IN ('completed', 'partially_refunded')
               AND oi.refunded_at IS NULL
               AND o.completed_at >= now() - interval '14 days'
               AND COALESCE(le.total_playtime_minutes, 0) < 120
          FROM order_items oi
          JOIN orders o ON o.order_id = oi.order_id
          LEFT JOIN library_entries le
                 ON le.user_id = COALESCE(o.gift_recipient_id, o.user_id) AND le.app_id = oi.app_id
         WHERE oi.order_item_id = p_order_item_id), FALSE);
$$;

CREATE FUNCTION refund_before_insert() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    v_buyer     BIGINT;
    v_recipient BIGINT;
    v_price     BIGINT;
    v_app       BIGINT;
BEGIN
    IF NEW.status <> 'pending' THEN
        RAISE EXCEPTION 'a refund request must start as pending';
    END IF;

    -- lock the item so two concurrent requests cannot both pass the eligibility check
    SELECT o.user_id, o.gift_recipient_id, oi.final_price_minor, oi.app_id
      INTO v_buyer, v_recipient, v_price, v_app
      FROM order_items oi JOIN orders o ON o.order_id = oi.order_id
     WHERE oi.order_item_id = NEW.order_item_id
       FOR UPDATE OF oi;

    IF NOT is_refund_eligible(NEW.order_item_id) THEN
        RAISE EXCEPTION 'order item % is not eligible for a refund (14 days / 2 hours rule)', NEW.order_item_id;
    END IF;
    IF NEW.user_id <> v_buyer THEN
        RAISE EXCEPTION 'only the purchaser can request this refund';
    END IF;

    NEW.amount_minor := COALESCE(NEW.amount_minor, v_price);
    IF NEW.amount_minor > v_price THEN
        RAISE EXCEPTION 'refund amount % is higher than the price paid %', NEW.amount_minor, v_price;
    END IF;

    NEW.playtime_minutes_at_request := COALESCE(
        (SELECT total_playtime_minutes FROM library_entries
          WHERE user_id = COALESCE(v_recipient, v_buyer) AND app_id = v_app), 0);
    RETURN NEW;
END $$;

CREATE FUNCTION refund_before_update() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.status <> OLD.status THEN
        IF OLD.status <> 'pending' THEN
            RAISE EXCEPTION 'refund % is already %', OLD.refund_id, OLD.status;
        END IF;
        NEW.processed_at := COALESCE(NEW.processed_at, now());
    END IF;
    RETURN NEW;
END $$;

CREATE FUNCTION refund_after_update() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    v_order_id  BIGINT;
    v_currency  CHAR(3);
    v_total     INT;
    v_refunded  INT;
BEGIN
    IF NEW.status = OLD.status THEN
        RETURN NULL;
    END IF;

    IF NEW.status = 'approved' THEN
        UPDATE order_items SET refunded_at = now() WHERE order_item_id = NEW.order_item_id
        RETURNING order_id INTO v_order_id;

        -- take the game back out of the (recipient's) library
        DELETE FROM library_entries WHERE order_item_id = NEW.order_item_id;

        SELECT currency_code INTO v_currency FROM orders WHERE order_id = v_order_id;
        IF NEW.amount_minor > 0 THEN
            INSERT INTO wallet_transactions (user_id, txn_type, amount_minor, currency_code, order_id, note)
            VALUES (NEW.user_id, 'refund', NEW.amount_minor, v_currency, v_order_id, 'Refund #' || NEW.refund_id);
        END IF;

        SELECT count(*), count(refunded_at) INTO v_total, v_refunded FROM order_items WHERE order_id = v_order_id;
        UPDATE orders SET status = CASE WHEN v_total = v_refunded THEN 'refunded'::order_status
                                        ELSE 'partially_refunded'::order_status END
         WHERE order_id = v_order_id;
    END IF;

    PERFORM notify_user(NEW.user_id, 'refund_processed',
                        jsonb_build_object('refund_id', NEW.refund_id, 'status', NEW.status, 'amount_minor', NEW.amount_minor));
    RETURN NULL;
END $$;

CREATE TRIGGER trg_refund_before_insert BEFORE INSERT ON refunds
    FOR EACH ROW EXECUTE FUNCTION refund_before_insert();
CREATE TRIGGER trg_refund_before_update BEFORE UPDATE OF status ON refunds
    FOR EACH ROW EXECUTE FUNCTION refund_before_update();
CREATE TRIGGER trg_refund_after_update  AFTER  UPDATE OF status ON refunds
    FOR EACH ROW EXECUTE FUNCTION refund_after_update();

-- ---------------------------------------------------------------------------
-- market listings and trade offers: sanity checks + notifications
-- ---------------------------------------------------------------------------
CREATE FUNCTION market_listing_before_insert() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.status <> 'active' THEN
        RAISE EXCEPTION 'a new market listing must be active';
    END IF;
    IF has_active_ban(NEW.seller_id, ARRAY['market', 'trade', 'account']::ban_type[]) THEN
        RAISE EXCEPTION 'user % is banned from the community market', NEW.seller_id;
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM inventory_items i JOIN item_definitions d USING (item_def_id)
         WHERE i.inventory_item_id = NEW.inventory_item_id
           AND i.owner_id = NEW.seller_id
           AND d.is_marketable
    ) THEN
        RAISE EXCEPTION 'item % is not owned by seller % or is not marketable', NEW.inventory_item_id, NEW.seller_id;
    END IF;
    -- the seller is paid into their wallet, so the listing must be in the wallet currency
    IF NOT EXISTS (SELECT 1 FROM user_wallets WHERE user_id = NEW.seller_id AND currency_code = NEW.currency_code) THEN
        RAISE EXCEPTION 'listing currency % does not match the seller''s wallet currency', NEW.currency_code;
    END IF;
    RETURN NEW;
END $$;

CREATE TRIGGER trg_market_listing_check BEFORE INSERT ON market_listings
    FOR EACH ROW EXECUTE FUNCTION market_listing_before_insert();

CREATE FUNCTION trade_offer_before_insert() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF has_active_ban(NEW.sender_id, ARRAY['trade', 'account']::ban_type[])
       OR has_active_ban(NEW.receiver_id, ARRAY['trade', 'account']::ban_type[]) THEN
        RAISE EXCEPTION 'one of the users is banned from trading';
    END IF;
    IF EXISTS (SELECT 1 FROM user_blocks
                WHERE (blocker_id = NEW.sender_id   AND blocked_id = NEW.receiver_id)
                   OR (blocker_id = NEW.receiver_id AND blocked_id = NEW.sender_id)) THEN
        RAISE EXCEPTION 'users % and % have blocked each other', NEW.sender_id, NEW.receiver_id;
    END IF;
    RETURN NEW;
END $$;

CREATE FUNCTION trade_offer_after_insert() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    PERFORM notify_user(NEW.receiver_id, 'trade_offer',
                        jsonb_build_object('trade_id', NEW.trade_id, 'from_user_id', NEW.sender_id));
    RETURN NULL;
END $$;

-- items in an offer must belong to one of the two traders and be tradable
CREATE FUNCTION trade_offer_item_check() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM trade_offers t
          JOIN inventory_items i  ON i.inventory_item_id = NEW.inventory_item_id
          JOIN item_definitions d ON d.item_def_id = i.item_def_id
         WHERE t.trade_id = NEW.trade_id
           AND t.status = 'pending'
           AND i.owner_id IN (t.sender_id, t.receiver_id)
           AND d.is_tradable
    ) THEN
        RAISE EXCEPTION 'item % cannot be added to trade % (not pending, not owned by a trader, or not tradable)',
                        NEW.inventory_item_id, NEW.trade_id;
    END IF;
    RETURN NEW;
END $$;

CREATE TRIGGER trg_trade_offer_before BEFORE INSERT ON trade_offers
    FOR EACH ROW EXECUTE FUNCTION trade_offer_before_insert();
CREATE TRIGGER trg_trade_offer_after  AFTER  INSERT ON trade_offers
    FOR EACH ROW EXECUTE FUNCTION trade_offer_after_insert();
CREATE TRIGGER trg_trade_offer_item_check BEFORE INSERT OR UPDATE ON trade_offer_items
    FOR EACH ROW EXECUTE FUNCTION trade_offer_item_check();

-- =============================================================================
--  Stored functions (the "API" of the database)
-- =============================================================================

-- Turn the user's cart into a completed order, paying with wallet and/or a saved payment method.
-- Returns the new order_id. Everything happens in one transaction: any error rolls it all back.
CREATE FUNCTION checkout_cart(
    p_user_id            BIGINT,
    p_use_wallet         BOOLEAN DEFAULT TRUE,
    p_payment_method_id  BIGINT  DEFAULT NULL,
    p_gift_recipient_id  BIGINT  DEFAULT NULL
) RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE
    v_currency     CHAR(3);
    v_balance      BIGINT;
    v_owner        BIGINT := COALESCE(p_gift_recipient_id, p_user_id);
    v_status       account_status;
    v_app_name     TEXT;
    v_subtotal     BIGINT;
    v_final        BIGINT;
    v_wallet_used  BIGINT := 0;
    v_order_id     BIGINT;
BEGIN
    -- the wallet row lock serialises concurrent checkouts / spends of the same user
    SELECT currency_code, balance_minor INTO v_currency, v_balance
      FROM user_wallets WHERE user_id = p_user_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'user % has no wallet', p_user_id; END IF;

    SELECT status INTO v_status FROM users WHERE user_id = p_user_id;
    IF v_status NOT IN ('active', 'limited') THEN
        RAISE EXCEPTION 'account % is %; purchases are disabled', p_user_id, v_status;
    END IF;

    IF p_gift_recipient_id IS NOT NULL THEN
        SELECT status INTO v_status FROM users WHERE user_id = p_gift_recipient_id;
        IF NOT FOUND OR v_status IN ('banned', 'deleted') THEN
            RAISE EXCEPTION 'user % cannot receive gifts', p_gift_recipient_id;
        END IF;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM cart_items WHERE user_id = p_user_id) THEN
        RAISE EXCEPTION 'cart of user % is empty', p_user_id;
    END IF;

    IF p_payment_method_id IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM payment_methods WHERE payment_method_id = p_payment_method_id AND user_id = p_user_id) THEN
        RAISE EXCEPTION 'payment method % does not belong to user %', p_payment_method_id, p_user_id;
    END IF;

    SELECT a.name INTO v_app_name FROM cart_items c JOIN apps a ON a.app_id = c.app_id
     WHERE c.user_id = p_user_id AND a.status = 'delisted' LIMIT 1;
    IF FOUND THEN RAISE EXCEPTION '"%" is no longer sold', v_app_name; END IF;

    SELECT a.name INTO v_app_name FROM cart_items c JOIN apps a ON a.app_id = c.app_id
     WHERE c.user_id = p_user_id AND a.is_free LIMIT 1;
    IF FOUND THEN RAISE EXCEPTION '"%" is free to play; use claim_free_app() instead', v_app_name; END IF;

    SELECT a.name INTO v_app_name FROM cart_items c
      JOIN apps a ON a.app_id = c.app_id
      JOIN library_entries l ON l.app_id = c.app_id AND l.user_id = v_owner
     WHERE c.user_id = p_user_id LIMIT 1;
    IF FOUND THEN RAISE EXCEPTION 'user % already owns "%"', v_owner, v_app_name; END IF;

    SELECT a.name INTO v_app_name FROM cart_items c
      JOIN apps a ON a.app_id = c.app_id
      LEFT JOIN v_current_app_prices p ON p.app_id = c.app_id AND p.currency_code = v_currency
     WHERE c.user_id = p_user_id AND p.app_id IS NULL LIMIT 1;
    IF FOUND THEN RAISE EXCEPTION '"%" has no price in %', v_app_name, v_currency; END IF;

    SELECT sum(p.base_price_minor), sum(p.final_price_minor) INTO v_subtotal, v_final
      FROM cart_items c JOIN v_current_app_prices p ON p.app_id = c.app_id AND p.currency_code = v_currency
     WHERE c.user_id = p_user_id;

    IF p_use_wallet THEN v_wallet_used := LEAST(v_balance, v_final); END IF;
    IF v_final - v_wallet_used > 0 AND p_payment_method_id IS NULL THEN
        RAISE EXCEPTION 'wallet balance is not enough and no payment method was given (missing % minor units)',
                        v_final - v_wallet_used;
    END IF;

    INSERT INTO orders (user_id, gift_recipient_id, currency_code, subtotal_minor, discount_minor, total_minor,
                        wallet_used_minor, payment_method_id)
    VALUES (p_user_id, p_gift_recipient_id, v_currency, v_subtotal, v_subtotal - v_final, v_final,
            v_wallet_used, p_payment_method_id)
    RETURNING order_id INTO v_order_id;

    INSERT INTO order_items (order_id, app_id, list_price_minor, discount_pct, final_price_minor)
    SELECT v_order_id, c.app_id, p.base_price_minor, p.discount_pct, p.final_price_minor
      FROM cart_items c JOIN v_current_app_prices p ON p.app_id = c.app_id AND p.currency_code = v_currency
     WHERE c.user_id = p_user_id;

    IF v_wallet_used > 0 THEN
        INSERT INTO wallet_transactions (user_id, txn_type, amount_minor, currency_code, order_id, note)
        VALUES (p_user_id, 'purchase', -v_wallet_used, v_currency, v_order_id, 'Order #' || v_order_id);
    END IF;

    UPDATE orders SET status = 'completed' WHERE order_id = v_order_id;   -- validates totals, grants library
    DELETE FROM cart_items WHERE user_id = p_user_id;
    RETURN v_order_id;
END $$;

-- Add a free-to-play app to a library.
CREATE FUNCTION claim_free_app(p_user_id BIGINT, p_app_id BIGINT) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM apps WHERE app_id = p_app_id AND is_free AND status IN ('released', 'early_access')) THEN
        RAISE EXCEPTION 'app % is not a free, released app', p_app_id;
    END IF;
    INSERT INTO library_entries (user_id, app_id, source) VALUES (p_user_id, p_app_id, 'free_license')
    ON CONFLICT DO NOTHING;
END $$;

-- Activate a product key. Returns the app_id that was added.
CREATE FUNCTION redeem_game_key(p_user_id BIGINT, p_key_code TEXT) RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE
    v_key game_keys%ROWTYPE;
BEGIN
    SELECT * INTO v_key FROM game_keys WHERE key_code = p_key_code FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'unknown key'; END IF;
    IF v_key.status <> 'available' THEN RAISE EXCEPTION 'key is %', v_key.status; END IF;
    IF EXISTS (SELECT 1 FROM library_entries WHERE user_id = p_user_id AND app_id = v_key.app_id) THEN
        RAISE EXCEPTION 'user % already owns app %', p_user_id, v_key.app_id;
    END IF;

    UPDATE game_keys SET status = 'redeemed', redeemed_by = p_user_id, redeemed_at = now() WHERE key_id = v_key.key_id;
    INSERT INTO library_entries (user_id, app_id, source, key_id) VALUES (p_user_id, v_key.app_id, 'key_activation', v_key.key_id);
    RETURN v_key.app_id;
END $$;

-- Redeem a wallet gift code into the user's wallet. Returns the amount added.
CREATE FUNCTION redeem_wallet_code(p_user_id BIGINT, p_code TEXT) RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE
    v_code wallet_codes%ROWTYPE;
BEGIN
    SELECT * INTO v_code FROM wallet_codes WHERE code = p_code FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'unknown wallet code'; END IF;
    IF v_code.redeemed_at IS NOT NULL THEN RAISE EXCEPTION 'wallet code already redeemed'; END IF;
    IF NOT EXISTS (SELECT 1 FROM user_wallets WHERE user_id = p_user_id AND currency_code = v_code.currency_code) THEN
        RAISE EXCEPTION 'this code is in % but the wallet of user % is not', v_code.currency_code, p_user_id;
    END IF;

    UPDATE wallet_codes SET redeemed_by = p_user_id, redeemed_at = now() WHERE code = p_code;
    INSERT INTO wallet_transactions (user_id, txn_type, amount_minor, currency_code, note)
    VALUES (p_user_id, 'wallet_code', v_code.amount_minor, v_code.currency_code, 'Code ' || p_code);
    RETURN v_code.amount_minor;
END $$;

-- Close the current list price and open a new one (keeps the price history).
-- SECURITY DEFINER: steam_app may not edit app_prices directly, only through this function.
CREATE FUNCTION set_app_price(p_app_id BIGINT, p_currency CHAR(3), p_price_minor BIGINT) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    -- a price set earlier in this same transaction is simply overwritten
    UPDATE app_prices SET price_minor = p_price_minor
     WHERE app_id = p_app_id AND currency_code = p_currency AND valid_to IS NULL AND valid_from = now();
    IF FOUND THEN RETURN; END IF;

    UPDATE app_prices SET valid_to = now()
     WHERE app_id = p_app_id AND currency_code = p_currency AND valid_to IS NULL;
    INSERT INTO app_prices (app_id, currency_code, price_minor, valid_from)
    VALUES (p_app_id, p_currency, p_price_minor, now());
END $$;

-- The receiver accepts a trade: items owned by the sender go to the receiver and vice versa.
CREATE FUNCTION accept_trade_offer(p_trade_id BIGINT, p_user_id BIGINT) RETURNS void LANGUAGE plpgsql AS $$
DECLARE
    v_trade trade_offers%ROWTYPE;
BEGIN
    SELECT * INTO v_trade FROM trade_offers WHERE trade_id = p_trade_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'unknown trade %', p_trade_id; END IF;
    IF v_trade.receiver_id <> p_user_id THEN RAISE EXCEPTION 'only the receiver can accept trade %', p_trade_id; END IF;
    IF v_trade.status <> 'pending' THEN RAISE EXCEPTION 'trade % is already %', p_trade_id, v_trade.status; END IF;
    IF has_active_ban(v_trade.sender_id, ARRAY['trade', 'account']::ban_type[])
       OR has_active_ban(v_trade.receiver_id, ARRAY['trade', 'account']::ban_type[]) THEN
        RAISE EXCEPTION 'one of the users is banned from trading';
    END IF;

    -- lock the items (in id order) so a concurrent trade or market sale cannot move them underneath us
    PERFORM 1 FROM inventory_items
     WHERE inventory_item_id IN (SELECT inventory_item_id FROM trade_offer_items WHERE trade_id = p_trade_id)
     ORDER BY inventory_item_id
       FOR UPDATE;

    IF EXISTS (
        SELECT 1 FROM trade_offer_items toi
          JOIN inventory_items i  ON i.inventory_item_id = toi.inventory_item_id
          JOIN item_definitions d ON d.item_def_id = i.item_def_id
         WHERE toi.trade_id = p_trade_id
           AND (i.owner_id NOT IN (v_trade.sender_id, v_trade.receiver_id) OR NOT d.is_tradable)
    ) THEN
        RAISE EXCEPTION 'trade % contains an item that changed owner or is not tradable', p_trade_id;
    END IF;

    -- items on the market are pulled from sale, other offers with these items become void
    UPDATE market_listings SET status = 'cancelled'
     WHERE status = 'active'
       AND inventory_item_id IN (SELECT inventory_item_id FROM trade_offer_items WHERE trade_id = p_trade_id);

    UPDATE trade_offers SET status = 'cancelled', responded_at = now()
     WHERE status = 'pending' AND trade_id <> p_trade_id
       AND trade_id IN (SELECT t2.trade_id FROM trade_offer_items t2
                         WHERE t2.inventory_item_id IN (SELECT inventory_item_id FROM trade_offer_items WHERE trade_id = p_trade_id));

    UPDATE inventory_items i
       SET owner_id     = CASE WHEN i.owner_id = v_trade.sender_id THEN v_trade.receiver_id ELSE v_trade.sender_id END,
           acquired_via = 'trade',
           acquired_at  = now()
      FROM trade_offer_items toi
     WHERE toi.trade_id = p_trade_id AND toi.inventory_item_id = i.inventory_item_id;

    UPDATE trade_offers SET status = 'accepted', responded_at = now() WHERE trade_id = p_trade_id;

    PERFORM notify_user(v_trade.sender_id, 'trade_accepted',
                        jsonb_build_object('trade_id', p_trade_id, 'by_user_id', v_trade.receiver_id));
END $$;

-- Buy a community-market listing with wallet funds. The seller pays a 15% fee (minimum 1).
CREATE FUNCTION purchase_market_listing(p_listing_id BIGINT, p_buyer_id BIGINT) RETURNS void LANGUAGE plpgsql AS $$
DECLARE
    v_listing  market_listings%ROWTYPE;
    v_owner    BIGINT;
    v_fee      BIGINT;
BEGIN
    SELECT * INTO v_listing FROM market_listings WHERE listing_id = p_listing_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'unknown listing %', p_listing_id; END IF;
    IF v_listing.status <> 'active' THEN RAISE EXCEPTION 'listing % is %', p_listing_id, v_listing.status; END IF;
    IF v_listing.seller_id = p_buyer_id THEN RAISE EXCEPTION 'you cannot buy your own listing'; END IF;
    IF has_active_ban(p_buyer_id, ARRAY['market', 'trade', 'account']::ban_type[]) THEN
        RAISE EXCEPTION 'user % is banned from the community market', p_buyer_id;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM user_wallets WHERE user_id = p_buyer_id AND currency_code = v_listing.currency_code) THEN
        RAISE EXCEPTION 'listing % is priced in %, which is not the buyer''s wallet currency', p_listing_id, v_listing.currency_code;
    END IF;

    SELECT owner_id INTO v_owner FROM inventory_items WHERE inventory_item_id = v_listing.inventory_item_id FOR UPDATE;
    IF v_owner IS DISTINCT FROM v_listing.seller_id THEN
        RAISE EXCEPTION 'the item of listing % no longer belongs to the seller', p_listing_id;
    END IF;

    v_fee := GREATEST(1, round(v_listing.price_minor * 0.15));

    INSERT INTO wallet_transactions (user_id, txn_type, amount_minor, currency_code, note)
    VALUES (p_buyer_id, 'market_purchase', -v_listing.price_minor, v_listing.currency_code, 'Listing #' || p_listing_id);

    INSERT INTO wallet_transactions (user_id, txn_type, amount_minor, currency_code, note)
    VALUES (v_listing.seller_id, 'market_sale', v_listing.price_minor - v_fee, v_listing.currency_code, 'Listing #' || p_listing_id);

    UPDATE inventory_items
       SET owner_id = p_buyer_id, acquired_via = 'market', acquired_at = now()
     WHERE inventory_item_id = v_listing.inventory_item_id;

    UPDATE market_listings
       SET status = 'sold', buyer_id = p_buyer_id, fee_minor = v_fee, sold_at = now()
     WHERE listing_id = p_listing_id;

    UPDATE trade_offers SET status = 'cancelled', responded_at = now()
     WHERE status = 'pending'
       AND trade_id IN (SELECT trade_id FROM trade_offer_items WHERE inventory_item_id = v_listing.inventory_item_id);

    PERFORM notify_user(v_listing.seller_id, 'market_item_sold',
                        jsonb_build_object('listing_id', p_listing_id, 'price_minor', v_listing.price_minor,
                                           'fee_minor', v_fee, 'currency', v_listing.currency_code));
END $$;

-- ---------------------------------------------------------------------------
-- pin search_path on every function of the schema (see header)
-- ---------------------------------------------------------------------------
DO $$
DECLARE
    f record;
BEGIN
    FOR f IN SELECT p.oid::regprocedure AS sig
               FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
              WHERE n.nspname = 'steam'
    LOOP
        EXECUTE format('ALTER FUNCTION %s SET search_path = steam, public', f.sig);
    END LOOP;
END $$;
