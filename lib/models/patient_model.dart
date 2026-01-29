import 'package:hive/hive.dart';

part 'patient_model.g.dart';

/// Hasta bilgilerini tutan model sınıfı
@HiveType(typeId: 0)
class Patient {
  @HiveField(0)
  final String id; // Benzersiz hasta ID (UUID)

  @HiveField(1)
  final String deviceMac; // Cihaz MAC adresi (QR'dan gelen)

  @HiveField(2)
  final String fullName; // Hasta Adı Soyadı

  @HiveField(3)
  final String tcNo; // TC Kimlik No

  @HiveField(4)
  final DateTime surgeryDate; // Ameliyat Tarihi

  @HiveField(5)
  final String notes; // Doktor notları

  @HiveField(6)
  final DateTime createdAt; // Kayıt tarihi

  @HiveField(7)
  final DateTime? lastMeasurement; // Son ölçüm tarihi

  @HiveField(8)
  final String? surgeryType; // Ameliyat türü (Opsiyonel)

  @HiveField(9)
  final int? age; // Yaş (Opsiyonel)

  @HiveField(10)
  final String? gender; // Cinsiyet (Opsiyonel: "E", "K")

  Patient({
    required this.id,
    required this.deviceMac,
    required this.fullName,
    required this.tcNo,
    required this.surgeryDate,
    required this.notes,
    required this.createdAt,
    this.lastMeasurement,
    this.surgeryType,
    this.age,
    this.gender,
  });

  /// Kopyalama metodu (güncelleme için)
  Patient copyWith({
    String? fullName,
    String? tcNo,
    String? notes,
    DateTime? lastMeasurement,
    String? surgeryType,
    int? age,
    String? gender,
  }) {
    return Patient(
      id: id,
      deviceMac: deviceMac,
      fullName: fullName ?? this.fullName,
      tcNo: tcNo ?? this.tcNo,
      surgeryDate: surgeryDate,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      lastMeasurement: lastMeasurement ?? this.lastMeasurement,
      surgeryType: surgeryType ?? this.surgeryType,
      age: age ?? this.age,
      gender: gender ?? this.gender,
    );
  }

  /// Ameliyat sonrası geçen gün sayısı
  int daysSinceSurgery() {
    return DateTime.now().difference(surgeryDate).inDays;
  }

  /// Hasta kayıt sonrası geçen gün sayısı
  int daysSinceCreated() {
    return DateTime.now().difference(createdAt).inDays;
  }

  /// Hasta durumu (Aktif/Pasif)
  bool get isActive {
    if (lastMeasurement == null) return false;
    // Son 7 gün içinde ölçüm yapıldıysa aktif
    return DateTime.now().difference(lastMeasurement!).inDays <= 7;
  }

  /// Hasta başlangıç harfleri (Avatar için)
  String get initials {
    final names = fullName.split(' ');
    if (names.length >= 2) {
      return '${names[0][0]}${names[1][0]}'.toUpperCase();
    }
    return fullName.substring(0, 1).toUpperCase();
  }

  @override
  String toString() {
    return 'Patient(id: $id, name: $fullName, tc: $tcNo)';
  }
}