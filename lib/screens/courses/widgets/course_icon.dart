import 'package:flutter/material.dart';

import '../../../services/courses_service.dart';

/// The colored, rounded square showing a course's initials — used on the
/// courses list, the Add Course preview card, and Course Detail's header.
class CourseIcon extends StatelessWidget {
  const CourseIcon({
    super.key,
    required this.color,
    required this.courseName,
    this.size = 48,
  });

  final Color color;
  final String courseName;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size / 3),
      ),
      child: Text(
        courseInitials(courseName),
        style: TextStyle(
          fontSize: size * 0.31,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    );
  }
}
