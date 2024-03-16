import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class StorageAccessExample extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Storage Access Example'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            // Open the system file picker
            FilePickerResult? result = await FilePicker.platform.pickFiles();

            if (result != null) {
              // Access the selected file using result.files.first
              print('File path: ${result.files.first.path}');
            } else {
              print('User canceled the file picker');
            }
          },
          child: Text('Open File Picker'),
        ),
      ),
    );
  }
}

void main() {
  runApp(MaterialApp(
    home: StorageAccessExample(),
  ));
}
