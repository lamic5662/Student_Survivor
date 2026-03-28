import 'package:flutter/material.dart';
import 'package:student_survivor/core/mvp/presenter_state.dart';
import 'package:student_survivor/core/widgets/app_card.dart';
import 'package:student_survivor/core/widgets/section_header.dart';
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
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  void close() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
      ),
      body: ValueListenableBuilder<ProfileEditViewModel>(
        valueListenable: presenter.state,
        builder: (context, model, _) {
          if (model.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (model.errorMessage != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(model.errorMessage!),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(title: 'Profile Info'),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Full name'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        hintText: model.email,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(title: 'Semester'),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<Semester>(
                      value: model.selectedSemester,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Select semester',
                      ),
                      items: model.semesters
                          .map(
                            (semester) => DropdownMenuItem(
                              value: semester,
                              child: Text(semester.name),
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
                      'All subjects in this semester will be available in Play.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: model.canSave ? presenter.save : null,
                  child: const Text('Save Changes'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
