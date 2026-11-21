import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'shared_store.dart';

void main()=>runApp(const SheikhaClientApp());
const rose=Color(0xFFB77D91), plum=Color(0xFF80647F), cream=Color(0xFFFFF9F6);
class SheikhaClientApp extends StatelessWidget{
 const SheikhaClientApp({super.key});
 @override Widget build(BuildContext context)=>MaterialApp(debugShowCheckedModeBanner:false,title:'الشيخة',theme:ThemeData(useMaterial3:true,colorScheme:ColorScheme.fromSeed(seedColor:rose),scaffoldBackgroundColor:cream),darkTheme:ThemeData(useMaterial3:true,brightness:Brightness.dark,colorScheme:ColorScheme.fromSeed(seedColor:rose,brightness:Brightness.dark)),themeMode:ThemeMode.system,home:const ClientHome());
}
class ClientHome extends StatefulWidget{const ClientHome({super.key});@override State<ClientHome> createState()=>_ClientHomeState();}
class _ClientHomeState extends State<ClientHome>{
 int tab=0;bool busy=true;String search='';String conversationId='customer-main';
 List<Map<String,dynamic>> members=[],sessions=[],banners=[],bookings=[],favorites=[],messages=[];
 final searchCtrl=TextEditingController();final messageCtrl=TextEditingController();Timer? poll;
 @override void initState(){super.initState();load();poll=Timer.periodic(const Duration(seconds:5),(_)=>load(silent:true));}
 @override void dispose(){poll?.cancel();searchCtrl.dispose();messageCtrl.dispose();super.dispose();}
 void note(String s)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));
 Future<void> load({bool silent=false})async{
  if(!silent&&mounted)setState(()=>busy=true);
  try{final r=await Future.wait([SharedStore.list('members'),SharedStore.list('sessions'),SharedStore.list('banners'),SharedStore.list('bookings'),SharedStore.list('favorites'),SharedStore.list('messages')]);
   if(mounted)setState((){members=r[0].where((m)=>m['available']!=false).toList();sessions=r[1];banners=r[2].where((b)=>b['active']!=false).take(7).toList();bookings=r[3];favorites=r[4];messages=(r[5].where((m)=>m['conversationId']==conversationId).toList()..sort((a,b)=>'${a['createdAt']??''}'.compareTo('${b['createdAt']??''}')));});
  }catch(e){if(!silent&&mounted)note('تعذر تحميل البيانات المشتركة: $e');}finally{if(mounted)setState(()=>busy=false);}
 }
 bool isFav(Map<String,dynamic> m)=>favorites.any((f)=>f['memberId']==m['id']);
 Future<void> toggleFav(Map<String,dynamic> m)async{final old=favorites.where((f)=>f['memberId']==m['id']).toList();if(old.isNotEmpty){await SharedStore.delete('favorites',old.first['id']);}else{await SharedStore.save('favorites',{'memberId':m['id'],'memberName':m['name']});}await load(silent:true);}
 Future<void> book(Map<String,dynamic> m)async{
  final name=TextEditingController(),phone=TextEditingController(),notes=TextEditingController();
  DateTime? selectedDate; TimeOfDay? selectedTime;
  final result=await showDialog<bool>(context:context,builder:(c)=>StatefulBuilder(builder:(c,ds)=>AlertDialog(
   title:Text('طلب حجز - ${m['name']}'),
   content:SizedBox(width:420,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
    TextField(controller:name,decoration:const InputDecoration(labelText:'الاسم الكامل',prefixIcon:Icon(Icons.person))),
    TextField(controller:phone,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'رقم الهاتف',prefixIcon:Icon(Icons.phone))),
    const SizedBox(height:10),
    OutlinedButton.icon(onPressed:()async{final d=await showDatePicker(context:c,initialDate:selectedDate??DateTime.now().add(const Duration(days:1)),firstDate:DateTime.now(),lastDate:DateTime.now().add(const Duration(days:365)));if(d!=null)ds(()=>selectedDate=d);},icon:const Icon(Icons.calendar_month),label:Text(selectedDate==null?'اختيار تاريخ الحجز':'${selectedDate!.year}/${selectedDate!.month}/${selectedDate!.day}')),
    OutlinedButton.icon(onPressed:()async{final t=await showTimePicker(context:c,initialTime:selectedTime??TimeOfDay.now());if(t!=null)ds(()=>selectedTime=t);},icon:const Icon(Icons.schedule),label:Text(selectedTime==null?'اختيار وقت الحجز':selectedTime!.format(c))),
    TextField(controller:notes,maxLines:2,decoration:const InputDecoration(labelText:'ملاحظات إضافية')),
   ]))),
   actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('إرسال الطلب'))],
  )));
  if(result==true){if(name.text.trim().isEmpty||phone.text.trim().isEmpty||selectedDate==null||selectedTime==null){note('أكمل الاسم ورقم الهاتف والتاريخ والوقت');}else{final dt=DateTime(selectedDate!.year,selectedDate!.month,selectedDate!.day,selectedTime!.hour,selectedTime!.minute);await SharedStore.save('bookings',{'customerName':name.text.trim(),'phone':phone.text.trim(),'memberId':m['id'],'memberName':m['name'],'date':dt.toIso8601String(),'notes':notes.text.trim(),'status':'قيد المراجعة'});note('تم إرسال طلب الحجز');await load();}}
  name.dispose();phone.dispose();notes.dispose();
 }
 Future<void> sendMessage()async{final value=messageCtrl.text.trim();if(value.isEmpty)return;try{await SharedStore.save('messages',{'conversationId':conversationId,'sender':'عميل','text':value,'createdAt':DateTime.now().toIso8601String()});messageCtrl.clear();await load(silent:true);}catch(e){note('تعذر إرسال الرسالة: $e');}}
 Widget photo(Map<String,dynamic> m,{double size=66}){final images=List<String>.from(m['images']??[]);if(images.isEmpty)return CircleAvatar(radius:size/2,child:const Icon(Icons.spa_outlined));try{return ClipRRect(borderRadius:BorderRadius.circular(12),child:Image.memory(base64Decode(images.first),width:size,height:size,fit:BoxFit.cover));}catch(_){return CircleAvatar(radius:size/2,child:const Icon(Icons.spa));}}
 void openMember(Map<String,dynamic> m){Navigator.push(context,MaterialPageRoute(builder:(_)=>Scaffold(backgroundColor:cream,appBar:AppBar(title:Text('${m['name']??'الملف الشخصي'}')),body:Directionality(textDirection:TextDirection.rtl,child:memberProfilePage(m)))));}
 void previewMember(Map<String,dynamic> m){showModalBottomSheet(context:context,isScrollControlled:true,backgroundColor:cream,shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(26))),builder:(c)=>Directionality(textDirection:TextDirection.rtl,child:SafeArea(child:Padding(padding:const EdgeInsets.fromLTRB(18,12,18,22),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
  Center(child:Container(width:42,height:4,decoration:BoxDecoration(color:Colors.grey.shade400,borderRadius:BorderRadius.circular(4)))),
  const SizedBox(height:12),
  ClipRRect(borderRadius:BorderRadius.circular(18),child:photo(m,size:220)),
  const SizedBox(height:12),Text('${m['name']??''}',style:const TextStyle(fontSize:21,fontWeight:FontWeight.bold)),
  Text('العمر: ${m['age']??'-'}  •  الساعة: ${m['hourlyPrice']??0} د.ع'),
  if((m['description']??'').toString().isNotEmpty)Padding(padding:const EdgeInsets.only(top:8),child:Text('${m['description']}')),
  const SizedBox(height:14),Row(children:[Expanded(child:OutlinedButton.icon(onPressed:(){Navigator.pop(c);openMember(m);},icon:const Icon(Icons.person),label:const Text('الملف الكامل'))),const SizedBox(width:8),Expanded(child:FilledButton.icon(onPressed:(){Navigator.pop(c);book(m);},icon:const Icon(Icons.calendar_month),label:const Text('احجز الآن')))])
 ])))));}
 Widget memberProfilePage(Map<String,dynamic> m)=>ListView(padding:const EdgeInsets.all(16),children:[
  Center(child:photo(m,size:250)),
  const SizedBox(height:14),Text('${m['name']??''}',textAlign:TextAlign.center,style:const TextStyle(fontSize:24,fontWeight:FontWeight.bold)),
  const SizedBox(height:14),
  Card(child:Column(children:[ListTile(leading:const Icon(Icons.cake_outlined),title:const Text('العمر'),subtitle:Text('${m['age']??'-'}')),ListTile(leading:const Icon(Icons.payments_outlined),title:const Text('سعر الساعة'),subtitle:Text('${m['hourlyPrice']??0} د.ع')),ListTile(leading:const Icon(Icons.nights_stay_outlined),title:const Text('سعر الليلة'),subtitle:Text('${m['nightlyPrice']??0} د.ع')),ListTile(leading:const Icon(Icons.place_outlined),title:const Text('المكان'),subtitle:Text(m['hasPlace']==true?'يوجد مكان':'لا يوجد مكان')),if((m['address']??'').toString().isNotEmpty)ListTile(leading:const Icon(Icons.location_on_outlined),title:const Text('العنوان'),subtitle:Text('${m['address']}'))])),
  if((m['description']??'').toString().isNotEmpty)Card(child:Padding(padding:const EdgeInsets.all(16),child:Text('${m['description']}'))),
  FilledButton.icon(onPressed:()=>book(m),icon:const Icon(Icons.calendar_month),label:const Text('احجز موعداً')),
 ]);
 Widget memberCard(Map<String,dynamic> m)=>Card(clipBehavior:Clip.antiAlias,child:InkWell(onTap:()=>openMember(m),onLongPress:()=>previewMember(m),child:Padding(padding:const EdgeInsets.all(8),child:Row(children:[
  photo(m,size:76),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${m['name']??''}',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:16)),Text('العمر: ${m['age']??'-'} • ${m['hourlyPrice']??0} د.ع/ساعة',maxLines:1,overflow:TextOverflow.ellipsis),Text(m['hasPlace']==true?'يوجد مكان':'لا يوجد مكان',style:const TextStyle(color:plum))])),
  IconButton(onPressed:()=>toggleFav(m),icon:Icon(isFav(m)?Icons.favorite:Icons.favorite_border,color:isFav(m)?Colors.pink:null)),
  const Icon(Icons.chevron_left)
 ])))));
 Widget homePage()=>ListView(padding:const EdgeInsets.all(14),children:[
  Container(height:170,padding:const EdgeInsets.all(22),decoration:BoxDecoration(gradient:const LinearGradient(colors:[rose,plum]),borderRadius:BorderRadius.circular(24)),child:const Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.center,children:[Text('AL SHEIKHA MASSAGE CENTER',style:TextStyle(color:Colors.white70)),SizedBox(height:12),Text('الراحة تبدأ من هنا',style:TextStyle(color:Colors.white,fontSize:26,fontWeight:FontWeight.bold)),Text('عناية وراحة بتجربة مميزة',style:TextStyle(color:Colors.white))])),
  if(banners.isNotEmpty)...banners.map((b)=>Card(child:Column(children:[if((b['images'] as List? ?? []).isNotEmpty)Image.memory(base64Decode((b['images'] as List).first),height:145,width:double.infinity,fit:BoxFit.cover),ListTile(title:Text('${b['title']??''}'),subtitle:Text('${b['description']??''}'))]))),
  const SizedBox(height:12),const Text('الكادر المتوفر',style:TextStyle(fontSize:21,fontWeight:FontWeight.bold)),
  ...members.where((m)=>'${m['name']} ${m['description']}'.toLowerCase().contains(search.toLowerCase())).map(memberCard),
  const SizedBox(height:16),const Text('أرشيف الجلسات',style:TextStyle(fontSize:21,fontWeight:FontWeight.bold)),
  ...sessions.map((s)=>Card(child:Column(children:[if((s['images'] as List? ?? []).isNotEmpty)Image.memory(base64Decode((s['images'] as List).first),height:150,width:double.infinity,fit:BoxFit.cover),ListTile(title:Text('${s['title']??'جلسة'}'),subtitle:Text('${s['date']??''} • ${s['description']??''}'))]))),
 ]);
 Widget favoritesPage()=>ListView(padding:const EdgeInsets.all(12),children:[const Text('المفضلة',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold)),...members.where(isFav).map(memberCard),if(!favorites.any((f)=>members.any((m)=>m['id']==f['memberId'])))const Padding(padding:EdgeInsets.all(18),child:Text('لم تضف أي عضو إلى المفضلة بعد.'))]);
 Widget bookingsPage()=>ListView(padding:const EdgeInsets.all(12),children:[const Text('طلباتي وحجوزاتي',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold)),...bookings.map((b)=>Card(child:ListTile(leading:const Icon(Icons.event_available),title:Text('${b['memberName']??'حجز'}'),subtitle:Text('${b['date']??''} • ${b['status']??'قيد المراجعة'}')))),if(bookings.isEmpty)const Text('لا توجد حجوزات حتى الآن.')]);
 Widget chatPage()=>Column(children:[
  const ListTile(leading:CircleAvatar(child:Icon(Icons.support_agent)),title:Text('التواصل مع الإدارة'),subtitle:Text('يمكنك إرسال الرسائل واستقبال رد الإدارة هنا')),
  Expanded(child:messages.isEmpty?const Center(child:Text('ابدأ المحادثة بإرسال رسالتك الأولى')):ListView(padding:const EdgeInsets.all(12),children:messages.map((m){final mine=m['sender']=='عميل';return Align(alignment:mine?Alignment.centerRight:Alignment.centerLeft,child:Container(constraints:const BoxConstraints(maxWidth:320),margin:const EdgeInsets.symmetric(vertical:5),padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:mine?rose.withOpacity(.18):plum.withOpacity(.16),borderRadius:BorderRadius.circular(14)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${m['sender']??'الإدارة'}',style:const TextStyle(fontSize:12,fontWeight:FontWeight.bold)),const SizedBox(height:4),Text('${m['text']??''}'),const SizedBox(height:3),Text('${m['createdAt']??''}',style:const TextStyle(fontSize:10,color:Colors.grey))])));}).toList())),
  SafeArea(child:Padding(padding:const EdgeInsets.all(8),child:Row(children:[Expanded(child:TextField(controller:messageCtrl,minLines:1,maxLines:4,decoration:const InputDecoration(hintText:'اكتب رسالتك...',border:OutlineInputBorder()),onSubmitted:(_)=>sendMessage())),IconButton(onPressed:sendMessage,icon:const Icon(Icons.send))]))),
 ]);
 Widget morePage()=>ListView(padding:const EdgeInsets.all(18),children:[const ListTile(leading:Icon(Icons.spa),title:Text('مركز الشيخة'),subtitle:Text('نرحب بكم دائماً')),const ListTile(leading:Icon(Icons.currency_exchange),title:Text('العملة'),subtitle:Text('الدينار العراقي (د.ع)')),ListTile(leading:const Icon(Icons.refresh),title:const Text('تحديث البيانات'),onTap:load)]);
 Widget currentPage()=>switch(tab){1=>favoritesPage(),2=>bookingsPage(),3=>chatPage(),4=>morePage(),_=>homePage()};
 @override Widget build(BuildContext context)=>Directionality(textDirection:TextDirection.rtl,child:Scaffold(
  appBar:AppBar(title:const Text('الشيخة',style:TextStyle(fontWeight:FontWeight.bold)),actions:[if(tab==0)IconButton(tooltip:'المفضلة',onPressed:()=>setState(()=>tab=1),icon:const Icon(Icons.favorite_border)),if(tab==0)IconButton(tooltip:'البحث',onPressed:()=>showSearch(context:context,delegate:MemberSearch(members,onPick:(v){setState(()=>search=v);})),icon:const Icon(Icons.search)),IconButton(onPressed:load,icon:const Icon(Icons.refresh))]),
  body:busy?const Center(child:CircularProgressIndicator()):RefreshIndicator(onRefresh:load,child:currentPage()),
  bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),destinations:const[NavigationDestination(icon:Icon(Icons.home_outlined),label:'الرئيسية'),NavigationDestination(icon:Icon(Icons.favorite_border),label:'المفضلة'),NavigationDestination(icon:Icon(Icons.calendar_month),label:'حجوزاتي'),NavigationDestination(icon:Icon(Icons.chat_outlined),label:'الدردشة'),NavigationDestination(icon:Icon(Icons.more_horiz),label:'المزيد')])
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
