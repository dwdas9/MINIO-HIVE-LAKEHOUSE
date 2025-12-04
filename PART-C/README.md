# PART-C: Data Engineering Projects

**← [Back to Main Repository](../README.md)**

Welcome to the project section! This is where you'll apply everything you've learned.

PART-C contains **hands-on data engineering projects** that use the infrastructure from PART-A and PART-B. These aren't toy examples - they're real projects using production patterns, live APIs, and industry-standard tools. Each project shows real-world data engineering patterns, from ingestion to transformation to analytics.

## Prerequisites

Before diving into projects, let's make sure you have the foundation ready:

- ✅ **PART-A is running** - Core lakehouse infrastructure (MinIO, Hive, Spark)
- ✅ **PART-B is running** - Streaming infrastructure (Kafka, producers)

**Haven't set these up yet?** No worries! Head over to the [main README](../README.md) for step-by-step setup instructions. It takes about 5-10 minutes.

**Already running?** Great! Let's explore the projects.

---

## Available Projects

### 🪙 Crypto Analytics

Your first project! This is a production-grade real-time analytics pipeline that streams live cryptocurrency prices into your lakehouse. It's a complete end-to-end project that demonstrates everything you need to know about building streaming data pipelines.

**Location:** [`crypto-analytics/`](crypto-analytics/)

**What you'll learn (and actually build):**
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

**Ready to start?** Here's how:
```bash
# 1. Open Jupyter Notebook in your browser
# http://localhost:8888

# 2. Navigate to the crypto-analytics folder
# 3. Open: getting_started.ipynb
```

The notebook walks you through everything step-by-step. You'll see live data flowing, create your first Iceberg tables, and build a complete analytics pipeline.

📖 **[View Full Project Documentation](crypto-analytics/README.md)**

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
