# Real-Time Crypto Analytics

This project teaches building a real-time cryptocurrency analytics platform. We use **live data** from public APIs, process it with **Spark Structured Streaming**, store it in **Iceberg tables** on **MinIO**, transform with **dbt**, and orchestrate with **Airflow**.

## What You'll Learn

1. **Data Modeling** - Design Bronze/Silver/Gold layers and dimensional models
2. **Streaming Ingestion** - Kafka producers consuming real-time crypto APIs
3. **Spark Structured Streaming** - Process data as it arrives
4. **dbt Transformations** - Clean, model, and test your data
5. **Orchestration** - Airflow to schedule and monitor everything
6. **Performance** - Iceberg features (compaction, time travel, partitioning)

## Architecture

```
CoinGecko API (live prices)
    ↓
Kafka (streaming buffer)
    ↓
Spark Structured Streaming
    ↓
Iceberg Tables in MinIO
    ↓
dbt (transformations)
    ↓
Analytics & Dashboards
```

**Network:** All services connect via `dasnet` to share MinIO and Hive Metastore from the main lakehouse.

## Project Structure

```
learning/
├── README.md                    # This file
├── docker-compose.yml           # Kafka, Airflow, producers
├── setup.ps1                    # Windows setup script
├── setup.sh                     # Mac/Linux setup script
├── data-modeling/
│   ├── schema-design.md         # Bronze/Silver/Gold design
│   ├── dimensional-model.md     # Fact and dimension tables
│   └── diagrams/                # ERD diagrams
├── producers/
│   ├── crypto_producer.py       # Fetches prices, sends to Kafka
│   ├── requirements.txt
│   └── Dockerfile
├── streaming/
│   ├── bronze_ingestion.py      # Kafka → Bronze Iceberg
│   └── notebooks/
│       └── streaming_setup.ipynb
├── dbt_crypto/
│   ├── dbt_project.yml
│   ├── profiles.yml
│   ├── models/
│   │   ├── bronze/              # Raw data models
│   │   ├── silver/              # Cleaned models
│   │   └── gold/                # Fact/dimension tables
│   ├── tests/
│   └── docs/
└── airflow/
    ├── dags/
    │   └── crypto_pipeline.py
    └── logs/
```

## Phase 1: Data Modeling (Start Here)

Before writing code, we design our schema. This is how real projects begin.

### The Business Requirements

**Goal:** Build a real-time analytics platform for cryptocurrency trading.

**Questions We Need to Answer:**
1. What is Bitcoin's current price and how has it changed in the last hour?
2. Which crypto has the highest volatility today?
3. What was Ethereum's price exactly 2 hours ago? (Time Travel)
4. Alert me when any coin drops more than 5% in 10 minutes
5. What is the 24-hour trading volume for the top 10 coins?

### The Medallion Architecture

We follow the industry-standard pattern:

#### **Bronze Layer - Raw Landing Zone**

Tables that capture data exactly as received from APIs:

**`bronze.crypto_ticks_raw`**
- Purpose: Every API response, stored as-is
- Schema: JSON blob + ingestion timestamp
- Partitioned by: `ingestion_date`
- Retention: 30 days (then archive to cold storage)

#### **Silver Layer - Cleaned & Validated**

Tables with business logic applied:

**`silver.crypto_prices_clean`**
- Purpose: Typed, validated, deduplicated prices
- Schema: Structured columns (symbol, price, volume, timestamp)
- Deduplication: Latest price per symbol per minute
- Partitioned by: `price_date`
- Quality checks: No nulls in price, timestamp within 5 minutes of ingestion

#### **Gold Layer - Analytics-Ready**

Dimensional model optimized for queries:

**Fact Tables:**

**`gold.fact_crypto_ticks`**
- Grain: One row per price update
- Measures: price_usd, volume_24h, market_cap, percent_change_1h
- Foreign keys: crypto_id, time_id
- Partitioned by: price_date

**`gold.fact_crypto_hourly`**
- Grain: One row per crypto per hour
- Measures: open, high, low, close, avg_price, total_volume
- Aggregated from: fact_crypto_ticks
- Partitioned by: hour_date

**Dimension Tables:**

**`gold.dim_crypto`** (SCD Type 2)
- Attributes: symbol, name, category, market_cap_rank
- SCD Type 2: Track when coins get delisted or renamed
- Columns: crypto_id, symbol, name, category, valid_from, valid_to, is_current

**`gold.dim_time`**
- Attributes: timestamp, hour, day, week, month, quarter, year, is_trading_hour
- Pre-populated for fast joins
- Granularity: Per minute

### Data Flow

```
1. CoinGecko API → Kafka topic: 'crypto.prices.raw'
2. Spark Streaming → bronze.crypto_ticks_raw (append mode)
3. dbt incremental → silver.crypto_prices_clean
4. dbt transformation → gold.fact_crypto_ticks
5. dbt aggregation → gold.fact_crypto_hourly
6. dbt dimension → gold.dim_crypto (SCD Type 2)
```

## Quick Start

### Prerequisites

Your main lakehouse must be running (MinIO, Hive, PostgreSQL on `dasnet`).

### Setup

**Windows:**
```powershell
cd learning
powershell -ExecutionPolicy Bypass -File .\setup.ps1
```

**Mac/Linux:**
```bash
cd learning
./setup.sh
```

This will:
1. Start Kafka and Zookeeper
2. Create Kafka topics
3. Start the crypto price producer
4. Set up Airflow

### Verify

```bash
# Check Kafka UI
http://localhost:8080

# Check Airflow
http://localhost:8081
```

## Learning Path

Follow these phases in order:

### Phase 1: Data Modeling (2-3 hours)
- Read `data-modeling/schema-design.md`
- Design your Bronze/Silver/Gold tables
- Draw the dimensional model

### Phase 2: Streaming Setup (3-4 hours)
- Start the crypto producer
- Build Spark Structured Streaming job
- Watch data flow into Bronze tables

### Phase 3: dbt Transformations (4-6 hours)
- Set up dbt project
- Build Silver cleaning models
- Build Gold fact/dimension tables
- Add tests and documentation

### Phase 4: Orchestration (2-3 hours)
- Create Airflow DAG
- Schedule Bronze → Silver → Gold pipeline
- Add monitoring and alerts

### Phase 5: Advanced Features (4-6 hours)
- Implement time travel queries
- Add Z-ordering for performance
- Run compaction jobs
- Build real-time alerts

## What Makes This Real

**Not a tutorial project:**
- No pre-cleaned CSV files
- No "assume the data is perfect"
- No skipping the hard parts

**Real production scenarios:**
- API rate limits and failures
- Late-arriving data
- Schema changes
- Duplicate records
- Missing values
- Performance optimization

## Next Steps

Start with [Phase 1: Data Modeling](data-modeling/schema-design.md)
    │   └── crypto_pipeline.py
    └── logs/
```
*   **Sorting & Z-Ordering:** Organize data so Spark skips 90% of files during filtered queries.

### 7. Extensions (Expanding your setup)
*   **Streaming:** Add **Kafka** for real-time Bronze ingestion.
*   **Orchestration:** Use **Airflow** or **Dagster** to schedule pipelines.
*   **Data Quality:** Add **Great Expectations** for validation.

### Your First Project: "The E-Commerce Pipeline"
1.  **Generate Data:** Python script creates fake Orders (JSON) and uploads to MinIO.
2.  **Ingest (Bronze):** Spark job reads JSONs into Iceberg table `orders_bronze`.
3.  **Clean (Silver):** Spark job cleans data, filters invalid orders, merges into `orders_silver`.
4.  **Model (Gold):** Use dbt to build fact/dimension tables and calculate "Total Sales per Minute".

