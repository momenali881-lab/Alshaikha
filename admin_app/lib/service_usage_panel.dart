import 'package:flutter/material.dart';

class ServiceUsagePanel extends StatefulWidget {
  const ServiceUsagePanel({super.key});

  @override
  State<ServiceUsagePanel> createState() => _ServiceUsagePanelState();
}

class _ServiceUsagePanelState extends State<ServiceUsagePanel> {
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
        if (progress != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: Colors.black12,
              color: color,
            ),
          )
        else
          const Text('لا تتوفر قراءة مباشرة من داخل التطبيق',
            style: TextStyle(fontSize: 10, color: Colors.black54)),
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
      ]),
      _serviceCard(
        title: 'OneSignal',
        subtitle: 'الخطة المجانية — حدود المؤسسة',
        icon: Icons.notifications_active,
        color: const Color(0xFF5E35B1),
        children: [
          _line('المستخدمون النشطون شهرياً (MAU)', '1,000', 'راجع لوحة OneSignal',
            note: 'إشعارات Push غير محدودة من حيث عدد الإرسال ضمن حد 1,000 مستخدم نشط شهرياً.'),
          _line('رسائل البريد الإلكتروني', '10,000 / شهر', 'راجع لوحة OneSignal'),
          const SelectableText('لوحة الاستخدام: https://dashboard.onesignal.com/'),
        ],
      ),
      _serviceCard(
        title: 'Firebase — Spark',
        subtitle: 'حدود Firestore المجانية',
        icon: Icons.local_fire_department,
        color: const Color(0xFFFF8F00),
        children: [
          _line('قراءات المستندات', '50,000 / يوم', 'راجع لوحة Firebase'),
          _line('كتابات المستندات', '20,000 / يوم', 'راجع لوحة Firebase'),
          _line('حذف المستندات', '20,000 / يوم', 'راجع لوحة Firebase'),
          _line('تخزين Firestore', '1 GiB', 'راجع لوحة Firebase'),
          _line('نقل البيانات الصادر', '10 GiB / شهر', 'راجع لوحة Firebase'),
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
          _line('التخزين', '5 GB', 'راجع لوحة GetPronto'),
          _line('النقل الشهري', '10 GB / شهر', 'راجع لوحة GetPronto'),
          _line('التحويلات', '2,500 / شهر', 'راجع لوحة GetPronto'),
          const Text('مفتاح الرفع العام الموجود في التطبيق لا يملك صلاحية قراءة قائمة الملفات؛ لذلك لا نستخدمه لقراءة الاستهلاك. راجع الأرقام الفعلية من لوحة GetPronto.',
            style: TextStyle(fontSize: 11, color: Colors.black54)),
          const SelectableText('لوحة GetPronto: https://app.getpronto.io/'),
        ],
      ),
      const Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: Text('حدود الخطة المجانية معروضة للمقارنة. مؤشرات الاستهلاك الفعلي لا تظهر إلا عند توفر صلاحية قراءة موثوقة من مزود الخدمة.',
          style: TextStyle(fontSize: 11, color: Colors.black54)),
      ),
    ]);
  }
}
