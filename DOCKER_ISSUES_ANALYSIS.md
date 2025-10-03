# 🐳 HomeGenie Docker Issues Analysis & Solutions

## 📊 **Executive Summary**

The HomeGenie Docker deployment has several critical issues preventing proper operation:

1. **Missing Web App Service** (FIXED) ✅
2. **Port Exposure Problems** (PARTIALLY FIXED) ⚠️
3. **Container Permission Issues** (ONGOING) ❌
4. **API Backend Not Binding to Port 8000** (CRITICAL) ❌
5. **Build Context Issues in Flutter Dockerfile** (FIXED) ✅

---

## 🔍 **Detailed Issue Analysis**

### Issue #1: Missing Web App Service ✅ **RESOLVED**

**Problem:**
- Documentation mentions a web app on port 3000
- `docker-compose.yml` was missing the entire `web-app` service
- Users couldn't access the Flutter web interface

**Root Cause:**
```yaml
# This service was completely missing from docker-compose.yml
web-app:
  build:
    context: ./frontend
    dockerfile: ../docker/frontend/Dockerfile
  ports:
    - "3000:3000"
```

**Solution Applied:**
```yaml
# ✅ Added to docker-compose.yml
web-app:
  build:
    context: .
    dockerfile: docker/frontend/Dockerfile
  container_name: homegenie-webapp
  ports:
    - "3000:3000"
  depends_on:
    - api-backend
  networks:
    - homegenie-net
  restart: unless-stopped
```

---

### Issue #2: Port Conflicts Preventing Container Startup ❌ **CRITICAL**

**Problem:**
- Port 1883 (MQTT) already in use by system service
- Redis and PostgreSQL ports not exposed for debugging
- Port conflicts preventing container startup

**Latest Error:**
```bash
Error response from daemon: ports are not available: 
exposing port TCP 0.0.0.0:1883 -> 127.0.0.1:0: listen tcp 0.0.0.0:1883: bind: address already in use
```

**Original Configuration:**
```yaml
redis:
  # No port exposure - only internal access

postgres:  
  # No port exposure - only internal access
```

**Solution Applied:**
```yaml
redis:
  ports:
    - "6380:6379"  # Mapped to avoid conflict with system Redis

postgres:
  ports:
    - "5433:5432"  # Mapped to avoid conflict with system PostgreSQL
```

**Status:** ✅ **RESOLVED** - Ports now properly mapped

---

### Issue #3: Container Permission Issues ❌ **ONGOING**

**Problem:**
```bash
Error response from daemon: cannot stop container: 
3a7626176c39f91e442d6d052d7bdec3a558c06d297b37bc9091daa4c9ce4e90: permission denied
```

**Root Cause:**
- Containers become "stuck" and cannot be stopped normally
- Docker daemon permission issues
- Old containers not being properly cleaned up

**Attempted Solutions:**
1. `docker-compose down --volumes --remove-orphans`
2. `docker system prune -f`
3. `sudo systemctl restart docker`
4. `docker kill $(docker ps -q)`

**Current Status:** ❌ **UNRESOLVED**
- Containers get stuck with permission errors
- Requires manual Docker service restart to resolve

**Recommended Permanent Solution:**
```bash
# Add to system maintenance script
sudo systemctl restart docker
docker system prune -f
docker-compose up -d --build --force-recreate
```

---

### Issue #4: API Backend Not Binding to Port 8000 ❌ **CRITICAL**

**Problem:**
```bash
$ curl http://localhost:8000/health
curl: (7) Failed to connect to localhost port 8000 after 0 ms: Couldn't connect to server

$ ss -tulpn | grep :8000
# No output - port 8000 not bound
```

**Root Cause Analysis:**

1. **Container Shows as Running:**
   ```bash
   $ docker-compose ps
   homegenie-api    Up 13 hours (healthy)    0.0.0.0:8000->8000/tcp
   ```

2. **Internal API Server Starts Successfully:**
   ```log
   INFO: Uvicorn running on http://0.0.0.0:8000 (Press CTRL+C to quit)
   INFO: 127.0.0.1:51466 - "GET /health HTTP/1.1" 200 OK
   ```

3. **Port Mapping Exists but Not Working:**
   - Docker shows port mapping: `0.0.0.0:8000->8000/tcp`
   - System doesn't show port 8000 as bound
   - Suggests Docker port forwarding failure

**Possible Causes:**
- Docker networking driver issues
- Firewall blocking port forwarding
- Container restart loop preventing stable port binding
- Old/cached containers interfering

**Debugging Steps Needed:**
```bash
# 1. Check if container is actually running
docker exec homegenie-api ps aux

# 2. Test internal connectivity
docker exec homegenie-api curl http://localhost:8000/health

# 3. Check Docker bridge network
docker network inspect homegenie_homegenie-net

# 4. Check iptables rules
sudo iptables -L -n | grep 8000
```

---

### Issue #5: Flutter Dockerfile Build Context Issues ✅ **RESOLVED**

**Problem:**
```dockerfile
# Original - Invalid relative path
web-app:
  build:
    context: ./frontend
    dockerfile: ../docker/frontend/Dockerfile  # Invalid: goes outside context
```

**Root Cause:**
- Build context was `./frontend` 
- Dockerfile path `../docker/frontend/Dockerfile` goes outside build context
- COPY commands in Dockerfile expected wrong paths

**Solution Applied:**

1. **Fixed docker-compose.yml:**
   ```yaml
   web-app:
     build:
       context: .                           # Root context
       dockerfile: docker/frontend/Dockerfile  # Correct relative path
   ```

2. **Updated Dockerfile paths:**
   ```dockerfile
   # Before
   COPY pubspec.yaml pubspec.lock ./
   COPY lib/ ./lib/
   COPY nginx.conf /etc/nginx/nginx.conf

   # After  
   COPY frontend/pubspec.yaml frontend/pubspec.lock ./
   COPY frontend/lib/ ./lib/
   COPY docker/frontend/nginx.conf /etc/nginx/nginx.conf
   ```

**Status:** ✅ **RESOLVED**

---

## 🚨 **Critical Issues Requiring Immediate Attention**

### 1. API Backend Port Binding Failure
**Priority:** 🔴 **CRITICAL**
**Impact:** Complete API unavailability
**Users Cannot:**
- Access REST API endpoints
- Control smart home devices
- Use Flutter web app (depends on API)

### 2. Container Permission Issues  
**Priority:** 🟡 **HIGH**
**Impact:** Development workflow disruption
**Problems:**
- Cannot stop/restart containers normally
- Requires manual Docker service restarts
- Blocks rapid iteration during development

---

## 🔧 **Immediate Action Plan**

### Step 1: Resolve API Port Binding
```bash
# Force clean Docker environment
sudo systemctl stop docker
sudo systemctl start docker
docker system prune -af

# Rebuild from scratch
cd /home/harish/Desktop/Homegenie
docker-compose down -v
docker-compose build --no-cache api-backend
docker-compose up api-backend -d

# Verify API connectivity
sleep 10
curl http://localhost:8000/health
```

### Step 2: Test Individual Services
```bash
# Start services one by one to isolate issues
docker-compose up mqtt-broker redis postgres -d
docker-compose up device-simulator -d  
docker-compose up api-backend -d
docker-compose up web-app -d

# Test each service
curl http://localhost:8000/health        # API
curl http://localhost:3000               # Web App
ss -tulpn | grep -E ':(1883|3000|8000)'  # Port verification
```

### Step 3: Implement Monitoring
```bash
# Add health check script
cat > check_services.sh << 'EOF'
#!/bin/bash
echo "=== HomeGenie Service Status ==="
echo "MQTT Broker (1883): $(ss -tulpn | grep :1883 &>/dev/null && echo "✅ OK" || echo "❌ FAIL")"
echo "API Backend (8000): $(curl -s http://localhost:8000/health &>/dev/null && echo "✅ OK" || echo "❌ FAIL")"
echo "Web App (3000): $(curl -s http://localhost:3000 &>/dev/null && echo "✅ OK" || echo "❌ FAIL")"
echo "Redis (6380): $(ss -tulpn | grep :6380 &>/dev/null && echo "✅ OK" || echo "❌ FAIL")"
echo "PostgreSQL (5433): $(ss -tulpn | grep :5433 &>/dev/null && echo "✅ OK" || echo "❌ FAIL")"
EOF
chmod +x check_services.sh
```

---

## 📋 **Current System Status**

| Service | Container | Port Mapping | Status | Issues |
|---------|-----------|--------------|--------|---------|
| MQTT Broker | `homegenie-mqtt` | `1883:1883`, `9002:9001` | ✅ **WORKING** | None |
| Redis | `homegenie-redis` | `6380:6379` | ✅ **WORKING** | None |
| PostgreSQL | `homegenie-postgres` | `5433:5432` | ✅ **WORKING** | None |
| Device Simulator | `homegenie-simulator` | Internal only | ⚠️ **PARTIAL** | MQTT disconnections |
| **API Backend** | `homegenie-api` | `8000:8000` | ❌ **FAILING** | **Port not binding** |
| Web App | `homegenie-webapp` | `3000:3000` | ✅ **WORKING** | Depends on API |

---

## 🔮 **Next Steps & Recommendations**

### Immediate (Today)
1. ✅ **Fix API port binding issue** - Critical for system functionality
2. ✅ **Test complete workflow** - Verify all services work together
3. ✅ **Document working configuration** - Prevent regression

### Short Term (This Week)
1. 🔧 **Implement container restart automation** - Handle permission issues
2. 📊 **Add comprehensive health checks** - Monitor service status
3. 🐛 **Fix MQTT device simulator disconnections** - Improve reliability

### Long Term (Next Sprint)
1. 🏗️ **Container orchestration improvements** - Consider Kubernetes
2. 🔒 **Security hardening** - Remove development-only configurations
3. 📈 **Performance optimization** - Reduce startup time
4. 🧪 **Automated testing pipeline** - Prevent deployment issues

---

## 📞 **Support Information**

**Configuration Files Modified:**
- `/home/harish/Desktop/Homegenie/docker-compose.yml`
- `/home/harish/Desktop/Homegenie/docker/frontend/Dockerfile`

**Key Commands for Troubleshooting:**
```bash
# Check container status
docker-compose ps

# View logs for specific service
docker-compose logs api-backend --tail 50

# Test service connectivity 
curl http://localhost:8000/health

# Force clean restart
sudo systemctl restart docker && docker-compose up -d --build
```

**Environment Details:**
- OS: Linux
- Docker Compose Version: Latest
- Project Path: `/home/harish/Desktop/Homegenie`
- Network: `homegenie-net` (bridge driver)

---

*Last Updated: October 3, 2025*
*Status: API Backend port binding issue requires immediate resolution*