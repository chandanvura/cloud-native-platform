#!/bin/bash
# scripts/test-services.sh
# ─────────────────────────────────────────────────────────────────
# End-to-end test: port-forward all 3 services and run API tests.
# Run AFTER setup-local.sh and after services are deployed by ArgoCD.
# ─────────────────────────────────────────────────────────────────
set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'
pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; FAILURES=$((FAILURES+1)); }
FAILURES=0

echo -e "\n${BOLD}  cloud-native-platform — end-to-end tests${NC}\n"

# ── Port-forward services ────────────────────────────────────────
echo "Starting port-forwards..."
kubectl port-forward svc/user-service         -n apps 8081:80  &>/dev/null &
kubectl port-forward svc/order-service        -n apps 8082:80  &>/dev/null &
kubectl port-forward svc/notification-service -n apps 8083:80  &>/dev/null &
sleep 4
echo "Port-forwards ready"
echo ""

# ── user-service tests ───────────────────────────────────────────
echo -e "${BOLD}user-service${NC}"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8081/api/users/health)
[ "$STATUS" = "200" ] && pass "GET /api/users/health → 200" || fail "GET /api/users/health → $STATUS"

RESULT=$(curl -s http://localhost:8081/api/users | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('count',0))" 2>/dev/null || echo "0")
[ "$RESULT" -ge "1" ] && pass "GET /api/users → count=$RESULT" || fail "GET /api/users → no users"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8081/api/users/u001)
[ "$STATUS" = "200" ] && pass "GET /api/users/u001 → 200" || fail "GET /api/users/u001 → $STATUS"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8081/api/users/u999)
[ "$STATUS" = "404" ] && pass "GET /api/users/u999 → 404 (correct)" || fail "GET /api/users/u999 → $STATUS (expected 404)"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8081/actuator/prometheus)
[ "$STATUS" = "200" ] && pass "GET /actuator/prometheus → 200 (Prometheus scraping works)" || fail "GET /actuator/prometheus → $STATUS"

echo ""

# ── notification-service tests ───────────────────────────────────
echo -e "${BOLD}notification-service${NC}"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8083/api/notifications/health)
[ "$STATUS" = "200" ] && pass "GET /api/notifications/health → 200" || fail "GET /api/notifications/health → $STATUS"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -X POST http://localhost:8083/api/notifications \
  -H 'Content-Type: application/json' \
  -d '{"userId":"u001","type":"TEST","message":"hello from test script"}')
[ "$STATUS" = "201" ] && pass "POST /api/notifications → 201" || fail "POST /api/notifications → $STATUS"

echo ""

# ── order-service tests ──────────────────────────────────────────
echo -e "${BOLD}order-service${NC}"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8082/api/orders/health)
[ "$STATUS" = "200" ] && pass "GET /api/orders/health → 200" || fail "GET /api/orders/health → $STATUS"

# Create order — triggers inter-service calls
RESPONSE=$(curl -s -w "\n%{http_code}" \
  -X POST http://localhost:8082/api/orders \
  -H 'Content-Type: application/json' \
  -d '{"userId":"u001","item":"PlayStation 5","quantity":"1"}')
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)
[ "$HTTP_CODE" = "201" ] && pass "POST /api/orders → 201 (inter-service call succeeded)" || fail "POST /api/orders → $HTTP_CODE"

ORDER_ID=$(echo "$BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('orderId',''))" 2>/dev/null || echo "")
[ -n "$ORDER_ID" ] && pass "Order created: $ORDER_ID" || fail "No orderId in response"

# Bad user — expect 404
STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -X POST http://localhost:8082/api/orders \
  -H 'Content-Type: application/json' \
  -d '{"userId":"u999","item":"PS5"}')
[ "$STATUS" = "404" ] && pass "POST /api/orders invalid user → 404 (correct)" || fail "POST /api/orders invalid user → $STATUS"

echo ""

# ── Verify notification was logged ───────────────────────────────
echo -e "${BOLD}inter-service verification${NC}"
NOTIF_COUNT=$(curl -s http://localhost:8083/api/notifications | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('count',0))" 2>/dev/null || echo "0")
[ "$NOTIF_COUNT" -ge "1" ] && pass "Notification log has $NOTIF_COUNT entries (order-service called notification-service)" || fail "No notifications logged"

# ── Summary ──────────────────────────────────────────────────────
pkill -f "kubectl port-forward svc/user-service" 2>/dev/null || true
pkill -f "kubectl port-forward svc/order-service" 2>/dev/null || true
pkill -f "kubectl port-forward svc/notification-service" 2>/dev/null || true

echo ""
if [ "$FAILURES" -eq "0" ]; then
  echo -e "${GREEN}${BOLD}  All tests passed!${NC}"
else
  echo -e "${RED}${BOLD}  $FAILURES test(s) failed.${NC}"
  exit 1
fi
