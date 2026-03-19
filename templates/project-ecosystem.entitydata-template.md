# com_entitydata — Ecosystem Role & API

## Extension Purpose

Central entity data management layer for the Emporium ecosystem. Manages all people and business entity data (customers, suppliers, businesses, contacts, addresses) so multiple extensions can share the same entity source without duplication.

**Type**: Data Access Layer
**Scope**: Entity and relationship management
**Status**: Core data provider

---

## Data Managed

### Entities
- **Customer** — Individual or business customers (buyers, end-users)
- **Supplier** — Suppliers, vendors, wholesalers
- **Business** — Legal entities (companies, organizations, partnerships)
- **Contact** — Individual contacts within businesses
- **Address** — Physical addresses for entities
- **Relationship** — Relationships between entities (parent company, affiliated businesses)
- **Classification** — Customer/Supplier categories and segmentation

### Data Sources
- Customers table: `#__entitydata_customers`
- Suppliers table: `#__entitydata_suppliers`
- Businesses table: `#__entitydata_businesses`
- Contacts table: `#__entitydata_contacts`
- Addresses table: `#__entitydata_addresses`
- Relationships table: `#__entitydata_relationships`
- Classifications table: `#__entitydata_classifications`

---

## Provided Services (Public API)

### Repositories

**CustomerRepository**
```php
namespace Emporium\EntityData\Repository;

interface CustomerRepository {
    // Retrieve
    public function getCustomer(int $id): Customer;
    public function getCustomers(?CustomerFilter $filter = null): CustomerCollection;
    public function getCustomerByEmail(string $email): ?Customer;
    public function getCustomerByPhone(string $phone): ?Customer;

    // Create/Update
    public function save(Customer $customer): int;  // Returns ID
    public function delete(int $id): void;

    // Relationships
    public function getContacts(int $customerId): ContactCollection;
    public function getAddresses(int $customerId): AddressCollection;
    public function getPrimaryAddress(int $customerId): ?Address;

    // Search
    public function search(string $query): CustomerCollection;
    public function findByCriteria(array $criteria): CustomerCollection;
}
```

**SupplierRepository**
```php
namespace Emporium\EntityData\Repository;

interface SupplierRepository {
    // Retrieve
    public function getSupplier(int $id): Supplier;
    public function getSuppliers(?SupplierFilter $filter = null): SupplierCollection;
    public function getSupplierByCode(string $code): ?Supplier;

    // Create/Update
    public function save(Supplier $supplier): int;
    public function delete(int $id): void;

    // Relationships
    public function getContacts(int $supplierId): ContactCollection;
    public function getAddresses(int $supplierId): AddressCollection;
    public function getCategories(int $supplierId): CategoryCollection;

    // Search
    public function search(string $query): SupplierCollection;
    public function findByCriteria(array $criteria): SupplierCollection;
}
```

**BusinessRepository**
```php
namespace Emporium\EntityData\Repository;

interface BusinessRepository {
    // Retrieve
    public function getBusiness(int $id): Business;
    public function getBusinesses(): BusinessCollection;
    public function getBusinessByRegistration(string $registrationNumber): ?Business;
    public function getBusinessByTax(string $taxId): ?Business;

    // Create/Update
    public function save(Business $business): int;
    public function delete(int $id): void;

    // Hierarchy
    public function getRelated(int $businessId): BusinessCollection;  // Parent, subsidiaries, affiliates
    public function getParent(int $businessId): ?Business;
    public function getSubsidiaries(int $businessId): BusinessCollection;
}
```

**ContactRepository**
```php
namespace Emporium\EntityData\Repository;

interface ContactRepository {
    // Retrieve
    public function getContact(int $id): Contact;
    public function getContactsForEntity(int $entityId, string $entityType): ContactCollection;
    public function getContactByEmail(string $email): ?Contact;

    // Create/Update
    public function save(Contact $contact): int;
    public function delete(int $id): void;

    // Bulk
    public function getContactsByRole(string $role): ContactCollection;
}
```

**AddressRepository**
```php
namespace Emporium\EntityData\Repository;

interface AddressRepository {
    // Retrieve
    public function getAddress(int $id): Address;
    public function getAddressesForEntity(int $entityId, string $entityType): AddressCollection;
    public function getPrimaryAddress(int $entityId, string $entityType): ?Address;

    // Create/Update
    public function save(Address $address): int;
    public function setPrimary(int $addressId): void;
    public function delete(int $id): void;
}
```

### Business Logic Services

**EntityRelationshipService**
```php
namespace Emporium\EntityData\Service;

interface EntityRelationshipService {
    // Define relationships
    public function createRelationship(int $fromId, int $toId, string $type): void;
    public function deleteRelationship(int $fromId, int $toId, string $type): void;

    // Query relationships
    public function getRelationships(int $entityId): RelationshipCollection;
    public function hasRelationship(int $fromId, int $toId, string $type): bool;

    // Types: 'parent_company', 'subsidiary', 'affiliated', 'distributor', 'reseller'
}
```

**CustomerClassificationService**
```php
namespace Emporium\EntityData\Service;

interface CustomerClassificationService {
    // Classification (VIP, wholesale, retail, preferred, etc.)
    public function classify(int $customerId, string $classification): void;
    public function getClassifications(int $customerId): array;
    public function removeClassification(int $customerId, string $classification): void;
}
```

**EntityValidationService**
```php
namespace Emporium\EntityData\Service;

interface EntityValidationService {
    // Validation
    public function validateCustomer(Customer $customer): ValidationResult;
    public function validateSupplier(Supplier $supplier): ValidationResult;
    public function validateBusiness(Business $business): ValidationResult;
    public function validateAddress(Address $address): ValidationResult;
}
```

---

## Events Emitted

This extension broadcasts events when entity data changes.

### Customer Events
- **onEntityCustomerCreated**
  - Data: `customerId`, `name`, `email`, `type` (individual/business)

- **onEntityCustomerUpdated**
  - Data: `customerId`, `changes` (array of fields modified)

- **onEntityCustomerDeleted**
  - Data: `customerId`, `name`, `email`

- **onEntityCustomerClassified**
  - Data: `customerId`, `classification` (VIP, wholesale, etc.)

### Supplier Events
- **onEntitySupplierCreated**
  - Data: `supplierId`, `name`, `email`, `country`

- **onEntitySupplierUpdated**
  - Data: `supplierId`, `changes`

- **onEntitySupplierDeleted**
  - Data: `supplierId`, `name`

- **onEntitySupplierStatusChanged**
  - Data: `supplierId`, `previousStatus`, `newStatus` (active, inactive, suspended)

### Business Events
- **onEntityBusinessCreated**
  - Data: `businessId`, `name`, `registrationNumber`, `taxId`

- **onEntityBusinessUpdated**
  - Data: `businessId`, `changes`

- **onEntityBusinessDeleted**
  - Data: `businessId`, `name`

### Contact Events
- **onEntityContactCreated**
  - Data: `contactId`, `entityId`, `entityType`, `name`, `email`, `role`

- **onEntityContactUpdated**
  - Data: `contactId`, `changes`

- **onEntityContactDeleted**
  - Data: `contactId`, `name`

### Address Events
- **onEntityAddressCreated**
  - Data: `addressId`, `entityId`, `entityType`, `country`, `type` (billing/shipping)

- **onEntityAddressUpdated**
  - Data: `addressId`, `changes`

- **onEntityAddressDeleted**
  - Data: `addressId`, `entityId`

### Relationship Events
- **onEntityRelationshipCreated**
  - Data: `fromId`, `toId`, `type` (parent_company, subsidiary, etc.)

- **onEntityRelationshipDeleted**
  - Data: `fromId`, `toId`, `type`

---

## Events Consumed

Data layer extensions do NOT consume events from other extensions.

---

## Dependencies on Other Data Layers

### No Direct Dependencies
EntityData does NOT depend on com_inventorydata or com_accountdata. It is a standalone data layer providing entity information.

However, other extensions may reference EntityData entities:
- com_inventorydata references Supplier (supplier_id foreign key)
- com_accountdata references Customer and Business (for invoicing)

---

## Extensions That Consume This Data Layer

### Primary Consumers
1. **com_emporium** (Required)
   - Uses: CustomerRepository, SupplierRepository, BusinessRepository, AddressRepository
   - Listens to: onEntityCustomerUpdated, onEntityAddressUpdated

2. **future_shop** (Planned)
   - Uses: CustomerRepository, AddressRepository
   - Listens to: onEntityCustomerUpdated

3. **extension_invoicing** (Required)
   - Uses: CustomerRepository, BusinessRepository, AddressRepository
   - Listens to: onEntityCustomerUpdated, onEntityBusinessUpdated

### Secondary Consumers
4. **extension_mailing**
   - Uses: CustomerRepository (email, contact preferences)
   - Listens to: onEntityCustomerCreated (welcome email), onEntityCustomerUpdated (profile changes)

5. **extension_accounts** (Future)
   - Uses: CustomerRepository, BusinessRepository (account holders)
   - Listens to: onEntityCustomerClassified (credit tier changes)

6. **com_inventorydata**
   - Uses: SupplierRepository (supplier details on items)
   - Listens to: onEntitySupplierUpdated (pricing/lead time changes)

---

## Shared Entities

These entities are used across multiple extensions.

### Customer Entity
```php
namespace Emporium\EntityData\Entity;

class Customer {
    public int $id;
    public int $asset_id;
    public string $type;  // 'individual' or 'business'
    public string $name;
    public string $alias;
    public string $email;
    public string $phone;
    public string $mobilePhone;
    public string $taxId;  // VAT/Tax ID if business
    public string $registrationNumber;  // For businesses
    public string $country;
    public string $currency;  // Preferred currency
    public array $classifications;  // VIP, wholesale, retail, preferred
    public float $creditLimit;

    // Standard Joomla system fields
    public int $state;              // 1=published, 0=unpublished, 2=archived, -2=trashed
    public int $ordering;
    public int $access;
    public \DateTime $created;
    public int $created_by;
    public ?\DateTime $modified;
    public int $modified_by;
    public ?int $checked_out;
    public ?\DateTime $checked_out_time;
    public string $language;
    public string $note;

    // Lazy-loaded relations
    public ?Business $business;  // If type='business'
    public array $contacts = [];
    public array $addresses = [];
    public ?Address $primaryAddress;
}
```

### Supplier Entity
```php
namespace Emporium\EntityData\Entity;

class Supplier {
    public int $id;
    public int $asset_id;
    public string $name;
    public string $alias;
    public string $code;  // Supplier code/ID
    public string $email;
    public string $phone;
    public string $website;
    public string $country;
    public string $taxId;
    public float $leadTime;  // Days to delivery
    public int $minimumOrderQuantity;
    public float $minimumOrderValue;
    public string $paymentTerms;  // Net 30, COD, etc.
    public float $rating;  // Quality rating
    public array $categories;  // Supplier categories

    // Standard Joomla system fields
    public int $state;              // 1=published, 0=unpublished, 2=archived, -2=trashed
    public int $ordering;
    public int $access;
    public \DateTime $created;
    public int $created_by;
    public ?\DateTime $modified;
    public int $modified_by;
    public ?int $checked_out;
    public ?\DateTime $checked_out_time;
    public string $language;
    public string $note;

    // Lazy-loaded relations
    public array $contacts = [];
    public array $addresses = [];
    public ?Address $primaryAddress;
}
```

### Business Entity
```php
namespace Emporium\EntityData\Entity;

class Business {
    public int $id;
    public int $asset_id;
    public string $name;
    public string $alias;
    public string $legalName;
    public string $registrationNumber;
    public string $taxId;
    public string $taxStatus;  // 'registered', 'pending', 'exempt'
    public string $businessType;  // 'corporation', 'partnership', 'sole_trader', 'non_profit'
    public string $industryCode;
    public int $employeeCount;
    public string $country;
    public string $founded;  // Year

    // Standard Joomla system fields
    public int $state;
    public int $ordering;
    public int $access;
    public \DateTime $created;
    public int $created_by;
    public ?\DateTime $modified;
    public int $modified_by;
    public ?int $checked_out;
    public ?\DateTime $checked_out_time;
    public string $language;
    public string $note;

    // Relationships
    public ?int $parentBusinessId;  // If subsidiary
    public array $relationships = [];  // Other related businesses

    // Lazy-loaded
    public array $contacts = [];
    public array $addresses = [];
}
```

### Contact Entity
```php
namespace Emporium\EntityData\Entity;

class Contact {
    public int $id;
    public int $entityId;  // Customer/Supplier/Business ID
    public string $entityType;  // 'customer', 'supplier', 'business'
    public string $firstName;
    public string $lastName;
    public string $title;  // Mr, Ms, Dr, etc.
    public string $role;  // 'buyer', 'accounts', 'shipping', 'technical', etc.
    public string $email;
    public string $phone;
    public string $mobilePhone;
    public bool $primaryContact;
    public string $department;

    // Secondary entity — minimum Joomla system fields
    public int $state;
    public \DateTime $created;
    public int $created_by;
    public ?\DateTime $modified;
    public int $modified_by;
}
```

### Address Entity
```php
namespace Emporium\EntityData\Entity;

class Address {
    public int $id;
    public int $entityId;  // Customer/Supplier/Business ID
    public string $entityType;  // 'customer', 'supplier', 'business'
    public string $type;  // 'billing', 'shipping', 'headquarters', 'warehouse'
    public string $name;  // Label for address (e.g., "Main Office")
    public string $line1;
    public string $line2;
    public string $city;
    public string $stateProvince;
    public string $postalCode;
    public string $country;
    public string $phone;
    public bool $isPrimary;
    public string $deliveryInstructions;

    // Secondary entity — minimum Joomla system fields
    public int $state;
    public \DateTime $created;
    public int $created_by;
    public ?\DateTime $modified;
    public int $modified_by;
}
```

### Relationship Entity
```php
namespace Emporium\EntityData\Entity;

// Link/join table — system fields NOT required, keep minimal
class Relationship {
    public int $id;
    public int $fromId;  // Entity ID
    public int $toId;    // Related entity ID
    public string $type;  // 'parent_company', 'subsidiary', 'affiliated', 'distributor', 'reseller'
    public string $status;  // 'active', 'inactive'
    public string $details;  // Additional context
    public \DateTime $created;
}
```

---

## Namespace Structure

```
Emporium\EntityData\
├── Repository\
│   ├── CustomerRepository.php
│   ├── SupplierRepository.php
│   ├── BusinessRepository.php
│   ├── ContactRepository.php
│   ├── AddressRepository.php
│   └── ...RepositoryInterface.php
├── Service\
│   ├── EntityRelationshipService.php
│   ├── CustomerClassificationService.php
│   ├── EntityValidationService.php
│   └── ...ServiceInterface.php
├── Entity\
│   ├── Customer.php
│   ├── Supplier.php
│   ├── Business.php
│   ├── Contact.php
│   ├── Address.php
│   ├── Relationship.php
│   ├── Classification.php
│   └── ...
├── Event\
│   ├── CustomerCreatedEvent.php
│   ├── CustomerUpdatedEvent.php
│   ├── SupplierStatusChangedEvent.php
│   └── ...Event.php
├── Exception\
│   ├── CustomerNotFoundException.php
│   ├── DuplicateEntityException.php
│   └── ...Exception.php
└── Filter\
    ├── CustomerFilter.php
    ├── SupplierFilter.php
    └── ...Filter.php
```

---

## Service Registration

In `services/provider.php`:

```php
// Customer data access
$container->set(CustomerRepository::class, function (Container $c) { ... });
$container->set(SupplierRepository::class, function (Container $c) { ... });
$container->set(BusinessRepository::class, function (Container $c) { ... });
$container->set(ContactRepository::class, function (Container $c) { ... });
$container->set(AddressRepository::class, function (Container $c) { ... });

// Business logic services
$container->set(EntityRelationshipService::class, function (Container $c) { ... });
$container->set(CustomerClassificationService::class, function (Container $c) { ... });
$container->set(EntityValidationService::class, function (Container $c) { ... });

// Model factories
$container->set(CustomerModel::class, function (Container $c) { ... });
$container->set(SupplierModel::class, function (Container $c) { ... });
```

---

## How Other Extensions Use This

### Example: com_emporium OrderService Using EntityData

```php
namespace Emporium\Emporium\Service;

use Emporium\EntityData\Repository\CustomerRepository;
use Emporium\EntityData\Repository\AddressRepository;

class OrderService {
    public function __construct(
        private readonly CustomerRepository $customers,
        private readonly AddressRepository $addresses,
    ) {}

    public function createOrder(int $customerId, OrderData $orderData): Order {
        // Load customer from EntityData
        $customer = $this->customers->getCustomer($customerId);

        // Load customer's shipping address
        $shippingAddress = $this->addresses->getAddress($orderData->shippingAddressId);

        // Create order with customer and address details
        $order = new Order($orderData);
        $order->customer = $customer;
        $order->shippingAddress = $shippingAddress;

        return $order;
    }
}
```

### Example: com_mailing Listening to EntityData Events

```php
namespace Emporium\Mailing\Plugin;

class EntityListener {
    public static function getSubscribedEvents(): array {
        return [
            'onEntityCustomerCreated' => 'sendWelcomeEmail',
            'onEntityCustomerUpdated' => 'handleProfileChange',
        ];
    }

    public function sendWelcomeEmail(object $event): void {
        $customer = $event->getCustomer();
        $this->emailService->send([
            'to' => $customer->email,
            'template' => 'welcome',
            'variables' => ['name' => $customer->name],
        ]);
    }
}
```

---

## Data Consistency Rules

- **Email**: Must be unique per customer type (a supplier can have same email as customer)
- **Tax ID**: Unique per business
- **Primary Address**: Only one per entity per type
- **Contacts**: At least one contact required for business customers
- **Classifications**: Multi-valued (customer can be both VIP and wholesale)
- **Relationships**: Cannot be circular (B→A if A→B already exists)

---

## Database Tables

```sql
-- Customers (CORE/CRUD table — full Joomla system fields)
CREATE TABLE IF NOT EXISTS `#__entitydata_customers` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `asset_id` INT UNSIGNED NOT NULL DEFAULT 0,
    `type` ENUM('individual', 'business') NOT NULL DEFAULT 'individual',
    `name` VARCHAR(255) NOT NULL DEFAULT '',
    `alias` VARCHAR(400) NOT NULL DEFAULT '',
    `email` VARCHAR(255),
    `phone` VARCHAR(20),
    `mobile_phone` VARCHAR(20),
    `tax_id` VARCHAR(50),
    `registration_number` VARCHAR(50),
    `country` VARCHAR(2),
    `currency` VARCHAR(3),
    `credit_limit` DECIMAL(12,2),
    `state` TINYINT(1) NOT NULL DEFAULT 0,
    `ordering` INT NOT NULL DEFAULT 0,
    `access` INT UNSIGNED NOT NULL DEFAULT 1,
    `created` DATETIME NOT NULL,
    `created_by` INT UNSIGNED NOT NULL DEFAULT 0,
    `modified` DATETIME,
    `modified_by` INT UNSIGNED NOT NULL DEFAULT 0,
    `checked_out` INT UNSIGNED,
    `checked_out_time` DATETIME,
    `language` CHAR(7) NOT NULL DEFAULT '*',
    `note` VARCHAR(255) NOT NULL DEFAULT '',
    PRIMARY KEY (`id`),
    UNIQUE KEY `idx_email` (`email`),
    KEY `idx_state` (`state`),
    KEY `idx_created_by` (`created_by`),
    KEY `idx_access` (`access`),
    KEY `idx_checked_out` (`checked_out`),
    KEY `idx_language` (`language`),
    KEY `idx_alias` (`alias`(191))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Suppliers (CORE/CRUD table — full Joomla system fields)
CREATE TABLE IF NOT EXISTS `#__entitydata_suppliers` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `asset_id` INT UNSIGNED NOT NULL DEFAULT 0,
    `name` VARCHAR(255) NOT NULL DEFAULT '',
    `alias` VARCHAR(400) NOT NULL DEFAULT '',
    `code` VARCHAR(50) NOT NULL,
    `email` VARCHAR(255),
    `phone` VARCHAR(20),
    `website` VARCHAR(255),
    `country` VARCHAR(2),
    `tax_id` VARCHAR(50),
    `lead_time` INT,                                -- Days
    `minimum_order_qty` INT,
    `minimum_order_value` DECIMAL(12,2),
    `payment_terms` VARCHAR(50),
    `rating` DECIMAL(3,2),
    `state` TINYINT(1) NOT NULL DEFAULT 0,
    `ordering` INT NOT NULL DEFAULT 0,
    `access` INT UNSIGNED NOT NULL DEFAULT 1,
    `created` DATETIME NOT NULL,
    `created_by` INT UNSIGNED NOT NULL DEFAULT 0,
    `modified` DATETIME,
    `modified_by` INT UNSIGNED NOT NULL DEFAULT 0,
    `checked_out` INT UNSIGNED,
    `checked_out_time` DATETIME,
    `language` CHAR(7) NOT NULL DEFAULT '*',
    `note` VARCHAR(255) NOT NULL DEFAULT '',
    PRIMARY KEY (`id`),
    UNIQUE KEY `idx_code` (`code`),
    KEY `idx_state` (`state`),
    KEY `idx_created_by` (`created_by`),
    KEY `idx_access` (`access`),
    KEY `idx_checked_out` (`checked_out`),
    KEY `idx_language` (`language`),
    KEY `idx_alias` (`alias`(191))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Addresses (Secondary entity table — admin-managed, minimum system fields)
CREATE TABLE IF NOT EXISTS `#__entitydata_addresses` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `entity_id` INT NOT NULL,
    `entity_type` ENUM('customer', 'supplier', 'business') NOT NULL,
    `type` ENUM('billing', 'shipping', 'headquarters', 'warehouse') NOT NULL,
    `name` VARCHAR(100),
    `line1` VARCHAR(255),
    `line2` VARCHAR(255),
    `city` VARCHAR(100),
    `state_province` VARCHAR(100),
    `postal_code` VARCHAR(20),
    `country` VARCHAR(2),
    `phone` VARCHAR(20),
    `is_primary` TINYINT(1) NOT NULL DEFAULT 0,
    `delivery_instructions` TEXT,
    `state` TINYINT(1) NOT NULL DEFAULT 0,
    `created` DATETIME NOT NULL,
    `created_by` INT UNSIGNED NOT NULL DEFAULT 0,
    `modified` DATETIME,
    `modified_by` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `idx_entity` (`entity_id`, `entity_type`),
    KEY `idx_state` (`state`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Relationships (Link/join table — system fields NOT required)
CREATE TABLE IF NOT EXISTS `#__entitydata_relationships` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `from_id` INT NOT NULL,
    `to_id` INT NOT NULL,
    `type` VARCHAR(50),                             -- parent_company, subsidiary, affiliated, distributor, reseller
    `status` ENUM('active', 'inactive') NOT NULL DEFAULT 'active',
    `details` TEXT,
    `created` DATETIME NOT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_from_id` (`from_id`),
    KEY `idx_to_id` (`to_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

---

## Related Documentation

- Architecture: `.claude/ARCHITECTURE.md`
- Ecosystem Overview: `..\..\ClaudeCode\docs\PROJECT-ECOSYSTEM.md`
- Integration Guide: `..\..\ClaudeCode\docs\INTERPROJECT-REFERENCES.md`
