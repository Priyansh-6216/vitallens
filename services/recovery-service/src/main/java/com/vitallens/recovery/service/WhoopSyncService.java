package com.vitallens.recovery.service;

import com.vitallens.recovery.entity.RecoveryRecord;
import com.vitallens.recovery.entity.WhoopToken;
import com.vitallens.recovery.repository.RecoveryRepository;
import com.vitallens.recovery.repository.WhoopTokenRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.time.Instant;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;

@Service
public class WhoopSyncService {

    @Autowired
    private WhoopTokenRepository whoopTokenRepository;

    @Autowired
    private RecoveryRepository recoveryRepository;

    @Autowired
    private IngestionService ingestionService; // Reusing getBand logic

    public void syncUserRecovery(String userId, int daysBack) {
        WhoopToken token = whoopTokenRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("No WHOOP connection for user " + userId));

        // In a real app, refresh token if expired here
        if (token.getExpiresAt().isBefore(Instant.now())) {
            // Placeholder for token refresh logic
            System.err.println("Token expired for " + userId + ". Refresh needed.");
        }

        RestTemplate restTemplate = new RestTemplate();
        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(token.getAccessToken());
        HttpEntity<?> entity = new HttpEntity<>(headers);

        String start = OffsetDateTime.now().minusDays(daysBack).atZoneSameInstant(ZoneOffset.UTC).toString();
        String url = "https://api.prod.whoop.com/developer/v1/user/measurement/recovery?start=" + start;

        ResponseEntity<Map> response = restTemplate.exchange(url, HttpMethod.GET, entity, Map.class);

        if (response.getStatusCode().is2xxSuccessful() && response.getBody() != null) {
            List<Map<String, Object>> records = (List<Map<String, Object>>) response.getBody().get("records");
            if (records != null) {
                for (Map<String, Object> recordMap : records) {
                    processRecoveryRecord(userId, recordMap);
                }
            }
        }
    }

    private void processRecoveryRecord(String userId, Map<String, Object> recordMap) {
        Map<String, Object> scoreMap = (Map<String, Object>) recordMap.get("score");
        if (scoreMap == null) return;

        String createdAtStr = (String) recordMap.get("created_at");
        LocalDate date = OffsetDateTime.parse(createdAtStr).toLocalDate();

        int score = (int) scoreMap.get("recovery_score");
        double rhr = ((Number) scoreMap.get("resting_heart_rate")).doubleValue();
        double hrv = ((Number) scoreMap.get("hrv_rmssd_milli")).doubleValue();

        // Check if record already exists for this date and user
        recoveryRepository.findByUserIdAndDate(userId, date).ifPresentOrElse(
            existing -> {
                existing.setRecoveryScore(score);
                existing.setRhr(rhr);
                existing.setHrv(hrv);
                existing.setReadinessBand(getBand(score));
                recoveryRepository.save(existing);
            },
            () -> {
                RecoveryRecord newRecord = RecoveryRecord.builder()
                        .userId(userId)
                        .date(date)
                        .recoveryScore(score)
                        .rhr(rhr)
                        .hrv(hrv)
                        .strain(0.0) // Strain might be in another API call, for now default
                        .readinessBand(getBand(score))
                        .build();
                recoveryRepository.save(newRecord);
            }
        );
    }

    private String getBand(int score) {
        if (score >= 67) return "green";
        if (score >= 34) return "yellow";
        return "red";
    }
}
