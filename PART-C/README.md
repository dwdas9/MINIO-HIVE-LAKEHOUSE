# PART-C: Data Engineering Projects

**← [Back to Main Repository](../README.md)**

This section contains **hands-on data engineering projects** that use the infrastructure from PART-A and PART-B. Each project demonstrates real-world data engineering patterns, from ingestion to transformation to analytics.

## Prerequisites

Before working on any project here, ensure:
- ✅ **PART-A is running** - Core lakehouse infrastructure (MinIO, Hive, Spark)
- ✅ **PART-B is running** - Streaming infrastructure (Kafka, producers)

See the [main README](../README.md) for setup instructions.

---

## Available Projects

### 🪙 Crypto Analytics

A production-grade real-time analytics pipeline that streams cryptocurrency prices into the lakehouse.

**Location:** [`crypto-analytics/`](crypto-analytics/)

**What you'll learn:**
- Real-time data ingestion from APIs
- Streaming data through Kafka into Iceberg tables
- Medallion architecture (Bronze/Silver/Gold layers)
- Data modeling and dimensional design
- Spark Structured Streaming at scale

**Tech Stack:**
- Kafka for streaming ingestion
- Apache Iceberg for ACID transactions
- Spark for processing
- MinIO for storage
- Hive Metastore for catalog

**Get Started:**
```bash
# Access Jupyter Notebook
# http://localhost:8888

# Open the getting started notebook
PART-C/crypto-analytics/notebooks/getting_started.ipynb
```

📖 **[View Project Documentation](crypto-analytics/README.md)**

---

## Project Structure

Each project follows this standard structure:

```
project-name/
├── README.md                    # Project overview and instructions
├── notebooks/                   # Jupyter notebooks for analysis
│   ├── 01_getting_started.ipynb
│   ├── 02_bronze_layer.ipynb
│   ├── 03_silver_layer.ipynb
│   └── 04_gold_layer.ipynb
├── data-modeling/              # Data model documentation
│   ├── schema-design.md
│   └── dimensional-model.md
└── sql/                        # SQL scripts organized by layer
    ├── bronze/
    ├── silver/
    └── gold/
```

---

## Adding Your Own Projects

Want to add a new project? Follow this pattern:

1. Create a new directory under `PART-C/`
2. Follow the standard project structure above
3. Document your data sources and transformations
4. Add a comprehensive README
5. Use the existing infrastructure (PART-A + PART-B)

**Project Ideas:**
- Stock market analytics
- IoT sensor data processing
- Log analytics pipeline
- Customer behavior analysis
- Social media sentiment analysis

---

## Working with Projects

### Access Jupyter Notebook
```bash
# Already running from PART-A setup
# http://localhost:8888
```

### Access Services

| Service | URL | Purpose |
|---------|-----|---------|
| Jupyter Notebook | http://localhost:8888 | Run Spark queries and notebooks |
| MinIO Console | http://localhost:9001 | View stored data files |
| Kafka UI | http://localhost:8080 | Monitor streaming data |
| Spark UI | http://localhost:4040 | Monitor Spark jobs |

### Common Patterns

**Reading from Iceberg:**
```python
df = spark.table("lakehouse.bronze.crypto_prices")
df.show()
```

**Writing to Iceberg:**
```python
df.writeTo("lakehouse.silver.crypto_hourly") \
  .using("iceberg") \
  .createOrReplace()
```

**Streaming from Kafka:**
```python
df = spark.readStream \
  .format("kafka") \
  .option("kafka.bootstrap.servers", "crypto-kafka:9092") \
  .option("subscribe", "crypto.prices.raw") \
  .load()
```

---

## Next Steps

1. **Start with Crypto Analytics** - [`crypto-analytics/`](crypto-analytics/)
2. **Explore the data model** - [`crypto-analytics/data-modeling/`](crypto-analytics/data-modeling/)
3. **Build your own project** - Use the infrastructure for your ideas

Happy building! 🚀
