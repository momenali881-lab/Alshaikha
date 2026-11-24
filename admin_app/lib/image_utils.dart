import 'dart:convert';
import 'package:flutter/material.dart';

/// Reads both legacy Firestore Base64 images and new Get Pronto HTTPS URLs.
Widget appImage(
  String source, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  ImageErrorWidgetBuilder? errorBuilder,
}) {
  final fallback = errorBuilder ??
      (BuildContext context, Object error, StackTrace? stackTrace) =>
          const Center(child: Icon(Icons.broken_image_outlined));
  final uri = Uri.tryParse(source);
  if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
    return Image.network(source, width: width, height: height, fit: fit, errorBuilder: fallback);
  }
  try {
    return Image.memory(base64Decode(source), width: width, height: height, fit: fit, errorBuilder: fallback);
  } catch (_) {
    return const Center(child: Icon(Icons.broken_image_outlined));
  }
}
