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
   if(mounted)setState((){members=r[0].where((m)=>m['available']!=false).toList();sessions=r[1];banners=r[2].where((b)=>b['active']!=false).take(7).toList();bookings=r[3];favorites=r[4];messages=r[5].where((m)=>m['conversationId']==conversationId).toList();});
  }catch(e){if(!silent&&mounted)note('تعذر تحميل البيانات المشتركة: $e');}finally{if(mounted)setState(()=>busy=false);}
 }
 bool isFav(Map<String,dynamic> m)=>favorites.any((f)=>f['memberId']==m['id']);
 Future<void> toggleFav(Map<String,dynamic> m)async{final old=favorites.where((f)=>f['memberId']==m['id']).toList();if(old.isNotEmpty){await SharedStore.delete('favorites',old.first['id']);}else{await SharedStore.save('favorites',{'memberId':m['id'],'memberName':m['name']});}await load(silent:true);}
 Future<void> book(Map<String,dynamic> m)async{
  final name=TextEditingController(),phone=TextEditingController(),date=TextEditingController(),notes=TextEditingController();
  final result=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text('طلب حجز - ${m['name']}'),content:SizedBox(width:420,child:SingleChildScrollView(child:Column(children:[
   TextField(controller:name,decoration:const InputDecoration(labelText:'الاسم الكامل')),
   TextField(controller:phone,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'رقم الهاتف')),
   TextField(controller:date,decoration:const InputDecoration(labelText:'التاريخ والوقت المطلوب')),
   TextField(controller:notes,maxLines:2,decoration:const InputDecoration(labelText:'ملاحظات إضافية')),
  ]))),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('إرسال'))]));
  if(result==true){if(name.text.trim().isEmpty||phone.text.trim().isEmpty||date.text.trim().isEmpty){note('أكمل الاسم ورقم الهاتف والموعد');}else{await SharedStore.save('bookings',{'customerName':name.text.trim(),'phone':phone.text.trim(),'memberId':m['id'],'memberName':m['name'],'date':date.text.trim(),'notes':notes.text.trim(),'status':'قيد المراجعة'});note('تم إرسال طلب الحجز');await load();}}
  name.dispose();phone.dispose();date.dispose();notes.dispose();
 }
 Future<void> sendMessage()async{final value=messageCtrl.text.trim();if(value.isEmpty)return;await SharedStore.save('messages',{'conversationId':conversationId,'sender':'عميل','text':value,'createdAt':DateTime.now().toIso8601String()});messageCtrl.clear();await load(silent:true);}
 Widget photo(Map<String,dynamic> m){final images=List<String>.from(m['images']??[]);if(images.isEmpty)return const CircleAvatar(radius:30,child:Icon(Icons.spa_outlined));try{return ClipRRect(borderRadius:BorderRadius.circular(12),child:Image.memory(base64Decode(images.first),width:66,height:66,fit:BoxFit.cover));}catch(_){return const CircleAvatar(child:Icon(Icons.spa));}}
 Widget memberCard(Map<String,dynamic> m)=>Card(child:Padding(padding:const EdgeInsets.all(8),child:Column(children:[
  ListTile(leading:photo(m),title:Text('${m['name']??''}',style:const TextStyle(fontWeight:FontWeight.bold)),subtitle:Text('العمر: ${m['age']??'-'} • الساعة: ${m['hourlyPrice']??0} د.ع • الليلة: ${m['nightlyPrice']??0} د.ع\n${m['hasPlace']==true?'يوجد مكان':'لا يوجد مكان'}'),isThreeLine:true,trailing:IconButton(onPressed:()=>toggleFav(m),icon:Icon(isFav(m)?Icons.favorite:Icons.favorite_border,color:isFav(m)?Colors.pink:null))),
  if((m['description']??'').toString().isNotEmpty)Align(alignment:Alignment.centerRight,child:Text(m['description'])),
  Align(alignment:Alignment.centerLeft,child:FilledButton.icon(onPressed:()=>book(m),icon:const Icon(Icons.calendar_month),label:const Text('احجز الآن'))),
  if((m['images'] as List? ?? []).length>1)SizedBox(height:94,child:ListView(scrollDirection:Axis.horizontal,children:List<String>.from(m['images']).skip(1).map((s)=>Padding(padding:const EdgeInsets.all(4),child:ClipRRect(borderRadius:BorderRadius.circular(8),child:Image.memory(base64Decode(s),width:100,height:84,fit:BoxFit.cover)))).toList()))
 ])));
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
  const ListTile(leading:CircleAvatar(child:Icon(Icons.support_agent)),title:Text('التواصل مع الإدارة'),subtitle:Text('اكتب رسالتك وسيتم عرضها للإدارة')),
  Expanded(child:ListView(padding:const EdgeInsets.all(12),children:messages.map((m)=>Align(alignment:m['sender']=='عميل'?Alignment.centerRight:Alignment.centerLeft,child:Container(margin:const EdgeInsets.symmetric(vertical:4),padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:m['sender']=='عميل'?rose.withOpacity(.18):plum.withOpacity(.16),borderRadius:BorderRadius.circular(14)),child:Text('${m['text']??''}')))).toList())),
  SafeArea(child:Padding(padding:const EdgeInsets.all(8),child:Row(children:[Expanded(child:TextField(controller:messageCtrl,decoration:const InputDecoration(hintText:'اكتب رسالة...',border:OutlineInputBorder()))),IconButton(onPressed:sendMessage,icon:const Icon(Icons.send))])))
 ]);
 Widget morePage()=>ListView(padding:const EdgeInsets.all(18),children:[const ListTile(leading:Icon(Icons.spa),title:Text('مركز الشيخة'),subtitle:Text('نرحب بكم دائماً')),const ListTile(leading:Icon(Icons.currency_exchange),title:Text('العملة'),subtitle:Text('الدينار العراقي (د.ع)')),ListTile(leading:const Icon(Icons.refresh),title:const Text('تحديث البيانات'),onTap:load)]);
 Widget currentPage()=>switch(tab){1=>favoritesPage(),2=>bookingsPage(),3=>chatPage(),4=>morePage(),_=>homePage()};
 @override Widget build(BuildContext context)=>Directionality(textDirection:TextDirection.rtl,child:Scaffold(
  appBar:AppBar(title:const Text('الشيخة',style:TextStyle(fontWeight:FontWeight.bold)),actions:[if(tab==0)IconButton(onPressed:()=>showSearch(context:context,delegate:MemberSearch(members,onPick:(v){setState(()=>search=v);})),icon:const Icon(Icons.search)),IconButton(onPressed:load,icon:const Icon(Icons.refresh))]),
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
