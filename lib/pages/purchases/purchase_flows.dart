import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../components/vendor_dialog.dart';
import '../../exception/app_exception.dart';
import '../../models/bill_model.dart';
import '../../models/receipt_model.dart';
import '../../repository/receipt_repository.dart';
import '../../routes/routes.dart';

/// Navigation flows for Purchases, shared by every "add" button.

Future<void> showAddPurchaseSheet(BuildContext context) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('New bill'),
            subtitle: const Text('Something you owe a vendor and will pay later'),
            onTap: () => Navigator.pop(ctx, 'bill'),
          ),
          ListTile(
            leading: const Icon(Icons.document_scanner_outlined),
            title: const Text('Add a receipt'),
            subtitle: const Text('A photo of something you already paid for'),
            onTap: () => Navigator.pop(ctx, 'receipt'),
          ),
          ListTile(
            leading: const Icon(Icons.storefront_outlined),
            title: const Text('New vendor'),
            subtitle: const Text('Someone you buy from'),
            onTap: () => Navigator.pop(ctx, 'vendor'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (!context.mounted) return;
  switch (choice) {
    case 'bill':
      await openBillForm(context);
    case 'receipt':
      await captureReceipt(context);
    case 'vendor':
      await showAddVendorDialog(context);
  }
}

Future<void> openBillDetail(BuildContext context, String billId) =>
    Navigator.pushNamed(context, PageRoutes.billDetail, arguments: BillDetailArgs(billId));

/// Opens the bill form; on save, shows the new bill.
Future<void> openBillForm(
  BuildContext context, {
  String? vendorId,
  Receipt? receipt,
  bool replace = false,
}) async {
  final bill = await Navigator.pushNamed<Bill>(
    context,
    PageRoutes.billForm,
    arguments: BillFormArgs(vendorId: vendorId, receiptId: receipt?.id, receipt: receipt),
  );
  if (bill == null || !context.mounted) return;
  final args = BillDetailArgs(bill.id, justCreated: true);
  if (replace) {
    Navigator.pushReplacementNamed(context, PageRoutes.billDetail, arguments: args);
  } else {
    Navigator.pushNamed(context, PageRoutes.billDetail, arguments: args);
  }
}

bool get _hasCamera =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// Take or choose a receipt photo, save it to "To review", then open it.
Future<void> captureReceipt(BuildContext context) async {
  ImageSource? source = ImageSource.gallery;
  if (_hasCamera) {
    source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from photos'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
  if (source == null || !context.mounted) return;

  try {
    // Downscaled on pick: readable, but small enough to keep many receipts.
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 80,
    );
    if (file == null || !context.mounted) return;
    final bytes = await file.readAsBytes();
    if (!context.mounted) return;
    final receipt = await context.read<ReceiptRepository>().addReceipt(bytes);
    if (!context.mounted) return;
    await Navigator.pushNamed(context, PageRoutes.receipt, arguments: receipt.id);
  } on AppException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not open the camera or photos: $e')));
    }
  }
}
