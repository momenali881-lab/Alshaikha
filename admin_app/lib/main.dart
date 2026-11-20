import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'shared_store.dart';

void main() => runApp(const SheikhaAdminApp());

const rose = Color(0xFFB77D91);
const plum = Color(0xFF80647F);
const cream = Color(0xFFFFF9F6);
const sections = <String,String>{'members':'الكادر','sessions':'أرشيف الجلسات','banners':'البانرات','bookings':'الحجوزات','messages':'الدردشة'};

class SheikhaAdminApp extends StatelessWidget {
  const SheikhaAdminApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner:false, title:'الشيخة - الإدارة',
    theme:ThemeData(useMaterial3:true,colorScheme:ColorScheme.fromSeed(seedColor:rose),scaffoldBackgroundColor:cream),
    darkTheme:ThemeData(useMaterial3:true,brightness:Brightness.dark,colorScheme:ColorScheme.fromSeed(seedColor:rose,brightness:Brightness.dark)),
    themeMode:ThemeMode.system, home:const AdminHome());
}

class AdminHome extends StatefulWidget { const AdminHome({super.key}); @override State<AdminHome> createState()=>_AdminHomeState(); }
class _AdminHomeState extends State<AdminHome> {
  String section='members'; List<Map<String,dynamic>> rows=[]; bool busy=true; Timer? poll;
  @override void initState(){super.initState(); refresh(); poll=Timer.periodic(const Duration(seconds:5),(_)=>refresh(silent:true));}
  @override void dispose(){poll?.cancel();super.dispose();}
  void note(String s)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));
  Future<void> refresh({bool silent=false}) async {
    if(!silent && mounted)setState(()=>busy=true);
    try { final data=await SharedStore.list(section); if(mounted)setState(()=>rows=data); }
    catch(e){if(!silent&&mounted)note('تعذر تحميل البيانات: $e');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Map<String,String> fieldsFor(String s)=>switch(s){
    'members'=>{'name':'الاسم','age':'العمر','address':'العنوان','hourlyPrice':'سعر الساعة بالدينار','nightlyPrice':'سعر الليلة بالدينار','description':'نبذة وتعريف','hasPlace':'يوجد مكان؟','available':'متاح للحجز؟'},
    'sessions'=>{'title':'عنوان الجلسة','memberId':'معرّف عضو الكادر (اختياري)','date':'التاريخ','description':'الوصف'},
    'banners'=>{'title':'عنوان البانر','description':'النص الظاهر','targetType':'الربط (member أو session)','targetId':'معرّف العنصر المرتبط'},
    'bookings'=>{'customerName':'اسم العميل','phone':'رقم الهاتف','memberName':'اسم العضو','date':'الموعد المطلوب','notes':'ملاحظات','status':'الحالة'},
    _=>{'conversationId':'رقم المحادثة','sender':'المرسل','text':'نص الرسالة','createdAt':'وقت الإرسال'}
  };
  Future<List<String>> pickImages([List<String> existing=const[]]) async {
    final picker=ImagePicker();
    final files=await picker.pickMultiImage(imageQuality:72,maxWidth:1500);
    if(files.isEmpty)return existing;
    final out=[...existing];
    for(final f in files.take(10-existing.length)){out.add(base64Encode(await f.readAsBytes()));}
    return out;
  }
  Future<void> edit([Map<String,dynamic>? old]) async {
    final fields=fieldsFor(section); final ctrls=<String,TextEditingController>{};
    for(final e in fields.entries){ctrls[e.key]=TextEditingController(text:'${old?[e.key]??''}');}
    bool available=old?['available']!=false, hasPlace=old == null || old['hasPlace']==true, active=old?['active']!=false;
    List<String> images=List<String>.from(old?['images']??[]);
    final result=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,ds)=>AlertDialog(
      title:Text(old==null?'إضافة ${sections[section]}':'تعديل ${sections[section]}'),
      content:SizedBox(width:460,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        ...fields.entries.where((e)=>!['available','hasPlace'].contains(e.key)).map((e)=>Padding(padding:const EdgeInsets.only(bottom:10),child:TextField(controller:ctrls[e.key],maxLines:['description','notes','text'].contains(e.key)?3:1,keyboardType:['age','hourlyPrice','nightlyPrice'].contains(e.key)?TextInputType.number:TextInputType.text,decoration:InputDecoration(labelText:e.value,border:const OutlineInputBorder())))),
        if(section=='members')...[
          SwitchListTile(value:hasPlace,onChanged:(v)=>ds(()=>hasPlace=v),title:const Text('يوجد مكان')),
          SwitchListTile(value:available,onChanged:(v)=>ds(()=>available=v),title:const Text('متاح للحجز')),
        ],
        if(section=='banners')SwitchListTile(value:active,onChanged:(v)=>ds(()=>active=v),title:const Text('عرض البانر للعملاء')),
        if(['members','sessions','banners'].contains(section))...[
          Align(alignment:Alignment.centerRight,child:Text('الصور ${images.length}/10')),
          Wrap(spacing:6,children:images.asMap().entries.map((e)=>Stack(children:[
            ClipRRect(borderRadius:BorderRadius.circular(8),child:Image.memory(base64Decode(e.value),width:62,height:62,fit:BoxFit.cover)),
            Positioned(right:0,top:0,child:InkWell(onTap:()=>ds(()=>images.removeAt(e.key)),child:const CircleAvatar(radius:10,child:Icon(Icons.close,size:12))))
          ])).toList()),
          OutlinedButton.icon(onPressed:images.length>=10?null:()async{final v=await pickImages(images);ds(()=>images=v);},icon:const Icon(Icons.add_photo_alternate),label:const Text('اختيار صور من الهاتف')),
        ]
      ]))),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('حفظ'))],
    )));
    if(result==true){
      final data=<String,dynamic>{'id':old?['id']};
      for(final key in fields.keys){if(key=='available'||key=='hasPlace')continue;final v=ctrls[key]!.text.trim();data[key]=key=='age'?int.tryParse(v)??0:(key=='hourlyPrice'||key=='nightlyPrice')?double.tryParse(v)??0:v;}
      if(section=='members'){data['available']=available;data['hasPlace']=hasPlace;}
      if(section=='banners')data['active']=active;
      if(['members','sessions','banners'].contains(section))data['images']=images;
      try{await SharedStore.save(section,data);await refresh();note('تم الحفظ بنجاح');}catch(e){note('فشل الحفظ: $e');}
    }
    for(final c in ctrls.values){c.dispose();}
  }
  Future<void> remove(Map<String,dynamic> item) async {
    final yes=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('حذف السجل؟'),content:const Text('لا يمكن التراجع عن الحذف.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('حذف'))]));
    if(yes==true){await SharedStore.delete(section,item['id']);await refresh();}
  }
  Future<void> updateBooking(Map<String,dynamic> b,String status)async{final d={...b,'status':status};await SharedStore.save('bookings',d);await refresh();}
  Widget recordCard(Map<String,dynamic> m){
    final title=m['name']??m['title']??m['customerName']??m['sender']??'سجل';
    final subtitle=[m['description'],m['date'],m['status'],if(section=='members')'${m['hourlyPrice']??0} د.ع/ساعة',if(section=='members')'${m['nightlyPrice']??0} د.ع/ليلة'].where((x)=>x!=null&&x.toString().isNotEmpty).join(' • ');
    final imgs=List<String>.from(m['images']??[]);
    return Card(child:Padding(padding:const EdgeInsets.all(8),child:Column(children:[
      ListTile(leading:imgs.isNotEmpty?ClipRRect(borderRadius:BorderRadius.circular(8),child:Image.memory(base64Decode(imgs.first),width:52,height:52,fit:BoxFit.cover)):const CircleAvatar(child:Icon(Icons.spa)),title:Text('$title'),subtitle:Text(subtitle),trailing:PopupMenuButton<String>(onSelected:(v){if(v=='edit')edit(m);else if(v=='delete')remove(m);else if(v=='accept')updateBooking(m,'مؤكد');else updateBooking(m,'مرفوض');},itemBuilder:(_)=>[
        if(section=='bookings')const PopupMenuItem(value:'accept',child:Text('تأكيد الحجز')),
        if(section=='bookings')const PopupMenuItem(value:'reject',child:Text('رفض الحجز')),
        const PopupMenuItem(value:'edit',child:Text('تعديل')),
        const PopupMenuItem(value:'delete',child:Text('حذف')),
      ])),
      if(section=='messages')Align(alignment:Alignment.centerRight,child:Text('المحادثة: ${m['conversationId']??'-'}')),
    ])));
  }
  @override Widget build(BuildContext context)=>Directionality(textDirection:TextDirection.rtl,child:Scaffold(
    appBar:AppBar(title:const Text('الشيخة | الإدارة'),actions:[IconButton(onPressed:()=>refresh(),icon:const Icon(Icons.refresh))]),
    floatingActionButton:section=='messages'?null:FloatingActionButton.extended(onPressed:()=>edit(),icon:const Icon(Icons.add),label:const Text('إضافة')),
    body:Column(children:[
      SizedBox(height:58,child:ListView(scrollDirection:Axis.horizontal,padding:const EdgeInsets.symmetric(horizontal:8),children:sections.entries.map((e)=>Padding(padding:const EdgeInsets.all(4),child:ChoiceChip(label:Text(e.value),selected:section==e.key,onSelected:(_){setState(()=>section=e.key);refresh();}))).toList())),
      Expanded(child:busy?const Center(child:CircularProgressIndicator()):RefreshIndicator(onRefresh:refresh,child:ListView(padding:const EdgeInsets.all(14),children:[
        Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(gradient:const LinearGradient(colors:[rose,plum]),borderRadius:BorderRadius.circular(22)),child:Text('${sections[section]}\n${rows.length} سجل',style:const TextStyle(color:Colors.white,fontSize:22,fontWeight:FontWeight.bold))),
        if(section=='banners'&&rows.length>=7)const Padding(padding:EdgeInsets.all(8),child:Text('وصلت إلى الحد الأقصى: 7 بانرات.')),
        if(rows.isEmpty)const Card(child:Padding(padding:EdgeInsets.all(20),child:Text('لا توجد بيانات بعد. استخدم زر الإضافة للبدء.'))),
        ...rows.map(recordCard),const SizedBox(height:90)
      ])))
    ])
  ));
}
