#!/usr/bin/env node

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { CallToolRequestSchema, ListToolsRequestSchema } from '@modelcontextprotocol/sdk/types.js';
import fs from 'fs/promises';
import path from 'path';
import crypto from 'crypto';
import mysql from 'mysql2/promise';

class DatabaseConnectionMCP {
  constructor() {
    this.server = new Server(
      {
        name: 'database-connection-mcp',
        version: '1.0.0',
      },
      {
        capabilities: {
          tools: {},
        },
      }
    );

    this.connectionFile = path.join(process.cwd(), 'connections.json');
    this.encryptionKey = process.env.DB_ENCRYPTION_KEY || this.generateEncryptionKey();
    
    this.setupToolHandlers();
    
    // Error handling
    this.server.onerror = (error) => console.error('[MCP Error]', error);
    process.on('SIGINT', async () => {
      await this.server.close();
      process.exit(0);
    });
  }

  generateEncryptionKey() {
    // Generate a default key - in production, use environment variable
    return crypto.randomBytes(32).toString('hex');
  }

  encrypt(text) {
    const algorithm = 'aes-256-cbc';
    const key = Buffer.from(this.encryptionKey.slice(0, 64), 'hex'); // Use first 32 bytes for AES-256
    const iv = crypto.randomBytes(16);
    
    const cipher = crypto.createCipheriv(algorithm, key.slice(0, 32), iv);
    
    let encrypted = cipher.update(text, 'utf8', 'hex');
    encrypted += cipher.final('hex');
    
    return {
      encrypted,
      iv: iv.toString('hex')
    };
  }

  decrypt(encryptedData) {
    const algorithm = 'aes-256-cbc';
    const key = Buffer.from(this.encryptionKey.slice(0, 64), 'hex'); // Use first 32 bytes for AES-256
    const iv = Buffer.from(encryptedData.iv, 'hex');
    
    const decipher = crypto.createDecipheriv(algorithm, key.slice(0, 32), iv);
    
    let decrypted = decipher.update(encryptedData.encrypted, 'hex', 'utf8');
    decrypted += decipher.final('utf8');
    
    return decrypted;
  }

  async loadConnections() {
    try {
      const data = await fs.readFile(this.connectionFile, 'utf8');
      return JSON.parse(data);
    } catch (error) {
      if (error.code === 'ENOENT') {
        return {};
      }
      throw error;
    }
  }

  async saveConnections(connections) {
    await fs.writeFile(this.connectionFile, JSON.stringify(connections, null, 2));
  }

  setupToolHandlers() {
    this.server.setRequestHandler(ListToolsRequestSchema, async () => ({
      tools: [
        {
          name: 'save_db',
          description: 'Save a new database connection for a project',
          inputSchema: {
            type: 'object',
            properties: {
              project_name: {
                type: 'string',
                description: 'Name of the project (e.g., SHOP, PROJECT_ABC)'
              },
              connection_name: {
                type: 'string',
                description: 'Name for this connection (e.g., main, readonly, backup)',
                default: 'main'
              },
              host: {
                type: 'string',
                description: 'Database host address'
              },
              port: {
                type: 'integer',
                description: 'Database port number'
              },
              database_name: {
                type: 'string',
                description: 'Name of the database'
              },
              username: {
                type: 'string',
                description: 'Database username'
              },
              password: {
                type: 'string',
                description: 'Database password (will be encrypted)'
              },
              connection_type: {
                type: 'string',
                enum: ['mysql', 'postgresql', 'sqlite', 'mongodb'],
                description: 'Type of database'
              },
              ssl_enabled: {
                type: 'boolean',
                description: 'Whether SSL is enabled',
                default: true
              },
              is_readonly: {
                type: 'boolean',
                description: 'Whether this is a read-only connection',
                default: true
              },
              additional_params: {
                type: 'object',
                description: 'Additional connection parameters'
              }
            },
            required: ['project_name', 'host', 'port', 'database_name', 'username', 'password', 'connection_type']
          }
        },
        {
          name: 'get_db',
          description: 'Retrieve a database connection for a project',
          inputSchema: {
            type: 'object',
            properties: {
              project_name: {
                type: 'string',
                description: 'Name of the project'
              },
              connection_name: {
                type: 'string',
                description: 'Name of the connection',
                default: 'main'
              },
              include_password: {
                type: 'boolean',
                description: 'Whether to include decrypted password in response',
                default: false
              }
            },
            required: ['project_name']
          }
        },
        {
          name: 'list_db',
          description: 'List all database connections, optionally filtered by project',
          inputSchema: {
            type: 'object',
            properties: {
              project_name: {
                type: 'string',
                description: 'Optional project name to filter by'
              }
            }
          }
        },
        {
          name: 'delete_db',
          description: 'Delete a database connection',
          inputSchema: {
            type: 'object',
            properties: {
              project_name: {
                type: 'string',
                description: 'Name of the project'
              },
              connection_name: {
                type: 'string',
                description: 'Name of the connection',
                default: 'main'
              }
            },
            required: ['project_name']
          }
        },
        {
          name: 'test_db',
          description: 'Test if a database connection is working',
          inputSchema: {
            type: 'object',
            properties: {
              project_name: {
                type: 'string',
                description: 'Name of the project'
              },
              connection_name: {
                type: 'string',
                description: 'Name of the connection',
                default: 'main'
              }
            },
            required: ['project_name']
          }
        },
        {
          name: 'create_markdown',
          description: 'Generate comprehensive markdown documentation of database schema',
          inputSchema: {
            type: 'object',
            properties: {
              project_name: {
                type: 'string',
                description: 'Name of the project to generate schema documentation for'
              },
              connection_name: {
                type: 'string',
                description: 'Name of the connection to use',
                default: 'main'
              }
            },
            required: ['project_name']
          }
        }
      ]
    }));

    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const { name, arguments: args } = request.params;

      try {
        switch (name) {
          case 'save_db':
            return await this.saveDatabaseConnection(args);
          
          case 'get_db':
            return await this.getDatabaseConnection(args);
          
          case 'list_db':
            return await this.listDatabaseConnections(args);
          
          case 'delete_db':
            return await this.deleteDatabaseConnection(args);
          
          case 'test_db':
            return await this.testDatabaseConnection(args);
          
          default:
            throw new Error(`Unknown tool: ${name}`);
        }
      } catch (error) {
        return {
          content: [
            {
              type: 'text',
              text: `Error: ${error.message}`
            }
          ]
        };
      }
    });
  }

  async saveDatabaseConnection(args) {
    const {
      project_name,
      connection_name = 'main',
      host,
      port,
      database_name,
      username,
      password,
      connection_type,
      ssl_enabled = true,
      is_readonly = true,
      additional_params = {}
    } = args;

    const connections = await this.loadConnections();
    
    // Initialize project if it doesn't exist
    if (!connections[project_name]) {
      connections[project_name] = {};
    }

    // Encrypt the password
    const encryptedPassword = this.encrypt(password);

    // Save connection
    connections[project_name][connection_name] = {
      host,
      port,
      database_name,
      username,
      password_encrypted: encryptedPassword,
      connection_type,
      ssl_enabled,
      is_readonly,
      additional_params,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    };

    await this.saveConnections(connections);

    return {
      content: [
        {
          type: 'text',
          text: `✅ Database connection saved successfully!\n\nProject: ${project_name}\nConnection: ${connection_name}\nHost: ${host}:${port}\nDatabase: ${database_name}\nType: ${connection_type}\nRead-only: ${is_readonly}`
        }
      ]
    };
  }

  async getDatabaseConnection(args) {
    const { project_name, connection_name = 'main', include_password = false } = args;

    const connections = await this.loadConnections();

    if (!connections[project_name]) {
      throw new Error(`Project '${project_name}' not found`);
    }

    if (!connections[project_name][connection_name]) {
      throw new Error(`Connection '${connection_name}' not found for project '${project_name}'`);
    }

    const connection = { ...connections[project_name][connection_name] };

    // Decrypt password if requested
    if (include_password) {
      try {
        connection.password = this.decrypt(connection.password_encrypted);
      } catch (error) {
        connection.password = '[DECRYPTION_ERROR]';
      }
    }

    // Remove encrypted password from response
    delete connection.password_encrypted;

    return {
      content: [
        {
          type: 'text',
          text: `📋 Database Connection Details:\n\n${JSON.stringify({
            project_name,
            connection_name,
            ...connection
          }, null, 2)}`
        }
      ]
    };
  }

  async listDatabaseConnections(args) {
    const { project_name } = args;
    const connections = await this.loadConnections();

    let result = [];

    if (project_name) {
      // List connections for specific project
      if (connections[project_name]) {
        Object.keys(connections[project_name]).forEach(conn_name => {
          const conn = connections[project_name][conn_name];
          result.push({
            project_name,
            connection_name: conn_name,
            host: conn.host,
            port: conn.port,
            database_name: conn.database_name,
            connection_type: conn.connection_type,
            is_readonly: conn.is_readonly,
            created_at: conn.created_at
          });
        });
      }
    } else {
      // List all connections
      Object.keys(connections).forEach(proj_name => {
        Object.keys(connections[proj_name]).forEach(conn_name => {
          const conn = connections[proj_name][conn_name];
          result.push({
            project_name: proj_name,
            connection_name: conn_name,
            host: conn.host,
            port: conn.port,
            database_name: conn.database_name,
            connection_type: conn.connection_type,
            is_readonly: conn.is_readonly,
            created_at: conn.created_at
          });
        });
      });
    }

    return {
      content: [
        {
          type: 'text',
          text: `📊 Database Connections:\n\n${JSON.stringify(result, null, 2)}`
        }
      ]
    };
  }

  async deleteDatabaseConnection(args) {
    const { project_name, connection_name = 'main' } = args;

    const connections = await this.loadConnections();

    if (!connections[project_name]) {
      throw new Error(`Project '${project_name}' not found`);
    }

    if (!connections[project_name][connection_name]) {
      throw new Error(`Connection '${connection_name}' not found for project '${project_name}'`);
    }

    delete connections[project_name][connection_name];

    // Remove project if no connections left
    if (Object.keys(connections[project_name]).length === 0) {
      delete connections[project_name];
    }

    await this.saveConnections(connections);

    return {
      content: [
        {
          type: 'text',
          text: `🗑️ Connection '${connection_name}' deleted from project '${project_name}'`
        }
      ]
    };
  }

  async testDatabaseConnection(args) {
    const { project_name, connection_name = 'main' } = args;

    // For now, just verify the connection exists
    // In a full implementation, you would actually test the database connection
    const connections = await this.loadConnections();

    if (!connections[project_name]) {
      throw new Error(`Project '${project_name}' not found`);
    }

    if (!connections[project_name][connection_name]) {
      throw new Error(`Connection '${connection_name}' not found for project '${project_name}'`);
    }

    const connection = connections[project_name][connection_name];

    return {
      content: [
        {
          type: 'text',
          text: `🔍 Connection Test Results:\n\nProject: ${project_name}\nConnection: ${connection_name}\nHost: ${connection.host}:${connection.port}\nDatabase: ${connection.database_name}\nType: ${connection.connection_type}\n\n⚠️ Note: This is a basic validation. Full database connectivity testing requires additional database drivers.`
        }
      ]
    };
  }

  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error('Database Connection MCP server running on stdio');
  }
}

const server = new DatabaseConnectionMCP();
server.run().catch(console.error);