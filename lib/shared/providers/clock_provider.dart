import 'package:flutter_riverpod/flutter_riverpod.dart';

final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
