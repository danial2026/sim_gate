import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../config/theme.dart';
import '../providers/config_provider.dart';
import '../widgets/common/app_widgets.dart';

/// Page 3: Display the API endpoint URL + QR code for sharing.
class ApiEndpointPage extends StatelessWidget {
  const ApiEndpointPage({super.key});

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ConfigProvider>().config;
    final apiUrl = config.apiUrl;
    final apiUrlWithToken = config.apiUrlWithToken;

    return SimGateScaffold(
      title: 'API Endpoint',
      body: ListView(
        children: [
          const Text(
            'API Endpoint',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Scan the QR code or copy the URL to connect a client.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SectionHeader('QR Code'),
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.dividerColor),
              ),
              child: QrImageView(
                data: apiUrlWithToken,
                version: QrVersions.auto,
                size: 240,
                backgroundColor: AppTheme.surfaceColor,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: AppTheme.textPrimary,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: AppTheme.textPrimary,
                ),
                errorStateBuilder: (_, error) => Center(
                  child: Text(
                    'QR too long: $error',
                    style: const TextStyle(color: AppTheme.errorColor),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader('URL'),
          _UrlTile(label: 'Base URL', value: apiUrl),
          _UrlTile(
              label: 'Auth Header',
              value: 'Authorization: Bearer ${config.accessToken ?? '—'}'),
          const SectionHeader('Example'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.dividerColor),
            ),
            child: SelectableText(
              'curl -X GET "$apiUrl/sms/status?requestId=demo" \\\n'
              '  -H "Authorization: Bearer ${config.accessToken ?? 'TOKEN'}"',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontFamily: AppTheme.monoFamily,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Copy URL',
            icon: Icons.copy_outlined,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: apiUrl));
              if (!context.mounted) return;
              _toast(context, 'URL copied to clipboard');
            },
          ),
          const SizedBox(height: 8),
          SecondaryButton(
            label: 'Copy as cURL',
            icon: Icons.terminal,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(
                  text:
                      'curl -X GET "$apiUrl/sms/status?requestId=demo" \\\n'
                      '  -H "Authorization: Bearer ${config.accessToken ?? 'TOKEN'}"'));
              if (!context.mounted) return;
              _toast(context, 'cURL copied to clipboard');
            },
          ),
          const SizedBox(height: 8),
          SecondaryButton(
            label: 'Back',
            icon: Icons.arrow_back,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.surfaceColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _UrlTile extends StatelessWidget {
  const _UrlTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          SelectableText(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontFamily: AppTheme.monoFamily,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
