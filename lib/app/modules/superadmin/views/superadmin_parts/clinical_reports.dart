part of '../superadmin_view.dart';

/// Restricted cross-account clinical reports. Kept separate from existing
/// report-usage cards, navigation dock, subscriptions and account management.
class _AdminClinicalReportsPage extends StatefulWidget {
  const _AdminClinicalReportsPage();
  @override State<_AdminClinicalReportsPage> createState()=>_AdminClinicalReportsPageState();
}
class _AdminClinicalReportsPageState extends State<_AdminClinicalReportsPage> {
  final auth=Get.find<AuthService>();
  late Future<Map<String,dynamic>> reportsFuture;
  int offset=0;
  @override void initState(){super.initState();_load();}
  void _load(){reportsFuture=auth.api('GET','/api/admin/clinical-reports?limit=100&offset=$offset');if(mounted)setState((){});}
  @override Widget build(BuildContext context)=>_AdminCanvas(child:Scaffold(
    backgroundColor:Colors.transparent,
    appBar:AppBar(title:const Text('All Patient Reports'),backgroundColor:Colors.transparent,
      foregroundColor:_AdminColors.ink,actions:[IconButton(tooltip:'Export all data as CSV',onPressed:_exportCsv,icon:const Icon(Icons.table_view_outlined)),IconButton(onPressed:_load,icon:const Icon(Icons.refresh))]),
    body:FutureBuilder<Map<String,dynamic>>(future:reportsFuture,builder:(context,snapshot){
      if(!snapshot.hasData){if(snapshot.hasError)return Center(child:Text('Cannot load reports: ${snapshot.error}'));return const Center(child:CircularProgressIndicator());}
      final list=(snapshot.data!['reports'] as List).cast<Map<String,dynamic>>();
      final total=(snapshot.data!['total'] as num?)?.toInt()??0;
      return ListView(padding:const EdgeInsets.all(17),children:[
        _FrostedPanel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('$total patient-linked reports',style:TextStyle(color:_AdminColors.ink,fontSize:23,fontWeight:FontWeight.w800)),
          Text('Cross-account clinical record access is audited.',style:TextStyle(color:_AdminColors.muted,fontSize:12)),
        ])),const SizedBox(height:15),
        for(final r in list)...[
          _FrostedPanel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(r['patient_name_snapshot']?.toString()??'',style:TextStyle(color:_AdminColors.ink,fontSize:16,fontWeight:FontWeight.w800)),
            const SizedBox(height:4),Text(r['public_id']?.toString()??'',style:TextStyle(color:_AdminColors.muted)),
            const SizedBox(height:8),Text('Origin: ${r['account_name_snapshot']}  •  ${r['account_type_snapshot']}',style:TextStyle(color:_AdminColors.ink)),
            Text('Completed: ${r['created_at']}',style:TextStyle(color:_AdminColors.muted,fontSize:11)),
            const SizedBox(height:8),_GlassAction(label:'View patient report',icon:Icons.open_in_new,
              color:_AdminColors.violet,onTap:()=>_showDetail(r['id'].toString())),
          ])),const SizedBox(height:12),
        ],
        if(list.isEmpty)const _FrostedPanel(child:Text('No patient-linked reports yet.')),
        Row(children:[if(offset>0)TextButton(onPressed:(){offset=(offset-100).clamp(0,100000000);_load();},child:const Text('← Newer')),
          const Spacer(),if(offset+list.length<total)TextButton(onPressed:(){offset+=100;_load();},child:const Text('Older →'))]),
      ]);
    }),
  ));
  Future<void> _exportCsv() async {
    try {
      final path=await auth.downloadAdminFile('/api/admin/clinical-reports.csv','HemoGuard-Clinical-Reports.csv');
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('CSV saved to: $path')));
    } catch(e) {
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('CSV export failed: $e')));
    }
  }
  Future<void> _downloadEvidence(Map<String,dynamic> file) async {
    try {
      final name='${file['kind']}_${file['id']}.${file['mime_type']=='application/pdf'?'pdf':(file['mime_type']?.toString().split('/').last??'bin')}';
      final path=await auth.downloadAdminFile('/api/admin/clinical-attachments/${Uri.encodeComponent(file['id'].toString())}/download',name);
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Document saved to: $path')));
    } catch(e) {
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Document download failed: $e')));
    }
  }

  Future<void> _showDetail(String id) async {
    try {
      final detail=await auth.api('GET','/api/admin/clinical-reports/${Uri.encodeComponent(id)}');
      if(!mounted)return;
      final report=Map<String,dynamic>.from(detail['report'] as Map);
      final cbc=Map<String,dynamic>.from(report['cbc'] as Map);
      final prediction=Map<String,dynamic>.from(report['prediction'] as Map);
      final files=(detail['attachments'] as List? ?? [])
        .map((d)=>Map<String,dynamic>.from(d as Map)).toList();
      await showModalBottomSheet<void>(context:context,useSafeArea:true,isScrollControlled:true,
        backgroundColor:Colors.transparent,builder:(ctx)=>Padding(padding:const EdgeInsets.all(12),
          child:_FrostedPanel(child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,
            crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('Clinical report',style:TextStyle(color:_AdminColors.ink,fontSize:20,fontWeight:FontWeight.w800)),
              const SizedBox(height:10),Text('Patient: ${report['patient_name_snapshot']}',style:TextStyle(color:_AdminColors.ink)),
              Text('Patient ID: ${report['public_id']}',style:TextStyle(color:_AdminColors.ink)),
              Text('Account: ${report['account_name_snapshot']} (${report['account_type_snapshot']})',style:TextStyle(color:_AdminColors.ink)),
              const SizedBox(height:12),for(final e in cbc.entries)Padding(padding:const EdgeInsets.symmetric(vertical:3),
                child:Text('${e.key.replaceAll('_',' ').toUpperCase()}: ${e.value}',style:TextStyle(color:_AdminColors.ink))),
              const Divider(),
              Text('Hematologist carrier assessment: ${report['hematologist_carrier'] ?? 'Not recorded'}',
                style:TextStyle(color:_AdminColors.ink,fontWeight:FontWeight.w700)),
              if(report['hematologist_name']!=null)Text('Hematologist: ${report['hematologist_name']}',style:TextStyle(color:_AdminColors.ink)),
              if(report['hematologist_notes']!=null)Text('Notes: ${report['hematologist_notes']}',style:TextStyle(color:_AdminColors.ink)),
              for(final file in files)TextButton.icon(onPressed:()=>_downloadEvidence(file),
                icon:const Icon(Icons.download_outlined),label:Text('Download ${file['kind']== 'consent_document'?'consent':'electrophoresis'}: ${file['filename']}')),
              const Divider(),Text(prediction['is_thalassemia']==true?'Indicators detected':'No indicators detected',
                style:TextStyle(color:_AdminColors.ink,fontWeight:FontWeight.bold)),
              Text('Consent: ${report['consent_id']}',style:TextStyle(color:_AdminColors.muted)),
              Text('Model: ${prediction['model_version']}',style:TextStyle(color:_AdminColors.muted)),
              const SizedBox(height:10),const Text('Screening aid only — not a diagnosis.'),
            ])))));
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Could not open report: $e')));}
  }
}
