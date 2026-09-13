import 'package:flutter/material.dart';

/// Supported application language codes.
enum AppLanguage {
  arabic('ar', 'العربية', 'Arabic', '🇮🇶'),
  english('en', 'English', 'English', '🇬🇧'),
  french('fr', 'Français', 'French', '🇫🇷'),
  spanish('es', 'Español', 'Spanish', '🇪🇸'),
  hindi('hi', 'हिन्दी', 'Hindi', '🇮🇳'),
  chinese('zh', '中文', 'Chinese', '🇨🇳'),
  japanese('ja', '日本語', 'Japanese', '🇯🇵');

  final String code;
  final String nativeName;
  final String englishName;
  final String flag;

  const AppLanguage(this.code, this.nativeName, this.englishName, this.flag);

  static AppLanguage fromCode(String code) {
    return AppLanguage.values.firstWhere(
      (lang) => lang.code == code,
      orElse: () => AppLanguage.arabic,
    );
  }
}

/// Comprehensive Localization class supporting Arabic, English, French, and Spanish.
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('ar'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static final Map<String, Map<String, String>> _localizedValues = {
    // ----------------- ARABIC -----------------
    'ar': {
      // UI Components Translations
      'battery_banner_text': 'لرفع موثوقية المراقبة بالخلفية، يمكنك استثناء التطبيق من قيود البطارية.',
      'battery_banner_details': 'تفاصيل',
      'battery_dialog_title': 'استثناء قيود البطارية',
      'battery_dialog_body': 'DriveAlert يحتاج إلى استمرار المراقبة أثناء الرحلة.\n\nقد تقوم قيود البطارية في Android بإيقاف الكاميرا أو المعالجة في الخلفية.\n\nلرفع موثوقية مراقبة السائق، يرجى السماح للتطبيق بالعمل دون قيود البطارية أثناء القيادة.',
      'dialog_later': 'لاحقاً',
      'dialog_oem_settings': 'إعدادات الجهاز',
      'dialog_allow': 'سماح',
      'monitoring_stopped': 'المراقبة متوقفة',
      'alert_banner_wake_up': '🚨 استيقظ فوراً!',
      'alert_banner_wake_up_sub': 'استيقظ فوراً! العينان مغمضتان!',
      'alert_banner_recovering': 'جاري تأكيد استيقاظ السائق...',
      'alert_banner_drowsy': '⚠️ تحذير: علامات نعاس!',
      'alert_banner_watching': 'مراقبة إغلاق العينين...',
      'alert_banner_normal': '● السائق متيقظ - القيادة آمنة',
      'status_inactive': 'غير نشط',
      'status_eyes_open': 'العينان مفتوحتان',
      'status_eyes_closed': 'العينان مغمضتان',
      'status_unknown': 'غير محدد',
      'confidence_label': 'الثقة',
      'perclos_label': 'مؤشر الإجهاد التراكمي (PERCLOS): ',
      'head_nod_label': '⚠️ انحناء رأس',
      'btn_start_monitoring': 'بدء المراقبة',
      'btn_stop_monitoring': 'إيقاف المراقبة',
      'camera_preparing': 'جاري تجهيز الكاميرا...',
      'face_locked': 'تم قفل تتبع وجه السائق',
      'face_searching': 'جاري البحث عن وجه السائق...',
      'power_saver_title': 'وضع توفير الطاقة النشط (OLED Saver)',
      'power_saver_desc': 'معاينة الكاميرا متوقفة لتبريد الهاتف وتوفير البطارية\nالمراقبة بالذكاء الاصطناعي والإنذار يعملان بالخلفية 100%\n(انقر في أي مكان للعودة للمعاينة المباشرة)',
      'btn_show_camera': 'إظهار الكاميرا',
      'btn_power_saver': 'توفير الطاقة',
      'low_light_badge': 'إضاءة خافتة',
      'eye_closed_badge': 'تم غلق العين',
      'eye_open_badge': 'تم فتح العين',
      'eye_checking_badge': 'جاري فحص العين...',
      'hud_driver_awake': 'السائق مستيقظ ويقظ',
      'hud_watching': 'مراقبة حركة العينين...',
      'hud_drowsy': '⚠️ تحذير: علامات نعاس وإجهاد!',
      'hud_recovering': 'جاري تأكيد استيقاظ السائق...',
      'hud_alarm': '🚨 خطر: تم اكتشاف نوم أثناء القيادة!',
      'hud_eye_closed': 'حالة العين: مغمضة',
      'hud_eye_open': 'حالة العين: مفتوحة',
      'hud_perclos_label': 'مؤشر الإجهاد التراكمي (PERCLOS):',
      'hud_exit_tooltip': 'الخروج من وضع HUD',
      'hud_mirror_tooltip': 'عكس الشاشة للزجاج الأمامي',
      'status_starting_monitoring': 'جاري بدء خدمة المراقبة...',
      'status_monitoring_driver': 'جاري مراقبة حالة السائق...',
      'status_start_failed': 'فشل في بدء المراقبة',
      'status_stopped_success': 'تم إيقاف المراقبة بنجاح',
      'status_recovering_monitoring': '🔄 جاري استعادة نظام المراقبة...',
      'thermal_protection_prefix': 'حماية حرارية: تم تخفيض الحمل لتبريد الجهاز',

      // App & Navigation
      'app_title': 'DriveAlert - مراقب يقظة السائق',
      'app_subtitle': 'نظام القيادة الآمنة والذكية',
      'menu': 'القائمة',
      'version': 'الإصدار',
      'monitoring_active': 'المراقبة نشطة ومستقرة',
      'monitoring_inactive': 'جاهز لبدء المراقبة',
      
      // Drawer Items
      'drawer_home': 'شاشة المراقبة الرئيسية',
      'drawer_test_alarm': 'فحص الإنذار الصوتي والاهتزاز',
      'drawer_hud_mode': 'وضع القيادة المظلمة (HUD Mode)',
      'drawer_permissions': 'فحص أذونات التطبيق',
      'drawer_safety_guide': 'إرشادات السلامة وإخلاء المسؤولية',
      'drawer_quick_start': 'دليل البداية السريعة',
      'drawer_settings': 'الإعدادات واللغات',
      
      // Test Alarm
      'alarm_test_snack': 'جاري تشغيل تجربة الإنذار الصوتي والاهتزاز لمدة ثانيتين...',
      
      // Model & System State
      'ai_preparing': 'جاري تجهيز نظام الذكاء الاصطناعي...',
      'ai_ready': 'نظام الذكاء الاصطناعي جاهز',
      'ai_failed': 'تعذر تحميل موديل الذكاء الاصطناعي',
      'camera_init': 'جاري تهيئة الكاميرا...',
      'system_ready_msg': 'تمت التهيئة بنجاح. اضغط على زر البدء لبدء المراقبة.',
      'retry': 'إعادة المحاولة',
      'start_monitoring': 'بدء المراقبة',
      'stop_monitoring': 'إيقاف المراقبة',
      
      // HUD Screen
      'hud_title': 'وضع القيادة المظلمة (HUD)',
      'hud_subtitle': 'شاشة مبسطة عاكسة للزجاج الأمامي',
      
      // Permissions Screen
      'permissions_title': 'أذونات التطبيق والجهاز',
      'permissions_desc': 'يحتاج التطبيق للأذونات التالية لضمان مراقبة دقيقة ومستمرة دون انقطاع أثناء القيادة:',
      'perm_camera_title': 'إذن الكاميرا الأمامية',
      'perm_camera_desc': 'ضروري لرصد حركة العين وملامح الوجه لحظياً على الجهاز لحمايتك من النعاس.',
      'perm_notifications_title': 'إذن الإشعارات',
      'perm_notifications_desc': 'ضروري لعرض خدمة المراقبة المستمرة وإرسال تنبيهات الطوارئ عند تشغيل التطبيق بالخلفية.',
      'perm_battery_title': 'استثناء توفير طاقة البطارية',
      'perm_battery_desc': 'يمنع نظام أندرويد من تجميد أو إيقاف المراقبة عند قفل الشاشة أو استخدام تطبيق الخرائط.',
      'perm_granted': 'ممنوح بنجاح',
      'perm_denied': 'غير ممنوح',
      'perm_restricted': 'مقيد من النظام',
      'perm_request_btn': 'طلب الإذن الآن',
      'perm_settings_btn': 'فتح إعدادات الجهاز',
      'perm_refresh_btn': 'تحديث حالة الأذونات',
      
      // Safety Guidelines Screen
      'safety_title': 'إرشادات السلامة والمسؤولية',
      'safety_how_it_works_title': 'كيف يعمل التطبيق؟',
      'safety_how_it_works_body': 'يستخدم DriveAlert تقنيات الرؤية الحاسوبية والذكاء الاصطناعي على جهازك مباشرة (On-Device Edge AI) لتحليل مؤشرات العين والوجه (مثل معدل انغلاق الجفن PERCLOS وحركات الرأس). جميع العمليات تُنفذ محلياً ولا يتم تصويرك أو تسجيلك أو إرسال أي بيانات إلى خوادم خارجية حفاظاً على خصوصيتك المطلقة.',
      'safety_disclaimer_title': 'إخلاء المسؤولية القانوني',
      'safety_disclaimer_body': 'تطبيق DriveAlert هو أداة مساعدة إلكترونية ثانوية فقط، ولا يمكن اعتباره بديلاً بأي شكل من الأشكال عن اليقظة الذهنية والتركيز الكامل للسائق. السائق يتحمل المسؤولية القانونية والأخلاقية الكاملة عن قيادة المركبة ومراعاة قوانين المرور. لا تتحمل الشركة أو المطورون أي مسؤولية مدنية أو جنائية عن أي حوادث أو أضرار أو غرامات أو خسائر ناتجة عن القيادة تحت تأثير الإرهاق أو الاعتماد الحصري على التطبيق.',
      'safety_rules_title': 'إرشادات ذهبية للقيادة الآمنة',
      'safety_rule_1_title': 'النوم الكافي قبل الانطلاق',
      'safety_rule_1_body': 'احرص على أخذ قسط كافٍ من النوم (7-8 ساعات) قبل السفر لمسافات طويلة، وتجنب السفر بعد يوم عمل شاق.',
      'safety_rule_2_title': 'استراحة كل ساعتين',
      'safety_rule_2_body': 'توقف للاستراحة لمدة 15 إلى 20 دقيقة على الأقل كل ساعتين أو كل 200 كم لتجديد نشاطك وتنشيط دورتك الدموية.',
      'safety_rule_3_title': 'الحذر من ساعات النعاس البيولوجي',
      'safety_rule_3_body': 'تعتبر الفترات بين 2:00 إلى 6:00 صباحاً وفترة ما بعد الظهر هي الأعلى في حوادث النعاس الطبيعي وفق الدراسات العالمية.',
      'safety_rule_4_title': 'علامات الإنذار للتوقف الفوري',
      'safety_rule_4_body': 'إذا شعرت بثقل في الجفون، كثرة التثاؤب، صعوبة تذكر الكيلومترات الأخيرة، أو الانحراف عن المسار، توقف فوراً في مكان آمن وخذ غفوة قصيرة.',
      'safety_rule_5_title': 'تجنب المشتتات والسرعة',
      'safety_rule_5_body': 'لا تستخدم الهاتف المحمول أثناء القيادة، واحرص على الالتزام بالسرعات المقررة وترك مسافة أمان كافية مع المركبات الأخرى.',

      // Settings Screen
      'settings_title': 'الإعدادات وتفضيلات النظام',
      'language_section_title': 'لغة التطبيق (App Language)',
      'language_section_desc': 'اختر اللغة المناسبة لواجهة التطبيق. سيتم تغيير النصوص والاتجاه فوراً:',
      'device_security_title': 'بيئة أمان التطبيق والجهاز',
      'security_status_safe': 'البيئة آمنة وطبيعية',
      'security_status_warning': 'بيئة مشبوهة أو تم اكتشاف صلاحيات Root',
      'privacy_policy_title': 'سياسة الخصوصية وحماية البيانات',
      'privacy_policy_desc': 'يعمل التطبيق بدون اتصال بالإنترنت (Offline First) ولا يقوم برفع أي صور أو إحداثيات لخوادم خارجية.',
      'about_app_title': 'عن التطبيق',
      'about_app_body': 'DriveAlert هو نظام ذكي مصمم للمساعدة في الحد من حوادث السير الناجمة عن النعاس وتشتت السائق عبر تحليل التعابير المباشرة محلياً.',
    },

    // ----------------- ENGLISH -----------------
    'en': {
      // UI Components Translations
      'battery_banner_text': 'To improve background monitoring reliability, you can exclude the app from battery restrictions.',
      'battery_banner_details': 'Details',
      'battery_dialog_title': 'Battery Restrictions Exemption',
      'battery_dialog_body': 'DriveAlert needs continuous monitoring during your drive.\n\nBattery restrictions may stop the camera or background processing.\n\nTo ensure reliable driver protection, please allow the app to run unrestricted.',
      'dialog_later': 'Later',
      'dialog_oem_settings': 'Device Settings',
      'dialog_allow': 'Allow',
      'monitoring_stopped': 'Monitoring Paused',
      'alert_banner_wake_up': '🚨 WAKE UP!',
      'alert_banner_wake_up_sub': 'Wake up immediately! Eyes closed!',
      'alert_banner_recovering': 'Confirming driver alertness...',
      'alert_banner_drowsy': '⚠️ Warning: Drowsiness detected!',
      'alert_banner_watching': 'Monitoring eye closure...',
      'alert_banner_normal': '● Driver Alert - Driving Safe',
      'status_inactive': 'Inactive',
      'status_eyes_open': 'Eyes Open',
      'status_eyes_closed': 'Eyes Closed',
      'status_unknown': 'Unknown',
      'confidence_label': 'Confidence',
      'perclos_label': 'Cumulative Fatigue (PERCLOS): ',
      'head_nod_label': '⚠️ Head Nod',
      'btn_start_monitoring': 'Start Monitoring',
      'btn_stop_monitoring': 'Stop Monitoring',
      'camera_preparing': 'Preparing camera...',
      'face_locked': 'Driver Face Locked',
      'face_searching': 'Searching for driver face...',
      'power_saver_title': 'Power Saver Active (OLED Saver)',
      'power_saver_desc': 'Camera preview is paused to cool phone and save battery\nAI monitoring and alerts are 100% active in background\n(Tap anywhere to return to live preview)',
      'btn_show_camera': 'Show Camera',
      'btn_power_saver': 'Power Saver',
      'low_light_badge': 'Low Light',
      'eye_closed_badge': 'Eye Closed',
      'eye_open_badge': 'Eye Open',
      'eye_checking_badge': 'Checking eyes...',
      'hud_driver_awake': 'Driver is Awake & Alert',
      'hud_watching': 'Watching eye movement...',
      'hud_drowsy': '⚠️ Warning: Drowsiness & Fatigue!',
      'hud_recovering': 'Confirming driver alertness...',
      'hud_alarm': '🚨 DANGER: SLEEP DETECTED WHILE DRIVING!',
      'hud_eye_closed': 'Eye State: Closed',
      'hud_eye_open': 'Eye State: Open',
      'hud_perclos_label': 'Cumulative Fatigue (PERCLOS):',
      'hud_exit_tooltip': 'Exit HUD Mode',
      'hud_mirror_tooltip': 'Mirror for Windshield',
      'status_starting_monitoring': 'Starting monitoring service...',
      'status_monitoring_driver': 'Monitoring driver state...',
      'status_start_failed': 'Failed to start monitoring',
      'status_stopped_success': 'Monitoring stopped successfully',
      'status_recovering_monitoring': '🔄 Recovering monitoring system...',
      'thermal_protection_prefix': 'Thermal protection: Non-essential load reduced to cool device',

      // App & Navigation
      'app_title': 'DriveAlert - Driver Drowsiness Monitor',
      'app_subtitle': 'Smart & Safe Driving System',
      'menu': 'Menu',
      'version': 'Version',
      'monitoring_active': 'Monitoring active & stable',
      'monitoring_inactive': 'Ready to start monitoring',
      
      // Drawer Items
      'drawer_home': 'Main Monitor Screen',
      'drawer_test_alarm': 'Test Audio Alarm & Haptics',
      'drawer_hud_mode': 'Night Driving HUD Mode',
      'drawer_permissions': 'App Permissions Status',
      'drawer_safety_guide': 'Safety Guide & Disclaimer',
      'drawer_quick_start': 'Quick Start Guide',
      'drawer_settings': 'Settings & Languages',
      
      // Test Alarm
      'alarm_test_snack': 'Testing audio alarm and haptic vibration for 2 seconds...',
      
      // Model & System State
      'ai_preparing': 'Preparing AI model...',
      'ai_ready': 'AI engine is ready',
      'ai_failed': 'Failed to load AI model',
      'camera_init': 'Initializing camera...',
      'system_ready_msg': 'System initialized. Press Start to begin monitoring.',
      'retry': 'Retry',
      'start_monitoring': 'Start Monitoring',
      'stop_monitoring': 'Stop Monitoring',
      
      // HUD Screen
      'hud_title': 'Head-Up Display (HUD Mode)',
      'hud_subtitle': 'Minimalist windshield reflective display',
      
      // Permissions Screen
      'permissions_title': 'App & Device Permissions',
      'permissions_desc': 'DriveAlert requires the following permissions to ensure continuous and reliable monitoring while driving:',
      'perm_camera_title': 'Front Camera Permission',
      'perm_camera_desc': 'Required for real-time local eye and face analysis to protect you against microsleep and drowsiness.',
      'perm_notifications_title': 'Notification Permission',
      'perm_notifications_desc': 'Required to maintain the foreground monitoring service and broadcast alerts when running in the background.',
      'perm_battery_title': 'Battery Optimization Exemption',
      'perm_battery_desc': 'Prevents Android system from freezing or killing monitoring when the screen locks or navigation apps are open.',
      'perm_granted': 'Granted',
      'perm_denied': 'Not Granted',
      'perm_restricted': 'System Restricted',
      'perm_request_btn': 'Grant Permission',
      'perm_settings_btn': 'Open System Settings',
      'perm_refresh_btn': 'Refresh Permissions Status',
      
      // Safety Guidelines Screen
      'safety_title': 'Safety Guidelines & Legal Disclaimer',
      'safety_how_it_works_title': 'How It Works',
      'safety_how_it_works_body': 'DriveAlert uses cutting-edge computer vision directly on your device (Edge AI) to analyze eye patterns (PERCLOS eyelid closure and head nodding). All processing is 100% on-device. No photos or video streams are ever stored or uploaded to any cloud server, preserving your absolute privacy.',
      'safety_disclaimer_title': 'Legal Liability Disclaimer',
      'safety_disclaimer_body': 'DriveAlert is strictly a secondary driving assistance tool and under no circumstances replaces driver alertness, attentiveness, and judgment. The driver retains sole legal responsibility for safe vehicle operation and adherence to traffic regulations. The developers and publishers accept no liability for any accidents, injuries, damages, or fines resulting from driver fatigue or reliance on this application.',
      'safety_rules_title': 'Essential Safe Driving Guidelines',
      'safety_rule_1_title': 'Adequate Sleep Before Driving',
      'safety_rule_1_body': 'Ensure 7 to 8 hours of restorative sleep before long highway trips. Never drive after an exhausting workday.',
      'safety_rule_2_title': 'Rest Every 2 Hours',
      'safety_rule_2_body': 'Stop for a 15–20 minute rest break every 2 hours or every 200 km to stretch, hydrate, and restore alertness.',
      'safety_rule_3_title': 'Watch Out for Biological Drowsiness Hours',
      'safety_rule_3_body': 'The hours between 2:00 AM – 6:00 AM and mid-afternoon have the highest statistical incidence of sleep-related crashes.',
      'safety_rule_4_title': 'Immediate Fatigue Warning Signs',
      'safety_rule_4_body': 'Heavy eyelids, frequent yawning, missing exits, or drifting out of lane demand an immediate stop in a safe area for a power nap.',
      'safety_rule_5_title': 'Eliminate Distractions & Respect Speed',
      'safety_rule_5_body': 'Never use your smartphone while driving. Maintain legal speeds and safe following distances at all times.',

      // Settings Screen
      'settings_title': 'Settings & System Preferences',
      'language_section_title': 'Application Language',
      'language_section_desc': 'Select your preferred language. Interface text and layout orientation will adapt immediately:',
      'device_security_title': 'Device Security Environment',
      'security_status_safe': 'Environment is secure and verified',
      'security_status_warning': 'Elevated risk or root environment detected',
      'privacy_policy_title': 'Privacy Policy & Zero Cloud Footprint',
      'privacy_policy_desc': 'DriveAlert operates offline-first and never sends camera images or telemetry to external servers.',
      'about_app_title': 'About DriveAlert',
      'about_app_body': 'DriveAlert is an advanced safety assistant designed to reduce traffic accidents caused by fatigue and distracted driving through local neural networks.',
    },

    // ----------------- FRENCH -----------------
    'fr': {
      // UI Components Translations
      'battery_banner_text': 'Pour améliorer la surveillance en arrière-plan, vous pouvez exclure l\'application des restrictions de batterie.',
      'battery_banner_details': 'Détails',
      'battery_dialog_title': 'Exemption des Restrictions de Batterie',
      'battery_dialog_body': 'DriveAlert nécessite une surveillance continue pendant le trajet.\n\nLes restrictions de batterie peuvent couper la caméra en arrière-plan.\n\nVeuillez autoriser l\'exécution sans restriction de batterie.',
      'dialog_later': 'Plus tard',
      'dialog_oem_settings': 'Paramètres Système',
      'dialog_allow': 'Autoriser',
      'monitoring_stopped': 'Surveillance Suspendue',
      'alert_banner_wake_up': '🚨 RÉVEILLEZ-VOUS !',
      'alert_banner_wake_up_sub': 'Réveillez-vous immédiatement ! Yeux fermés !',
      'alert_banner_recovering': 'Confirmation de la vigilance...',
      'alert_banner_drowsy': '⚠️ Attention : Signes de somnolence !',
      'alert_banner_watching': 'Surveillance des yeux...',
      'alert_banner_normal': '● Conducteur Vigilant - Conduite Sûre',
      'status_inactive': 'Inactif',
      'status_eyes_open': 'Yeux Ouverts',
      'status_eyes_closed': 'Yeux Fermés',
      'status_unknown': 'Inconnu',
      'confidence_label': 'Confiance',
      'perclos_label': 'Indice de Fatigue (PERCLOS) : ',
      'head_nod_label': '⚠️ Tête Inclinée',
      'btn_start_monitoring': 'Démarrer la Surveillance',
      'btn_stop_monitoring': 'Arrêter la Surveillance',
      'camera_preparing': 'Préparation de la caméra...',
      'face_locked': 'Visage du Conducteur Capturé',
      'face_searching': 'Recherche du visage...',
      'power_saver_title': 'Économiseur d\'Énergie Actif (OLED)',
      'power_saver_desc': 'Aperçu caméra en pause pour refroidir l\'appareil\nSurveillance IA active à 100% en arrière-plan\n(Touchez l\'écran pour réactiver l\'aperçu)',
      'btn_show_camera': 'Afficher Caméra',
      'btn_power_saver': 'Économiseur',
      'low_light_badge': 'Faible Éclairage',
      'eye_closed_badge': 'Œil Fermé',
      'eye_open_badge': 'Œil Ouvert',
      'eye_checking_badge': 'Examen des yeux...',
      'hud_driver_awake': 'Conducteur Éveillé et Vigilant',
      'hud_watching': 'Surveillance du regard...',
      'hud_drowsy': '⚠️ Attention : Signes de Fatigue !',
      'hud_recovering': 'Confirmation de la vigilance...',
      'hud_alarm': '🚨 DANGER : SOMMEIL DÉTECTÉ AU VOLANT !',
      'hud_eye_closed': 'État de l\'œil : Fermé',
      'hud_eye_open': 'État de l\'œil : Ouvert',
      'hud_perclos_label': 'Indice de Fatigue (PERCLOS) :',
      'hud_exit_tooltip': 'Quitter le Mode HUD',
      'hud_mirror_tooltip': 'Miroir Pare-brise',
      'status_starting_monitoring': 'Démarrage du service de surveillance...',
      'status_monitoring_driver': 'Surveillance du conducteur en cours...',
      'status_start_failed': 'Échec du démarrage de la surveillance',
      'status_stopped_success': 'Surveillance arrêtée avec succès',
      'status_recovering_monitoring': '🔄 Restauration du système de surveillance...',
      'thermal_protection_prefix': 'Protection thermique : Charge réduite pour refroidir',

      // App & Navigation
      'app_title': 'DriveAlert - Détecteur de Somnolence',
      'app_subtitle': 'Système de Conduite Intelligente et Sûre',
      'menu': 'Menu',
      'version': 'Version',
      'monitoring_active': 'Surveillance active et stable',
      'monitoring_inactive': 'Prêt à démarrer la surveillance',
      
      // Drawer Items
      'drawer_home': 'Écran Principal de Surveillance',
      'drawer_test_alarm': 'Tester l\'Alarme Sonore et Vibration',
      'drawer_hud_mode': 'Mode Nuit Tête Haute (HUD)',
      'drawer_permissions': 'Statut des Autorisations',
      'drawer_safety_guide': 'Conseils de Sécurité et Mentions Légales',
      'drawer_quick_start': 'Guide de Démarrage Rapide',
      'drawer_settings': 'Paramètres et Langues',
      
      // Test Alarm
      'alarm_test_snack': 'Test de l\'alarme sonore et vibration pendant 2 secondes...',
      
      // Model & System State
      'ai_preparing': 'Préparation du modèle IA...',
      'ai_ready': 'Moteur IA prêt',
      'ai_failed': 'Échec du chargement du modèle IA',
      'camera_init': 'Initialisation de la caméra...',
      'system_ready_msg': 'Système prêt. Appuyez sur Démarrer pour commencer.',
      'retry': 'Réessayer',
      'start_monitoring': 'Démarrer la Surveillance',
      'stop_monitoring': 'Arrêter la Surveillance',
      
      // HUD Screen
      'hud_title': 'Affichage Tête Haute (Mode HUD)',
      'hud_subtitle': 'Écran réfléchissant minimaliste pour pare-brise',
      
      // Permissions Screen
      'permissions_title': 'Autorisations de l\'Appareil',
      'permissions_desc': 'DriveAlert requiert les autorisations suivantes pour assurer une surveillance ininterrompue :',
      'perm_camera_title': 'Autorisation Caméra Frontale',
      'perm_camera_desc': 'Indispensable pour l\'analyse faciale et oculaire locale afin de prévenir la somnolence.',
      'perm_notifications_title': 'Autorisation de Notifications',
      'perm_notifications_desc': 'Nécessaire pour maintenir le service actif et émettre des alertes en arrière-plan.',
      'perm_battery_title': 'Exemption d\'Optimisation Batterie',
      'perm_battery_desc': 'Empêche le système Android de geler l\'application lorsque l\'écran est verrouillé.',
      'perm_granted': 'Accordée',
      'perm_denied': 'Non Accordée',
      'perm_restricted': 'Restreinte par le Système',
      'perm_request_btn': 'Accorder l\'Autorisation',
      'perm_settings_btn': 'Ouvrir les Paramètres Système',
      'perm_refresh_btn': 'Actualiser le Statut',
      
      // Safety Guidelines Screen
      'safety_title': 'Conseils de Sécurité et Responsabilité',
      'safety_how_it_works_title': 'Comment ça fonctionne ?',
      'safety_how_it_works_body': 'DriveAlert utilise la vision par ordinateur directement sur votre appareil (Edge AI). Aucun flux vidéo n\'est jamais envoyé vers le cloud, garantissant votre confidentialité absolue.',
      'safety_disclaimer_title': 'Avis de Non-Responsabilité Légale',
      'safety_disclaimer_body': 'DriveAlert est un outil d\'assistance secondaire et ne remplace en aucun cas la vigilance du conducteur. Le conducteur demeure seul responsable de sa conduite et du respect du code de la route.',
      'safety_rules_title': 'Règles d\'Or pour une Conduite Sûre',
      'safety_rule_1_title': 'Sommeil Suffisant Avant de Partir',
      'safety_rule_1_body': 'Dormez 7 à 8 heures avant les longs trajets. Ne conduisez jamais après une journée épuisante.',
      'safety_rule_2_title': 'Pause Toutes les 2 Heures',
      'safety_rule_2_body': 'Arrêtez-vous au moins 15 à 20 minutes toutes les 2 heures ou 200 km pour vous détendre et vous hydrater.',
      'safety_rule_3_title': 'Heures Biologiques à Risque',
      'safety_rule_3_body': 'Les plages de 2h00 à 6h00 du matin et le début d\'après-midi présentent le risque statistique le plus élevé d\'endormissement.',
      'safety_rule_4_title': 'Signes d\'Alerte Immédiats',
      'safety_rule_4_body': 'Paupières lourdes, bâillements répétés ou déviation de trajectoire imposent un arrêt immédiat pour faire une sieste.',
      'safety_rule_5_title': 'Évitez les Distractions et Respectez la Vitesse',
      'safety_rule_5_body': 'N\'utilisez jamais votre téléphone au volant et respectez les distances de sécurité.',

      // Settings Screen
      'settings_title': 'Paramètres et Préférences',
      'language_section_title': 'Langue de l\'Application',
      'language_section_desc': 'Sélectionnez votre langue préférée. L\'interface s\'adaptera instantanément :',
      'device_security_title': 'Sécurité de l\'Environnement',
      'security_status_safe': 'Environnement sécurisé et vérifié',
      'security_status_warning': 'Risque détecté ou appareil rooté',
      'privacy_policy_title': 'Confidentialité et Respect de la Vie Privée',
      'privacy_policy_desc': 'DriveAlert fonctionne 100% hors ligne et ne transmet aucune image vers des serveurs.',
      'about_app_title': 'À Propos de DriveAlert',
      'about_app_body': 'DriveAlert est un assistant intelligent conçu pour prévenir les accidents causés par la fatigue au volant.',
    },

    // ----------------- SPANISH -----------------
    'es': {
      // UI Components Translations
      'battery_banner_text': 'Para mejorar la fiabilidad en segundo plano, puede excluir la app de restricciones de batería.',
      'battery_banner_details': 'Detalles',
      'battery_dialog_title': 'Exención de Restricciones de Batería',
      'battery_dialog_body': 'DriveAlert necesita monitoreo continuo durante el viaje.\n\nLas restricciones de batería pueden suspender la cámara en segundo plano.\n\nPermita que la app funcione sin restricciones de batería.',
      'dialog_later': 'Más tarde',
      'dialog_oem_settings': 'Ajustes del Dispositivo',
      'dialog_allow': 'Permitir',
      'monitoring_stopped': 'Monitoreo Detenido',
      'alert_banner_wake_up': '🚨 ¡DESPIERTE!',
      'alert_banner_wake_up_sub': '¡Despierte de inmediato! ¡Ojos cerrados!',
      'alert_banner_recovering': 'Confirmando alerta del conductor...',
      'alert_banner_drowsy': '⚠️ Advertencia: ¡Signos de somnolencia!',
      'alert_banner_watching': 'Monitoreando cierre de ojos...',
      'alert_banner_normal': '● Conductor Alerta - Conducción Segura',
      'status_inactive': 'Inactivo',
      'status_eyes_open': 'Ojos Abiertos',
      'status_eyes_closed': 'Ojos Cerrados',
      'status_unknown': 'Desconocido',
      'confidence_label': 'Confianza',
      'perclos_label': 'Índice de Fatiga (PERCLOS): ',
      'head_nod_label': '⚠️ Cabeceo',
      'btn_start_monitoring': 'Iniciar Monitoreo',
      'btn_stop_monitoring': 'Detener Monitoreo',
      'camera_preparing': 'Preparando cámara...',
      'face_locked': 'Rostro del Conductor Bloqueado',
      'face_searching': 'Buscando rostro del conductor...',
      'power_saver_title': 'Ahorro de Energía Activo (OLED)',
      'power_saver_desc': 'Vista previa pausada para enfriar el dispositivo\nMonitoreo de IA y alarmas 100% activos en segundo plano\n(Toque en cualquier parte para volver)',
      'btn_show_camera': 'Mostrar Cámara',
      'btn_power_saver': 'Ahorro Energía',
      'low_light_badge': 'Poca Luz',
      'eye_closed_badge': 'Ojo Cerrado',
      'eye_open_badge': 'Ojo Abierto',
      'eye_checking_badge': 'Comprobando ojos...',
      'hud_driver_awake': 'Conductor Despierto y Alerta',
      'hud_watching': 'Monitoreando mirada...',
      'hud_drowsy': '⚠️ ¡Advertencia: Fatiga y Sueño!',
      'hud_recovering': 'Confirmando alerta del conductor...',
      'hud_alarm': '🚨 ¡PELIGRO: SUEÑO DETECTADO AL VOLANTE!',
      'hud_eye_closed': 'Estado del ojo: Cerrado',
      'hud_eye_open': 'Estado del ojo: Abierto',
      'hud_perclos_label': 'Índice de Fatiga (PERCLOS):',
      'hud_exit_tooltip': 'Salir de Modo HUD',
      'hud_mirror_tooltip': 'Reflejar en Parabrisas',
      'status_starting_monitoring': 'Iniciando servicio de monitoreo...',
      'status_monitoring_driver': 'Monitoreando estado del conductor...',
      'status_start_failed': 'Error al iniciar monitoreo',
      'status_stopped_success': 'Monitoreo detenido con éxito',
      'status_recovering_monitoring': '🔄 Restaurando sistema de monitoreo...',
      'thermal_protection_prefix': 'Protección térmica: Carga reducida para enfriar equipo',

      // App & Navigation
      'app_title': 'DriveAlert - Monitor de Somnolencia',
      'app_subtitle': 'Sistema de Conducción Segura e Inteligente',
      'menu': 'Menú',
      'version': 'Versión',
      'monitoring_active': 'Monitoreo activo y estable',
      'monitoring_inactive': 'Listo para iniciar monitoreo',
      
      // Drawer Items
      'drawer_home': 'Pantalla Principal',
      'drawer_test_alarm': 'Probar Alarma Sonora y Vibración',
      'drawer_hud_mode': 'Modo Nocturno HUD',
      'drawer_permissions': 'Estado de Permisos',
      'drawer_safety_guide': 'Guía de Seguridad y Descargo Legal',
      'drawer_quick_start': 'Guía de Inicio Rápido',
      'drawer_settings': 'Ajustes e Idiomas',
      
      // Test Alarm
      'alarm_test_snack': 'Probando alarma sonora y vibración por 2 segundos...',
      
      // Model & System State
      'ai_preparing': 'Preparando modelo de IA...',
      'ai_ready': 'Motor de IA listo',
      'ai_failed': 'Error al cargar el modelo de IA',
      'camera_init': 'Inicializando cámara...',
      'system_ready_msg': 'Sistema listo. Presione Iniciar para comenzar el monitoreo.',
      'retry': 'Reintentar',
      'start_monitoring': 'Iniciar Monitoreo',
      'stop_monitoring': 'Detener Monitoreo',
      
      // HUD Screen
      'hud_title': 'Pantalla HUD (Head-Up Display)',
      'hud_subtitle': 'Visualización reflectante minimalista para parabrisas',
      
      // Permissions Screen
      'permissions_title': 'Permisos de la Aplicación',
      'permissions_desc': 'DriveAlert requiere los siguientes permisos para garantizar un monitoreo ininterrumpido:',
      'perm_camera_title': 'Permiso de Cámara Frontal',
      'perm_camera_desc': 'Necesario para el análisis facial y ocular en tiempo real para prevenir la somnolencia.',
      'perm_notifications_title': 'Permiso de Notificaciones',
      'perm_notifications_desc': 'Necesario para mantener el servicio activo y emitir alertas en segundo plano.',
      'perm_battery_title': 'Exención de Optimización de Batería',
      'perm_battery_desc': 'Evita que el sistema Android congele el monitoreo cuando la pantalla se bloquea.',
      'perm_granted': 'Concedido',
      'perm_denied': 'No Concedido',
      'perm_restricted': 'Restringido por Sistema',
      'perm_request_btn': 'Solicitar Permiso',
      'perm_settings_btn': 'Abrir Ajustes del Dispositivo',
      'perm_refresh_btn': 'Actualizar Permisos',
      
      // Safety Guidelines Screen
      'safety_title': 'Guía de Seguridad y Responsabilidad',
      'safety_how_it_works_title': '¿Cómo funciona?',
      'safety_how_it_works_body': 'DriveAlert utiliza visión artificial directamente en su dispositivo (Edge AI). Ninguna imagen o video se almacena ni se envía a la nube, protegiendo su privacidad total.',
      'safety_disclaimer_title': 'Descargo de Responsabilidad Legal',
      'safety_disclaimer_body': 'DriveAlert es una herramienta auxiliar y bajo ninguna circunstancia reemplaza la atención y responsabilidad del conductor. El conductor es el único responsable legal del control seguro del vehículo.',
      'safety_rules_title': 'Reglas de Oro para una Conducción Segura',
      'safety_rule_1_title': 'Sueño Suficiente Antes de Conducir',
      'safety_rule_1_body': 'Duerma de 7 a 8 horas antes de viajes largos. Nunca conduzca después de una jornada agotadora.',
      'safety_rule_2_title': 'Descanse Cada 2 Horas',
      'safety_rule_2_body': 'Deténgase al menos 15 a 20 minutos cada 2 horas o cada 200 km para estirarse e hidratarse.',
      'safety_rule_3_title': 'Horas Biológicas Críticas',
      'safety_rule_3_body': 'El periodo entre las 2:00 y las 6:00 de la madrugada y las primeras horas de la tarde presentan el mayor riesgo de somnolencia.',
      'safety_rule_4_title': 'Señales de Alerta Inmediata',
      'safety_rule_4_body': 'Párpados pesados, bostezos frecuentes o salirse del carril exigen detenerse de inmediato en un lugar seguro.',
      'safety_rule_5_title': 'Sin Distracciones y Velocidad Adecuada',
      'safety_rule_5_body': 'Nunca use su teléfono móvil al volante y respete los límites de velocidad y distancia de seguridad.',

      // Settings Screen
      'settings_title': 'Ajustes y Preferencias',
      'language_section_title': 'Idioma de la Aplicación',
      'language_section_desc': 'Seleccione su idioma preferido. La interfaz y orientación se adaptarán de inmediato:',
      'device_security_title': 'Seguridad del Dispositivo',
      'security_status_safe': 'Entorno seguro y verificado',
      'security_status_warning': 'Riesgo detectado o dispositivo rooteado',
      'privacy_policy_title': 'Privacidad y Cero Envío a la Nube',
      'privacy_policy_desc': 'DriveAlert funciona 100% sin conexión y no transmite imágenes a servidores externos.',
      'about_app_title': 'Acerca de DriveAlert',
      'about_app_body': 'DriveAlert es un asistente inteligente diseñado para reducir accidentes provocados por el cansancio al volante.',
    },

    // ----------------- HINDI -----------------
    'hi': {
      // UI Components Translations
      'battery_banner_text': 'बैकग्राउंड में निर्बाध निगरानी के लिए, आप ऐप को बैटरी प्रतिबंधों से मुक्त कर सकते हैं।',
      'battery_banner_details': 'विवरण',
      'battery_dialog_title': 'बैटरी प्रतिबंध छूट',
      'battery_dialog_body': 'ड्राइविंग के दौरान DriveAlert को निरंतर निगरानी की आवश्यकता होती है।\n\nबैटरी प्रतिबंध बैकग्राउंड में कैमरा रोक सकते हैं।\n\nविश्वसनीय सुरक्षा के लिए, कृपया ऐप को बिना बैटरी प्रतिबंध चलने की अनुमति दें।',
      'dialog_later': 'बाद में',
      'dialog_oem_settings': 'डिवाइस सेटिंग्स',
      'dialog_allow': 'अनुमति दें',
      'monitoring_stopped': 'निगरानी रुकी हुई है',
      'alert_banner_wake_up': '🚨 तुरंत जागें!',
      'alert_banner_wake_up_sub': 'तुरंत जागें! आँखें बंद हैं!',
      'alert_banner_recovering': 'ड्राइवर की सतर्कता की पुष्टि हो रही है...',
      'alert_banner_drowsy': '⚠️ चेतावनी: उनींदापन के लक्षण!',
      'alert_banner_watching': 'आँखें बंद होने की निगरानी...',
      'alert_banner_normal': '● ड्राइवर सतर्क है - ड्राइविंग सुरक्षित है',
      'status_inactive': 'निष्क्रिय',
      'status_eyes_open': 'आँखें खुली हैं',
      'status_eyes_closed': 'आँखें बंद हैं',
      'status_unknown': 'अज्ञात',
      'confidence_label': 'विश्वसनीयता',
      'perclos_label': 'थकान सूचकांक (PERCLOS): ',
      'head_nod_label': '⚠️ सिर झुकना',
      'btn_start_monitoring': 'निगरानी प्रारंभ करें',
      'btn_stop_monitoring': 'निगरानी रोकें',
      'camera_preparing': 'कैमरा तैयार किया जा रहा है...',
      'face_locked': 'ड्राइवर का चेहरा ट्रैक हुआ',
      'face_searching': 'ड्राइवर का चेहरा खोजा जा रहा है...',
      'power_saver_title': 'पावर सेवर सक्रिय (OLED Saver)',
      'power_saver_desc': 'फोन ठंडा रखने और बैटरी बचाने के लिए कैमरा पूर्वावलोकन बंद है\nAI निगरानी और अलार्म 100% बैकग्राउंड में सक्रिय हैं\n(पूर्वावलोकन के लिए कहीं भी टैप करें)',
      'btn_show_camera': 'कैमरा दिखाएं',
      'btn_power_saver': 'पावर सेवर',
      'low_light_badge': 'कम रोशनी',
      'eye_closed_badge': 'आँख बंद है',
      'eye_open_badge': 'आँख खुली है',
      'eye_checking_badge': 'आँखों की जाँच हो रही है...',
      'hud_driver_awake': 'ड्राइवर जागृत और सतर्क है',
      'hud_watching': 'आँखों की गतिविधियों की निगरानी...',
      'hud_drowsy': '⚠️ चेतावनी: उनींदापन और थकान!',
      'hud_recovering': 'सतर्कता की पुष्टि हो रही है...',
      'hud_alarm': '🚨 खतरा: ड्राइविंग के दौरान नींद का पता चला!',
      'hud_eye_closed': 'आँख की स्थिति: बंद',
      'hud_eye_open': 'आँख की स्थिति: खुली',
      'hud_perclos_label': 'थकान सूचकांक (PERCLOS):',
      'hud_exit_tooltip': 'HUD मोड से बाहर निकलें',
      'hud_mirror_tooltip': 'विंडशील्ड के लिए मिरर करें',
      'status_starting_monitoring': 'निगरानी सेवा शुरू हो रही है...',
      'status_monitoring_driver': 'ड्राइवर की निगरानी जारी है...',
      'status_start_failed': 'निगरानी शुरू करने में विफल',
      'status_stopped_success': 'निगरानी सफलतापूर्वक रोक दी गई',
      'status_recovering_monitoring': '🔄 निगरानी प्रणाली बहाल की जा रही है...',
      'thermal_protection_prefix': 'थर्मल सुरक्षा: फोन ठंडा करने के लिए लोड कम किया गया',

      // App & Navigation
      'app_title': 'DriveAlert - ड्राइवर उनींदापन मॉनिटर',
      'app_subtitle': 'सुरक्षित और स्मार्ट ड्राइविंग सिस्टम',
      'menu': 'मेनू',
      'version': 'संस्करण',
      'monitoring_active': 'निगरानी सक्रिय और स्थिर है',
      'monitoring_inactive': 'निगरानी शुरू करने के लिए तैयार',
      
      // Drawer Items
      'drawer_home': 'मुख्य मॉनिटर स्क्रीन',
      'drawer_test_alarm': 'ऑडियो अलार्म और कंपन का परीक्षण करें',
      'drawer_hud_mode': 'नाइट ड्राइविंग HUD मोड',
      'drawer_permissions': 'ऐप अनुमतियों की स्थिति',
      'drawer_safety_guide': 'सुरक्षा दिशानिर्देश और अस्वीकरण',
      'drawer_quick_start': 'त्वरित आरंभ मार्गदर्शिका',
      'drawer_settings': 'सेटिंग्स और भाषाएँ',
      
      // Test Alarm
      'alarm_test_snack': '2 सेकंड के लिए ऑडियो अलार्म और कंपन का परीक्षण...',
      
      // Model & System State
      'ai_preparing': 'AI मॉडल तैयार किया जा रहा है...',
      'ai_ready': 'AI इंजन तैयार है',
      'ai_failed': 'AI मॉडल लोड करने में विफल',
      'camera_init': 'कैमरा प्रारंभ किया जा रहा है...',
      'system_ready_msg': 'सिस्टम प्रारंभ हुआ। निगरानी शुरू करने के लिए स्टार्ट दबाएं।',
      'retry': 'पुनः प्रयास करें',
      'start_monitoring': 'निगरानी प्रारंभ करें',
      'stop_monitoring': 'निगरानी रोकें',
      
      // HUD Screen
      'hud_title': 'हेड-अप डिस्प्ले (HUD मोड)',
      'hud_subtitle': 'विंडशील्ड परावर्तक डिस्प्ले',
      
      // Permissions Screen
      'permissions_title': 'ऐप और डिवाइस अनुमतियाँ',
      'permissions_desc': 'ड्राइविंग के दौरान निरंतर निगरानी सुनिश्चित करने के लिए DriveAlert को निम्नलिखित अनुमतियों की आवश्यकता है:',
      'perm_camera_title': 'फ्रंट कैमरा अनुमति',
      'perm_camera_desc': 'उनींदापन और झपकी से बचाने के लिए रीयल-टाइम स्थानीय आंख और चेहरे के विश्लेषण के लिए आवश्यक।',
      'perm_notifications_title': 'सूचना अनुमति',
      'perm_notifications_desc': 'बैकग्राउंड में चलने पर अलर्ट प्रसारित करने और सेवा बनाए रखने के लिए आवश्यक।',
      'perm_battery_title': 'बैटरी अनुकूलन छूट',
      'perm_battery_desc': 'स्क्रीन लॉक होने पर एंड्रॉइड सिस्टम को निगरानी रोकने से रोकता है।',
      'perm_granted': 'अनुमति स्वीकृत',
      'perm_denied': 'अस्वीकृत',
      'perm_restricted': 'सिस्टम द्वारा प्रतिबंधित',
      'perm_request_btn': 'अनुमति दें',
      'perm_settings_btn': 'डिवाइस सेटिंग्स खोलें',
      'perm_refresh_btn': 'अनुमति स्थिति ताज़ा करें',
      
      // Safety Guidelines Screen
      'safety_title': 'सुरक्षा दिशानिर्देश और कानूनी अस्वीकरण',
      'safety_how_it_works_title': 'यह कैसे काम करता है?',
      'safety_how_it_works_body': 'DriveAlert सीधे आपके डिवाइस पर कंप्यूटर विज़न (Edge AI) का उपयोग करता है। आपकी पूर्ण गोपनीयता की रक्षा के लिए कोई भी फोटो या वीडियो क्लाउड पर संग्रहीत या अपलोड नहीं किया जाता है।',
      'safety_disclaimer_title': 'कानूनी दायित्व अस्वीकरण',
      'safety_disclaimer_body': 'DriveAlert केवल एक माध्यमिक ड्राइविंग सहायता उपकरण है और किसी भी परिस्थिति में ड्राइवर की सतर्कता की जगह नहीं लेता है। ड्राइवर वाहन संचालन के लिए पूरी तरह से कानूनी रूप से जिम्मेदार है।',
      'safety_rules_title': 'सुरक्षित ड्राइविंग के आवश्यक नियम',
      'safety_rule_1_title': 'ड्राइविंग से पहले पर्याप्त नींद',
      'safety_rule_1_body': 'लंबी यात्रा से पहले 7 से 8 घंटे की नींद लें। थकाऊ कार्यदिवस के बाद कभी गाड़ी न चलाएं।',
      'safety_rule_2_title': 'हर 2 घंटे में आराम करें',
      'safety_rule_2_body': 'सक्रियता बनाए रखने के लिए हर 2 घंटे या 200 किमी पर कम से कम 15-20 मिनट का ब्रेक लें।',
      'safety_rule_3_title': 'जैविक उनींदापन के घंटों से सावधान रहें',
      'safety_rule_3_body': 'सुबह 2:00 से 6:00 बजे और दोपहर के समय नींद से संबंधित दुर्घटनाओं का जोखिम सबसे अधिक होता है।',
      'safety_rule_4_title': 'तत्काल थकान चेतावनी संकेत',
      'safety_rule_4_body': 'भारी पलकें, बार-बार जम्हाई आना, या लेन से हटना तुरंत सुरक्षित स्थान पर रुकने का संकेत है।',
      'safety_rule_5_title': 'ध्यान भटकाने से बचें और गति का सम्मान करें',
      'safety_rule_5_body': 'ड्राइविंग करते समय मोबाइल का उपयोग न करें। कानूनी गति और सुरक्षित दूरी बनाए रखें।',
      
      // Settings Screen
      'settings_title': 'सेटिंग्स और प्राथमिकताएं',
      'language_section_title': 'एप्लिकेशन भाषा',
      'language_section_desc': 'अपनी पसंदीदा भाषा चुनें। इंटरफ़ेस तुरंत अनुकूलित हो जाएगा:',
      'device_security_title': 'डिवाइस सुरक्षा वातावरण',
      'security_status_safe': 'वातावरण सुरक्षित और सत्यापित है',
      'security_status_warning': 'जोखिम या रूट वातावरण का पता चला',
      'privacy_policy_title': 'गोपनीयता नीति और शून्य क्लाउड पदचिह्न',
      'privacy_policy_desc': 'DriveAlert 100% ऑफ़लाइन काम करता है और कभी भी बाहरी सर्वर पर छवियां नहीं भेजता है।',
      'about_app_title': 'DriveAlert के बारे में',
      'about_app_body': 'DriveAlert स्थानीय न्यूरल नेटवर्क के माध्यम से थकान और विचलित ड्राइविंग से होने वाली दुर्घटनाओं को कम करने के लिए एक स्मार्ट सहायक है।',
    },

    // ----------------- CHINESE -----------------
    'zh': {
      // UI Components Translations
      'battery_banner_text': '为提高后台监测稳定性，您可以将应用排除在电池限制之外。',
      'battery_banner_details': '详情',
      'battery_dialog_title': '电池优化白名单',
      'battery_dialog_body': 'DriveAlert 需要在行驶中持续监测。\n\n电池优化可能会在后台冻结相机或算法。\n\n为确保可靠预警，请允许应用无限制运行。',
      'dialog_later': '稍后',
      'dialog_oem_settings': '系统设置',
      'dialog_allow': '允许',
      'monitoring_stopped': '监测已暂停',
      'alert_banner_wake_up': '🚨 立即清醒！',
      'alert_banner_wake_up_sub': '立即清醒！双眼处于闭合状态！',
      'alert_banner_recovering': '正在确认驾驶员警觉状态...',
      'alert_banner_drowsy': '⚠️ 警告：检测到疲劳嗜睡！',
      'alert_banner_watching': '正在监测闭眼状态...',
      'alert_banner_normal': '● 驾驶员清醒 - 安全驾驶中',
      'status_inactive': '未启动',
      'status_eyes_open': '双眼睁开',
      'status_eyes_closed': '双眼闭合',
      'status_unknown': '未识别',
      'confidence_label': '置信度',
      'perclos_label': '疲劳积累指数 (PERCLOS): ',
      'head_nod_label': '⚠️ 头部低垂',
      'btn_start_monitoring': '开始监测',
      'btn_stop_monitoring': '停止监测',
      'camera_preparing': '正在准备相机...',
      'face_locked': '已锁定驾驶员面部',
      'face_searching': '正在寻找驾驶员面部...',
      'power_saver_title': '节能模式已开启 (OLED Saver)',
      'power_saver_desc': '相机实时预览已关闭以降低发热与省电\nAI监测与紧急警报在后台100%正常工作\n(点击任意位置恢复实时画面)',
      'btn_show_camera': '显示画面',
      'btn_power_saver': '节能模式',
      'low_light_badge': '微光弱光',
      'eye_closed_badge': '闭眼',
      'eye_open_badge': '睁眼',
      'eye_checking_badge': '正在检查眼部...',
      'hud_driver_awake': '驾驶员清醒且警觉',
      'hud_watching': '正在监测眼部动作...',
      'hud_drowsy': '⚠️ 警告：检测到疲劳困倦！',
      'hud_recovering': '正在确认驾驶员清醒状态...',
      'hud_alarm': '🚨 危险：检测到驾车途中睡眠！',
      'hud_eye_closed': '眼部状态: 闭合',
      'hud_eye_open': '眼部状态: 睁开',
      'hud_perclos_label': '疲劳积累指数 (PERCLOS):',
      'hud_exit_tooltip': '退出 HUD 模式',
      'hud_mirror_tooltip': '前挡风玻璃反光镜像',
      'status_starting_monitoring': '正在启动监测服务...',
      'status_monitoring_driver': '正在监测驾驶员状态...',
      'status_start_failed': '启动监测失败',
      'status_stopped_success': '监测已成功停止',
      'status_recovering_monitoring': '🔄 正在恢复监测系统...',
      'thermal_protection_prefix': '散热保护：已降低非必要负载降温',

      // App & Navigation
      'app_title': 'DriveAlert - 驾驶员疲劳监测',
      'app_subtitle': '智能安全驾驶预警系统',
      'menu': '菜单',
      'version': '版本',
      'monitoring_active': '监测运行中且稳定',
      'monitoring_inactive': '准备开始监测',
      
      // Drawer Items
      'drawer_home': '主监测界面',
      'drawer_test_alarm': '测试声音警报与振动',
      'drawer_hud_mode': '夜间抬头显示 (HUD模式)',
      'drawer_permissions': '应用权限状态',
      'drawer_safety_guide': '安全指南与免责声明',
      'drawer_quick_start': '快速入门指南',
      'drawer_settings': '设置与语言',
      
      // Test Alarm
      'alarm_test_snack': '正在测试声音警报和触觉振动2秒...',
      
      // Model & System State
      'ai_preparing': '正在准备AI模型...',
      'ai_ready': 'AI引擎已就绪',
      'ai_failed': 'AI模型加载失败',
      'camera_init': '正在初始化摄像头...',
      'system_ready_msg': '系统初始化完成。点击开始以启动监测。',
      'retry': '重试',
      'start_monitoring': '开始监测',
      'stop_monitoring': '停止监测',
      
      // HUD Screen
      'hud_title': '抬头显示 (HUD模式)',
      'hud_subtitle': '前挡风玻璃极简反光显示',
      
      // Permissions Screen
      'permissions_title': '应用与设备权限',
      'permissions_desc': 'DriveAlert 需要以下权限以确保驾驶过程中的持续稳定监测：',
      'perm_camera_title': '前置摄像头权限',
      'perm_camera_desc': '用于实时本地分析眼部与面部特征，保护您免受疲劳和微睡眠影响。',
      'perm_notifications_title': '通知权限',
      'perm_notifications_desc': '用于维持后台前台服务并在后台运行时发出紧急警报。',
      'perm_battery_title': '电池优化白名单',
      'perm_battery_desc': '防止Android系统在锁屏或使用导航时冻结或终止监测。',
      'perm_granted': '已授权',
      'perm_denied': '未授权',
      'perm_restricted': '系统受限',
      'perm_request_btn': '立即授权',
      'perm_settings_btn': '打开系统设置',
      'perm_refresh_btn': '刷新权限状态',
      
      // Safety Guidelines Screen
      'safety_title': '安全准则与法律声明',
      'safety_how_it_works_title': '工作原理',
      'safety_how_it_works_body': 'DriveAlert 直接在您的设备上使用端侧计算机视觉（Edge AI）。绝对不会存储或上传任何照片或视频流到云端服务器，全面保护您的隐私。',
      'safety_disclaimer_title': '法律责任免责声明',
      'safety_disclaimer_body': 'DriveAlert 仅为辅助驾驶安全工具，绝不能替代驾驶员的警觉、专注与判断。驾驶员对车辆安全行驶和遵守交通法规承担全部法律责任。',
      'safety_rules_title': '安全驾驶黄金法则',
      'safety_rule_1_title': '驾驶前保证充足睡眠',
      'safety_rule_1_body': '长途驾驶前确保7至8小时充足睡眠。切勿在疲惫工作后长途驾驶。',
      'safety_rule_2_title': '每两小时休息一次',
      'safety_rule_2_body': '每行驶2小时或200公里至少停车休息15-20分钟，以活动身体并补充水分。',
      'safety_rule_3_title': '警惕生物钟嗜睡时段',
      'safety_rule_3_body': '凌晨 2:00 至 6:00 以及午后是疲劳驾驶事故高发期。',
      'safety_rule_4_title': '疲劳预警立即停车',
      'safety_rule_4_body': '眼皮沉重、频繁打哈欠或偏离车道时，必须立即在安全地带停车小憩。',
      'safety_rule_5_title': '避免分心并严守车速',
      'safety_rule_5_body': '驾驶过程中切勿使用手机，始终保持合法车速和安全跟车距离。',
      
      // Settings Screen
      'settings_title': '设置与系统偏好',
      'language_section_title': '应用语言',
      'language_section_desc': '选择您的偏好语言。界面文本与排版将立即切换：',
      'device_security_title': '设备安全环境',
      'security_status_safe': '环境安全已验证',
      'security_status_warning': '检测到环境风险或Root权限',
      'privacy_policy_title': '隐私政策与零云端留存',
      'privacy_policy_desc': 'DriveAlert 100% 离线运行，绝不向外部服务器传输任何图像数据。',
      'about_app_title': '关于 DriveAlert',
      'about_app_body': 'DriveAlert 是一个基于端侧神经网络的智能安全助手，旨在减少由疲劳和注意力分散引起的交通事故。',
    },

    // ----------------- JAPANESE -----------------
    'ja': {
      // UI Components Translations
      'battery_banner_text': 'バックグラウンド監視の安定性を向上させるため、バッテリー制限からアプリを除外できます。',
      'battery_banner_details': '詳細',
      'battery_dialog_title': 'バッテリー制限の除外',
      'battery_dialog_body': 'DriveAlertは運転中の継続的な監視を必要とします。\n\nバッテリー制限によりバックグラウンドでカメラが停止する場合があります。\n\n安全のため、制限なしでの実行を許可してください。',
      'dialog_later': '後で',
      'dialog_oem_settings': '端末設定',
      'dialog_allow': '許可',
      'monitoring_stopped': '監視停止中',
      'alert_banner_wake_up': '🚨 目を覚ましてください！',
      'alert_banner_wake_up_sub': '直ちに目を開けてください！目を閉じています！',
      'alert_banner_recovering': '覚醒状態を確認中...',
      'alert_banner_drowsy': '⚠️ 警告：居眠りの兆候を検知！',
      'alert_banner_watching': '閉眼を監視中...',
      'alert_banner_normal': '● 正常覚醒 - 安全運転中',
      'status_inactive': '待機中',
      'status_eyes_open': '開眼',
      'status_eyes_closed': '閉眼',
      'status_unknown': '未検出',
      'confidence_label': '信頼度',
      'perclos_label': '疲労蓄積指標 (PERCLOS): ',
      'head_nod_label': '⚠️ 頭部の傾き',
      'btn_start_monitoring': '監視を開始',
      'btn_stop_monitoring': '監視を停止',
      'camera_preparing': 'カメラを準備中...',
      'face_locked': '運転者の顔を捕捉',
      'face_searching': '運転者の顔を探索中...',
      'power_saver_title': '省電力モード有効 (OLED Saver)',
      'power_saver_desc': '発熱防止と節電のためカメラ映像を非表示にしています\nAI監視と警報はバックグラウンドで100%稼働中\n(画面をタップすると映像を再表示します)',
      'btn_show_camera': 'カメラ表示',
      'btn_power_saver': '省電力',
      'low_light_badge': '低照度',
      'eye_closed_badge': '閉眼',
      'eye_open_badge': '開眼',
      'eye_checking_badge': '目を検査中...',
      'hud_driver_awake': '運転者は覚醒・良好です',
      'hud_watching': '視線の動きを監視中...',
      'hud_drowsy': '⚠️ 警告：疲労・居眠りの兆候！',
      'hud_recovering': '覚醒の回復を確認中...',
      'hud_alarm': '🚨 危険：運転中の居眠りを検知しました！',
      'hud_eye_closed': '目の状態: 閉眼',
      'hud_eye_open': '目の状態: 開眼',
      'hud_perclos_label': '疲労蓄積指標 (PERCLOS):',
      'hud_exit_tooltip': 'HUDモードを終了',
      'hud_mirror_tooltip': 'フロントガラス用反転表示',
      'status_starting_monitoring': '監視サービスを開始中...',
      'status_monitoring_driver': '運転者の状態を監視中...',
      'status_start_failed': '監視の開始に失敗しました',
      'status_stopped_success': '監視を正常に停止しました',
      'status_recovering_monitoring': '🔄 監視システムを復旧中...',
      'thermal_protection_prefix': '熱保護：端末冷却のため負荷を低減しました',

      // App & Navigation
      'app_title': 'DriveAlert - 居眠り運転検知モニター',
      'app_subtitle': 'スマート＆安全運転支援システム',
      'menu': 'メニュー',
      'version': 'バージョン',
      'monitoring_active': 'モニタリング中・安定',
      'monitoring_inactive': '監視開始の準備完了',
      
      // Drawer Items
      'drawer_home': 'メイン監視画面',
      'drawer_test_alarm': '警報音と振動のテスト',
      'drawer_hud_mode': '夜間運転HUDモード',
      'drawer_permissions': 'アプリ権限ステータス',
      'drawer_safety_guide': '安全ガイドラインと免責事項',
      'drawer_quick_start': 'クイックスタートガイド',
      'drawer_settings': '設定と言語',
      
      // Test Alarm
      'alarm_test_snack': '警報音と触覚振動を2秒間テスト中...',
      
      // Model & System State
      'ai_preparing': 'AIモデルを準備中...',
      'ai_ready': 'AIエンジン準備完了',
      'ai_failed': 'AIモデルの読み込みに失敗しました',
      'camera_init': 'カメラを初期化中...',
      'system_ready_msg': '初期化完了。開始ボタンを押して監視を開始します。',
      'retry': '再試行',
      'start_monitoring': '監視を開始',
      'stop_monitoring': '監視を停止',
      
      // HUD Screen
      'hud_title': 'ヘッドアップディスプレイ (HUD)',
      'hud_subtitle': 'フロントガラス反射用シンプル画面',
      
      // Permissions Screen
      'permissions_title': 'アプリと端末の権限',
      'permissions_desc': '運転中の継続的かつ安定した監視を確保するため、以下の権限が必要です：',
      'perm_camera_title': 'フロントカメラ権限',
      'perm_camera_desc': '居眠りや瞬きを検知するため、端末内でのリアルタイム顔・目分析に必須です。',
      'perm_notifications_title': '通知権限',
      'perm_notifications_desc': 'フォアグラウンドサービスを維持し、バックグラウンド実行中に緊急警報を発信するために必要です。',
      'perm_battery_title': 'バッテリー最適化の除外',
      'perm_battery_desc': '画面ロック時やナビ使用時にAndroidが監視を停止するのを防ぎます。',
      'perm_granted': '許可済み',
      'perm_denied': '未許可',
      'perm_restricted': 'システム制限あり',
      'perm_request_btn': '権限を許可する',
      'perm_settings_btn': '端末の設定を開く',
      'perm_refresh_btn': 'ステータスを更新',
      
      // Safety Guidelines Screen
      'safety_title': '安全ガイドラインと免責事項',
      'safety_how_it_works_title': '動作の仕組み',
      'safety_how_it_works_body': 'DriveAlertはお使いの端末上で直接AI画像解析（Edge AI）を実行します。完全なプライバシー保護のため、写真や動画が外部サーバーに送信または保存されることは一切ありません。',
      'safety_disclaimer_title': '法的免責事項',
      'safety_disclaimer_body': 'DriveAlertは補助的な運転支援ツールであり、いかなる場合も運転手の注意力や判断力に代わるものではありません。安全運転および交通規則の遵守に関する法的責任はすべて運転手にあります。',
      'safety_rules_title': '安全運転の基本ルール',
      'safety_rule_1_title': '運転前の十分な睡眠',
      'safety_rule_1_body': '長距離運転の前には7〜8時間の十分な睡眠を取りましょう。疲れた状態での運転は避けてください。',
      'safety_rule_2_title': '2時間ごとの休憩',
      'safety_rule_2_body': '集中力を維持するため、2時間または200kmごとに少なくとも15〜20分の休憩を取りましょう。',
      'safety_rule_3_title': '居眠り危険時間帯への警戒',
      'safety_rule_3_body': '午前2:00〜6:00および午後の時間帯は、統計的に居眠り事故が最も発生しやすい時間帯です。',
      'safety_rule_4_title': '疲労の危険サインを見逃さない',
      'safety_rule_4_body': 'まぶたが重い、あくびが頻発する、車線をはみ出すなどの場合は、直ちに安全な場所に停車して仮眠を取ってください。',
      'safety_rule_5_title': '運転中のスマホ禁止と速度厳守',
      'safety_rule_5_body': '運転中のスマートフォン操作は絶対にやめ、法定速度と十分な車間距離を保ちましょう。',
      
      // Settings Screen
      'settings_title': '設定とシステム環境',
      'language_section_title': 'アプリの言語',
      'language_section_desc': '言語を選択してください。テキストとレイアウトが即座に切り替わります：',
      'device_security_title': '端末セキュリティ環境',
      'security_status_safe': '安全な環境が確認されました',
      'security_status_warning': 'セキュリティリスクまたはRootが検出されました',
      'privacy_policy_title': 'プライバシーポリシー（外部送信なし）',
      'privacy_policy_desc': 'DriveAlertは完全オフラインで動作し、カメラ画像を外部サーバーに送信することはありません。',
      'about_app_title': 'DriveAlertについて',
      'about_app_body': 'DriveAlertは、端末内のニューラルネットワークを通じて居眠りやわき見運転による事故を低減するための安全支援システムです。',
    },
  };

  /// Translates dynamic status messages and provider labels into the active language.
  String translateStatus(String? rawStatus) {
    if (rawStatus == null || rawStatus.isEmpty) return '';

    // Direct translation if it matches known phrases
    if (rawStatus.contains('تمت التهيئة بنجاح')) return translate('system_ready_msg');
    if (rawStatus.contains('جاهز لبدء المراقبة')) return translate('monitoring_inactive');
    if (rawStatus.contains('جاري تهيئة الكاميرا')) return translate('camera_init');
    if (rawStatus.contains('جاري بدء خدمة المراقبة')) return translate('status_starting_monitoring');
    if (rawStatus.contains('جاري مراقبة حالة السائق')) return translate('status_monitoring_driver');
    if (rawStatus.contains('فشل في بدء المراقبة')) return translate('status_start_failed');
    if (rawStatus.contains('تم إيقاف المراقبة')) return translate('status_stopped_success');
    if (rawStatus.contains('جاري استعادة نظام المراقبة')) return translate('status_recovering_monitoring');
    if (rawStatus.contains('نظام الذكاء الاصطناعي جاهز')) return translate('ai_ready');
    if (rawStatus.contains('جاري تجهيز نظام الذكاء الاصطناعي')) return translate('ai_preparing');
    if (rawStatus.contains('تعذر تحميل موديل')) return translate('ai_failed');
    if (rawStatus.contains('المراقبة متوقفة')) return translate('monitoring_stopped');
    if (rawStatus.contains('المراقبة نشطة')) return translate('monitoring_active');

    return translate(rawStatus);
  }

  String translate(String key) {
    final langCode = locale.languageCode;
    final map = _localizedValues[langCode] ?? _localizedValues['ar']!;
    return map[key] ?? _localizedValues['ar']?[key] ?? key;
  }

  bool get isRtl => locale.languageCode == 'ar';
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['ar', 'en', 'fr', 'es', 'hi', 'zh', 'ja'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocalizationsX on BuildContext {
  AppLocalizations get loc => AppLocalizations.of(this);
  String tr(String key) => AppLocalizations.of(this).translate(key);
  String trStatus(String? status) => AppLocalizations.of(this).translateStatus(status);
}
