import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/shop_api.dart';
import '../services/auth_api.dart';

class ShopPage extends StatefulWidget {
  const ShopPage({super.key});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> with TickerProviderStateMixin {
  // ---------------------------------------------------------
  // 1. التعريفات والمتغيرات الأساسية
  // ---------------------------------------------------------
  late TabController _mainTabController;
  final ApiClient _apiClient = ApiClient('http://192.168.1.114:3000');
  late final ShopApi _shopApi = ShopApi(_apiClient);
  late final AuthApi _authApi = AuthApi(_apiClient);

  int _userCoins = 0;
  List<dynamic> _allStoreItems = [];
  List<dynamic> _allMyInventory = [];
  bool _isLoading = true;

  // تعريف الألوان الجديدة (السمة الذهبية)
  final Color goldColor = const Color(0xFFFFD700); 
  final Color darkGold = const Color(0xFFB8860B);  

  final List<Map<String, String>> _categories = [
    {'id': 'avatar', 'name': 'الشخصية'},
    {'id': 'background', 'name': 'الخلفية'},
    {'id': 'hair', 'name': 'الشعر'},
    {'id': 'top', 'name': 'قميص'},
    {'id': 'bottom', 'name': 'بنطلون'},
    {'id': 'shoes', 'name': 'حذاء'},
    {'id': 'cap', 'name': 'كاب'},
    {'id': 'accessory', 'name': 'إكسسوار'},
  ];

  // ---------------------------------------------------------
  // 2. دورة حياة الصفحة (Initialization)
  // ---------------------------------------------------------
  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(length: 2, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _mainTabController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------
  // 3. منطق جلب وتحديث البيانات (تم تنظيف التحذيرات الصفراء)
  // ---------------------------------------------------------
  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final resMe = await _authApi.me();
      final resStore = await _shopApi.getItems();
      final resInv = await _shopApi.getInventory();

      setState(() {
        // تم إزالة التحقق غير الضروري (is Map) لأن Dart يعرف النوع مسبقاً
        var data = resMe.containsKey('user') ? resMe['user'] : resMe;
        _userCoins = (data['coins'] ?? 0).toInt();

        _allStoreItems = resStore.containsKey('items') ? resStore['items'] : [];
        _allMyInventory = resInv.containsKey('items') ? resInv['items'] : [];
        
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------------------------------------------------------
  // 4. بناء واجهة المستخدم (UI)
  // ---------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // خلفية بيضاء مريحة
      appBar: AppBar(
        backgroundColor: goldColor,
        elevation: 2,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.monetization_on, color: Colors.white, size: 28),
            const SizedBox(width: 10),
            Text(
              "$_userCoins",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white),
            ),
          ],
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _mainTabController,
          indicatorColor: Colors.white,
          indicatorWeight: 4,
          labelStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          tabs: const [Tab(text: "المتجر"), Tab(text: "حقيبتي")],
        ),
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: goldColor))
        : TabBarView(
            controller: _mainTabController,
            physics: const BouncingScrollPhysics(),
            children: [
              _buildNestedCategoryView(_allStoreItems, isStore: true),
              _buildNestedCategoryView(_allMyInventory, isStore: false),
            ],
          ),
    );
  }

  Widget _buildNestedCategoryView(List<dynamic> dataList, {required bool isStore}) {
    return DefaultTabController(
      length: _categories.length,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            labelColor: darkGold,
            unselectedLabelColor: Colors.grey,
            indicatorColor: goldColor,
            labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            tabs: _categories.map((cat) => Tab(text: cat['name'])).toList(),
          ),
          Expanded(
            child: TabBarView(
              children: _categories.map((cat) {
                final filtered = dataList.where((i) => i['item_type'] == cat['id']).toList();
                return _buildItemGrid(filtered, isStore);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemGrid(List<dynamic> items, bool isStore) {
    if (items.isEmpty) {
      return const Center(child: Text("لا يوجد عناصر هنا حالياً", style: TextStyle(fontSize: 18, color: Colors.grey)));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, 
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => _buildItemCard(items[index], isStore),
    );
  }

  Widget _buildItemCard(dynamic item, bool isStore) {
    bool isEquipped = item['is_equipped'] == true;

    return GestureDetector(
      // عرض الوصف عند الضغط المطول
      onLongPress: () => _showDescription(item),
      child: Card(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: goldColor.withOpacity(0.3), width: 1),
        ),
        elevation: 4,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: item['image_url'] != null 
                  ? Image.network(item['image_url'], errorBuilder: (c, e, s) => Icon(Icons.checkroom, size: 60, color: goldColor))
                  : Icon(Icons.checkroom, size: 60, color: goldColor),
              ),
            ),
            Text(item['name'] ?? "", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18), textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(bottom: 12, left: 8, right: 8),
              child: isStore ? _buildBuyButton(item) : _buildEquipButton(item, isEquipped),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // 5. الأزرار والحوارات (Widgets)
  // ---------------------------------------------------------
  Widget _buildBuyButton(dynamic item) {
    return ElevatedButton(
      onPressed: () => _handleBuy(item), 
      style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("${item['price_coins']}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(width: 6),
          const Icon(Icons.monetization_on, color: Colors.white, size: 20), 
        ],
      ),
    );
  }

  Widget _buildEquipButton(dynamic item, bool isEquipped) {
    return ElevatedButton(
      onPressed: () => isEquipped ? _handleUnequip(item['item_type']) : _handleEquip(item),
      style: ElevatedButton.styleFrom(backgroundColor: isEquipped ? Colors.redAccent : Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      child: Text(isEquipped ? "خلع القطعة" : "تجهيز", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }

  void _showDescription(dynamic item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(item['name'] ?? "وصف العنصر", textAlign: TextAlign.center),
        content: Text(item['description'] ?? "بدون وصف", textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("حسناً", style: TextStyle(color: darkGold, fontSize: 18)))
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // 6. الدوال التنفيذية (Actions)
  // ---------------------------------------------------------
  void _handleBuy(item) async {
    try {
      final res = await _shopApi.buyItem(item['id']);
      if (res['success'] == true) { _loadAllData(); _showSnackBar("تم الشراء بنجاح! 🎉", Colors.green); }
    } catch (e) { _showSnackBar(e.toString().replaceAll("Exception: ", ""), Colors.red); }
  }

  void _handleEquip(item) async {
    try { await _shopApi.equipItem(item['id'], item['item_type']); _loadAllData(); _showSnackBar("تم تغيير المظهر! ✨", Colors.blue); }
    catch (e) { _showSnackBar("فشل في تجهيز القطعة", Colors.red); }
  }

  void _handleUnequip(String itemType) async {
    try { await _shopApi.unequipItem(itemType); _loadAllData(); _showSnackBar("تم خلع القطعة! ✨", Colors.orange); }
    catch (e) { _showSnackBar("فشل في إلغاء التجهيز", Colors.red); }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), backgroundColor: color, behavior: SnackBarBehavior.floating));
  }
}