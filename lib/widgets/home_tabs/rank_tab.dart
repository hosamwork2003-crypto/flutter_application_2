import 'dart:convert'; // <- ده الـ import اللي كان ناقص
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/services/api_client.dart';

class RankTab extends StatefulWidget {
  const RankTab({super.key});

  @override
  State<RankTab> createState() => _RankTabState();
}

class _RankTabState extends State<RankTab> {
  final ApiClient apiClient = ApiClient('http://192.168.1.114:3000');
  
  List<dynamic> leaderboard = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchLeaderboard();
  }

Future<void> _fetchLeaderboard() async {
    try {
      final data = await apiClient.get('/leaderboard');
      
      if (mounted) {
        setState(() {
          // 1. لو السيرفر رجع رسالة خطأ صريحة
          if (data is Map && data.containsKey('error')) {
            errorMessage = "خطأ من السيرفر: ${data['error']}";
          } 
          // 2. لو الداتا رجعت زي ما إحنا متوقعين (قائمة)
          else if (data is List) {
leaderboard = (data as List?) ?? [];          } 
          // 3. لو راجعة جوه مفتاح اسمه items (لو الـ ApiClient متبرمج كده)
          else if (data is Map && data.containsKey('items')) {
            leaderboard = data['items'] as List<dynamic>;
          }
          else {
            errorMessage = "تنسيق البيانات غير معروف";
          }
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("LEADERBOARD ERROR: $e");
      if (mounted) {
        setState(() {
          // هيطبع الخطأ التقني على الشاشة عشان نقدر نحله
          errorMessage = "تفاصيل الخطأ: $e"; 
          isLoading = false;
        });
      }
    }
  }

  // 👇 دالة جديدة آمنة جداً للتعامل مع صور الـ Base64
  ImageProvider? _getAvatarImage(String? base64String) {
    if (base64String == null || base64String.trim().isEmpty) return null;
    try {
      // 1. نشيل الجزء الأول لو موجود (data:image/png;base64,)
      String cleanString = base64String.split(',').last;
      
      // 2. نشيل أي مسافات أو سطور جديدة ممكن تبوظ الـ Decode
      cleanString = cleanString.replaceAll(RegExp(r'\s+'), '');
      
      // 3. نعالج مشكلة الـ Padding لو السلسلة ناقصة علامات '='
      int paddingLength = cleanString.length % 4;
      if (paddingLength > 0) {
        cleanString += '=' * (4 - paddingLength);
      }
      
      return MemoryImage(base64Decode(cleanString));
    } catch (e) {
      debugPrint("Error decoding base64 image: $e");
      return null; // لو باظت، هترجع null ويعرض أيقونة الشخص الافتراضية
    }
  }

  Widget _buildRankAvatar(int index, String? avatarBase64) {
    Color ringColor;
    if (index == 0) ringColor = Colors.amber; // الأول ذهبي
    else if (index == 1) ringColor = Colors.grey.shade400; // التاني فضي
    else if (index == 2) ringColor = Colors.brown.shade400; // التالت برونزي
    else ringColor = Colors.white24;

    final avatarImage = _getAvatarImage(avatarBase64);

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ringColor, width: 2.5),
      ),
      child: CircleAvatar(
        radius: 22,
        backgroundColor: Colors.black45,
        backgroundImage: avatarImage,
        child: avatarImage == null 
          ? const Icon(Icons.person, color: Colors.white) 
          : null,
      ),
    );
  }

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
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Text(
                          "لوحة الشرف",
                          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : errorMessage != null
                            ? Center(child: Text(errorMessage!, style: const TextStyle(color: Colors.redAccent)))
                            : leaderboard.isEmpty
                                ? const Center(child: Text("لا توجد بيانات للترتيب حتى الآن", style: TextStyle(color: Colors.white70)))
                                : ListView.builder(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    itemCount: leaderboard.length,
                                    itemBuilder: (context, index) {
                                      final user = leaderboard[index];
                                      final isTop3 = index < 3;

                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 12),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: isTop3 ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.4),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: isTop3 ? Colors.amber.withOpacity(0.5) : Colors.white12,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            SizedBox(
                                              width: 30,
                                              child: Text(
                                                "#${index + 1}",
                                                style: TextStyle(
                                                  color: isTop3 ? Colors.amber : Colors.white70,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            _buildRankAvatar(index, user['avatar_base64']),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                user['full_name'] ?? user['name'] ?? 'طالب مجهول',
                                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                            Row(
                                              children: [
                                                const Icon(Icons.star, color: Colors.amber, size: 20),
                                                const SizedBox(width: 4),
                                                Text(
                                                  "${user['stars'] ?? 0}",
                                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    },
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