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

class _LauncherState extends State<Launcher> with SingleTickerProviderStateMixin {
  static const platform = MethodChannel('com.example.safelaunch/app_launcher');
  static const String favAppsKey = 'favorite_apps';

  List<AppData>? _allApps;
  List<AppData> _favoriteApps = [];
  bool _isLoading = false;
  bool _showAllApps = false;
  late DateTime _currentTime;
  late Timer _timer;
  late SharedPreferences _prefs;
  
  // Animation controllers
  late AnimationController _slideController;
  late Animation<double> _slideAnimation;
  double _dragOffset = 0;
  bool _isDragging = false;

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

    // Initialize animation controller with smoother duration
    _slideController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 400),
    );
    _slideAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutExpo,
      reverseCurve: Curves.easeInExpo,
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    _slideController.dispose();
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
        final app = apps.firstWhere(
          (app) => app.packageName == packageName,
          orElse: () => apps.first,
        );
        selectedApps.add(app);
      }

      setState(() {
        _allApps = apps;
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
      // Uygulama başlatıldıktan sonra paneli kapat
      if (_showAllApps) {
        _slideController.animateTo(
          0,
          duration: Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
        ).then((_) {
          if (mounted) {
            setState(() {
              _showAllApps = false;
              _isDragging = false;
              _dragOffset = 0;
            });
          }
        });
      }
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

  Widget _buildMainGrid() {
    return GridView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.8,
        crossAxisSpacing: 16,
        mainAxisSpacing: 24,
      ),
      itemCount: _favoriteApps.length,
      itemBuilder: (context, index) {
        return _buildAppItem(_favoriteApps[index], index);
      },
    );
  }

  Widget _buildAllAppsPanel() {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        final height = MediaQuery.of(context).size.height;
        final panelOffset = _isDragging 
            ? height - _dragOffset 
            : height * (1 - _slideAnimation.value);
            
        return Positioned.fill(
          child: IgnorePointer(
            ignoring: !_showAllApps && !_isDragging,
            child: Stack(
              children: [
                // Blur background with fade
                AnimatedOpacity(
                  opacity: _showAllApps || _isDragging ? 1.0 : 0.0,
                  duration: Duration(milliseconds: 200),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      color: Colors.black.withOpacity(0.3),
                    ),
                  ),
                ),
                // Panel
                Positioned(
                  top: panelOffset,
                  left: 0,
                  right: 0,
                  height: height,
                  child: ClipRRect(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        color: Colors.white.withOpacity(0.1),
                        child: Column(
                          children: [
                            // Handle bar
                            Container(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            // Header
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              child: Row(
                                children: [
                                  Text(
                                    'All Apps',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Apps grid
                            Expanded(
                              child: GridView.builder(
                                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                physics: BouncingScrollPhysics(),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 4,
                                  childAspectRatio: 0.75,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 24,
                                ),
                                itemCount: _allApps?.length ?? 0,
                                itemBuilder: (context, index) {
                                  final app = _allApps![index];
                                  return GestureDetector(
                                    onTap: () => _launchApp(app.packageName),
                                    onLongPress: () {
                                      if (!_favoriteApps.any(
                                          (favApp) => favApp.packageName == app.packageName)) {
                                        _addToFavorites(app);
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('This app is already in favorites'),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    },
                                    child: Column(
                                      children: [
                                        Container(
                                          width: 56,
                                          height: 56,
                                          padding: EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: Image.memory(
                                            app.icon,
                                            fit: BoxFit.contain,
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
                                            color: Colors.white,
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
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAllAppsWithAnimation() {
    setState(() {
      _showAllApps = true;
      _dragOffset = MediaQuery.of(context).size.height;
    });
    
    _slideController.animateTo(
      1,
      duration: Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  void _handleDragStart(DragStartDetails details) {
    final delta = details.globalPosition.dy;
    final height = MediaQuery.of(context).size.height;
    
    // Ana sayfada yukarı kaydırmayı engelle
    if (!_showAllApps) {
      return;
    }
    
    setState(() {
      _isDragging = true;
    });
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    
    final delta = details.delta.dy;
    final height = MediaQuery.of(context).size.height;
    
    // Sadece aşağı kaydırmaya izin ver
    if (delta < 0) return;
    
    setState(() {
      if (_showAllApps) {
        _dragOffset = (_dragOffset - delta).clamp(0.0, height);
      }
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!_isDragging) return;
    
    final height = MediaQuery.of(context).size.height;
    final velocity = details.primaryVelocity ?? 0;
    
    if (_showAllApps) {
      if (_dragOffset < height * 0.3 || velocity > 300) {
        // Daha yumuşak kapanma animasyonu
        _slideController.animateTo(
          0,
          duration: Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
        ).then((_) {
          if (mounted) {
            setState(() {
              _showAllApps = false;
              _isDragging = false;
              _dragOffset = 0;
            });
          }
        });
      } else {
        _showAllAppsWithAnimation();
      }
    } else {
      if (velocity < -300 || _dragOffset > height * 0.15) {
        _showAllAppsWithAnimation();
      } else {
        // Daha yumuşak kapanma animasyonu
        _slideController.animateTo(
          0,
          duration: Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
        ).then((_) {
          if (mounted) {
            setState(() {
              _showAllApps = false;
              _isDragging = false;
              _dragOffset = 0;
            });
          }
        });
      }
    }
    
    setState(() {
      _isDragging = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onVerticalDragStart: _handleDragStart,
        onVerticalDragUpdate: _handleDragUpdate,
        onVerticalDragEnd: _handleDragEnd,
        behavior: HitTestBehavior.translucent,
        child: Container(
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
                          'Remaining:${widget.hours}h ${widget.minutes}m',
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

                // All Apps Panel with Animation
                if (_showAllApps || _isDragging) _buildAllAppsPanel(),

                // Bottom Controls
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 24,
                  child: AnimatedOpacity(
                    opacity: _showAllApps || _isDragging ? 0.0 : 1.0,
                    duration: Duration(milliseconds: 300),
                    child: IgnorePointer(
                      ignoring: _showAllApps || _isDragging,
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
                            onTap: _showAllAppsWithAnimation,
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
                  ),
                ),
              ],
            ),
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
