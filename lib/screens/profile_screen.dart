import '../widgets/common.dart';
import 'package:flutter/material.dart';

import '../core/localization.dart';
import '../core/theme.dart';
import '../services/db_service.dart';

/// Profile setup / edit. Writes users/{uid}/profile with the same fields the
/// web app uses (name, phone, createdAt), so both stay in sync.
///
/// When [isSetup] is true this is the first-run gate shown right after signup,
/// matching the web app's profile-setup section.
class ProfileScreen extends StatefulWidget {
  final bool isSetup;
  const ProfileScreen({super.key, this.isSetup = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _busy = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await DbService.instance.getProfile();
    if (!mounted) return;
    setState(() {
      _name.text = (p?['name'] ?? '').toString();
      _phone.text = (p?['phone'] ?? '').toString();
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter your name')));
      return;
    }
    setState(() => _busy = true);
    try {
      await DbService.instance
          .saveProfile(_name.text.trim(), _phone.text.trim());
      if (!mounted) return;
      if (!widget.isSetup) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Profile saved')));
      }
      // In setup mode the auth gate reacts to the profile stream itself.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final form = _loading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.isSetup) ...[
                  const Icon(Icons.person_add_alt_1,
                      size: 54, color: AppColors.primary),
                  const SizedBox(height: 10),
                  const Text('Complete your profile',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text('Just once, so people know who you are when you share.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600)),
                  const SizedBox(height: 24),
                ],
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 24),
                GradientButton(
                  onPressed: _busy ? null : _save,
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(widget.isSetup
                          ? 'Continue'
                          : context.t('save')),
                ),
              ],
            ),
          );

    if (widget.isSetup) {
      return Scaffold(
        body: SafeArea(child: Center(child: form)),
      );
    }
    return Scaffold(
      appBar: const GradientAppBar(title: Text('My Profile')),
      body: form,
    );
  }
}
