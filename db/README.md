# Steam-style database (PostgreSQL)

A database-only model of a Steam-like platform: accounts and friends, store catalog with regional
prices and sales, cart and checkout, Steam wallet, refunds, library and playtime, achievements,
reviews, discussions, workshop, inventory, trading, and the community market.

Requires **PostgreSQL 14+** with the standard `citext`, `pg_trgm` and `btree_gist` extensions
(included with normal PostgreSQL installs).

## Load

```bash
cd db
createdb steam_db
psql -d steam_db -f 00_init.sql        # schema + sample data + roles
psql -d steam_db -f sample_queries.sql # optional: example queries
psql -d steam_db -f 99_drop.sql        # remove everything (then run 00_init.sql again)
```

`00_init.sql` also sets the database default `search_path` to `steam, public`, so new
connections can write `SELECT * FROM apps` without the schema prefix.

## Files

| File | Contents |
|---|---|
| `00_init.sql` | Entry point, runs everything below in order |
| `01_types.sql` | Extensions and enum types |
| `02_reference.sql` | Currencies, countries, languages, platforms, genres, tags |
| `03_accounts.sql` | Users, profiles, wallets, sessions, bans, friends, blocks, chat, groups |
| `04_catalog.sql` | Companies, apps (games/DLC/soundtracks...), metadata, price history, achievements, bundles |
| `05_store.sql` | Sales, wishlist, cart, payment methods, orders, wallet ledger, wallet codes, game keys, refunds |
| `06_library.sql` | Library, playtime sessions, unlocked achievements |
| `07_community.sql` | Reviews, votes, comments, discussions, notifications, workshop |
| `08_inventory_market.sql` | Item definitions, inventory, trade offers, market listings |
| `09_indexes.sql` | Secondary indexes |
| `10_functions_triggers.sql` | Business rules (triggers) and the stored-function API |
| `11_views.sql` | Reporting views |
| `12_seed.sql` | Fictional sample data that exercises every feature |
| `13_roles.sql` | `steam_app` and `steam_readonly` roles with least privilege |
| `sample_queries.sql` | 15 example read-only queries |
| `99_drop.sql` | Drops the `steam` schema |

## Conventions

- Money is always an integer in the currency's **minor unit** (cents); see `currencies.minor_units`.
- Timestamps are `timestamptz`.
- Users are never hard-deleted while they have orders; set `users.status = 'deleted'` instead.
- Counters such as `apps.positive_reviews` and `reviews.votes_helpful` are maintained by triggers.
  `refresh_app_review_counts(app_id)` recounts one app if they ever need repairing.

## Stored functions

| Function | What it does |
|---|---|
| `checkout_cart(user, use_wallet, payment_method, gift_recipient)` | Turns the cart into a completed order at today's sale prices; returns `order_id` |
| `claim_free_app(user, app)` | Adds a free-to-play game to the library |
| `redeem_game_key(user, key)` | Activates a product key |
| `redeem_wallet_code(user, code)` | Adds a gift code's value to the wallet |
| `set_app_price(app, currency, price)` | Changes a list price while keeping price history |
| `accept_trade_offer(trade, user)` | Swaps the items of a trade offer |
| `purchase_market_listing(listing, buyer)` | Buys a market item with wallet funds (15% seller fee) |
| `is_refund_eligible(order_item)` | 14 days / under 2 hours rule |
| `has_active_ban(user, ban_types[])` | Ban check used by trading and the market |

## Rules enforced by the database

- **Wallet**: balance can never go negative; every change goes through the append-only
  `wallet_transactions` ledger, which records the balance after each entry.
- **Orders**: `pending -> completed | failed | cancelled`, then `-> partially_refunded | refunded`.
  An order completes only if its totals match its items; after that its items are frozen and it
  cannot be deleted. Completing an order adds the games to the buyer's or the gift recipient's library.
- **Checkout**: rejects banned/suspended buyers, gifts to banned/deleted users, delisted or free
  apps, games already owned, and apps without a price in the wallet currency.
- **Refunds**: only the purchaser, only within 14 days and under 2 hours of playtime, never more
  than was paid; `pending -> approved | denied` is final. A denied request can be filed again.
  Approval removes the game from the library and refunds to the wallet.
- **Prices**: price periods for the same app and currency can never overlap.
- **Reviews**: only owners can review; playtime at review time is snapshotted; no voting on your own review.
- **Achievements**: only for games the user owns. **Playtime** sessions are append-only.
- **Friends**: no requests between users who blocked each other or who are already friends;
  blocking ends an existing friendship. Groups always have exactly one owner, who is a member.
- **Trading & market**: items must belong to one of the traders and be tradable/marketable;
  trade/market bans are respected; listings must be in the seller's wallet currency; accepting a
  trade or selling an item cancels other offers and listings that contain the same item.
- **Concurrency**: functions lock the wallet, listing or trade first and then the items, so
  concurrent double-spends, double sales and double refunds are rejected.
- **Security**: passwords and session tokens are stored only as hashes; payment methods store a
  provider token, never card numbers. Every function pins its `search_path`.

## Known trade-offs

- Wallets hold a single currency; buying a market item listed in another currency is rejected
  rather than converted.
- Refunds always go back to the Steam wallet (not to the original card).
- Review and vote counters live on the `apps` / `reviews` rows, so very popular apps get a hot row
  under heavy concurrent reviewing. Fine at this scale; a sharded counter table is the next step.
- Sample data uses fixed 2025–2026 dates for history; the "Autumn Sale" and the refunded purchase
  are relative to `now()` so they behave the same whenever you load the seed.
