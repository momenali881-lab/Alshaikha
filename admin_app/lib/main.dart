import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'glass_design.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'shared_store.dart';
import 'image_utils.dart';
import 'get_pronto_uploader.dart';
import 'iraq_locations.dart';
import 'analytics_screen.dart';
import 'notification_service.dart';
import 'shared/one_signal_service.dart';
import 'shared/one_signal_subscription_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.android);
  try {
    OneSignalService.initialize('5ccd4e96-a64c-4565-9ae5-964548bed976');
    OneSignalService.addNotificationClickListener(NotificationService.handleExternalTap);
  } catch (_) {
    // OneSignal is optional and must never block app startup.
  }
  try {
    await NotificationService.initialize();
  } catch (_) {
    // Push notifications are optional; never prevent the app from opening.
  }
  final themePrefs = await SharedPreferences.getInstance();
  final savedTheme = themePrefs.getString('admin_theme_mode');
  adminThemeMode.value = savedTheme == 'dark' ? ThemeMode.dark : savedTheme == 'light' ? ThemeMode.light : ThemeMode.system;
  runApp(const SheikhaAdminApp());
}

final ValueNotifier<ThemeMode> adminThemeMode = ValueNotifier<ThemeMode>(ThemeMode.system);

Future<void> setAdminThemeMode(ThemeMode mode) async {
  adminThemeMode.value = mode;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('admin_theme_mode', mode == ThemeMode.dark ? 'dark' : mode == ThemeMode.light ? 'light' : 'system');
}

const rose = Color(0xFFC49A55);
const plum = Color(0xFF59452F);
const cream = Color(0xFFF7F2E9);
const teal = Color(0xFF9C835D);
const gold = Color(0xFFD8B878);
const sections = <String,String>{'members':'الكادر','sessions':'أرشيف الجلسات','banners':'البانرات','bookings':'الحجوزات','messages':'الدردشة','announcements':'الإعلانات','analytics':'الإحصاءات'};
const sectionIcons=<String,IconData>{'members':Icons.groups_rounded,'sessions':Icons.photo_library_rounded,'banners':Icons.campaign_rounded,'bookings':Icons.event_available_rounded,'messages':Icons.forum_rounded,'announcements':Icons.notifications_active_rounded,'analytics':Icons.query_stats_rounded};
const sectionColors=<String,Color>{'members':teal,'sessions':plum,'banners':gold,'bookings':rose,'messages':Color(0xFF3F51B5),'announcements':teal,'analytics':Color(0xFF6A1B9A)};

class SheikhaAdminApp extends StatelessWidget {
  const SheikhaAdminApp({super.key});
  @override Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
    valueListenable: adminThemeMode,
    builder: (context, mode, _) => MaterialApp(
      debugShowCheckedModeBanner:false,
      title:'الشيخة - الإدارة',
      theme:GlassDesign.light,
      darkTheme:GlassDesign.dark,
      themeMode:mode,
      home:const OneSignalSubscriptionGate(child:AdminAuthGate()),
    ),
  );
}


Future<void> showAdminSetupInstructions(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('إعداد حساب الإدارة'),
        content: const SingleChildScrollView(
          child: Text(
            'يتم إنشاء حساب المدير الأول يدوياً مرة واحدة لتجنب خدمات Firebase المدفوعة:\n\n'
            '1. افتح Firebase Console ثم Authentication ثم Users وأضف مستخدماً جديداً.\n'
            '2. اجعل البريد بصيغة اسم_المستخدم@alshaikha.app، وحدد كلمة مرور.\n'
            '3. انسخ UID للمستخدم الجديد.\n'
            '4. افتح Firestore وأنشئ مجموعة profiles، ثم مستنداً يكون معرّفه هو UID نفسه.\n'
            '5. أضف الحقول: uid (String)، username (String)، displayName (String)، role (String وقيمته admin).\n'
            '6. احفظ المستند ثم سجّل الدخول هنا باسم المستخدم وكلمة المرور.\n\n'
            'لا تنشئ ملف المدير من التطبيق ولا تشارك كلمة المرور أو مفاتيح Secret.'
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('فهمت'))],
      ),
    ),
  );
}

String _adminAccountEmail(String username) => '${username.trim().toLowerCase()}@alshaikha.app';


class AdminAuthGate extends StatelessWidget {
 const AdminAuthGate({super.key});
 @override Widget build(BuildContext context)=>StreamBuilder<User?>(
  stream:FirebaseAuth.instance.authStateChanges(),
  builder:(context,snapshot){
   if(snapshot.connectionState==ConnectionState.waiting)return const Scaffold(body:Center(child:CircularProgressIndicator()));
   if(snapshot.data==null)return const AdminLoginScreen();
   return const AdminRoleCheck();
  });
}
class AdminRoleCheck extends StatefulWidget {
 const AdminRoleCheck({super.key});
 @override State<AdminRoleCheck> createState() => _AdminRoleCheckState();
}
class _AdminRoleCheckState extends State<AdminRoleCheck> {
 late Future<DocumentSnapshot<Map<String,dynamic>>> _profileFuture;

 Future<DocumentSnapshot<Map<String,dynamic>>> _loadProfile() {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw StateError('لا يوجد حساب مسجل');
  return FirebaseFirestore.instance.collection('profiles').doc(user.uid).get();
 }

 @override void initState() {
  super.initState();
  _profileFuture = _loadProfile();
 }

 @override Widget build(BuildContext context) => FutureBuilder<DocumentSnapshot<Map<String,dynamic>>>(
  future: _profileFuture,
  builder:(context,snapshot){
   if(snapshot.connectionState==ConnectionState.waiting) {
    return const Scaffold(body:Center(child:CircularProgressIndicator()));
   }
   if(snapshot.hasError) {
    return Scaffold(body:Center(child:Padding(
     padding:const EdgeInsets.all(24),
     child:Column(mainAxisSize:MainAxisSize.min,children:[
      const Text('تعذر الاتصال ببيانات الحساب. تحقق من الإنترنت ثم أعد المحاولة.'),
      const SizedBox(height:16),
      FilledButton(onPressed:()=>setState(()=>_profileFuture=_loadProfile()),child:const Text('إعادة المحاولة')),
     ]),
    )));
   }
   if(!snapshot.hasData || !snapshot.data!.exists || snapshot.data!.data()?['role']!='admin') {
    WidgetsBinding.instance.addPostFrameCallback((_) {
     if(mounted && FirebaseAuth.instance.currentUser!=null) {
      FirebaseAuth.instance.signOut();
     }
    });
    return const AdminLoginScreen(message:'هذا الحساب لا يملك صلاحية الإدارة');
   }
   return const AdminHome();
  });
}
class AdminLoginScreen extends StatefulWidget {
 final String? message;
 const AdminLoginScreen({super.key,this.message});
 @override State<AdminLoginScreen> createState()=>_AdminLoginScreenState();
}
class _AdminLoginScreenState extends State<AdminLoginScreen>{
 final username=TextEditingController(),password=TextEditingController();
 bool loading=false,obscure=true;String? error;
 @override void initState(){super.initState();error=widget.message;}
 @override void dispose(){username.dispose();password.dispose();super.dispose();}
 Future<void> submit()async{
   final u=username.text.trim().toLowerCase(),p=password.text;
   if(!RegExp(r'^[a-z0-9._]{3,24}$').hasMatch(u)||p.isEmpty){setState(()=>error='أدخل اسم المستخدم وكلمة المرور');return;}
   setState(() { loading=true; error=null; });
   try{
    final credential=await FirebaseAuth.instance.signInWithEmailAndPassword(email:_adminAccountEmail(u),password:p);
    final profile=await FirebaseFirestore.instance.collection('profiles').doc(credential.user!.uid).get();
    if(!profile.exists||profile.data()?['role']!='admin'){
     await FirebaseAuth.instance.signOut();
     throw FirebaseAuthException(code:'admin-required',message:'الحساب غير مخوّل للإدارة');
    }
   }on FirebaseAuthException catch(e){
    setState(()=>error=e.code=='admin-required'?'هذا الحساب لا يملك صلاحية الإدارة':e.code=='invalid-credential'?'اسم المستخدم أو كلمة المرور غير صحيحة':'تعذر تسجيل الدخول: ${e.message??e.code}');
   }catch(e){setState(()=>error='حدث خطأ: $e');}
   finally{if(mounted)setState(()=>loading=false);}
  }
  Future<void> createFirstAdmin() async {
    await showAdminSetupInstructions(context);
  }

  Future<bool> handleSystemBack() async {
    if(section!='members'||showChatConversation){
      setState((){section='members';showChatConversation=false;selectedConversationId=null;selectedBookingCustomerId=null;selectedBookingId=null;});
      await refresh();
      return false;
    }
    final now=DateTime.now();
    if(_lastBackPress==null||now.difference(_lastBackPress!)>const Duration(seconds:2)){
      _lastBackPress=now;
      note('اضغط زر الرجوع مرة أخرى للخروج');
      return false;
    }
    return true;
  }
  void selectAdminSection(String key){
    setState((){
      section=key;
      if(key!='bookings'){selectedBookingCustomerId=null;selectedBookingId=null;}
      if(key!='messages')showChatConversation=false;
    });
    if(key=='bookings')loadChatMembers();
    refresh();
  }
  Widget adminBottomBar(){
    final showAdd=section!='analytics'&&section!='messages';
    return SafeArea(top:false,child:Padding(padding:const EdgeInsets.fromLTRB(10,5,10,8),child:GlassPanel(radius:22,padding:const EdgeInsets.symmetric(horizontal:7,vertical:7),child:Row(children:[
      Expanded(child:SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(mainAxisSize:MainAxisSize.min,children:sections.entries.map((e){
        final active=section==e.key;
        return Padding(padding:const EdgeInsets.symmetric(horizontal:2),child:InkWell(borderRadius:BorderRadius.circular(14),onTap:()=>selectAdminSection(e.key),child:AnimatedContainer(duration:const Duration(milliseconds:200),padding:const EdgeInsets.symmetric(horizontal:9,vertical:8),decoration:BoxDecoration(gradient:active?const LinearGradient(colors:[Color(0xFFEAD8B5),Color(0xFFD2B47E)]):null,borderRadius:BorderRadius.circular(14)),child:Column(mainAxisSize:MainAxisSize.min,children:[
          Icon(sectionIcons[e.key],size:19,color:active?const Color(0xFF302719):sectionColors[e.key]),
          const SizedBox(height:3),
          Text(e.value,style:TextStyle(fontSize:9,fontWeight:FontWeight.w800,color:active?const Color(0xFF302719):sectionColors[e.key]),maxLines:1,overflow:TextOverflow.ellipsis),
        ]))));
      }).toList()))),
      if(showAdd)...[
        const SizedBox(width:6),
        SizedBox(width:104,height:48,child:FilledButton.icon(
          style:FilledButton.styleFrom(backgroundColor:gold,foregroundColor:const Color(0xFF302719),padding:const EdgeInsets.symmetric(horizontal:8),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(15))),
          onPressed:(){if(section!='members')setState(()=>section='members');edit();},
          icon:const Icon(Icons.person_add_alt_1_rounded,size:18),
          label:const Text('إضافة عضو',style:TextStyle(fontSize:11,fontWeight:FontWeight.w900)),
        )),
      ],
    ))));
  }
  @override Widget build(BuildContext context)=>Directionality(textDirection:TextDirection.rtl,child:WillPopScope(onWillPop:handleSystemBack,child:Scaffold(
    backgroundColor:Theme.of(context).scaffoldBackgroundColor,
    resizeToAvoidBottomInset:true,
    body:SafeArea(child:Column(children:[
      if(section!='messages')Padding(padding:const EdgeInsets.fromLTRB(12,6,12,7),child:Container(
        padding:const EdgeInsets.symmetric(horizontal:10,vertical:5),
        decoration:BoxDecoration(gradient:const LinearGradient(begin:Alignment.topRight,end:Alignment.bottomLeft,colors:[Color(0xFF30271D),Color(0xFF6C5433),Color(0xFF9A7845)]),borderRadius:BorderRadius.circular(20),border:Border.all(color:gold.withOpacity(.5)),boxShadow:[BoxShadow(color:Colors.black.withOpacity(.09),blurRadius:12,offset:const Offset(0,4))]),
        child:Row(children:[
          const Expanded(child:Text('إدارة الشيخة',style:TextStyle(color:Colors.white,fontSize:17,fontWeight:FontWeight.w900))),
          IconButton(visualDensity:VisualDensity.compact,constraints:const BoxConstraints.tightFor(width:36,height:36),tooltip:'الحسابات الإدارية',onPressed:()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>const AdminAccountsScreen())),icon:const Icon(Icons.admin_panel_settings_outlined,color:Colors.white,size:20)),
          Badge(isLabelVisible:notifications.any((n)=>n['read']!=true),label:Text('${notifications.where((n)=>n['read']!=true).length}'),child:IconButton(visualDensity:VisualDensity.compact,constraints:const BoxConstraints.tightFor(width:36,height:36),tooltip:'الإشعارات',onPressed:openNotifications,icon:const Icon(Icons.notifications_none_rounded,color:Colors.white,size:20))),
          IconButton(visualDensity:VisualDensity.compact,constraints:const BoxConstraints.tightFor(width:36,height:36),tooltip:'تبديل المظهر',onPressed:()=>setAdminThemeMode(Theme.of(context).brightness==Brightness.dark?ThemeMode.light:ThemeMode.dark),icon:Icon(Theme.of(context).brightness==Brightness.dark?Icons.light_mode_rounded:Icons.dark_mode_rounded,color:Colors.white,size:20)),
          IconButton(visualDensity:VisualDensity.compact,constraints:const BoxConstraints.tightFor(width:36,height:36),tooltip:'تحديث',onPressed:()=>refresh(),icon:const Icon(Icons.refresh_rounded,color:Colors.white,size:20)),
          IconButton(visualDensity:VisualDensity.compact,constraints:const BoxConstraints.tightFor(width:36,height:36),tooltip:'تسجيل الخروج',onPressed:()=>FirebaseAuth.instance.signOut(),icon:const Icon(Icons.logout_rounded,color:Colors.white,size:20)),
        ]),
      )),
      Expanded(child:section=='analytics'?const AdminAnalyticsScreen():section=='messages'?adminChat():section=='bookings'?adminBookingsPage():busy?const Center(child:CircularProgressIndicator()):RefreshIndicator(
        onRefresh:refresh,color:gold,child:ListView(padding:const EdgeInsets.fromLTRB(14,12,14,20),children:[
          GlassPanel(padding:const EdgeInsets.all(18),radius:24,child:Row(children:[
            Container(width:46,height:46,decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[gold.withOpacity(.32),gold.withOpacity(.10)]),borderRadius:BorderRadius.circular(16),border:Border.all(color:gold.withOpacity(.35))),child:Icon(sectionIcons[section]??Icons.dashboard_rounded,color:gold,size:25)),
            const SizedBox(width:13),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(sections[section]??'الإدارة',style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900)),
              Text('إدارة وتنظيم بيانات ${sections[section]??''}',style:TextStyle(fontSize:11,color:Theme.of(context).hintColor)),
            ])),
            Container(padding:const EdgeInsets.symmetric(horizontal:14,vertical:8),decoration:BoxDecoration(color:gold.withOpacity(.14),borderRadius:BorderRadius.circular(14),border:Border.all(color:gold.withOpacity(.28))),child:Text('${rows.length}',style:TextStyle(fontSize:21,fontWeight:FontWeight.w900,color:gold))),
          ])),
          const SizedBox(height:12),
          if(section=='banners'&&rows.length>=7)const Padding(padding:EdgeInsets.all(8),child:Text('وصلت إلى الحد الأقصى: 7 بانرات.')),
          if(rows.isEmpty)Container(padding:const EdgeInsets.all(24),decoration:BoxDecoration(color:Theme.of(context).cardColor,borderRadius:BorderRadius.circular(22),border:Border.all(color:gold.withOpacity(.2))),child:const Column(children:[Icon(Icons.inbox_rounded,size:42,color:Color(0xFFC49A55)),SizedBox(height:10),Text('لا توجد بيانات بعد',style:TextStyle(fontWeight:FontWeight.w800)),Text('استخدم زر إضافة سجل للبدء',style:TextStyle(fontSize:12,color:Colors.grey))])),
          ...rows.map(recordCard),
        ]))),
      if(!(section=='messages'&&showChatConversation))adminBottomBar(),
    ])),
  )));


}
