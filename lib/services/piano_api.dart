import 'api_client.dart';

class PianoApi {
  final ApiClient api;
  PianoApi(this.api);

  Future<Map<String, dynamic>> getState() async {
    final data = await api.get('/api/piano/state');
    return data;
  }

  Future<Map<String, dynamic>> saveState({
    required int stars,
    required int score,
    required int lastMode,
    required int teacherSequenceLength,
  }) async {
    final data = await api.post('/api/piano/state', {
      'stars': stars,
      'score': score,
      'last_mode': lastMode,
      'teacher_sequence_length': teacherSequenceLength,
    });
    return data;
  }
}