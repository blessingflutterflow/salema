import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One priced escort tier from the server (`getEscortQuotes`).
class EscortQuote {
  const EscortQuote({
    required this.id,
    required this.label,
    required this.numVehicles,
    required this.isArmed,
    required this.price,
  });

  final String id; // standard | premium | presidential
  final String label;
  final int numVehicles;
  final bool isArmed;
  final double price;

  String get vehiclesText =>
      numVehicles == 1 ? '1 officer' : '$numVehicles officers';

  factory EscortQuote.fromMap(Map<dynamic, dynamic> m) => EscortQuote(
        id: (m['id'] ?? '').toString(),
        label: (m['label'] ?? '').toString(),
        numVehicles: (m['numVehicles'] as num?)?.toInt() ?? 1,
        isArmed: m['isArmed'] == true,
        price: (m['price'] as num?)?.toDouble() ?? 0,
      );
}

/// Escort pricing previews. Prices come from the server (admin-editable
/// config), so the client never computes money — it only displays.
class EscortRepository {
  EscortRepository({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  Future<List<EscortQuote>> quotes({
    required double distanceKm,
    required String areaType,
    required String carYear,
  }) async {
    final res = await _functions
        .httpsCallable('getEscortQuotes')
        .call<Map<dynamic, dynamic>>({
      'distanceKm': distanceKm,
      'areaType': areaType,
      'carYear': carYear,
    });
    final tiers = (res.data['tiers'] as List?) ?? [];
    return tiers
        .whereType<Map>()
        .map((t) => EscortQuote.fromMap(t))
        .toList();
  }
}

final escortRepositoryProvider =
    Provider<EscortRepository>((ref) => EscortRepository());
