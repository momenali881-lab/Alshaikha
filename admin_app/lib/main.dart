import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'package:google_fonts/google_fonts.dart';
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
  runApp(const SheikhaAdminApp());
}

const rose = Color(0xFFE91E63);
const plum = Color(0xFF6A1B9A);
const cream = Color(0xFFFFF7FB);
const teal = Color(0xFF00A6A6);
const gold = Color(0xFFFFB300);
const sections = <String,String>{'members':'الكادر','sessions':'أرشيف الجلسات','banners':'البانرات','bookings':'الحجوزات','messages':'الدردشة','announcements':'الإعلانات','analytics':'الإحصاءات'};
const sectionIcons=<String,IconData>{'members':Icons.groups_rounded,'sessions':Icons.photo_library_rounded,'banners':Icons.campaign_rounded,'bookings':Icons.event_available_rounded,'messages':Icons.forum_rounded,'announcements':Icons.notifications_active_rounded,'analytics':Icons.query_stats_rounded};
const sectionColors=<String,Color>{'members':teal,'sessions':plum,'banners':gold,'bookings':rose,'messages':Color(0xFF3F51B5),'announcements':teal,'analytics':Color(0xFF6A1B9A)};

class SheikhaAdminApp extends StatelessWidget {
  const SheikhaAdminApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner:false, title:'الشيخة - الإدارة',
    theme:ThemeData(useMaterial3:true,colorScheme:ColorScheme.fromSeed(seedColor:plum,brightness:Brightness.light),scaffoldBackgroundColor:cream,textTheme:GoogleFonts.ibmPlexSansArabicTextTheme(),iconTheme:const IconThemeData(color:plum),inputDecorationTheme:InputDecorationTheme(filled:true,fillColor:Colors.white,border:OutlineInputBorder(borderRadius:BorderRadius.all(Radius.circular(14)))),appBarTheme:const AppBarTheme(backgroundColor:rose,foregroundColor:Colors.white,elevation:0),cardTheme:CardThemeData(color:Colors.white,elevation:2,shape:RoundedRectangleBorder(borderRadius:BorderRadius.all(Radius.circular(18)))),filledButtonTheme:FilledButtonThemeData(style:FilledButton.styleFrom(backgroundColor:rose,foregroundColor:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14)))),floatingActionButtonTheme:const FloatingActionButtonThemeData(backgroundColor:teal,foregroundColor:Colors.white)),
    darkTheme:ThemeData(useMaterial3:true,brightness:Brightness.dark,colorScheme:ColorScheme.fromSeed(seedColor:rose,brightness:Brightness.dark),textTheme:GoogleFonts.ibmPlexSansArabicTextTheme(ThemeData.dark().textTheme)),
    themeMode:ThemeMode.system, home:const OneSignalSubscriptionGate(child:AdminAuthGate()));
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

  @override Widget build(BuildContext context)=>Directionality(textDirection:TextDirection.rtl,child:Scaffold(body:SafeArea(child:Center(child:SingleChildScrollView(padding:const EdgeInsets.all(24),child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:420),child:Column(mainAxisSize:MainAxisSize.min,children:[
   const Icon(Icons.admin_panel_settings_rounded,size:68,color:plum),const SizedBox(height:12),
   const Text('الشيخة - الإدارة',style:TextStyle(fontSize:28,fontWeight:FontWeight.bold,color:plum)),
   const SizedBox(height:24),
   TextField(controller:username,autocorrect:false,decoration:const InputDecoration(labelText:'اسم المستخدم',prefixIcon:Icon(Icons.account_circle))),
   const SizedBox(height:12),
   TextField(controller:password,obscureText:obscure,decoration:InputDecoration(labelText:'كلمة المرور',prefixIcon:const Icon(Icons.lock),suffixIcon:IconButton(onPressed:()=>setState(()=>obscure=!obscure),icon:Icon(obscure?Icons.visibility:Icons.visibility_off)))),
   if(error!=null)Padding(padding:const EdgeInsets.only(top:12),child:Text(error!,style:const TextStyle(color:Colors.red))),
   const SizedBox(height:20),SizedBox(width:double.infinity,child:FilledButton(onPressed:loading?null:submit,child:loading?const CircularProgressIndicator():const Text('تسجيل الدخول'))),
   const SizedBox(height:14),
   SizedBox(width:double.infinity,child:OutlinedButton.icon(onPressed:loading?null:createFirstAdmin,icon:const Icon(Icons.info_outline),label:const Text('طريقة إنشاء أول حساب إداري'))),
   const SizedBox(height:8),const Text('لأمان الحسابات، تتم إضافة المديرين من وحدة تحكم Firebase فقط.',textAlign:TextAlign.center,style:TextStyle(fontSize:12,color:Colors.black54))
  ])))))));
}

class AdminAccountsScreen extends StatefulWidget {
  const AdminAccountsScreen({super.key});
  @override
  State<AdminAccountsScreen> createState() => _AdminAccountsScreenState();
}

class _AdminAccountsScreenState extends State<AdminAccountsScreen> {
  bool busy = false;

  Future<void> addAdmin() async => showAdminSetupInstructions(context);

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(flexibleSpace: const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.centerRight, end: Alignment.centerLeft, colors: [Color(0xFF3D126A), Color(0xFF6A1B9A), Color(0xFF914A9A)]))), backgroundColor: Colors.transparent, title: const Text('الحسابات الإدارية')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: busy ? null : addAdmin,
            icon: const Icon(Icons.info_outline),
            label: const Text('طريقة إضافة مدير'),
          ),
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('profiles')
                .where('role', isEqualTo: 'admin')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('تعذر تحميل الحسابات: ${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return const Center(child: Text('لا توجد حسابات إدارية'));
              }
              return ListView(
                children: docs.map((d) {
                  final data = d.data();
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.admin_panel_settings)),
                      title: Text('${data['displayName'] ?? data['username'] ?? 'مدير'}'),
                      subtitle: Text('@${data['username'] ?? ''}'),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
      );
}

class AdminHome extends StatefulWidget {
 const AdminHome({super.key});
 @override State<AdminHome> createState()=>_AdminHomeState();
}
class _AdminHomeState extends State<AdminHome> {
  bool fromChatBooking=false;
  bool showChatConversation=false;
  String section='members'; String? selectedConversationId; String? selectedBookingCustomerId; String? selectedBookingId; StreamSubscription<Map<String,dynamic>>? notificationTapSub; final Set<String> _seenNotificationIds=<String>{}; bool _notificationsInitialized=false; List<Map<String,dynamic>> rows=[]; List<Map<String,dynamic>> chatMembers=[]; List<Map<String,dynamic>> customerProfiles=[]; List<Map<String,dynamic>> notifications=[]; bool busy=true; Timer? poll; Timer? topNotificationTimer; final chatController=TextEditingController(); final FocusNode chatFocusNode=FocusNode(); final ScrollController adminChatScrollController=ScrollController();
  @override void initState(){super.initState();notificationTapSub=NotificationService.taps.listen((data)=>handleNotificationTap(data));WidgetsBinding.instance.addPostFrameCallback((_){final initial=NotificationService.takeInitialTap();if(initial!=null)handleNotificationTap(initial);});refresh();loadChatMembers();loadNotifications();poll=Timer.periodic(const Duration(seconds:5),(_){if(!(section=='messages'&&chatFocusNode.hasFocus))refresh(silent:true);loadNotifications();});}
  @override void dispose(){poll?.cancel();topNotificationTimer?.cancel();notificationTapSub?.cancel();chatController.dispose();chatFocusNode.dispose();adminChatScrollController.dispose();super.dispose();}
  void note(String s)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));
  void _showTopNotification(Map<String,dynamic> n){
    final messenger=ScaffoldMessenger.of(context);
    messenger.hideCurrentMaterialBanner();
    final customerId=(n['customerId']??n['createdBy']??'').toString();
    final matches=customerProfiles.where((p)=>p['id']?.toString()==customerId).toList();
    final avatar=(matches.isEmpty?'':(matches.first['avatarBase64']??'').toString());
    final avatarUrl=(matches.isEmpty?'':(matches.first['avatarUrl']??matches.first['photoUrl']??'').toString());
    Widget leading=const CircleAvatar(backgroundColor:Color(0xFFFFE4EF),child:Icon(Icons.person,color:rose));
    if(avatarUrl.startsWith('https://')){leading=CircleAvatar(backgroundImage:NetworkImage(avatarUrl));}
    else if(avatar.isNotEmpty){try{leading=CircleAvatar(backgroundImage:MemoryImage(base64Decode(avatar)));}catch(_){}}
    messenger.showMaterialBanner(MaterialBanner(
      backgroundColor:Colors.white,elevation:5,
      padding:const EdgeInsets.symmetric(horizontal:14,vertical:10),
      leading:leading,
      content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text((n['title']??'إشعار جديد').toString(),maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w800,color:plum)),
        Text((n['body']??'').toString(),maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.black87)),
      ]),
      actions:[TextButton(onPressed:(){messenger.hideCurrentMaterialBanner();openNotifications();},child:const Text('عرض'))],
    ));
    topNotificationTimer?.cancel();
    topNotificationTimer=Timer(const Duration(seconds:5),()=>messenger.hideCurrentMaterialBanner());
  }
  Future<void> loadChatMembers() async { try { chatMembers=await SharedStore.list('members'); } catch(_){} try { final snapshot=await FirebaseFirestore.instance.collection('profiles').where('role',isEqualTo:'customer').get(); customerProfiles=snapshot.docs.map((d)=>{'id':d.id,...d.data()}).toList(); } catch(_){} if(mounted)setState((){}); }
  String customerLabel(String id){final profile=customerProfiles.where((p)=>p['id']?.toString()==id).toList();if(profile.isNotEmpty)return (profile.first['displayName']??profile.first['username']??'عميل').toString();return 'عميل ${id.length>8?id.substring(0,8):id}';}
  String chatTime(dynamic value){final d=DateTime.tryParse(value?.toString()??'');if(d==null)return '';final now=DateTime.now();String two(int n)=>n.toString().padLeft(2,'0');if(d.year==now.year&&d.month==now.month&&d.day==now.day)return '${two(d.hour)}:${two(d.minute)}';return '${two(d.day)}/${two(d.month)}';}
  String chatPreview(Map<String,dynamic> m){if(m['type']=='memberProfile')return 'ملف عضو من الكادر';if(m['type']=='bookingCard')return 'بطاقة حجز';return (m['text']??'رسالة').toString();}
  Future<void> markConversationRead(String id)async{for(final n in notifications.where((n)=>n['createdBy']?.toString()==id&&n['read']!=true).toList()){try{await SharedStore.save('notifications',{...n,'read':true});}catch(_){}}await loadNotifications();}
  Future<void> loadNotifications()async{try{final all=await SharedStore.list('notifications');final items=all.where((n)=>n['target']=='admin').toList()..sort((a,b)=>'${b['createdAt']??''}'.compareTo('${a['createdAt']??''}'));final incoming=<Map<String,dynamic>>[];for(final item in items){final id=(item['id']??'').toString();if(id.isEmpty)continue;if(!_notificationsInitialized){_seenNotificationIds.add(id);}else if(_seenNotificationIds.add(id)){incoming.add(item);}}_notificationsInitialized=true;if(mounted){setState(()=>notifications=items);if(incoming.isNotEmpty){final latest=incoming.first;_showTopNotification(latest);}}}catch(_){}}
  Future<void> openCustomerChat(String customerId)async{
    if(customerId.isEmpty){note('لا يوجد حساب عميل مرتبط بهذا السجل');return;}
    setState(() {section='messages';selectedConversationId=customerId;showChatConversation=true;});
    await refresh();await markConversationRead(customerId);
  }
  Future<void> showBookingNotificationDetails(Map<String,dynamic> booking,String customerId)async{
    await showDialog<void>(context:context,builder:(ctx)=>Directionality(textDirection:TextDirection.rtl,child:AlertDialog(
      title:const Text('تفاصيل الحجز'),
      content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('العميل: ${booking['customerName']??customerLabel(customerId)}'),
        Text('عضو الكادر: ${booking['memberName']??'-'}'),
        Text('الموعد: ${booking['date']??'-'}'),
        Text('الحالة: ${booking['status']??'قيد المراجعة'}'),
        if((booking['notes']??'').toString().isNotEmpty)Text('ملاحظات: ${booking['notes']}')
      ]),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إغلاق')),
        FilledButton.icon(onPressed:(){Navigator.pop(ctx);openCustomerChat(customerId);},icon:const Icon(Icons.forum),label:const Text('فتح محادثة العميل'))
      ]
    )));
  }
  Future<void> handleNotificationTap(Map<String,dynamic> n)async{
    final notificationId=(n['notificationId']??n['id']??'').toString();
    if(notificationId.isNotEmpty){try{await SharedStore.save('notifications',{...n,'id':notificationId,'read':true});}catch(_){}}
    final type=(n['type']??'').toString();
    final customerId=(n['createdBy']??n['customerId']??n['conversationId']??'').toString();
    if(type=='message'){
      if(customerId.isEmpty){note('تعذر تحديد محادثة العميل لهذا الإشعار');return;}
      await openCustomerChat(customerId);
    }else if(type=='booking'){
      if(customerId.isEmpty){note('هذا الحجز غير مرتبط بحساب عميل');return;}
      setState(() {section='bookings';selectedBookingCustomerId=customerId;selectedBookingId=(n['bookingId']??'').toString();});
      await refresh();
      final found=rows.where((b)=>b['id']?.toString()==selectedBookingId).toList();
      if(found.isNotEmpty&&mounted)showBookingNotificationDetails(found.first,customerId);
    }else{
      setState(() {section='announcements';selectedBookingCustomerId=null;});
      await refresh();
    }
    await loadNotifications();
  }
  Future<void> openNotifications()async{
    await loadNotifications();if(!mounted)return;
    showModalBottomSheet(context:context,isScrollControlled:true,backgroundColor:cream,builder:(ctx)=>Directionality(textDirection:TextDirection.rtl,child:SafeArea(child:SizedBox(height:MediaQuery.of(ctx).size.height*.72,child:Column(children:[
      const Padding(padding:EdgeInsets.all(16),child:Text('الإشعارات',style:TextStyle(fontSize:21,fontWeight:FontWeight.bold))),
      Expanded(child:notifications.isEmpty?const Center(child:Text('لا توجد إشعارات حالياً')):ListView(children:notifications.map((n)=>ListTile(
        leading:Icon(n['type']=='booking'?Icons.event_available:n['type']=='message'?Icons.forum:Icons.notifications,color:rose),
        title:Text('${n['title']??'إشعار'}'),subtitle:Text('${n['body']??''}'),
        trailing:n['read']==true?const Icon(Icons.done,color:teal):const Icon(Icons.circle,color:rose,size:10),
        onTap:(){Navigator.pop(ctx);handleNotificationTap(n);}
      )).toList()))
    ])))));
  }

  Future<void> refresh({bool silent=false}) async {
    if(section=='analytics'){if(mounted)setState(()=>busy=false);return;}
    if(!silent && mounted)setState(()=>busy=true);
    try { final data=await SharedStore.list(section); if(mounted)setState(()=>rows=data); }
    catch(e){if(!silent&&mounted)note('تعذر تحميل البيانات: $e');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Map<String,String> fieldsFor(String s)=>switch(s){
    'members'=>{'name':'الاسم','age':'العمر','address':'العنوان','hourlyPrice':'سعر الساعة بالدينار','nightlyPrice':'سعر الليلة بالدينار','description':'نبذة وتعريف','hasPlace':'يوجد مكان؟','available':'متاح للحجز؟'},
    'sessions'=>{'title':'عنوان الجلسة','memberId':'معرّف عضو الكادر (اختياري)','date':'التاريخ','description':'الوصف'},
    'banners'=>{'title':'عنوان البانر','description':'النص الظاهر'},
    'announcements'=>{'title':'عنوان الإعلان','body':'نص الإعلان'},
    'bookings'=>{'customerName':'اسم العميل','phone':'رقم الهاتف','memberId':'العضو','date':'الموعد المطلوب','durationMinutes':'مدة الجلسة بالدقائق','notes':'ملاحظات','status':'الحالة'},
    _=>{'conversationId':'رقم المحادثة','sender':'المرسل','text':'نص الرسالة','createdAt':'وقت الإرسال'}
  };
  Future<List<String>> pickImages([List<String> existing=const[]]) async {
    final picker=ImagePicker();
    final files=await picker.pickMultiImage(imageQuality:72,maxWidth:1500);
    if(files.isEmpty)return existing;
    final out=[...existing];
    for(final f in files.take(10-existing.length)){
      try {
        out.add(await GetProntoUploader.upload(f));
      } catch (e) {
        note('تعذر رفع الصورة ${f.name}: $e');
        break;
      }
    }
    return out;
  }
  Future<void> edit([Map<String,dynamic>? old]) async {
    if(section=='banners'&&old==null&&rows.length>=7){note('وصلت إلى الحد الأقصى: 7 بانرات.');return;}
    final fields=fieldsFor(section); final ctrls=<String,TextEditingController>{};
    for(final e in fields.entries){if(section=='members'&&e.key=='address')continue;ctrls[e.key]=TextEditingController(text:'${old?[e.key]??''}');}if(section=='bookings'&&old==null)ctrls['durationMinutes']!.text='60';
    final landmark=TextEditingController(text:'${old?['landmark']??''}');
    final areaName=TextEditingController(text:'${old?['area']??old?['district']??''}');
    String? selectedProvince=old?['province']?.toString(),selectedArea=old?['area']?.toString()??old?['district']?.toString(),selectedLandmark=old?['landmark']?.toString();
    if(selectedArea!=null&&selectedArea!.trim().isEmpty)selectedArea=null;
    if(selectedLandmark!=null&&!((iraqVerifiedLandmarks[selectedProvince]??const <String>[]).contains(selectedLandmark)))selectedLandmark=null;
    List<String> liveLandmarks=[];bool loadingLandmarks=false;List<String> liveAreas=[];bool loadingAreas=false;
    final bookingMembers=section=='bookings'?await SharedStore.list('members'):<Map<String,dynamic>>[];
    final bannerMembers=section=='banners'?await SharedStore.list('members'):<Map<String,dynamic>>[];
    final bannerSessions=section=='banners'?await SharedStore.list('sessions'):<Map<String,dynamic>>[];
    final sessionMembers=section=='sessions'?await SharedStore.list('members'):<Map<String,dynamic>>[];
    String? sessionMemberId=old?['memberId']?.toString();
    DateTime? sessionDate=DateTime.tryParse('${old?['date']??''}');
    String? linkedMemberId=old?['linkedMemberId']?.toString();
    String? linkedSessionId=old?['linkedSessionId']?.toString();
    String? selectedMemberId=old?['memberId']?.toString()??(bookingMembers.isNotEmpty?bookingMembers.first['id']?.toString():null);
    String? selectedCustomerId=old?['customerId']?.toString()??(fromChatBooking?selectedConversationId:null);
    DateTime? bookingDate=DateTime.tryParse('${old?['date']??''}');
    bool available=old?['available']!=false, hasPlace=old == null || old['hasPlace']==true, active=old?['active']!=false;
    List<String> images=List<String>.from(old?['images']??[]);
    final result=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,ds)=>AlertDialog(
      title:Text(old==null?'إضافة ${sections[section]}':'تعديل ${sections[section]}'),
      content:SizedBox(width:460,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        ...fields.entries.where((e)=>!['available','hasPlace','memberId','date'].contains(e.key)&&!(section=='members'&&e.key=='address')).map((e)=>Padding(padding:const EdgeInsets.only(bottom:10),child:TextField(controller:ctrls[e.key],scrollPadding:const EdgeInsets.only(bottom:180),maxLines:['description','notes','text','address'].contains(e.key)?3:1,keyboardType:['age','hourlyPrice','nightlyPrice','durationMinutes'].contains(e.key)?TextInputType.number:TextInputType.text,decoration:InputDecoration(labelText:e.value,border:const OutlineInputBorder())))),
        if(section=='sessions')...[
          DropdownButtonFormField<String>(value:sessionMembers.any((m)=>m['id']?.toString()==sessionMemberId)?sessionMemberId:'',decoration:const InputDecoration(labelText:'ربط الجلسة بعضو الكادر (اختياري)',border:OutlineInputBorder()),items:[const DropdownMenuItem<String>(value:'',child:Text('بدون ربط')), ...sessionMembers.map((m)=>DropdownMenuItem<String>(value:m['id'].toString(),child:Text('${m['name']??'عضو'}')))],onChanged:(v)=>ds(()=>sessionMemberId=v)),
          const SizedBox(height:10),
          OutlinedButton.icon(onPressed:()async{final d=await showDatePicker(context:ctx,initialDate:sessionDate??DateTime.now(),firstDate:DateTime(2000),lastDate:DateTime(2100));if(d!=null)ds(()=>sessionDate=DateTime(d.year,d.month,d.day));},icon:const Icon(Icons.calendar_month),label:Text(sessionDate==null?'تحديد تاريخ الجلسة':'${sessionDate!.year}/${sessionDate!.month}/${sessionDate!.day}')),
        ],
        if(section=='bookings')...[
          if(customerProfiles.isNotEmpty)DropdownButtonFormField<String>(value:customerProfiles.any((p)=>p['id']?.toString()==selectedCustomerId)?selectedCustomerId:null,decoration:const InputDecoration(labelText:'ربط الحجز بحساب العميل',border:OutlineInputBorder()),items:customerProfiles.map((p)=>DropdownMenuItem<String>(value:p['id'].toString(),child:Text('${p['displayName']??p['username']??'عميل'}'))).toList(),onChanged:(v)=>ds(()=>selectedCustomerId=v)),
          const SizedBox(height:10),
          DropdownButtonFormField<String>(value:bookingMembers.any((m)=>m['id']?.toString()==selectedMemberId)?selectedMemberId:null,decoration:const InputDecoration(labelText:'اختيار عضو الكادر',border:OutlineInputBorder()),items:bookingMembers.map((m)=>DropdownMenuItem<String>(value:m['id'].toString(),child:Row(children:[if((m['images'] as List? ?? []).isNotEmpty)ClipRRect(borderRadius:BorderRadius.circular(6),child:appImage((m['images'] as List).first,width:30,height:30,fit:BoxFit.cover)),const SizedBox(width:8),Text('${m['name']??'عضو'}')]))).toList(),onChanged:(v)=>ds(()=>selectedMemberId=v)),
          const SizedBox(height:10),
          OutlinedButton.icon(onPressed:()async{final d=await showDatePicker(context:ctx,initialDate:bookingDate??DateTime.now().add(const Duration(days:1)),firstDate:DateTime.now(),lastDate:DateTime.now().add(const Duration(days:365)));if(d!=null)ds(()=>bookingDate=DateTime(d.year,d.month,d.day,bookingDate?.hour??12,bookingDate?.minute??0));},icon:const Icon(Icons.calendar_month),label:Text(bookingDate==null?'تحديد تاريخ الحجز':'${bookingDate!.year}/${bookingDate!.month}/${bookingDate!.day}')),
          OutlinedButton.icon(onPressed:()async{final t=await showTimePicker(context:ctx,initialTime:TimeOfDay.fromDateTime(bookingDate??DateTime.now()));if(t!=null)ds(()=>bookingDate=DateTime(bookingDate?.year??DateTime.now().year,bookingDate?.month??DateTime.now().month,bookingDate?.day??DateTime.now().day,t.hour,t.minute));},icon:const Icon(Icons.schedule),label:Text(bookingDate==null?'تحديد وقت الحجز':TimeOfDay.fromDateTime(bookingDate!).format(ctx))),
          if(bookingMembers.isEmpty)const Text('أضف أعضاء الكادر أولاً لتتمكن من ربط الحجز بعضو.'),
        ],
        if(section=='members')...[
          const Align(alignment:Alignment.centerRight,child:Padding(padding:EdgeInsets.only(top:6,bottom:8),child:Text('عنوان العضو داخل العراق',style:TextStyle(fontWeight:FontWeight.bold,fontSize:16)))),
          DropdownButtonFormField<String>(value:iraqGovernorates.containsKey(selectedProvince)?selectedProvince:null,decoration:const InputDecoration(labelText:'المحافظة',border:OutlineInputBorder(),prefixIcon:Icon(Icons.location_city)),items:iraqGovernorates.keys.map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),onChanged:(v)=>ds((){selectedProvince=v;selectedArea=null;areaName.clear();selectedLandmark=null;liveLandmarks=[];liveAreas=[];})),
          const SizedBox(height:9),
          DropdownButtonFormField<String>(value:(<String>{...iraqAreaChoices(selectedProvince),...liveAreas}).contains(selectedArea)?selectedArea:null,decoration:const InputDecoration(labelText:'المنطقة',border:OutlineInputBorder(),prefixIcon:Icon(Icons.map_outlined)),items:(<String>{...iraqAreaChoices(selectedProvince),...liveAreas}.toList()..sort((a,b)=>a.compareTo(b))).map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),onChanged:selectedProvince==null?null:(v)=>ds((){selectedArea=v;areaName.text=v??'';})),
          const SizedBox(height:8),
          TextField(controller:areaName,decoration:const InputDecoration(labelText:'أو اكتب اسم المنطقة إذا لم تظهر بالقائمة',border:OutlineInputBorder(),prefixIcon:Icon(Icons.edit_location_alt)),onChanged:(v)=>ds(()=>selectedArea=v.trim().isEmpty?null:v.trim())),
          OutlinedButton.icon(onPressed:selectedProvince==null||loadingAreas?null:()async{ds(()=>loadingAreas=true);final found=await searchRealAreas(selectedProvince!);if(!mounted)return;ds((){liveAreas=found;loadingAreas=false;});note(found.isEmpty?'لم تُرجع مصادر الخرائط مناطق إضافية حالياً. يمكنك كتابة اسم المنطقة يدوياً.':'تم العثور على ${found.length} منطقة إضافية من الخرائط المفتوحة');},icon:loadingAreas?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.travel_explore),label:Text(loadingAreas?'جارٍ جلب المناطق...':'جلب مناطق إضافية من الخرائط المجانية')),
          const SizedBox(height:9),
          DropdownButtonFormField<String>(value:selectedLandmark,decoration:const InputDecoration(labelText:'النقطة الدالة',border:OutlineInputBorder(),prefixIcon:Icon(Icons.place_outlined)),items:<String>{...(iraqVerifiedLandmarks[selectedProvince]??const <String>[]),...liveLandmarks}.toList().map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),onChanged:selectedProvince==null?null:(v)=>ds((){selectedLandmark=v;landmark.clear();})),
          OutlinedButton.icon(onPressed:selectedProvince==null||selectedArea==null||loadingLandmarks?null:()async{ds(()=>loadingLandmarks=true);final found=await searchRealLandmarks(selectedProvince!,selectedArea!);if(!mounted)return;ds((){liveLandmarks=found;loadingLandmarks=false;if(found.isNotEmpty)selectedLandmark=found.first;});note(found.isEmpty?'لم يعثر OpenStreetMap على نقاط مسماة داخل هذه المنطقة. لا توجد أسماء مختلقة.':'تم العثور على ${found.length} نقطة دالة مسماة داخل المنطقة');},icon:loadingLandmarks?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.travel_explore),label:Text(loadingLandmarks?'جارٍ البحث عن نقاط حقيقية...':'جلب نقاط دالة حقيقية داخل المنطقة من OpenStreetMap')),
          const Align(alignment:Alignment.centerRight,child:Text('المصدر: OpenStreetMap contributors. النتائج مرتبطة بالمنطقة المختارة وقد تختلف حسب تغطية الخرائط.',style:TextStyle(fontSize:11,color:Colors.black54))),
          const SizedBox(height:6),
          const Align(alignment:Alignment.centerRight,child:Text('تُعرض الأسماء المتاحة من قاعدة المعالم والمرافق المسماة. إذا لم يظهر معلم منطقتك، اكتب اسمه الكامل كما هو معروف محلياً.',style:TextStyle(fontSize:12,color:Colors.black54))),
          TextField(controller:landmark,decoration:const InputDecoration(labelText:'اسم النقطة الدالة الكامل (عند عدم وجودها بالقائمة)',hintText:'اكتب الاسم الحقيقي المعروف في المنطقة',border:OutlineInputBorder())),
        ],
        if(section=='members')...[
          SwitchListTile(value:hasPlace,onChanged:(v)=>ds(()=>hasPlace=v),title:const Text('يوجد مكان')),
          SwitchListTile(value:available,onChanged:(v)=>ds(()=>available=v),title:const Text('متاح للحجز')),
        ],
        if(section=='banners')SwitchListTile(value:active,onChanged:(v)=>ds(()=>active=v),title:const Text('عرض البانر للعملاء')),
        if(section=='banners')...[
          DropdownButtonFormField<String>(value:bannerMembers.any((m)=>m['id']?.toString()==linkedMemberId)?linkedMemberId:'',decoration:const InputDecoration(labelText:'ربط البانر بملف عضو (اختياري)'),items:[const DropdownMenuItem<String>(value:'',child:Text('بدون ربط')), ...bannerMembers.map((m)=>DropdownMenuItem<String>(value:m['id'].toString(),child:Text('${m['name']??'عضو'}')))],onChanged:(v)=>ds((){linkedMemberId=v;if(v!=null&&v.isNotEmpty)linkedSessionId=null;})),
          const SizedBox(height:8),
          DropdownButtonFormField<String>(value:bannerSessions.any((x)=>x['id']?.toString()==linkedSessionId)?linkedSessionId:'',decoration:const InputDecoration(labelText:'أو ربط البانر بجلسة (اختياري)'),items:[const DropdownMenuItem<String>(value:'',child:Text('بدون ربط بجلسة')), ...bannerSessions.map((x)=>DropdownMenuItem<String>(value:x['id'].toString(),child:Text('${x['title']??'جلسة'}')))],onChanged:(v)=>ds((){linkedSessionId=v;if(v!=null&&v.isNotEmpty)linkedMemberId=null;})),
          const SizedBox(height:8),
        ],
        if(['members','sessions','banners','announcements'].contains(section))...[
          Align(alignment:Alignment.centerRight,child:Text('الصور ${images.length}/10')),
          Wrap(spacing:6,children:images.asMap().entries.map((e)=>Stack(children:[
            ClipRRect(borderRadius:BorderRadius.circular(8),child:appImage(e.value,width:62,height:62,fit:BoxFit.cover)),
            Positioned(right:0,top:0,child:InkWell(onTap:()=>ds(()=>images.removeAt(e.key)),child:const CircleAvatar(radius:10,child:Icon(Icons.close,size:12))))
          ])).toList()),
          OutlinedButton.icon(onPressed:images.length>=10?null:()async{final v=await pickImages(images);ds(()=>images=v);},icon:const Icon(Icons.add_photo_alternate),label:const Text('اختيار صور من الهاتف')),
        ]
      ]))),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('حفظ'))],
    )));
    if(result==true){
      final data=<String,dynamic>{'id':old?['id'],'customerId':selectedCustomerId};
      for(final key in fields.keys){if(key=='available'||key=='hasPlace'||(section=='members'&&key=='address'))continue;if(section=='bookings'&&key=='memberId'){data[key]=selectedMemberId;continue;}if(section=='bookings'&&key=='date'){data[key]=bookingDate?.toIso8601String()??'';continue;}final v=ctrls[key]!.text.trim();data[key]=(key=='age'||key=='durationMinutes')?int.tryParse(v)??0:(key=='hourlyPrice'||key=='nightlyPrice')?double.tryParse(v)??0:v;}
      if(section=='bookings'){final chosen=bookingMembers.where((m)=>m['id']?.toString()==selectedMemberId).toList();data['memberName']=chosen.isEmpty?'':chosen.first['name'];final customer=customerProfiles.where((p)=>p['id']?.toString()==selectedCustomerId).toList();if(customer.isNotEmpty){data['customerId']=selectedCustomerId;if((data['customerName']??'').toString().trim().isEmpty)data['customerName']=customer.first['displayName']??customer.first['username']??'عميل';}}
      if(section=='sessions'){final chosen=sessionMembers.where((m)=>m['id']?.toString()==sessionMemberId).toList();data['memberId']=sessionMemberId==null||sessionMemberId!.isEmpty?null:sessionMemberId;data['memberName']=chosen.isEmpty?'':chosen.first['name'];data['date']=sessionDate?.toIso8601String()??'';}
      if(section=='members'){data['available']=available;data['hasPlace']=hasPlace;data['province']=selectedProvince??'';data['area']=areaName.text.trim();data['district']=areaName.text.trim();data['neighborhood']='';data['landmark']=landmark.text.trim().isNotEmpty?landmark.text.trim():(selectedLandmark??'');data['landmarkSource']=landmark.text.trim().isNotEmpty?'user-entered':'reference-dataset';data['address']=[selectedProvince,areaName.text.trim(),data['landmark']].where((v)=>v!=null&&v.toString().trim().isNotEmpty).join('، ');}
      if(section=='banners')data['active']=active;
      if(['members','sessions','banners','announcements'].contains(section))data['images']=images;
      if(section=='banners'){data['linkedMemberId']=(linkedMemberId==null||linkedMemberId!.isEmpty)?null:linkedMemberId;data['linkedSessionId']=(linkedSessionId==null||linkedSessionId!.isEmpty)?null:linkedSessionId;data['targetType']=data['linkedMemberId']!=null?'member':data['linkedSessionId']!=null?'session':'none';data['targetId']=data['linkedMemberId']??data['linkedSessionId'];}
      if(section=='announcements'){data['createdAt']=DateTime.now().toIso8601String();}
      if(section=='members'&&(selectedProvince==null||areaName.text.trim().isEmpty||(selectedLandmark==null&&landmark.text.trim().isEmpty))){note('اختر المحافظة والمنطقة وحدد نقطة دالة حقيقية أو اكتب اسمها الكامل');}else if(section=='bookings'&&(selectedMemberId==null||bookingDate==null||(ctrls['customerName']!.text.trim().isEmpty&&selectedCustomerId==null))){note('اكتب اسم العميل واختر عضو الكادر وحدد تاريخ ووقت الحجز');}else if(section=='sessions'&&(ctrls['title']!.text.trim().isEmpty||sessionDate==null)){note('اكتب عنوان الجلسة وحدد تاريخها');}else try{final savedId=await SharedStore.save(section,data);if(section=='bookings'&&fromChatBooking&&selectedConversationId!=null){await SharedStore.save('messages',{'conversationId':selectedConversationId,'senderId':FirebaseAuth.instance.currentUser?.uid,'sender':'الإدارة','type':'bookingCard','bookingId':savedId,'customerName':data['customerName'],'memberId':data['memberId'],'memberName':data['memberName'],'date':data['date'],'durationMinutes':data['durationMinutes']??60,'notes':data['notes']??'','status':data['status']??'قيد المراجعة','text':'تم إنشاء بطاقة حجز','createdAt':DateTime.now().toIso8601String()});}if(section=='announcements'){await SharedStore.save('notifications',{'target':'all','type':'announcement','title':data['title']??'إعلان جديد','body':data['body']??'','createdAt':DateTime.now().toIso8601String(),'read':false});}if(section=='bookings'&&data['customerId']!=null){await SharedStore.save('notifications',{'target':'customer','customerId':data['customerId'],'conversationId':data['customerId'],'type':'booking','title':'تم تسجيل حجزك','senderName':'الإدارة','body':'الموعد: ${data['date']} مع ${data['memberName']??''} لمدة ${data['durationMinutes']??60} دقيقة','createdAt':DateTime.now().toIso8601String(),'read':false,'bookingId':savedId});}await refresh();note('تم الحفظ بنجاح');}catch(e){note('فشل الحفظ: $e');}
    }
    for(final c in ctrls.values){c.dispose();}landmark.dispose();areaName.dispose();
  }
  Future<void> remove(Map<String,dynamic> item) async {
    final yes=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('حذف السجل؟'),content:const Text('لا يمكن التراجع عن الحذف.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('حذف'))]));
    if(yes==true){await SharedStore.delete(section,item['id']);await refresh();}
  }
  Future<void> updateBooking(Map<String,dynamic> b,String status)async{
    if((b['status']??'قيد المراجعة')!=status){
      final d={...b,'status':status};
      await SharedStore.save('bookings',d);
      final cancelled=status.contains('إلغاء')||status.contains('ملغ')||status.contains('رفض');
      final confirmed=status.contains('تأكيد')||status.contains('مؤكد')||status.contains('مقبول');
      final title=cancelled?'تم إلغاء الحجز':confirmed?'تم تأكيد الحجز':'تحديث حالة الحجز';
      final body=cancelled?'نعتذر، تم إلغاء حجزك مع ${b['memberName']??''}':confirmed?'تم تأكيد حجزك مع ${b['memberName']??''} في الموعد المحدد':'حالة حجزك مع ${b['memberName']??''}: $status';
      await SharedStore.save('notifications',{'target':'customer','customerId':b['customerId'],'conversationId':b['customerId'],'type':'booking','title':title,'senderName':'الإدارة','body':body,'createdAt':DateTime.now().toIso8601String(),'read':false,'bookingId':b['id'],'bookingStatus':status});
    }
    await refresh();
  }
  Widget adminBookingsPage(){
    final grouped=<String,List<Map<String,dynamic>>>{};
    for(final booking in rows){
      final raw=(booking['customerId']??'').toString().trim();
      final key=raw.isNotEmpty?raw:'legacy:${booking['customerName']??'عميل'}:${booking['phone']??''}';
      (grouped[key]??=<Map<String,dynamic>>[]).add(booking);
    }
    if(selectedBookingCustomerId==null){
      final ids=grouped.keys.toList()..sort((x,y){
        String latest(String id){final list=grouped[id]!..sort((p,q)=>(p['date']?.toString()??'').compareTo(q['date']?.toString()??''));return list.last['date']?.toString()??'';}
        return latest(y).compareTo(latest(x));
      });
      return ListView(padding:const EdgeInsets.all(12),children:[
        const Padding(padding:EdgeInsets.symmetric(horizontal:6,vertical:8),child:Text('حسابات العملاء الذين لديهم حجوزات',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold))),
        if(ids.isEmpty)const Center(child:Padding(padding:EdgeInsets.all(28),child:Text('لا توجد حجوزات مرتبطة بحسابات العملاء بعد'))),
        ...ids.map((id){
          final items=grouped[id]!..sort((x,y)=>(y['date']?.toString()??'').compareTo(x['date']?.toString()??''));
          final legacy=id.startsWith('legacy:');
          final title=legacy?(items.first['customerName']??'عميل').toString():customerLabel(id);
          return Card(child:ListTile(
            leading:CircleAvatar(backgroundColor:rose.withOpacity(.12),child:const Icon(Icons.person,color:rose)),
            title:Text(title,style:const TextStyle(fontWeight:FontWeight.bold)),
            subtitle:Text('${items.length} حجز • آخر موعد: ${items.first['date']??'-'}'),
            trailing:const Icon(Icons.chevron_left),
            onTap:()=>setState(()=>selectedBookingCustomerId=id)
          ));
        })
      ]);
    }
    final customerId=selectedBookingCustomerId!;
    final items=grouped[customerId]??<Map<String,dynamic>>[];
    final legacy=customerId.startsWith('legacy:');
    final title=legacy?(items.isEmpty?'عميل':items.first['customerName']??'عميل'):customerLabel(customerId);
    return ListView(padding:const EdgeInsets.all(12),children:[
      ListTile(contentPadding:EdgeInsets.zero,leading:IconButton(onPressed:()=>setState(() {selectedBookingCustomerId=null;selectedBookingId=null;}),icon:const Icon(Icons.arrow_back,color:rose)),title:Text('$title',style:const TextStyle(fontSize:19,fontWeight:FontWeight.bold)),subtitle:Text('${items.length} حجز مرتبط بهذا الحساب')),
      const Divider(),
      if(items.isEmpty)const Text('لا توجد حجوزات لهذا العميل'),
      ...items.map((booking)=>Card(
        color:booking['id']?.toString()==selectedBookingId?const Color(0xFFFFE4EF):Colors.white,
        child:ListTile(
          leading:const CircleAvatar(backgroundColor:Color(0xFFFFE4EF),child:Icon(Icons.event_available,color:rose)),
          title:Text('${booking['memberName']??'حجز'}',style:const TextStyle(fontWeight:FontWeight.bold)),
          subtitle:Text('${booking['date']??''} • ${booking['status']??'قيد المراجعة'}'),
          trailing:Row(mainAxisSize:MainAxisSize.min,children:[
            IconButton(tooltip:'فتح محادثة العميل',onPressed:()=>legacy?note('هذا الحجز قديم ولا يرتبط بمعرّف حساب عميل'):openCustomerChat(customerId),icon:const Icon(Icons.forum_outlined,color:plum)),
            PopupMenuButton<String>(tooltip:'إجراءات الحجز',onSelected:(action){if(action=='accept')updateBooking(booking,'مؤكد');else if(action=='reject')updateBooking(booking,'مرفوض');else if(action=='delete')remove(booking);else if(action=='edit')edit(booking);},itemBuilder:(_)=>[
              if((booking['status']??'قيد المراجعة')!='مؤكد')const PopupMenuItem(value:'accept',child:Text('تأكيد الحجز')),
              if((booking['status']??'قيد المراجعة')!='مرفوض')const PopupMenuItem(value:'reject',child:Text('رفض الحجز')),
              const PopupMenuItem(value:'edit',child:Text('تعديل الحجز')),
              const PopupMenuItem(value:'delete',child:Text('إزالة الحجز')),
            ]),
          ]),
          onTap:()=>legacy?note('هذا الحجز قديم ولا يرتبط بمعرّف حساب عميل، لذلك لا يمكن فتح محادثة له'):openCustomerChat(customerId)
        )
      ))
    ]);
  }
  Widget recordCard(Map<String,dynamic> m){
    final title=m['name']??m['title']??m['customerName']??m['sender']??'سجل';
    final subtitle=[m['description'],m['date'],m['status'],if(section=='bookings'&&m['address']!=null)m['address'],if(section=='members')'${m['hourlyPrice']??0} د.ع/ساعة',if(section=='members')'${m['nightlyPrice']??0} د.ع/ليلة'].where((x)=>x!=null&&x.toString().isNotEmpty).join(' • ');
    final imgs=List<String>.from(m['images']??[]);
    return Card(child:Padding(padding:const EdgeInsets.all(8),child:Column(children:[
      ListTile(leading:imgs.isNotEmpty?ClipRRect(borderRadius:BorderRadius.circular(8),child:appImage(imgs.first,width:52,height:52,fit:BoxFit.cover)):const CircleAvatar(child:Icon(Icons.spa)),title:Text('$title'),subtitle:Text(subtitle),trailing:PopupMenuButton<String>(onSelected:(v){if(v=='edit')edit(m);else if(v=='delete')remove(m);else if(v=='accept')updateBooking(m,'مؤكد');else updateBooking(m,'مرفوض');},itemBuilder:(_)=>[
        if(section=='bookings')const PopupMenuItem(value:'accept',child:Text('تأكيد الحجز')),
        if(section=='bookings')const PopupMenuItem(value:'reject',child:Text('رفض الحجز')),
        const PopupMenuItem(value:'edit',child:Text('تعديل')),
        const PopupMenuItem(value:'delete',child:Text('حذف')),
      ])),
      if(section=='messages')Align(alignment:Alignment.centerRight,child:Text('المحادثة: ${m['conversationId']??'-'}')),
      if(section=='bookings'&&(m['address']??'').toString().isNotEmpty)Align(alignment:Alignment.centerRight,child:Padding(padding:const EdgeInsets.symmetric(horizontal:12,vertical:6),child:Text('العنوان: ${m['address']}',style:const TextStyle(color:plum)))),
    ])));
  }
  Future<void> shareMemberProfile() async {
    chatMembers=await SharedStore.list('members');
    if(chatMembers.isEmpty){note('أضف أعضاء الكادر أولاً');return;}
    final chosen=await showModalBottomSheet<Map<String,dynamic>>(context:context,isScrollControlled:true,builder:(ctx)=>Directionality(textDirection:TextDirection.rtl,child:SafeArea(child:ListView(shrinkWrap:true,children:[const Padding(padding:EdgeInsets.all(16),child:Text('اختر ملف العضو لإرساله للعميل',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold))),...chatMembers.map((m){final imgs=List<String>.from(m['images']??[]);Widget avatar=const CircleAvatar(child:Icon(Icons.spa));if(imgs.isNotEmpty){try{avatar=ClipRRect(borderRadius:BorderRadius.circular(9),child:appImage(imgs.first,width:48,height:48,fit:BoxFit.cover));}catch(_){}}return ListTile(leading:avatar,title:Text('${m['name']??'عضو'}'),subtitle:const Text('إرسال بطاقة الملف الشخصي'),onTap:()=>Navigator.pop(ctx,m));})]))));
    if(chosen==null)return;
    if(selectedConversationId==null){note('اختر محادثة العميل أولاً');return;}
    await SharedStore.save('messages',{'conversationId':selectedConversationId,'senderId':FirebaseAuth.instance.currentUser?.uid,'sender':'الإدارة','type':'memberProfile','memberId':chosen['id'],'memberName':chosen['name'],'text':'ملف العضو: ${chosen['name']}','createdAt':DateTime.now().toIso8601String()});
    await SharedStore.save('notifications',{'target':'customer','customerId':selectedConversationId,'conversationId':selectedConversationId,'type':'message','title':'رسالة جديدة من الإدارة','body':'تم إرسال ملف العضو ${chosen['name']}','createdAt':DateTime.now().toIso8601String(),'read':false});
    await refresh(silent:true);note('تم إرسال ملف العضو للعميل');
  }
  Map<String,dynamic>? findChatMember(dynamic id){for(final member in chatMembers){if(member['id']==id)return member;}return null;}
  void openSharedMember(Map<String,dynamic> member){showDialog(context:context,builder:(ctx)=>Directionality(textDirection:TextDirection.rtl,child:AlertDialog(title:Text('${member['name']??'ملف العضو'}'),content:SizedBox(width:360,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[if((member['images'] as List? ?? []).isNotEmpty)ClipRRect(borderRadius:BorderRadius.circular(14),child:appImage((member['images'] as List).first,height:180,fit:BoxFit.cover)),ListTile(title:const Text('العمر'),subtitle:Text('${member['age']??'-'}')),ListTile(title:const Text('سعر الساعة'),subtitle:Text('${member['hourlyPrice']??0} د.ع')),ListTile(title:const Text('سعر الليلة'),subtitle:Text('${member['nightlyPrice']??0} د.ع')),if((member['description']??'').toString().isNotEmpty)Text('${member['description']}')]))),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إغلاق'))])));}
  Widget adminMessageBubble(Map<String,dynamic> m){
    final mine=m['sender']=='الإدارة';
    final member=m['type']=='memberProfile'?findChatMember(m['memberId']):null;
    Widget? bookingCard;
    if(m['type']=='bookingCard'){bookingCard=Card(color:Colors.white,child:Padding(padding:const EdgeInsets.all(10),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Row(children:[Icon(Icons.event_available,color:teal),SizedBox(width:7),Text('بطاقة حجز',style:TextStyle(fontWeight:FontWeight.bold,color:plum))]),
      const SizedBox(height:6),
      Text('العميل: ${m['customerName']??'-'}'),
      Text('عضو الكادر: ${m['memberName']??'-'}'),
      Text('الموعد: ${m['date']??'-'}'),
      Text('المدة: ${m['durationMinutes']??60} دقيقة'),
      Text('الحالة: ${m['status']??'قيد المراجعة'}',style:const TextStyle(fontWeight:FontWeight.bold,color:teal)),
    ])));}
    Widget? profile;
    if(member!=null){final imgs=List<String>.from(member['images']??[]);Widget avatar=const CircleAvatar(child:Icon(Icons.spa));if(imgs.isNotEmpty){try{avatar=ClipRRect(borderRadius:BorderRadius.circular(10),child:appImage(imgs.first,width:58,height:58,fit:BoxFit.cover));}catch(_){}}profile=Card(color:Colors.white,child:Padding(padding:const EdgeInsets.all(8),child:Row(children:[avatar,const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${member['name']??'ملف العضو'}',style:const TextStyle(fontWeight:FontWeight.bold)),const Text('بطاقة ملف العضو') ])),const Icon(Icons.badge_outlined,color:rose)])));}
    return Align(alignment:mine?Alignment.centerLeft:Alignment.centerRight,child:Container(constraints:const BoxConstraints(maxWidth:330),margin:const EdgeInsets.symmetric(vertical:6),padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:mine?teal.withOpacity(.12):rose.withOpacity(.13),borderRadius:BorderRadius.circular(18)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${m['sender']??'عميل'}',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:12,color:plum)),if(profile!=null)InkWell(onTap:()=>openSharedMember(member!),child:profile!),if(bookingCard!=null)bookingCard!,if(m['type']!='memberProfile'&&m['type']!='bookingCard'||profile==null&&m['type']=='memberProfile')Text('${m['text']??'تعذر العثور على ملف العضو'}'),Text('${m['createdAt']??''}',style:const TextStyle(fontSize:10,color:Colors.grey))])));
  }
  Future<void> sendAdminMessage() async {
    final value=chatController.text.trim();
    final customerId=selectedConversationId;
    final user=FirebaseAuth.instance.currentUser;
    if(value.isEmpty||user==null)return;
    if(customerId==null){note('لا توجد محادثة عميل للرد عليها بعد');return;}
    final now=DateTime.now();
    final localId='local_${now.microsecondsSinceEpoch}';
    final optimistic=<String,dynamic>{'id':localId,'_localId':localId,'conversationId':customerId,'senderId':user.uid,'sender':'الإدارة','type':'text','text':value,'createdAt':now.toIso8601String(),'pending':true};
    chatController.clear();
    setState(()=>rows.add(optimistic));
    WidgetsBinding.instance.addPostFrameCallback((_){if(adminChatScrollController.hasClients)adminChatScrollController.animateTo(0,duration:const Duration(milliseconds:180),curve:Curves.easeOut);});
    try {
      final savedId=await SharedStore.save('messages',{'conversationId':customerId,'senderId':user.uid,'sender':'الإدارة','type':'text','text':value,'createdAt':now.toIso8601String()});
      if(mounted)setState(()=>rows=rows.map((m)=>m['_localId']==localId?({...m,'id':savedId,'pending':false}):m).toList());
      unawaited(()async{
        try{
          await SharedStore.save('notifications',{'target':'customer','customerId':customerId,'conversationId':customerId,'type':'message','title':'رسالة جديدة من الإدارة','senderName':'الإدارة','body':value,'createdAt':now.toIso8601String(),'read':false});
        }catch(notificationError){debugPrint('Admin message notification failed: $notificationError');}
      }());
    } catch(e) {
      if(mounted){setState(()=>rows.removeWhere((m)=>m['_localId']==localId));if(chatController.text.isEmpty)chatController.text=value;note('تعذر إرسال الرد: $e');}
    }
  }
  Future<void> createBookingFromChat() async {
    final previous=section;
    setState(()=>section='bookings');
    fromChatBooking=true;
    try{await edit();}finally{fromChatBooking=false;}
    if(!mounted)return;
    setState(()=>section=previous);
    await refresh();
  }
  Widget adminChat() {
    if(!showChatConversation){
      final grouped=<String,List<Map<String,dynamic>>>{};
      for(final message in rows){final id=message['conversationId']?.toString()??'';if(id.isEmpty)continue;(grouped[id]??=<Map<String,dynamic>>[]).add(message);}
      final ids=grouped.keys.toList()..sort((x,y){final xm=grouped[x]!..sort((p,q)=>(p['createdAt']?.toString()??'').compareTo(q['createdAt']?.toString()??''));final ym=grouped[y]!..sort((p,q)=>(p['createdAt']?.toString()??'').compareTo(q['createdAt']?.toString()??''));return (ym.last['createdAt']?.toString()??'').compareTo(xm.last['createdAt']?.toString()??'');});
      if(ids.isEmpty)return const Center(child:Column(mainAxisSize:MainAxisSize.min,children:[Icon(Icons.forum_outlined,size:52,color:rose),SizedBox(height:12),Text('لا توجد محادثات بعد'),Text('ستظهر محادثات العملاء هنا عند وصول أول رسالة',style:TextStyle(color:Colors.black54))]));
      return ListView.separated(
        padding:const EdgeInsets.all(12),itemCount:ids.length,separatorBuilder:(_,__)=>const Divider(height:1,indent:72),
        itemBuilder:(context,index){
          final id=ids[index];final thread=grouped[id]!..sort((x,y)=>(x['createdAt']?.toString()??'').compareTo(y['createdAt']?.toString()??''));final latest=thread.last;
          final unread=notifications.where((n)=>n['createdBy']?.toString()==id&&n['read']!=true).length;
          return ListTile(contentPadding:const EdgeInsets.symmetric(horizontal:8,vertical:5),
            leading:CircleAvatar(radius:25,backgroundColor:rose.withOpacity(.12),child:const Icon(Icons.person,color:rose)),
            title:Text(customerLabel(id),style:const TextStyle(fontWeight:FontWeight.bold)),
            subtitle:Text(chatPreview(latest),maxLines:1,overflow:TextOverflow.ellipsis),
            trailing:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.end,children:[
              Text(chatTime(latest['createdAt']),style:const TextStyle(fontSize:11,color:Colors.black54)),
              if(unread>0)Padding(padding:const EdgeInsets.only(top:5),child:CircleAvatar(radius:10,backgroundColor:rose,child:Text('$unread',style:const TextStyle(color:Colors.white,fontSize:10,fontWeight:FontWeight.bold))))
            ]),
            onTap:(){setState((){selectedConversationId=id;showChatConversation=true;});markConversationRead(id);}
          );
        }
      );
    }
    final id=selectedConversationId;if(id==null)return const Center(child:Text('لم يتم اختيار محادثة'));
    final messages=rows.where((m)=>m['conversationId']?.toString()==id).toList()..sort((x,y)=>(x['createdAt']?.toString()??'').compareTo(y['createdAt']?.toString()??''));
    return Column(children:[
      Container(height:58,color:const Color(0xFFFFE4EF),padding:const EdgeInsets.symmetric(horizontal:6),child:Row(children:[
        IconButton(tooltip:'قائمة المحادثات',onPressed:()=>setState(()=>showChatConversation=false),icon:const Icon(Icons.arrow_back_rounded,color:rose)),
        const CircleAvatar(radius:18,backgroundColor:Colors.white,child:Icon(Icons.person,color:rose,size:20)),const SizedBox(width:9),
        Expanded(child:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(customerLabel(id),style:const TextStyle(fontWeight:FontWeight.bold,fontSize:15)),const Text('محادثة العميل',style:TextStyle(fontSize:11,color:Colors.black54))
        ]))
      ])),
      Expanded(child:messages.isEmpty?const Center(child:Text('ابدأ المحادثة بإرسال أول رد')):ListView.builder(controller:adminChatScrollController,reverse:true,padding:const EdgeInsets.all(12),itemCount:messages.length,itemBuilder:(context,index)=>adminMessageBubble(messages[messages.length-1-index]))),
      SafeArea(child:Padding(padding:const EdgeInsets.all(8),child:Row(children:[
        IconButton(tooltip:'تسجيل حجز للعميل',onPressed:createBookingFromChat,icon:const Icon(Icons.event_available,color:teal)),
        IconButton(tooltip:'إرسال ملف عضو',onPressed:shareMemberProfile,icon:const Icon(Icons.person_add_alt_1,color:rose)),
        Expanded(child:TextField(controller:chatController,focusNode:chatFocusNode,minLines:1,maxLines:4,scrollPadding:const EdgeInsets.only(bottom:180),decoration:const InputDecoration(hintText:'اكتب رد الإدارة...',border:OutlineInputBorder()),onTap:(){WidgetsBinding.instance.addPostFrameCallback((_){if(adminChatScrollController.hasClients)adminChatScrollController.jumpTo(0);});},onSubmitted:(_)=>sendAdminMessage())),
        IconButton(onPressed:sendAdminMessage,icon:const Icon(Icons.send,color:plum))
      ])))
    ]);
  }
  @override Widget build(BuildContext context)=>Directionality(textDirection:TextDirection.rtl,child:Scaffold(
    appBar:AppBar(toolbarHeight:64,backgroundColor:cream,surfaceTintColor:Colors.transparent,foregroundColor:Colors.black,iconTheme:const IconThemeData(color:Colors.black),actionsIconTheme:const IconThemeData(color:Colors.black),flexibleSpace:const DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Color(0xFFFF91B8),Color(0xFFFFC7DB),Color(0xFFFFF7FB)]))),title:const Row(mainAxisSize:MainAxisSize.min,children:[Icon(Icons.auto_awesome_rounded,color:Colors.black,size:19),SizedBox(width:6),Text('الشيخة | الإدارة',style:TextStyle(color:Colors.black,fontWeight:FontWeight.w900,fontSize:21,letterSpacing:.2))]),actions:[IconButton(tooltip:'الحسابات الإدارية',onPressed:()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>const AdminAccountsScreen())),icon:const Icon(Icons.admin_panel_settings,color:Colors.black)),Badge(isLabelVisible:notifications.any((n)=>n['read']!=true),label:Text('${notifications.where((n)=>n['read']!=true).length}'),child:IconButton(tooltip:'الإشعارات',onPressed:openNotifications,icon:const Icon(Icons.notifications_active,color:Colors.black))),IconButton(tooltip:'تسجيل الخروج',onPressed:()=>FirebaseAuth.instance.signOut(),icon:const Icon(Icons.logout,color:Colors.black)),IconButton(onPressed:()=>refresh(),icon:const Icon(Icons.refresh,color:Colors.black))]),
    floatingActionButton:(section=='messages'||section=='analytics')?null:FloatingActionButton.extended(backgroundColor:rose,foregroundColor:Colors.white,onPressed:()=>edit(),icon:const Icon(Icons.add_circle_rounded,color:Colors.white),label:const Text('إضافة سجل')),
    resizeToAvoidBottomInset:true,
    body:Column(children:[
      SizedBox(height:58,child:ListView(scrollDirection:Axis.horizontal,padding:const EdgeInsets.symmetric(horizontal:8),children:sections.entries.map((e)=>Padding(padding:const EdgeInsets.all(4),child:ChoiceChip(avatar:Icon(sectionIcons[e.key],size:18,color:section==e.key?Colors.white:sectionColors[e.key]),label:Text(e.value,style:TextStyle(color:section==e.key?Colors.white:sectionColors[e.key],fontWeight:FontWeight.bold)),selected:section==e.key,selectedColor:sectionColors[e.key],backgroundColor:Colors.white,side:BorderSide(color:sectionColors[e.key]!.withOpacity(.35)),shape:const StadiumBorder(),onSelected:(_){setState(() {section=e.key;if(e.key!='bookings'){selectedBookingCustomerId=null;selectedBookingId=null;}if(e.key!='messages')showChatConversation=false;});if(e.key=='bookings')loadChatMembers();refresh();}))).toList())),
      Expanded(child:section=='analytics'?const AdminAnalyticsScreen():section=='messages'?adminChat():section=='bookings'?adminBookingsPage():busy?const Center(child:CircularProgressIndicator()):RefreshIndicator(onRefresh:refresh,child:ListView(padding:const EdgeInsets.all(14),children:[
        Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(gradient:const LinearGradient(colors:[plum,rose,teal]),borderRadius:BorderRadius.circular(22)),child:Text('${sections[section]}\n${rows.length} سجل',style:const TextStyle(color:Colors.white,fontSize:22,fontWeight:FontWeight.bold))),
        if(section=='banners'&&rows.length>=7)const Padding(padding:EdgeInsets.all(8),child:Text('وصلت إلى الحد الأقصى: 7 بانرات.')),
        if(rows.isEmpty)const Card(child:Padding(padding:EdgeInsets.all(20),child:Text('لا توجد بيانات بعد. استخدم زر الإضافة للبدء.'))),
        ...rows.map(recordCard),const SizedBox(height:90)
      ])))
    ])
  ));
}
