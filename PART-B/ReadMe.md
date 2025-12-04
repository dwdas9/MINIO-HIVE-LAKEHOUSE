# PART-B: Streaming Infrastructure

**← [Back to Main Repository](../README.md) | ⚠️ Prerequisites: [Complete PART-A first](../PART-A/README.md)**

This is the **streaming layer** of the lakehouse. It provides Kafka infrastructure for real-time data ingestion, along with a crypto price producer as a demonstration of streaming data pipelines.

## What You'll Get

Streaming infrastructure including:
- Kafka cluster for message streaming
- Zookeeper for Kafka coordination
- Kafka UI for monitoring topics and messages
- Crypto price producer (demonstration)
- Network connectivity to PART-A infrastructure

**For the complete crypto analytics project**, see [PART-C: Projects](../PART-C/README.md).

## Architecture Overview

![](images/20251204182616.png)

**Network:** All services run on the `dasnet` Docker network created by PART-A. This lets them access MinIO and Hive Metastore from the core infrastructure.

---

## Quick Start

** If you followed the [main README](../README.md), everything is already running!**

The main README Quick Start guide already:
-  Started PART-A (MinIO, Hive, Spark)
-  Started PART-B (Kafka, Producer)
-  Configured all services

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

## What's Included

### Services

| Service | Purpose | Port |
|---------|---------|------|
| **Zookeeper** | Kafka coordination | 2181 |
| **Kafka** | Message streaming | 9092 (internal), 9093 (external) |
| **Kafka UI** | Web interface for monitoring | 8080 |
| **Crypto Producer** | Example data generator | - |

### Demonstration: Crypto Price Streaming

PART-B includes a cryptocurrency price producer that demonstrates real-time data streaming:

**What it does:**
- Fetches live crypto prices from CoinGecko API every 30 seconds
- Publishes to Kafka topic `crypto.prices.raw`
- Includes 10 cryptocurrencies (Bitcoin, Ethereum, etc.)
- Wraps data with metadata for tracking

**View the data:**
1. Open Kafka UI: http://localhost:8080
2. Navigate to Topics → `crypto.prices.raw`
3. View live messages arriving every 30 seconds

**Producer code:** [`producers/crypto_producer.py`](producers/crypto_producer.py)

---

## Using This Infrastructure

PART-B provides the streaming layer for your projects. The crypto producer is a working example you can:

- **Study** - Learn how to build producers
- **Modify** - Change API endpoints or frequency
- **Replace** - Build your own producers for different data sources

**Ready to build a complete project?**  
📖 **[Go to PART-C: Crypto Analytics Project](../PART-C/README.md)** to see how to consume this streaming data, transform it through Bronze/Silver/Gold layers, and build analytics.

---

## Data Structure Example

The crypto producer sends JSON messages in this format:

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
    "ethereum": { ... }
  },
  "api_call_timestamp": "2025-12-03T10:42:30.109530",
  "http_status_code": 200,
  "source_system": "coingecko_v3",
  "ingestion_timestamp": "2025-12-03T10:42:30.110290"
}
```

**For detailed schema design and data modeling,** see [PART-C: Crypto Analytics](../PART-C/crypto-analytics/data-modeling/).

---

## Managing PART-B
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

** Done!** Your database schema is ready. Now you can proceed to Phase 3 for streaming ingestion.

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

###  Currently Implemented

| Component | Status | What Works |
|-----------|--------|------------|
| Kafka Stack |  Complete | Zookeeper, Kafka, Kafka UI running |
| Crypto Producer |  Complete | Fetches live prices every 30s from CoinGecko |
| Data Modeling Docs |  Complete | Bronze/Silver/Gold schemas documented |
| Bronze Ingestion |  Tutorial Ready | Step-by-step guide above |

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

## Customizing the Producer

Want to stream different data? The crypto producer is a template:

**File:** [`producers/crypto_producer.py`](producers/crypto_producer.py)

**Modify it to:**
- Change API endpoints
- Adjust frequency (currently 30 seconds)
- Add new data sources
- Change Kafka topics

**After changes:**
```bash
docker-compose restart crypto-producer
```

---

## Next Steps

1. ✅ **PART-B is running** - Streaming infrastructure ready
2. 📖 **Monitor Kafka UI** - http://localhost:8080 to see live data
3. 🚀 **Build projects** - [Go to PART-C](../PART-C/README.md) to learn data engineering with this streaming infrastructure

---

## What Makes This Real

The crypto producer demonstrates production patterns:
- ✅ **Real APIs** - Live data from CoinGecko (not CSV files)
- ✅ **Error handling** - Status tracking and retry logic
- ✅ **Metadata** - Timestamps for tracking and debugging
- ✅ **Industry Tools** - Kafka, not toy examples

**See it in action in [PART-C: Crypto Analytics Project](../PART-C/crypto-analytics/)**, which shows how to consume this streaming data and build a complete medallion architecture pipeline.
