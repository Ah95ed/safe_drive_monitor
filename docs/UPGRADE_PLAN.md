# Safe Drive Monitor — خطة الترقية (تقسيم البرومبت V3)

> قاعدة: Audit → Fix → Refactor → Extend → Test على المشروع الحالي. لا `flutter create`، لا إعادة معمارية،
> لا استبدال Provider، لا نقل المنطق إلى Native. أقل تعديل صحيح + اختبار + قياس بعد كل مرحلة.

---

## PHASE 0 — AUDIT (نقطة الأساس) ✅ تم

| فحص | النتيجة |
|-----|---------|
| Flutter | 3.47.2 / Dart 3.13.2 (stable) |
| `flutter pub get` | ✅ نجح |
| `flutter analyze` | ✅ `No issues found` |
| `flutter test` | ⚠️ الوكيل السابق **حذف مجلد `test/` بالكامل** — تمت الاستعادة من HEAD |
| baseline بعد الاستعادة | **13 ناجح / 4 فاشل** (انظر أدناه) |
| targetSdk / compileSdk | 36 / 36 — حديث، يبقى |
| minSdk | 24 (كافٍ لـ ML Kit ≥ 21) |
| coreLibraryDesugaring | مفعّل + dependency موجودة ✅ |
| Manifest ML Kit bundled model | `com.google.mlkit.vision.DEPENDENCIES=face` موجودة ✅ |
| Release signing | يستخدم debug keystore ❌ (PHASE 18) |

### الاختبارات الفاشلة في الأساس
1. `drowsiness_analyzer_test` → *watching→drowsy→alarm*
2. `drowsiness_analyzer_test` → *natural blink < 400ms*
3. `drowsiness_analyzer_test` → *alarm recovery 1000ms*
4. `widget_test` → *Timer pending after dispose*

السبب الجذري (1‑3): الوكيل السابق ربط **PERCLOS كمُطلق إنذار مباشر** بدون نافذة تسخين، فأول رمشة
تجعل `currentPerclos = 100%` → `isAlarmLevel = true` فوراً → إنذار كاذب / وعدم قدرة على الاستشفاء.
السبب (4): `AppCameraService.dispose` يجدول `Future.delayed(60ms)` غير محروس.

---

## المشاكل الجذرية المؤكدة (سبب "لا يكشف الوجه / لا يكشف العينين")

| # | المكان | العطب | الإصلاح | Phase |
|---|--------|-------|---------|-------|
| A | `eye_prediction_model.dart` | وضع `probabilities` يقسم على المجموع؛ ينهار مع logits سالبة → حالة `unknown`/عكسية دائماً | إضافة `ModelOutputMode.auto` + stable softmax حقيقي؛ كشف تلقائي logits/probabilities | 2 |
| B | `perclos_calculator.dart` | لا نافذة تسخين → PERCLOS يفرض `drowsy/alarm` من أول عيّنة | `isReady` (≥20s span و ≥30 عيّنة) يحرس `isWarningLevel/isAlarmLevel` | 7 |
| C | `drowsiness_analyzer.dart` | PERCLOS وحده يطلق الإنذار الصاخب ويمنع الاستشفاء | خفض PERCLOS إلى `drowsy` فقط؛ الاستشفاء = زمن فتح متواصل فقط | 7 |
| D | `camera_service.dart` | تايمر dispose غير محروس يسرّب في الاختبارات | حراسة `if (_controller != null)` | 1 |
| E | `drowsiness_detection_provider.dart` | `_syncConfigWithClassifier` يُستدعى مرة في الباني فقط | استدعاؤه أيضاً في `initialize()` | 2 |
| F | `face_detection_service.dart` | لا سجلّات تشخيص؛ الدوران يعتمد `sensorOrientation` الخام فقط | سجلّات تشخيص + توضيح مسار التحويل؛ تحقق على جهاز حقيقي بعد `flutter clean` | 4 |

> ملاحظة: تحويل YUV_420_888 → NV21 ومطابقة إحداثيات ROI بين ML Kit والـ preprocessor فُحصت **وهي صحيحة**
> رياضياً (حالات الدوران 90/270 معكوسة عكسياً بشكل سليم). لا تُعاد كتابتها.

---

## المراحل (تنفيذ بالترتيب — اختبار + قياس بعد كل واحدة)

- [~] **1. Bugs مؤكدة**: ✅ dispose timer محروس (D)؛ ✅ PERCLOS readiness (B) + demotion (C). باقٍ: تقليل `debugPrint` لكل frame في الـ provider → AppLogger/throttle.
- [~] **2. تفسير الخرج**: ✅ `ModelOutputMode.auto` + softmax مستقر (A)؛ ✅ `_syncConfigWithClassifier` في `initialize()` (E). باقٍ: تأكيد نوع الخرج فعلياً على جهاز (inspection tool)، ضبط عتبتي Open/Closed.
- [~] **3. Recovery**: ✅ `recoveryThreshold` = 1000ms ولا يُحجب بـ PERCLOS + اختبار الاستشفاء يمرّ. باقٍ: اختبارات تسلسلات `unknown` الطويلة.
- [ ] **4. Golden TFLite compatibility**: صور ثابتة → planar/interleaved/rotation/mirror/normalization/center-crop، حفظ الخرج المتوقع ضمن tolerance.
- [ ] **5. ML Kit face detection حقيقي**: bundled/offline، `DriverFaceTracker` متعدد الوجوه، تقييم `RoiStrategy` (legacyCenterCrop / fullFace / eyeBand) بالبيانات.
- [ ] **6. Background Camera PoC**: foreground service + التحقق من وصول frames بعد Home/شاشة مطفأة/تطبيق آخر. قبل أي توسّع.
- [ ] **7. Foreground Service + notification + wakelock + BatteryOptimizationService** (شرح قبل طلب النظام).
- [ ] **8. MonitoringHealth + Watchdog + MonitoringIssue** منفصلة عن `DriverAlertState`.
- [ ] **9. Direct ROI preprocessing** داخل `ImagePreprocessor` الحالي (لا preprocessor موازٍ)، benchmark old vs optimized بنفس Golden output.
- [ ] **10. Profile ثم Isolate** فقط عند الحاجة (long‑lived worker، لا spawn لكل frame).
- [ ] **11. Adaptive inference** (صعود سريع/نزول تدريجي + hysteresis) + thermal/battery.
- [ ] **12. Low‑light**: `LightingManager` (normal/low/critical) من عيّنة Y؛ فشل صريح `insufficientLight`.
- [ ] **13. Driving black‑screen mode** (Reliable Mode افتراضي، Real screen‑off يُقاس).
- [ ] **14. UI rebuilds**: `Selector`/`Consumer` مُضيّق، تحديث metrics ~2Hz، إزالة `debugPrint` لكل frame، `LegacyDecisionAnalyzer` debug فقط.
- [ ] **15. Model/ROI evaluation**: dataset محلي، مقاييس (Recall للـ closed أولاً، False Negative، false alarms/hour...).
- [ ] **16. Localization** (`flutter_localizations` + `gen-l10n` ar/en) نقل تدريجي.
- [ ] **17. Privacy + Disclaimer** يظهر قبل أول جلسة، موافقة محلية، لا `INTERNET` في merged manifest.
- [ ] **18. Release signing** (`key.properties` + keystore + CI secrets) + R8 keep rules عند الحاجة.
- [ ] **19. CI**: `pub get` → `analyze --fatal-warnings` → `test --coverage` → build مرة واحدة، Pin Flutter، بلا `pub upgrade`.
- [ ] **20. Dependencies**: لا إضافة package إلا بحاجة مُثبتة (`google_mlkit_face_detection` موجودة).

---

## سجل التنفيذ

### 2026-09-01
- PHASE 0: audit + استعادة `test/` (6 ملفات) من HEAD. baseline = 13/4.
- PHASE 1/2/3 (جزئي):
  - `PerclosCalculator`: `isReady` (≥20s + ≥30 عيّنة) يحرس `isWarningLevel/isAlarmLevel`.
  - `DrowsinessAnalyzer`: PERCLOS لم يعد يطلق الإنذار الصاخب وحده (→ `drowsy` فقط)؛ الاستشفاء يعتمد الزمن المفتوح فقط.
  - `camera_service.dispose`: حراسة تايمر الـ 60ms (`_controller != null`).
  - `ModelOutputMode.auto` + `normalizeScores` + softmax مستقر؛ الافتراضي الآن `auto` في classifier و `fromRawOutput`.
  - `provider.initialize`: `_syncConfigWithClassifier()` يُعاد تطبيقه.
  - `face_detection_service`: سجلّات تشخيص throttled (‏1/ث) لعدد الوجوه/الصيغة/الأبعاد/الدوران.
  - اختبارات: +16 (eye output modes، PERCLOS readiness، PERCLOS-no-alarm). **النتيجة: 29/29 ✅**، `analyze` نظيف.
- **يتطلب جهاز Android حقيقي**: `flutter clean && flutter run` ثم فحص لوج `face-detect:` — إن كان `faces(sum)=0` دائماً فالمشكلة في ML Kit native/الدوران؛ إن ظهرت وجوه فراقب لوج `[EYE_STATUS]` لصحة التصنيف.

### 2026-09-01 (جولة 2 — بعد لوج الجهاز)
- **الجهاز أثبت**: ML Kit يكشف الوجه بنجاح (`faces(sum)=2` لكل frame، `yuv420 640x480 planes=3 rot=270`).
- **العطب الحقيقي**: الموديل يعطي `Closed 93–97%` والعينان **مفتوحتان** (تأكيد المستخدم). PERCLOS 90% أثر تابع.
- سببان مرجّحان (خمّنهما الوكيل السابق بلا قياس):
  1. **channelLayout = `planarRgb` عند الإقلاع** — تنسور `[1,224,224,3]` قياسي = HWC interleaved. planar → إدخال مشوّه → الموديل ينهار لفئة واحدة. الوضع `improved` يضبط interleaved لكن `setDetectionMode` يعمل early-return لأن الوضع أصلاً `improved` → لا يُطبَّق أبداً.
  2. **ترتيب `index 0 = Open`** قد لا يطابق هذا الـ `.tflite`.
- الإصلاح هذه الجولة:
  - `ImagePreprocessor.channelLayout` الافتراضي → `interleavedRgb`.
  - `provider._applyDetectionModeConfig()` جديد يُستدعى في `initialize()` (وفي `setDetectionMode`) → يدفع layout/pipeline/roi متسقة من أول تشغيل + يفعّل `debugRawOutput` في debug.
  - `TfliteEyeStateClassifier.debugRawOutput`: لوج throttled (1/ث) للخرج **الخام** + ROI + layout + أول 3 قيم إدخال.
- **مطلوب من المستخدم — اختبار مضبوط**: شغّل، انظر للكاميرا **بعينين مفتوحتين 10 ثوانٍ** ثم **مغمضتين 10 ثوانٍ**، وأرسل أسطر `RAW out=[...]`. منها نحسم: قلب التسميات؟ أم إصلاح المعالجة؟

### 2026-09-01 (جولة 3 — تحليل بيانات الجهاز المضبوطة)
- بيانات الحقيقة الأرضية من المستخدم:
  - مفتوحة: `[0.23,-0.26] [-0.06,0.00] [0.33,-0.13] [-0.02,0.10]`
  - مغلقة: `[-0.29,0.32] [0.14,0.12] [-0.16,0.46] [0.00,-0.09]`
- **الاستنتاج**:
  1. ترتيب التسميات (`0=open, 1=closed`) **صحيح** — يوجد ميل ضعيف لكنه حقيقي.
  2. الـ logits الخام **قريبة من الصفر (±0.4)** = الموديل **مشوّش وليس مقلوباً**؛ موديل سليم يعطي `[4,-3]`. سبب التشويش: الإدخال ليس صورة عين يتعرّف عليها.
  3. `roi=none` متكرر (ROI يتقادم بين عمليات الكشف). كما أن eye landmarks (نوع 4/10) **لا تصل من الـ plugin** → القص يعتمد شريط تخميني ثم upsample من ~165×62 إلى 224² → OOD.
- إصلاح هذه الجولة:
  - `RoiStrategy` الافتراضي (improved) → `fullFace` (صندوق ML Kit الموثوق) بدل `eyeBand`.
  - `legacyCenterCrop` الآن يمرّر `dynamicRoi=null` (قص مركزي حقيقي كمرجع Java).
  - `DriverFaceTracker.faceLossTimeout` 1000→1500ms (يقلّل `roi=none`).
  - لوج جديد: **صورة ASCII مصغّرة 40×24 لِما يراه الموديل فعلاً** (`model-input thumbnail`).
- **مطلوب — اختبار مضبوط جديد**: افتح/أغمض 10 ثوانٍ لكلٍّ، وأرسل:
  - أسطر `RAW out=` (الجديدة فيها `roiStrat=`)
  - كتلة `model-input thumbnail` مرة عند العين المفتوحة ومرة عند المغلقة.
  - إن كانت الصورة المصغّرة لا تُظهر وجهاً/عيناً واضحة → المشكلة قص/دوران. إن أظهرت عيناً واضحة والـ logits ما زالت ~0 → الموديل نفسه ضعيف (ننتقل لتقييم موديلات PHASE 16).

### 2026-09-01 (جولة 4 — بعد الصورة المصغّرة)
- الصورة المصغّرة تُظهر وجهاً معقولاً داخل القص (fullFace يعمل)، لكن حافة يسار ساطعة (خلفية/إضاءة).
- **الأهم**: بعد إصلاح layout+ROI:
  - عين مفتوحة (جولة 2): open ≈ 57–70% (كان **3%**!) → إصلاح interleaved نجح.
  - عين مغلقة (جولة 4): closed ≈ 55–76% + PERCLOS 100% + ALARM = **سلوك صحيح** للاختبار المغلق.
  - لكن الـ logits الخام ما زالت ضعيفة (±0.5) → الموديل نفسه منخفض الثقة/صغير (65 op).
- إصلاح هذه الجولة:
  - **Temporal smoothing** في `DrowsinessAnalyzer` (debounce: حالة جديدة تحتاج إطارين متتاليين، أو إطاراً واحداً عند ثقة ≥80%). يمنع الوميض من إطار شاذ دون تأخير إنذار حقيقي.
  - `ModelConstants.modelAssetPath` عبر `--dart-define=EYE_MODEL=...` لاختبار الموديلات الثلاثة (يوجد `...114.tflite` و `..._opt_default.tflite` 5.6MB) — PHASE 16.
  - اختبارات: +3 (debounce). 
- **مطلوب — تأكيد نهائي**: أعد الاختبار المضبوط (مفتوح 10s / مغلق 10s) وأرسل **أسطر `RAW out=` فقط** (لا حاجة للصورة المصغّرة). لو الاتجاه صحيح (مفتوح→open، مغلق→closed) نثبّت ونكمل. لو ما زال ضعيفاً جداً: جرّب:
  - `flutter run --dart-define=EYE_MODEL=assets/models/eye_state_model_tensorFlow114.tflite`
  - `flutter run --dart-define=EYE_MODEL=assets/models/eye_state_model_tensorFlow_opt_default.tflite`

### 2026-09-01 (جولة 5 — لوج فيه فقدان الوجه)
- **مؤكَّد أن الـ pipeline يعمل عند وجود ROI صحيح**:
  - عين مغلقة + وجه: `RAW [-0.13, 0.57]` → Closed 66% ✅
  - عين مفتوحة + وجه: Open 57–91% ✅ (ظهرت قراءة 91% عالية الثقة)
  - **الاستشفاء نجح**: `✅ تم استعادة يقظة السائق` بعد فتح العين، والإنذار توقف، و PERCLOS نزل لـ 0.
  - **debounce يعمل**: لا وميض إنذار من إطار مفرد.
- **العطب المكتشف الآن**: ML Kit يفقد الوجه (`faces=0`) لفترات، وعندها القص الاحتياطي = خلفية → الصورة المصغّرة **تدرّج قطري (خلفية)** لا وجه → الموديل يعطي **"Open 65%" افتراضياً للإدخال غير الصالح**. خطر: false negative لسائق نعسان فُقد وجهه لحظياً.
- **Ground truth للموديل**: closed logit يتأرجح من ~‑0.6 (لا عين/مفتوحة) إلى ~+0.5 (مغلقة) — إشارة حقيقية لكن ضعيفة. الموديل يعمل بالكاد.
- إصلاح هذه الجولة:
  - **PHASE 4**: خارج `legacyCenterCrop`، إذا لا يوجد وجه طازج → **لا تصنيف** إطلاقاً؛ يُرسَل `EyeState.unknown` + رسالة "لا يوجد وجه سائق واضح". يوقف قراءات الخلفية الزائفة.
  - padding ~12%/18% لصندوق `fullFace`.
  - اختبارات: 32/32 ✅
- **الموديل ضعيف** — لم يُختبر البديلان بعد. المطلوب من المستخدم:
  1. جرّب `--dart-define=EYE_MODEL=assets/models/eye_state_model_tensorFlow114.tflite` ثم `..._opt_default.tflite`، اختبار مفتوح/مغلق، وأرسل أسطر `RAW out=` لكلٍّ.
  2. **حقّق في فقدان الوجه**: هل كنت تحرّك الهاتف/الوجه خارج الإطار؟ أم يفقده رغم ثبات الوجه؟

### 2026-09-01 (جولة 6 — الموديلات الثلاثة تعطي نفس النتيجة)
- المستخدم: الموديلات الـ3 نتيجتها **متطابقة** (logits ضعيفة ~0). ⇒ **المشكلة في الإدخال لا الموديل**، أو الموديلات الثلاثة كلها ضعيفة/مدرّبة بنفس الطريقة.
- الإشارة موجودة لكن ضعيفة: closed logit من ~‑0.6 (لا عين) إلى ~+0.5 (مغلقة)، Δ≈1.1. مع debounce + عتبات الزمن، الإغلاق المستمر ≥1.2s **يُكتشف** رغم الضعف؛ المشكلة في الرمشات السريعة/الحدود.
- إصلاح/أدوات هذه الجولة:
  - `--dart-define=DETECTION_MODE=java` → يبدأ بمسار Java الأصلي (center crop + planarRgb، بلا ROI من ML Kit) = مسار تدريب الموديل. **اختبار حاسم**: لو هذا أعطى فصلاً قوياً → قص ML Kit عندنا معطوب. لو ضعيف أيضاً → الموديل ضعيف فعلاً.
  - `--dart-define=ROT_OFFSET=90` (أو 180/270) → يضيف للدوران في الـ preprocessing وML Kit معاً، لاختبار فرضية الدوران الخاطئ.
  - اختبارات 32/32 ✅
- **المطلوب من المستخدم — اختباران**:
  1. `flutter run --dart-define=DETECTION_MODE=java` ثم مركّز وجهك، افتح/أغمض، أرسل `RAW out=`.
  2. جرّب `--dart-define=ROT_OFFSET=90` و `=270` (بدون DETECTION_MODE) وقل هل الصورة المصغّرة صارت وجهاً واضحاً منتصباً.
  3. **سؤال مباشر**: في الوضع الحالي — لو جلست بعين مفتوحة 30 ثانية هل يبقى هادئاً؟ ولو أغمضت 3 ثوانٍ هل يُنذر؟ (اللوج السابق يوحي بنعم — الاستشفاء ظهر).

### معلّق (ليس الآن)
- `AudioAlarmService`: خطأ `defaultToSpeaker` بدون `playAndRecord` (iOS AudioContext) — PHASE 10.
- حافة يسار ساطعة في القص — احتمال دوران/إضاءة، يُراجع في PHASE 4/11.
