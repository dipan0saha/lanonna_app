import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'config/app_config.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const LaNonnaApp());
}

class LaNonnaApp extends StatelessWidget {
  const LaNonnaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'La Nonna',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) => DevHomeScreen(user: snapshot.data),
      ),
    );
  }
}

class DevHomeScreen extends StatefulWidget {
  const DevHomeScreen({super.key, this.user});

  final User? user;

  @override
  State<DevHomeScreen> createState() => _DevHomeScreenState();
}

class _DevHomeScreenState extends State<DevHomeScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _healthResult;
  String? _meResult;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? e.code);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  Future<void> _getMe() async {
    final user = widget.user;
    if (user == null) {
      setState(() => _error = 'Sign in first');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _meResult = null;
    });
    try {
      final token = await user.getIdToken();
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/v1/me');
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );
      setState(() {
        _meResult = '${response.statusCode}: ${response.body}';
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pingHealth() async {
    setState(() {
      _busy = true;
      _error = null;
      _healthResult = null;
    });
    try {
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/health');
      final response = await http.get(uri);
      setState(() {
        _healthResult = '${response.statusCode}: ${response.body}';
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('La Nonna (dev)'),
        actions: [
          if (user != null)
            IconButton(
              onPressed: _busy ? null : _signOut,
              icon: const Icon(Icons.logout),
              tooltip: 'Sign out',
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text('Environment: ${AppConfig.environment}'),
            Text('API: ${AppConfig.apiBaseUrl}'),
            const SizedBox(height: 16),
            if (user == null) ...[
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
              ),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _busy ? null : _signIn,
                child: const Text('Sign in'),
              ),
            ] else ...[
              Text('Signed in as ${user.email ?? user.uid}'),
            ],
            const Divider(height: 32),
            FilledButton.tonal(
              onPressed: _busy ? null : _pingHealth,
              child: const Text('GET /health'),
            ),
            if (_healthResult != null) ...[
              const SizedBox(height: 8),
              SelectableText(_healthResult!),
            ],
            if (user != null) ...[
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: _busy ? null : _getMe,
                child: const Text('GET /v1/me'),
              ),
            ],
            if (_meResult != null) ...[
              const SizedBox(height: 8),
              SelectableText(_meResult!),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
    );
  }
}
