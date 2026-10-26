import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hemo_guard/app/theme/app_theme.dart';

/// Returns an existing internal patient UUID, 'new', or null (cancel).
/// No name-only candidate is silently merged.
class PatientMatchDialog extends StatelessWidget {
  const PatientMatchDialog({super.key,required this.matches,required this.verified});
  final List<Map<String,dynamic>> matches;
  final bool verified;
  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor:Colors.transparent,child:ClipRRect(borderRadius:BorderRadius.circular(24),
      child:BackdropFilter(filter:ImageFilter.blur(sigmaX:18,sigmaY:18),
        child:Container(padding:const EdgeInsets.all(19),constraints:const BoxConstraints(maxWidth:470),
          decoration:BoxDecoration(color:Colors.white.withValues(alpha:.92),borderRadius:BorderRadius.circular(24),
            border:Border.all(color:Colors.white.withValues(alpha:.9))),
          child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[Icon(verified?Icons.person_pin_circle_outlined:Icons.manage_search_rounded,color:AppColors.brandDark,size:28),
              const SizedBox(width:9),Expanded(child:Text(verified?'Returning patient detected':'Possible existing patient',
                style:const TextStyle(fontWeight:FontWeight.w800,fontSize:18)))]),
            const SizedBox(height:8),Text(verified?'A patient record already exists. Select it to append this screening; previous reports stay unchanged.':
              'Similar patient details were found. Confirm carefully — name alone is not reliable proof of identity.',
              style:const TextStyle(fontSize:12,color:AppColors.muted)),const SizedBox(height:14),
            for(final p in matches)...[
              Card(child:ListTile(leading:const Icon(Icons.person_outline,color:AppColors.brandDark),
                title:Text(p['name']?.toString()??''),subtitle:Text('${p['public_id']} • age ${p['age_at_registration']??'unknown'} • ${p['sex']??'unknown'}'),
                trailing:const Text('Add test →',style:TextStyle(color:AppColors.brandDark,fontWeight:FontWeight.w700,fontSize:11)),
                onTap:()=>Navigator.pop(context,p['id'].toString()))),
              const SizedBox(height:6),
            ],
            const SizedBox(height:8),SizedBox(width:double.infinity,child:OutlinedButton.icon(
              icon:const Icon(Icons.person_add_alt_1_outlined),label:const Text('This is a new patient'),
              onPressed:()=>Navigator.pop(context,'new'))),
            const SizedBox(height:4),SizedBox(width:double.infinity,child:TextButton(
              onPressed:()=>Navigator.pop(context,'rescan'),child:const Text('Scan again'))),
          ]))))));
}
