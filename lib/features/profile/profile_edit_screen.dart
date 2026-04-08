import 'package:flutter/material.dart';
import 'package:student_survivor/core/localization/app_localizations.dart';
import 'package:student_survivor/core/mvp/presenter_state.dart';
import 'package:student_survivor/data/college_service.dart';
import 'package:student_survivor/data/supabase_config.dart';
import 'package:student_survivor/features/profile/profile_edit_presenter.dart';
import 'package:student_survivor/features/profile/profile_edit_view_model.dart';
import 'package:student_survivor/models/app_models.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState
    extends PresenterState<ProfileEditScreen, ProfileEditView,
        ProfileEditPresenter>
    implements ProfileEditView {
  late final TextEditingController _nameController;
  late final CollegeService _collegeService;
  List<College> _colleges = const [];
  College? _selectedCollege;
  bool _isCollegeLoading = false;

  @override
  ProfileEditPresenter createPresenter() => ProfileEditPresenter();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: presenter.state.value.fullName,
    );
    _nameController.addListener(() {
      presenter.updateName(_nameController.text);
    });
    _collegeService = CollegeService(SupabaseConfig.client);
    _loadColleges();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  InputDecoration _darkInputDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white54),
      filled: true,
      fillColor: const Color(0xFF111B2E),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF1E2A44)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.4),
      ),
    );
  }

  @override
  void close() {
    Navigator.of(context).pop();
  }

  Future<void> _openCollegePicker() async {
    if (_colleges.isEmpty) return;
    final selected = await showModalBottomSheet<College>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final controller = TextEditingController();
        var filtered = List<College>.from(_colleges);
        return StatefulBuilder(
          builder: (context, setModalState) {
            void applyFilter(String value) {
              final query = value.trim().toLowerCase();
              setModalState(() {
                if (query.isEmpty) {
                  filtered = List<College>.from(_colleges);
                } else {
                  filtered = _colleges
                      .where(
                        (college) =>
                            college.name.toLowerCase().contains(query),
                      )
                      .toList();
                }
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: _GameCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('Select College', 'कलेज छान्नुहोस्'),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      style: const TextStyle(color: Colors.white),
                      cursorColor: const Color(0xFF38BDF8),
                      decoration: _darkInputDecoration(
                        context.tr('Search college', 'कलेज खोज्नुहोस्'),
                      ),
                      onChanged: applyFilter,
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 360),
                      child: filtered.isEmpty
                          ? Text(
                              context.tr(
                                'No colleges found.',
                                'कलेज भेटिएन।',
                              ),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.white70),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(color: Color(0xFF1E2A44)),
                              itemBuilder: (context, index) {
                                final college = filtered[index];
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    college.name,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  onTap: () =>
                                      Navigator.of(context).pop(college),
                                );
                              },
                            ),
                    ),
                  ],
                ),
                ),
              ),
            );
          },
        );
      },
    );

    if (selected != null) {
      setState(() {
        _selectedCollege = selected;
      });
      presenter.updateCollege(selected.name);
    }
  }

  Future<void> _loadColleges() async {
    setState(() {
      _isCollegeLoading = true;
    });
    try {
      final colleges = await _collegeService.fetchColleges();
      if (!mounted) return;
      final current = presenter.state.value.collegeName.trim();
      final hasCurrent = colleges.any(
        (college) => college.name.toLowerCase() == current.toLowerCase(),
      );
      final enriched = !hasCurrent && current.isNotEmpty
          ? [
              College(id: 'current', name: current, isActive: true),
              ...colleges,
            ]
          : colleges;
      final selected = current.isEmpty
          ? null
          : enriched.firstWhere(
              (college) =>
                  college.name.toLowerCase() == current.toLowerCase(),
              orElse: () => enriched.first,
            );
      setState(() {
        _colleges = enriched;
        _selectedCollege = selected;
        _isCollegeLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isCollegeLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF070B14),
      appBar: AppBar(
        title: Text(
          context.tr('Edit Profile', 'प्रोफाइल सम्पादन'),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: ValueListenableBuilder<ProfileEditViewModel>(
        valueListenable: presenter.state,
        builder: (context, model, _) {
          if (model.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
            );
          }

          if (model.errorMessage != null) {
            return Stack(
              children: [
                const Positioned.fill(child: _ProfileEditBackdrop()),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      model.errorMessage!,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.white70),
                    ),
                  ),
                ),
              ],
            );
          }

          return Stack(
            children: [
              const Positioned.fill(child: _ProfileEditBackdrop()),
              ListView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  MediaQuery.of(context).padding.top +
                      kToolbarHeight +
                      -44,
                  20,
                  28,
                ),
                children: [
                  _GameCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('Profile Info', 'प्रोफाइल जानकारी'),
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _nameController,
                          style: const TextStyle(color: Colors.white),
                          cursorColor: const Color(0xFF38BDF8),
                          decoration: _darkInputDecoration(
                            context.tr('Full name', 'पुरा नाम'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_isCollegeLoading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: LinearProgressIndicator(minHeight: 2),
                          )
                        else
                          InkWell(
                            onTap: _openCollegePicker,
                            borderRadius: BorderRadius.circular(14),
                            child: InputDecorator(
                              decoration: _darkInputDecoration(
                                context.tr('College name', 'कलेजको नाम'),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _selectedCollege?.name ??
                                          context.tr(
                                            'Select college',
                                            'कलेज छान्नुहोस्',
                                          ),
                                      style: TextStyle(
                                        color: _selectedCollege == null
                                            ? Colors.white54
                                            : Colors.white,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.search,
                                    color: Colors.white70,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        TextField(
                          readOnly: true,
                          style: const TextStyle(color: Colors.white),
                          decoration: _darkInputDecoration(
                            context.tr('Email', 'इमेल'),
                            hint: model.email,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _GameCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('Semester', 'सेमेस्टर'),
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<Semester>(
                          initialValue: model.selectedSemester,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF0B1220),
                          style: const TextStyle(color: Colors.white),
                          iconEnabledColor: Colors.white70,
                          decoration: _darkInputDecoration(
                            context.tr('Select semester', 'सेमेस्टर छान्नुहोस्'),
                          ),
                          items: model.semesters
                              .map(
                                (semester) => DropdownMenuItem(
                                  value: semester,
                                  child: Text(
                                    semester.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (Semester? semester) {
                            if (semester != null) {
                              presenter.selectSemester(semester);
                            }
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.tr(
                            'All subjects in this semester will be available in Play.',
                            'यस सेमेस्टरका सबै विषय Play मा उपलब्ध हुनेछन्।',
                          ),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _PrimaryActionButton(
                    label: context.tr('Save Changes', 'परिवर्तन सुरक्षित गर्नुहोस्'),
                    enabled: model.canSave,
                    onPressed: model.canSave ? presenter.save : null,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileEditBackdrop extends StatelessWidget {
  const _ProfileEditBackdrop();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF070B14),
            Color(0xFF0B1324),
            Color(0xFF101C2E),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: const [
          Positioned.fill(child: CustomPaint(painter: _ProfileEditGrid())),
          Positioned(
            top: -140,
            right: -80,
            child: _GlowOrb(size: 280, color: Color(0x3322D3EE)),
          ),
          Positioned(
            bottom: -120,
            left: -60,
            child: _GlowOrb(size: 240, color: Color(0x334F46E5)),
          ),
          Positioned(
            top: 160,
            left: 40,
            child: _GlowOrb(size: 180, color: Color(0x332DD4BF)),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: 80,
            spreadRadius: 16,
          ),
        ],
      ),
    );
  }
}

class _ProfileEditGrid extends CustomPainter {
  const _ProfileEditGrid();

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF1E293B).withValues(alpha: 0.4)
      ..strokeWidth = 1;
    const gap = 52.0;
    for (double x = 0; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    final glowPaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final rect = Rect.fromLTWH(
      size.width * 0.08,
      size.height * 0.08,
      size.width * 0.84,
      size.height * 0.76,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(28)),
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProfileEditGrid oldDelegate) => false;
}

class _GameCard extends StatelessWidget {
  final Widget child;

  const _GameCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF22D3EE),
            Color(0xFF38BDF8),
            Color(0xFF4F46E5),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0B1220),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF1E2A44)),
        ),
        child: child,
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback? onPressed;

  const _PrimaryActionButton({
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF38BDF8),
              Color(0xFF4F46E5),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: enabled ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1),
          ),
        ),
      ),
    );
  }
}
