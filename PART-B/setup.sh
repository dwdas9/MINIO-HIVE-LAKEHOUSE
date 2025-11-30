#!/bin/bash
# Setup Script for Crypto Analytics Learning Project
# macOS / Linux

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=========================================="
echo "Crypto Analytics - Learning Project Setup"
echo "=========================================="
echo ""

# Check if main lakehouse is running
echo "Checking if main lakehouse is running..."
minio_running=$(docker ps --filter "name=hive-minio" --filter "status=running" --format "{{.Names}}")
hive_running=$(docker ps --filter "name=hive-metastore" --filter "status=running" --format "{{.Names}}")

if [ -z "$minio_running" ] || [ -z "$hive_running" ]; then
    echo "ERROR: Main lakehouse is not running!"
    echo ""
    echo "Please start the main lakehouse first:"
    echo "  cd .."
    echo "  ./start.sh"
    echo ""
    exit 1
fi

echo "Main lakehouse is running"
echo ""

# Check if dasnet network exists
echo "Checking Docker network..."
network_exists=$(docker network ls --filter "name=dasnet" --format "{{.Name}}")

if [ -z "$network_exists" ]; then
    echo "ERROR: Network 'dasnet' does not exist!"
    echo ""
    echo "The network should have been created by the main lakehouse."
    echo "Please run the main setup first:"
    echo "  cd .."
    echo "  ./setup.sh"
    echo ""
    exit 1
fi

echo "Network 'dasnet' exists"
echo ""

# Start Kafka stack
echo "Starting Kafka, Zookeeper, and Crypto Producer..."
docker-compose up -d

echo ""
echo "Waiting for Kafka to be ready..."
sleep 15

# Check if services are healthy
kafka_healthy=$(docker ps --filter "name=crypto-kafka" --filter "health=healthy" --format "{{.Names}}")

if [ -n "$kafka_healthy" ]; then
    echo "Kafka is healthy"
else
    echo "WARNING: Kafka might still be starting up..."
    echo "Check status with: docker-compose ps"
fi

echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Services Available:"
echo "  Kafka UI:        http://localhost:8080"
echo "  Kafka Broker:    localhost:9092"
echo "  Zookeeper:       localhost:2181"
echo ""
echo "Next Steps:"
echo "  1. Open Kafka UI to see live messages: http://localhost:8080"
echo "  2. Check producer logs: docker logs crypto-producer -f"
echo "  3. Read Phase 1 documentation: data-modeling/schema-design.md"
echo ""
echo "To stop:"
echo "  docker-compose stop"
echo ""
