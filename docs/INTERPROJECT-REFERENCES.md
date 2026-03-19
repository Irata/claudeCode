# Inter-Project References Guide

How to access and use services from other extensions in a multi-extension Joomla ecosystem. This is a **generic template** — replace placeholder names (`Vendor`, `com_productdata`, `YourExtension`, etc.) with your actual project names.

---

## Quick Reference

### Injecting Data Layer Models

```php
use Vendor\Component\ProductData\Administrator\Model\StockModel;
use Vendor\Component\ProductData\Administrator\Service\StockReservationService;

class YourService {
    public function __construct(
        private readonly StockModel $stockModel,
        private readonly StockReservationService $reservations,
    ) {}

    public function addToCart(int $itemId, int $qty): void {
        // Check availability via Model (read operation)
        $item = $this->stockModel->getItem($itemId);
        if ($item->currentStock < $qty) {
            throw new InsufficientStockException($itemId);
        }

        // Reserve stock via Service (which uses Model → Table::save())
        $reservation = $this->reservations->reserve($itemId, $qty);
    }
}
```

### Injecting Customer Data Models

```php
use Vendor\Component\CustomerData\Administrator\Model\CustomerModel;
use Vendor\Component\CustomerData\Administrator\Model\AddressModel;

class YourService {
    public function __construct(
        private readonly CustomerModel $customerModel,
        private readonly AddressModel $addressModel,
    ) {}

    public function getCustomerShippingAddress(int $customerId): Address {
        $customer = $this->customerModel->getItem($customerId);
        return $this->addressModel->getPrimaryAddress($customerId, 'customer');
    }
}
```

### Injecting Order/Financial Data Models

```php
use Vendor\Component\OrderData\Administrator\Model\InvoiceModel;
use Vendor\Component\OrderData\Administrator\Service\InvoiceCalculationService;

class YourService {
    public function __construct(
        private readonly InvoiceModel $invoiceModel,
        private readonly InvoiceCalculationService $calculator,
    ) {}

    public function generateInvoice(int $orderId): Invoice {
        $invoice = $this->invoiceModel->getByReference("order-$orderId");
        $invoice->total = $this->calculator->calculateTotal($invoice);
        return $invoice;
    }
}
```

---

## Detailed Usage Patterns

### Pattern 1: Retrieve Data from Another Layer

**Scenario**: You need customer data from a data layer in your extension

```php
use Vendor\Component\CustomerData\Administrator\Model\CustomerModel;

class CheckoutService {
    public function __construct(
        private readonly CustomerModel $customerModel,
    ) {}

    public function checkout(int $customerId): void {
        // Get customer via Model (read operation)
        $customer = $this->customerModel->getItem($customerId);

        // Use customer data for your operation
        $this->sendConfirmationEmail($customer->email);
        $this->createOrder($customer);
    }
}
```

### Pattern 2: Check Availability Before Operation

**Scenario**: Check if item is available before creating an order

```php
use Vendor\Component\ProductData\Administrator\Service\AvailabilityService;
use Vendor\Component\OrderData\Administrator\Model\OrderModel;

class OrderService {
    public function __construct(
        private readonly AvailabilityService $availability,
        private readonly OrderModel $orderModel,
    ) {}

    public function createOrder(int $itemId, int $qty): void {
        // Check availability via data layer service
        if (!$this->availability->isAvailable($itemId, $qty)) {
            throw new OutOfStockException($itemId);
        }

        // Create order via Model → Table::save()
        $this->orderModel->saveOrder($itemId, $qty);
    }
}
```

### Pattern 3: Coordinate Multiple Data Layers

**Scenario**: Create order that involves inventory and accounting

```php
use Vendor\Component\ProductData\Administrator\Service\StockReservationService;
use Vendor\Component\CustomerData\Administrator\Model\CustomerModel;
use Vendor\Component\OrderData\Administrator\Model\OrderModel;

class CompleteOrderService {
    public function __construct(
        private readonly StockReservationService $reservations,
        private readonly CustomerModel $customerModel,
        private readonly OrderModel $orderModel,
    ) {}

    public function completeCheckout(int $customerId, array $items): Order {
        // 1. Verify customer exists (CustomerData — Model read)
        $customer = $this->customerModel->getItem($customerId);

        // 2. Reserve inventory (ProductData — Service uses Model → Table)
        $reservations = [];
        foreach ($items as $item) {
            $reservations[] = $this->reservations->reserve(
                $item['id'],
                $item['quantity']
            );
        }

        // 3. Create order (OrderData — Model → Table::save())
        $orderId = $this->orderModel->saveOrder($customerId, $items, $reservations);

        // 4. Return complete order
        return $this->orderModel->getItem($orderId);
    }
}
```

### Pattern 4: Listen to Events from Other Layers

**Scenario**: React when item stock is low in a data layer

```php
use Joomla\Event\SubscriberInterface;
use Vendor\Component\ProductData\Administrator\Model\ProductModel;

class LowStockAlert implements SubscriberInterface {
    public function __construct(
        private readonly ProductModel $productModel,
    ) {}

    public static function getSubscribedEvents(): array {
        return [
            'onLowStock' => 'handleLowStock',
        ];
    }

    public function handleLowStock(object $event): void {
        $itemId = $event->getItemId();
        $item = $this->productModel->getItem($itemId);

        // Your custom logic here
        $this->notifyInventoryManager($item);
        $this->createPurchaseOrder($item);
    }
}
```

### Pattern 5: Update Related Data Across Layers

**Scenario**: When customer profile updates, refresh their order history

```php
use Vendor\Component\CustomerData\Administrator\Model\CustomerModel;
use Vendor\Component\OrderData\Administrator\Model\OrderModel;

class CustomerService {
    public function __construct(
        private readonly CustomerModel $customerModel,
        private readonly OrderModel $orderModel,
    ) {}

    public function updateCustomerProfile(int $customerId, array $data): void {
        // Update in CustomerData via Model → Table::save()
        $this->customerModel->updateProfile($customerId, $data);

        // Refresh related orders in OrderData via Model → Table::save()
        $this->orderModel->updateCustomerSnapshots($customerId, $data);

        // Emit event for other extensions
        $this->dispatcher->dispatch('onCustomerProfileUpdated', [
            'customerId' => $customerId,
            'changes' => $data,
        ]);
    }
}
```

---

## Service Registration & Discovery

### Accessing Services from Other Extensions

When another extension's service is registered in the DI container:

```php
// Data layer registers its Models and Services
// com_productdata/services/provider.php
$container->set(
    StockModel::class,
    function (Container $c) {
        $model = new StockModel();
        $model->setDatabase($c->get(DatabaseInterface::class));
        return $model;
    }
);

$container->set(
    StockReservationService::class,
    function (Container $c) {
        return new StockReservationService(
            $c->get(StockModel::class),           // Model, not Repository
            $c->get(ReservationModel::class),     // Model, not Repository
        );
    }
);

// Your extension injects it
class YourService {
    public function __construct(
        private readonly StockReservationService $reservations,
    ) {}
}
```

### Which Services Are Available?

Check the project's ecosystem documentation for available Models and Services from each data layer. Each data layer should document:
- **Models** — what data they provide (read access)
- **Services** — what business operations they support
- **Events** — what events they emit for listeners

---

## Data Referencing Patterns

### Pattern: Reference by ID, Not Object

When one layer references data from another, store IDs and snapshots, not live objects:

```php
// ✗ WRONG: Live object reference
class Invoice {
    public Customer $customer;  // Live object from another layer
}
// Problems: Customer updates retroactively change old invoices

// ✓ CORRECT: ID reference + snapshot
class Invoice {
    public int $customerId;              // Live reference
    public string $customerName;        // Snapshot
    public string $customerAddress;     // Snapshot
}
// Benefits: Invoice stays accurate to time of creation
```

### Pattern: Load Related Data As Needed

```php
class ReportService {
    public function __construct(
        private readonly OrderModel $orderModel,
        private readonly CustomerModel $customerModel,
        private readonly ProductModel $productModel,
    ) {}

    public function generateOrderReport(): void {
        $orders = $this->orderModel->getItems(); // Read via Model

        foreach ($orders as $order) {
            // Load customer when needed (lazy loading)
            $customer = $this->customerModel->getItem($order->customerId);

            // Load products when needed
            foreach ($order->lineItems as $line) {
                $item = $this->productModel->getItem($line->itemId);
            }
        }
    }
}
```

### Pattern: Data Snapshots in Events

When emitting events, include snapshot data:

```php
$event = new OrderCreatedEvent([
    'orderId' => $order->id,
    'customerId' => $order->customerId,
    'customerNameSnapshot' => $customer->name,        // Snapshot
    'total' => $order->total,
    'itemsSnapshot' => $order->lineItems,            // Snapshot
    'created' => $order->created,
]);

$this->dispatcher->dispatch('onOrderCreated', ['event' => $event]);
```

---

## Event Communication

### Listening to Events from Other Layers

```php
use Joomla\Event\SubscriberInterface;

class MyListener implements SubscriberInterface {
    public static function getSubscribedEvents(): array {
        return [
            // ProductData events
            'onProductCreated' => 'handleProductCreated',
            'onLowStock' => 'handleLowStock',

            // CustomerData events
            'onCustomerCreated' => 'handleNewCustomer',
            'onCustomerUpdated' => 'handleCustomerUpdate',

            // OrderData events
            'onInvoiceCreated' => 'handleInvoiceCreated',
            'onPaymentReceived' => 'handlePaymentReceived',
        ];
    }
}
```

### Emitting Your Own Events

```php
class YourService {
    public function __construct(
        private readonly DispatcherInterface $dispatcher,
    ) {}

    public function createPromotion(string $name): void {
        // Your logic...

        // Emit event for other extensions to react
        $this->dispatcher->dispatch('onPromotionCreated', [
            'promotionId' => $promotion->id,
            'name' => $name,
            'discountPercent' => $promotion->discount,
        ]);
    }
}
```

---

## Troubleshooting

### Issue: Service Not Found

**Problem**: "Service XYZ not found in container"

**Solution**:
1. Check that the extension is installed and enabled
2. Verify the fully qualified class name is correct
3. Ensure service provider registers the service in `services/provider.php`

### Issue: Circular Reference

**Problem**: "Extension A depends on B, B depends on A"

**Solution**:
1. Only data layers can have no dependencies
2. Use events instead of direct calls to break cycles
3. Refactor so dependency is one-way

### Issue: Stale Data

**Problem**: Order still shows old customer name after customer updates

**Solution**:
1. Store snapshots of data, not live references
2. When customer name changed, emit event
3. Listen to event and update snapshots

---

## Best Practices

### ✓ DO:

1. **Inject Models/Services** via constructor
2. **Use Model→Table** for all data access and writes
3. **Listen to events** for inter-layer communication
4. **Store IDs + snapshots** when referencing other data
5. **Check availability** before operations
6. **Use interfaces** for all public services

### ✗ DON'T:

1. **Use Repositories** — use Joomla's native Model→Table pattern
2. **Write raw SQL** — use Table classes for all writes
3. **Service locator**: Don't use `Factory::getContainer()->get()`
4. **Direct queries**: Don't bypass Models with raw SQL writes
5. **Hard-code class names**: Reference via interfaces
6. **Modify other extensions' data**: Use their Models/Services

---

## Related Documentation

- **Project Ecosystem Overview**: `PROJECT-ECOSYSTEM.md`
- **Agent Usage Guide**: `agent-usage-guide.md`