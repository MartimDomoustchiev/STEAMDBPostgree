-- =============================================================================
-- 11  Views
-- =============================================================================

-- Current price of every app per currency, with the best active sale discount applied.
CREATE VIEW v_current_app_prices AS
SELECT p.app_id,
       p.currency_code,
       p.price_minor                                             AS base_price_minor,
       COALESCE(d.discount_pct, 0)::smallint                     AS discount_pct,
       round(p.price_minor * (100 - COALESCE(d.discount_pct, 0)) / 100.0)::bigint AS final_price_minor,
       d.sale_id
  FROM app_prices p
  LEFT JOIN LATERAL (
        SELECT sa.discount_pct, sa.sale_id
          FROM sale_apps sa
          JOIN sales s ON s.sale_id = sa.sale_id
         WHERE sa.app_id = p.app_id
           AND now() BETWEEN s.starts_at AND s.ends_at
         ORDER BY sa.discount_pct DESC
         LIMIT 1
  ) d ON TRUE
 WHERE p.valid_from <= now()
   AND (p.valid_to IS NULL OR p.valid_to > now());

-- Store page overview: one row per app with developers, publishers, genres and review score.
CREATE VIEW v_app_catalog AS
SELECT a.app_id,
       a.name,
       a.slug,
       a.app_type,
       a.status,
       a.release_date,
       a.is_free,
       a.metacritic_score,
       a.positive_reviews,
       a.negative_reviews,
       CASE WHEN a.positive_reviews + a.negative_reviews = 0 THEN NULL
            ELSE round(100.0 * a.positive_reviews / (a.positive_reviews + a.negative_reviews), 1) END AS positive_pct,
       (SELECT string_agg(c.name, ', ' ORDER BY c.name) FROM app_developers ad JOIN companies c USING (company_id) WHERE ad.app_id = a.app_id) AS developers,
       (SELECT string_agg(c.name, ', ' ORDER BY c.name) FROM app_publishers ap JOIN companies c USING (company_id) WHERE ap.app_id = a.app_id) AS publishers,
       (SELECT string_agg(g.name, ', ' ORDER BY ag.is_primary DESC, g.name) FROM app_genres ag JOIN genres g USING (genre_id) WHERE ag.app_id = a.app_id) AS genres,
       (SELECT string_agg(pl.code, ', ' ORDER BY pl.code) FROM app_platforms ap JOIN platforms pl USING (platform_id) WHERE ap.app_id = a.app_id) AS platforms
  FROM apps a;

-- "Mostly Positive", "Overwhelmingly Positive" ... like the store badges.
CREATE VIEW v_app_review_summary AS
SELECT a.app_id,
       a.name,
       a.positive_reviews + a.negative_reviews AS total_reviews,
       CASE
           WHEN a.positive_reviews + a.negative_reviews = 0 THEN 'No user reviews'
           WHEN a.positive_reviews + a.negative_reviews < 10 THEN 'Not enough reviews'
           WHEN a.positive_reviews::numeric / (a.positive_reviews + a.negative_reviews) >= 0.95 THEN 'Overwhelmingly Positive'
           WHEN a.positive_reviews::numeric / (a.positive_reviews + a.negative_reviews) >= 0.80 THEN 'Very Positive'
           WHEN a.positive_reviews::numeric / (a.positive_reviews + a.negative_reviews) >= 0.70 THEN 'Mostly Positive'
           WHEN a.positive_reviews::numeric / (a.positive_reviews + a.negative_reviews) >= 0.40 THEN 'Mixed'
           WHEN a.positive_reviews::numeric / (a.positive_reviews + a.negative_reviews) >= 0.20 THEN 'Mostly Negative'
           ELSE 'Overwhelmingly Negative'
       END AS rating_label
  FROM apps a;

-- Per-user library totals.
CREATE VIEW v_user_library_summary AS
SELECT u.user_id,
       u.username,
       count(le.app_id)                                         AS apps_owned,
       COALESCE(sum(le.total_playtime_minutes), 0)              AS total_playtime_minutes,
       round(COALESCE(sum(le.total_playtime_minutes), 0) / 60.0, 1) AS total_playtime_hours,
       max(le.last_played_at)                                   AS last_played_at
  FROM users u
  LEFT JOIN library_entries le ON le.user_id = u.user_id
 GROUP BY u.user_id, u.username;

-- Friend list, both directions: one row per (user, friend).
CREATE VIEW v_user_friends AS
SELECT f.user_id_low  AS user_id, f.user_id_high AS friend_id, f.since FROM friendships f
UNION ALL
SELECT f.user_id_high AS user_id, f.user_id_low  AS friend_id, f.since FROM friendships f;

-- Best sellers by net revenue (refunded items excluded), per currency.
CREATE VIEW v_top_selling_apps AS
SELECT a.app_id,
       a.name,
       o.currency_code,
       count(*)                      AS units_sold,
       sum(oi.final_price_minor)     AS revenue_minor
  FROM order_items oi
  JOIN orders o ON o.order_id = oi.order_id AND o.status IN ('completed', 'partially_refunded')
  JOIN apps   a ON a.app_id   = oi.app_id
 WHERE oi.refunded_at IS NULL
 GROUP BY a.app_id, a.name, o.currency_code;

-- Achievement progress per user and game.
CREATE VIEW v_user_achievement_progress AS
SELECT le.user_id,
       a.app_id,
       a.name                                   AS app_name,
       count(ach.achievement_id)                AS total_achievements,
       count(ua.achievement_id)                 AS unlocked,
       CASE WHEN count(ach.achievement_id) = 0 THEN NULL
            ELSE round(100.0 * count(ua.achievement_id) / count(ach.achievement_id), 1) END AS pct_complete
  FROM library_entries le
  JOIN apps a ON a.app_id = le.app_id
  LEFT JOIN achievements ach ON ach.app_id = a.app_id
  LEFT JOIN user_achievements ua ON ua.achievement_id = ach.achievement_id AND ua.user_id = le.user_id
 GROUP BY le.user_id, a.app_id, a.name
HAVING count(ach.achievement_id) > 0;

-- Wallet balance with formatted display amount.
CREATE VIEW v_user_wallets AS
SELECT w.user_id,
       u.username,
       w.currency_code,
       w.balance_minor,
       to_char(w.balance_minor / power(10, c.minor_units), 'FM999,999,990.' || repeat('0', c.minor_units)) || ' ' || c.symbol AS balance_display
  FROM user_wallets w
  JOIN users u      ON u.user_id = w.user_id
  JOIN currencies c ON c.currency_code = w.currency_code;

-- Active community market listings with item details.
CREATE VIEW v_active_market_listings AS
SELECT ml.listing_id,
       ml.price_minor,
       ml.currency_code,
       d.name       AS item_name,
       d.item_type,
       d.rarity,
       a.name       AS app_name,
       u.username   AS seller,
       ml.listed_at
  FROM market_listings ml
  JOIN inventory_items i  ON i.inventory_item_id = ml.inventory_item_id
  JOIN item_definitions d ON d.item_def_id = i.item_def_id
  JOIN apps a             ON a.app_id = d.app_id
  JOIN users u            ON u.user_id = ml.seller_id
 WHERE ml.status = 'active';

-- Daily community-market price history per item type (what the market price graph shows).
CREATE VIEW v_market_price_history AS
SELECT d.item_def_id,
       d.name                          AS item_name,
       ml.currency_code,
       (ml.sold_at AT TIME ZONE 'UTC')::date AS day_utc,
       count(*)                        AS units_sold,
       min(ml.price_minor)             AS min_price_minor,
       max(ml.price_minor)             AS max_price_minor,
       round(avg(ml.price_minor))::bigint AS avg_price_minor
  FROM market_listings ml
  JOIN inventory_items i  ON i.inventory_item_id = ml.inventory_item_id
  JOIN item_definitions d ON d.item_def_id = i.item_def_id
 WHERE ml.status = 'sold'
 GROUP BY d.item_def_id, d.name, ml.currency_code, (ml.sold_at AT TIME ZONE 'UTC')::date;

-- Users that currently have an active ban.
CREATE VIEW v_active_bans AS
SELECT b.*, u.username
  FROM user_bans b JOIN users u ON u.user_id = b.user_id
 WHERE b.expires_at IS NULL OR b.expires_at > now();

-- Workshop items with subscriber counts.
CREATE VIEW v_workshop_items AS
SELECT w.item_id, w.app_id, a.name AS app_name, w.title, u.username AS author,
       (SELECT count(*) FROM workshop_subscriptions s WHERE s.item_id = w.item_id) AS subscribers,
       w.created_at
  FROM workshop_items w
  JOIN apps a  ON a.app_id = w.app_id
  JOIN users u ON u.user_id = w.author_id;
