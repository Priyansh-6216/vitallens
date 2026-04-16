package com.vitallens.recovery.entity;

import jakarta.persistence.*;
import lombok.*;
import java.time.Instant;

@Entity
@Table(name = "whoop_tokens")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class WhoopToken {
    @Id
    private String userId; // Link to our internal user ID

    @Column(length = 2048)
    private String accessToken;

    @Column(length = 2048)
    private String refreshToken;

    private Instant expiresAt;

    private String scope;
}
