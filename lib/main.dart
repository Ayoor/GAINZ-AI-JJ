



import 'package:animated_splash_screen/animated_splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:gainz_ai/ui/views/exerciseScreen.dart';
import 'package:gainz_ai/ui/views/exercise_summary.dart';
import 'package:gainz_ai/ui/views/splashscreen.dart';

void main()  {
  runApp(MyApp());
}
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return  MaterialApp(
      debugShowCheckedModeBanner: false,

// home: Dashboard()
      home: AnimatedSplashScreen(splash: const Splashscreen(),
        nextScreen: const ExerciseScreen(),
        duration: 3000,
        splashTransition: SplashTransition.fadeTransition,
        backgroundColor: Colors.white,

      ),
    );
  }
}










