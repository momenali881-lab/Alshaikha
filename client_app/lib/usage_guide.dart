import 'package:flutter/material.dart';

class UsageGuideStep {
  final GlobalKey targetKey;
  final String title;
  final String description;
  final IconData icon;
  const UsageGuideStep({required this.targetKey,required this.title,required this.description,required this.icon});
}

class UsageGuide {
  static void show(BuildContext context,List<UsageGuideStep> steps) {
    if(steps.isEmpty)return;
    final overlay=Overlay.of(context);
    var index=0;
    late OverlayEntry entry;
    void close()=>entry.remove();
    entry=OverlayEntry(builder:(overlayContext){
      final size=MediaQuery.sizeOf(overlayContext);
      final targetContext=steps[index].targetKey.currentContext;
      Rect? target;
      if(targetContext!=null){
        final render=targetContext.findRenderObject();
        if(render is RenderBox&&render.hasSize)target=render.localToGlobal(Offset.zero)&render.size;
      }
      final cardTop=target==null?size.height*.30:(target.center.dy>size.height*.52?86.0:size.height-226.0);
      return Positioned.fill(child:Material(color:Colors.transparent,child:Stack(children:[
        CustomPaint(size:size,painter:_GuidePainter(target)),
        Positioned(left:18,right:18,top:cardTop.clamp(70.0,size.height-205.0).toDouble(),child:Material(
          color:Colors.white,elevation:16,borderRadius:BorderRadius.circular(22),
          child:Directionality(textDirection:TextDirection.rtl,child:Padding(padding:const EdgeInsets.all(17),child:Column(
            mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
              Row(children:[Icon(steps[index].icon,color:const Color(0xFFE91E63),size:25),const SizedBox(width:9),Expanded(child:Text(steps[index].title,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900,color:Color(0xFF54205F)))),Text('${index+1}/${steps.length}',style:const TextStyle(color:Colors.black54,fontWeight:FontWeight.bold))]),
              const SizedBox(height:9),Text(steps[index].description,style:const TextStyle(fontSize:14,height:1.6,color:Colors.black87)),
              const SizedBox(height:15),Row(children:[
                TextButton(onPressed:close,child:const Text('إنهاء الدليل')),
                const Spacer(),
                if(index>0)TextButton(onPressed:(){index--;entry.markNeedsBuild();},child:const Text('السابق')),
                FilledButton(onPressed:(){if(index<steps.length-1){index++;entry.markNeedsBuild();}else{close();}},style:FilledButton.styleFrom(backgroundColor:const Color(0xFFE91E63)),child:Text(index==steps.length-1?'تم':'التالي'))
              ])
            ]))),
        ))
      ])));
    });
    overlay.insert(entry);
  }
}

class _GuidePainter extends CustomPainter {
  final Rect? target;
  const _GuidePainter(this.target);
  @override void paint(Canvas canvas,Size size){
    final full=Path()..addRect(Offset.zero&size);
    final hole=target==null?Path():Path()..addRRect(RRect.fromRectAndRadius(target!.inflate(8),const Radius.circular(16)));
    final shade=Path.combine(PathOperation.difference,full,hole);
    canvas.drawPath(shade,Paint()..color=Colors.black.withOpacity(.76));
    if(target!=null)canvas.drawRRect(RRect.fromRectAndRadius(target!.inflate(8),const Radius.circular(16)),Paint()..color=const Color(0xFFFF8DB8)..style=PaintingStyle.stroke..strokeWidth=3);
  }
  @override bool shouldRepaint(covariant _GuidePainter old)=>old.target!=target;
}
