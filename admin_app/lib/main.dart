import 'package:flutter/material.dart';
import 'shared_store.dart';

void main() => runApp(const SheikhaAdminApp());

class SheikhaAdminApp extends StatelessWidget {
  const SheikhaAdminApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false, title: 'الشيخة - الإدارة',
    theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFB77D91)), scaffoldBackgroundColor: const Color(0xFFFFF9F6)),
    darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark, colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFB77D91), brightness: Brightness.dark)),
    themeMode: ThemeMode.system, home: const AdminDashboard());
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override State<AdminDashboard> createState() => _AdminDashboardState();
}
class _AdminDashboardState extends State<AdminDashboard> {
  List<Map<String,dynamic>> members=[];
  bool loading=true;
  @override void initState(){super.initState(); refresh();}
  Future<void> refresh() async { try { final rows=await SharedStore.list('members'); if(mounted)setState(()=>members=rows); } catch(e){ if(mounted) _message('تعذر الاتصال بالتخزين المشترك: $e'); } finally {if(mounted)setState(()=>loading=false);} }
  void _message(String s)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));
  Future<void> edit([Map<String,dynamic>? old]) async {
    final name=TextEditingController(text:old?['name']??'');
    final age=TextEditingController(text:'${old?['age']??''}');
    final address=TextEditingController(text:old?['address']??'');
    final hourly=TextEditingController(text:'${old?['hourlyPrice']??''}');
    final nightly=TextEditingController(text:'${old?['nightlyPrice']??''}');
    bool hasPlace=old?['hasPlace']??false, available=old?['available']??true;
    final form=GlobalKey<FormState>();
    final data=await showDialog<Map<String,dynamic>>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setDialog)=>AlertDialog(
      title:Text(old==null?'إضافة عضو للكادر':'تعديل ملف العضو'),
      content:Form(key:form,child:SizedBox(width:420,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        _field(name,'الاسم',required:true),_field(age,'العمر',number:true),_field(address,'العنوان'),_field(hourly,'سعر الساعة بالدينار',number:true),_field(nightly,'سعر الليلة بالدينار',number:true),
        SwitchListTile(value:hasPlace,title:const Text('يوجد مكان'),onChanged:(v)=>setDialog(()=>hasPlace=v)),
        SwitchListTile(value:available,title:const Text('متوفر للحجز'),onChanged:(v)=>setDialog(()=>available=v)),
      ])))),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),FilledButton(onPressed:(){if(form.currentState!.validate())Navigator.pop(ctx,{'id':old?['id'],'name':name.text.trim(),'age':int.tryParse(age.text)??0,'address':address.text.trim(),'hourlyPrice':double.tryParse(hourly.text)??0,'nightlyPrice':double.tryParse(nightly.text)??0,'hasPlace':hasPlace,'available':available});},child:const Text('حفظ'))],
    )));
    if(data!=null){try{await SharedStore.save('members',data);await refresh();_message('تم حفظ بيانات الكادر');}catch(e){_message('فشل الحفظ: $e');}}
  }
  Widget _field(TextEditingController c,String label,{bool number=false,bool required=false})=>Padding(padding:const EdgeInsets.only(bottom:10),child:TextFormField(controller:c,keyboardType:number?TextInputType.number:TextInputType.text,validator:(v)=>required&&(v==null||v.trim().isEmpty)?'هذا الحقل مطلوب':null,decoration:InputDecoration(labelText:label,border:const OutlineInputBorder())));
  Future<void> remove(Map<String,dynamic> m)async{await SharedStore.delete('members',m['id']);await refresh();}
  @override Widget build(BuildContext context)=>Directionality(textDirection:TextDirection.rtl,child:Scaffold(
    appBar:AppBar(title:const Text('الشيخة | لوحة الإدارة'),actions:[IconButton(onPressed:refresh,icon:const Icon(Icons.refresh))]),
    floatingActionButton:FloatingActionButton.extended(onPressed:()=>edit(),icon:const Icon(Icons.person_add_alt_1),label:const Text('إضافة عضو')),
    body:loading?const Center(child:CircularProgressIndicator()):RefreshIndicator(onRefresh:refresh,child:ListView(padding:const EdgeInsets.all(16),children:[
      Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFFB77D91),Color(0xFF80647F)]),borderRadius:BorderRadius.circular(22)),child:Text('إدارة الكادر\n${members.length} ملف محفوظ',style:const TextStyle(color:Colors.white,fontSize:20,fontWeight:FontWeight.bold))),
      const SizedBox(height:14),if(members.isEmpty)const Card(child:Padding(padding:EdgeInsets.all(20),child:Text('لا توجد ملفات بعد. اضغط «إضافة عضو» للبدء.'))),
      ...members.map((m)=>Card(child:ListTile(leading:CircleAvatar(child:Text((m['name']??'؟').toString().isEmpty?'؟':(m['name'] as String).characters.first)),title:Text(m['name']??''),subtitle:Text('العمر: ${m['age']??'-'} • الساعة: ${m['hourlyPrice']??0} د.ع • الليلة: ${m['nightlyPrice']??0} د.ع\n${m['available']==true?'متوفر':'مشغول'} • ${m['hasPlace']==true?'يوجد مكان':'لا يوجد مكان'}'),isThreeLine:true,trailing:PopupMenuButton<String>(onSelected:(v)=>v=='edit'?edit(m):remove(m),itemBuilder:(_)=>const[PopupMenuItem(value:'edit',child:Text('تعديل')),PopupMenuItem(value:'delete',child:Text('حذف'))])))),
      const SizedBox(height:80)
    ]))));
}
