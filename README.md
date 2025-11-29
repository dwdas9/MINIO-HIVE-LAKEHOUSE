# MinIO + Hive Metastore + Iceberg Lakehouse
This repository provides a Docker-based setup for a data lakehouse using Apache Iceberg, with MinIO for object storage and Hive Metastore as the catalog. It includes a Jupyter notebook environment with PySpark for interactive querying and data manipulation.

## Why This Setup?

If you've tried the Polaris-based setup, you know the pain - every time the container restarts, you get new credentials and have to reconfigure everything. That's fine for a demo, but annoying for actual development work.

This setup uses Hive Metastore instead. It's been around for 15+ years, runs at thousands of companies, and Just Works™. Start it once, use it forever. Your tables, your data, your catalogs - everything persists.

## What We're Building

Same architecture as the Polaris setup, just with a different catalog:

```
┌─────────────┐     ┌──────────────────┐     ┌─────────┐
│   Jupyter   │────▶│  Spark + Iceberg │────▶│  MinIO  │
│  Notebook   │     │                  │     │ (data)  │
└─────────────┘     └────────┬─────────┘     └─────────┘
                             │
                             ▼
                    ┌──────────────────┐
                    │  Hive Metastore  │
                    │    (catalog)     │
                    └────────┬─────────┘
                             │
                             ▼
                    ┌──────────────────┐
                    │    PostgreSQL    │
                    │   (metadata)     │
                    └──────────────────┘
```

**How it flows:**
1. You write SQL in Jupyter
2. Spark asks Hive Metastore "where's this table?"
3. Hive checks PostgreSQL and returns the location
4. Spark reads Iceberg metadata from MinIO to find data files
5. Spark reads/writes Parquet files directly to MinIO

## Polaris vs Hive Metastore - What's the Difference?

Both are catalogs - they track what tables exist and where the data lives. The architecture is identical, just swapping the catalog component.

| Aspect | Polaris | Hive Metastore |
|--------|---------|----------------|
| **Credentials** | Regenerates on every restart | Static, never changes |
| **After restart** | Run setup script, update notebooks | Just start containers |
| **Maturity** | Newer, still evolving | 15+ years in production |
| **Protocol** | REST API | Thrift |
| **Access control** | Built-in, granular | Needs external tools (Ranger) |
| **Modern features** | Multi-catalog, view support | Basic catalog operations |

**When to use Polaris:** You need fine-grained access control, multi-catalog organization, or want the newest features.

**When to use Hive Metastore:** You want stability, zero maintenance, and don't want to deal with credential rotation. Perfect for learning and development.

For most learning and development scenarios, Hive Metastore is the pragmatic choice. It's boring in the best way - you set it up once and forget it exists.

## Quick Start

Just run the start script:

```bash
./start.sh
```

That's it. The script downloads required JARs (first run only), starts all containers, and waits for everything to be healthy.

Open http://localhost:8888 and run `notebooks/getting_started.ipynb`.

### Manual Start (if you prefer)

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

## Services

| Service | URL | Purpose |
|---------|-----|---------|
| Jupyter | http://localhost:8888 | Write and run Spark SQL |
| MinIO Console | http://localhost:9001 | Browse your data files |
| Spark UI | http://localhost:4040 | Monitor running jobs (active during queries) |
| Hive Metastore | localhost:9083 | Catalog service (internal) |
| PostgreSQL | localhost:5432 | Metadata storage (internal) |

**MinIO credentials:** `minioadmin` / `minioadmin`

## What Persists Across Restarts?

**Everything.** Unlike the Polaris setup, nothing is lost when you restart Docker.

Docker volumes store:
- **postgres_data** - All your databases, tables, schemas, column definitions
- **minio_data** - Your actual Parquet files and Iceberg metadata

Restart Docker, restart your machine, come back a week later - your data is exactly where you left it. No setup scripts to re-run, no credentials to update, no catalogs to recreate.

This is how production systems work. You set them up once and they keep running.

## Shutdown and Restart

```bash
# Stop everything (data persists)
./stop.sh

# Or manually:
docker-compose down
docker-compose -f spark-notebook.yml down

# Start again
./start.sh

# Or manually:
docker-compose up -d
docker-compose -f spark-notebook.yml up -d
```

## Complete Cleanup

To wipe everything and start completely fresh:

```bash
./cleanup.sh

# Or manually:
docker-compose down -v
docker-compose -f spark-notebook.yml down -v
```

The `-v` flag removes the Docker volumes, which is where your data lives.

## Why These Specific JARs?

The `apache/hive:4.0.0` Docker image is minimal - it doesn't include drivers for PostgreSQL or S3-compatible storage. We mount three JARs:

| JAR | Purpose |
|-----|---------|
| `postgresql-42.6.0.jar` | JDBC driver for Hive to connect to PostgreSQL |
| `hadoop-aws-3.3.4.jar` | S3AFileSystem class for MinIO/S3 storage |
| `aws-java-sdk-bundle-1.12.262.jar` | AWS SDK that hadoop-aws depends on |

Without these, Hive Metastore fails with cryptic ClassNotFoundException errors. The `start.sh` script downloads them automatically on first run.

## Troubleshooting

### Hive Metastore won't start

**Most common cause:** Missing JARs. Check they exist:

```bash
ls -la lib/
```

You should see three JAR files. If any are missing, download them:

```bash
mkdir -p lib
curl -sL -o lib/postgresql-42.6.0.jar https://jdbc.postgresql.org/download/postgresql-42.6.0.jar
curl -sL -o lib/hadoop-aws-3.3.4.jar https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.4/hadoop-aws-3.3.4.jar
curl -sL -o lib/aws-java-sdk-bundle-1.12.262.jar https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.12.262/aws-java-sdk-bundle-1.12.262.jar
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
docker network ls | grep lakehouse
```

### MinIO bucket doesn't exist

The `minio-init` container creates the `warehouse` bucket automatically. Check if it ran:

```bash
docker-compose logs minio-init
```

Should show "Bucket warehouse created successfully".

## Project Structure

```
MINIO-HIVE-LAKEHOUSE/
├── docker-compose.yml      # PostgreSQL, MinIO, Hive Metastore
├── spark-notebook.yml      # Jupyter + Spark
├── start.sh               # Start everything
├── stop.sh                # Stop everything
├── cleanup.sh             # Remove everything including data
├── conf/
│   ├── hive-site.xml      # Hive Metastore configuration
│   ├── core-site.xml      # Hadoop S3A configuration
│   └── spark-defaults.conf # Spark + Iceberg configuration
├── lib/                   # Downloaded JARs (gitignored)
│   ├── postgresql-42.6.0.jar
│   ├── hadoop-aws-3.3.4.jar
│   └── aws-java-sdk-bundle-1.12.262.jar
└── notebooks/
    └── getting_started.ipynb
```

## What You Can Do

Once running, you have a full Iceberg lakehouse with:

- **ACID transactions** - No partial writes, no corruption
- **Schema evolution** - Add/drop/rename columns without rewriting data
- **Time travel** - Query any historical version of your data
- **Partition evolution** - Change partitioning without rewriting data
- **Hidden partitioning** - Write `WHERE date = '2024-01-01'`, not `WHERE year=2024 AND month=01 AND day=01`

Open the `getting_started.ipynb` notebook to see examples of all these features.
