# Schema Design - Keep It Simple

**What This Is:** You're building a real-time crypto price tracker. This doc shows you what tables to create and why. No fluff.

## The Three Layers (Medallion Architecture)

Think of it like cooking:
- **Bronze:** Raw ingredients (data exactly as you got it)
- **Silver:** Prepped ingredients (cleaned, chopped, ready to cook)
- **Gold:** The finished dish (ready to serve)

---

## Bronze Layer - Just Store Everything

**What's the point?** Keep the raw JSON from Kafka. If something goes wrong later, you can always replay from here.

### Table: `bronze.crypto_ticks_raw`

This is what you already created in Phase 2:

```sql
CREATE TABLE bronze.crypto_ticks_raw (
    raw_payload STRING,              -- The complete JSON message from Kafka
    ingestion_timestamp TIMESTAMP,   -- When you wrote it to Iceberg
    kafka_offset BIGINT,             -- Kafka offset (for exactly-once processing)
    kafka_partition INT              -- Which Kafka partition
)
USING iceberg
PARTITIONED BY (days(ingestion_timestamp))
```

**Why this design?**
- `raw_payload` as STRING → You can store anything, even broken JSON
- `kafka_offset` → If Spark crashes, you know where to resume
- Partitioned by day → Easy to delete old data (just drop old partitions)

**What goes in here?** Everything. Good data, bad data, duplicates. You clean it up later in Silver.

---

## Silver Layer - Make It Clean

**What's the point?** Parse the JSON, validate it, remove duplicates. This is where data becomes useful.

### Table: `silver.crypto_prices_clean`

This is also from Phase 2:

```sql
CREATE TABLE silver.crypto_prices_clean (
    crypto_symbol STRING,             -- 'bitcoin', 'ethereum'
    price_usd DECIMAL(18, 8),        -- Price with 8 decimal places
    volume_24h DECIMAL(20, 2),       -- 24-hour trading volume
    percent_change_24h DECIMAL(10, 4),-- Percent change
    api_timestamp TIMESTAMP,          -- When CoinGecko recorded this price
    processing_timestamp TIMESTAMP    -- When you processed it
)
USING iceberg
PARTITIONED BY (days(api_timestamp))
```

**What's happening here?**
1. Parse the JSON from `raw_payload`
2. Split one message (10 cryptos) into 10 rows
3. Remove duplicates (keep latest price per minute)
4. Validate: price > 0, timestamp makes sense

**Simple transformation:**
```python
# Read Bronze
bronze_df = spark.table("bronze.crypto_ticks_raw")

# Parse JSON and explode (1 message → 10 rows)
from pyspark.sql.functions import from_json, explode, col

silver_df = bronze_df \
    .select(from_json(col("raw_payload"), schema).alias("data")) \
    .select(explode("data").alias("crypto_symbol", "price_data")) \
    .select(
        col("crypto_symbol"),
        col("price_data.usd").alias("price_usd"),
        col("price_data.usd_24h_vol").alias("volume_24h"),
        col("price_data.usd_24h_change").alias("percent_change_24h"),
        # ... timestamps
    ) \
    .filter(col("price_usd") > 0)  # Basic validation

# Write to Silver
silver_df.write.format("iceberg").mode("append").save("silver.crypto_prices_clean")
```

---

## Gold Layer - Make It Fast

**What's the point?** Dashboards and analysts shouldn't scan millions of rows. Pre-aggregate the data.

### Table: `gold.crypto_hourly_ohlc`

**OHLC = Open, High, Low, Close** (standard format for price charts)

```sql
CREATE TABLE gold.crypto_hourly_ohlc (
    crypto_symbol STRING,
    hour_start TIMESTAMP,            -- Start of the hour (e.g., 2024-12-04 14:00:00)
    
    -- Price stats for this hour
    open_price DECIMAL(18, 8),       -- First price in the hour
    high_price DECIMAL(18, 8),       -- Highest price
    low_price DECIMAL(18, 8),        -- Lowest price
    close_price DECIMAL(18, 8),      -- Last price
    avg_price DECIMAL(18, 8),        -- Average
    
    -- Volume
    total_volume DECIMAL(20, 2),     -- Sum of volumes
    tick_count INT                   -- How many data points in this hour
)
USING iceberg
PARTITIONED BY (days(hour_start))
```

**How to populate:**
```sql
INSERT INTO gold.crypto_hourly_ohlc
SELECT 
    crypto_symbol,
    date_trunc('hour', api_timestamp) as hour_start,
    first(price_usd) as open_price,      -- First price
    max(price_usd) as high_price,        -- Max
    min(price_usd) as low_price,         -- Min
    last(price_usd) as close_price,      -- Last price
    avg(price_usd) as avg_price,
    sum(volume_24h) as total_volume,
    count(*) as tick_count
FROM silver.crypto_prices_clean
WHERE api_timestamp >= '2024-12-04 00:00:00'  -- Only process new data
GROUP BY crypto_symbol, date_trunc('hour', api_timestamp)
```

**Why hourly?**
- Real-time: Query `silver.crypto_prices_clean` (every 30 seconds)
- Historical charts: Query `gold.crypto_hourly_ohlc` (much faster)

---

## What You Actually Need Right Now

For the tutorial, focus on **Bronze and Silver only**. Gold is for later when you have enough data.

**Your immediate todo:**
1.  Bronze table (done in Phase 2)
2.  Silver table (done in Phase 2)
3. Phase 3: Stream Kafka → Bronze
4. Phase 4: Transform Bronze → Silver (batch job)
5. Later: Aggregate Silver → Gold (when you have days of data)

---

## Data Flow Summary

```
CoinGecko API (every 30s)
    ↓
Kafka Topic: crypto.prices.raw
    ↓
Bronze: Raw JSON (append-only, never delete)
    ↓
Silver: Parsed, validated (deduplicated)
    ↓
Gold: Hourly aggregates (for fast dashboards)
```

**How long to keep data?**
- Bronze: 30 days (audit trail)
- Silver: Forever (it's clean and useful)
- Gold: Forever (it's tiny - only hourly summaries)

---

## Next Steps

Go back to the main README and continue Phase 3 (streaming from Kafka to Bronze).

You don't need Gold tables yet. Build them when you're ready to create dashboards.

**Description:** Grain = One row per cryptocurrency per hour (OHLC format).

**Schema:**
```sql
CREATE TABLE gold.fact_crypto_hourly (
    hourly_id BIGINT,                -- Surrogate key
    crypto_id INT,                   -- FK to dim_crypto
    time_id BIGINT,                  -- FK to dim_time (hour level)
    
    -- OHLC Measures
    open_price DECIMAL(18, 8),       -- First price in the hour
    high_price DECIMAL(18, 8),       -- Max price in the hour
    low_price DECIMAL(18, 8),        -- Min price in the hour
    close_price DECIMAL(18, 8),      -- Last price in the hour
    
    -- Aggregates
    avg_price DECIMAL(18, 8),
    total_volume DECIMAL(20, 2),
    tick_count INT,                  -- How many ticks in this hour
    
    -- Metadata
    hour_start TIMESTAMP,
    hour_end TIMESTAMP
)
PARTITIONED BY (days(hour_start))
```

**Aggregation Logic:**
```sql
SELECT 
    crypto_id,
    date_trunc('hour', last_updated) as hour_start,
    FIRST(price_usd) as open_price,
    MAX(price_usd) as high_price,
    MIN(price_usd) as low_price,
    LAST(price_usd) as close_price,
    AVG(price_usd) as avg_price,
    SUM(volume_24h) as total_volume,
    COUNT(*) as tick_count
FROM gold.fact_crypto_ticks
GROUP BY crypto_id, date_trunc('hour', last_updated)
```

---

### Dimension Table: `gold.dim_crypto`

**Description:** Slowly Changing Dimension (SCD Type 2) tracking cryptocurrency attributes.

**Schema:**
```sql
CREATE TABLE gold.dim_crypto (
    crypto_id INT,                   -- Surrogate key
    crypto_symbol STRING,            -- Business key: 'bitcoin'
    crypto_name STRING,              -- Display name: 'Bitcoin'
    category STRING,                 -- 'layer-1', 'defi', 'meme'
    market_cap_rank INT,             -- Ranking by market cap
    
    -- SCD Type 2 Tracking
    valid_from TIMESTAMP,            -- When this version became active
    valid_to TIMESTAMP,              -- When it was superseded (NULL = current)
    is_current BOOLEAN,              -- TRUE for active version
    
    -- Metadata
    first_seen_date DATE,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
)
```

**SCD Type 2 Example:**
```
crypto_id | symbol    | name      | market_cap_rank | valid_from          | valid_to            | is_current
----------|-----------|-----------|-----------------|---------------------|---------------------|------------
1         | bitcoin   | Bitcoin   | 1               | 2024-01-01 00:00:00 | 2024-03-15 10:30:00 | FALSE
1         | bitcoin   | Bitcoin   | 2               | 2024-03-15 10:30:00 | NULL                | TRUE
```

**Why SCD Type 2:**
- If Bitcoin drops to #2 by market cap, we need to know it *was* #1 historically
- Enables "What was the top crypto by market cap on Jan 1?" queries

---

### Dimension Table: `gold.dim_time`

**Description:** Pre-populated time dimension for fast joins.

**Schema:**
```sql
CREATE TABLE gold.dim_time (
    time_id BIGINT,                  -- Surrogate key (epoch seconds)
    timestamp TIMESTAMP,             -- Actual timestamp
    
    -- Time Hierarchies
    minute INT,                      -- 0-59
    hour INT,                        -- 0-23
    day INT,                         -- 1-31
    month INT,                       -- 1-12
    quarter INT,                     -- 1-4
    year INT,                        -- 2024
    day_of_week INT,                 -- 1=Monday, 7=Sunday
    day_of_year INT,                 -- 1-366
    
    -- Business Attributes
    is_weekend BOOLEAN,
    is_holiday BOOLEAN,
    is_trading_hour BOOLEAN,         -- Crypto trades 24/7, but useful for stocks later
    
    -- Formatted Strings
    date_string STRING,              -- '2024-01-15'
    time_string STRING,              -- '14:30:00'
    datetime_string STRING           -- '2024-01-15 14:30:00'
)
```

**Population:**
```python
# Pre-populate for 2024-2030, minute-level granularity
import pandas as pd
date_range = pd.date_range('2024-01-01', '2030-12-31', freq='1min')
# Convert to DataFrame and write to Iceberg
```

---

## Data Flow Summary

```
┌─────────────────────────────────────────────────────────────────┐
│                      CoinGecko API                              │
│  GET /simple/price?ids=bitcoin,ethereum&vs_currencies=usd       │
└─────────────────────┬───────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│              Kafka Topic: crypto.prices.raw                     │
│  { "bitcoin": {"usd": 45000.23}, "timestamp": 1234567890 }      │
└─────────────────────┬───────────────────────────────────────────┘
                      │
                      ▼ (Spark Structured Streaming)
┌─────────────────────────────────────────────────────────────────┐
│           Bronze: crypto_ticks_raw (append-only)                │
│  raw_payload | ingestion_timestamp | source_system              │
└─────────────────────┬───────────────────────────────────────────┘
                      │
                      ▼ (dbt incremental model)
┌─────────────────────────────────────────────────────────────────┐
│         Silver: crypto_prices_clean (deduplicated)              │
│  symbol | price_usd | volume_24h | last_updated                 │
└─────────────────────┬───────────────────────────────────────────┘
                      │
          ┌───────────┼───────────────┐
          ▼           ▼               ▼
    ┌─────────┐  ┌─────────┐  ┌────────────┐
    │  Gold:  │  │  Gold:  │  │   Gold:    │
    │  fact_  │  │  fact_  │  │ dim_crypto │
    │  ticks  │  │ hourly  │  │  (SCD-2)   │
    └─────────┘  └─────────┘  └────────────┘
```

---

## Query Examples (What We Can Answer)

### 1. Current Price
```sql
SELECT c.crypto_name, f.price_usd, f.last_updated
FROM gold.fact_crypto_ticks f
JOIN gold.dim_crypto c ON f.crypto_id = c.crypto_id
WHERE c.is_current = TRUE
  AND f.last_updated = (SELECT MAX(last_updated) FROM gold.fact_crypto_ticks)
```

### 2. Hourly Chart (Last 24 hours)
```sql
SELECT 
    c.crypto_name,
    h.hour_start,
    h.open_price,
    h.high_price,
    h.low_price,
    h.close_price
FROM gold.fact_crypto_hourly h
JOIN gold.dim_crypto c ON h.crypto_id = c.crypto_id
WHERE c.crypto_symbol = 'bitcoin'
  AND h.hour_start >= current_timestamp - INTERVAL 24 HOURS
ORDER BY h.hour_start
```

### 3. Time Travel (Price 2 hours ago)
```sql
SELECT c.crypto_name, f.price_usd, f.last_updated
FROM gold.fact_crypto_ticks FOR SYSTEM_TIME AS OF current_timestamp - INTERVAL 2 HOURS f
JOIN gold.dim_crypto c ON f.crypto_id = c.crypto_id
WHERE c.crypto_symbol = 'ethereum'
  AND f.last_updated <= current_timestamp - INTERVAL 2 HOURS
ORDER BY f.last_updated DESC
LIMIT 1
```

---

## Next Steps

1. Review this schema design
2. Create the tables in your lakehouse (we'll do this in Phase 2)
3. Move to [dimensional-model.md](dimensional-model.md) for ERD diagrams
