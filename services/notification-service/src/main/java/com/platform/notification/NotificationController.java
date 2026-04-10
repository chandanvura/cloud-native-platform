package com.platform.notification;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.time.Instant;
import java.util.*;
import java.util.concurrent.CopyOnWriteArrayList;

@RestController
@RequestMapping("/api/notifications")
public class NotificationController {

    // Thread-safe in-memory log
    private final List<Map<String, String>> notificationLog = new CopyOnWriteArrayList<>();

    private static final String VERSION =
        System.getenv().getOrDefault("APP_VERSION", "1.0.0");
    private static final String ENV =
        System.getenv().getOrDefault("APP_ENV", "local");

    @PostMapping
    public ResponseEntity<Map<String, String>> sendNotification(
            @RequestBody Map<String, String> body) {

        String notifId = "notif-" + UUID.randomUUID().toString().substring(0, 8);
        Map<String, String> entry = new LinkedHashMap<>();
        entry.put("notifId",   notifId);
        entry.put("userId",    body.getOrDefault("userId", "unknown"));
        entry.put("type",      body.getOrDefault("type", "GENERIC"));
        entry.put("message",   body.getOrDefault("message", ""));
        entry.put("status",    "SENT");
        entry.put("timestamp", Instant.now().toString());

        notificationLog.add(entry);

        // In production this would publish to SQS/Kafka/SMTP
        System.out.printf("[NOTIFICATION] id=%s userId=%s type=%s msg=%s%n",
            notifId,
            entry.get("userId"),
            entry.get("type"),
            entry.get("message")
        );

        return ResponseEntity.status(201).body(Map.of(
            "notifId", notifId,
            "status",  "SENT"
        ));
    }

    @GetMapping
    public ResponseEntity<Map<String, Object>> listNotifications() {
        return ResponseEntity.ok(Map.of(
            "notifications", notificationLog,
            "count",         notificationLog.size(),
            "service",       "notification-service",
            "version",       VERSION
        ));
    }

    @GetMapping("/health")
    public ResponseEntity<Map<String, Object>> health() {
        return ResponseEntity.ok(Map.of(
            "status",    "UP",
            "service",   "notification-service",
            "version",   VERSION,
            "env",       ENV,
            "timestamp", Instant.now().toString(),
            "queueDepth", notificationLog.size()
        ));
    }
}
