# PART-B: Real-Time Crypto Analytics

**← [Back to Main Repository](../README.md) | ⚠️ Prerequisites: [Complete PART-A first](../PART-A/README.md)**

This tutorial builds a **production-grade real-time analytics platform** that streams live cryptocurrency prices from public APIs into your lakehouse. You'll learn by doing-starting from data modeling and progressing to real-time streaming ingestion.

## What You'll Build

A streaming data pipeline that:
- Fetches live crypto prices from CoinGecko API every 30 seconds
- Streams data through Kafka into your lakehouse
- Stores raw data in Iceberg tables on MinIO
- Processes millions of records with Spark Structured Streaming
- Applies medallion architecture (Bronze/Silver/Gold layers)

## Architecture Overview

![](images/20251204182616.png)

**Network:** All services run on the `dasnet` Docker network created by PART-A. This lets them access MinIO and Hive Metastore from the core infrastructure.

---

## Quick Start

**✅ If you followed the [main README](../README.md), everything is already running!**

The main README Quick Start guide already:
- ✅ Started PART-A (MinIO, Hive, Spark)
- ✅ Started PART-B (Kafka, Producer)
- ✅ Configured all services

**Skip to [Verify Everything is Running](#verify-everything-is-running) below.**

---

### If You Started Directly in PART-B (Standalone Setup)

Only use this if you skipped the main README and want to set up PART-B independently.

**Step 1: Ensure PART-A is Running**

```bash
docker ps --filter "name=hive-minio" --filter "name=hive-metastore"
```

Both containers must be running. If not, go to [PART-A README](../PART-A/README.md) first.

**Step 2: Launch Kafka & Crypto Producer**

| OS         | Commands                                                                                  |
|------------|-------------------------------------------------------------------------------------------|
| Mac/Linux  | `cd PART-B`<br>`chmod +x setup.sh`<br>`./setup.sh`                                        |
| Windows    | `cd PART-B`<br>`Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass`<br>`./setup.ps1`|

---

## Verify Everything is Running

Check all containers are healthy:

```bash
docker ps | grep crypto
```

You should see:
- `crypto-zookeeper` - Running
- `crypto-kafka` - Running (healthy)
- `crypto-kafka-ui` - Running
- `crypto-producer` - Running

### Step 4: Access Services

| Service | URL | What You'll See |
|---------|-----|-----------------|
| Kafka UI | http://localhost:8080 | Topics, messages, consumer groups |
| Jupyter Notebook | http://localhost:8888 | From PART-A (for Spark queries) |

Open Kafka UI and look for the topic `crypto.prices.raw`. You should see messages flowing in every 30 seconds.

---

## Tutorial: Phase 1 - Understanding the Data

Before writing any code, let's understand what data we're working with.

### What Data Are We Getting?

The crypto producer fetches data from CoinGecko's free API and wraps it with metadata for tracking.

**API Call:**
```
GET https://api.coingecko.com/api/v3/simple/price
?ids=bitcoin,ethereum,binancecoin,cardano,solana,ripple,polkadot,dogecoin,avalanche-2,chainlink
&vs_currencies=usd
&include_market_cap=true
&include_24hr_vol=true
&include_24hr_change=true
&include_last_updated_at=true
```

**Actual Message Structure in Kafka:**
```json
{
  "status": "success",
  "data": {
    "bitcoin": {
      "usd": 92937,
      "usd_market_cap": 1855524642938.09,
      "usd_24h_vol": 91517389314.45,
      "usd_24h_change": 6.77,
      "last_updated_at": 1764758514
    },
    "ethereum": {
      "usd": 3055.99,
      "usd_market_cap": 369131919906.30,
      "usd_24h_vol": 30743268805.08,
      "usd_24h_change": 8.76,
      "last_updated_at": 1764758507
    }
  },
  "api_call_timestamp": "2025-12-03T10:42:30.109530",
  "http_status_code": 200,
  "source_system": "coingecko_v3",
  "api_endpoint": "/simple/price",
  "ingestion_timestamp": "2025-12-03T10:42:30.110290"
}
```

**Message Structure Explained:**

| Field | Purpose |
|-------|---------|
| `status` | API call success/failure indicator |
| `data` | Nested object with price data for each cryptocurrency |
| `api_call_timestamp` | When the API was called |
| `http_status_code` | HTTP response code (200 = success) |
| `source_system` | Data source identifier |
| `api_endpoint` | Which API endpoint was called |
| `ingestion_timestamp` | When message was published to Kafka |

**Per-Crypto Fields:**

| Field | Description | Example |
|-------|-------------|---------|
| `usd` | Current price in USD | 92937 |
| `usd_market_cap` | Total market capitalization | 1.86 trillion |
| `usd_24h_vol` | 24-hour trading volume | 91.5 billion |
| `usd_24h_change` | Percent change in 24 hours | 6.77% |
| `last_updated_at` | Unix timestamp of price update | 1764758514 |

### View Real Data in Kafka

1. Open Kafka UI: http://localhost:8080
2. Click on **Topics** → `crypto.prices.raw`
3. Click **Messages** tab
4. You'll see the actual JSON structure shown above

**Key Observations:**
- Messages arrive every 30 seconds
- Each message contains **10 cryptocurrencies**
- Includes metadata fields for tracking (`api_call_timestamp`, `ingestion_timestamp`)
- `status` field helps identify failed API calls
- Nested structure: Top-level metadata + `data` object with crypto prices
- Unix timestamps need conversion to readable dates

**Why This Structure?**
- **Auditability**: Metadata tracks when/how data was collected
- **Error handling**: `status` and `http_status_code` help debug issues
- **Traceability**: Timestamps show pipeline latency (API call → Kafka)
- **Completeness**: Storing the entire response preserves context

---

## Tutorial: Phase 2 - Data Modeling

Real projects start with design, not code. Let's plan our tables before streaming data.

### Step-by-Step: Create Your Database Schema

**Step 1: Open Jupyter Notebook**

Go to http://localhost:8888 and open the existing `getting_started.ipynb` notebook (from PART-A).

**Step 2: Create Bronze Database and Table**

Run this in a new cell:

```python
# Create Bronze database (schema and database are synonymous in Hive/Spark)
spark.sql("CREATE DATABASE IF NOT EXISTS bronze")

# Create table for raw Kafka messages
spark.sql("""
CREATE TABLE IF NOT EXISTS bronze.crypto_ticks_raw (
    raw_payload STRING,
    ingestion_timestamp TIMESTAMP,
    kafka_offset BIGINT,
    kafka_partition INT
)
USING iceberg
PARTITIONED BY (days(ingestion_timestamp))
""")

spark.sql("SHOW TABLES IN bronze").show()
```

> **Note:** In Hive/Spark, `DATABASE` and `SCHEMA` are interchangeable terms - both create a namespace to organize tables. The commands `CREATE DATABASE bronze` and `CREATE SCHEMA bronze` do exactly the same thing.

**Step 3: Create Silver Database and Table**

Run this in the next cell:

```python
# Create Silver database
spark.sql("CREATE DATABASE IF NOT EXISTS silver")

# Create table for cleaned/parsed data
spark.sql("""
CREATE TABLE IF NOT EXISTS silver.crypto_prices_clean (
    crypto_symbol STRING,
    price_usd DECIMAL(18, 8),
    volume_24h DECIMAL(20, 2),
    percent_change_24h DECIMAL(10, 4),
    api_timestamp TIMESTAMP,
    processing_timestamp TIMESTAMP
)
USING iceberg
PARTITIONED BY (days(api_timestamp))
""")

spark.sql("SHOW TABLES IN silver").show()
```

**Step 4: Verify Tables Were Created**

```python
# Check table schemas
spark.sql("DESCRIBE bronze.crypto_ticks_raw").show()
spark.sql("DESCRIBE silver.crypto_prices_clean").show()
```

**✅ Done!** Your database schema is ready. Now you can proceed to Phase 3 for streaming ingestion.

---

### Understanding the Design

**The Medallion Architecture:**

| Layer | Purpose | Data Quality |
|-------|---------|--------------|
| **Bronze** | Raw data exactly as received from Kafka | Uncleaned, complete history |
| **Silver** | Cleaned, validated, typed | Business rules applied |
| **Gold** | Aggregated, analytics-ready | Optimized for queries |

**Why This Design?**

**Bronze (`crypto_ticks_raw`):**
- `raw_payload` as STRING preserves everything, even malformed JSON
- Kafka metadata (`offset`, `partition`) enables exactly-once processing
- Partitioned by ingestion date for efficient querying

**Silver (`crypto_prices_clean`):**
- Parsed JSON → structured columns
- Validated: price > 0, timestamps reasonable
- Deduplicated: keep latest per symbol per minute
- Type conversion: string → decimal/timestamp

📖 **Deep Dive:** See [data-modeling/schema-design.md](data-modeling/schema-design.md) for complete Bronze/Silver/Gold table designs and [data-modeling/dimensional-model.md](data-modeling/dimensional-model.md) for the star schema.

---

## Tutorial: Phase 3 - Streaming Ingestion (Bronze Layer)

Now let's write data from Kafka into Iceberg tables.

### Open Jupyter Notebook

1. Navigate to http://localhost:8888
2. Create a new notebook: **New** → **Python 3**
3. Name it `crypto_streaming_bronze.ipynb`

### Initialize Spark with Iceberg

```python
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("CryptoStreamingBronze") \
    .config("spark.jars.packages", 
            "org.apache.iceberg:iceberg-spark-runtime-3.3_2.12:1.4.2,"
            "org.apache.spark:spark-sql-kafka-0-10_2.12:3.3.2") \
    .config("spark.sql.catalog.spark_catalog", "org.apache.iceberg.spark.SparkCatalog") \
    .config("spark.sql.catalog.spark_catalog.type", "hive") \
    .config("spark.sql.catalog.spark_catalog.uri", "thrift://hive-metastore:9083") \
    .getOrCreate()

print("Spark session created with Iceberg support")
```

### Read from Kafka

```python
# Read streaming data from Kafka
kafka_df = spark.readStream \
    .format("kafka") \
    .option("kafka.bootstrap.servers", "kafka:29092") \
    .option("subscribe", "crypto.prices.raw") \
    .option("startingOffsets", "latest") \
    .load()

# Kafka gives us binary data - convert to string
from pyspark.sql.functions import col, current_timestamp

bronze_df = kafka_df.select(
    col("value").cast("string").alias("raw_payload"),
    current_timestamp().alias("ingestion_timestamp"),
    col("offset").alias("kafka_offset"),
    col("partition").alias("kafka_partition")
)

# Show schema
bronze_df.printSchema()
```

### Create Bronze Database and Table

```python
# Create database if not exists
spark.sql("CREATE DATABASE IF NOT EXISTS bronze")

# Create Iceberg table
spark.sql("""
CREATE TABLE IF NOT EXISTS bronze.crypto_ticks_raw (
    raw_payload STRING,
    ingestion_timestamp TIMESTAMP,
    kafka_offset BIGINT,
    kafka_partition INT
)
USING iceberg
PARTITIONED BY (days(ingestion_timestamp))
""")

print("Bronze table created successfully")
```

### Write Stream to Iceberg

```python
# Write stream to Iceberg table
query = bronze_df.writeStream \
    .format("iceberg") \
    .outputMode("append") \
    .option("path", "bronze.crypto_ticks_raw") \
    .option("checkpointLocation", "/tmp/checkpoint/bronze_crypto") \
    .trigger(processingTime="30 seconds") \
    .start()

print("Streaming query started. Data is being written to Bronze table.")
print(f"Query ID: {query.id}")
```

### Monitor the Stream

```python
# Check query status
query.status

# See recent progress
query.recentProgress
```

**In another notebook cell**, query the Bronze table:

```python
# Read from Bronze table
spark.sql("SELECT COUNT(*) as row_count FROM bronze.crypto_ticks_raw").show()

# See latest records
spark.sql("""
SELECT 
    raw_payload,
    ingestion_timestamp,
    kafka_offset
FROM bronze.crypto_ticks_raw 
ORDER BY ingestion_timestamp DESC 
LIMIT 5
""").show(truncate=False)
```

**What you should see:**
- Row count increasing every 30 seconds
- JSON data in `raw_payload` column
- Timestamps showing when data was ingested

🎉 **Congratulations!** You've built a real-time streaming pipeline from Kafka to Iceberg.

---

## What's Working vs. What's Planned

### ✅ Currently Implemented

| Component | Status | What Works |
|-----------|--------|------------|
| Kafka Stack | ✅ Complete | Zookeeper, Kafka, Kafka UI running |
| Crypto Producer | ✅ Complete | Fetches live prices every 30s from CoinGecko |
| Data Modeling Docs | ✅ Complete | Bronze/Silver/Gold schemas documented |
| Bronze Ingestion | ✅ Tutorial Ready | Step-by-step guide above |

### 🚧 Planned for Future Updates

| Component | Status | What's Needed |
|-----------|--------|---------------|
| Silver Layer | 📝 Documented | Need transformation notebook/script |
| Gold Layer | 📝 Documented | Need dbt project setup |
| Airflow Orchestration | 🔜 Planned | DAG for end-to-end pipeline |
| Time Travel Queries | 🔜 Planned | Examples using Iceberg snapshots |
| Performance Tuning | 🔜 Planned | Compaction, Z-ordering examples |

---

## Next Steps

### Continue Learning

1. **Practice Bronze Ingestion:** Run the tutorial above and let data accumulate for 10-15 minutes
2. **Explore the Data:** 
   - Query Bronze tables with different time ranges
   - Count records per partition
   - Parse JSON and extract specific coins
3. **Study the Schema Designs:**
   - Read [data-modeling/schema-design.md](data-modeling/schema-design.md)
   - Understand why each table is partitioned differently
   - Review the data quality rules for Silver layer
4. **Design Silver Transformations:**
   - How would you parse the JSON?
   - What validations would you add?
   - How would you handle duplicate records?

### Stop the Services

When you're done experimenting:

```bash
# Stop PART-B (preserves data)
docker-compose down

# Stop PART-A
cd ../PART-A
./stop.sh    # Mac/Linux
./stop.ps1   # Windows
```

All data is preserved in Docker volumes. Restart anytime with `./start.sh` (PART-A) and `docker-compose up -d` (PART-B).

### After Machine Restart

Both PART-A and PART-B containers are configured with `restart: unless-stopped`. After rebooting:

1. **Docker Desktop starts** (if configured in settings)
2. **All containers restart automatically** in the correct order
3. **Wait 30-60 seconds** for Kafka to become healthy
4. **Check status:**
   ```bash
   docker ps | grep crypto
   ```

If any service fails to start:
```bash
# Restart PART-B services
cd PART-B
docker-compose down
docker-compose up -d
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Network dasnet not found" | Start PART-A first: `cd PART-A && ./start.sh` |
| Crypto producer not sending data | Check logs: `docker logs crypto-producer` |
| Kafka UI shows no messages | Wait 30 seconds for first API call, refresh page |
| Spark can't connect to Kafka | Ensure Kafka is healthy: `docker ps \| grep kafka` |
| "Table already exists" error | Normal - Iceberg tables persist across restarts |

### View Logs

```bash
# Producer logs (shows API calls)
docker logs -f crypto-producer

# Kafka logs
docker logs -f crypto-kafka

# All PART-B services
docker-compose logs -f
```

---

## Contributing

Found a bug or have suggestions? This is a learning project-your feedback helps everyone. Open an issue or submit a pull request!

---

## What Makes This Real

Unlike typical tutorials, this project uses:
- ✅ **Real APIs** - Live data from CoinGecko (not CSV files)
- ✅ **Production Patterns** - Medallion architecture, proper partitioning
- ✅ **Real Challenges** - API rate limits, late data, duplicates
- ✅ **Industry Tools** - Kafka, Spark, Iceberg, not toy examples

**You're learning production skills, not just following scripts.**

