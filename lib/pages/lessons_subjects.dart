import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'lessons.dart';

class LessonsSubjectsPage extends StatelessWidget {
  const LessonsSubjectsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/image/main_home.png',
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'اختر المادة',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 20,
                          runSpacing: 20,
                          children: const [
                            _SubjectCard(
                              title: 'Math',
                              imagePath: 'assets/image/math.png',
                              subjectKey: 'math',
                            ),
                            _SubjectCard(
                              title: 'English',
                              imagePath: 'assets/image/english.png',
                              subjectKey: 'english',
                            ),
                            _SubjectCard(
                              title: 'Arabic',
                              imagePath: 'assets/image/arabic.png',
                              subjectKey: 'arabic',
                            ),
                            _SubjectCard(
                              title: 'Science',
                              imagePath: 'assets/image/science.png',
                              subjectKey: 'science',
                            ),
                            _SubjectCard(
                              title: 'Colors & Shapes',
                              imagePath: 'assets/image/colors_shapes.png',
                              subjectKey: 'colors_shapes',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  final String title;
  final String imagePath;
  final String subjectKey;

  const _SubjectCard({
    required this.title,
    required this.imagePath,
    required this.subjectKey,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LessonsPage(
              subject: subjectKey,
              title: title,
            ),
          ),
        );
      },
      child: Container(
        width: 180,
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          image: DecorationImage(
            image: AssetImage(imagePath),
            fit: BoxFit.cover,
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 12,
              spreadRadius: 2,
              color: Colors.black.withOpacity(0.25),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withOpacity(0.65),
              ],
            ),
          ),
          alignment: Alignment.bottomCenter,
          padding: const EdgeInsets.all(12),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}