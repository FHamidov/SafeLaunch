import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safelaunch/launcher.dart';
import 'package:flutter/services.dart';
import 'package:safelaunch/models/app_data.dart';
import 'dart:typed_data';
import 'package:geolocator/geolocator.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  int _hours = 0;
  int _minutes = 30;
  List<AppInfo> selectedApps = [];
  List<AppInfo>? _cachedApps;
  bool _isLoadingApps = false;
  String _password = '';
  String _confirmPassword = '';
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  Contact? _selectedContact;
  List<String> selectedAppPackages = [];

  static const platform =
      const MethodChannel('com.example.safelaunch/app_launcher');

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      int next = _pageController.page!.round();
      if (_currentPage != next) {
        setState(() {
          _currentPage = next;
        });
      }
    });
    
    // İcazələri yoxla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermissions();
    });
    
    // Pre-fetch apps list
    _loadApps();
    _loadEmergencyContact();
  }

  Future<void> _loadApps() async {
    if (_cachedApps != null) return;

    try {
      setState(() => _isLoadingApps = true);
      List<AppInfo> apps = await InstalledApps.getInstalledApps(true, true);

      // Filter apps
      apps = apps
          .where((app) =>
              !app.packageName!.startsWith('com.android') &&
              !app.packageName!.startsWith('com.google.android') &&
              app.name != null &&
              app.name!.isNotEmpty &&
              app.icon != null)
          .toList();

      // Sort apps
      apps.sort((a, b) => a.name!.compareTo(b.name!));

      setState(() {
        _cachedApps = apps;
        _isLoadingApps = false;
      });
    } catch (e) {
      print('Error pre-loading apps: $e');
      setState(() => _isLoadingApps = false);
    }
  }

  Future<void> _loadEmergencyContact() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final contactId = prefs.getString('emergencyContactId');
      
      if (contactId != null) {
        if (await FlutterContacts.requestPermission()) {
          final contact = await FlutterContacts.getContact(contactId);
          if (contact != null) {
            setState(() {
              _selectedContact = contact;
            });
          } else {
            // Əgər kontakt artıq mövcud deyilsə, yaddaşdan sil
            await prefs.remove('emergencyContactId');
            await prefs.remove('emergencyContactName');
            await prefs.remove('emergencyContactPhone');
          }
        }
      }
    } catch (e) {
      print('Təcili əlaqə yüklənməsi zamanı xəta: $e');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Stack(
          children: [
            PageView(
              controller: _pageController,
              children: [
                _buildWelcomePage(context),
                _buildLimitsPage(context),
                _buildPasswordPage(context),
              ],
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                color: Colors.grey[50],
                padding: EdgeInsets.only(bottom: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    3,
                    (index) => _buildPageIndicator(index == _currentPage),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      resizeToAvoidBottomInset: false,
    );
  }

  Widget _buildWelcomePage(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Welcome to ',
                  style: TextStyle(
                    fontSize: 32,
                    color: Colors.blue[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const TextSpan(
                  text: 'SafeLaunch',
                  style: TextStyle(
                    fontSize: 32,
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 60),
          _buildFeatureItem('Safety and Productivity'),
          _buildFeatureItem('Special for children'),
          _buildFeatureItem('Advanced child supervision'),
          const Spacer(),
          Center(
            child: Image.asset('assets/giraffe.png', height: 200),
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildLimitsPage(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Choose ',
                  style: TextStyle(
                    fontSize: 32,
                    color: Colors.blue[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const TextSpan(
                  text: 'Limits',
                  style: TextStyle(
                    fontSize: 32,
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        'Daily Usage Limit',
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.blue[600],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 16,
                            color: Colors.blue[600],
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Set Time',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildTimeSelector(
                        value: _hours,
                        maxValue: 23,
                        label: 'h',
                        onChanged: (value) => setState(() => _hours = value),
                      ),
                      SizedBox(width: 20),
                      _buildTimeSelector(
                        value: _minutes,
                        maxValue: 59,
                        label: 'min',
                        onChanged: (value) => setState(() => _minutes = value),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12),
                Center(
                  child: GestureDetector(
                    onTap: () => _showPremiumDialog(context),
                    child: Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lock_outline,
                            size: 16,
                            color: Colors.blue[600],
                          ),
                          SizedBox(width: 4),
                          Text(
                            'unlock all with premium',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Home Screen Apps',
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.blue[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.apps_rounded,
                            size: 16,
                            color: Colors.blue[600],
                          ),
                          SizedBox(width: 4),
                          Text(
                            '${selectedApps.length}/5',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      ...List.generate(5, (index) => _buildAppSelector(index)),
                      _buildAddAppButton(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
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
              icon: Icon(Icons.keyboard_arrow_up, color: Colors.blue[600]),
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
                color: Colors.blue[600],
              ),
            ),
            IconButton(
              icon: Icon(Icons.keyboard_arrow_down, color: Colors.blue[600]),
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
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildAppSelector(int index) {
    bool hasApp = index < selectedApps.length;

    return GestureDetector(
      onTap: () => _showAppPickerDialog(index),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: hasApp
            ? ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: selectedApps[index].icon != null
                    ? Padding(
                        padding: const EdgeInsets.all(10),
                        child: Image.memory(
                          selectedApps[index].icon!,
                          fit: BoxFit.contain,
                        ),
                      )
                    : Icon(Icons.android, color: Colors.grey[400], size: 30),
              )
            : Icon(Icons.apps_rounded, color: Colors.grey[400], size: 30),
      ),
    );
  }

  Future<void> _showAppPickerDialog(int index) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Center(child: CircularProgressIndicator());
        },
      );

      List<AppInfo> apps = await InstalledApps.getInstalledApps(true, true);
      Navigator.pop(context);

      if (!mounted) return;

      apps = apps
          .where((app) =>
              app.name != null &&
              app.name!.isNotEmpty &&
              !app.packageName!.startsWith('com.android') &&
              !app.packageName!.startsWith('com.google.android'))
          .toList();

      apps.sort((a, b) => a.name!.compareTo(b.name!));

      List<AppInfo> tempSelectedApps = List.from(selectedApps);
      List<AppInfo> filteredApps = List.from(apps);

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (context, setState) {
              return Material(
                color: Colors.white,
                child: SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Select Apps',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            Row(
                              children: [
                                TextButton(
                                  onPressed: () {
                                    this.setState(() {
                                      selectedApps = tempSelectedApps;
                                      selectedAppPackages = selectedApps
                                          .map((app) => app.packageName!)
                                          .toList();
                                    });
                                    Navigator.pop(context);
                                  },
                                  child: Text('Save'),
                                ),
                                IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: Icon(Icons.close),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        margin:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Search apps...',
                            border: InputBorder.none,
                            icon: Icon(Icons.search, color: Colors.grey[600]),
                          ),
                          onChanged: (value) {
                            setState(() {
                              if (value.isEmpty) {
                                filteredApps = apps;
                              } else {
                                filteredApps = apps
                                    .where((app) =>
                                        app.name!
                                            .toLowerCase()
                                            .contains(value.toLowerCase()) ||
                                        app.packageName!
                                            .toLowerCase()
                                            .contains(value.toLowerCase()))
                                    .toList();
                              }
                            });
                          },
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: EdgeInsets.all(16),
                          itemCount: filteredApps.length,
                          itemBuilder: (context, appIndex) {
                            AppInfo app = filteredApps[appIndex];
                            bool isSelected = tempSelectedApps.any(
                                (selectedApp) =>
                                    selectedApp.packageName == app.packageName);
                            return Container(
                              margin: EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                color:
                                    isSelected ? Colors.blue[50] : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.blue[200]!
                                      : Colors.grey[200]!,
                                ),
                              ),
                              child: ListTile(
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                leading: Container(
                                  width: 48,
                                  height: 48,
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: app.icon != null
                                        ? Image.memory(
                                            app.icon!,
                                            fit: BoxFit.contain,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return Icon(Icons.android,
                                                  color: Colors.grey[400],
                                                  size: 24);
                                            },
                                          )
                                        : Icon(Icons.android,
                                            color: Colors.grey[400], size: 24),
                                  ),
                                ),
                                title: Text(
                                  app.name ?? '',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                                subtitle: Text(
                                  app.packageName ?? '',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                trailing: isSelected
                                    ? Icon(
                                        Icons.check_circle,
                                        color: Colors.blue[600],
                                      )
                                    : Icon(
                                        Icons.radio_button_unchecked,
                                        color: Colors.grey[400],
                                      ),
                                onTap: () {
                                  setState(() {
                                    if (isSelected) {
                                      tempSelectedApps.removeWhere(
                                          (selectedApp) =>
                                              selectedApp.packageName ==
                                              app.packageName);
                                    } else {
                                      if (tempSelectedApps.length < 5) {
                                        tempSelectedApps.add(app);
                                      } else {
                                        _showPremiumDialog(context);
                                      }
                                    }
                                  });
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      print('Error loading apps: $e');
    }
  }

  Widget _buildAddAppButton() {
    return GestureDetector(
      onTap: () => _showPremiumDialog(context),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Icon(
          Icons.add_rounded,
          color: Colors.blue[600],
          size: 30,
        ),
      ),
    );
  }

  void _showPremiumDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.star_rounded,
                    color: Colors.blue[600],
                    size: 40,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Unlock Premium',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Add more apps and unlock all premium features',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.blue[600],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        'Get Premium',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPasswordConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.warning_rounded,
                    color: Colors.blue[600],
                    size: 40,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Important Notice',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'I understand that if I forget this password:',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  '• I will need to reinstall the app\n• All settings will be reset\n• I have noted down the password',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Go Back',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        // Save preferences
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('isSetupComplete', true);
                        await prefs.setString('password', _password);
                        await prefs.setInt('hours', _hours);
                        await prefs.setInt('minutes', _minutes);
                        await prefs.setStringList(
                          'favAppsKey',
                          selectedAppPackages,
                        );
                        if (_selectedContact != null) {
                          await prefs.setString(
                              'emergencyContactId', _selectedContact!.id);
                        }

                        if (!mounted) return;
                        Navigator.pop(context);

                        // Open home settings
                        try {
                          await platform.invokeMethod('openHomeSettings');
                        } catch (e) {
                          print('Error opening home settings: $e');
                        }

                        // Navigate to launcher page
                        if (!mounted) return;
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => Launcher(
                              hours: _hours,
                              minutes: _minutes,
                              password: _password,
                              emergencyContact: _selectedContact,
                              selectedAppPackages: selectedAppPackages,
                              preloadedAllApps: _cachedApps!.map((app) => AppData(
                                name: app.name ?? '',
                                packageName: app.packageName ?? '',
                                icon: app.icon ?? Uint8List(0),
                              )).toList(),
                              preloadedFavoriteApps: selectedApps.map((app) => AppData(
                                name: app.name ?? '',
                                packageName: app.packageName ?? '',
                                icon: app.icon ?? Uint8List(0),
                              )).toList(),
                            ),
                          ),
                        );
                      },
                      child: Text(
                        'I Understand',
                        style: TextStyle(
                          color: Colors.blue[600],
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPasswordPage(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Set ',
                    style: TextStyle(
                      fontSize: 32,
                      color: Colors.blue[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const TextSpan(
                    text: 'password',
                    style: TextStyle(
                      fontSize: 32,
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SOS CALLS',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.blue[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: ListTile(
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.person_add_outlined,
                          color: Colors.blue[600],
                          size: 24,
                        ),
                      ),
                      title: Text(
                        _selectedContact?.displayName ?? 'Select Contact',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: _selectedContact != null &&
                              _selectedContact!.phones.isNotEmpty
                          ? Text(
                              _selectedContact!.phones.first.number,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            )
                          : null,
                      trailing: Icon(
                        Icons.chevron_right,
                        color: Colors.grey[400],
                      ),
                      onTap: _pickContact,
                    ),
                  ),
                  SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => _showPremiumDialog(context),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: ListTile(
                        dense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.add_circle_outline,
                            color: Colors.blue[600],
                            size: 20,
                          ),
                        ),
                        title: Text(
                          'Add More',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        trailing: Icon(
                          Icons.lock_outline,
                          color: Colors.grey[400],
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    _password = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Enter your password',
                  hintStyle: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 16,
                  ),
                  prefixIcon: Icon(
                    Icons.lock_outline,
                    color: Colors.blue[600],
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.grey[400],
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
                obscureText: _obscurePassword,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    _confirmPassword = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Confirm your password',
                  hintStyle: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 16,
                  ),
                  prefixIcon: Icon(
                    Icons.lock_outline,
                    color: Colors.blue[600],
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.grey[400],
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
                obscureText: _obscureConfirmPassword,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Password must be at least 6 characters',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This password is for parental controls to manage app usage',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 30),
            Center(
              child: GestureDetector(
                onTap: (_password.length >= 6 && _password == _confirmPassword)
                    ? () => _showPasswordConfirmationDialog(context)
                    : null,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color:
                        (_password.length >= 6 && _password == _confirmPassword)
                            ? Colors.blue[600]
                            : Colors.grey[400],
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: (_password.length >= 6 &&
                                    _password == _confirmPassword
                                ? Colors.blue
                                : Colors.grey)
                            .withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 0,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    'Confirm',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue[100],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.blue[600],
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            text,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator(bool isActive) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? Colors.blue[600] : Colors.grey[300],
      ),
    );
  }

  Future<void> _pickContact() async {
    try {
      if (await FlutterContacts.requestPermission()) {
        final contacts = await FlutterContacts.getContacts(
          withProperties: true,
          withPhoto: false,
        );

        if (!mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) {
              TextEditingController searchController = TextEditingController();
              List<Contact> filteredContacts = List.from(contacts);

              return StatefulBuilder(
                builder: (context, setState) {
                  return Scaffold(
                    backgroundColor: Colors.white,
                    appBar: AppBar(
                      backgroundColor: Colors.white,
                      elevation: 0,
                      title: Text(
                        'Təcili əlaqə seç',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      leading: IconButton(
                        icon: Icon(Icons.arrow_back, color: Colors.grey[600]),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    body: Column(
                      children: [
                        Container(
                          margin: EdgeInsets.all(16),
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: TextField(
                            controller: searchController,
                            decoration: InputDecoration(
                              hintText: 'Search contacts...',
                              border: InputBorder.none,
                              icon: Icon(Icons.search, color: Colors.grey[400]),
                              suffixIcon: searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(Icons.clear,
                                          color: Colors.grey[400]),
                                      onPressed: () {
                                        searchController.clear();
                                        setState(() {
                                          filteredContacts =
                                              List.from(contacts);
                                        });
                                      },
                                    )
                                  : null,
                            ),
                            onChanged: (value) {
                              setState(() {
                                filteredContacts = contacts
                                    .where((contact) =>
                                        contact.displayName
                                            .toLowerCase()
                                            .contains(value.toLowerCase()) ||
                                        (contact.phones.isNotEmpty &&
                                            contact.phones.first.number
                                                .toLowerCase()
                                                .contains(value.toLowerCase())))
                                    .toList();
                              });
                            },
                          ),
                        ),
                        if (filteredContacts.isEmpty)
                          Expanded(
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.search_off_outlined,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'No contacts found',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: ListView.builder(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              itemCount: filteredContacts.length,
                              itemBuilder: (context, index) {
                                final contact = filteredContacts[index];
                                if (contact.phones.isEmpty) return Container();

                                return Container(
                                  margin: EdgeInsets.symmetric(vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border:
                                        Border.all(color: Colors.grey[200]!),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.02),
                                        blurRadius: 4,
                                        spreadRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: ListTile(
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    leading: Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: Colors.blue[50],
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          (contact.displayName)[0]
                                              .toUpperCase(),
                                          style: TextStyle(
                                            color: Colors.blue[600],
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      contact.displayName,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    subtitle: Text(
                                      contact.phones.first.number,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                    onTap: () async {
                                      final fullContact =
                                          await FlutterContacts.getContact(
                                              contact.id);
                                      if (fullContact != null) {
                                        if (!mounted) return;
                                        this.setState(() {
                                          _selectedContact = fullContact;
                                        });
                                        Navigator.pop(context);
                                      }
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Please allow access to contacts to select emergency contact'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () => openAppSettings(),
            ),
          ),
        );
      }
    } catch (e) {
      print('Error picking contact: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load contacts. Please try again.'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () => openAppSettings(),
            ),
          ),
        );
      }
    }
  }

  void _savePasswordAndProceed() async {
    if (_password.isEmpty || _password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password must be at least 6 characters')),
      );
      return;
    }

    if (_password != _confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('password', _password);
    await prefs.setInt('hours', _hours);
    await prefs.setInt('minutes', _minutes);
    await prefs.setBool('isSetupComplete', true);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => Launcher(
          hours: _hours,
          minutes: _minutes,
          password: _password,
          emergencyContact: _selectedContact,
          selectedAppPackages: selectedAppPackages,
          preloadedAllApps: _cachedApps!.map((app) => AppData(
            name: app.name ?? '',
            packageName: app.packageName ?? '',
            icon: app.icon ?? Uint8List(0),
          )).toList(),
          preloadedFavoriteApps: selectedApps.map((app) => AppData(
            name: app.name ?? '',
            packageName: app.packageName ?? '',
            icon: app.icon ?? Uint8List(0),
          )).toList(),
        ),
      ),
    );
  }

  void _navigateToLauncher() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => Launcher(
          hours: _hours,
          minutes: _minutes,
          password: _password,
          emergencyContact: _selectedContact,
          selectedAppPackages: selectedAppPackages,
          preloadedAllApps: _cachedApps!.map((app) => AppData(
            name: app.name ?? '',
            packageName: app.packageName ?? '',
            icon: app.icon ?? Uint8List(0),
          )).toList(),
          preloadedFavoriteApps: selectedApps.map((app) => AppData(
            name: app.name ?? '',
            packageName: app.packageName ?? '',
            icon: app.icon ?? Uint8List(0),
          )).toList(),
        ),
      ),
    );
  }

  void _onFinishSetup() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirstTime', false);
    await prefs.setInt('hours', _hours);
    await prefs.setInt('minutes', _minutes);
    await prefs.setString('password', _password);

    selectedAppPackages = selectedApps.map((app) => app.packageName!).toList();
    await prefs.setStringList('favAppsKey', selectedAppPackages);

    // Save emergency contact with full details
    if (_selectedContact != null) {
      // Get full contact details before saving
      final fullContact = await FlutterContacts.getContact(_selectedContact!.id, withProperties: true);
      if (fullContact != null) {
        await prefs.setString('emergencyContactId', fullContact.id);
        await prefs.setString('emergencyContactName', fullContact.displayName);
        if (fullContact.phones.isNotEmpty) {
          await prefs.setString('emergencyContactPhone', fullContact.phones.first.number);
        }
      }
    }

    // Open home settings and wait for result
    try {
      await platform.invokeMethod('openHomeSettings');
      // Wait for the home settings to be shown
      await Future.delayed(Duration(seconds: 3));
      
      if (!mounted) return;
      
      // Now navigate to launcher
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => Launcher(
            hours: _hours,
            minutes: _minutes,
            password: _password,
            emergencyContact: _selectedContact,
            selectedAppPackages: selectedAppPackages,
            preloadedAllApps: _cachedApps!.map((app) => AppData(
              name: app.name ?? '',
              packageName: app.packageName ?? '',
              icon: app.icon ?? Uint8List(0),
            )).toList(),
            preloadedFavoriteApps: selectedApps.map((app) => AppData(
              name: app.name ?? '',
              packageName: app.packageName ?? '',
              icon: app.icon ?? Uint8List(0),
            )).toList(),
          ),
        ),
      );
    } catch (e) {
      print('Error opening home settings: $e');
      // If home settings fails, still navigate to launcher
      if (!mounted) return;
      _navigateToLauncher();
    }
  }

  Future<void> _checkPermissions() async {
    try {
      // İcazələri yoxla və istifadəçiyə məlumat ver
      bool allPermissionsGranted = true;
      String missingPermissions = '';

      // Lokasiya icazəsi
      LocationPermission locationPermission = await Geolocator.checkPermission();
      if (locationPermission == LocationPermission.denied) {
        locationPermission = await Geolocator.requestPermission();
      }

      // SMS icazəsi
      final smsStatus = await Permission.sms.status;
      if (smsStatus.isDenied) {
        await Permission.sms.request();
      }

      // Kontaktlar icazəsi
      final contactsStatus = await Permission.contacts.status;
      if (contactsStatus.isDenied) {
        await Permission.contacts.request();
      }

      // Usage Stats icazəsi
      bool hasUsageStats = await platform.invokeMethod('checkUsageStatsPermission');
      if (!hasUsageStats) {
        // Usage Stats icazəsi üçün dialoq göstər
        bool? shouldRequest = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Usage Stats icazəsi'),
              content: Text('Tətbiqin düzgün işləməsi üçün Usage Stats icazəsi lazımdır. '
                  'Settings səhifəsi açılacaq, "SafeLaunch" tətbiqini tapıb icazə verin.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('Ləğv et'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text('İcazə ver'),
                ),
              ],
            );
          },
        );

        if (shouldRequest == true) {
          await platform.invokeMethod('requestUsageStatsPermission');
          // İstifadəçiyə icazə verməsi üçün vaxt ver
          await Future.delayed(Duration(seconds: 3));
          // İcazəni yenidən yoxla
          hasUsageStats = await platform.invokeMethod('checkUsageStatsPermission');
        }
      }

      // System Alert Window icazəsi
      bool hasSystemAlert = await platform.invokeMethod('checkSystemAlertPermission');
      if (!hasSystemAlert) {
        // System Alert icazəsi üçün dialoq göstər
        bool? shouldRequest = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Digər tətbiqlər üzərində göstərmə icazəsi'),
              content: Text('Tətbiqin düzgün işləməsi üçün digər tətbiqlər üzərində '
                  'göstərmə icazəsi lazımdır. Settings səhifəsi açılacaq, icazəni aktiv edin.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('Ləğv et'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text('İcazə ver'),
                ),
              ],
            );
          },
        );

        if (shouldRequest == true) {
          await platform.invokeMethod('requestSystemAlertPermission');
          // İstifadəçiyə icazə verməsi üçün vaxt ver
          await Future.delayed(Duration(seconds: 3));
          // İcazəni yenidən yoxla
          hasSystemAlert = await platform.invokeMethod('checkSystemAlertPermission');
        }
      }

      // Bütün icazələri yoxla
      if (locationPermission == LocationPermission.denied || 
          locationPermission == LocationPermission.deniedForever) {
        allPermissionsGranted = false;
        missingPermissions += '- Location\n';
      }

      if (!(await Permission.sms.isGranted)) {
        allPermissionsGranted = false;
        missingPermissions += '- SMS\n';
      }

      if (!(await Permission.contacts.isGranted)) {
        allPermissionsGranted = false;
        missingPermissions += '- Contacts\n';
      }

      if (!hasUsageStats) {
        allPermissionsGranted = false;
        missingPermissions += '- Usage Stats\n';
      }

      if (!hasSystemAlert) {
        allPermissionsGranted = false;
        missingPermissions += '- Display over other apps\n';
      }

      if (!allPermissionsGranted && mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('İcazələr tələb olunur'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tətbiqin düzgün işləməsi üçün aşağıdakı icazələr lazımdır:'),
                  SizedBox(height: 12),
                  Text(missingPermissions, style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 12),
                  Text('Hər bir icazə üçün ayrıca sorğu göndəriləcək.'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    // İcazələri yenidən yoxla
                    _checkPermissions();
                  },
                  child: Text('İcazələri yoxla'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text('Sonra'),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      print('İcazələrin yoxlanması zamanı xəta: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('İcazələrin yoxlanması zamanı xəta baş verdi'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () => openAppSettings(),
            ),
          ),
        );
      }
    }
  }
}
