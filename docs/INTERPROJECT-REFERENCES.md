# Inter-Project References Guide

How to access and use services from other extensions in the Emporium ecosystem.

---

## Quick Reference

### Injecting InventoryData Services

```php
use Emporium\InventoryData\Repository\ItemRepository;
use Emporium\InventoryData\Service\StockReservationService;

class YourService {
    public function __construct(
        private readonly ItemRepository $items,
        private readonly StockReservationService $reservations,
    ) {}

    public function addToCart(int $itemId, int $qty): void {
        // Check availability
        $item = $this->items->getItem($itemId);
        if ($item->currentStock < $qty) {
            throw new InsufficientStockException($itemId);
        }

        // Reserve stock
        $reservation = $this->reservations->reserve($itemId, $qty);
    }
}
```

### Injecting EntityData Services

```php
use Emporium\EntityData\Repository\CustomerRepository;
use Emporium\EntityData\Repository\AddressRepository;

class YourService {
    public function __construct(
        private readonly CustomerRepository $customers,
        private readonly AddressRepository $addresses,
    ) {}

    public function getCustomerShippingAddress(int $customerId): Address {
        $customer = $this->customers->getCustomer($customerId);
        return $this->addresses->getPrimaryAddress($customerId, 'customer');
    }
}
```

### Injecting AccountData Services

```php
use Emporium\AccountData\Repository\InvoiceRepository;
use Emporium\AccountData\Service\InvoiceCalculationService;

class YourService {
    public function __construct(
        private readonly InvoiceRepository $invoices,
        private readonly InvoiceCalculationService $calculator,
    ) {}

    public function generateInvoice(int $orderId): Invoice {
        $invoice = $this->invoices->getInvoiceByReference("order-$orderId");
        $invoice->total = $this->calculator->calculateTotal($invoice);
        return $invoice;
    }
}
```

---

## Detailed Usage Patterns

### Pattern 1: Retrieve Data from Another Layer

**Scenario**: You need customer data from EntityData in your extension

```php
// In your service/controller
use Emporium\EntityData\Repository\CustomerRepository;

class CheckoutService {
    public function __construct(
        private readonly CustomerRepository $customers,
    ) {}

    public function checkout(int $customerId): void {
        // Get customer from EntityData
        $customer = $this->customers->getCustomer($customerId);

        // Use customer data for your operation
        $this->sendConfirmationEmail($customer->email);
        $this->createOrder($customer);
    }
}
```

### Pattern 2: Check Availability Before Operation

**Scenario**: Check if item is available in InventoryData before creating order

```php
use Emporium\InventoryData\Service\AvailabilityService;
use Emporium\AccountData\Repository\OrderRepository;

class OrderService {
    public function __construct(
        private readonly AvailabilityService $availability,
        private readonly OrderRepository $orders,
    ) {}

    public function createOrder(int $itemId, int $qty): void {
        // Check availability via InventoryData
        if (!$this->availability->isAvailable($itemId, $qty)) {
            throw new OutOfStockException($itemId);
        }

        // Create order via AccountData
        $order = new Order($itemId, $qty);
        $this->orders->save($order);
    }
}
```

### Pattern 3: Coordinate Multiple Data Layers

**Scenario**: Create order that involves inventory and accounting

```php
use Emporium\InventoryData\Service\StockReservationService;
use Emporium\EntityData\Repository\CustomerRepository;
use Emporium\AccountData\Repository\OrderRepository;

class CompleteOrderService {
    public function __construct(
        private readonly StockReservationService $reservations,
        private readonly CustomerRepository $customers,
        private readonly OrderRepository $orders,
    ) {}

    public function completeCheckout(int $customerId, array $items): Order {
        // 1. Verify customer exists (EntityData)
        $customer = $this->customers->getCustomer($customerId);

        // 2. Reserve inventory (InventoryData)
        $reservations = [];
        foreach ($items as $item) {
            $reservations[] = $this->reservations->reserve(
                $item['id'],
                $item['quantity']
            );
        }

        // 3. Create order in accounting (AccountData)
        $order = new Order($customerId);
        $order->reservationRef = $reservations[0]->id;
        $orderId = $this->orders->save($order);

        // 4. Return complete order
        return $this->orders->getOrder($orderId);
    }
}
```

### Pattern 4: Listen to Events from Other Layers

**Scenario**: React when item stock is low in InventoryData

```php
use Joomla\Event\SubscriberInterface;
use Emporium\InventoryData\Repository\ItemRepository;

class LowStockAlert implements SubscriberInterface {
    public function __construct(
        private readonly ItemRepository $items,
    ) {}

    public static function getSubscribedEvents(): array {
        return [
            'onInventoryLowStock' => 'handleLowStock',
        ];
    }

    public function handleLowStock(object $event): void {
        $itemId = $event->getItemId();
        $item = $this->items->getItem($itemId);

        // Your custom logic here
        $this->notifyInventoryManager($item);
        $this->createPurchaseOrder($item);
    }
}
```

### Pattern 5: Update Related Data Across Layers

**Scenario**: When customer profile updates, refresh their order history

```php
use Emporium\EntityData\Repository\CustomerRepository;
use Emporium\AccountData\Repository\OrderRepository;

class CustomerService {
    public function __construct(
        private readonly CustomerRepository $customers,
        private readonly OrderRepository $orders,
    ) {}

    public function updateCustomerProfile(int $customerId, array $data): void {
        // Update in EntityData
        $customer = $this->customers->getCustomer($customerId);
        $customer->phone = $data['phone'];
        $this->customers->save($customer);

        // Refresh related orders in AccountData
        $relatedOrders = $this->orders->getOrdersByCustomer($customerId);
        foreach ($relatedOrders as $order) {
            $order->customerPhone = $data['phone'];
            $this->orders->save($order);
        }

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
// InventoryData registers its services
// services/provider.php
$container->set(
    \Emporium\InventoryData\Repository\ItemRepository::class,
    function (Container $c) {
        return new ItemRepository($c->get(DatabaseInterface::class));
    }
);

// Your extension (com_emporium) injects it
class YourService {
    public function __construct(
        // Reference by fully qualified class name
        private readonly \Emporium\InventoryData\Repository\ItemRepository $items,
    ) {}
}

// Container automatically finds and injects it
```

### Which Services Are Available?

Check the `.claude/project-ecosystem.md` in each data layer extension:

**com_inventorydata** provides:
- `Emporium\InventoryData\Repository\ItemRepository`
- `Emporium\InventoryData\Repository\CategoryRepository`
- `Emporium\InventoryData\Service\StockReservationService`
- `Emporium\InventoryData\Service\AvailabilityService`
- `Emporium\InventoryData\Service\StockService`

**com_entitydata** provides:
- `Emporium\EntityData\Repository\CustomerRepository`
- `Emporium\EntityData\Repository\SupplierRepository`
- `Emporium\EntityData\Repository\BusinessRepository`
- `Emporium\EntityData\Repository\ContactRepository`
- `Emporium\EntityData\Repository\AddressRepository`

**com_accountdata** provides:
- `Emporium\AccountData\Repository\InvoiceRepository`
- `Emporium\AccountData\Repository\OrderRepository`
- `Emporium\AccountData\Repository\PaymentRepository`
- `Emporium\AccountData\Repository\PricingRepository`
- `Emporium\AccountData\Repository\TransactionRepository`

---

## Data Referencing Patterns

### Pattern: Reference by ID, Not Object

When one layer references data from another, store IDs and snapshots, not live objects:

```php
// ❌ WRONG: Live object reference
class Invoice {
    public Customer $customer;  // Live EntityData object
}
// Problems: Customer updates retroactively change old invoices

// ✓ CORRECT: ID reference + snapshot
class Invoice {
    public int $customerId;              // Live reference
    public string $customerName;        // Snapshot
    public string $customerAddress;     // Snapshot
}
// Benefits: Invoice stays accurate to time of invoice
```

### Pattern: Load Related Data As Needed

```php
// In your service
class ReportService {
    public function __construct(
        private readonly OrderRepository $orders,
        private readonly CustomerRepository $customers,
        private readonly ItemRepository $items,
    ) {}

    public function generateOrderReport(): void {
        $orders = $this->orders->getOrders(); // From AccountData

        foreach ($orders as $order) {
            // Load customer when needed (lazy loading pattern)
            $customer = $this->customers->getCustomer($order->customerId);

            // Load items when needed
            foreach ($order->lineItems as $line) {
                $item = $this->items->getItem($line->itemId);
                // Use item data
            }
        }
    }
}
```

### Pattern: Data Snapshots in Events

When emitting events, include snapshot data:

```php
// When creating an order, emit with data at that moment
$event = new OrderCreatedEvent([
    'orderId' => $order->id,
    'customerId' => $order->customerId,
    'customerNameSnapshot' => $customer->name,        // Snapshot
    'total' => $order->total,
    'itemsSnapshot' => $order->lineItems,            // Snapshot
    'createdDate' => $order->createdDate,
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
            // InventoryData events
            'onInventoryItemCreated' => 'handleItemCreated',
            'onInventoryLowStock' => 'handleLowStock',

            // EntityData events
            'onEntityCustomerCreated' => 'handleNewCustomer',
            'onEntityCustomerUpdated' => 'handleCustomerUpdate',

            // AccountData events
            'onAccountDataInvoiceCreated' => 'handleInvoiceCreated',
            'onAccountDataPaymentReceived' => 'handlePaymentReceived',
        ];
    }

    public function handleItemCreated(object $event): void {
        $itemId = $event->getItemId();
        // Your logic here
    }

    public function handleLowStock(object $event): void {
        $item = $event->getItem();
        // Your logic here
    }

    // ... other event handlers
}
```

### Emitting Your Own Events

For other extensions to listen to:

```php
class YourService {
    public function __construct(
        private readonly DispatcherInterface $dispatcher,
    ) {}

    public function createPromotion(string $name): void {
        // Your logic

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

## Example: Complete Integration Workflow

Building a feature that spans multiple data layers:

### Step 1: Define Dependencies in Constructor

```php
namespace Emporium\Emporium\Service;

use Emporium\InventoryData\Repository\ItemRepository;
use Emporium\InventoryData\Service\StockReservationService;
use Emporium\EntityData\Repository\CustomerRepository;
use Emporium\EntityData\Repository\AddressRepository;
use Emporium\AccountData\Repository\OrderRepository;
use Emporium\AccountData\Service\OrderProcessingService;
use Joomla\Event\DispatcherInterface;

class CheckoutService {
    public function __construct(
        private readonly ItemRepository $items,
        private readonly StockReservationService $reservations,
        private readonly CustomerRepository $customers,
        private readonly AddressRepository $addresses,
        private readonly OrderRepository $orders,
        private readonly OrderProcessingService $orderProcessing,
        private readonly DispatcherInterface $dispatcher,
    ) {}

    // Service methods below...
}
```

### Step 2: Use Injected Services

```php
public function checkout(int $customerId, array $cart): Order {
    // 1. Validate customer (EntityData)
    $customer = $this->customers->getCustomer($customerId);
    if (!$customer || $customer->status !== 'active') {
        throw new InvalidCustomerException($customerId);
    }

    // 2. Get shipping address (EntityData)
    $shippingAddress = $this->addresses->getAddress($cart['shippingAddressId']);

    // 3. Check and reserve inventory (InventoryData)
    $reservations = [];
    foreach ($cart['items'] as $item) {
        $invItem = $this->items->getItem($item['id']);
        if ($invItem->currentStock < $item['qty']) {
            throw new OutOfStockException($item['id']);
        }
        $reservations[] = $this->reservations->reserve($item['id'], $item['qty']);
    }

    // 4. Create order (AccountData)
    $order = new \Emporium\AccountData\Entity\Order([
        'customerId' => $customerId,
        'customerName' => $customer->name,
        'shippingAddressId' => $shippingAddress->id,
        'items' => $cart['items'],
        'total' => $this->calculateTotal($cart),
    ]);

    $orderId = $this->orders->save($order);
    $order = $this->orders->getOrder($orderId);

    // 5. Confirm reservations (InventoryData)
    foreach ($reservations as $res) {
        $this->reservations->confirm($res);
    }

    // 6. Process order (AccountData)
    $this->orderProcessing->confirmOrder($order);

    // 7. Emit event for other extensions
    $this->dispatcher->dispatch('onEmporiumCheckoutComplete', [
        'orderId' => $orderId,
        'customerId' => $customerId,
        'total' => $order->total,
    ]);

    return $order;
}
```

### Step 3: Listen to Other Extensions' Events

```php
// In a plugin or listener class
use Joomla\Event\SubscriberInterface;

class OrderNotificationListener implements SubscriberInterface {
    public static function getSubscribedEvents(): array {
        return [
            'onEmporiumCheckoutComplete' => 'notifyCheckout',
            'onAccountDataPaymentReceived' => 'notifyPayment',
        ];
    }

    public function notifyCheckout(object $event): void {
        $orderId = $event->getOrderId();
        $customerId = $event->getCustomerId();

        // Get full order data to use in notification
        $order = $this->orderRepo->getOrder($orderId);
        $customer = $this->customerRepo->getCustomer($customerId);

        $this->emailService->sendOrderConfirmation($customer, $order);
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
3. Check `.claude/project-ecosystem.md` for available services
4. Ensure service provider registers the service in `services/provider.php`

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
3. Listen to event and update snapshots in orders

### Issue: Performance

**Problem**: Loading order with 100 line items, each loading full item data

**Solution**:
1. Batch load: `$items = $itemRepo->getItems(['ids' => [...]])`
2. Cache frequently accessed data
3. Use lazy loading pattern (load only when needed)

---

## Best Practices

### ✓ DO:

1. **Inject services** via constructor
2. **Use repositories** for all data access
3. **Listen to events** for inter-layer communication
4. **Store IDs + snapshots** when referencing other data
5. **Document your dependencies** in `.claude/project-ecosystem.md`
6. **Check availability** before operations
7. **Use interfaces** for all public services

### ✗ DON'T:

1. **Service locator**: Don't use `Factory::getContainer()->get()`
2. **Direct queries**: Don't bypass repositories with raw SQL
3. **Cross-extension direct calls**: Use events instead
4. **Hard-code class names**: Reference via interfaces
5. **Assume data is current**: Load fresh or use snapshots
6. **Modify other extensions' data**: Use their repositories
7. **Emit events** that reference domain extensions

---

## Related Documentation

- **Project Ecosystem Overview**: `PROJECT-ECOSYSTEM.md`
- **InventoryData**: `../templates/project-ecosystem.inventorydata-template.md`
- **EntityData**: `../templates/project-ecosystem.entitydata-template.md`
- **AccountData**: `../templates/project-ecosystem.accountdata-template.md`
- **DI Patterns**: `joomla5-di-patterns.md`
- **Service Layer**: `agent-usage-guide.md` (Service Layer Architecture section)
