import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/foundation.dart';
import '../utils/app_constants.dart';

/// Bluetooth Low Energy bağlantı ve veri işlemlerini yöneten servis
class BleService {
  static final BleService _instance = BleService._internal();
  factory BleService() => _instance;
  BleService._internal();

  BluetoothDevice? connectedDevice;

  // Karakteristikler
  BluetoothCharacteristic? tempChar;
  BluetoothCharacteristic? sendLogsChar;
  BluetoothCharacteristic? setTimeChar;
  BluetoothCharacteristic? getLogsChar;
  BluetoothCharacteristic? batteryChar;
  BluetoothCharacteristic? clearLogsChar;

  // Stream controller'lar
  final _statusController = StreamController<String>.broadcast();
  final _liveTempController = StreamController<double>.broadcast();
  final _batteryController = StreamController<int>.broadcast();
  final _logLineController = StreamController<String>.broadcast();

  // Public stream'ler
  Stream<String> get statusStream => _statusController.stream;
  Stream<double> get liveTempStream => _liveTempController.stream;
  Stream<int> get batteryStream => _batteryController.stream;
  Stream<String> get logLineStream => _logLineController.stream;

  // Bağlantı durumu
  bool get isConnected => connectedDevice?.isConnected ?? false;

  /// Cihaza bağlanır
  Future<void> connect(String macAddress) async {
    // Önceki bağlantıyı temizle
    await disconnect();

    _statusController.add('Bağlanıyor...');

    try {
      connectedDevice = BluetoothDevice.fromId(macAddress.trim());

      debugPrint('🔵 Cihaza bağlanılıyor: $macAddress');

      await connectedDevice!.connect(
        timeout: const Duration(seconds: AppConstants.connectionTimeout),
        autoConnect: false,
      );

      _statusController.add('Servisler keşfediliyor...');

      // Android'de stabilite için kısa bekleme
      await Future.delayed(const Duration(milliseconds: 1000));

      await _discoverServices();
    } catch (e) {
      final errorMsg = 'Bağlantı hatası: ${e.toString()}';
      debugPrint('❌ $errorMsg');
      _statusController.add(errorMsg);
      await disconnect();
      rethrow;
    }
  }

  /// Servisleri keşfeder ve karakteristikleri bulur
  Future<void> _discoverServices() async {
    if (connectedDevice == null) {
      _statusController.add('Cihaz bulunamadı');
      return;
    }

    try {
      debugPrint('🔍 Servisler aranıyor...');
      var services = await connectedDevice!.discoverServices();

      bool serviceFound = false;

      for (var service in services) {
        if (service.uuid.toString().toLowerCase() ==
            AppConstants.serviceUUID.toLowerCase()) {
          serviceFound = true;
          debugPrint('✅ Ana servis bulundu: ${service.uuid}');

          for (var c in service.characteristics) {
            String u = c.uuid.toString().toLowerCase();

            if (u == AppConstants.tempUUID.toLowerCase()) {
              tempChar = c;
              debugPrint('  📡 Sıcaklık karakteristiği bulundu');
            }
            if (u == AppConstants.sendLogsUUID.toLowerCase()) {
              sendLogsChar = c;
              debugPrint('  📡 Log gönderme karakteristiği bulundu');
            }
            if (u == AppConstants.setTimeUUID.toLowerCase()) {
              setTimeChar = c;
              debugPrint('  📡 Zaman ayarlama karakteristiği bulundu');
            }
            if (u == AppConstants.getLogsUUID.toLowerCase()) {
              getLogsChar = c;
              debugPrint('  📡 Log alma karakteristiği bulundu');
            }
            if (u == AppConstants.batteryUUID.toLowerCase()) {
              batteryChar = c;
              debugPrint('  📡 Pil karakteristiği bulundu');
            }
            if (u == AppConstants.clearLogsUUID.toLowerCase()) {
              clearLogsChar = c;
              debugPrint('  📡 Log temizleme karakteristiği bulundu');
            }
          }
        }
      }

      if (!serviceFound) {
        _statusController.add('Uyumlu servis bulunamadı');
        debugPrint('❌ Beklenen UUID eşleşmedi');
        return;
      }

      if (getLogsChar != null) {
        _statusController.add('Bağlandı. Veriler alınıyor...');
        await _startListening();
        await _syncTime();
        await Future.delayed(const Duration(milliseconds: 500));
        await requestLogs();
      } else {
        _statusController.add('Gerekli karakteristikler bulunamadı');
      }
    } catch (e) {
      final errorMsg = 'Servis keşif hatası: ${e.toString()}';
      debugPrint('❌ $errorMsg');
      _statusController.add(errorMsg);
      rethrow;
    }
  }

  /// Bildirim dinleyicilerini başlatır
  Future<void> _startListening() async {
    try {
      // Sıcaklık verisi dinleyicisi
      if (tempChar != null) {
        await tempChar!.setNotifyValue(true);
        tempChar!.onValueReceived.listen((value) {
          if (value.length >= 4) {
            final floatVal = ByteData.view(Uint8List.fromList(value).buffer)
                .getFloat32(0, Endian.little);

            if (floatVal == -999.0) {
              // EOF sinyali
              _logLineController.add('EOF');
              debugPrint('📨 Veri akışı tamamlandı (EOF)');
            } else {
              _liveTempController.add(floatVal);
              debugPrint('🌡️ Canlı sıcaklık: ${floatVal.toStringAsFixed(1)}°C');
            }
          }
        }, onError: (error) {
          debugPrint('❌ Sıcaklık dinleme hatası: $error');
        });
      }

      // Log verisi dinleyicisi
      if (sendLogsChar != null) {
        await sendLogsChar!.setNotifyValue(true);
        sendLogsChar!.onValueReceived.listen((value) {
          String line = utf8.decode(value).trim();
          if (line.isNotEmpty) {
            _logLineController.add(line);
            debugPrint('📝 Log satırı alındı: $line');
          }
        }, onError: (error) {
          debugPrint('❌ Log dinleme hatası: $error');
        });
      }

      // Pil seviyesi dinleyicisi
      if (batteryChar != null) {
        await batteryChar!.setNotifyValue(true);
        batteryChar!.onValueReceived.listen((value) {
          if (value.isNotEmpty) {
            _batteryController.add(value[0]);
            debugPrint('🔋 Pil seviyesi: %${value[0]}');
          }
        }, onError: (error) {
          debugPrint('❌ Pil dinleme hatası: $error');
        });
      }

      debugPrint('✅ Tüm dinleyiciler aktif');
    } catch (e) {
      debugPrint('❌ Dinleyici başlatma hatası: $e');
      rethrow;
    }
  }

  /// Cihazdan log verilerini talep eder
  Future<void> requestLogs() async {
    if (getLogsChar != null) {
      try {
        await getLogsChar!.write(utf8.encode('GET'));
        debugPrint('📤 Log talebi gönderildi');
      } catch (e) {
        debugPrint('❌ Log talep hatası: $e');
        rethrow;
      }
    } else {
      debugPrint('⚠️ Log karakteristiği mevcut değil');
    }
  }

  /// Cihaz hafızasını temizler
  Future<void> clearDeviceLogs() async {
    if (clearLogsChar != null) {
      try {
        await clearLogsChar!.write(utf8.encode('CLEAR'));
        _statusController.add('Cihaz hafızası temizlendi');
        debugPrint('🗑️ Cihaz hafızası temizlendi');
      } catch (e) {
        debugPrint('❌ Hafıza temizleme hatası: $e');
        rethrow;
      }
    } else {
      debugPrint('⚠️ Temizleme karakteristiği mevcut değil');
    }
  }

  /// Cihaz saatini senkronize eder
  Future<void> _syncTime() async {
    if (setTimeChar != null) {
      try {
        int timestamp = (DateTime.now().millisecondsSinceEpoch / 1000).floor();
        await setTimeChar!.write(utf8.encode(timestamp.toString()));
        debugPrint('🕐 Cihaz saati senkronize edildi: $timestamp');
      } catch (e) {
        debugPrint('❌ Saat senkronizasyon hatası: $e');
      }
    }
  }

  /// Bağlantıyı keser ve kaynakları temizler
  Future<void> disconnect() async {
    try {
      if (connectedDevice != null && connectedDevice!.isConnected) {
        debugPrint('🔌 Bağlantı kesiliyor...');

        // Bildirimleri kapat (hata olsa bile devam et)
        try {
          if (tempChar != null) await tempChar!.setNotifyValue(false);
          if (sendLogsChar != null) await sendLogsChar!.setNotifyValue(false);
          if (batteryChar != null) await batteryChar!.setNotifyValue(false);
        } catch (e) {
          debugPrint('⚠️ Bildirim kapatma hatası (göz ardı edildi): $e');
        }

        await connectedDevice?.disconnect();
      }
    } catch (e) {
      debugPrint('⚠️ Bağlantı kesme hatası: $e');
    } finally {
      // Her durumda referansları temizle
      connectedDevice = null;
      tempChar = null;
      sendLogsChar = null;
      setTimeChar = null;
      getLogsChar = null;
      batteryChar = null;
      clearLogsChar = null;

      _statusController.add('Bağlantı kesildi');
      _liveTempController.add(0.0);
      _batteryController.add(0);

      debugPrint('✅ Bağlantı tamamen temizlendi');
    }
  }

  /// Servisi temizler (uygulama kapanırken)
  void dispose() {
    _statusController.close();
    _liveTempController.close();
    _batteryController.close();
    _logLineController.close();
    debugPrint('🧹 BLE Servisi kapatıldı');
  }
}