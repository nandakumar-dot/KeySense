import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Custom Fonts',
      theme: ThemeData(
        fontFamily: 'Outfit',
        textTheme: TextTheme(
          bodyMedium: TextStyle(fontSize: 16),
        ),
      ),
      home: const KeyLoggerScreen(),
    );
  }
}

class KeyLoggerScreen extends StatefulWidget {
  const KeyLoggerScreen({Key? key}) : super(key: key);

  @override
  _KeyLoggerScreenState createState() => _KeyLoggerScreenState();
}

class _KeyLoggerScreenState extends State<KeyLoggerScreen> {
  final List<String> _loggedData = [];
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;
  GyroscopeEvent? _gyroscopeEvent;
  AccelerometerEvent? _accelerometerEvent;
  MagnetometerEvent? _magnetometerEvent;
  List<AccelerometerEvent> _accelBuffer = [];
  List<GyroscopeEvent> _gyroBuffer = [];
  List<MagnetometerEvent> _magBuffer = [];
  Timer? _timer;
  bool _isLogging = false;
  late File _logFile;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  static const Duration sensorInterval = Duration(milliseconds: 20);

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _initializeLogFile();
  }

  Future<void> _requestPermissions() async {
    PermissionStatus status;
    if (Platform.isAndroid) {
      status = await Permission.storage.request();
      if (status == PermissionStatus.denied) {
        status = await Permission.manageExternalStorage.request();
      }
    } else {
      status = await Permission.photos.request();
    }

    if (status == PermissionStatus.granted) {
      await _initializeLogFile();
      _startListeningToSensors();
    } else if (status == PermissionStatus.denied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Storage permission is required to log data'),
          action: SnackBarAction(
            label: 'Grant Permission',
            onPressed: _requestPermissions,
          ),
        ),
      );
    } else if (status == PermissionStatus.permanentlyDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Storage permission is required to log data. Please grant permission in the app settings.'),
          action: SnackBarAction(
            label: 'Open Settings',
            onPressed: () => openAppSettings(),
          ),
        ),
      );
    }
  }

  Future<void> _initializeLogFile() async {
    if (Platform.isAndroid) {
      Directory? directory = await getExternalStorageDirectory();
      if (directory == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('External storage unavailable')));
        return;
      }
      String newPath = "";
      List<String> folders = directory.path.split("/");
      for (int x = 1; x < folders.length; x++) {
        String folder = folders[x];
        if (folder != "Android") {
          newPath += "/" + folder;
        } else {
          break;
        }
      }
      newPath = newPath + "/KEYLOGGER";
      directory = Directory(newPath);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      if (await directory.exists()) {
        _logFile = File('${directory.path}/key_log.txt');
        if (!await _logFile.exists()) {
          _logFile.createSync();
        }
      }
    } else {
      Directory? directory = await getTemporaryDirectory();
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      if (await directory.exists()) {
        _logFile = File('${directory.path}/key_log.txt');
        if (!await _logFile.exists()) {
          _logFile.createSync();
        }
      }
    }
  }

  void _startListeningToSensors() {
    _gyroscopeSubscription =
        gyroscopeEventStream(samplingPeriod: sensorInterval)
            .listen((GyroscopeEvent event) {
      setState(() {
        _gyroscopeEvent = event;
        _gyroBuffer.add(event);
        if (_gyroBuffer.length > 11) {
          _gyroBuffer.removeAt(0);
        }
      });
    });

    _accelerometerSubscription =
        accelerometerEventStream(samplingPeriod: sensorInterval)
            .listen((AccelerometerEvent event) {
      setState(() {
        _accelerometerEvent = event;
        _accelBuffer.add(event);
        if (_accelBuffer.length > 11) {
          _accelBuffer.removeAt(0);
        }
      });
    });

    _magnetometerSubscription =
        magnetometerEventStream(samplingPeriod: sensorInterval)
            .listen((MagnetometerEvent event) {
      setState(() {
        _magnetometerEvent = event;
        _magBuffer.add(event);
        if (_magBuffer.length > 11) {
          _magBuffer.removeAt(0);
        }
      });
    });
  }

  void _startLogging() {
    setState(() {
      _isLogging = true;
      _loggedData.clear();
    });
  }

  void _stopLogging() {
    setState(() {
      _isLogging = false;
    });
  }

  Future<void> _updateLogFile() async {
    if (_loggedData.isNotEmpty) {
      final logString = _loggedData.join('\n') + '\n';
      await _logFile.writeAsString(logString, mode: FileMode.append);
      setState(() {
        _loggedData.clear();
      });
    }
  }

  void _logKeyPress(String key) {
    if (_isLogging &&
        _gyroscopeEvent != null &&
        _accelerometerEvent != null &&
        _magnetometerEvent != null) {
      // Capture data before key press
      List<AccelerometerEvent> accelBefore = [];
      List<GyroscopeEvent> gyroBefore = [];
      List<MagnetometerEvent> magBefore = [];
      for (int i = 5; i > 0; i--) {
        if (_accelBuffer.length >= i &&
            _gyroBuffer.length >= i &&
            _magBuffer.length >= i) {
          accelBefore.add(_accelBuffer[_accelBuffer.length - i]);
          gyroBefore.add(_gyroBuffer[_gyroBuffer.length - i]);
          magBefore.add(_magBuffer[_magBuffer.length - i]);
        }
      }

      // Capture data at the exact moment of key press
      var accelDuring = _accelerometerEvent;
      var gyroDuring = _gyroscopeEvent;
      var magDuring = _magnetometerEvent;

      // Delay to capture data after key press
      if (accelBefore.length == 5 &&
          gyroBefore.length == 5 &&
          magBefore.length == 5) {
        Future.delayed(sensorInterval, () {
          List<AccelerometerEvent> accelAfter = [];
          List<GyroscopeEvent> gyroAfter = [];
          List<MagnetometerEvent> magAfter = [];
          for (int i = 0; i < 5; i++) {
            if (_accelBuffer.length > i &&
                _gyroBuffer.length > i &&
                _magBuffer.length > i) {
              accelAfter.add(_accelBuffer[i]);
              gyroAfter.add(_gyroBuffer[i]);
              magAfter.add(_magBuffer[i]);
            }
          }

          if (accelBefore.length == 5 &&
              gyroBefore.length == 5 &&
              magBefore.length == 5 &&
              accelDuring != null &&
              gyroDuring != null &&
              magDuring != null &&
              accelAfter.length == 5 &&
              gyroAfter.length == 5 &&
              magAfter.length == 5) {
            final logEntry =
                '($key, Before: (${_formatSensorData(accelBefore, gyroBefore, magBefore)}), '
                'During: (${gyroDuring.x}, ${gyroDuring.y}, ${gyroDuring.z}), '
                '(${accelDuring.x}, ${accelDuring.y}, ${accelDuring.z}), '
                '(${magDuring.x}, ${magDuring.y}, ${magDuring.z}), '
                'After: ${_formatSensorData(accelAfter, gyroAfter, magAfter)})\n';
            setState(() {
              _loggedData.add(logEntry);
            });
            _scrollToBottom();
          }
        });
      }
    }
  }

  String _formatSensorData(List<AccelerometerEvent> accel,
      List<GyroscopeEvent> gyro, List<MagnetometerEvent> mag) {
    String formattedData = '';
    for (int i = 0; i < accel.length; i++) {
      formattedData += '((${gyro[i].x}, ${gyro[i].y}, ${gyro[i].z}), '
          '(${accel[i].x}, ${accel[i].y}, ${accel[i].z}), '
          '(${mag[i].x}, ${mag[i].y}, ${mag[i].z}))';
      if (i < accel.length - 1) {
        formattedData += ', ';
      }
    }
    return formattedData;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _gyroscopeSubscription?.cancel();
    _accelerometerSubscription?.cancel();
    _magnetometerSubscription?.cancel();
    _timer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KeySense'),
        elevation: 4,
      ),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              ElevatedButton(
                onPressed: _isLogging ? null : _startLogging,
                child: const Text('Start'),
              ),
              ElevatedButton(
                onPressed: _isLogging ? _stopLogging : null,
                child: const Text('Stop'),
              ),
              ElevatedButton(
                onPressed: _loggedData.isNotEmpty ? _updateLogFile : null,
                child: const Text('Update'),
              ),
            ],
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16.0),
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _loggedData.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(
                      _loggedData[index],
                      style: const TextStyle(
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Type here...',
              ),
              onChanged: (text) {
                if (text.isNotEmpty) {
                  _logKeyPress(text.characters.last);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
