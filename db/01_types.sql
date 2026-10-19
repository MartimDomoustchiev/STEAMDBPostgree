-- =============================================================================
-- 01  Extensions and enum types
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS citext     SCHEMA public;   -- case-insensitive usernames / emails
CREATE EXTENSION IF NOT EXISTS pg_trgm    SCHEMA public;   -- fuzzy store search
CREATE EXTENSION IF NOT EXISTS btree_gist SCHEMA public;   -- "no overlapping price periods" exclusion constraint

-- accounts & social
CREATE TYPE account_status      AS ENUM ('active', 'limited', 'suspended', 'banned', 'deleted');
CREATE TYPE profile_visibility  AS ENUM ('public', 'friends_only', 'private');
CREATE TYPE request_status      AS ENUM ('pending', 'accepted', 'declined', 'cancelled');
CREATE TYPE group_role          AS ENUM ('member', 'moderator', 'officer', 'owner');
CREATE TYPE ban_type            AS ENUM ('community', 'trade', 'market', 'anti_cheat', 'account');

-- catalog
CREATE TYPE app_type            AS ENUM ('game', 'dlc', 'demo', 'software', 'tool', 'soundtrack', 'video');
CREATE TYPE app_status          AS ENUM ('unreleased', 'early_access', 'released', 'delisted');
CREATE TYPE requirement_tier    AS ENUM ('minimum', 'recommended');
CREATE TYPE media_type          AS ENUM ('header', 'capsule', 'background', 'screenshot', 'trailer');

-- store & wallet
CREATE TYPE payment_provider    AS ENUM ('card', 'paypal', 'bank_transfer');
CREATE TYPE order_status        AS ENUM ('pending', 'completed', 'failed', 'cancelled', 'refunded', 'partially_refunded');
CREATE TYPE wallet_txn_type     AS ENUM ('topup', 'wallet_code', 'purchase', 'refund', 'market_sale', 'market_purchase', 'adjustment');
CREATE TYPE key_status          AS ENUM ('available', 'redeemed', 'revoked');
CREATE TYPE refund_status       AS ENUM ('pending', 'approved', 'denied');

-- library & community
CREATE TYPE ownership_source    AS ENUM ('purchase', 'gift', 'key_activation', 'free_license', 'promo');
CREATE TYPE vote_type           AS ENUM ('helpful', 'not_helpful', 'funny');
CREATE TYPE notification_type   AS ENUM ('friend_request', 'gift_received', 'trade_offer', 'trade_accepted',
                                         'market_item_sold', 'refund_processed');

-- inventory & market
CREATE TYPE item_type           AS ENUM ('trading_card', 'emoticon', 'profile_background', 'game_item', 'booster_pack');
CREATE TYPE item_rarity         AS ENUM ('common', 'uncommon', 'rare', 'legendary');
CREATE TYPE trade_status        AS ENUM ('pending', 'accepted', 'declined', 'cancelled', 'expired');
CREATE TYPE listing_status      AS ENUM ('active', 'sold', 'cancelled');
