import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:my_final_app/models.dart';
import 'package:my_final_app/utils.dart';
import 'package:my_final_app/pose_painter.dart';
import 'package:my_final_app/workout_completion_screen.dart';

late PoseDetector _poseDetector;
bool _isProcessing = false;

class ShoulderPressScreen extends StatefulWidget {
  final CameraDescription camera;
  final Exercise exercise;
  final int targetReps;
  final BluetoothDevice? bleDevice;

  const ShoulderPressScreen({
    Key? key,
    required this.camera,
    required this.exercise,
    required this.targetReps,
    this.bleDevice,
  }) : super(key: key);

  @override
  State<ShoulderPressScreen> createState() => _ShoulderPressScreenState();
}

class _ShoulderPressScreenState extends State<ShoulderPressScreen> {
  late CameraController _cameraController;
  List<Pose> _poses = [];
  String _feedbackMessage = "운동을 시작하세요!";
  int _completedReps = 0;
  RepetitionState _repState = RepetitionState.initial;
  List<FeedbackEntry> _feedbackLog = [];
  DateTime? _sessionStartTime;
  List<PostureRule> _violatedRules = [];
  double _lastElbowAngle = 0.0;

  BluetoothCharacteristic? vibrationCharacteristic;
  bool isExerciseStarted = false;
  Timer? _startDelayTimer;
  bool _canVibrate = true;

  @override
  void initState() {
    super.initState();
    _initializeCameraAndDetector();
    _initBleConnection();
  }

  Future<void> _initBleConnection() async {
    if (widget.bleDevice == null) return;
    try {
      await widget.bleDevice!.connect();
      var services = await widget.bleDevice!.discoverServices();
      for (var service in services) {
        if (service.uuid.toString().toLowerCase() == "4fafc201-1fb5-459e-8fcc-c5c9c331914b") {
          for (var char in service.characteristics) {
            if (char.uuid.toString().toLowerCase() == "beb5483e-36e1-4688-b7f5-ea07361b26a8") {
              vibrationCharacteristic = char;
              break;
            }
          }
        }
      }
    } catch (e) {
      debugPrint("BLE 연결/특성 검색 에러: $e");
    }
  }

  Future<void> _sendVibration() async {
    if (vibrationCharacteristic == null || !_canVibrate) return;
    try {
      _canVibrate = false;
      await vibrationCharacteristic!.write([0x31]);
      Future.delayed(const Duration(milliseconds: 500), () {
        _canVibrate = true;
      });
    } catch (e) {
      debugPrint("BLE 진동 명령 실패: $e");
      _canVibrate = true;
    }
  }

  Future<void> _initializeCameraAndDetector() async {
    _cameraController = CameraController(
      widget.camera,
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    try {
      await _cameraController.initialize();
    } on CameraException catch (e) {
      if (mounted) {
        setState(() => _feedbackMessage = "카메라를 초기화할 수 없습니다: ${e.code}");
      }
      return;
    }

    final options = PoseDetectorOptions(
      mode: PoseDetectionMode.stream,
      model: PoseDetectionModel.base,
    );
    _poseDetector = PoseDetector(options: options);

    if (_cameraController.value.isInitialized) {
      _cameraController.startImageStream((CameraImage image) {
        if (!_isProcessing) {
          _isProcessing = true;
          _detectPose(image);
        }
      });
      _sessionStartTime = DateTime.now();
    }

    if (mounted) setState(() {});
  }

  Future<void> _detectPose(CameraImage image) async {
    if (!isExerciseStarted) {
      _isProcessing = false;
      return;
    }

    try {
      final InputImage inputImage = _inputImageFromCameraImage(image);
      if (inputImage.bytes == null || inputImage.bytes!.isEmpty) {
        _isProcessing = false;
        return;
      }

      final poses = await _poseDetector.processImage(inputImage);
      if (mounted) {
        setState(() {
          _poses = poses;
          if (_poses.isNotEmpty) {
            _analyzeCurrentPosture(_poses.first);
          } else {
            _feedbackMessage = "사람을 감지할 수 없습니다. 프레임 중앙에 위치해주세요.";
            _violatedRules = [];
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _feedbackMessage = "포즈 분석 중 오류 발생: ${e.toString()}";
          _violatedRules = [];
        });
      }
    } finally {
      _isProcessing = false;
    }
  }

  InputImage _inputImageFromCameraImage(CameraImage image) {
    final InputImageRotation rotation =
        InputImageRotationValue.fromRawValue(widget.camera.sensorOrientation) ??
            InputImageRotation.rotation0deg;
    final InputImageFormat targetFormat = InputImageFormat.nv21;

    if (image.format.raw == 35) {
      final Plane yPlane = image.planes[0];
      final Plane uPlane = image.planes[1];
      final Plane vPlane = image.planes[2];

      final int width = image.width;
      final int height = image.height;
      final int uvRowStride = uPlane.bytesPerRow;
      final int uvPixelStride = 2;

      final Uint8List nv21Bytes = Uint8List(width * height + (width * height ~/ 2));

      int yIndex = 0;
      for (int i = 0; i < height; i++) {
        nv21Bytes.setRange(yIndex, yIndex + width,
            yPlane.bytes.sublist(i * yPlane.bytesPerRow, i * yPlane.bytesPerRow + width));
        yIndex += width;
      }

      int uvIndex = width * height;
      for (int row = 0; row < height / 2; row++) {
        for (int col = 0; col < width / 2; col++) {
          nv21Bytes[uvIndex++] = vPlane.bytes[row * uvRowStride + col * uvPixelStride];
          nv21Bytes[uvIndex++] = uPlane.bytes[row * uvRowStride + col * uvPixelStride];
        }
      }

      return InputImage.fromBytes(
        bytes: nv21Bytes,
        metadata: InputImageMetadata(
          size: Size(width.toDouble(), height.toDouble()),
          rotation: rotation,
          format: targetFormat,
          bytesPerRow: width,
        ),
      );
    } else if (image.format.raw == 875704422) {
      return InputImage.fromBytes(
        bytes: image.planes[0].bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.bgra8888,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );
    } else {
      return InputImage.fromBytes(
        bytes: Uint8List(0),
        metadata: InputImageMetadata(
          size: Size.zero,
          rotation: rotation,
          format: targetFormat,
          bytesPerRow: 0,
        ),
      );
    }
  }
  bool _alreadyCounted = false;

  void _analyzeCurrentPosture(Pose pose) async {
    final result = analyzeShoulderPressPosture(
      pose: pose,
      currentRepState: _repState,
      lastElbowAngle: _lastElbowAngle,
    );

    final bool repCounted = result.item1;
    final String newFeedbackMessage = result.item2;
    final List<PostureRule> newViolatedRules = result.item3;
    final RepetitionState newRepState = result.item4;

    if (repCounted && isExerciseStarted) {
      // 이미 카운트가 된 상태라면 무시(한 번만 카운트!)
      if (!_alreadyCounted) {
        setState(() {
          _completedReps++;
        });
        _alreadyCounted = true;
        _feedbackLog.add(FeedbackEntry(
          timestamp: DateTime.now(),
          message: "반복 $_completedReps회 카운트됨!",
          violatedRules: newViolatedRules,
        ));
        await _sendVibration();

        if (_completedReps >= widget.targetReps) {
          _endWorkoutSession();
          return;
        }
      }
    } else if (!repCounted) {
      // repCounted 가 false일 때는 다시 카운트를 허용
      _alreadyCounted = false;
    }

    setState(() {
      _feedbackMessage = newFeedbackMessage;
      _violatedRules = newViolatedRules;
      _repState = newRepState;
    });


    final leftElbow = pose.landmarks[PoseLandmarkType.leftElbow]?.toOffset();
    final rightElbow = pose.landmarks[PoseLandmarkType.rightElbow]?.toOffset();
    if (leftElbow != null && rightElbow != null) {
      final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist]?.toOffset();
      final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist]?.toOffset();
      final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder]?.toOffset();
      final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder]?.toOffset();
      if (leftWrist != null && rightWrist != null && leftShoulder != null && rightShoulder != null) {
        final double leftArmAngle = calculateAngle3P(leftShoulder, leftElbow, leftWrist);
        final double rightArmAngle = calculateAngle3P(rightShoulder, rightElbow, rightWrist);
        _lastElbowAngle = (leftArmAngle + rightArmAngle) / 2;
      }
    }
  }

  void _endWorkoutSession() {
    _cameraController.stopImageStream();
    _poseDetector.close();
    _startDelayTimer?.cancel();
    _canVibrate = true;
    if (widget.bleDevice != null) {
      widget.bleDevice!.disconnect();
    }

    final session = WorkoutSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      exerciseType: widget.exercise.type,
      targetReps: widget.targetReps,
      completedReps: _completedReps,
      startTime: _sessionStartTime ?? DateTime.now(),
      endTime: DateTime.now(),
      feedbackLog: _feedbackLog,
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => WorkoutCompletionScreen(
          session: session,
          cameras: [widget.camera],
          bleDevice: widget.bleDevice,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _poseDetector.close();
    _startDelayTimer?.cancel();
    _canVibrate = true;
    if (widget.bleDevice != null) {
      widget.bleDevice!.disconnect();
    }
    super.dispose();
  }

  void _onStartExercisePressed() {
    if (isExerciseStarted) return;
    setState(() {
      _feedbackMessage = "4초 후 운동을 시작합니다!";
    });
    _startDelayTimer?.cancel();
    _startDelayTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() {
        isExerciseStarted = true;
        _feedbackMessage = "운동 중입니다!";
        _completedReps = 0;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_cameraController.value.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.exercise.name),
        centerTitle: true,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: CameraPreview(_cameraController),
          ),
          Positioned.fill(
            child: _poses.isNotEmpty
                ? CustomPaint(
              painter: PoseLandmarkPainter(
                _poses.first,
                imageSize: _cameraController.value.previewSize!,
                violatedRules: _violatedRules,
              ),
            )
                : Container(),
          ),
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      '$_completedReps / ${widget.targetReps} 회',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: _completedReps / widget.targetReps,
                      backgroundColor: Colors.grey[300],
                      color: Colors.blueAccent,
                      minHeight: 10,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: Colors.white.withOpacity(0.9),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      _feedbackMessage,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color:
                        _violatedRules.isNotEmpty ? Colors.red : Colors.green,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (!isExerciseStarted)
                      ElevatedButton(
                        onPressed: _onStartExercisePressed,
                        child: const Text('운동 시작 (4초 후 시작)'),
                      )
                    else
                      ElevatedButton(
                        onPressed: _endWorkoutSession,
                        child: const Text('운동 종료'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}