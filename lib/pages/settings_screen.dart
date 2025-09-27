import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app/app_state.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onLogoutComplete;

  const SettingsScreen({super.key, this.onLogoutComplete});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool pushNotifs = true;
  bool emailNotifs = false;

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isDarkMode = appState.isDarkMode;

    final bgColor = isDarkMode
        ? const Color(0xFF1C1B1F)
        : const Color(0xFFF5F5F5);
    final cardColor = isDarkMode ? const Color(0xFF2C2C2E) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final iconColor = isDarkMode ? Colors.white : Colors.black87;
    final subtle = textColor.withOpacity(0.6);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
        ),
        centerTitle: true,
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _sectionHeader('Appearance', subtle),
          _buildSwitchTile(
            label: "Dark Mode",
            icon: LucideIcons.moon,
            value: isDarkMode,
            onChanged: (v) =>
                Provider.of<AppState>(context, listen: false).setThemeMode(v),
            tileColor: cardColor,
            textColor: textColor,
            iconColor: iconColor,
          ),

          const SizedBox(height: 16),
          _sectionHeader('Notifications', subtle),
          _buildSwitchTile(
            label: "Push Notifications",
            icon: LucideIcons.bell,
            value: pushNotifs,
            onChanged: (v) => setState(() => pushNotifs = v),
            tileColor: cardColor,
            textColor: textColor,
            iconColor: iconColor,
          ),
          _buildSwitchTile(
            label: "Email Notifications",
            icon: LucideIcons.mail,
            value: emailNotifs,
            onChanged: (v) => setState(() => emailNotifs = v),
            tileColor: cardColor,
            textColor: textColor,
            iconColor: iconColor,
          ),

          const SizedBox(height: 16),
          _sectionHeader('Support & Legal', subtle),
          _buildSettingTile(
            label: "Support",
            icon: LucideIcons.helpCircle,
            onTap: () => _showInfoSheet(
              context,
              title: 'Support',
              message:
                  'For internal support, please contact #it-helpdesk on Slack or email support@yourcompany.com.',
            ),
            tileColor: cardColor,
            textColor: textColor,
            iconColor: iconColor,
          ),
          _buildSettingTile(
            label: "Privacy Policy",
            icon: LucideIcons.shield,
            onTap: () => _showInfoSheet(
              context,
              title: 'Privacy Policy',
              message:
                  'This is an internal tool. Data is used for operational purposes and handled under company policy.',
            ),
            tileColor: cardColor,
            textColor: textColor,
            iconColor: iconColor,
          ),
          _buildSettingTile(
            label: "Terms of Service",
            icon: LucideIcons.fileText,
            onTap: () => _showInfoSheet(
              context,
              title: 'Terms of Service',
              message:
                  'By using this tool you agree to abide by internal policies and security guidelines.',
            ),
            tileColor: cardColor,
            textColor: textColor,
            iconColor: iconColor,
          ),
          _buildSettingTile(
            label: "Community Guidelines",
            icon: LucideIcons.users,
            onTap: () => _showInfoSheet(
              context,
              title: 'Community Guidelines',
              message:
                  'Be respectful. Don’t share sensitive data outside approved channels. Follow least-privilege access.',
            ),
            tileColor: cardColor,
            textColor: textColor,
            iconColor: iconColor,
          ),

          const SizedBox(height: 16),
          _sectionHeader('Account', subtle),
          _buildSettingTile(
            label: "Blocked Accounts",
            icon: LucideIcons.userMinus,
            onTap: () => _showInfoSheet(
              context,
              title: 'Blocked Accounts',
              message: 'Feature not implemented yet.',
            ),
            tileColor: cardColor,
            textColor: textColor,
            iconColor: iconColor,
          ),
          _buildSettingTile(
            label: "Log out",
            icon: LucideIcons.logOut,
            onTap: _confirmLogout,
            danger: true,
            tileColor: cardColor,
            textColor: textColor,
            iconColor: Colors.redAccent,
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required Color tileColor,
    required Color textColor,
    required Color iconColor,
    bool danger = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(icon, color: iconColor, size: 24),
        title: Text(
          label,
          style: TextStyle(
            color: danger ? Colors.redAccent : textColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Icon(Icons.chevron_right, color: textColor.withOpacity(0.5)),
        onTap: onTap,
      ),
    );
  }

  Widget _buildSwitchTile({
    required String label,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color tileColor,
    required Color textColor,
    required Color iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        title: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        secondary: Icon(icon, color: iconColor, size: 24),
        activeColor: Colors.orange,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }

  void _showInfoSheet(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(message, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Log out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await Supabase.instance.client.auth.signOut();

      // 🔑 Mark app as logged out
      if (mounted) {
        context.read<AppState>().setLoggedOut();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Signed out')));
        widget.onLogoutComplete?.call();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logout failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
