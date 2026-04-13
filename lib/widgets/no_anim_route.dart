import 'package:flutter/material.dart';

class NoAnimRoute<T> extends MaterialPageRoute<T> {
  NoAnimRoute({required WidgetBuilder builder, RouteSettings? settings})
      : super(builder: builder, settings: settings);

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Duration get reverseTransitionDuration => Duration.zero;

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    return child; // بدون أي تأثير نهائيًا
  }
}