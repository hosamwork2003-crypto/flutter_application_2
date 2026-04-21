import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_client.dart';

class AdminLessonsPage extends StatefulWidget {
  const AdminLessonsPage({super.key});

  @override
  State<AdminLessonsPage> createState() => _AdminLessonsPageState();
}

class _AdminLessonsPageState extends State<AdminLessonsPage> {
  final ApiClient _api = ApiClient('http://192.168.1.114:3000');

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _lessonNameCtrl = TextEditingController();
  final TextEditingController _lessonIdCtrl = TextEditingController();
  final TextEditingController _qFileNameCtrl = TextEditingController();

  String? _selectedSubject;
  File? _videoFile;

  bool _isUploading = false;
  String? _statusMessage;

  final List<_QuizMarkItem> _marks = [
    _QuizMarkItem(markId: 1),
  ];

  final List<String> _subjects = const [
    'math',
    'english',
    'arabic',
    'science',
    'colors_shapes',
  ];

  @override
  void dispose() {
    _lessonNameCtrl.dispose();
    _lessonIdCtrl.dispose();
    _qFileNameCtrl.dispose();

    for (final mark in _marks) {
      mark.dispose();
    }
    super.dispose();
  }

  Future<void> _pickVideo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
        withData: false,
      );

      if (result == null || result.files.isEmpty) return;

      final path = result.files.single.path;
      if (path == null || path.isEmpty) return;

      setState(() {
        _videoFile = File(path);
      });
    } catch (e) {
      _showSnack('فشل اختيار الفيديو: $e');
    }
  }

  void _addMark() {
    final nextId = _marks.isEmpty ? 1 : (_marks.last.markId + 1);
    setState(() {
      _marks.add(_QuizMarkItem(markId: nextId));
    });
  }

  void _removeMark(int index) {
    if (_marks.length == 1) {
      _showSnack('لازم يفضل عندك علامة سؤال واحدة على الأقل');
      return;
    }

    setState(() {
      final item = _marks.removeAt(index);
      item.dispose();
    });
  }

  List<Map<String, dynamic>> _buildQuizMarksJson() {
    final qFile = _qFileNameCtrl.text.trim();

    return _marks.map((item) {
      final qNo = int.tryParse(item.qNoCtrl.text.trim()) ?? 0;
      final atValue = int.tryParse(item.atMsCtrl.text.trim()) ?? 0;

      return {
        'mark_id': item.markId,
        'q_file': qFile,
        'q_no': qNo,
        'at_ms': atValue,
        'active': item.active,
      };
    }).toList();
  }

  Future<void> _uploadLesson() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    if (_selectedSubject == null || _selectedSubject!.trim().isEmpty) {
      _showSnack('اختر المادة');
      return;
    }

    if (_videoFile == null) {
      _showSnack('اختر الفيديو');
      return;
    }

    final videoExists = await _videoFile!.exists();
    if (!videoExists) {
      _showSnack('ملف الفيديو غير موجود');
      return;
    }

    setState(() {
      _isUploading = true;
      _statusMessage = 'جاري رفع الدرس...';
    });

    try {
      final data = await _api.multipartPost(
        '/api/lessons/upload',
        fields: {
          'subject': _selectedSubject!.trim(),
          'lesson_name': _lessonNameCtrl.text.trim(),
          'lesson_id': _lessonIdCtrl.text.trim(),
          'quiz_marks_json': jsonEncode(_buildQuizMarksJson()),
        },
        files: {
          'video': _videoFile!,
        },
      );

      setState(() {
        _statusMessage = data['message']?.toString() ?? 'تم رفع الدرس بنجاح';
      });

      _showSnack('تم رفع الدرس بنجاح');
      _clearForm();
    } catch (e) {
      debugPrint('UPLOAD ERROR: $e');
      setState(() {
        _statusMessage = 'حدث خطأ أثناء الرفع: $e';
      });
      _showSnack('حدث خطأ أثناء الرفع: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _clearForm() {
    _lessonNameCtrl.clear();
    _lessonIdCtrl.clear();
    _qFileNameCtrl.clear();

    for (final mark in _marks) {
      mark.dispose();
    }

    setState(() {
      _selectedSubject = null;
      _videoFile = null;
      _marks
        ..clear()
        ..add(_QuizMarkItem(markId: 1));
    });
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white24),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Text(
            'Admin Lessons Upload',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.white70),
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: Colors.black.withOpacity(0.25),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.lightBlueAccent),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.28),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildPickerBox({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required IconData icon,
    String? selectedName,
  }) {
    return InkWell(
      onTap: _isUploading ? null : onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.22),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    selectedName ?? subtitle,
                    style: TextStyle(
                      color: selectedName == null
                          ? Colors.white60
                          : Colors.lightGreenAccent,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.upload_file, color: Colors.white70),
          ],
        ),
      ),
    );
  }

  Widget _buildMarksList() {
    return Column(
      children: [
        for (int i = 0; i < _marks.length; i++) ...[
          _buildSingleMarkCard(_marks[i], i),
          if (i != _marks.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildSingleMarkCard(_QuizMarkItem item, int index) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.20),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Question Mark ${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(
                  'mark_id: ${item.markId}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _isUploading ? null : () => _removeMark(index),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                  ),
                  child: const Icon(Icons.delete_outline, color: Colors.redAccent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: item.qNoCtrl,
            label: 'رقم السؤال في بنك الأسئلة',
            hint: 'مثال: 12',
            keyboardType: TextInputType.number,
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'اكتب رقم السؤال';
              }
              if (int.tryParse(v.trim()) == null) {
                return 'اكتب رقم صحيح';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: item.atMsCtrl,
            label: 'وقت ظهور السؤال في الفيديو بالملي ثانية',
            hint: 'مثال: 45000',
            keyboardType: TextInputType.number,
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'اكتب وقت الظهور';
              }
              if (int.tryParse(v.trim()) == null) {
                return 'اكتب رقم صحيح';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: item.active,
            activeColor: Colors.lightGreenAccent,
            title: const Text(
              'السؤال مفعل',
              style: TextStyle(color: Colors.white),
            ),
            onChanged: _isUploading
                ? null
                : (val) {
                    setState(() {
                      item.active = val;
                    });
                  },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final videoName = _videoFile?.path.split(Platform.pathSeparator).last;

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
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTopBar(),
                      const SizedBox(height: 18),
                      _buildSectionCard(
                        title: 'بيانات الدرس',
                        child: Column(
                          children: [
                            DropdownButtonFormField<String>(
                              value: _selectedSubject,
                              dropdownColor: const Color(0xFF1F1F1F),
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'المادة',
                                labelStyle:
                                    const TextStyle(color: Colors.white70),
                                filled: true,
                                fillColor: Colors.black.withOpacity(0.25),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide:
                                      const BorderSide(color: Colors.white24),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Colors.lightBlueAccent,
                                  ),
                                ),
                              ),
                              items: _subjects
                                  .map(
                                    (s) => DropdownMenuItem<String>(
                                      value: s,
                                      child: Text(s),
                                    ),
                                  )
                                  .toList(),
                              onChanged: _isUploading
                                  ? null
                                  : (v) {
                                      setState(() {
                                        _selectedSubject = v;
                                      });
                                    },
                              validator: (v) =>
                                  v == null || v.isEmpty ? 'اختر المادة' : null,
                            ),
                            const SizedBox(height: 12),
                            _buildTextField(
                              controller: _lessonNameCtrl,
                              label: 'اسم الدرس',
                              hint: 'مثال: Lesson 1',
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'اكتب اسم الدرس';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            _buildTextField(
                              controller: _lessonIdCtrl,
                              label: 'Lesson ID',
                              hint: 'مثال: math_lesson_1',
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'اكتب lesson_id';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            _buildTextField(
                              controller: _qFileNameCtrl,
                              label: 'اسم ملف بنك الأسئلة',
                              hint: 'مثال: math.q',
                              validator: (v) {
                                final t = (v ?? '').trim();
                                if (t.isEmpty) {
                                  return 'اكتب اسم ملف الأسئلة';
                                }
                                if (!t.toLowerCase().endsWith('.q')) {
                                  return 'لازم الاسم ينتهي بـ .q';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildSectionCard(
                        title: 'الفيديو',
                        child: _buildPickerBox(
                          title: 'اختيار الفيديو',
                          subtitle: 'اختر ملف الفيديو المراد رفعه',
                          icon: Icons.video_library_outlined,
                          selectedName: videoName,
                          onTap: _pickVideo,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildSectionCard(
                        title: 'علامات ظهور الأسئلة في الفيديو',
                        trailing: GestureDetector(
                          onTap: _isUploading ? null : _addMark,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.lightBlueAccent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.lightBlueAccent.withOpacity(0.5),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.add, color: Colors.lightBlueAccent),
                                SizedBox(width: 6),
                                Text(
                                  'إضافة',
                                  style: TextStyle(
                                    color: Colors.lightBlueAccent,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        child: _buildMarksList(),
                      ),
                      const SizedBox(height: 18),
                      if (_statusMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            _statusMessage!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isUploading ? null : _uploadLesson,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: _isUploading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Upload Lesson',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuizMarkItem {
  _QuizMarkItem({required this.markId})
      : qNoCtrl = TextEditingController(),
        atMsCtrl = TextEditingController(),
        active = true;

  final int markId;
  final TextEditingController qNoCtrl;
  final TextEditingController atMsCtrl;
  bool active;

  void dispose() {
    qNoCtrl.dispose();
    atMsCtrl.dispose();
  }
}
