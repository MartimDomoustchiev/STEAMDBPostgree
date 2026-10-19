-- =============================================================================
-- 12  Sample data (all users, emails, hashes and codes are fictional)
-- =============================================================================

-- ---------------------------------------------------------------------------
-- reference data
-- ---------------------------------------------------------------------------
INSERT INTO currencies (currency_code, name, symbol, minor_units) VALUES
    ('USD', 'US Dollar',      '$',   2),
    ('EUR', 'Euro',           '€',   2),
    ('BGN', 'Bulgarian Lev',  'лв.', 2),
    ('GBP', 'Pound Sterling', '£',   2),
    ('PLN', 'Polish Zloty',   'zł',  2),
    ('JPY', 'Japanese Yen',   '¥',   0);

INSERT INTO countries (country_code, name, default_currency) VALUES
    ('US', 'United States', 'USD'),
    ('BG', 'Bulgaria',      'BGN'),
    ('DE', 'Germany',       'EUR'),
    ('FR', 'France',        'EUR'),
    ('GB', 'United Kingdom','GBP'),
    ('ES', 'Spain',         'EUR'),
    ('PL', 'Poland',        'PLN'),
    ('JP', 'Japan',         'JPY');

INSERT INTO languages (language_code, name, native_name) VALUES
    ('en',    'English',             'English'),
    ('bg',    'Bulgarian',           'Български'),
    ('de',    'German',              'Deutsch'),
    ('fr',    'French',              'Français'),
    ('es',    'Spanish',             'Español'),
    ('ru',    'Russian',             'Русский'),
    ('ja',    'Japanese',            '日本語'),
    ('zh-CN', 'Simplified Chinese',  '简体中文'),
    ('pl',    'Polish',              'Polski');

INSERT INTO platforms (platform_id, code, name) VALUES
    (1, 'windows',   'Windows'),
    (2, 'macos',     'macOS'),
    (3, 'linux',     'Linux / SteamOS'),
    (4, 'steamdeck', 'Steam Deck');

INSERT INTO genres (genre_id, name) VALUES
    (1, 'Action'), (2, 'Adventure'), (3, 'RPG'), (4, 'Strategy'), (5, 'Simulation'),
    (6, 'Indie'),  (7, 'Puzzle'),    (8, 'Shooter'), (9, 'Racing'), (10, 'Sports');

INSERT INTO tags (tag_id, name) VALUES
    (1, 'Open World'), (2, 'Singleplayer'), (3, 'Multiplayer'), (4, 'Co-op'), (5, 'Story Rich'),
    (6, 'Souls-like'), (7, 'Difficult'),    (8, 'Sci-fi'),      (9, 'Fantasy'), (10, 'Atmospheric'),
    (11, 'Sandbox'),   (12, 'Roguelike'),   (13, 'Pixel Graphics'), (14, 'Competitive'),
    (15, 'Free to Play'), (16, 'Metroidvania');

-- ---------------------------------------------------------------------------
-- users (wallet + profile rows are created by trigger)
-- ---------------------------------------------------------------------------
INSERT INTO users (user_id, username, email, password_hash, country_code, steam_level, xp, two_factor_enabled, email_verified_at, created_at, last_login_at) VALUES
    (1, 'alice_gamer',    'alice@example.com',   '$argon2id$v=19$m=65536,t=3,p=4$c2FsdHNhbHQ$ZmFrZWhhc2gx', 'US', 24, 2400, TRUE,  '2023-05-01 10:00+00', '2023-05-01 09:55+00', now() - interval '1 hour'),
    (2, 'bob_the_builder','bob@example.com',     '$argon2id$v=19$m=65536,t=3,p=4$c2FsdHNhbHQ$ZmFrZWhhc2gy', 'BG', 12, 1200, FALSE, '2024-01-12 12:00+00', '2024-01-12 11:50+00', now() - interval '3 hours'),
    (3, 'charlie_dev',    'charlie@example.com', '$argon2id$v=19$m=65536,t=3,p=4$c2FsdHNhbHQ$ZmFrZWhhc2gz', 'DE', 35, 4100, TRUE,  '2022-09-30 08:30+00', '2022-09-30 08:20+00', now() - interval '1 day'),
    (4, 'diana_plays',    'diana@example.com',   '$argon2id$v=19$m=65536,t=3,p=4$c2FsdHNhbHQ$ZmFrZWhhc2g0', 'FR',  8,  700, FALSE, '2025-02-02 17:00+00', '2025-02-02 16:58+00', now() - interval '2 days'),
    (5, 'eve_speedrun',   'eve@example.com',     '$argon2id$v=19$m=65536,t=3,p=4$c2FsdHNhbHQ$ZmFrZWhhc2g1', 'GB', 18, 1900, TRUE,  '2023-11-11 11:11+00', '2023-11-11 11:00+00', now() - interval '5 hours'),
    (6, 'frank_rpg',      'frank@example.com',   '$argon2id$v=19$m=65536,t=3,p=4$c2FsdHNhbHQ$ZmFrZWhhc2g2', 'ES',  5,  400, FALSE, '2025-12-24 20:00+00', '2025-12-24 19:59+00', now() - interval '6 hours'),
    (7, 'grace_indie',    'grace@example.com',   '$argon2id$v=19$m=65536,t=3,p=4$c2FsdHNhbHQ$ZmFrZWhhc2g3', 'US', 15, 1500, FALSE, '2024-06-06 06:06+00', '2024-06-06 06:00+00', now() - interval '30 minutes'),
    (8, 'heidi_tank',     'heidi@example.com',   '$argon2id$v=19$m=65536,t=3,p=4$c2FsdHNhbHQ$ZmFrZWhhc2g4', 'BG',  3,  150, FALSE, '2026-04-04 14:00+00', '2026-04-04 13:55+00', now() - interval '4 days');

UPDATE user_profiles SET display_name = 'Alice',   bio = 'Souls-like enthusiast. Send help.',       visibility = 'public'       WHERE user_id = 1;
UPDATE user_profiles SET display_name = 'Bob',     bio = 'Terraria is a lifestyle.',                visibility = 'public'       WHERE user_id = 2;
UPDATE user_profiles SET display_name = 'Charlie', bio = 'I mod everything.',                       visibility = 'friends_only' WHERE user_id = 3;
UPDATE user_profiles SET display_name = 'Diana',   real_name = 'Diana M.',                          visibility = 'public'       WHERE user_id = 4;
UPDATE user_profiles SET display_name = 'Eve',     bio = 'Any% or nothing.',                        visibility = 'public'       WHERE user_id = 5;
UPDATE user_profiles SET display_name = 'Frank',   visibility = 'private'                           WHERE user_id = 6;
UPDATE user_profiles SET display_name = 'Grace',   bio = 'Cozy and indie games only.',              visibility = 'public'       WHERE user_id = 7;
UPDATE user_profiles SET display_name = 'Heidi',   bio = 'Always play the tank.',                   visibility = 'public'       WHERE user_id = 8;

INSERT INTO user_sessions (user_id, token_hash, ip_address, user_agent, created_at, expires_at) VALUES
    (1, sha256('demo-session-token-1'::bytea), '203.0.113.10',  'SteamClient/2026.10 (Windows)', now() - interval '1 hour',     now() + interval '29 days'),
    (2, sha256('demo-session-token-2'::bytea), '198.51.100.24', 'SteamClient/2026.10 (SteamOS)', now() - interval '3 hours',    now() + interval '29 days'),
    (7, sha256('demo-session-token-7'::bytea), '203.0.113.77',  'Mozilla/5.0 (Macintosh)',       now() - interval '30 minutes', now() + interval '1 day');

INSERT INTO user_bans (user_id, ban_type, reason, issued_by, issued_at, expires_at) VALUES
    (8, 'trade', 'Trade scam report (resolved after review)', 3, '2026-05-01 10:00+00', '2026-05-15 10:00+00');

INSERT INTO user_blocks (blocker_id, blocked_id) VALUES (3, 4), (6, 8);

-- friends (accepted requests create the friendships through a trigger)
INSERT INTO friend_requests (sender_id, receiver_id, status, created_at, responded_at) VALUES
    (1, 2, 'accepted',  '2024-02-01 10:00+00', '2024-02-01 12:00+00'),
    (1, 3, 'accepted',  '2024-03-10 09:00+00', '2024-03-10 09:30+00'),
    (2, 3, 'accepted',  '2024-04-02 18:00+00', '2024-04-03 08:00+00'),
    (5, 6, 'accepted',  '2026-01-05 21:00+00', '2026-01-05 21:10+00'),
    (7, 8, 'accepted',  '2026-04-20 15:00+00', '2026-04-20 16:00+00'),
    (3, 4, 'declined',  '2025-03-01 10:00+00', '2025-03-02 10:00+00'),
    (8, 1, 'cancelled', '2026-05-02 10:00+00', '2026-05-02 11:00+00');
INSERT INTO friend_requests (sender_id, receiver_id) VALUES (4, 1);          -- still pending

INSERT INTO chat_messages (sender_id, receiver_id, body, sent_at, read_at) VALUES
    (1, 2, 'Did you finish the Hollow Knight DLC yet?',   now() - interval '2 days', now() - interval '2 days' + interval '5 minutes'),
    (2, 1, 'Not yet, stuck on the Pantheon runs.',        now() - interval '2 days' + interval '6 minutes', now() - interval '2 days' + interval '9 minutes'),
    (1, 2, 'Trade me that card and I will help you out.', now() - interval '1 day',  NULL),
    (7, 8, 'Want to try the co-op in Stardew tonight?',   now() - interval '3 hours', NULL);

INSERT INTO groups (group_id, name, tag, description, owner_id) VALUES
    (1, 'Souls-like Survivors', 'SOULS', 'We died so you do not have to.', 1),
    (2, 'Indie Lovers',         'INDIE', 'Small teams, big ideas.',         7);
-- the owners (1 and 7) are added as members automatically by a trigger
INSERT INTO group_members (group_id, user_id, role) VALUES
    (1, 2, 'member'), (1, 3, 'moderator'),
    (2, 8, 'member'), (2, 6, 'officer');

-- ---------------------------------------------------------------------------
-- catalog
-- ---------------------------------------------------------------------------
INSERT INTO companies (company_id, name, website_url, country_code) VALUES
    (1, 'Valve',                          'https://www.valvesoftware.com', 'US'),
    (2, 'CD PROJEKT RED',                 'https://www.cdprojektred.com',  'PL'),
    (3, 'FromSoftware',                   'https://www.fromsoftware.jp',   'JP'),
    (4, 'Bandai Namco Entertainment',     'https://www.bandainamcoent.com','JP'),
    (5, 'Supergiant Games',               'https://www.supergiantgames.com','US'),
    (6, 'Team Cherry',                    'https://www.teamcherry.com.au', NULL),
    (7, 'Re-Logic',                       'https://re-logic.com',          'US'),
    (8, 'ConcernedApe',                   'https://www.stardewvalley.net', 'US'),
    (9, 'Larian Studios',                 'https://larian.com',            NULL);

INSERT INTO apps (app_id, parent_app_id, app_type, name, slug, short_description, status, release_date, is_free, age_rating, metacritic_score) VALUES
    (1,  NULL, 'game',       'Counter-Strike 2',                    'counter-strike-2',        'Competitive team-based tactical shooter.',                         'released', '2023-09-27', TRUE,  18, NULL),
    (2,  NULL, 'game',       'Dota 2',                              'dota-2',                  'Every day, millions of players enter the battle as one of over a hundred heroes.', 'released', '2013-07-09', TRUE, 12, 90),
    (3,  NULL, 'game',       'Portal 2',                            'portal-2',                'Sequel to the acclaimed puzzle game about portals and science.',   'released', '2011-04-18', FALSE, 12, 95),
    (4,  NULL, 'game',       'The Witcher 3: Wild Hunt',            'the-witcher-3',           'Story-driven open world RPG set in a dark fantasy universe.',      'released', '2015-05-18', FALSE, 18, 93),
    (5,  4,    'dlc',        'The Witcher 3: Blood and Wine',       'the-witcher-3-blood-and-wine', 'Expansion set in the sun-drenched region of Toussaint.',       'released', '2016-05-31', FALSE, 18, 92),
    (6,  NULL, 'game',       'Elden Ring',                          'elden-ring',              'Rise, Tarnished, and be guided by grace in a vast open fantasy world.', 'released', '2022-02-25', FALSE, 16, 96),
    (7,  NULL, 'game',       'Hades',                               'hades',                   'Defy the god of the dead as you hack and slash out of the Underworld.', 'released', '2020-09-17', FALSE, 12, 93),
    (8,  NULL, 'game',       'Hollow Knight',                       'hollow-knight',           'Explore a vast ruined kingdom of insects and heroes.',             'released', '2017-02-24', FALSE, 7,  87),
    (9,  NULL, 'game',       'Terraria',                            'terraria',                'Dig, fight, explore, build. The very world is at your fingertips.', 'released', '2011-05-16', FALSE, 12, 83),
    (10, NULL, 'game',       'Stardew Valley',                      'stardew-valley',          'Inherit your grandfather''s old farm and build a new life.',        'released', '2016-02-26', FALSE, 7,  89),
    (11, NULL, 'game',       'Baldur''s Gate 3',                    'baldurs-gate-3',          'Gather your party and return to the Forgotten Realms.',            'released', '2023-08-03', FALSE, 18, 96),
    (12, NULL, 'game',       'Half-Life: Alyx',                     'half-life-alyx',          'Virtual reality return to the Half-Life universe.',                'released', '2020-03-23', FALSE, 16, 93),
    (13, 7,    'soundtrack', 'Hades - Original Soundtrack',         'hades-ost',               'The complete score of Hades.',                                     'released', '2020-09-17', FALSE, 0,  NULL);

INSERT INTO app_developers (app_id, company_id) VALUES
    (1,1),(2,1),(3,1),(4,2),(5,2),(6,3),(7,5),(8,6),(9,7),(10,8),(11,9),(12,1),(13,5);
INSERT INTO app_publishers (app_id, company_id) VALUES
    (1,1),(2,1),(3,1),(4,2),(5,2),(6,4),(7,5),(8,6),(9,7),(10,8),(11,9),(12,1),(13,5);

INSERT INTO app_genres (app_id, genre_id, is_primary) VALUES
    (1,8,TRUE),(1,1,FALSE),
    (2,4,TRUE),(2,1,FALSE),
    (3,7,TRUE),(3,2,FALSE),
    (4,3,TRUE),(4,2,FALSE),(4,1,FALSE),
    (5,3,TRUE),(5,2,FALSE),
    (6,3,TRUE),(6,1,FALSE),
    (7,1,TRUE),(7,6,FALSE),(7,3,FALSE),
    (8,1,TRUE),(8,2,FALSE),(8,6,FALSE),
    (9,2,TRUE),(9,1,FALSE),(9,6,FALSE),
    (10,5,TRUE),(10,6,FALSE),(10,3,FALSE),
    (11,3,TRUE),(11,4,FALSE),(11,2,FALSE),
    (12,8,TRUE),(12,2,FALSE),
    (13,6,TRUE);

INSERT INTO app_tags (app_id, tag_id, votes) VALUES
    (1,14,900),(1,3,850),(1,15,300),
    (2,14,800),(2,3,780),(2,15,400),
    (3,7,700),(3,4,500),(3,8,450),(3,2,300),
    (4,1,1200),(4,5,1100),(4,9,900),(4,2,700),
    (5,5,400),(5,9,380),
    (6,1,1500),(6,6,1400),(6,7,1100),(6,9,900),
    (7,12,1300),(7,7,600),(7,10,500),(7,2,400),
    (8,16,1500),(8,10,1100),(8,7,900),(8,13,300),
    (9,11,1200),(9,4,900),(9,13,700),(9,3,500),
    (10,13,900),(10,4,700),(10,2,500),
    (11,5,1600),(11,4,1100),(11,9,1000),(11,3,600),
    (12,8,800),(12,5,600),(12,2,500),
    (13,10,200);

INSERT INTO app_platforms (app_id, platform_id) SELECT app_id, 1 FROM apps;        -- everything runs on Windows
INSERT INTO app_platforms (app_id, platform_id) VALUES
    (1,3),(2,2),(2,3),(3,2),(3,3),(7,2),(8,2),(8,3),(9,2),(9,3),(10,2),(10,3),
    (3,4),(4,4),(6,4),(7,4),(8,4),(9,4),(10,4),(11,4);

INSERT INTO app_languages (app_id, language_code, has_interface, has_full_audio, has_subtitles) VALUES
    (4,'bg',TRUE,FALSE,TRUE),(4,'de',TRUE,TRUE,TRUE),(4,'fr',TRUE,TRUE,TRUE),(4,'pl',TRUE,TRUE,TRUE),(4,'ru',TRUE,TRUE,TRUE),
    (6,'de',TRUE,FALSE,TRUE),(6,'fr',TRUE,FALSE,TRUE),(6,'ja',TRUE,TRUE,TRUE),(6,'es',TRUE,FALSE,TRUE),
    (11,'de',TRUE,FALSE,TRUE),(11,'fr',TRUE,FALSE,TRUE),(11,'es',TRUE,FALSE,TRUE),(11,'pl',TRUE,FALSE,TRUE),(11,'zh-CN',TRUE,FALSE,TRUE),
    (10,'de',TRUE,FALSE,FALSE),(10,'fr',TRUE,FALSE,FALSE),(10,'ja',TRUE,FALSE,FALSE),
    (2,'bg',TRUE,FALSE,TRUE),(2,'ru',TRUE,TRUE,TRUE);
INSERT INTO app_languages (app_id, language_code, has_interface, has_full_audio, has_subtitles)
SELECT app_id, 'en', TRUE, app_type <> 'soundtrack', app_type <> 'soundtrack' FROM apps;

INSERT INTO system_requirements (app_id, platform_id, tier, os, processor, memory_mb, graphics, storage_mb) VALUES
    (4, 1, 'minimum',     'Windows 10 64-bit', 'Intel Core i5-2500K 3.3 GHz',  6144,  'NVIDIA GeForce GTX 660',  50000),
    (4, 1, 'recommended', 'Windows 10 64-bit', 'Intel Core i7-3770 3.4 GHz',   8192,  'NVIDIA GeForce GTX 770',  50000),
    (6, 1, 'minimum',     'Windows 10',        'Intel Core i5-8400',           12288, 'NVIDIA GeForce GTX 1060', 60000),
    (6, 1, 'recommended', 'Windows 10/11',     'Intel Core i7-8700K',          16384, 'NVIDIA GeForce GTX 1070', 60000),
    (11,1, 'minimum',     'Windows 10 64-bit', 'Intel i5-4690',                8192,  'NVIDIA GTX 970',          150000),
    (11,1, 'recommended', 'Windows 10 64-bit', 'Intel i7-8700K',               16384, 'NVIDIA RTX 2060 Super',   150000);

INSERT INTO app_media (app_id, media_type, url, sort_order)
SELECT app_id, 'header', 'https://cdn.example.com/apps/' || app_id || '/header.jpg', 0 FROM apps;
INSERT INTO app_media (app_id, media_type, url, sort_order)
SELECT a.app_id, 'screenshot', 'https://cdn.example.com/apps/' || a.app_id || '/shot_' || n || '.jpg', n
  FROM apps a CROSS JOIN generate_series(1, 3) AS n WHERE a.app_id IN (4, 6, 7, 8, 11);
INSERT INTO app_media (app_id, media_type, url, sort_order) VALUES
    (6,  'trailer', 'https://cdn.example.com/apps/6/trailer.mp4',  0),
    (11, 'trailer', 'https://cdn.example.com/apps/11/trailer.mp4', 0);

-- list prices (valid since launch); USD is the base, other currencies are derived x.99 prices
INSERT INTO app_prices (app_id, currency_code, price_minor, valid_from)
SELECT b.app_id, c.code, (round(b.usd * c.factor / 100.0) * 100 - 1)::bigint, '2025-01-01 00:00+00'
  FROM (VALUES (3, 999), (4, 3999), (5, 1999), (6, 5999), (7, 2499), (8, 1499),
               (9, 999), (10, 1499), (11, 5999), (12, 5999), (13, 999)) AS b(app_id, usd)
 CROSS JOIN (VALUES ('USD', 1.00), ('EUR', 0.92), ('BGN', 1.80), ('GBP', 0.80)) AS c(code, factor);

-- a price history example: Hollow Knight used to cost 1999 USD
UPDATE app_prices SET valid_from = '2025-06-01 00:00+00' WHERE app_id = 8 AND currency_code = 'USD';
INSERT INTO app_prices (app_id, currency_code, price_minor, valid_from, valid_to)
VALUES (8, 'USD', 1999, '2025-01-01 00:00+00', '2025-06-01 00:00+00');

INSERT INTO achievements (achievement_id, app_id, api_name, name, description, points, is_hidden) VALUES
    (1,  6,  'ACH_MALENIA',   'Elden Lord',          'Achieve the Elden Lord ending.',                50, FALSE),
    (2,  6,  'ACH_LIMGRAVE',  'Leave Limgrave',      'Reach Liurnia of the Lakes.',                   10, FALSE),
    (3,  6,  'ACH_SECRET',    'The Secret',          'Find what hides beneath the roots.',            25, TRUE),
    (4,  8,  'ACH_FIRST_BOSS','False Knight',        'Defeat the False Knight.',                      10, FALSE),
    (5,  8,  'ACH_MAP',       'Cartographer',        'Buy all the maps.',                             15, FALSE),
    (6,  8,  'ACH_RADIANCE',  'The Radiance',        'Reach the true ending.',                        50, TRUE),
    (7,  7,  'ACH_ESCAPE',    'Escaped',             'Escape the Underworld for the first time.',     20, FALSE),
    (8,  7,  'ACH_HEAT',      'Max Heat',            'Escape with 32 Heat.',                          40, FALSE),
    (9,  7,  'ACH_GIFT',      'Gift Giver',          'Give 25 gifts of nectar.',                      15, FALSE),
    (10, 9,  'ACH_EYE',       'Eye of Cthulhu',      'Defeat the Eye of Cthulhu.',                    10, FALSE),
    (11, 9,  'ACH_MOON',      'Moon Lord',           'Defeat the Moon Lord.',                         50, FALSE),
    (12, 9,  'ACH_FISH',      'Anglers Delight',     'Complete 25 angler quests.',                    20, FALSE);

INSERT INTO bundles (bundle_id, name, description, discount_pct) VALUES
    (1, 'Valve Classics Bundle', 'Portal 2 and Half-Life: Alyx together.', 20),
    (2, 'Indie Gems Bundle',     'Hollow Knight, Terraria and Stardew Valley.', 15);
INSERT INTO bundle_apps (bundle_id, app_id) VALUES (1,3),(1,12),(2,8),(2,9),(2,10);

-- ---------------------------------------------------------------------------
-- sales
-- ---------------------------------------------------------------------------
INSERT INTO sales (sale_id, name, starts_at, ends_at) VALUES
    (1, 'Summer Sale 2026', '2026-06-25 17:00+00', '2026-07-09 17:00+00'),
    (2, 'Autumn Sale 2026', now() - interval '5 days', now() + interval '10 days');   -- always "current"
INSERT INTO sale_apps (sale_id, app_id, discount_pct) VALUES
    (1, 4, 80), (1, 5, 50), (1, 6, 25), (1, 8, 40),
    (2, 4, 70), (2, 7, 30), (2, 8, 50), (2, 9, 60), (2, 6, 20), (2, 10, 25);

-- ---------------------------------------------------------------------------
-- payment methods and starting wallet balances
-- ---------------------------------------------------------------------------
INSERT INTO payment_methods (payment_method_id, user_id, provider, provider_token, label, card_last4, expires_month, expires_year, is_default) VALUES
    (1, 1, 'card',   'tok_demo_alice',   'Visa ending 4242',       '4242', 8,  2028, TRUE),
    (2, 2, 'paypal', 'tok_demo_bob',     'bob@example.com (PayPal)', NULL, NULL, NULL, TRUE),
    (3, 3, 'card',   'tok_demo_charlie', 'Mastercard ending 1881', '1881', 11, 2027, TRUE),
    (4, 4, 'card',   'tok_demo_diana',   'Visa ending 9012',       '9012', 3,  2029, TRUE),
    (5, 5, 'paypal', 'tok_demo_eve',     'eve@example.com (PayPal)', NULL, NULL, NULL, TRUE),
    (6, 8, 'card',   'tok_demo_heidi',   'Maestro ending 3344',    '3344', 1,  2027, TRUE);

INSERT INTO wallet_transactions (user_id, txn_type, amount_minor, currency_code, note, created_at) VALUES
    (1, 'topup',  5000, 'USD', 'Initial top-up', '2025-10-01 10:00+00'),
    (2, 'topup',  3000, 'BGN', 'Initial top-up', '2025-10-01 10:00+00'),
    (3, 'topup',  4000, 'EUR', 'Initial top-up', '2025-10-01 10:00+00'),
    (4, 'topup',  5000, 'EUR', 'Initial top-up', '2025-10-01 10:00+00'),
    (5, 'topup',  2500, 'GBP', 'Initial top-up', '2025-10-01 10:00+00'),
    (6, 'topup',  2000, 'EUR', 'Initial top-up', '2025-10-01 10:00+00'),
    (7, 'topup',  3000, 'USD', 'Initial top-up', '2025-10-01 10:00+00'),
    (8, 'topup',  1000, 'BGN', 'Initial top-up', '2025-10-01 10:00+00');

-- ---------------------------------------------------------------------------
-- historical orders, paid by card/PayPal (created pending -> items -> completed)
-- ---------------------------------------------------------------------------
INSERT INTO orders (order_id, user_id, gift_recipient_id, currency_code, payment_method_id, created_at) VALUES
    (1, 1, NULL, 'USD', 1, '2025-11-02 18:30+00'),
    (2, 2, NULL, 'BGN', 2, '2025-12-20 09:15+00'),
    (3, 3, NULL, 'EUR', 3, '2026-01-15 20:45+00'),
    (4, 4, NULL, 'EUR', 4, '2026-02-10 16:00+00'),
    (5, 5, 6,    'GBP', 5, '2026-03-01 12:00+00'),    -- Eve gifts Hades to Frank
    (6, 8, NULL, 'BGN', 6, '2026-06-25 19:30+00');    -- Summer Sale

INSERT INTO order_items (order_id, app_id, list_price_minor, discount_pct, final_price_minor)
SELECT v.order_id, v.app_id, p.price_minor, v.pct, round(p.price_minor * (100 - v.pct) / 100.0)
  FROM (VALUES (1, 6, 0), (1, 4, 0),
               (2, 8, 0), (2, 9, 0), (2, 10, 0),
               (3, 11, 0), (3, 7, 10),
               (4, 3, 0), (4, 12, 0),
               (5, 7, 0),
               (6, 4, 80)) AS v(order_id, app_id, pct)
  JOIN orders o     ON o.order_id = v.order_id
  JOIN app_prices p ON p.app_id = v.app_id AND p.currency_code = o.currency_code AND p.valid_to IS NULL;

UPDATE orders o
   SET subtotal_minor = s.sub,
       discount_minor = s.disc,
       total_minor    = s.sub - s.disc
  FROM (SELECT order_id, sum(list_price_minor) AS sub, sum(list_price_minor - final_price_minor) AS disc
          FROM order_items GROUP BY order_id) s
 WHERE s.order_id = o.order_id;

UPDATE orders SET status = 'completed', completed_at = created_at + interval '1 minute';   -- grants library entries

-- ---------------------------------------------------------------------------
-- free games, keys, wallet codes
-- ---------------------------------------------------------------------------
DO $$ BEGIN
    PERFORM claim_free_app(u, a) FROM (VALUES (1,1), (1,2), (2,1), (3,1), (4,1), (7,1), (8,2)) AS t(u, a);
END $$;

INSERT INTO game_keys (app_id, key_code, company_id) VALUES
    (11, 'BG3AA-DEMO1-KEY01', 9),
    (11, 'BG3AA-DEMO1-KEY02', 9),
    (4,  'WTCH3-DEMO1-KEY01', 2),
    (6,  'ELDEN-DEMO1-KEY01', 4);

INSERT INTO wallet_codes (code, currency_code, amount_minor) VALUES
    ('DEMO-BGN-2000-0001', 'BGN', 2000),
    ('DEMO-USD-1000-0001', 'USD', 1000),
    ('DEMO-EUR-2500-0001', 'EUR', 2500);

-- ---------------------------------------------------------------------------
-- playtime (updates library totals through a trigger)
-- ---------------------------------------------------------------------------
INSERT INTO playtime_sessions (user_id, app_id, platform_id, started_at, ended_at) VALUES
    (1, 6, 1, '2025-11-03 20:00+00', '2025-11-03 23:30+00'),
    (1, 6, 1, '2025-11-05 19:00+00', '2025-11-05 22:15+00'),
    (1, 6, 1, '2025-11-09 14:00+00', '2025-11-09 19:00+00'),
    (1, 4, 1, '2025-12-01 18:00+00', '2025-12-01 21:00+00'),
    (1, 1, 1, '2025-11-10 21:00+00', '2025-11-10 22:30+00'),
    (2, 8, 4, '2025-12-22 19:00+00', '2025-12-22 22:00+00'),
    (2, 8, 4, '2025-12-27 13:00+00', '2025-12-27 17:30+00'),
    (2, 9, 3, '2025-12-23 10:00+00', '2025-12-23 15:00+00'),
    (2, 10,3, '2025-12-28 09:00+00', '2025-12-28 11:00+00'),
    (3, 11,1, '2026-01-16 18:00+00', '2026-01-16 23:59+00'),
    (3, 11,1, '2026-01-18 17:00+00', '2026-01-18 22:00+00'),
    (3, 7, 1, '2026-01-20 20:00+00', '2026-01-20 21:10+00'),
    (3, 1, 1, '2026-02-01 20:00+00', '2026-02-01 21:00+00'),
    (4, 3, 1, '2026-02-11 15:00+00', '2026-02-11 19:30+00'),
    (4, 12,1, '2026-02-14 20:00+00', '2026-02-14 23:00+00'),
    (6, 7, 4, '2026-03-02 21:00+00', '2026-03-02 23:00+00'),
    (6, 7, 4, '2026-03-05 21:00+00', '2026-03-05 22:30+00'),
    (8, 4, 1, '2026-06-26 18:00+00', '2026-06-26 22:00+00'),
    (8, 2, 1, '2026-05-10 20:00+00', '2026-05-10 22:00+00');

INSERT INTO user_achievements (user_id, achievement_id, unlocked_at) VALUES
    (1, 1, '2025-11-09 18:50+00'),
    (1, 2, '2025-11-04 21:00+00'),
    (2, 4, '2025-12-22 20:00+00'),
    (2, 5, '2025-12-27 15:00+00'),
    (2, 10,'2025-12-23 12:00+00'),
    (3, 7, '2026-01-20 20:45+00'),
    (6, 7, '2026-03-02 22:00+00'),
    (6, 9, '2026-03-05 22:00+00');

-- ---------------------------------------------------------------------------
-- reviews, votes, comments, discussions, workshop
-- ---------------------------------------------------------------------------
INSERT INTO reviews (review_id, user_id, app_id, is_recommended, body, created_at) VALUES
    (1,  1, 6,  TRUE,  'Punishing, beautiful and unforgettable. Bring a shield.',                  '2025-11-10 10:00+00'),
    (2,  1, 4,  TRUE,  'Side quests here are better than the main quest of most games.',           '2025-12-02 10:00+00'),
    (3,  2, 8,  TRUE,  'Tight controls and a world that begs to be explored.',                     '2025-12-28 10:00+00'),
    (4,  2, 9,  TRUE,  'Hundreds of hours and I still find new things.',                           '2025-12-30 10:00+00'),
    (5,  3, 11, TRUE,  'Every choice matters. Best RPG in years.',                                 '2026-01-19 10:00+00'),
    (6,  4, 3,  TRUE,  'Funny, clever and a perfect length.',                                      '2026-02-12 10:00+00'),
    (7,  4, 12, TRUE,  'The VR gold standard.',                                                    '2026-02-15 10:00+00'),
    (8,  6, 7,  TRUE,  'Just one more run... said me at 3 AM.',                                    '2026-03-06 10:00+00'),
    (9,  8, 4,  TRUE,  'Geralt is the best thing that happened to me this summer.',                '2026-06-27 10:00+00'),
    (10, 3, 7,  FALSE, 'Great game, but the meta-progression grind is not for me.',                '2026-01-21 10:00+00'),
    (11, 2, 10, TRUE,  'Relaxing, deep and endlessly charming.',                                   '2025-12-29 10:00+00');

INSERT INTO review_votes (review_id, user_id, vote) VALUES
    (1, 2, 'helpful'), (1, 3, 'helpful'), (1, 4, 'funny'),
    (3, 1, 'helpful'), (3, 6, 'helpful'),
    (5, 1, 'helpful'),
    (9, 1, 'helpful'),
    (10, 2, 'helpful'), (10, 4, 'not_helpful');

INSERT INTO review_comments (review_id, user_id, body, created_at) VALUES
    (1, 2, 'Agreed, the shield advice alone is worth the upvote.', '2025-11-11 09:00+00'),
    (10, 6, 'The grind is the point! (kind of)',                   '2026-01-22 09:00+00');

INSERT INTO discussion_threads (thread_id, app_id, author_id, title, is_pinned, created_at) VALUES
    (1, 6, 1, 'Best build for a first playthrough?', TRUE,  '2025-11-04 12:00+00'),
    (2, 8, 2, 'Hidden areas worth exploring',        FALSE, '2025-12-26 12:00+00'),
    (3, 11,3, 'Party composition for tactician mode',FALSE, '2026-01-17 12:00+00');
INSERT INTO discussion_posts (thread_id, author_id, body, created_at) VALUES
    (1, 1, 'I am about to start. Any advice on stats?',                    '2025-11-04 12:00+00'),
    (1, 2, 'Put points in Vigor early, everything else is optional.',      '2025-11-04 13:00+00'),
    (1, 3, 'Use spirit ashes liberally, they carry early bosses.',         '2025-11-04 14:30+00'),
    (2, 2, 'Check behind every breakable wall in Greenpath.',              '2025-12-26 12:00+00'),
    (3, 3, 'Gale or Shadowheart as the support? Opinions?',                '2026-01-17 12:00+00'),
    (3, 8, 'Shadowheart. Healing is never wasted.',                        '2026-01-17 12:20+00');

INSERT INTO workshop_items (item_id, app_id, author_id, title, description, file_url, created_at) VALUES
    (1, 9, 2, 'Better Minimap',   'A larger, clearer minimap overlay.',  'https://cdn.example.com/workshop/1.zip', '2026-01-10 10:00+00'),
    (2, 9, 2, 'Pixel Pets Pack',  'Twelve new cosmetic pets.',           'https://cdn.example.com/workshop/2.zip', '2026-02-20 10:00+00'),
    (3, 8, 3, 'Boss Rush Mode',   'Fight all bosses back to back.',      'https://cdn.example.com/workshop/3.zip', '2026-03-03 10:00+00');
INSERT INTO workshop_subscriptions (user_id, item_id) VALUES (1,1), (3,1), (7,1), (8,2), (2,3), (7,3);

-- wishlists and a cart that is still open
INSERT INTO wishlists (user_id, app_id, priority) VALUES
    (1, 11, 1), (1, 7, 2),
    (2, 6, 1),  (2, 11, 2),
    (3, 6, 1),
    (8, 6, 1),  (8, 11, 2);
INSERT INTO cart_items (user_id, app_id) VALUES (8, 6);

-- ---------------------------------------------------------------------------
-- inventory, trades and market
-- ---------------------------------------------------------------------------
INSERT INTO item_definitions (item_def_id, app_id, name, item_type, rarity, is_tradable, is_marketable) VALUES
    (1, 8, 'Hornet (Trading Card)',          'trading_card',       'rare',     TRUE, TRUE),
    (2, 8, 'Knight Emoticon',                'emoticon',           'common',   TRUE, TRUE),
    (3, 9, 'Terraria Guide (Trading Card)',  'trading_card',       'common',   TRUE, TRUE),
    (4, 7, 'Zagreus (Trading Card)',         'trading_card',       'uncommon', TRUE, TRUE),
    (5, 6, 'Erdtree Profile Background',     'profile_background', 'legendary',TRUE, TRUE);

INSERT INTO inventory_items (inventory_item_id, item_def_id, owner_id, acquired_via, acquired_at) VALUES
    (1, 1, 2, 'drop',  '2025-12-23 12:00+00'),
    (2, 2, 2, 'drop',  '2025-12-24 12:00+00'),
    (3, 3, 3, 'craft', '2026-02-01 12:00+00'),
    (4, 4, 6, 'drop',  '2026-03-03 12:00+00'),
    (5, 5, 1, 'drop',  '2025-11-06 12:00+00'),
    (6, 1, 8, 'gift',  '2026-06-30 12:00+00'),
    (7, 3, 3, 'drop',  '2026-02-05 12:00+00'),
    (8, 4, 4, 'drop',  '2026-02-20 12:00+00');

INSERT INTO trade_offers (trade_id, sender_id, receiver_id, message) VALUES
    (1, 2, 3, 'Hornet for your Terraria Guide?'),
    (2, 6, 4, 'Want to swap Zagreus cards?');
INSERT INTO trade_offer_items (trade_id, inventory_item_id) VALUES (1, 1), (1, 3), (2, 4), (2, 8);

INSERT INTO market_listings (listing_id, inventory_item_id, seller_id, currency_code, price_minor) VALUES
    (1, 5, 1, 'USD', 450),
    (2, 7, 3, 'EUR', 120),
    (3, 6, 8, 'BGN', 200);

-- ---------------------------------------------------------------------------
-- move identity sequences past the explicit ids used above
-- ---------------------------------------------------------------------------
DO $$
DECLARE
    r record;
BEGIN
    FOR r IN SELECT table_name, column_name
               FROM information_schema.columns
              WHERE table_schema = 'steam' AND is_identity = 'YES'
    LOOP
        EXECUTE format(
            'SELECT setval(pg_get_serial_sequence(%L, %L), COALESCE((SELECT max(%I) FROM steam.%I), 0) + 1, false)',
            'steam.' || r.table_name, r.column_name, r.column_name, r.table_name);
    END LOOP;
END $$;

-- ---------------------------------------------------------------------------
-- live flows that exercise the stored functions
-- ---------------------------------------------------------------------------
-- Diana pays for two games from her wallet during the Autumn Sale.
INSERT INTO cart_items (user_id, app_id) VALUES (4, 7), (4, 8);
DO $$ BEGIN PERFORM checkout_cart(4, TRUE); END $$;

-- Grace buys two games, then refunds one of them (no playtime, within 14 days).
INSERT INTO cart_items (user_id, app_id) VALUES (7, 9), (7, 10);
DO $$ BEGIN PERFORM checkout_cart(7, TRUE); END $$;

INSERT INTO refunds (order_item_id, user_id, reason)
SELECT oi.order_item_id, 7, 'Bought it by mistake'
  FROM order_items oi JOIN orders o ON o.order_id = oi.order_id
 WHERE o.user_id = 7 AND oi.app_id = 9;
UPDATE refunds SET status = 'approved'
 WHERE order_item_id = (SELECT oi.order_item_id FROM order_items oi JOIN orders o ON o.order_id = oi.order_id
                         WHERE o.user_id = 7 AND oi.app_id = 9);

-- Heidi redeems a wallet code and a game key.
DO $$ BEGIN PERFORM redeem_wallet_code(8, 'DEMO-BGN-2000-0001'); END $$;
DO $$ BEGIN PERFORM redeem_game_key(8, 'BG3AA-DEMO1-KEY01'); END $$;

-- Charlie accepts Bob's trade offer; Diana buys Charlie's market listing.
DO $$ BEGIN PERFORM accept_trade_offer(1, 3); END $$;
DO $$ BEGIN PERFORM purchase_market_listing(2, 4); END $$;
