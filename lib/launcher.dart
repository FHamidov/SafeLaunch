import 'dart:async';
import 'dart:ui';
import 'dart:math';
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
  bool _isLocked = false;
  String _enteredPassword = '';
  int _remainingMinutes = 0;
  
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
    
    // Initialize everything
    _initializeApp();
    
    // İcazələri yoxla
    _checkUsageStatsPermission();

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

  Future<void> _initializeApp() async {
    _prefs = await SharedPreferences.getInstance();
    _currentTime = DateTime.now();
    
    // Load and check remaining time
    await _loadRemainingTime();
    
    // Start timer after loading time
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(minutes: 1), (timer) {
      setState(() {
        _currentTime = DateTime.now();
        
        if (_remainingMinutes > 0) {
          _remainingMinutes--;
          _updateRemainingTime();
        }
        
        if (_remainingMinutes <= 0 && !_isLocked) {
          _lockScreen();
        }
      });
    });
  }

  // Load remaining time from SharedPreferences
  Future<void> _loadRemainingTime() async {
    final lastResetDate = _prefs.getString('lastResetDate');
    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);
    
    // Əgər son sıfırlama tarixi bu gün deyilsə, vaxtı sıfırla
    if (lastResetDate != today) {
      _remainingMinutes = widget.hours * 60 + widget.minutes;
      await _prefs.setString('lastResetDate', today);
      await _prefs.setInt('remainingMinutes', _remainingMinutes);
    } else {
      // Əks halda saxlanılmış vaxtı yüklə
      _remainingMinutes = _prefs.getInt('remainingMinutes') ?? (widget.hours * 60 + widget.minutes);
    }

    // Əgər qalan vaxt 0-dırsa və ya 0-dan kiçikdirsə, ekranı kilidlə
    if (_remainingMinutes <= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _lockScreen();
      });
    }
    
    setState(() {});
  }

  Future<void> _updateRemainingTime() async {
    await _prefs.setInt('remainingMinutes', _remainingMinutes);
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
      if (widget.emergencyContact != null && widget.emergencyContact!.phones.isNotEmpty) {
        // Get location
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        final phoneNumber = widget.emergencyContact!.phones.first.number;
        final locationMessage = 'Emergency! My location: https://www.google.com/maps?q=${position.latitude},${position.longitude}';

        // Send SMS
        final Uri smsUri = Uri(
          scheme: 'sms',
          path: phoneNumber,
          queryParameters: {'body': locationMessage},
        );
        await launchUrl(smsUri);

        // Show notification
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sending location to emergency contact'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No emergency contact found'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send SOS'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _launchApp(String packageName) async {
    try {
      await platform.invokeMethod('launchApp', {'packageName': packageName});
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
              _selectedLetter = 'A'; // Reset selected letter to A when closing
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
              _selectedLetter = 'A'; // Reset selected letter to A when closing
            });
          }
        });
      }
    }
    
    setState(() {
      _isDragging = false;
    });
  }

  Future<void> _checkUsageStatsPermission() async {
    try {
      final hasPermission = await platform.invokeMethod('checkUsageStatsPermission');
      if (!hasPermission) {
        await platform.invokeMethod('requestUsageStatsPermission');
      }
    } catch (e) {
      print('Usage stats permission error: $e');
    }
  }

  void _lockScreen() {
    setState(() {
      _isLocked = true;
      _enteredPassword = '';
    });
    
    if (!mounted) return;
    
    // Set system UI flags to prevent access to system bars
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
    
    // Notify Android about lock state
    platform.invokeMethod('setLockState', {'locked': true});
    
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black,
      useSafeArea: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: TweenAnimationBuilder(
          duration: Duration(milliseconds: 800),
          tween: Tween<double>(begin: 0, end: 1),
          builder: (context, double value, child) {
            return BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 10 * value,
                sigmaY: 10 * value,
              ),
              child: Dialog(
                backgroundColor: Colors.transparent,
                elevation: 0,
                child: Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Animated clock icon with stars
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          // Rotating stars
                          ...List.generate(6, (index) {
                            return TweenAnimationBuilder(
                              duration: Duration(seconds: 2),
                              tween: Tween<double>(begin: 0, end: 1),
                              builder: (context, double value, child) {
                                return Transform.rotate(
                                  angle: value * 2 * 3.14 + (index * 1.0),
                                  child: Transform.translate(
                                    offset: Offset(50 * cos(index * 1.0), 50 * sin(index * 1.0)),
                                    child: Icon(
                                      Icons.star,
                                      color: Colors.amber,
                                      size: 20,
                                    ),
                                  ),
                                );
                              },
                            );
                          }),
                          // Main clock icon
                          TweenAnimationBuilder(
                            duration: Duration(seconds: 2),
                            tween: Tween<double>(begin: 0, end: 1),
                            builder: (context, double value, child) {
                              return Transform.rotate(
                                angle: value * 2 * 3.14,
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.blue[300]!,
                                        Colors.blue[600]!,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blue.withOpacity(0.3),
                                        blurRadius: 15,
                                        spreadRadius: 5,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.timer_off_rounded,
                                    size: 40,
                                    color: Colors.white,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: 24),
                      
                      // Time's Up text
                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [
                            Colors.blue[400]!,
                            Colors.purple[400]!,
                          ],
                        ).createShader(bounds),
                        child: Text(
                          "Time's Up!",
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      
                      SizedBox(height: 16),
                      
                      // Motivation message
                      Text(
                        "It's Break Time! 🌟",
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      
                      SizedBox(height: 32),
                      
                      // Password field
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue[50]!,
                              Colors.purple[50]!,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          obscureText: true,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            letterSpacing: 4,
                          ),
                          decoration: InputDecoration(
                            hintText: '••••••',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 20,
                            ),
                          ),
                          onChanged: (value) {
                            _enteredPassword = value;
                          },
                          onSubmitted: _checkPassword,
                        ),
                      ),
                      
                      SizedBox(height: 24),
                      
                      // Continue button
                      TweenAnimationBuilder(
                        duration: Duration(milliseconds: 500),
                        tween: Tween<double>(begin: 0.8, end: 1),
                        builder: (context, double value, child) {
                          return Transform.scale(
                            scale: value,
                            child: Container(
                              width: double.infinity,
                              height: 60,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.blue[400]!,
                                    Colors.blue[700]!,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.withOpacity(0.3),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () => _checkPassword(_enteredPassword),
                                  child: Center(
                                    child: Text(
                                      'Continue',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      
                      SizedBox(height: 16),
                      
                      // Hint message
                      Text(
                        'Ask your parents for the password 🤗',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _checkPassword(String password) {
    if (password == widget.password) {
      // Restore system UI
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
      
      // Notify Android about unlock
      platform.invokeMethod('setLockState', {'locked': false});
      
      setState(() {
        _isLocked = false;
        _remainingMinutes = widget.hours * 60 + widget.minutes;
        _updateRemainingTime();
      });
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Wrong password!'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Parent password dialog
  void _showParentPasswordDialog() {
    String enteredPassword = '';
    
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (BuildContext dialogContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            constraints: BoxConstraints(maxWidth: 340),
            padding: EdgeInsets.fromLTRB(24, 32, 24, 24),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.2),
                  blurRadius: 30,
                  spreadRadius: -5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Parent Icon with Animation
                TweenAnimationBuilder(
                  duration: Duration(milliseconds: 200),
                  tween: Tween<double>(begin: 0, end: 1),
                  builder: (context, double value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        width: 64,
                        height: 64,
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Icons.lock_outline_rounded,
                          size: 28,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    );
                  },
                ),
                
                SizedBox(height: 24),
                
                // Title
                Text(
                  "Parent Access",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.9),
                    letterSpacing: 0.5,
                  ),
                ),
                
                SizedBox(height: 8),
                
                // Subtitle
                Text(
                  "Enter password to continue",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.5),
                    letterSpacing: 0.3,
                  ),
                ),
                
                SizedBox(height: 32),
                
                // Password field with animation
                TweenAnimationBuilder(
                  duration: Duration(milliseconds: 350),
                  tween: Tween<double>(begin: 0, end: 1),
                  builder: (context, double value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: Colors.white.withOpacity(0.08),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: TextField(
                          obscureText: true,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            letterSpacing: 3,
                          ),
                          cursorColor: Colors.white.withOpacity(0.5),
                          decoration: InputDecoration(
                            hintText: '••••••',
                            hintStyle: TextStyle(
                              color: Colors.white.withOpacity(0.3),
                              fontSize: 16,
                              letterSpacing: 3,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          onChanged: (value) {
                            enteredPassword = value;
                          },
                          onSubmitted: (value) {
                            if (value == widget.password) {
                              Navigator.pop(dialogContext);
                              // TODO: Add parent settings page navigation
                            } else {
                              Navigator.pop(dialogContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Wrong password'),
                                  backgroundColor: Colors.redAccent.withOpacity(0.9),
                                  behavior: SnackBarBehavior.floating,
                                  margin: EdgeInsets.all(16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              );
                              // Show dialog again after error
                              Future.delayed(Duration(milliseconds: 100), () {
                                _showParentPasswordDialog();
                              });
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
                
                SizedBox(height: 24),
                
                // Verify button with animation
                TweenAnimationBuilder(
                  duration: Duration(milliseconds: 350),
                  tween: Tween<double>(begin: 0, end: 1),
                  builder: (context, double value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        width: double.infinity,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF2196F3).withOpacity(0.8), // Light Blue
                              Color(0xFF1976D2).withOpacity(0.8), // Dark Blue
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              if (enteredPassword == widget.password) {
                                Navigator.pop(dialogContext);
                                // TODO: Add parent settings page navigation
                              } else {
                                Navigator.pop(dialogContext);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Wrong password'),
                                    backgroundColor: Colors.redAccent.withOpacity(0.9),
                                    behavior: SnackBarBehavior.floating,
                                    margin: EdgeInsets.all(16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                );
                                // Show dialog again after error
                                Future.delayed(Duration(milliseconds: 100), () {
                                  _showParentPasswordDialog();
                                });
                              }
                            },
                            child: Center(
                              child: Text(
                                'Verify',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLocked) {
      return Container(
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
        child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                color: Colors.black.withOpacity(0.3),
              ),
            ),
      );
    }
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
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              color: Colors.white,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Time left: ${_remainingMinutes ~/ 60}h ${_remainingMinutes % 60}m',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
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
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _remainingMinutes = 1;
                                _updateRemainingTime();
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Time limit set to 1 minute'),
                                  backgroundColor: Colors.blue,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.withOpacity(0.3),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  '1m',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
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
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _showParentPasswordDialog,
                                customBorder: CircleBorder(),
                                child: Icon(
                                  Icons.family_restroom,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
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
