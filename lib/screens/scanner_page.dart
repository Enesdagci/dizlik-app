import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/app_colors.dart';
import '../utils/helpers.dart';

/// QR kod tarama ekranı - 3 yöntem: Kamera, Galeri, Manuel
class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _manualController = TextEditingController();
  
  bool _showManualInput = false;
  bool _showCameraScanner = false;
  MobileScannerController? _cameraController;

  @override
  void dispose() {
    _cameraController?.dispose();
    _manualController.dispose();
    super.dispose();
  }

  // Galeriden QR kod okuma
  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
      );

      if (image == null) return;

      // Galeriden seçilen fotoğrafı mobile_scanner ile analiz et
      final controller = MobileScannerController();
      
      // Fotoğrafı analiz et
      final BarcodeCapture? capture = await controller.analyzeImage(image.path);
      
      await controller.dispose();

      if (capture != null && capture.barcodes.isNotEmpty) {
        final String? macAddress = capture.barcodes.first.rawValue;
        
        if (macAddress != null && macAddress.isNotEmpty) {
          if (mounted) {
            Helpers.showSuccessSnackBar(context, 'QR kod galeriden okundu!');
            Navigator.pop(context, macAddress);
          }
        } else {
          if (mounted) {
            _showErrorDialog('QR kod bulunamadı', 
              'Seçtiğiniz fotoğrafta geçerli bir QR kod bulunamadı.');
          }
        }
      } else {
        if (mounted) {
          _showErrorDialog('QR kod okunamadı', 
            'Lütfen QR kodun net görüldüğü bir fotoğraf seçin.');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Hata', 'Fotoğraf analiz edilirken hata oluştu: $e');
      }
    }
  }

  // Kamera ile QR kod okuma
  Future<void> _openCameraScanner() async {
    // Önce izin kontrol et
    final status = await Permission.camera.status;
    
    if (status.isDenied) {
      final result = await Permission.camera.request();
      if (!result.isGranted) {
        _showPermissionDialog();
        return;
      }
    } else if (status.isPermanentlyDenied) {
      _showPermissionDialog();
      return;
    }

    // İzin varsa kamera scanner'ı aç
    setState(() {
      _showCameraScanner = true;
      _cameraController = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
      );
    });
  }

  // Manuel MAC adresi girişi
  void _openManualInput() {
    setState(() {
      _showManualInput = true;
    });
  }

  void _submitManualInput() {
    final macAddress = _manualController.text.trim();
    
    if (macAddress.isEmpty) {
      Helpers.showErrorSnackBar(context, 'Lütfen MAC adresi girin');
      return;
    }

    // MAC adresi formatı kontrolü (opsiyonel)
    final macRegex = RegExp(r'^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$');
    if (!macRegex.hasMatch(macAddress)) {
      _showErrorDialog('Geçersiz Format', 
        'MAC adresi formatı: AA:BB:CC:DD:EE:FF\nÖrnek: 12:34:56:78:9A:BC');
      return;
    }

    Helpers.showSuccessSnackBar(context, 'MAC adresi kaydedildi!');
    Navigator.pop(context, macAddress);
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kamera İzni Gerekli'),
        content: const Text(
          'Kamera ile QR kod okumak için izin gerekiyor.\n\n'
          'Alternatif olarak:\n'
          '• Galeriden QR fotoğrafı seçebilirsiniz\n'
          '• Manuel olarak MAC adresini girebilirsiniz',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              openAppSettings();
              Navigator.pop(context);
            },
            child: const Text('Ayarlara Git'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  void _onCameraDetect(BarcodeCapture capture) {
    if (capture.barcodes.isEmpty) return;

    final String? macAddress = capture.barcodes.first.rawValue;

    if (macAddress != null && macAddress.isNotEmpty) {
      Helpers.showSuccessSnackBar(context, 'QR kod okundu!');
      Navigator.pop(context, macAddress);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Manuel giriş ekranı
    if (_showManualInput) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('MAC Adresi Gir'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => setState(() => _showManualInput = false),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.edit,
                size: 80,
                color: AppColors.primary,
              ),
              const SizedBox(height: 32),
              const Text(
                'Dizlik üzerindeki MAC adresini girin',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _manualController,
                decoration: InputDecoration(
                  labelText: 'MAC Adresi',
                  hintText: 'AA:BB:CC:DD:EE:FF',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.bluetooth),
                ),
                keyboardType: TextInputType.text,
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 12),
              Text(
                'Format: AA:BB:CC:DD:EE:FF veya AA-BB-CC-DD-EE-FF',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _submitManualInput,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Kaydet',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Kamera scanner ekranı
    if (_showCameraScanner && _cameraController != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text('QR Kod Tara'),
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              _cameraController?.dispose();
              setState(() {
                _showCameraScanner = false;
                _cameraController = null;
              });
            },
          ),
        ),
        body: MobileScanner(
          controller: _cameraController!,
          onDetect: _onCameraDetect,
        ),
      );
    }

    // Ana seçim ekranı
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cihaz Bağlantısı'),
        backgroundColor: AppColors.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            const Icon(
              Icons.qr_code_scanner,
              size: 100,
              color: AppColors.primary,
            ),
            const SizedBox(height: 24),
            const Text(
              'QR Kodu Nasıl Okumak İstersiniz?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            
            // Kamera ile tara
            _buildOptionCard(
              icon: Icons.camera_alt,
              title: 'Kamera ile Tara',
              subtitle: 'Kamerayı QR kodun üzerine tutun',
              onTap: _openCameraScanner,
              color: Colors.blue,
            ),
            
            const SizedBox(height: 16),
            
            // Galeriden seç
            _buildOptionCard(
              icon: Icons.photo_library,
              title: 'Galeriden Seç',
              subtitle: 'QR kod fotoğrafını galeriden seçin',
              onTap: _pickFromGallery,
              color: Colors.green,
            ),
            
            const SizedBox(height: 16),
            
            // Manuel giriş
            _buildOptionCard(
              icon: Icons.keyboard,
              title: 'Manuel Gir',
              subtitle: 'MAC adresini elle girin',
              onTap: _openManualInput,
              color: Colors.orange,
            ),
            
            const Spacer(),
            
            Text(
              'Dizlik üzerindeki QR kodu okuyarak\ncihaza bağlanabilirsiniz',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: color,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
