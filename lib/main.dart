import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mappls_gl/mappls_gl.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Mappls initialize with proper keys
  MapplsAccountManager.setMapSDKKey("fb12c8e7a8265c74180abd4ae32edecb");
  MapplsAccountManager.setRestAPIKey("fb12c8e7a8265c74180abd4ae32edecb");
  MapplsAccountManager.setAtlasClientId("96dHZVzsAuuKw16xggfnetRJNYtixNbchhWWckES3pEifmxCHIMVXukNes5-cBL6TKM-hgfPxIj1YBKX-JkRhVxBgbjnfVu-");
  MapplsAccountManager.setAtlasClientSecret("lrFxI-iSEg_DdPG3KSbo6nmVDIgLPa3sc9KQPdfL0ozX5IVJJmaOP7T2nm6V_VXutKJwZwjO6vThUUTTa0s3dEyDqfPAPWoWpbXA5QcI8OU=");

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Background Location Tracker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: LocationTrackerPage(),
    );
  }
}

class LocationTrackerPage extends StatefulWidget {
  @override
  _LocationTrackerPageState createState() => _LocationTrackerPageState();
}

class _LocationTrackerPageState extends State<LocationTrackerPage> {
  String latitude = 'Waiting...';
  String longitude = 'Waiting...';
  String altitude = 'Waiting...';
  String accuracy = 'Waiting...';
  bool isTracking = false;
  String permissionStatus = 'Permission check nahi hua';
  StreamSubscription<Position>? positionStream;

  // Mappls Map related variables
  MapplsMapController? mapController;
  LatLng? currentLocation;
  List<LatLng> pathPoints = [];
  bool showMap = false;
  Symbol? currentMarker;
  Line? pathLine;

  @override
  void initState() {
    super.initState();
    checkPermissions();
  }

  @override
  void dispose() {
    positionStream?.cancel();
    super.dispose();
  }

  Future<void> checkPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    LocationPermission permission = await Geolocator.checkPermission();

    setState(() {
      permissionStatus = 'GPS: ${serviceEnabled ? "On" : "Off"}, Permission: ${permission.toString()}';
    });
  }

  Future<bool> requestPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        permissionStatus = 'GPS off hai! GPS on karo';
      });

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('GPS Off Hai'),
          content: Text('Location tracking ke liye GPS on karna zaroori hai.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Geolocator.openLocationSettings();
              },
              child: Text('GPS Settings Kholo'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
          ],
        ),
      );
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          permissionStatus = 'Permission denied';
        });
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        permissionStatus = 'Permission permanently denied';
      });

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Permission Denied'),
          content: Text('Settings mein ja kar location permission allow karo.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Geolocator.openAppSettings();
              },
              child: Text('Settings Kholo'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
          ],
        ),
      );
      return false;
    }

    if (permission == LocationPermission.whileInUse) {
      await Permission.locationAlways.request();
    }

    setState(() {
      permissionStatus = 'Permission granted: ${permission.toString()}';
    });

    return true;
  }

  void _onMapCreated(MapplsMapController controller) {
    mapController = controller;
  }

  void _updateMapLocation(double lat, double lng) async {
    if (mapController == null) return;

    LatLng newLocation = LatLng(lat, lng);

    // Remove old marker
    if (currentMarker != null) {
      await mapController!.removeSymbol(currentMarker!);
    }

    // Add new marker
    currentMarker = await mapController!.addSymbol(
      SymbolOptions(
        geometry: newLocation,
        iconImage: "assets/symbols/place.png",
        iconSize: 1.5,
      ),
    );

    // Update path line
    pathPoints.add(newLocation);
    if (pathPoints.length > 1) {
      if (pathLine != null) {
        await mapController!.removeLine(pathLine!);
      }
      pathLine = await mapController!.addLine(
        LineOptions(
          geometry: pathPoints,
          lineColor: "#0000FF",
          lineWidth: 4.0,
        ),
      );
    }

    // Move camera to current location
    mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(newLocation, 15.0),
    );
  }

  void startLocationTracking() async {
    bool hasPermission = await requestPermissions();

    if (!hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Permission ya GPS ki problem hai!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isTracking = true;
      permissionStatus = 'Tracking shuru ho raha hai...';
      showMap = true;
      pathPoints.clear();
    });

    LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
          (Position position) {
        print('=== Location Update ===');
        print('Lat: ${position.latitude}');
        print('Long: ${position.longitude}');

        setState(() {
          latitude = position.latitude.toStringAsFixed(6);
          longitude = position.longitude.toStringAsFixed(6);
          altitude = position.altitude.toStringAsFixed(2);
          accuracy = position.accuracy.toStringAsFixed(2);
          permissionStatus = 'Location mil raha hai!';

          currentLocation = LatLng(position.latitude, position.longitude);
          _updateMapLocation(position.latitude, position.longitude);
        });
      },
      onError: (error) {
        print('Error: $error');
        setState(() {
          permissionStatus = 'Error: $error';
        });
      },
    );

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        latitude = position.latitude.toStringAsFixed(6);
        longitude = position.longitude.toStringAsFixed(6);
        altitude = position.altitude.toStringAsFixed(2);
        accuracy = position.accuracy.toStringAsFixed(2);

        currentLocation = LatLng(position.latitude, position.longitude);
        _updateMapLocation(position.latitude, position.longitude);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location tracking shuru ho gaya! ✅'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Current position error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pehla location milne mein time lag sakta hai...'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void stopLocationTracking() {
    positionStream?.cancel();
    setState(() {
      isTracking = false;
      permissionStatus = 'Tracking band ho gaya';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Location tracking band ho gaya!')),
    );
  }

  void _centerMap() {
    if (mapController != null && currentLocation != null) {
      mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(currentLocation!, 15.0),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Background Location Tracker'),
        centerTitle: true,
        actions: [
          if (showMap && currentLocation != null)
            IconButton(
              icon: Icon(Icons.my_location),
              onPressed: _centerMap,
              tooltip: 'Center Map',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mappls Map Section
            if (showMap)
              Container(
                height: 300,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: MapplsMap(
                    initialCameraPosition: CameraPosition(
                      target: currentLocation ?? LatLng(28.7041, 77.1025),
                      zoom: 15.0,
                    ),
                    onMapCreated: _onMapCreated,
                    myLocationEnabled: true,
                    compassEnabled: true,
                  ),
                ),
              )
            else
              Icon(
                Icons.location_on,
                size: 80,
                color: isTracking ? Colors.green : Colors.grey,
              ),

            SizedBox(height: 20),
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                permissionStatus,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.blue[900]),
              ),
            ),
            SizedBox(height: 20),
            Card(
              elevation: 3,
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    LocationInfo(label: 'Latitude', value: latitude),
                    Divider(height: 20),
                    LocationInfo(label: 'Longitude', value: longitude),
                    Divider(height: 20),
                    LocationInfo(label: 'Altitude (m)', value: altitude),
                    Divider(height: 20),
                    LocationInfo(label: 'Accuracy (m)', value: accuracy),
                  ],
                ),
              ),
            ),
            SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: isTracking ? null : startLocationTracking,
              icon: Icon(Icons.play_arrow),
              label: Text('Start Tracking', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.all(16),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey,
              ),
            ),
            SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: isTracking ? stopLocationTracking : null,
              icon: Icon(Icons.stop),
              label: Text('Stop Tracking', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.all(16),
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey,
              ),
            ),
            SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: checkPermissions,
              icon: Icon(Icons.refresh),
              label: Text('Check Status'),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.all(16),
              ),
            ),
            SizedBox(height: 20),
            Container(
              padding: EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚠️ Important Tips:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.orange[900],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• GPS on karo (location settings)\n'
                        '• Battery saver mode off karo\n'
                        '• Permission "Allow all the time" select karo\n'
                        '• Khule area mein jao (window ke paas)\n'
                        '• First update mein 10-30 seconds lag sakta hai\n'
                        '• Mappls map pe blue line tumhara path dikhayega',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange[900],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LocationInfo extends StatelessWidget {
  final String label;
  final String value;

  LocationInfo({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$label:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            color: Colors.blue[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}