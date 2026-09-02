#!/bin/bash

# Test connection from your phone to laptop server
echo "Testing connection to laptop server at 10.128.184.195..."
echo ""

# Test main API
echo "1. Testing AI Service (port 8000):"
curl -s -m 5 http://10.128.184.195:8000/health && echo "✅ AI Service is accessible" || echo "❌ AI Service not reachable"
echo ""

# Test SmolVLM2 API
echo "2. Testing SmolVLM2 API (port 8080):"
curl -s -m 5 http://10.128.184.195:8080/health && echo "✅ SmolVLM2 API is accessible" || echo "❌ SmolVLM2 API not reachable"
echo ""

# Show laptop's listening ports
echo "3. Checking which ports are open on laptop:"
ss -tuln | grep -E ':(8000|8080)' || echo "No services listening on ports 8000 or 8080"
echo ""

# Show firewall status
echo "4. Checking firewall rules:"
sudo ufw status | grep -E '(8000|8080)' || echo "Ports 8000 and 8080 not explicitly allowed in firewall"
echo ""

echo "To fix issues:"
echo "1. Start your server with: --host 0.0.0.0 (not 127.0.0.1)"
echo "2. Allow firewall: sudo ufw allow 8000 && sudo ufw allow 8080"
echo "3. Check both devices are on same WiFi"
