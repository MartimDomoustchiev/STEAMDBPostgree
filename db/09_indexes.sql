-- =============================================================================
-- 09  Secondary indexes (primary keys and UNIQUE constraints already have their own)
-- =============================================================================

-- accounts & social
CREATE INDEX ix_users_country            ON users (country_code);
CREATE INDEX ix_user_sessions_user       ON user_sessions (user_id) WHERE revoked_at IS NULL;
CREATE INDEX ix_user_bans_user_type      ON user_bans (user_id, ban_type);
CREATE INDEX ix_user_bans_issued_by      ON user_bans (issued_by) WHERE issued_by IS NOT NULL;
CREATE INDEX ix_groups_owner             ON groups (owner_id);
CREATE INDEX ix_notifications_unread     ON notifications (user_id, created_at DESC) WHERE read_at IS NULL;
CREATE INDEX ix_notifications_user       ON notifications (user_id, created_at DESC);
CREATE INDEX ix_friendships_high         ON friendships (user_id_high);
CREATE INDEX ix_friend_requests_receiver ON friend_requests (receiver_id, status);
CREATE INDEX ix_friend_requests_sender   ON friend_requests (sender_id, status);
CREATE INDEX ix_chat_receiver            ON chat_messages (receiver_id, sent_at DESC);
CREATE INDEX ix_chat_pair                ON chat_messages (sender_id, receiver_id, sent_at DESC);
CREATE INDEX ix_group_members_user       ON group_members (user_id);

-- catalog
CREATE INDEX ix_apps_name_trgm           ON apps USING gin (name gin_trgm_ops);
CREATE INDEX ix_apps_type_status         ON apps (app_type, status);
CREATE INDEX ix_apps_release_date        ON apps (release_date DESC);
CREATE INDEX ix_apps_parent              ON apps (parent_app_id) WHERE parent_app_id IS NOT NULL;
CREATE INDEX ix_app_developers_company   ON app_developers (company_id);
CREATE INDEX ix_app_publishers_company   ON app_publishers (company_id);
CREATE INDEX ix_app_genres_genre         ON app_genres (genre_id);
CREATE INDEX ix_app_tags_tag             ON app_tags (tag_id, votes DESC);
CREATE INDEX ix_app_platforms_platform   ON app_platforms (platform_id);
CREATE INDEX ix_app_languages_language   ON app_languages (language_code);
CREATE INDEX ix_app_media_app            ON app_media (app_id, media_type, sort_order);
CREATE INDEX ix_achievements_app         ON achievements (app_id);

-- store
CREATE INDEX ix_sales_period             ON sales (starts_at, ends_at);
CREATE INDEX ix_sale_apps_app            ON sale_apps (app_id);
CREATE INDEX ix_wishlists_app            ON wishlists (app_id);
CREATE INDEX ix_cart_items_app           ON cart_items (app_id);
CREATE INDEX ix_payment_methods_user     ON payment_methods (user_id);
CREATE INDEX ix_orders_user              ON orders (user_id, created_at DESC);
CREATE INDEX ix_orders_recipient         ON orders (gift_recipient_id) WHERE gift_recipient_id IS NOT NULL;
CREATE INDEX ix_orders_status            ON orders (status);
CREATE INDEX ix_orders_payment_method    ON orders (payment_method_id) WHERE payment_method_id IS NOT NULL;
CREATE INDEX ix_order_items_app          ON order_items (app_id);
CREATE INDEX ix_order_items_bundle       ON order_items (bundle_id) WHERE bundle_id IS NOT NULL;
CREATE INDEX ix_wallet_txn_user          ON wallet_transactions (user_id, created_at DESC);
CREATE INDEX ix_wallet_txn_order         ON wallet_transactions (order_id) WHERE order_id IS NOT NULL;
CREATE INDEX ix_wallet_codes_redeemed_by ON wallet_codes (redeemed_by) WHERE redeemed_by IS NOT NULL;
CREATE INDEX ix_game_keys_app            ON game_keys (app_id, status);
CREATE INDEX ix_game_keys_redeemed_by    ON game_keys (redeemed_by) WHERE redeemed_by IS NOT NULL;
CREATE INDEX ix_refunds_user             ON refunds (user_id);

-- library
CREATE INDEX ix_library_app              ON library_entries (app_id);
CREATE INDEX ix_library_order_item       ON library_entries (order_item_id) WHERE order_item_id IS NOT NULL;   -- refunds
CREATE INDEX ix_library_key              ON library_entries (key_id) WHERE key_id IS NOT NULL;
CREATE INDEX ix_playtime_user_time       ON playtime_sessions (user_id, started_at DESC);
CREATE INDEX ix_playtime_user_app        ON playtime_sessions (user_id, app_id, started_at DESC);           -- FK + per-game history
CREATE INDEX ix_playtime_app             ON playtime_sessions (app_id);
CREATE INDEX ix_user_achievements_ach    ON user_achievements (achievement_id);

-- community
CREATE INDEX ix_reviews_app              ON reviews (app_id, created_at DESC) WHERE is_visible;
CREATE INDEX ix_review_votes_user        ON review_votes (user_id);
CREATE INDEX ix_review_comments_review   ON review_comments (review_id, created_at);
CREATE INDEX ix_review_comments_user     ON review_comments (user_id);
CREATE INDEX ix_threads_app              ON discussion_threads (app_id, created_at DESC);
CREATE INDEX ix_threads_author           ON discussion_threads (author_id);
CREATE INDEX ix_posts_thread             ON discussion_posts (thread_id, created_at);
CREATE INDEX ix_posts_author             ON discussion_posts (author_id);
CREATE INDEX ix_workshop_app             ON workshop_items (app_id);
CREATE INDEX ix_workshop_author          ON workshop_items (author_id);
CREATE INDEX ix_workshop_subs_item       ON workshop_subscriptions (item_id);

-- inventory & market
CREATE INDEX ix_item_defs_app            ON item_definitions (app_id);
CREATE INDEX ix_inventory_owner          ON inventory_items (owner_id);
CREATE INDEX ix_inventory_def            ON inventory_items (item_def_id);
CREATE INDEX ix_trade_offers_receiver    ON trade_offers (receiver_id, status);
CREATE INDEX ix_trade_offers_sender      ON trade_offers (sender_id, status);
CREATE INDEX ix_trade_items_item         ON trade_offer_items (inventory_item_id);
CREATE INDEX ix_market_seller            ON market_listings (seller_id);
CREATE INDEX ix_market_buyer             ON market_listings (buyer_id) WHERE buyer_id IS NOT NULL;
CREATE INDEX ix_market_item              ON market_listings (inventory_item_id);    -- FK + item sale history
CREATE INDEX ix_market_sold              ON market_listings (sold_at) WHERE status = 'sold';
CREATE INDEX ix_market_active_price      ON market_listings (currency_code, price_minor) WHERE status = 'active';
