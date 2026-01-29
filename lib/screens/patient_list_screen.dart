import 'package:flutter/material.dart';
import '../models/patient_model.dart';
import '../services/storage_service.dart';
import '../utils/app_colors.dart';
import '../utils/helpers.dart';
import '../widgets/empty_state_widgets.dart';
import '../widgets/loading_widgets.dart';
import './add_patient_screen.dart';
import './patient_detail_screen.dart';

/// Ana ekran - Hasta listesi
class PatientListScreen extends StatefulWidget {
  const PatientListScreen({super.key});

  @override
  State<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends State<PatientListScreen> {
  final StorageService _storage = StorageService();
  List<Patient> _patients = [];
  List<Patient> _filteredPatients = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPatients() async {
    setState(() => _isLoading = true);
    
    await Future.delayed(const Duration(milliseconds: 500));
    
    setState(() {
      _patients = _storage.getAllPatients();
      _filteredPatients = _patients;
      _isLoading = false;
    });
  }

  void _searchPatients(String query) {
    setState(() {
      _filteredPatients = _storage.searchPatients(query);
    });
  }

  Future<void> _refreshPatients() async {
    await _loadPatients();
    if (mounted) {
      Helpers.showInfoSnackBar(context, 'Liste güncellendi');
    }
  }

  // ✅ YENİ: Hasta silme fonksiyonu
  Future<void> _deletePatient(Patient patient) async {
    final shouldDelete = await Helpers.showConfirmDialog(
      context: context,
      title: 'Hastayı Sil',
      message: '${patient.fullName} adlı hastayı ve tüm ölçüm verilerini silmek istediğinize emin misiniz?\n\nBu işlem geri alınamaz!',
      confirmText: 'Sil',
      cancelText: 'İptal',
    );

    if (!shouldDelete) return;

    try {
      await _storage.deletePatient(patient.id);
      if (mounted) {
        Helpers.showSuccessSnackBar(context, 'Hasta başarıyla silindi');
        _loadPatients();
      }
    } catch (e) {
      if (mounted) {
        Helpers.showErrorSnackBar(context, 'Silme hatası: ${e.toString()}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Hasta Yönetim Sistemi',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfoDialog(),
            tooltip: 'Bilgi',
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingWidget(message: 'Hastalar yükleniyor...')
          : RefreshIndicator(
              onRefresh: _refreshPatients,
              color: AppColors.primary,
              child: Column(
                children: [
                  _buildHeader(),
                  _buildStatistics(),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _filteredPatients.isEmpty
                        ? _buildEmptyState()
                        : _buildPatientList(),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddPatient,
        icon: const Icon(Icons.person_add),
        label: const Text('Yeni Hasta'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: TextField(
              controller: _searchController,
              onChanged: _searchPatients,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Hasta adı veya TC ile ara...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                prefixIcon: const Icon(Icons.search, color: Colors.white),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white),
                        onPressed: () {
                          _searchController.clear();
                          _searchPatients('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.2),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatistics() {
    final totalPatients = _patients.length;
    final activePatients = _storage.getActivePatients().length;
    final weekPatients = _storage.getPatientsThisWeek().length;
    final totalMeasurements = _storage.getTotalMeasurementCount();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _statCard(
              'Toplam Hasta',
              totalPatients.toString(),
              Icons.people,
              AppColors.info,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _statCard(
              'Aktif',
              activePatients.toString(),
              Icons.trending_up,
              AppColors.success,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _statCard(
              'Bu Hafta',
              weekPatients.toString(),
              Icons.calendar_today,
              AppColors.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _statCard(
              'Ölçümler',
              totalMeasurements.toString(),
              Icons.assessment,
              AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    if (_searchController.text.isNotEmpty) {
      return EmptyStateWidget(
        icon: Icons.search_off,
        title: 'Sonuç Bulunamadı',
        subtitle: '"${_searchController.text}" için hasta bulunamadı',
      );
    }

    return EmptyStateWidget(
      icon: Icons.person_off,
      title: 'Henüz Hasta Eklenmemiş',
      subtitle: 'Yeni hasta eklemek için + butonuna basın',
      actionText: 'Yeni Hasta Ekle',
      onActionPressed: _navigateToAddPatient,
    );
  }

  Widget _buildPatientList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      itemCount: _filteredPatients.length,
      itemBuilder: (context, index) {
        return _patientCard(_filteredPatients[index], index);
      },
    );
  }

  Widget _patientCard(Patient patient, int index) {
    final daysSinceSurgery = patient.daysSinceSurgery();
    final measurementCount = _storage.getMeasurementCount(patient.id);
    final hasRecentMeasurement = patient.lastMeasurement != null &&
        patient.lastMeasurement!.isAfter(
          DateTime.now().subtract(const Duration(hours: 24)),
        );

    return TweenAnimationBuilder(
      duration: Duration(milliseconds: 300 + (index * 50)),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          onTap: () => _navigateToPatientDetail(patient),
          // ✅ YENİ: Uzun basınca menü açılır
          onLongPress: () => _showPatientOptionsMenu(patient),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Hero(
                  tag: 'patient_avatar_${patient.id}',
                  child: CircleAvatar(
                    radius: 32,
                    backgroundColor:
                        hasRecentMeasurement ? AppColors.success : AppColors.warning,
                    child: Text(
                      patient.initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient.fullName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'TC: ${patient.tcNo}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Ameliyat: $daysSinceSurgery gün önce',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.assessment,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$measurementCount ölçüm kaydı',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if (patient.lastMeasurement != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              '• ${Helpers.timeAgo(patient.lastMeasurement!)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textHint,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // ✅ YENİ: Menü butonu
                IconButton(
                  icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
                  onPressed: () => _showPatientOptionsMenu(patient),
                  tooltip: 'Seçenekler',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ✅ YENİ: Hasta seçenekleri menüsü
  void _showPatientOptionsMenu(Patient patient) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.primary,
                child: Icon(Icons.person, color: Colors.white),
              ),
              title: Text(
                patient.fullName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('TC: ${patient.tcNo}'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.visibility, color: AppColors.info),
              title: const Text('Hasta Detayını Görüntüle'),
              onTap: () {
                Navigator.pop(context);
                _navigateToPatientDetail(patient);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: AppColors.error),
              title: const Text('Hastayı Sil'),
              onTap: () {
                Navigator.pop(context);
                _deletePatient(patient);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _navigateToAddPatient() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddPatientScreen()),
    );
    if (result == true) {
      _loadPatients();
    }
  }

  void _navigateToPatientDetail(Patient patient) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PatientDetailScreen(patient: patient),
      ),
    );
    _loadPatients();
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hakkında'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Diz Artroplastisi Takip Sistemi'),
            SizedBox(height: 8),
            Text(
              'TÜBİTAK 2209-A Projesi',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              'Bu uygulama diz ameliyatı sonrası termal izleme için geliştirilmiştir.',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }
}