#!/bin/bash
# Stop the Hive-Iceberg-MinIO Lakehouse

echo "Stopping Jupyter notebook..."
docker-compose -f spark-notebook.yml down

echo "Stopping infrastructure..."
docker-compose down

echo ""
echo "=========================================="
echo "Lakehouse stopped."
echo "=========================================="
echo ""
echo "Your data is preserved in Docker volumes."
echo "Run ./start.sh to start again."
echo ""
