import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:flutter_application_1/services/api_client.dart';
import 'package:flutter_application_1/services/auth_api.dart';

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic>? initial;
  const EditProfilePage({super.key, this.initial});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final auth = AuthApi(ApiClient('http://192.168.1.114:3000'));

  late final TextEditingController fullName;
  String academicLevel = 'Not set';
  DateTime? birthDate;

  bool loading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    fullName = TextEditingController(text: (widget.initial?['full_name'] ?? widget.initial?['name'] ?? '') as String);

    final lvl = widget.initial?['academic_level'];
    if (lvl is String && lvl.isNotEmpty) academicLevel = lvl;

    final bd = widget.initial?['birth_date'];
    if (bd is String && bd.length >= 10) {
      birthDate = DateTime.tryParse(bd.substring(0, 10));
    }
  }

  @override
  void dispose() {
    fullName.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: birthDate ?? DateTime(now.year - 10, 1, 1),
      firstDate: DateTime(1950, 1, 1),
      lastDate: now,
    );
    if (picked != null) setState(() => birthDate = picked);
  }

  String? _birthToIso() {
    if (birthDate == null) return null;
    final y = birthDate!.year.toString().padLeft(4, '0');
    final m = birthDate!.month.toString().padLeft(2, '0');
    final d = birthDate!.day.toString().padLeft(2, '0');
    return "$y-$m-$d";
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, imageQuality: 80);
    if (x == null) return;

    final bytes = await x.readAsBytes();
    final b64 = base64Encode(bytes);

    setState(() { loading = true; error = null; });
    try {
      await auth.updateAvatarBase64(b64);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Avatar updated")));
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  Future<void> _save() async {
    setState(() { loading = true; error = null; });
    try {
      await auth.updateProfile(
        fullName: fullName.text,
        academicLevel: academicLevel == 'Not set' ? null : academicLevel,
        birthDate: _birthToIso(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/image/main_home.png', fit: BoxFit.cover, gaplessPlayback: true),
          ),
          SafeArea(
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context, false),
                    ),
                    const Text("Edit Profile", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: loading ? null : _pickAvatar,
                              child: const Text("Upload Photo"),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: fullName,
                            style: const TextStyle(color: Colors.white),
                            decoration: _dec("Full name"),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            value: academicLevel,
                            dropdownColor: Colors.black,
                            decoration: _dec("Academic level"),
                            items: const [
                              DropdownMenuItem(value: 'Not set', child: Text('Not set')),
                              DropdownMenuItem(value: 'Primary', child: Text('Primary')),
                              DropdownMenuItem(value: 'Preparatory', child: Text('Preparatory')),
                              DropdownMenuItem(value: 'Secondary', child: Text('Secondary')),
                              DropdownMenuItem(value: 'University', child: Text('University')),
                            ],
                            onChanged: loading ? null : (v) => setState(() => academicLevel = v ?? 'Not set'),
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: loading ? null : _pickBirthDate,
                              child: Text(birthDate == null ? "Pick birth date" : "Birth: ${_birthToIso()}"),
                            ),
                          ),
                          if (error != null) ...[
                            const SizedBox(height: 10),
                            Text(error!, style: const TextStyle(color: Colors.redAccent)),
                          ],
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: loading ? null : _save,
                              child: Text(loading ? "Saving..." : "Save"),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  InputDecoration _dec(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Colors.white70),
    filled: true,
    fillColor: Colors.black.withOpacity(0.25),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
  );
}