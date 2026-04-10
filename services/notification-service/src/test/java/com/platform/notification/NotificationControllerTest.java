package com.platform.notification;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
class NotificationControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void healthReturnsUp() throws Exception {
        mockMvc.perform(get("/api/notifications/health"))
               .andExpect(status().isOk())
               .andExpect(jsonPath("$.status").value("UP"));
    }

    @Test
    void sendNotificationReturns201() throws Exception {
        mockMvc.perform(post("/api/notifications")
               .contentType(MediaType.APPLICATION_JSON)
               .content("{\"userId\":\"u001\",\"type\":\"ORDER_CREATED\",\"message\":\"test\"}"))
               .andExpect(status().isCreated())
               .andExpect(jsonPath("$.status").value("SENT"));
    }

    @Test
    void listNotificationsReturnsLog() throws Exception {
        mockMvc.perform(get("/api/notifications"))
               .andExpect(status().isOk())
               .andExpect(jsonPath("$.service").value("notification-service"));
    }
}
