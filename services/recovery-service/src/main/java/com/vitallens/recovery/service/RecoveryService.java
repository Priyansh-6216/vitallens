package com.vitallens.recovery.service;

import com.vitallens.recovery.model.RecoveryResponse;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import java.time.LocalDate;
import java.util.Arrays;

@Service
public class RecoveryService {

    @Autowired
    private com.vitallens.recovery.repository.RecoveryRepository recoveryRepository;

    public RecoveryResponse calculateDailyRecovery(String userId, LocalDate date) {
        return recoveryRepository.findByUserIdAndDate(userId, date)
                .map(this::mapToResponse)
                .orElseGet(() -> createMockResponse(date)); // Fallback to mock if no data exists
    }

    private RecoveryResponse mapToResponse(com.vitallens.recovery.entity.RecoveryRecord record) {
        return RecoveryResponse.builder()
                .day(record.getDate())
                .recoveryScore(record.getRecoveryScore())
                .readinessBand(record.getReadinessBand())
                .topFactors(Arrays.asList(
                    "HRV: " + record.getHrv() + " ms",
                    "RHR: " + record.getRhr() + " bpm",
                    "Strain: " + record.getStrain()
                ))
                .aiSummary("Recovery based on data metrics.")
                .recommendedStrain(record.getStrain() < 10 ? 12.0 : 8.5)
                .hrv(record.getHrv())
                .rhr(record.getRhr())
                .build();
    }

    private RecoveryResponse createMockResponse(LocalDate date) {
        return RecoveryResponse.builder()
                .day(date)
                .recoveryScore(0)
                .readinessBand("gray")
                .topFactors(Arrays.asList("No data imported for this date"))
                .aiSummary("Please upload your WHOOP CSV data to see analysis.")
                .recommendedStrain(0.0)
                .build();
    }
}
