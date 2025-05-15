import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart';

class WalkPage extends StatefulWidget {
  const WalkPage({Key? key}) : super(key: key);

  @override
  _WalkPageState createState() => _WalkPageState();
}

class _WalkPageState extends State<WalkPage> {
  late CameraController _cameraController;
  late Interpreter _interpreter;
  List<String> _labels = [];
  bool isDetecting = false;
  String result = "No Object Detected";

  @override
  void initState() {
    super.initState();
    _initializeModel();
    _initializeCamera();
  }

  Future<void> _initializeModel() async {
    _interpreter = await Interpreter.fromAsset('detect.tflite');
    final labelData = await rootBundle.loadString('assets/labelmap.txt');
    _labels = labelData.split('\n');
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final camera = cameras.first;

    _cameraController = CameraController(camera, ResolutionPreset.medium);
    await _cameraController.initialize();

    _startImageStream();
    setState(() {});
  }

  void _startImageStream() {
    _cameraController.startImageStream((CameraImage image) async {
      if (!isDetecting) {
        isDetecting = true;
        await _runInference(image);
        isDetecting = false;
      }
    });
  }

  Future<void> _runInference(CameraImage cameraImage) async {
    try {
      final img.Image rgbImage = _convertYUV420ToImage(cameraImage);
      final img.Image resized = img.copyResize(
        rgbImage,
        width: 300,
        height: 300,
      );

      Uint8List input = _imageToByteList(resized, 300);

      var outputBoxes = List.generate(1, (_) => List.filled(10 * 4, 0.0));
      var outputClasses = List.generate(1, (_) => List.filled(10, 0.0));
      var outputScores = List.generate(1, (_) => List.filled(10, 0.0));
      var numDetections = List.filled(1, 0.0);

      _interpreter.runForMultipleInputs(
        [input],
        {0: outputBoxes, 1: outputClasses, 2: outputScores, 3: numDetections},
      );

      String detectedText = "";
      for (int i = 0; i < numDetections[0].toInt(); i++) {
        double score = outputScores[0][i];
        int classIndex = outputClasses[0][i].toInt();
        if (score > 0.5 && classIndex < _labels.length) {
          detectedText +=
              "${_labels[classIndex]} - ${(score * 100).toStringAsFixed(2)}%\n";
        }
      }

      setState(() {
        result = detectedText.isNotEmpty ? detectedText : "No Object Detected";
      });
    } catch (e) {
      print("Error during inference: $e");
    }
  }

  Uint8List _imageToByteList(img.Image image, int size) {
    final bytes = Uint8List(size * size * 3);
    int pixelIndex = 0;
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        final pixel = image.getPixel(x, y);
        bytes[pixelIndex++] = img.getRed(pixel);
        bytes[pixelIndex++] = img.getGreen(pixel);
        bytes[pixelIndex++] = img.getBlue(pixel);
      }
    }
    return bytes;
  }

  img.Image _convertYUV420ToImage(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final uvRowStride = image.planes[1].bytesPerRow;
    final uvPixelStride = image.planes[1].bytesPerPixel!;

    final img.Image imgBuffer = img.Image(width, height);

    for (int y = 0; y < height; y++) {
      final uvRow = uvRowStride * (y >> 1);
      for (int x = 0; x < width; x++) {
        final uvPixel = uvRow + (x >> 1) * uvPixelStride;

        final yVal = image.planes[0].bytes[y * width + x];
        final uVal = image.planes[1].bytes[uvPixel];
        final vVal = image.planes[2].bytes[uvPixel];

        final r = (yVal + 1.370705 * (vVal - 128)).toInt().clamp(0, 255);
        final g = (yVal - 0.337633 * (uVal - 128) - 0.698001 * (vVal - 128))
            .toInt()
            .clamp(0, 255);
        final b = (yVal + 1.732446 * (uVal - 128)).toInt().clamp(0, 255);

        imgBuffer.setPixel(x, y, img.getColor(r, g, b));
      }
    }

    return imgBuffer;
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _interpreter.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Walk Mode - Object Detection')),
      body:
          _cameraController.value.isInitialized
              ? Stack(
                children: [
                  CameraPreview(_cameraController),
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      color: Colors.black54,
                      child: Text(
                        result,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              )
              : const Center(child: CircularProgressIndicator()),
    );
  }
}
