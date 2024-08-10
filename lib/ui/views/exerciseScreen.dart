import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class ExerciseScreen extends StatefulWidget {
  const ExerciseScreen({super.key});

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

late List<CameraDescription> cameras;

class _ExerciseScreenState extends State<ExerciseScreen> {
  CameraController? controller;
  late List<CameraDescription> cameras;
  bool isBusy = false;
  int reps = 0;
  CameraImage? img;
  dynamic poseDetector;
  dynamic _scanResults;
  String poseCoordinates = '';

  // *********************
  // *** Init State ***
  // *********************
  @override
  void initState() {
    super.initState();
    final options = PoseDetectorOptions();
    poseDetector = PoseDetector(options: options);
    initializeCamera();
  }

  // *********************
  // *** Initialise Camera ***
  // *********************
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
        if (!isBusy) {
          isBusy = true;
          img = image;
          doPoseEstimationOnFrame();
        }
      });
      setState(() {});
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

  // *********************
  // *** Pose Estimation ***
  // *********************
  void doPoseEstimationOnFrame() async {
    if (img == null) return;

    var inputImage = getInputImage();

    final List<Pose> poses = await poseDetector.processImage(inputImage);
    _scanResults = poses;
    for (Pose pose in poses) {
      // to access all landmarks
      pose.landmarks.forEach((_, landmark) {
        final type = landmark.type;
        final x = landmark.x;
        final y = landmark.y;
      });

      // to access specific landmarks
      final landmark = pose.landmarks[PoseLandmarkType.nose];
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
    final inputImageFormat = InputImageFormatValue.fromRawValue(img!.format.raw);

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
        !controller!.value.isInitialized) {
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
      body: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          children: [
            const SizedBox(
              height: 25,
            ),
            const Text("GAINZ AI"),
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
            Container(
              margin: EdgeInsets.only(top: 20),
              decoration: BoxDecoration(border: Border.all()),
              height: MediaQuery.of(context).size.height / 1.6,
              width: MediaQuery.of(context).size.width,
              child: Stack(
                children: stackChildren,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    "Total Reps: $reps",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey),
                  child: const Text(
                    "Clear",
                    style: TextStyle(color: Colors.white),
                  ),
                )
              ],
            ),
            Container(
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(45),
                  backgroundColor: Colors.black,
                ),
                child: const Text(
                  "Go",
                  style: TextStyle(color: Colors.white, fontSize: 35),
                ),
              ),
            )
          ],
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

    final jointPaint = Paint()
      ..style = PaintingStyle.fill
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

    final bodyPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.redAccent;

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

          canvas.drawCircle(Offset(x, y), 6, jointPaint);
        }
      }

      void paintLine(PoseLandmarkType type1, PoseLandmarkType type2,
          Paint paintType) {
        final joint1 = pose.landmarks[type1];
        final joint2 = pose.landmarks[type2];

        if (joint1 == null || joint2 == null) return;

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
      paintLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow,
          leftPaint);
      paintLine(
          PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist, leftPaint);
      paintLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow,
          rightPaint);
      paintLine(
          PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist, rightPaint);

      // Draw body connections
      paintLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder,
          bodyPaint);
      paintLine(
          PoseLandmarkType.leftHip, PoseLandmarkType.rightHip, bodyPaint);

      // Draw torso lines
      paintLine(
          PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip, bodyPaint);
      paintLine(
          PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip, bodyPaint);

      // Draw legs
      paintLine(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee, leftPaint);
      paintLine(
          PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle, leftPaint);
      paintLine(
          PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee, rightPaint);
      paintLine(
          PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle, rightPaint);
    }
  }

  @override
  bool shouldRepaint(PosePainter oldDelegate) {
    return oldDelegate.absoluteImageSize != absoluteImageSize ||
        oldDelegate.poses != poses ||
        oldDelegate.lensDirection != lensDirection;
  }
}
