import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/brand.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/session.dart';
import '../../shared/widgets/fade_in.dart';
import '../../shared/widgets/primary_button.dart';
import 'session_controller.dart';

/// After verifying their phone, the user chooses how they'll use Sift.
class RoleSelectScreen extends ConsumerStatefulWidget {
  const RoleSelectScreen({super.key});

  @override
  ConsumerState<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends ConsumerState<RoleSelectScreen> {
  /// 'rider' | 'driver' | 'security'
  String? _selected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How do you want to use ${Brand.current.name}?',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.dark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'You can change this later in settings.',
                      style: TextStyle(fontSize: 15, color: AppColors.muted),
                    ),
                    const SizedBox(height: 28),
                    FadeInUp(
                      child: _roleCard(
                        value: 'rider',
                        icon: Icons.person_outline,
                        title: 'I need a ride or escort',
                        subtitle: 'Book trips or request a security escort.',
                      ),
                    ),
                    const SizedBox(height: 16),
                    FadeInUp(
                      delay: const Duration(milliseconds: 90),
                      child: _roleCard(
                        value: 'driver',
                        icon: Icons.directions_car_outlined,
                        title: 'I want to drive',
                        subtitle: 'Earn money driving on your schedule.',
                      ),
                    ),
                    const SizedBox(height: 16),
                    FadeInUp(
                      delay: const Duration(milliseconds: 180),
                      child: _roleCard(
                        value: 'security',
                        icon: Icons.shield_outlined,
                        title: 'I provide security escorts',
                        subtitle: 'PSIRA-registered officer offering escorts.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: PrimaryButton(
                label: 'Continue',
                enabled: _selected != null,
                onPressed: _selected == null
                    ? null
                    : () {
                        final notifier = ref.read(sessionProvider.notifier);
                        // Security provider = a driver-type responder in the
                        // security pool; rider/driver map directly.
                        notifier.setRole(_selected == 'rider'
                            ? UserRole.rider
                            : UserRole.driver);
                        notifier.setProviderType(
                            _selected == 'security' ? 'security' : 'driver');
                        context.go(AppRouter.profile);
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roleCard({
    required String value,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final selected = _selected == value;
    return GestureDetector(
      onTap: () => setState(() => _selected = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected ? AppColors.selectedFill : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.selectedBorder : AppColors.line,
            width: selected ? 2 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: selected ? AppColors.green : AppColors.field,
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  size: 28, color: selected ? Colors.white : AppColors.dark),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.dark)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.muted, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
