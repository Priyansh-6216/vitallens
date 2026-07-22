import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import '../models/heart_rate_data_model.dart';
import '../services/database_service.dart';
import 'package:intl/intl.dart';

class ExportService {
  final DatabaseService _dbService = DatabaseService();

  // Export data to CSV format
  Future<File?> exportToCSV({DateTime? startDate, DateTime? endDate}) async {
    try {
      // Get data based on date range
      List<HeartRateDataModel> data;
      if (startDate != null && endDate != null) {
        data = await _dbService.getHeartRateDataInRange(startDate, endDate);
      } else {
        data = await _dbService.getAllHeartRateData();
      }

      if (data.isEmpty) {
        return null; // No data to export
      }

      // Create CSV content
      StringBuffer csvBuffer = StringBuffer();
      
      // Add header
      csvBuffer.writeln('Timestamp,Heart Rate (bpm),SDNN (ms),RMSSD (ms),pNN50 (%)');
      
      // Add data rows
      for (var record in data) {
        csvBuffer.writeln(
            '${record.timestamp},${record.heartRate},${record.sdnn ?? ''},${record.rmssd ?? ''},${record.pnn50 ?? ''}');
      }

      // Get application documents directory
      final Directory directory = await getApplicationDocumentsDirectory();
      final String timestamp =
          DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final String filename = 'vitalLens_export_$timestamp.csv';
      final File file = File('${directory.path}/$filename');

      // Write CSV to file
      await file.writeAsString(csvBuffer.toString());
      return file;
    } catch (e) {
      // In a real app, you might want to log this error
      return null;
    }
  }

  // Export data to JSON format
  Future<File?> exportToJSON({DateTime? startDate, DateTime? endDate}) async {
    try {
      // Get data based on date range
      List<HeartRateDataModel> data;
      if (startDate != null && endDate != null) {
        data = await _dbService.getHeartRateDataInRange(startDate, endDate);
      } else {
        data = await _dbService.getAllHeartRateData();
      }

      if (data.isEmpty) {
        return null; // No data to export
      }

      // Convert to JSON-compatible format
      List<Map<String, dynamic>> jsonData = [];
      for (var record in data) {
        jsonData.add({
          'timestamp': record.timestamp,
          'heart_rate': record.heartRate,
          'sdnn': record.sdnn,
          'rmssd': record.rmssd,
          'pnn50': record.pnn50
        });
      }

      // Create JSON string with pretty printing
      final String json = JsonEncoder.withIndent('  ').convert({
        'export_info': {
          'timestamp': DateTime.now().toIso8601String(),
          'record_count': data.length,
          'date_range': {
            'start': startDate?.toIso8601String(),
            'end': endDate?.toIso8601String()
          }
        },
        'data': jsonData
      });

      // Get application documents directory
      final Directory directory = await getApplicationDocumentsDirectory();
      final String timestamp =
          DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final String filename = 'vitalLens_export_$timestamp.json';
      final File file = File('${directory.path}/$filename');

      // Write JSON to file
      await file.writeAsString(json);
      return file;
    } catch (e) {
      // In a real app, you might want to log this error
      return null;
    }
  }

  // Get list of exported files
  Future<List<FileSystemEntity>> getExportedFiles() async {
    try {
      final Directory directory = await getApplicationDocumentsDirectory();
      final List<FileSystemEntity> allFiles = directory.listSync();
      return allFiles.where((entity) {
        final String path = entity.path.toLowerCase();
        return path.endsWith('.csv') || path.endsWith('.json');
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // Delete an exported file
  Future<bool> deleteExportedFile(String filePath) async {
    try {
      final File file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
