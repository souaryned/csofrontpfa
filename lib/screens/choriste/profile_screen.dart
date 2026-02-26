import 'dart:io';
import '../../config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/avatar_widget.dart'; // ✅ IMPORT

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  File? _selectedImage;
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    // Recharger depuis le backend pour avoir phone à jour
    await context.read<AuthProvider>().loadUser();
    _loadProfile();
  });
}

void _loadProfile() {
  final user = context.read<AuthProvider>().user;
  if (user != null) {
    final parts = user.fullName.split(' ');
    _firstNameController.text = parts.isNotEmpty ? parts[0] : '';
    _lastNameController.text =
        parts.length > 1 ? parts.sublist(1).join(' ') : '';
    _phoneController.text = user.phone ?? '';
    setState(() {});
  }
}

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    try {
      final success = await context.read<AuthProvider>().updateProfile(
        {
          'firstName': _firstNameController.text.trim(),
          'lastName': _lastNameController.text.trim(),
          'phone': _phoneController.text.trim(),
        },
        avatarFile: _selectedImage,
      );

      if (!mounted) return;

      if (success) {
        _showSnackBar('Profil mis à jour ✅', Colors.green);
        setState(() => _selectedImage = null);
      } else {
        final error = context.read<AuthProvider>().errorMessage;
        _showSnackBar('Erreur : $error', Colors.red);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Erreur : $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    // ✅ URL complète de l'avatar
    final String? avatarUrl = user?.avatar != null
        ? '${ApiConfig.baseUrl}${user!.avatar}'
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2DD4BF), Color(0xFF3B82F6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      // ✅ Si image sélectionnée localement → FileImage
                      // Sinon → AvatarImage robuste
                      _selectedImage != null
                          ? CircleAvatar(
                              radius: 45,
                              backgroundImage: FileImage(_selectedImage!),
                            )
                          : AvatarImage(
                              avatarUrl: avatarUrl,
                              fullName: user?.fullName,
                              radius: 45,
                              backgroundColor: Colors.white30,
                              textColor: Colors.white,
                            ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt, size: 16, color: Color(0xFF2DD4BF)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Cliquez pour changer la photo', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 8),
                Text(user?.fullName ?? '', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(user?.role ?? '', style: const TextStyle(color: Colors.white, fontSize: 13)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Modifier mes informations', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildField(controller: _firstNameController, label: 'Prénom', icon: Icons.person_outline)),
              const SizedBox(width: 12),
              Expanded(child: _buildField(controller: _lastNameController, label: 'Nom', icon: Icons.person_outline)),
            ],
          ),
          const SizedBox(height: 12),
          _buildField(controller: _phoneController, label: 'Téléphone', icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _saveProfile,
              icon: _isLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save),
              label: Text(_isLoading ? 'Sauvegarde...' : 'Sauvegarder'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2DD4BF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF2DD4BF)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2DD4BF))),
      ),
    );
  }
}