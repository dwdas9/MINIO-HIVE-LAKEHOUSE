# PART-A: Core Lakehouse Infrastructure

**← [Back to Main Repository](../README.md)**

This is the **foundation layer** of the MinIO + Hive Metastore + Iceberg Lakehouse. It provides a Docker-based setup with MinIO for object storage, Hive Metastore as the catalog, PostgreSQL for metadata, and Jupyter notebook with PySpark for interactive querying. The setup is fully on-premises with no cloud dependencies, giving you better understanding of components compared to cloud services.

## Why This Setup?

The recommended approach for a lakehouse catalog using Iceberg is Polaris. However, if you've tried the Polaris-based setup, you know the pain - every time the container restarts, you get new credentials and have to reconfigure everything. This is not a practical approach. You need a solid setup that doesn't require changes every time something restarts. Hence, Hive is used as the catalog. This is also a standard setup with proven compatibility. Hive is not an odd component in the architecture.



**How it flows:**
1. You write SQL in Jupyter
2. Spark asks Hive Metastore "where's this table?"
3. Hive checks PostgreSQL and returns the location
4. Spark reads Iceberg metadata from MinIO to find data files
5. Spark reads/writes Parquet files directly to MinIO


![](images/20251130131955.png)

## Setup Instructions

**If you followed the [main README](../README.md), PART-A is already running!**


**Still here?** You probably want to set up PART-A independently or understand what's happening under the hood. Let's walk through it.

### First Time Setup (Standalone)

Setting up PART-A independently is straightforward. The setup script handles everything automatically:

**macOS / Linux:**
```bash
cd PART-A
chmod +x setup.sh
./setup.sh
```

**Windows:**
```powershell
cd PART-A
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\setup.ps1
```

**What setup does:**
- Downloads 3 required JAR files (~50MB)
- Creates all containers
- Waits for health checks
- Starts Jupyter notebook

**When it's done**, you'll see a success message and all services will be ready. Give it 30-60 seconds for health checks to pass.

**Note:** Notebooks have been moved to [PART-C](../PART-C/README.md) for better project organization. This keeps infrastructure (PART-A) separate from actual projects. Jupyter will still be accessible at http://localhost:8888 to run those project notebooks.

![](images/20251130162734.png)

### Manual Start (if you prefer)

#### macOS / Linux

```bash
# One-time setup: download required JARs
mkdir -p lib
curl -sL -o lib/postgresql-42.6.0.jar https://jdbc.postgresql.org/download/postgresql-42.6.0.jar
curl -sL -o lib/hadoop-aws-3.3.4.jar https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.4/hadoop-aws-3.3.4.jar
curl -sL -o lib/aws-java-sdk-bundle-1.12.262.jar https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.12.262/aws-java-sdk-bundle-1.12.262.jar

# Start infrastructure
docker-compose up -d

# Wait for "Starting Hive Metastore Server" in logs
docker-compose logs -f hive-metastore

# Start Jupyter (in a new terminal)
docker-compose -f spark-notebook.yml up -d
```

#### Windows (PowerShell)

```powershell
# One-time setup: download required JARs
New-Item -ItemType Directory -Path lib -Force
Invoke-WebRequest -Uri "https://jdbc.postgresql.org/download/postgresql-42.6.0.jar" -OutFile "lib\postgresql-42.6.0.jar"
Invoke-WebRequest -Uri "https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.4/hadoop-aws-3.3.4.jar" -OutFile "lib\hadoop-aws-3.3.4.jar"
Invoke-WebRequest -Uri "https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.12.262/aws-java-sdk-bundle-1.12.262.jar" -OutFile "lib\aws-java-sdk-bundle-1.12.262.jar"

# Start infrastructure
docker-compose up -d

# Wait for "Starting Hive Metastore Server" in logs
docker-compose logs -f hive-metastore

# Start Jupyter (in a new terminal)
docker-compose -f spark-notebook.yml up -d
```


## Services

Now that everything's running, here's how to access each component. Bookmark these URLs - you'll use them often:

| Service | URL | Purpose |
|---------|-----|---------|
| Jupyter | http://localhost:8888 | Write and run Spark SQL |
| MinIO Console | http://localhost:9001 | Browse your data files |
| Spark UI | http://localhost:4040 | Monitor running jobs (active during queries) |
| Hive Metastore | localhost:9083 | Catalog service (internal) |
| PostgreSQL | localhost:5432 | Metadata storage (internal) |

![](images/20251130161336.png)

**MinIO credentials:** `minioadmin` / `minioadmin`

## What Persists Across Restarts?

Here's some great news: **Everything persists.** You won't lose your work.

Unlike some other setups (looking at you, Polaris), nothing is lost when you restart Docker. Your tables, data, schemas - all safe and sound.

Docker volumes store:
- **postgres_data** - All your databases, tables, schemas, column definitions
- **minio_data** - Your actual Parquet files and Iceberg metadata

Restart Docker, restart your machine, come back a week later - your data is exactly where you left it. No setup scripts to re-run, no credentials to update, no catalogs to recreate.

**This is how production systems work.** You set them up once and they keep running.

This is how production systems work. You set them up once and they keep running.

### Auto-Restart After Machine Reboot

All containers are configured with `restart: unless-stopped`. After rebooting your machine:

1. **Docker Desktop starts automatically** (if configured in Docker settings)
2. **All containers restart automatically** in dependency order
3. **Wait 30-60 seconds** for health checks to pass
4. **Services are ready** - no manual intervention needed

**Verify all services are running:**
```bash
docker ps --filter "name=hive"
```

You should see:
-  `hive-postgres` - Running
-  `hive-minio` - Running (healthy)
-  `hive-metastore` - Running
-  `hive-spark-notebook` - Running

If any service is missing, use the start scripts:
```bash
./start.sh    # Mac/Linux
./start.ps1   # Windows
```

## Daily Usage

### macOS / Linux

```bash
# End of day - stop containers (preserves everything)
./stop.sh

# Next day - start containers again
./start.sh
```

### Windows (PowerShell)

```powershell
# End of day - stop containers (preserves everything)
.\stop.ps1

# Next day - start containers again
.\start.ps1
```

Containers are stopped but preserved. All your data, tables, and settings remain intact.

---

## Scripts Reference

| Script | When to Use | What It Does |
|--------|-------------|-------------|
| `setup.sh`/`setup.ps1` | **First time only** | Downloads JARs, creates containers, waits for health checks |
| `start.sh`/`start.ps1` | **Daily use** | Starts containers (creates if missing), much faster than setup |
| `stop.sh`/`stop.ps1` | **End of day** | Stops containers, preserves all data |
| `nuke.sh`/`nuke.ps1` | **Complete reset** | Deletes everything (containers, volumes, data) |

**Tip:** After first-time setup, always use `start.sh`/`start.ps1` for daily work. Only run setup again if you've run nuke or deleted the `lib/` folder.

## Complete Cleanup

To wipe everything and start completely fresh:

### macOS / Linux

```bash
./nuke.sh
```

### Windows (PowerShell)

```powershell
.\nuke.ps1
```

This removes all containers, volumes, and data. Run `./setup.sh` (or `.\setup.ps1` on Windows) afterwards to create fresh containers.


## Why These Specific JARs?

The `apache/hive:4.0.0` Docker image is minimal-it doesn't include drivers for PostgreSQL or S3-compatible storage. We mount three JARs:

| JAR | Purpose |
|-----|---------|
| `postgresql-42.6.0.jar` | JDBC driver for Hive to connect to PostgreSQL |
| `hadoop-aws-3.3.4.jar` | S3AFileSystem class for MinIO/S3 storage |
| `aws-java-sdk-bundle-1.12.262.jar` | AWS SDK that hadoop-aws depends on |

Without these, Hive Metastore fails with cryptic ClassNotFoundException errors. The `setup.sh` script downloads them automatically on first run.

## Troubleshooting

### Hive Metastore won't start

**Most common cause:** Missing JARs. Check they exist:

**macOS / Linux:**
```bash
ls -la lib/
```

**Windows (PowerShell):**
```powershell
Get-ChildItem lib\
```

You should see three JAR files. If any are missing, download them:

**macOS / Linux:**
```bash
mkdir -p lib
curl -sL -o lib/postgresql-42.6.0.jar https://jdbc.postgresql.org/download/postgresql-42.6.0.jar
curl -sL -o lib/hadoop-aws-3.3.4.jar https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.4/hadoop-aws-3.3.4.jar
curl -sL -o lib/aws-java-sdk-bundle-1.12.262.jar https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.12.262/aws-java-sdk-bundle-1.12.262.jar
```

**Windows (PowerShell):**
```powershell
New-Item -ItemType Directory -Path lib -Force
Invoke-WebRequest -Uri "https://jdbc.postgresql.org/download/postgresql-42.6.0.jar" -OutFile "lib\postgresql-42.6.0.jar"
Invoke-WebRequest -Uri "https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.4/hadoop-aws-3.3.4.jar" -OutFile "lib\hadoop-aws-3.3.4.jar"
Invoke-WebRequest -Uri "https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.12.262/aws-java-sdk-bundle-1.12.262.jar" -OutFile "lib\aws-java-sdk-bundle-1.12.262.jar"
```

Then restart:

```bash
docker-compose down && docker-compose up -d
```

### "ClassNotFoundException: org.postgresql.Driver"

PostgreSQL JDBC driver is missing. Download it:

```bash
curl -sL -o lib/postgresql-42.6.0.jar https://jdbc.postgresql.org/download/postgresql-42.6.0.jar
docker-compose restart hive-metastore
```

### "ClassNotFoundException: org.apache.hadoop.fs.s3a.S3AFileSystem"

Hadoop AWS JARs are missing. Download them:

```bash
curl -sL -o lib/hadoop-aws-3.3.4.jar https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.4/hadoop-aws-3.3.4.jar
curl -sL -o lib/aws-java-sdk-bundle-1.12.262.jar https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.12.262/aws-java-sdk-bundle-1.12.262.jar
docker-compose restart hive-metastore
```

### Spark can't connect to Metastore

Make sure Hive Metastore is actually running:

```bash
docker-compose logs hive-metastore | tail -20
```

Look for "Starting Hive Metastore Server". If you see errors, check the JAR files above.

Also verify both compose files use the same network:

```bash
docker network ls | grep dasnet
```

### MinIO bucket doesn't exist

The `minio-init` container creates the `warehouse` bucket automatically. Check if it ran:

```bash
docker-compose logs minio-init
```

Should show "Bucket warehouse created successfully".


## What You Can Do

Once running, you have a full Iceberg lakehouse with:

- **ACID transactions** - No partial writes, no corruption
- **Schema evolution** - Add/drop/rename columns without rewriting data
- **Time travel** - Query any historical version of your data
- **Partition evolution** - Change partitioning without rewriting data
- **Hidden partitioning** - Write `WHERE date = '2024-01-01'`, not `WHERE year=2024 AND month=01 AND day=01`

**Ready to build projects?** Check out [PART-C: Projects](../PART-C/README.md) for hands-on data engineering applications using this infrastructure.

---

## Next Steps

1. ✅ **PART-A is running** - Infrastructure ready
2. 📖 **[Set up PART-B](../PART-B/ReadMe.md)** - Add streaming capabilities
3. 🚀 **[Explore PART-C](../PART-C/README.md)** - Build data engineering projects
