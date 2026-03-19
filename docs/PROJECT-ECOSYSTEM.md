# Multi-Extension Data Ecosystem Template

## Overview

This is a **generic template** for projects where multiple independent Joomla extensions share a common data access layer. Copy and customize for your specific project, replacing placeholder names with your actual extension names.

```
┌──────────────────────────────────────────────────────────────────────┐
│                     DOMAIN/APPLICATION EXTENSIONS                    │
│  (These extensions use data layer services to build applications)    │
│                                                                      │
│  com_yourapp (Primary App)    com_secondapp (Secondary App)         │
│  ext_notifications (Alerts)   ext_reporting (Reports)               │
└──────────────────┬───────────────────────────────────────────────────┘
                   │
                   │ (Inject services, listen to events)
                   ↓
┌──────────────────────────────────────────────────────────────────────┐
│              DATA ACCESS LAYER EXTENSIONS (Single Source of Truth)   │
│                                                                      │
│  com_productdata              com_customerdata        com_orderdata │
│  ─────────────────            ────────────────        ─────────────│
│  • Products                   • Customers             • Orders      │
│  • Categories                 • Suppliers             • Invoices    │
│  • Stock Levels               • Contacts              • Payments    │
│  • Reservations               • Addresses             • Pricing     │
│                                                                      │
│  Provides: Models & Business Logic Services (Model→Table pattern)   │
│  Events: Product/Stock/Category updates                             │
│          Customer/Supplier updates                                  │
│          Order/Invoice/Payment updates                              │
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
Each data layer extension manages a specific business domain as a vertical slice. Each has its own Models, Tables, and Services.

### 2. **No Circular Dependencies**
- Data layers do NOT depend on each other
- Data layers do NOT depend on domain extensions
- Domain extensions depend on data layers
- Domain extensions MAY depend on each other

### 3. **Single Source of Truth**
- Each data entity exists in only one data layer
- No data duplication across extensions

### 4. **Event-Driven Communication**
- Data layers emit events when their data changes
- Domain extensions listen to events and react
- Enables loose coupling between extensions

### 5. **Joomla First — Model→Table Access**
- All data access through Models and Tables, not direct queries
- **Models** (BaseDatabaseModel subclasses) provide data retrieval and delegate writes to Tables
- **Tables** (Table subclasses) handle all database writes: `save()`, `delete()`, `publish()`
- **No Repository layer** — Services use Models which use Tables
- Business logic encapsulated in Services

---

## Data Layer Structure (Generic)

### Data Layer Extension Pattern

Each data layer extension follows this structure:

```
Vendor\Component\DataLayerName\Administrator\
├── Service\
│   ├── StockReservationService.php    — Business logic service
│   └── AvailabilityService.php        — Business logic service
├── Model\
│   ├── ProductModel.php               — MVC FormModel for admin CRUD
│   ├── ProductsModel.php              — MVC ListModel for admin list
│   ├── StockModel.php                 — Service Model (BaseDatabaseModel)
│   └── ReservationModel.php           — Service Model (BaseDatabaseModel)
└── Table\
    ├── ProductTable.php               — Shared by ProductModel and StockModel
    └── ReservationTable.php           — Used by ReservationModel
```

**Public Services** (injected by domain extensions):
```
StockReservationService  — Reserve and release stock (uses ReservationModel → ReservationTable)
AvailabilityService      — Check item availability (uses StockModel for reads)
```

**Events Emitted**:
```
onProductCreated         — New product added
onProductUpdated         — Product changed
onStockReserved          — Stock reserved for order
onStockReleased          — Reservation cancelled
onLowStock               — Item below threshold
```

---

## Data Flows (Generic Examples)

### Flow 1: Customer Places Order (Multi-Extension)

```
1. com_yourapp (Site)
   └─ User adds item to cart
   └─ Calls: ProductData\StockReservationService::reserve()
            CustomerData\CustomerModel::getItem()

2. ProductData
   └─ Reserves stock via ReservationModel → ReservationTable::save()
   └─ Emits: onStockReserved

3. ext_notifications (listens)
   └─ Receives: onStockReserved
   └─ Sends: Stock reservation confirmation

4. com_yourapp (User checks out)
   └─ Creates order via OrderData\OrderModel → OrderTable::save()
   └─ Calls: ProductData\StockReservationService::confirm()

5. OrderData
   └─ Confirms order via OrderTable::save()
   └─ Emits: onOrderCreated, onInvoiceCreated
```

### Flow 2: Stock Level Changes

```
1. com_yourapp (Admin)
   └─ Admin updates item stock
   └─ Calls: ProductData\StockService::adjustStock()

2. ProductData
   └─ Adjusts stock via StockModel → ProductTable::save()
   └─ Checks threshold
   └─ Emits: onLowStock (if needed)

3. ext_notifications (listens)
   └─ Receives: onLowStock
   └─ Sends: "Low stock alert" to manager
```

---

## Reference Architecture

### Service Registration Pattern (Model→Table)

Each data layer registers its services in a service provider. Services inject Models, not Repositories:

```php
// com_productdata/services/provider.php
$container->set(StockModel::class, function (Container $c) {
    $model = new StockModel();
    $model->setDatabase($c->get(DatabaseInterface::class));
    return $model;
});

$container->set(StockReservationService::class, function (Container $c) {
    return new StockReservationService(
        $c->get(StockModel::class),          // Model, not Repository
        $c->get(ReservationModel::class),    // Model, not Repository
    );
});
```

### Service Injection Pattern (Model→Table)

Domain extensions inject data layer services:

```php
// com_yourapp/src/Service/OrderService.php
use Vendor\Component\ProductData\Administrator\Model\StockModel;
use Vendor\Component\CustomerData\Administrator\Model\CustomerModel;

class OrderService {
    public function __construct(
        private readonly StockModel $stockModel,         // Model, not Repository
        private readonly CustomerModel $customerModel,   // Model, not Repository
        private readonly OrderModel $orderModel,         // Local Service Model
    ) {}

    public function createOrder(int $customerId, OrderData $data): Order {
        // Use injected Models (which use Tables for writes)
        $customer = $this->customerModel->getItem($customerId);
        $stock = $this->stockModel->getAvailability($data->itemId);
        return $this->orderModel->saveOrder($data); // Model → Table::save()
    }
}
```

### Event Listening Pattern

Other extensions listen to data layer events:

```php
// ext_notifications/src/Plugin/NotificationPlugin.php
class NotificationPlugin implements SubscriberInterface {
    public static function getSubscribedEvents(): array {
        return [
            'onLowStock' => 'alertLowStock',
            'onInvoiceCreated' => 'sendInvoiceEmail',
            'onCustomerCreated' => 'sendWelcomeEmail',
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

---

## Data Consistency

### Single Source of Truth Guarantees

| Data | Layer | Single Source |
|---|---|---|
| Products, Stock, Availability | ProductData | ✓ |
| Customers, Suppliers, Contacts | CustomerData | ✓ |
| Orders, Invoices, Payments | OrderData | ✓ |

### Data Snapshots (Read-Only References)

When one layer references data from another, store IDs and snapshots, not live objects:

```php
// ✓ CORRECT: ID reference + snapshot
class OrderLineItem {
    public int $itemId;               // Live reference
    public string $itemName;          // Snapshot at order time
    public string $itemSku;           // Snapshot at order time
    public float $unitPrice;          // Snapshot at order time
}
```

This prevents old orders showing updated (incorrect) item names or prices.

---

## Best Practices

### ✓ DO:

1. **Inject services** in constructors, not service locator
2. **Use Models→Tables** for all data access and writes
3. **Listen to events** for inter-extension communication
4. **Snapshot data** when referencing other layers
5. **Keep data layers independent** (no cross-layer dependencies)
6. **Use interfaces** for all services (allow mocking/testing)

### ✗ DON'T:

1. **Use Repositories** — use Joomla's native Model→Table pattern
2. **Write raw SQL in Models** — use Table classes for all writes
3. **Query directly** across database tables from different layers
4. **Create circular dependencies** between extensions
5. **Store duplicate data** (violates single source of truth)
6. **Hard-code** references to other extensions' namespaces

---

## Migration Path for New Extensions

When adding a new domain extension:

1. **Identify** what data it needs (which data layers)
2. **Check** if required data layers exist
3. **Define** required services/models in those layers (if missing)
4. **Inject** Models/services in your extension
5. **Listen** to events for notifications from other layers
6. **Emit** your own events for other extensions to consume
7. **Document** in your project's ecosystem documentation

---

## Related Files

- **Integration Guide**: `INTERPROJECT-REFERENCES.md` (this folder)
- **Agent Usage**: `agent-usage-guide.md`