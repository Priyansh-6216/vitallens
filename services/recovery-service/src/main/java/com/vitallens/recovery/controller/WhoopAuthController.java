package com.vitallens.recovery.controller;

import com.vitallens.recovery.entity.WhoopToken;
import com.vitallens.recovery.repository.WhoopTokenRepository;
import com.vitallens.recovery.service.WhoopSyncService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.servlet.view.RedirectView;

import java.time.Instant;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/recovery/auth")
public class WhoopAuthController {

    @Value("${spring.security.oauth2.client.registration.whoop.client-id}")
    private String clientId;

    @Value("${spring.security.oauth2.client.registration.whoop.client-secret}")
    private String clientSecret;

    @Value("${spring.security.oauth2.client.registration.whoop.redirect-uri}")
    private String redirectUri;

    @Autowired
    private WhoopTokenRepository whoopTokenRepository;

    @Autowired
    private WhoopSyncService whoopSyncService;

    @GetMapping("/connect")
    public RedirectView connect(@RequestParam String userId) {
        String url = "https://api.prod.whoop.com/oauth/oauth2/auth" +
                "?client_id=" + clientId +
                "&redirect_uri=" + redirectUri +
                "&response_type=code" +
                "&scope=read:recovery read:cycles read:workout offline" +
                "&state=" + userId;
        return new RedirectView(url);
    }

    @GetMapping("/callback")
    public RedirectView callback(@RequestParam String code, @RequestParam String state) {
        String userId = state; // We used userId as the state
        
        RestTemplate restTemplate = new RestTemplate();
        
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_FORM_URLENCODED);
        
        MultiValueMap<String, String> map = new LinkedMultiValueMap<>();
        map.add("grant_type", "authorization_code");
        map.add("code", code);
        map.add("client_id", clientId);
        map.add("client_secret", clientSecret);
        map.add("redirect_uri", redirectUri);
        
        HttpEntity<MultiValueMap<String, String>> request = new HttpEntity<>(map, headers);
        
        ResponseEntity<Map> response = restTemplate.postForEntity(
                "https://api.prod.whoop.com/oauth/oauth2/token", 
                request, 
                Map.class
        );
        
        if (response.getStatusCode() == HttpStatus.OK) {
            Map<String, Object> body = response.getBody();
            WhoopToken token = WhoopToken.builder()
                    .userId(userId)
                    .accessToken((String) body.get("access_token"))
                    .refreshToken((String) body.get("refresh_token"))
                    .expiresAt(Instant.now().plusSeconds((Integer) body.get("expires_in")))
                    .scope((String) body.get("scope"))
                    .build();
            
            whoopTokenRepository.save(token);
            
            // Trigger initial sync for the last 7 days
            try {
                whoopSyncService.syncUserRecovery(userId, 7);
            } catch (Exception e) {
                System.err.println("Failed initial sync: " + e.getMessage());
            }
        }
        
        // Redirect back to the dashboard
        return new RedirectView("http://localhost:5173/?connected=true");
    }
}
