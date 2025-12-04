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

## Next Steps

1. Complete the `getting_started.ipynb` notebook
2. Review the data model documentation
3. Explore the Bronze/Silver/Gold layers
4. Add custom transformations
5. Create your own analytics queries

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
