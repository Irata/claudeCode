# com_inventorydata — Ecosystem Role & API

## Extension Purpose

Central inventory data access layer for the Emporium ecosystem. Manages all inventory-related data (items, categories, stock levels, reservations, suppliers, lists) so multiple extensions can share the same inventory source without duplication.

**Type**: Data Access Layer
**Scope**: Inventory management and stock control
**Status**: Core data provider

---

## Data Managed

### Entities
- **Item** — Products/inventory items (name, SKU, description, pricing, categorization)
- **Category** — Inventory categories and hierarchies
- **Stock** — Current stock levels per warehouse/location
- **Reservation** — Temporary stock reservations for orders/transactions
- **Supplier** — Supplier/vendor information (references com_entitydata)
- **List** — Predefined item collections (bundles, catalogs, promotions)
- **ItemAttribute** — Dynamic attributes on items (color, size, etc.)

### Data Sources
- Items table: `#__inventorydata_items`
- Categories table: `#__inventorydata_categories`
- Stock table: `#__inventorydata_stock`
- Reservations table: `#__inventorydata_reservations`
- Lists table: `#__inventorydata_lists`
- Item-List mappings: `#__inventorydata_list_items`

---

## Provided Services (Public API)

### Repositories

**ItemRepository**
```php
namespace Emporium\InventoryData\Repository;

interface ItemRepository {
    // Retrieve
    public function getItem(int $id): Item;
    public function getItems(ItemFilter $filter): ItemCollection;
    public function getItemBySKU(string $sku): ?Item;
    public function getItemsBySupplier(int $supplierId): ItemCollection;

    // Create/Update
    public function save(Item $item): int;  // Returns ID
    public function delete(int $id): void;

    // Search
    public function search(string $query): ItemCollection;
    public function findByCriteria(array $criteria): ItemCollection;
}
```

**CategoryRepository**
```php
namespace Emporium\InventoryData\Repository;

interface CategoryRepository {
    // Retrieve
    public function getCategory(int $id): Category;
    public function getCategories(): CategoryCollection;
    public function getCategoryTree(): CategoryTree;
    public function getChildren(int $parentId): CategoryCollection;

    // Create/Update
    public function save(Category $category): int;
    public function delete(int $id): void;

    // Hierarchy
    public function getPath(int $categoryId): array;  // Breadcrumb path
}
```

**StockReservationService**
```php
namespace Emporium\InventoryData\Service;

interface StockReservationService {
    // Reserve stock
    public function reserve(int $itemId, int $quantity, ?string $reference = null): Reservation;

    // Confirm/Release reservation
    public function confirm(Reservation $reservation): void;
    public function release(Reservation $reservation): void;
    public function releaseByReference(string $reference): void;

    // Query
    public function getReservation(int $reservationId): Reservation;
    public function getReservationsForItem(int $itemId): ReservationCollection;
    public function getReservationsForReference(string $reference): ReservationCollection;

    // Bulk operations
    public function reserveMultiple(array $items): ReservationBatch;  // [{itemId, qty}]
    public function releaseMultiple(array $reservationIds): void;
}
```

**ListRepository**
```php
namespace Emporium\InventoryData\Repository;

interface ListRepository {
    // Retrieve
    public function getList(int $id): ItemList;
    public function getLists(): ListCollection;
    public function getListsByType(string $type): ListCollection;

    // Create/Update
    public function save(ItemList $list): int;
    public function delete(int $id): void;

    // Items in list
    public function getListItems(int $listId): ItemCollection;
    public function addItem(int $listId, int $itemId): void;
    public function removeItem(int $listId, int $itemId): void;
}
```

### Business Logic Services

**AvailabilityService**
```php
namespace Emporium\InventoryData\Service;

interface AvailabilityService {
    // Check availability
    public function isAvailable(int $itemId, int $quantity): bool;
    public function getAvailableQuantity(int $itemId): int;
    public function getAvailabilityStatus(int $itemId): AvailabilityStatus;

    // Predict availability
    public function predictAvailability(int $itemId, \DateTime $date): int;
}
```

**StockService**
```php
namespace Emporium\InventoryData\Service;

interface StockService {
    // Adjust stock
    public function adjustStock(int $itemId, int $adjustment, string $reason): void;
    public function setStock(int $itemId, int $quantity): void;

    // Transfer between locations
    public function transfer(int $fromLocation, int $toLocation, int $itemId, int $quantity): void;

    // Reporting
    public function getLowStockItems(int $threshold = 10): ItemCollection;
    public function getStockMovement(int $itemId, \DatePeriod $period): MovementCollection;
}
```

---

## Events Emitted

This extension broadcasts events when inventory data changes. Other extensions listen and react.

### Item Events
- **onInventoryItemCreated**
  - Fired when new item created
  - Data: `itemId`, `sku`, `name`, `categoryId`, `supplierId`

- **onInventoryItemUpdated**
  - Fired when item modified
  - Data: `itemId`, `changes` (array of what changed)

- **onInventoryItemDeleted**
  - Fired when item deleted
  - Data: `itemId`, `sku`, `name`

### Stock Events
- **onInventoryStockReserved**
  - Fired when stock reserved
  - Data: `itemId`, `quantity`, `reservationId`, `reference` (e.g., order ID)

- **onInventoryStockReleased**
  - Fired when reservation released
  - Data: `itemId`, `quantity`, `reservationId`, `reason`

- **onInventoryStockConfirmed**
  - Fired when reservation confirmed (committed)
  - Data: `itemId`, `quantity`, `reservationId`, `reference`

- **onInventoryLowStock**
  - Fired when item stock falls below threshold
  - Data: `itemId`, `currentStock`, `threshold`

- **onInventoryOutOfStock**
  - Fired when item becomes unavailable
  - Data: `itemId`, `sku`, `name`

### Category Events
- **onInventoryCategoryCreated**
  - Data: `categoryId`, `name`, `parentId`

- **onInventoryCategoryUpdated**
  - Data: `categoryId`, `changes`

- **onInventoryCategoryDeleted**
  - Data: `categoryId`, `name`

### List Events
- **onInventoryListCreated**
  - Data: `listId`, `name`, `type`

- **onInventoryListItemAdded**
  - Data: `listId`, `itemId`

- **onInventoryListItemRemoved**
  - Data: `listId`, `itemId`

---

## Events Consumed

Data layer extensions do NOT consume events from other extensions. They are pure data providers.

---

## Dependencies on Other Data Layers

### com_entitydata (Supplier Information)
- **References**: Supplier entity comes from com_entitydata
- **Usage**: ItemRepository returns items with supplier details
- **Integration**: When supplier is updated in com_entitydata, com_inventorydata may need to refresh

```php
// Item entity includes supplier reference
class Item {
    public int $supplierId;  // Link to EntityData\Supplier
    public ?Supplier $supplier;  // Lazy-loaded from com_entitydata
}
```

### com_accountdata (Pricing)
- **References**: Item pricing from com_accountdata (optional, read-only)
- **Usage**: For inventory valuation reporting
- **Integration**: Read-only reference, inventorydata doesn't modify accounting data

```php
// May reference pricing from com_accountdata
class Item {
    public float $cost;  // From AccountData if configured
    public ?PricingTier $pricingTier;  // Reference to AccountData pricing
}
```

---

## Extensions That Consume This Data Layer

### Primary Consumers
1. **com_emporium** (Required)
   - Uses: ItemRepository, StockReservationService, AvailabilityService
   - Listens to: onInventoryStockReserved, onInventoryStockConfirmed, onInventoryLowStock

2. **future_shop** (Planned)
   - Uses: ItemRepository, AvailabilityService, CategoryRepository
   - Listens to: onInventoryItemUpdated, onInventoryOutOfStock

3. **extension_invoicing** (Planned)
   - Uses: ItemRepository (for line items), StockService (for inventory valuation)
   - Listens to: onInventoryItemUpdated (cost changes)

### Secondary Consumers
4. **extension_mailing**
   - Uses: ItemRepository (product details for emails)
   - Listens to: onInventoryLowStock (send alerts)

5. **extension_dropshipping** (Future)
   - Uses: StockReservationService, StockService, AvailabilityService
   - Listens to: onInventoryLowStock (auto-reorder)

---

## Shared Entities

These entities are used across multiple extensions. Defined here, consumed everywhere.

### Item Entity
```php
namespace Emporium\InventoryData\Entity;

class Item {
    public int $id;
    public string $sku;
    public string $name;
    public string $description;
    public int $categoryId;
    public int $supplierId;  // From com_entitydata
    public float $weight;
    public array $dimensions;
    public bool $trackStock;
    public int $currentStock;
    public int $reorderLevel;
    public bool $published;
    public \DateTime $createdDate;
    public \DateTime $modifiedDate;
    public int $createdBy;
    public int $modifiedBy;

    // Lazy-loaded relations
    public ?Category $category;
    public ?Supplier $supplier;  // From EntityData
    public ?PricingTier $pricing;  // From AccountData
    public array $attributes = [];
}
```

### Category Entity
```php
namespace Emporium\InventoryData\Entity;

class Category {
    public int $id;
    public string $name;
    public string $alias;
    public string $description;
    public ?int $parentId;
    public int $level;
    public string $path;  // /parent/child/name
    public int $ordering;
    public bool $published;
    public array $metadata = [];
}
```

### Reservation Entity
```php
namespace Emporium\InventoryData\Entity;

class Reservation {
    public int $id;
    public int $itemId;
    public int $quantity;
    public string $status;  // 'pending', 'confirmed', 'released'
    public string $reference;  // e.g., order-123, quote-456
    public \DateTime $reservedDate;
    public \DateTime $expiryDate;
    public ?int $confirmedBy;
    public ?\DateTime $confirmedDate;
    public ?int $releasedBy;
    public ?\DateTime $releasedDate;
    public string $reason;  // Why reserved/released
}
```

### Supplier Entity (Reference)
```php
// Defined in com_entitydata, but used here for type hints
namespace Emporium\EntityData\Entity;

class Supplier {
    public int $id;
    public string $name;
    public string $email;
    public string $phone;
    public string $country;
    public float $leadTime;  // Days
    public int $minimumOrder;
    // ... more fields
}
```

---

## Namespace Structure

```
Emporium\InventoryData\
├── Repository\
│   ├── ItemRepository.php
│   ├── CategoryRepository.php
│   ├── ListRepository.php
│   └── ItemRepositoryInterface.php
├── Service\
│   ├── StockReservationService.php
│   ├── AvailabilityService.php
│   ├── StockService.php
│   └── ...ServiceInterface.php
├── Entity\
│   ├── Item.php
│   ├── Category.php
│   ├── Reservation.php
│   ├── Supplier.php  (reference to EntityData)
│   └── ...
├── Event\
│   ├── ItemCreatedEvent.php
│   ├── StockReservedEvent.php
│   └── ...Event.php
├── Exception\
│   ├── ItemNotFoundException.php
│   ├── InsufficientStockException.php
│   └── ...Exception.php
└── Filter\
    ├── ItemFilter.php
    ├── CategoryFilter.php
    └── ...Filter.php
```

---

## Service Registration

In `services/provider.php`, all public services are registered:

```php
// Item data access
$container->set(ItemRepository::class, function (Container $c) { ... });
$container->set(CategoryRepository::class, function (Container $c) { ... });
$container->set(ListRepository::class, function (Container $c) { ... });

// Business logic services
$container->set(StockReservationService::class, function (Container $c) { ... });
$container->set(AvailabilityService::class, function (Container $c) { ... });
$container->set(StockService::class, function (Container $c) { ... });

// Model factories for DI
$container->set(ItemModel::class, function (Container $c) { ... });
$container->set(CategoryModel::class, function (Container $c) { ... });
```

---

## How Other Extensions Use This

### Example: com_emporium OrderService

```php
namespace Emporium\Emporium\Service;

use Emporium\InventoryData\Repository\ItemRepository;
use Emporium\InventoryData\Service\StockReservationService;
use Emporium\InventoryData\Service\AvailabilityService;

class OrderService {
    public function __construct(
        private readonly ItemRepository $items,
        private readonly StockReservationService $reservations,
        private readonly AvailabilityService $availability,
    ) {}

    public function createOrder(OrderData $orderData): Order {
        // Check all items are available
        foreach ($orderData->items as $item) {
            if (!$this->availability->isAvailable($item['id'], $item['quantity'])) {
                throw new InsufficientStockException($item['id']);
            }
        }

        // Reserve stock
        $reservationBatch = $this->reservations->reserveMultiple($orderData->items);

        // Create order (saved to AccountData by OrderRepository)
        $order = new Order($orderData);
        $order->reservationReference = $reservationBatch->reference;

        // Order created — fire event for other extensions
        $this->dispatcher->dispatch(
            'onEmporiumOrderCreated',
            ['orderId' => $order->id, 'reservationRef' => $reservationBatch->reference]
        );

        return $order;
    }

    public function completeOrder(Order $order): void {
        // Confirm stock reservation (converts to actual stock deduction)
        $this->reservations->confirm($order->reservationReference);

        // Update order status
        $order->status = 'completed';
    }
}
```

### Example: com_mailing Listening to Events

```php
namespace Emporium\Mailing\Plugin;

class InventoryListener {
    public static function getSubscribedEvents(): array {
        return [
            'onInventoryLowStock' => 'alertLowStock',
            'onInventoryOutOfStock' => 'alertOutOfStock',
        ];
    }

    public function alertLowStock(object $event): void {
        $item = $event->getItem();
        // Send email to inventory manager
        $this->emailService->send([
            'to' => 'inventory@company.com',
            'subject' => "Low Stock Alert: {$item->name}",
            'body' => "Item {$item->sku} is low on stock ({$item->currentStock} remaining)",
        ]);
    }
}
```

---

## Data Consistency Rules

- **Stock Levels**: Sum of all reservations + confirmed stock = total available
- **Reservations**: Expire automatically after 7 days if not confirmed
- **Categories**: Hierarchical, max 5 levels deep
- **SKUs**: Must be unique across all items
- **Suppliers**: Must exist in com_entitydata before linking

---

## Database Tables

```sql
-- Items
CREATE TABLE `#__inventorydata_items` (
    id INT PRIMARY KEY AUTO_INCREMENT,
    sku VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    category_id INT,
    supplier_id INT,  -- Link to EntityData supplier
    weight DECIMAL(8,2),
    dimensions JSON,
    track_stock TINYINT(1),
    current_stock INT DEFAULT 0,
    reorder_level INT DEFAULT 0,
    published TINYINT(1) DEFAULT 1,
    created_date DATETIME,
    modified_date DATETIME,
    created_by INT,
    modified_by INT
);

-- Stock Reservations
CREATE TABLE `#__inventorydata_reservations` (
    id INT PRIMARY KEY AUTO_INCREMENT,
    item_id INT NOT NULL,
    quantity INT NOT NULL,
    status ENUM('pending', 'confirmed', 'released'),
    reference VARCHAR(100),  -- e.g., "order-123"
    reserved_date DATETIME,
    expiry_date DATETIME,
    confirmed_by INT,
    confirmed_date DATETIME,
    released_by INT,
    released_date DATETIME,
    reason VARCHAR(255)
);
```

---

## Related Documentation

- Architecture: `.claude/ARCHITECTURE.md`
- Ecosystem Overview: `..\..\ClaudeCode\docs\PROJECT-ECOSYSTEM.md`
- Integration Guide: `..\..\ClaudeCode\docs\INTERPROJECT-REFERENCES.md`
