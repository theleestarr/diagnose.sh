#!/bin/bash

# AIME Project Diagnostic Script
# This script performs comprehensive diagnostics of the AIME project
# and helps identify potential issues and their solutions.

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print section headers
print_section() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

# Function to print status with explanation
print_status() {
    if [ "$2" = "success" ]; then
        echo -e "${GREEN}✓ $1${NC}"
    elif [ "$2" = "warning" ]; then
        echo -e "${YELLOW}⚠ $1${NC}"
    else
        echo -e "${RED}✗ $1${NC}"
    fi
}

# Function to check if a command exists
check_command() {
    if command -v $1 &> /dev/null; then
        print_status "$1 is installed" "success"
    else
        print_status "$1 is not installed" "error"
    fi
}

# Function to check if a port is in use
check_port() {
    if lsof -i :$1 &> /dev/null; then
        print_status "Port $1 is in use" "warning"
        lsof -i :$1
    else
        print_status "Port $1 is available" "success"
    fi
}

# Function to check Docker container status
check_container() {
    if docker ps -a | grep -q $1; then
        if docker ps | grep -q $1; then
            print_status "Container $1 is running" "success"
        else
            print_status "Container $1 exists but is not running" "warning"
        fi
    else
        print_status "Container $1 does not exist" "error"
    fi
}

# Function to check service logs
check_logs() {
    print_section "Recent logs for $1"
    docker logs --tail 50 $1 2>&1 | grep -i "error\|warn\|fail"
}

# Function to check network connectivity
check_network() {
    print_section "Network connectivity for $1"
    if docker exec $1 ping -c 1 $2 &> /dev/null; then
        print_status "Can reach $2 from $1" "success"
    else
        print_status "Cannot reach $2 from $1" "error"
    fi
}

# Function to check file existence
check_file() {
    if [ -f "$1" ]; then
        print_status "File $1 exists" "success"
    else
        print_status "File $1 is missing" "error"
    fi
}

# Function to check directory structure
check_directory() {
    print_section "Checking directory structure"
    for dir in "services" "monitoring" "docs" "scripts" "models" "data" "configs"; do
        if [ -d "$dir" ]; then
            print_status "Directory $dir exists" "success"
        else
            print_status "Directory $dir is missing" "error"
        fi
    done
}

# Function to check environment variables
check_env() {
    print_section "Checking environment variables"
    if [ -f ".env" ]; then
        print_status ".env file exists" "success"
        # Check for required variables
        required_vars=(
            "OPENAI_API_KEY"
            "MONGODB_URI"
            "REDIS_URL"
            "MODEL_PATH"
            "API_PORT"
            "WORKER_CONCURRENCY"
            "LOG_LEVEL"
            "ENVIRONMENT"
        )
        for var in "${required_vars[@]}"; do
            if grep -q "^$var=" .env; then
                print_status "$var is set" "success"
            else
                print_status "$var is not set" "error"
            fi
        done
    else
        print_status ".env file is missing" "error"
    fi
}

# Function to check GPU status
check_gpu() {
    print_section "Checking GPU status"
    if command -v nvidia-smi &> /dev/null; then
        nvidia-smi
        # Check GPU memory usage
        print_section "GPU Memory Usage"
        nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits | while read -r used total; do
            usage_percent=$((used * 100 / total))
            if [ $usage_percent -gt 90 ]; then
                print_status "GPU memory usage is high: ${usage_percent}%" "warning"
            else
                print_status "GPU memory usage: ${usage_percent}%" "success"
            fi
        done
    else
        print_status "nvidia-smi not found" "warning"
    fi
}

# Function to check monitoring stack
check_monitoring() {
    print_section "Checking monitoring stack"
    services=("prometheus" "grafana" "nvidia-dcgm-exporter" "alertmanager")
    for service in "${services[@]}"; do
        check_container $service
    done
    
    # Check Prometheus targets
    print_section "Prometheus targets"
    curl -s localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, state: .health}'
}

# Function to check AIME services
check_aime_services() {
    print_section "Checking AIME services"
    services=("project_aime-api-1" "project_aime-worker-1" "project_aime-redis-1" "project_aime-mongodb-1")
    for service in "${services[@]}"; do
        check_container $service
    done
}

# Function to check API health
check_api_health() {
    print_section "Checking API Health"
    if curl -s http://localhost:8000/health | grep -q "ok"; then
        print_status "API is healthy" "success"
    else
        print_status "API health check failed" "error"
    fi
    
    # Check API endpoints
    print_section "API Endpoints"
    endpoints=("/health" "/status" "/metrics" "/docs")
    for endpoint in "${endpoints[@]}"; do
        if curl -s -o /dev/null -w "%{http_code}" http://localhost:8000$endpoint | grep -q "200"; then
            print_status "Endpoint $endpoint is accessible" "success"
        else
            print_status "Endpoint $endpoint is not accessible" "error"
        fi
    done
}

# Function to check worker status
check_worker_status() {
    print_section "Checking Worker Status"
    # Check worker queue
    if docker exec project_aime-redis-1 redis-cli LLEN worker_queue | grep -q "^[0-9]*$"; then
        queue_size=$(docker exec project_aime-redis-1 redis-cli LLEN worker_queue)
        if [ $queue_size -gt 100 ]; then
            print_status "Worker queue is large: $queue_size items" "warning"
        else
            print_status "Worker queue size: $queue_size items" "success"
        fi
    else
        print_status "Could not check worker queue" "error"
    fi
    
    # Check worker processes
    worker_count=$(docker exec project_aime-worker-1 ps aux | grep -c "worker")
    if [ $worker_count -gt 0 ]; then
        print_status "Worker processes running: $worker_count" "success"
    else
        print_status "No worker processes running" "error"
    fi
}

# Function to check model status
check_model_status() {
    print_section "Checking Model Status"
    # Check model files
    if [ -d "models" ]; then
        model_files=$(find models -type f -name "*.pt" -o -name "*.bin" | wc -l)
        if [ $model_files -gt 0 ]; then
            print_status "Found $model_files model files" "success"
        else
            print_status "No model files found" "warning"
        fi
    else
        print_status "Models directory not found" "error"
    fi
    
    # Check model loading
    if curl -s http://localhost:8000/models/status | grep -q "loaded"; then
        print_status "Models are loaded" "success"
    else
        print_status "Models are not loaded" "error"
    fi
}

# Function to check database status
check_database_status() {
    print_section "Checking Database Status"
    # Check MongoDB
    if docker exec project_aime-mongodb-1 mongosh --eval "db.adminCommand('ping')" | grep -q "ok"; then
        print_status "MongoDB is running" "success"
        # Check collections
        collections=$(docker exec project_aime-mongodb-1 mongosh --eval "db.getCollectionNames()" | grep -c "conversations")
        if [ $collections -gt 0 ]; then
            print_status "Required collections exist" "success"
        else
            print_status "Missing required collections" "warning"
        fi
    else
        print_status "MongoDB is not responding" "error"
    fi
    
    # Check Redis
    if docker exec project_aime-redis-1 redis-cli ping | grep -q "PONG"; then
        print_status "Redis is running" "success"
        # Check memory usage
        memory_used=$(docker exec project_aime-redis-1 redis-cli info memory | grep "used_memory_human" | cut -d: -f2)
        print_status "Redis memory usage: $memory_used" "success"
    else
        print_status "Redis is not responding" "error"
    fi
}

# Function to check documentation
check_docs() {
    print_section "Checking documentation"
    docs=(
        "README.md"
        "docs/PHASE1_STATUS.md"
        "docs/PHASE2_STATUS.md"
        "docs/PHASE3_STATUS.md"
        "docs/API.md"
        "docs/ARCHITECTURE.md"
        "docs/DEPLOYMENT.md"
        "docs/TROUBLESHOOTING.md"
    )
    for doc in "${docs[@]}"; do
        check_file $doc
    done
}

# Function to check Triton status
check_triton_status() {
    print_section "Checking Triton Inference Server"
    
    # Check if Triton container is running
    check_container "triton"
    
    # Check Triton server health
    if curl -s http://localhost:8000/v2/health/ready | grep -q "ready"; then
        print_status "Triton server is ready" "success"
    else
        print_status "Triton server is not ready" "error"
    fi
    
    # Check model repository
    print_section "Triton Model Repository"
    if [ -d "models/triton" ]; then
        model_count=$(find models/triton -maxdepth 1 -type d | wc -l)
        if [ $model_count -gt 1 ]; then
            print_status "Found $((model_count-1)) models in repository" "success"
            # List models
            for model in $(find models/triton -maxdepth 1 -type d -not -path "models/triton"); do
                model_name=$(basename $model)
                if curl -s http://localhost:8000/v2/models/$model_name/ready | grep -q "ready"; then
                    print_status "Model $model_name is ready" "success"
                else
                    print_status "Model $model_name is not ready" "warning"
                fi
            done
        else
            print_status "No models found in repository" "warning"
        fi
    else
        print_status "Triton model repository not found" "error"
    fi
    
    # Check model statistics
    print_section "Triton Model Statistics"
    if curl -s http://localhost:8000/v2/models/stats | jq -e . >/dev/null 2>&1; then
        print_status "Model statistics available" "success"
        # Check inference statistics
        inference_stats=$(curl -s http://localhost:8000/v2/models/stats | jq '.model_stats[].inference_stats')
        if [ ! -z "$inference_stats" ]; then
            print_status "Inference statistics collected" "success"
            # Display execution count
            exec_count=$(echo $inference_stats | jq '.execution_count')
            print_status "Total executions: $exec_count" "success"
            # Check for errors
            error_count=$(echo $inference_stats | jq '.inference_stats.error.count')
            if [ "$error_count" -gt 0 ]; then
                print_status "Inference errors detected: $error_count" "warning"
            fi
        fi
    else
        print_status "Could not fetch model statistics" "warning"
    fi
    
    # Check GPU utilization for Triton
    print_section "Triton GPU Utilization"
    if command -v nvidia-smi &> /dev/null; then
        triton_gpu_util=$(nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv,noheader | grep triton)
        if [ ! -z "$triton_gpu_util" ]; then
            print_status "Triton GPU utilization found" "success"
            echo "$triton_gpu_util"
        else
            print_status "No Triton GPU utilization found" "warning"
        fi
    fi
    
    # Check model configuration
    print_section "Triton Model Configuration"
    for model in $(find models/triton -maxdepth 1 -type d -not -path "models/triton"); do
        model_name=$(basename $model)
        if [ -f "$model/config.pbtxt" ]; then
            print_status "Config found for $model_name" "success"
            # Check instance groups
            if grep -q "instance_group" "$model/config.pbtxt"; then
                print_status "Instance groups configured for $model_name" "success"
            else
                print_status "No instance groups configured for $model_name" "warning"
            fi
            # Check dynamic batching
            if grep -q "dynamic_batching" "$model/config.pbtxt"; then
                print_status "Dynamic batching enabled for $model_name" "success"
            fi
        else
            print_status "No config found for $model_name" "warning"
        fi
    done
}

# Function to list all services
list_all_services() {
    print_section "AIME Project Services"
    
    # Core Services
    print_section "Core Services"
    core_services=(
        "project_aime-api-1"
        "project_aime-worker-1"
        "project_aime-redis-1"
        "project_aime-mongodb-1"
        "project_aime-nginx-1"
    )
    for service in "${core_services[@]}"; do
        check_container $service
    done
    
    # Monitoring Services
    print_section "Monitoring Services"
    monitoring_services=(
        "prometheus"
        "grafana"
        "nvidia-dcgm-exporter"
        "alertmanager"
        "node-exporter"
        "cadvisor"
    )
    for service in "${monitoring_services[@]}"; do
        check_container $service
    done
    
    # AI/ML Services
    print_section "AI/ML Services"
    ai_services=(
        "triton"
        "project_aime-knowledge-indexer-1"
        "project_aime-embedding-service-1"
        "project_aime-model-manager-1"
    )
    for service in "${ai_services[@]}"; do
        check_container $service
    done
    
    # Storage Services
    print_section "Storage Services"
    storage_services=(
        "project_aime-minio-1"
        "project_aime-chroma-1"
    )
    for service in "${storage_services[@]}"; do
        check_container $service
    done
    
    # Utility Services
    print_section "Utility Services"
    utility_services=(
        "project_aime-scheduler-1"
        "project_aime-backup-1"
        "project_aime-log-aggregator-1"
    )
    for service in "${utility_services[@]}"; do
        check_container $service
    done
    
    # Check service dependencies
    print_section "Service Dependencies"
    dependencies=(
        "Redis -> API"
        "MongoDB -> API"
        "Redis -> Worker"
        "MongoDB -> Worker"
        "MinIO -> Knowledge Indexer"
        "Chroma -> Knowledge Indexer"
        "Redis -> Scheduler"
        "MongoDB -> Backup"
    )
    for dep in "${dependencies[@]}"; do
        source=$(echo $dep | cut -d' ' -f1)
        target=$(echo $dep | cut -d' ' -f3)
        if docker exec project_aime-$source-1 ping -c 1 project_aime-$target-1 &> /dev/null; then
            print_status "Dependency $source -> $target is healthy" "success"
        else
            print_status "Dependency $source -> $target is broken" "error"
        fi
    done
    
    # Check service logs for errors
    print_section "Service Error Logs"
    for service in $(docker ps --format "{{.Names}}"); do
        print_section "Recent errors in $service"
        docker logs --tail 50 $service 2>&1 | grep -i "error\|warn\|fail\|exception" | tail -n 5
    done
    
    # Check service resource usage
    print_section "Service Resource Usage"
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"
}

# Function to check API service
check_api_service() {
    print_section "API Service Diagnostics"
    local api_container="project_aime-api-1"
    
    # Check container
    check_container $api_container
    
    # Check API endpoints
    local endpoints=(
        "/health"
        "/status"
        "/metrics"
        "/docs"
        "/v1/models"
        "/v1/chat"
        "/v1/embeddings"
    )
    
    for endpoint in "${endpoints[@]}"; do
        if curl -s -o /dev/null -w "%{http_code}" http://localhost:8000$endpoint | grep -q "200"; then
            print_status "Endpoint $endpoint is accessible" "success"
        else
            print_status "Endpoint $endpoint is not accessible" "error"
        fi
    done
    
    # Check API dependencies
    if docker exec $api_container curl -s redis:6379 | grep -q "PONG"; then
        print_status "Redis connection is healthy" "success"
    else
        print_status "Redis connection failed" "error"
    fi
    
    if docker exec $api_container curl -s mongodb:27017 | grep -q "MongoDB"; then
        print_status "MongoDB connection is healthy" "success"
    else
        print_status "MongoDB connection failed" "error"
    fi
}

# Function to check Worker service
check_worker_service() {
    print_section "Worker Service Diagnostics"
    local worker_container="project_aime-worker-1"
    
    # Check container
    check_container $worker_container
    
    # Check worker processes
    local worker_count=$(docker exec $worker_container ps aux | grep -c "worker")
    if [ $worker_count -gt 0 ]; then
        print_status "Worker processes running: $worker_count" "success"
    else
        print_status "No worker processes running" "error"
    fi
    
    # Check queue status
    local queue_size=$(docker exec project_aime-redis-1 redis-cli LLEN worker_queue)
    print_status "Queue size: $queue_size" "success"
    
    # Check worker logs for errors
    print_section "Worker Error Logs"
    docker logs --tail 50 $worker_container 2>&1 | grep -i "error\|warn\|fail\|exception" | tail -n 5
}

# Function to check Redis service
check_redis_service() {
    print_section "Redis Service Diagnostics"
    local redis_container="project_aime-redis-1"
    
    # Check container
    check_container $redis_container
    
    # Check Redis info
    print_section "Redis Information"
    docker exec $redis_container redis-cli info | grep -E "used_memory|connected_clients|total_connections_received|total_commands_processed"
    
    # Check memory usage
    local memory_used=$(docker exec $redis_container redis-cli info memory | grep "used_memory_human" | cut -d: -f2)
    print_status "Memory usage: $memory_used" "success"
    
    # Check persistence
    if docker exec $redis_container redis-cli info persistence | grep -q "rdb_last_save_time"; then
        print_status "RDB persistence is configured" "success"
    else
        print_status "RDB persistence is not configured" "warning"
    fi
}

# Function to check MongoDB service
check_mongodb_service() {
    print_section "MongoDB Service Diagnostics"
    local mongodb_container="project_aime-mongodb-1"
    
    # Check container
    check_container $mongodb_container
    
    # Check MongoDB status
    if docker exec $mongodb_container mongosh --eval "db.adminCommand('ping')" | grep -q "ok"; then
        print_status "MongoDB is running" "success"
    else
        print_status "MongoDB is not responding" "error"
    fi
    
    # Check databases
    print_section "MongoDB Databases"
    docker exec $mongodb_container mongosh --eval "db.adminCommand('listDatabases')" | grep "name"
    
    # Check collections
    print_section "MongoDB Collections"
    docker exec $mongodb_container mongosh --eval "db.getCollectionNames()"
    
    # Check storage stats
    print_section "MongoDB Storage Stats"
    docker exec $mongodb_container mongosh --eval "db.stats()" | grep -E "dataSize|storageSize|indexSize"
}

# Function to check MinIO service
check_minio_service() {
    print_section "MinIO Service Diagnostics"
    local minio_container="project_aime-minio-1"
    
    # Check container
    check_container $minio_container
    
    # Check MinIO health
    if curl -s http://localhost:9000/minio/health/live | grep -q "ok"; then
        print_status "MinIO is healthy" "success"
    else
        print_status "MinIO health check failed" "error"
    fi
    
    # Check buckets
    print_section "MinIO Buckets"
    docker exec $minio_container mc ls minio/
    
    # Check storage usage
    print_section "MinIO Storage Usage"
    docker exec $minio_container mc admin info minio/
}

# Function to check ChromaDB service
check_chroma_service() {
    print_section "ChromaDB Service Diagnostics"
    local chroma_container="project_aime-chroma-1"
    
    # Check container
    check_container $chroma_container
    
    # Check ChromaDB health
    if curl -s http://localhost:8000/api/v1/heartbeat | grep -q "ok"; then
        print_status "ChromaDB is healthy" "success"
    else
        print_status "ChromaDB health check failed" "error"
    fi
    
    # Check collections
    print_section "ChromaDB Collections"
    curl -s http://localhost:8000/api/v1/collections | jq .
    
    # Check embedding count
    print_section "ChromaDB Embeddings"
    curl -s http://localhost:8000/api/v1/count | jq .
}

# Function to check Knowledge Indexer
check_knowledge_indexer() {
    print_section "Knowledge Indexer Diagnostics"
    local indexer_container="project_aime-knowledge-indexer-1"
    
    # Check container
    check_container $indexer_container
    
    # Check service health
    if curl -s http://localhost:8000/health | grep -q "ok"; then
        print_status "Knowledge Indexer is healthy" "success"
    else
        print_status "Knowledge Indexer health check failed" "error"
    fi
    
    # Check indexing status
    print_section "Indexing Status"
    curl -s http://localhost:8000/status | jq .
    
    # Check dependencies
    if docker exec $indexer_container curl -s minio:9000/minio/health/live | grep -q "ok"; then
        print_status "MinIO connection is healthy" "success"
    else
        print_status "MinIO connection failed" "error"
    fi
    
    if docker exec $indexer_container curl -s chroma:8000/api/v1/heartbeat | grep -q "ok"; then
        print_status "ChromaDB connection is healthy" "success"
    else
        print_status "ChromaDB connection failed" "error"
    fi
}

# Function to check Embedding Service
check_embedding_service() {
    print_section "Embedding Service Diagnostics"
    local embedding_container="project_aime-embedding-service-1"
    
    # Check container
    check_container $embedding_container
    
    # Check service health
    if curl -s http://localhost:8000/health | grep -q "ok"; then
        print_status "Embedding Service is healthy" "success"
    else
        print_status "Embedding Service health check failed" "error"
    fi
    
    # Check model status
    print_section "Model Status"
    curl -s http://localhost:8000/models/status | jq .
    
    # Check GPU utilization
    if command -v nvidia-smi &> /dev/null; then
        print_section "GPU Utilization"
        nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv,noheader | grep embedding
    fi
}

# Function to check Model Manager
check_model_manager() {
    print_section "Model Manager Diagnostics"
    local manager_container="project_aime-model-manager-1"
    
    # Check container
    check_container $manager_container
    
    # Check service health
    if curl -s http://localhost:8000/health | grep -q "ok"; then
        print_status "Model Manager is healthy" "success"
    else
        print_status "Model Manager health check failed" "error"
    fi
    
    # Check model registry
    print_section "Model Registry"
    curl -s http://localhost:8000/models | jq .
    
    # Check model versions
    print_section "Model Versions"
    curl -s http://localhost:8000/models/versions | jq .
}

# Function to check Scheduler
check_scheduler() {
    print_section "Scheduler Diagnostics"
    local scheduler_container="project_aime-scheduler-1"
    
    # Check container
    check_container $scheduler_container
    
    # Check service health
    if curl -s http://localhost:8000/health | grep -q "ok"; then
        print_status "Scheduler is healthy" "success"
    else
        print_status "Scheduler health check failed" "error"
    fi
    
    # Check scheduled tasks
    print_section "Scheduled Tasks"
    curl -s http://localhost:8000/tasks | jq .
    
    # Check task history
    print_section "Task History"
    curl -s http://localhost:8000/tasks/history | jq .
}

# Function to check Backup Service
check_backup_service() {
    print_section "Backup Service Diagnostics"
    local backup_container="project_aime-backup-1"
    
    # Check container
    check_container $backup_container
    
    # Check backup status
    print_section "Backup Status"
    docker exec $backup_container ls -l /backups
    
    # Check backup schedule
    print_section "Backup Schedule"
    docker exec $backup_container crontab -l
    
    # Check backup logs
    print_section "Backup Logs"
    docker logs --tail 50 $backup_container 2>&1 | grep -i "backup\|error\|warn\|fail"
}

# Function to check Log Aggregator
check_log_aggregator() {
    print_section "Log Aggregator Diagnostics"
    local log_container="project_aime-log-aggregator-1"
    
    # Check container
    check_container $log_container
    
    # Check log collection
    print_section "Log Collection Status"
    curl -s http://localhost:8000/status | jq .
    
    # Check log storage
    print_section "Log Storage"
    docker exec $log_container ls -l /logs
    
    # Check log rotation
    print_section "Log Rotation"
    docker exec $log_container ls -l /logs/rotated
}

# Function to generate service summary
generate_service_summary() {
    print_section "Service Status Summary"
    echo -e "\nStatus Legend:"
    echo -e "${GREEN}✓ Success${NC} - Service is functioning normally"
    echo -e "${YELLOW}⚠ Warning${NC} - Service is running but has potential issues"
    echo -e "${RED}✗ Error${NC} - Service has critical issues that need attention"
    
    echo -e "\nService Status Overview:"
    echo "----------------------------------------"
    printf "%-30s %-10s %-10s %-10s\n" "Service" "Success" "Warning" "Error"
    echo "----------------------------------------"
    
    for service in $(docker ps --format "{{.Names}}"); do
        success_count=$(grep -c "✓" <<< "$(docker logs --tail 100 $service 2>&1)")
        warning_count=$(grep -c "⚠" <<< "$(docker logs --tail 100 $service 2>&1)")
        error_count=$(grep -c "✗" <<< "$(docker logs --tail 100 $service 2>&1)")
        printf "%-30s %-10s %-10s %-10s\n" "$service" "$success_count" "$warning_count" "$error_count"
    done
    
    echo "----------------------------------------"
    echo -e "\nNote: A service is considered healthy if:"
    echo "1. Container is running"
    echo "2. Health check passes"
    echo "3. No critical errors in logs"
    echo "4. Dependencies are accessible"
    echo -e "\nWarnings are acceptable and don't indicate failure:"
    echo "- High resource usage"
    echo "- Non-critical configuration issues"
    echo "- Expected error conditions"
    echo -e "\nErrors require immediate attention:"
    echo "- Service crashes"
    echo "- Failed health checks"
    echo "- Critical dependency failures"
}

# Main diagnostic routine
main() {
    print_section "AIME Project Diagnostic"
    echo "Starting comprehensive diagnostic check..."
    
    # Check system requirements
    print_section "System Requirements"
    check_command "docker"
    check_command "docker-compose"
    check_command "nvidia-smi"
    check_command "jq"
    check_command "curl"
    
    # Check ports
    print_section "Port Availability"
    check_port 3000  # Grafana
    check_port 9090  # Prometheus
    check_port 9400  # DCGM Exporter
    check_port 8000  # API
    check_port 6379  # Redis
    check_port 27017 # MongoDB
    
    # Check directory structure
    check_directory
    
    # Check environment
    check_env
    
    # Check GPU
    check_gpu
    
    # Check monitoring stack
    check_monitoring
    
    # Check AIME services
    check_aime_services
    
    # Check API health
    check_api_health
    
    # Check worker status
    check_worker_status
    
    # Check model status
    check_model_status
    
    # Check database status
    check_database_status
    
    # Check documentation
    check_docs
    
    # Check Triton status
    check_triton_status
    
    # Check logs for errors
    print_section "Recent Errors in Logs"
    for service in $(docker ps --format "{{.Names}}"); do
        check_logs $service
    done
    
    # List all services
    list_all_services
    
    # Run service-specific diagnostics
    check_api_service
    check_worker_service
    check_redis_service
    check_mongodb_service
    check_minio_service
    check_chroma_service
    check_knowledge_indexer
    check_embedding_service
    check_model_manager
    check_scheduler
    check_backup_service
    check_log_aggregator
    
    # Generate summary at the end
    generate_service_summary
    
    print_section "Diagnostic Complete"
    echo "Please review the output above for any issues."
    echo "For more detailed information, check the logs of specific services."
    echo "Common issues and solutions can be found in docs/TROUBLESHOOTING.md"
}

# Run the diagnostic
main 
