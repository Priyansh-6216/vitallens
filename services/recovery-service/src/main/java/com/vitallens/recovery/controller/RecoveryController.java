package com.vitallens.recovery.controller;

import com.vitallens.recovery.model.RecoveryResponse;
import com.vitallens.recovery.service.RecoveryService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;
import java.time.LocalDate;

@RestController
@RequestMapping("/api/v1/recovery")
public class RecoveryController {

    @Autowired
    private RecoveryService recoveryService;

    @Autowired
    private IngestionService ingestionService;

    @GetMapping("/today")
    public RecoveryResponse getTodayRecovery(@RequestParam String userId) {
        return recoveryService.calculateDailyRecovery(userId, LocalDate.now());
    }

    @PostMapping("/import")
    public String importCSV(@RequestParam("userId") String userId, @RequestParam("file") org.springframework.web.multipart.MultipartFile file) throws Exception {
        int count = ingestionService.importWhoopCSV(userId, file);
        return "Successfully imported " + count + " records for user " + userId;
    }

    @Autowired
    private WhoopSyncService whoopSyncService;

    @PostMapping("/sync")
    public String syncData(@RequestParam String userId) {
        whoopSyncService.syncUserRecovery(userId, 3); // Sync last 3 days
        return "Sync triggered for user " + userId;
    }
}
