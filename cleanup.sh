#!/bin/bash
# Complete cleanup - removes all data!

echo "WARNING: This will delete all your data!"
echo ""
read -p "Are you sure? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo "Stopping and removing everything..."
docker-compose -f spark-notebook.yml down -v
docker-compose down -v

echo ""
echo "=========================================="
echo "Cleanup complete."
echo "=========================================="
echo ""
echo "All containers, volumes, and data removed."
echo "Run ./start.sh to start fresh."
echo ""
