import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://lfztgrmrcooszjryocng.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxmenRncm1yY29vc3pqcnlvY25nIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI0ODM5NTQsImV4cCI6MjA4ODA1OTk1NH0.bT016gtDeme3naBAYVTeuMFWpWNnWwkke5Hut6Khw6Y',
  );

  runApp(const ClimbingRouteApp());
}

// Handy global accessor used throughout the app
final supabase = Supabase.instance.client;

class ClimbingRouteApp extends StatelessWidget {
  const ClimbingRouteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Climbing Route Creator',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 224, 86, 255),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}