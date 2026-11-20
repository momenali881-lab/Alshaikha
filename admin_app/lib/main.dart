import 'package:flutter/material.dart';

void main() => runApp(const SheikhaAdminApp());

class SheikhaAdminApp extends StatelessWidget {
  const SheikhaAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFFB77D91));
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'الشيخة - الإدارة',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: const Color(0xFFFFF9F6),
        appBarTheme: const AppBarTheme(centerTitle: true),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFB77D91),
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const AdminDashboard(),
    );
  }
}

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  static const sections = <(String, String, IconData)>[
    ('إدارة الكادر', 'الملفات والصور والتوفر والأسعار', Icons.groups_2_outlined),
    ('أرشيف الجلسات', 'التوثيق وربط الجلسات بالكادر', Icons.photo_library_outlined),
    ('الحجوزات', 'طلبات العملاء والمواعيد', Icons.calendar_month_outlined),
    ('محادثات العملاء', 'محادثات منفصلة مع الإدارة', Icons.forum_outlined),
    ('بانرات الرئيسية', 'إدارة ما يصل إلى 7 بانرات', Icons.view_carousel_outlined),
    ('التقارير والإعدادات', 'النشاط والمظهر والإعدادات', Icons.tune_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('الشيخة | لوحة الإدارة')),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFB77D91), Color(0xFF80647F)],
                ),
                borderRadius: BorderRadius.circular(26),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AL SHEIKHA MASSAGE CENTER',
                      style: TextStyle(color: Colors.white70)),
                  SizedBox(height: 12),
                  Text('مرحباً بك في إدارة المركز',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      )),
                  Text('النواة الأولية لتطبيق الإدارة',
                      style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            const SizedBox(height: 18),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sections.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.05,
              ),
              itemBuilder: (context, index) {
                final item = sections[index];
                return Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('قسم ${item.$1}: سيُنفذ في المرحلة التالية')),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(item.$3, size: 30, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(height: 12),
                          Text(item.$1, style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 5),
                          Text(item.$2, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
