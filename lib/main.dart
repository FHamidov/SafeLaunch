import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard.dart';
import 'launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Check login status
  final prefs = await SharedPreferences.getInstance();
  final bool isSetupComplete = prefs.getBool('isSetupComplete') ?? false;
  final String? password = prefs.getString('password');
  final int hours = prefs.getInt('hours') ?? 0;
  final int minutes = prefs.getInt('minutes') ?? 30;

  runApp(MyApp(
    isSetupComplete: isSetupComplete,
    password: password,
    hours: hours,
    minutes: minutes,
  ));
}

class MyApp extends StatelessWidget {
  final bool isSetupComplete;
  final String? password;
  final int hours;
  final int minutes;

  const MyApp({
    Key? key,
    required this.isSetupComplete,
    this.password,
    required this.hours,
    required this.minutes,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeLaunch',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        fontFamily: GoogleFonts.poppins().fontFamily,
      ),
      home: isSetupComplete && password != null
          ? Launcher(
              hours: hours,
              minutes: minutes,
              password: password!,
              emergencyContact: null,
            )
          : const Dashboard(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _controller.forward();

    Future.delayed(Duration(seconds: 3), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => Dashboard()),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue[300]!,
              Colors.blue[100]!,
            ],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _animation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _animation,
                  child: Icon(
                    Icons.child_care,
                    size: 100,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  'SafeLaunch',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'A Safe World for Your Child',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                SizedBox(height: 40),
                Container(
                  width: 200,
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.white.withOpacity(0.2),
                  ),
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
