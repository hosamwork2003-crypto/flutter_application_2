// lib/services/lessons_api.dart
import '../services/api_client.dart';

class LessonsApi {
  final ApiClient client;
  LessonsApi(this.client);

  Future<List<Map<String, dynamic>>> getState() async {
    final r = await client.get("/lessons/state");
    return (r["items"] as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> upsertState({
    required String lessonId,
    required String videoUrl,
    required int positionMs,
    required int durationMs,
    required double progress,
    required bool isFavorite,
  }) async {
    return await client.post("/lessons/state", {
      "lesson_id": lessonId,
      "video_url": videoUrl,
      "position_ms": positionMs,
      "duration_ms": durationMs,
      "progress": progress,
      "is_favorite": isFavorite,
    });
  }

  Future<List<Map<String, dynamic>>> getBookmarks(String lessonId) async {
    final r = await client.get("/lessons/$lessonId/bookmarks");
    return (r["items"] as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> addBookmark(String lessonId, int positionMs, String label) async {
    final r = await client.post("/lessons/$lessonId/bookmarks", {
      "position_ms": positionMs,
      "label": label,
    });
    return (r["item"] as Map<String, dynamic>);
  }

  Future<void> deleteBookmark(int id) async {
    await client.delete("/lessons/bookmarks/$id");
  }

Future<List<Map<String, dynamic>>> getQuizMarks(String lessonId) async {
  final r = await client.get("/lessons/$lessonId/quiz-marks");
  return (r["items"] as List).cast<Map<String, dynamic>>();
}

Future<Map<String, dynamic>> getQuizQuestion(String lessonId, int markId) async {
  return await client.get("/lessons/$lessonId/quiz-marks/$markId");
}

Future<bool> answerQuiz(String lessonId, int markId, String optionKey) async {
  final r = await client.post("/lessons/$lessonId/quiz-marks/$markId/answer", {
    "optionKey": optionKey,
  });
  return (r["correct"] == true);
}

}