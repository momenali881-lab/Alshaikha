import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:google_fonts/google_fonts.dart';
import 'shared_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.android);
  runApp(const SheikhaClientApp());
}
const rose=Color(0xFFE91E63), plum=Color(0xFF6A1B9A), cream=Color(0xFFFFF7FB), teal=Color(0xFF00A6A6), gold=Color(0xFFFFB300);
class SheikhaClientApp extends StatelessWidget{
 const SheikhaClientApp({super.key});
 @override Widget build(BuildContext context)=>MaterialApp(debugShowCheckedModeBanner:false,title:'الشيخة',theme:ThemeData(useMaterial3:true,colorScheme:ColorScheme.fromSeed(seedColor:plum,brightness:Brightness.light),scaffoldBackgroundColor:cream,textTheme:GoogleFonts.arefRuqaaTextTheme(),iconTheme:const IconThemeData(color:plum),inputDecorationTheme:InputDecorationTheme(filled:true,fillColor:Colors.white,border:OutlineInputBorder(borderRadius:BorderRadius.all(Radius.circular(14)))),appBarTheme:const AppBarTheme(backgroundColor:plum,foregroundColor:Colors.white,elevation:0),cardTheme:CardThemeData(color:Colors.white,elevation:2,shape:RoundedRectangleBorder(borderRadius:BorderRadius.all(Radius.circular(18)))),filledButtonTheme:FilledButtonThemeData(style:FilledButton.styleFrom(backgroundColor:rose,foregroundColor:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14)))),floatingActionButtonTheme:const FloatingActionButtonThemeData(backgroundColor:teal,foregroundColor:Colors.white)),darkTheme:ThemeData(useMaterial3:true,brightness:Brightness.dark,colorScheme:ColorScheme.fromSeed(seedColor:rose,brightness:Brightness.dark),textTheme:GoogleFonts.arefRuqaaTextTheme(ThemeData.dark().textTheme)),themeMode:ThemeMode.system,home:const ClientHome());
}
class ClientHome extends StatefulWidget{const ClientHome({super.key});@override State<ClientHome> createState()=>_ClientHomeState();}
class _ClientHomeState extends State<ClientHome>{
 int tab=0;bool busy=true;String search='';String conversationId='customer-main';
 List<Map<String,dynamic>> members=[],sessions=[],banners=[],bookings=[],favorites=[],messages=[],notifications=[],announcements=[];
 final searchCtrl=TextEditingController();final messageCtrl=TextEditingController();Timer? poll;Timer? bannerAuto;final PageController bannerPager=PageController(viewportFraction:.92);int bannerIndex=0;
 @override void initState(){super.initState();load();poll=Timer.periodic(const Duration(seconds:5),(_)=>load(silent:true));bannerAuto=Timer.periodic(const Duration(seconds:4),(_){if(!mounted||banners.length<2||!bannerPager.hasClients)return;final next=(bannerIndex+1)%banners.length;bannerPager.animateToPage(next,duration:const Duration(milliseconds:550),curve:Curves.easeInOutCubic);});}
 @override void dispose(){poll?.cancel();bannerAuto?.cancel();bannerPager.dispose();searchCtrl.dispose();messageCtrl.dispose();super.dispose();}
 void note(String s)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));
 Future<void> openNotifications()async{await load(silent:true);if(!mounted)return;showModalBottomSheet(context:context,isScrollControlled:true,backgroundColor:cream,builder:(ctx)=>Directionality(textDirection:TextDirection.rtl,child:SafeArea(child:SizedBox(height:MediaQuery.of(ctx).size.height*.72,child:Column(children:[const Padding(padding:EdgeInsets.all(16),child:Text('الإشعارات',style:TextStyle(fontSize:21,fontWeight:FontWeight.bold))),Expanded(child:notifications.isEmpty?const Center(child:Text('لا توجد إشعارات حالياً')):ListView(children:notifications.map((n)=>ListTile(leading:Icon(n['type']=='booking'?Icons.event_available:n['type']=='message'?Icons.forum:Icons.campaign,color:rose),title:Text('${n['title']??'إشعار'}'),subtitle:Text('${n['body']??''}'),trailing:n['read']==true?const Icon(Icons.done,color:teal):const Icon(Icons.circle,color:rose,size:10),onTap:()async{await SharedStore.save('notifications',{...n,'read':true});await load(silent:true);})).toList()))])))));}
 Future<void> load({bool silent=false})async{
  if(!silent&&mounted)setState(()=>busy=true);
  try{final r=await Future.wait([SharedStore.list('members'),SharedStore.list('sessions'),SharedStore.list('banners'),SharedStore.list('bookings'),SharedStore.list('favorites'),SharedStore.list('messages'),SharedStore.list('notifications'),SharedStore.list('announcements')]);
   if(mounted)setState((){members=r[0];sessions=r[1];banners=r[2].where((b)=>b['active']!=false).take(7).toList();bookings=r[3];favorites=r[4];messages=(r[5].where((m)=>m['conversationId']==conversationId).toList()..sort((a,b)=>'${a['createdAt']??''}'.compareTo('${b['createdAt']??''}')));notifications=r[6].where((n)=>n['target']=='customer'||n['target']=='all').toList()..sort((a,b)=>'${b['createdAt']??''}'.compareTo('${a['createdAt']??''}'));announcements=r[7]..sort((a,b)=>'${b['createdAt']??''}'.compareTo('${a['createdAt']??''}'));});
  }catch(e){if(!silent&&mounted)note('تعذر تحميل البيانات المشتركة: $e');}finally{if(mounted)setState(()=>busy=false);}
 }
 bool isFav(Map<String,dynamic> m)=>favorites.any((f)=>f['memberId']==m['id']);
 Future<void> toggleFav(Map<String,dynamic> m)async{final old=favorites.where((f)=>f['memberId']==m['id']).toList();if(old.isNotEmpty){await SharedStore.delete('favorites',old.first['id']);}else{await SharedStore.save('favorites',{'memberId':m['id'],'memberName':m['name']});}await load(silent:true);}
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
  if(result==true){if(name.text.trim().isEmpty||phone.text.trim().isEmpty||selectedMember==null||selectedDate==null||selectedTime==null){note('أكمل الاسم ورقم الهاتف والعضو والتاريخ والوقت');}else{final dt=DateTime(selectedDate!.year,selectedDate!.month,selectedDate!.day,selectedTime!.hour,selectedTime!.minute);final bookingId=await SharedStore.save('bookings',{'customerName':name.text.trim(),'phone':phone.text.trim(),'memberId':selectedMember!['id'],'memberName':selectedMember!['name'],'date':dt.toIso8601String(),'notes':notes.text.trim(),'status':'قيد المراجعة'});await SharedStore.save('notifications',{'target':'admin','type':'booking','title':'طلب حجز جديد','body':'${name.text.trim()} طلب حجزاً مع ${selectedMember!['name']}','createdAt':DateTime.now().toIso8601String(),'read':false,'bookingId':bookingId});note('تم إرسال طلب الحجز');await load();}}
  name.dispose();phone.dispose();notes.dispose();
 }
 Future<void> sendMessage()async{final value=messageCtrl.text.trim();if(value.isEmpty)return;try{await SharedStore.save('messages',{'conversationId':conversationId,'sender':'عميل','type':'text','text':value,'createdAt':DateTime.now().toIso8601String()});await SharedStore.save('notifications',{'target':'admin','type':'message','title':'رسالة جديدة من العميل','body':value,'createdAt':DateTime.now().toIso8601String(),'read':false});messageCtrl.clear();await load(silent:true);}catch(e){note('تعذر إرسال الرسالة: $e');}}
 Future<void> shareMemberProfile()async{
  if(members.isEmpty){note('لا يوجد أعضاء متاحون للمشاركة');return;}
  final chosen=await showModalBottomSheet<Map<String,dynamic>>(context:context,isScrollControlled:true,builder:(ctx)=>Directionality(textDirection:TextDirection.rtl,child:SafeArea(child:ListView(shrinkWrap:true,children:[const Padding(padding:EdgeInsets.all(16),child:Text('اختر ملف العضو لإرساله',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold))),...members.map((m)=>ListTile(leading:photo(m,size:48),title:Text('${m['name']??''}'),subtitle:Text('ملف العضو'),onTap:()=>Navigator.pop(ctx,m)))]))));
  if(chosen==null)return;
  await SharedStore.save('messages',{'conversationId':conversationId,'sender':'عميل','type':'memberProfile','memberId':chosen['id'],'memberName':chosen['name'],'text':'ملف العضو: ${chosen['name']}','createdAt':DateTime.now().toIso8601String()});
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
 void viewImages(List<String> images,int initial){if(images.isEmpty)return;showDialog(context:context,barrierColor:Colors.black,builder:(ctx)=>Dialog(insetPadding:EdgeInsets.zero,backgroundColor:Colors.black,child:Stack(children:[PageView.builder(controller:PageController(initialPage:initial),itemCount:images.length,itemBuilder:(ctx,i){try{return Center(child:InteractiveViewer(minScale:0.8,maxScale:4,child:Image.memory(base64Decode(images[i]),fit:BoxFit.contain,width:double.infinity,height:double.infinity,errorBuilder:(_,__,___)=>const Icon(Icons.broken_image,color:Colors.white,size:50))));}catch(_){return const Center(child:Icon(Icons.broken_image,color:Colors.white,size:50));}}),Positioned(top:18,right:18,child:IconButton(onPressed:()=>Navigator.pop(ctx),icon:const Icon(Icons.close,color:Colors.white,size:30))),Positioned(bottom:18,left:0,right:0,child:Center(child:Text('اسحب للتنقل بين الصور',style:const TextStyle(color:Colors.white,fontSize:13))))])));}
 Widget imageGallery(Map<String,dynamic> item,{double height=190}){final imgs=imageList(item);if(imgs.isEmpty)return const SizedBox.shrink();return SizedBox(height:height,child:PageView.builder(itemCount:imgs.length,itemBuilder:(ctx,i)=>GestureDetector(onTap:()=>viewImages(imgs,i),child:Stack(fit:StackFit.expand,children:[Image.memory(base64Decode(imgs[i]),fit:BoxFit.cover,errorBuilder:(_,__,___)=>const Center(child:Icon(Icons.broken_image))),if(imgs.length>1)Positioned(top:9,left:9,child:Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:5),decoration:BoxDecoration(color:Colors.black54,borderRadius:BorderRadius.circular(20)),child:Text('${i+1}/${imgs.length}',style:const TextStyle(color:Colors.white))))]))));}
 void openFavorites(){showModalBottomSheet(context:context,isScrollControlled:true,backgroundColor:cream,shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(26))),builder:(ctx)=>Directionality(textDirection:TextDirection.rtl,child:SafeArea(child:SizedBox(height:MediaQuery.of(ctx).size.height*.72,child:Column(children:[Padding(padding:const EdgeInsets.all(16),child:Row(children:[const Icon(Icons.favorite,color:rose),const SizedBox(width:8),const Expanded(child:Text('المفضلة',style:TextStyle(fontSize:21,fontWeight:FontWeight.bold))),IconButton(onPressed:()=>Navigator.pop(ctx),icon:const Icon(Icons.close))])),Expanded(child:members.where(isFav).isEmpty?const Center(child:Text('لم تضف أي عضو إلى المفضلة بعد')):ListView(padding:const EdgeInsets.all(12),children:members.where(isFav).map(memberCard).toList()))])))));}
 Widget photo(Map<String,dynamic> m,{double size=66}){final images=List<String>.from(m['images']??[]);if(images.isEmpty)return CircleAvatar(radius:size/2,child:const Icon(Icons.spa_outlined));try{return ClipRRect(borderRadius:BorderRadius.circular(12),child:Image.memory(base64Decode(images.first),width:size,height:size,fit:BoxFit.cover));}catch(_){return CircleAvatar(radius:size/2,child:const Icon(Icons.spa));}}
 void openMember(Map<String,dynamic> m){Navigator.push(context,MaterialPageRoute(builder:(_)=>Scaffold(backgroundColor:cream,appBar:AppBar(title:Text('${m['name']??'الملف الشخصي'}')),body:Directionality(textDirection:TextDirection.rtl,child:memberProfilePage(m)))));}
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
 void openBanner(Map<String,dynamic> b){final member=findMemberById(b['linkedMemberId']??b['targetId']);if(member!=null){openMember(member);return;}final imgs=imageList(b);if(imgs.isNotEmpty){viewImages(imgs,0);return;}showDialog(context:context,builder:(ctx)=>AlertDialog(title:Text('${b['title']??'إعلان'}'),content:Text('${b['description']??''}'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إغلاق'))]));}
 Widget bannerCard(Map<String,dynamic> b)=>Card(clipBehavior:Clip.antiAlias,margin:const EdgeInsets.symmetric(horizontal:3,vertical:2),child:InkWell(onTap:()=>openBanner(b),child:Stack(fit:StackFit.expand,children:[
 if(imageList(b).isNotEmpty)Image.memory(base64Decode(imageList(b).first),fit:BoxFit.cover,errorBuilder:(_,__,___)=>Container(color:plum,child:const Icon(Icons.broken_image,color:Colors.white,size:40))) else Container(color:plum,child:const Icon(Icons.image_outlined,color:Colors.white,size:42)),
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
  ...announcements.map((a)=>Card(child:ListTile(leading:const Icon(Icons.campaign,color:rose),title:Text('${a['title']??'إعلان'}'),subtitle:Text('${a['body']??''}')))),
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

 Widget bookingsPage()=>ListView(padding:const EdgeInsets.all(12),children:[const Text('طلباتي وحجوزاتي',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold)),FilledButton.icon(onPressed:()=>book(),icon:const Icon(Icons.add_circle_outline),label:const Text('حجز موعد جديد')),const SizedBox(height:10),...bookings.map((b)=>Card(child:ListTile(leading:const Icon(Icons.event_available),title:Text('${b['memberName']??'حجز'}'),subtitle:Text('${b['date']??''} • ${b['status']??'قيد المراجعة'}')))),if(bookings.isEmpty)const Text('لا توجد حجوزات حتى الآن.')]);
 Widget chatPage()=>Column(children:[
  const ListTile(leading:CircleAvatar(child:Icon(Icons.support_agent)),title:Text('التواصل مع الإدارة'),subtitle:Text('يمكنك إرسال الرسائل واستقبال رد الإدارة هنا')),
  Expanded(child:messages.isEmpty?const Center(child:Text('ابدأ المحادثة بإرسال رسالتك الأولى')):ListView(padding:const EdgeInsets.all(12),children:messages.map(chatMessage).toList())),
  SafeArea(child:Padding(padding:const EdgeInsets.all(8),child:Row(children:[IconButton(tooltip:'إرسال ملف عضو',onPressed:shareMemberProfile,icon:const Icon(Icons.person_add_alt_1,color:rose)),Expanded(child:TextField(controller:messageCtrl,minLines:1,maxLines:4,scrollPadding:const EdgeInsets.only(bottom:180),decoration:const InputDecoration(hintText:'اكتب رسالتك...',border:OutlineInputBorder()),onSubmitted:(_)=>sendMessage())),IconButton(onPressed:sendMessage,icon:const Icon(Icons.send,color:plum))]))),
 ]);
 Widget morePage()=>ListView(padding:const EdgeInsets.all(18),children:[const ListTile(leading:Icon(Icons.spa),title:Text('مركز الشيخة'),subtitle:Text('نرحب بكم دائماً')),const ListTile(leading:Icon(Icons.currency_exchange),title:Text('العملة'),subtitle:Text('الدينار العراقي (د.ع)')),ListTile(leading:const Icon(Icons.refresh),title:const Text('تحديث البيانات'),onTap:load)]);
 Widget currentPage()=>switch(tab){1=>chatPage(),2=>bookingsPage(),3=>sessionsPage(),4=>morePage(),_=>homePage()};
 @override Widget build(BuildContext context)=>Directionality(textDirection:TextDirection.rtl,child:Scaffold(
  appBar:AppBar(title:const Text('الشيخة',style:TextStyle(fontWeight:FontWeight.bold)),actions:[if(tab==0)IconButton(tooltip:'المفضلة',onPressed:openFavorites,style:IconButton.styleFrom(backgroundColor:rose.withOpacity(.14)),icon:const Icon(Icons.favorite,color:rose)),if(tab==0)IconButton(tooltip:'البحث',onPressed:()=>showSearch(context:context,delegate:MemberSearch(members,onPick:(v){setState(()=>search=v);})),icon:const Icon(Icons.search)),Badge(isLabelVisible:notifications.any((n)=>n['read']!=true),label:Text('${notifications.where((n)=>n['read']!=true).length}'),child:IconButton(tooltip:'الإشعارات',onPressed:openNotifications,icon:const Icon(Icons.notifications_active)))]),
  resizeToAvoidBottomInset:true,
  body:busy?const Center(child:CircularProgressIndicator()):RefreshIndicator(onRefresh:load,child:currentPage()),
  bottomNavigationBar:MediaQuery.of(context).viewInsets.bottom>0?null:NavigationBar(height:72,backgroundColor:Colors.white,indicatorColor:gold.withOpacity(.25),selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),destinations:const[NavigationDestination(icon:Icon(Icons.home_outlined,color:teal),selectedIcon:Icon(Icons.home_rounded,color:teal),label:'الرئيسية'),NavigationDestination(icon:Icon(Icons.forum_outlined,color:plum),selectedIcon:Icon(Icons.forum,color:plum),label:'الدردشة'),NavigationDestination(icon:Icon(Icons.event_note_outlined,color:rose),selectedIcon:Icon(Icons.event_available,color:rose),label:'حجوزاتي'),NavigationDestination(icon:Icon(Icons.photo_library_outlined,color:gold),selectedIcon:Icon(Icons.photo_library,color:gold),label:'الجلسات'),NavigationDestination(icon:Icon(Icons.more_horiz,color:plum),selectedIcon:Icon(Icons.more,color:plum),label:'المزيد')])
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
