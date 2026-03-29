#!/usr/bin/env python3
"""
PISONET - Client Application
Full-screen lock screen with credit management
"""

import sys
import os
import json
import socket
import threading
import time
import logging
import socket as socket_module
from datetime import datetime, timedelta
from tkinter import *
from tkinter import messagebox
import requests
from urllib.parse import urljoin

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('pisonet_client.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)


class PISONETClient:
    """PISONET Client Application"""
    
    def __init__(self, server_url):
        self.server_url = server_url.rstrip('/')
        self.client_id = self.generate_client_id()
        self.credit = 0
        self.hostname = socket.gethostname()
        self.ip_address = self.get_ip_address()
        self.session_minutes = 0
        self.running = True
        self.admin_password = ""
        
        logger.info(f"Client initialized - ID: {self.client_id}, Server: {self.server_url}")
        
        # Initialize Tkinter
        self.root = Tk()
        self.root.attributes('-fullscreen', True)
        self.root.configure(bg='#1a1a1a')
        
        # Disable close button
        self.root.protocol("WM_DELETE_WINDOW", self.on_close_attempt)
        
        # Key bindings
        self.root.bind('<Escape>', lambda e: None)  # Disable ESC
        self.root.bind('<Alt-F4>', lambda e: None)  # Disable Alt+F4
        self.root.bind('<ctrl-w>', lambda e: None)  # Disable Ctrl+W
        self.root.bind('<ctrl-shift-a>', self.admin_prompt)  # Admin access
        
        # GUI Setup
        self.setup_gui()
        self.register_client()
        self.start_update_thread()
    
    @staticmethod
    def generate_client_id():
        """Generate unique client ID"""
        mac = socket.gethostbyname(socket.gethostname())
        timestamp = int(time.time())
        return f"client_{mac.replace('.', '_')}_{timestamp}"
    
    @staticmethod
    def get_ip_address():
        """Get local IP address"""
        try:
            s = socket_module.socket(socket_module.AF_INET, socket_module.SOCK_DGRAM)
            s.connect(("8.8.8.8", 80))
            ip = s.getsockname()[0]
            s.close()
            return ip
        except:
            return "127.0.0.1"
    
    def setup_gui(self):
        """Setup GUI elements"""
        # Main frame
        main_frame = Frame(self.root, bg='#1a1a1a')
        main_frame.pack(expand=True, fill=BOTH)
        
        # Title
        title_label = Label(
            main_frame,
            text="🎮 PISONET",
            font=("Arial", 64, "bold"),
            bg='#1a1a1a',
            fg='#00ff00'
        )
        title_label.pack(pady=20)
        
        # Status frame
        status_frame = Frame(main_frame, bg='#1a1a1a')
        status_frame.pack(pady=20)
        
        status_label = Label(
            status_frame,
            text="Internet Session Monitor",
            font=("Arial", 24),
            bg='#1a1a1a',
            fg='#ffffff'
        )
        status_label.pack()
        
        # Credit display
        self.credit_label = Label(
            main_frame,
            text="Credit: Loading...",
            font=("Arial", 48, "bold"),
            bg='#1a1a1a',
            fg='#00ff00'
        )
        self.credit_label.pack(pady=30)
        
        # Timer display
        self.timer_label = Label(
            main_frame,
            text="Session Time: 00:00:00",
            font=("Arial", 36),
            bg='#1a1a1a',
            fg='#ffaa00'
        )
        self.timer_label.pack(pady=20)
        
        # Status info
        self.status_label = Label(
            main_frame,
            text="Status: Connecting...",
            font=("Arial", 16),
            bg='#1a1a1a',
            fg='#cccccc'
        )
        self.status_label.pack(pady=10)
        
        # Insert coin button
        self.coin_button = Button(
            main_frame,
            text="INSERT COIN",
            font=("Arial", 24, "bold"),
            bg='#ff6600',
            fg='#ffffff',
            padx=40,
            pady=20,
            command=self.request_coin,
            activebackground='#ff8844',
            activeforeground='#ffffff'
        )
        self.coin_button.pack(pady=30)
        
        # Info text
        info_label = Label(
            main_frame,
            text="Press Ctrl+Shift+A for admin panel | Your session is continuously monitored",
            font=("Arial", 11),
            bg='#1a1a1a',
            fg='#666666'
        )
        info_label.pack(side=BOTTOM, pady=20)
    
    def register_client(self):
        """Register with server"""
        try:
            response = requests.post(
                urljoin(self.server_url, '/api/register'),
                json={
                    'client_id': self.client_id,
                    'hostname': self.hostname,
                    'ip_address': self.ip_address
                },
                timeout=5
            )
            if response.status_code == 201:
                logger.info("Client registered successfully")
                self.update_status("Connected to server")
            else:
                logger.error(f"Registration failed: {response.text}")
                self.update_status("Registration error")
        except Exception as e:
            logger.error(f"Failed to register: {e}")
            self.update_status(f"Connection error: {str(e)}")
    
    def get_credit(self):
        """Get current credit from server"""
        try:
            response = requests.post(
                urljoin(self.server_url, '/api/get_credit'),
                json={'client_id': self.client_id},
                timeout=5
            )
            if response.status_code == 200:
                data = response.json()
                self.credit = data.get('credit', 0)
                return True
            else:
                logger.warning(f"Credit check failed: {response.status_code}")
                return False
        except Exception as e:
            logger.error(f"Failed to get credit: {e}")
            return False
    
    def request_coin(self):
        """Request coin insertion"""
        try:
            response = requests.post(
                urljoin(self.server_url, '/api/request_coin'),
                json={'client_id': self.client_id},
                timeout=5
            )
            if response.status_code == 200:
                self.update_status("Coin slot active - Insert coin now!")
                logger.info("Coin slot activated")
            else:
                self.update_status("Coin request failed")
                logger.warning(f"Coin request failed: {response.status_code}")
        except Exception as e:
            logger.error(f"Failed to request coin: {e}")
            self.update_status(f"Error: {str(e)}")
    
    def update_status(self, message):
        """Update status label"""
        try:
            self.status_label.config(text=f"Status: {message}")
        except:
            pass
    
    def update_credit_display(self):
        """Update credit display"""
        try:
            hours = self.credit // 60
            minutes = self.credit % 60
            self.credit_label.config(
                text=f"Credit: {self.credit} mins\n({hours}h {minutes}m)"
            )
        except:
            pass
    
    def on_close_attempt(self):
        """Handle window close attempt"""
        logger.warning("Close button pressed - ignoring")
        messagebox.showwarning("Blocked", "Cannot close this window during session")
    
    def admin_prompt(self, event):
        """Prompt for admin password"""
        dialog = Toplevel(self.root)
        dialog.title("Admin Access")
        dialog.geometry("400x150")
        dialog.configure(bg='#1a1a1a')
        
        Label(
            dialog,
            text="Enter Admin Password:",
            font=("Arial", 12),
            bg='#1a1a1a',
            fg='#ffffff'
        ).pack(pady=10)
        
        entry = Entry(dialog, show="*", font=("Arial", 12))
        entry.pack(pady=5, padx=20, fill=X)
        entry.focus()
        
        def verify():
            password = entry.get()
            if password == "admin":  # Simple verification
                self.show_admin_panel(password)
                dialog.destroy()
            else:
                messagebox.showerror("Failed", "Incorrect password")
        
        Button(
            dialog,
            text="Verify",
            command=verify,
            font=("Arial", 11),
            bg='#00ff00',
            fg='#000000'
        ).pack(pady=10)
    
    def show_admin_panel(self, password):
        """Show admin panel"""
        admin_window = Toplevel(self.root)
        admin_window.title("Admin Panel")
        admin_window.geometry("500x400")
        admin_window.configure(bg='#1a1a1a')
        
        Label(
            admin_window,
            text="Admin Control Panel",
            font=("Arial", 18, "bold"),
            bg='#1a1a1a',
            fg='#00ff00'
        ).pack(pady=10)
        
        # Display stats
        stats_text = f"""
Client ID: {self.client_id}
Hostname: {self.hostname}
IP Address: {self.ip_address}
Current Credit: {self.credit} minutes
Server: {self.server_url}
        """
        
        info_label = Label(
            admin_window,
            text=stats_text,
            font=("Courier", 10),
            bg='#1a1a1a',
            fg='#00ff00',
            justify=LEFT
        )
        info_label.pack(pady=10, padx=10)
        
        # Action buttons
        button_frame = Frame(admin_window, bg='#1a1a1a')
        button_frame.pack(pady=20)
        
        Button(
            button_frame,
            text="Test Connection",
            command=self.test_connectionz,
            font=("Arial", 10),
            bg='#0066ff',
            fg='#ffffff',
            width=20
        ).pack(pady=5)
        
        Button(
            button_frame,
            text="Exit Admin",
            command=admin_window.destroy,
            font=("Arial", 10),
            bg='#ff0000',
            fg='#ffffff',
            width=20
        ).pack(pady=5)
    
    def test_connectionz(self):
        """Test server connection"""
        try:
            response = requests.get(
                urljoin(self.server_url, '/api/status'),
                timeout=5
            )
            if response.status_code == 200:
                data = response.json()
                messagebox.showinfo(
                    "Connection",
                    f"✅ Server online\n\nVersion: {data.get('version', 'Unknown')}\nStatus: {data.get('status', 'Unknown')}"
                )
            else:
                messagebox.showerror("Error", f"Server error: {response.status_code}")
        except Exception as e:
            messagebox.showerror("Error", f"Connection failed: {str(e)}")
    
    def start_update_thread(self):
        """Start background update thread"""
        def update_loop():
            while self.running:
                try:
                    self.get_credit()
                    self.update_credit_display()
                    if self.session_minutes > 0:
                        self.session_minutes -= 1
                    time.sleep(1)
                except Exception as e:
                    logger.error(f"Update error: {e}")
                    time.sleep(5)
        
        thread = threading.Thread(target=update_loop, daemon=True)
        thread.start()
    
    def run(self):
        """Run the application"""
        try:
            self.root.mainloop()
        except KeyboardInterrupt:
            logger.info("Client stopped by user")
        finally:
            self.running = False


def main():
    """Main entry point"""
    if len(sys.argv) < 2:
        server_url = "http://localhost:5000"
        print(f"No server URL provided, using default: {server_url}")
    else:
        server_url = sys.argv[1]
    
    logger.info(f"Starting PISONET Client - Server: {server_url}")
    
    client = PISONETClient(server_url)
    client.run()


if __name__ == '__main__':
    main()
