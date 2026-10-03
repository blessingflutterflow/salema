import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/ride.dart';
import '../../data/repositories/escort_repository.dart';
import '../../data/repositories/ride_repository.dart';
import '../auth/session_controller.dart';
import '../ride_request/ride_request_controller.dart';

/// Escort tier selection — three server-priced tiers (Standard / Premium /
/// Presidential). Booking creates an `escort` request and hands off to the
/// shared matching/tracking screen.
class EscortTierScreen extends ConsumerStatefulWidget {
  const EscortTierScreen({super.key, required this.args});
  final Map<String, dynamic>? args;

  @override
  ConsumerState<EscortTierScreen> createState() => _EscortTierScreenState();
}

class _EscortTierScreenState extends ConsumerState<EscortTierScreen> {
  List<EscortQuote> _tiers = [];
  int _selected = 0;
  bool _loading = true;
  bool _booking = false;

  String get _areaType => widget.args?['areaType'] as String? ?? 'suburb';
  String get _carYear => widget.args?['carYear'] as String? ?? 'y2020_2024';

  @override
  void initState() {
    super.initState();
    _loadQuotes();
  }

  Future<void> _loadQuotes() async {
    final s = ref.read(rideRequestProvider);
    try {
      final tiers = await ref.read(escortRepositoryProvider).quotes(
            distanceKm: s.distanceKm,
            areaType: _areaType,
            carYear: _carYear,
          );
      if (!mounted) return;
      setState(() {
        _tiers = tiers;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _book() async {
    if (_tiers.isEmpty) return;
    final tier = _tiers[_selected];
    final session = ref.read(sessionProvider);
    final s = ref.read(rideRequestProvider);
    if (session.uid == null || s.pickup == null || s.destination == null) return;

    setState(() => _booking = true);
    try {
      final repo = ref.read(rideRepositoryProvider);
      final active = await repo.activeRideForRider(session.uid!);
      final rideId = active?.id ??
          await repo.createRequest(Ride.newRequest(
            riderId: session.uid!,
            riderName: session.name,
            riderPhone: session.phone,
            pickup: s.pickup!,
            pickupAddress: s.pickupAddress,
            destination: s.destination!,
            destinationLabel: s.destinationLabel,
            tierId: tier.id,
            tierName: tier.label,
            fare: tier.price,
            distanceKm: s.distanceKm,
            serviceType: 'escort',
            numVehicles: tier.numVehicles,
            isArmed: tier.isArmed,
            areaType: _areaType,
            carYear: _carYear,
          ));
      if (mounted) context.push(AppRouter.matching, extra: rideId);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not request an escort. Try again.')));
      }
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.dark),
          onPressed: () => context.pop(),
        ),
        title: const Text('Choose protection',
            style: TextStyle(
                color: AppColors.dark,
                fontSize: 18,
                fontWeight: FontWeight.w800)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.green))
          : _tiers.isEmpty
              ? const Center(
                  child: Text('Could not load tiers. Go back and retry.',
                      style: TextStyle(color: AppColors.muted)))
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        itemCount: _tiers.length,
                        itemBuilder: (context, i) => _tierCard(_tiers[i], i),
                      ),
                    ),
                    _bookBar(),
                  ],
                ),
    );
  }

  Widget _tierCard(EscortQuote t, int i) {
    final selected = i == _selected;
    final icon = switch (t.id) {
      'presidential' => Icons.military_tech,
      'premium' => Icons.verified_user,
      _ => Icons.shield,
    };
    return GestureDetector(
      onTap: () => setState(() => _selected = i),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.selectedFill : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.selectedBorder : AppColors.line,
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: selected ? AppColors.green : AppColors.field,
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  color: selected ? Colors.white : AppColors.dark, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.label,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(
                    '${t.vehiclesText}${t.isArmed ? ' · armed' : ''}',
                    style: const TextStyle(
                        fontSize: 13.5, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            Text('R${t.price.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontSize: 19, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  Widget _bookBar() {
    final t = _tiers.isNotEmpty ? _tiers[_selected] : null;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Color(0x14000000), blurRadius: 16, offset: Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 54,
          child: ElevatedButton(
            onPressed: _booking ? null : _book,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green,
              foregroundColor: Colors.white,
              elevation: 0,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
            ),
            child: _booking
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(
                    t == null
                        ? 'Request escort'
                        : 'Request escort · R${t.price.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
          ),
        ),
      ),
    );
  }
}
