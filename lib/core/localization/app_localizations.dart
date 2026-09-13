import 'package:flutter/material.dart';

/// Supported application language codes.
enum AppLanguage {
  arabic('ar', 'العربية', 'Arabic', '🇸🇦'),
  english('en', 'English', 'English', '🇬🇧'),
  french('fr', 'Français', 'French', '🇫🇷'),
  spanish('es', 'Español', 'Spanish', '🇪🇸');

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
  };

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
    return ['ar', 'en', 'fr', 'es'].contains(locale.languageCode);
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
}
