# Database Connection MCP Server

A Model Context Protocol (MCP) server for securely managing project-specific database connections.

## Features

- 🔐 **Secure Storage**: Passwords are encrypted using AES-256-GCM
- 📁 **Project-Based**: Organize connections by project name
- 🔄 **Multiple Connections**: Support multiple connections per project (main, readonly, backup)
- 🗄️ **Multi-Database**: Support for MySQL, PostgreSQL, SQLite, MongoDB
- 🔍 **Connection Testing**: Basic connection validation
- 📋 **Easy Management**: List, save, retrieve, and delete connections

## Installation

1. Navigate to the server directory:
```bash
cd E:\PROJECTS\database-connection-mcp
```

2. Install dependencies:
```bash
npm install
```

## Configuration

Add to your `.mcp.json` file:

```json
{
  "mcpServers": {
    "database-connections": {
      "command": "node",
      "args": ["E:\\PROJECTS\\database-connection-mcp\\index.js"],
      "env": {
        "DB_ENCRYPTION_KEY": "your-32-byte-hex-encryption-key-here"
      }
    }
  }
}
```

**Security Note**: Set a custom encryption key via the `DB_ENCRYPTION_KEY` environment variable. If not set, a random key will be generated each time.

## Available Tools

### `save_db`
Save a new database connection for a project.

**Parameters:**
- `project_name` (required): Name of the project (e.g., "SHOP", "PROJECT_ABC")
- `connection_name` (optional): Name for this connection (default: "main")
- `host` (required): Database host address
- `port` (required): Database port number
- `database_name` (required): Name of the database
- `username` (required): Database username
- `password` (required): Database password (will be encrypted)
- `connection_type` (required): Type of database ("mysql", "postgresql", "sqlite", "mongodb")
- `ssl_enabled` (optional): Whether SSL is enabled (default: true)
- `is_readonly` (optional): Whether this is a read-only connection (default: true)
- `additional_params` (optional): Additional connection parameters

### `get_db`
Retrieve a database connection for a project.

**Parameters:**
- `project_name` (required): Name of the project
- `connection_name` (optional): Name of the connection (default: "main")
- `include_password` (optional): Whether to include decrypted password (default: false)

### `list_db`
List all database connections, optionally filtered by project.

**Parameters:**
- `project_name` (optional): Project name to filter by

### `delete_db`
Delete a database connection.

**Parameters:**
- `project_name` (required): Name of the project
- `connection_name` (optional): Name of the connection (default: "main")

### `test_db`
Test if a database connection configuration is valid.

**Parameters:**
- `project_name` (required): Name of the project
- `connection_name` (optional): Name of the connection (default: "main")

## Usage Examples

### Save a MySQL connection for your SHOP project:
```json
{
  "project_name": "SHOP",
  "connection_name": "main",
  "host": "localhost",
  "port": 3306,
  "database_name": "j2commerce_shop",
  "username": "shop_user",
  "password": "your_secure_password",
  "connection_type": "mysql",
  "ssl_enabled": true,
  "is_readonly": false
}
```

### Save a read-only connection:
```json
{
  "project_name": "SHOP",
  "connection_name": "readonly",
  "host": "localhost",
  "port": 3306,
  "database_name": "j2commerce_shop",
  "username": "shop_readonly",
  "password": "readonly_password",
  "connection_type": "mysql",
  "is_readonly": true
}
```

### Retrieve a connection:
```json
{
  "project_name": "SHOP",
  "connection_name": "main",
  "include_password": true
}
```

## File Storage

Connections are stored in `connections.json` in the server directory. The file structure:

```json
{
  "PROJECT_NAME": {
    "connection_name": {
      "host": "localhost",
      "port": 3306,
      "database_name": "database_name",
      "username": "username",
      "password_encrypted": {
        "encrypted": "...",
        "iv": "...",
        "authTag": "..."
      },
      "connection_type": "mysql",
      "ssl_enabled": true,
      "is_readonly": true,
      "additional_params": {},
      "created_at": "2025-01-30T...",
      "updated_at": "2025-01-30T..."
    }
  }
}
```

## Security

- Passwords are encrypted using AES-256-GCM encryption
- Each encrypted password has a unique IV and authentication tag
- Set a custom encryption key via environment variable for production use
- Consider using secure storage solutions for the encryption key
- The connections.json file should be kept secure and backed up

## Development

Run in development mode with file watching:
```bash
npm run dev
```

## Testing

Basic testing:
```bash
npm test
```

## License

MIT