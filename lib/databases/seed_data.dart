import '../config/constants.dart';
import '../models/bill_model.dart';
import '../models/business_profile_model.dart';
import '../models/customer_model.dart';
import '../models/estimate_model.dart';
import '../models/journal_model.dart';
import '../models/invoice_model.dart';
import '../models/product_model.dart';
import '../models/recurring_invoice_model.dart';
import '../models/tag_model.dart';
import '../models/transaction_model.dart';
import '../models/vendor_model.dart';
import '../utils/format.dart';
import 'local_db.dart';

/// Demo data so every screen has something to show. Delete once the app
/// reads real data.
class SeedData {
  SeedData._();

  static void apply(LocalDb db) {
    final today = db.today;
    DateTime ago(int days) => today.subtract(Duration(days: days));
    final sst8 = Constants.taxes.first;
    const bank = 'Maybank Current';

    // Sample business (placeholder details, not a real company).
    db.profile = const BusinessProfile(
      name: 'My Business Sdn Bhd',
      address: 'Level 5, Wisma Contoh, Jalan Contoh 1, 50450 Kuala Lumpur',
      email: 'billing@mybusiness.example',
      phone: '+60 3-0000 0000',
      registrationNo: '000000000000 (0000000-X)',
      sstNo: 'W10-0000-00000000',
    );
    db.invoiceTemplate = db.invoiceTemplate.copyWith(
      paymentInstructions:
          'Bank transfer to Maybank 0000 0000 0000 (My Business Sdn Bhd). '
          'Please quote the invoice number as reference.',
    );

    Customer customer(String name, {String email = '', String phone = '', String address = ''}) {
      final c = Customer(
          id: db.newId('c'), name: name, email: email, phone: phone, address: address);
      db.customers[c.id] = c;
      return c;
    }

    Product product(String name, double price, {String description = ''}) {
      final p = Product(
          id: db.newId('p'), name: name, description: description, price: price, tax: sst8);
      db.products[p.id] = p;
      return p;
    }

    BankTransaction txn(int daysAgo, String desc, double amount, TransactionType type,
        String category,
        {String account = bank, String? customerId, String? invoiceId, String? billId}) {
      final t = BankTransaction(
        id: db.newId('t'),
        date: ago(daysAgo),
        description: desc,
        amount: amount,
        type: type,
        account: account,
        category: category,
        customerId: customerId,
        invoiceId: invoiceId,
        billId: billId,
      );
      db.transactions[t.id] = t;
      return t;
    }

    InvoiceLine line(Product p, [double qty = 1]) => InvoiceLine(
        productId: p.id, description: p.name, quantity: qty, unitPrice: p.price, tax: p.tax);

    Invoice invoice(Customer c, DateTime issue, DateTime due, List<InvoiceLine> lines,
        {String notes = '',
        String? sourceId,
        double paid = 0,
        String? estimateId,
        String? recurringId}) {
      final inv = Invoice(
        id: db.newId('i'),
        number: 'INV-${db.invoiceCounter.toString().padLeft(4, '0')}',
        customerId: c.id,
        issueDate: dateOnly(issue),
        dueDate: dateOnly(due),
        lines: lines,
        notes: notes,
        sourceTransactionId: sourceId,
        amountPaid: paid,
        estimateId: estimateId,
        recurringId: recurringId,
      );
      db.invoices[inv.id] = inv;
      db.invoiceCounter++;
      return inv;
    }

    void link(BankTransaction t, Invoice inv) =>
        db.transactions[t.id] = t.linkTo(invoiceId: inv.id, customerId: inv.customerId);

    Estimate estimate(Customer c, int issuedAgo, int validDays, List<InvoiceLine> lines,
        {EstimateDecision? decision, String notes = ''}) {
      final e = Estimate(
        id: db.newId('e'),
        number: 'EST-${db.estimateCounter.toString().padLeft(4, '0')}',
        customerId: c.id,
        issueDate: ago(issuedAgo),
        expiryDate: ago(issuedAgo).add(Duration(days: validDays)),
        lines: lines,
        notes: notes,
        decision: decision,
      );
      db.estimates[e.id] = e;
      db.estimateCounter++;
      return e;
    }

    // Customers & products.
    final tan = customer('Tan Hardware Sdn Bhd',
        email: 'accounts@tanhardware.my',
        phone: '+60 3-7781 2290',
        address: '12, Jalan SS2/24, 47300 Petaling Jaya, Selangor');
    final kopi = customer('Kopi Kita Café',
        email: 'hello@kopikita.my',
        phone: '+60 12-338 4410',
        address: '3A, Jalan Telawi 3, Bangsar, 59100 Kuala Lumpur');
    final siti = customer('Siti Design Studio',
        email: 'siti@sitidesign.my', address: 'B-5-2, Plaza Damas, 50480 Kuala Lumpur');
    final lim = customer('Lim & Co Logistics',
        email: 'finance@limco.com.my',
        address: 'Lot 8, Kawasan Perindustrian Shah Alam, 40000 Selangor');

    final bookkeeping =
        product('Monthly bookkeeping', 1200, description: 'Bookkeeping & bank reconciliation');
    final consulting = product('Consulting (per hour)', 250);
    final maintenance = product('Website maintenance', 450, description: 'Monthly plan');
    final setup = product('System setup fee', 1200, description: 'One-off');

    // Older sales invoiced FROM their transaction.
    final old1 = txn(64, 'IBG credit TAN HARDWARE SDN BHD', 2160, TransactionType.income,
        'Sales', customerId: tan.id);
    link(old1, invoice(tan, old1.date, old1.date, [line(consulting, 8)],
        sourceId: old1.id, paid: 2160));

    final old2 = txn(48, 'DuitNow transfer KOPI KITA CAFE', 1296, TransactionType.income,
        'Sales', customerId: kopi.id);
    link(old2, invoice(kopi, old2.date, old2.date, [line(bookkeeping)],
        sourceId: old2.id, paid: 1296));

    // Classic invoices (invoice first, payment later).
    invoice(siti, ago(40), ago(10), [line(consulting, 3)],
        notes: 'Thank you for your business.');
    // Lim & Co accepted a quote first; the invoice was converted from it.
    final limQuote = estimate(lim, 22, 30, [line(setup), line(maintenance)],
        decision: EstimateDecision.accepted);
    final limInv = invoice(lim, ago(15), ago(15).add(const Duration(days: 30)),
        [line(setup), line(maintenance)], paid: 500, estimateId: limQuote.id);
    db.estimates[limQuote.id] = limQuote.copyWith(invoiceId: limInv.id);
    txn(8, 'Payment for ${limInv.number}', 500, TransactionType.income, 'Sales',
        customerId: lim.id, invoiceId: limInv.id);

    // Other estimates: expired, awaiting a reply, accepted but not invoiced.
    estimate(kopi, 50, 30, [line(maintenance, 12)],
        notes: 'Annual website maintenance, billed monthly.');
    estimate(siti, 3, 30, [line(consulting, 6), line(setup)],
        notes: 'Prices valid for 30 days. 50% deposit on acceptance.');
    estimate(tan, 6, 14, [line(consulting, 10)], decision: EstimateDecision.accepted);

    // Recurring: Kopi Kita's bookkeeping, monthly from the 1st of last month.
    // Both invoices so far are issued; last month's is paid.
    final kopiPlan = RecurringInvoice(
      id: db.newId('r'),
      customerId: kopi.id,
      lines: [line(bookkeeping)],
      frequency: RecurFrequency.monthly,
      startDate: DateTime(today.year, today.month - 1, 1),
      termsDays: 14,
      notes: 'Monthly bookkeeping retainer.',
      issuedCount: 2,
    );
    db.recurring[kopiPlan.id] = kopiPlan;
    final kopiFirst = kopiPlan.occurrence(0);
    final kopiPaid = invoice(kopi, kopiFirst, kopiFirst.add(const Duration(days: 14)),
        kopiPlan.lines,
        notes: kopiPlan.notes, recurringId: kopiPlan.id, paid: 1296);
    txn(today.difference(kopiFirst).inDays - 10,
        'DuitNow transfer KOPI KITA CAFE', 1296, TransactionType.income, 'Sales',
        customerId: kopi.id, invoiceId: kopiPaid.id);
    final kopiSecond = kopiPlan.occurrence(1);
    invoice(kopi, kopiSecond, kopiSecond.add(const Duration(days: 14)), kopiPlan.lines,
        notes: kopiPlan.notes, recurringId: kopiPlan.id);

    // Siti: quarterly maintenance that starts next week (nothing issued yet).
    final sitiPlan = RecurringInvoice(
      id: db.newId('r'),
      customerId: siti.id,
      lines: [line(maintenance, 3)],
      frequency: RecurFrequency.quarterly,
      startDate: today.add(const Duration(days: 7)),
      termsDays: 30,
    );
    db.recurring[sitiPlan.id] = sitiPlan;

    // Tan Hardware: weekly on-site support, paused, at most 8 visits.
    final tanPlan = RecurringInvoice(
      id: db.newId('r'),
      customerId: tan.id,
      lines: [line(consulting, 2)],
      frequency: RecurFrequency.weekly,
      startDate: today.add(const Duration(days: 3)),
      maxCount: 8,
      termsDays: 7,
      paused: true,
    );
    db.recurring[tanPlan.id] = tanPlan;

    // Recent income NOT yet invoiced — these show up in the picker.
    txn(2, 'DuitNow transfer KOPI KITA CAFE', 1296, TransactionType.income, 'Sales',
        customerId: kopi.id);
    txn(5, 'Cash sale – walk-in customer', 350, TransactionType.income, 'Sales',
        account: 'Cash on Hand');
    txn(9, 'IBG credit TAN HARDWARE SDN BHD', 2700, TransactionType.income, 'Sales',
        customerId: tan.id);
    txn(20, 'Cheque deposit 004512', 486, TransactionType.income, 'Sales');
    // Not a sale — must never be invoiceable.
    txn(25, 'Owner capital injection', 5000, TransactionType.income, 'Owner Investment');

    // Expenses.
    for (final (d, desc, amt, cat) in [
      (6, 'TNB electricity bill', 412.30, 'Utilities'),
      (12, 'Software subscription', 189.0, 'Software'),
      (15, 'Office supplies – Popular', 96.50, 'Office Supplies'),
      (33, 'Office rent – September', 2500.0, 'Rent'),
      (37, 'TNB electricity bill', 389.10, 'Utilities'),
      (62, 'Office rent – August', 2500.0, 'Rent'),
    ]) {
      txn(d, desc, amt, TransactionType.expense, cat);
    }

    // ------------------------------------------------ vendors & bills
    Vendor vendor(String name, String category, {String email = '', String phone = ''}) {
      final v = Vendor(
          id: db.newId('v'), name: name, email: email, phone: phone, defaultCategory: category);
      db.vendors[v.id] = v;
      return v;
    }

    Bill bill(Vendor v, String number, int issuedAgo, int dueAgo, List<BillLine> lines,
        {double paid = 0, String notes = ''}) {
      final b = Bill(
        id: db.newId('b'),
        vendorId: v.id,
        number: number,
        issueDate: ago(issuedAgo),
        dueDate: ago(dueAgo),
        lines: lines,
        amountPaid: paid,
        notes: notes,
      );
      db.bills[b.id] = b;
      return b;
    }

    final landlord = vendor('Wisma Contoh Properties', 'Rent',
        email: 'leasing@wismacontoh.example', phone: '+60 3-0000 1111');
    final tnb = vendor('Tenaga Nasional (TNB)', 'Utilities');
    final printer = vendor('Kedai Cetak Jaya', 'Marketing', phone: '+60 12-000 2222');
    final cloud = vendor('CloudHost Asia', 'Software', email: 'billing@cloudhost.example');
    vendor('Popular Book Co', 'Office Supplies');

    // October rent: billed, then paid — the payment links back to the bill.
    final octRent = bill(landlord, 'WCP-1024', 10, 3,
        const [BillLine(description: 'Office rent – October', category: 'Rent', amount: 2500)],
        paid: 2500);
    txn(3, 'Payment for WCP-1024', 2500, TransactionType.expense, 'Rent', billId: octRent.id);

    // November rent: billed, not due yet.
    bill(landlord, 'WCP-1124', 2, -24,
        const [BillLine(description: 'Office rent – November', category: 'Rent', amount: 2500)]);

    // Electricity: due soon.
    bill(tnb, '220-0098-1123', 4, -9,
        const [BillLine(description: 'Electricity – September usage', category: 'Utilities', amount: 398.60)]);

    // Printing: overdue.
    bill(printer, 'KCJ-3391', 35, 5, [
      BillLine(description: 'Flyers, 2,000 pcs', category: 'Marketing', amount: 450, tax: sst8),
      BillLine(description: 'Name cards, 4 boxes', category: 'Marketing', amount: 150, tax: sst8),
    ]);

    // Hosting: partly paid.
    final hosting = bill(cloud, 'CH-77812', 20, -5,
        [BillLine(description: 'Annual hosting plan', category: 'Software', amount: 1200, tax: sst8)],
        paid: 400);
    txn(18, 'Payment for CH-77812', 400, TransactionType.expense, 'Software', billId: hosting.id);

    // Things you buy (shown when adding bill lines).
    for (final (name, cost, category) in [
      ('Printer paper A4 (box of 5)', 62.0, 'Office Supplies'),
      ('Business cards (box)', 37.5, 'Marketing'),
    ]) {
      final p = Product(
        id: db.newId('p'),
        name: name,
        price: 0,
        sold: false,
        bought: true,
        purchasePrice: cost,
        expenseCategory: category,
      );
      db.products[p.id] = p;
    }

    // ------------------------------------------------ ledger extras
    String accountId(String name) =>
        db.chart.values.firstWhere((a) => a.name == name).id;

    // A non-cash adjustment: the owner paid a software renewal personally.
    final journal = JournalEntry(
      id: db.newId('j'),
      date: ago(11),
      description: 'Software renewal paid personally by the owner',
      lines: [
        JournalLine(accountId: accountId('Software'), debit: 120),
        JournalLine(accountId: accountId('Owner Investment'), credit: 120),
      ],
    );
    db.journals[journal.id] = journal;

    // A tag on the utility and rent payments of the office.
    const office = Tag(id: 'g-office', name: 'KL office');
    db.tags[office.id] = office;
    for (final t in db.transactions.values.toList()) {
      if (!t.isIncome && (t.category == 'Rent' || t.category == 'Utilities')) {
        db.transactions[t.id] = t.copyWith(tagIds: [office.id]);
      }
    }
  }
}
