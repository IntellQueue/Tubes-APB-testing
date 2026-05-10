import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/song.dart';
import '../../providers/music_provider.dart';
import '../../theme/app_theme.dart';

class AdminSongFormScreen extends StatefulWidget {
  final Song? song;
  const AdminSongFormScreen({super.key, this.song});

  @override
  State<AdminSongFormScreen> createState() => _AdminSongFormScreenState();
}

class _AdminSongFormScreenState extends State<AdminSongFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _artistController;
  late TextEditingController _descController;
  late TextEditingController _coverPathController;
  late TextEditingController _filePathController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.song?.title ?? '');
    _artistController = TextEditingController(text: widget.song?.artist ?? '');
    _descController = TextEditingController(text: widget.song?.description ?? '');
    _coverPathController = TextEditingController(text: widget.song?.coverPath ?? '');
    _filePathController = TextEditingController(text: widget.song?.filePath ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _descController.dispose();
    _coverPathController.dispose();
    _filePathController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      if (widget.song != null) {
        await context.read<MusicProvider>().editSong(
          id: widget.song!.id,
          title: _titleController.text,
          artist: _artistController.text,
          description: _descController.text,
          coverPath: _coverPathController.text.isNotEmpty ? _coverPathController.text : null,
          filePath: _filePathController.text.isNotEmpty ? _filePathController.text : null,
        );
      } else {
        await context.read<MusicProvider>().addSong(
          title: _titleController.text,
          artist: _artistController.text,
          description: _descController.text,
          coverPath: _coverPathController.text,
          filePath: _filePathController.text,
        );
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.song != null ? 'Lagu berhasil diperbarui' : 'Lagu berhasil ditambahkan')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan lagu: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.song != null;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4A0E17), AppColors.ink],
            begin: Alignment.topLeft,
            end: FractionalOffset(0.2, 0.55),
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: Colors.transparent,
                title: Text(isEdit ? 'Edit Lagu' : 'Upload Lagu'),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverToBoxAdapter(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildInputCard(
                          title: 'Informasi Dasar',
                          children: [
                            TextFormField(
                              controller: _titleController,
                              decoration: const InputDecoration(labelText: 'Judul Lagu'),
                              validator: (val) => val == null || val.isEmpty ? 'Judul tidak boleh kosong' : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _artistController,
                              decoration: const InputDecoration(labelText: 'Artis / Band'),
                              validator: (val) => val == null || val.isEmpty ? 'Artis tidak boleh kosong' : null,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildInputCard(
                          title: 'Deskripsi',
                          children: [
                            TextFormField(
                              controller: _descController,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                labelText: 'Tentang Lagu Ini',
                                alignLabelWithHint: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildInputCard(
                          title: 'File Aset',
                          children: [
                            TextFormField(
                              controller: _coverPathController,
                              decoration: const InputDecoration(
                                labelText: 'Path Cover (URL atau Asset Path)',
                                hintText: 'contoh: assets/img/c1.jpg',
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _filePathController,
                              decoration: const InputDecoration(
                                labelText: 'Path Audio (URL atau Asset Path)',
                                hintText: 'contoh: assets/songs/song.wav',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _isLoading ? null : _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.accentHot,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: _isLoading
                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Text(
                                    isEdit ? 'Simpan Perubahan' : 'Upload Sekarang',
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputCard({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card.withOpacity(0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: AppColors.accentHot,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }
}
