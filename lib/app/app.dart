import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants/app_colors.dart';
import '../features/map/presentation/screens/map_screen.dart';
import '../features/splash/splash_screen.dart';

class ZimaneMeApp extends StatelessWidget {
  const ZimaneMeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ziman\u00EA Me',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.creamYellow,
        primaryColor: AppColors.darkBrown,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.darkBrown,
          primary: AppColors.darkBrown,
          secondary: AppColors.successGreen,
          surface: AppColors.creamYellow,
        ),
        textTheme: GoogleFonts.nunitoTextTheme(),
      ),
      routes: <String, WidgetBuilder>{'/home': (_) => const MapScreen()},
      home: const SplashScreen(),
    );
  }
}
