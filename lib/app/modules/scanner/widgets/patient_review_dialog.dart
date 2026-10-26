import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hemo_guard/app/theme/app_theme.dart';

/// Always review extracted fields, including when OCR found all demographics.
/// Values are not stored until the operator confirms this draft.
class PatientReviewDialog extends StatefulWidget {
  const PatientReviewDialog({super.key, required this.initial});
  final Map<String, String> initial;
  @override
  State<PatientReviewDialog> createState() => _PatientReviewDialogState();
}
class _PatientReviewDialogState extends State<PatientReviewDialog> {
  late final Map<String,TextEditingController> fields;
  late String sex;
  final form=GlobalKey<FormState>();
  @override
  void initState() {
    super.initState();
    fields={for(final k in ['name','age_at_test','public_id','lab_patient_number','source_report_number','sample_date'])
      k:TextEditingController(text:widget.initial[k] ?? '')};
    sex=widget.initial['sex'] ?? 'unknown';
  }
  @override
  void dispose(){for(final c in fields.values){c.dispose();} super.dispose();}
  Widget entry(String key,String label,{bool required=false,TextInputType? keyboard}) {
    final missing=(widget.initial[key] ?? '').trim().isEmpty;
    return Padding(padding:const EdgeInsets.only(bottom:12),child:TextFormField(
      controller:fields[key],keyboardType:keyboard,
      validator:(v){final value=(v??'').trim(); if(required && value.length<2)return 'Please enter the patient name';
        if(key=='age_at_test' && value.isNotEmpty && (int.tryParse(value)==null || int.parse(value)<0 || int.parse(value)>125))return 'Age must be 0–125';
        if(key=='sample_date' && value.isNotEmpty && !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value))return 'Use YYYY-MM-DD';
        return null;},
      decoration:InputDecoration(labelText:label,
        helperText:missing?'Not detected — enter manually if available':'Detected by OCR — editable',
        helperStyle:TextStyle(color:missing?AppColors.warn:AppColors.brandDark,fontSize:11),
        prefixIcon:Icon(missing?Icons.edit_note_rounded:Icons.verified_outlined,color:missing?AppColors.warn:AppColors.brandDark),
      )));
  }
  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor:Colors.transparent,insetPadding:const EdgeInsets.all(15),
    child:ClipRRect(borderRadius:BorderRadius.circular(25),
      child:BackdropFilter(filter:ImageFilter.blur(sigmaX:20,sigmaY:20),
        child:Container(constraints:const BoxConstraints(maxWidth:510,maxHeight:720),
          decoration:BoxDecoration(color:Colors.white.withValues(alpha:.90),borderRadius:BorderRadius.circular(25),
          border:Border.all(color:Colors.white.withValues(alpha:.9),width:1.3)),
          child:Column(mainAxisSize:MainAxisSize.min,children:[
            Padding(padding:const EdgeInsets.fromLTRB(20,20,20,10),child:Row(children:[
              const Icon(Icons.manage_accounts_outlined,color:AppColors.brandDark,size:29),const SizedBox(width:10),
              const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text('Review patient details',style:TextStyle(fontWeight:FontWeight.w800,fontSize:19)),
                Text('Correct OCR values before submitting',style:TextStyle(color:AppColors.muted,fontSize:12))])),
              IconButton(onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.close))])),
            Flexible(child:SingleChildScrollView(padding:const EdgeInsets.symmetric(horizontal:20),child:Form(key:form,child:Column(children:[
              entry('name','Patient name *',required:true),
              entry('age_at_test','Age at this test (years)',keyboard:TextInputType.number),
              DropdownButtonFormField<String>(value:sex,decoration:const InputDecoration(labelText:'Sex'),
                items:const [DropdownMenuItem(value:'unknown',child:Text('Not recorded')),
                  DropdownMenuItem(value:'male',child:Text('Male')),DropdownMenuItem(value:'female',child:Text('Female')),
                  DropdownMenuItem(value:'other',child:Text('Other'))],onChanged:(v)=>setState(()=>sex=v??'unknown')),
              const SizedBox(height:12),entry('public_id','Existing HemoGuard ID (if printed)'),
              entry('lab_patient_number','Laboratory patient number (if stable)'),
              entry('source_report_number','Source CBC report / sample number'),
              entry('sample_date','Sample date (YYYY-MM-DD)'),
              const SizedBox(height:4),
              const Text('CBC values remain editable on the scanner screen. No patient record is created until you confirm.',
                style:TextStyle(color:AppColors.muted,fontSize:12)),const SizedBox(height:12),
            ])))),
            Padding(padding:const EdgeInsets.all(16),child:SizedBox(width:double.infinity,child:ElevatedButton.icon(
              icon:const Icon(Icons.arrow_forward),label:const Text('Confirm and check patient'),
              onPressed:(){if(!(form.currentState?.validate()??false))return;
                Navigator.pop(context,{for(final e in fields.entries)e.key:e.value.text.trim(),'sex':sex});}))),
          ])))));
}
