import 'package:flutter/material.dart';

/// Uygulama genelinde kullanılan renk paleti
class AppColors {
  AppColors._(); // Private constructor

  // Ana Renkler
  static const Color primary = Color(0xFF00897B); // Teal 600
  static const Color primaryDark = Color(0xFF00695C); // Teal 800
  static const Color primaryLight = Color(0xFF4DB6AC); // Teal 300
  
  static const Color accent = Color(0xFFFF6F00); // Orange 900
  static const Color accentLight = Color(0xFFFFB74D); // Orange 300
  
  // Arka Plan Renkleri
  static const Color background = Color(0xFFF5F7FA);
  static const Color surface = Colors.white;
  static const Color cardBackground = Colors.white;
  
  // Metin Renkleri
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFFBDBDBD);
  
  // Durum Renkleri
  static const Color success = Color(0xFF4CAF50); // Green
  static const Color warning = Color(0xFFFFA726); // Orange
  static const Color error = Color(0xFFE53935); // Red
  static const Color info = Color(0xFF42A5F5); // Blue
  
  // Grafik Renkleri
  static const Color hotSpot = Color(0xFFE53935); // Kırmızı - Sıcak nokta
  static const Color baseline = Color(0xFF9E9E9E); // Gri - Kontrol sensörü
  static const Color gridLine = Color(0xFFE0E0E0);
  
  // Özel Renkler
  static const Color bluetooth = Color(0xFF2196F3);
  static const Color battery = Color(0xFF4CAF50);
  static const Color temperature = Color(0xFFFF9800);
  
  // Gölge Renkleri
  static Color shadow = Colors.black.withValues(alpha: 0.1);
  static Color shadowDark = Colors.black.withValues(alpha: 0.2);
}