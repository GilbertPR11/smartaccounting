import '../config/constants.dart';
import '../databases/local_db.dart';
import '../exception/app_exception.dart';
import '../models/business_profile_model.dart';
import '../models/invoice_template_model.dart';

/// Business profile, invoice design and other single-row settings.
class SettingRepository {
  SettingRepository(this._db);

  final LocalDb _db;

  Stream<void> get changes => _db.changes.where((t) => t == DbTable.settings);

  // Read-only values used synchronously across the app.
  DateTime get today => _db.today;
  double get openingBalance => _db.openingBalance;
  List<String> get accounts => List.unmodifiable(_db.accounts);

  Future<BusinessProfile> fetchProfile() async => _db.profile;

  Future<InvoiceTemplate> fetchInvoiceTemplate() async => _db.invoiceTemplate;

  /// Saves both together so the invoice header and design never disagree.
  Future<void> saveInvoiceSettings({
    required BusinessProfile profile,
    required InvoiceTemplate template,
  }) async {
    if (profile.name.trim().isEmpty) {
      throw const AppException('Business name is required.');
    }
    if (template.title.trim().isEmpty) {
      throw const AppException('Invoice title cannot be empty.');
    }
    final logo = template.logoBytes;
    if (logo != null && logo.length > Constants.maxLogoBytes) {
      throw const AppException('Logo is too large. Please use an image under 2 MB.');
    }
    _db.transaction({DbTable.settings}, () {
      _db.profile = profile.copyWith(name: profile.name.trim());
      _db.invoiceTemplate = template;
    });
  }
}
