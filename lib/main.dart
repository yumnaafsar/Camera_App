import 'package:camera/camera.dart';
import 'package:camera_app/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';


List<CameraDescription> cameras = [];

Future<void> main() async {
  try{
    WidgetsFlutterBinding.ensureInitialized();
    cameras=await availableCameras();
  
  } on CameraException catch(e){
    print('Error in fetching Camera: $e');
  }
  runApp( MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: CameraScreen(),
    );
  }
}

