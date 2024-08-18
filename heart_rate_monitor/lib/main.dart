import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    print('Error in fetching the cameras: $e');
  }
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HeartRateMonitor(),
    );
  }
}

class HeartRateMonitor extends StatefulWidget {
  @override
  _HeartRateMonitorState createState() => _HeartRateMonitorState();
}

class _HeartRateMonitorState extends State<HeartRateMonitor> {
  CameraController? _controller;
  AudioPlayer _audioPlayer = AudioPlayer();
  double _heartRate = 0.0;
  bool _isRecording = false;
  Timer? _audioTimer;
  int _currentPeakIndex = 0;
  List<int> _peaks = [];
  List<DateTime> _allPeaksTimestamps = [];
  bool _isProcessing = false;
  bool _unstableReading = false;
  Timer? _bpmTimer;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (cameras.isNotEmpty) {
      _controller = CameraController(cameras[0], ResolutionPreset.low, enableAudio: false);
      try {
        await _controller!.initialize();
        _controller!.setFlashMode(FlashMode.torch);
        setState(() {});
      } catch (e) {
        print('Error initializing camera: $e');
      }
    } else {
      print('No camera is available.');
    }
  }

  void _startContinuousRecording() {
    if (_controller != null && _controller!.value.isInitialized) {
      setState(() {
        _isRecording = true;
        _unstableReading = false;
      });
      _recordAndProcessVideo();
      _startBpmCalculation();
    }
  }

  void _stopRecording() {
    setState(() {
      _isRecording = false;
      _audioTimer?.cancel();
      _audioPlayer.stop();
      _bpmTimer?.cancel();
    });
  }

  void _startBpmCalculation() {
    _bpmTimer = Timer.periodic(Duration(seconds: 15), (timer) {
      _calculateBpm();
    });
  }

  void _calculateBpm() {
    final now = DateTime.now();
    _allPeaksTimestamps.removeWhere((timestamp) => now.difference(timestamp).inSeconds > 15);

    final int peakCount = _allPeaksTimestamps.length;
    setState(() {
      _heartRate = (peakCount * 60) / 15; // BPM based on the number of peaks in the last 15 seconds
    });
  }

  Future<void> _recordAndProcessVideo() async {
    final directory = await getApplicationDocumentsDirectory();
    final videoPath = '${directory.path}/heart_rate_video.mp4';

    while (_isRecording) {
      try {
        await _controller!.startVideoRecording();
        await Future.delayed(Duration(seconds: 1)); // Shorter video duration
        XFile videoFile = await _controller!.stopVideoRecording();

        final File newFile = await File(videoFile.path).copy(videoPath);
        if (await newFile.exists()) {
          _processVideoInBackground(newFile);
        } else {
          throw Exception('Video file does not exist at the expected location.');
        }
      } catch (e) {
        print('Error recording video: $e');
        await Future.delayed(Duration(milliseconds: 100)); // Short delay before retrying
      }
    }
  }

  Future<void> _processVideoInBackground(File videoFile) async {
    _sendVideoToBackend(videoFile.path).then((_) {
      videoFile.delete();
    }).catchError((e) {
      print('Error processing video: $e');
      videoFile.delete();
    });
  }

  Future<void> _sendVideoToBackend(String videoPath) async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://172.20.10.2:5000/process_video'),
      );
      request.files.add(await http.MultipartFile.fromPath('video', videoPath));

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        var result = jsonDecode(responseBody);
        setState(() {
          _peaks = List<int>.from(result['peaks']);
          if (_peaks.isEmpty || _peaks.length > 10) {
            _unstableReading = true;
            _audioPlayer.stop();
          } else {
            _unstableReading = false;
            _allPeaksTimestamps.addAll(_peaks.map((peak) => DateTime.now()));
            _playAudioByPeaks();
          }
        });
      } else {
        print('Error response from server: ${response.statusCode} ${response.reasonPhrase}');
        print('Response body: $responseBody');
      }
    } catch (e) {
      print('Exception caught: $e');
    } finally {
      _isProcessing = false;
    }
  }

  void _playAudioByPeaks() {
    if (_peaks.isNotEmpty) {
      _currentPeakIndex = 0;
      _audioTimer?.cancel();
      _playSound();
    }
  }

  Future<void> _playSound() async {
    if (_currentPeakIndex < _peaks.length) {
      await _audioPlayer.play(AssetSource('boom.mp3'));
      int interval = (_peaks[_currentPeakIndex] * 1000 ~/ 30); // Assuming 30 FPS
      _currentPeakIndex++;
      _audioTimer = Timer(Duration(milliseconds: interval), _playSound);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _audioTimer?.cancel();
    _bpmTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red[100],
      appBar: AppBar(title: Text('Heart Rate Monitor')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_controller != null && _controller!.value.isInitialized)
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.red, width: 4),
                ),
                child: ClipOval(child: CameraPreview(_controller!)),
              )
            else
              Center(child: Text('Initializing camera...')),
            SizedBox(height: 20),
            Text(
              'Heart Rate: ${_heartRate.toStringAsFixed(2)} BPM',
              style: TextStyle(fontSize: 24),
            ),
            if (_unstableReading)
              Text(
                'Don\'t move',
                style: TextStyle(fontSize: 24, color: Colors.red),
              ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isRecording ? null : _startContinuousRecording,
              child: Text('Start', style: TextStyle(fontSize: 24)),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                backgroundColor: Colors.green,
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isRecording ? _stopRecording : null,
              child: Text('Stop', style: TextStyle(fontSize: 24)),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                backgroundColor: Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
