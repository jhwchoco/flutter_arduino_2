import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:my_final_app/workout_selection_screen.dart';
import 'package:my_final_app/ble_device_list_screen.dart';

// 앱 시작 전, 사용 가능한 카메라를 찾습니다.
late List<CameraDescription> cameras;

Future<void> main() async {
  // Flutter 프레임워크가 초기화될 때까지 기다립니다.
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 기기에서 사용 가능한 카메라 목록을 가져옵니다.
    cameras = await availableCameras();
  } on CameraException catch (e) {
    // 카메라 초기화 실패 시 오류를 콘솔에 출력합니다.
    debugPrint('카메라 초기화 오류: ${e.code}\n오류 메시지: ${e.description}');
  }

  // MyApp 위젯을 실행하여 앱을 시작합니다.
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '덤벨 운동 자세 보조 시스템',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Inter',
      ),
      // 앱의 시작 화면을 WorkoutSelectionScreen으로 설정하고,
      // 감지된 카메라 목록을 전달합니다.
      home: BleDeviceListScreen(cameras: cameras),
    );
  }
}