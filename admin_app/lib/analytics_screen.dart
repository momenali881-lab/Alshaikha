import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'shared_store.dart';
import 'service_usage_panel.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  late Future<_AnalyticsData> _future;
  bool _migrating = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_AnalyticsData> _load() async {
    final db = FirebaseFirestore.instance;
    final results = await Future.wait([
      db.collection('profiles').where('role', isEqualTo: 'customer').get(),
      db.collection('app_devices').get(),
      db.collection('bookings').get(),
      db.collection('messages').get(),
    ]);
    final customers = results[0] as QuerySnapshot<Map<String, dynamic>>;
    final devices = results[1] as QuerySnapshot<Map<String, dynamic>>;
    final bookings = results[2] as QuerySnapshot<Map<String, dynamic>>;
    final messages = results[3] as QuerySnapshot<Map<String, dynamic>>;

    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final deviceRows = devices.docs.map((doc) => <String, dynamic>{
      'id': doc.id,
      ...doc.data(),
    }).toList();
    DateTime? dateOf(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      return null;
    }
    int numberOf(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;

    final profilesById = <String, Map<String, dynamic>>{
      for (final doc in customers.docs) doc.id: doc.data(),
    };
    final active7 = deviceRows.where((d) {
      final last = dateOf(d['lastSeen']);
      return last != null && last.isAfter(sevenDaysAgo);
    }).length;
    final active30 = deviceRows.where((d) {
      final last = dateOf(d['lastSeen']);
      return last != null && last.isAfter(thirtyDaysAgo);
    }).length;
    final new30 = deviceRows.where((d) {
      final first = dateOf(d['firstSeen']);
      return first != null && first.isAfter(thirtyDaysAgo);
    }).length;

    deviceRows.sort((a, b) {
      final da = dateOf(a['lastSeen']) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final db = dateOf(b['lastSeen']) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return db.compareTo(da);
    });

    return _AnalyticsData(
      registeredCustomers: customers.docs.length,
      totalDevices: devices.docs.length,
      newDevices30: new30,
      activeDevices7: active7,
      activeDevices30: active30,
      totalBookings: bookings.docs.length,
      totalMessages: messages.docs.length,
      totalLaunches: deviceRows.fold<int>(0, (sum, d) => sum + numberOf(d['launchCount'])),
      profileViews: deviceRows.fold<int>(0, (sum, d) => sum + numberOf(d['profileViewCount'])),
      bookingActions: deviceRows.fold<int>(0, (sum, d) => sum + numberOf(d['bookingCount'])),
      messageActions: deviceRows.fold<int>(0, (sum, d) => sum + numberOf(d['messageCount'])),
      favoriteActions: deviceRows.fold<int>(0, (sum, d) => sum + numberOf(d['favoriteCount'])),
      recentDevices: deviceRows.take(30).map((d) {
        final uid = (d['lastUserId'] ?? '').toString();
        final profile = profilesById[uid] ?? const <String, dynamic>{};
        return _DeviceRow(
          id: d['id'].toString(),
          customerName: (profile['displayName'] ?? profile['username'] ?? 'عميل').toString(),
          lastSeen: dateOf(d['lastSeen']),
          firstSeen: dateOf(d['firstSeen']),
          lastActivity: (d['lastActivity'] ?? '').toString(),
          launches: numberOf(d['launchCount']),
          bookings: numberOf(d['bookingCount']),
          messages: numberOf(d['messageCount']),
          profileViews: numberOf(d['profileViewCount']),
          favorites: numberOf(d['favoriteCount']),
        );
      }).toList(),
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _migrate() async {
    setState(() => _migrating = true);
    try {
      final result = await SharedStore.migrateLocalToCloud();
      if (!mounted) return;
      final migrated = result['migrated'] ?? 0;
      final skipped = result['skipped'] ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('اكتمل الفحص: نُقل $migrated سجل، وتُرك $skipped سجل موجود مسبقاً. لم تُحذف أي بيانات محلية.')),
      );
      setState(() => _future = _load());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر نقل البيانات المحلية: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _migrating = false);
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'غير متوفر';
    final d = date.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}  ${two(d.hour)}:${two(d.minute)}';
  }

  String _activityName(String value) => switch (value) {
    'app_open' => 'فتح التطبيق',
    'booking' => 'إرسال حجز',
    'message' => 'إرسال رسالة',
    'favorite' => 'تفاعل مع المفضلة',
    'profile_view' => 'مشاهدة ملف عضو',
    _ => value.isEmpty ? 'لا يوجد نشاط مسجل' : value,
  };

  Widget _metric(String title, int value, IconData icon, Color color, {String? hint}) {
    return SizedBox(
      width: 158,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(backgroundColor: color.withOpacity(.12), child: Icon(icon, color: color)),
              const SizedBox(height: 10),
              Text('$value', style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              if (hint != null) Text(hint, style: const TextStyle(fontSize: 10, color: Colors.black54)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AnalyticsData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.cloud_off, size: 42, color: Colors.redAccent),
                const SizedBox(height: 10),
                const Text('تعذر تحميل الإحصاءات من Firestore'),
                Text('${snapshot.error}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
                const SizedBox(height: 12),
                FilledButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة')),
              ]),
            ),
          );
        }
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!;
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(14),
            children: [
              Row(children: [
                const Expanded(child: Text('إحصاءات التطبيق ونشاط العملاء', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold))),
                IconButton(onPressed: _refresh, tooltip: 'تحديث الإحصاءات', icon: const Icon(Icons.refresh)),
              ]),
              Wrap(spacing: 8, runSpacing: 2, children: [
                _metric('أجهزة شغّلت التطبيق', data.totalDevices, Icons.phone_android, const Color(0xFF6A1B9A), hint: 'أول تشغيل مسجل'),
                _metric('أجهزة جديدة خلال 30 يوماً', data.newDevices30, Icons.new_releases, const Color(0xFF00897B)),
                _metric('الحسابات المسجلة', data.registeredCustomers, Icons.person, const Color(0xFF3949AB)),
                _metric('نشطة خلال 7 أيام', data.activeDevices7, Icons.bolt, const Color(0xFFE91E63)),
                _metric('نشطة خلال 30 يوماً', data.activeDevices30, Icons.calendar_month, const Color(0xFFFF8F00)),
                _metric('إجمالي الحجوزات', data.totalBookings, Icons.event_available, const Color(0xFF00897B)),
                _metric('رسائل الدردشة', data.totalMessages, Icons.forum, const Color(0xFF5E35B1)),
              ]),
              const ServiceUsagePanel(),
              Card(child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('مؤشرات النشاط المسجل', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _activityLine('مرات فتح التطبيق', data.totalLaunches),
                  _activityLine('مشاهدات ملفات الكادر', data.profileViews),
                  _activityLine('إجراءات الحجز من التطبيق', data.bookingActions),
                  _activityLine('الرسائل المرسلة', data.messageActions),
                  _activityLine('تفاعلات المفضلة', data.favoriteActions),
                ]),
              )),
              Card(child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('ترحيل البيانات المحلية القديمة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  const Text('ينقل السجلات الموجودة على هذا الجهاز إلى Firestore دون حذف النسخ المحلية. السجلات الموجودة سحابياً لن تُستبدل.', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _migrating ? null : _migrate,
                    icon: _migrating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.cloud_upload_outlined),
                    label: Text(_migrating ? 'جارٍ فحص ونقل البيانات...' : 'فحص ونقل البيانات القديمة'),
                  ),
                ]),
              )),
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 12, 4, 6),
                child: Text('آخر الأجهزة نشاطاً', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              if (data.recentDevices.isEmpty)
                const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('لا توجد أجهزة مسجلة بعد. سيظهر الجهاز بعد تسجيل دخول العميل واتصاله بالإنترنت.'))),
              ...data.recentDevices.map((device) => Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.smartphone)),
                  title: Text(device.customerName),
                  subtitle: Text('آخر نشاط: ${_activityName(device.lastActivity)}\nآخر ظهور: ${_formatDate(device.lastSeen)}\nأول تشغيل: ${_formatDate(device.firstSeen)}'),
                  isThreeLine: true,
                  trailing: PopupMenuButton<void>(
                    tooltip: 'ملخص النشاط',
                    itemBuilder: (_) => [
                      PopupMenuItem<void>(enabled: false, child: Text('فتح التطبيق: ${device.launches}')),
                      PopupMenuItem<void>(enabled: false, child: Text('الحجوزات: ${device.bookings}')),
                      PopupMenuItem<void>(enabled: false, child: Text('الرسائل: ${device.messages}')),
                      PopupMenuItem<void>(enabled: false, child: Text('مشاهدات الملفات: ${device.profileViews}')),
                      PopupMenuItem<void>(enabled: false, child: Text('المفضلة: ${device.favorites}')),
                    ],
                  ),
                ),
              )),
              const Padding(
                padding: EdgeInsets.all(10),
                child: Text('ملاحظة: عدد الأجهزة يقيس أول تشغيل واتصال مسجلين بعد تسجيل الدخول، ولا يقيس تنزيل ملف APK الذي لم يُفتح. أرقام التنزيلات الدقيقة تتطلب Google Play Console.', style: TextStyle(fontSize: 11, color: Colors.black54)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _activityLine(String label, int value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Expanded(child: Text(label)),
      Text('$value', style: const TextStyle(fontWeight: FontWeight.bold)),
    ]),
  );
}

class _AnalyticsData {
  final int registeredCustomers, totalDevices, newDevices30, activeDevices7, activeDevices30;
  final int totalBookings, totalMessages, totalLaunches, profileViews, bookingActions, messageActions, favoriteActions;
  final List<_DeviceRow> recentDevices;

  const _AnalyticsData({
    required this.registeredCustomers,
    required this.totalDevices,
    required this.newDevices30,
    required this.activeDevices7,
    required this.activeDevices30,
    required this.totalBookings,
    required this.totalMessages,
    required this.totalLaunches,
    required this.profileViews,
    required this.bookingActions,
    required this.messageActions,
    required this.favoriteActions,
    required this.recentDevices,
  });
}

class _DeviceRow {
  final String id, customerName, lastActivity;
  final DateTime? lastSeen, firstSeen;
  final int launches, bookings, messages, profileViews, favorites;

  const _DeviceRow({
    required this.id,
    required this.customerName,
    required this.lastSeen,
    required this.firstSeen,
    required this.lastActivity,
    required this.launches,
    required this.bookings,
    required this.messages,
    required this.profileViews,
    required this.favorites,
  });
}
