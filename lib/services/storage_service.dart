import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:uuid/uuid.dart';
import '../models/patient_model.dart';
import '../utils/app_constants.dart';

/// Veritabanı işlemlerini yöneten servis
class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  /// Servisi başlatır ve Hive veritabanını açar
  static Future<void> init() async {
    try {
      await Hive.initFlutter();

      // Hasta modelini kaydet
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(PatientAdapter());
      }

      await Hive.openBox<Patient>(AppConstants.patientsBox);
      await Hive.openBox(AppConstants.measurementsBox);

      debugPrint('✅ Veritabanı başlatıldı');
    } catch (e) {
      debugPrint('❌ Veritabanı başlatma hatası: $e');
      rethrow;
    }
  }

  // ============ HASTA İŞLEMLERİ ============

  /// Yeni hasta ekler
  Future<Patient> addPatient({
    required String deviceMac,
    required String fullName,
    required String tcNo,
    required DateTime surgeryDate,
    String notes = '',
    String? surgeryType,
    int? age,
    String? gender,
  }) async {
    try {
      var box = Hive.box<Patient>(AppConstants.patientsBox);

      final patient = Patient(
        id: const Uuid().v4(),
        deviceMac: deviceMac,
        fullName: fullName,
        tcNo: tcNo,
        surgeryDate: surgeryDate,
        notes: notes,
        createdAt: DateTime.now(),
        surgeryType: surgeryType,
        age: age,
        gender: gender,
      );

      await box.put(patient.id, patient);
      debugPrint('✅ Hasta eklendi: ${patient.fullName}');
      return patient;
    } catch (e) {
      debugPrint('❌ Hasta ekleme hatası: $e');
      rethrow;
    }
  }

  /// Tüm hastaları getirir (en yeni önce sıralı)
  List<Patient> getAllPatients() {
    try {
      var box = Hive.box<Patient>(AppConstants.patientsBox);
      return box.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      debugPrint('❌ Hasta listesi getirme hatası: $e');
      return [];
    }
  }

  /// Belirli bir hastayı ID ile getirir
  Patient? getPatientById(String patientId) {
    try {
      var box = Hive.box<Patient>(AppConstants.patientsBox);
      return box.get(patientId);
    } catch (e) {
      debugPrint('❌ Hasta getirme hatası: $e');
      return null;
    }
  }

  /// Hasta bilgilerini günceller
  Future<void> updatePatient(Patient patient) async {
    try {
      var box = Hive.box<Patient>(AppConstants.patientsBox);
      await box.put(patient.id, patient);
      debugPrint('✅ Hasta güncellendi: ${patient.fullName}');
    } catch (e) {
      debugPrint('❌ Hasta güncelleme hatası: $e');
      rethrow;
    }
  }

  /// Hastayı siler (ölçümler dahil)
  Future<void> deletePatient(String patientId) async {
    try {
      var box = Hive.box<Patient>(AppConstants.patientsBox);
      await box.delete(patientId);
      await deleteMeasurements(patientId);
      debugPrint('✅ Hasta silindi: $patientId');
    } catch (e) {
      debugPrint('❌ Hasta silme hatası: $e');
      rethrow;
    }
  }

  /// Hasta arar (isim veya TC ile)
  List<Patient> searchPatients(String query) {
    if (query.isEmpty) return getAllPatients();

    try {
      var allPatients = getAllPatients();
      return allPatients.where((p) {
        return p.fullName.toLowerCase().contains(query.toLowerCase()) ||
            p.tcNo.contains(query);
      }).toList();
    } catch (e) {
      debugPrint('❌ Hasta arama hatası: $e');
      return [];
    }
  }

  /// Aktif hastaları getirir (son 7 gün içinde ölçümü olan)
  List<Patient> getActivePatients() {
    try {
      return getAllPatients().where((p) => p.isActive).toList();
    } catch (e) {
      debugPrint('❌ Aktif hasta getirme hatası: $e');
      return [];
    }
  }

  /// Bu hafta eklenen hastaları getirir
  List<Patient> getPatientsThisWeek() {
    try {
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      return getAllPatients()
          .where((p) => p.createdAt.isAfter(weekAgo))
          .toList();
    } catch (e) {
      debugPrint('❌ Haftalık hasta getirme hatası: $e');
      return [];
    }
  }

  // ============ ÖLÇÜM İŞLEMLERİ ============

  /// Yeni ölçüm verisini kaydeder
  Future<void> saveMeasurement({
    required String patientId,
    required List<FlSpot> hotSpotData,
    required List<FlSpot> baseLineData,
    required Map<double, String> timeLabels,
  }) async {
    try {
      var box = Hive.box(AppConstants.measurementsBox);

      // Listeleri saklanabilir formata çevir
      List<List<double>> hotList = hotSpotData.map((e) => [e.x, e.y]).toList();
      List<List<double>> baseList =
          baseLineData.map((e) => [e.x, e.y]).toList();
      Map<String, String> labels =
          timeLabels.map((k, v) => MapEntry(k.toString(), v));

      // Timestamp ile benzersiz anahtar oluştur
      String key = '${patientId}_${DateTime.now().millisecondsSinceEpoch}';

      await box.put(key, {
        'hotSpotData': hotList,
        'baseLineData': baseList,
        'timeLabels': labels,
        'timestamp': DateTime.now().toIso8601String(),
      });

      // Hasta modelindeki son ölçüm tarihini güncelle
      var patientBox = Hive.box<Patient>(AppConstants.patientsBox);
      Patient? patient = patientBox.get(patientId);
      if (patient != null) {
        await updatePatient(
            patient.copyWith(lastMeasurement: DateTime.now()));
      }

      debugPrint('✅ Ölçüm kaydedildi: $patientId');
    } catch (e) {
      debugPrint('❌ Ölçüm kaydetme hatası: $e');
      rethrow;
    }
  }

  /// En son ölçümü getirir
  Map<String, dynamic>? getLatestMeasurement(String patientId) {
    try {
      var box = Hive.box(AppConstants.measurementsBox);

      // Bu hastaya ait tüm kayıtları bul
      var keys =
          box.keys.where((k) => k.toString().startsWith(patientId)).toList();
      if (keys.isEmpty) return null;

      // En yeni kaydı al (timestamp'e göre sırala)
      keys.sort((a, b) => b.toString().compareTo(a.toString()));
      String latestKey = keys.first.toString();

      Map<dynamic, dynamic> data = box.get(latestKey);

      // FlSpot formatına çevir
      List<FlSpot> hotSpotData = (data['hotSpotData'] as List)
          .map((e) => FlSpot(e[0], e[1]))
          .toList();
      List<FlSpot> baseLineData = (data['baseLineData'] as List)
          .map((e) => FlSpot(e[0], e[1]))
          .toList();
      Map<double, String> timeLabels = (data['timeLabels'] as Map)
          .map((k, v) => MapEntry(double.parse(k), v as String));

      return {
        'hotSpotData': hotSpotData,
        'baseLineData': baseLineData,
        'timeLabels': timeLabels,
        'timestamp': data['timestamp'],
      };
    } catch (e) {
      debugPrint('❌ Son ölçüm getirme hatası: $e');
      return null;
    }
  }

  /// Hastanın tüm ölçümlerini getirir (geçmiş kayıtlar)
  List<Map<String, dynamic>> getAllMeasurements(String patientId) {
    try {
      var box = Hive.box(AppConstants.measurementsBox);

      var keys = box.keys
          .where((k) => k.toString().startsWith(patientId))
          .toList()
        ..sort((a, b) => b.toString().compareTo(a.toString()));

      return keys.map((key) {
        Map<dynamic, dynamic> data = box.get(key);
        return {
          'key': key,
          'timestamp': data['timestamp'],
          'hotSpotData': (data['hotSpotData'] as List)
              .map((e) => FlSpot(e[0], e[1]))
              .toList(),
          'baseLineData': (data['baseLineData'] as List)
              .map((e) => FlSpot(e[0], e[1]))
              .toList(),
          'timeLabels': (data['timeLabels'] as Map)
              .map((k, v) => MapEntry(double.parse(k), v as String)),
        };
      }).toList();
    } catch (e) {
      debugPrint('❌ Tüm ölçümleri getirme hatası: $e');
      return [];
    }
  }

  /// Hastanın ölçüm sayısını döndürür
  int getMeasurementCount(String patientId) {
    try {
      var box = Hive.box(AppConstants.measurementsBox);
      return box.keys
          .where((k) => k.toString().startsWith(patientId))
          .length;
    } catch (e) {
      debugPrint('❌ Ölçüm sayısı getirme hatası: $e');
      return 0;
    }
  }

  /// Hastanın ölçümlerini siler
  Future<void> deleteMeasurements(String patientId) async {
    try {
      var box = Hive.box(AppConstants.measurementsBox);
      var keys =
          box.keys.where((k) => k.toString().startsWith(patientId)).toList();
      for (var key in keys) {
        await box.delete(key);
      }
      debugPrint('✅ Ölçümler silindi: $patientId');
    } catch (e) {
      debugPrint('❌ Ölçüm silme hatası: $e');
      rethrow;
    }
  }

  /// Belirli bir ölçümü siler
  Future<void> deleteSingleMeasurement(String measurementKey) async {
    try {
      var box = Hive.box(AppConstants.measurementsBox);
      await box.delete(measurementKey);
      debugPrint('✅ Ölçüm silindi: $measurementKey');
    } catch (e) {
      debugPrint('❌ Ölçüm silme hatası: $e');
      rethrow;
    }
  }

  // ============ İSTATİSTİK İŞLEMLERİ ============

  /// Toplam hasta sayısı
  int getTotalPatientCount() {
    try {
      return Hive.box<Patient>(AppConstants.patientsBox).length;
    } catch (e) {
      debugPrint('❌ Hasta sayısı getirme hatası: $e');
      return 0;
    }
  }

  /// Toplam ölçüm sayısı
  int getTotalMeasurementCount() {
    try {
      return Hive.box(AppConstants.measurementsBox).length;
    } catch (e) {
      debugPrint('❌ Ölçüm sayısı getirme hatası: $e');
      return 0;
    }
  }

  /// Veritabanını temizler (TEHLİKELİ!)
  Future<void> clearAllData() async {
    try {
      await Hive.box<Patient>(AppConstants.patientsBox).clear();
      await Hive.box(AppConstants.measurementsBox).clear();
      debugPrint('✅ Tüm veriler temizlendi');
    } catch (e) {
      debugPrint('❌ Veri temizleme hatası: $e');
      rethrow;
    }
  }
}