import 'api_client.dart';

class ShopApi {
  final ApiClient apiClient;

  ShopApi(this.apiClient);

  // 1. جلب منتجات المتجر (الأصناف غير المملوكة)
  Future<Map<String, dynamic>> getItems() async {
    final response = await apiClient.get('/shop/items');
    return response is Map<String, dynamic> ? response : {'items': []};
  }

  // 2. جلب "حقيبتي" (الأصناف التي اشتراها المستخدم)
  Future<Map<String, dynamic>> getInventory() async {
    final response = await apiClient.get('/shop/inventory');
    return response is Map<String, dynamic> ? response : {'items': []};
  }

  // 3. شراء منتج جديد
  Future<Map<String, dynamic>> buyItem(int itemId) async {
    final response = await apiClient.post('/shop/buy/$itemId', {});
    return response;
  }

  // 4. لبس/تجهيز قطعة (هذه هي الدالة التي كانت ناقصة وتسببت في الخطأ)
  Future<Map<String, dynamic>> equipItem(int itemId, String itemType) async {
    final response = await apiClient.post('/shop/equip', {
      'itemId': itemId,
      'itemType': itemType,
    });
    return response;
  }

// إضافة دالة إلغاء التجهيز
  Future<Map<String, dynamic>> unequipItem(String itemType) async {
    final response = await apiClient.post('/shop/unequip', {
      'itemType': itemType,
    });
    return response;
  }

}