import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/dual_screen_service.dart';

/// Floating action button that appears on dual-screen devices
/// Provides quick access to display mode switching
class DualScreenFAB extends StatefulWidget {
  const DualScreenFAB({super.key});

  @override
  State<DualScreenFAB> createState() => _DualScreenFABState();
}

class _DualScreenFABState extends State<DualScreenFAB> with SingleTickerProviderStateMixin {
  final DualScreenService _dualScreenService = DualScreenService();
  bool _hasMultiDisplay = false;
  bool _isSecondaryActive = false;
  bool _isExpanded = false;
  bool _isLoading = false;
  bool _isOnSecondaryDisplay = false;

  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _checkDisplays();
    _dualScreenService.addDisplayChangeListener(_onDisplaysChanged);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _dualScreenService.removeDisplayChangeListener(_onDisplaysChanged);
    super.dispose();
  }

  Future<void> _checkDisplays() async {
    final hasMulti = await _dualScreenService.hasSecondaryDisplay();
    final isOnSecondary = await _dualScreenService.isRunningOnSecondary();
    if (mounted) {
      setState(() {
        _hasMultiDisplay = hasMulti;
        _isOnSecondaryDisplay = isOnSecondary;
      });
      debugPrint('DualScreenFAB: hasMultiDisplay=$_hasMultiDisplay, isOnSecondary=$_isOnSecondaryDisplay');
    }
  }

  void _onDisplaysChanged(List<DisplayInfo> displays) {
    if (mounted) {
      setState(() {
        _hasMultiDisplay = displays.length > 1;
      });
    }
  }

  void _toggleExpanded() {
    HapticFeedback.lightImpact();
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _collapse() {
    setState(() => _isExpanded = false);
    _animationController.reverse();
  }

  Future<void> _setMode(DisplayMode mode) async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    _collapse();
    HapticFeedback.mediumImpact();

    try {
      if (_isOnSecondaryDisplay) {
        // We're running on the secondary (bottom) display
        await _handleModeFromSecondary(mode);
      } else {
        // We're running on the primary (top) display
        await _handleModeFromPrimary(mode);
      }
    } catch (e) {
      debugPrint('DualScreenFAB: Error setting mode: $e');
      _showSnackBar('Error: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Handle mode switching when running on the PRIMARY (top) display
  Future<void> _handleModeFromPrimary(DisplayMode mode) async {
    switch (mode) {
      case DisplayMode.topOnly:
        // Dismiss everything - presentation AND activity
        debugPrint('DualScreenFAB: Dismissing all secondary displays');
        // Deactivate companion mode first
        _dualScreenService.setCompanionModeActive(false);
        final dismissed = await _dualScreenService.dismissAll();
        debugPrint('DualScreenFAB: Dismiss result: $dismissed');
        setState(() => _isSecondaryActive = false);
        _showSnackBar('Secondary display dismissed');
        break;

      case DisplayMode.bottomOnly:
        // Deactivate companion mode
        _dualScreenService.setCompanionModeActive(false);
        // First dismiss companion if active, then launch full app
        if (_isSecondaryActive) {
          debugPrint('DualScreenFAB: Dismissing companion first');
          await _dualScreenService.dismissSecondary();
          setState(() => _isSecondaryActive = false);
          // Small delay to let it dismiss
          await Future.delayed(const Duration(milliseconds: 300));
        }
        debugPrint('DualScreenFAB: Launching full app on secondary');
        final success = await _dualScreenService.launchFullAppOnSecondary();
        if (success) {
          // Close the current (top) app since we're going bottom-only
          debugPrint('DualScreenFAB: Closing top screen app');
          await Future.delayed(const Duration(milliseconds: 500));
          await _dualScreenService.finishMainActivity();
        } else {
          _showSnackBar('Failed to launch on secondary', isError: true);
        }
        break;

      case DisplayMode.dualCompanion:
        // Activate companion mode - this hides nav bar on main screen
        _dualScreenService.setCompanionModeActive(true);
        // Show companion view on secondary
        debugPrint('DualScreenFAB: Showing companion view');
        await _dualScreenService.showOnSecondary(route: '/secondary');
        setState(() => _isSecondaryActive = true);
        _showSnackBar('Companion mode active');
        break;
    }
  }

  /// Handle mode switching when running on the SECONDARY (bottom) display
  Future<void> _handleModeFromSecondary(DisplayMode mode) async {
    switch (mode) {
      case DisplayMode.topOnly:
        // Launch app on primary display and close this (secondary) activity
        debugPrint('DualScreenFAB: Launching app on primary from secondary');
        final success = await _dualScreenService.launchOnPrimary();
        if (success) {
          debugPrint('DualScreenFAB: Closing secondary display app');
          await Future.delayed(const Duration(milliseconds: 500));
          await _dualScreenService.finishMainActivity();
        } else {
          _showSnackBar('Failed to launch on primary', isError: true);
        }
        break;

      case DisplayMode.bottomOnly:
        // We're already on the bottom screen, nothing to do
        _showSnackBar('Already on bottom screen');
        break;

      case DisplayMode.dualCompanion:
        // Launch on primary with companion mode
        // First launch on primary
        debugPrint('DualScreenFAB: Launching companion mode from secondary');
        final success = await _dualScreenService.launchOnPrimary();
        if (success) {
          // Small delay for primary to start
          await Future.delayed(const Duration(milliseconds: 500));
          // Close this activity - companion will be shown by primary
          await _dualScreenService.finishMainActivity();
        } else {
          _showSnackBar('Failed to launch companion mode', isError: true);
        }
        break;
    }
  }

  /// Build options when running on PRIMARY (top) display
  List<Widget> _buildPrimaryDisplayOptions(bool isDark) {
    return [
      _OptionTile(
        icon: Icons.tv_off,
        label: 'Top Only',
        color: Colors.orange,
        onTap: () => _setMode(DisplayMode.topOnly),
        isFirst: true,
      ),
      Divider(height: 1, color: isDark ? Colors.grey[700] : Colors.grey[300]),
      _OptionTile(
        icon: Icons.screen_share,
        label: 'Bottom Only',
        color: Colors.blue,
        onTap: () => _setMode(DisplayMode.bottomOnly),
      ),
      Divider(height: 1, color: isDark ? Colors.grey[700] : Colors.grey[300]),
      _OptionTile(
        icon: Icons.view_sidebar,
        label: 'Companion',
        color: Colors.green,
        isActive: _isSecondaryActive,
        onTap: () => _setMode(DisplayMode.dualCompanion),
        isLast: true,
      ),
    ];
  }

  /// Build options when running on SECONDARY (bottom) display
  List<Widget> _buildSecondaryDisplayOptions(bool isDark) {
    return [
      _OptionTile(
        icon: Icons.arrow_upward,
        label: 'Switch to Top',
        color: Colors.orange,
        onTap: () => _setMode(DisplayMode.topOnly),
        isFirst: true,
      ),
      Divider(height: 1, color: isDark ? Colors.grey[700] : Colors.grey[300]),
      _OptionTile(
        icon: Icons.view_sidebar,
        label: 'Companion Mode',
        color: Colors.green,
        onTap: () => _setMode(DisplayMode.dualCompanion),
        isLast: true,
      ),
    ];
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Don't show if no multi-display
    if (!_hasMultiDisplay) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Options (shown when expanded)
        AnimatedBuilder(
          animation: _expandAnimation,
          builder: (context, child) {
            if (_expandAnimation.value == 0) return const SizedBox.shrink();
            return Opacity(
              opacity: _expandAnimation.value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - _expandAnimation.value)),
                child: child,
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12, right: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _isOnSecondaryDisplay
                  ? _buildSecondaryDisplayOptions(isDark)
                  : _buildPrimaryDisplayOptions(isDark),
            ),
          ),
        ),

        // Main FAB
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FloatingActionButton.small(
            onPressed: _isLoading ? null : _toggleExpanded,
            backgroundColor: _isOnSecondaryDisplay
                ? Colors.blue  // Blue when on bottom screen
                : (_isSecondaryActive
                    ? Colors.green
                    : (_isExpanded ? Colors.grey[700] : Colors.deepPurple)),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    _isExpanded
                        ? Icons.close
                        : (_isOnSecondaryDisplay
                            ? Icons.screen_share  // Different icon on secondary
                            : (_isSecondaryActive ? Icons.connected_tv : Icons.connected_tv)),
                    color: Colors.white,
                    size: 20,
                  ),
          ),
        ),
      ],
    );
  }
}

/// Individual option tile in the menu
class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isActive;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isActive = false,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.vertical(
          top: isFirst ? const Radius.circular(16) : Radius.zero,
          bottom: isLast ? const Radius.circular(16) : Radius.zero,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isActive ? color.withValues(alpha: 0.15) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  fontSize: 15,
                  color: isActive ? color : (isDark ? Colors.white : Colors.black87),
                ),
              ),
              if (isActive) ...[
                const SizedBox(width: 8),
                Icon(Icons.check, color: color, size: 18),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum DisplayMode {
  topOnly,
  bottomOnly,
  dualCompanion,
}
