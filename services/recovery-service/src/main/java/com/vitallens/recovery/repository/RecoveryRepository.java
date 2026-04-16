package com.vitallens.recovery.repository;

import com.vitallens.recovery.entity.RecoveryRecord;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

@Repository
public interface RecoveryRepository extends JpaRepository<RecoveryRecord, Long> {
    List<RecoveryRecord> findByUserIdOrderByDateAsc(String userId);
    Optional<RecoveryRecord> findByUserIdAndDate(String userId, LocalDate date);
    List<RecoveryRecord> findByUserIdAndDateAfterOrderByDateDesc(String userId, LocalDate date);
}
