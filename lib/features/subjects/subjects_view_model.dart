import 'package:student_survivor/models/app_models.dart';

class SubjectsViewModel {
  final String semesterName;
  final List<Subject> subjects;

  const SubjectsViewModel({
    required this.semesterName,
    required this.subjects,
  });
}
