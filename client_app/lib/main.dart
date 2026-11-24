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
import 'package:google_fonts/google_fonts.dart';
import 'shared_store.dart';
import 'image_utils.dart';
import 'account_page.dart';
import 'shared/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.android);
  await NotificationService.initialize();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor:Colors.transparent,statusBarIconBrightness:Brightness.dark,systemNavigationBarColor:Colors.transparent,systemNavigationBarIconBrightness:Brightness.dark));
  runApp(const SheikhaClientApp());
}
const rose=Color(0xFFE91E63), plum=Color(0xFF6A1B9A), cream=Color(0xFFFFF7FB), teal=Color(0xFF00A6A6), gold=Color(0xFFFFB300);
class SheikhaClientApp extends StatelessWidget{
 const SheikhaClientApp({super.key});
 @override Widget build(BuildContext context)=>MaterialApp(debugShowCheckedModeBanner:false,title:'الشيخة',theme:ThemeData(useMaterial3:true,colorScheme:ColorScheme.fromSeed(seedColor:plum,brightness:Brightness.light),scaffoldBackgroundColor:cream,textTheme:GoogleFonts.arefRuqaaTextTheme(),iconTheme:const IconThemeData(color:plum),inputDecorationTheme:InputDecorationTheme(filled:true,fillColor:Colors.white,border:OutlineInputBorder(borderRadius:BorderRadius.all(Radius.circular(14)))),appBarTheme:const AppBarTheme(backgroundColor:rose,foregroundColor:Colors.white,elevation:0),cardTheme:CardThemeData(color:Colors.white,elevation:2,shape:RoundedRectangleBorder(borderRadius:BorderRadius.all(Radius.circular(18)))),filledButtonTheme:FilledButtonThemeData(style:FilledButton.styleFrom(backgroundColor:rose,foregroundColor:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14)))),floatingActionButtonTheme:const FloatingActionButtonThemeData(backgroundColor:teal,foregroundColor:Colors.white)),darkTheme:ThemeData(useMaterial3:true,brightness:Brightness.dark,colorScheme:ColorScheme.fromSeed(seedColor:rose,brightness:Brightness.dark),textTheme:GoogleFonts.arefRuqaaTextTheme(ThemeData.dark().textTheme)),themeMode:ThemeMode.system,home:const ClientAuthGate());
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
  const pink=Color(0xFFD41483), deepPink=Color(0xFF9F075F), ink=Color(0xFF74324F);
  return Directionality(
   textDirection:TextDirection.rtl,
   child:Scaffold(
    backgroundColor:const Color(0xFFFFD7EA),
    resizeToAvoidBottomInset:true,
    body:LayoutBuilder(builder:(context,constraints){
     final h=constraints.maxHeight;
     final keyboard=MediaQuery.viewInsetsOf(context).bottom>0;
     final compact=h<680||keyboard;
     final imageHeight=math.min(h*(keyboard ? .12 : .38),keyboard ? 105.0 : 300.0);
     final fieldHeight=compact?42.0:49.0;
     final buttonHeight=compact?44.0:51.0;
     InputDecoration decoration(String hint,IconData icon,{Widget? trailing})=>InputDecoration(
      hintText:hint,
      hintStyle:TextStyle(color:ink,fontSize:compact?14:16,fontWeight:FontWeight.w700),
      prefixIcon:Icon(icon,color:pink,size:compact?21:23),
      suffixIcon:trailing,
      filled:true,fillColor:const Color(0xFFFFF9FC),
      isDense:true,contentPadding:EdgeInsets.symmetric(horizontal:14,vertical:compact?7:10),
      enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(24),borderSide:const BorderSide(color:Color(0xFFD65AA5),width:1.5)),
      focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(24),borderSide:const BorderSide(color:pink,width:2)),
     );
     Widget field(TextEditingController c,String hint,IconData icon,{bool secret=false,Widget? trailing,TextInputAction action=TextInputAction.next})=>SizedBox(
      height:fieldHeight,
      child:TextField(
       controller:c,obscureText:secret,autocorrect:false,textAlign:TextAlign.right,
       textInputAction:action,style:TextStyle(color:ink,fontSize:compact?14:16,fontWeight:FontWeight.w700),
       onSubmitted:action==TextInputAction.done?(_){if(!loading)submit();}:null,
       decoration:decoration(hint,icon,trailing:trailing),
      ),
     );
     final content=Column(
      mainAxisAlignment:MainAxisAlignment.spaceEvenly,
      crossAxisAlignment:CrossAxisAlignment.stretch,
      children:[
       Column(mainAxisSize:MainAxisSize.min,children:[
        Text(register?'إنشاء حساب جديد':'الشيخة',textAlign:TextAlign.center,
         style:TextStyle(color:deepPink,fontSize:compact?19:23,fontWeight:FontWeight.w900)),
        if(!register)Padding(padding:const EdgeInsets.only(top:2),child:Text('مرحباً بك في عالم الجمال والتميز',
         textAlign:TextAlign.center,style:TextStyle(color:ink,fontSize:compact?11:13,fontWeight:FontWeight.w700))),
       ]),
       if(register)field(displayName,'الاسم الكامل',Icons.badge_outlined),
       field(username,'اسم المستخدم',Icons.person_outline),
       field(password,'كلمة المرور',Icons.lock_outline,secret:obscure,
        trailing:IconButton(padding:EdgeInsets.zero,constraints:const BoxConstraints(minWidth:42,minHeight:42),
         onPressed:()=>setState(()=>obscure=!obscure),
         icon:Icon(obscure?Icons.visibility_off_outlined:Icons.visibility_outlined,color:pink,size:21)),
        action:register?TextInputAction.next:TextInputAction.done),
       if(register)field(confirmPassword,'تأكيد كلمة المرور',Icons.verified_user_outlined,secret:obscureConfirm,
        trailing:IconButton(padding:EdgeInsets.zero,constraints:const BoxConstraints(minWidth:42,minHeight:42),
         onPressed:()=>setState(()=>obscureConfirm=!obscureConfirm),
         icon:Icon(obscureConfirm?Icons.visibility_off_outlined:Icons.visibility_outlined,color:pink,size:21)),
        action:TextInputAction.done),
       if(error!=null)Padding(padding:const EdgeInsets.symmetric(horizontal:6),child:Text(error!,
        textAlign:TextAlign.center,maxLines:2,overflow:TextOverflow.ellipsis,
        style:const TextStyle(color:Color(0xFFB00020),fontSize:11,fontWeight:FontWeight.w700))),
       SizedBox(height:buttonHeight,child:FilledButton(
        onPressed:loading?null:submit,
        style:FilledButton.styleFrom(backgroundColor:pink,foregroundColor:Colors.white,elevation:3,
         shadowColor:const Color(0x669F075F),
         shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(26),
          side:const BorderSide(color:deepPink,width:1.1))),
        child:loading?const SizedBox(width:19,height:19,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):
         Row(mainAxisAlignment:MainAxisAlignment.center,children:[
          Icon(register?Icons.person_add_alt_1:Icons.login,size:21),const SizedBox(width:9),
          Text(register?'إنشاء الحساب':'تسجيل الدخول',
           style:TextStyle(fontSize:compact?15:17,fontWeight:FontWeight.w900))
         ]),
       )),
       Row(children:[
        const Expanded(child:Divider(indent:18,endIndent:9,color:Color(0xFFD65AA5),thickness:1.2)),
        Text('أو',style:TextStyle(color:deepPink,fontSize:compact?12:14,fontWeight:FontWeight.w900)),
        const Expanded(child:Divider(indent:9,endIndent:18,color:Color(0xFFD65AA5),thickness:1.2)),
       ]),
       SizedBox(height:buttonHeight-2,child:OutlinedButton.icon(
        onPressed:loading?null:()=>setState((){register=!register;error=null;}),
        icon:Icon(register?Icons.arrow_back_rounded:Icons.person_add_alt_1,size:20),
        label:Text(register?'العودة لتسجيل الدخول':'إنشاء حساب جديد',
         style:TextStyle(fontSize:compact?14:16,fontWeight:FontWeight.w900)),
        style:OutlinedButton.styleFrom(foregroundColor:deepPink,backgroundColor:const Color(0xFFFFF0F8),
         side:const BorderSide(color:pink,width:1.6),shape:const StadiumBorder()),
       )),
       if(!register)TextButton(
        onPressed:()=>setState(()=>error='لاستعادة كلمة المرور، تواصلي مع إدارة الشيخة.'),
        style:TextButton.styleFrom(visualDensity:VisualDensity.compact,
         padding:const EdgeInsets.symmetric(horizontal:8,vertical:0),
         minimumSize:Size(0,compact?22:26),tapTargetSize:MaterialTapTargetSize.shrinkWrap),
        child:Text('نسيت كلمة المرور؟',style:TextStyle(color:deepPink,fontSize:compact?12:14,
         fontWeight:FontWeight.w800,decoration:TextDecoration.underline,decorationColor:pink)),
       ),
      ],
     );
     return Column(children:[
      SizedBox(
       height:imageHeight,width:double.infinity,
       child:Stack(fit:StackFit.expand,children:[
        Image.asset('file_00000000df048210b32f5dc7efa7f5ad.png',fit:BoxFit.cover,alignment:Alignment.center,filterQuality:FilterQuality.high,
         errorBuilder:(_,__,___)=>const ColoredBox(color:Color(0xFFF45EAE),child:Center(child:Icon(Icons.image_not_supported_outlined,color:Colors.white70,size:38)))),
        const DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Colors.transparent,Color(0xFFFFD7EA)])))
       ]),
      ),
      Expanded(child:Container(
       width:double.infinity,
       decoration:const BoxDecoration(
        gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,
         colors:[Color(0xFFFFF8FC),Color(0xFFFFD9EC)]),
        borderRadius:BorderRadius.vertical(top:Radius.circular(26)),
        border:Border(top:BorderSide(color:Color(0xFFE99BC8),width:1.5)),
       ),
       padding:EdgeInsets.fromLTRB(compact?17:22,compact?8:12,compact?17:22,compact?5:10),
       child:content,
      )),
     ]);
    }),
   ),
  );
 }

}

class LoginWaveClipper extends CustomClipper<Path>{
 @override Path getClip(Size size){final p=Path()..lineTo(0,size.height-34);p.quadraticBezierTo(size.width*.22,size.height-82,size.width*.48,size.height-40);p.quadraticBezierTo(size.width*.76,size.height+2,size.width,size.height-88);p.lineTo(size.width,0);p.close();return p;}
 @override bool shouldReclip(covariant CustomClipper<Path> oldClipper)=>false;
}

class ClientHome extends StatefulWidget { const ClientHome({super.key}); @override State<ClientHome> createState()=>_ClientHomeState(); }
class _ClientHomeState extends State<ClientHome>{
 int tab=0;bool busy=true;String search='';String get conversationId => FirebaseAuth.instance.currentUser?.uid ?? 'signed-out';
 List<Map<String,dynamic>> members=[],sessions=[],banners=[],bookings=[],favorites=[],messages=[],notifications=[],announcements=[];String? selectedBookingId;StreamSubscription<Map<String,dynamic>>? notificationTapSub;
 final searchCtrl=TextEditingController();final messageCtrl=TextEditingController();final ScrollController clientChatScrollController=ScrollController();Timer? poll;Timer? bannerAuto;final PageController bannerPager=PageController(viewportFraction:.92);int bannerIndex=0;
 @override void initState(){super.initState();notificationTapSub=NotificationService.taps.listen((data)=>handleNotificationTap(data));WidgetsBinding.instance.addPostFrameCallback((_){final initial=NotificationService.takeInitialTap();if(initial!=null)handleNotificationTap(initial);});_trackActivity('app_open');load();poll=Timer.periodic(const Duration(seconds:5),(_)=>load(silent:true));bannerAuto=Timer.periodic(const Duration(seconds:4),(_){if(!mounted||banners.length<2||!bannerPager.hasClients)return;final next=(bannerIndex+1)%banners.length;bannerPager.animateToPage(next,duration:const Duration(milliseconds:550),curve:Curves.easeInOutCubic);});}
 @override void dispose(){poll?.cancel();bannerAuto?.cancel();notificationTapSub?.cancel();bannerPager.dispose();searchCtrl.dispose();messageCtrl.dispose();clientChatScrollController.dispose();super.dispose();}
 void note(String s)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));
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
  showModalBottomSheet(context:context,isScrollControlled:true,backgroundColor:cream,builder:(ctx)=>Directionality(textDirection:TextDirection.rtl,child:SafeArea(child:SizedBox(height:MediaQuery.of(ctx).size.height*.72,child:Column(children:[
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
   if(mounted)setState((){members=r[0];sessions=r[1];banners=r[2].where((b)=>b['active']!=false).take(7).toList();bookings=r[3];favorites=r[4];messages=(r[5].where((m)=>m['conversationId']==conversationId).toList()..sort((a,b)=>'${a['createdAt']??''}'.compareTo('${b['createdAt']??''}')));notifications=r[6].where((n)=>n['target']=='customer'||n['target']=='all').toList()..sort((a,b)=>'${b['createdAt']??''}'.compareTo('${a['createdAt']??''}'));announcements=r[7]..sort((a,b)=>'${b['createdAt']??''}'.compareTo('${a['createdAt']??''}'));});
  }catch(e){if(!silent&&mounted)note('تعذر تحميل البيانات المشتركة: $e');}finally{if(mounted)setState(()=>busy=false);}
 }
 bool isFav(Map<String,dynamic> m)=>favorites.any((f)=>f['memberId']==m['id']);
 Future<void> toggleFav(Map<String,dynamic> m)async{final old=favorites.where((f)=>f['memberId']==m['id']).toList();if(old.isNotEmpty){await SharedStore.delete('favorites',old.first['id']);}else{await SharedStore.save('favorites',{'customerId':FirebaseAuth.instance.currentUser!.uid,'memberId':m['id'],'memberName':m['name']});}_trackActivity('favorite');await load(silent:true);}
 Future<void> book([Map<String,dynamic>? initialMember])async{
  Map<String,dynamic>? selectedMember=initialMember;
  if(selectedMember==null){for(final candidate in members){if(candidate['available']!=false){selectedMember=candidate;break;}}}
  final name=TextEditingController(),phone=TextEditingController(),notes=TextEditingController();
  DateTime? selectedDate; TimeOfDay? selectedTime;
  final result=await showDialog<bool>(context:context,builder:(c)=>StatefulBuilder(builder:(c,ds)=>AlertDialog(
   title:const Text('طلب حجز موعد'),
   content:SizedBox(width:420,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
    DropdownButtonFormField<String>(value:selectedMember?['id']?.toString(),decoration:const InputDecoration(labelText:'اختيار العضو',prefixIcon:Icon(Icons.spa),border:OutlineInputBorder()),items:members.where((member)=>member['available']!=false).map((member)=>DropdownMenuItem<String>(value:member['id'].toString(),child:Text('${member['name']??'عضو'}'))).toList(),onChanged:(v)=>ds(()=>selectedMember=members.firstWhere((member)=>member['id'].toString()==v)),),
    const SizedBox(height:10),
    TextField(controller:name,scrollPadding:const EdgeInsets.only(bottom:180),decoration:const InputDecoration(labelText:'الاسم الكامل',prefixIcon:Icon(Icons.person))),
    TextField(controller:phone,keyboardType:TextInputType.phone,scrollPadding:const EdgeInsets.only(bottom:180),decoration:const InputDecoration(labelText:'رقم الهاتف',prefixIcon:Icon(Icons.phone))),
    const SizedBox(height:12),
    const SizedBox(height:10),
    OutlinedButton.icon(onPressed:()async{final d=await showDatePicker(context:c,initialDate:selectedDate??DateTime.now().add(const Duration(days:1)),firstDate:DateTime.now(),lastDate:DateTime.now().add(const Duration(days:365)));if(d!=null)ds(()=>selectedDate=d);},icon:const Icon(Icons.calendar_month),label:Text(selectedDate==null?'اختيار تاريخ الحجز':'${selectedDate!.year}/${selectedDate!.month}/${selectedDate!.day}')),
    OutlinedButton.icon(onPressed:()async{final t=await showTimePicker(context:c,initialTime:selectedTime??TimeOfDay.now());if(t!=null)ds(()=>selectedTime=t);},icon:const Icon(Icons.schedule),label:Text(selectedTime==null?'اختيار وقت الحجز':selectedTime!.format(c))),
    TextField(controller:notes,maxLines:2,scrollPadding:const EdgeInsets.only(bottom:180),decoration:const InputDecoration(labelText:'ملاحظات إضافية')),
   ]))),
   actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('إرسال الطلب'))],
  )));
  if(result==true){if(name.text.trim().isEmpty||phone.text.trim().isEmpty||selectedMember==null||selectedDate==null||selectedTime==null){note('أكمل الاسم ورقم الهاتف والعضو والتاريخ والوقت');}else{try{final dt=DateTime(selectedDate!.year,selectedDate!.month,selectedDate!.day,selectedTime!.hour,selectedTime!.minute);final bookingId=await SharedStore.save('bookings',{'customerId':FirebaseAuth.instance.currentUser!.uid,'customerName':name.text.trim(),'phone':phone.text.trim(),'memberId':selectedMember!['id'],'memberName':selectedMember!['name'],'date':dt.toIso8601String(),'notes':notes.text.trim(),'status':'قيد المراجعة'});try{await SharedStore.save('notifications',{'target':'admin','createdBy':FirebaseAuth.instance.currentUser!.uid,'customerId':FirebaseAuth.instance.currentUser!.uid,'conversationId':conversationId,'type':'booking','title':'طلب حجز جديد','body':'${name.text.trim()} طلب حجزاً مع ${selectedMember!['name']}','createdAt':DateTime.now().toIso8601String(),'read':false,'bookingId':bookingId});}catch(notificationError){debugPrint('Booking notification failed: $notificationError');}_trackActivity('booking');note('تم إرسال طلب الحجز إلى الإدارة');await load();}catch(e){note('تعذر إرسال طلب الحجز إلى الإدارة: $e');}}}
  name.dispose();phone.dispose();notes.dispose();
 }
 Future<void> sendMessage()async{final value=messageCtrl.text.trim();if(value.isEmpty)return;try{await SharedStore.save('messages',{'conversationId':conversationId,'senderId':FirebaseAuth.instance.currentUser!.uid,'sender':'عميل','type':'text','text':value,'createdAt':DateTime.now().toIso8601String()});try{await SharedStore.save('notifications',{'target':'admin','createdBy':FirebaseAuth.instance.currentUser!.uid,'customerId':FirebaseAuth.instance.currentUser!.uid,'conversationId':conversationId,'type':'message','title':'رسالة جديدة من العميل','body':value,'createdAt':DateTime.now().toIso8601String(),'read':false});}catch(notificationError){debugPrint('Message notification failed: $notificationError');}messageCtrl.clear();_trackActivity('message');await load(silent:true);WidgetsBinding.instance.addPostFrameCallback((_){if(clientChatScrollController.hasClients)clientChatScrollController.jumpTo(0);});}catch(e){note('تعذر إرسال الرسالة: $e');}}
 Future<void> shareMemberProfile()async{
  if(members.isEmpty){note('لا يوجد أعضاء متاحون للمشاركة');return;}
  final chosen=await showModalBottomSheet<Map<String,dynamic>>(context:context,isScrollControlled:true,builder:(ctx)=>Directionality(textDirection:TextDirection.rtl,child:SafeArea(child:ListView(shrinkWrap:true,children:[const Padding(padding:EdgeInsets.all(16),child:Text('اختر ملف العضو لإرساله',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold))),...members.map((m)=>ListTile(leading:photo(m,size:48),title:Text('${m['name']??''}'),subtitle:Text('ملف العضو'),onTap:()=>Navigator.pop(ctx,m)))]))));
  if(chosen==null)return;
  await SharedStore.save('messages',{'conversationId':conversationId,'senderId':FirebaseAuth.instance.currentUser!.uid,'sender':'عميل','type':'memberProfile','memberId':chosen['id'],'memberName':chosen['name'],'text':'ملف العضو: ${chosen['name']}','createdAt':DateTime.now().toIso8601String()});
  await SharedStore.save('notifications',{'target':'admin','createdBy':FirebaseAuth.instance.currentUser!.uid,'type':'message','title':'مشاركة ملف عضو جديدة','body':'شارك العميل ملف العضو ${chosen['name']}','createdAt':DateTime.now().toIso8601String(),'read':false});
  _trackActivity('message');
  await load(silent:true);note('تم إرسال ملف العضو داخل المحادثة');
 }
  Map<String,dynamic>? findMemberById(dynamic id){for(final member in members){if(member['id'].toString()==id?.toString())return member;}return null;}
 Widget chatMessage(Map<String,dynamic> msg){
  final mine=msg['sender']=='عميل';
  final member=msg['type']=='memberProfile'?findMemberById(msg['memberId']):null;
  return Align(alignment:mine?Alignment.centerRight:Alignment.centerLeft,child:Container(constraints:const BoxConstraints(maxWidth:330),margin:const EdgeInsets.symmetric(vertical:6),padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:mine?rose.withOpacity(.13):teal.withOpacity(.12),borderRadius:BorderRadius.circular(18)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
   Text('${msg['sender']??'الإدارة'}',style:const TextStyle(fontSize:12,fontWeight:FontWeight.bold,color:plum)),
   if(member!=null)InkWell(onTap:()=>openMember(member),child:Card(color:Colors.white,child:Padding(padding:const EdgeInsets.all(8),child:Row(children:[photo(member,size:58),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${member['name']??'ملف العضو'}',style:const TextStyle(fontWeight:FontWeight.bold)),const Text('اضغط لفتح الملف الكامل') ])),const Icon(Icons.open_in_new,color:rose)])))),
   if(msg['type']=='bookingCard')bookingMessageCard(msg),
   if(msg['type']!='memberProfile'&&msg['type']!='bookingCard'||member==null&&msg['type']=='memberProfile')Text('${msg['text']??'تعذر العثور على ملف العضو'}'),
   Text('${msg['createdAt']??''}',style:const TextStyle(fontSize:10,color:Colors.grey))
  ])));
 }
 Widget bookingMessageCard(Map<String,dynamic> msg)=>Card(color:Colors.white,child:Padding(padding:const EdgeInsets.all(10),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
  const Row(children:[Icon(Icons.event_available,color:teal),SizedBox(width:7),Text('بطاقة حجز',style:TextStyle(fontWeight:FontWeight.bold,color:plum))]),
  const SizedBox(height:6),
  Text('العميل: ${msg['customerName']??'-'}'),
  Text('عضو الكادر: ${msg['memberName']??'-'}'),
  Text('الموعد: ${msg['date']??'-'}'),
  Text('الحالة: ${msg['status']??'قيد المراجعة'}',style:const TextStyle(fontWeight:FontWeight.bold,color:teal)),
 ])));
 List<String> imageList(Map<String,dynamic> item){final raw=item['images'];if(raw is List)return raw.whereType<String>().where((v)=>v.isNotEmpty).toList();return <String>[];}
 void viewImages(List<String> images,int initial){if(images.isEmpty)return;showDialog(context:context,barrierColor:Colors.black,builder:(ctx)=>Dialog(insetPadding:EdgeInsets.zero,backgroundColor:Colors.black,child:Stack(children:[PageView.builder(controller:PageController(initialPage:initial),itemCount:images.length,itemBuilder:(ctx,i){try{return Center(child:InteractiveViewer(minScale:0.8,maxScale:4,child:appImage(images[i],fit:BoxFit.contain,width:double.infinity,height:double.infinity,errorBuilder:(_,__,___)=>const Icon(Icons.broken_image,color:Colors.white,size:50))));}catch(_){return const Center(child:Icon(Icons.broken_image,color:Colors.white,size:50));}}),Positioned(top:18,right:18,child:IconButton(onPressed:()=>Navigator.pop(ctx),icon:const Icon(Icons.close,color:Colors.white,size:30))),Positioned(bottom:18,left:0,right:0,child:Center(child:Text('اسحب للتنقل بين الصور',style:const TextStyle(color:Colors.white,fontSize:13))))])));}
 Widget imageGallery(Map<String,dynamic> item,{double height=190}){final imgs=imageList(item);if(imgs.isEmpty)return const SizedBox.shrink();return SizedBox(height:height,child:PageView.builder(itemCount:imgs.length,itemBuilder:(ctx,i)=>GestureDetector(onTap:()=>viewImages(imgs,i),child:Stack(fit:StackFit.expand,children:[appImage(imgs[i],fit:BoxFit.cover,errorBuilder:(_,__,___)=>const Center(child:Icon(Icons.broken_image))),if(imgs.length>1)Positioned(top:9,left:9,child:Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:5),decoration:BoxDecoration(color:Colors.black54,borderRadius:BorderRadius.circular(20)),child:Text('${i+1}/${imgs.length}',style:const TextStyle(color:Colors.white))))]))));}
 void openFavorites(){showModalBottomSheet(context:context,isScrollControlled:true,backgroundColor:cream,shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(26))),builder:(ctx)=>Directionality(textDirection:TextDirection.rtl,child:SafeArea(child:SizedBox(height:MediaQuery.of(ctx).size.height*.72,child:Column(children:[Padding(padding:const EdgeInsets.all(16),child:Row(children:[const Icon(Icons.favorite,color:rose),const SizedBox(width:8),const Expanded(child:Text('المفضلة',style:TextStyle(fontSize:21,fontWeight:FontWeight.bold))),IconButton(onPressed:()=>Navigator.pop(ctx),icon:const Icon(Icons.close))])),Expanded(child:members.where(isFav).isEmpty?const Center(child:Text('لم تضف أي عضو إلى المفضلة بعد')):ListView(padding:const EdgeInsets.all(12),children:members.where(isFav).map(memberCard).toList()))])))));}
 Widget photo(Map<String,dynamic> m,{double size=66}){final images=List<String>.from(m['images']??[]);if(images.isEmpty)return CircleAvatar(radius:size/2,child:const Icon(Icons.spa_outlined));try{return ClipRRect(borderRadius:BorderRadius.circular(12),child:appImage(images.first,width:size,height:size,fit:BoxFit.cover));}catch(_){return CircleAvatar(radius:size/2,child:const Icon(Icons.spa));}}
 void openMember(Map<String,dynamic> m){_trackActivity('profile_view');Navigator.push(context,MaterialPageRoute(builder:(_)=>Scaffold(backgroundColor:cream,appBar:AppBar(flexibleSpace:const DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.centerRight,end:Alignment.centerLeft,colors:[Color(0xFFAD1457),Color(0xFFE91E63),Color(0xFFF48FB1)]))),backgroundColor:Colors.transparent,title:Text('${m['name']??'الملف الشخصي'}')),body:Directionality(textDirection:TextDirection.rtl,child:memberProfilePage(m)))));}
 void previewMember(Map<String,dynamic> m){showModalBottomSheet(context:context,isScrollControlled:true,backgroundColor:cream,shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(26))),builder:(c)=>Directionality(textDirection:TextDirection.rtl,child:SafeArea(child:Padding(padding:const EdgeInsets.fromLTRB(18,12,18,22),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
  Center(child:Container(width:42,height:4,decoration:BoxDecoration(color:Colors.grey.shade400,borderRadius:BorderRadius.circular(4)))),
  const SizedBox(height:12),
  imageGallery(m,height:220),
  const SizedBox(height:12),Text('${m['name']??''}',style:const TextStyle(fontSize:21,fontWeight:FontWeight.bold)),
  Text('العمر: ${m['age']??'-'}  •  الساعة: ${m['hourlyPrice']??0} د.ع'),
  if((m['description']??'').toString().isNotEmpty)Padding(padding:const EdgeInsets.only(top:8),child:Text('${m['description']}')),
  const SizedBox(height:14),Row(children:[Expanded(child:OutlinedButton.icon(onPressed:(){Navigator.pop(c);openMember(m);},icon:const Icon(Icons.person),label:const Text('الملف الكامل'))),const SizedBox(width:8),Expanded(child:FilledButton.icon(onPressed:(){Navigator.pop(c);book(m);},icon:const Icon(Icons.calendar_month),label:const Text('احجز الآن')))])
 ])))));}
 Widget memberProfilePage(Map<String,dynamic> m)=>ListView(padding:const EdgeInsets.all(16),children:[
  imageGallery(m,height:290),
  const SizedBox(height:14),Text('${m['name']??''}',textAlign:TextAlign.center,style:const TextStyle(fontSize:24,fontWeight:FontWeight.bold)),
  const SizedBox(height:14),
  Card(child:Column(children:[ListTile(leading:const Icon(Icons.cake_outlined),title:const Text('العمر'),subtitle:Text('${m['age']??'-'}')),ListTile(leading:const Icon(Icons.payments_outlined),title:const Text('سعر الساعة'),subtitle:Text('${m['hourlyPrice']??0} د.ع')),ListTile(leading:const Icon(Icons.nights_stay_outlined),title:const Text('سعر الليلة'),subtitle:Text('${m['nightlyPrice']??0} د.ع')),ListTile(leading:const Icon(Icons.place_outlined),title:const Text('المكان'),subtitle:Text(m['hasPlace']==true?'يوجد مكان':'لا يوجد مكان')),if((m['address']??'').toString().isNotEmpty)ListTile(leading:const Icon(Icons.location_on_outlined),title:const Text('العنوان'),subtitle:Text('${m['address']}'))])),
  if((m['description']??'').toString().isNotEmpty)Card(child:Padding(padding:const EdgeInsets.all(16),child:Text('${m['description']}'))),
  FilledButton.icon(onPressed:()=>book(m),icon:const Icon(Icons.calendar_month),label:const Text('احجز موعداً')),
 ]);
 Widget memberCard(Map<String,dynamic> m)=>Card(clipBehavior:Clip.antiAlias,child:InkWell(onTap:()=>openMember(m),onLongPress:()=>previewMember(m),child:Padding(padding:const EdgeInsets.all(8),child:Row(children:[
  photo(m,size:76),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${m['name']??''}',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:16)),Text('العمر: ${m['age']??'-'} • ${m['hourlyPrice']??0} د.ع/ساعة',maxLines:1,overflow:TextOverflow.ellipsis),Text(m['hasPlace']==true?'يوجد مكان':'لا يوجد مكان',style:const TextStyle(color:plum))])),
  IconButton(onPressed:()=>toggleFav(m),style:IconButton.styleFrom(backgroundColor:rose.withOpacity(.10)),icon:Icon(isFav(m)?Icons.favorite:Icons.favorite_border,color:isFav(m)?rose:plum)),
  const Icon(Icons.chevron_left)
  ]))));
 Widget memberGridCard(Map<String,dynamic> m)=>Card(clipBehavior:Clip.antiAlias,child:InkWell(onTap:()=>openMember(m),onLongPress:()=>previewMember(m),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
  Expanded(child:Stack(fit:StackFit.expand,children:[photo(m,size:180),Positioned(left:5,top:5,child:IconButton(onPressed:()=>toggleFav(m),style:IconButton.styleFrom(backgroundColor:Colors.white.withOpacity(.92),minimumSize:const Size(34,34),padding:EdgeInsets.zero),icon:Icon(isFav(m)?Icons.favorite:Icons.favorite_border,color:rose,size:19)))])),
  Padding(padding:const EdgeInsets.fromLTRB(8,6,8,8),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
   Text('${m['name']??''}',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:15)),
   Text('${m['hourlyPrice']??0} د.ع/ساعة',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:12,color:plum)),
   Text(m['hasPlace']==true?'يوجد مكان':'لا يوجد مكان',maxLines:1,style:const TextStyle(fontSize:11,color:Colors.black54))
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
 Widget bannerCard(Map<String,dynamic> b)=>Card(clipBehavior:Clip.antiAlias,margin:const EdgeInsets.symmetric(horizontal:3,vertical:2),child:InkWell(onTap:()=>openBanner(b),child:Stack(fit:StackFit.expand,children:[
 if(imageList(b).isNotEmpty)appImage(imageList(b).first,fit:BoxFit.cover,errorBuilder:(_,__,___)=>Container(color:plum,child:const Icon(Icons.broken_image,color:Colors.white,size:40))) else Container(color:plum,child:const Icon(Icons.image_outlined,color:Colors.white,size:42)),
 const DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Colors.transparent,Color(0xCC180A25)],stops:[.28,1]))),
 Positioned(right:18,left:18,bottom:15,child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[
  if('${b['title']??''}'.toString().trim().isNotEmpty)Text('${b['title']}',maxLines:2,overflow:TextOverflow.ellipsis,style:GoogleFonts.cairo(color:Colors.white,fontSize:21,fontWeight:FontWeight.w800,shadows:[const Shadow(color:Colors.black54,blurRadius:8,offset:Offset(0,2))])),
  if('${b['description']??''}'.toString().trim().isNotEmpty)Padding(padding:const EdgeInsets.only(top:3),child:Text('${b['description']}',maxLines:2,overflow:TextOverflow.ellipsis,style:GoogleFonts.cairo(color:Colors.white,fontSize:13,fontWeight:FontWeight.w600,shadows:[const Shadow(color:Colors.black54,blurRadius:6)])))
 ]))
])));
Widget homePage()=>ListView(padding:const EdgeInsets.all(14),children:[
  if(banners.isNotEmpty)...[SizedBox(height:190,child:PageView.builder(controller:bannerPager,itemCount:banners.length,onPageChanged:(i)=>setState(()=>bannerIndex=i),itemBuilder:(ctx,i)=>bannerCard(banners[i]))),if(banners.length>1)Padding(padding:const EdgeInsets.only(top:8,bottom:2),child:Row(mainAxisAlignment:MainAxisAlignment.center,children:List.generate(banners.length,(i)=>AnimatedContainer(duration:const Duration(milliseconds:250),margin:const EdgeInsets.symmetric(horizontal:3),width:bannerIndex==i?18:6,height:6,decoration:BoxDecoration(color:bannerIndex==i?rose:plum.withOpacity(.25),borderRadius:BorderRadius.circular(8))))))],
  if(banners.isEmpty)const SizedBox.shrink(),
  if(announcements.isNotEmpty)const Padding(padding:EdgeInsets.only(top:12,bottom:6),child:Text('الإعلانات والتنبيهات',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold))),
  ...announcements.map((a)=>Card(clipBehavior:Clip.antiAlias,child:Column(children:[if(imageList(a).isNotEmpty)imageGallery(a,height:150),ListTile(leading:const Icon(Icons.campaign,color:rose),title:Text('${a['title']??'إعلان'}'),subtitle:Text('${a['body']??''}'))]))),
  const SizedBox(height:12),const Text('الكادر المتوفر',style:TextStyle(fontSize:21,fontWeight:FontWeight.bold)),
  GridView.builder(
    shrinkWrap:true,
    physics:const NeverScrollableScrollPhysics(),
    itemCount:members.where((m)=>m['available']!=false&&'${m['name']} ${m['description']}'.toLowerCase().contains(search.toLowerCase())).length,
    gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:2,crossAxisSpacing:9,mainAxisSpacing:9,childAspectRatio:.72),
    itemBuilder:(context,index){
      final visible=members.where((m)=>m['available']!=false&&'${m['name']} ${m['description']}'.toLowerCase().contains(search.toLowerCase())).toList();
      return memberGridCard(visible[index]);
    },
  ),
 ]);
 Widget sessionsPage()=>ListView(padding:const EdgeInsets.all(14),children:[
  const Text('الجلسات',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold)),
  const SizedBox(height:10),
  if(sessions.isEmpty)const Center(child:Padding(padding:EdgeInsets.all(30),child:Text('لا توجد جلسات في الأرشيف حالياً'))),
  ...sessions.map((session)=>Card(clipBehavior:Clip.antiAlias,child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
   imageGallery(session,height:190),
   ListTile(title:Text('${session['title']??'جلسة'}'),subtitle:Text('${session['date']??''} • ${session['description']??''}')),
  ]))),
 ]);

 Widget bookingsPage()=>ListView(padding:const EdgeInsets.all(12),children:[const Text('طلباتي وحجوزاتي',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold)),FilledButton.icon(onPressed:()=>book(),icon:const Icon(Icons.add_circle_outline),label:const Text('حجز موعد جديد')),const SizedBox(height:10),...bookings.map((b)=>Card(color:b['id']?.toString()==selectedBookingId?const Color(0xFFFFE4EF):Colors.white,child:ListTile(onTap:()=>showClientBooking(b),leading:const Icon(Icons.event_available),title:Text('${b['memberName']??'حجز'}'),subtitle:Text('${b['date']??''} • ${b['status']??'قيد المراجعة'}')))),if(bookings.isEmpty)const Text('لا توجد حجوزات حتى الآن.')]);
 Widget chatPage()=>Column(children:[
  Expanded(child:messages.isEmpty?const Center(child:Text('ابدأ المحادثة بإرسال رسالتك الأولى')):ListView.builder(controller:clientChatScrollController,reverse:true,padding:const EdgeInsets.all(12),itemCount:messages.length,itemBuilder:(context,index)=>chatMessage(messages[messages.length-1-index]))),
  SafeArea(child:Padding(padding:const EdgeInsets.all(8),child:Row(children:[IconButton(tooltip:'إرسال ملف عضو',onPressed:shareMemberProfile,icon:const Icon(Icons.person_add_alt_1,color:rose)),Expanded(child:TextField(controller:messageCtrl,minLines:1,maxLines:4,scrollPadding:const EdgeInsets.only(bottom:180),decoration:const InputDecoration(hintText:'اكتب رسالتك...',border:OutlineInputBorder()),onTap:(){WidgetsBinding.instance.addPostFrameCallback((_){if(clientChatScrollController.hasClients)clientChatScrollController.jumpTo(0);});},onSubmitted:(_)=>sendMessage())),IconButton(onPressed:sendMessage,icon:const Icon(Icons.send,color:plum))]))),
 ]);
 Widget accountPage()=>const AccountPage();
 Widget currentPage()=>switch(tab){1=>chatPage(),2=>bookingsPage(),3=>sessionsPage(),4=>accountPage(),_=>homePage()};
 @override Widget build(BuildContext context)=>Directionality(textDirection:TextDirection.rtl,child:Scaffold(
  appBar:AppBar(toolbarHeight:64,backgroundColor:cream,surfaceTintColor:Colors.transparent,foregroundColor:Colors.black,iconTheme:const IconThemeData(color:Colors.black),actionsIconTheme:const IconThemeData(color:Colors.black),backgroundColor:cream,flexibleSpace:const DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Color(0xFFFF91B8),Color(0xFFFFC7DB),Color(0xFFFFF7FB)]))),title:const Row(mainAxisSize:MainAxisSize.min,children:[Icon(Icons.auto_awesome_rounded,color:Colors.black,size:19),SizedBox(width:6),Text('الشيخة',style:TextStyle(color:Colors.black,fontWeight:FontWeight.w900,fontSize:23,letterSpacing:.3))]),actions:[if(tab==0)IconButton(tooltip:'المفضلة',onPressed:openFavorites,style:IconButton.styleFrom(backgroundColor:Colors.black.withOpacity(.06)),icon:const Icon(Icons.favorite,color:Colors.black)),if(tab==0)IconButton(tooltip:'البحث',onPressed:()=>showSearch(context:context,delegate:MemberSearch(members,onPick:(v){setState(()=>search=v);})),icon:const Icon(Icons.search,color:Colors.black)),Badge(isLabelVisible:notifications.any((n)=>n['read']!=true),label:Text('${notifications.where((n)=>n['read']!=true).length}'),child:IconButton(tooltip:'الإشعارات',onPressed:openNotifications,icon:const Icon(Icons.notifications_active,color:Colors.black)))]),
  resizeToAvoidBottomInset:true,
  body:busy?const Center(child:CircularProgressIndicator()):RefreshIndicator(onRefresh:load,child:currentPage()),
  bottomNavigationBar:MediaQuery.of(context).viewInsets.bottom>0?null:NavigationBar(height:72,backgroundColor:Colors.white,indicatorColor:gold.withOpacity(.25),selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),destinations:const[NavigationDestination(icon:Icon(Icons.home_outlined,color:teal),selectedIcon:Icon(Icons.home_rounded,color:teal),label:'الرئيسية'),NavigationDestination(icon:Icon(Icons.forum_outlined,color:plum),selectedIcon:Icon(Icons.forum,color:plum),label:'الدردشة'),NavigationDestination(icon:Icon(Icons.event_note_outlined,color:rose),selectedIcon:Icon(Icons.event_available,color:rose),label:'حجوزاتي'),NavigationDestination(icon:Icon(Icons.photo_library_outlined,color:gold),selectedIcon:Icon(Icons.photo_library,color:gold),label:'الجلسات'),NavigationDestination(icon:Icon(Icons.account_circle_outlined,color:plum),selectedIcon:Icon(Icons.account_circle,color:plum),label:'حسابي')])
 ));
}
class MemberSearch extends SearchDelegate<String>{
 final List<Map<String,dynamic>> members;final ValueChanged<String> onPick;
 MemberSearch(this.members,{required this.onPick});
 @override List<Widget>? buildActions(BuildContext context)=>[IconButton(onPressed:()=>query='',icon:const Icon(Icons.clear))];
 @override Widget? buildLeading(BuildContext context)=>IconButton(onPressed:()=>close(context,''),icon:const Icon(Icons.arrow_back));
 @override Widget buildResults(BuildContext context)=>buildSuggestions(context);
 @override Widget buildSuggestions(BuildContext context)=>ListView(children:members.where((m)=>'${m['name']} ${m['description']}'.toLowerCase().contains(query.toLowerCase())).map((m)=>ListTile(title:Text('${m['name']}'),subtitle:Text('${m['address']??''}'),onTap:(){onPick(query);close(context,query);})).toList());
}
