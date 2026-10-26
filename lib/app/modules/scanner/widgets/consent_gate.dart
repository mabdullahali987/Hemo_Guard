import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hemo_guard/app/theme/app_theme.dart';
import '../controllers/scanner_controller.dart';

/// Shown before camera/gallery/OCR or manual values become usable.
class ConsentGate extends StatefulWidget {
  const ConsentGate({super.key,required this.controller});
  final ScannerController controller;
  @override State<ConsentGate> createState()=>_ConsentGateState();
}
class _ConsentGateState extends State<ConsentGate> {
  bool agreed=false;
  @override
  Widget build(BuildContext context) => Center(child:SingleChildScrollView(padding:const EdgeInsets.all(20),
    child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:510),
      child:ClipRRect(borderRadius:BorderRadius.circular(27),child:BackdropFilter(filter:ImageFilter.blur(sigmaX:22,sigmaY:22),
      child:Container(padding:const EdgeInsets.all(24),decoration:BoxDecoration(
        color:Colors.white.withValues(alpha:.87),border:Border.all(color:Colors.white.withValues(alpha:.85)),
        borderRadius:BorderRadius.circular(27),boxShadow:[BoxShadow(color:AppColors.brandDark.withValues(alpha:.1),blurRadius:22)]),
        child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Icon(Icons.shield_outlined,size:36,color:AppColors.brandDark),const SizedBox(height:12),
          const Text('Patient consent',style:TextStyle(fontSize:24,fontWeight:FontWeight.w800)),
          const SizedBox(height:7),
          const Text('Confirm permission before scanning a CBC report or entering patient medical data.',
            style:TextStyle(color:AppColors.muted)),const SizedBox(height:17),
          if(widget.controller.consentLoading.value)const LinearProgressIndicator(),
          if(!widget.controller.consentLoading.value && widget.controller.consentVersion.value.isEmpty)
            TextButton.icon(onPressed:widget.controller.retryConsent,
              icon:const Icon(Icons.refresh),label:const Text('Retry loading consent')),
          Text(widget.controller.consentText.value.isEmpty?'Loading consent information…':widget.controller.consentText.value,
            style:const TextStyle(height:1.5,fontSize:13)),const SizedBox(height:12),
          CheckboxListTile(value:agreed,contentPadding:EdgeInsets.zero,controlAffinity:ListTileControlAffinity.leading,
            title:const Text('I confirm that the patient or authorized representative has agreed.',style:TextStyle(fontSize:13,fontWeight:FontWeight.w600)),
            subtitle:const Text('Operator attestation only — not a patient signature.',style:TextStyle(fontSize:11)),
            onChanged:(v)=>setState(()=>agreed=v??false)),
          const SizedBox(height:12),SizedBox(width:double.infinity,child:ElevatedButton.icon(
            onPressed:agreed && !widget.controller.consentLoading.value && widget.controller.consentVersion.value.isNotEmpty
              ? widget.controller.confirmConsent : null,
            icon:const Icon(Icons.arrow_forward_rounded),label:const Text('Agree & continue'))),
        ])))))));
}
