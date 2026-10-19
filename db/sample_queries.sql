-- =============================================================================
--  Sample queries (read-only). Not loaded by 00_init.sql.
--      psql -d steam_db -f sample_queries.sql
-- =============================================================================
SET search_path TO steam, public;

-- 1. Store front: what is on sale right now in EUR, biggest discount first
SELECT a.name, p.discount_pct, round(p.base_price_minor / 100.0, 2) AS was_eur, round(p.final_price_minor / 100.0, 2) AS now_eur
  FROM v_current_app_prices p JOIN apps a USING (app_id)
 WHERE p.currency_code = 'EUR' AND p.discount_pct > 0
 ORDER BY p.discount_pct DESC, a.name;

-- 2. Fuzzy search, tolerant of typos (uses the pg_trgm index)
SELECT name, similarity(name, 'witcher wild hunt') AS score
  FROM apps
 WHERE name % 'witcher wild hunt'
 ORDER BY score DESC
 LIMIT 5;

-- 3. Store page for one game
SELECT c.*, r.rating_label
  FROM v_app_catalog c JOIN v_app_review_summary r USING (app_id)
 WHERE c.slug = 'elden-ring';

-- 4. Games by tag, ranked by how strongly the community applied the tag
SELECT a.name, at.votes
  FROM app_tags at JOIN tags t USING (tag_id) JOIN apps a USING (app_id)
 WHERE t.name = 'Difficult'
 ORDER BY at.votes DESC;

-- 5. Games that support Bulgarian
SELECT a.name, al.has_interface, al.has_full_audio, al.has_subtitles
  FROM app_languages al JOIN apps a USING (app_id)
 WHERE al.language_code = 'bg';

-- 6. A user's library, most played first
SELECT a.name, le.source, round(le.total_playtime_minutes / 60.0, 1) AS hours, le.last_played_at
  FROM library_entries le JOIN apps a USING (app_id) JOIN users u USING (user_id)
 WHERE u.username = 'alice_gamer'
 ORDER BY le.total_playtime_minutes DESC;

-- 7. Friends of a user and what they played most recently
SELECT fu.username AS friend,
       (SELECT a.name FROM playtime_sessions ps JOIN apps a USING (app_id)
         WHERE ps.user_id = f.friend_id ORDER BY ps.started_at DESC LIMIT 1) AS last_game
  FROM v_user_friends f JOIN users fu ON fu.user_id = f.friend_id
 WHERE f.user_id = (SELECT user_id FROM users WHERE username = 'alice_gamer');

-- 8. Wishlisted games that are discounted right now, for each user (sale e-mail)
SELECT u.username, a.name, p.discount_pct, p.final_price_minor, p.currency_code
  FROM wishlists w
  JOIN users u        ON u.user_id = w.user_id
  JOIN user_wallets uw ON uw.user_id = u.user_id
  JOIN apps a         ON a.app_id = w.app_id
  JOIN v_current_app_prices p ON p.app_id = w.app_id AND p.currency_code = uw.currency_code
 WHERE p.discount_pct > 0
 ORDER BY u.username, p.discount_pct DESC;

-- 9. Revenue per game and currency (refunds excluded)
SELECT name, currency_code, units_sold, round(revenue_minor / 100.0, 2) AS revenue
  FROM v_top_selling_apps
 ORDER BY currency_code, revenue_minor DESC;

-- 10. Wallet statement of a user
SELECT t.created_at, t.txn_type, t.amount_minor, t.balance_after_minor, t.note
  FROM wallet_transactions t JOIN users u USING (user_id)
 WHERE u.username = 'diana_plays'
 ORDER BY t.txn_id;

-- 11. Rarest achievements (share of owners that unlocked them)
SELECT a.name AS game, ach.name AS achievement,
       round(100.0 * count(ua.user_id) / NULLIF((SELECT count(*) FROM library_entries le WHERE le.app_id = a.app_id), 0), 1) AS pct_of_owners
  FROM achievements ach
  JOIN apps a ON a.app_id = ach.app_id
  LEFT JOIN user_achievements ua ON ua.achievement_id = ach.achievement_id
 GROUP BY a.app_id, a.name, ach.achievement_id, ach.name
 ORDER BY pct_of_owners NULLS FIRST;

-- 12. Most helpful reviews of a game
SELECT u.username, r.is_recommended, r.votes_helpful, r.votes_funny,
       round(r.playtime_at_review_minutes / 60.0, 1) AS hours_at_review, left(r.body, 60) AS excerpt
  FROM reviews r JOIN users u USING (user_id)
 WHERE r.app_id = (SELECT app_id FROM apps WHERE slug = 'hades') AND r.is_visible
 ORDER BY r.votes_helpful DESC, r.created_at DESC;

-- 13. Unread notifications of a user
SELECT n.type, n.payload, n.created_at
  FROM notifications n JOIN users u USING (user_id)
 WHERE u.username = 'charlie_dev' AND n.read_at IS NULL
 ORDER BY n.created_at DESC;

-- 14. Cheapest active market listing per item
SELECT DISTINCT ON (item_name, currency_code) item_name, app_name, currency_code, price_minor, seller
  FROM v_active_market_listings
 ORDER BY item_name, currency_code, price_minor;

-- 15. Can this purchase still be refunded?
SELECT oi.order_item_id, a.name, o.completed_at, is_refund_eligible(oi.order_item_id) AS refundable
  FROM order_items oi JOIN orders o USING (order_id) JOIN apps a USING (app_id)
 ORDER BY oi.order_item_id;
