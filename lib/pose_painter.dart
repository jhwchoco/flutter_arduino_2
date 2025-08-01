import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:my_final_app/models.dart'; // PostureRule 임포트
import 'package:collection/collection.dart';

class PoseLandmarkPainter extends CustomPainter {
  final Pose pose;
  final Size imageSize;
  final List<PostureRule> violatedRules;

  final Paint _pointPaint = Paint()
    ..strokeWidth = 5.0
    ..style = PaintingStyle.fill;

  final Paint _linePaint = Paint()
    ..color = Colors.blue
    ..strokeWidth = 3.0
    ..style = PaintingStyle.stroke;

  final Paint _redLinePaint = Paint()
    ..color = Colors.red
    ..strokeWidth = 4.0
    ..style = PaintingStyle.stroke;

  PoseLandmarkPainter(
      this.pose, {
        required this.imageSize,
        required this.violatedRules,
      });

  @override
  void paint(Canvas canvas, Size size) {
    final double scaleX = size.width / imageSize.width;
    final double scaleY = size.height / imageSize.height;

    for (var landmark in pose.landmarks.values) {
      final Offset position = Offset(
        size.width - (landmark.x * scaleX),
        landmark.y * scaleY,
      );

      if (violatedRules.contains(PostureRule.armNotFullyExtended) ||
          violatedRules.contains(PostureRule.elbowTooFarBack) ||
          violatedRules.contains(PostureRule.dumbbellHeightUneven)) {
        if ([
          PoseLandmarkType.leftElbow,
          PoseLandmarkType.rightElbow,
          PoseLandmarkType.leftWrist,
          PoseLandmarkType.rightWrist,
          PoseLandmarkType.leftShoulder,
          PoseLandmarkType.rightShoulder,
        ].contains(landmark.type)) {
          _pointPaint.color = Colors.red;
        } else {
          _pointPaint.color = Colors.green;
        }
      } else {
        _pointPaint.color = Colors.green;
      }

      canvas.drawCircle(position, 4.0, _pointPaint);
    }

    _drawSegment(canvas, size, PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder, [PostureRule.torsoTooLeaned]);
    _drawSegment(canvas, size, PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow, [PostureRule.armNotFullyExtended, PostureRule.elbowTooFarBack]);
    _drawSegment(canvas, size, PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist, [PostureRule.armNotFullyExtended, PostureRule.dumbbellHeightUneven]);
    _drawSegment(canvas, size, PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow, [PostureRule.armNotFullyExtended, PostureRule.elbowTooFarBack]);
    _drawSegment(canvas, size, PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist, [PostureRule.armNotFullyExtended, PostureRule.dumbbellHeightUneven]);
    _drawSegment(canvas, size, PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip, [PostureRule.torsoTooLeaned]);
    _drawSegment(canvas, size, PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip, [PostureRule.torsoTooLeaned]);
    _drawSegment(canvas, size, PoseLandmarkType.leftHip, PoseLandmarkType.rightHip, [PostureRule.torsoTooLeaned]);
    _drawSegment(canvas, size, PoseLandmarkType.nose, PoseLandmarkType.leftEyeInner, []);
    _drawSegment(canvas, size, PoseLandmarkType.leftEyeInner, PoseLandmarkType.leftEye, []);
    _drawSegment(canvas, size, PoseLandmarkType.leftEye, PoseLandmarkType.leftEyeOuter, []);
    _drawSegment(canvas, size, PoseLandmarkType.leftEyeOuter, PoseLandmarkType.leftEar, []);
    _drawSegment(canvas, size, PoseLandmarkType.nose, PoseLandmarkType.rightEyeInner, []);
    _drawSegment(canvas, size, PoseLandmarkType.rightEyeInner, PoseLandmarkType.rightEye, []);
    _drawSegment(canvas, size, PoseLandmarkType.rightEye, PoseLandmarkType.rightEyeOuter, []);
    _drawSegment(canvas, size, PoseLandmarkType.rightEyeOuter, PoseLandmarkType.rightEar, []);
    _drawSegment(canvas, size, PoseLandmarkType.leftMouth, PoseLandmarkType.rightMouth, []);
    _drawSegment(canvas, size, PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee, []);
    _drawSegment(canvas, size, PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle, []);
    _drawSegment(canvas, size, PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee, []);
    _drawSegment(canvas, size, PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle, []);
    _drawSegment(canvas, size, PoseLandmarkType.leftAnkle, PoseLandmarkType.leftHeel, []);
    _drawSegment(canvas, size, PoseLandmarkType.rightAnkle, PoseLandmarkType.rightHeel, []);
    _drawSegment(canvas, size, PoseLandmarkType.leftHeel, PoseLandmarkType.leftFootIndex, []);
    _drawSegment(canvas, size, PoseLandmarkType.rightHeel, PoseLandmarkType.rightFootIndex, []);
  }

  void _drawSegment(
      Canvas canvas,
      Size size,
      PoseLandmarkType startType,
      PoseLandmarkType endType,
      List<PostureRule> rulesAffectingThisSegment) {
    final start = pose.landmarks[startType];
    final end = pose.landmarks[endType];

    if (start != null && end != null) {
      final double scaleX = size.width / imageSize.width;
      final double scaleY = size.height / imageSize.height;

      final double startDx = size.width - (start.x * scaleX);
      final double startDy = start.y * scaleY;

      final double endDx = size.width - (end.x * scaleX);
      final double endDy = end.y * scaleY;

      final Offset startPoint = Offset(startDx, startDy);
      final Offset endPoint = Offset(endDx, endDy);

      bool isViolated = rulesAffectingThisSegment.any((rule) => violatedRules.contains(rule));
      canvas.drawLine(startPoint, endPoint, isViolated ? _redLinePaint : _linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant PoseLandmarkPainter oldDelegate) {
    const listEquality = ListEquality();
    return oldDelegate.pose != pose || !listEquality.equals(oldDelegate.violatedRules, violatedRules);
  }
}