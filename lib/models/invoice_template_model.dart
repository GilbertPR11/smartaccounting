import 'dart:typed_data';

import 'package:equatable/equatable.dart';

enum InvoiceLayout { classic, modern, compact }

extension InvoiceLayoutLabel on InvoiceLayout {
  String get label => switch (this) {
        InvoiceLayout.classic => 'Classic',
        InvoiceLayout.modern => 'Modern',
        InvoiceLayout.compact => 'Compact',
      };
}

enum LogoSize { small, medium, large }

extension LogoSizeValue on LogoSize {
  String get label => switch (this) {
        LogoSize.small => 'S',
        LogoSize.medium => 'M',
        LogoSize.large => 'L',
      };

  /// Logo height in logical pixels on the invoice.
  double get height => switch (this) {
        LogoSize.small => 36,
        LogoSize.medium => 56,
        LogoSize.large => 80,
      };
}

/// How invoices look: one per business. Every field has a default, so
/// `const InvoiceTemplate()` is the out-of-the-box design.
///
/// Kept free of Flutter types (colour is an ARGB int) so it can be saved to
/// sqflite / sent to an API as-is later.
class InvoiceTemplate extends Equatable {
  const InvoiceTemplate({
    this.layout = InvoiceLayout.classic,
    this.accentColor = 0xFF0F766E,
    this.title = 'INVOICE',
    this.logoBytes,
    this.logoVersion = 0,
    this.logoSize = LogoSize.medium,
    this.showLogo = true,
    this.showBusinessAddress = true,
    this.showBusinessContact = true,
    this.showRegistrationNo = true,
    this.showSstNo = true,
    this.showCustomerAddress = true,
    this.showCustomerEmail = false,
    this.showDueDate = true,
    this.showQuantityColumns = true,
    this.showLineTax = true,
    this.showTaxBreakdown = true,
    this.showAmountPaid = true,
    this.showNotes = true,
    this.showPaymentInstructions = true,
    this.paymentInstructions = '',
    this.showFooter = true,
    this.footerText = 'Thank you for your business.',
  });

  final InvoiceLayout layout;
  final int accentColor;
  final String title;

  /// PNG/JPEG bytes of the uploaded logo, or null.
  final Uint8List? logoBytes;

  /// Bumped whenever [logoBytes] changes. Used for equality instead of
  /// comparing the whole image byte-by-byte on every state change.
  final int logoVersion;
  final LogoSize logoSize;

  // Header.
  final bool showLogo;
  final bool showBusinessAddress;
  final bool showBusinessContact;
  final bool showRegistrationNo;
  final bool showSstNo;

  // Bill to.
  final bool showCustomerAddress;
  final bool showCustomerEmail;
  final bool showDueDate;

  // Items & totals.
  final bool showQuantityColumns;
  final bool showLineTax;
  final bool showTaxBreakdown;
  final bool showAmountPaid;

  // Bottom.
  final bool showNotes;
  final bool showPaymentInstructions;
  final String paymentInstructions;
  final bool showFooter;
  final String footerText;

  bool get hasLogo => logoBytes != null && logoBytes!.isNotEmpty;

  InvoiceTemplate copyWith({
    InvoiceLayout? layout,
    int? accentColor,
    String? title,
    Uint8List? logoBytes,
    bool clearLogo = false,
    LogoSize? logoSize,
    bool? showLogo,
    bool? showBusinessAddress,
    bool? showBusinessContact,
    bool? showRegistrationNo,
    bool? showSstNo,
    bool? showCustomerAddress,
    bool? showCustomerEmail,
    bool? showDueDate,
    bool? showQuantityColumns,
    bool? showLineTax,
    bool? showTaxBreakdown,
    bool? showAmountPaid,
    bool? showNotes,
    bool? showPaymentInstructions,
    String? paymentInstructions,
    bool? showFooter,
    String? footerText,
  }) {
    final logoChanged = clearLogo || logoBytes != null;
    return InvoiceTemplate(
      layout: layout ?? this.layout,
      accentColor: accentColor ?? this.accentColor,
      title: title ?? this.title,
      logoBytes: clearLogo ? null : (logoBytes ?? this.logoBytes),
      logoVersion: logoChanged ? logoVersion + 1 : logoVersion,
      logoSize: logoSize ?? this.logoSize,
      showLogo: showLogo ?? this.showLogo,
      showBusinessAddress: showBusinessAddress ?? this.showBusinessAddress,
      showBusinessContact: showBusinessContact ?? this.showBusinessContact,
      showRegistrationNo: showRegistrationNo ?? this.showRegistrationNo,
      showSstNo: showSstNo ?? this.showSstNo,
      showCustomerAddress: showCustomerAddress ?? this.showCustomerAddress,
      showCustomerEmail: showCustomerEmail ?? this.showCustomerEmail,
      showDueDate: showDueDate ?? this.showDueDate,
      showQuantityColumns: showQuantityColumns ?? this.showQuantityColumns,
      showLineTax: showLineTax ?? this.showLineTax,
      showTaxBreakdown: showTaxBreakdown ?? this.showTaxBreakdown,
      showAmountPaid: showAmountPaid ?? this.showAmountPaid,
      showNotes: showNotes ?? this.showNotes,
      showPaymentInstructions: showPaymentInstructions ?? this.showPaymentInstructions,
      paymentInstructions: paymentInstructions ?? this.paymentInstructions,
      showFooter: showFooter ?? this.showFooter,
      footerText: footerText ?? this.footerText,
    );
  }

  /// Back to the default design, keeping the uploaded logo and the texts.
  InvoiceTemplate resetDesign() => const InvoiceTemplate().copyWith(
        title: title,
        paymentInstructions: paymentInstructions,
        footerText: footerText,
      )._withLogo(logoBytes, logoVersion + 1);

  InvoiceTemplate _withLogo(Uint8List? bytes, int version) => InvoiceTemplate(
        layout: layout,
        accentColor: accentColor,
        title: title,
        logoBytes: bytes,
        logoVersion: version,
        logoSize: logoSize,
        showLogo: showLogo,
        showBusinessAddress: showBusinessAddress,
        showBusinessContact: showBusinessContact,
        showRegistrationNo: showRegistrationNo,
        showSstNo: showSstNo,
        showCustomerAddress: showCustomerAddress,
        showCustomerEmail: showCustomerEmail,
        showDueDate: showDueDate,
        showQuantityColumns: showQuantityColumns,
        showLineTax: showLineTax,
        showTaxBreakdown: showTaxBreakdown,
        showAmountPaid: showAmountPaid,
        showNotes: showNotes,
        showPaymentInstructions: showPaymentInstructions,
        paymentInstructions: paymentInstructions,
        showFooter: showFooter,
        footerText: footerText,
      );

  @override
  List<Object?> get props => [
        layout,
        accentColor,
        title,
        logoVersion,
        logoSize,
        showLogo,
        showBusinessAddress,
        showBusinessContact,
        showRegistrationNo,
        showSstNo,
        showCustomerAddress,
        showCustomerEmail,
        showDueDate,
        showQuantityColumns,
        showLineTax,
        showTaxBreakdown,
        showAmountPaid,
        showNotes,
        showPaymentInstructions,
        paymentInstructions,
        showFooter,
        footerText,
      ];
}
