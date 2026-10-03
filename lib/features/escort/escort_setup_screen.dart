import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../ride_request/ride_request_controller.dart';
import '../ride_request/services/places_service.dart';

/// Escort setup — destination + the two pricing inputs (area type, car year),
/// then "Get quote" → the tier-selection screen.
class EscortSetupScreen extends ConsumerStatefulWidget {
  const EscortSetupScreen({super.key});

  @override
  ConsumerState<EscortSetupScreen> createState() => _EscortSetupScreenState();
}

const _areaTypes = [
  ('township', 'Township'),
  ('cbd', 'CBD'),
  ('suburb', 'Suburb'),
];
const _carYears = [
  ('pre2019', 'Before 2019'),
  ('y2020_2024', '2020–2024'),
  ('y2025_2026', '2025–2026'),
];

class _EscortSetupScreenState extends ConsumerState<EscortSetupScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<PlacePrediction> _predictions = [];
  String? _destPlaceId;
  String _destLabel = '';
  String _areaType = 'suburb';
  String _carYear = 'y2020_2024';
  bool _resolving = false;

  @override
  void initState() {
    super.initState();
    ref.read(rideRequestProvider.notifier).loadPickup();
    _controller.addListener(_onChanged);
  }

  void _onChanged() {
    _debounce?.cancel();
    final q = _controller.text;
    if (q.trim().length < 2) {
      setState(() => _predictions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 320), () async {
      final preds = await ref.read(placesServiceProvider).autocomplete(q);
      if (mounted) setState(() => _predictions = preds);
    });
  }

  void _pick(PlacePrediction p) {
    setState(() {
      _destPlaceId = p.placeId;
      _destLabel = p.primary;
      _controller.text = p.primary;
      _predictions = [];
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _getQuote() async {
    final placeId = _destPlaceId;
    if (placeId == null) return;
    setState(() => _resolving = true);
    final ok = await ref
        .read(rideRequestProvider.notifier)
        .chooseDestination(placeId, _destLabel);
    if (!mounted) return;
    setState(() => _resolving = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not resolve that destination.')));
      return;
    }
    context.push(AppRouter.escortTiers, extra: {
      'areaType': _areaType,
      'carYear': _carYear,
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pickup = ref.watch(rideRequestProvider).pickupAddress;
    final ready = _destPlaceId != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.dark),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: const [
            Icon(Icons.shield, color: AppColors.green, size: 22),
            SizedBox(width: 8),
            Text('Request an escort',
                style: TextStyle(
                    color: AppColors.dark,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Column(
              children: [
                _pickupRow(pickup),
                const SizedBox(height: 10),
                _destinationField(),
              ],
            ),
          ),
          Expanded(
            child: _predictions.isNotEmpty
                ? _predictionList()
                : _inputsForm(ready),
          ),
        ],
      ),
    );
  }

  Widget _pickupRow(String address) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
          color: AppColors.field, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(Icons.my_location, size: 20, color: AppColors.green),
          const SizedBox(width: 12),
          Expanded(
              child: Text(address,
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _destinationField() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.green, width: 2),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 22, color: AppColors.dark),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Destination',
                border: InputBorder.none,
                isCollapsed: true,
              ),
              style: const TextStyle(fontSize: 17),
            ),
          ),
        ],
      ),
    );
  }

  Widget _predictionList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _predictions.length,
      separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.line),
      itemBuilder: (context, i) {
        final p = _predictions[i];
        return ListTile(
          leading: const Icon(Icons.location_on_outlined,
              color: Color(0xFF7A7C86)),
          title: Text(p.primary, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(p.secondary,
              maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () => _pick(p),
        );
      },
    );
  }

  Widget _inputsForm(bool ready) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      children: [
        const Text('Pickup area',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('Helps us price the risk for your area.',
            style: TextStyle(fontSize: 13, color: AppColors.muted)),
        const SizedBox(height: 10),
        _pillRow(_areaTypes, _areaType, (v) => setState(() => _areaType = v)),
        const SizedBox(height: 22),
        const Text('Your vehicle',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('The vehicle being escorted.',
            style: TextStyle(fontSize: 13, color: AppColors.muted)),
        const SizedBox(height: 10),
        _pillRow(_carYears, _carYear, (v) => setState(() => _carYear = v)),
        const SizedBox(height: 30),
        SizedBox(
          height: 54,
          child: ElevatedButton(
            onPressed: ready && !_resolving ? _getQuote : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.line,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(27)),
            ),
            child: _resolving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Get quote',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
        ),
        if (!ready)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text('Pick a destination above to continue.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.muted)),
          ),
      ],
    );
  }

  Widget _pillRow(
    List<(String, String)> options,
    String selected,
    ValueChanged<String> onPick,
  ) {
    return Row(
      children: [
        for (final (id, label) in options) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => onPick(id),
              child: Container(
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected == id
                      ? AppColors.selectedFill
                      : AppColors.field,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected == id
                        ? AppColors.selectedBorder
                        : AppColors.line,
                    width: selected == id ? 1.5 : 1,
                  ),
                ),
                child: Text(label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: selected == id
                            ? AppColors.green
                            : AppColors.dark)),
              ),
            ),
          ),
          if (id != options.last.$1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}
