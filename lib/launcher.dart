import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safelaunch/models/app_data.dart';

class Launcher extends StatefulWidget {
  final int hours;
  final int minutes;
  final String password;
  final Contact? emergencyContact;
  final List<String> selectedAppPackages;
  final List<AppData> preloadedAllApps;
  final List<AppData> preloadedFavoriteApps;

  const Launcher({
    Key? key,
    required this.hours,
    required this.minutes,
    required this.password,
    required this.selectedAppPackages,
    required this.preloadedAllApps,
    required this.preloadedFavoriteApps,
    this.emergencyContact,
  }) : super(key: key);

  @override
  State<Launcher> createState() => _LauncherState();
}

class _LauncherState extends State<Launcher> with SingleTickerProviderStateMixin {
  static const platform = MethodChannel('com.example.safelaunch/app_launcher');
  static const String favAppsKey = 'favorite_apps';

  late List<AppData> _allApps;
  late List<AppData> _favoriteApps;
  bool _showAllApps = false;
  late DateTime _currentTime;
  late Timer _timer;
  late SharedPreferences _prefs;
  String _selectedLetter = 'A'; // Seçili harf
  Map<String, List<AppData>> _groupedApps = {}; // Harflere göre gruplanmış uygulamalar
  
  // Animation controllers
  late AnimationController _slideController;
  late Animation<double> _slideAnimation;
  double _dragOffset = 0;
  bool _isDragging = false;

  // Scroll controller ekleyelim
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _allApps = widget.preloadedAllApps;
    _allApps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _favoriteApps = widget.preloadedFavoriteApps;
    _groupAppsByLetter();
    _initPrefs();
    _currentTime = DateTime.now();
    _timer = Timer.periodic(Duration(minutes: 1), (timer) {
      setState(() {
        _currentTime = DateTime.now();
      });
    });

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
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    
    // Kaydedilmiş sıralamayı yükle
    List<String> savedPackages = _prefs.getStringList(favAppsKey) ?? widget.selectedAppPackages;
    
    if (savedPackages.isNotEmpty) {
      // Kaydedilmiş sıralamaya göre favori uygulamaları düzenle
      List<AppData> orderedFavorites = [];
      for (String packageName in savedPackages) {
        final app = _allApps.firstWhere(
          (app) => app.packageName == packageName,
          orElse: () => _allApps.first,
        );
        orderedFavorites.add(app);
      }
      
      setState(() {
        _favoriteApps = orderedFavorites;
      });
    }
  }

  Future<void> _saveFavoriteApps() async {
    await _prefs.setStringList(favAppsKey, widget.selectedAppPackages);
  }

  Future<void> _loadApps() async {
    try {
      final List<dynamic> result = await platform.invokeMethod('getInstalledApps');

      if (!mounted) return;

      final List<AppData> apps = result.map((app) {
        final Map<String, dynamic> appMap = Map<String, dynamic>.from(app);
        return AppData(
          name: appMap['name'] as String,
          packageName: appMap['packageName'] as String,
          icon: appMap['icon'] as Uint8List,
        );
      }).toList();

      apps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      // Kaydedilmiş sıralamayı al
      List<String> savedPackages = _prefs.getStringList(favAppsKey) ?? widget.selectedAppPackages;

      // Kaydedilmiş sıralamaya göre favori uygulamaları düzenle
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
        _groupAppsByLetter();
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
      
      // Yeni sıralamayı SharedPreferences'a kaydet
      final List<String> updatedPackages = _favoriteApps.map((app) => app.packageName).toList();
      _prefs.setStringList(favAppsKey, updatedPackages);
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
        elevation: 8.0,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 70,
          height: 90,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 15,
                spreadRadius: 3,
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.2),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Transform.scale(
            scale: 1.1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white.withOpacity(0.15),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.5),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.2),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Image.memory(
                    app.icon,
                    fit: BoxFit.contain,
                  ),
                ),
                SizedBox(height: 6),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    app.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 2,
              style: BorderStyle.solid,
            ),
          ),
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
                  color: Colors.white.withOpacity(0.3),
                  colorBlendMode: BlendMode.srcATop,
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
                  color: Colors.white.withOpacity(0.3),
                ),
              ),
            ],
          ),
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
          final isDragTarget = candidateData.isNotEmpty;
          return AnimatedContainer(
            duration: Duration(milliseconds: 200),
            transform: isDragTarget 
              ? (Matrix4.identity()..scale(1.1))
              : Matrix4.identity(),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: isDragTarget ? Border.all(
                color: Colors.white.withOpacity(0.5),
                width: 2,
              ) : null,
              boxShadow: isDragTarget ? [
                BoxShadow(
                  color: Colors.white.withOpacity(0.2),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ] : null,
            ),
            child: GestureDetector(
              onTap: () => _launchApp(app.packageName),
              child: Column(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: isDragTarget ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ] : null,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: isDragTarget ? 5 : 0, sigmaY: isDragTarget ? 5 : 0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDragTarget ? Colors.white.withOpacity(0.1) : Colors.transparent,
                            border: isDragTarget ? Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 1,
                            ) : null,
                          ),
                          child: Image.memory(
                            app.icon,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 4),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDragTarget ? Colors.white.withOpacity(0.2) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      app.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: isDragTarget ? FontWeight.w500 : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
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

  // Uygulamaları harflere göre gruplama
  void _groupAppsByLetter() {
    _groupedApps.clear();
    // Önce tüm uygulamaları alfabetik sırala
    _allApps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    
    for (var app in _allApps) {
      String firstLetter = app.name.toUpperCase()[0];
      if (!_groupedApps.containsKey(firstLetter)) {
        _groupedApps[firstLetter] = [];
      }
      _groupedApps[firstLetter]?.add(app);
    }
  }

  // Harf seçildiğinde çağrılacak fonksiyon
  void _onLetterSelected(String letter) {
    setState(() {
      _selectedLetter = letter;
    });
    
    // Seçili harfin ilk uygulamasına scroll yap
    int targetIndex = _allApps.indexWhere(
      (app) => app.name.toUpperCase().startsWith(letter)
    );
    
    if (targetIndex != -1) {
      _scrollController.animateTo(
        targetIndex * 72.0, // ListTile height + padding
        duration: Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  // Sağ taraftaki hızlı erişim paneli
  Widget _buildQuickAccessPanel() {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double panelHeight = screenHeight * 0.8;
    final double totalPadding = 12.0;
    final double letterHeight = (panelHeight - totalPadding) / 26;

    return Container(
      width: 40,
      height: panelHeight,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      margin: EdgeInsets.symmetric(horizontal: 6),
      child: Stack(
        children: [
          // Görünür harfler
          Positioned.fill(
            child: Container(
              padding: EdgeInsets.symmetric(vertical: totalPadding / 2),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(26, (index) {
                      String letter = String.fromCharCode(65 + index);
                      bool hasApps = _groupedApps.containsKey(letter) && 
                                  (_groupedApps[letter]?.isNotEmpty ?? false);
                      bool isSelected = _selectedLetter == letter;
                      
                      return Container(
                        height: letterHeight,
                        width: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white.withOpacity(0.2) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          letter,
                          style: TextStyle(
                            color: hasApps ? Colors.white : Colors.white.withOpacity(0.3),
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
            ),
          ),
          // Görünmez kaydırma alanı
          Positioned.fill(
            child: GestureDetector(
              onTapDown: (details) => _handleLetterSelection(details.localPosition.dy, letterHeight),
              onVerticalDragStart: (details) => _handleLetterSelection(details.localPosition.dy, letterHeight),
              onVerticalDragUpdate: (details) => _handleLetterSelection(details.localPosition.dy, letterHeight),
            ),
          ),
        ],
      ),
    );
  }

  void _handleLetterSelection(double dy, double letterHeight) {
    // Üst padding'i çıkar
    double adjustedDy = dy - 6; // Padding azaltıldı
    if (adjustedDy < 0) return;
    
    // Hangi harfin üzerinde olduğumuzu hesapla
    int letterIndex = (adjustedDy / letterHeight).floor();
    if (letterIndex < 0 || letterIndex >= 26) return;
    
    String letter = String.fromCharCode(65 + letterIndex);
    if (_groupedApps.containsKey(letter) && 
        (_groupedApps[letter]?.isNotEmpty ?? false)) {
      _onLetterSelected(letter);
    }
  }

  // Gruplandırılmış uygulamalar listesi
  Widget _buildGroupedAppsList() {
    return ListView.builder(
      controller: _scrollController,
      physics: BouncingScrollPhysics(),
      padding: EdgeInsets.only(
        right: 52,
        bottom: 100,
      ),
      itemCount: _allApps.length,
      itemBuilder: (context, index) {
        final app = _allApps[index];
        final bool isHighlighted = app.name.toUpperCase().startsWith(_selectedLetter);
        
        return AnimatedContainer(
          duration: Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: isHighlighted ? Colors.white.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isHighlighted ? Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ) : null,
          ),
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              width: 44,
              height: 44,
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isHighlighted ? Colors.white.withOpacity(0.1) : Colors.transparent,
              ),
              child: Image.memory(
                app.icon,
                fit: BoxFit.contain,
                opacity: isHighlighted ? const AlwaysStoppedAnimation(1.0) : const AlwaysStoppedAnimation(0.5),
              ),
            ),
            title: Text(
              app.name,
              style: TextStyle(
                color: isHighlighted ? Colors.white : Colors.white.withOpacity(0.5),
                fontWeight: isHighlighted ? FontWeight.w500 : FontWeight.normal,
                fontSize: 15,
              ),
            ),
            trailing: isHighlighted ? Icon(
              Icons.chevron_right,
              color: Colors.white.withOpacity(0.5),
              size: 20,
            ) : null,
            onTap: () => _launchApp(app.packageName),
          ),
        );
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
                            // Apps list with quick access panel
                            Expanded(
                              child: Stack(
                                children: [
                                  _buildGroupedAppsList(),
                                  Positioned(
                                    right: 0,
                                    top: 0, // En üste taşındı
                                    child: _buildQuickAccessPanel(),
                                  ),
                                ],
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
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                  child: _buildMainGrid(),
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
