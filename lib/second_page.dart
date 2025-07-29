import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'setting_page.dart';

class SecondPage extends StatefulWidget {
  const SecondPage({super.key});

  @override
  State<SecondPage> createState() => _SecondPageState();
}

class _SecondPageState extends State<SecondPage> {
  String? _localIp;

  @override
  void initState() {
    super.initState();
    _loadLocalIp();
  }

  Future<void> _loadLocalIp() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _localIp = prefs.getString('localIp') ?? '未設定';
    });
  }

  Future<void> _navigateToSettingPage() async {
    final updatedIp = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingPage(initialIp: _localIp),
      ),
    );
    if (updatedIp != null) {
      setState(() {
        _localIp = updatedIp;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Second Page')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('現在のIP: $_localIp', style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DebugPage(),
                  ),
                );
              },
              child: const Text('デバッグ'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _navigateToSettingPage,
              child: const Text('セッティング'),
            ),
          ],
        ),
      ),
    );
  }
}

class DebugPage extends StatelessWidget {
  const DebugPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('デバッグ')),
      body: Center(
        child: Container(
          width: 300,
          height: 300,
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(16.0),
          ),
        ),
      ),
    );
  }
}
