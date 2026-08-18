import '../models/course.dart';

enum CourseMatchStatus {
  matched,
  notFound,
  ambiguous,
}

class CourseMatchResult {
  const CourseMatchResult({
    required this.status,
    this.course,
  });

  final CourseMatchStatus status;
  final Course? course;
}

CourseMatchResult findCourse(List<Course> courses, CourseTarget target) {
  final matches = _matchingCourses(courses, target);
  if (matches.isEmpty) {
    return const CourseMatchResult(status: CourseMatchStatus.notFound);
  }
  if (matches.length > 1) {
    return const CourseMatchResult(status: CourseMatchStatus.ambiguous);
  }
  return CourseMatchResult(
    status: CourseMatchStatus.matched,
    course: matches.single,
  );
}

List<CourseTarget> sortTargetsByPriority(List<CourseTarget> targets) {
  final sorted = List<CourseTarget>.of(targets);
  sorted.sort((left, right) => left.priority.compareTo(right.priority));
  return sorted;
}

List<Course> _matchingCourses(List<Course> courses, CourseTarget target) {
  final targetCourse = _norm(target.courseCode);
  final targetClass = _norm(target.classCode);
  final targetGroup = _norm(target.groupCode);

  final exactClass = targetClass.isEmpty
      ? <Course>[]
      : courses
          .where((course) => _norm(course.classCode) == targetClass)
          .toList(growable: false);
  if (exactClass.isNotEmpty) {
    return exactClass;
  }

  final exactGroup = targetGroup.isEmpty
      ? <Course>[]
      : courses
          .where(
            (course) =>
                _norm(course.courseCode) == targetCourse &&
                _norm(course.groupCode) == targetGroup,
          )
          .toList(growable: false);
  if (exactGroup.isNotEmpty) {
    return exactGroup;
  }

  return courses
      .where((course) => _norm(course.courseCode) == targetCourse)
      .toList(growable: false);
}

String _norm(String? value) => (value ?? '').trim().toUpperCase();
