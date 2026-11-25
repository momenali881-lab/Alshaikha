import 'package:flutter/material.dart';
import 'get_pronto_uploader.dart';

class ServiceUsagePanel extends StatefulWidget {
  const ServiceUsagePanel({super.key});

  @override
  State<ServiceUsagePanel> createState() => _ServiceUsagePanelState();
}

class _ServiceUsagePanelState extends State<ServiceUsagePanel> {
  late Future<Map<String, int>> _prontoUsage;

  @override
  void initState() {
    super.initState();
    _prontoUsage = GetProntoUploader.readStorageUsage();
  }

  void _refresh() {
    setState(() => _prontoUsage = GetProntoUploader.readStorageUsage());
  }

  String _bytes(int value) {
    if (value >= 1024 * 1024 * 1024) {
      return '${(value / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    if (value >= 1024 * 1024) {
      return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(value / 1024).toStringAsFixed(1)} KB';
  }

  Widget _line(String label, String limit, String actual, {double? ratio, String? note}) {
    final progress = ratio == null ? null : ratio.clamp(0.0, 1.0).toDouble();
    final color = progress == null
        ? Colors.blueGrey
        : progress >= .9 ? Colors.red : progress >= .75 ? Colors.orange : Colors.teal;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          Text(actual, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          Text(' / $limit', style: const TextStyle(color: Colors.black54, fontSize: 12)),
        ]),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress ?? 0,
            minHeight: 7,
            backgroundColor: Colors.black12,
            color: color,
          ),
        ),
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(note, style: const TextStyle(fontSize: 11, color: Colors.black54)),
          ),
      ]),
    );
  }

  Widget _serviceCard({required String title, required String subtitle,
      required IconData icon, required Color color, required List<Widget> children}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(backgroundColor: color.withOpacity(.12),
              child: Icon(icon, color: color)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.black54)),
            ])),
          ]),
          const SizedBox(height: 12),
          ...children,
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Expanded(child: Text('استهلاك الخدمات والحدود المجانية',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        IconButton(onPressed: _refresh, tooltip: 'تحديث الاستهلاك',
          icon: const Icon(Icons.refresh)),
      ]),
      _serviceCard(
        title: 'OneSignal',
        subtitle: 'الخطة المجانية — حدود المؤسسة',
        icon: Icons.notifications_active,
        color: const Color(0xFF5E35B1),
        children: [
          _line('المستخدمون النشطون شهرياً (MAU)', '1,000', 'غير مقروء',
            note: 'حد الخطة المجانية. الرقم الفعلي يظهر في لوحة Organization لدى OneSignal.'),
          _line('رسائل البريد الإلكتروني', '10,000 / شهر', 'غير مقروء',
            note: 'حجم الإرسال الفعلي لا يتوفر عبر إعدادات التطبيق الحالية.'),
          const SelectableText('لوحة الاستخدام: https://dashboard.onesignal.com/'),
        ],
      ),
      _serviceCard(
        title: 'Firebase — Spark',
        subtitle: 'حدود Firestore المجانية',
        icon: Icons.local_fire_department,
        color: const Color(0xFFFF8F00),
        children: [
          _line('قراءات المستندات', '50,000 / يوم', 'غير متصل'),
          _line('كتابات المستندات', '20,000 / يوم', 'غير متصل'),
          _line('حذف المستندات', '20,000 / يوم', 'غير متصل'),
          _line('تخزين Firestore', '1 GiB', 'غير متصل'),
          _line('نقل البيانات الصادر', '10 GiB / شهر', 'غير متصل'),
          const Text('الأرقام الفعلية تحتاج صلاحية Cloud Monitoring؛ لا تُستنتج من عدد السجلات داخل التطبيق.',
            style: TextStyle(fontSize: 11, color: Colors.black54)),
          const SelectableText('لوحة Firebase: https://console.firebase.google.com/project/alshaikha/usage'),
        ],
      ),
      _serviceCard(
        title: 'GetPronto',
        subtitle: 'الخطة المجانية — تخزين الصور والملفات',
        icon: Icons.cloud_done,
        color: const Color(0xFF00897B),
        children: [
          FutureBuilder<Map<String, int>>(
            future: _prontoUsage,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(padding: EdgeInsets.all(8),
                  child: LinearProgressIndicator());
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return const Text('تعذر جلب حجم الملفات حالياً. تحقق من اتصال API key وصلاحية القراءة.',
                  style: TextStyle(color: Colors.deepOrange, fontSize: 12));
              }
              final bytes = snapshot.data!['bytes'] ?? 0;
              final files = snapshot.data!['files'] ?? 0;
              final limit = 5 * 1024 * 1024 * 1024;
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _line('التخزين المستخدم', '5 GB', _bytes(bytes),
                  ratio: bytes / limit, note: 'مجموع أحجام الملفات المسجلة في حساب GetPronto.'),
                _line('عدد الملفات', 'حسب الحساب', '$files ملف'),
              ]);
            },
          ),
          _line('النقل الشهري', '10 GB / شهر', 'غير متاح عبر Files API'),
          _line('التحويلات', '2,500 / شهر', 'غير متاح عبر Files API'),
          const Text('التخزين محسوب من بيانات الملفات. النقل والتحويلات لا تعرضهما واجهة Files API الموثقة.',
            style: TextStyle(fontSize: 11, color: Colors.black54)),
          const SelectableText('لوحة GetPronto: https://app.getpronto.io/'),
        ],
      ),
      const Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: Text('تنبيه: حدود الخطة ثابتة حسب الأسعار المنشورة، أما الاستهلاك الفعلي فيظهر فقط عندما توفر الخدمة واجهة قراءة موثوقة. لا تعرض هذه اللوحة قيماً فعلية مخمّنة.',
          style: TextStyle(fontSize: 11, color: Colors.black54)),
      ),
    ]);
  }
}
