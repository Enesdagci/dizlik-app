import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Yardımcı fonksiyonlar ve uzantılar
class Helpers {
  Helpers._();

  /// Tarihi "15 Ocak 2024" formatında döndürür
  static String formatDate(DateTime date) {
    return DateFormat('d MMMM y', 'tr_TR').format(date);
  }

  /// Tarihi "15.01.2024" formatında döndürür
  static String formatDateShort(DateTime date) {
    return DateFormat('dd.MM.yyyy').format(date);
  }

  /// Saati "14:30" formatında döndürür
  static String formatTime(DateTime date) {
    return DateFormat('HH:mm').format(date);
  }

  /// Tarih ve saati "15.01.2024 14:30" formatında döndürür
  static String formatDateTime(DateTime date) {
    return DateFormat('dd.MM.yyyy HH:mm').format(date);
  }

  /// Şu andan itibaren geçen süreyi hesaplar
  /// Örn: "5 dakika önce", "2 saat önce", "3 gün önce"
  static String timeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return 'Az önce';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} dakika önce';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} saat önce';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} gün önce';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks hafta önce';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months ay önce';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years yıl önce';
    }
  }

  /// TC Kimlik No doğrulama
  static bool validateTCKN(String tckn) {
    if (tckn.length != 11) return false;
    if (tckn[0] == '0') return false;

    try {
      final digits = tckn.split('').map((e) => int.parse(e)).toList();
      
      // İlk 10 hanenin toplamının birler basamağı 11. haneye eşit olmalı
      int sum = 0;
      for (int i = 0; i < 10; i++) {
        sum += digits[i];
      }
      if (sum % 10 != digits[10]) return false;

      // 1,3,5,7,9. hanelerin toplamının 7 katından 2,4,6,8. hanelerin toplamı çıkarıldığında
      // elde edilen sonucun birler basamağı 10. haneye eşit olmalı
      int oddSum = digits[0] + digits[2] + digits[4] + digits[6] + digits[8];
      int evenSum = digits[1] + digits[3] + digits[5] + digits[7];
      if ((oddSum * 7 - evenSum) % 10 != digits[9]) return false;

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Sıcaklık durumuna göre renk döndürür
  static Color getTemperatureColor(double temperature) {
    if (temperature < 35.0) {
      return Colors.blue; // Düşük
    } else if (temperature >= 35.0 && temperature < 37.5) {
      return Colors.green; // Normal
    } else if (temperature >= 37.5 && temperature < 38.5) {
      return Colors.orange; // Hafif yüksek
    } else {
      return Colors.red; // Yüksek
    }
  }

  /// Sıcaklık durumuna göre açıklama döndürür
  static String getTemperatureStatus(double temperature) {
    if (temperature < 35.0) {
      return 'Düşük';
    } else if (temperature >= 35.0 && temperature < 37.5) {
      return 'Normal';
    } else if (temperature >= 37.5 && temperature < 38.5) {
      return 'Hafif Yüksek';
    } else {
      return 'Yüksek';
    }
  }

  /// Başarı mesajı göster
  static void showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Hata mesajı göster
  static void showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Bilgi mesajı göster
  static void showInfoSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Onay dialogu göster
  static Future<bool> showConfirmDialog({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'Evet',
    String cancelText = 'İptal',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Loading dialog göster
  static void showLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message),
          ],
        ),
      ),
    );
  }

  /// Loading dialog kapat
  static void hideLoadingDialog(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }
}