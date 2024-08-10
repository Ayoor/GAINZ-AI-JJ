import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:gainz_ai/ui/views/exercise_summary.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class ExerciseScreen extends StatefulWidget {
  const ExerciseScreen({super.key});

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

late List<CameraDescription> cameras;

/*TODO
implement mvvm
Save on Firebase
readme
code comments
video demonstration of the app
 */
class _ExerciseScreenState extends State<ExerciseScreen> {
  CameraController? controller;
  late List<CameraDescription> cameras;
  bool isBusy = false;
  int reps = 0;
  CameraImage? img;
  dynamic poseDetector;
  dynamic _scanResults;
  String poseCoordinates = '';

  bool isCounting = false; // To control when the counting starts
  bool hasStarted = false; // To track if the exercise has started or stopped

  Timer? _timer; // Timer object
  int _start = 0; // Timer start in seconds

  @override
  void initState() {
    super.initState();
    final options = PoseDetectorOptions();
    poseDetector = PoseDetector(options: options);
    initializeCamera();
  }

  void initializeCamera() async {
    WidgetsFlutterBinding.ensureInitialized();
    cameras = await availableCameras();

    final options = PoseDetectorOptions(mode: PoseDetectionMode.stream);
    poseDetector = PoseDetector(options: options);

    controller = CameraController(cameras[1], ResolutionPreset.max);
    await controller?.initialize().then((_) {
      if (!mounted) {
        return;
      }
      controller?.startImageStream((image) {
        if (!isBusy && isCounting) {
          // Only process if not busy and counting
          isBusy = true;
          img = image;
          doPoseEstimationOnFrame();
        }
      });
    }).catchError((e) {
      print('Error initializing camera: $e');
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    poseDetector.close();
    super.dispose();
  }

  bool isInJackPosition = false;

  void doPoseEstimationOnFrame() async {
    if (img == null) return;

    var inputImage = getInputImage();
    final List<Pose> poses = await poseDetector.processImage(inputImage);
    _scanResults = poses;

    for (Pose pose in poses) {
      // Get landmarks
      final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
      final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];
      final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
      final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];
      final nose = pose.landmarks[PoseLandmarkType.nose];

      // Ensure the landmarks are detected
      if (leftWrist != null &&
          rightWrist != null &&
          leftAnkle != null &&
          rightAnkle != null &&
          nose != null) {
        // Check if hands are above head (jumping jack "up" position)
        bool handsAboveHead = leftWrist.y < nose.y && rightWrist.y < nose.y;

        // Check if feet are apart (jumping jack "up" position)
        bool feetApart = (rightAnkle.x - leftAnkle.x).abs() >
            200; // Adjust threshold as needed

        // Check if hands are by the sides (jumping jack "down" position)
        bool handsBySides = leftWrist.y > nose.y && rightWrist.y > nose.y;

        // Check if feet are together (jumping jack "down" position)
        bool feetTogether = (rightAnkle.x - leftAnkle.x).abs() <
            100; // Adjust threshold as needed

        if (handsAboveHead && feetApart) {
          // The user is in the "jack" position
          isInJackPosition = true;
        } else if (handsBySides && feetTogether && isInJackPosition) {
          // The user has returned to the "jump" position from the "jack" position
          setState(() {
            reps++;
          });
          isInJackPosition = false; // Reset the state
        }
      }
    }

    setState(() {
      _scanResults;
      isBusy = false;
    });
  }

  InputImage getInputImage() {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in img!.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();
    final Size imageSize = Size(img!.width.toDouble(), img!.height.toDouble());
    final camera = cameras[1];
    final imageRotation =
        InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    final inputImageFormat =
        InputImageFormatValue.fromRawValue(img!.format.raw);

    final planeData = img!.planes.map((Plane plane) {
      return InputImagePlaneMetadata(
        bytesPerRow: plane.bytesPerRow,
        height: plane.height,
        width: plane.width,
      );
    }).toList();

    final inputImageData = InputImageData(
      size: imageSize,
      imageRotation: imageRotation!,
      inputImageFormat: inputImageFormat!,
      planeData: planeData,
    );

    return InputImage.fromBytes(bytes: bytes, inputImageData: inputImageData);
  }

  Widget buildResult() {
    if (_scanResults == null ||
        controller == null ||
        !controller!.value.isInitialized ||
        !isCounting) {
      // Only paint when counting
      return const Text('');
    }

    final Size imageSize = Size(
      controller!.value.previewSize!.height,
      controller!.value.previewSize!.width,
    );
    CustomPainter painter = PosePainter(
        imageSize, _scanResults, controller!.description.lensDirection);
    return CustomPaint(
      painter: painter,
    );
  }

  void startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _start++;
      });
    });
  }

  void stopTimer() {
    _timer?.cancel();
  }

  void resetTimer() {
    setState(() {
      _start = 0;
    });
    stopTimer();
  }

  String getTimerText() {
    final minutes = _start ~/ 60;
    final seconds = _start % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> stackChildren = [];
    Size size = MediaQuery.of(context).size;

    if (controller != null && controller!.value.isInitialized) {
      stackChildren.add(
        Positioned(
          top: 0.0,
          left: 0.0,
          width: size.width,
          height: size.height / 1.6,
          child: AspectRatio(
            aspectRatio: controller!.value.aspectRatio,
            child: CameraPreview(controller!),
          ),
        ),
      );
    }

    stackChildren.add(
      Positioned(
        top: 0.0,
        left: 0.0,
        width: size.width,
        height: size.height / 1.6,
        child: buildResult(),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.blueGrey,
      body: Padding(
        padding: const EdgeInsets.all(15.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(
                height: 25,
              ),
              const Text("GAINZ AI", style: TextStyle(color: Colors.white),),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Jumping Jacks",
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Image.asset(
                    "lib/Assets/jumping-jack.png",
                    width: 30,
                  )
                ],
              ),
             const SizedBox(height: 10,),
             const Text("Please position the camera to cover your entire body", style: TextStyle(color: Colors.pinkAccent, fontSize: 16),),
              Container(
                margin: const EdgeInsets.only(top: 20),
                decoration: BoxDecoration(border: Border.all()),
                height: MediaQuery.of(context).size.height / 1.6,
                width: MediaQuery.of(context).size.width,
                child: Stack(
                  children: stackChildren,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        "Total Reps: $reps",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          reps = 0;
                          resetTimer();
                          hasStarted = false;

                        });
                      },
                      child: const Text(
                        "Reset",
                        style: TextStyle(color: Colors.redAccent, decoration: TextDecoration.underline, decorationColor: Colors.redAccent, fontSize: 20),
                      ),
                    ),
                    Text("Duration: ${getTimerText()}",style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),

                  ],
                ),
              ),
              Container(
                child: ElevatedButton(
                  onPressed: () {
                    if(hasStarted) {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => ExerciseSummary(reps: reps, time: getTimerText())));
                    }
                    setState(() {
                      if (hasStarted) {
                        stopTimer();
                      } else {
                        startTimer();
                      }
                      isCounting = !isCounting;
                      hasStarted = !hasStarted; // Toggle start/stop state
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(25),
                    backgroundColor: hasStarted
                        ? Colors.red
                        : Colors.black, // Change color based on state
                  ),
                  child: Text(
                    hasStarted ? "Stop" : "Go", // Change text based on state
                    style: const TextStyle(color: Colors.white, fontSize: 35),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class PosePainter extends CustomPainter {
  PosePainter(this.absoluteImageSize, this.poses, this.lensDirection);

  final Size absoluteImageSize;
  final List<Pose> poses;
  final CameraLensDirection lensDirection;

  // Define a list of joints where circles should be drawn
  final List<PoseLandmarkType> joints = [
    PoseLandmarkType.leftShoulder,
    PoseLandmarkType.rightShoulder,
    PoseLandmarkType.leftElbow,
    PoseLandmarkType.rightElbow,
    PoseLandmarkType.leftWrist,
    PoseLandmarkType.rightWrist,
    PoseLandmarkType.leftHip,
    PoseLandmarkType.rightHip,
    PoseLandmarkType.leftKnee,
    PoseLandmarkType.rightKnee,
    PoseLandmarkType.leftAnkle,
    PoseLandmarkType.rightAnkle,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final double scaleX = size.width / absoluteImageSize.width;
    final double scaleY = size.height / absoluteImageSize.height;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..color = Colors.green;

    final leftPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.yellow;

    final rightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.blueAccent;

    final connectingLinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..color = Colors.red;

    for (final pose in poses) {
      // Draw circles only on joints
      for (final joint in joints) {
        final landmark = pose.landmarks[joint];
        if (landmark != null) {
          double x = landmark.x * scaleX;
          double y = landmark.y * scaleY;

          // Mirror horizontally for front camera
          if (lensDirection == CameraLensDirection.front) {
            x = size.width - x;
          }

          canvas.drawCircle(Offset(x, y), 4, paint);
        }
      }

      void paintLine(
          PoseLandmarkType type1, PoseLandmarkType type2, Paint paintType) {
        final PoseLandmark joint1 = pose.landmarks[type1]!;
        final PoseLandmark joint2 = pose.landmarks[type2]!;

        double x1 = joint1.x * scaleX;
        double y1 = joint1.y * scaleY;
        double x2 = joint2.x * scaleX;
        double y2 = joint2.y * scaleY;

        // Mirror horizontally for front camera
        if (lensDirection == CameraLensDirection.front) {
          x1 = size.width - x1;
          x2 = size.width - x2;
        }

        canvas.drawLine(
          Offset(x1, y1),
          Offset(x2, y2),
          paintType,
        );
      }

      // Draw arms
      paintLine(
          PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow, leftPaint);
      paintLine(
          PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist, leftPaint);
      paintLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow,
          rightPaint);
      paintLine(
          PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist, rightPaint);

      // Draw body
      paintLine(
          PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip, leftPaint);
      paintLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip,
          rightPaint);

      // Draw legs
      paintLine(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee, leftPaint);
      paintLine(
          PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle, leftPaint);
      paintLine(
          PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee, rightPaint);
      paintLine(
          PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle, rightPaint);

      // Draw a line connecting the shoulders
      paintLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder,
          connectingLinePaint);

      // Draw a line connecting the hips
      paintLine(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip,
          connectingLinePaint);
    }
  }

  @override
  bool shouldRepaint(PosePainter oldDelegate) {
    return oldDelegate.absoluteImageSize != absoluteImageSize ||
        oldDelegate.poses != poses ||
        oldDelegate.lensDirection != lensDirection;
  }
}
