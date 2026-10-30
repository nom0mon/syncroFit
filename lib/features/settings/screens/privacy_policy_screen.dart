import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/responsive_layout.dart';

/// Privacy policy screen describing how SyncroFit collects, uses, and protects
/// member data in accordance with the Philippine Data Privacy Act of 2012
/// (Republic Act No. 10173).
///
/// Reachable from the hamburger menu and the Settings screen, and linked from
/// the sign-up data-privacy consent so members can read it before agreeing.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: SafeArea(
        child: ResponsiveConstrainedPage(
          child: ListView(
            key: const Key('privacy-policy-list'),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            children: [
              Text(
                'SyncroFit Privacy Policy',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Your data is protected under Republic Act No. 10173, the '
                'Data Privacy Act of 2012.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const _PolicySection(
                title: '1. Who We Are',
                body:
                    'SyncroFit is the personal information controller for the '
                    'data you provide. We are committed to processing your '
                    'personal data fairly, lawfully, and transparently, '
                    'consistent with RA 10173 (the Data Privacy Act of 2012), '
                    'its Implementing Rules and Regulations, and the issuances '
                    'of the National Privacy Commission (NPC).',
              ),
              const _PolicySection(
                title: '2. Information We Collect',
                body:
                    'To create your fitness profile and generate personalized '
                    'workout plans, we collect:\n\n'
                    '• Account details: username and email address.\n'
                    '• Profile details: first and last name, age, gender, '
                    'height, and weight.\n'
                    '• Fitness details: your goal, fitness level, training '
                    'location preference, and weekly availability.\n'
                    '• Progress data: weight entries and private progress '
                    'photos you choose to upload.\n'
                    '• Activity data: generated and completed workouts and '
                    'community posts you create.',
              ),
              const _PolicySection(
                title: '3. How We Use Your Information',
                body:
                    'We process your personal data only for legitimate '
                    'purposes, including to:\n\n'
                    '• Authenticate you and secure your account.\n'
                    '• Compute your BMI and generate recommendations based on '
                    'your goal, fitness level, and training location.\n'
                    '• Track your progress over time.\n'
                    '• Provide community features you choose to use.\n\n'
                    'We do not sell your personal data.',
              ),
              const _PolicySection(
                title: '4. Legal Basis and Consent',
                body:
                    'We rely on your consent, given at sign-up, as the legal '
                    'basis for processing your personal data under Section 12 '
                    'of RA 10173. You may withdraw your consent at any time by '
                    'contacting us or deleting your account; withdrawal does '
                    'not affect processing already performed.',
              ),
              const _PolicySection(
                title: '5. Data Storage and Security',
                body:
                    'Your data is transmitted over encrypted connections and '
                    'stored on secured servers. Progress photos are kept '
                    'private to your account. We apply organizational, '
                    'physical, and technical security measures proportionate '
                    'to the sensitivity of the information, as required by the '
                    'Data Privacy Act.',
              ),
              const _PolicySection(
                title: '6. Your Rights as a Data Subject',
                body:
                    'Under RA 10173 you have the right to be informed, to '
                    'access, to object, to rectify, to erasure or blocking, '
                    'to data portability, to damages, and to lodge a complaint '
                    'with the National Privacy Commission. You can review and '
                    'edit your profile data from within the app at any time.',
              ),
              const _PolicySection(
                title: '7. Data Retention',
                body:
                    'We retain your personal data only for as long as your '
                    'account is active or as needed to provide the service. '
                    'When you delete your account, your personal data is '
                    'removed except where retention is required by law.',
              ),
              const _PolicySection(
                title: '8. Contact Us',
                body:
                    'For privacy concerns or to exercise your rights as a data '
                    'subject, contact our Data Protection Officer through the '
                    'support channels listed in the app. You may also contact '
                    'the National Privacy Commission at privacy.gov.ph.',
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'By creating an account and using SyncroFit, you acknowledge '
                'that you have read and understood this Privacy Policy.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  const _PolicySection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(body, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
