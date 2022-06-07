import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ichat_app/allConstants/constants.dart';

class FullPhotoPage extends StatelessWidget {
  final String imageUrl;
  const FullPhotoPage({
    Key? key,
    required this.imageUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: ColorConstants.primaryColor,
          statusBarIconBrightness: Brightness.light,
        ),
        backgroundColor: ColorConstants.primaryColor,
        iconTheme: const IconThemeData(
          color: ColorConstants.greyColor2,
        ),
      ),
      body: SizedBox(
        child: Image.network(
          imageUrl,
          width: double.infinity,
        ),
      ),
    );
  }
}
