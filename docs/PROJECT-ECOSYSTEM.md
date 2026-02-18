# Emporium Multi-Extension Data Ecosystem

## Overview

The Emporium ecosystem is a modular architecture where multiple independent extensions share a common data access layer. This document provides a complete overview of the ecosystem, data flows, dependencies, and design patterns.

```
┌──────────────────────────────────────────────────────────────────────┐
│                     DOMAIN/APPLICATION EXTENSIONS                    │
│  (These extensions use data layer services to build applications)    │
│                                                                      │
│  com_emporium (E-commerce)  future_shop (Single Vendor)             │
│  extension_events (Events)  extension_invoicing (Invoicing)         │
│  extension_mailing (Email)  extension_accounting (GL Management)    │
└──────────────────┬───────────────────────────────────────────────────┘
                   │
                   │ (Inject services, listen to events)
                   ↓
┌──────────────────────────────────────────────────────────────────────┐
│              DATA ACCESS LAYER EXTENSIONS (Single Source of Truth)   │
│                                                                      │
│  com_inventorydata          com_entitydata          com_accountdata │
│  ─────────────────          ──────────────          ────────────────│
│  • Items                    • Customers             • Invoices      │
│  • Categories               • Suppliers             • Orders        │
│  • Stock Levels             • Businesses            • Payments      │
│  • Reservations             • Contacts              • Transactions  │
│  • Lists                    • Addresses             • Pricing       │
│                             • Relationships         • Tax Rates     │
│                                                                      │
│  Provides: Repositories & Business Logic Services                   │
│  Events: Item/Stock/Category updates                                │
│          Customer/Supplier updates                                  │
│          Invoice/Order/Payment updates                              │
└──────────────────────────────────────────────────────────────────────┘
                   ↓
┌──────────────────────────────────────────────────────────────────────┐
│                      JOOMLA DATABASE LAYER                           │
│         (Persistent storage for all data layers)                    │
└──────────────────────────────────────────────────────────────────────┘
```

---

## Architecture Principles

### 1. **Data Layer Separation**
Each data layer extension manages a specific business domain:
- **com_inventorydata** — Product/inventory data (vertical slice)
- **com_entitydata** — Customer/supplier/business data (vertical slice)
- **com_accountdata** — Financial/accounting data (vertical slice)

### 2. **No Circular Dependencies**
- Data layers do NOT depend on each other
- Data layers do NOT depend on domain extensions
- Domain extensions depend on data layers
- Domain extensions MAY depend on each other

### 3. **Single Source of Truth**
- Customer data exists only in com_entitydata
- Item/inventory data exists only in com_inventorydata
- Invoice/order data exists only in com_accountdata
- No data duplication across extensions

### 4. **Event-Driven Communication**
- Data layers emit events when their data changes
- Domain extensions listen to events and react
- Enables loose coupling between extensions

### 5. **Service-Based Access**
- All data access through repositories/services, not direct queries
- Repositories provide consistent interfaces
- Business logic encapsulated in services

---

## Data Domains

### Domain 1: Inventory Data (com_inventorydata)

**Manages**:
- What products/items exist
- How much stock we have
- How stock is reserved/allocated
- Product categories and organization
- Supplier information (linked to EntityData)

**Public Repositories**:
```
ItemRepository          - Get/save/search items
CategoryRepository      - Get/save categories
ListRepository          - Manage predefined item lists
```

**Public Services**:
```
StockReservationService - Reserve and release stock
AvailabilityService     - Check if items are available
StockService            - Adjust stock levels, transfers
```

**Events Emitted**:
```
onInventoryItemCreated       - New item added
onInventoryItemUpdated       - Item changed
onInventoryStockReserved     - Stock reserved for order
onInventoryStockConfirmed    - Reservation committed
onInventoryStockReleased     - Reservation cancelled
onInventoryLowStock          - Item below threshold
onInventoryOutOfStock        - Item unavailable
```

**Used By**:
- com_emporium (primary consumer)
- extension_invoicing (line items, valuation)
- extension_mailing (stock alerts)
- com_accountdata (cost references)

---

### Domain 2: Entity Data (com_entitydata)

**Manages**:
- Who our customers are
- Who our suppliers are
- What businesses exist
- Contact information and addresses
- Relationships between entities

**Public Repositories**:
```
CustomerRepository      - Get/save customers
SupplierRepository      - Get/save suppliers
BusinessRepository      - Get/save businesses
ContactRepository       - Get/save contacts
AddressRepository       - Get/save addresses
```

**Public Services**:
```
EntityRelationshipService      - Define relationships
CustomerClassificationService - Classify customers (VIP, wholesale)
EntityValidationService        - Validate entity data
```

**Events Emitted**:
```
onEntityCustomerCreated        - New customer added
onEntityCustomerUpdated        - Customer profile changed
onEntityCustomerClassified     - Customer tier changed
onEntitySupplierCreated        - New supplier added
onEntitySupplierUpdated        - Supplier changed
onEntitySupplierStatusChanged  - Supplier status (active/suspended)
onEntityBusinessCreated        - New business added
onEntityContactCreated         - New contact added
onEntityAddressCreated         - New address added
```

**Used By**:
- com_emporium (primary consumer)
- extension_invoicing (customer/supplier data)
- extension_mailing (email addresses, contact info)
- com_inventorydata (supplier details)

---

### Domain 3: Account Data (com_accountdata)

**Manages**:
- Sales and purchase invoices
- Customer and purchase orders
- Payment records
- Financial transactions
- Product pricing
- Tax configuration

**Public Repositories**:
```
InvoiceRepository       - Get/save invoices
OrderRepository         - Get/save orders
PaymentRepository       - Get/save payments
PricingRepository       - Get/save pricing
TransactionRepository   - Get/save GL transactions
```

**Public Services**:
```
InvoiceCalculationService   - Calculate invoice totals
OrderProcessingService      - Process order workflows
PaymentProcessingService    - Process payments/refunds
TaxCalculationService       - Calculate taxes
```

**Events Emitted**:
```
onAccountDataInvoiceCreated       - Invoice generated
onAccountDataInvoiceStatusChanged - Invoice status changed
onAccountDataInvoicePaid          - Invoice paid
onAccountDataOrderCreated         - Order created
onAccountDataOrderConfirmed       - Order confirmed
onAccountDataOrderCompleted       - Order delivered/completed
onAccountDataPaymentReceived      - Payment received
onAccountDataPriceUpdated         - Item price changed
```

**Used By**:
- com_emporium (primary consumer)
- extension_invoicing (required consumer)
- extension_reporting (financial reports)
- extension_mailing (invoices, payment receipts)

---

## Data Flows

### Flow 1: Customer Places Order (Multi-Extension)

```
1. com_emporium (Site)
   └─ User adds item to cart
   └─ Calls: InventoryData\StockReservationService::reserve()
            EntityData\CustomerRepository::getCustomer()

2. InventoryData
   └─ Reserves stock
   └─ Emits: onInventoryStockReserved

3. extension_mailing (listens)
   └─ Receives: onInventoryStockReserved
   └─ Calls: EntityData\CustomerRepository::getCustomer()
   └─ Sends: Stock reservation confirmation email

4. com_emporium (User checks out)
   └─ Creates order via AccountData\OrderRepository::save()
   └─ Calls: InventoryData\StockReservationService::confirm()
   └─ Calls: AccountData\OrderProcessingService::createInvoiceFromOrder()

5. AccountData
   └─ Confirms order, creates invoice
   └─ Emits: onAccountDataOrderCreated, onAccountDataInvoiceCreated

6. extension_invoicing (listens)
   └─ Receives: onAccountDataInvoiceCreated
   └─ Creates GL transactions via TransactionRepository::batch()

7. extension_mailing (listens)
   └─ Receives: onAccountDataInvoiceCreated
   └─ Calls: AccountData\InvoiceRepository::getInvoice()
   └─ Calls: EntityData\CustomerRepository::getCustomer()
   └─ Sends: Invoice email
```

### Flow 2: Inventory Stock Level Changes

```
1. com_emporium (Admin)
   └─ Admin updates item stock
   └─ Calls: InventoryData\StockService::adjustStock()

2. InventoryData
   └─ Adjusts stock
   └─ Checks if below threshold
   └─ Emits: onInventoryLowStock (if needed)

3. extension_mailing (listens)
   └─ Receives: onInventoryLowStock
   └─ Gets: InventoryData\ItemRepository::getItem()
   └─ Sends: "Low stock alert" email to inventory manager

4. extension_dropshipping (listens - future)
   └─ Receives: onInventoryLowStock
   └─ Auto-creates purchase order from Supplier
   └─ Calls: AccountData\OrderRepository::save()
```

### Flow 3: Customer Updates Profile

```
1. com_emporium (Site)
   └─ Customer updates profile
   └─ Calls: EntityData\CustomerRepository::save()

2. EntityData
   └─ Saves customer changes
   └─ Emits: onEntityCustomerUpdated

3. com_emporium (Admin - listens)
   └─ Receives: onEntityCustomerUpdated
   └─ Updates related orders/invoices
   └─ Calls: AccountData\OrderRepository::getOrdersByCustomer()

4. extension_mailing (listens)
   └─ Receives: onEntityCustomerUpdated
   └─ Triggers: Profile update confirmation email

5. com_inventorydata (may listen - future)
   └─ If customer tier changed, recalculate pricing
```

### Flow 4: Payment Received

```
1. com_emporium (Admin)
   └─ Admin records payment received
   └─ Calls: AccountData\PaymentRepository::save()
   └─ Calls: AccountData\PaymentProcessingService::applyPaymentToInvoice()

2. AccountData
   └─ Records payment
   └─ Updates invoice balance
   └─ Emits: onAccountDataPaymentReceived

3. extension_invoicing (listens)
   └─ Receives: onAccountDataPaymentReceived
   └─ Creates GL transaction for payment
   └─ Calls: AccountData\TransactionRepository::save()

4. extension_mailing (listens)
   └─ Receives: onAccountDataPaymentReceived
   └─ Sends: Payment receipt to customer
```

---

## Reference Architecture

### Service Registration Pattern

Each data layer registers its services in a service provider:

```php
// com_inventorydata/services/provider.php
$container->set(ItemRepository::class, function (Container $c) {
    return new ItemRepository($c->get(DatabaseInterface::class));
});

$container->set(StockReservationService::class, function (Container $c) {
    return new StockReservationService(
        $c->get(DatabaseInterface::class),
        $c->get(ItemRepository::class)
    );
});
```

### Service Injection Pattern

Domain extensions inject data layer services:

```php
// com_emporium/src/Service/OrderService.php
use Emporium\InventoryData\Repository\ItemRepository;
use Emporium\EntityData\Repository\CustomerRepository;
use Emporium\AccountData\Repository\OrderRepository;

class OrderService {
    public function __construct(
        private readonly ItemRepository $items,
        private readonly CustomerRepository $customers,
        private readonly OrderRepository $orders,
    ) {}

    public function createOrder(int $customerId, OrderData $data): Order {
        // Use injected repositories
        $customer = $this->customers->getCustomer($customerId);
        $item = $this->items->getItem($data->itemId);
        $order = new Order($data);
        $orderId = $this->orders->save($order);
        return $this->orders->getOrder($orderId);
    }
}
```

### Event Listening Pattern

Other extensions listen to data layer events:

```php
// extension_mailing/src/Plugin/MailingPlugin.php
class MailingPlugin implements SubscriberInterface {
    public static function getSubscribedEvents(): array {
        return [
            'onInventoryLowStock' => 'alertLowStock',
            'onAccountDataInvoiceCreated' => 'sendInvoiceEmail',
            'onEntityCustomerCreated' => 'sendWelcomeEmail',
        ];
    }

    public function alertLowStock(object $event): void {
        $item = $event->getItem();
        $this->email->send([
            'to' => 'inventory@company.com',
            'subject' => "Low Stock: {$item->name}",
        ]);
    }
}
```

---

## Extension Roles

### Data Layer Extensions (3)

| Extension | Role | Manages | Consumers |
|---|---|---|---|
| **com_inventorydata** | Inventory data access layer | Items, Stock, Categories, Reservations | emporium, invoicing, mailing, dropshipping |
| **com_entitydata** | Entity data access layer | Customers, Suppliers, Businesses, Contacts | emporium, invoicing, mailing, accounting |
| **com_accountdata** | Financial data access layer | Invoices, Orders, Payments, Transactions | emporium, invoicing, reporting, mailing |

### Domain Extensions

| Extension | Purpose | Data Layers Used |
|---|---|---|
| **com_emporium** | Multi-vendor marketplace | All three (primary consumer) |
| **future_shop** | Single-vendor shop | InventoryData, EntityData |
| **extension_events** | Events management | EntityData (venues, attendees) |
| **extension_invoicing** | Accounting integration | AccountData (primary) |
| **extension_mailing** | Email notifications | All three (reads data for emails) |
| **extension_accounting** | GL management | AccountData (transactions, reconciliation) |
| **extension_reporting** | Financial/inventory reports | AccountData, InventoryData |

---

## Dependency Graph

### Allowed Dependencies
```
✓ Domain Extensions → Data Layers
✓ Domain Extensions → Other Domain Extensions
✓ Data Layers → Joomla Core
```

### Prohibited Dependencies
```
✗ Data Layers → Domain Extensions
✗ Data Layers → Other Data Layers (no direct dependencies)
```

### Actual Dependencies

```
com_emporium
  ├─ depends on: InventoryData, EntityData, AccountData
  └─ emits: OrderPlaced, PaymentProcessed, UserRegistered

future_shop
  ├─ depends on: InventoryData, EntityData
  └─ emits: OrderPlaced

extension_invoicing
  ├─ depends on: AccountData (primary)
  └─ emits: InvoiceProcessed

extension_mailing
  ├─ depends on: EntityData (for contacts)
  └─ consumes events from: All layers

extension_reporting
  ├─ depends on: InventoryData, AccountData
  └─ generates: Reports (read-only)

InventoryData (no dependencies on other data layers)
  ├─ references: EntityData (supplier details - read-only)
  └─ provides: ItemRepository, StockReservationService

EntityData (no dependencies on other data layers)
  └─ provides: CustomerRepository, SupplierRepository

AccountData (no dependencies on other data layers)
  ├─ references: InventoryData (item costs - read-only)
  ├─ references: EntityData (customer/supplier IDs - read-only)
  └─ provides: InvoiceRepository, OrderRepository
```

---

## Data Consistency

### Single Source of Truth Guarantees

| Data | Layer | Single Source |
|---|---|---|
| Items, Stock, Availability | InventoryData | ✓ |
| Customers, Suppliers, Contacts | EntityData | ✓ |
| Invoices, Orders, Payments | AccountData | ✓ |
| Pricing | AccountData | ✓ |
| Item Names/Descriptions | InventoryData | ✓ |

### Data Snapshots (Read-Only References)

When one layer references data from another, it typically snapshots the data:

```php
// AccountData Order snapshots EntityData customer data
class Order {
    public int $customerId;           // Live reference
    public string $customerName;      // Snapshot at order time
    public string $customerAddress;   // Snapshot at order time
}

// AccountData Invoice snapshots InventoryData item data
class LineItem {
    public int $itemId;               // Live reference
    public string $itemName;          // Snapshot at invoice time
    public string $itemSku;           // Snapshot at invoice time
    public float $unitPrice;          // From pricing at that time
}
```

This prevents:
- Customer name changes retroactively affecting old invoices
- Item name changes affecting old order history
- Old orders showing updated (incorrect) item names

---

## Event Communication Patterns

### Event Emission

Data layers emit domain events when their data changes:

```
onInventoryItemCreated
  → emitted by: InventoryData
  → data: itemId, name, sku, categoryId
  → consumed by: mailing (catalog update notification)

onAccountDataInvoiceCreated
  → emitted by: AccountData
  → data: invoiceId, customerId, total, dueDate
  → consumed by: mailing (send invoice), invoicing (create GL entry)

onEntityCustomerUpdated
  → emitted by: EntityData
  → data: customerId, changes (array of modified fields)
  → consumed by: mailing (alert user), emporium (refresh user data)
```

### Event Listening

Domain extensions listen and react:

```php
// extension_mailing listens to multiple layers
class MailingListener {
    public function getSubscribedEvents() {
        return [
            'onInventoryLowStock' => 'sendAlert',
            'onAccountDataInvoiceCreated' => 'sendInvoice',
            'onEntityCustomerCreated' => 'sendWelcome',
        ];
    }
}

// com_emporium listens to updates
class CacheInvalidator {
    public function getSubscribedEvents() {
        return [
            'onInventoryItemUpdated' => 'invalidateItemCache',
            'onEntityCustomerUpdated' => 'invalidateCustomerCache',
            'onAccountDataPriceUpdated' => 'invalidatePriceCache',
        ];
    }
}
```

---

## Best Practices

### ✓ DO:

1. **Inject services** in constructors, not service locator
2. **Use repositories** for all data access
3. **Listen to events** for inter-extension communication
4. **Snapshot data** when referencing other layers
5. **Document dependencies** in `.claude/project-ecosystem.md`
6. **Keep data layers independent** (no cross-layer dependencies)
7. **Use interfaces** for all services (allow mocking/testing)

### ✗ DON'T:

1. **Query directly** across database tables from different layers
2. **Call services** from data layer without injection
3. **Modify other extensions' data** without using their repositories
4. **Create circular dependencies** between extensions
5. **Store duplicate data** (violates single source of truth)
6. **Emit events** from data layers that reference domain extensions
7. **Hard-code** references to other extensions' namespaces

---

## Migration Path for New Extensions

When adding a new domain extension:

1. **Identify** what data it needs (which data layers)
2. **Check** if required data layers exist
3. **Define** required services in those layers (if missing)
4. **Inject** repositories/services in your extension
5. **Listen** to events for notifications from other layers
6. **Emit** your own events for other extensions to consume
7. **Document** in `.claude/project-ecosystem.md`

---

## Future Extensibility

### Adding New Data Layers

If a new business domain needs dedicated data layer (e.g., com_shippingdata for shipping):

1. Create new extension following same pattern
2. Add services and repositories
3. Emit events when data changes
4. Document in PROJECT-ECOSYSTEM.md
5. Existing domain extensions can inject without code changes

### Adding New Domain Extensions

Any new extension can:
1. Inject existing data layer services
2. Listen to data layer events
3. Emit its own events
4. Coordinate with other domain extensions

No changes needed to data layers.

---

## Related Files

- **Individual Project Docs**: `.claude/project-ecosystem.md` in each extension
- **Integration Guide**: `INTERPROJECT-REFERENCES.md` (this folder)
- **Architecture Patterns**: `joomla5-di-patterns.md`
- **Code Standards**: `joomla-coding-preferences.md`
