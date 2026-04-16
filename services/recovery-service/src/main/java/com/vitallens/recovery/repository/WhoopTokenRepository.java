package com.vitallens.recovery.repository;

import com.vitallens.recovery.entity.WhoopToken;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface WhoopTokenRepository extends JpaRepository<WhoopToken, String> {
}
