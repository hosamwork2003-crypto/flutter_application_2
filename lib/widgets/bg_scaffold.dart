import 'package:flutter/material.dart';

class BgScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final bool showBack;

  const BgScaffold({
    super.key,
    required this.title,
    required this.child,
    this.showBack = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/image/main_home.png',
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            centerTitle: true,
            iconTheme: const IconThemeData(color: Colors.white),
            titleTextStyle: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            leading: showBack
                ? IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  )
                : null,
            title: Text(title),
          ),
          body: SafeArea(child: child),
        ),
      ],
    );
  }
}