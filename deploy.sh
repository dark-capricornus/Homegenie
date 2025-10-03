#!/bin/bash

# HomeGenie Docker Deployment Script
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}🏠 HomeGenie Docker Deployment${NC}"
echo "=================================="
echo ""

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check if Docker is installed
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        print_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    print_status "Docker and Docker Compose are available"
}

# Create necessary directories
create_directories() {
    print_info "Creating necessary directories..."
    
    mkdir -p "$PROJECT_DIR/docker/mosquitto/data"
    mkdir -p "$PROJECT_DIR/docker/mosquitto/log"
    mkdir -p "$PROJECT_DIR/docker/backend/data"
    mkdir -p "$PROJECT_DIR/docker/backend/logs"
    
    # Set permissions for mosquitto
    chmod -R 755 "$PROJECT_DIR/docker/mosquitto"
    
    print_status "Directories created successfully"
}

# Build and start services
start_services() {
    print_info "Building and starting HomeGenie services..."
    
    cd "$PROJECT_DIR"
    
    # Use docker-compose or docker compose based on availability
    if command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
    else
        COMPOSE_CMD="docker compose"
    fi
    
    # Build and start services
    $COMPOSE_CMD build --no-cache
    $COMPOSE_CMD up -d
    
    print_status "Services started successfully"
}

# Wait for services to be healthy
wait_for_services() {
    print_info "Waiting for services to be healthy..."
    
    cd "$PROJECT_DIR"
    
    # Determine compose command
    if command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
    else
        COMPOSE_CMD="docker compose"
    fi
    
    # Wait for MQTT broker
    print_info "Waiting for MQTT broker..."
    timeout=60
    counter=0
    
    while [ $counter -lt $timeout ]; do
        if $COMPOSE_CMD exec -T mqtt-broker mosquitto_pub -h localhost -t test -m "health-check" 2>/dev/null; then
            print_status "MQTT broker is ready"
            break
        fi
        sleep 2
        counter=$((counter + 2))
    done
    
    if [ $counter -ge $timeout ]; then
        print_warning "MQTT broker health check timed out"
    fi
    
    # Wait for API backend
    print_info "Waiting for API backend..."
    timeout=90
    counter=0
    
    while [ $counter -lt $timeout ]; do
        if curl -f http://localhost:8000/health 2>/dev/null >/dev/null; then
            print_status "API backend is ready"
            break
        fi
        sleep 3
        counter=$((counter + 3))
    done
    
    if [ $counter -ge $timeout ]; then
        print_warning "API backend health check timed out"
    fi
}

# Show service status
show_status() {
    print_info "Service Status:"
    echo ""
    
    cd "$PROJECT_DIR"
    
    # Determine compose command
    if command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
    else
        COMPOSE_CMD="docker compose"
    fi
    
    $COMPOSE_CMD ps
    
    echo ""
    print_info "Service URLs:"
    echo "  🌐 API Server:     http://localhost:8000"
    echo "  📖 API Docs:      http://localhost:8000/docs"
    echo "  📱 Web App:       http://localhost:3000"
    echo "  📡 MQTT Broker:   localhost:1883"
    echo "  🌐 MQTT WebSocket: ws://localhost:9001"
    echo ""
}

# Show logs
show_logs() {
    cd "$PROJECT_DIR"
    
    # Determine compose command
    if command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
    else
        COMPOSE_CMD="docker compose"
    fi
    
    print_info "Showing logs (Ctrl+C to exit)..."
    $COMPOSE_CMD logs -f
}

# Stop services
stop_services() {
    print_info "Stopping HomeGenie services..."
    
    cd "$PROJECT_DIR"
    
    # Determine compose command
    if command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
    else
        COMPOSE_CMD="docker compose"
    fi
    
    $COMPOSE_CMD down
    
    print_status "Services stopped successfully"
}

# Clean up everything
cleanup() {
    print_info "Cleaning up HomeGenie deployment..."
    
    cd "$PROJECT_DIR"
    
    # Determine compose command
    if command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
    else
        COMPOSE_CMD="docker compose"
    fi
    
    $COMPOSE_CMD down -v --remove-orphans
    $COMPOSE_CMD system prune -f
    
    print_status "Cleanup completed"
}

# Test the deployment
test_deployment() {
    print_info "Testing HomeGenie deployment..."
    
    # Test API health
    if curl -f http://localhost:8000/health 2>/dev/null >/dev/null; then
        print_status "API health check passed"
    else
        print_error "API health check failed"
        return 1
    fi
    
    # Test goal endpoint
    response=$(curl -s -o /dev/null -w "%{http_code}" -X POST "http://localhost:8000/goal/testuser?goal=test" 2>/dev/null)
    if [ "$response" = "200" ]; then
        print_status "Goal endpoint test passed"
    else
        print_warning "Goal endpoint test returned status: $response"
    fi
    
    # Test state endpoint
    if curl -f http://localhost:8000/state 2>/dev/null >/dev/null; then
        print_status "State endpoint test passed"
    else
        print_warning "State endpoint test failed"
    fi
    
    print_status "Deployment tests completed"
}

# Show help
show_help() {
    echo "HomeGenie Docker Deployment Script"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  start     - Build and start all services"
    echo "  stop      - Stop all services"
    echo "  restart   - Restart all services"
    echo "  status    - Show service status and URLs"
    echo "  logs      - Show service logs"
    echo "  test      - Test the deployment"
    echo "  cleanup   - Stop services and clean up"
    echo "  help      - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 start      # Start HomeGenie"
    echo "  $0 logs       # View logs"
    echo "  $0 test       # Test deployment"
    echo "  $0 cleanup    # Clean everything"
}

# Main script logic
main() {
    case "${1:-start}" in
        "start")
            check_docker
            create_directories
            start_services
            wait_for_services
            show_status
            print_info "🎉 HomeGenie deployment completed!"
            print_info "Try: curl 'http://localhost:8000/goal/user123?goal=make it cozy'"
            ;;
        "stop")
            stop_services
            ;;
        "restart")
            stop_services
            sleep 2
            start_services
            wait_for_services
            show_status
            ;;
        "status")
            show_status
            ;;
        "logs")
            show_logs
            ;;
        "test")
            test_deployment
            ;;
        "cleanup")
            cleanup
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            print_error "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"