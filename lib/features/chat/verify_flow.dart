// lib/features/chat/verify_flow.dart
// Structured verification (FR-7.3). Claimant submits proof; holder accepts/rejects.
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase.dart';

class VerifyFlowScreen extends StatefulWidget {
  final String chatId;
  const VerifyFlowScreen({super.key, required this.chatId});

  @override
  State<VerifyFlowScreen> createState() => _VerifyFlowScreenState();
}

class _VerifyFlowScreenState extends State<VerifyFlowScreen> {
  String _method = 'photo';

  Future<void> _submit() async {
    await supabase.from('verifications').insert({
      'chat_id': widget.chatId,
      'method': _method,
      'proof_media': [],
    });
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('التحقق من الملكية')),
      body: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        const Text('اختر طريقة الإثبات:'),
        DropdownButton<String>(value: _method, items: const [
          DropdownMenuItem(value: 'photo', child: Text('صورة للغرض من زاوية محددة')),
          DropdownMenuItem(value: 'serial', child: Text('معرّف سري (serial/IMEI)')),
          DropdownMenuItem(value: 'detail', child: Text('سؤال تفصيلي (ماذا محفور؟)')),
        ], onChanged: (v) => setState(() => _method = v!)),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: _submit, child: const Text('إرسال طلب التحقق')),
      ])));
  }
}
