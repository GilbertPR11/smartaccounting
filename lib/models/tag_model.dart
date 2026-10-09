import 'package:equatable/equatable.dart';

/// A free label for grouping transactions across categories, e.g. a project
/// or a branch ("Bangsar outlet", "Project Lim").
class Tag extends Equatable {
  const Tag({required this.id, required this.name});

  final String id;
  final String name;

  @override
  List<Object?> get props => [id, name];
}
