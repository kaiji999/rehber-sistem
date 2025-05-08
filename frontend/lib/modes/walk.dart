import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:path_provider/path_provider.dart';

class WalkPage extends StatefulWidget {
  const WalkPage({Key? key}) : super(key: key);

  @override
  _WalkPageState createState() => _WalkPageState();
}

class _WalkPageState extends State<WalkPage> {
  late CameraController _cameraController;
  late ImageLabeler _imageLabeler;
  bool isDetecting = false;
  String result = "No Object Detected";

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _initializeImageLabeler();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final camera = cameras.first;

    _cameraController = CameraController(camera, ResolutionPreset.max);

    await _cameraController.initialize();
    _startImageStream();
  }

  void _initializeImageLabeler() {
    final options = ImageLabelerOptions(confidenceThreshold: 0.5);
    _imageLabeler = ImageLabeler(options: options);
  }

  void _startImageStream() {
    _cameraController.startImageStream((CameraImage image) async {
      if (isDetecting) return;

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
      final List<ImageLabel> labels = await _imageLabeler.processImage(
        inputImage,
      );

      String detectedObjects = labels.isNotEmpty
          ? labels
              .map(
                (label) =>
                    "${label.label} - ${(label.confidence * 100).toStringAsFixed(2)}%",
              )
              .join("\n")
          : "No Object Detected";

      setState(() {
        result = detectedObjects;
      });
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error Processing Image"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _imageLabeler.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onDoubleTap: () {
          Navigator.pop(context); // Navigate back to the homepage
        },
        child: _cameraController.value.isInitialized
            ? Stack(
                children: [
                  CameraPreview(_cameraController),
                  Positioned(
                    bottom: 20,
                    left: 20,
                    child: Text(
                      result,
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