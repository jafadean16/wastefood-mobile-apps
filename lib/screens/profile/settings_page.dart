import 'package:flutter/material.dart';
import 'package:wastefood/l10n/app_localizations.dart';

class SettingsPage extends StatefulWidget {
  final Function(Locale) onLocaleChange;
  final Function(bool) onDarkModeChange;
  final bool isDarkMode;

  const SettingsPage({
    super.key,
    required this.onLocaleChange,
    required this.onDarkModeChange,
    required this.isDarkMode,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late bool _isDarkMode;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.isDarkMode;
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          localizations.settings,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        elevation: 3,
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        shadowColor: Colors.green.withValues(alpha: 0.05),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _buildSettingCard(
              icon: Icons.language,
              title: localizations.language,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Locale>(
                  value: Localizations.localeOf(context),
                  borderRadius: BorderRadius.circular(12),
                  dropdownColor: Colors.green.shade50,
                  iconEnabledColor: Colors.green.shade600,
                  items: const [
                    DropdownMenuItem(
                      value: Locale('id'),
                      child: Text("🇮🇩  Bahasa Indonesia"),
                    ),
                    DropdownMenuItem(
                      value: Locale('en'),
                      child: Text("🇺🇸  English"),
                    ),
                  ],
                  onChanged: (locale) {
                    if (locale != null) widget.onLocaleChange(locale);
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildSettingCard(
              icon: Icons.dark_mode_rounded,
              title: localizations.darkMode,
              child: Switch.adaptive(
                activeTrackColor: Colors.green.shade200,
                activeThumbColor: Colors.green.shade700,
                value: _isDarkMode,
                onChanged: (value) {
                  setState(() => _isDarkMode = value);
                  widget.onDarkModeChange(value);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.green.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.green.shade700),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade900,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
