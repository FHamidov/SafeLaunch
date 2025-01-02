import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:lottie/lottie.dart';

class Launcher extends StatefulWidget {
  final int hours;
  final int minutes;
  final String password;
  final Contact? emergencyContact;

  const Launcher({
    Key? key,
    required this.hours,
    required this.minutes,
    required this.password,
    this.emergencyContact,
  }) : super(key: key);

  @override
  State<Launcher> createState() => _LauncherState();
}

class _LauncherState extends State<Launcher>
    with SingleTickerProviderStateMixin {
  static const platform = MethodChannel('com.example.safelaunch/app_launcher');

  List<AppData>? _allApps;
  bool _isLoading = false;
  bool _isGridView = true;
  TextEditingController _searchController = TextEditingController();
  List<AppData>? _filteredApps;
  late AnimationController _loadingController;

  @override
  void initState() {
    super.initState();
    _loadingController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..repeat();
    _loadApps();
    _searchController.addListener(_filterApps);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _loadingController.dispose();
    super.dispose();
  }

  void _filterApps() {
    if (_allApps == null) return;

    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredApps = _allApps;
      } else {
        _filteredApps = _allApps!.where((app) {
          return app.name.toLowerCase().contains(query) ||
              app.packageName.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  Future<void> _loadApps() async {
    if (_allApps != null) return; // Önbellekten kullan
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

      setState(() {
        _allApps = apps;
        _filteredApps = apps;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading apps: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load apps')),
        );
      }
    }
  }

  Future<void> _launchApp(String packageName) async {
    try {
      await platform.invokeMethod('launchApp', {'packageName': packageName});
    } catch (e) {
      print('Error launching app: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to launch app')),
      );
    }
  }

  Widget _buildAppItem(AppData app) {
    return GestureDetector(
      onTap: () => _launchApp(app.packageName),
      child: _isGridView ? _buildGridItem(app) : _buildListItem(app),
    );
  }

  Widget _buildGridItem(AppData app) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 60,
          height: 60,
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.grey[200]!),
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
            fontSize: 12,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildListItem(AppData app) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Image.memory(
            app.icon,
            fit: BoxFit.contain,
          ),
        ),
        title: Text(
          app.name,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        subtitle: Text(
          app.packageName,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.network(
              'https://assets5.lottiefiles.com/packages/lf20_jhlaooj5.json',
              width: 200,
              height: 200,
              controller: _loadingController,
            ),
            SizedBox(height: 20),
            Text(
              'Loading Applications...',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue[600],
                fontFamily: 'Roboto',
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Please wait while we prepare your fun applications!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontFamily: 'Roboto',
              ),
            ),
            SizedBox(height: 30),
            Container(
              width: 200,
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.grey[200],
              ),
              child: LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
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
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingScreen()
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Search apps...',
                                border: InputBorder.none,
                                icon:
                                    Icon(Icons.search, color: Colors.grey[400]),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: Icon(Icons.clear,
                                            color: Colors.grey[400]),
                                        onPressed: () {
                                          _searchController.clear();
                                          _filterApps();
                                        },
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        IconButton(
                          icon: Icon(
                            _isGridView ? Icons.list : Icons.grid_view,
                            color: Colors.blue[600],
                          ),
                          onPressed: () {
                            setState(() {
                              _isGridView = !_isGridView;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  if (_isLoading)
                    Expanded(
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_filteredApps == null || _filteredApps!.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text('No apps found'),
                      ),
                    )
                  else
                    Expanded(
                      child: _isGridView
                          ? GridView.builder(
                              padding: EdgeInsets.all(16),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 4,
                                childAspectRatio: 0.8,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                              itemCount: _filteredApps!.length,
                              itemBuilder: (context, index) {
                                return _buildAppItem(_filteredApps![index]);
                              },
                            )
                          : ListView.builder(
                              padding: EdgeInsets.all(16),
                              itemCount: _filteredApps!.length,
                              itemBuilder: (context, index) {
                                return _buildAppItem(_filteredApps![index]);
                              },
                            ),
                    ),
                ],
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
