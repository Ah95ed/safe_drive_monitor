# Safe Drive Monitor (Driver Drowsiness Detection)

Simple flutter app made to help drivers stay awake while drivin. It uses ur phone front camera to watch ur eyes on real time, running local machine learnin on device so no internet needed and ur privacy is safe.

---

## English Overview

### What is this project?
This app is built to detect if a driver is getting sleepy or closin their eyes for too long. If ur eyes stay closed for more than a sec, a loud sound alarm triggers to wake u up before any accident happens.

### How it works?
1. App opens ur front camera feed.
2. It takes frames and crops the eye/face region to 224x224 size.
3. The image gets normalized with mean 128 and std 128.
4. Tensor data is sent to the local TFLite model (`eye_state_model_tensorFlow.tflite`).
5. Model gives two outputs: Open score and Closed score.
6. The app checks time:
   - Quick blink (< 400ms): normal, nothin happens.
   - Closed between 400ms - 1000ms: watching state.
   - Closed for over 1200ms: alarm triggers instantly with sound and vibration.
   - As soon as u open ur eyes again, the sound stops immediately.

### Model details
- Model file: `assets/models/eye_state_model_tensorFlow.tflite`
- Input size: 1 x 224 x 224 x 3 (Float32)
- Normalization: `(pixel - 128.0) / 128.0`
- Output shape: `[1, 2]` where index 0 is Open and index 1 is Closed
- Preprocessin: supports planar RGB (Java compatible) and interleaved RGB.

### Important files and folders
- `lib/main.dart`: app start point and orientation lock.
- `lib/features/drowsiness_detection/data/services/eye_state_classifier.dart`: runs tflite interpreter using direct native memory.
- `lib/features/drowsiness_detection/data/services/image_preprocessor.dart`: converts camera stream to normalized float tensors.
- `lib/features/drowsiness_detection/domain/services/drowsiness_analyzer.dart`: time based state machine for blinks and sleep detection.
- `lib/features/drowsiness_detection/presentation/screens/driver_monitor_screen.dart`: main screen with camera feed and alert card.
- `assets/models/`: contains the trained tflite eye models.
- `assets/sounds/alarm.mp3`: loud alert audio file.

### How to run?
Make sure u have flutter sdk installed on ur machine, then connect ur android phone and run:

```bash
flutter pub get
flutter run
```

---

## الوصف باللغة العربية

### ما هو هذا التطبيق؟
تطبيق فلاتر مخصص لمراقبة يقظة السائق أثناء القيادة لمنع الحوادث الناتجة عن النوم أو النعاس. التطبيق يعمل بالكامل على الهاتف بدون الحاجة إلى اتصال بالإنترنت (On-Device Inference)، ولا يتم إرسال أي صور أو فيديو إلى خوادم خارجية حفاظاً على الخصوصية.

### كيف يعمل التطبيق؟
1. يفتح التطبيق الكاميرا الأمامية للهاتف لمتابعة وجه وعيني السائق.
2. يتم قص وتجهيز إطارات الكاميرا بحجم 224×224 بكسل مع ضبط الاتجاه.
3. يتم تحويل وتطبيع قيم البكسلات حسب معادلة الموديل (طرح 128 والقسمة على 128).
4. يمرر الإطار لنموذج TensorFlow Lite المحلي لحساب نسبة فتح أو غلق العين.
5. يتولى نظام إدارة الحالة الزمني اتخاذ القرار:
   - الرمش الطبيعي (أقل من 400 ميلي ثانية): يتم تجاهله ولا يطلق أي إنذار.
   - إغلاق العين لأكثر من 1.2 ثانية: يعتبر نوم ويتم تشغيل صوت إنذار قوي ومستمر مع الاهتزاز.
   - بمجرد فتح السائق لعينه مرة أخرى: يتوقف الإنذار الصوتي بشكل فوري.

### تفاصيل النموذج والتدريب
- ملف النموذج: `assets/models/eye_state_model_tensorFlow.tflite`
- أبعاد المدخلات: `1x224x224x3` بنوع Float32.
- مخرجات النموذج: مصفوفة `[1, 2]` حيث يمثل المؤشر 0 حالة العين المفتوحة والمؤشر 1 حالة العين المغلقة.
- طريقة المعالجة: تدعم ترتيب الذاكرة الموجه (Planar RGB) المطابق للنسخة الأصلية وكذلك الترتيب التسلسلي (Interleaved RGB).

### بنية ومواقع الملفات الأساسية
- `lib/main.dart`: نقطة انطلاق التطبيق وتثبيت الاتجاه الرأسي.
- `lib/features/drowsiness_detection/data/services/eye_state_classifier.dart`: إدارة وتشغيل نموذج TFLite ونقل الذاكرة المباشر.
- `lib/features/drowsiness_detection/data/services/image_preprocessor.dart`: تحويل ومعالجة إطارات الكاميرا إلى مصفوفات رقمية.
- `lib/features/drowsiness_detection/domain/services/drowsiness_analyzer.dart`: المنطق الزمني لتمييز الرمش الطبيعي عن النعاس وإدارة الإنذار.
- `lib/features/drowsiness_detection/presentation/screens/driver_monitor_screen.dart`: الشاشة الرئيسية التي تعرض الكاميرا وبطاقة الحالة وزر التشغيل.
- `assets/models/`: الموديلات المدربة بصيغة tflite.
- `assets/sounds/alarm.mp3`: ملف صوت الإنذار.

### طريقة التشغيل
بعد تثبيت Flutter وتوصيل الهاتف، قم بتنفيذ الأوامر التالية:

```bash
flutter pub get
flutter run
```
