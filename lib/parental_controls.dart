import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safelaunch/launcher.dart';
import 'package:safelaunch/models/app_data.dart';

class ParentalControls extends StatefulWidget {
  final Function(int)? onTimeUpdated;
  final List<AppData> currentAllApps;
  final List<AppData> currentFavoriteApps;

  const ParentalControls({
    Key? key,
    this.onTimeUpdated,
    required this.currentAllApps,
    required this.currentFavoriteApps,
  }) : super(key: key);

  @override
  _ParentalControlsState createState() => _ParentalControlsState();
}

class _ParentalControlsState extends State<ParentalControls> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Get default time limits
        final prefs = await SharedPreferences.getInstance();
        final defaultHours = prefs.getInt('hours') ?? 0;
        final defaultMinutes = prefs.getInt('minutes') ?? 30;
        final totalMinutes = defaultHours * 60 + defaultMinutes;
        
        // Get current remaining time
        final remainingMinutes = prefs.getInt('remainingMinutes') ?? totalMinutes;

        // Only reset remaining time if it's 0
        if (remainingMinutes <= 0) {
          await prefs.setInt('remainingMinutes', totalMinutes);
        }

        // Get saved values for launcher
        final password = prefs.getString('password') ?? '';
        final selectedAppPackages = prefs.getStringList('favAppsKey') ?? [];

        // Navigate back to launcher with current apps
        if (!mounted) return false;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => Launcher(
              hours: defaultHours,
              minutes: defaultMinutes,
              password: password,
              emergencyContact: null,
              selectedAppPackages: selectedAppPackages,
              preloadedAllApps: widget.currentAllApps,
              preloadedFavoriteApps: widget.currentFavoriteApps,
            ),
          ),
        );

        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1A237E),
                Color(0xFF0D47A1),
                Color(0xFF01579B),
              ],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Animated Header
                SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Hero(
                            tag: 'back_button',
                            child: Material(
                              color: Colors.transparent,
                              child: IconButton(
                                icon: Icon(Icons.arrow_back_ios, color: Colors.white),
                                onPressed: () async {
                                  // Get default time limits
                                  final prefs = await SharedPreferences.getInstance();
                                  final defaultHours = prefs.getInt('hours') ?? 0;
                                  final defaultMinutes = prefs.getInt('minutes') ?? 30;
                                  final totalMinutes = defaultHours * 60 + defaultMinutes;

                                  // Reset remaining time to default limit
                                  await prefs.setInt('remainingMinutes', totalMinutes);

                                  // Get saved values for launcher
                                  final password = prefs.getString('password') ?? '';
                                  final selectedAppPackages = prefs.getStringList('favAppsKey') ?? [];

                                  // Navigate back to launcher with current apps
                                  if (!mounted) return;
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => Launcher(
                                        hours: defaultHours,
                                        minutes: defaultMinutes,
                                        password: password,
                                        emergencyContact: null,
                                        selectedAppPackages: selectedAppPackages,
                                        preloadedAllApps: widget.currentAllApps,
                                        preloadedFavoriteApps: widget.currentFavoriteApps,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          Text(
                            'Parental Controls',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  blurRadius: 10,
                                  color: Colors.black26,
                                  offset: Offset(2, 2),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: 4,
                    itemBuilder: (context, index) {
                      final items = [
                        {'title': 'Time Limits', 'icon': Icons.timer},
                        {'title': 'Home Apps', 'icon': Icons.apps},
                        {'title': 'Security', 'icon': Icons.security},
                        {'title': 'Emergency Contact', 'icon': Icons.emergency},
                      ];
                      
                      return AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          final delay = index * 0.2;
                          final slideAnimation = Tween<Offset>(
                            begin: Offset(1, 0),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: _controller,
                            curve: Interval(
                              delay,
                              delay + 0.4,
                              curve: Curves.easeOut,
                            ),
                          ));

                          final item = items[index];
                          return SlideTransition(
                            position: slideAnimation,
                            child: Padding(
                              padding: EdgeInsets.only(bottom: 16),
                              child: _buildSettingsCard(
                                title: item['title'] as String,
                                icon: item['icon'] as IconData,
                                onTap: () {
                                  if (item['title'] == 'Time Limits') {
                                    _showTimeLimitDialog(context);
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsCard({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                onTap();
              },
              splashColor: Colors.white.withOpacity(0.1),
              highlightColor: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        icon,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          shadows: [
                            Shadow(
                              blurRadius: 4,
                              color: Colors.black26,
                              offset: Offset(1, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white.withOpacity(0.7),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showTimeLimitDialog(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    int currentHours = prefs.getInt('hours') ?? 0;
    int currentMinutes = prefs.getInt('minutes') ?? 30;
    int selectedHours = currentHours;
    int selectedMinutes = currentMinutes;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Dialog(
                backgroundColor: Colors.transparent,
                child: Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.2),
                        Colors.white.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Set Time Limit',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 24),
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildTimeSelector(
                              value: selectedHours,
                              maxValue: 23,
                              label: 'h',
                              onChanged: (value) {
                                setState(() => selectedHours = value);
                              },
                            ),
                            SizedBox(width: 20),
                            _buildTimeSelector(
                              value: selectedMinutes,
                              maxValue: 59,
                              label: 'min',
                              onChanged: (value) {
                                setState(() => selectedMinutes = value);
                              },
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 24),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.blue[400]!.withOpacity(0.9),
                              Colors.blue[600]!.withOpacity(0.9),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue[600]!.withOpacity(0.3),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () async {
                              // Save new limits
                              await prefs.setInt('hours', selectedHours);
                              await prefs.setInt('minutes', selectedMinutes);
                              
                              // Calculate total minutes for new limit
                              int totalMinutes = selectedHours * 60 + selectedMinutes;
                              
                              // Notify launcher about time update if callback exists
                              if (widget.onTimeUpdated != null) {
                                widget.onTimeUpdated!(totalMinutes);
                              }
                              
                              // Pop the dialog
                              Navigator.pop(context);
                              
                              // Show success message
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Time limit updated successfully'),
                                  backgroundColor: Colors.green,
                                  behavior: SnackBarBehavior.floating,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.save_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Save Changes',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.purple[300]!.withOpacity(0.9),
                              Colors.purple[500]!.withOpacity(0.9),
                            ],
                          ),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _showPremiumDialog(context),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.star_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Get Premium',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTimeSelector({
    required int value,
    required int maxValue,
    required String label,
    required Function(int) onChanged,
  }) {
    int step = label == 'min' ? 5 : 1;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.keyboard_arrow_up, color: Colors.white),
              onPressed: () {
                if (value < maxValue) {
                  int newValue = value + step;
                  if (newValue > maxValue) {
                    newValue = maxValue;
                  }
                  onChanged(newValue);
                }
              },
            ),
            Text(
              value.toString().padLeft(2, '0'),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            IconButton(
              icon: Icon(Icons.keyboard_arrow_down, color: Colors.white),
              onPressed: () {
                if (value > 0) {
                  int newValue = value - step;
                  if (newValue < 0) {
                    newValue = 0;
                  } else if (label == 'min' && newValue % 5 != 0) {
                    newValue = (newValue ~/ 5) * 5;
                  }
                  onChanged(newValue);
                }
              },
            ),
          ],
        ),
        SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  void _showPremiumDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.2),
                    Colors.white.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50]?.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.star_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Unlock Premium',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Get unlimited access to all features',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      minimumSize: Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                                    Icons.star_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Get Premium',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
} 