# MinIO + Hive Metastore + Iceberg Lakehouse

## Overview

Welcome to my repo. Here, I tried to create a complete, production-ready data lakehouse running locally with Docker on Mac, Linux, or Windows.

**Key Specialties:**
- **On-Premises**: Fully self-hosted - nothing on cloud. Works both on Windows and MAC(Apple silicon)
- **Open Source Stack**: Apache Iceberg, MinIO, Hive Metastore, Spark, Kafka, Airflow
- **Scalable Architecture**: Even though the design is local on docker. The same architecture can be scalled up for real production use.

**What You'll Learn:**
- Building modern data lakehouse architectures
- Managing metadata catalogs with Hive Metastore
- Real-time streaming pipelines with Kafka and Spark
- Data transformations with dbt and Spark SQL
- Orchestrating workflows with Airflow

## Start Here: Choose Your Path

I have split the repo into three main parts. **Start with PART-A first**, then PART-B, and finally explore PART-C.

| Part | Purpose | Documentation |
|------|---------|---------------|
| **PART-A** | Foundation layer: Storage, metadata catalog, processing engine | 📖 [Go to PART-A →](PART-A/README.md) |
| **PART-B** | Streaming layer: Real-time data ingestion with Kafka | 📖 [Go to PART-B →](PART-B/ReadMe.md) |
| **PART-C** | Projects: Hands-on data engineering applications | 📖 [Go to PART-C →](PART-C/README.md) |


## Quick Start

### 1. Setup Core Infrastructure (PART-A)

**First time only:** Use setup scripts to auto-download required JARs and create containers automatically.

| OS         | Command(s)                                                                                  |
|------------|------------------------------------------------------------------------------------------|
| Mac/Linux  | `cd PART-A`<br>`chmod +x setup.sh`<br>`./setup.sh`                                        |
| Windows    | `cd PART-A`<br>`Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass`<br>`./setup.ps1` |

**What setup does:**
- Downloads 3 required JAR files (~50MB) to `lib/` folder
- Creates and starts all containers
- Waits for services to be healthy
- Starts Jupyter notebook

![](images/20251202124641.png)


### 2. Access Core Services

Great! If setup completed successfully, your lakehouse is now running. Let's verify everything works by accessing the services:

| Service            | URL                    | Credentials                |
|--------------------|------------------------|----------------------------|
| Jupyter Notebook   | http://localhost:8888  | No password                |
| MinIO Console      | http://localhost:9001  | minioadmin / minioadmin    |
| Spark UI           | http://localhost:4040  | (Active during queries)    |

**Try it now:** Open Jupyter at http://localhost:8888. You'll see the familiar Jupyter interface ready to run Spark SQL queries. The MinIO console at http://localhost:9001 lets you browse your data lake like an S3 bucket.

### 3. Run Streaming Analytics (Optional)

Now that your lakehouse is running, let's add real-time streaming capabilities! PART-B sets up Kafka infrastructure and starts streaming live cryptocurrency prices into your lakehouse.

**This step is optional** - you can skip it if you just want to explore the core lakehouse features. But if you're interested in real-time data pipelines, this is where the magic happens.

| OS         | Command(s)                                                                                 |
|------------|-------------------------------------------------------------------------------------------|
| Mac/Linux  | `cd PART-B`<br>`chmod +x setup.sh`<br>`./setup.sh`                                         |
| Windows    | `cd PART-B`<br>`Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass`<br>`./setup.ps1`|

**What happens:** This sets up Kafka, starts a producer that fetches crypto prices every 30 seconds, and makes the data available for streaming into your lakehouse.

### 4. Work on Data Projects (PART-C)

Excellent! With both infrastructure layers running (lakehouse + streaming), you're ready to build real data engineering projects.

PART-C contains hands-on projects that use your infrastructure. Start with the **crypto analytics project** - it's a complete, production-style pipeline that shows you how to:
- Ingest streaming data from Kafka
- Build Bronze/Silver/Gold layers
- Apply dimensional modeling
- Create analytics-ready datasets

📖 **[Go to PART-C: Projects →](PART-C/README.md)**

**To get started quickly:**
```bash
# Open Jupyter: http://localhost:8888
# You'll find notebooks in the work/ directory
# Start with getting_started.ipynb in the crypto-analytics folder
```

**Tip:** Even if you skipped PART-B, you can still explore the notebooks and learn the concepts. The streaming examples just won't have live data.

---

### 5. Daily Usage - Managing Your Lakehouse

After the initial setup, you'll want to start and stop your lakehouse as needed. Here are the commands you'll use regularly:

**Good news:** You only need to run setup once. After that, use these simpler commands:

| Step                | Mac/Linux Command(s)           | Windows Command(s)           |
|---------------------|-------------------------------|------------------------------|
| Start PART-A        | `cd PART-A`<br>`./start.sh`   | `cd PART-A`<br>`./start.ps1` |
| Stop PART-A         | `cd PART-A`<br>`./stop.sh`    | `cd PART-A`<br>`./stop.ps1`  |
| Start PART-B        | `cd PART-B`<br>`docker-compose up -d` | `cd PART-B`<br>`docker-compose up -d` |
| Stop PART-B         | `cd PART-B`<br>`docker-compose down`  | `cd PART-B`<br>`docker-compose down`  |


### 6. Starting Over (Nuclear Option)

Sometimes you just want to wipe everything clean and start fresh. Maybe you experimented too much, or things got messy, or you just want that "new project" feeling.

**The `nuke` scripts** completely destroy everything and give you a blank slate:
- ⚠️ Stops and removes all containers
- ⚠️ Deletes all Docker volumes (postgres_data, minio_data)
- ⚠️ **Permanently deletes** all your tables, data, and Iceberg metadata
- Use only when you want to completely start over

```bash
cd PART-A
./nuke.sh    # Mac/Linux
./nuke.ps1   # Windows
```

After nuking, run `./setup.sh` or `./setup.ps1` to recreate everything from scratch.

## Architecture

Let me walk you through how everything connects. Understanding this architecture will help you troubleshoot issues and build better pipelines.

### How Data Flows

**PART-A (Core Lakehouse):**
1. You write SQL queries in **Jupyter** notebook
2. **Spark** executes the query and asks **Hive** "where is this table?"
3. **Hive** checks **PostgreSQL** for table metadata (schema, location)
4. **Spark** reads/writes Parquet files directly from **MinIO** (S3 storage)

**PART-B (Real-Time Streaming):**
1. **Producer** fetches live crypto prices from **CoinGecko API** every 30 seconds
2. Prices are published as events to **Kafka** message queue
3. **Spark Streaming** consumes from Kafka and writes to Iceberg tables (Bronze layer)
4. **Kafka UI** lets you monitor topics and messages in real-time

![](images/20251203200553.png)

**What Each Service Does:**

| Service | Role | What It Stores |
|---------|------|----------------|
| **Jupyter** | Interactive interface | Your SQL queries and notebooks |
| **Spark** | Query engine | Nothing (stateless processing) |
| **Hive** | Metadata catalog | Table definitions, schemas, partitions |
| **PostgreSQL** | Database | Hive's metadata (backing store) |
| **MinIO** | Object storage | Your actual data files (Parquet/Iceberg) |
| **Kafka** | Message queue | Streaming events (temporary, configurable retention) |
| **Zookeeper** | Coordinator | Kafka cluster state |
| **Producer** | Data ingester | Nothing (fetches and forwards) |
| **Kafka UI** | Monitoring tool | Nothing (reads from Kafka) |

## What Persists Across Restarts?

You might be wondering: "If I stop Docker, do I lose everything?" **Nope!** Your work is completely safe. Docker volumes preserve everything:

| Volume         | Description                       |
|---------------|-----------------------------------|
| postgres_data  | Table metadata and schemas        |
| minio_data     | Parquet/Iceberg data files        |

Stopping containers preserves all data. Only `./nuke.sh`/`./nuke.ps1` deletes everything.

### After Machine/Docker Restart

Just restart Docker Desktop. All services automatically restart with the `restart: unless-stopped` policy, ensuring containers start automatically when Docker boots, dependencies initialize in the correct order (Postgres → Hive → Spark), and all your data persists across restarts.

If services don't automatically start, manually restart them:
```bash
cd PART-A
./start.sh    # Mac/Linux
./start.ps1   # Windows
```

Wait 30–60 seconds for services to be healthy before accessing them.

**Verify everything is running:**
```bash
docker ps
```

You should see all containers with "Up" status. If something's missing, manually restart:
```bash
cd PART-A
./start.sh    # Mac/Linux
./start.ps1   # Windows
```

**Important:** Enable "Start Docker Desktop when you log in" in Docker settings to ensure Docker itself starts on boot.

## Network Architecture

| Network | Role |
|---------|------|
| dasnet  | Created by PART-A; PART-B connects for cross-service access |

## Prerequisites

| Requirement         | Details                       |
|--------------------|-------------------------------|
| Docker             | Desktop (Mac/Windows) or Engine (Linux) |
| RAM                | 8GB+ available for Docker      |
| Disk Space         | 10GB+ free                     |

## Troubleshooting

Running into issues? Don't worry - here are the most common problems and how to fix them:

| Issue                        | Solution/Check |
|------------------------------|----------------|
| PART-A won't start           | See [PART-A/README.md](PART-A/README.md#troubleshooting).<br>Common: missing JARs, ports in use (5432, 9000, 9001, 8888), not enough Docker memory |
| PART-B can't connect to PART-A| Ensure PART-A is running (`cd PART-A`, `docker-compose ps`). If not, restart PART-A (`./stop.sh`/`./start.sh` or `./stop.ps1`/`./start.ps1`). Then retry PART-B setup. |
| Network not found error       | Start PART-A first to create `dasnet` network |

## Contributing

Found a bug? Have a suggestion? Open an issue!

## License

MIT License - Use freely for learning and commercial projects.
