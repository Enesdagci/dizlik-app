/// Uygulama genelinde kullanılan sabit değerler
class AppConstants {
  AppConstants._();

  // Uygulama Bilgileri
  static const String appName = 'Dizlik Takip Sistemi';
  static const String appVersion = '1.0.0';
  static const String projectInfo = 'TÜBİTAK 2209-A Projesi';
  
  // Veritabanı
  static const String patientsBox = 'patients';
  static const String measurementsBox = 'measurements';
  
  // Bluetooth UUID'ler
  static const String serviceUUID = '12345678-1234-1234-1234-1234567890ab';
  static const String tempUUID = 'abcd1234-5678-90ab-cdef-1234567890ab';
  static const String setTimeUUID = '13333333-3333-3333-3333-333333333333';
  static const String getLogsUUID = '13333333-4444-4444-4444-444444444444';
  static const String sendLogsUUID = '13333333-5555-5555-5555-555555555555';
  static const String clearLogsUUID = '13333333-6666-6666-6666-666666666666';
  static const String batteryUUID = '13333333-7777-7777-7777-777777777777';
  
  // Zaman Aşımı Süreleri
  static const int connectionTimeout = 15; // saniye
  static const int scanTimeout = 10; // saniye
  
  // Grafik Ayarları
  static const double minTemperature = 20.0;
  static const double maxTemperature = 40.0;
  static const double normalBodyTemp = 36.5;
  static const double feverThreshold = 37.5;
  
  // Mesajlar
  static const String noDataMessage = 'Henüz veri bulunmuyor';
  static const String loadingMessage = 'Yükleniyor...';
  static const String connectingMessage = 'Bağlanıyor...';
  static const String connectedMessage = 'Bağlantı başarılı';
  static const String disconnectedMessage = 'Bağlantı kesildi';
  static const String errorMessage = 'Bir hata oluştu';
  
  // Hata Mesajları
  static const String bluetoothPermissionError = 'Bluetooth izni gerekli';
  static const String cameraPermissionError = 'Kamera izni gerekli';
  static const String connectionError = 'Bağlantı hatası';
  static const String dataError = 'Veri okuma hatası';
  
  // Başarı Mesajları
  static const String patientAddedSuccess = 'Hasta başarıyla eklendi';
  static const String patientUpdatedSuccess = 'Hasta bilgileri güncellendi';
  static const String patientDeletedSuccess = 'Hasta kaydı silindi';
  static const String measurementSavedSuccess = 'Ölçüm kaydedildi';
  static const String dataClearedSuccess = 'Veriler temizlendi';
}