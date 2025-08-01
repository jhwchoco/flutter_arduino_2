import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:my_final_app/models.dart';
import 'package:camera/camera.dart'; // CameraImageFormatGroup을 위해 필요
import 'package:google_mlkit_commons/google_mlkit_commons.dart'; // 별칭 없이 직접 사용

const double pi = 3.1415926535897932;

double calculateAngle3P(Offset a, Offset b, Offset c) {
  double distance(Offset p1, Offset p2) {
    return sqrt(pow(p1.dx - p2.dx, 2) + pow(p1.dy - p2.dy, 2));
  }

  final double ab = distance(a, b);
  final double bc = distance(b, c);
  final double ac = distance(a, c);

  double cosAngle = 0.0;
  if (ab > 0 && bc > 0) {
    cosAngle = (ab * ab + bc * bc - ac * ac) / (2 * ab * bc);
  }

  if (cosAngle > 1.0) cosAngle = 1.0;
  if (cosAngle < -1.0) cosAngle = -1.0;

  double angleRad = acos(cosAngle);
  return angleRad * 180 / pi;
}

Offset calculateMidpoint(Offset p1, Offset p2) {
  return Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
}

double calculateAngleToHorizontal(Offset p1, Offset p2) {
  final double dx = p2.dx - p1.dx;
  final double dy = p2.dy - p1.dy;
  final double angleRad = atan2(dy, dx);
  double angleDeg = angleRad * 180 / pi;

  if (angleDeg < 0) {
    angleDeg += 360;
  }
  return angleDeg > 180 ? angleDeg - 360 : angleDeg;
}

Tuple4<bool, String, List<PostureRule>, RepetitionState> analyzeShoulderPressPosture({
  required Pose pose,
  required RepetitionState currentRepState,
  required double lastElbowAngle,
}) {
  List<PostureRule> violatedRules = [];
  String feedbackMessage = "자세가 좋습니다.";
  bool repCounted = false;
  RepetitionState nextRepState = currentRepState;

  final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder]?.toOffset();
  final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder]?.toOffset();
  final leftElbow = pose.landmarks[PoseLandmarkType.leftElbow]?.toOffset();
  final rightElbow = pose.landmarks[PoseLandmarkType.rightElbow]?.toOffset();
  final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist]?.toOffset();
  final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist]?.toOffset();
  final leftHip = pose.landmarks[PoseLandmarkType.leftHip]?.toOffset();
  final rightHip = pose.landmarks[PoseLandmarkType.rightHip]?.toOffset();
  final nose = pose.landmarks[PoseLandmarkType.nose]?.toOffset();

  if (leftShoulder == null || rightShoulder == null ||
      leftElbow == null || rightElbow == null ||
      leftWrist == null || rightWrist == null ||
      leftHip == null || rightHip == null ||
      nose == null) {
    return Tuple4(false, "몸이 카메라에 충분히 잡히지 않았습니다.", violatedRules, currentRepState);
  }

  final double leftArmAngle = calculateAngle3P(leftShoulder, leftElbow, leftWrist);
  final double rightArmAngle = calculateAngle3P(rightShoulder, rightElbow, rightWrist);
  final double avgElbowAngle = (leftArmAngle + rightArmAngle) / 2;

  if (currentRepState == RepetitionState.initial) {
    if (avgElbowAngle <= 90) {
      nextRepState = RepetitionState.down;
      feedbackMessage = "운동 시작 준비 (팔 내림)";
    }
  } else if (currentRepState == RepetitionState.down) {
    if (avgElbowAngle >= 160) {
      nextRepState = RepetitionState.up;
      feedbackMessage = "팔을 끝까지 밀어올리세요!";
    }
  } else if (currentRepState == RepetitionState.up) {
    if (avgElbowAngle <= 90) {
      repCounted = true;
      nextRepState = RepetitionState.down;
      feedbackMessage = "횟수 카운트!";
    }
  }

  if (nextRepState == RepetitionState.up && avgElbowAngle < 160) {
    violatedRules.add(PostureRule.armNotFullyExtended);
    if (!feedbackMessage.contains("팔을 끝까지")) {
      feedbackMessage = "팔이 완전히 펴지지 않았습니다. 팔을 끝까지 밀어올리세요.";
    }
  }

  final Offset midHip = calculateMidpoint(leftHip, rightHip);
  final Offset midShoulder = calculateMidpoint(leftShoulder, rightShoulder);
  final double torsoAngle = calculateAngleToHorizontal(midHip, midShoulder);

  if (torsoAngle < 80 || torsoAngle > 100) {
    violatedRules.add(PostureRule.torsoTooLeaned);
    if (!feedbackMessage.contains("상체")) {
      feedbackMessage = "상체가 너무 기울어졌습니다. 몸을 곧게 세우세요.";
    }
  }

  if (leftElbow.dx > leftShoulder.dx + 0.05 || rightElbow.dx < rightShoulder.dx - 0.05) {
    violatedRules.add(PostureRule.elbowTooFarBack);
    if (!feedbackMessage.contains("팔꿈치")) {
      feedbackMessage = "팔꿈치가 너무 뒤로 빠졌습니다. 팔꿈치를 앞쪽에서 유지하세요.";
    }
  }

  final double wristYDiff = (leftWrist.dy - rightWrist.dy).abs();
  if (wristYDiff > 0.05) {
    violatedRules.add(PostureRule.dumbbellHeightUneven);
    if (!feedbackMessage.contains("덤벨 높이")) {
      feedbackMessage = "양쪽 덤벨의 높이를 일치시키세요.";
    }
  }

  if (!repCounted && violatedRules.isNotEmpty) {
    if (violatedRules.length >= 2) {
      feedbackMessage = "자세가 불안정합니다. 자세를 교정해주세요!";
    }
  } else if (!repCounted && violatedRules.isEmpty && nextRepState == currentRepState) {
    feedbackMessage = "자세가 좋습니다.";
  }

  return Tuple4(repCounted, feedbackMessage, violatedRules, nextRepState);
}

class Tuple4<T1, T2, T3, T4> {
  final T1 item1;
  final T2 item2;
  final T3 item3;
  final T4 item4;

  Tuple4(this.item1, this.item2, this.item3, this.item4);
}

extension PoseLandmarkExtension on PoseLandmark {
  Offset toOffset() {
    return Offset(x, y);
  }
}