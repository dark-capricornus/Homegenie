import 'package:flutter/material.dart';

/// All Stitch design tokens for HomeGenie
class AppColors {
  // ── Dark Theme ──────────────────────────────────────────────
  static const darkBackground = Color(0xFF0F0F13);
  static const darkSurface = Color(0xFF1C1C22);
  static const darkSurface2 = Color(0xFF25252F);
  static const darkBorder = Color(0xFF2A2A35);
  static const darkBorderLight = Color(0xFF3A3A48);

  // ── Light Theme ─────────────────────────────────────────────
  static const lightBackground = Color(0xFFF4F5F7);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurface2 = Color(0xFFF0F1F3);
  static const lightBorder = Color(0xFFE5E7EB);
  static const lightBorderDark = Color(0xFFD1D5DB);

  // ── Shared / Brand ──────────────────────────────────────────
  static const primary = Color(0xFF137FEC);
  static const primaryLight = Color(0xFF3B9AEF);
  static const primaryDim = Color(0x1A137FEC); // 10% opacity
  static const success = Color(0xFF17CF17);
  static const successDim = Color(0x1A17CF17);
  static const error = Color(0xFFE53935);
  static const errorDim = Color(0x1AE53935);
  static const warning = Color(0xFFFF9800);
  static const warningDim = Color(0x1AFF9800);
  static const purple = Color(0xFF7C3AED);
  static const purpleDim = Color(0x1A7C3AED);
  static const orange = Color(0xFFFF6B35);
  static const green = Color(0xFF10B981);
  static const teal = Color(0xFF14B8A6);

  // ── Text ───────────────────────────────────────────────────
  static const darkTextPrimary = Color(0xFFFFFFFF);
  static const darkTextSecondary = Color(0xFF9E9EA7);
  static const darkTextTertiary = Color(0xFF5A5A6A);
  static const lightTextPrimary = Color(0xFF0F0F13);
  static const lightTextSecondary = Color(0xFF6B7280);
  static const lightTextTertiary = Color(0xFF9CA3AF);

  // ── Status Badges ──────────────────────────────────────────
  static const badgeCriticalBg = Color(0xFFFFEBEE);
  static const badgeCriticalText = Color(0xFFE53935);
  static const badgeRoutineBg = Color(0xFFE3F2FD);
  static const badgeRoutineText = Color(0xFF137FEC);
  static const badgeUpdateBg = Color(0xFFE8EAF6);
  static const badgeUpdateText = Color(0xFF5C6BC0);
  static const badgeCameraBg = Color(0xFFF3E5F5);
  static const badgeCameraText = Color(0xFF7C3AED);
  static const badgeSecurityBg = Color(0xFFE8F5E9);
  static const badgeSecurityText = Color(0xFF17CF17);

  // ── Aliases for UI Components ──────────────────────────────
  static const surfaceDark = darkSurface;
  static const textPrimaryLight = lightTextPrimary;
  static const textSecondaryLight = lightTextSecondary;
  static const secondary =
      Color(0xFF9E9EA7); // Matching darkTextSecondary for now
}
