package com.platform.user;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.time.Instant;
import java.util.*;

@RestController
@RequestMapping("/api/users")
public class UserController {

    private static final String VERSION =
        System.getenv().getOrDefault("APP_VERSION", "1.0.0");
    private static final String ENV =
        System.getenv().getOrDefault("APP_ENV", "local");

    // In-memory store — no database needed, keeps the demo simple
    private static final Map<String, Map<String, String>> USERS = new LinkedHashMap<>();
    static {
        USERS.put("u001", Map.of(
            "id", "u001",
            "name", "Chandan Vura",
            "email", "chandan@example.com",
            "role", "admin"
        ));
        USERS.put("u002", Map.of(
            "id", "u002",
            "name", "Alice DevOps",
            "email", "alice@example.com",
            "role", "developer"
        ));
        USERS.put("u003", Map.of(
            "id", "u003",
            "name", "Bob Platform",
            "email", "bob@example.com",
            "role", "sre"
        ));
    }

    @GetMapping
    public ResponseEntity<Map<String, Object>> listUsers() {
        return ResponseEntity.ok(Map.of(
            "users", USERS.values(),
            "count", USERS.size(),
            "service", "user-service",
            "version", VERSION,
            "env", ENV
        ));
    }

    @GetMapping("/{id}")
    public ResponseEntity<?> getUser(@PathVariable String id) {
        if (USERS.containsKey(id)) {
            return ResponseEntity.ok(USERS.get(id));
        }
        return ResponseEntity.status(404).body(Map.of(
            "error", "User not found",
            "userId", id
        ));
    }

    @PostMapping
    public ResponseEntity<Map<String, Object>> createUser(
            @RequestBody Map<String, String> body) {
        String id = "u" + String.format("%03d", USERS.size() + 1);
        Map<String, String> user = new HashMap<>(body);
        user.put("id", id);
        USERS.put(id, user);
        return ResponseEntity.status(201).body(Map.of(
            "message", "User created",
            "user", user
        ));
    }

    @GetMapping("/health")
    public ResponseEntity<Map<String, Object>> health() {
        return ResponseEntity.ok(Map.of(
            "status", "UP",
            "service", "user-service",
            "version", VERSION,
            "env", ENV,
            "timestamp", Instant.now().toString(),
            "userCount", USERS.size()
        ));
    }
}
