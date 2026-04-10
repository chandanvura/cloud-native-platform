package com.platform.order;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.client.ResourceAccessException;
import org.springframework.web.client.HttpClientErrorException;

import java.time.Instant;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

@RestController
@RequestMapping("/api/orders")
public class OrderController {

    private final RestTemplate restTemplate = new RestTemplate();
    private final Map<String, Map<String, Object>> orders = new ConcurrentHashMap<>();

    private static final String VERSION =
        System.getenv().getOrDefault("APP_VERSION", "1.0.0");
    private static final String ENV =
        System.getenv().getOrDefault("APP_ENV", "local");

    // K8s internal DNS: <service-name>.<namespace>.svc.cluster.local
    @Value("${user.service.url:http://localhost:8081}")
    private String userServiceUrl;

    @Value("${notification.service.url:http://localhost:8083}")
    private String notificationServiceUrl;

    @PostMapping
    public ResponseEntity<?> createOrder(@RequestBody Map<String, String> body) {
        String userId = body.get("userId");
        String item   = body.getOrDefault("item", "unknown-item");
        String qty    = body.getOrDefault("quantity", "1");

        if (userId == null || userId.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of(
                "error", "userId is required"
            ));
        }

        // ── Inter-service call 1: validate user exists ────────────
        try {
            restTemplate.getForObject(
                userServiceUrl + "/api/users/" + userId, Map.class);
        } catch (HttpClientErrorException.NotFound e) {
            return ResponseEntity.status(404).body(Map.of(
                "error", "User not found: " + userId,
                "hint", "user-service returned 404"
            ));
        } catch (ResourceAccessException e) {
            // user-service unreachable — still create order (resilience demo)
            System.err.println("[WARN] user-service unreachable: " + e.getMessage());
        }

        // Create order
        String orderId = "ord-" + UUID.randomUUID().toString().substring(0, 8);
        Map<String, Object> order = new LinkedHashMap<>();
        order.put("orderId",   orderId);
        order.put("userId",    userId);
        order.put("item",      item);
        order.put("quantity",  qty);
        order.put("status",    "CREATED");
        order.put("createdAt", Instant.now().toString());
        orders.put(orderId, order);

        // ── Inter-service call 2: send notification ───────────────
        try {
            restTemplate.postForObject(
                notificationServiceUrl + "/api/notifications",
                Map.of(
                    "userId",  userId,
                    "type",    "ORDER_CREATED",
                    "message", "Order " + orderId + " created — " + qty + "x " + item
                ),
                Map.class
            );
        } catch (Exception e) {
            // Notification failure is non-fatal — order still succeeds
            System.err.println("[WARN] notification-service unreachable: " + e.getMessage());
        }

        return ResponseEntity.status(201).body(order);
    }

    @GetMapping
    public ResponseEntity<Map<String, Object>> listOrders() {
        return ResponseEntity.ok(Map.of(
            "orders", orders.values(),
            "count",  orders.size(),
            "service","order-service",
            "version", VERSION
        ));
    }

    @GetMapping("/{orderId}")
    public ResponseEntity<?> getOrder(@PathVariable String orderId) {
        if (orders.containsKey(orderId)) {
            return ResponseEntity.ok(orders.get(orderId));
        }
        return ResponseEntity.status(404).body(Map.of("error", "Order not found"));
    }

    @GetMapping("/health")
    public ResponseEntity<Map<String, Object>> health() {
        return ResponseEntity.ok(Map.of(
            "status",   "UP",
            "service",  "order-service",
            "version",  VERSION,
            "env",      ENV,
            "timestamp",Instant.now().toString(),
            "dependencies", Map.of(
                "user-service",         userServiceUrl,
                "notification-service", notificationServiceUrl
            )
        ));
    }
}
