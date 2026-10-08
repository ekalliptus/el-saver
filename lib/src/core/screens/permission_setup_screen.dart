// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:el_saver/src/core/services/permission_service.dart';
import '../../config/routes_manager.dart';
import 'dart:developer' as developer;
import '../common_widgets/fancy_loader.dart';

class PermissionSetupScreen extends StatefulWidget {
  const PermissionSetupScreen({super.key});

  @override
  State<PermissionSetupScreen> createState() => _PermissionSetupScreenState();
}

class _PermissionSetupScreenState extends State<PermissionSetupScreen> {
  final PermissionService _permissionService = PermissionService();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Dark background
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1E1E1E),
              Color(0xFF121212),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const SizedBox(height: 20),

                // Main permission setup container
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E), // Dark container
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF333333),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Quick Setup Required',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white, // White text
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'We need to setup a few permissions for the best experience:',
                          style: TextStyle(
                            fontSize: 15,
                            color: Color(0xFFB0B0B0), // Light gray text
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Permission items with proper spacing
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                _buildPermissionItem(
                                  icon: Icons.folder,
                                  title: 'Gallery Access',
                                  description:
                                      'Save downloaded media to your gallery',
                                  isCompleted: false,
                                ),
                                const SizedBox(height: 16),
                                _buildPermissionItem(
                                  icon: Icons.install_mobile,
                                  title: 'Install Apps',
                                  description:
                                      'Auto-update when new versions are available',
                                  isCompleted: false,
                                ),
                                const SizedBox(height: 16),
                                _buildPermissionItem(
                                  icon: Icons.picture_in_picture,
                                  title: 'Picture-in-Picture',
                                  description:
                                      'Continue watching while using other apps',
                                  isCompleted: false,
                                  isOptional: true,
                                ),
                                const SizedBox(height: 24),
                                // Information text with dark theme
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF7C3AED)
                                        .withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFF7C3AED)
                                          .withOpacity(0.4),
                                    ),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        color: Color(0xFF9B6CFB),
                                        size: 20,
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'This will only take a moment and is required for the app to work properly.',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF9B6CFB),
                                            height: 1.3,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Action buttons with dark theme
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isLoading ? null : _exitApp,
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  side: const BorderSide(
                                    color: Color(0xFF333333),
                                    width: 1.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Exit App',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFB0B0B0),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed:
                                    _isLoading ? null : _setupPermissions,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF7C3AED),
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  elevation: 4,
                                  shadowColor:
                                      const Color(0xFF7C3AED).withOpacity(0.4),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isLoading
                                    ? const FancyLoader(
                                        size: 14,
                                        color: Colors.white,
                                      )
                                    : const Text(
                                        'Setup Permissions',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionItem({
    required IconData icon,
    required String title,
    required String description,
    required bool isCompleted,
    bool isOptional = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isCompleted
            ? Colors.green.withOpacity(0.15)
            : const Color(0xFF2A2A2A), // Dark item background
        border: Border.all(
          color: isCompleted
              ? Colors.green
              : const Color(0xFF333333), // Dark border
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isCompleted ? Colors.green : const Color(0xFF7C3AED),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: (isCompleted ? Colors.green : const Color(0xFF7C3AED))
                      .withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              isCompleted ? Icons.check : icon,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Colors.white, // White text for dark theme
                        ),
                      ),
                    ),
                    if (isOptional) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.5),
                          ),
                        ),
                        child: const Text(
                          'Optional',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFB0B0B0), // Light gray for dark theme
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _setupPermissions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _permissionService.requestAllPermissions(context);

      if (result == true) {
        developer.log('Permission setup completed',
            name: 'PermissionSetupScreen');

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Setup completed successfully!'),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }

        // Navigate to main app
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          Navigator.of(context).pushReplacementNamed(Routes.downloader);
        }

        // No need for manual update checks here - MyApp.markPermissionSetupCompleted()
        // is called by PermissionService and will handle update checking automatically
      } else if (result == false) {
        // This means user actually tried permissions but some were denied
        developer.log('Some permissions denied', name: 'PermissionSetupScreen');

        // Handle permission denied
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.warning, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        'Some permissions were not granted. App may not work properly.'),
                  ),
                ],
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }

        // Still navigate to app but with limited functionality
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.of(context).pushReplacementNamed(Routes.downloader);
        }

        // No manual update check needed - handled by MyApp callback
      }
      // If result is null, user cancelled - do nothing, stay on permission screen
    } catch (e) {
      developer.log('Error setting up permissions: $e',
          name: 'PermissionSetupScreen');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Setup failed: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Navigate anyway
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(Routes.downloader);
      }

      // No manual update check needed - handled by MyApp callback
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _exitApp() {
    // Close the app
    SystemNavigator.pop();
  }
}
