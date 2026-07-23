import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/heart_rate_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _dataSharingEnabled = false;
  int _monitoringInterval = 30; // seconds

  @override
  Widget build(BuildContext context) {
    final heartRateProvider = Provider.of<HeartRateProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Data management section
          const ListTile(
            title: Text('Data Management'),
            subtitle: Text('Control how your data is handled'),
          ),
          SwitchListTile(
            title: const Text('Enable Notifications'),
            subtitle: const Text('Receive alerts for abnormal heart rates'),
            value: _notificationsEnabled,
            onChanged: (value) => setState(() {
                  _notificationsEnabled = value;
                  // Update the provider's notification setting
                  final heartRateProvider =
                      Provider.of<HeartRateProvider>(context, listen: false);
                  heartRateProvider.setNotificationsEnabled(value);
                }),
          ),
          SwitchListTile(
            title: const Text('Share Data'),
            subtitle: const Text('Share anonymized data for research'),
            value: _dataSharingEnabled,
            onChanged: (value) => setState(() => _dataSharingEnabled = value),
          ),
          const Divider(),
          
          // Monitoring settings
          const ListTile(
            title: Text('Monitoring Settings'),
            subtitle: Text('Configure heart rate monitoring'),
          ),
          ListTile(
            title: const Text('Monitoring Interval'),
            subtitle: Text('$_monitoringInterval seconds between readings'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: _monitoringInterval > 5
                      ? () => setState(() => _monitoringInterval -= 5)
                      : null,
                ),
                Text('$_monitoringInterval s'),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () =>
                      setState(() => _monitoringInterval += 5),
                ),
              ],
            ),
          ),
          
          const Divider(),
          
          // Actions
          ListTile(
            leading: const Icon(Icons.data_reset),
            title: const Text('Clear All Data'),
            onTap: () => _showClearDataDialog(context, heartRateProvider),
          ),

          const Divider(),

          // Export options
          const ListTile(
            title: Text('Data Export'),
            subtitle: Text('Export your heart rate data'),
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf),
            title: const Text('Export as CSV'),
            onTap: () => _exportAsCsv(context, heartRateProvider),
          ),
          ListTile(
            leading: const Icon(Icons.file_copy),
            title: const Text('Export as JSON'),
            onTap: () => _exportAsJson(context, heartRateProvider),
          ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('About'),
            onTap: () => _showAboutDialog(context),
          ),
        ],
      ),
    );
  }

  void _showClearDataDialog(BuildContext context, HeartRateProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Data'),
        content: const Text(
            'Are you sure you want to clear all heart rate and HRV data?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              provider.clearData();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Data cleared')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'VitalLens',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.favorite),
      children: const [
        Text('VitalLens is a heart rate monitoring app that tracks your'),
        Text('cardiovascular health using Bluetooth LE heart rate sensors.'),
        SizedBox(height: 16),
        Text('Features include:'),
        Text('• Real-time heart rate monitoring'),
        Text('• Heart Rate Variability analysis (SDNN, RMSSD, pNN50)'),
        Text('• Local data storage with export capabilities'),
        Text('• Abnormal heart rate notifications'),
      ],
    );
  }

  void _exportAsCsv(BuildContext context, HeartRateProvider provider) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          title: Text('Exporting Data'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Preparing CSV export...'),
              SizedBox(height: 16),
              CircularProgressIndicator(),
            ],
          ),
        ),
      );

      // Export data using the provider's export service
      final result = await provider.exportDataCsv();

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      if (result['success']) {
        // Show success message with file path
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Data exported successfully to:\n${result['filePath']}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Export failed: ${result['error']}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) Navigator.of(context).pop();

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _exportAsJson(BuildContext context, HeartRateProvider provider) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          title: Text('Exporting Data'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Preparing JSON export...'),
              SizedBox(height: 16),
              CircularProgressIndicator(),
            ],
          ),
        ),
      );

      // Export data using the provider's export service
      final result = await provider.exportDataJson();

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      if (result['success']) {
        // Show success message with file path
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Data exported successfully to:\n${result['filePath']}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Export failed: ${result['error']}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) Navigator.of(context).pop();

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _toggleNotifications(BuildContext context, HeartRateProvider provider, bool value) {
    setState(() => _notificationsEnabled = value);
    // Update the provider's notification setting
    // We need to access the provider's notification setting through a method
    // For now, we'll update it directly by accessing the provider instance
    // Note: This assumes we have access to the same provider instance
    // In a more complex app, we might use a different state management approach
  }
