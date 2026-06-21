import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

class ImageProcessor {
  // تحويل صورة الكاميرا إلى تنسيق النموذج
  static img.Image convertCameraImage(CameraImage image) {
    // تحويل YUV إلى RGB
    var imgBuffer = image.planes[0].bytes;

    // إذا كانت الصورة بتنسيق NV21 (شائع في Android)
    if (Platform.isAndroid) {
      return img.Image.fromBytes(
        width: image.width,
        height: image.height,
        bytes: imgBuffer.buffer,
        numChannels: 3,
        order: img.ChannelOrder.bgr,
      );
    } else {
      return img.Image.fromBytes(
        width: image.width,
        height: image.height,
        bytes: imgBuffer.buffer,
        numChannels: 3,
        order: img.ChannelOrder.bgra,
      );
    }
  }

  // تغيير حجم الصورة
  static img.Image resizeImage(img.Image image, int width, int height) {
    return img.copyResize(
      image,
      width: width,
      height: height,
      interpolation: img.Interpolation.linear,
    );
  }

  // تحويل الصورة إلى قائمة بايت Float32
  static Float32List imageToFloat32List(
    img.Image image,
    int inputSize,
    double mean,
    double std,
  ) {
    // تغيير حجم الصورة
    var resizedImage = resizeImage(image, inputSize, inputSize);

    // تحويل إلى Float32
    Float32List floatList = Float32List(inputSize * inputSize * 3);
    int index = 0;

    for (int y = 0; y < resizedImage.height; y++) {
      for (int x = 0; x < resizedImage.width; x++) {
        final pixel = resizedImage.getPixel(x, y);
        floatList[index++] = ((pixel.r - mean) / std);
        floatList[index++] = ((pixel.g - mean) / std);
        floatList[index++] = ((pixel.b - mean) / std);
      }
    }

    return floatList;
  }
}
