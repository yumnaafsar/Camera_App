import 'dart:io';

import 'package:camera/camera.dart';
import 'package:camera_app/dimensions.dart';
import 'package:camera_app/main.dart';
import 'package:camera_app/preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? controller;
  bool _isCameraInitialized = false;
  File? _imageFile;
  bool _isCameraPermissionGranted = false;

  // parameters for resolution
  final resolutionPresets = ResolutionPreset.values;
  ResolutionPreset currentResolutionPreset = ResolutionPreset.high;

  // parameters for zoom feature
  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 1.0;
  double _currentZoomLevel = 1.0;

  // parameters for exposure
  double _minAvailableExposureOffset = 0.0;
  double _maxAvailableExposureOffset = 0.0;
  double _currentExposureOffset = 0.0;

  // Flash light
  FlashMode? _currentFlashMode;

  // back camera
  bool _isRearCameraSelected = true;

//
//
  getPermissionStatus() async {
    await Permission.camera.request();
    var status = await Permission.camera.status;
    if (status.isGranted) {
      print('Camera Permission: GRANTED');
      setState(() {
        _isCameraPermissionGranted = true;
      });
      // Set and initialize the new camera
      onNewCameraSelected(cameras[0]);
      refreshAlreadyCapturedImages();
    } else {
      print('Camera Permission: DENIED');
    }
  }

  // To store the retrieved files
  List<File> allFileList = [];

  refreshAlreadyCapturedImages() async {
    // Get the directory
    final directory = await getApplicationDocumentsDirectory();
    List<FileSystemEntity> fileList = await directory.list().toList();
    allFileList.clear();

    List<Map<int, dynamic>> fileNames = [];

    // Searching for all the image and video files using
    // their default format, and storing them
    fileList.forEach((file) {
      if (file.path.contains('.jpg') || file.path.contains('.mp4')) {
        allFileList.add(File(file.path));

        String name = file.path.split('/').last.split('.').first;
        fileNames.add({0: int.parse(name), 1: file.path.split('/').last});
      }
    });

    // Retrieving the recent file
    if (fileNames.isNotEmpty) {
      final recentFile =
          fileNames.reduce((curr, next) => curr[0] > next[0] ? curr : next);
      String recentFileName = recentFile[1];
      _imageFile = File('${directory.path}/$recentFileName');

      setState(() {});
    }
  }

  //
  void updateImageFile(File newImageFile) {
    setState(() {
      _imageFile = newImageFile;
    });
  }

  // camer to take picture
  Future<XFile?> takePicture() async {
    final CameraController? cameraController = controller;
    // if capture is already done do nothing
    if (cameraController!.value.isTakingPicture) {
      return null;
    }
    try {
      XFile file = await cameraController.takePicture();
      return file;
    } on CameraException catch (e) {
      print('Error occured while taking picture:$e');
      return null;
    }
  }

  Future<void> takeAndSavePicture() async {
    final XFile? imageFile = await takePicture();

    if (imageFile != null) {
      // Save the image to the gallery
      final result = await ImageGallerySaver.saveFile(imageFile.path);

      if (result['isSuccess']) {
        // Image saved successfully
        print('Image saved to gallery');
        updateImageFile(File(imageFile.path));
      } else {
        // Error saving the image
        print('Error saving image to gallery');
      }
    }
  }

  void onNewCameraSelected(CameraDescription cameraDescription) async {
    final previousCameraController = controller;

    final CameraController cameraController = CameraController(
      cameraDescription,
      currentResolutionPreset,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await previousCameraController?.dispose();

    if (mounted) {
      setState(() {
        controller = cameraController;
      });
    }

    // Update UI if controller updated
    cameraController.addListener(() {
      if (mounted) setState(() {});
    });

    try {
      await cameraController.initialize();
      await Future.wait([
        cameraController
            .getMinExposureOffset()
            .then((value) => _minAvailableExposureOffset = value),
        cameraController
            .getMaxExposureOffset()
            .then((value) => _maxAvailableExposureOffset = value),
        cameraController
            .getMaxZoomLevel()
            .then((value) => _maxAvailableZoom = value),
        cameraController
            .getMinZoomLevel()
            .then((value) => _minAvailableZoom = value),
      ]);

      _currentFlashMode = controller!.value.flashMode;
    } on CameraException catch (e) {
      print('Error initializing camera: $e');
    }

    if (mounted) {
      setState(() {
        _isCameraInitialized = controller!.value.isInitialized;
      });
    }
  }

  // camera[0]--> back camera
  // camera[1]--> front camera
  @override
  void initState() {
    // hide statys bar
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
    getPermissionStatus();
    super.initState();
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  // manage memory
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = controller;

    // App state changed before we got the chance to initialize.
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      // Free up memory when camera not active
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      // Reinitialize the camera with same properties
      onNewCameraSelected(cameraController.description);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    print(screenHeight);
    print(screenWidth);
    return Scaffold(
      body: _isCameraPermissionGranted
          ? _isCameraInitialized
              ? Column(children: [
                  AspectRatio(
                      aspectRatio: 1 / controller!.value.aspectRatio,
                      child: Stack(children: [
                        CameraPreview(
                          controller!,
                          child: LayoutBuilder(builder: (BuildContext context,
                              BoxConstraints constraints) {
                            return GestureDetector();
                          }),
                        ),
                        Padding(
                            padding: const EdgeInsets.fromLTRB(
                              16.0,
                              8.0,
                              16.0,
                              8.0,
                            ),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Align(
                                    alignment: Alignment.topRight,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black87,
                                        borderRadius: BorderRadius.circular(
                                            Dimension.radius10),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          left: 8.0,
                                          right: 8.0,
                                        ),
                                        child: DropdownButton<ResolutionPreset>(
                                          dropdownColor: Colors.black87,
                                          underline: Container(),
                                          value: currentResolutionPreset,
                                          items: [
                                            for (ResolutionPreset preset
                                                in resolutionPresets)
                                              DropdownMenuItem(
                                                child: Text(
                                                  preset
                                                      .toString()
                                                      .split('.')[1]
                                                      .toUpperCase(),
                                                  style: TextStyle(
                                                      color: Colors.white),
                                                ),
                                                value: preset,
                                              )
                                          ],
                                          onChanged: (value) {
                                            setState(() {
                                              currentResolutionPreset = value!;
                                              _isCameraInitialized = false;
                                            });
                                            onNewCameraSelected(
                                                controller!.description);
                                          },
                                          hint: Text("Select item"),
                                        ),
                                      ),
                                    ),
                                  ),
                                ])),

                        // Exposure Feature
                        Padding(
                          padding: const EdgeInsets.only(top: 70, bottom: 40),
                          child: Align(
                            alignment: Alignment.topRight,
                            child: Column(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(
                                        Dimension.radius10),
                                  ),
                                  child: Padding(
                                    padding:
                                        EdgeInsets.all(Dimension.padding10),
                                    child: Text(
                                      _currentExposureOffset
                                              .toStringAsFixed(1) +
                                          'x',
                                      style: TextStyle(color: Colors.black),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: RotatedBox(
                                    quarterTurns: 3,
                                    child: Container(
                                      height: 30,
                                      child: Slider(
                                        value: _currentExposureOffset,
                                        min: _minAvailableExposureOffset,
                                        max: _maxAvailableExposureOffset,
                                        activeColor: Colors.white,
                                        inactiveColor: Colors.white30,
                                        onChanged: (value) async {
                                          setState(() {
                                            _currentExposureOffset = value;
                                          });
                                          await controller!
                                              .setExposureOffset(value);
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Zoom feature
                        Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Slider(
                                    value: _currentZoomLevel,
                                    min: _minAvailableZoom,
                                    max: _maxAvailableZoom,
                                    activeColor: Colors.white,
                                    inactiveColor: Colors.white38,
                                    onChanged: (value) async {
                                      setState(() {
                                        _currentZoomLevel = value;
                                      });
                                      await controller!.setZoomLevel(value);
                                    },
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.all(8),
                                    child: Text(
                                      _currentZoomLevel.toStringAsFixed(1) +
                                          'x',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                )
                              ],
                            ),
                          ],
                        ),
                      ])),
                  Expanded(
                      child: Container(
                          decoration: BoxDecoration(color: Colors.black),
                          child: Padding(
                              padding:
                                  EdgeInsets.only(bottom: Dimension.padding10),
                              child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    // front back camera toggle
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        InkWell(
                                          onTap: () {
                                            setState(() {
                                              _isCameraInitialized = false;
                                            });
                                            onNewCameraSelected(
                                              cameras[_isRearCameraSelected
                                                  ? 0
                                                  : 1],
                                            );
                                            setState(() {
                                              _isRearCameraSelected =
                                                  !_isRearCameraSelected;
                                            });
                                          },
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              Icon(
                                                Icons.circle,
                                                color: Colors.black38,
                                                size: Dimension.icon60,
                                              ),
                                              Icon(
                                                _isRearCameraSelected
                                                    ? Icons.camera_front
                                                    : Icons.camera_rear,
                                                color: Colors.white,
                                                size: Dimension.icon30,
                                              ),
                                            ],
                                          ),
                                        ),

                                        // picture taking button
                                        InkWell(
                                          onTap: () async {
                                            XFile? rawImage =
                                                await takePicture();
                                            File imageFile =
                                                File(rawImage!.path);

                                            int currentUnix = DateTime.now()
                                                .millisecondsSinceEpoch;
                                            final directory =
                                                await getApplicationDocumentsDirectory();
                                            String fileFormat =
                                                imageFile.path.split('.').last;

                                            await imageFile.copy(
                                              '${directory.path}/$currentUnix.$fileFormat',
                                            );
                                            await takeAndSavePicture();
                                          },
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              Icon(Icons.circle,
                                                  color: Colors.white38,
                                                  size: Dimension.icon80),
                                              Icon(Icons.circle,
                                                  color: Colors.white,
                                                  size: Dimension.icon65),
                                            ],
                                          ),
                                        ),

                                        // show captured image
                                        GestureDetector(
                                          onTap:_imageFile != null
                                            ? () {
                                                Navigator.of(context).push(
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        PreviewScreen(
                                                      imageFile: _imageFile!,
                                                      fileList: allFileList,
                                                    ),
                                                  ),
                                                );
                                              }
                                            : null,
                                          child: Container(
                                            width: Dimension.width55,
                                            height: Dimension.height55,
                                            decoration: BoxDecoration(
                                              color: Colors.black,
                                              borderRadius: BorderRadius.circular(
                                                  Dimension.radius10),
                                              border: Border.all(
                                                  color: Colors.white, width: 2),
                                              image: _imageFile != null
                                                  ? DecorationImage(
                                                      image:
                                                          FileImage(_imageFile!),
                                                      fit: BoxFit.cover,
                                                    )
                                                  : null,
                                            ),
                                          ),
                                        )
                                      ],
                                    ),
                                  
                                    // Flash modes
                                    Expanded(
                                      child: Padding(
                                        padding: EdgeInsets.only(
                                            bottom: Dimension.padding20,
                                            left: Dimension.padding10,
                                            right: Dimension.padding10),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            InkWell(
                                              onTap: () async {
                                                setState(() {
                                                  _currentFlashMode =
                                                      FlashMode.off;
                                                });
                                                await controller!.setFlashMode(
                                                  FlashMode.off,
                                                );
                                              },
                                              child: Icon(
                                                Icons.flash_off,
                                                color: _currentFlashMode ==
                                                        FlashMode.off
                                                    ? Colors.amber
                                                    : Colors.white,
                                              ),
                                            ),
                                            InkWell(
                                              onTap: () async {
                                                setState(() {
                                                  _currentFlashMode =
                                                      FlashMode.auto;
                                                });
                                                await controller!.setFlashMode(
                                                  FlashMode.auto,
                                                );
                                              },
                                              child: Icon(
                                                Icons.flash_auto,
                                                color: _currentFlashMode ==
                                                        FlashMode.auto
                                                    ? Colors.amber
                                                    : Colors.white,
                                              ),
                                            ),
                                            InkWell(
                                              onTap: () async {
                                                setState(() {
                                                  _currentFlashMode =
                                                      FlashMode.always;
                                                });
                                                await controller!.setFlashMode(
                                                  FlashMode.always,
                                                );
                                              },
                                              child: Icon(
                                                Icons.flash_on,
                                                color: _currentFlashMode ==
                                                        FlashMode.always
                                                    ? Colors.amber
                                                    : Colors.white,
                                              ),
                                            ),
                                            InkWell(
                                              onTap: () async {
                                                setState(() {
                                                  _currentFlashMode =
                                                      FlashMode.torch;
                                                });
                                                await controller!.setFlashMode(
                                                  FlashMode.torch,
                                                );
                                              },
                                              child: Icon(
                                                Icons.highlight,
                                                color: _currentFlashMode ==
                                                        FlashMode.torch
                                                    ? Colors.amber
                                                    : Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  ]))))
                ])
              : Center(
                  child: Text(
                    'LOADING',
                    style: TextStyle(color: Colors.white),
                  ),
                )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(),
                Text(
                  'Permission denied',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: Dimension.font25,
                  ),
                ),
                SizedBox(height: Dimension.font25),
                ElevatedButton(
                  onPressed: () {
                    getPermissionStatus();
                  },
                  child: Padding(
                    padding: EdgeInsets.all(Dimension.padding10),
                    child: Text(
                      'Give permission',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: Dimension.font25,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
