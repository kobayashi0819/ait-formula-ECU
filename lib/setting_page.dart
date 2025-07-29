import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingPage extends StatefulWidget {
  final String? initialIp;

  const SettingPage({super.key, this.initialIp});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialIp ?? '';
  }

  Future<void> _saveIp() async {
    String newIp = _controller.text;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('localIp', newIp);
    if (context.mounted) {
      Navigator.pop(context, newIp); // セッティングを保存して戻る
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('セッティング')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'IPアドレス',
                border: OutlineInputBorder(),
              ),
              // keyboardType: TextInputType.number,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveIp,
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}
