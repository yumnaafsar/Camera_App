import 'dart:io';

import 'package:flutter/material.dart';

class PreviewScreen extends StatefulWidget {
  final File imageFile;
  final List<File> fileList;

  const PreviewScreen({
    required this.imageFile,
    required this.fileList,
  });


  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  @override
  Widget build(BuildContext context) {
    return  Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [ 
          Expanded(
            child: Image.file(widget.imageFile),
          ),
        ],
      ),
    );
  }
}