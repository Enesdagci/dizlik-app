import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../utils/app_colors.dart';
import '../utils/helpers.dart';
import 'package:permission_handler/permission_handler.dart';

/// QR kod tarama ekranı
class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> with WidgetsBindingObserver {
  bool isScanCompleted = false;
  bool isTorchOn = false;
  MobileScannerController? controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeScanner();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (controller == null) return;

    switch (state) {
      case AppLifecycleState.resumed:
        // Uygulama ön plana geldiğinde kamerayı başlat
        controller?.start();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        // Uygulama arka plana gittiğinde kamerayı durdur
        controller?.stop();
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  Future<void> _initializeScanner() async {
    // İzin kontrolü
    final status = await Permission.camera.status;
    
    if (status.isDenied) {
      final result = await Permission.camera.request();
      if (!result.isGranted) {
        if (mounted) {
          _showPermissionDialog();
        }
        return;
      }
    } else if (status.isPermanentlyDenied) {
      if (mounted) {
        _showPermissionDialog();
      }
      return;
    }

    // İzin varsa controller'ı oluştur
    setState(() {
      controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
      );
    });
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kamera İzni Gerekli'),
        content: const Text(
          'QR kod okuyabilmek için kamera iznine ihtiyacımız var. '
          'Lütfen ayarlardan "Kamera" iznini açın.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
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

  void _onDetect(BarcodeCapture capture) {
    if (isScanCompleted) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String? macAddress = barcodes.first.rawValue;

      if (macAddress != null && macAddress.isNotEmpty) {
        setState(() {
          isScanCompleted = true;
        });

        Helpers.showSuccessSnackBar(context, 'QR kod okundu!');
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          Navigator.pop(context, macAddress);
        });
      }
    }
  }

  void _toggleTorch() {
    controller?.toggleTorch();
    setState(() {
      isTorchOn = !isTorchOn;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Cihaz QR Kodu Tara'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (controller != null)
            IconButton(
              icon: Icon(isTorchOn ? Icons.flash_on : Icons.flash_off),
              onPressed: _toggleTorch,
              tooltip: isTorchOn ? 'Flaşı Kapat' : 'Flaşı Aç',
            ),
        ],
      ),
      body: Stack(
        children: [
          if (controller != null)
            MobileScanner(
              controller: controller!,
              onDetect: _onDetect,
              errorBuilder: (context, error, child) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error,
                        color: Colors.red,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Kamera hatası',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          error.errorDetails?.message ?? 'Bilinmeyen hata',
                          style: const TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => openAppSettings(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                        ),
                        child: const Text('Ayarlara Git'),
                      ),
                    ],
                  ),
                );
              },
            )
          else
            const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            ),
          Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.primary,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Stack(
                children: [
                  _CornerWidget(alignment: Alignment.topLeft),
                  _CornerWidget(alignment: Alignment.topRight),
                  _CornerWidget(alignment: Alignment.bottomLeft),
                  _CornerWidget(alignment: Alignment.bottomRight),
                ],
              ),
            ),
          ),
          if (!isScanCompleted && controller != null)
            const Center(
              child: SizedBox(
                width: 280,
                height: 280,
                child: ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                  child: _ScannerAnimation(),
                ),
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.qr_code_scanner,
                    color: AppColors.primary,
                    size: 40,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Cihazın üzerindeki QR kodu\nkameranın önüne tutun',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          if (isScanCompleted)
            Container(
              color: AppColors.success.withValues(alpha: 0.3),
              child: const Center(
                child: Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 80,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CornerWidget extends StatelessWidget {
  final Alignment alignment;

  const _CornerWidget({required this.alignment});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          border: Border(
            top: alignment.y < 0
                ? const BorderSide(color: AppColors.accent, width: 4)
                : BorderSide.none,
            bottom: alignment.y > 0
                ? const BorderSide(color: AppColors.accent, width: 4)
                : BorderSide.none,
            left: alignment.x < 0
                ? const BorderSide(color: AppColors.accent, width: 4)
                : BorderSide.none,
            right: alignment.x > 0
                ? const BorderSide(color: AppColors.accent, width: 4)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _ScannerAnimation extends StatefulWidget {
  const _ScannerAnimation();

  @override
  State<_ScannerAnimation> createState() => _ScannerAnimationState();
}

class _ScannerAnimationState extends State<_ScannerAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Align(
          alignment: Alignment(0, -1 + (_controller.value * 2)),
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Colors.transparent,
                  AppColors.primary,
                  Colors.transparent,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.5),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
