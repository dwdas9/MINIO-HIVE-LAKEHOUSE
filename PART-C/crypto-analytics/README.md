# Crypto Analytics Project

**← [Back to PART-C](../README.md) | [Main Repository](../../README.md)**

## Overview

A production-grade real-time analytics platform that streams live cryptocurrency prices from public APIs into your lakehouse. This project demonstrates enterprise data engineering patterns including real-time ingestion, medallion architecture, and dimensional modeling.

## Prerequisites

Ensure both infrastructure layers are running:

✅ **PART-A** - Core lakehouse (MinIO, Hive, Spark)  
✅ **PART-B** - Streaming layer (Kafka, crypto producer)

See [main README](../../README.md) for setup.

---

## What You'll Build

A complete streaming data pipeline that:
- Fetches live crypto prices from CoinGecko API every 30 seconds
- Streams through Kafka into Iceberg tables
- Implements Bronze → Silver → Gold layers
- Processes millions of records with Spark Structured Streaming
- Applies dimensional modeling for analytics

---

## Architecture

```
CoinGecko API → Crypto Producer → Kafka → Spark Streaming → Iceberg Tables (MinIO)
                                                          ↓
                                                    Bronze Layer (raw)
                                                          ↓
                                                    Silver Layer (cleaned)
                                                          ↓
                                                    Gold Layer (aggregated)
```

**Key Components:**
- **Producer:** Python app fetching prices every 30s
- **Kafka:** Message broker for streaming
- **Spark Streaming:** Processing engine
- **Iceberg:** ACID transactions on data lake
- **MinIO:** S3-compatible object storage

---

## Getting Started

### 1. Access Jupyter Notebook

```bash
# Navigate to: http://localhost:8888
# Open: work/getting_started.ipynb
```

### 2. Verify Data is Flowing

Check Kafka UI for incoming messages:
```
http://localhost:8080
Topic: crypto.prices.raw
```

You should see messages arriving every 30 seconds.

### 3. Follow the Notebooks

Work through these in order:

1. **`getting_started.ipynb`** - Initial setup and Bronze layer
2. **`02_bronze_layer.ipynb`** - Raw data ingestion (coming soon)
3. **`03_silver_layer.ipynb`** - Data cleaning and transformation (coming soon)
4. **`04_gold_layer.ipynb`** - Analytics and aggregations (coming soon)

---

## Data Model

Detailed documentation available in [`data-modeling/`](data-modeling/):

- **[schema-design.md](data-modeling/schema-design.md)** - Bronze/Silver/Gold schemas
- **[dimensional-model.md](data-modeling/dimensional-model.md)** - Star schema design

### Quick Overview

**Bronze Layer** (Raw)
```sql
lakehouse.bronze.crypto_prices_raw
- Contains raw JSON from Kafka
- No transformations
- Full audit trail
```

**Silver Layer** (Cleaned)
```sql
lakehouse.silver.crypto_prices
- Parsed and cleaned data
- Proper data types
- Deduplicated
```

**Gold Layer** (Analytics)
```sql
lakehouse.gold.crypto_hourly_stats
lakehouse.gold.crypto_daily_summary
- Aggregated metrics
- Business logic applied
- Ready for BI tools
```

---

## Project Structure

```
crypto-analytics/
├── README.md                           # This file
├── notebooks/                          # Jupyter notebooks
│   └── getting_started.ipynb          # Main tutorial notebook
├── data-modeling/                      # Data model documentation
│   ├── schema-design.md               # Layer-by-layer schemas
│   └── dimensional-model.md           # Star schema design
└── sql/                               # SQL scripts (for future use)
    ├── bronze/
    ├── silver/
    └── gold/
```

---

## Sample Queries

### Check latest prices
```sql
SELECT symbol, price_usd, last_updated 
FROM lakehouse.silver.crypto_prices 
ORDER BY last_updated DESC 
LIMIT 10;
```

### Hourly statistics
```sql
SELECT 
  hour,
  symbol,
  avg_price_usd,
  max_price_usd,
  min_price_usd,
  price_volatility
FROM lakehouse.gold.crypto_hourly_stats
WHERE symbol = 'bitcoin'
ORDER BY hour DESC
LIMIT 24;
```

---

## Technologies Used

| Technology | Purpose |
|------------|---------|
| **Apache Kafka** | Stream cryptocurrency price data |
| **Apache Spark** | Process and transform data |
| **Apache Iceberg** | Table format with ACID transactions |
| **MinIO** | S3-compatible object storage |
| **Hive Metastore** | Metadata catalog |
| **PostgreSQL** | Metastore backend |
| **Jupyter** | Interactive development |
| **Python** | Producer and data generation |

---

## Step-by-Step Tutorial

### Phase 1: Streaming Ingestion (Bronze Layer)

Let's write data from Kafka into Iceberg tables.

#### 1. Open Jupyter Notebook

1. Navigate to http://localhost:8888
2. Create a new notebook: **New** → **Python 3**
3. Name it `crypto_streaming_bronze.ipynb`

#### 2. Initialize Spark with Iceberg

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

#### 3. Read from Kafka

```python
# Read streaming data from Kafka
kafka_df = spark.readStream \
    .format("kafka") \
    .option("kafka.bootstrap.servers", "crypto-kafka:9092") \
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

#### 4. Create Bronze Database and Table

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

#### 5. Write Stream to Iceberg

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

#### 6. Monitor the Stream

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

## What's Implemented vs. Planned

### ✅ Currently Available

| Component | Status | What's Ready |
|-----------|--------|-------------|
| Infrastructure | ✅ Complete | Kafka, producer, lakehouse all running |
| Bronze Ingestion | ✅ Tutorial Ready | Step-by-step guide above |
| Data Modeling | ✅ Documented | Bronze/Silver/Gold schemas defined |

### 🚧 Coming Soon

| Component | Status | Description |
|-----------|--------|-------------|
| Silver Layer | 📝 In Progress | Transformation notebooks |
| Gold Layer | 📝 In Progress | Aggregation examples |
| dbt Integration | 🔜 Planned | SQL transformations |
| Airflow DAGs | 🔜 Planned | Pipeline orchestration |
| Time Travel Examples | 🔜 Planned | Iceberg snapshots |

---

## Learning Outcomes

After completing this project, you'll understand:

✅ Real-time data ingestion patterns  
✅ Kafka → Spark → Iceberg pipeline  
✅ Medallion architecture (Bronze/Silver/Gold)  
✅ Dimensional modeling for analytics  
✅ Iceberg table operations and time travel  
✅ Spark Structured Streaming  
✅ Production-grade error handling  

---

## Practice Exercises

### Beginner Level
1. **Explore Bronze Data:** Run the tutorial and let data accumulate for 10-15 minutes
2. **Query Patterns:** 
   - Count records per partition
   - Filter by time ranges
   - Parse JSON and extract specific cryptocurrencies

### Intermediate Level
3. **Study Schema Designs:** Read the [data-modeling docs](data-modeling/)
4. **Design Transformations:** Plan how to build the Silver layer
   - How would you parse the JSON?
   - What validations would you add?
   - How would you handle duplicates?

### Advanced Level
5. **Optimize Performance:** 
   - Experiment with different partition strategies
   - Test various checkpoint intervals
   - Monitor Spark UI for bottlenecks

---

## Troubleshooting

**No data appearing in Kafka?**
```bash
docker logs crypto-producer
# Check for API rate limits or connection issues
```

**Spark job failing?**
```bash
# Check Spark UI: http://localhost:4040
# Review full logs in Jupyter notebook output
```

**Can't connect to Hive Metastore?**
```bash
docker logs hive-metastore
# Ensure PART-A is running properly
```

---

**Ready to dive in?** Open Jupyter at http://localhost:8888 and start with `getting_started.ipynb`! 🚀
