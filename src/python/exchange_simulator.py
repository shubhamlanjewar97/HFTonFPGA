import tkinter as tk
from tkinter import ttk, filedialog, scrolledtext
import serial
import threading
import csv
import time
import random
import queue
from datetime import datetime
import serial.tools.list_ports
import configparser
import os

# Load configuration
def load_config():
    config = {
        "baud_rate": 115200,
        "packet_delay": 0.1,  # seconds between packets
        "num_packets": 1500,  # number of packets to generate
        "num_stocks": 4,      # number of different stocks
        "order_book_depth": 256,  # maximum orders per stock
        "price_min": 90.0,    # minimum price
        "price_max": 110.0,   # maximum price
        "quantity_min": 1,    # minimum quantity
        "quantity_max": 255,  # maximum quantity
        "cancel_probability": 0.3,  # probability of generating a cancel order
    }
    
    if os.path.exists('config.ini'):
        parser = configparser.ConfigParser()
        parser.read('config.ini')
        if 'Settings' in parser:
            settings = parser['Settings']
            for key in config:
                if key in settings:
                    # Convert value to appropriate type
                    if isinstance(config[key], int):
                        config[key] = int(settings[key])
                    elif isinstance(config[key], float):
                        config[key] = float(settings[key])
                    else:
                        config[key] = settings[key]
    
    return config

CONFIG = load_config()

# Save configuration
def save_config(config):
    parser = configparser.ConfigParser()
    parser['Settings'] = {str(k): str(v) for k, v in config.items()}
    with open('config.ini', 'w') as f:
        parser.write(f)

# Message types
MSG_ADD_ORDER = 0x82
MSG_CANCEL_ORDER = 0xA1

# Stock book to track orders
class StockBook:
    def __init__(self):
        self.orders = {}  # order_id -> order_details
        self.buy_orders = {}  # stock_id -> list of buy orders
        self.sell_orders = {}  # stock_id -> list of sell orders
        
    def add_order(self, order_id, stock_id, is_buy, price, quantity):
        self.orders[order_id] = {
            "stock_id": stock_id,
            "is_buy": is_buy,
            "price": price,
            "quantity": quantity
        }
        
        # Add to buy/sell order lists
        orders_list = self.buy_orders if is_buy else self.sell_orders
        if stock_id not in orders_list:
            orders_list[stock_id] = []
        
        orders_list[stock_id].append({
            "order_id": order_id,
            "price": price,
            "quantity": quantity
        })
        
        # Sort buy orders by price (descending)
        if is_buy and stock_id in self.buy_orders:
            self.buy_orders[stock_id] = sorted(
                self.buy_orders[stock_id], 
                key=lambda x: x["price"], 
                reverse=True
            )
        
        # Sort sell orders by price (ascending)
        if not is_buy and stock_id in self.sell_orders:
            self.sell_orders[stock_id] = sorted(
                self.sell_orders[stock_id], 
                key=lambda x: x["price"]
            )
    
    def remove_order(self, order_id):
        if order_id in self.orders:
            order = self.orders[order_id]
            stock_id = order["stock_id"]
            is_buy = order["is_buy"]
            
            # Remove from buy/sell order lists
            orders_list = self.buy_orders if is_buy else self.sell_orders
            if stock_id in orders_list:
                orders_list[stock_id] = [o for o in orders_list[stock_id] if o["order_id"] != order_id]
            
            # Remove from orders dictionary
            del self.orders[order_id]
            return True
        return False
    
    def get_highest_buy(self, stock_id):
        if stock_id in self.buy_orders and self.buy_orders[stock_id]:
            return self.buy_orders[stock_id][0]  # Already sorted
        return None
    
    def get_lowest_sell(self, stock_id):
        if stock_id in self.sell_orders and self.sell_orders[stock_id]:
            return self.sell_orders[stock_id][0]  # Already sorted
        return None
    
    def get_order_count(self, stock_id):
        buy_count = len(self.buy_orders.get(stock_id, []))
        sell_count = len(self.sell_orders.get(stock_id, []))
        return buy_count + sell_count

# Main application
class ExchangeSimulator:
    def __init__(self, root):
        self.root = root
        self.root.title("HFT Exchange Simulator")
        self.root.geometry("1000x800")
        
        self.serial_port = None
        self.tx_thread = None
        self.rx_thread = None
        self.running = False
        self.stock_book = StockBook()
        self.next_order_id = 1
        self.packet_queue = queue.Queue()
        self.rx_queue = queue.Queue()
        
        # Create the GUI
        self.create_widgets()
    
    def create_widgets(self):
        # Connection frame
        conn_frame = ttk.LabelFrame(self.root, text="Connection")
        conn_frame.pack(fill="x", padx=10, pady=5)
        
        ttk.Label(conn_frame, text="Port:").grid(row=0, column=0, padx=5, pady=5)
        self.port_var = tk.StringVar()
        self.port_combo = ttk.Combobox(conn_frame, textvariable=self.port_var)
        self.port_combo.grid(row=0, column=1, padx=5, pady=5)
        self.refresh_ports()
        
        ttk.Button(conn_frame, text="Refresh", command=self.refresh_ports).grid(row=0, column=2, padx=5, pady=5)
        ttk.Button(conn_frame, text="Connect", command=self.connect).grid(row=0, column=3, padx=5, pady=5)
        ttk.Button(conn_frame, text="Disconnect", command=self.disconnect).grid(row=0, column=4, padx=5, pady=5)
        
        # Settings frame
        settings_frame = ttk.LabelFrame(self.root, text="Settings")
        settings_frame.pack(fill="x", padx=10, pady=5)
        
        ttk.Label(settings_frame, text="Packet Delay (s):").grid(row=0, column=0, padx=5, pady=5)
        self.delay_var = tk.DoubleVar(value=CONFIG["packet_delay"])
        ttk.Entry(settings_frame, textvariable=self.delay_var, width=10).grid(row=0, column=1, padx=5, pady=5)
        
        ttk.Label(settings_frame, text="Number of Packets:").grid(row=0, column=2, padx=5, pady=5)
        self.num_packets_var = tk.IntVar(value=CONFIG["num_packets"])
        ttk.Entry(settings_frame, textvariable=self.num_packets_var, width=10).grid(row=0, column=3, padx=5, pady=5)
        
        ttk.Label(settings_frame, text="Cancel Probability:").grid(row=0, column=4, padx=5, pady=5)
        self.cancel_prob_var = tk.DoubleVar(value=CONFIG["cancel_probability"])
        ttk.Entry(settings_frame, textvariable=self.cancel_prob_var, width=10).grid(row=0, column=5, padx=5, pady=5)
        
        ttk.Button(settings_frame, text="Save Config", command=self.save_config).grid(row=0, column=6, padx=5, pady=5)
        
        # Action buttons
        action_frame = ttk.Frame(self.root)
        action_frame.pack(fill="x", padx=10, pady=5)
        
        ttk.Button(action_frame, text="Generate CSV", command=self.generate_csv).pack(side="left", padx=5, pady=5)
        ttk.Button(action_frame, text="Load CSV", command=self.load_csv).pack(side="left", padx=5, pady=5)
        ttk.Button(action_frame, text="Start Simulation", command=self.start_simulation).pack(side="left", padx=5, pady=5)
        ttk.Button(action_frame, text="Stop Simulation", command=self.stop_simulation).pack(side="left", padx=5, pady=5)
        
        # Notebook for different views
        notebook = ttk.Notebook(self.root)
        notebook.pack(fill="both", expand=True, padx=10, pady=5)
        
        # Sent packets tab
        sent_tab = ttk.Frame(notebook)
        notebook.add(sent_tab, text="Sent Packets")
        
        self.sent_text = scrolledtext.ScrolledText(sent_tab)
        self.sent_text.pack(fill="both", expand=True)
        
        # Received packets tab
        received_tab = ttk.Frame(notebook)
        notebook.add(received_tab, text="Received Packets")
        
        self.received_text = scrolledtext.ScrolledText(received_tab)
        self.received_text.pack(fill="both", expand=True)
        
        # Order book tab
        orderbook_tab = ttk.Frame(notebook)
        notebook.add(orderbook_tab, text="Order Book")
        
        self.orderbook_text = scrolledtext.ScrolledText(orderbook_tab)
        self.orderbook_text.pack(fill="both", expand=True)
        
        # Status bar
        self.status_var = tk.StringVar(value="Ready")
        status_bar = ttk.Label(self.root, textvariable=self.status_var, relief="sunken", anchor="w")
        status_bar.pack(side="bottom", fill="x")
        
        # Set up periodic UI updates
        self.root.after(100, self.update_ui)
    
    def save_config(self):
        # Update CONFIG with current values
        CONFIG["packet_delay"] = self.delay_var.get()
        CONFIG["num_packets"] = self.num_packets_var.get()
        CONFIG["cancel_probability"] = self.cancel_prob_var.get()
        
        # Save the updated configuration
        save_config(CONFIG)
        self.status_var.set("Configuration saved")
    
    def refresh_ports(self):
        ports = [p.device for p in serial.tools.list_ports.comports()]
        self.port_combo['values'] = ports
        if ports:
            self.port_var.set(ports[0])
    
    def connect(self):
        port = self.port_var.get()
        try:
            self.serial_port = serial.Serial(
                port=port,
                baudrate=CONFIG["baud_rate"],
                bytesize=serial.EIGHTBITS,
                parity=serial.PARITY_NONE,
                stopbits=serial.STOPBITS_ONE,
                timeout=0.1
            )
            self.status_var.set(f"Connected to {port}")
            
            # Start the receiver thread
            self.running = True
            self.rx_thread = threading.Thread(target=self.receive_packets)
            self.rx_thread.daemon = True
            self.rx_thread.start()
            
        except Exception as e:
            self.status_var.set(f"Error connecting: {str(e)}")
    
    def disconnect(self):
        self.running = False
        if self.tx_thread:
            self.tx_thread.join(timeout=1)
            self.tx_thread = None
        
        if self.rx_thread:
            self.rx_thread.join(timeout=1)
            self.rx_thread = None
        
        if self.serial_port and self.serial_port.is_open:
            self.serial_port.close()
            self.status_var.set("Disconnected")
    
    def generate_csv(self):
        filename = filedialog.asksaveasfilename(
            defaultextension=".csv",
            filetypes=[("CSV files", "*.csv"), ("All files", "*.*")]
        )
        if not filename:
            return
        
        try:
            num_packets = self.num_packets_var.get()
            self.status_var.set(f"Generating {num_packets} packets...")
            
            packets = self.generate_market_data(num_packets)
            
            with open(filename, 'w', newline='') as csvfile:
                fieldnames = ['type', 'stock_id', 'order_id', 'is_buy', 'price', 'quantity']
                writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
                writer.writeheader()
                
                for packet in packets:
                    writer.writerow(packet)
            
            self.status_var.set(f"Generated {num_packets} packets to {filename}")
            
        except Exception as e:
            self.status_var.set(f"Error generating CSV: {str(e)}")
    
    def load_csv(self):
        filename = filedialog.askopenfilename(
            filetypes=[("CSV files", "*.csv"), ("All files", "*.*")]
        )
        if not filename:
            return
        
        try:
            packets = []
            with open(filename, 'r', newline='') as csvfile:
                reader = csv.DictReader(csvfile)
                for row in reader:
                    packet = {
                        'type': row['type'],
                        'stock_id': int(row['stock_id']),
                        'order_id': int(row['order_id']),
                        'is_buy': row['is_buy'].lower() == 'true',
                        'price': float(row['price']),
                        'quantity': int(row['quantity'])
                    }
                    packets.append(packet)
            
            # Clear the queue and add the new packets
            while not self.packet_queue.empty():
                self.packet_queue.get()
            
            for packet in packets:
                self.packet_queue.put(packet)
            
            self.status_var.set(f"Loaded {len(packets)} packets from {filename}")
            
        except Exception as e:
            self.status_var.set(f"Error loading CSV: {str(e)}")
    
    def start_simulation(self):
        if not self.serial_port or not self.serial_port.is_open:
            self.status_var.set("Please connect to a serial port first")
            return
        
        if self.packet_queue.empty():
            self.status_var.set("No packets to send. Please generate or load packets first.")
            return
        
        # Start the transmitter thread
        self.running = True
        self.tx_thread = threading.Thread(target=self.send_packets)
        self.tx_thread.daemon = True
        self.tx_thread.start()
        
        self.status_var.set("Simulation started")
    
    def stop_simulation(self):
        self.running = False
        self.status_var.set("Simulation stopped")
    
    def generate_market_data(self, num_packets):
        packets = []
        active_orders = {stock_id: [] for stock_id in range(1, CONFIG["num_stocks"] + 1)}
        next_order_id = 1
        
        for _ in range(num_packets):
            # Decide whether to add or cancel an order
            if (random.random() < CONFIG["cancel_probability"] and 
                any(len(orders) > 0 for orders in active_orders.values())):
                # Find a stock with active orders to cancel
                valid_stocks = [stock_id for stock_id, orders in active_orders.items() if orders]
                if not valid_stocks:
                    # No valid stocks to cancel orders from, create a new order instead
                    stock_id = random.randint(1, CONFIG["num_stocks"])
                    is_buy = random.random() < 0.5
                    price = round(random.uniform(CONFIG["price_min"], CONFIG["price_max"]), 2)
                    quantity = random.randint(CONFIG["quantity_min"], CONFIG["quantity_max"])
                    
                    # Create add packet
                    packets.append({
                        'type': 'ADD',
                        'stock_id': stock_id,
                        'order_id': next_order_id,
                        'is_buy': is_buy,
                        'price': price,
                        'quantity': quantity
                    })
                    
                    # Add to active orders if we haven't reached the limit
                    if len(active_orders[stock_id]) < CONFIG["order_book_depth"]:
                        active_orders[stock_id].append({
                            'order_id': next_order_id,
                            'is_buy': is_buy,
                            'price': price,
                            'quantity': quantity
                        })
                    
                    next_order_id += 1
                    if next_order_id > 255:
                        next_order_id = 1  # Reset order ID to stay within 8-bit range
                    
                    continue
                
                stock_id = random.choice(valid_stocks)
                
                # Choose an order to cancel (prioritize highest buy or lowest sell)
                orders = active_orders[stock_id]
                buy_orders = sorted([o for o in orders if o['is_buy']], 
                                   key=lambda x: x['price'], reverse=True)
                sell_orders = sorted([o for o in orders if not o['is_buy']], 
                                    key=lambda x: x['price'])
                
                if buy_orders and (not sell_orders or random.random() < 0.5):
                    # Cancel highest buy order
                    order = buy_orders[0]
                else:
                    # Cancel lowest sell order
                    order = sell_orders[0] if sell_orders else buy_orders[0]
                
                # Remove the order from active orders
                active_orders[stock_id].remove(order)
                
                # Create cancel packet
                packets.append({
                    'type': 'CANCEL',
                    'stock_id': stock_id,
                    'order_id': order['order_id'],
                    'is_buy': order['is_buy'],
                    'price': order['price'],
                    'quantity': order['quantity']
                })
            else:
                # Create a new order
                stock_id = random.randint(1, CONFIG["num_stocks"])
                is_buy = random.random() < 0.5
                price = round(random.uniform(CONFIG["price_min"], CONFIG["price_max"]), 2)
                quantity = random.randint(CONFIG["quantity_min"], CONFIG["quantity_max"])
                
                # Create add packet
                packets.append({
                    'type': 'ADD',
                    'stock_id': stock_id,
                    'order_id': next_order_id,
                    'is_buy': is_buy,
                    'price': price,
                    'quantity': quantity
                })
                
                # Add to active orders if we haven't reached the limit
                if len(active_orders[stock_id]) < CONFIG["order_book_depth"]:
                    active_orders[stock_id].append({
                        'order_id': next_order_id,
                        'is_buy': is_buy,
                        'price': price,
                        'quantity': quantity
                    })
                
                next_order_id += 1
                if next_order_id > 255:
                    next_order_id = 1  # Reset order ID to stay within 8-bit range
        
        return packets
    
    def send_packets(self):
        delay = self.delay_var.get()
        self.sent_text.insert(tk.END, "Starting packet transmission\n")
        
        while self.running and not self.packet_queue.empty():
            packet_data = self.packet_queue.get()
            
            if packet_data['type'] == 'ADD':
                binary_packet = self.create_add_order_packet(
                    packet_data['stock_id'], 
                    packet_data['order_id'], 
                    packet_data['price'], 
                    packet_data['quantity'], 
                    packet_data['is_buy']
                )
            else:  # CANCEL
                binary_packet = self.create_cancel_order_packet(
                    packet_data['stock_id'], 
                    packet_data['order_id'], 
                    packet_data['quantity']
                )
            
            # Send the packet
            try:
                self.serial_port.write(binary_packet)
                
                # Update the packet queue display
                packet_str = f"[{datetime.now().strftime('%H:%M:%S.%f')[:-3]}] "
                packet_str += f"Sent {packet_data['type']} - Stock: {packet_data['stock_id']}, "
                packet_str += f"Order: {packet_data['order_id']}, "
                packet_str += f"{'Buy' if packet_data['is_buy'] else 'Sell'}, "
                packet_str += f"Price: {packet_data['price']:.2f}, "
                packet_str += f"Qty: {packet_data['quantity']}\n"
                
                self.sent_text.insert(tk.END, packet_str)
                self.sent_text.see(tk.END)
                
                # Update the stock book (for order book display)
                if packet_data['type'] == 'ADD':
                    self.stock_book.add_order(
                        packet_data['order_id'],
                        packet_data['stock_id'],
                        packet_data['is_buy'],
                        packet_data['price'],
                        packet_data['quantity']
                    )
                else:  # CANCEL
                    self.stock_book.remove_order(packet_data['order_id'])
                
                # Sleep to control packet rate
                time.sleep(delay)
                
            except Exception as e:
                self.status_var.set(f"Error sending packet: {str(e)}")
                break
        
        self.status_var.set("Transmission complete")
    
    def receive_packets(self):
        if not self.serial_port:
            return
        
        buffer = bytearray()
        
        while self.running:
            try:
                # Read data from serial port
                if self.serial_port.in_waiting:
                    data = self.serial_port.read(self.serial_port.in_waiting)
                    buffer.extend(data)
                    
                    # Process complete packets
                    while len(buffer) >= 1:  # At least 1 byte for length
                        packet_length = buffer[0]
                        
                        if len(buffer) < packet_length:
                            break  # Wait for more data
                        
                        # Extract the packet
                        packet = buffer[:packet_length]
                        buffer = buffer[packet_length:]
                        
                        # Process the packet
                        self.process_received_packet(packet)
                
                time.sleep(0.01)  # Short delay to prevent CPU hogging
                
            except Exception as e:
                self.status_var.set(f"Receiver error: {str(e)}")
                break
    
    def process_received_packet(self, packet):
        # Expected format: Length (1), Stock ID (1), Buy/Sell (1), Quantity (2), Price (2)
        if len(packet) < 6:
            return
        
        try:
            stock_id = packet[1]
            is_buy = packet[2] == 1  # 1 for buy, 0 for sell
            quantity = int.from_bytes(packet[3:5], byteorder='little')
            
            # Price is split into integer and fraction parts
            price_int = packet[5]
            price_frac = packet[6] / 256.0 if len(packet) > 6 else 0
            price = price_int + price_frac
            
            # Add to the queue for UI update
            self.rx_queue.put({
                'timestamp': datetime.now(),
                'stock_id': stock_id,
                'is_buy': is_buy,
                'quantity': quantity,
                'price': price
            })
            
        except Exception as e:
            print(f"Error processing received packet: {str(e)}")
    
    def update_ui(self):
        # Update received packets display
        while not self.rx_queue.empty():
            packet = self.rx_queue.get()
            
            packet_str = f"[{packet['timestamp'].strftime('%H:%M:%S.%f')[:-3]}] "
            packet_str += f"Received - Stock: {packet['stock_id']}, "
            packet_str += f"{'Buy' if packet['is_buy'] else 'Sell'}, "
            packet_str += f"Price: {packet['price']:.2f}, "
            packet_str += f"Qty: {packet['quantity']}\n"
            
            self.received_text.insert(tk.END, packet_str)
            self.received_text.see(tk.END)
        
        # Update order book display
        self.update_orderbook_display()
        
        # Schedule the next update
        self.root.after(100, self.update_ui)
    
    def update_orderbook_display(self):
        # Clear the order book display
        self.orderbook_text.delete(1.0, tk.END)
        
        # Gather order book data
        for stock_id in range(1, CONFIG["num_stocks"] + 1):
            buy_orders = self.stock_book.buy_orders.get(stock_id, [])
            sell_orders = self.stock_book.sell_orders.get(stock_id, [])
            
            # Skip if no orders
            if not buy_orders and not sell_orders:
                continue
            
            # Add header
            self.orderbook_text.insert(tk.END, f"Stock {stock_id} Order Book:\n")
            self.orderbook_text.insert(tk.END, "-" * 60 + "\n")
            
            # Add sell orders (highest to lowest)
            self.orderbook_text.insert(tk.END, "SELL ORDERS:\n")
            if sell_orders:
                for order in sorted(sell_orders, key=lambda x: x["price"]):
                    self.orderbook_text.insert(
                        tk.END, 
                        f"  Order {order['order_id']}: {order['quantity']} @ ${order['price']:.2f}\n"
                    )
            else:
                self.orderbook_text.insert(tk.END, "  No sell orders\n")
            
            # Add buy orders (highest to lowest)
            self.orderbook_text.insert(tk.END, "BUY ORDERS:\n")
            if buy_orders:
                for order in sorted(buy_orders, key=lambda x: x["price"], reverse=True):
                    self.orderbook_text.insert(
                        tk.END, 
                        f"  Order {order['order_id']}: {order['quantity']} @ ${order['price']:.2f}\n"
                    )
            else:
                self.orderbook_text.insert(tk.END, "  No buy orders\n")
            
            self.orderbook_text.insert(tk.END, "\n")
    
    def create_add_order_packet(self, stock_id, order_id, price, quantity, is_buy):
        # Convert price to fixed point format
        price_int = int(price)
        price_frac = int((price - price_int) * 256) & 0xFF
        
        # Create packet
        packet = bytearray()
        
        # Length (1 byte)
        packet.append(37)  # Fixed length for ADD_ORDER
        
        # Message Type (1 byte)
        packet.append(MSG_ADD_ORDER)
        
        # Stock Locate (2 bytes) - Little endian
        packet.extend(stock_id.to_bytes(2, byteorder='little'))
        
        # Tracking Number (2 bytes) - Random value
        packet.extend(random.randint(0, 65535).to_bytes(2, byteorder='little'))
        
        # Timestamp (6 bytes) - Nanoseconds since midnight
        now = datetime.now()
        midnight = now.replace(hour=0, minute=0, second=0, microsecond=0)
        nanoseconds = int((now - midnight).total_seconds() * 1_000_000_000)
        packet.extend(nanoseconds.to_bytes(6, byteorder='little'))
        
        # Order Reference Number (8 bytes)
        packet.extend(order_id.to_bytes(8, byteorder='little'))
        
        # Canceled Shares (4 bytes)
        packet.extend(quantity.to_bytes(4, byteorder='little'))
        
        return packet

# Main entry point
if __name__ == "__main__":
    root = tk.Tk()
    app = ExchangeSimulator(root)
    root.mainloop()_000_000)
        packet.extend(nanoseconds.to_bytes(6, byteorder='little'))
        
        # Order Reference Number (8 bytes)
        packet.extend(order_id.to_bytes(8, byteorder='little'))
        
        # Buy/Sell Indicator (1 byte)
        packet.append(0x41 if is_buy else 0x42)  # 'A' for Buy, 'B' for Sell
        
        # Shares (4 bytes)
        packet.extend(quantity.to_bytes(4, byteorder='little'))
        
        # Stock (8 bytes) - Stock symbol padded with spaces
        stock_symbol = f"STOCK{stock_id:02d}"
        stock_bytes = stock_symbol.encode('ascii')
        stock_bytes = stock_bytes + b' ' * (8 - len(stock_bytes))
        packet.extend(stock_bytes)
        
        # Price (4 bytes) - Only using last 2 bytes as specified
        packet.extend(bytes([0, 0, price_int, price_frac]))
        
        return packet
    
    def create_cancel_order_packet(self, stock_id, order_id, quantity):
        # Create packet
        packet = bytearray()
        
        # Length (1 byte)
        packet.append(24)  # Fixed length for CANCEL_ORDER
        
        # Message Type (1 byte)
        packet.append(MSG_CANCEL_ORDER)
        
        # Stock Locate (2 bytes) - Little endian
        packet.extend(stock_id.to_bytes(2, byteorder='little'))
        
        # Tracking Number (2 bytes) - Random value
        packet.extend(random.randint(0, 65535).to_bytes(2, byteorder='little'))
        
        # Timestamp (6 bytes) - Nanoseconds since midnight
        now = datetime.now()
        midnight = now.replace(hour=0, minute=0, second=0, microsecond=0)
        nanoseconds = int((now - midnight).total_seconds() * 1_000