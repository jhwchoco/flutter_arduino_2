// lib/camera_screen.dart

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

// ignore_for_file: avoid_print

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    // 사용 가능한 카메라 목록을 가져옵니다.
    final cameras = await availableCameras();
    // 첫 번째 카메라를 선택합니다 (대부분 후면 카메라).
    final firstCamera = cameras.first;

    // 카메라 컨트롤러를 초기화합니다.
    _controller = CameraController(
      firstCamera,
      ResolutionPreset.high,
      enableAudio: false, // 마이크는 사용하지 않으므로 비활성화
    );

    // 컨트롤러 초기화 작업을 시작합니다.
    _initializeControllerFuture = _controller.initialize();

    // 초기화가 완료되면 화면을 다시 그립니다.
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    // 위젯이 제거될 때 카메라 컨트롤러를 해제합니다.
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('운동 감지')),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            // 초기화가 완료되면 카메라 미리보기를 보여줍니다.
            return CameraPreview(_controller);
          } else {
            // 초기화 중이면 로딩 스피너를 보여줍니다.
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}