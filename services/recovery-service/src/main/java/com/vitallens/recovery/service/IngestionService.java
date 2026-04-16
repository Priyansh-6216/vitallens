package com.vitallens.recovery.service;

import com.vitallens.recovery.entity.RecoveryRecord;
import com.vitallens.recovery.repository.RecoveryRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;

@Service
public class IngestionService {

    @Autowired
    private RecoveryRepository recoveryRepository;

    private static final DateTimeFormatter DATE_FORMATTER = DateTimeFormatter.ofPattern("yyyy-MM-dd");

    public int importWhoopCSV(String userId, MultipartFile file) throws Exception {
        List<RecoveryRecord> records = new ArrayList<>();
        
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(file.getInputStream()))) {
            String header = reader.readLine();
            if (header == null) return 0;

            String line;
            while ((line = reader.readLine()) != null) {
                String[] columns = line.split(",");
                if (columns.length < 5) continue;

                try {
                    // Mapping typical WHOOP Physiological Cycles Columns
                    // Column index assumptions (Subject to adjustment based on specific export version)
                    // Index 0: Cycle Start Time (e.g. 2023-11-25 01:23:45)
                    // Index 2: Recovery score %
                    // Index 3: Resting heart rate
                    // Index 4: Heart Rate Variability
                    // Index 5: Day Strain
                    
                    String startTimeStr = columns[0].replace("\"", "");
                    LocalDate date = LocalDate.parse(startTimeStr.substring(0, 10)); // Extract YYYY-MM-DD
                    
                    Integer recoveryScore = Integer.parseInt(columns[2].replace("\"", ""));
                    Double rhr = Double.parseDouble(columns[3].replace("\"", ""));
                    Double hrv = Double.parseDouble(columns[4].replace("\"", ""));
                    Double strain = columns.length > 5 ? Double.parseDouble(columns[5].replace("\"", "")) : 0.0;

                    RecoveryRecord record = RecoveryRecord.builder()
                            .userId(userId)
                            .date(date)
                            .recoveryScore(recoveryScore)
                            .rhr(rhr)
                            .hrv(hrv)
                            .strain(strain)
                            .readinessBand(getBand(recoveryScore))
                            .build();
                    
                    records.add(record);
                } catch (Exception e) {
                    // Skip malformed rows
                    System.err.println("Skipping malformed row: " + line);
                }
            }
        }
        
        if (!records.isEmpty()) {
            recoveryRepository.saveAll(records);
        }
        return records.size();
    }

    private String getBand(int score) {
        if (score >= 67) return "green";
        if (score >= 34) return "yellow";
        return "red";
    }
}
