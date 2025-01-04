import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Launcher extends StatefulWidget {
  final int hours;
  final int minutes;
  final String password;
  final Contact? emergencyContact;
  final List<String> selectedAppPackages;

  const Launcher({
    Key? key,
    required this.hours,
    required this.minutes,
    required this.password,
    required this.selectedAppPackages,
    this.emergencyContact,
  }) : super(key: key);

  @override
  State<Launcher> createState() => _LauncherState();
}

class _LauncherState extends State<Launcher> {
  static const platform = MethodChannel('com.example.safelaunch/app_launcher');
  static const String favAppsKey = 'favorite_apps';

  List<AppData>? _allApps;
  List<AppData> _favoriteApps = [];
  List<AppData> _systemApps = [];
  bool _isLoading = false;
  bool _showAllApps = false;
  bool _showSystemApps = false;
  late DateTime _currentTime;
  late Timer _timer;
  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _initPrefs();
    _currentTime = DateTime.now();
    _timer = Timer.periodic(Duration(minutes: 1), (timer) {
      setState(() {
        _currentTime = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _loadApps();
  }

  Future<void> _saveFavoriteApps() async {
    await _prefs.setStringList(favAppsKey, widget.selectedAppPackages);
  }

  Future<void> _loadApps() async {
    setState(() => _isLoading = true);

    try {
      final List<dynamic> result =
          await platform.invokeMethod('getInstalledApps');

      if (!mounted) return;

      final List<AppData> apps = result.map((app) {
        final Map<String, dynamic> appMap = Map<String, dynamic>.from(app);
        return AppData(
          name: appMap['name'] as String,
          packageName: appMap['packageName'] as String,
          icon: appMap['icon'] as Uint8List,
        );
      }).toList();

      // Sistem uygulamalarını bul
      final List<AppData> systemApps = [];

      // Kamera uygulaması
      final cameraApp = apps.firstWhere(
        (app) =>
            app.packageName.contains('com.android.camera') ||
            app.packageName.contains('com.sec.android.app.camera') ||
            app.packageName.contains('com.huawei.camera') ||
            app.packageName.contains('com.google.android.GoogleCamera') ||
            app.packageName.contains('com.oneplus.camera') ||
            app.packageName.contains('com.motorola.camera') ||
            app.packageName.contains('com.asus.camera') ||
            app.packageName.contains('com.sonyericsson.android.camera') ||
            app.name.toLowerCase().contains('camera'),
        orElse: () => apps.first,
      );
      systemApps.add(cameraApp);

      // Galeri uygulaması
      final galleryApp = apps.firstWhere(
        (app) =>
            app.packageName.contains('com.android.gallery3d') ||
            app.packageName.contains('com.sec.android.gallery3d') ||
            app.packageName.contains('com.google.android.apps.photos') ||
            app.packageName.contains('com.huawei.gallery') ||
            app.packageName.contains('com.oneplus.gallery') ||
            app.packageName.contains('com.motorola.gallery') ||
            app.packageName.contains('com.asus.gallery') ||
            app.name.toLowerCase().contains('gallery') ||
            app.name.toLowerCase().contains('photos'),
        orElse: () => apps[1],
      );
      systemApps.add(galleryApp);

      // Telefon uygulaması
      final phoneApp = apps.firstWhere(
        (app) =>
            app.packageName.contains('com.android.dialer') ||
            app.packageName.contains('com.google.android.dialer') ||
            app.packageName.contains('com.samsung.android.dialer') ||
            app.packageName.contains('com.huawei.phoneservice') ||
            app.packageName.contains('com.oneplus.dialer') ||
            app.packageName.contains('com.motorola.dialer') ||
            app.packageName.contains('com.asus.dialer') ||
            app.name.toLowerCase().contains('phone') ||
            app.name.toLowerCase().contains('dialer'),
        orElse: () => apps[2],
      );
      systemApps.add(phoneApp);

      // SMS uygulaması
      final smsApp = apps.firstWhere(
        (app) =>
            app.packageName.contains('com.android.mms') ||
            app.packageName.contains('com.google.android.apps.messaging') ||
            app.packageName.contains('com.samsung.android.messaging') ||
            app.packageName.contains('com.huawei.message') ||
            app.packageName.contains('com.oneplus.message') ||
            app.packageName.contains('com.motorola.messaging') ||
            app.packageName.contains('com.asus.message') ||
            app.name.toLowerCase().contains('messages') ||
            app.name.toLowerCase().contains('messaging'),
        orElse: () => apps[3],
      );
      systemApps.add(smsApp);

      // Ayarlar uygulaması
      final settingsApp = apps.firstWhere(
        (app) =>
            app.packageName == 'com.android.settings' ||
            app.packageName.contains('com.sec.android.app.launcher') ||
            app.name.toLowerCase() == 'settings',
        orElse: () => apps[4],
      );
      systemApps.add(settingsApp);

      // Tarayıcı uygulaması
      final browserApp = apps.firstWhere(
        (app) =>
            app.packageName.contains('com.android.chrome') ||
            app.packageName.contains('com.sec.android.app.sbrowser') ||
            app.packageName.contains('com.huawei.browser') ||
            app.packageName.contains('com.oneplus.browser') ||
            app.packageName.contains('com.motorola.browser') ||
            app.packageName.contains('com.asus.browser') ||
            app.name.toLowerCase().contains('chrome') ||
            app.name.toLowerCase().contains('browser'),
        orElse: () => apps[5],
      );
      systemApps.add(browserApp);

      // Sistem uygulamalarını hariç tut
      final nonSystemApps = apps
          .where((app) => !systemApps
              .any((sysApp) => sysApp.packageName == app.packageName))
          .toList();

      // SharedPreferences'dan seçili uygulamaları al
      List<String> savedPackages =
          _prefs.getStringList(favAppsKey) ?? widget.selectedAppPackages;

      // İlk kez çalıştırılıyorsa dashboard'dan gelen uygulamaları kaydet
      if (!_prefs.containsKey(favAppsKey)) {
        _saveFavoriteApps();
      }

      // Seçili uygulamaları bul
      final List<AppData> selectedApps = [];
      for (String packageName in savedPackages) {
        final app = nonSystemApps.firstWhere(
          (app) => app.packageName == packageName,
          orElse: () => nonSystemApps.first,
        );
        selectedApps.add(app);
      }

      setState(() {
        _allApps = nonSystemApps;
        _systemApps = systemApps;
        _favoriteApps = selectedApps;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load apps')),
        );
      }
    }
  }

  // Favori uygulamaları güncelle
  void _updateFavoriteApps(int oldIndex, int newIndex) {
    setState(() {
      final app = _favoriteApps.removeAt(oldIndex);
      _favoriteApps.insert(newIndex, app);
      // Değişiklikleri SharedPreferences'a kaydet
      _prefs.setStringList(
        favAppsKey,
        _favoriteApps.map((app) => app.packageName).toList(),
      );
    });
  }

  // Tüm uygulamalar panelinden favori uygulama ekle
  void _addToFavorites(AppData app) {
    if (_favoriteApps.length < 5) {
      setState(() {
        _favoriteApps.add(app);
        // Değişiklikleri SharedPreferences'a kaydet
        _prefs.setStringList(
          favAppsKey,
          _favoriteApps.map((app) => app.packageName).toList(),
        );
      });
      Navigator.pop(context); // Paneli kapat
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You can only add up to 5 favorite apps')),
      );
    }
  }

  // Favori uygulamayı kaldır
  void _removeFromFavorites(int index) {
    setState(() {
      _favoriteApps.removeAt(index);
      // Değişiklikleri SharedPreferences'a kaydet
      _prefs.setStringList(
        favAppsKey,
        _favoriteApps.map((app) => app.packageName).toList(),
      );
    });
  }

  Future<void> _sendSOS() async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      String locationMessage =
          'SOS! I need help! My location: https://www.google.com/maps?q=${position.latitude},${position.longitude}';

      if (widget.emergencyContact != null &&
          widget.emergencyContact!.phones.isNotEmpty) {
        final Uri smsUri = Uri(
          scheme: 'sms',
          path: widget.emergencyContact!.phones.first.number,
          queryParameters: {'body': locationMessage},
        );

        await launchUrl(smsUri);

        final Uri callUri = Uri(
          scheme: 'tel',
          path: widget.emergencyContact!.phones.first.number,
        );
        await launchUrl(callUri);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send SOS')),
      );
    }
  }

  Future<void> _launchApp(String packageName) async {
    try {
      await platform.invokeMethod('launchApp', {'packageName': packageName});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to launch app')),
      );
    }
  }

  Widget _buildAppItem(AppData app, int index) {
    return LongPressDraggable<Map<String, dynamic>>(
      data: {'type': 'app', 'index': index, 'data': app},
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: 60,
          height: 80,
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Image.memory(
                  app.icon,
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(height: 4),
              Text(
                app.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.5,
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Image.memory(
                app.icon,
                fit: BoxFit.contain,
              ),
            ),
            SizedBox(height: 4),
            Text(
              app.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
      child: DragTarget<Map<String, dynamic>>(
        onWillAccept: (data) => data != null,
        onAccept: (data) {
          final fromIndex = data['index'] as int;
          final toIndex = index;

          if (data['type'] == 'app') {
            _updateFavoriteApps(fromIndex, toIndex);
          }
        },
        builder: (context, candidateData, rejectedData) {
          return GestureDetector(
            onTap: () => _launchApp(app.packageName),
            onLongPress: () {
              // Uzun basma menüsü
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Remove from favorites?'),
                  content: Text(
                      'Do you want to remove ${app.name} from your favorite apps?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _removeFromFavorites(index);
                      },
                      child: Text('Remove'),
                    ),
                  ],
                ),
              );
            },
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Image.memory(
                    app.icon,
                    fit: BoxFit.contain,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  app.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSystemFolder() {
    return LongPressDraggable<Map<String, dynamic>>(
      data: {'type': 'folder', 'index': 0},
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: 60,
          height: 80,
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        Icons.folder_special_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${_systemApps.length}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 4),
              Text(
                'System',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.5,
        child: _buildSystemFolderContent(),
      ),
      child: DragTarget<Map<String, dynamic>>(
        onWillAccept: (data) => data != null,
        onAccept: (data) {
          if (data['type'] == 'folder') return;

          final fromIndex = data['index'] as int;
          setState(() {
            final app = _favoriteApps.removeAt(fromIndex);
            _favoriteApps.insert(0, app);
          });
        },
        builder: (context, candidateData, rejectedData) {
          return GestureDetector(
            onTap: () => _showSystemFolder(),
            child: _buildSystemFolderContent(),
          );
        },
      ),
    );
  }

  Widget _buildSystemFolderContent() {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              Center(
                child: Icon(
                  Icons.folder_special_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${_systemApps.length}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 4),
        Text(
          'System',
          style: TextStyle(
            fontSize: 11,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  void _showSystemFolder() {
    showDialog(
      context: context,
      barrierColor: Colors.black45,
      builder: (BuildContext context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(28),
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
                  Padding(
                    padding: EdgeInsets.fromLTRB(24, 20, 24, 16),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.folder_special_rounded,
                            color: Colors.blue[700],
                            size: 24,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'System Apps',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        Spacer(),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.black54),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1),
                  Padding(
                    padding: EdgeInsets.all(20),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        childAspectRatio: 0.75,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 20,
                      ),
                      itemCount: _systemApps.length,
                      itemBuilder: (context, index) {
                        final app = _systemApps[index];
                        return GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            _launchApp(app.packageName);
                          },
                          child: Column(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                padding: EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.memory(
                                    app.icon,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                app.name,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black87,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
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

  Widget _buildMainGrid() {
    return GridView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.8,
        crossAxisSpacing: 16,
        mainAxisSpacing: 24,
      ),
      itemCount: _favoriteApps.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildSystemFolder();
        }
        return _buildAppItem(_favoriteApps[index - 1], index - 1);
      },
    );
  }

  Widget _buildAllAppsPanel() {
    return Positioned.fill(
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => setState(() => _showAllApps = false),
                  ),
                  SizedBox(width: 16),
                  Text(
                    'All Apps',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: 0.8,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 24,
                ),
                itemCount: _allApps?.length ?? 0,
                itemBuilder: (context, index) {
                  final app = _allApps![index];
                  return GestureDetector(
                    onTap: () => _launchApp(app.packageName),
                    onLongPress: () {
                      // Favori uygulamalara ekle
                      if (!_favoriteApps.any(
                          (favApp) => favApp.packageName == app.packageName)) {
                        _addToFavorites(app);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content:
                                  Text('This app is already in favorites')),
                        );
                      }
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Image.memory(
                            app.icon,
                            fit: BoxFit.contain,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          app.name,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          child: Stack(
            children: [
              // Clock and Date
              Positioned(
                top: 40,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    Text(
                      DateFormat('HH:mm').format(_currentTime),
                      style: TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.w300,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      DateFormat('EEEE, d MMMM').format(_currentTime),
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                    Container(
                      margin: EdgeInsets.only(top: 8),
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Remaining: ${widget.hours}h ${widget.minutes}m',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Main Apps Grid
              Positioned(
                top: 200,
                left: 0,
                right: 0,
                bottom: 100,
                child: _isLoading
                    ? Center(child: CircularProgressIndicator())
                    : _buildMainGrid(),
              ),

              // All Apps Panel
              if (_showAllApps) _buildAllAppsPanel(),

              // Bottom Controls
              Positioned(
                left: 0,
                right: 0,
                bottom: 24,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    GestureDetector(
                      onTap: _sendSOS,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.3),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            'SOS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _showAllApps = true),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.apps_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.family_restroom,
                        color: Colors.white,
                        size: 28,
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
  }
}

class AppData {
  final String name;
  final String packageName;
  final Uint8List icon;

  AppData({
    required this.name,
    required this.packageName,
    required this.icon,
  });
}
