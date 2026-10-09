import 'package:flutter/material.dart';

import 'app.dart';
import 'databases/local_db.dart';

void main() {
  runApp(SmartAccountingApp(db: LocalDb()));
}
