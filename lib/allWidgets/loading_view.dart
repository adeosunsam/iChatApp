import 'package:flutter/material.dart';
import 'package:ichat_app/allConstants/color_constants.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      child: const Center(
        child: CircularProgressIndicator(
          color: ColorConstants.primaryColor,
        ),
      ),
    );
  }
}
