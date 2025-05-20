import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TalkPage extends StatefulWidget {
  const TalkPage({Key? key}) : super(key: key);

  @override
  _TalkPageState createState() => _TalkPageState();
}

class _TalkPageState extends State<TalkPage> {
  late CameraController _cameraController;
  late FaceDetector _faceDetector;
  late FlutterTts _flutterTts;
  bool isDetecting = false;
  bool isSpeaking = false;
  String detectedExpression = "Yüz tespit edilemedi";

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _initializeFaceDetector();
    _flutterTts = FlutterTts();
    _flutterTts.setCompletionHandler(() {
      setState(() {
        isSpeaking = false;
      });
    });
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final camera = cameras.first;

    _cameraController = CameraController(camera, ResolutionPreset.max);

    await _cameraController.initialize();
    _startImageStream();
  }

  void _initializeFaceDetector() {
    final options = FaceDetectorOptions(
      enableClassification: true,
      enableLandmarks: true,
      enableContours: false,
      minFaceSize: 0.1,
    );
    _faceDetector = FaceDetector(options: options);
  }

  void _startImageStream() {
    _cameraController.startImageStream((CameraImage image) async {
      if (isDetecting || isSpeaking) return;

      isDetecting = true;
      await _processImage(image);
      isDetecting = false;
    });
  }

  Future<void> _processImage(CameraImage cameraImage) async {
    try {
      final Directory tempDir = await getTemporaryDirectory();
      final String filePath =
          "${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg";
      final File imageFile = File(filePath);

      final XFile picture = await _cameraController.takePicture();
      await picture.saveTo(imageFile.path);

      final inputImage = InputImage.fromFile(imageFile);
      final List<Face> faces = await _faceDetector.processImage(inputImage);

      String expression =
          faces.isNotEmpty
              ? _analyzeFacialExpressions(faces.first)
              : "Yüz tespit edilemedi";

      setState(() {
        detectedExpression = expression;
      });

      // Speak the detected expression
      if (expression != "Yüz tespit edilemedi") {
        isSpeaking = true;
        await _flutterTts.speak(expression);
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Görüntü işleme hatası"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _analyzeFacialExpressions(Face face) {
    if (face.smilingProbability != null && face.smilingProbability! > 0.7) {
      return "Mutlu";
    } else if (face.smilingProbability != null &&
        face.smilingProbability! < 0.3) {
      if (face.leftEyeOpenProbability != null &&
          face.leftEyeOpenProbability! < 0.3 &&
          face.rightEyeOpenProbability != null &&
          face.rightEyeOpenProbability! < 0.3) {
        return "Üzgün";
      } else if (face.leftEyeOpenProbability != null &&
          face.leftEyeOpenProbability! > 0.7 &&
          face.rightEyeOpenProbability != null &&
          face.rightEyeOpenProbability! > 0.7) {
        return "Şaşırmış";
      } else {
        return "Korkmuş";
      }
    } else {
      return "Tepkisiz";
    }
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _faceDetector.close();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onDoubleTap: () {
          Navigator.pop(context); // Navigate back to the homepage
        },
        child:
            _cameraController.value.isInitialized
                ? Stack(
                  children: [
                    CameraPreview(_cameraController),
                    Positioned(
                      bottom: 20,
                      left: 20,
                      child: Text(
                        detectedExpression,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          backgroundColor: Colors.black54,
                        ),
                      ),
                    ),
                  ],
                )
                : const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
