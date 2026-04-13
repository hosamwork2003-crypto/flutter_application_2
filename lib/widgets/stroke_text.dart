import 'package:flutter/material.dart';

Widget strokeText(
  String text, {
  double size = 24,
  Color strokeColor = Colors.black,
  Color fillColor = Colors.red,
  double strokeWidth = 2,
}) =>
    Stack(
      children: [
        Text(
          text,
          style: TextStyle(
            fontSize: size,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..color = strokeColor,
          ),
        ),
        Text(
          text,
          style: TextStyle(
            fontSize: size,
            color: fillColor,
          ),
        ),
      ],
    );