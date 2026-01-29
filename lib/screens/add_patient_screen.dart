import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/storage_service.dart';
import '../utils/app_colors.dart';
import '../utils/app_constants.dart';
import '../utils/helpers.dart';
import './scanner_page.dart';

/// Yeni hasta ekleme ekranı
class AddPatientScreen extends StatefulWidget {
  const AddPatientScreen({super.key});

  @override
  State<AddPatientScreen> createState() => _AddPatientScreenState();
}

class _AddPatientScreenState extends State<AddPatientScreen> {
  final _formKey = GlobalKey<FormState>();
  final StorageService _storage = StorageService();

  final _nameController = TextEditingController();
  final _tcController = TextEditingController();
  final _notesController = TextEditingController();
  final _ageController = TextEditingController();

  DateTime _surgeryDate = DateTime.now();
  String? _deviceMac;
  String? _selectedGender;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _tcController.dispose();
    _notesController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _scanDevice() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
      Permission.camera,
    ].request();

    if (!statuses[Permission.camera]!.isGranted) {
      if (!mounted) return;
      Helpers.showErrorSnackBar(
        context,
        AppConstants.cameraPermissionError,
      );
      return;
    }

    if (!mounted) return;
    final mac = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ScannerPage()),
    );

    if (mac != null) {
      if (!mounted) return; // widget hâlâ ekranda mı kontrol et
      setState(() {
        _deviceMac = mac;
      });
      Helpers.showSuccessSnackBar(context, 'Cihaz QR kodu okundu!');
    }
  }

  Future<void> _selectSurgeryDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _surgeryDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('tr', 'TR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _surgeryDate) {
      setState(() {
        _surgeryDate = picked;
      });
    }
  }

  Future<void> _savePatient() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_deviceMac == null) {
      Helpers.showErrorSnackBar(context, 'Lütfen cihaz QR kodunu tarayın!');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _storage.addPatient(
        deviceMac: _deviceMac!,
        fullName: _nameController.text.trim(),
        tcNo: _tcController.text.trim(),
        surgeryDate: _surgeryDate,
        notes: _notesController.text.trim(),
        age: _ageController.text.isNotEmpty
            ? int.tryParse(_ageController.text)
            : null,
        gender: _selectedGender,
      );

      if (!mounted) return;
      Helpers.showSuccessSnackBar(
        context,
        AppConstants.patientAddedSuccess,
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      Helpers.showErrorSnackBar(context, 'Hata: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Yeni Hasta Ekle'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildDeviceCard(),
            const SizedBox(height: 24),
            const Text(
              'Hasta Bilgileri',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _nameController,
              label: 'Ad Soyad *',
              icon: Icons.person,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Ad Soyad zorunludur';
                }
                if (value.trim().split(' ').length < 2) {
                  return 'Ad ve Soyad giriniz';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _tcController,
              label: 'TC Kimlik No *',
              icon: Icons.badge,
              keyboardType: TextInputType.number,
              maxLength: 11,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                if (value == null || value.length != 11) {
                  return 'TC Kimlik No 11 haneli olmalıdır';
                }
                if (!Helpers.validateTCKN(value)) {
                  return 'Geçersiz TC Kimlik No';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _ageController,
                    label: 'Yaş (Opsiyonel)',
                    icon: Icons.cake,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildGenderDropdown(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _selectSurgeryDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Ameliyat Tarihi *',
                  prefixIcon: Icon(Icons.calendar_today, color: AppColors.primary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                child: Text(
                  Helpers.formatDate(_surgeryDate),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _notesController,
              label: 'Doktor Notları (Opsiyonel)',
              icon: Icons.note_alt,
              maxLines: 4,
              hint: 'Özel notlar, öneriler veya önemli bilgiler...',
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _savePatient,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.save, size: 28),
                label: Text(
                  _isLoading ? 'Kaydediliyor...' : 'Hastayı Kaydet',
                  style: const TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: _deviceMac != null 
          ? AppColors.success.withValues(alpha: 0.1) 
          : AppColors.warning.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              _deviceMac != null ? Icons.check_circle : Icons.qr_code_scanner,
              color: _deviceMac != null ? AppColors.success : AppColors.warning,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              _deviceMac ?? 'Cihaz QR Kodu Taranmadı',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            if (_deviceMac != null) ...[
              const SizedBox(height: 4),
              Text(
                'MAC: $_deviceMac',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _scanDevice,
                icon: const Icon(Icons.qr_code_scanner),
                label: Text(_deviceMac != null ? 'Yeniden Tara' : 'QR Kodu Tara'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _deviceMac != null ? AppColors.success : AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
        counterText: '',
      ),
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
    );
  }

  Widget _buildGenderDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedGender, // eski 'value' yerine
      decoration: const InputDecoration(
        labelText: 'Cinsiyet',
        prefixIcon: Icon(Icons.wc, color: AppColors.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      items: const [
        DropdownMenuItem(value: 'E', child: Text('Erkek')),
        DropdownMenuItem(value: 'K', child: Text('Kadın')),
      ],
      onChanged: (value) {
        setState(() {
          _selectedGender = value;
        });
      },
    );
  }
}