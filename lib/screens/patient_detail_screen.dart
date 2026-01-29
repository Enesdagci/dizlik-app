import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/patient_model.dart';
import '../services/storage_service.dart';
import '../services/ble_service.dart';
import '../utils/app_colors.dart';
import '../utils/app_constants.dart';
import '../utils/helpers.dart';
import '../widgets/medical_chart.dart';

/// Hasta detay ve ölçüm ekranı
class PatientDetailScreen extends StatefulWidget {
  final Patient patient;

  const PatientDetailScreen({super.key, required this.patient});

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  final BleService _ble = BleService();
  final StorageService _storage = StorageService();

  String _status = AppConstants.noDataMessage;
  String _liveTemp = '--';
  String _battery = '--';

  List<FlSpot> hotSpotData = [];
  List<FlSpot> baseLineData = [];
  Map<double, String> timeLabels = {};
  double _timeIndex = 0;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _loadPatientData();
    _setupListeners();
  }

  @override
  void dispose() {
    _ble.disconnect();
    super.dispose();
  }

  void _loadPatientData() {
    final data = _storage.getLatestMeasurement(widget.patient.id);
    if (data != null) {
      setState(() {
        hotSpotData = data['hotSpotData'];
        baseLineData = data['baseLineData'];
        timeLabels = data['timeLabels'];
        if (hotSpotData.isNotEmpty) {
          _timeIndex = hotSpotData.last.x + 1;
        }
        _status = 'Geçmiş veriler yüklendi';
      });
    }
  }

  void _setupListeners() {
    _ble.statusStream.listen((status) {
      if (mounted) {
        setState(() => _status = status);
        if (status.contains('Hata') || status.contains('hatası')) {
          _isConnecting = false;
        }
      }
    });

    _ble.liveTempStream.listen((temp) {
      if (mounted) {
        setState(() {
          if (_status != 'Canlı Takip Modu') _status = 'Canlı Takip Modu';
          _liveTemp = temp.toStringAsFixed(1);
          _isConnecting = false;
        });
      }
    });

    _ble.batteryStream.listen((level) {
      if (mounted) setState(() => _battery = level.toString());
    });

    _ble.logLineStream.listen((line) {
      if (line == 'EOF') {
        if (mounted) {
          setState(() => _status = 'Veriler güncellendi');
          _saveMeasurement();
          _ble.clearDeviceLogs();
        }
      } else {
        _processLogLine(line);
      }
    });
  }

  void _processLogLine(String line) {
    try {
      List<String> parts = line.split(',');
      if (parts.length == 6) {
        String time = parts[0];
        List<double> temps = parts.sublist(1).map((s) => double.parse(s)).toList();
        double maxTemp = [temps[0], temps[1], temps[2], temps[3]].reduce((a, b) => a > b ? a : b);
        double controlTemp = temps[4];

        if (mounted) {
          setState(() {
            hotSpotData.add(FlSpot(_timeIndex, maxTemp));
            baseLineData.add(FlSpot(_timeIndex, controlTemp));
            timeLabels[_timeIndex] = time;
            _timeIndex++;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Veri işleme hatası: $line');
    }
  }

  Future<void> _saveMeasurement() async {
    try {
      await _storage.saveMeasurement(
        patientId: widget.patient.id,
        hotSpotData: hotSpotData,
        baseLineData: baseLineData,
        timeLabels: timeLabels,
      );
      if (mounted) {
        Helpers.showSuccessSnackBar(context, AppConstants.measurementSavedSuccess);
      }
    } catch (e) {
      if (mounted) {
        Helpers.showErrorSnackBar(context, 'Kayıt hatası: ${e.toString()}');
      }
    }
  }

  Future<void> _connectDevice() async {
    if (_isConnecting) return;

    final shouldConnect = await Helpers.showConfirmDialog(
      context: context,
      title: 'Cihaza Bağlan',
      message: 'Mevcut grafik verileri silinecek ve yeni ölçüm başlayacak. Devam etmek istiyor musunuz?',
      confirmText: 'Bağlan',
      cancelText: 'İptal',
    );

    if (!shouldConnect) return;

    setState(() => _isConnecting = true);

    try {
      await _ble.disconnect();
      setState(() {
        hotSpotData.clear();
        baseLineData.clear();
        timeLabels.clear();
        _timeIndex = 0;
        _liveTemp = '--';
        _battery = '--';
        _status = AppConstants.connectingMessage;
      });
      await _ble.connect(widget.patient.deviceMac);
    } catch (e) {
      if (mounted) {
        Helpers.showErrorSnackBar(context, '${AppConstants.connectionError}: ${e.toString()}');
        setState(() {
          _isConnecting = false;
          _status = AppConstants.disconnectedMessage;
        });
      }
    }
  }

  Future<void> _exportToCSV() async {
    if (hotSpotData.isEmpty) {
      Helpers.showErrorSnackBar(context, 'Paylaşılacak veri yok!');
      return;
    }

    try {
      Helpers.showLoadingDialog(context, 'CSV hazırlanıyor...');

      String csvContent = 'HASTA BİLGİLERİ\n';
      csvContent += 'Ad Soyad,${widget.patient.fullName}\n';
      csvContent += 'TC,${widget.patient.tcNo}\n';
      csvContent += 'Ameliyat,${Helpers.formatDate(widget.patient.surgeryDate)}\n';
      csvContent += 'Ölçüm,${Helpers.formatDateTime(DateTime.now())}\n\n';
      csvContent += 'Sıra,Zaman,Sıcak Nokta,Kontrol,Fark\n';

      for (int i = 0; i < hotSpotData.length; i++) {
        double x = hotSpotData[i].x;
        double hot = hotSpotData[i].y;
        double base = (i < baseLineData.length) ? baseLineData[i].y : 0;
        String time = timeLabels[x] ?? '?';
        csvContent += '${i + 1},$time,${hot.toStringAsFixed(2)},${base.toStringAsFixed(2)},${(hot - base).toStringAsFixed(2)}\n';
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${widget.patient.fullName}_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csvContent);

      if (mounted) {
        Helpers.hideLoadingDialog(context);
        await Share.shareXFiles([XFile(file.path)], text: '${widget.patient.fullName} - Veriler');
      }
    } catch (e) {
      if (mounted) {
        Helpers.hideLoadingDialog(context);
        Helpers.showErrorSnackBar(context, 'Export hatası: ${e.toString()}');
      }
    }
  }

  void _showMeasurementHistory() {
    final measurements = _storage.getAllMeasurements(widget.patient.id);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Geçmiş Ölçümler',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Expanded(
              child: measurements.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          const Text('Henüz ölçüm kaydı yok', style: TextStyle(color: AppColors.textSecondary)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: measurements.length,
                      itemBuilder: (context, index) {
                        final m = measurements[index];
                        final date = DateTime.parse(m['timestamp']);
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primary,
                              child: Text('${index + 1}', style: const TextStyle(color: Colors.white)),
                            ),
                            title: Text(Helpers.formatDateTime(date)),
                            subtitle: Text('${m['hotSpotData'].length} veri noktası'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              setState(() {
                                hotSpotData = m['hotSpotData'];
                                baseLineData = m['baseLineData'];
                                timeLabels = m['timeLabels'];
                              });
                              Navigator.pop(context);
                              Helpers.showSuccessSnackBar(context, 'Ölçüm yüklendi');
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.patient.fullName),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'CSV Paylaş',
            onPressed: _exportToCSV,
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Geçmiş Kayıtlar',
            onPressed: _showMeasurementHistory,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Hasta bilgi kartı
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Hero(
                    tag: 'patient_avatar_${widget.patient.id}',
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white,
                      child: Text(
                        widget.patient.initials,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.patient.fullName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ameliyat Sonrası ${widget.patient.daysSinceSurgery()} Gün',
                    style: const TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ],
              ),
            ),

            // Durum kartları
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(child: _infoCard('Durum', _status, Icons.bluetooth, AppColors.bluetooth)),
                  const SizedBox(width: 8),
                  Expanded(child: _infoCard('Canlı', '$_liveTemp°C', Icons.thermostat, AppColors.temperature)),
                  const SizedBox(width: 8),
                  Expanded(child: _infoCard('Pil', '%$_battery', Icons.battery_std, AppColors.battery)),
                ],
              ),
            ),

            // Grafik
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 10)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Termal Analiz Grafiği',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: MedicalChart(
                        hotSpotData: hotSpotData,
                        baseLineData: baseLineData,
                        timeLabels: timeLabels,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bağlan butonu
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isConnecting ? null : _connectDevice,
                  icon: _isConnecting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                        )
                      : const Icon(Icons.bluetooth_searching, size: 28),
                  label: Text(
                    _isConnecting ? 'Bağlanıyor...' : 'Cihaza Bağlan ve Ölç',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 4)],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          FittedBox(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}