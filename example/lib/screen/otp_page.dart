import 'package:c_shield_sdk/c_shield_sdk.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../network/api_client.dart';
import '../widgets/result_card.dart';

class OtpPage extends StatefulWidget {
  const OtpPage({super.key});

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final _controller = TextEditingController();
  final _dio = buildDio();

  bool _loading = false;
  String _result = '';
  bool? _success;

  @override
  void dispose() {
    _controller.dispose();
    _dio.close();
    super.dispose();
  }

  Future<void> _submit() async {
    final otp = _controller.text.trim();
    if (otp.isEmpty) return;

    setState(() {
      _loading = true;
      _result = '';
      _success = null;
    });

    try {
      final response = await _dio.post('/verify-otp', data: {'otp': otp});
      final data = response.data as Map<String, dynamic>;
      setState(() {
        _success = data['code'] == 'OK';
        _result = '${data['message']}';
        
      });
    } on CShieldException catch (e) {
      setState(() {
        _success = false;
        _result = '[${e.code.name}] ${e.message}';
        
      });
    } on DioException catch (e) {
      setState(() {
        _success = false;
        final inner = e.error;
        if (inner is CShieldException) {
          _result = '[${inner.code.name}] ${inner.message}';
          
        } else {
          _result = e.message ?? e.toString();
         
        }
      });
    } catch (e) {
      setState(() {
        _success = false;
        _result = e.toString();
      
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OTP Verification'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
        
            const SizedBox(height: 32),
            TextField(
              controller: _controller,
              enabled: !_loading,
              decoration: const InputDecoration(
                labelText: 'OTP',
                hintText: 'Enter OTP',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Verify OTP'),
            ),
            if (_result.isNotEmpty) ...[
              const SizedBox(height: 24),
              ResultCard(message: _result, success: _success == true),
            ],
          ],
        ),
      ),
    );
  }
}
