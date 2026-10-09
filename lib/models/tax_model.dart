import 'package:equatable/equatable.dart';

class Tax extends Equatable {
  const Tax({required this.id, required this.name, required this.rate});

  final String id;
  final String name;

  /// 0.08 == 8%
  final double rate;

  String get label => '$name ${(rate * 100).toStringAsFixed(0)}%';

  @override
  List<Object?> get props => [id, name, rate];
}
