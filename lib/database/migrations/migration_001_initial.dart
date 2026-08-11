import 'package:sqflite/sqflite.dart';

/// Initial schema: creates every table defined in the project document.
///
/// Tables:
///   - sms_requests
///   - retry_attempts
///   - app_logs
///   - configuration
///   - sim_cards
///   - api_access_log
Future<void> migration001Initial(Database db) async {
  final batch = db.batch();

  // --- sms_requests --------------------------------------------------------
  batch.execute('''
    CREATE TABLE sms_requests (
      id TEXT PRIMARY KEY,
      request_id TEXT UNIQUE NOT NULL,
      sim_id TEXT NOT NULL,
      recipient TEXT NOT NULL,
      message TEXT NOT NULL,
      message_length INTEGER NOT NULL,
      status TEXT NOT NULL,
      max_retries INTEGER NOT NULL DEFAULT 3,
      current_retry_count INTEGER NOT NULL DEFAULT 0,
      last_error TEXT,
      priority TEXT NOT NULL DEFAULT 'normal',
      created_at DATETIME NOT NULL,
      sent_at DATETIME,
      cancelled_at DATETIME,
      last_retry_at DATETIME,
      next_retry_at DATETIME,
      expires_at DATETIME,
      client_ip TEXT,
      metadata TEXT
    )
  ''');
  batch.execute('CREATE INDEX idx_status ON sms_requests(status)');
  batch.execute('CREATE INDEX idx_sim_id ON sms_requests(sim_id)');
  batch.execute('CREATE INDEX idx_created_at ON sms_requests(created_at)');
  batch.execute('CREATE INDEX idx_request_id ON sms_requests(request_id)');

  // --- retry_attempts ------------------------------------------------------
  batch.execute('''
    CREATE TABLE retry_attempts (
      id TEXT PRIMARY KEY,
      request_id TEXT NOT NULL,
      attempt_number INTEGER NOT NULL,
      status TEXT NOT NULL,
      error_message TEXT,
      error_code TEXT,
      attempted_at DATETIME NOT NULL,
      response_time_ms INTEGER,
      FOREIGN KEY(request_id) REFERENCES sms_requests(request_id) ON DELETE CASCADE
    )
  ''');
  batch.execute(
    'CREATE INDEX idx_request_id_retry ON retry_attempts(request_id)',
  );
  batch.execute(
    'CREATE INDEX idx_attempt_number ON retry_attempts(attempt_number)',
  );

  // --- app_logs ------------------------------------------------------------
  batch.execute('''
    CREATE TABLE app_logs (
      id TEXT PRIMARY KEY,
      log_level TEXT NOT NULL,
      component TEXT NOT NULL,
      message TEXT NOT NULL,
      details TEXT,
      timestamp DATETIME NOT NULL,
      stack_trace TEXT
    )
  ''');
  batch.execute('CREATE INDEX idx_log_level ON app_logs(log_level)');
  batch.execute('CREATE INDEX idx_component ON app_logs(component)');
  batch.execute('CREATE INDEX idx_timestamp ON app_logs(timestamp)');

  // --- configuration -------------------------------------------------------
  batch.execute('''
    CREATE TABLE configuration (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL,
      data_type TEXT NOT NULL,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )
  ''');

  // --- sim_cards -----------------------------------------------------------
  batch.execute('''
    CREATE TABLE sim_cards (
      id TEXT PRIMARY KEY,
      sim_id TEXT UNIQUE NOT NULL,
      slot_number INTEGER NOT NULL,
      name TEXT,
      phone_number TEXT,
      carrier TEXT,
      is_active INTEGER DEFAULT 1,
      is_roaming INTEGER DEFAULT 0,
      network_type TEXT,
      sim_state TEXT,
      last_signal_strength INTEGER,
      last_updated DATETIME
    )
  ''');
  batch.execute('CREATE INDEX idx_sim_cards_sim_id ON sim_cards(sim_id)');
  batch.execute('CREATE INDEX idx_is_active ON sim_cards(is_active)');

  // --- api_access_log ------------------------------------------------------
  batch.execute('''
    CREATE TABLE api_access_log (
      id TEXT PRIMARY KEY,
      request_id TEXT,
      client_ip TEXT NOT NULL,
      endpoint TEXT NOT NULL,
      method TEXT NOT NULL,
      status_code INTEGER NOT NULL,
      response_time_ms INTEGER,
      request_body_size INTEGER,
      response_body_size INTEGER,
      timestamp DATETIME NOT NULL,
      error_message TEXT
    )
  ''');
  batch.execute('CREATE INDEX idx_client_ip ON api_access_log(client_ip)');
  batch.execute('CREATE INDEX idx_endpoint ON api_access_log(endpoint)');
  batch.execute(
    'CREATE INDEX idx_timestamp_access ON api_access_log(timestamp)',
  );

  await batch.commit(noResult: true);
}
