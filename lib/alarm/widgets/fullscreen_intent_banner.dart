import 'package:app_settings/app_settings.dart';
import 'package:clock_app/common/widgets/card_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// Dismissible warning banner shown on the alarm screen when the
/// USE_FULL_SCREEN_INTENT permission is not granted. On Android 14 and above
/// this permission has to be granted manually, otherwise alarms with missions
/// won't show over the lock screen. Tapping the banner opens the notification
/// settings.
class FullScreenIntentBanner extends StatelessWidget {
  const FullScreenIntentBanner({super.key, required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    ColorScheme colorScheme = theme.colorScheme;
    TextTheme textTheme = theme.textTheme;
    return Dismissible(
      key: const ValueKey("fullscreen_intent_banner"),
      direction: DismissDirection.horizontal,
      onDismissed: (_) => onDismiss(),
      child: CardContainer(
        color: colorScheme.errorContainer,
        margin: const EdgeInsets.fromLTRB(8.0, 4.0, 8.0, 4.0),
        onTap: () => AppSettings.openAppSettings(
            type: AppSettingsType.notification),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Icon(Icons.fullscreen_exit_rounded,
                  color: colorScheme.onErrorContainer),
              const SizedBox(width: 12.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!
                          .fullScreenIntentWarningTitle,
                      style: textTheme.titleSmall
                          ?.copyWith(color: colorScheme.onErrorContainer),
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      AppLocalizations.of(context)!
                          .fullScreenIntentWarningDescription,
                      style: textTheme.bodySmall
                          ?.copyWith(color: colorScheme.onErrorContainer),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                color: colorScheme.onErrorContainer,
                onPressed: () => onDismiss(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
