import 'package:flutter/foundation.dart';
import 'dart:io';

Future<bool> hasInternet() async {
  if (kIsWeb) return true; // Browser handles connectivity or uses other APIs
  try {
    final result = await InternetAddress.lookup('google.com');
    return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
  } catch (_) {
    return false;
  }
}
