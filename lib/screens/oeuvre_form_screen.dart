import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/oeuvre_model.dart';
import '../../providers/oeuvre_provider.dart';

class OeuvreFormScreen extends StatefulWidget {
  final OeuvreModel? oeuvre; // null = création
  const OeuvreFormScreen({super.key, this.oeuvre});

  @override
  State<OeuvreFormScreen> createState() => _OeuvreFormScreenState();
}

class _OeuvreFormScreenState extends State<OeuvreFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _title;
  late final TextEditingController _year;
  late final TextEditingController _genre;
  late final TextEditingController _composers;
  late final TextEditingController _arrangers;
  bool _requiresChoir = false;
  bool _isLoading = false;

  File? _lyricsFile;
  File? _partitionFile;
  File? _videoFile;
  File? _audioFile;

  String? _lyricsName;
  String? _partitionName;
  String? _videoName;
  String? _audioName;

  bool get isEdit => widget.oeuvre != null;

  @override
  void initState() {
    super.initState();
    final o = widget.oeuvre;
    _title     = TextEditingController(text: o?.title ?? '');
    _year      = TextEditingController(text: o?.year ?? '');
    _genre     = TextEditingController(text: o?.genre ?? '');
    _composers = TextEditingController(text: o?.composers.join(', ') ?? '');
    _arrangers = TextEditingController(text: o?.arrangers.join(', ') ?? '');
    _requiresChoir = o?.requiresChoir ?? false;
    // Noms actuels des fichiers existants
    _lyricsName    = o?.lyrics.isNotEmpty == true ? o!.lyrics : null;
    _partitionName = o?.partition.isNotEmpty == true ? o!.partition : null;
    _videoName     = o?.video.isNotEmpty == true ? o!.video : null;
    _audioName     = o?.audio.isNotEmpty == true ? o!.audio : null;
  }

  @override
  void dispose() {
    _title.dispose(); _year.dispose(); _genre.dispose();
    _composers.dispose(); _arrangers.dispose();
    super.dispose();
  }

  // ─── Picker helpers ───────────────────────────────────────────────────────
  Future<void> _pickFile({
    required List<String> extensions,
    required void Function(File file, String name) onPicked,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
    );
    if (result != null && result.files.single.path != null) {
      final f = File(result.files.single.path!);
      onPicked(f, result.files.single.name);
    }
  }

  Future<void> _pickPdf(String field) async {
    await _pickFile(
      extensions: ['pdf'],
      onPicked: (f, name) => setState(() {
        if (field == 'lyrics') { _lyricsFile = f; _lyricsName = name; }
        else { _partitionFile = f; _partitionName = name; }
      }),
    );
  }

  Future<void> _pickVideo() async {
    await _pickFile(
      extensions: ['mp4', 'mov', 'avi'],
      onPicked: (f, name) => setState(() { _videoFile = f; _videoName = name; }),
    );
  }

  Future<void> _pickAudio() async {
    await _pickFile(
      extensions: ['mp3', 'wav', 'aac', 'm4a'],
      onPicked: (f, name) => setState(() { _audioFile = f; _audioName = name; }),
    );
  }

  // ─── Soumettre ────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final data = {
      'title':        _title.text.trim(),
      'year':         _year.text.trim(),
      'genre':        _genre.text.trim(),
      'requiresChoir': _requiresChoir,
      'composers': _composers.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      'arrangers': _arrangers.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
    };

    final provider = context.read<OeuvreProvider>();
    bool ok;

    if (isEdit) {
      ok = await provider.updateOeuvre(
        id: widget.oeuvre!.id,
        data: data,
        lyricsFile: _lyricsFile,
        partitionFile: _partitionFile,
        videoFile: _videoFile,
        audioFile: _audioFile,
      );
    } else {
      ok = await provider.createOeuvre(
        data: data,
        lyricsFile: _lyricsFile,
        partitionFile: _partitionFile,
        videoFile: _videoFile,
        audioFile: _audioFile,
      );
    }

    setState(() => _isLoading = false);

    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isEdit ? 'Œuvre mise à jour ✅' : 'Œuvre créée ✅'),
        backgroundColor: const Color(0xFF10B981),
      ));
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(provider.error ?? 'Erreur inconnue'),
        backgroundColor: const Color(0xFFEF4444),
      ));
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded,
              color: Color(0xFF1E293B), size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEdit ? 'Modifier l\'œuvre' : 'Nouvelle œuvre',
          style: const TextStyle(
              color: Color(0xFF1E293B),
              fontSize: 16,
              fontWeight: FontWeight.w700),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF3B82F6)))
                : TextButton(
                    onPressed: _submit,
                    child: Text(
                      isEdit ? 'Enregistrer' : 'Créer',
                      style: const TextStyle(
                          color: Color(0xFF3B82F6),
                          fontWeight: FontWeight.w700,
                          fontSize: 15),
                    ),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Infos générales ──────────────────────────────────────
            _SectionLabel('Informations'),
            const SizedBox(height: 8),
            _Field(
              controller: _title,
              label: 'Titre *',
              icon: Icons.music_note_rounded,
              validator: (v) =>
                  v == null || v.isEmpty ? 'Titre requis' : null,
            ),
            _Field(
              controller: _composers,
              label: 'Compositeur(s) * (séparés par virgule)',
              icon: Icons.person_rounded,
              validator: (v) =>
                  v == null || v.isEmpty ? 'Compositeur requis' : null,
            ),
            _Field(
              controller: _arrangers,
              label: 'Arrangeur(s) (séparés par virgule)',
              icon: Icons.edit_rounded,
            ),
            _Field(
              controller: _year,
              label: 'Année *',
              icon: Icons.calendar_today_rounded,
              keyboardType: TextInputType.number,
              validator: (v) =>
                  v == null || v.isEmpty ? 'Année requise' : null,
            ),
            _Field(
              controller: _genre,
              label: 'Genre *',
              icon: Icons.category_rounded,
              validator: (v) =>
                  v == null || v.isEmpty ? 'Genre requis' : null,
            ),

            // Choeur
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0))),
              child: SwitchListTile(
                value: _requiresChoir,
                onChanged: (v) => setState(() => _requiresChoir = v),
                title: const Text('Nécessite le chœur',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B))),
                secondary: const Icon(Icons.group_rounded,
                    color: Color(0xFF64748B), size: 20),
                activeColor: const Color(0xFF3B82F6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),

            // ── Fichiers ─────────────────────────────────────────────
            const SizedBox(height: 8),
            _SectionLabel('Fichiers (optionnel)'),
            const SizedBox(height: 8),

            _FilePicker(
              icon: Icons.picture_as_pdf_rounded,
              label: 'Partition (PDF)',
              color: const Color(0xFFEF4444),
              fileName: _partitionName,
              onPick: () => _pickPdf('partition'),
              onClear: () => setState(
                  () { _partitionFile = null; _partitionName = null; }),
            ),
            _FilePicker(
              icon: Icons.article_rounded,
              label: 'Paroles (PDF)',
              color: const Color(0xFF8B5CF6),
              fileName: _lyricsName,
              onPick: () => _pickPdf('lyrics'),
              onClear: () => setState(
                  () { _lyricsFile = null; _lyricsName = null; }),
            ),
            _FilePicker(
              icon: Icons.headphones_rounded,
              label: 'Audio (MP3/WAV)',
              color: const Color(0xFF0EA5E9),
              fileName: _audioName,
              onPick: _pickAudio,
              onClear: () => setState(
                  () { _audioFile = null; _audioName = null; }),
            ),
            _FilePicker(
              icon: Icons.play_circle_rounded,
              label: 'Vidéo (MP4)',
              color: const Color(0xFF10B981),
              fileName: _videoName,
              onPick: _pickVideo,
              onClear: () => setState(
                  () { _videoFile = null; _videoName = null; }),
            ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(
                        isEdit ? 'Enregistrer les modifications' : 'Créer l\'œuvre',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Champ texte ──────────────────────────────────────────────────────────────
class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.validator,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            prefixIcon:
                Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: Color(0xFF3B82F6), width: 1.5)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFEF4444))),
          ),
        ),
      );
}

// ─── Sélecteur de fichier ─────────────────────────────────────────────────────
class _FilePicker extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final String? fileName;
  final VoidCallback onPick;
  final VoidCallback onClear;
  const _FilePicker({
    required this.icon,
    required this.label,
    required this.color,
    required this.fileName,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final hasFile = fileName != null && fileName!.isNotEmpty;
    return GestureDetector(
      onTap: onPick,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: hasFile ? color.withValues(alpha: 0.4) : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B))),
                  if (hasFile) ...[
                    const SizedBox(height: 2),
                    Text(
                      fileName!.length > 35
                          ? '…${fileName!.substring(fileName!.length - 32)}'
                          : fileName!,
                      style: TextStyle(
                          fontSize: 11,
                          color: color,
                          fontWeight: FontWeight.w500),
                    ),
                  ] else
                    const Text('Appuyer pour choisir',
                        style: TextStyle(
                            fontSize: 11, color: Color(0xFF94A3B8))),
                ],
              ),
            ),
            if (hasFile)
              GestureDetector(
                onTap: onClear,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6)),
                  child: const Icon(Icons.close_rounded,
                      size: 14, color: Color(0xFF64748B)),
                ),
              )
            else
              const Icon(Icons.upload_rounded,
                  size: 18, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF64748B),
          letterSpacing: 0.5));
}