#!/usr/bin/env python3
"""
PISONET - Centralized Internet Cafe Management System
Main Server Application
"""

import os
import sys
import json
import sqlite3
import logging
import time
from datetime import datetime, timedelta
from threading import Thread, Lock
from functools import wraps

from flask import Flask, render_template, request, jsonify, send_from_directory
from flask_cors import CORS

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('pisonet.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Try to import GPIO libraries (optional for non-RPi systems)
try:
    import gpiozero
    GPIO_AVAILABLE = True
    logger.info("GPIO library available")
except ImportError:
    GPIO_AVAILABLE = False
    logger.warning("GPIO library not available - running in simulation mode")

# Flask app configuration
app = Flask(__name__)
CORS(app)
app.config['JSON_SORT_KEYS'] = False

# Configuration
DB_PATH = 'data/pisonet.db'
DATA_DIR = 'data'
ADMIN_PASSWORD = 'pisonet123'  # Change this!
COIN_VALUE = 10  # Minutes per peso
MAX_CREDIT = 480  # Max minutes per client
SESSION_TIMEOUT = 1440  # Minutes

# GPIO Configuration
COIN_PIN = 3
RELAY_PIN = 5

# Thread safety
db_lock = Lock()
gpio_lock = Lock()

# Global GPIO devices (if available)
coin_sensor = None
relay_device = None


class DatabaseManager:
    """Handle all database operations"""
    
    @staticmethod
    def init_db():
        """Initialize database with required tables"""
        os.makedirs(DATA_DIR, exist_ok=True)
        
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        # Clients table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS clients (
                client_id TEXT PRIMARY KEY,
                hostname TEXT,
                ip_address TEXT,
                credit INTEGER DEFAULT 0,
                status TEXT DEFAULT 'online',
                last_seen TIMESTAMP,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                banned INTEGER DEFAULT 0
            )
        ''')
        
        # Transactions table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS transactions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                client_id TEXT,
                amount INTEGER,
                type TEXT,
                timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY(client_id) REFERENCES clients(client_id)
            )
        ''')
        
        # System logs table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS system_logs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                level TEXT,
                message TEXT,
                timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        # Configuration table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS config (
                key TEXT PRIMARY KEY,
                value TEXT
            )
        ''')
        
        # Insert default configuration
        defaults = {
            'coin_value': str(COIN_VALUE),
            'max_credit': str(MAX_CREDIT),
            'session_timeout': str(SESSION_TIMEOUT),
            'admin_password': ADMIN_PASSWORD
        }
        
        for key, value in defaults.items():
            cursor.execute('INSERT OR IGNORE INTO config (key, value) VALUES (?, ?)',
                         (key, value))
        
        conn.commit()
        conn.close()
        logger.info("Database initialized successfully")
    
    @staticmethod
    def get_client(client_id):
        """Get client information"""
        with db_lock:
            conn = sqlite3.connect(DB_PATH)
            conn.row_factory = sqlite3.Row
            cursor = conn.cursor()
            cursor.execute('SELECT * FROM clients WHERE client_id = ?', (client_id,))
            row = cursor.fetchone()
            conn.close()
            return dict(row) if row else None
    
    @staticmethod
    def add_client(client_id, hostname, ip_address):
        """Register a new client"""
        with db_lock:
            conn = sqlite3.connect(DB_PATH)
            cursor = conn.cursor()
            cursor.execute('''
                INSERT OR REPLACE INTO clients 
                (client_id, hostname, ip_address, last_seen)
                VALUES (?, ?, ?, CURRENT_TIMESTAMP)
            ''', (client_id, hostname, ip_address))
            conn.commit()
            conn.close()
            logger.info(f"Client registered: {client_id} ({hostname})")
    
    @staticmethod
    def update_credit(client_id, amount, transaction_type='manual'):
        """Update client credit"""
        with db_lock:
            conn = sqlite3.connect(DB_PATH)
            cursor = conn.cursor()
            
            # Get max credit from config
            cursor.execute('SELECT value FROM config WHERE key = ?', ('max_credit',))
            max_credit = int(cursor.fetchone()[0])
            
            # Get current credit
            cursor.execute('SELECT credit FROM clients WHERE client_id = ?', (client_id,))
            result = cursor.fetchone()
            current = result[0] if result else 0
            
            new_credit = min(current + amount, max_credit)
            
            cursor.execute(
                'UPDATE clients SET credit = ? WHERE client_id = ?',
                (new_credit, client_id)
            )
            cursor.execute(
                'INSERT INTO transactions (client_id, amount, type) VALUES (?, ?, ?)',
                (client_id, amount, transaction_type)
            )
            
            conn.commit()
            conn.close()
            logger.info(f"Credit updated for {client_id}: {amount} minutes (now: {new_credit})")
            
            return new_credit
    
    @staticmethod
    def get_all_clients():
        """Get all registered clients"""
        with db_lock:
            conn = sqlite3.connect(DB_PATH)
            conn.row_factory = sqlite3.Row
            cursor = conn.cursor()
            cursor.execute('SELECT * FROM clients ORDER BY last_seen DESC')
            rows = cursor.fetchall()
            conn.close()
            return [dict(row) for row in rows]
    
    @staticmethod
    def get_statistics():
        """Get system statistics"""
        with db_lock:
            conn = sqlite3.connect(DB_PATH)
            cursor = conn.cursor()
            
            cursor.execute('SELECT COUNT(*) FROM clients WHERE status = ?', ('online',))
            active_clients = cursor.fetchone()[0]
            
            cursor.execute('SELECT COUNT(*) FROM clients')
            total_clients = cursor.fetchone()[0]
            
            cursor.execute('SELECT SUM(amount) FROM transactions WHERE type = ?', ('coin',))
            total_revenue = cursor.fetchone()[0] or 0
            
            cursor.execute('SELECT COUNT(*) FROM transactions WHERE type = ?', ('coin',))
            total_coins = cursor.fetchone()[0]
            
            conn.close()
            
            return {
                'active_clients': active_clients,
                'total_clients': total_clients,
                'total_revenue': total_revenue,
                'total_coins': total_coins
            }


class GPIOManager:
    """Handle GPIO operations"""
    
    @staticmethod
    def init_gpio():
        """Initialize GPIO pins"""
        global coin_sensor, relay_device
        
        if not GPIO_AVAILABLE:
            logger.warning("GPIO not available - using simulation mode")
            return False
        
        try:
            with gpio_lock:
                coin_sensor = gpiozero.Button(COIN_PIN)
                relay_device = gpiozero.OutputDevice(RELAY_PIN)
                relay_device.on()  # Default state: relay OFF (HIGH)
            logger.info(f"GPIO initialized - Coin Pin: {COIN_PIN}, Relay Pin: {RELAY_PIN}")
            return True
        except Exception as e:
            logger.error(f"GPIO initialization failed: {e}")
            return False
    
    @staticmethod
    def activate_coin_slot():
        """Activate coin slot (energize relay - LOW)"""
        if not GPIO_AVAILABLE or relay_device is None:
            logger.info("Coin slot activated (simulated)")
            return True
        
        try:
            with gpio_lock:
                relay_device.off()  # LOW = Relay ON (energized)
            logger.info("Coin slot activated")
            return True
        except Exception as e:
            logger.error(f"Failed to activate coin slot: {e}")
            return False
    
    @staticmethod
    def deactivate_coin_slot():
        """Deactivate coin slot (de-energize relay - HIGH)"""
        if not GPIO_AVAILABLE or relay_device is None:
            logger.info("Coin slot deactivated (simulated)")
            return True
        
        try:
            with gpio_lock:
                relay_device.on()  # HIGH = Relay OFF (de-energized)
            logger.info("Coin slot deactivated")
            return True
        except Exception as e:
            logger.error(f"Failed to deactivate coin slot: {e}")
            return False
    
    @staticmethod
    def get_gpio_status():
        """Get GPIO status"""
        status = {
            'gpio_available': GPIO_AVAILABLE,
            'coin_pin': COIN_PIN,
            'relay_pin': RELAY_PIN,
            'relay_state': None
        }
        
        if GPIO_AVAILABLE and relay_device is not None:
            try:
                with gpio_lock:
                    status['relay_state'] = 'ON (energized)' if not relay_device.is_lit else 'OFF (de-energized)'
            except Exception as e:
                logger.warning(f"Could not read relay state: {e}")
        
        return status


# API Endpoints
def require_admin(f):
    """Decorator to require admin authentication"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        auth = request.json.get('admin_password') if request.json else None
        with db_lock:
            conn = sqlite3.connect(DB_PATH)
            cursor = conn.cursor()
            cursor.execute('SELECT value FROM config WHERE key = ?', ('admin_password',))
            result = cursor.fetchone()
            conn.close()
            admin_password = result[0] if result else ADMIN_PASSWORD
        
        if auth != admin_password:
            return jsonify({'error': 'Unauthorized'}), 401
        return f(*args, **kwargs)
    return decorated_function


@app.route('/api/status', methods=['GET'])
def api_status():
    """Get server status"""
    return jsonify({
        'status': 'running',
        'version': '7.0.0',
        'timestamp': datetime.now().isoformat(),
        'gpio': GPIOManager.get_gpio_status()
    })


@app.route('/api/register', methods=['POST'])
def api_register():
    """Register a new client"""
    data = request.json
    client_id = data.get('client_id')
    hostname = data.get('hostname', 'Unknown')
    ip_address = data.get('ip_address', request.remote_addr)
    
    if not client_id:
        return jsonify({'error': 'client_id required'}), 400
    
    DatabaseManager.add_client(client_id, hostname, ip_address)
    
    return jsonify({
        'status': 'registered',
        'client_id': client_id,
        'message': f'Client {hostname} registered successfully'
    }), 201


@app.route('/api/get_credit', methods=['POST'])
def api_get_credit():
    """Get client credit"""
    data = request.json
    client_id = data.get('client_id')
    
    if not client_id:
        return jsonify({'error': 'client_id required'}), 400
    
    client = DatabaseManager.get_client(client_id)
    
    if not client:
        return jsonify({'error': 'Client not found'}), 404
    
    if client['banned']:
        return jsonify({'error': 'Client is banned'}), 403
    
    return jsonify({
        'client_id': client_id,
        'credit': client['credit'],
        'status': client['status']
    })


@app.route('/api/request_coin', methods=['POST'])
def api_request_coin():
    """Request coin insertion (activate coin slot)"""
    data = request.json
    client_id = data.get('client_id')
    
    if not client_id:
        return jsonify({'error': 'client_id required'}), 400
    
    client = DatabaseManager.get_client(client_id)
    if not client:
        return jsonify({'error': 'Client not found'}), 404
    
    GPIOManager.activate_coin_slot()
    
    # Auto-deactivate after 10 seconds
    def deactivate_later():
        time.sleep(10)
        GPIOManager.deactivate_coin_slot()
    
    Thread(target=deactivate_later, daemon=True).start()
    
    return jsonify({
        'status': 'coin_slot_active',
        'client_id': client_id,
        'message': 'Coin slot activated, waiting for coin insertion...'
    })


@app.route('/api/add_credit', methods=['POST'])
def api_add_credit():
    """Admin: Add credit to client"""
    data = request.json
    admin_password = data.get('admin_password')
    client_id = data.get('client_id')
    amount = data.get('amount', 0)
    
    # Verify admin password
    with db_lock:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        cursor.execute('SELECT value FROM config WHERE key = ?', ('admin_password',))
        result = cursor.fetchone()
        conn.close()
        stored_password = result[0] if result else ADMIN_PASSWORD
    
    if admin_password != stored_password:
        return jsonify({'error': 'Unauthorized'}), 401
    
    if not client_id or amount <= 0:
        return jsonify({'error': 'Invalid parameters'}), 400
    
    new_credit = DatabaseManager.update_credit(client_id, amount, 'admin')
    
    return jsonify({
        'client_id': client_id,
        'added': amount,
        'new_credit': new_credit,
        'message': f'Added {amount} minutes to {client_id}'
    })


@app.route('/api/clear_all_credits', methods=['POST'])
@require_admin
def api_clear_all_credits():
    """Admin: Clear all credits (emergency)"""
    with db_lock:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        cursor.execute('UPDATE clients SET credit = 0')
        conn.commit()
        conn.close()
    
    logger.warning("EMERGENCY: All credits cleared")
    
    return jsonify({
        'status': 'success',
        'message': 'All credits have been cleared'
    })


@app.route('/admin', methods=['GET'])
def admin_panel():
    """Admin panel dashboard"""
    return render_template('admin.html')


@app.route('/api/admin/clients', methods=['GET'])
def api_admin_clients():
    """Get all clients for admin"""
    password = request.args.get('password')
    
    with db_lock:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        cursor.execute('SELECT value FROM config WHERE key = ?', ('admin_password',))
        result = cursor.fetchone()
        conn.close()
        stored_password = result[0] if result else ADMIN_PASSWORD
    
    if password != stored_password:
        return jsonify({'error': 'Unauthorized'}), 401
    
    clients = DatabaseManager.get_all_clients()
    return jsonify(clients)


@app.route('/api/admin/statistics', methods=['GET'])
def api_admin_statistics():
    """Get statistics"""
    password = request.args.get('password')
    
    with db_lock:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        cursor.execute('SELECT value FROM config WHERE key = ?', ('admin_password',))
        result = cursor.fetchone()
        conn.close()
        stored_password = result[0] if result else ADMIN_PASSWORD
    
    if password != stored_password:
        return jsonify({'error': 'Unauthorized'}), 401
    
    stats = DatabaseManager.get_statistics()
    return jsonify(stats)


@app.route('/', methods=['GET'])
def index():
    """Welcome page"""
    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <title>PISONET - Server Running</title>
        <style>
            body { font-family: Arial; text-align: center; margin-top: 50px; }
            .container { max-width: 600px; margin: 0 auto; }
            h1 { color: #333; }
            p { color: #666; }
            a { color: #007bff; text-decoration: none; margin: 10px; }
            a:hover { text-decoration: underline; }
            .status { background: #d4edda; padding: 20px; border-radius: 5px; }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🎮 PISONET Server Running</h1>
            <div class="status">
                <p>✅ Server is online and operational</p>
                <p><strong>Version:</strong> 7.0.0</p>
                <p><strong>Timestamp:</strong> ''' + datetime.now().strftime('%Y-%m-%d %H:%M:%S') + '''</p>
            </div>
            <p><a href="/admin">→ Go to Admin Panel</a></p>
            <p><a href="/api/status">→ Check Server Status</a></p>
        </div>
    </body>
    </html>
    '''


def init_app():
    """Initialize the application"""
    logger.info("=== PISONET Server Starting ===")
    DatabaseManager.init_db()
    GPIOManager.init_gpio()
    logger.info("=== PISONET Server Ready ===")


if __name__ == '__main__':
    init_app()
    app.run(host='0.0.0.0', port=5000, debug=False)
