import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safelaunch/models/app_data.dart';
import 'dart:typed_data';
import 'dashboard.dart';
import 'launcher.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF1A237E),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(MaterialApp(
    title: 'SafeLaunch',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      primarySwatch: Colors.blue,
      scaffoldBackgroundColor: Color(0xFF1A237E),
      fontFamily: GoogleFonts.poppins().fontFamily,
    ),
    home: SplashScreen(),
  ));
}

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  static const platform = MethodChannel('com.example.safelaunch/app_launcher');
  static const String favAppsKey = 'favorite_apps';
  
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _slideAnimation;
  bool _isLoading = true;
  bool _isInitialized = false;
  double _loadingProgress = 0.0;

  List<AppData>? _allApps;
  List<AppData> _favoriteApps = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 2000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.0, 0.5, curve: Curves.elasticOut),
      ),
    );

    _rotateAnimation = Tween<double>(begin: 0.0, end: 2.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.2, 0.7, curve: Curves.easeOut),
      ),
    );

    _initializeApp();
    _controller.forward();
  }

  Future<void> _initializeApp() async {
    try {
      setState(() => _loadingProgress = 0.1);
      
      final prefs = await SharedPreferences.getInstance();
      setState(() => _loadingProgress = 0.2);
      
      final bool isSetupComplete = prefs.getBool('isSetupComplete') ?? false;
      final String? password = prefs.getString('password');
      final int hours = prefs.getInt('hours') ?? 0;
      final int minutes = prefs.getInt('minutes') ?? 30;
      
      // Load emergency contact
      final String? contactId = prefs.getString('emergencyContactId');
      Contact? emergencyContact;
      if (contactId != null) {
        if (await FlutterContacts.requestPermission()) {
          emergencyContact = await FlutterContacts.getContact(contactId);
        }
      }
      setState(() => _loadingProgress = 0.3);

      // Uygulamaları yükle
      final List<dynamic> result = await platform.invokeMethod('getInstalledApps');
      setState(() => _loadingProgress = 0.6);

      final List<AppData> apps = result.map((app) {
        final Map<String, dynamic> appMap = Map<String, dynamic>.from(app);
        return AppData(
          name: appMap['name'] as String,
          packageName: appMap['packageName'] as String,
          icon: appMap['icon'] as Uint8List,
        );
      }).toList();
      setState(() => _loadingProgress = 0.8);

      // Favori uygulamaları hazırla
      List<String> savedPackages = prefs.getStringList('favAppsKey') ?? [];
      
      final List<AppData> selectedApps = [];
      for (String packageName in savedPackages) {
        final app = apps.firstWhere(
          (app) => app.packageName == packageName,
          orElse: () => apps.first,
        );
        selectedApps.add(app);
      }
      setState(() {
        _loadingProgress = 1.0;
        _allApps = apps;
        _favoriteApps = selectedApps;
      });

      await Future.delayed(Duration(milliseconds: 500));

      if (mounted) {
        setState(() {
          _isLoading = false;
          _isInitialized = true;
        });

        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
              isSetupComplete && password != null
                ? Launcher(
                    hours: hours,
                    minutes: minutes,
                    password: password,
                    emergencyContact: emergencyContact,
                    selectedAppPackages: savedPackages,
                    preloadedAllApps: _allApps!,
                    preloadedFavoriteApps: _favoriteApps,
                  )
                : const Dashboard(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            transitionDuration: Duration(milliseconds: 800),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const Dashboard()),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
          ),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Stack(
              children: [
                // Arka plan animasyonlu parçacıklar
                ...List.generate(10, (index) {
                  final random = index * 36.0;
                  return Positioned(
                    left: MediaQuery.of(context).size.width * (index / 10),
                    top: MediaQuery.of(context).size.height * 0.2 + random,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Transform.rotate(
                        angle: _rotateAnimation.value * 3.14 + random,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Transform.translate(
                        offset: Offset(0, _slideAnimation.value),
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: ScaleTransition(
                            scale: _scaleAnimation,
                            child: Transform.rotate(
                              angle: _rotateAnimation.value * 0.5,
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 20,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.shield_outlined,
                                  size: 60,
                                  color: Color(0xFF1A237E),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 24),
                      Transform.translate(
                        offset: Offset(0, _slideAnimation.value),
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: Text(
                            'SafeLaunch',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 32),
                      if (_isLoading && !_isInitialized) ...[
                        Container(
                          width: 200,
                          child: Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: _loadingProgress,
                                  backgroundColor: Colors.white24,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  minHeight: 4,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                '${(_loadingProgress * 100).toInt()}%',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
