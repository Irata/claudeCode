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
    public string $type;  // 'individual' or 'business'
    public string $name;
    public string $email;
    public string $phone;
    public string $mobilePhone;
    public string $taxId;  // VAT/Tax ID if business
    public string $registrationNumber;  // For businesses
    public string $country;
    public string $currency;  // Preferred currency
    public string $language;  // Preferred language
    public array $classifications;  // VIP, wholesale, retail, preferred
    public string $status;  // 'active', 'inactive', 'suspended'
    public float $creditLimit;
    public \DateTime $createdDate;
    public \DateTime $modifiedDate;
    public int $createdBy;
    public int $modifiedBy;

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
    public string $name;
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
    public string $status;  // 'active', 'inactive', 'preferred', 'suspended'
    public float $rating;  // Quality rating
    public array $categories;  // Supplier categories
    public \DateTime $createdDate;
    public \DateTime $modifiedDate;

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
    public string $name;
    public string $legalName;
    public string $registrationNumber;
    public string $taxId;
    public string $taxStatus;  // 'registered', 'pending', 'exempt'
    public string $businessType;  // 'corporation', 'partnership', 'sole_trader', 'non_profit'
    public string $industryCode;
    public int $employeeCount;
    public string $country;
    public string $founded;  // Year
    public \DateTime $createdDate;
    public \DateTime $modifiedDate;

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
    public string $status;  // 'active', 'inactive'
    public \DateTime $createdDate;
    public \DateTime $modifiedDate;
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
    public string $state;
    public string $postalCode;
    public string $country;
    public string $phone;
    public bool $isPrimary;
    public string $deliveryInstructions;
    public \DateTime $createdDate;
    public \DateTime $modifiedDate;
}
```

### Relationship Entity
```php
namespace Emporium\EntityData\Entity;

class Relationship {
    public int $id;
    public int $fromId;  // Entity ID
    public int $toId;    // Related entity ID
    public string $type;  // 'parent_company', 'subsidiary', 'affiliated', 'distributor', 'reseller'
    public string $status;  // 'active', 'inactive'
    public string $details;  // Additional context
    public \DateTime $createdDate;
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
-- Customers
CREATE TABLE `#__entitydata_customers` (
    id INT PRIMARY KEY AUTO_INCREMENT,
    type ENUM('individual', 'business'),
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE,
    phone VARCHAR(20),
    mobile_phone VARCHAR(20),
    tax_id VARCHAR(50),
    registration_number VARCHAR(50),
    country VARCHAR(2),
    currency VARCHAR(3),
    language VARCHAR(5),
    status ENUM('active', 'inactive', 'suspended') DEFAULT 'active',
    credit_limit DECIMAL(12,2),
    created_date DATETIME,
    modified_date DATETIME,
    created_by INT,
    modified_by INT
);

-- Suppliers
CREATE TABLE `#__entitydata_suppliers` (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(255) NOT NULL,
    code VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255),
    phone VARCHAR(20),
    website VARCHAR(255),
    country VARCHAR(2),
    tax_id VARCHAR(50),
    lead_time INT,  -- Days
    minimum_order_qty INT,
    minimum_order_value DECIMAL(12,2),
    payment_terms VARCHAR(50),
    status ENUM('active', 'inactive', 'preferred', 'suspended') DEFAULT 'active',
    rating DECIMAL(3,2),
    created_date DATETIME,
    modified_date DATETIME
);

-- Addresses
CREATE TABLE `#__entitydata_addresses` (
    id INT PRIMARY KEY AUTO_INCREMENT,
    entity_id INT NOT NULL,
    entity_type ENUM('customer', 'supplier', 'business'),
    type ENUM('billing', 'shipping', 'headquarters', 'warehouse'),
    name VARCHAR(100),
    line1 VARCHAR(255),
    line2 VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(100),
    postal_code VARCHAR(20),
    country VARCHAR(2),
    phone VARCHAR(20),
    is_primary TINYINT(1) DEFAULT 0,
    delivery_instructions TEXT
);

-- Relationships
CREATE TABLE `#__entitydata_relationships` (
    id INT PRIMARY KEY AUTO_INCREMENT,
    from_id INT NOT NULL,
    to_id INT NOT NULL,
    type VARCHAR(50),  -- parent_company, subsidiary, affiliated, distributor, reseller
    status ENUM('active', 'inactive') DEFAULT 'active',
    details TEXT,
    created_date DATETIME
);
```

---

## Related Documentation

- Architecture: `.claude/ARCHITECTURE.md`
- Ecosystem Overview: `..\..\ClaudeCode\docs\PROJECT-ECOSYSTEM.md`
- Integration Guide: `..\..\ClaudeCode\docs\INTERPROJECT-REFERENCES.md`
