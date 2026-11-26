import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'glass_design.dart';
import 'package:google_fonts/google_fonts.dart';
import 'shared_store.dart';
import 'image_utils.dart';
import 'account_page.dart';
import 'notification_service.dart';
import 'shared/one_signal_service.dart';
import 'shared/one_signal_subscription_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.android);
  try {
    OneSignalService.initialize('603a9d8a-365a-4b6f-befd-b213f725c09e');
    OneSignalService.addNotificationClickListener(NotificationService.handleExternalTap);
  } catch (_) {
    // OneSignal is optional and must never block app startup.
  }
  try {
    await NotificationService.initialize();
  } catch (_) {
    // Push notifications are optional; never prevent the app from opening.
  }
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor:Colors.transparent,statusBarIconBrightness:Brightness.dark,systemNavigationBarColor:Colors.transparent,systemNavigationBarIconBrightness:Brightness.dark));
  final themePrefs = await SharedPreferences.getInstance();
  final savedTheme = themePrefs.getString('client_theme_mode');
  clientThemeMode.value = savedTheme == 'dark' ? ThemeMode.dark : savedTheme == 'light' ? ThemeMode.light : ThemeMode.system;
  runApp(const SheikhaClientApp());
}
final ValueNotifier<ThemeMode> clientThemeMode = ValueNotifier<ThemeMode>(ThemeMode.system);

Future<void> setClientThemeMode(ThemeMode mode) async {
  clientThemeMode.value = mode;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('client_theme_mode', mode == ThemeMode.dark ? 'dark' : mode == ThemeMode.light ? 'light' : 'system');
}

const rose=Color(0xFFC49A55), plum=Color(0xFF59452F), cream=Color(0xFFF7F2E9), teal=Color(0xFF9C835D), gold=Color(0xFFD8B878);
class SheikhaClientApp extends StatelessWidget {
 const SheikhaClientApp({super.key});
 @override Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
  valueListenable: clientThemeMode,
  builder: (context, mode, _) => MaterialApp(
   debugShowCheckedModeBanner:false,
   title:'الشيخة',
   theme:GlassDesign.light,
   darkTheme:GlassDesign.dark,
   themeMode:mode,
   home:const OneSignalSubscriptionGate(child:ClientAuthGate()),
  ),
 );
}

String _accountEmail(String username) => '${username.trim().toLowerCase()}@alshaikha.app';

class ClientAuthGate extends StatelessWidget {
 const ClientAuthGate({super.key});
 @override Widget build(BuildContext context) => StreamBuilder<User?>(
  stream: FirebaseAuth.instance.authStateChanges(),
  builder:(context,snapshot){
   if(snapshot.connectionState==ConnectionState.waiting) return const Scaffold(body:Center(child:CircularProgressIndicator()));
   if(snapshot.data==null) return const ClientAccountScreen();
   return const ClientHome();
  });
}

class ClientAccountScreen extends StatefulWidget {
 const ClientAccountScreen({super.key});
 @override State<ClientAccountScreen> createState()=>_ClientAccountScreenState();
}
class _ClientAccountScreenState extends State<ClientAccountScreen> with TickerProviderStateMixin {
 final username=TextEditingController(), password=TextEditingController(), displayName=TextEditingController(), confirmPassword=TextEditingController();
 bool register=false, loading=false, obscure=true, obscureConfirm=true;
 String? error;
 late final AnimationController _breathController;
 late final AnimationController _breezeController;
 @override void initState(){
  super.initState();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  _breathController=AnimationController(vsync:this,duration:const Duration(milliseconds:3600))..repeat(reverse:true);
  _breezeController=AnimationController(vsync:this,duration:const Duration(milliseconds:5200))..repeat(reverse:true);
 }
 @override void dispose(){
  _breathController.dispose();_breezeController.dispose();
  username.dispose();password.dispose();displayName.dispose();confirmPassword.dispose();
  super.dispose();
 }
 Future<void> submit() async {
  final u=username.text.trim().toLowerCase(), p=password.text;
  if(!RegExp(r'^[a-z0-9._]{3,24}$').hasMatch(u)){setState(()=>error='اسم المستخدم يجب أن يكون 3 إلى 24 حرفاً إنجليزياً أو رقماً');return;}
  if(p.length<6){setState(()=>error='كلمة المرور يجب ألا تقل عن 6 أحرف');return;}
  if(register&&displayName.text.trim().isEmpty){setState(()=>error='اكتب الاسم الذي سيظهر في الحساب');return;}
  if(register&&password.text!=confirmPassword.text){setState(()=>error='كلمتا المرور غير متطابقتين');return;}
  setState(() { loading=true; error=null; });
  try {
   final credential=register
    ? await FirebaseAuth.instance.createUserWithEmailAndPassword(email:_accountEmail(u),password:p)
    : await FirebaseAuth.instance.signInWithEmailAndPassword(email:_accountEmail(u),password:p);
   final user=credential.user!;
   if(register){
    await user.updateDisplayName(displayName.text.trim());
    await FirebaseFirestore.instance.collection('profiles').doc(user.uid).set({
     'uid':user.uid,'username':u,'displayName':displayName.text.trim(),'role':'customer',
     'createdAt':FieldValue.serverTimestamp()
    });
   } else {
    final profile=await FirebaseFirestore.instance.collection('profiles').doc(user.uid).get();
    if(!profile.exists || profile.data()?['role']!='customer'){
     await FirebaseAuth.instance.signOut();
     throw FirebaseAuthException(code:'profile-not-found',message:'الحساب غير مهيأ كحساب عميل');
    }
   }
  } on FirebaseAuthException catch(e){
   setState(()=>error=switch(e.code){
    'email-already-in-use'=>'اسم المستخدم مستخدم مسبقاً',
    'invalid-credential'=>'اسم المستخدم أو كلمة المرور غير صحيحة',
    'user-not-found'=>'الحساب غير موجود',
    'weak-password'=>'كلمة المرور ضعيفة',
    'profile-not-found'=>'هذا الحساب غير مهيأ كحساب عميل',
    _=>'تعذر إكمال العملية: ${e.message??e.code}'
   });
  } catch(e){setState(()=>error='حدث خطأ: $e');}
  finally{if(mounted)setState(()=>loading=false);}
 }
 @override
 Widget build(BuildContext context) {
  const ink=Color(0xFF33291D), gold=Color(0xFFC49A55), muted=Color(0xFF806F59);
  final dark=Theme.of(context).brightness==Brightness.dark;
  final compact=MediaQuery.sizeOf(context).height<700||MediaQuery.viewInsetsOf(context).bottom>0;
  InputDecoration decoration(String hint,IconData icon,{Widget? trailing})=>InputDecoration(
   hintText:hint,hintStyle:TextStyle(color:muted,fontSize:14,fontWeight:FontWeight.w600),
   prefixIcon:Icon(icon,color:gold,size:21),suffixIcon:trailing,filled:true,
   fillColor:dark?const Color(0xFF24211D):const Color(0xFFF8F4EC),
   contentPadding:const EdgeInsets.symmetric(horizontal:16,vertical:15),
   border:OutlineInputBorder(borderRadius:BorderRadius.circular(19),borderSide:BorderSide(color:gold.withOpacity(.22))),
   enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(19),borderSide:BorderSide(color:gold.withOpacity(.25))),
   focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(19),borderSide:const BorderSide(color:gold,width:1.6)),
  );
  Widget field(TextEditingController c,String hint,IconData icon,{bool secret=false,Widget? trailing,TextInputAction action=TextInputAction.next})=>TextField(
   controller:c,obscureText:secret,autocorrect:false,textAlign:TextAlign.right,textInputAction:action,
   style:const TextStyle(fontSize:15,fontWeight:FontWeight.w600),
   onSubmitted:action==TextInputAction.done?(_){if(!loading)submit();}:null,
   decoration:decoration(hint,icon,trailing:trailing),
  );
  return Directionality(textDirection:TextDirection.rtl,child:Scaffold(
   resizeToAvoidBottomInset:true,
   body:Stack(fit:StackFit.expand,children:[
    Container(color:dark?const Color(0xFF17130F):const Color(0xFFF7F2E9)),
    Positioned(top:0,left:0,right:0,height:MediaQuery.sizeOf(context).height*.48,child:Image.asset('file_00000000df048210b32f5dc7efa7f5ad.png',fit:BoxFit.cover,alignment:Alignment.topCenter)),
    Positioned(top:0,left:0,right:0,height:MediaQuery.sizeOf(context).height*.58,child:DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:dark?[Colors.black.withOpacity(.20),const Color(0xFF17130F)]:[Colors.transparent,const Color(0xFFF7F2E9)])))),
    SafeArea(child:LayoutBuilder(builder:(context,constraints)=>SingleChildScrollView(
     padding:EdgeInsets.fromLTRB(20,compact?8:18,20,24),
     child:ConstrainedBox(constraints:BoxConstraints(minHeight:constraints.maxHeight-42),child:Column(
      mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.stretch,
      children:[
       SizedBox(height:compact?8:18),
       Container(padding:EdgeInsets.all(compact?18:22),decoration:BoxDecoration(
        color:dark?const Color(0xB925211B):const Color(0xBFFBF9F4),borderRadius:BorderRadius.circular(30),
        border:Border.all(color:gold.withOpacity(.32)),boxShadow:[BoxShadow(color:Colors.black.withOpacity(dark ? .18 : .07),blurRadius:28,offset:const Offset(0,12))]),
        child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
         Row(children:[Container(width:4,height:34,decoration:BoxDecoration(color:gold,borderRadius:BorderRadius.circular(8))),
          const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
           Text(register?'انضم إلى الشيخة':'مرحباً بعودتك',style:const TextStyle(fontSize:23,fontWeight:FontWeight.w900,color:ink)),
           const SizedBox(height:3),Text(register?'أنشئ حسابك وابدأ رحلتك':'سجّل الدخول لمتابعة حجوزاتك',style:const TextStyle(color:muted,fontSize:12)),
          ])),
          Icon(Icons.auto_awesome_rounded,color:gold.withOpacity(.9),size:25),
         ]),
         const SizedBox(height:20),
         if(register)Padding(padding:const EdgeInsets.only(bottom:12),child:field(displayName,'الاسم الكامل',Icons.badge_outlined)),
         Padding(padding:const EdgeInsets.only(bottom:12),child:field(username,'اسم المستخدم',Icons.person_outline)),
         Padding(padding:const EdgeInsets.only(bottom:12),child:field(password,'كلمة المرور',Icons.lock_outline,secret:obscure,
          trailing:IconButton(onPressed:()=>setState(()=>obscure=!obscure),icon:Icon(obscure?Icons.visibility_off_outlined:Icons.visibility_outlined,color:muted)),
          action:register?TextInputAction.next:TextInputAction.done)),
         if(register)Padding(padding:const EdgeInsets.only(bottom:12),child:field(confirmPassword,'تأكيد كلمة المرور',Icons.verified_user_outlined,secret:obscureConfirm,
          trailing:IconButton(onPressed:()=>setState(()=>obscureConfirm=!obscureConfirm),icon:Icon(obscureConfirm?Icons.visibility_off_outlined:Icons.visibility_outlined,color:muted)),
          action:TextInputAction.done)),
         if(error!=null)Padding(padding:const EdgeInsets.only(bottom:12),child:Text(error!,textAlign:TextAlign.center,style:const TextStyle(color:Color(0xFFB3261E),fontSize:12,fontWeight:FontWeight.w700))),
         SizedBox(height:52,child:FilledButton(onPressed:loading?null:submit,
          style:FilledButton.styleFrom(backgroundColor:gold,foregroundColor:const Color(0xFF21190F),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18)),elevation:0),
          child:loading?const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2,color:ink)):
           Row(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(register?Icons.person_add_alt_1:Icons.login_rounded),const SizedBox(width:9),
            Text(register?'إنشاء الحساب':'تسجيل الدخول',style:const TextStyle(fontSize:16,fontWeight:FontWeight.w900))]))),
         const SizedBox(height:10),
         OutlinedButton(onPressed:loading?null:()=>setState((){register=!register;error=null;}),
          style:OutlinedButton.styleFrom(foregroundColor:dark?const Color(0xFFE9D8B8):ink,side:BorderSide(color:gold.withOpacity(.55)),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18)),minimumSize:const Size.fromHeight(48)),
          child:Text(register?'العودة لتسجيل الدخول':'إنشاء حساب جديد',style:const TextStyle(fontWeight:FontWeight.w800))),
         if(!register)Align(alignment:Alignment.center,child:TextButton(
          onPressed:()=>setState(()=>error='لاستعادة كلمة المرور، تواصلي مع إدارة الشيخة.'),
          child:const Text('نسيت كلمة المرور؟',style:TextStyle(color:muted,fontWeight:FontWeight.w700)))),
        ]),
       ),
       const SizedBox(height:16),
       Text('راحة • عناية • تجربة حجز سهلة',textAlign:TextAlign.center,style:TextStyle(color:dark?Colors.white54:muted,fontSize:11,fontWeight:FontWeight.w600)),
      ],
     )),
    ))),
   ]),
  ));
 }

}

class LoginWaveClipper extends CustomClipper<Path>{
 @override Path getClip(Size size){final p=Path()..lineTo(0,size.height-34);p.quadraticBezierTo(size.width*.22,size.height-82,size.width*.48,size.height-40);p.quadraticBezierTo(size.width*.76,size.height+2,size.width,size.height-88);p.lineTo(size.width,0);p.close();return p;}
 @override bool shouldReclip(covariant CustomClipper<Path> oldClipper)=>false;
}

class ClientHome extends StatefulWidget { const ClientHome({super.key}); @override State<ClientHome> createState()=>_ClientHomeState(); }
class _ClientHomeState extends State<ClientHome>{
 int tab=0;bool busy=true;bool sendingMessage=false;bool headerVisible=true;String search='';String memberSort='recommended';bool compactMembers=false;bool onlyWithPlace=false;String availabilityFilter='all';String get conversationId => FirebaseAuth.instance.currentUser?.uid ?? 'signed-out';
 List<Map<String,dynamic>> members=[],sessions=[],banners=[],bookings=[],favorites=[],messages=[],notifications=[],announcements=[];String? selectedBookingId;StreamSubscription<Map<String,dynamic>>? notificationTapSub;final Set<String> _seenNotificationIds=<String>{};bool _notificationsInitialized=false;
 final searchCtrl=TextEditingController();final messageCtrl=TextEditingController();final FocusNode chatFocusNode=FocusNode();final ScrollController clientChatScrollController=ScrollController();Timer? poll;Timer? bannerAuto;Timer? topNotificationTimer;final PageController bannerPager=PageController(viewportFraction:.985);int bannerIndex=0;
 @override void initState(){super.initState();WidgetsBinding.instance.addPostFrameCallback((_)=>_showFirstUseGuide());notificationTapSub=NotificationService.taps.listen((data)=>handleNotificationTap(data));WidgetsBinding.instance.addPostFrameCallback((_){final initial=NotificationService.takeInitialTap();if(initial!=null)handleNotificationTap(initial);});_trackActivity('app_open');load();poll=Timer.periodic(const Duration(seconds:5),(_){if(!(tab==1&&chatFocusNode.hasFocus))load(silent:true);});bannerAuto=Timer.periodic(const Duration(seconds:10),(_){if(!mounted||banners.length<2||!bannerPager.hasClients)return;final next=(bannerIndex+1)%banners.length;bannerPager.animateToPage(next,duration:const Duration(milliseconds:550),curve:Curves.easeInOutCubic);});}
 @override void dispose(){poll?.cancel();bannerAuto?.cancel();topNotificationTimer?.cancel();notificationTapSub?.cancel();bannerPager.dispose();searchCtrl.dispose();messageCtrl.dispose();chatFocusNode.dispose();clientChatScrollController.dispose();super.dispose();}
 Future<void> _showFirstUseGuide() async {
  final user=FirebaseAuth.instance.currentUser;
  if(user==null||!mounted)return;
  final prefs=await SharedPreferences.getInstance();
  final key='client_first_guide_seen_${user.uid}';
  if(prefs.getBool(key)==true||!mounted)return;
  final steps=<Map<String,dynamic>>[
   {'icon':Icons.waving_hand_rounded,'title':'مرحباً بك في الشيخة','body':'أهلاً بك! هذا دليل سريع يساعدك على استخدام التطبيق والعثور على الكادر وإدارة حجوزاتك والتواصل مع الإدارة.'},
   {'icon':Icons.search_rounded,'title':'اكتشف الكادر','body':'من الرئيسية يمكنك البحث باسم عضو الكادر أو التخصص، واستخدام الترتيب والفلاتر لمعرفة المتاح أو المحجوز وتحديد الموقع.'},
   {'icon':Icons.spa_rounded,'title':'تعرّف على ملف الكادر','body':'اضغط على بطاقة العضو لعرض الصور والتفاصيل والسعر والموقع. يمكنك تكبير الصور وإضافة العضو إلى المفضلة.'},
   {'icon':Icons.event_available_rounded,'title':'كيف تحجز موعداً؟','body':'افتح ملف عضو الكادر واضغط زر الحجز، ثم راجع تفاصيل طلبك وأرسله. تابع حالة الطلب من «حجوزاتي» داخل «المزيد».'},
   {'icon':Icons.chat_bubble_outline_rounded,'title':'تواصل مع الإدارة','body':'افتح «المحادثات» لإرسال استفسارك مباشرة إلى الإدارة. يمكنك أيضاً مشاركة ملف عضو الكادر داخل المحادثة.'},
   {'icon':Icons.favorite_border_rounded,'title':'المفضلة والجلسات','body':'استخدم رمز القلب للوصول إلى الكادر المفضل، وافتح «الجلسات» لمشاهدة أرشيف الصور والتفاصيل المنشورة.'},
   {'icon':Icons.tune_rounded,'title':'حسابك والإعدادات','body':'من «المزيد» تصل إلى حسابك وحجوزاتك. ومن رأس التطبيق يمكنك تغيير المظهر الفاتح أو الداكن ومراجعة الإشعارات.'},
  ];
  var page=0;
  await showDialog<void>(context:context,barrierDismissible:false,builder:(dc)=>StatefulBuilder(builder:(dc,setGuideState){
   final step=steps[page];
   return Directionality(textDirection:TextDirection.rtl,child:Dialog(backgroundColor:Colors.transparent,insetPadding:const EdgeInsets.symmetric(horizontal:22,vertical:24),child:GlassPanel(radius:28,padding:const EdgeInsets.all(20),child:Column(mainAxisSize:MainAxisSize.min,children:[
    Row(children:[const Spacer(),const Text('دليل الاستخدام',style:TextStyle(fontWeight:FontWeight.w900)),const Spacer(),IconButton(onPressed:()async{await prefs.setBool(key,true);if(dc.mounted)Navigator.pop(dc);},icon:const Icon(Icons.close_rounded))]),
    const SizedBox(height:8),Container(width:66,height:66,decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFFEAD8B5),Color(0xFFD2B47E)]),borderRadius:BorderRadius.circular(22)),child:Icon(step['icon'] as IconData,size:32,color:const Color(0xFF342719))),
    const SizedBox(height:15),Text(step['title'] as String,textAlign:TextAlign.center,style:const TextStyle(fontSize:20,fontWeight:FontWeight.w900)),
    const SizedBox(height:10),Text(step['body'] as String,textAlign:TextAlign.center,style:TextStyle(fontSize:14,height:1.7,color:Theme.of(dc).colorScheme.onSurface.withOpacity(.78))),
    const SizedBox(height:18),Row(mainAxisAlignment:MainAxisAlignment.center,children:List.generate(steps.length,(i)=>AnimatedContainer(duration:const Duration(milliseconds:180),margin:const EdgeInsets.symmetric(horizontal:3),width:i==page?20:7,height:7,decoration:BoxDecoration(color:i==page?gold:gold.withOpacity(.28),borderRadius:BorderRadius.circular(10))))),
    const SizedBox(height:18),Row(children:[
     if(page>0)Expanded(child:OutlinedButton(onPressed:()=>setGuideState(()=>page--),child:const Text('السابق'))),
     if(page>0)const SizedBox(width:8),
     Expanded(child:FilledButton(onPressed:()async{if(page<steps.length-1){setGuideState(()=>page++);}else{await prefs.setBool(key,true);if(dc.mounted)Navigator.pop(dc);}},style:FilledButton.styleFrom(backgroundColor:gold,foregroundColor:const Color(0xFF342719)),child:Text(page==steps.length-1?'ابدأ الاستخدام':'التالي'))),
    ]),
    TextButton(onPressed:()async{await prefs.setBool(key,true);if(dc.mounted)Navigator.pop(dc);},child:const Text('تخطي الدليل')),
   ]))));
  }));
 }
 void note(String s)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));
 void _showTopNotification(Map<String,dynamic> n){
  final messenger=ScaffoldMessenger.of(context);
  messenger.hideCurrentMaterialBanner();
  messenger.showMaterialBanner(MaterialBanner(
   backgroundColor:Colors.white,
   elevation:5,
   padding:const EdgeInsets.symmetric(horizontal:14,vertical:10),
   leading:const Icon(Icons.notifications_active_rounded,color:plum,size:30),
   content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text((n['title']??'إشعار جديد').toString(),maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w800,color:plum)),
    Text((n['body']??'').toString(),maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.black87)),
   ]),
   actions:[TextButton(onPressed:(){messenger.hideCurrentMaterialBanner();openNotifications();},child:const Text('عرض'))],
  ));
  topNotificationTimer?.cancel();
  topNotificationTimer=Timer(const Duration(seconds:5),()=>messenger.hideCurrentMaterialBanner());
 }
 Future<void> _trackActivity(String activity) async {
  try {
   final user=FirebaseAuth.instance.currentUser;
   if(user==null)return;
   final prefs=await SharedPreferences.getInstance();
   var installationId=prefs.getString('alshaikha_installation_id');
   if(installationId==null||installationId.isEmpty){
    final random=math.Random.secure();
    installationId=List.generate(32,(_)=>random.nextInt(16).toRadixString(16)).join();
    await prefs.setString('alshaikha_installation_id',installationId);
   }
   final firstLaunch=prefs.getBool('alshaikha_installation_registered')!=true;
   final updates=<String,dynamic>{
    'installationId':installationId,
    'lastUserId':user.uid,
    'lastSeen':FieldValue.serverTimestamp(),
    'lastActivity':activity,
    'platform':'android',
    'appVersion':'1.0.0+1',
   };
   if(firstLaunch)updates['firstSeen']=FieldValue.serverTimestamp();
   if(activity=='app_open')updates['launchCount']=FieldValue.increment(1);
   final counter=switch(activity){
    'booking'=>'bookingCount',
    'message'=>'messageCount',
    'favorite'=>'favoriteCount',
    'profile_view'=>'profileViewCount',
    _=>null,
   };
   if(counter!=null)updates[counter]=FieldValue.increment(1);
   await FirebaseFirestore.instance.collection('app_devices').doc(installationId).set(updates,SetOptions(merge:true));
   if(firstLaunch)await prefs.setBool('alshaikha_installation_registered',true);
  }catch(e){debugPrint('Analytics tracking failed: $e');}
 }
Future<void> handleNotificationTap(Map<String,dynamic> n)async{
  final id=(n['id']??n['notificationId']??'').toString();
  if(id.isNotEmpty&&n['target']!='all'){try{await SharedStore.save('notifications',{...n,'id':id,'read':true});}catch(_){}}
  await load(silent:true);if(!mounted)return;
  final type=(n['type']??'').toString();
  if(type=='message'){setState(()=>tab=1);WidgetsBinding.instance.addPostFrameCallback((_){if(clientChatScrollController.hasClients)clientChatScrollController.jumpTo(0);});}
  else if(type=='booking'){
    final bookingId=(n['bookingId']??'').toString();
    setState(() {tab=2;selectedBookingId=bookingId;});
    final found=bookings.where((b)=>b['id']?.toString()==bookingId).toList();
    if(found.isNotEmpty)WidgetsBinding.instance.addPostFrameCallback((_){if(mounted)showClientBooking(found.first);});
  }else{setState(()=>tab=0);}
}
Future<void> showClientBooking(Map<String,dynamic> b)async{
  await showDialog<void>(context:context,builder:(ctx)=>Directionality(textDirection:TextDirection.rtl,child:AlertDialog(
    title:const Text('تفاصيل الحجز'),
    content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('عضو الكادر: ${b['memberName']??'-'}'),Text('الموعد: ${b['date']??'-'}'),
      Text('الحالة: ${b['status']??'قيد المراجعة'}'),
      if((b['notes']??'').toString().isNotEmpty)Text('ملاحظات: ${b['notes']}')
    ]),
    actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إغلاق'))]
  )));
}
Future<void> openNotifications()async{
  await load(silent:true);if(!mounted)return;
  showModalBottomSheet(context:context,isScrollControlled:true,builder:(ctx)=>Directionality(textDirection:TextDirection.rtl,child:SafeArea(child:SizedBox(height:MediaQuery.of(ctx).size.height*.72,child:Column(children:[
    const Padding(padding:EdgeInsets.all(16),child:Text('الإشعارات',style:TextStyle(fontSize:21,fontWeight:FontWeight.bold))),
    Expanded(child:notifications.isEmpty?const Center(child:Text('لا توجد إشعارات حالياً')):ListView(children:notifications.map((n)=>ListTile(
      leading:Icon(n['type']=='booking'?Icons.event_available:n['type']=='message'?Icons.forum:Icons.campaign,color:rose),
      title:Text('${n['title']??'إشعار'}'),subtitle:Text('${n['body']??''}'),
      trailing:n['read']==true?const Icon(Icons.done,color:teal):const Icon(Icons.circle,color:rose,size:10),
      onTap:(){Navigator.pop(ctx);handleNotificationTap(n);}
    )).toList()))
  ])))));
}

 Future<void> load({bool silent=false})async{
  if(!silent&&mounted)setState(()=>busy=true);
  try{final r=await Future.wait([SharedStore.list('members'),SharedStore.list('sessions'),SharedStore.list('banners'),SharedStore.list('bookings'),SharedStore.list('favorites'),SharedStore.list('messages'),SharedStore.list('notifications'),SharedStore.list('announcements')]);
   final incoming=<Map<String,dynamic>>[];final latestNotifications=r[6].where((n)=>n['target']=='customer'||n['target']=='all').toList();for(final item in latestNotifications){final id=(item['id']??'').toString();if(id.isEmpty)continue;if(!_notificationsInitialized){_seenNotificationIds.add(id);}else if(_seenNotificationIds.add(id)){incoming.add(item);}}_notificationsInitialized=true;if(mounted){setState((){members=r[0];sessions=r[1];banners=r[2].where((b)=>b['active']!=false).take(7).toList();bookings=r[3];favorites=r[4];messages=(r[5].where((m)=>m['conversationId']==conversationId).toList()..sort((a,b)=>'${a['createdAt']??''}'.compareTo('${b['createdAt']??''}')));notifications=latestNotifications..sort((a,b)=>'${b['createdAt']??''}'.compareTo('${a['createdAt']??''}'));announcements=r[7]..sort((a,b)=>'${b['createdAt']??''}'.compareTo('${a['createdAt']??''}'));});}
  }catch(e){if(!silent&&mounted)note('تعذر تحميل البيانات المشتركة: $e');}finally{if(mounted)setState(()=>busy=false);}
 }
 bool isFav(Map<String,dynamic> m)=>favorites.any((f)=>f['memberId']==m['id']);
 Future<void> toggleFav(Map<String,dynamic> m)async{final old=favorites.where((f)=>f['memberId']==m['id']).toList();if(old.isNotEmpty){await SharedStore.delete('favorites',old.first['id']);}else{await SharedStore.save('favorites',{'customerId':FirebaseAuth.instance.currentUser!.uid,'memberId':m['id'],'memberName':m['name']});}_trackActivity('favorite');await load(silent:true);}
 Future<void> book([Map<String,dynamic>? initialMember])async{
  Map<String,dynamic>? selectedMember=initialMember;
  if(selectedMember==null){for(final candidate in members){if(candidate['available']!=false){selectedMember=candidate;break;}}}
  final phone=TextEditingController(),notes=TextEditingController();
  final user=FirebaseAuth.instance.currentUser;
  final profileData=user==null? <String,dynamic>{} : ((await FirebaseFirestore.instance.collection('profiles').doc(user.uid).get()).data()??<String,dynamic>{});
  final customerName=(profileData['displayName']??user?.displayName??profileData['username']??'عميل').toString().trim();
  DateTime? selectedDate; TimeOfDay? selectedTime;
  final result=await showDialog<bool>(context:context,builder:(c)=>StatefulBuilder(builder:(c,ds)=>AlertDialog(
   title:const Text('طلب حجز موعد'),
   content:SizedBox(width:420,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
    DropdownButtonFormField<String>(value:selectedMember?['id']?.toString(),decoration:const InputDecoration(labelText:'اختيار العضو',prefixIcon:Icon(Icons.spa),border:OutlineInputBorder()),items:members.where((member)=>member['available']!=false).map((member)=>DropdownMenuItem<String>(value:member['id'].toString(),child:Text('${member['name']??'عضو'}'))).toList(),onChanged:(v)=>ds(()=>selectedMember=members.firstWhere((member)=>member['id'].toString()==v)),),
    const SizedBox(height:10),
    TextField(controller:phone,keyboardType:TextInputType.phone,scrollPadding:const EdgeInsets.only(bottom:180),decoration:const InputDecoration(labelText:'رقم الهاتف',prefixIcon:Icon(Icons.phone))),
    const SizedBox(height:12),
    const SizedBox(height:10),
    OutlinedButton.icon(onPressed:()async{final d=await showDatePicker(context:c,initialDate:selectedDate??DateTime.now().add(const Duration(days:1)),firstDate:DateTime.now(),lastDate:DateTime.now().add(const Duration(days:365)));if(d!=null)ds(()=>selectedDate=d);},icon:const Icon(Icons.calendar_month),label:Text(selectedDate==null?'اختيار تاريخ الحجز':'${selectedDate!.year}/${selectedDate!.month}/${selectedDate!.day}')),
    OutlinedButton.icon(onPressed:()async{final t=await showTimePicker(context:c,initialTime:selectedTime??TimeOfDay.now());if(t!=null)ds(()=>selectedTime=t);},icon:const Icon(Icons.schedule),label:Text(selectedTime==null?'اختيار وقت الحجز':selectedTime!.format(c))),
    TextField(controller:notes,maxLines:2,scrollPadding:const EdgeInsets.only(bottom:180),decoration:const InputDecoration(labelText:'ملاحظات إضافية')),
   ]))),
   actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('إرسال الطلب'))],
  )));
  if(result==true){if(customerName.isEmpty||selectedMember==null||selectedDate==null||selectedTime==null){note('تعذر تحديد اسم الحساب أو لم تكتمل بيانات الحجز');}else{try{final dt=DateTime(selectedDate!.year,selectedDate!.month,selectedDate!.day,selectedTime!.hour,selectedTime!.minute);final bookingId=await SharedStore.save('bookings',{'customerId':FirebaseAuth.instance.currentUser!.uid,'customerName':customerName,'phone':phone.text.trim(),'memberId':selectedMember!['id'],'memberName':selectedMember!['name'],'date':dt.toIso8601String(),'notes':notes.text.trim(),'status':'قيد المراجعة'});try{final bookingUser=FirebaseAuth.instance.currentUser!;final profile=(await FirebaseFirestore.instance.collection('profiles').doc(bookingUser.uid).get()).data()??<String,dynamic>{};await SharedStore.save('notifications',{'target':'admin','createdBy':bookingUser.uid,'customerId':bookingUser.uid,'conversationId':conversationId,'type':'booking','title':'طلب حجز جديد من $customerName','senderName':customerName,'body':'طلب حجز مع ${selectedMember!['name']}','createdAt':DateTime.now().toIso8601String(),'read':false,'bookingId':bookingId});}catch(notificationError){debugPrint('Booking notification failed: $notificationError');}_trackActivity('booking');note('تم إرسال طلب الحجز إلى الإدارة');await load();}catch(e){note('تعذر إرسال طلب الحجز إلى الإدارة: $e');}}}
  phone.dispose();notes.dispose();
 }
 Future<void> sendMessage()async{
  final value=messageCtrl.text.trim();
  final user=FirebaseAuth.instance.currentUser;
  if(value.isEmpty||user==null||sendingMessage)return;
  final now=DateTime.now();
  final localId='local_${now.microsecondsSinceEpoch}';
  final optimistic=<String,dynamic>{'id':localId,'_localId':localId,'conversationId':conversationId,'senderId':user.uid,'sender':'عميل','type':'text','text':value,'createdAt':now.toIso8601String(),'pending':true};
  messageCtrl.clear();
  setState(()=>messages.add(optimistic));
  WidgetsBinding.instance.addPostFrameCallback((_){if(clientChatScrollController.hasClients)clientChatScrollController.animateTo(0,duration:const Duration(milliseconds:180),curve:Curves.easeOut);});
  try{
    final savedId=await SharedStore.save('messages',{'conversationId':conversationId,'senderId':user.uid,'sender':'عميل','type':'text','text':value,'createdAt':now.toIso8601String()});
    if(mounted){setState(()=>messages=messages.map((m)=>m['_localId']==localId?({...m,'id':savedId,'pending':false}):m).toList());}
    unawaited(_trackActivity('message'));
    unawaited(()async{
      try{
        final profile=await FirebaseFirestore.instance.collection('profiles').doc(user.uid).get();
        final data=profile.data()??<String,dynamic>{};
        final senderName=(data['displayName']??user.displayName??'عميل').toString();
        await SharedStore.save('notifications',{'target':'admin','createdBy':user.uid,'customerId':user.uid,'conversationId':conversationId,'type':'message','title':'رسالة من $senderName','senderName':senderName,'senderImageUrl':data['avatarUrl']??data['photoUrl']??'','body':value,'createdAt':now.toIso8601String(),'read':false});
      }catch(notificationError){debugPrint('Message notification failed: $notificationError');}
    }());
  }catch(e){
    if(mounted){setState(()=>messages.removeWhere((m)=>m['_localId']==localId));if(messageCtrl.text.isEmpty)messageCtrl.text=value;note('تعذر إرسال الرسالة: $e');}
  }
}
 Future<void> shareMemberProfile()async{
  if(members.isEmpty){note('لا يوجد أعضاء متاحون للمشاركة');return;}
  final chosen=await showModalBottomSheet<Map<String,dynamic>>(context:context,isScrollControlled:true,builder:(ctx)=>Directionality(textDirection:TextDirection.rtl,child:SafeArea(child:ListView(shrinkWrap:true,children:[const Padding(padding:EdgeInsets.all(16),child:Text('اختر ملف العضو لإرساله',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold))),...members.map((m)=>ListTile(leading:photo(m,size:48),title:Text('${m['name']??''}'),subtitle:Text('ملف العضو'),onTap:()=>Navigator.pop(ctx,m)))]))));
  if(chosen==null)return;
  await SharedStore.save('messages',{'conversationId':conversationId,'senderId':FirebaseAuth.instance.currentUser!.uid,'sender':'عميل','type':'memberProfile','memberId':chosen['id'],'memberName':chosen['name'],'text':'ملف العضو: ${chosen['name']}','createdAt':DateTime.now().toIso8601String()});
  await SharedStore.save('notifications',{'target':'admin','createdBy':FirebaseAuth.instance.currentUser!.uid,'customerId':FirebaseAuth.instance.currentUser!.uid,'conversationId':conversationId,'type':'message','title':'مشاركة ملف عضو جديدة','body':'شارك العميل ملف العضو ${chosen['name']}','createdAt':DateTime.now().toIso8601String(),'read':false});
  _trackActivity('message');
  await load(silent:true);note('تم إرسال ملف العضو داخل المحادثة');
 }
  Map<String,dynamic>? findMemberById(dynamic id){for(final member in members){if(member['id'].toString()==id?.toString())return member;}return null;}
 Widget chatMessage(Map<String,dynamic> msg){
  final mine=msg['sender']=='عميل';
  final member=msg['type']=='memberProfile'?findMemberById(msg['memberId']):null;
  final accent=Theme.of(context).colorScheme.primary;
  final stamp=DateTime.tryParse('${msg['createdAt']??''}');
  final timeLabel=stamp==null?'':TimeOfDay.fromDateTime(stamp.toLocal()).format(context);
  final bubbleTint=mine?const Color(0x33D8B878):const Color(0x3359452F);
  return Align(
   alignment:mine?Alignment.centerRight:Alignment.centerLeft,
   child:Container(
    constraints:const BoxConstraints(maxWidth:330),
    margin:const EdgeInsets.symmetric(vertical:6),
    child:GlassPanel(
     radius:mine?21:17,
     tint:bubbleTint,
     child:Container(
      decoration:BoxDecoration(
       borderRadius:BorderRadius.circular(mine?21:17),
       border:Border.all(color:mine?const Color(0xFFD8B878).withOpacity(.72):const Color(0xFF80664A).withOpacity(.58),width:1.15)
      ),
      child:Padding(
       padding:const EdgeInsets.all(12),
       child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        if(msg['pending']==true)const Align(alignment:Alignment.centerLeft,child:SizedBox(width:10,height:10,child:CircularProgressIndicator(strokeWidth:1.5))),
        const SizedBox(height:4),
        if(member!=null)InkWell(onTap:()=>openMember(member),child:GlassPanel(radius:17,child:Padding(padding:const EdgeInsets.all(10),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
         Row(children:[ClipRRect(borderRadius:BorderRadius.circular(13),child:photo(member,size:68)),const SizedBox(width:11),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${member['name']??'عضو الكادر'}',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w900,fontSize:15)),const SizedBox(height:5),Text('${member['hourlyPrice']??0} د.ع / ساعة',style:TextStyle(color:accent,fontWeight:FontWeight.w800)),const SizedBox(height:4),_memberInfoPill(member['available']==false?'غير متاح':'متاح للحجز',member['available']==false?Colors.grey:teal)])),Icon(Icons.open_in_new_rounded,color:accent)]),
         const SizedBox(height:9),Row(children:[Expanded(child:Text(member['hasPlace']==true?'يوجد مكان':'بدون مكان',style:TextStyle(fontSize:11,color:Theme.of(context).hintColor))),TextButton.icon(onPressed:()=>openMember(member),icon:const Icon(Icons.person_search_rounded,size:17),label:const Text('عرض الملف'))])
        ])))),
        if(msg['type']=='bookingCard')bookingMessageCard(msg),
        if(msg['type']!='memberProfile'&&msg['type']!='bookingCard'||member==null&&msg['type']=='memberProfile')
         Text('${msg['text']??'تعذر العثور على ملف العضو'}',style:TextStyle(height:1.45,color:Theme.of(context).colorScheme.onSurface)),
        const SizedBox(height:7),
        Row(mainAxisSize:MainAxisSize.min,children:[
         if(timeLabel.isNotEmpty)Text(timeLabel,style:TextStyle(fontSize:10,color:Theme.of(context).hintColor)),
         if(msg['pending']!=true&&timeLabel.isNotEmpty)...[
          const SizedBox(width:4),Icon(Icons.done_all_rounded,size:13,color:mine?accent:Theme.of(context).hintColor)
         ]
        ])
       ])
      )
     )
    )
   )
  );
 }
 Widget bookingMessageCard(Map<String,dynamic> msg)=>GlassPanel(radius:16,child:Padding(padding:const EdgeInsets.all(10),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
  const Row(children:[Icon(Icons.event_available,color:teal),SizedBox(width:7),Text('بطاقة حجز',style:TextStyle(fontWeight:FontWeight.bold,color:plum))]),
  const SizedBox(height:6),
  Text('العميل: ${msg['customerName']??'-'}'),
  Text('عضو الكادر: ${msg['memberName']??'-'}'),
  Text('الموعد: ${msg['date']??'-'}'),
  Text('الحالة: ${msg['status']??'قيد المراجعة'}',style:const TextStyle(fontWeight:FontWeight.bold,color:teal)),
 ])));
 List<String> imageList(Map<String,dynamic> item){final raw=item['images'];if(raw is List)return raw.whereType<String>().where((v)=>v.isNotEmpty).toList();return <String>[];}
 void viewImages(List<String> images,int initial){
  if(images.isEmpty)return;
  final page=PageController(initialPage:initial);
  showDialog(context:context,barrierColor:Colors.black,builder:(ctx)=>Dialog(
   insetPadding:EdgeInsets.zero,backgroundColor:Colors.black,
   child:Stack(fit:StackFit.expand,children:[
    PageView.builder(controller:page,itemCount:images.length,itemBuilder:(ctx,i)=>LayoutBuilder(builder:(ctx,box)=>Center(child:InteractiveViewer(
     minScale:.8,maxScale:4,panEnabled:true,child:appImage(images[i],fit:BoxFit.contain,width:box.maxWidth,height:box.maxHeight,
      errorBuilder:(_,__,___)=>const Center(child:Icon(Icons.broken_image_outlined,color:Colors.white,size:54)))
    )))),
    Positioned(top:18,right:18,child:IconButton(style:IconButton.styleFrom(backgroundColor:Colors.white.withOpacity(.14)),onPressed:()=>Navigator.pop(ctx),icon:const Icon(Icons.close,color:Colors.white,size:28))),
    if(images.length>1)Positioned(top:25,left:18,child:Container(padding:const EdgeInsets.symmetric(horizontal:13,vertical:7),decoration:BoxDecoration(color:Colors.white.withOpacity(.15),borderRadius:BorderRadius.circular(20),border:Border.all(color:gold.withOpacity(.5))),child:Text('${(page.hasClients ? (page.page?.round() ?? initial) : initial)+1}/${images.length}',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w800)))),
    Positioned(bottom:22,left:0,right:0,child:Center(child:Container(padding:const EdgeInsets.symmetric(horizontal:16,vertical:9),decoration:BoxDecoration(color:Colors.white.withOpacity(.12),borderRadius:BorderRadius.circular(22),border:Border.all(color:gold.withOpacity(.35))),child:Text(images.length>1?'اسحب للتنقل بين الصور':'كبّر الصورة بإصبعين',style:const TextStyle(color:Colors.white,fontSize:12)))))
   ])
  ));
 }
 Widget imageGallery(Map<String,dynamic> item,{double height=190}){final imgs=imageList(item);if(imgs.isEmpty)return const SizedBox.shrink();return SizedBox(height:height,child:PageView.builder(itemCount:imgs.length,itemBuilder:(ctx,i)=>GestureDetector(onTap:()=>viewImages(imgs,i),child:Stack(fit:StackFit.expand,children:[appImage(imgs[i],fit:BoxFit.cover,errorBuilder:(_,__,___)=>const Center(child:Icon(Icons.broken_image))),if(imgs.length>1)Positioned(top:9,left:9,child:Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:5),decoration:BoxDecoration(color:Colors.black54,borderRadius:BorderRadius.circular(20)),child:Text('${i+1}/${imgs.length}',style:const TextStyle(color:Colors.white))))]))));}
 void openFavorites(){showModalBottomSheet(context:context,isScrollControlled:true,builder:(ctx)=>Directionality(textDirection:TextDirection.rtl,child:SafeArea(child:SizedBox(height:MediaQuery.of(ctx).size.height*.72,child:Column(children:[Padding(padding:const EdgeInsets.all(16),child:Row(children:[const Icon(Icons.favorite,color:rose),const SizedBox(width:8),const Expanded(child:Text('المفضلة',style:TextStyle(fontSize:21,fontWeight:FontWeight.bold))),IconButton(onPressed:()=>Navigator.pop(ctx),icon:const Icon(Icons.close))])),Expanded(child:members.where(isFav).isEmpty?const Center(child:Text('لم تضف أي عضو إلى المفضلة بعد')):ListView(padding:const EdgeInsets.all(12),children:members.where(isFav).map(memberCard).toList()))])))));}
 Widget photo(Map<String,dynamic> m,{double size=66}){final images=List<String>.from(m['images']??[]);if(images.isEmpty)return CircleAvatar(radius:size/2,child:const Icon(Icons.spa_outlined));try{return ClipRRect(borderRadius:BorderRadius.circular(12),child:appImage(images.first,width:size,height:size,fit:BoxFit.cover));}catch(_){return CircleAvatar(radius:size/2,child:const Icon(Icons.spa));}}
 void openMember(Map<String,dynamic> m){_trackActivity('profile_view');Navigator.push(context,MaterialPageRoute(builder:(_)=>Scaffold(appBar:AppBar(flexibleSpace:const DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.centerRight,end:Alignment.centerLeft,colors:[Color(0xFFAD1457),Color(0xFFE91E63),Color(0xFFF48FB1)]))),backgroundColor:Colors.transparent,title:Text('${m['name']??'الملف الشخصي'}')),body:Directionality(textDirection:TextDirection.rtl,child:memberProfilePage(m)))));}
 void previewMember(Map<String,dynamic> m){showModalBottomSheet(context:context,isScrollControlled:true,builder:(c)=>Directionality(textDirection:TextDirection.rtl,child:SafeArea(child:Padding(padding:const EdgeInsets.fromLTRB(18,12,18,22),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
  Center(child:Container(width:42,height:4,decoration:BoxDecoration(color:Colors.grey.shade400,borderRadius:BorderRadius.circular(4)))),
  const SizedBox(height:12),
  imageGallery(m,height:220),
  const SizedBox(height:12),Text('${m['name']??''}',style:const TextStyle(fontSize:21,fontWeight:FontWeight.bold)),
  Text('العمر: ${m['age']??'-'}  •  الساعة: ${m['hourlyPrice']??0} د.ع'),
  if((m['description']??'').toString().isNotEmpty)Padding(padding:const EdgeInsets.only(top:8),child:Text('${m['description']}')),
  const SizedBox(height:14),Row(children:[Expanded(child:OutlinedButton.icon(onPressed:(){Navigator.pop(c);openMember(m);},icon:const Icon(Icons.person),label:const Text('الملف الكامل'))),const SizedBox(width:8),Expanded(child:FilledButton.icon(onPressed:(){Navigator.pop(c);book(m);},icon:const Icon(Icons.calendar_month),label:const Text('احجز الآن')))])
 ])))));}
 Future<void> messageMember(Map<String,dynamic> m)async{
  final user=FirebaseAuth.instance.currentUser;
  if(user==null){note('يرجى تسجيل الدخول أولاً');return;}
  try{
   final now=DateTime.now();
   await SharedStore.save('messages',{'conversationId':conversationId,'senderId':user.uid,'sender':'عميل','type':'memberProfile','memberId':m['id'],'memberName':m['name'],'text':'ملف العضو: ${m['name']}','createdAt':now.toIso8601String()});
   await SharedStore.save('notifications',{'target':'admin','createdBy':user.uid,'customerId':user.uid,'conversationId':conversationId,'type':'message','title':'مشاركة ملف عضو جديدة','body':'يرغب العميل بمراسلة الإدارة حول عضو الكادر ${m['name']}','createdAt':now.toIso8601String(),'read':false});
   _trackActivity('message');
   if(!mounted)return;
   setState(()=>tab=1);
   await load(silent:true);
   note('تم إرسال بطاقة ${m['name']} وفتح المحادثة');
  }catch(e){if(mounted)note('تعذر إرسال بطاقة العضو: $e');}
 }
 Widget memberProfilePage(Map<String,dynamic> m)=>ListView(padding:const EdgeInsets.fromLTRB(14,14,14,28),children:[
   ClipRRect(borderRadius:BorderRadius.circular(26),child:Stack(children:[
    imageGallery(m,height:290),
    Positioned(right:14,bottom:14,left:68,child:Container(padding:const EdgeInsets.symmetric(horizontal:14,vertical:8),decoration:BoxDecoration(color:Colors.black.withOpacity(.58),borderRadius:BorderRadius.circular(16),border:Border.all(color:gold.withOpacity(.55))),child:Text('${m['name']??'عضو الكادر'}',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white,fontSize:20,fontWeight:FontWeight.w900)))),
    Positioned(left:12,top:12,child:ClipRRect(borderRadius:BorderRadius.circular(18),child:Container(decoration:BoxDecoration(color:Colors.black.withOpacity(.42),border:Border.all(color:gold.withOpacity(.45)),borderRadius:BorderRadius.circular(18)),child:IconButton(tooltip:isFav(m)?'إزالة من المفضلة':'إضافة إلى المفضلة',onPressed:()=>toggleFav(m),icon:Icon(isFav(m)?Icons.favorite_rounded:Icons.favorite_border_rounded,color:isFav(m)?rose:Colors.white,size:23))))),
   ])),
   const SizedBox(height:14),
   GlassPanel(padding:const EdgeInsets.all(14),radius:22,child:Column(children:[
    Row(children:[
     Expanded(child:_memberInfoTile(Icons.payments_outlined,'سعر الساعة','${m['hourlyPrice']??0} د.ع')),
     const SizedBox(width:8),
     Expanded(child:_memberInfoTile(Icons.nights_stay_outlined,'سعر الليلة','${m['nightlyPrice']??0} د.ع')),
    ]),
    const Divider(height:22),
    Row(children:[
     Expanded(child:_memberInfoTile(Icons.cake_outlined,'العمر','${m['age']??'-'}')),
     const SizedBox(width:8),
     Expanded(child:_memberInfoTile(Icons.place_outlined,'المكان',m['hasPlace']==true?'متاح':'لا يوجد')),
    ]),
    if((m['address']??'').toString().isNotEmpty)...[
     const Divider(height:22),
     _memberInfoTile(Icons.location_on_outlined,'العنوان','${m['address']}'),
    ],
   ])),
   if((m['description']??'').toString().isNotEmpty)...[
    const SizedBox(height:12),
    GlassPanel(padding:const EdgeInsets.all(16),radius:22,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
     const Text('نبذة عن عضو الكادر',style:TextStyle(fontSize:16,fontWeight:FontWeight.w900)),
     const SizedBox(height:8),Text('${m['description']}',style:const TextStyle(height:1.6)),
    ])),
   ],
   const SizedBox(height:16),
   Row(children:[
    Expanded(child:GlassActionButton(onPressed:()=>book(m),label:'احجز موعداً',icon:Icons.calendar_month_rounded,expanded:true)),
    const SizedBox(width:10),
    Expanded(child:GlassActionButton(onPressed:()=>messageMember(m),label:'مراسلة',icon:Icons.chat_bubble_outline_rounded,expanded:true)),
   ]),
  ]);
Widget _memberInfoTile(IconData icon,String label,String value)=>Row(children:[
 Icon(icon,color:gold,size:21),const SizedBox(width:8),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
  Text(label,style:TextStyle(fontSize:11,color:Theme.of(context).hintColor)),
  Text(value,style:const TextStyle(fontWeight:FontWeight.w800,fontSize:14),maxLines:2,overflow:TextOverflow.ellipsis),
 ])),
]);
Widget _memberInfoPill(String label,Color color)=>Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:5),decoration:BoxDecoration(color:color.withOpacity(.13),borderRadius:BorderRadius.circular(10),border:Border.all(color:color.withOpacity(.24))),child:Text(label,style:TextStyle(fontSize:10,fontWeight:FontWeight.w800,color:color)));
 Widget memberCard(Map<String,dynamic> m)=>GlassPanel(radius:23,child:InkWell(borderRadius:BorderRadius.circular(23),onTap:()=>openMember(m),onLongPress:()=>previewMember(m),child:Padding(padding:const EdgeInsets.all(10),child:Row(children:[
  ClipRRect(borderRadius:BorderRadius.circular(16),child:photo(m,size:104)),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${m['name']??''}',style:const TextStyle(fontWeight:FontWeight.w900,fontSize:16)),const SizedBox(height:4),Text('العمر: ${m['age']??'-'} • ${m['hourlyPrice']??0} د.ع/ساعة',maxLines:1,overflow:TextOverflow.ellipsis),const SizedBox(height:5),Wrap(spacing:6,runSpacing:4,children:[_memberInfoPill(m['available']==false?'محجوز':'متاح',m['available']==false?Colors.grey:teal),if(('${m['province']??''} ${m['area']??m['district']??''}').trim().isNotEmpty)Text('${m['province']??''}${(m['area']??m['district']??'').toString().isNotEmpty?'، ':''}${m['area']??m['district']??''}',maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(fontSize:11,color:Theme.of(context).hintColor))])])),
  IconButton(onPressed:()=>toggleFav(m),style:IconButton.styleFrom(backgroundColor:rose.withOpacity(.10)),icon:Icon(isFav(m)?Icons.favorite:Icons.favorite_border,color:isFav(m)?rose:plum)),
  const Icon(Icons.chevron_left)
  ]))));
 Widget memberGridCard(Map<String,dynamic> m)=>GlassPanel(radius:22,child:InkWell(borderRadius:BorderRadius.circular(22),onTap:()=>openMember(m),onLongPress:()=>previewMember(m),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
  Expanded(child:Stack(fit:StackFit.expand,children:[ClipRRect(borderRadius:const BorderRadius.vertical(top:Radius.circular(21)),child:photo(m,size:230)),Positioned(left:7,top:7,child:IconButton(onPressed:()=>toggleFav(m),style:IconButton.styleFrom(backgroundColor:Colors.white.withOpacity(.92),minimumSize:const Size(36,36),padding:EdgeInsets.zero),icon:Icon(isFav(m)?Icons.favorite:Icons.favorite_border,color:rose,size:19))),const SizedBox.shrink()])),
  Padding(padding:const EdgeInsets.fromLTRB(10,8,10,10),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
   Text('${m['name']??''}',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w900,fontSize:15)),
   const SizedBox(height:3),
   Text('${m['hourlyPrice']??0} د.ع/ساعة',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:12,color:plum,fontWeight:FontWeight.w800)),
   const SizedBox(height:5),
   if(('${m['province']??''} ${m['area']??m['district']??''}').trim().isNotEmpty)Row(children:[
    Icon(Icons.location_on_outlined,size:14,color:plum),
    const SizedBox(width:3),
    Expanded(child:Text('${m['province']??''}${(m['area']??m['district']??'').toString().isNotEmpty?'، ':''}${m['area']??m['district']??''}',maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(fontSize:10,color:Theme.of(context).hintColor))),
   ]),
   if((m['description']??'').toString().trim().isNotEmpty)Text('${m['description']}',maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(fontSize:10,color:Theme.of(context).hintColor)),
  ]))
 ])));
 void openBanner(Map<String,dynamic> b){
  final member=findMemberById(b['linkedMemberId']??(b['targetType']=='member'?b['targetId']:null));
  if(member!=null){openMember(member);return;}
  final sessionId=(b['linkedSessionId']??(b['targetType']=='session'?b['targetId']:null))?.toString();
  Map<String,dynamic>? linkedSession;
  for(final session in sessions){if(session['id']?.toString()==sessionId){linkedSession=session;break;}}
  if(linkedSession!=null){
   showDialog(context:context,builder:(ctx)=>Directionality(textDirection:TextDirection.rtl,child:AlertDialog(
    title:Text('${linkedSession!['title']??'الجلسة'}'),
    content:SizedBox(width:360,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
     imageGallery(linkedSession!,height:180),
     const SizedBox(height:8),
     Text('${linkedSession!['date']??''}'),
     Text('${linkedSession!['description']??''}'),
    ]))),
    actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إغلاق'))],
   )));
   return;
  }
  final imgs=imageList(b);
  if(imgs.isNotEmpty){viewImages(imgs,0);return;}
  showDialog(context:context,builder:(ctx)=>AlertDialog(title:Text('${b['title']??'إعلان'}'),content:Text('${b['description']??''}'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إغلاق'))]));
 }
 Widget bannerCard(Map<String,dynamic> b)=>Card(clipBehavior:Clip.antiAlias,margin:const EdgeInsets.symmetric(horizontal:1,vertical:2),child:InkWell(onTap:()=>openBanner(b),child:Stack(fit:StackFit.expand,children:[
 if(imageList(b).isNotEmpty)appImage(imageList(b).first,fit:BoxFit.cover,errorBuilder:(_,__,___)=>Container(color:plum,child:const Icon(Icons.broken_image,color:Colors.white,size:40))) else Container(color:plum,child:const Icon(Icons.image_outlined,color:Colors.white,size:42)),
 
 Positioned(right:18,left:18,bottom:15,child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[
  if('${b['title']??''}'.toString().trim().isNotEmpty)Text('${b['title']}',maxLines:2,overflow:TextOverflow.ellipsis,style:GoogleFonts.cairo(color:Colors.white,fontSize:21,fontWeight:FontWeight.w800,)),
  if('${b['description']??''}'.toString().trim().isNotEmpty)Padding(padding:const EdgeInsets.only(top:3),child:Text('${b['description']}',maxLines:2,overflow:TextOverflow.ellipsis,style:GoogleFonts.cairo(color:Colors.white,fontSize:13,fontWeight:FontWeight.w600,)))
 ]))
])));
 void openMemberFilters(){
  showModalBottomSheet(context:context,isScrollControlled:true,backgroundColor:Colors.transparent,builder:(sheetContext)=>StatefulBuilder(builder:(sheetContext,setSheetState)=>Directionality(textDirection:TextDirection.rtl,child:GlassPanel(radius:26,margin:const EdgeInsets.all(10),padding:const EdgeInsets.all(18),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
   Row(children:[const Expanded(child:Text('تصفية الكادر',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900))),IconButton(onPressed:()=>Navigator.pop(sheetContext),icon:const Icon(Icons.close_rounded))]),
   const SizedBox(height:12),const Text('حالة التوفر',style:TextStyle(fontWeight:FontWeight.w800)),
   Wrap(spacing:8,children:[
    ChoiceChip(label:const Text('الكل'),selected:availabilityFilter=='all',onSelected:(_){setState(()=>availabilityFilter='all');setSheetState((){});}),
    ChoiceChip(label:const Text('متاح'),selected:availabilityFilter=='available',onSelected:(_){setState(()=>availabilityFilter='available');setSheetState((){});}),
    ChoiceChip(label:const Text('محجوز'),selected:availabilityFilter=='booked',onSelected:(_){setState(()=>availabilityFilter='booked');setSheetState((){});}),
   ]),
   const SizedBox(height:12),const Text('المكان',style:TextStyle(fontWeight:FontWeight.w800)),
   SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('يوجد مكان'),value:onlyWithPlace,onChanged:(v){setState(()=>onlyWithPlace=v);setSheetState((){});}),
   const SizedBox(height:10),Row(children:[
    Expanded(child:OutlinedButton(onPressed:(){setState((){onlyWithPlace=false;availabilityFilter='all';});setSheetState((){});},child:const Text('مسح الفلاتر'))),
    const SizedBox(width:10),Expanded(child:FilledButton(onPressed:()=>Navigator.pop(sheetContext),child:const Text('عرض النتائج'))),
   ])
  ])))));
 }
Widget homePage(){
  final visible=members.where((m)=>(availabilityFilter=='all'||(availabilityFilter=='available'&&m['available']!=false)||(availabilityFilter=='booked'&&m['available']==false))&&(!onlyWithPlace||m['hasPlace']==true)&&'${m['name']} ${m['description']}'.toLowerCase().contains(search.toLowerCase())).toList();
  visible.sort((a,b){
   final ap=double.tryParse('${a['hourlyPrice']??0}')??0, bp=double.tryParse('${b['hourlyPrice']??0}')??0;
   if(memberSort=='low')return ap.compareTo(bp);
   if(memberSort=='high')return bp.compareTo(ap);
   if(memberSort=='name')return '${a['name']??''}'.toLowerCase().compareTo('${b['name']??''}'.toLowerCase());
   return 0;
  });
   final featuredMembers=members.where((m)=>m['featured']==true&&m['available']!=false).toList();
  return ListView(padding:const EdgeInsets.fromLTRB(12,14,12,18),children:[
    if(featuredMembers.isNotEmpty)...[
     const Padding(padding:EdgeInsets.only(top:14,bottom:8),child:Text('الكادر المميز',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900))),
     SizedBox(height:158,child:ListView.separated(scrollDirection:Axis.horizontal,itemCount:featuredMembers.length,separatorBuilder:(_,__)=>const SizedBox(width:10),itemBuilder:(ctx,i){final m=featuredMembers[i];return SizedBox(width:126,child:InkWell(onTap:()=>openMember(m),borderRadius:BorderRadius.circular(20),child:GlassPanel(radius:20,padding:const EdgeInsets.all(8),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[Expanded(child:ClipRRect(borderRadius:BorderRadius.circular(14),child:photo(m,size:100))),const SizedBox(height:6),Text('${m['name']??'عضو الكادر'}',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w800,fontSize:12)),Text('${m['hourlyPrice']??0} د.ع/ساعة',style:TextStyle(fontSize:10,color:Theme.of(context).hintColor))]))));})),
    ],
   if(banners.isNotEmpty)...[SizedBox(height:210,child:PageView.builder(controller:bannerPager,itemCount:banners.length,onPageChanged:(i)=>setState(()=>bannerIndex=i),itemBuilder:(ctx,i)=>bannerCard(banners[i]))),if(banners.length>1)Padding(padding:const EdgeInsets.only(top:8,bottom:2),child:Row(mainAxisAlignment:MainAxisAlignment.center,children:List.generate(banners.length,(i)=>AnimatedContainer(duration:const Duration(milliseconds:250),margin:const EdgeInsets.symmetric(horizontal:3),width:bannerIndex==i?18:6,height:6,decoration:BoxDecoration(color:bannerIndex==i?rose:plum.withOpacity(.25),borderRadius:BorderRadius.circular(8))))))],
   if(announcements.isNotEmpty)...[
    const Padding(padding:EdgeInsets.only(top:14,bottom:8),child:Text('الإعلانات والتنبيهات',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900))),
    ...announcements.map((a)=>Card(clipBehavior:Clip.antiAlias,child:Column(children:[if(imageList(a).isNotEmpty)imageGallery(a,height:150),ListTile(leading:const Icon(Icons.campaign_rounded,color:rose),title:Text('${a['title']??'إعلان'}'),subtitle:Text('${a['body']??''}'))]))),
   ],
   const SizedBox(height:18),
   const SizedBox(height:15),
   Row(children:[
    const Expanded(child:Text('اكتشف الكادر',style:TextStyle(fontSize:22,fontWeight:FontWeight.w900))),
    Text('${visible.length} نتيجة',style:TextStyle(fontSize:12,color:Theme.of(context).colorScheme.onSurface.withOpacity(.65),fontWeight:FontWeight.w700)),
    const SizedBox(width:8),
    IconButton(tooltip:compactMembers?'عرض البطاقات':'عرض مختصر',onPressed:()=>setState(()=>compactMembers=!compactMembers),icon:Icon(compactMembers?Icons.grid_view_rounded:Icons.view_agenda_rounded)),
   ]),
   const SizedBox(height:8),
   Row(children:[
    Expanded(child:DropdownButtonFormField<String>(value:memberSort,decoration:const InputDecoration(prefixIcon:Icon(Icons.sort_rounded),contentPadding:EdgeInsets.symmetric(horizontal:12,vertical:8),isDense:true),items:const[
     DropdownMenuItem(value:'recommended',child:Text('الترتيب المقترح')),
     DropdownMenuItem(value:'low',child:Text('السعر: الأقل أولاً')),
     DropdownMenuItem(value:'high',child:Text('السعر: الأعلى أولاً')),
     DropdownMenuItem(value:'name',child:Text('الاسم: أ إلى ي')),
    ],onChanged:(v)=>setState(()=>memberSort=v??'recommended'))),
    const SizedBox(width:8),
    IconButton(tooltip:'الفلاتر',onPressed:openMemberFilters,icon:Badge(isLabelVisible:onlyWithPlace||availabilityFilter!='all',child:const Icon(Icons.filter_alt_rounded))),
   ]),
   const SizedBox(height:12),
   if(visible.isEmpty)GlassPanel(child:Column(children:[
    const Icon(Icons.search_off_rounded,size:38),
    const SizedBox(height:8),
    const Text('لا توجد نتائج مطابقة',style:TextStyle(fontWeight:FontWeight.w800,fontSize:16)),
    const Text('جرّب تغيير عبارة البحث أو إعادة ضبط الترتيب'),
    const SizedBox(height:8),
    TextButton.icon(onPressed:()=>setState(()=>search=''),icon:const Icon(Icons.refresh_rounded),label:const Text('عرض الكادر المتوفر')),
   ]))
   else if(compactMembers) ...visible.map((m)=>Card(child:ListTile(
    onTap:()=>openMember(m),leading:photo(m,size:54),title:Text('${m['name']??'عضو الكادر'}',style:const TextStyle(fontWeight:FontWeight.w800)),
    subtitle:Text('${m['hourlyPrice']??0} د.ع/ساعة • ${m['hasPlace']==true?'يوجد مكان':'لا يوجد مكان'}'),
    trailing:IconButton(onPressed:()=>toggleFav(m),icon:Icon(isFav(m)?Icons.favorite:Icons.favorite_border,color:rose)),
   )))
   else GridView.builder(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),itemCount:visible.length,
    gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:2,crossAxisSpacing:10,mainAxisSpacing:10,childAspectRatio:.62),
    itemBuilder:(context,index)=>memberGridCard(visible[index])),
  ]);
 }
 Widget sessionsPage()=>ListView(padding:const EdgeInsets.fromLTRB(14,16,14,24),children:[
  const Text('أرشيف الجلسات',style:TextStyle(fontSize:23,fontWeight:FontWeight.w800)),
  const SizedBox(height:5),
  const Text('استعرض الصور والتفاصيل المحفوظة للجلسات',style:TextStyle(color:Colors.grey)),
  const SizedBox(height:14),
  if(sessions.isEmpty)GlassPanel(child:Padding(padding:const EdgeInsets.all(28),child:Column(children:[Icon(Icons.photo_library_outlined,size:42,color:Theme.of(context).colorScheme.primary),const SizedBox(height:10),const Text('لا توجد جلسات في الأرشيف حالياً',style:TextStyle(fontWeight:FontWeight.bold))]))),
  ...sessions.map((session)=>Padding(padding:const EdgeInsets.only(bottom:12),child:GlassPanel(radius:22,child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
   ClipRRect(borderRadius:const BorderRadius.vertical(top:Radius.circular(22)),child:imageGallery(session,height:190)),
   Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text('${session['title']??'جلسة'}',style:const TextStyle(fontSize:17,fontWeight:FontWeight.bold)),
    const SizedBox(height:5),
    Text('${session['date']??''} • ${session['description']??''}',style:TextStyle(color:Theme.of(context).colorScheme.onSurface.withOpacity(.65)))
   ]))
  ])))),
 ]);

 Widget bookingsPage()=>ListView(padding:const EdgeInsets.fromLTRB(14,16,14,24),children:[
  const Text('طلباتي وحجوزاتي',style:TextStyle(fontSize:23,fontWeight:FontWeight.w800)),
  const SizedBox(height:5),
  Text('تابع حالة مواعيدك وتفاصيل كل حجز',style:TextStyle(color:Theme.of(context).colorScheme.onSurface.withOpacity(.62))),
  const SizedBox(height:16),
  GlassActionButton(label:'حجز موعد جديد',icon:Icons.add_circle_outline,onPressed:()=>book()),
  const SizedBox(height:14),
  if(bookings.isEmpty)GlassPanel(child:Padding(padding:const EdgeInsets.symmetric(vertical:28),child:Column(children:[Icon(Icons.event_busy_rounded,size:42,color:Theme.of(context).colorScheme.primary),const SizedBox(height:12),const Text('لا توجد حجوزات حتى الآن',style:TextStyle(fontWeight:FontWeight.bold,fontSize:16)),const SizedBox(height:5),const Text('يمكنك إنشاء حجز جديد من الزر أعلاه',style:TextStyle(color:Colors.grey))]))),
  ...bookings.map((b){
   final selected=b['id']?.toString()==selectedBookingId;
   return Padding(padding:const EdgeInsets.only(bottom:10),child:GlassPanel(tint:selected?Theme.of(context).colorScheme.primary.withOpacity(.10):null,child:ListTile(
    contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:5),
    leading:Container(width:44,height:44,decoration:BoxDecoration(color:Theme.of(context).colorScheme.primary.withOpacity(.12),borderRadius:BorderRadius.circular(15)),child:Icon(Icons.event_available_rounded,color:Theme.of(context).colorScheme.primary)),
    title:Text('${b['memberName']??'حجز'}',style:const TextStyle(fontWeight:FontWeight.bold)),
    subtitle:Padding(padding:const EdgeInsets.only(top:5),child:Text('${b['date']??''} • ${b['status']??'قيد المراجعة'}')),
    trailing:const Icon(Icons.chevron_left_rounded),
    onTap:()=>showClientBooking(b)
   )));
  })
 ]);
 Widget chatPage()=>Column(children:[
  Padding(padding:const EdgeInsets.fromLTRB(14,8,14,4),child:GlassPanel(radius:18,padding:const EdgeInsets.symmetric(horizontal:13,vertical:10),child:Row(children:[Container(width:38,height:38,decoration:BoxDecoration(color:Theme.of(context).colorScheme.primary.withOpacity(.12),borderRadius:BorderRadius.circular(13)),child:Icon(Icons.support_agent_rounded,color:Theme.of(context).colorScheme.primary,size:23)),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('محادثة الإدارة',style:TextStyle(fontWeight:FontWeight.w900,fontSize:14)),Text('نحن هنا لمساعدتك',style:TextStyle(fontSize:11,color:Theme.of(context).hintColor))])),_memberInfoPill('محادثة خاصة',teal)]))),
  Expanded(child:messages.isEmpty?Center(child:GlassPanel(margin:const EdgeInsets.all(20),child:Padding(padding:const EdgeInsets.symmetric(vertical:30),child:Column(mainAxisSize:MainAxisSize.min,children:[Icon(Icons.forum_rounded,size:42,color:Theme.of(context).colorScheme.primary),const SizedBox(height:12),const Text('ابدأ المحادثة',style:TextStyle(fontSize:17,fontWeight:FontWeight.bold)),const SizedBox(height:5),const Text('اكتب رسالتك وسنكون معك',style:TextStyle(color:Colors.grey))])))):ListView.builder(controller:clientChatScrollController,reverse:true,padding:const EdgeInsets.all(12),itemCount:messages.length,itemBuilder:(context,index)=>chatMessage(messages[messages.length-1-index]))),
  SafeArea(child:Padding(padding:const EdgeInsets.fromLTRB(10,6,10,10),child:GlassPanel(radius:25,padding:const EdgeInsets.symmetric(horizontal:7,vertical:5),child:Row(crossAxisAlignment:CrossAxisAlignment.end,children:[
   IconButton(tooltip:'إرسال ملف عضو',onPressed:shareMemberProfile,style:IconButton.styleFrom(backgroundColor:Theme.of(context).colorScheme.primary.withOpacity(.10)),icon:Icon(Icons.person_add_alt_1_rounded,color:Theme.of(context).colorScheme.primary)),
   Expanded(child:TextField(controller:messageCtrl,focusNode:chatFocusNode,minLines:1,maxLines:4,scrollPadding:const EdgeInsets.only(bottom:180),decoration:const InputDecoration(hintText:'اكتب رسالتك...',border:InputBorder.none,contentPadding:EdgeInsets.symmetric(horizontal:9,vertical:13)),onTap:(){WidgetsBinding.instance.addPostFrameCallback((_){if(clientChatScrollController.hasClients)clientChatScrollController.jumpTo(0);});},onSubmitted:(_)=>sendMessage())),
   Padding(padding:const EdgeInsets.only(bottom:4),child:IconButton(onPressed:sendingMessage?null:sendMessage,tooltip:'إرسال',style:IconButton.styleFrom(backgroundColor:Theme.of(context).colorScheme.primary,foregroundColor:Colors.white,minimumSize:const Size(46,46)),icon:const Icon(Icons.send_rounded)))
  ])))),
 ]);
 Widget accountPage()=>const AccountPage();
 Widget currentPage()=>switch(tab){1=>chatPage(),2=>bookingsPage(),3=>sessionsPage(),4=>accountPage(),_=>homePage()};
 @override Widget build(BuildContext context){
  const labels=['الرئيسية','المحادثات','حجوزاتي','الجلسات','حسابي'];
  const icons=[Icons.home_rounded,Icons.forum_rounded,Icons.event_note_rounded,Icons.photo_library_rounded,Icons.person_rounded];
  final dark=Theme.of(context).brightness==Brightness.dark;
  final unread=notifications.where((n)=>n['read']!=true).length;
  return Directionality(textDirection:TextDirection.rtl,child:Scaffold(
   extendBody:true,
   backgroundColor:dark?const Color(0xFF11100E):const Color(0xFFF7F2E9),
    body:SafeArea(child:Column(children:[
     if(tab!=1&&headerVisible)Padding(padding:const EdgeInsets.fromLTRB(14,10,14,8),child:Container(
      padding:const EdgeInsets.symmetric(horizontal:14,vertical:11),
      decoration:BoxDecoration(color:dark?const Color(0xD923201B):const Color(0xDDFBF8F1),borderRadius:BorderRadius.circular(24),border:Border.all(color:gold.withOpacity(.28)),boxShadow:[BoxShadow(color:Colors.black.withOpacity(.045),blurRadius:20,offset:const Offset(0,7))]),
      child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
       Row(children:[Container(width:42,height:42,decoration:BoxDecoration(gradient:const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[Color(0xFFE9D4A8),Color(0xFFB78C4D)]),borderRadius:BorderRadius.circular(15)),child:const Icon(Icons.spa_rounded,color:Color(0xFF332719),size:25)),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('الشيخة',maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(fontSize:19,fontWeight:FontWeight.w900)),Text(labels[tab],maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(fontSize:11,color:dark?Colors.white60:const Color(0xFF806F59),fontWeight:FontWeight.w600))]))]),
       Row(mainAxisAlignment:MainAxisAlignment.end,children:[
        if(tab==0)IconButton(visualDensity:VisualDensity.compact,tooltip:'المفضلة',onPressed:openFavorites,icon:const Icon(Icons.favorite_border_rounded)),
        Badge(isLabelVisible:unread>0,label:Text('$unread'),child:IconButton(visualDensity:VisualDensity.compact,tooltip:'الإشعارات',onPressed:openNotifications,icon:const Icon(Icons.notifications_none_rounded))),
        IconButton(visualDensity:VisualDensity.compact,tooltip:dark?'الوضع الفاتح':'الوضع الداكن',onPressed:()=>setClientThemeMode(dark?ThemeMode.light:ThemeMode.dark),icon:Icon(dark?Icons.light_mode_rounded:Icons.dark_mode_rounded)),
       ]),
       if(tab==0)Padding(padding:const EdgeInsets.only(top:5),child:Container(height:43,decoration:BoxDecoration(color:dark?Colors.white.withOpacity(.07):const Color(0xFFF0E9DC),borderRadius:BorderRadius.circular(15),border:Border.all(color:gold.withOpacity(.25))),child:Row(children:[const SizedBox(width:10),Icon(Icons.search_rounded,color:gold,size:20),const SizedBox(width:8),Expanded(child:TextField(controller:searchCtrl,textInputAction:TextInputAction.search,onChanged:(v)=>setState(()=>search=v),decoration:const InputDecoration(hintText:'ابحث عن الكادر أو التخصص...',border:InputBorder.none,isDense:true,contentPadding:EdgeInsets.symmetric(vertical:10)))),if(search.isNotEmpty)IconButton(visualDensity:VisualDensity.compact,onPressed:(){setState(()=>search='');searchCtrl.clear();},icon:const Icon(Icons.close_rounded))]))),
      ]))),
     Expanded(child:NotificationListener<ScrollNotification>(onNotification:(n){if(tab==1)return false;if(n is ScrollUpdateNotification&&n.scrollDelta!=null&&n.depth==0){final next=n.scrollDelta!<0;if(next!=headerVisible)setState(()=>headerVisible=next);}if(n is ScrollStartNotification&&n.metrics.pixels<=0&&!headerVisible)setState(()=>headerVisible=true);return false;},child:busy?const Center(child:CircularProgressIndicator()):RefreshIndicator(onRefresh:load,color:gold,child:currentPage()))),
     if(tab!=1&&MediaQuery.of(context).viewInsets.bottom==0)Padding(padding:const EdgeInsets.fromLTRB(12,3,12,7),child:GlassPanel(radius:25,padding:const EdgeInsets.symmetric(horizontal:4,vertical:6),child:Row(mainAxisAlignment:MainAxisAlignment.spaceAround,children:[
      _navItem(0,Icons.home_rounded,'الرئيسية',tab,dark),
      _navItem(1,Icons.forum_rounded,'المحادثات',tab,dark,unread:unread),
      _navItem(3,Icons.photo_library_rounded,'الجلسات',tab,dark),
      InkWell(borderRadius:BorderRadius.circular(17),onTap:()=>showModalBottomSheet(context:context,backgroundColor:Colors.transparent,builder:(sheetContext)=>GlassPanel(radius:24,margin:const EdgeInsets.all(12),padding:const EdgeInsets.all(12),child:Column(mainAxisSize:MainAxisSize.min,children:[
       ListTile(leading:const Icon(Icons.event_note_rounded),title:const Text('حجوزاتي'),onTap:(){Navigator.pop(sheetContext);setState(()=>tab=2);}),
       ListTile(leading:const Icon(Icons.person_rounded),title:const Text('حسابي'),onTap:(){Navigator.pop(sheetContext);setState(()=>tab=4);}),
      ]))),child:Padding(padding:const EdgeInsets.symmetric(horizontal:14,vertical:7),child:Column(mainAxisSize:MainAxisSize.min,children:[Icon(Icons.more_horiz_rounded,color:tab==2||tab==4?gold:(dark?Colors.white70:const Color(0xFF806F59)),size:23),Text('المزيد',style:TextStyle(fontSize:10,fontWeight:FontWeight.w800,color:tab==2||tab==4?gold:(dark?Colors.white70:const Color(0xFF806F59))))]))),
     ]))),
    ])),
   ));
 }

 Widget _navItem(int index,IconData icon,String label,int activeTab,bool dark,{int unread=0}){
  final active=activeTab==index;
  final fg=active?const Color(0xFF342719):(dark?Colors.white70:const Color(0xFF806F59));
  return InkWell(borderRadius:BorderRadius.circular(17),onTap:()=>setState((){tab=index;headerVisible=true;}),child:AnimatedContainer(duration:const Duration(milliseconds:220),padding:EdgeInsets.symmetric(horizontal:active?13:10,vertical:7),decoration:BoxDecoration(gradient:active?const LinearGradient(colors:[Color(0xFFEAD8B5),Color(0xFFD2B47E)]):null,color:active?null:Colors.transparent,borderRadius:BorderRadius.circular(17)),child:Column(mainAxisSize:MainAxisSize.min,children:[Stack(clipBehavior:Clip.none,children:[Icon(icon,size:22,color:fg),if(index==1&&unread>0)Positioned(left:-7,top:-5,child:CircleAvatar(radius:4,backgroundColor:Color(0xFFB86C52)))]),const SizedBox(height:3),Text(label,style:TextStyle(fontSize:10,fontWeight:FontWeight.w800,color:fg))])));
 }
}
class MemberSearch extends SearchDelegate<String>{
 final List<Map<String,dynamic>> members;final ValueChanged<String> onPick;
 MemberSearch(this.members,{required this.onPick});
 @override List<Widget>? buildActions(BuildContext context)=>[IconButton(onPressed:()=>query='',icon:const Icon(Icons.clear))];
 @override Widget? buildLeading(BuildContext context)=>IconButton(onPressed:()=>close(context,''),icon:const Icon(Icons.arrow_back));
 @override Widget buildResults(BuildContext context)=>buildSuggestions(context);
 @override Widget buildSuggestions(BuildContext context)=>ListView(children:members.where((m)=>'${m['name']} ${m['description']}'.toLowerCase().contains(query.toLowerCase())).map((m)=>ListTile(title:Text('${m['name']}'),subtitle:Text('${m['address']??''}'),onTap:(){onPick(query);close(context,query);})).toList());


}
