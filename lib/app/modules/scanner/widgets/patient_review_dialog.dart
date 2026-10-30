import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hemo_guard/app/modules/home/widgets/user_feedback.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hemo_guard/app/modules/home/widgets/user_glass.dart';

/// Patient data is still reviewed before saving; all original fields,
/// validators, and returned keys are preserved.
class PatientReviewDialog extends StatefulWidget {
  const PatientReviewDialog({super.key, required this.initial});
  final Map<String, String> initial;
  @override
  State<PatientReviewDialog> createState() => _PatientReviewDialogState();
}

class _PatientReviewDialogState extends State<PatientReviewDialog> {
  late final Map<String, TextEditingController> fields;
  late String sex;
  String? carrier;
  late Map<String,String> attachments;
  bool choosingDocument=false;
  final form = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    fields = {
      for (final key in ['name', 'age_at_test', 'public_id',
        'lab_patient_number', 'source_report_number', 'sample_date', 'hematologist_name', 'hematologist_notes'])
        key: TextEditingController(text: widget.initial[key] ?? '')
    };
    sex = widget.initial['sex'] ?? 'unknown';
    carrier = ['yes','no'].contains(widget.initial['hematologist_carrier'])
      ? widget.initial['hematologist_carrier'] : null;
    attachments={
      'consent_document_path':widget.initial['consent_document_path'] ?? '',
      'electrophoresis_path':widget.initial['electrophoresis_path'] ?? '',
    };
  }

  @override
  void dispose() {
    for (final controller in fields.values) { controller.dispose(); }
    super.dispose();
  }

  Widget entry(String key, String label, {bool required = false, TextInputType? keyboard}) {
    final missing = (widget.initial[key] ?? '').trim().isEmpty;
    return Padding(padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: fields[key], keyboardType: keyboard,
        style: TextStyle(color: UserGlassColors.ink, fontWeight: FontWeight.w600),
        cursorColor: UserGlassColors.violet,
        validator: (value) {
          final text = (value ?? '').trim();
          if (required && text.length < 2) return 'Please enter the patient name';
          if (key == 'age_at_test' && text.isEmpty) return 'Patient age is required';
          if (key == 'age_at_test' && text.isNotEmpty &&
              (int.tryParse(text) == null || int.parse(text) < 0 || int.parse(text) > 125)) {
            return 'Age must be 0–125';
          }
          if (key == 'sample_date' && text.isNotEmpty &&
              !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) return 'Use YYYY-MM-DD';
          return null;
        },
        decoration: InputDecoration(
          filled: true,
          fillColor: UserGlassColors.dark
            ? const Color(0xFF211A25) : const Color(0xFFFFFAFF),
          labelStyle: TextStyle(color: UserGlassColors.muted),
          floatingLabelStyle: const TextStyle(color: UserGlassColors.violet),
          errorStyle: TextStyle(color: UserGlassColors.dark
            ? const Color(0xFFFFAEBE) : const Color(0xFFB3264D)),
          labelText: label,
          helperText: missing ? 'Not detected — enter manually if available' : 'Detected by OCR — editable',
          helperStyle: TextStyle(color: missing
            ? (UserGlassColors.dark ? const Color(0xFFFFD18A) : const Color(0xFF89520C))
            : (UserGlassColors.dark ? const Color(0xFFD9BEFF) : UserGlassColors.violet),
            fontSize: 11),
          prefixIcon: Icon(missing ? Icons.edit_note_rounded : Icons.verified_outlined,
            color: missing
              ? (UserGlassColors.dark ? const Color(0xFFFFD18A) : const Color(0xFF89520C))
              : UserGlassColors.violet),
        ),
      ),
    );
  }

  Future<void> pickDocument(String kind) async {
    if (choosingDocument) return;
    final selected=await showModalBottomSheet<String>(context:context,builder:(ctx)=>SafeArea(
      child:Column(mainAxisSize:MainAxisSize.min,children:[
        ListTile(leading:const Icon(Icons.camera_alt_outlined),title:const Text('Take photo'),
          onTap:()=>Navigator.pop(ctx,'camera')),
        ListTile(leading:const Icon(Icons.photo_library_outlined),title:const Text('Choose from gallery'),
          onTap:()=>Navigator.pop(ctx,'gallery')),
        ListTile(leading:const Icon(Icons.picture_as_pdf_outlined),title:const Text('Choose PDF or image file'),
          onTap:()=>Navigator.pop(ctx,'file')),
      ])));
    if (selected==null || !mounted) return;
    choosingDocument=true;
    try {
      String? path;
      if (selected=='camera' || selected=='gallery') {
        path=(await ImagePicker().pickImage(source:selected=='camera'?ImageSource.camera:ImageSource.gallery,
          imageQuality:60,maxWidth:1200))?.path;
      } else {
        final chosen=await FilePicker.platform.pickFiles(type:FileType.custom,
          allowedExtensions:['pdf','jpg','jpeg','png','webp'],withData:false);
        path=chosen?.files.single.path;
      }
      if (path!=null && mounted) {
        if (await File(path).length()>1200000) {
          UserFeedback.error('Document too large','Choose a file smaller than 1.2 MB.');
        } else {
          setState(()=>attachments[kind]=path!);
        }
      }
    } catch(e) {
      if(mounted) UserFeedback.error('Document selection failed',e.toString());
    } finally {choosingDocument=false;}
  }

  Widget documentPicker(String key,String title,String subtitle) {
    final path=attachments[key]??'';
    return Padding(padding:const EdgeInsets.only(bottom:10),child:Container(
      decoration:BoxDecoration(borderRadius:BorderRadius.circular(14),
        color:UserGlassColors.surface,border:Border.all(color:UserGlassColors.border)),
      child:ListTile(
        leading:Icon(key=='consent_document_path'?Icons.description_outlined:Icons.science_outlined,
          color:UserGlassColors.violet),
        title:Text(title,style:TextStyle(color:UserGlassColors.ink,fontWeight:FontWeight.w700)),
        subtitle:Text(path.isEmpty?subtitle:path.split(RegExp(r'[/\\]')).last,
          maxLines:2,overflow:TextOverflow.ellipsis,style:TextStyle(color:UserGlassColors.muted)),
        trailing:Row(mainAxisSize:MainAxisSize.min,children:[
          if(path.isNotEmpty)IconButton(tooltip:'Remove document',icon:const Icon(Icons.close),
            color:UserGlassColors.muted,onPressed:()=>setState(()=>attachments[key]='')),
          IconButton(tooltip:'Add document',icon:const Icon(Icons.add_a_photo_outlined),
            color:UserGlassColors.violet,onPressed:()=>pickDocument(key)),
        ]),
        onTap:()=>pickDocument(key),
      )));
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.all(15),
    child: UserGlassPanel(padding: EdgeInsets.zero, radius: 25,
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 510, maxHeight: 720),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Row(children: [
              const Icon(Icons.manage_accounts_outlined, color: UserGlassColors.violet, size: 29),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Review patient details', style: TextStyle(color: UserGlassColors.ink,
                  fontWeight: FontWeight.w800, fontSize: 19)),
                Text('Correct OCR values before submitting',
                  style: TextStyle(color: UserGlassColors.muted, fontSize: 12)),
              ])),
              IconButton(onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close, color: UserGlassColors.ink)),
            ])),
          Flexible(child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Form(key: form, child: Column(children: [
              entry('name', 'Patient name *', required: true),
              entry('age_at_test', 'Patient age * (years)', keyboard: TextInputType.number),
              DropdownButtonFormField<String>(
                value: sex,
                style: TextStyle(color: UserGlassColors.ink, fontWeight: FontWeight.w600),
                dropdownColor: UserGlassColors.dark
                  ? const Color(0xFF29212E) : const Color(0xFFFFF7FF),
                decoration: InputDecoration(
                  labelText: 'Sex *',
                  labelStyle: TextStyle(color: UserGlassColors.muted),
                  filled: true,
                  fillColor: UserGlassColors.dark
                    ? const Color(0xFF211A25) : const Color(0xFFFFFAFF)),
                items: const [
                  DropdownMenuItem(value: 'unknown', child: Text('Select sex')),
                  DropdownMenuItem(value: 'male', child: Text('Male')),
                  DropdownMenuItem(value: 'female', child: Text('Female')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (value) => setState(() => sex = value ?? 'unknown'),
              ),
              const SizedBox(height: 12),
              const SizedBox(height:12),
              Align(alignment:Alignment.centerLeft,child:Text('Hematologist assessment *',
                style:TextStyle(color:UserGlassColors.ink,fontWeight:FontWeight.w800))),
              Text('According to the hematologist, is this patient a carrier? This is independent of the AI prediction.',
                style:TextStyle(color:UserGlassColors.muted,fontSize:12)),
              Row(children:[
                Expanded(child:RadioListTile<String>(title:Text('Yes',style:TextStyle(color:UserGlassColors.ink)),
                  value:'yes',groupValue:carrier,activeColor:UserGlassColors.violet,
                  onChanged:(v)=>setState(()=>carrier=v))),
                Expanded(child:RadioListTile<String>(title:Text('No',style:TextStyle(color:UserGlassColors.ink)),
                  value:'no',groupValue:carrier,activeColor:UserGlassColors.violet,
                  onChanged:(v)=>setState(()=>carrier=v))),
              ]),
              entry('hematologist_name','Hematologist name (optional)'),
              entry('hematologist_notes','Hematologist notes (optional)'),
              const SizedBox(height:8),
              documentPicker('consent_document_path','Consent document (optional)',
                'Take a photo or upload a signed form; checkbox consent is still required'),
              documentPicker('electrophoresis_path','Electrophoresis report (optional)',
                'Take a photo, choose an image, or upload a PDF'),
              Text('Documents are stored privately for superadmin review (maximum 1.2 MB each).',
                style:TextStyle(color:UserGlassColors.muted,fontSize:11)),
              const SizedBox(height:12),
              entry('public_id', 'Existing HemoGuard ID (if printed)'),
              entry('lab_patient_number', 'Laboratory patient number (if stable)'),
              entry('source_report_number', 'Source CBC report / sample number'),
              entry('sample_date', 'Sample date (YYYY-MM-DD)'),
              const SizedBox(height: 4),
              Text('CBC values remain editable on the scanner screen. No patient record is created until you confirm.',
                style: TextStyle(color: UserGlassColors.muted, fontSize: 12)),
              const SizedBox(height: 12),
            ])),
          )),
          Padding(padding: const EdgeInsets.all(16),
            child: SizedBox(width: double.infinity, child: ElevatedButton.icon(
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Confirm and check patient'),
              onPressed: () {
                if (!(form.currentState?.validate() ?? false)) return;
                if(sex=='unknown' || carrier==null) {
                  UserFeedback.info('Patient details required',
                    'Select patient sex and the hematologist carrier assessment (Yes/No).');
                  return;
                }
                Navigator.pop(context, {
                  for (final e in fields.entries) e.key: e.value.text.trim(),
                  'sex': sex,
                  'hematologist_carrier':carrier!,
                  ...attachments,
                });
              },
            )),
          ),
        ]),
      ),
    ),
  );
}
