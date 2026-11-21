import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'shared_store.dart';

void main() => runApp(const SheikhaAdminApp());

const rose = Color(0xFFE91E63);
const plum = Color(0xFF6A1B9A);
const cream = Color(0xFFFFF7FB);
const teal = Color(0xFF00A6A6);
const gold = Color(0xFFFFB300);
const sections = <String,String>{'members':'الكادر','sessions':'أرشيف الجلسات','banners':'البانرات','bookings':'الحجوزات','messages':'الدردشة','announcements':'الإعلانات'};
const sectionIcons=<String,IconData>{'members':Icons.groups_rounded,'sessions':Icons.photo_library_rounded,'banners':Icons.campaign_rounded,'bookings':Icons.event_available_rounded,'messages':Icons.forum_rounded,'announcements':Icons.notifications_active_rounded};
const sectionColors=<String,Color>{'members':teal,'sessions':plum,'banners':gold,'bookings':rose,'messages':Color(0xFF3F51B5),'announcements':teal};

class SheikhaAdminApp extends StatelessWidget {
  const SheikhaAdminApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner:false, title:'الشيخة - الإدارة',
    theme:ThemeData(useMaterial3:true,colorScheme:ColorScheme.fromSeed(seedColor:plum,brightness:Brightness.light),scaffoldBackgroundColor:cream,textTheme:GoogleFonts.arefRuqaaTextTheme(),iconTheme:const IconThemeData(color:plum),inputDecorationTheme:InputDecorationTheme(filled:true,fillColor:Colors.white,border:OutlineInputBorder(borderRadius:BorderRadius.all(Radius.circular(14)))),appBarTheme:const AppBarTheme(backgroundColor:plum,foregroundColor:Colors.white,elevation:0),cardTheme:CardThemeData(color:Colors.white,elevation:2,shape:RoundedRectangleBorder(borderRadius:BorderRadius.all(Radius.circular(18)))),filledButtonTheme:FilledButtonThemeData(style:FilledButton.styleFrom(backgroundColor:rose,foregroundColor:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14)))),floatingActionButtonTheme:const FloatingActionButtonThemeData(backgroundColor:teal,foregroundColor:Colors.white)),
    darkTheme:ThemeData(useMaterial3:true,brightness:Brightness.dark,colorScheme:ColorScheme.fromSeed(seedColor:rose,brightness:Brightness.dark),textTheme:GoogleFonts.arefRuqaaTextTheme(ThemeData.dark().textTheme)),
    themeMode:ThemeMode.system, home:const AdminHome());
}

class AdminHome extends StatefulWidget { const AdminHome({super.key}); @override State<AdminHome> createState()=>_AdminHomeState(); }
class _AdminHomeState extends State<AdminHome> {
  String section='members'; List<Map<String,dynamic>> rows=[]; List<Map<String,dynamic>> chatMembers=[]; bool busy=true; Timer? poll; final chatController=TextEditingController();
  @override void initState(){super.initState(); refresh(); loadChatMembers(); poll=Timer.periodic(const Duration(seconds:5),(_)=>refresh(silent:true));}
  @override void dispose(){poll?.cancel();chatController.dispose();super.dispose();}
  void note(String s)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));
  Future<void> loadChatMembers() async { try { chatMembers=await SharedStore.list('members'); if(mounted)setState((){}); } catch(_){} }
  Future<void> refresh({bool silent=false}) async {
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
    'bookings'=>{'customerName':'اسم العميل','phone':'رقم الهاتف','province':'المحافظة','district':'القضاء / المنطقة','neighborhood':'الحي / المكان','landmarkType':'نوع النقطة الدالة','landmark':'أقرب نقطة دالة بالتحديد','address':'العنوان الكامل','memberId':'العضو','date':'الموعد المطلوب','notes':'ملاحظات','status':'الحالة'},
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
    final bookingMembers=section=='bookings'?await SharedStore.list('members'):<Map<String,dynamic>>[];
    final bannerMembers=section=='banners'?await SharedStore.list('members'):<Map<String,dynamic>>[];
    String? linkedMemberId=old?['linkedMemberId']?.toString();
    String? selectedMemberId=old?['memberId']?.toString()??(bookingMembers.isNotEmpty?bookingMembers.first['id']?.toString():null);
    DateTime? bookingDate=DateTime.tryParse('${old?['date']??''}');
    bool available=old?['available']!=false, hasPlace=old == null || old['hasPlace']==true, active=old?['active']!=false;
    List<String> images=List<String>.from(old?['images']??[]);
    final result=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,ds)=>AlertDialog(
      title:Text(old==null?'إضافة ${sections[section]}':'تعديل ${sections[section]}'),
      content:SizedBox(width:460,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        ...fields.entries.where((e)=>!['available','hasPlace','memberId','date'].contains(e.key)).map((e)=>Padding(padding:const EdgeInsets.only(bottom:10),child:TextField(controller:ctrls[e.key],scrollPadding:const EdgeInsets.only(bottom:180),maxLines:['description','notes','text','address'].contains(e.key)?3:1,keyboardType:['age','hourlyPrice','nightlyPrice'].contains(e.key)?TextInputType.number:TextInputType.text,decoration:InputDecoration(labelText:e.value,border:const OutlineInputBorder())))),
        if(section=='bookings')...[
          DropdownButtonFormField<String>(value:bookingMembers.any((m)=>m['id']?.toString()==selectedMemberId)?selectedMemberId:null,decoration:const InputDecoration(labelText:'اختيار عضو الكادر',border:OutlineInputBorder()),items:bookingMembers.map((m)=>DropdownMenuItem<String>(value:m['id'].toString(),child:Row(children:[if((m['images'] as List? ?? []).isNotEmpty)ClipRRect(borderRadius:BorderRadius.circular(6),child:Image.memory(base64Decode((m['images'] as List).first),width:30,height:30,fit:BoxFit.cover)),const SizedBox(width:8),Text('${m['name']??'عضو'}')]))).toList(),onChanged:(v)=>ds(()=>selectedMemberId=v)),
          const SizedBox(height:10),
          OutlinedButton.icon(onPressed:()async{final d=await showDatePicker(context:ctx,initialDate:bookingDate??DateTime.now().add(const Duration(days:1)),firstDate:DateTime.now(),lastDate:DateTime.now().add(const Duration(days:365)));if(d!=null)ds(()=>bookingDate=DateTime(d.year,d.month,d.day,bookingDate?.hour??12,bookingDate?.minute??0));},icon:const Icon(Icons.calendar_month),label:Text(bookingDate==null?'تحديد تاريخ الحجز':'${bookingDate!.year}/${bookingDate!.month}/${bookingDate!.day}')),
          OutlinedButton.icon(onPressed:()async{final t=await showTimePicker(context:ctx,initialTime:TimeOfDay.fromDateTime(bookingDate??DateTime.now()));if(t!=null)ds(()=>bookingDate=DateTime(bookingDate?.year??DateTime.now().year,bookingDate?.month??DateTime.now().month,bookingDate?.day??DateTime.now().day,t.hour,t.minute));},icon:const Icon(Icons.schedule),label:Text(bookingDate==null?'تحديد وقت الحجز':TimeOfDay.fromDateTime(bookingDate!).format(ctx))),
          if(bookingMembers.isEmpty)const Text('أضف أعضاء الكادر أولاً لتتمكن من ربط الحجز بعضو.'),
        ],
        if(section=='members')...[
          SwitchListTile(value:hasPlace,onChanged:(v)=>ds(()=>hasPlace=v),title:const Text('يوجد مكان')),
          SwitchListTile(value:available,onChanged:(v)=>ds(()=>available=v),title:const Text('متاح للحجز')),
        ],
        if(section=='banners')SwitchListTile(value:active,onChanged:(v)=>ds(()=>active=v),title:const Text('عرض البانر للعملاء')),
        if(section=='banners')...[
          DropdownButtonFormField<String>(value:bannerMembers.any((m)=>m['id']?.toString()==linkedMemberId)?linkedMemberId:'',decoration:const InputDecoration(labelText:'ربط البانر بملف عضو (اختياري)'),items:[const DropdownMenuItem<String>(value:'',child:Text('بدون ربط')), ...bannerMembers.map((m)=>DropdownMenuItem<String>(value:m['id'].toString(),child:Text('${m['name']??'عضو'}')))],onChanged:(v)=>ds(()=>linkedMemberId=v)),
          const SizedBox(height:8),
        ],
        if(['members','sessions','banners','announcements'].contains(section))...[
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
      for(final key in fields.keys){if(key=='available'||key=='hasPlace')continue;if(section=='bookings'&&key=='memberId'){data[key]=selectedMemberId;continue;}if(section=='bookings'&&key=='date'){data[key]=bookingDate?.toIso8601String()??'';continue;}final v=ctrls[key]!.text.trim();data[key]=key=='age'?int.tryParse(v)??0:(key=='hourlyPrice'||key=='nightlyPrice')?double.tryParse(v)??0:v;}
      if(section=='bookings'){final chosen=bookingMembers.where((m)=>m['id']?.toString()==selectedMemberId).toList();data['memberName']=chosen.isEmpty?'':chosen.first['name'];}
      if(section=='members'){data['available']=available;data['hasPlace']=hasPlace;}
      if(section=='banners')data['active']=active;
      if(['members','sessions','banners','announcements'].contains(section))data['images']=images;
      if(section=='banners'){data['linkedMemberId']=(linkedMemberId==null||linkedMemberId!.isEmpty)?null:linkedMemberId;data['targetType']=(linkedMemberId==null||linkedMemberId!.isEmpty)?'none':'member';data['targetId']=data['linkedMemberId'];}
      if(section=='announcements'){data['createdAt']=DateTime.now().toIso8601String();}
      if(section=='bookings'&&(selectedMemberId==null||bookingDate==null)){note('اختر عضو الكادر وحدد تاريخ ووقت الحجز');}else try{await SharedStore.save(section,data);if(section=='announcements'){await SharedStore.save('notifications',{'target':'all','type':'announcement','title':data['title']??'إعلان جديد','body':data['body']??'','createdAt':DateTime.now().toIso8601String(),'read':false});}await refresh();note('تم الحفظ بنجاح');}catch(e){note('فشل الحفظ: $e');}
    }
    for(final c in ctrls.values){c.dispose();}
  }
  Future<void> remove(Map<String,dynamic> item) async {
    final yes=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('حذف السجل؟'),content:const Text('لا يمكن التراجع عن الحذف.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('حذف'))]));
    if(yes==true){await SharedStore.delete(section,item['id']);await refresh();}
  }
  Future<void> updateBooking(Map<String,dynamic> b,String status)async{if((b['status']??'قيد المراجعة')!=status){final d={...b,'status':status};await SharedStore.save('bookings',d);await SharedStore.save('notifications',{'target':'customer','type':'booking','title':'تحديث طلب الحجز','body':'تم تحديث حالة حجز ${b['memberName']??''} إلى $status','createdAt':DateTime.now().toIso8601String(),'read':false,'bookingId':b['id']});}await refresh();}
  Widget recordCard(Map<String,dynamic> m){
    final title=m['name']??m['title']??m['customerName']??m['sender']??'سجل';
    final subtitle=[m['description'],m['date'],m['status'],if(section=='bookings'&&m['address']!=null)m['address'],if(section=='members')'${m['hourlyPrice']??0} د.ع/ساعة',if(section=='members')'${m['nightlyPrice']??0} د.ع/ليلة'].where((x)=>x!=null&&x.toString().isNotEmpty).join(' • ');
    final imgs=List<String>.from(m['images']??[]);
    return Card(child:Padding(padding:const EdgeInsets.all(8),child:Column(children:[
      ListTile(leading:imgs.isNotEmpty?ClipRRect(borderRadius:BorderRadius.circular(8),child:Image.memory(base64Decode(imgs.first),width:52,height:52,fit:BoxFit.cover)):const CircleAvatar(child:Icon(Icons.spa)),title:Text('$title'),subtitle:Text(subtitle),trailing:PopupMenuButton<String>(onSelected:(v){if(v=='edit')edit(m);else if(v=='delete')remove(m);else if(v=='accept')updateBooking(m,'مؤكد');else updateBooking(m,'مرفوض');},itemBuilder:(_)=>[
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
    final chosen=await showModalBottomSheet<Map<String,dynamic>>(context:context,isScrollControlled:true,builder:(ctx)=>Directionality(textDirection:TextDirection.rtl,child:SafeArea(child:ListView(shrinkWrap:true,children:[const Padding(padding:EdgeInsets.all(16),child:Text('اختر ملف العضو لإرساله للعميل',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold))),...chatMembers.map((m){final imgs=List<String>.from(m['images']??[]);Widget avatar=const CircleAvatar(child:Icon(Icons.spa));if(imgs.isNotEmpty){try{avatar=ClipRRect(borderRadius:BorderRadius.circular(9),child:Image.memory(base64Decode(imgs.first),width:48,height:48,fit:BoxFit.cover));}catch(_){}}return ListTile(leading:avatar,title:Text('${m['name']??'عضو'}'),subtitle:const Text('إرسال بطاقة الملف الشخصي'),onTap:()=>Navigator.pop(ctx,m));})]))));
    if(chosen==null)return;
    await SharedStore.save('messages',{'conversationId':'customer-main','sender':'الإدارة','type':'memberProfile','memberId':chosen['id'],'memberName':chosen['name'],'text':'ملف العضو: ${chosen['name']}','createdAt':DateTime.now().toIso8601String()});
    await SharedStore.save('notifications',{'target':'customer','type':'message','title':'رسالة جديدة من الإدارة','body':'تم إرسال ملف العضو ${chosen['name']}','createdAt':DateTime.now().toIso8601String(),'read':false});
    await refresh(silent:true);note('تم إرسال ملف العضو للعميل');
  }
  Map<String,dynamic>? findChatMember(dynamic id){for(final member in chatMembers){if(member['id']==id)return member;}return null;}
  void openSharedMember(Map<String,dynamic> member){showDialog(context:context,builder:(ctx)=>Directionality(textDirection:TextDirection.rtl,child:AlertDialog(title:Text('${member['name']??'ملف العضو'}'),content:SizedBox(width:360,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[if((member['images'] as List? ?? []).isNotEmpty)ClipRRect(borderRadius:BorderRadius.circular(14),child:Image.memory(base64Decode((member['images'] as List).first),height:180,fit:BoxFit.cover)),ListTile(title:const Text('العمر'),subtitle:Text('${member['age']??'-'}')),ListTile(title:const Text('سعر الساعة'),subtitle:Text('${member['hourlyPrice']??0} د.ع')),ListTile(title:const Text('سعر الليلة'),subtitle:Text('${member['nightlyPrice']??0} د.ع')),if((member['description']??'').toString().isNotEmpty)Text('${member['description']}')]))),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إغلاق'))])));}
  Widget adminMessageBubble(Map<String,dynamic> m){
    final mine=m['sender']=='الإدارة';
    final member=m['type']=='memberProfile'?findChatMember(m['memberId']):null;
    Widget? profile;
    if(member!=null){final imgs=List<String>.from(member['images']??[]);Widget avatar=const CircleAvatar(child:Icon(Icons.spa));if(imgs.isNotEmpty){try{avatar=ClipRRect(borderRadius:BorderRadius.circular(10),child:Image.memory(base64Decode(imgs.first),width:58,height:58,fit:BoxFit.cover));}catch(_){}}profile=Card(color:Colors.white,child:Padding(padding:const EdgeInsets.all(8),child:Row(children:[avatar,const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${member['name']??'ملف العضو'}',style:const TextStyle(fontWeight:FontWeight.bold)),const Text('بطاقة ملف العضو') ])),const Icon(Icons.badge_outlined,color:rose)])));}
    return Align(alignment:mine?Alignment.centerLeft:Alignment.centerRight,child:Container(constraints:const BoxConstraints(maxWidth:330),margin:const EdgeInsets.symmetric(vertical:6),padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:mine?teal.withOpacity(.12):rose.withOpacity(.13),borderRadius:BorderRadius.circular(18)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${m['sender']??'عميل'}',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:12,color:plum)),if(profile!=null)InkWell(onTap:()=>openSharedMember(member!),child:profile!),if(m['type']!='memberProfile'||profile==null)Text('${m['text']??'تعذر العثور على ملف العضو'}'),Text('${m['createdAt']??''}',style:const TextStyle(fontSize:10,color:Colors.grey))])));
  }
  Future<void> sendAdminMessage() async {
    final value=chatController.text.trim();
    if(value.isEmpty)return;
    try {
      await SharedStore.save('messages', {'conversationId':'customer-main','sender':'الإدارة','type':'text','text':value,'createdAt':DateTime.now().toIso8601String()});
      await SharedStore.save('notifications',{'target':'customer','type':'message','title':'رسالة جديدة من الإدارة','body':value,'createdAt':DateTime.now().toIso8601String(),'read':false});
      chatController.clear();
      await refresh(silent:true);
    } catch(e) { note('تعذر إرسال الرد: $e'); }
  }
  Widget adminChat() {
    final messages=[...rows]..sort((a,b)=>('${a['createdAt']??''}').compareTo('${b['createdAt']??''}'));
    return Column(children:[
      const ListTile(leading:CircleAvatar(child:Icon(Icons.support_agent)),title:Text('محادثة العميل'),subtitle:Text('الرسائل والردود تظهر هنا تلقائياً')),
      Expanded(child:messages.isEmpty?const Center(child:Text('لا توجد رسائل بعد')):ListView.builder(padding:const EdgeInsets.all(12),itemCount:messages.length,itemBuilder:(context,index){
        final m=messages[index]; return adminMessageBubble(m);
      })),
      SafeArea(child:Padding(padding:const EdgeInsets.all(8),child:Row(children:[IconButton(tooltip:'إرسال ملف عضو',onPressed:shareMemberProfile,icon:const Icon(Icons.person_add_alt_1,color:rose)),Expanded(child:TextField(controller:chatController,minLines:1,maxLines:4,scrollPadding:const EdgeInsets.only(bottom:180),decoration:const InputDecoration(hintText:'اكتب رد الإدارة...',border:OutlineInputBorder()),onSubmitted:(_)=>sendAdminMessage())),IconButton(onPressed:sendAdminMessage,icon:const Icon(Icons.send,color:plum))]))),
    ]);
  }
  @override Widget build(BuildContext context)=>Directionality(textDirection:TextDirection.rtl,child:Scaffold(
    appBar:AppBar(title:const Text('الشيخة | الإدارة'),actions:[IconButton(onPressed:()=>refresh(),icon:const Icon(Icons.refresh))]),
    floatingActionButton:section=='messages'?null:FloatingActionButton.extended(backgroundColor:rose,foregroundColor:Colors.white,onPressed:()=>edit(),icon:const Icon(Icons.add_circle_rounded,color:Colors.white),label:const Text('إضافة سجل')),
    resizeToAvoidBottomInset:true,
    body:Column(children:[
      SizedBox(height:58,child:ListView(scrollDirection:Axis.horizontal,padding:const EdgeInsets.symmetric(horizontal:8),children:sections.entries.map((e)=>Padding(padding:const EdgeInsets.all(4),child:ChoiceChip(avatar:Icon(sectionIcons[e.key],size:18,color:section==e.key?Colors.white:sectionColors[e.key]),label:Text(e.value,style:TextStyle(color:section==e.key?Colors.white:sectionColors[e.key],fontWeight:FontWeight.bold)),selected:section==e.key,selectedColor:sectionColors[e.key],backgroundColor:Colors.white,side:BorderSide(color:sectionColors[e.key]!.withOpacity(.35)),shape:const StadiumBorder(),onSelected:(_){setState(()=>section=e.key);refresh();}))).toList())),
      Expanded(child:section=='messages'?adminChat():busy?const Center(child:CircularProgressIndicator()):RefreshIndicator(onRefresh:refresh,child:ListView(padding:const EdgeInsets.all(14),children:[
        Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(gradient:const LinearGradient(colors:[plum,rose,teal]),borderRadius:BorderRadius.circular(22)),child:Text('${sections[section]}\n${rows.length} سجل',style:const TextStyle(color:Colors.white,fontSize:22,fontWeight:FontWeight.bold))),
        if(section=='banners'&&rows.length>=7)const Padding(padding:EdgeInsets.all(8),child:Text('وصلت إلى الحد الأقصى: 7 بانرات.')),
        if(rows.isEmpty)const Card(child:Padding(padding:EdgeInsets.all(20),child:Text('لا توجد بيانات بعد. استخدم زر الإضافة للبدء.'))),
        ...rows.map(recordCard),const SizedBox(height:90)
      ])))
    ])
  ));
}
