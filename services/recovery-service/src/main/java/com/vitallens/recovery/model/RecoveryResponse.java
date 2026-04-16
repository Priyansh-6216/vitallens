package com.vitallens.recovery.model;

import lombok.Builder;
import lombok.Data;
import java.time.LocalDate;
import java.util.List;

@Data
@Builder
public class RecoveryResponse {
    private LocalDate day;
    private int recoveryScore;
    private String readinessBand;
    private List<String> topFactors;
    private String aiSummary;
    private double recommendedStrain;
    private double hrv;
    private double rhr;
}
