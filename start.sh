#!/bin/bash
# Start the Hive-Iceberg-MinIO Lakehouse

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$SCRIPT_DIR/lib"

# Download required JARs if not present
if [ ! -f "$SCRIPT_DIR/lib/postgresql-42.6.0.jar" ]; then
    echo "Downloading PostgreSQL JDBC driver..."
    curl -sL -o "$SCRIPT_DIR/lib/postgresql-42.6.0.jar" \
        https://jdbc.postgresql.org/download/postgresql-42.6.0.jar
    echo "✓ PostgreSQL driver downloaded"
fi

if [ ! -f "$SCRIPT_DIR/lib/hadoop-aws-3.3.4.jar" ]; then
    echo "Downloading Hadoop AWS JAR..."
    curl -sL -o "$SCRIPT_DIR/lib/hadoop-aws-3.3.4.jar" \
        https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.4/hadoop-aws-3.3.4.jar
    echo "✓ Hadoop AWS downloaded"
fi

if [ ! -f "$SCRIPT_DIR/lib/aws-java-sdk-bundle-1.12.262.jar" ]; then
    echo "Downloading AWS SDK bundle..."
    curl -sL -o "$SCRIPT_DIR/lib/aws-java-sdk-bundle-1.12.262.jar" \
        https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.12.262/aws-java-sdk-bundle-1.12.262.jar
    echo "✓ AWS SDK downloaded"
fi

echo "Starting infrastructure..."
docker-compose up -d

echo ""
echo "Waiting for Hive Metastore to be ready..."
sleep 10

# Wait for metastore
for i in {1..30}; do
    if docker-compose logs hive-metastore 2>&1 | grep -q "Starting Hive Metastore Server"; then
        echo "✓ Hive Metastore is ready!"
        break
    fi
    echo "  Waiting... ($i/30)"
    sleep 2
done

echo ""
echo "Starting Jupyter notebook..."
docker-compose -f spark-notebook.yml up -d

echo ""
echo "=========================================="
echo "Lakehouse is running!"
echo "=========================================="
echo ""
echo "  Jupyter:      http://localhost:8888"
echo "  MinIO:        http://localhost:9001"
echo "  Spark UI:     http://localhost:4040 (when running queries)"
echo ""
echo "  MinIO login:  minioadmin / minioadmin"
echo ""
echo "Open the getting_started.ipynb notebook to begin."
echo ""
