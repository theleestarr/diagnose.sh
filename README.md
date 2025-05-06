# AIME Project Diagnostic Script

The `diagnose.sh` script is a comprehensive diagnostic tool for the AIME project that checks the health and status of all services, dependencies, and configurations.

## Features

- System requirements verification
- Port availability checks
- Directory structure validation
- Environment variable validation
- GPU status and utilization monitoring
- Service health checks
- Database status verification
- Monitoring stack status
- Resource usage tracking
- Error log analysis

## Usage

```bash
./scripts/diagnose.sh
```

## Output Sections

### System Requirements
Checks for required system tools:
- Docker
- Docker Compose
- NVIDIA drivers (nvidia-smi)
- jq
- curl

### Port Availability
Verifies that required ports are available:
- 3000 (Web UI)
- 9090 (Metrics)
- 9400 (Monitoring)
- 8000 (API)
- 6379 (Redis)
- 27017 (MongoDB)

### Directory Structure
Validates the presence of required directories:
- services/
- monitoring/
- docs/
- scripts/
- models/
- data/
- configs/

### Environment Variables
Checks for required environment variables:
- OPENAI_API_KEY
- MONGODB_URI
- REDIS_URL
- MODEL_PATH
- API_PORT
- WORKER_CONCURRENCY
- LOG_LEVEL
- ENVIRONMENT

### GPU Status
- GPU model and driver information
- Memory usage
- Temperature
- Power consumption
- Running processes

### Service Status
Checks the status of all AIME services:
- API Gateway
- Worker
- Redis
- MongoDB
- Monitoring stack
- AI/ML services
- Storage services
- Utility services

### Database Status
- MongoDB connection and collections
- Redis connection and memory usage
- Database health metrics

### Monitoring Stack
- Prometheus status
- Grafana status
- Metrics collection
- Alerting configuration

### Resource Usage
- CPU utilization
- Memory usage
- Network I/O
- Disk I/O

### Error Logs
- Recent errors from all services
- Critical issues
- Warning messages

## Status Indicators

- ✓ Success - Service is functioning normally
- ⚠ Warning - Service is running but has potential issues
- ✗ Error - Service has critical issues that need attention

## Troubleshooting

If you encounter issues:

1. Check the error logs section for specific error messages
2. Verify all environment variables are set correctly
3. Ensure all required ports are available
4. Check system resource usage
5. Verify service dependencies are running
6. Consult docs/TROUBLESHOOTING.md for common issues and solutions

## Requirements

- Linux/Unix environment
- Bash shell
- Docker and Docker Compose installed
- Required system tools (jq, curl)
- NVIDIA drivers (for GPU monitoring)

## Contributing

To add new diagnostic checks:

1. Add the check to the appropriate section in diagnose.sh
2. Update this README with the new check's description
3. Test the new check thoroughly
4. Submit a pull request

## License

This script is part of the AIME project and is subject to the project's license terms.
