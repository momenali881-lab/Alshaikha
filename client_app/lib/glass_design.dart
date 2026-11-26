import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared visual language for the Al Sheikha glass interface.
class GlassDesign {
  static const champagne = Color(0xFFCBA96B);
  static const ink = Color(0xFF30271D);
  static const lightBg = Color(0xFFF4F0E8);
  static const darkBg = Color(0xFF101114);

  static ThemeData get light => _build(false);
  static ThemeData get dark => _build(true);

  static ThemeData _build(bool dark) {
    final canvas = dark ? darkBg : lightBg;
    final foreground = dark ? const Color(0xFFF4EBDD) : ink;
    final accent = champagne;
    final surface = dark ? const Color(0xCC24262B) : const Color(0xCCFFFFFF);
    final outline = dark ? const Color(0x44E8D7B7) : const Color(0x66B69A68);
    final base = ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: dark ? Brightness.dark : Brightness.light,
        surface: surface,
      ),
      scaffoldBackgroundColor: canvas,
      textTheme: GoogleFonts.ibmPlexSansArabicTextTheme(
        dark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
      ).apply(bodyColor: foreground, displayColor: foreground),
      iconTheme: IconThemeData(color: dark ? const Color(0xFFE4C78F) : const Color(0xFF735B36)),
      dividerTheme: DividerThemeData(color: outline, thickness: 0.7, space: 1),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: BorderSide(color: outline, width: 0.8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0x992E3035) : const Color(0xBFFFFFFF),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
        hintStyle: TextStyle(color: foreground.withOpacity(.48), fontSize: 13),
        labelStyle: TextStyle(color: foreground.withOpacity(.72)),
        prefixIconColor: accent,
        suffixIconColor: accent,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(19),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(19),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(19),
          borderSide: const BorderSide(color: champagne, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(19),
          borderSide: const BorderSide(color: Color(0xFFD66C65)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(19),
          borderSide: const BorderSide(color: Color(0xFFD66C65), width: 1.5),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: canvas.withOpacity(.72),
        foregroundColor: foreground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: const Color(0xFF241C11),
          disabledBackgroundColor: accent.withOpacity(.35),
          disabledForegroundColor: foreground.withOpacity(.45),
          elevation: 0,
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: .1),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: foreground,
          minimumSize: const Size(48, 50),
          side: BorderSide(color: outline),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: dark ? const Color(0xFFE7CA91) : const Color(0xFF735B36),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: accent.withOpacity(.28),
        side: BorderSide(color: outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        labelStyle: TextStyle(color: foreground, fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: dark ? const Color(0xF024262B) : const Color(0xF9FFFEFA),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: BorderSide(color: outline, width: .9),
        ),
        titleTextStyle: TextStyle(color: foreground, fontSize: 19, fontWeight: FontWeight.w900),
        contentTextStyle: TextStyle(color: foreground, height: 1.5),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: dark ? const Color(0xF0222429) : const Color(0xF7F8F5EF),
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: dark ? const Color(0xF0222429) : const Color(0xF7F8F5EF),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: accent.withOpacity(.25),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w900 : FontWeight.w600,
          color: foreground,
        )),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: champagne,
        foregroundColor: Color(0xFF241C11),
        elevation: 2,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: champagne),
    );
    return base;
  }
}

/// A real blurred glass panel; use around content cards and grouped controls.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 26,
    this.margin = EdgeInsets.zero,
    this.tint,
    this.blur = 16,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final EdgeInsetsGeometry margin;
  final Color? tint;
  final double blur;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final border = dark ? Colors.white.withOpacity(.13) : const Color(0xFFB69A68).withOpacity(.25);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(dark ? .20 : .055),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: tint ?? (dark ? const Color(0xB824262B) : const Color(0xCFFFFFFF)),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: border, width: .9),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: dark
                    ? [Colors.white.withOpacity(.075), Colors.white.withOpacity(.018)]
                    : [Colors.white.withOpacity(.82), Colors.white.withOpacity(.38)],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Glassy gradient action with consistent touch target and press feedback.
class GlassActionButton extends StatelessWidget {
  const GlassActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.secondary = false,
    this.expanded = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool secondary;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = secondary
        ? (dark ? const Color(0xFFF1E5D0) : const Color(0xFF59452F))
        : const Color(0xFF241C11);
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 19),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: secondary
                ? null
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFE8D2A5), Color(0xFFC49A55)],
                  ),
            color: secondary ? (dark ? Colors.white.withOpacity(.07) : Colors.white.withOpacity(.58)) : null,
            border: Border.all(color: secondary ? const Color(0x66C49A55) : Colors.white.withOpacity(.55)),
          ),
          child: Row(
            mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[Icon(icon, color: fg, size: 19), const SizedBox(width: 9)],
              Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ),
    );
    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}
