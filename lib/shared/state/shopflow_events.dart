import 'package:flutter/foundation.dart';

/// Lightweight app-wide notifications for successfully persisted changes.
abstract final class ShopFlowEvents {
  static final ValueNotifier<int> dataRevision = ValueNotifier<int>(0);

  static void notifyDataChanged() {
    dataRevision.value++;
  }
}