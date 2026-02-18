# com_accountdata — Ecosystem Role & API

## Extension Purpose

Central accounting and financial data layer for the Emporium ecosystem. Manages all financial records, invoices, orders, payments, transactions, and pricing so multiple extensions can share the same accounting source without duplication.

**Type**: Data Access Layer
**Scope**: Financial records and accounting data
**Status**: Core data provider

---

## Data Managed

### Entities
- **Invoice** — Sales and purchase invoices
- **Order** — Sales orders and purchase orders
- **Payment** — Payment records and receipts
- **Transaction** — Ledger transactions and journal entries
- **Pricing** — Product pricing, tiered pricing, pricing rules
- **TaxRate** — Tax configuration and rules
- **Currency** — Currency exchange rates and settings
- **Account** — General ledger accounts

### Data Sources
- Invoices table: `#__accountdata_invoices`
- Orders table: `#__accountdata_orders`
- Payments table: `#__accountdata_payments`
- Transactions table: `#__accountdata_transactions`
- Pricing table: `#__accountdata_pricing`
- Tax rates table: `#__accountdata_tax_rates`
- Currencies table: `#__accountdata_currencies`
- GL Accounts table: `#__accountdata_gl_accounts`

---

## Provided Services (Public API)

### Repositories

**InvoiceRepository**
```php
namespace Emporium\AccountData\Repository;

interface InvoiceRepository {
    // Retrieve
    public function getInvoice(int $id): Invoice;
    public function getInvoices(?InvoiceFilter $filter = null): InvoiceCollection;
    public function getInvoiceByNumber(string $number): ?Invoice;
    public function getInvoicesByCustomer(int $customerId): InvoiceCollection;
    public function getInvoicesByDateRange(\DatePeriod $period): InvoiceCollection;

    // Create/Update
    public function save(Invoice $invoice): int;
    public function updateStatus(int $invoiceId, string $status): void;
    public function void(int $invoiceId, string $reason): void;
    public function delete(int $id): void;

    // Line items
    public function getLineItems(int $invoiceId): LineItemCollection;
    public function addLineItem(int $invoiceId, LineItem $item): void;
    public function removeLineItem(int $invoiceId, int $lineItemId): void;

    // Payments
    public function getPayments(int $invoiceId): PaymentCollection;
    public function getRemainingBalance(int $invoiceId): float;
}
```

**OrderRepository**
```php
namespace Emporium\AccountData\Repository;

interface OrderRepository {
    // Retrieve
    public function getOrder(int $id): Order;
    public function getOrders(?OrderFilter $filter = null): OrderCollection;
    public function getOrderByNumber(string $number): ?Order;
    public function getOrdersByCustomer(int $customerId): OrderCollection;
    public function getOrdersByStatus(string $status): OrderCollection;

    // Create/Update
    public function save(Order $order): int;
    public function updateStatus(int $orderId, string $status): void;
    public function cancel(int $orderId, string $reason): void;
    public function delete(int $id): void;

    // Line items
    public function getLineItems(int $orderId): LineItemCollection;
    public function addLineItem(int $orderId, LineItem $item): void;
    public function removeLineItem(int $orderId, int $lineItemId): void;

    // Totals
    public function getOrderTotal(int $orderId): OrderTotal;  // Subtotal, tax, shipping, total
}
```

**PaymentRepository**
```php
namespace Emporium\AccountData\Repository;

interface PaymentRepository {
    // Retrieve
    public function getPayment(int $id): Payment;
    public function getPayments(?PaymentFilter $filter = null): PaymentCollection;
    public function getPaymentsForInvoice(int $invoiceId): PaymentCollection;
    public function getPaymentsForOrder(int $orderId): PaymentCollection;

    // Create/Update
    public function save(Payment $payment): int;
    public function updateStatus(int $paymentId, string $status): void;
    public function refund(int $paymentId, float $amount, string $reason): int;  // Returns refund ID
    public function delete(int $id): void;

    // Reconciliation
    public function getPendingPayments(): PaymentCollection;
    public function getUnreconciledPayments(): PaymentCollection;
}
```

**PricingRepository**
```php
namespace Emporium\AccountData\Repository;

interface PricingRepository {
    // Retrieve pricing
    public function getPricing(int $itemId, int $customerId = null): Pricing;
    public function getPricingByCode(string $code): ?Pricing;

    // Apply pricing rules
    public function getPrice(int $itemId, int $quantity = 1, int $customerId = null): float;
    public function getPriceTier(int $itemId, int $quantity): ?PricingTier;

    // Create/Update
    public function save(Pricing $pricing): int;
    public function updatePrice(int $pricingId, float $newPrice): void;
    public function delete(int $id): void;

    // Bulk
    public function getPricingForItems(array $itemIds): PricingCollection;
}
```

**TransactionRepository**
```php
namespace Emporium\AccountData\Repository;

interface TransactionRepository {
    // Retrieve
    public function getTransaction(int $id): Transaction;
    public function getTransactions(?TransactionFilter $filter = null): TransactionCollection;
    public function getTransactionsByAccount(string $accountCode): TransactionCollection;

    // Create/Update
    public function save(Transaction $transaction): int;
    public function batch(array $transactions): int;  // Batch create, returns batch ID

    // Query
    public function getAccountBalance(string $accountCode): float;
    public function getTrialBalance(): TrialBalance;
}
```

### Business Logic Services

**InvoiceCalculationService**
```php
namespace Emporium\AccountData\Service;

interface InvoiceCalculationService {
    // Calculate totals
    public function calculateSubtotal(Invoice $invoice): float;
    public function calculateTax(Invoice $invoice): float;
    public function calculateTotal(Invoice $invoice): float;
    public function calculateDiscount(Invoice $invoice): float;

    // Apply rules
    public function applyTaxRate(Invoice $invoice, string $taxCode): float;
    public function applyDiscount(Invoice $invoice, Discount $discount): float;
    public function applyShipping(Invoice $invoice, float $shippingCost): float;
}
```

**OrderProcessingService**
```php
namespace Emporium\AccountData\Service;

interface OrderProcessingService {
    // Create from order
    public function createInvoiceFromOrder(Order $order, string $invoiceType = 'invoice'): Invoice;

    // Workflow
    public function confirmOrder(Order $order): void;
    public function completeOrder(Order $order): void;
    public function cancelOrder(Order $order, string $reason): void;

    // Reconciliation
    public function reconcileOrder(Order $order): bool;  // Check invoice vs order amounts
}
```

**PaymentProcessingService**
```php
namespace Emporium\AccountData\Service;

interface PaymentProcessingService {
    // Process payment
    public function recordPayment(Payment $payment): int;
    public function applyPaymentToInvoice(int $paymentId, int $invoiceId): void;

    // Refunds
    public function createRefund(int $paymentId, float $amount, string $reason): int;
    public function processRefund(int $refundId): void;

    // Reconciliation
    public function reconcilePayment(Payment $payment): bool;
}
```

**TaxCalculationService**
```php
namespace Emporium\AccountData\Service;

interface TaxCalculationService {
    // Calculate tax
    public function calculateTax(float $amount, string $taxCode, string $country): float;
    public function getTaxRate(string $taxCode, string $country): float;

    // Multiple items
    public function calculateTaxOnLineItems(array $lineItems, string $country): float;
}
```

---

## Events Emitted

This extension broadcasts events when financial data changes.

### Invoice Events
- **onAccountDataInvoiceCreated**
  - Data: `invoiceId`, `number`, `customerId`, `total`, `dueDate`

- **onAccountDataInvoiceUpdated**
  - Data: `invoiceId`, `changes`

- **onAccountDataInvoiceStatusChanged**
  - Data: `invoiceId`, `previousStatus`, `newStatus` (draft, sent, overdue, paid, cancelled)

- **onAccountDataInvoiceVoided**
  - Data: `invoiceId`, `reason`

- **onAccountDataInvoicePaid**
  - Data: `invoiceId`, `amountPaid`, `remainingBalance`

### Order Events
- **onAccountDataOrderCreated**
  - Data: `orderId`, `number`, `customerId`, `total`, `status`

- **onAccountDataOrderConfirmed**
  - Data: `orderId`, `number`, `total`

- **onAccountDataOrderCompleted**
  - Data: `orderId`, `number`, `invoiceId`

- **onAccountDataOrderCancelled**
  - Data: `orderId`, `reason`

### Payment Events
- **onAccountDataPaymentReceived**
  - Data: `paymentId`, `invoiceId`, `amount`, `method` (card, transfer, check, etc.)

- **onAccountDataPaymentReconciled**
  - Data: `paymentId`, `invoiceId`

- **onAccountDataRefundCreated**
  - Data: `refundId`, `originalPaymentId`, `amount`, `reason`

- **onAccountDataRefundProcessed**
  - Data: `refundId`, `amount`

### Pricing Events
- **onAccountDataPriceUpdated**
  - Data: `itemId`, `oldPrice`, `newPrice`, `effectiveDate`

- **onAccountDataTaxRateChanged**
  - Data: `taxCode`, `country`, `oldRate`, `newRate`

---

## Events Consumed

### From com_inventorydata
- Listens to: `onInventoryItemCreated`, `onInventoryItemUpdated`
- Purpose: Update item pricing/valuation in accounting records

### No consumption from com_entitydata
- AccountData maintains references to entities but doesn't need event notifications

---

## Dependencies on Other Data Layers

### com_inventorydata (Read-Only References)
- **References**: Item IDs and costs from com_inventorydata
- **Usage**: Line items reference inventory items, cost calculations use inventory costs
- **Integration**: When item cost changes in inventorydata, pricing may need adjustment

```php
// Order line item references an inventory item
class LineItem {
    public int $itemId;  // Reference to inventorydata item
    public float $unitCost;  // From inventorydata at time of order
    public string $itemName;  // Snapshot of item name
    public string $itemSku;   // Snapshot of item SKU
}
```

### com_entitydata (Read-Only References)
- **References**: Customer and Supplier IDs from com_entitydata
- **Usage**: Invoices and orders reference customers/suppliers
- **Integration**: Entity names/details are stored as snapshots (not real-time linked)

```php
// Invoice references customer from entitydata
class Invoice {
    public int $customerId;  // Reference to entitydata customer
    public string $customerName;  // Snapshot
    public string $customerAddress;  // Snapshot
}
```

---

## Extensions That Consume This Data Layer

### Primary Consumers
1. **com_emporium** (Required)
   - Uses: OrderRepository, InvoiceRepository, PricingRepository, PaymentRepository
   - Listens to: onAccountDataOrderConfirmed, onAccountDataInvoicePaid

2. **extension_invoicing** (Required)
   - Uses: InvoiceRepository, TransactionRepository, TaxCalculationService
   - Listens to: All accounting events (manages general ledger)

3. **extension_accounting** (Planned)
   - Uses: All repositories, full transaction management
   - Emits/Consumes: Full ledger reconciliation

### Secondary Consumers
4. **extension_mailing**
   - Uses: InvoiceRepository (to send invoice emails)
   - Listens to: onAccountDataInvoiceCreated (send invoice), onAccountDataPaymentReceived (payment receipt)

5. **extension_reporting**
   - Uses: TransactionRepository, InvoiceRepository (for financial reports)
   - Listens to: All events for real-time reporting

6. **com_inventorydata**
   - Uses: PricingRepository (read pricing)
   - Listens to: onAccountDataPriceUpdated (sync costs)

---

## Shared Entities

### Invoice Entity
```php
namespace Emporium\AccountData\Entity;

class Invoice {
    public int $id;
    public string $number;  // Invoice number (auto-generated or custom)
    public string $type;  // 'sales_invoice', 'purchase_invoice', 'credit_note'
    public int $customerId;  // Reference to EntityData customer
    public string $customerName;  // Snapshot
    public string $customerAddress;  // Snapshot
    public \DateTime $invoiceDate;
    public \DateTime $dueDate;
    public string $status;  // 'draft', 'sent', 'viewed', 'paid', 'overdue', 'cancelled'
    public float $subtotal;
    public float $taxAmount;
    public float $shippingCost;
    public float $discountAmount;
    public float $total;
    public float $paidAmount;
    public float $balance;  // remaining
    public string $currency;
    public string $paymentTerms;  // Net 30, Due on receipt, etc.
    public string $notes;
    public array $lineItems;  // LineItem[]
    public \DateTime $createdDate;
    public \DateTime $modifiedDate;
}
```

### Order Entity
```php
namespace Emporium\AccountData\Entity;

class Order {
    public int $id;
    public string $number;  // Order number
    public string $type;  // 'sales_order', 'purchase_order'
    public int $customerId;  // Reference to EntityData customer
    public string $customerName;  // Snapshot
    public int $billingAddressId;  // Reference to EntityData address
    public int $shippingAddressId;  // Reference to EntityData address
    public string $orderDate;
    public string $requiredDate;
    public string $shippingDate;
    public string $status;  // 'pending', 'confirmed', 'shipped', 'delivered', 'cancelled'
    public float $subtotal;
    public float $taxAmount;
    public float $shippingCost;
    public float $discountAmount;
    public float $total;
    public string $currency;
    public string $shippingMethod;  // Standard, Express, etc.
    public string $paymentMethod;  // Card, Transfer, etc.
    public string $poReference;  // PO number if provided
    public array $lineItems;  // LineItem[]
    public ?int $relatedInvoiceId;  // If invoice created from order
    public string $notes;
    public \DateTime $createdDate;
    public \DateTime $modifiedDate;
}
```

### Payment Entity
```php
namespace Emporium\AccountData\Entity;

class Payment {
    public int $id;
    public string $reference;  // Payment reference/receipt number
    public int $invoiceId;  // Which invoice this pays
    public int $customerId;  // Reference to EntityData customer
    public float $amount;
    public string $method;  // 'card', 'transfer', 'check', 'cash', 'other'
    public string $status;  // 'pending', 'reconciled', 'failed', 'refunded'
    public \DateTime $paymentDate;
    public \DateTime $reconciliationDate;
    public string $bankAccount;  // Which account received it
    public string $transactionId;  // External transaction ID
    public string $notes;
    public ?\DateTime $refundDate;
    public \DateTime $createdDate;
}
```

### Pricing Entity
```php
namespace Emporium\AccountData\Entity;

class Pricing {
    public int $id;
    public int $itemId;  // Reference to InventoryData item
    public string $code;  // Pricing code/tier
    public float $basePrice;
    public string $currency;
    public int $customerId;  // Optional: customer-specific pricing
    public int $minQuantity;  // For tiered pricing
    public int $maxQuantity;  // For tiered pricing
    public float $discountPercent;  // For tiered pricing
    public \DateTime $effectiveDate;
    public ?\DateTime $expiryDate;
    public bool $active;
    public string $notes;
}
```

### LineItem Entity
```php
namespace Emporium\AccountData\Entity;

class LineItem {
    public int $id;
    public int $orderId;  // or invoiceId
    public int $itemId;  // Reference to InventoryData item
    public string $itemName;  // Snapshot
    public string $itemSku;  // Snapshot
    public float $unitPrice;
    public int $quantity;
    public float $lineTotal;  // quantity * unitPrice
    public string $description;  // Optional: extended description
    public ?int $reservationId;  // Link to InventoryData reservation if applicable
    public array $attributes;  // JSON: color, size, etc. if applicable
}
```

### Transaction Entity
```php
namespace Emporium\AccountData\Entity;

class Transaction {
    public int $id;
    public string $accountCode;  // GL account code
    public string $type;  // 'debit', 'credit'
    public float $amount;
    public string $description;
    public \DateTime $transactionDate;
    public string $reference;  // Invoice, order, or payment reference
    public int $referenceId;  // Invoice ID, order ID, payment ID
    public int $createdBy;
    public \DateTime $createdDate;
}
```

---

## Namespace Structure

```
Emporium\AccountData\
├── Repository\
│   ├── InvoiceRepository.php
│   ├── OrderRepository.php
│   ├── PaymentRepository.php
│   ├── PricingRepository.php
│   ├── TransactionRepository.php
│   └── ...RepositoryInterface.php
├── Service\
│   ├── InvoiceCalculationService.php
│   ├── OrderProcessingService.php
│   ├── PaymentProcessingService.php
│   ├── TaxCalculationService.php
│   └── ...ServiceInterface.php
├── Entity\
│   ├── Invoice.php
│   ├── Order.php
│   ├── Payment.php
│   ├── Pricing.php
│   ├── Transaction.php
│   ├── LineItem.php
│   ├── Discount.php
│   └── ...
├── Event\
│   ├── InvoiceCreatedEvent.php
│   ├── OrderConfirmedEvent.php
│   ├── PaymentReceivedEvent.php
│   └── ...Event.php
├── Exception\
│   ├── InvoiceNotFoundException.php
│   ├── InsufficientPaymentException.php
│   └── ...Exception.php
└── Filter\
    ├── InvoiceFilter.php
    ├── OrderFilter.php
    ├── PaymentFilter.php
    └── ...Filter.php
```

---

## Service Registration

In `services/provider.php`:

```php
// Invoice/Order/Payment access
$container->set(InvoiceRepository::class, function (Container $c) { ... });
$container->set(OrderRepository::class, function (Container $c) { ... });
$container->set(PaymentRepository::class, function (Container $c) { ... });
$container->set(PricingRepository::class, function (Container $c) { ... });
$container->set(TransactionRepository::class, function (Container $c) { ... });

// Business logic services
$container->set(InvoiceCalculationService::class, function (Container $c) { ... });
$container->set(OrderProcessingService::class, function (Container $c) { ... });
$container->set(PaymentProcessingService::class, function (Container $c) { ... });
$container->set(TaxCalculationService::class, function (Container $c) { ... });

// Model factories
$container->set(InvoiceModel::class, function (Container $c) { ... });
$container->set(OrderModel::class, function (Container $c) { ... });
```

---

## How Other Extensions Use This

### Example: com_emporium OrderService Using AccountData

```php
namespace Emporium\Emporium\Service;

use Emporium\AccountData\Repository\OrderRepository;
use Emporium\AccountData\Service\OrderProcessingService;

class OrderService {
    public function __construct(
        private readonly OrderRepository $orders,
        private readonly OrderProcessingService $orderProcessing,
    ) {}

    public function createOrder(OrderData $orderData): Order {
        // Create order via AccountData
        $order = new \Emporium\AccountData\Entity\Order($orderData);
        $orderId = $this->orders->save($order);

        // Process (creates invoice, etc.)
        $order = $this->orders->getOrder($orderId);
        $this->orderProcessing->confirmOrder($order);

        // Emit event
        $this->dispatcher->dispatch('onEmporiumOrderCreated', ['orderId' => $orderId]);

        return $order;
    }
}
```

### Example: extension_invoicing Using AccountData

```php
namespace Emporium\Invoicing\Service;

use Emporium\AccountData\Repository\InvoiceRepository;
use Emporium\AccountData\Service\InvoiceCalculationService;

class InvoicingService {
    public function __construct(
        private readonly InvoiceRepository $invoices,
        private readonly InvoiceCalculationService $calculator,
    ) {}

    public function createInvoice(int $orderId): \Emporium\AccountData\Entity\Invoice {
        // Load order
        $order = $this->orders->getOrder($orderId);

        // Create invoice from order
        $invoice = new \Emporium\AccountData\Entity\Invoice($order);

        // Calculate totals
        $invoice->subtotal = $this->calculator->calculateSubtotal($invoice);
        $invoice->tax = $this->calculator->calculateTax($invoice);
        $invoice->total = $this->calculator->calculateTotal($invoice);

        // Save
        $invoiceId = $this->invoices->save($invoice);

        return $this->invoices->getInvoice($invoiceId);
    }
}
```

---

## Data Consistency Rules

- **Invoice Number**: Must be unique per company
- **Order Number**: Must be unique per company
- **Line Item Totals**: quantity × unitPrice must equal lineTotal
- **Invoice Balance**: total - paidAmount = balance
- **Order Status**: Cannot go backwards (pending → confirmed → shipped → delivered)
- **Payment Amount**: Cannot exceed invoice balance
- **Pricing**: Cannot have negative prices or quantities

---

## Database Tables

```sql
-- Invoices
CREATE TABLE `#__accountdata_invoices` (
    id INT PRIMARY KEY AUTO_INCREMENT,
    number VARCHAR(50) UNIQUE NOT NULL,
    type ENUM('sales_invoice', 'purchase_invoice', 'credit_note'),
    customer_id INT NOT NULL,
    customer_name VARCHAR(255),
    customer_address TEXT,
    invoice_date DATE,
    due_date DATE,
    status ENUM('draft', 'sent', 'viewed', 'paid', 'overdue', 'cancelled') DEFAULT 'draft',
    subtotal DECIMAL(12,2),
    tax_amount DECIMAL(12,2),
    shipping_cost DECIMAL(12,2),
    discount_amount DECIMAL(12,2),
    total DECIMAL(12,2),
    paid_amount DECIMAL(12,2) DEFAULT 0,
    currency VARCHAR(3),
    payment_terms VARCHAR(50),
    notes TEXT,
    created_date DATETIME,
    modified_date DATETIME
);

-- Orders
CREATE TABLE `#__accountdata_orders` (
    id INT PRIMARY KEY AUTO_INCREMENT,
    number VARCHAR(50) UNIQUE NOT NULL,
    type ENUM('sales_order', 'purchase_order'),
    customer_id INT NOT NULL,
    billing_address_id INT,
    shipping_address_id INT,
    order_date DATE,
    required_date DATE,
    shipping_date DATE,
    status ENUM('pending', 'confirmed', 'shipped', 'delivered', 'cancelled') DEFAULT 'pending',
    subtotal DECIMAL(12,2),
    tax_amount DECIMAL(12,2),
    shipping_cost DECIMAL(12,2),
    discount_amount DECIMAL(12,2),
    total DECIMAL(12,2),
    currency VARCHAR(3),
    shipping_method VARCHAR(50),
    payment_method VARCHAR(50),
    po_reference VARCHAR(50),
    related_invoice_id INT,
    notes TEXT,
    created_date DATETIME,
    modified_date DATETIME
);

-- Payments
CREATE TABLE `#__accountdata_payments` (
    id INT PRIMARY KEY AUTO_INCREMENT,
    reference VARCHAR(100) UNIQUE NOT NULL,
    invoice_id INT NOT NULL,
    customer_id INT NOT NULL,
    amount DECIMAL(12,2),
    method VARCHAR(50),
    status ENUM('pending', 'reconciled', 'failed', 'refunded') DEFAULT 'pending',
    payment_date DATE,
    reconciliation_date DATE,
    bank_account VARCHAR(50),
    transaction_id VARCHAR(100),
    notes TEXT,
    created_date DATETIME
);

-- Pricing
CREATE TABLE `#__accountdata_pricing` (
    id INT PRIMARY KEY AUTO_INCREMENT,
    item_id INT NOT NULL,
    code VARCHAR(50),
    base_price DECIMAL(12,2),
    currency VARCHAR(3),
    customer_id INT,
    min_quantity INT,
    max_quantity INT,
    discount_percent DECIMAL(5,2),
    effective_date DATE,
    expiry_date DATE,
    active TINYINT(1) DEFAULT 1
);
```

---

## Related Documentation

- Architecture: `.claude/ARCHITECTURE.md`
- Ecosystem Overview: `..\..\ClaudeCode\docs\PROJECT-ECOSYSTEM.md`
- Integration Guide: `..\..\ClaudeCode\docs\INTERPROJECT-REFERENCES.md`
