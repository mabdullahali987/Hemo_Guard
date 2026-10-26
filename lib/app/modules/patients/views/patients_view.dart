import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hemo_guard/app/theme/app_theme.dart';
import 'package:hemo_guard/app/services/auth_service.dart';
import 'package:hemo_guard/app/data/hemoguard_pdf_generator.dart';

/// Account-isolated patient directory. Every server lookup checks ownership.
class PatientsView extends StatefulWidget {
  const PatientsView({super.key});
  @override State<PatientsView> createState()=>_PatientsViewState();
}
class _PatientsViewState extends State<PatientsView> {
  final search=TextEditingController();
  late Future<Map<String,dynamic>> result;
  @override void initState(){super.initState();_refresh();}
  @override void dispose(){search.dispose();super.dispose();}
  void _refresh(){result=Get.find<AuthService>().api('GET','/api/patients?search=${Uri.encodeQueryComponent(search.text)}');if(mounted)setState((){});}
  @override Widget build(BuildContext context)=>Scaffold(
    backgroundColor:AppColors.background,
    appBar:AppBar(title:const Text('Patient Reports'),actions:[IconButton(icon:const Icon(Icons.refresh),onPressed:_refresh)]),
    body:SafeArea(child:Column(children:[
      Padding(padding:const EdgeInsets.all(16),child:TextField(controller:search,onSubmitted:(_)=>_refresh(),
        textInputAction:TextInputAction.search,decoration:InputDecoration(prefixIcon:const Icon(Icons.search),
          hintText:'Search patient name or HG-P ID',suffixIcon:IconButton(icon:const Icon(Icons.arrow_forward),onPressed:_refresh)))),
      Expanded(child:FutureBuilder<Map<String,dynamic>>(future:result,builder:(context,snapshot){
        if(!snapshot.hasData){if(snapshot.hasError)return Center(child:Text('Could not load patient history: ${snapshot.error}'));return const Center(child:CircularProgressIndicator());}
        final patients=(snapshot.data!['patients'] as List).cast<Map<String,dynamic>>();
        if(patients.isEmpty)return const Center(child:Text('No patient reports yet. Scan a CBC report to begin.'));
        return ListView.builder(padding:const EdgeInsets.fromLTRB(16,0,16,22),itemCount:patients.length,itemBuilder:(context,i){
          final p=patients[i];return Padding(padding:const EdgeInsets.only(bottom:12),child:_GlassPatientCard(
            child:ListTile(contentPadding:const EdgeInsets.symmetric(horizontal:18,vertical:9),
              leading:const CircleAvatar(backgroundColor:AppColors.positiveBg,child:Icon(Icons.person_outline,color:AppColors.brandDark)),
              title:Text(p['name']?.toString()??'',style:const TextStyle(fontWeight:FontWeight.w800)),
              subtitle:Text('${p['public_id']}\n${p['reports_count']} saved screenings'),isThreeLine:true,
              trailing:const Icon(Icons.chevron_right,color:AppColors.brandDark),
              onTap:()=>Get.to(()=>PatientHistoryView(patient:p)))));
        });
      }))
    ])));
}
class _GlassPatientCard extends StatelessWidget {
  const _GlassPatientCard({required this.child});final Widget child;
  @override Widget build(BuildContext context)=>ClipRRect(borderRadius:BorderRadius.circular(21),
    child:BackdropFilter(filter:ImageFilter.blur(sigmaX:16,sigmaY:16),
      child:Container(decoration:BoxDecoration(
        color:Colors.white.withValues(alpha:.78),borderRadius:BorderRadius.circular(21),
        border:Border.all(color:Colors.white.withValues(alpha:.85))),child:child)));
}
class PatientHistoryView extends StatefulWidget {
  const PatientHistoryView({super.key,required this.patient});final Map<String,dynamic> patient;
  @override State<PatientHistoryView> createState()=>_PatientHistoryViewState();
}
class _PatientHistoryViewState extends State<PatientHistoryView> {
  late Future<Map<String,dynamic>> history;
  @override void initState(){super.initState();_load();}
  void _load(){history=Get.find<AuthService>().api('GET','/api/patients/${Uri.encodeComponent(widget.patient['id'].toString())}/reports');if(mounted)setState((){});}
  @override Widget build(BuildContext context)=>Scaffold(backgroundColor:AppColors.background,
    appBar:AppBar(title:Text(widget.patient['name']?.toString()??'Patient History'),actions:[IconButton(onPressed:_load,icon:const Icon(Icons.refresh))]),
    body:FutureBuilder<Map<String,dynamic>>(future:history,builder:(context,snap){
      if(!snap.hasData){if(snap.hasError)return Center(child:Text('Could not load reports: ${snap.error}'));return const Center(child:CircularProgressIndicator());}
      final reports=(snap.data!['reports'] as List).cast<Map<String,dynamic>>();
      return ListView(padding:const EdgeInsets.all(16),children:[
        _GlassPatientCard(child:Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(widget.patient['name']?.toString()??'',style:const TextStyle(fontSize:21,fontWeight:FontWeight.w800)),
          const SizedBox(height:5),Text(widget.patient['public_id']?.toString()??'',style:const TextStyle(color:AppColors.brandDark,fontWeight:FontWeight.w700)),
          const SizedBox(height:5),Text('${reports.length} recent saved reports',style:const TextStyle(color:AppColors.muted)),
        ]))),const SizedBox(height:14),
        if(reports.isEmpty)const Center(child:Text('No tests yet')),
        for(final report in reports)...[
          _GlassPatientCard(child:ListTile(
            leading:const Icon(Icons.description_outlined,color:AppColors.brandDark),
            title:Text(report['sample_date']?.toString()??report['created_at']?.toString().split('T').first??'',style:const TextStyle(fontWeight:FontWeight.w700)),
            subtitle:Text('${(report['cbc'] as Map)['hemoglobin']} g/dL Hb · ${(report['cbc'] as Map)['mcv']} fL MCV\n${report['prediction']['is_thalassemia']==true?'Indicators detected':'No indicators detected'}'),
            isThreeLine:true,trailing:const Icon(Icons.open_in_new),
            onTap:()=>_showReport(context,report))),const SizedBox(height:12),
        ],
      ]);
    }));
  Future<void> _showReport(BuildContext context,Map<String,dynamic> report) async {
    final cbc=Map<String,dynamic>.from(report['cbc'] as Map);
    final model=Map<String,dynamic>.from(report['prediction'] as Map);
    await showModalBottomSheet<void>(context:context,isScrollControlled:true,useSafeArea:true,
      backgroundColor:Colors.transparent,builder:(context)=>Padding(padding:const EdgeInsets.all(13),
        child:_GlassPatientCard(child:SingleChildScrollView(padding:const EdgeInsets.all(22),child:Column(
          mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('Clinical screening report',style:TextStyle(fontSize:19,fontWeight:FontWeight.w800)),const SizedBox(height:8),
          Text('Patient: ${widget.patient['name']}  ·  ${widget.patient['public_id']}'),
          Text('Recorded: ${report['created_at']}'),
          const Divider(),for(final e in cbc.entries)Padding(padding:const EdgeInsets.symmetric(vertical:3),child:Text('${e.key.replaceAll('_',' ').toUpperCase()}: ${e.value}')),
          const Divider(),Text(model['is_thalassemia']==true?'Thalassemia indicators detected':'No thalassemia indicators',style:const TextStyle(fontWeight:FontWeight.w700)),
          Text('Consent: operator attestation • ${report['consent_id']}'),
          const SizedBox(height:12),SizedBox(width:double.infinity,child:ElevatedButton.icon(
            icon:const Icon(Icons.picture_as_pdf_outlined),label:const Text('Save PDF'),onPressed:() async {
              try {final f=await HemoGuardPdfGenerator.generate(report,patientPublicId:widget.patient['public_id']?.toString());
                if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('PDF saved to ${f.path}')));
              } catch(e){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('PDF failed: $e')));}
            })),
          const SizedBox(height:12),const Text('Screening aid only — not a diagnosis.',style:TextStyle(fontSize:11,color:AppColors.muted)),
        ])))));
  }
}
