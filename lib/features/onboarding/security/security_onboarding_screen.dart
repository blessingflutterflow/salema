import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/session.dart';
import '../../../data/repositories/application_repository.dart';
import '../../auth/session_controller.dart';

/// Security-provider onboarding — PSIRA credentials. Submits the application
/// (pending) and reuses the shared pending-review screen. A provider can't go
/// online until an admin verifies these.
class SecurityOnboardingScreen extends ConsumerStatefulWidget {
  const SecurityOnboardingScreen({super.key});

  @override
  ConsumerState<SecurityOnboardingScreen> createState() =>
      _SecurityOnboardingScreenState();
}

const _grades = ['A', 'B', 'C', 'D', 'E'];
const _vehicles = [('car', 'Car'), ('bike', 'Bike'), ('foot', 'On foot')];

class _SecurityOnboardingScreenState
    extends ConsumerState<SecurityOnboardingScreen> {
  final _psira = TextEditingController();
  final _badge = TextEditingController();
  String _grade = 'C';
  String _vehicle = 'car';
  bool _armed = true;
  bool _submitting = false;

  @override
  void dispose() {
    _psira.dispose();
    _badge.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final session = ref.read(sessionProvider);
    final uid = session.uid;
    if (uid == null) return;
    if (_psira.text.trim().length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enter a valid PSIRA registration number.')));
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(applicationRepositoryProvider).submit(
        uid: uid,
        role: UserRole.driver,
        providerType: 'security',
        vehicle: {'type': _vehicle},
        documents: const {},
        security: {
          'psiraNumber': _psira.text.trim(),
          'psiraGrade': _grade,
          'isArmed': _armed,
          'vehicleType': _vehicle,
          'badgeNumber': _badge.text.trim(),
        },
      );
      ref.read(sessionProvider.notifier).submitDriverApplication();
      if (mounted) context.go(AppRouter.pending);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not submit. Please try again.')));
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Security credentials',
            style: TextStyle(
                color: AppColors.dark,
                fontSize: 18,
                fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          const Text(
            'We verify every officer before they can take escorts. Your PSIRA '
            'details are reviewed by our team (1–2 business days).',
            style: TextStyle(color: AppColors.muted, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 22),
          _label('PSIRA registration number'),
          _field(_psira, hint: 'e.g. 1234567', keyboard: TextInputType.number),
          const SizedBox(height: 18),
          _label('PSIRA grade'),
          _pillRow(
            [for (final g in _grades) (g, 'Grade $g')],
            _grade,
            (v) => setState(() => _grade = v),
          ),
          const SizedBox(height: 18),
          _label('Vehicle'),
          _pillRow(_vehicles, _vehicle, (v) => setState(() => _vehicle = v)),
          const SizedBox(height: 18),
          _label('Badge / ID number (optional)'),
          _field(_badge, hint: 'e.g. SG-1194', keyboard: TextInputType.text),
          const SizedBox(height: 18),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: AppColors.green,
            value: _armed,
            onChanged: (v) => setState(() => _armed = v),
            title: const Text('Armed officer',
                style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('Carrying a licensed firearm on duty',
                style: TextStyle(color: AppColors.muted, fontSize: 13)),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(27)),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Submit for verification',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t,
            style:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      );

  Widget _field(TextEditingController c,
      {required String hint, required TextInputType keyboard}) {
    return TextField(
      controller: c,
      keyboardType: keyboard,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.field,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _pillRow(
    List<(String, String)> options,
    String selected,
    ValueChanged<String> onPick,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (id, label) in options)
          GestureDetector(
            onTap: () => onPick(id),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color:
                    selected == id ? AppColors.selectedFill : AppColors.field,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected == id
                      ? AppColors.selectedBorder
                      : AppColors.line,
                  width: selected == id ? 1.5 : 1,
                ),
              ),
              child: Text(label,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color:
                          selected == id ? AppColors.green : AppColors.dark)),
            ),
          ),
      ],
    );
  }
}
