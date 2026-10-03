import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/map_style.dart';
import '../../data/models/ride.dart';
import '../../data/repositories/payment_repository.dart';
import '../../data/repositories/ride_repository.dart';
import '../auth/session_controller.dart';
import 'models/ride_tier.dart';
import 'ride_request_controller.dart';
import 'widgets/car_image.dart';
import 'widgets/map_markers.dart';

/// Screens 5118/5119 — ride options. Real route + real ZAR fares (R30 base +
/// R5/km, per-tier multiplier). Drag the sheet to see all 8 tiers.
class RideOptionsScreen extends ConsumerStatefulWidget {
  const RideOptionsScreen({super.key});

  @override
  ConsumerState<RideOptionsScreen> createState() => _RideOptionsScreenState();
}

class _RideOptionsScreenState extends ConsumerState<RideOptionsScreen> {
  GoogleMapController? _map;
  int _selected = 0;
  bool _requesting = false;

  /// 'cash' or 'card' (card = the rider's default vaulted card).
  String _payMethod = 'cash';
  PaymentMethod? _defaultCard;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadDefaultCard();
  }

  Future<void> _loadDefaultCard() async {
    final uid = ref.read(sessionProvider).uid;
    if (uid == null) return;
    final methods =
        await ref.read(paymentRepositoryProvider).watchMethods(uid).first;
    if (!mounted) return;
    setState(() {
      _defaultCard = methods.where((m) => m.isDefault).firstOrNull ??
          methods.firstOrNull;
      // Card by default when one is vaulted — the Uber-like experience.
      if (_defaultCard != null) _payMethod = 'card';
    });
  }

  Future<void> _choosePayment() async {
    final card = _defaultCard;
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 14),
            const Text('Pay with',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            ListTile(
              leading: const Icon(Icons.payments_outlined,
                  color: AppColors.green, size: 26),
              title: const Text('Cash',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Pay the driver directly'),
              trailing: _payMethod == 'cash'
                  ? const Icon(Icons.check_circle, color: AppColors.green)
                  : null,
              onTap: () => Navigator.pop(sheetContext, 'cash'),
            ),
            if (card != null)
              ListTile(
                leading: const Icon(Icons.credit_card,
                    color: AppColors.dark, size: 26),
                title: Text(card.label,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Charged automatically after the trip'),
                trailing: _payMethod == 'card'
                    ? const Icon(Icons.check_circle, color: AppColors.green)
                    : null,
                onTap: () => Navigator.pop(sheetContext, 'card'),
              )
            else
              ListTile(
                leading: const Icon(Icons.add_card,
                    color: AppColors.muted, size: 26),
                title: const Text('Add a card'),
                subtitle: const Text('Set up once, pay automatically'),
                onTap: () => Navigator.pop(sheetContext, 'add'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || chosen == null) return;
    if (chosen == 'add') {
      await context.push(AppRouter.payments);
      await _loadDefaultCard();
    } else {
      setState(() => _payMethod = chosen);
    }
  }

  @override
  void initState() {
    super.initState();
    MapMarkers.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
  }

  /// Create the ride request (server then dispatches to drivers) and head to
  /// the matching screen, which tracks that ride doc.
  Future<void> _requestRide() async {
    final s = ref.read(rideRequestProvider);
    final session = ref.read(sessionProvider);
    final tier = kRideTiers[_selected];

    if (session.uid == null || s.pickup == null || s.destination == null) {
      context.push(AppRouter.matching, extra: null); // graceful fallback
      return;
    }

    setState(() => _requesting = true);
    final repo = ref.read(rideRepositoryProvider);
    try {
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
            tierName: tier.name,
            fare: tier.fareValue(s.distanceKm),
            distanceKm: s.distanceKm,
            paymentMethod: _payMethod,
          ));
      if (mounted) context.push(AppRouter.matching, extra: rideId);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not request ride. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  void _fitRoute(RideRequestState s) {
    if (_map == null || s.pickup == null || s.destination == null) return;
    final p = s.pickup!, d = s.destination!;
    final bounds = LatLngBounds(
      southwest: LatLng(
        p.latitude < d.latitude ? p.latitude : d.latitude,
        p.longitude < d.longitude ? p.longitude : d.longitude,
      ),
      northeast: LatLng(
        p.latitude > d.latitude ? p.latitude : d.latitude,
        p.longitude > d.longitude ? p.longitude : d.longitude,
      ),
    );
    _map!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(rideRequestProvider);
    final size = MediaQuery.sizeOf(context);
    const sheetMin = 0.46;
    final km = s.distanceKm;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: s.pickup ?? const LatLng(-26.2041, 28.0473),
                zoom: 12,
              ),
              style: kDarkMapStyle,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              compassEnabled: false,
              padding: EdgeInsets.only(bottom: size.height * sheetMin),
              markers: {
                if (s.pickup != null)
                  Marker(
                    markerId: const MarkerId('pickup'),
                    position: s.pickup!,
                    icon: MapMarkers.person ?? BitmapDescriptor.defaultMarker,
                    anchor: const Offset(0.5, 0.9),
                  ),
                if (s.destination != null)
                  Marker(
                    markerId: const MarkerId('dest'),
                    position: s.destination!,
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueGreen),
                  ),
              },
              polylines: {
                if (s.hasRoute)
                  Polyline(
                    polylineId: const PolylineId('route'),
                    points: s.route!.points,
                    color: AppColors.green,
                    width: 4,
                    startCap: Cap.roundCap,
                    endCap: Cap.roundCap,
                  ),
              },
              onMapCreated: (c) {
                _map = c;
                Future.delayed(
                    const Duration(milliseconds: 250), () => _fitRoute(s));
              },
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: _topBar(s.destinationLabel),
            ),
          ),

          DraggableScrollableSheet(
            initialChildSize: sheetMin,
            minChildSize: sheetMin,
            maxChildSize: 0.92,
            builder: (context, scroll) => _sheet(scroll, km),
          ),
        ],
      ),
    );
  }

  Widget _topBar(String destination) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 3,
      shadowColor: Colors.black26,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              onPressed: () => context.pop(),
            ),
            Expanded(
              child: Container(
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.sheetField,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(destination.isEmpty ? 'Destination' : destination,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ),
            IconButton(icon: const Icon(Icons.add, size: 26), onPressed: () {}),
          ],
        ),
      ),
    );
  }

  Widget _sheet(ScrollController scroll, double km) {
    final tier = kRideTiers[_selected];
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
              color: Color(0x22000000), blurRadius: 25, offset: Offset(0, -5)),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 5,
            margin: const EdgeInsets.only(top: 12, bottom: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFE6E6E8),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scroll,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              itemCount: kRideTiers.length,
              itemBuilder: (context, i) => _tile(i, km),
            ),
          ),
          _payRow(),
          _cta(tier.name),
        ],
      ),
    );
  }

  Widget _tile(int i, double km) {
    final t = kRideTiers[i];
    final selected = _selected == i;
    return GestureDetector(
      onTap: () => setState(() => _selected = i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 74,
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.selectedFill : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.selectedBorder : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            _carIcon(t),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.name,
                      style: const TextStyle(
                          fontSize: 19, fontWeight: FontWeight.w800)),
                  Text('${t.etaMin} min  ·  ${t.seats} seats',
                      style: const TextStyle(
                          fontSize: 14, color: Color(0xFF73757F))),
                ],
              ),
            ),
            Text(t.price(km),
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  // Placeholder car icon (swapped for PNG art when assets arrive).
  Widget _carIcon(RideTier t) {
    return CarImage(
      tierId: t.id,
      fallbackIcon: t.icon,
      badge: t.badge,
      size: 52,
    );
  }

  Widget _payRow() {
    final card = _defaultCard;
    final usingCard = _payMethod == 'card' && card != null;
    return InkWell(
      onTap: _choosePayment,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFF1F1F1))),
        ),
        child: Row(
          children: [
            Icon(
              usingCard ? Icons.credit_card : Icons.payments_outlined,
              size: 22,
              color: usingCard ? AppColors.dark : AppColors.green,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(usingCard ? card.label : 'Cash',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w500)),
                  Text(
                      usingCard
                          ? 'Charged automatically after the trip'
                          : 'Pay the driver directly',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.muted)),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, color: AppColors.muted),
          ],
        ),
      ),
    );
  }

  Widget _cta(String tierName) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _requesting ? null : _requestRide,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28)),
                  ),
                  child: _requesting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        )
                      : Text('Select $tierName',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800)),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Container(
              width: 56,
              height: 56,
              decoration:
                  const BoxDecoration(color: AppColors.green, shape: BoxShape.circle),
              child: const Icon(Icons.schedule, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
