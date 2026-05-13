import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/date_selection_screen.dart';

// دالة بسيطة لتعتيم المفتاح السري قليلاً
String getSecretKey() {
  const part1 = 'your_super_s';
  const part2 = 'ecret_key_123';
  const part3 = '!@#';
  return '$part1$part2$part3';
}

class ActivationScreen extends StatefulWidget {
  const ActivationScreen({super.key});

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final _ngrokUrlController = TextEditingController();
  final _customerNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  String _errorMessage = '';

  // دالة لجلب معرّف الجهاز الفريد
  Future<String?> _getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id;
    }
    return null;
  }

  Future<void> _activateDevice() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final deviceId = await _getDeviceId();
    if (deviceId == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'لم يتمكن من الحصول على معرّف الجهاز.';
      });
      return;
    }

    String url = _ngrokUrlController.text.trim();
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    final fullUrl = Uri.parse('$url/api/register_device.php');

    try {
      final response = await http
          .post(
            fullUrl,
            headers: {'Content-Type': 'application/json; charset=UTF-8'},
            body: jsonEncode({
              'customer_name': _customerNameController.text.trim(),
              'device_id': deviceId,
              'app_key': getSecretKey(),
            }),
          )
          .timeout(const Duration(seconds: 20));

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (responseData['status'] == 'success') {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
              'activation_status', base64.encode(utf8.encode('activated_ok')));

          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => const DateSelectionScreen(
                  storeType: '',
                  storeName: '',
                ),
              ),
            );
          }
        }
      } else {
        setState(() {
          _errorMessage = responseData['message'] ?? 'حدث خطأ غير معروف.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage =
            'فشل الاتصال بالخادم. تأكد من الرابط واتصال الإنترنت.\n$e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // --- رأس الصفحة ---
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.teal[700],
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_outline_rounded,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'تفعيل التطبيق',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'يرجى إدخال بيانات التفعيل للمتابعة',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 30),

                    // --- حقل الرابط ---
                    TextFormField(
                      controller: _ngrokUrlController,
                      textAlign: TextAlign.right,
                      decoration: InputDecoration(
                        labelText: 'ادخل رابط التفعيل',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.link),
                        alignLabelWithHint: true,
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'حقل الرابط مطلوب';
                        }
                        return null;
                      },
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 16),

                    // --- حقل اسم الزبون ---
                    TextFormField(
                      controller: _customerNameController,
                      textAlign: TextAlign.right,
                      decoration: InputDecoration(
                        labelText: 'اسم الزبون',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.person),
                        alignLabelWithHint: true,
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'حقل اسم الزبون مطلوب';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // --- زر التفعيل ---
                    if (_isLoading)
                      const CircularProgressIndicator(color: Colors.teal)
                    else
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _activateDevice,
                          icon: const Icon(Icons.verified_user_outlined),
                          label: const Text('تفعيل'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            textStyle: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),

                    // --- رسالة الخطأ ---
                    if (_errorMessage.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline,
                                color: Colors.red[700], size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage,
                                style: TextStyle(color: Colors.red[700]),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 28),

                    // --- بطاقة معلومات التواصل ---
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.teal[800]!, Colors.teal[600]!],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.teal.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 20, horizontal: 6),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.support_agent,
                                    color: Colors.white70, size: 50),
                                SizedBox(width: 8),
                                Text(
                                  'إن اعجبك التطبيق يرجى التواصل \n عن طريق الارقام الآتية:',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            const Divider(color: Colors.white24, thickness: 1),
                            const SizedBox(height: 14),

                            // الأرقام
                            Row(
                              children: [
                                _buildPhoneChip('0944367326'),
                                const SizedBox(width: 5),
                                _buildPhoneChip('0935017509'),
                              ],
                            ),

                            const SizedBox(height: 16),
                            const Divider(color: Colors.white24, thickness: 1),

                            // الاسم
                            const Text(
                              'المحاسب عدنان محمد الحجي ',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'أبو فراس',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // widget مساعد لعرض رقم الهاتف بشكل أنيق
  Widget _buildPhoneChip(String number) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.phone, color: Colors.white70, size: 14),
          const SizedBox(width: 6),
          Text(
            number,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
