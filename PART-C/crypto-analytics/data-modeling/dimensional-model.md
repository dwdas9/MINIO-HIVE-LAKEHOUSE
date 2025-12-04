# Dimensional Model - Star Schema (For Later)

**What This Is:** Advanced data modeling stuff. You don't need this for the tutorial. Skip this file unless you want to build proper data warehouse features.

## Why You'd Use Star Schema

**Your current approach (simple tables):**
- Bronze, Silver, Gold tables
- Works great for basic queries
- Easy to understand

**Star schema approach (enterprise):**
- Fact tables (measurements) + Dimension tables (who/what/when/where)
- Faster for complex analytics
- Standard in BI tools like Tableau, Power BI

**When to switch?** When you're building dashboards for other people and need blazing-fast queries.

---

## Star Schema Design (Future State)

```
                    ┌──────────────┐
                    │  dim_crypto  │
                    │              │
                    │ - symbol     │
                    │ - name       │
                    │ - category   │
                    └──────┬───────┘
                           │
                           │ 1:N
                           │
            ┌──────────────▼──────────────────┐
            │     fact_crypto_prices          │
            │                                  │
            │ - price_usd                      │
            │ - volume_24h                     │
            │ - percent_change_24h             │
            │ - timestamp                      │
            └──────────────┬──────────────────┘
                           │
                           │ N:1
                           │
                    ┌──────▼───────┐
                    │   dim_time   │
                    │              │
                    │ - hour       │
                    │ - day        │
                    │ - month      │
                    │ - is_weekend │
                    └──────────────┘
```

**Translation:**
- `fact_crypto_prices` = Your measurements (price, volume)
- `dim_crypto` = Info about each coin (bitcoin, ethereum)
- `dim_time` = Date/time attributes (hour, day, weekend flag)

**Why separate tables?**
- If Bitcoin's name changes, you update `dim_crypto` once (not millions of fact rows)
- Time attributes (is_weekend, is_holiday) are pre-calculated
- Joins are fast because dimensions are small

---

## What You'd Build (Eventually)

### Fact Table: `gold.fact_crypto_prices`

```sql
CREATE TABLE gold.fact_crypto_prices (
    price_id BIGINT,                 -- Unique ID for this row
    crypto_id INT,                   -- Links to dim_crypto
    time_id BIGINT,                  -- Links to dim_time
    
    -- The actual measurements
    price_usd DECIMAL(18, 8),
    volume_24h DECIMAL(20, 2),
    percent_change_24h DECIMAL(10, 4)
)
USING iceberg
PARTITIONED BY (days(time_id))
```

### Dimension Table: `gold.dim_crypto`

```sql
CREATE TABLE gold.dim_crypto (
    crypto_id INT PRIMARY KEY,       -- Surrogate key
    crypto_symbol STRING,            -- 'bitcoin'
    crypto_name STRING,              -- 'Bitcoin'
    category STRING,                 -- 'layer-1', 'defi'
    created_date DATE
)
USING iceberg
```

### Dimension Table: `gold.dim_time`

```sql
CREATE TABLE gold.dim_time (
    time_id BIGINT PRIMARY KEY,      -- Unix timestamp
    timestamp TIMESTAMP,
    hour INT,
    day INT,
    month INT,
    year INT,
    is_weekend BOOLEAN,
    is_holiday BOOLEAN
)
USING iceberg
```

---

## Sample Queries

### Current Price (Without Star Schema)

```sql
-- Your current approach
SELECT crypto_symbol, price_usd, api_timestamp
FROM silver.crypto_prices_clean
WHERE api_timestamp = (SELECT MAX(api_timestamp) FROM silver.crypto_prices_clean)
```

### Current Price (With Star Schema)

```sql
-- Star schema approach
SELECT c.crypto_name, f.price_usd, t.timestamp
FROM gold.fact_crypto_prices f
JOIN gold.dim_crypto c ON f.crypto_id = c.crypto_id
JOIN gold.dim_time t ON f.time_id = t.time_id
WHERE t.timestamp = (SELECT MAX(timestamp) FROM gold.dim_time)
```

**Are they different?** Not really. Star schema shines when you have:
- Complex filters (e.g., "weekends only, exclude holidays")
- Many dimensions (e.g., user, location, product)
- BI tool queries (Tableau loves star schemas)

---

## Slowly Changing Dimensions (SCD Type 2)

**The problem:** Bitcoin is #1 by market cap today. Tomorrow, Ethereum might overtake it. How do you track history?

**Bad approach (overwrite):**
```sql
UPDATE dim_crypto 
SET market_cap_rank = 2 
WHERE crypto_symbol = 'bitcoin'
```

Now you lost the fact that Bitcoin *was* #1 yesterday.

**Good approach (SCD Type 2):**
```sql
-- Bitcoin was #1, now it's #2
crypto_id | symbol  | rank | valid_from          | valid_to            | is_current
----------|---------|------|---------------------|---------------------|------------
1         | bitcoin | 1    | 2024-01-01 00:00:00 | 2024-12-04 10:30:00 | FALSE
1         | bitcoin | 2    | 2024-12-04 10:30:00 | NULL                | TRUE
```

**How to query:**
```sql
-- Current state
SELECT * FROM dim_crypto WHERE is_current = TRUE

-- Historical state (Jan 1)
SELECT * FROM dim_crypto 
WHERE valid_from <= '2024-01-01' 
  AND (valid_to > '2024-01-01' OR valid_to IS NULL)
```

**Is this necessary for crypto prices?** Probably not. But if you're tracking:
- Market cap rankings
- Crypto categories (BTC moves from "currency" to "store of value")
- Exchange listings

Then yes, SCD Type 2 is useful.

---

## When to Actually Build This

**Don't build star schema if:**
- You're still learning
- Simple queries work fine
- You don't have a BI tool yet

**Do build star schema when:**
- Queries are slow (joining Silver tables takes 10+ seconds)
- You're connecting Tableau/Power BI
- Business users need to slice data by many dimensions

---

## Bottom Line

Forget this file for now. Build Bronze → Silver → Gold with simple tables first. Come back here when you need enterprise-grade analytics.

The tutorial in the main README is all you need to get started.

```
                    ┌──────────────────────────┐
                    │     dim_crypto (SCD-2)   │
                    ├──────────────────────────┤
                    │ PK: crypto_id            │
                    │     crypto_symbol (BK)   │
                    │     crypto_name          │
                    │     category             │
                    │     market_cap_rank      │
                    │     valid_from           │
                    │     valid_to             │
                    │     is_current           │
                    └────────┬─────────────────┘
                             │
                             │ 1:N
                             │
            ┌────────────────▼─────────────────────┐
            │      fact_crypto_ticks (Fact)        │
            ├──────────────────────────────────────┤
            │ PK: tick_id                          │
            │ FK: crypto_id ─────────┐             │
            │ FK: time_id ───────────┼────┐        │
            │                        │    │        │
            │ price_usd              │    │        │
            │ volume_24h             │    │        │
            │ market_cap             │    │        │
            │ percent_change_1h      │    │        │
            │ percent_change_24h     │    │        │
            │ data_quality_score     │    │        │
            │ last_updated           │    │        │
            └────────────────────────┼────┼────────┘
                                     │    │
                                     │    │ N:1
                                     │    │
                                     │    └────────────────────┐
                                     │                         │
                                     │                ┌────────▼─────────┐
                                     │                │    dim_time      │
                                     │                ├──────────────────┤
                                     │                │ PK: time_id      │
                                     │                │     timestamp    │
                                     │                │     hour         │
                                     │                │     day          │
                                     │                │     month        │
                                     │                │     year         │
                                     │                │     is_weekend   │
                                     │                └──────────────────┘
                                     │
                                     │
                                     │
            ┌────────────────────────┼────────────────────────┐
            │   fact_crypto_hourly (Aggregate Fact)          │
            ├────────────────────────────────────────────────┤
            │ PK: hourly_id                                  │
            │ FK: crypto_id ─────────────────────────┘       │
            │ FK: time_id ───────────────────────────────────┤
            │                                                 │
            │ open_price                                      │
            │ high_price                                      │
            │ low_price                                       │
            │ close_price                                     │
            │ avg_price                                       │
            │ total_volume                                    │
            │ tick_count                                      │
            │ hour_start                                      │
            └─────────────────────────────────────────────────┘
```

---

## Design Decisions

### 1. Why Two Fact Tables?

**`fact_crypto_ticks`:**
- **Grain:** One row per API response (every 30 seconds)
- **Use case:** Real-time dashboards, minute-level analysis
- **Size:** Grows quickly (millions of rows per day)

**`fact_crypto_hourly`:**
- **Grain:** One row per crypto per hour (OHLC)
- **Use case:** Historical charts, trend analysis
- **Size:** Manageable (24 rows per crypto per day)

**Why both?**
- Different query patterns need different granularity
- Hourly is pre-aggregated for speed (no need to scan millions of ticks)
- Follows the "Aggregate Fact Table" pattern in Kimball methodology

---

### 2. Why SCD Type 2 for `dim_crypto`?

**Problem:**
Bitcoin is currently #1 by market cap. Tomorrow, Ethereum might overtake it. How do we:
1. Show Bitcoin is currently #1?
2. Show Bitcoin *was* #1 on January 15, 2024?

**Solution: Slowly Changing Dimension Type 2**

**Example:**
```
crypto_id | symbol  | market_cap_rank | valid_from          | valid_to            | is_current
----------|---------|-----------------|---------------------|---------------------|------------
1         | bitcoin | 1               | 2024-01-01 00:00:00 | 2024-03-15 10:30:00 | FALSE
1         | bitcoin | 2               | 2024-03-15 10:30:00 | NULL                | TRUE
```

**How to Query:**

**Current State:**
```sql
SELECT * FROM dim_crypto WHERE is_current = TRUE
```

**Historical State:**
```sql
SELECT * FROM dim_crypto 
WHERE valid_from <= '2024-02-01' 
  AND (valid_to > '2024-02-01' OR valid_to IS NULL)
```

---

### 3. Why `dim_time` Instead of Just Using Timestamps?

**Without `dim_time`:**
```sql
-- Extract hour, day, month for every query
SELECT 
    EXTRACT(HOUR FROM last_updated) as hour,
    EXTRACT(DAY FROM last_updated) as day,
    COUNT(*)
FROM fact_crypto_ticks
GROUP BY EXTRACT(HOUR FROM last_updated), EXTRACT(DAY FROM last_updated)
```

**With `dim_time`:**
```sql
-- Pre-computed attributes, faster joins
SELECT 
    t.hour,
    t.day,
    COUNT(*)
FROM fact_crypto_ticks f
JOIN dim_time t ON f.time_id = t.time_id
GROUP BY t.hour, t.day
```

**Benefits:**
- Pre-computed hierarchies (hour → day → month → year)
- Business attributes (`is_weekend`, `is_holiday`)
- Faster GROUP BY operations
- Consistent date formatting

---

## Partitioning Strategy

### `fact_crypto_ticks`
```sql
PARTITIONED BY (days(last_updated))
```

**Why:**
- Most queries filter by date range ("last 24 hours", "last week")
- Iceberg can skip entire partitions
- Easy to drop old partitions for retention

**Example:**
```
warehouse/fact_crypto_ticks/
  ├── last_updated_day=2024-01-15/
  ├── last_updated_day=2024-01-16/
  └── last_updated_day=2024-01-17/
```

Query: `WHERE last_updated >= '2024-01-17'`
→ Iceberg only reads `last_updated_day=2024-01-17/` partition

---

### `fact_crypto_hourly`
```sql
PARTITIONED BY (days(hour_start))
```

**Why:**
- Hourly aggregates are queried by date range
- Much fewer files than `fact_crypto_ticks`

---

### Dimensions: No Partitioning

**Why:**
- Small tables (hundreds of rows)
- Fully scanned every time anyway
- Partitioning overhead > benefit

---

## Z-Ordering for Performance

Z-Ordering physically co-locates related data in the same files.

### `fact_crypto_ticks`
```sql
CALL local.system.rewrite_data_files(
    table => 'gold.fact_crypto_ticks',
    strategy => 'sort',
    sort_order => 'zorder(crypto_id, last_updated)'
)
```

**Why This Combination:**
- Most queries: `WHERE crypto_symbol = 'bitcoin' AND last_updated > '2024-01-15'`
- Z-Order groups all Bitcoin records together, sorted by time
- Iceberg skips 90%+ of files during read

**Without Z-Order:**
```
File1: BTC 10:00, ETH 10:05, BTC 10:10  ← Must read
File2: ETH 10:15, BTC 10:20, ETH 10:25  ← Must read
File3: BTC 10:30, ETH 10:35, BTC 10:40  ← Must read
```

**With Z-Order:**
```
File1: BTC 10:00, BTC 10:10, BTC 10:20, BTC 10:30  ← Must read
File2: ETH 10:05, ETH 10:15, ETH 10:25, ETH 10:35  ← Skip!
```

---

## Common Query Patterns

### 1. Real-Time Price (Latest Tick)
```sql
SELECT 
    c.crypto_name,
    f.price_usd,
    f.percent_change_24h,
    f.last_updated
FROM gold.fact_crypto_ticks f
JOIN gold.dim_crypto c ON f.crypto_id = c.crypto_id
WHERE c.is_current = TRUE
  AND f.last_updated = (SELECT MAX(last_updated) FROM gold.fact_crypto_ticks)
ORDER BY c.market_cap_rank
```

**Optimization:**
- Partition pruning on `last_updated`
- Z-Order helps GROUP BY crypto

---

### 2. Hourly OHLC Chart (Last 7 Days)
```sql
SELECT 
    c.crypto_name,
    t.datetime_string,
    h.open_price,
    h.high_price,
    h.low_price,
    h.close_price,
    h.total_volume
FROM gold.fact_crypto_hourly h
JOIN gold.dim_crypto c ON h.crypto_id = c.crypto_id
JOIN gold.dim_time t ON h.time_id = t.time_id
WHERE c.crypto_symbol = 'bitcoin'
  AND t.timestamp >= current_timestamp - INTERVAL 7 DAYS
ORDER BY t.timestamp
```

**Optimization:**
- Partition pruning on `hour_start`
- Pre-aggregated (no need to scan `fact_crypto_ticks`)
- `dim_time` join is fast (small dimension)

---

### 3. Top Movers (Highest % Change Today)
```sql
SELECT 
    c.crypto_name,
    f.price_usd,
    f.percent_change_24h,
    f.volume_24h
FROM gold.fact_crypto_ticks f
JOIN gold.dim_crypto c ON f.crypto_id = c.crypto_id
WHERE f.last_updated >= date_trunc('day', current_timestamp)
  AND c.is_current = TRUE
ORDER BY f.percent_change_24h DESC
LIMIT 10
```

---

### 4. Time Travel (Price 3 Hours Ago)
```sql
SELECT 
    c.crypto_name,
    f.price_usd,
    f.last_updated
FROM gold.fact_crypto_ticks 
    FOR SYSTEM_TIME AS OF current_timestamp - INTERVAL 3 HOURS f
JOIN gold.dim_crypto c ON f.crypto_id = c.crypto_id
WHERE c.crypto_symbol = 'ethereum'
  AND f.last_updated <= current_timestamp - INTERVAL 3 HOURS
ORDER BY f.last_updated DESC
LIMIT 1
```

**Iceberg Time Travel:**
- Queries the snapshot from 3 hours ago
- No need to filter deleted records
- Audit-friendly

---

## Data Volume Estimates

### `fact_crypto_ticks`
- API calls: Every 30 seconds
- Cryptos tracked: 50
- Records per day: 50 * (86400 / 30) = **144,000 rows/day**
- Storage per row: ~200 bytes
- Daily storage: **28 MB/day** (before compression)
- Annual storage: **10 GB/year**

### `fact_crypto_hourly`
- Records per day: 50 * 24 = **1,200 rows/day**
- Storage per row: ~150 bytes
- Daily storage: **180 KB/day**
- Annual storage: **66 MB/year**

### Dimensions
- `dim_crypto`: 50 rows (static-ish)
- `dim_time`: 3.15M rows (2024-2030, minute grain)

**Total Storage (1 year):** ~10 GB

---

## Next Steps

1. Review this dimensional model
2. Proceed to [Phase 2: Docker Setup](../docker-compose.yml)
3. Create the tables in Jupyter
