package com.platform.user;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
class UserControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void listUsersReturns200() throws Exception {
        mockMvc.perform(get("/api/users"))
               .andExpect(status().isOk())
               .andExpect(jsonPath("$.count").value(3));
    }

    @Test
    void getUserByIdReturnsUser() throws Exception {
        mockMvc.perform(get("/api/users/u001"))
               .andExpect(status().isOk())
               .andExpect(jsonPath("$.name").value("Chandan Vura"));
    }

    @Test
    void getUserNotFoundReturns404() throws Exception {
        mockMvc.perform(get("/api/users/u999"))
               .andExpect(status().isNotFound());
    }

    @Test
    void healthEndpointReturnsUp() throws Exception {
        mockMvc.perform(get("/api/users/health"))
               .andExpect(status().isOk())
               .andExpect(jsonPath("$.status").value("UP"))
               .andExpect(jsonPath("$.service").value("user-service"));
    }
}
