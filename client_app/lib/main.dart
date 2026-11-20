import 'package:flutter/material.dart';

void main() => runApp(const SheikhaClientApp());

class SheikhaClientApp extends StatelessWidget {
  const SheikhaClientApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'الشيخة',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFB77D91)),
        scaffoldBackgroundColor: const Color(0xFFFFF9F6),
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
      home: const ClientHome(),
    );
  }
}

class ClientHome extends StatefulWidget {
  const ClientHome({super.key});

  @override
  State<ClientHome> createState() => _ClientHomeState();
}

class _ClientHomeState extends State<ClientHome> {
  int selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            height: 180,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFB77D91), Color(0xFF80647F)],
              ),
              borderRadius: BorderRadius.circular(26),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('AL SHEIKHA MASSAGE CENTER',
                    style: TextStyle(color: Colors.white70)),
                SizedBox(height: 12),
                Text('الراحة تبدأ من هنا',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    )),
                Text('تصفح الكادر وتواصل مع الإدارة للحجز',
                    style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('الكادر', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const Card(child: ListTile(
            leading: Icon(Icons.spa_outlined),
            title: Text('سيظهر الكادر بعد ربط قاعدة البيانات'),
          )),
        ],
      ),
      const Center(child: Text('المفضلة ستظهر هنا')),
      const Center(child: Text('حجوزاتك ستظهر هنا')),
      const Center(child: Text('محادثاتك مع الإدارة ستظهر هنا')),
      const Center(child: Text('المزيد من الإعدادات')),
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الشيخة', style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('سيتم ربط البحث بالكادر في المرحلة التالية')),
              ),
              icon: const Icon(Icons.search),
            ),
            IconButton(
              onPressed: () => setState(() => selectedTab = 1),
              icon: const Icon(Icons.favorite_border),
            ),
          ],
        ),
        body: IndexedStack(index: selectedTab, children: pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedTab,
          onDestinationSelected: (value) => setState(() => selectedTab = value),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), label: 'الرئيسية'),
            NavigationDestination(icon: Icon(Icons.favorite_border), label: 'المفضلة'),
            NavigationDestination(icon: Icon(Icons.calendar_month_outlined), label: 'الحجوزات'),
            NavigationDestination(icon: Icon(Icons.chat_outlined), label: 'الدردشة'),
            NavigationDestination(icon: Icon(Icons.more_horiz), label: 'المزيد'),
          ],
        ),
      ),
    );
  }
}
