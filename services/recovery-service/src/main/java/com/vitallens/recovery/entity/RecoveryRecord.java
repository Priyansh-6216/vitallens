package com.vitallens.recovery.entity;

import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDate;

@Entity
@Table(name = "recovery_records")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class RecoveryRecord {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String userId;

    @Column(nullable = false)
    private LocalDate date;

    private Integer recoveryScore;
    
    private Double hrv;
    
    private Double rhr;
    
    private Double strain;
    
    private Integer sleepDurationMin;

    private String readinessBand;
}
