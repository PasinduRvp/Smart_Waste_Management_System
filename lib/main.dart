import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get_storage/get_storage.dart';
import 'package:smart_waste_management/controllers/auth_controller.dart';
import 'package:smart_waste_management/controllers/theme_controller.dart';
import 'package:smart_waste_management/utils/app_themes.dart';
import 'package:smart_waste_management/utils/logger.dart';
import 'package:smart_waste_management/views/splash_screen.dart';
import 'controllers/pickup_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize GetStorage
    await GetStorage.init();
    AppLogger.info('GetStorage initialized', 'main');

    // Initialize Firebase
    await Firebase.initializeApp();
    AppLogger.info('Firebase initialized', 'main');

    // Configure Firestore settings
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    AppLogger.info('Firestore configured', 'main');

    // Initialize GetX Controllers
    Get.put(AuthController(), permanent: true);
    Get.put(ThemeController(), permanent: true);
    Get.put(PickupController());


    AppLogger.success('Application initialization complete', 'main');
  } catch (e) {
    AppLogger.error('Error during app initialization: $e', 'main');
    rethrow;
  }

  runApp(const SmartWasteManagementApp());
}

class SmartWasteManagementApp extends StatelessWidget {
  const SmartWasteManagementApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeController themeController = Get.find();

    return GetMaterialApp(
      title: 'Smart Waste Management - EcoCollect',
      theme: AppThemes.light,
      darkTheme: AppThemes.dark,
      themeMode: themeController.theme,
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
      locale: Get.deviceLocale,
      fallbackLocale: const Locale('en', 'US'),
      defaultTransition: Transition.cupertino,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('si', 'LK'),
        Locale('ta', 'LK'),
      ],
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        scrollbars: false,
      ),
    );
  }
}