import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:my_final_app/workout_selection_screen.dart'; // 운동 선택 화면 임포트
import 'package:camera/camera.dart';

class BleDeviceListScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const BleDeviceListScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  State<BleDeviceListScreen> createState() => _BleDeviceListScreenState();
}

class _BleDeviceListScreenState extends State<BleDeviceListScreen> {
  List<BluetoothDevice> devices = [];
  StreamSubscription? _scanSub;

  @override
  void initState() {
    super.initState();
    requestPermissionsAndStartScan();
  }

  Future<void> requestPermissionsAndStartScan() async {
    var statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    // Map의 values로 PermissionStatus Iterable을 얻고 every() 호출
    bool allGranted = statuses.values.every((status) => status.isGranted);

    if (allGranted) {
      FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
      _scanSub = FlutterBluePlus.scanResults.listen((results) {
        final uniqueDevices = <String, BluetoothDevice>{};
        for (var r in results) {
          uniqueDevices[r.device.remoteId.str] = r.device;
        }
        setState(() {
          devices = uniqueDevices.values.toList();
        });
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('블루투스 및 위치 권한이 필요합니다. 앱 설정에서 허용해주세요.')),
      );
    }
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BLE 기기 선택')),
      body: ListView.builder(
        itemCount: devices.length,
        itemBuilder: (context, index) {
          final device = devices[index];
          return ListTile(
            title: Text(device.name.isNotEmpty ? device.name : "(알 수 없음)"),
            subtitle: Text(device.remoteId.str),
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => WorkoutSelectionScreen(
                    bleDevice: device,
                    cameras: widget.cameras,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}