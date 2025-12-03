# MinIO + Hive Metastore + Iceberg Lakehouse

## Overview

Welcome to my repo. Here, I tried to create a complete, production-ready data lakehouse running locally with Docker on Mac, Linux, or Windows.

**Key Specialties:**
- **On-Premises**: Fully self-hosted—no cloud dependencies. Works both on Windows and MAC(Apple silicon)
- **Open Source Stack**: Apache Iceberg, MinIO, Hive Metastore, Spark, Kafka, Airflow
- **Scalable Architecture**: Even though the design is local on docker. The same architecture can be scalled up for real production use.

**What You'll Learn:**
- Building modern data lakehouse architectures
- Managing metadata catalogs with Hive Metastore
- Real-time streaming pipelines with Kafka and Spark
- Data transformations with dbt and Spark SQL
- Orchestrating workflows with Airflow

## Start Here: Choose Your Path

This repository is organized into two main parts. **Start with PART-A first**, then optionally add PART-B.

| Part | Purpose | Documentation |
|------|---------|---------------|
| **PART-A** | Foundation layer: Storage, metadata catalog, processing engine | 📖 [Go to PART-A →](PART-A/README.md) |
| **PART-B** | Real-time analytics: Streaming, transformations, orchestration | 📖 [Go to PART-B →](PART-B/ReadMe.md) |


## Quick Start

### 1. Setup Core Infrastructure (PART-A)

**First time only:** Use setup scripts to download required JARs and create containers.

| OS         | Command(s)                                                                                  |
|------------|------------------------------------------------------------------------------------------|
| Mac/Linux  | `cd PART-A`<br>`chmod +x setup.sh`<br>`./setup.sh`                                        |
| Windows    | `cd PART-A`<br>`Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass`<br>`./setup.ps1` |

**What setup does:**
- Downloads 3 required JAR files (~50MB) to `lib/` folder
- Creates and starts all containers
- Waits for services to be healthy
- Starts Jupyter notebook

**Daily use after setup:** Use start scripts (much faster, no downloads).

| OS         | Command(s)                     |
|------------|--------------------------------|
| Mac/Linux  | `cd PART-A`<br>`./start.sh`    |
| Windows    | `cd PART-A`<br>`./start.ps1`   |

This creates the base lakehouse with MinIO, Hive, and Spark.

![](images/20251202124641.png)

### 2. Access Services

| Service            | URL                    | Credentials                |
|--------------------|------------------------|----------------------------|
| Jupyter Notebook   | http://localhost:8888  | No password                |
| MinIO Console      | http://localhost:9001  | minioadmin / minioadmin    |
| Spark UI           | http://localhost:4040  | (Active during queries)    |

### 3. Run Streaming Analytics (Optional)

Once PART-A is running, you can add real-time crypto price streaming:

| OS         | Command(s)                                                                                 |
|------------|--------------------------------------------------------------------------------------------|
| Mac/Linux  | `cd PART-B`<br>`chmod +x setup.sh`<br>`./setup.sh`                                         |
| Windows    | `cd PART-B`<br>`Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass`<br>`./setup.ps1`|

---

## Daily Workflow

After initial setup, these are the common commands you'll use to manage your lakehouse:

| Step                | Mac/Linux Command(s)           | Windows Command(s)           |
|---------------------|-------------------------------|------------------------------|
| Start PART-A        | `cd PART-A`<br>`./start.sh`   | `cd PART-A`<br>`./start.ps1` |
| Stop PART-A         | `cd PART-A`<br>`./stop.sh`    | `cd PART-A`<br>`./stop.ps1`  |
| Start PART-B        | `cd PART-B`<br>`docker-compose up -d` | `cd PART-B`<br>`docker-compose up -d` |
| Stop PART-B         | `cd PART-B`<br>`docker-compose down`  | `cd PART-B`<br>`docker-compose down`  |
| Access Jupyter      | http://localhost:8888         | http://localhost:8888        |
| Access MinIO        | http://localhost:9001         | http://localhost:9001        |
| Access Kafka UI     | http://localhost:8080         | http://localhost:8080        |

### Complete Reset (Use with Caution)

**`nuke.sh` / `nuke.ps1`** - Deletes everything and starts fresh:
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



## What Persists?

Your work is safe across restarts. Docker volumes preserve everything:

| Volume         | Description                       |
|---------------|-----------------------------------|
| postgres_data  | Table metadata and schemas        |
| minio_data     | Parquet/Iceberg data files        |

Stopping containers preserves all data. Only `./nuke.sh`/`./nuke.ps1` deletes everything.

### After Machine Restart

**Good news:** All containers now auto-restart when your machine reboots. 

All services use `restart: unless-stopped` policy, which means:
- ✅ **Automatic startup** - Containers restart when Docker starts
- ✅ **Correct order** - Dependencies respected (Postgres → Hive → Spark)
- ✅ **Data intact** - All your tables and files remain untouched
- ⏱️ **Wait 30-60 seconds** - Services need time to become healthy

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

| Issue                        | Solution/Check |
|------------------------------|----------------|
| PART-A won't start           | See [PART-A/README.md](PART-A/README.md#troubleshooting).<br>Common: missing JARs, ports in use (5432, 9000, 9001, 8888), not enough Docker memory |
| PART-B can't connect to PART-A| Ensure PART-A is running (`cd PART-A`, `docker-compose ps`). If not, restart PART-A (`./stop.sh`/`./start.sh` or `./stop.ps1`/`./start.ps1`). Then retry PART-B setup. |
| Network not found error       | Start PART-A first to create `dasnet` network |

## Contributing

Found a bug? Have a suggestion? Open an issue!

## License

MIT License - Use freely for learning and commercial projects.
