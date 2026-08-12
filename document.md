# Self-Hosted SMS API Android App - MVP Documentation
**Version:** 0.0.7  
**Platform:** Flutter (Android)  
**Date Created:** August 2026

---

## Table of Contents
1. [Project Overview](#project-overview)
2. [Architecture Overview](#architecture-overview)
3. [Pages & UI Flows](#pages--ui-flows)
4. [API Endpoints](#api-endpoints)
5. [Database Schema](#database-schema)
6. [Features Breakdown](#features-breakdown)
7. [Required Packages](#required-packages)
8. [Task Breakdown](#task-breakdown)
9. [MVP Scope](#mvp-scope)
10. [Logging Strategy](#logging-strategy)
11. [MCP Code Structure](#mcp-code-structure)

---

## Project Overview

### Purpose
A self-hosted SMS API running natively on Android devices, allowing external applications to send SMS messages through the phone's SIM cards via HTTP API requests.

### Key Features
- HTTP server listening on configurable port (default: 3000)
- Multi-SIM support with selective activation
- Token-based API authentication
- SQLite database for request tracking and retry management
- Dashboard with logs, diagrams, and system status
- QR code sharing of API endpoint
- Automatic retry mechanism for failed SMS sends

### Target Users
- Developers who need SMS functionality for applications
- Self-hosted infrastructure enthusiasts
- Users wanting full control over SMS API without external services

---

## Architecture Overview

### High-Level Structure
```
┌─────────────────────────────────────────┐
│         Flutter UI Layer (Pages)        │
├─────────────────────────────────────────┤
│     BLoC/Provider State Management      │
├─────────────────────────────────────────┤
│     HTTP Server (shelf/dio/shelf_router)│
├─────────────────────────────────────────┤
│     Service Layer (SMS, SIM, Auth)      │
├─────────────────────────────────────────┤
│     Data Layer (SQLite + SharedPrefs)   │
├─────────────────────────────────────────┤
│     Platform Channels (Android Native)  │
└─────────────────────────────────────────┘
```

### Core Modules
1. **UI Layer** - Flutter pages and widgets
2. **Business Logic** - BLoC/Provider for state management
3. **HTTP Server** - Dart HTTP server for API
4. **Services** - SMS sending, SIM detection, authentication
5. **Data Layer** - SQLite for persistence, SharedPreferences for config
6. **Platform Integration** - Android native calls for SMS/SIM access
7. **Logging** - Centralized logging system
8. **Networking** - Retry logic, request handling

---

## Pages & UI Flows

### Page 1: Initial Setup / Configuration Page
**Trigger:** First app launch OR user clicks "Edit" from Main Setup Page

**Purpose:** Configure server connection settings

**UI Elements:**
- Header: "Configure Server"
- IP Selection Dropdown
  - Display list of available network interfaces (localhost, 0.0.0.0, 192.168.x.x, etc.)
  - Default selected: "0.0.0.0" (any network)
  - Show current IP address for each option
- Port Input Field
  - TextFormField with validation (1024-65535)
  - Default value: 3000
  - Show validation error if invalid
- Status Indicator
  - Show current API server status (running/stopped/not started)
- Action Buttons
  - "Continue" - Validate and move to Main Setup Page or next page if already configured
  - "Cancel" - Go back to previous page or Main Setup Page

**Data Flow:**
- Read saved configuration from SharedPreferences
- If exists, pre-populate fields
- On Continue: Save to SharedPreferences and SharedPreferences

**Validation Rules:**
- Port must be numeric and between 1024-65535
- IP must be valid network interface

---

### Page 2: Main Setup / Confirm Configuration Page
**Trigger:** After Initial Setup is completed OR app opens (if already configured)

**Purpose:** Display and confirm all server configuration before starting API

**UI Elements:**
- Header: "Server Configuration"
- Configuration Display (Read-Only Cards)
  - Card 1: IP Address (with icon)
    - Display selected IP
    - Display actual IP addresses if multiple interfaces
  - Card 2: Port Number (with icon)
    - Display configured port
  - Card 3: Server Status
    - Status badge (Running/Stopped/Not Started)
    - Uptime counter (if running)
  - Card 4: Access Token
    - Display token (masked with reveal button)
    - Show token generation date
- Action Buttons
  - "Edit Configuration" - Navigate to Page 1
  - "Continue to API" - Start API server and navigate to Page 3
  - "Settings" - Navigate to Settings Page
  - "View Logs" - Navigate to Logs Page

**Data Flow:**
- Load configuration from SharedPreferences
- Load access token from SharedPreferences
- If token doesn't exist: Generate and save new token
- Display all saved values
- On Continue: Start HTTP server in background service

**Token Generation:**
- Generate on first app open using UUID/crypto package
- Store in SharedPreferences with timestamp
- Never auto-regenerate if exists

---

### Page 3: API Endpoint & QR Code Page
**Trigger:** After confirming configuration

**Purpose:** Display sharable API endpoint and QR code

**UI Elements:**
- Header: "API Endpoint"
- QR Code Display
  - Large QR code (256x256 or responsive)
  - Generate from URL: `http://[ip]:[port]/api`
  - QR code should include token in query parameter or as encoded data
- API URL Display
  - Text showing full URL: `http://[ip]:[port]/api?token=[access_token]`
  - Alternative format: `http://[ip]:[port]/api` (token in header)
- Action Buttons
  - "Copy URL" - Copy to clipboard with toast notification
  - "Copy as cURL" - Copy sample cURL command with auth
  - "Share QR Code" - Share QR code image
  - "Back" - Go back to Setup page

**Data to Display:**
- Current server IP
- Current server port
- Access token (partially masked in URL display, fully visible in QR)
- Example API request format

**Additional Info:**
- Show authentication method: "Token in Header: Authorization: Bearer [token]"
- Show example request endpoint: GET /api/sms/status

---

### Page 4: SIM Cards Management Page
**Trigger:** After Setup confirmation

**Purpose:** Display available SIM cards and allow user to activate them for SMS sending

**UI Elements:**
- Header: "Active SIM Cards"
- SIM List (Scrollable)
  - For each SIM card display:
    - SIM Card Icon
    - SIM Slot Number / Name (e.g., "SIM 1", "SIM 2")
    - Carrier/Company Name
    - Phone Number
    - Signal Strength (bars indicator: 0-4 bars)
    - Status: Active/Inactive/No Service/Airplane Mode
    - Toggle Switch (Enable/Disable for SMS sending)
    - Unique SIM ID (hidden, used for API calls)
- Action Buttons
  - "Refresh SIM List" - Re-scan available SIMs
  - "Back" - Go back to previous page
  - "Settings" - Navigate to Settings Page

**Behavior:**
- Minimum 1 SIM must be active (if available)
- Multiple SIMs can be active simultaneously
- Display warning if trying to disable last active SIM
- Store active SIM selection in SharedPreferences
- Auto-refresh SIM list on page load
- Show "No SIM Cards Available" if none detected

**SIM Information to Display:**
- Slot number/name
- Phone number
- Carrier information
- Signal strength
- Current network type (2G/3G/4G/5G)
- Roaming status
- SIM state (active, ready, not ready)

---

### Page 5: Main Dashboard Page
**Trigger:** Main page after app initialization

**Purpose:** Real-time dashboard showing system status and recent activity

**UI Elements:**

#### Top Section - Server Status
- Server Status Card (Green/Red indicator)
  - Status: Running/Stopped
  - Uptime: HH:MM:SS
  - Port: [port]
  - Connected Clients: [count]
- Quick Access Buttons (Horizontal Scroll)
  - "Configure" - Go to Setup
  - "SIM Cards" - Go to SIM Management
  - "API Docs" - Show API documentation modal
  - "Settings" - Go to Settings

#### Middle Section - Statistics (Cards with Numbers)
- Total SMS Sent: [count]
- SMS Failed: [count]
- Pending SMS: [count]
- Average Response Time: [ms]
- Active SIM Cards: [count]/[total]

#### Lower Section - Recent Logs (Last 10)
- Scrollable list of recent SMS requests
- Each log item shows:
  - Timestamp
  - Recipient number (partially masked)
  - Status (Sent/Failed/Pending/Retrying)
  - SIM used
  - Color-coded status badge
- Load more logs button
- Refresh logs button

#### Bottom Section - Charts/Diagrams
- SMS Activity Chart (Line graph)
  - Last 24 hours SMS count by hour
- Success Rate Pie Chart
  - Sent vs Failed vs Pending
- Network Status Indicator
  - Signal strength for each active SIM (bar chart)

**Behavior:**
- Auto-refresh every 2-5 seconds
- Real-time status updates
- Pull-to-refresh gesture
- Background color indicates server status

---

### Page 6: Logs Page
**Trigger:** User clicks "View Logs" or "Logs" navigation item

**Purpose:** Detailed view of all SMS requests with filtering and search

**UI Elements:**
- Header: "Request Logs"
- Filter & Search Section
  - Search TextFormField (search by recipient number, message snippet)
  - Filter Dropdown (All, Sent, Failed, Pending, Retrying)
  - Date Range Picker (From - To dates)
  - Apply/Reset Filters button
- Logs List (Scrollable with pagination)
  - Each log entry displays:
    - Date & Time
    - Recipient Number (partially masked for privacy)
    - Message Preview (first 50 chars + "...")
    - Status Badge (color-coded)
    - SIM Used (slot number)
    - Number of Retries
    - Expand icon
  - On expand: Show full details
    - Full message content
    - All retry attempts with timestamps and reasons
    - Final status reason/error message
    - Request ID
- Action Buttons per Log
  - "View Details" - Expand/collapse
  - "Retry" - Manual retry (if failed)
  - "Cancel" - Cancel if pending (if applicable)
  - "Copy Details" - Copy to clipboard

**Behavior:**
- Load logs from SQLite database
- Pagination: Load 20 items at a time
- Sort by newest first
- Real-time log updates if running background service
- Clear old logs option (older than X days)

---

### Page 7: Settings Page
**Trigger:** User clicks "Settings"

**Purpose:** Configure app settings and credentials

**UI Elements:**

#### Access Token Section
- Current Token Display (masked)
- "Show Token" toggle
- "Copy Token" button
- Token Generation Date: [date]
- **Regenerate Token Section**
  - "Regenerate Token" button
  - Warning dialog before regeneration:
    - "⚠️ WARNING: Generating a new token will invalidate the current token. All servers using the old token will need to be updated. This action cannot be undone."
    - Confirmation checkbox: "I understand and want to regenerate"
    - "Cancel" / "Regenerate" buttons

#### Server Settings
- Port Configuration
  - Current Port: [port]
  - "Edit Port" button - Opens dialog to change port
  - Warning: "Changing port requires API restart"
- IP Configuration
  - Current IP: [ip]
  - "Edit IP" button - Opens dialog
  - Display all available network interfaces
- Auto-Start Option
  - Toggle: "Start API on app launch"
  - Requires permission on first enable

#### Logging Settings
- Log Level
  - Dropdown: Debug, Info, Warning, Error
- Max Log Entries
  - Number input: [default 10000]
- "Clear All Logs" button
  - Confirmation dialog before clearing
- "Export Logs" button
  - Export as JSON/CSV file
- "View App Logs" button
  - Navigate to detailed logs page

#### General Settings
- App Theme
  - Radio buttons: Light, Dark, System
- Notification Settings
  - Toggle: Show SMS delivery notifications
  - Toggle: Show error notifications
- Database
  - Database Size: [size in MB]
  - "Backup Database" button
  - "Restore from Backup" button

#### About Section
- App Version: 0.0.7
- Build Number
- Permissions Status (SMS, Phone, Network)
- "Check for Updates" button
- "View Licenses" button
- "Send Feedback" button

**Behavior:**
- Save all changes to SharedPreferences
- Validate port changes before saving
- Show loading indicator during token regeneration
- Show success/error messages for all operations

---

### Page 8: Permissions & Initial Grant Page
**Trigger:** App first launch OR if permissions not granted

**Purpose:** Request necessary permissions from user

**UI Elements:**
- Header: "Grant Permissions"
- Permission Cards (for each required permission)
  - Permission Icon
  - Permission Name
  - Permission Description
  - Status: Granted / Not Granted
  - "Grant" button
- "Grant All" button (if multiple not granted)
- Information Text
  - Explanation why each permission is needed

**Required Permissions:**
- `android.permission.SEND_SMS` - Send SMS messages
- `android.permission.READ_PHONE_STATE` - Read phone state and SIM information
- `android.permission.ACCESS_NETWORK_STATE` - Monitor network connectivity
- `android.permission.INTERNET` - For HTTP server
- `android.permission.READ_PHONE_NUMBERS` - Get phone numbers of SIM cards (Android 10+)
- `android.permission.READ_CALL_LOG` - (Optional) For advanced features
- `android.permission.RECEIVE_SMS` - (Optional) For delivery receipts

**Behavior:**
- Check permissions on app launch
- Navigate to setup after all permissions granted
- Show explanation why permission is needed
- Handle permission denial gracefully (show message about limitations)

---

## API Endpoints

### Base URL
`http://[server-ip]:[port]/api`

### Authentication
All endpoints require token in header:
```
Authorization: Bearer [access_token]
```

### Response Format
All responses return JSON:
```json
{
  "success": true/false,
  "data": {},
  "error": "error message (if failed)",
  "timestamp": "ISO-8601",
  "requestId": "unique-id"
}
```

---

### GET Endpoints

#### 1. GET /api/health
**Purpose:** Check if API is alive  
**Authentication:** Not required  
**Query Parameters:** None  
**Response:**
```json
{
  "success": true,
  "data": {
    "status": "running",
    "uptime": "02:30:45",
    "version": "0.0.7"
  }
}
```

---

#### 2. GET /api/sims/active
**Purpose:** Get list of active SIM cards  
**Authentication:** Required  
**Query Parameters:** None  
**Response:**
```json
{
  "success": true,
  "data": {
    "simCards": [
      {
        "simId": "unique-uuid",
        "slotNumber": 0,
        "name": "SIM 1",
        "phoneNumber": "+1234567890",
        "carrier": "Carrier Name",
        "signalStrength": 4,
        "networkType": "4G",
        "isActive": true,
        "isRoaming": false,
        "state": "active"
      },
      {
        "simId": "unique-uuid-2",
        "slotNumber": 1,
        "name": "SIM 2",
        "phoneNumber": "+0987654321",
        "carrier": "Another Carrier",
        "signalStrength": 2,
        "networkType": "3G",
        "isActive": true,
        "isRoaming": true,
        "state": "active"
      }
    ],
    "activeSIMCount": 2,
    "totalSIMCount": 2
  }
}
```

---

#### 3. GET /api/sms/status
**Purpose:** Get status of a specific SMS request  
**Authentication:** Required  
**Query Parameters:**
- `requestId` (required): UUID of the SMS request
- `detailed` (optional): Boolean, include retry history (default: false)

**Response:**
```json
{
  "success": true,
  "data": {
    "requestId": "request-uuid",
    "status": "sent|failed|pending|retrying",
    "simId": "sim-uuid",
    "recipient": "+1234567890",
    "messageLength": 160,
    "createdAt": "2026-08-11T10:00:00Z",
    "sentAt": "2026-08-11T10:00:05Z",
    "retryCount": 0,
    "maxRetries": 3,
    "lastError": null,
    "retryHistory": [
      {
        "attempt": 1,
        "status": "sent",
        "timestamp": "2026-08-11T10:00:05Z",
        "message": "SMS sent successfully"
      }
    ]
  }
}
```

---

#### 4. GET /api/sms/logs
**Purpose:** Get SMS request logs with filtering  
**Authentication:** Required  
**Query Parameters:**
- `limit` (optional): Max results per page (default: 20, max: 100)
- `offset` (optional): Pagination offset (default: 0)
- `status` (optional): Filter by status (sent, failed, pending, retrying)
- `simId` (optional): Filter by SIM ID
- `startDate` (optional): ISO-8601 date
- `endDate` (optional): ISO-8601 date
- `searchQuery` (optional): Search recipient number or message

**Response:**
```json
{
  "success": true,
  "data": {
    "logs": [
      {
        "requestId": "uuid",
        "status": "sent",
        "simId": "sim-uuid",
        "recipient": "+1234567890",
        "messagePreview": "Hello, this is a test...",
        "createdAt": "2026-08-11T10:00:00Z",
        "sentAt": "2026-08-11T10:00:05Z",
        "retryCount": 0,
        "maxRetries": 3
      }
    ],
    "total": 150,
    "limit": 20,
    "offset": 0
  }
}
```

---

#### 5. GET /api/server/info
**Purpose:** Get server information and status  
**Authentication:** Required  
**Query Parameters:** None  
**Response:**
```json
{
  "success": true,
  "data": {
    "serverStatus": "running",
    "listeningIP": "0.0.0.0",
    "listeningPort": 3000,
    "uptime": "02:30:45",
    "startTime": "2026-08-11T07:30:00Z",
    "version": "0.0.7",
    "androidVersion": 13,
    "deviceName": "Device Name",
    "deviceManufacturer": "Samsung",
    "activeSims": 2,
    "totalSims": 2,
    "databaseSize": "5.2MB",
    "totalRequests": 250,
    "successfulRequests": 240,
    "failedRequests": 10,
    "pendingRequests": 0,
    "averageResponseTime": "45ms",
    "connectedClients": 3,
    "systemMemoryUsage": "45%",
    "batteryLevel": 87,
    "isCharging": true,
    "networkConnected": true,
    "networkType": "WiFi"
  }
}
```

---

#### 6. GET /api/server/token
**Purpose:** Get current token info (without exposing full token)  
**Authentication:** Required  
**Query Parameters:** None  
**Response:**
```json
{
  "success": true,
  "data": {
    "generatedAt": "2026-08-11T07:30:00Z",
    "lastUsed": "2026-08-11T10:00:00Z",
    "usageCount": 47,
    "lastClientIP": "192.168.1.100"
  }
}
```

---

### POST Endpoints

#### 1. POST /api/sms/send
**Purpose:** Send SMS message  
**Authentication:** Required  
**Request Body:**
```json
{
  "simId": "sim-uuid",
  "recipient": "+1234567890",
  "message": "Hello, this is a test message",
  "maxRetries": 3,
  "retryDelayMs": 5000,
  "priority": "normal"
}
```

**Request Validation:**
- `simId`: Required, must be valid active SIM ID
- `recipient`: Required, valid phone number format
- `message`: Required, max 1600 chars (10 SMS parts)
- `maxRetries`: Optional, default 3, range 0-10
- `retryDelayMs`: Optional, default 5000, range 1000-60000
- `priority`: Optional, values: "low", "normal", "high"

**Response:**
```json
{
  "success": true,
  "data": {
    "requestId": "unique-request-uuid",
    "status": "pending|sent",
    "simId": "sim-uuid",
    "recipient": "+1234567890",
    "messageLength": 160,
    "maxRetries": 3,
    "createdAt": "2026-08-11T10:00:00Z",
    "estimatedDeliveryTime": 30,
    "message": "Request queued for sending"
  }
}
```

**Error Responses:**
- 400: Invalid parameters
- 401: Unauthorized (invalid token)
- 403: SIM not active
- 409: Rate limit exceeded
- 500: Server error

---

#### 2. POST /api/sms/cancel
**Purpose:** Cancel pending SMS request  
**Authentication:** Required  
**Request Body:**
```json
{
  "requestId": "request-uuid"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "requestId": "request-uuid",
    "previousStatus": "pending",
    "newStatus": "cancelled",
    "cancelledAt": "2026-08-11T10:00:00Z",
    "message": "SMS request cancelled successfully"
  }
}
```

**Error Responses:**
- 400: Invalid request ID
- 404: Request not found
- 409: Cannot cancel already sent SMS
- 500: Server error

---

#### 3. POST /api/token/regenerate
**Purpose:** Generate new access token  
**Authentication:** Required (old token)  
**Request Body:** (Empty)
```json
{}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "newToken": "new-token-string",
    "oldTokenInvalidatedAt": "2026-08-11T10:00:00Z",
    "message": "New token generated. Old token is now invalid.",
    "warning": "Update all clients with the new token immediately"
  }
}
```

**Note:** Requires confirmation from user in app

---

#### 4. POST /api/sims/activate
**Purpose:** Activate a SIM card for sending  
**Authentication:** Required  
**Request Body:**
```json
{
  "simId": "sim-uuid",
  "activate": true
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "simId": "sim-uuid",
    "isActive": true,
    "message": "SIM card activated"
  }
}
```

---

### PUT Endpoints

#### 1. PUT /api/config/port
**Purpose:** Update listening port  
**Authentication:** Required  
**Request Body:**
```json
{
  "port": 3001
}
```

**Validation:**
- Port must be between 1024-65535
- Port must not be in use

**Response:**
```json
{
  "success": true,
  "data": {
    "newPort": 3001,
    "message": "Port updated. Server will restart on next connection.",
    "warning": "Update API endpoint URL in clients"
  }
}
```

---

#### 2. PUT /api/config/ip
**Purpose:** Update listening IP address  
**Authentication:** Required  
**Request Body:**
```json
{
  "ip": "192.168.1.100"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "newIP": "192.168.1.100",
    "message": "IP updated. Server will use new address.",
    "warning": "Update API endpoint URL in clients"
  }
}
```

---

#### 3. PUT /api/logs/retention
**Purpose:** Update log retention policy  
**Authentication:** Required  
**Request Body:**
```json
{
  "retentionDays": 30,
  "maxEntries": 10000
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "retentionDays": 30,
    "maxEntries": 10000,
    "message": "Log retention policy updated"
  }
}
```

---

## Database Schema

### SQLite Database: `sim_gateway.db`

#### Table: `sms_requests`
```sql
CREATE TABLE sms_requests (
  id TEXT PRIMARY KEY,
  request_id TEXT UNIQUE NOT NULL,
  sim_id TEXT NOT NULL,
  recipient TEXT NOT NULL,
  message TEXT NOT NULL,
  message_length INTEGER NOT NULL,
  status TEXT NOT NULL, -- 'pending', 'sent', 'failed', 'cancelled'
  max_retries INTEGER NOT NULL DEFAULT 3,
  current_retry_count INTEGER NOT NULL DEFAULT 0,
  last_error TEXT,
  priority TEXT NOT NULL DEFAULT 'normal', -- 'low', 'normal', 'high'
  created_at DATETIME NOT NULL,
  sent_at DATETIME,
  cancelled_at DATETIME,
  last_retry_at DATETIME,
  next_retry_at DATETIME,
  expires_at DATETIME, -- When to stop retrying
  client_ip TEXT,
  metadata TEXT, -- JSON for additional data
  created_timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_status ON sms_requests(status);
CREATE INDEX idx_sim_id ON sms_requests(sim_id);
CREATE INDEX idx_created_at ON sms_requests(created_at);
CREATE INDEX idx_request_id ON sms_requests(request_id);
```

#### Table: `retry_attempts`
```sql
CREATE TABLE retry_attempts (
  id TEXT PRIMARY KEY,
  request_id TEXT NOT NULL,
  attempt_number INTEGER NOT NULL,
  status TEXT NOT NULL, -- 'success', 'failed'
  error_message TEXT,
  error_code TEXT,
  attempted_at DATETIME NOT NULL,
  response_time_ms INTEGER,
  FOREIGN KEY(request_id) REFERENCES sms_requests(request_id) ON DELETE CASCADE,
  UNIQUE(request_id, attempt_number)
);

CREATE INDEX idx_request_id_retry ON retry_attempts(request_id);
CREATE INDEX idx_attempt_number ON retry_attempts(attempt_number);
```

#### Table: `app_logs`
```sql
CREATE TABLE app_logs (
  id TEXT PRIMARY KEY,
  log_level TEXT NOT NULL, -- 'DEBUG', 'INFO', 'WARNING', 'ERROR'
  component TEXT NOT NULL, -- 'SMS', 'API', 'SIM', 'Database', 'Auth', 'Server'
  message TEXT NOT NULL,
  details TEXT, -- JSON for additional context
  timestamp DATETIME NOT NULL,
  stack_trace TEXT
);

CREATE INDEX idx_log_level ON app_logs(log_level);
CREATE INDEX idx_component ON app_logs(component);
CREATE INDEX idx_timestamp ON app_logs(timestamp);
```

#### Table: `configuration`
```sql
CREATE TABLE configuration (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  data_type TEXT NOT NULL, -- 'string', 'integer', 'boolean', 'json'
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

**Predefined Configurations:**
- `server_port` (integer, default: 3000)
- `server_ip` (string, default: "0.0.0.0")
- `access_token` (string, auto-generated)
- `token_generated_at` (string, ISO-8601)
- `auto_start_server` (boolean, default: false)
- `log_level` (string, default: "info")
- `log_retention_days` (integer, default: 30)
- `max_log_entries` (integer, default: 10000)
- `app_theme` (string, default: "system")
- `app_version` (string, default: "0.0.7")

#### Table: `sim_cards`
```sql
CREATE TABLE sim_cards (
  id TEXT PRIMARY KEY,
  sim_id TEXT UNIQUE NOT NULL,
  slot_number INTEGER NOT NULL,
  name TEXT,
  phone_number TEXT,
  carrier TEXT,
  is_active BOOLEAN DEFAULT 1,
  is_roaming BOOLEAN DEFAULT 0,
  network_type TEXT, -- '2G', '3G', '4G', '5G'
  sim_state TEXT, -- 'active', 'ready', 'not_ready'
  last_signal_strength INTEGER,
  last_updated DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_sim_id ON sim_cards(sim_id);
CREATE INDEX idx_is_active ON sim_cards(is_active);
```

#### Table: `api_access_log`
```sql
CREATE TABLE api_access_log (
  id TEXT PRIMARY KEY,
  request_id TEXT,
  client_ip TEXT NOT NULL,
  endpoint TEXT NOT NULL,
  method TEXT NOT NULL, -- GET, POST, PUT, DELETE
  status_code INTEGER NOT NULL,
  response_time_ms INTEGER,
  request_body_size INTEGER,
  response_body_size INTEGER,
  timestamp DATETIME NOT NULL,
  error_message TEXT
);

CREATE INDEX idx_client_ip ON api_access_log(client_ip);
CREATE INDEX idx_endpoint ON api_access_log(endpoint);
CREATE INDEX idx_method ON api_access_log(method);
CREATE INDEX idx_status_code ON api_access_log(status_code);
CREATE INDEX idx_timestamp_access ON api_access_log(timestamp);
```

---

## Features Breakdown

### Feature 1: Server Configuration & Setup
**Scope:** Pages 1 & 2  
**Requirements:**
- Store IP, port, and token in SharedPreferences
- Validate IP addresses against available network interfaces
- Validate port numbers (1024-65535)
- Display current configuration
- Allow editing of configuration

**Tasks:**
- [ ] Create ConfigurationProvider (state management)
- [ ] Create SetupPage widget
- [ ] Create ConfigurationPage widget
- [ ] Implement network interface detection (platform channel)
- [ ] Implement SharedPreferences storage
- [ ] Add form validation
- [ ] Add configuration save/load logic

---

### Feature 2: Access Token Generation & Management
**Scope:** Page 3 & Settings  
**Requirements:**
- Generate token on first app launch
- Display token with copy to clipboard
- Show QR code with API endpoint
- Implement token regeneration with warning
- Store token in SharedPreferences
- Never auto-regenerate existing token

**Tasks:**
- [ ] Implement token generation (UUID/crypto)
- [ ] Create QRCode widget (using qr_flutter package)
- [ ] Implement copy to clipboard functionality
- [ ] Create token management UI
- [ ] Implement regeneration logic with confirmation
- [ ] Add token expiration tracking (optional)
- [ ] Create API documentation modal

---

### Feature 3: SIM Card Detection & Management
**Scope:** Page 4  
**Requirements:**
- Detect all SIM cards in device
- Display SIM information (number, carrier, signal, network type)
- Allow activation/deactivation of SIMs
- Maintain minimum 1 active SIM
- Store active SIM selection in database
- Generate unique SIM ID for API calls
- Periodically refresh SIM status

**Tasks:**
- [ ] Implement platform channel for SIM detection (Android native)
- [ ] Create SIM model with all required fields
- [ ] Create SimProvider (state management)
- [ ] Create SimCardsPage widget
- [ ] Implement SIM refresh logic (background)
- [ ] Add signal strength display
- [ ] Add network type detection
- [ ] Implement SIM activation toggle with validation

---

### Feature 4: HTTP Server Implementation
**Scope:** Background service  
**Requirements:**
- Create HTTP server using shelf or similar
- Listen on configured IP and port
- Implement routing for all endpoints
- Handle authentication (token validation)
- Implement request logging
- Proper error handling
- Background service that survives app state changes

**Tasks:**
- [ ] Choose HTTP framework (shelf/dio/shelf_router)
- [ ] Implement server initialization
- [ ] Create request handler for each endpoint
- [ ] Implement authentication middleware
- [ ] Implement error handling middleware
- [ ] Add request/response logging
- [ ] Implement background service
- [ ] Add server lifecycle management (start/stop)
- [ ] Handle port conflicts

---

### Feature 5: SMS Sending Implementation
**Scope:** Background service  
**Requirements:**
- Send SMS via platform channel to native Android
- Handle SMS sending errors
- Implement retry mechanism (configurable)
- Track sending status in database
- Support multiple SIMs
- Handle message splitting (SMS parts)
- Respect rate limiting

**Tasks:**
- [ ] Implement platform channel for SMS sending (Android native)
- [ ] Create SMS sending service
- [ ] Implement retry logic with exponential backoff
- [ ] Create SMS status tracking
- [ ] Handle message splitting (>160 chars = multiple SMS)
- [ ] Implement delivery receipts (if available)
- [ ] Add rate limiting per SIM
- [ ] Handle permission checks

---

### Feature 6: Dashboard & Monitoring
**Scope:** Page 5  
**Requirements:**
- Display real-time server status
- Show statistics (sent, failed, pending SMS)
- Display recent logs (last 10)
- Show activity charts and diagrams
- Display signal strength for active SIMs
- Auto-refresh every 2-5 seconds
- Pull-to-refresh support

**Tasks:**
- [ ] Create Dashboard widget
- [ ] Implement real-time statistics calculation
- [ ] Create statistics provider
- [ ] Implement chart widgets (using fl_chart or similar)
- [ ] Create log display widget
- [ ] Implement auto-refresh logic (periodic timer)
- [ ] Add pull-to-refresh gesture detector
- [ ] Create signal strength visualization
- [ ] Add database query for statistics

---

### Feature 7: Detailed Logging & Analytics
**Scope:** Page 6 + logging system  
**Requirements:**
- Store all app logs in database
- Filter logs by level, component, date
- Search logs by keywords
- Display detailed retry information
- Pagination of logs
- Clear old logs automatically
- Export logs functionality
- Clean logging system (structured logging)

**Tasks:**
- [ ] Create Logger class (singleton)
- [ ] Implement structured logging (JSON format)
- [ ] Create app logs database storage
- [ ] Create LogsPage widget
- [ ] Implement filtering and search
- [ ] Add pagination
- [ ] Create log export functionality (JSON/CSV)
- [ ] Implement log retention policy
- [ ] Add background cleanup task

---

### Feature 8: Settings & Configuration
**Scope:** Page 7  
**Requirements:**
- Token regeneration with warning
- Port configuration
- IP configuration
- Log level settings
- Theme selection (light/dark)
- Database management (backup/restore)
- Notification settings
- Permissions management
- About and version info

**Tasks:**
- [ ] Create SettingsPage widget
- [ ] Implement token regeneration UI with warning
- [ ] Implement port/IP editing with validation
- [ ] Add log level configuration
- [ ] Implement theme switching
- [ ] Add database backup/restore
- [ ] Implement notification settings
- [ ] Add permissions status display
- [ ] Create about section with version info

---

### Feature 9: Retry Mechanism & Request Management
**Scope:** Background service  
**Requirements:**
- Every 5 seconds, check for pending/retrying requests
- Retry failed requests (configurable retries)
- Update request status after each attempt
- Store retry history with timestamps and errors
- Exponential backoff for retries
- Cancel pending requests
- Handle request expiration

**Tasks:**
- [ ] Create RetryManager service
- [ ] Implement retry timer (5-second interval)
- [ ] Create retry logic with exponential backoff
- [ ] Implement request status updates
- [ ] Add retry history tracking
- [ ] Implement request cancellation
- [ ] Add request expiration logic
- [ ] Handle database updates

---

### Feature 10: Logging System & MCP Code Quality
**Scope:** Entire app  
**Requirements:**
- Clean, structured logging
- Logs to database
- Logs to console (debug)
- Multiple log levels (Debug, Info, Warning, Error)
- Component-based logging (SMS, API, SIM, Database, etc.)
- Stack traces for errors
- Request IDs for tracing

**Tasks:**
- [ ] Create Logger utility class
- [ ] Implement log levels
- [ ] Implement component tagging
- [ ] Add request ID tracking
- [ ] Create log formatting (JSON format)
- [ ] Implement database storage
- [ ] Add console output for development
- [ ] Create structured error handling

---

## Required Packages

### Core Flutter & State Management
```yaml
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.0.0              # State management
  get_it: ^7.0.0                # Service locator (dependency injection)
  flutter_bloc: ^8.1.0          # BLoC pattern (alternative)
```

### Database & Storage
```yaml
  sqflite: ^2.0.0               # SQLite database
  shared_preferences: ^2.0.0    # Local preferences
  path_provider: ^2.0.0         # Path for database files
```

### HTTP & Networking
```yaml
  shelf: ^1.4.0                 # HTTP server framework
  shelf_router: ^1.1.0          # Routing for shelf
  dio: ^5.0.0                   # HTTP client (for external API calls)
  connectivity_plus: ^5.0.0     # Network connectivity detection
```

### UI & Widgets
```yaml
  qr_flutter: ^4.0.0            # QR code generation
  fl_chart: ^0.63.0             # Charts and graphs
  intl: ^0.18.0                 # Internationalization and formatting
  timeago: ^3.4.0               # Relative time display
  expandable: ^5.0.1            # Expandable list items
```

### Android Native Integration
```yaml
  android_intent_plus: ^4.0.0   # For sending intents
  permission_handler: ^11.0.0   # Permission management
```

### Utilities
```yaml
  uuid: ^3.0.0                  # UUID generation
  crypto: ^3.0.0                # Cryptographic functions (for token)
  json_serializable: ^6.0.0     # JSON serialization
  build_runner: ^2.0.0          # Build runner (dev dependency)
  freezed: ^2.0.0               # Immutable data classes
```

### Testing
```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  mocktail: ^0.3.0              # Mocking for tests
  integration_test:
    sdk: flutter
```

### Android-Specific (pubspec.yaml additions)
```yaml
flutter:
  plugin:
    platforms:
      android:
        package: com.example.sim_gateway
```

### Build Gradle Dependencies (android/app/build.gradle)
```gradle
android {
  compileSdkVersion 33  // or higher
  
  defaultConfig {
    minSdkVersion 21  // SMS and permissions support
    targetSdkVersion 33  // or higher
  }
}

dependencies {
  // Android SMS support is built-in
  // Additional AndroidX dependencies are handled by Flutter plugins
  // (permission_handler, android_intent_plus, etc.)
}
```

---

## Task Breakdown

### Phase 1: Project Setup & Architecture (Foundation)
1. [ ] Initialize Flutter project with version 0.0.7
2. [ ] Set up directory structure (lib/models, lib/services, lib/pages, lib/widgets, lib/providers, lib/utils)
3. [ ] Configure pubspec.yaml with all required packages
4. [ ] Set up Android platform channel configuration
5. [ ] Create Android manifest with required permissions
6. [ ] Set up build configuration (gradle)
7. [ ] Create core utilities (Logger, Constants, Enums)
8. [ ] Set up dependency injection (GetIt)
9. [ ] Create base models and entities
10. [ ] Set up git repository with .gitignore

**Deliverables:**
- Clean project structure
- All dependencies installed
- Permissions configured
- Logging system ready

---

### Phase 2: Database & Data Layer
1. [ ] Create SQLite database helper
2. [ ] Implement all table schemas
3. [ ] Create database schema creation logic
4. [ ] Create repository pattern for each table
5. [ ] Implement SharedPreferences wrapper
6. [ ] Create model classes for all entities
7. [ ] Add JSON serialization/deserialization
8. [ ] Implement database queries for each entity
9. [ ] Create database backup/restore logic
10. [ ] Test database operations

**Deliverables:**
- Working SQLite database
- All tables created
- Repository pattern implemented
- Data models ready

---

### Phase 3: State Management & Business Logic
1. [ ] Create configuration provider
2. [ ] Create SIM provider
3. [ ] Create SMS requests provider
4. [ ] Create server status provider
5. [ ] Create logs provider
6. [ ] Create token provider
7. [ ] Implement all providers with proper state updates
8. [ ] Set up event handling between providers
9. [ ] Test provider logic

**Deliverables:**
- All providers created
- State management working
- Proper data flow

---

### Phase 4: HTTP Server Implementation
1. [ ] Create HTTP server initialization logic
2. [ ] Implement request handler base class
3. [ ] Create authentication middleware
4. [ ] Create request logging middleware
5. [ ] Implement all GET endpoints
6. [ ] Implement all POST endpoints
7. [ ] Implement all PUT endpoints
8. [ ] Add error handling for all endpoints
9. [ ] Implement rate limiting
10. [ ] Test all endpoints with curl/Postman

**Deliverables:**
- Working HTTP server
- All endpoints functional
- Authentication working
- Proper error handling

---

### Phase 5: Platform Channels (Android Integration)
1. [ ] Create Android platform channel for SMS sending
2. [ ] Create Android platform channel for SIM detection
3. [ ] Create Android platform channel for network interfaces
4. [ ] Implement native Android code for SMS sending
5. [ ] Implement native Android code for SIM detection
6. [ ] Implement native Android code for network interfaces
7. [ ] Handle permission requests properly
8. [ ] Test on actual Android device

**Deliverables:**
- SMS sending working
- SIM detection working
- Network interface detection working
- Permissions handled

---

### Phase 6: Services Layer
1. [ ] Create SMS Service with retry logic
2. [ ] Create SIM Service for SIM management
3. [ ] Create Token Service for token generation
4. [ ] Create Configuration Service
5. [ ] Create Server Service for lifecycle management
6. [ ] Create Retry Manager service
7. [ ] Create Notification Service
8. [ ] Implement background tasks

**Deliverables:**
- All services implemented
- Services working together
- Background services running

---

### Phase 7: UI - Setup & Configuration Pages
1. [ ] Create Initial Setup page (Page 1)
2. [ ] Create Main Setup page (Page 2)
3. [ ] Implement IP selection dropdown
4. [ ] Implement port input with validation
5. [ ] Create configuration display cards
6. [ ] Add navigation between pages
7. [ ] Test user flow

**Deliverables:**
- Setup pages working
- Configuration can be saved
- Navigation working

---

### Phase 8: UI - API Endpoint & QR Code Page
1. [ ] Create API Endpoint page (Page 3)
2. [ ] Implement QR code generation
3. [ ] Add URL display
4. [ ] Implement copy to clipboard
5. [ ] Add share functionality
6. [ ] Add example request display
7. [ ] Test QR code scanning

**Deliverables:**
- QR code page working
- Copy to clipboard working
- Share functionality working

---

### Phase 9: UI - SIM Cards Management Page
1. [ ] Create SIM Cards page (Page 4)
2. [ ] Implement SIM list display
3. [ ] Add SIM information cards
4. [ ] Implement activation toggles
5. [ ] Add signal strength display
6. [ ] Add refresh functionality
7. [ ] Test SIM detection

**Deliverables:**
- SIM page working
- SIM detection working
- Activation toggles working

---

### Phase 10: UI - Dashboard Page
1. [ ] Create Dashboard page (Page 5)
2. [ ] Add server status card
3. [ ] Add statistics cards
4. [ ] Implement recent logs display
5. [ ] Add charts and diagrams
6. [ ] Implement auto-refresh
7. [ ] Add pull-to-refresh gesture
8. [ ] Style dashboard

**Deliverables:**
- Dashboard page working
- Real-time updates
- Charts displaying

---

### Phase 11: UI - Logs Page
1. [ ] Create Logs page (Page 6)
2. [ ] Implement filtering UI
3. [ ] Implement search functionality
4. [ ] Add pagination
5. [ ] Create log detail view
6. [ ] Add export functionality
7. [ ] Test filtering and search

**Deliverables:**
- Logs page working
- Filtering working
- Search working
- Export working

---

### Phase 12: UI - Settings Page
1. [ ] Create Settings page (Page 7)
2. [ ] Add token section with show/copy
3. [ ] Add token regeneration with warning
4. [ ] Add port/IP configuration
5. [ ] Add logging settings
6. [ ] Add theme selection
7. [ ] Add database management
8. [ ] Add about section

**Deliverables:**
- Settings page working
- All settings functional
- Warnings showing properly

---

### Phase 13: UI - Permissions Page
1. [ ] Create Permissions page (Page 8)
2. [ ] Implement permission checking
3. [ ] Add permission request buttons
4. [ ] Show permission status
5. [ ] Handle permission denial
6. [ ] Add explanations for each permission

**Deliverables:**
- Permissions page working
- All permissions can be requested
- Proper handling of denials

---

### Phase 14: App Navigation & Flow
1. [ ] Create main navigation structure
2. [ ] Implement page transitions
3. [ ] Add bottom navigation (if needed)
4. [ ] Implement deep linking
5. [ ] Add back button handling
6. [ ] Test complete user flow

**Deliverables:**
- Navigation working
- All pages accessible
- User flow smooth

---

### Phase 15: Logging System & MCP Code
1. [ ] Create Logger utility class
2. [ ] Implement structured logging
3. [ ] Add log levels
4. [ ] Add component tagging
5. [ ] Implement request ID tracking
6. [ ] Create MCP-style code structure
7. [ ] Add proper error handling throughout
8. [ ] Review code quality

**Deliverables:**
- Clean logging system
- MCP code structure
- Proper error handling

---

### Phase 16: Testing
1. [ ] Create unit tests for services
2. [ ] Create widget tests for UI
3. [ ] Create integration tests
4. [ ] Test API endpoints
5. [ ] Test database operations
6. [ ] Test SMS sending
7. [ ] Test retry logic
8. [ ] Test on multiple Android versions

**Deliverables:**
- Test coverage
- All critical flows tested
- Ready for production

---

### Phase 17: Documentation & Deployment
1. [ ] Create README with setup instructions
2. [ ] Create API documentation
3. [ ] Create user guide
4. [ ] Add inline code documentation
5. [ ] Create troubleshooting guide
6. [ ] Build APK for distribution
7. [ ] Test on multiple devices
8. [ ] Version 0.0.7 released

**Deliverables:**
- Complete documentation
- APK built
- App ready for users

### Building the Release APK

Build the release APK with:

```bash
flutter build apk --release
```

The output file is placed at:

```
build/app/outputs/apk/release/sim_gate-<VERSION>-release.apk
```

where `<VERSION>` is the app version from `pubspec.yaml` (e.g. `sim_gate-0.0.7-release.apk`).
The APK filename is derived automatically from the pubspec version by the Gradle
build config, so it always matches the current app version.

---

## MVP Scope

### In MVP:
- Single user interface (no multi-user)
- Basic HTTP server on single port
- SMS sending via available SIM cards
- Basic retry logic (fixed intervals)
- SQLite database storage
- QR code sharing of API endpoint
- Basic dashboard
- Token-based authentication
- SIM card detection and activation
- Configuration management
- Basic logging

### Out of MVP (Future Versions):
- Web dashboard
- Multiple server instances
- Advanced analytics
- SMS scheduling
- SMS templates
- Advanced retry strategies with machine learning
- Delivery receipts handling
- Multi-language support
- Custom themes
- Rest API client library (SDK)
- Docker containerization
- Cloud backup
- Webhook notifications
- SMS message history export
- Payment/Subscription features

---

## Logging Strategy

### Logging Levels
1. **DEBUG** - Detailed diagnostic information (development only)
2. **INFO** - General informational messages
3. **WARNING** - Warning messages for potentially problematic situations
4. **ERROR** - Error messages for serious problems

### Log Components
- `SMS` - SMS sending related logs
- `API` - HTTP API server related logs
- `SIM` - SIM card detection and management
- `SERVER` - Server startup, shutdown, configuration
- `AUTH` - Authentication and token related
- `DATABASE` - Database operations
- `UI` - UI events and navigation
- `RETRY` - Retry mechanism logs
- `CONFIG` - Configuration changes

### Log Storage
- **Console** - Real-time development logs
- **Database** - Persistent logs stored in SQLite
- **File** (Optional) - Local file storage for debugging

### Example Log Entry
```json
{
  "timestamp": "2026-08-11T10:00:00Z",
  "level": "INFO",
  "component": "SMS",
  "message": "SMS sent successfully",
  "details": {
    "requestId": "uuid",
    "simId": "sim-uuid",
    "recipient": "+1234567890",
    "messageLength": 160,
    "responseTimeMs": 45
  },
  "requestId": "request-uuid"
}
```

---

## MCP Code Structure

### Directory Structure
```
lib/
├── main.dart
├── constants/
│   ├── app_constants.dart
│   ├── api_endpoints.dart
│   └── colors.dart
├── models/
│   ├── sms_request.dart
│   ├── sim_card.dart
│   ├── configuration.dart
│   ├── app_log.dart
│   ├── retry_attempt.dart
│   └── server_info.dart
├── services/
│   ├── logger_service.dart
│   ├── sms_service.dart
│   ├── sim_service.dart
│   ├── token_service.dart
│   ├── config_service.dart
│   ├── server_service.dart
│   ├── retry_manager.dart
│   └── database_service.dart
├── repositories/
│   ├── sms_repository.dart
│   ├── sim_repository.dart
│   ├── config_repository.dart
│   ├── logs_repository.dart
│   └── retry_repository.dart
├── providers/
│   ├── config_provider.dart
│   ├── sim_provider.dart
│   ├── sms_provider.dart
│   ├── server_provider.dart
│   ├── logs_provider.dart
│   └── token_provider.dart
├── pages/
│   ├── setup_page.dart
│   ├── config_page.dart
│   ├── api_endpoint_page.dart
│   ├── sim_cards_page.dart
│   ├── dashboard_page.dart
│   ├── logs_page.dart
│   ├── settings_page.dart
│   └── permissions_page.dart
├── widgets/
│   ├── common/
│   │   ├── app_bar.dart
│   │   ├── bottom_navigation.dart
│   │   └── loading_indicator.dart
│   ├── config/
│   │   ├── ip_selector.dart
│   │   └── port_input.dart
│   ├── dashboard/
│   │   ├── stats_card.dart
│   │   ├── recent_logs.dart
│   │   └── charts.dart
│   └── sim/
│       ├── sim_card_item.dart
│       └── signal_indicator.dart
├── utils/
│   ├── logger.dart
│   ├── extensions.dart
│   ├── validators.dart
│   └── helpers.dart
├── server/
│   ├── http_server.dart
│   ├── middleware/
│   │   ├── auth_middleware.dart
│   │   └── logging_middleware.dart
│   └── handlers/
│       ├── sms_handler.dart
│       ├── sim_handler.dart
│       ├── server_handler.dart
│       ├── token_handler.dart
│       └── logs_handler.dart
├── database/
│   ├── database_helper.dart
│   ├── schema.dart
│   └── queries/
│       ├── sms_queries.dart
│       ├── sim_queries.dart
│       └── log_queries.dart
└── config/
    ├── service_locator.dart
    ├── theme.dart
    └── routes.dart
```

### Code Style Guidelines
- Use null safety throughout
- Follow Dart naming conventions (camelCase for variables/functions, PascalCase for classes)
- Use async/await instead of Future.then()
- Use const constructors where possible
- Document public APIs with dartdoc comments
- Keep functions small and focused
- Use proper error handling with try-catch
- Create custom exceptions for different error scenarios
- Use enums for status values
- Implement proper logging in all services

### Example Service Structure
```dart
// Abstract base service
abstract class BaseService {
  void log(String message, {String level = 'INFO'});
}

// Concrete service
class SmsService extends BaseService {
  final LoggerService logger;
  
  SmsService({required this.logger});
  
  /// Send SMS via specified SIM card
  /// Returns [SmsRequest] with generated ID
  Future<SmsRequest> sendSms({
    required String simId,
    required String recipient,
    required String message,
    int maxRetries = 3,
  }) async {
    try {
      log('Sending SMS to $recipient via SIM $simId');
      // Implementation
    } catch (e, stackTrace) {
      log('Error sending SMS: $e', level: 'ERROR');
      logger.logError('SMS_SEND_ERROR', e, stackTrace);
      rethrow;
    }
  }
  
  @override
  void log(String message, {String level = 'INFO'}) {
    logger.log(level, 'SMS', message);
  }
}
```

---

## Summary

This MVP document provides a comprehensive guide for implementing a self-hosted SMS API Android app using Flutter. It covers:

- **8 main pages** with specific UI/UX requirements
- **10+ core features** with detailed requirements
- **Multiple API endpoints** (GET, POST, PUT) with authentication
- **SQLite database** with optimized schema
- **Background services** for SMS sending and retry management
- **Clean logging system** with structured logs
- **MCP code structure** for maintainability
- **17 development phases** for organized implementation
- **Clear MVP scope** with future enhancements outlined

The app will provide a complete solution for self-hosted SMS API management with professional UI, robust backend, and comprehensive monitoring capabilities.
