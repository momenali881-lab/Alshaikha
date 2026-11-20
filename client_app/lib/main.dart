import 'package:flutter/material.dart';
import 'shared_store.dart';

void main()=>runApp(const SheikhaClientApp());
class SheikhaClientApp extends StatelessWidget{
 const SheikhaClientApp({super.key});
 @override Widget build(BuildContext context)=>MaterialApp(debugShowCheckedModeBanner:false,title:'الشيخة',theme:ThemeData(useMaterial3:true,colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xFFB77D91)),scaffoldBackgroundColor:const Color(0xFFFFF9F6)),darkTheme:ThemeData(useMaterial3:true,brightness:Brightness.dark,colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xFFB77D91),brightness:Brightness.dark)),themeMode:ThemeMode.system,home:const ClientHome());
}
class ClientHome extends StatefulWidget{const ClientHome({super.key});@override State<ClientHome> createState()=>_ClientHomeState();}
class _ClientHomeState extends State<ClientHome>{
 List<Map<String,dynamic>> members=[];bool loading=true;int tab=0;
 @override void initState(){super.initState();load();}
 Future<void> load()async{try{final data=await SharedStore.list('members');if(mounted)setState(()=>members=data.where((m)=>m['available']==true).toList());}catch(e){}finally{if(mounted)setState(()=>loading=false);}}
 @override Widget build(BuildContext context)=>Directionality(textDirection:TextDirection.rtl,child:Scaffold(
 appBar:AppBar(title:const Text('الشيخة',style:TextStyle(fontWeight:FontWeight.bold)),actions:[IconButton(onPressed:load,icon:const Icon(Icons.refresh))]),
 body:RefreshIndicator(onRefresh:load,child:ListView(padding:const EdgeInsets.all(16),children:[
 Container(height:160,padding:const EdgeInsets.all(22),decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFFB77D91),Color(0xFF80647F)]),borderRadius:BorderRadius.circular(24)),child:const Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.center,children:[Text('AL SHEIKHA MASSAGE CENTER',style:TextStyle(color:Colors.white70)),SizedBox(height:12),Text('الراحة تبدأ من هنا',style:TextStyle(color:Colors.white,fontSize:25,fontWeight:FontWeight.bold)),Text('تصفح الكادر المتاح',style:TextStyle(color:Colors.white))])),
 const SizedBox(height:18),const Text('الكادر المتوفر',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),const SizedBox(height:8),
 if(loading)const Center(child:CircularProgressIndicator()) else if(members.isEmpty)const Card(child:Padding(padding:EdgeInsets.all(18),child:Text('لا توجد ملفات كادر متاحة حالياً. اسحب للتحديث.'))),
 ...members.map((m)=>Card(child:ListTile(leading:const CircleAvatar(child:Icon(Icons.spa_outlined)),title:Text(m['name']??''),subtitle:Text('سعر الساعة: ${m['hourlyPrice']??0} د.ع • الليلة: ${m['nightlyPrice']??0} د.ع\n${m['hasPlace']==true?'يوجد مكان':'لا يوجد مكان'}'),isThreeLine:true,trailing:const Icon(Icons.chevron_left)))),
 ])),
 bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),destinations:const[NavigationDestination(icon:Icon(Icons.home_outlined),label:'الرئيسية'),NavigationDestination(icon:Icon(Icons.favorite_border),label:'المفضلة'),NavigationDestination(icon:Icon(Icons.calendar_month_outlined),label:'الحجوزات'),NavigationDestination(icon:Icon(Icons.chat_outlined),label:'الدردشة'),NavigationDestination(icon:Icon(Icons.more_horiz),label:'المزيد')])
 ));
}
