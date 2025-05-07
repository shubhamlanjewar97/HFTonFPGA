import tkinter as tk
from tkinter import ttk, filedialog, scrolledtext
import serial
import threading
import csv
import time
import queue
from datetime import datetime
import serial.tools.list_ports

# Import our modular components
from config_manager import load_config, save_config, create_default_config
from stock_book import StockBook
from packet_utils import create_add_order_packet, create_cancel_order_packet, parse_fpga_response_packet
from market_data_generator import generate_market_data
# Import the updated plotter 
# Note: Make sure to place the updated real_time_plotter.py in your project directory
from real_time_plotter import RealTimePlotter

# Ensure default configuration exists
create_default_config()

# Load configuration
CONFIG = load_config()

class ExchangeSimulator:
    def __init__(self, root):
        self.root = root
        self.root.title("HFT Exchange Simulator")
        self.root.geometry("1400x800")  # Increased width for better side-by-side display
        
        self.serial_port = None
        self.tx_thread = None
        self.rx_thread = None
        self.running = False
        self.stock_book = StockBook()
        self.next_order_id = 1
        self.packet_queue = queue.Queue()
        self.rx_queue = queue.Queue()
        self.orderbook_updating = True  # Flag to control order book updates
        
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

        # New row with checkboxes for new options
        self.buy_orders_only_var = tk.BooleanVar(value=CONFIG.get("buy_orders_only", False))
        ttk.Checkbutton(settings_frame, text="Buy Orders Only", 
                      variable=self.buy_orders_only_var).grid(row=1, column=0, columnspan=2, padx=5, pady=5, sticky="w")
        
        self.cancel_highest_price_var = tk.BooleanVar(value=CONFIG.get("cancel_highest_price", False))
        ttk.Checkbutton(settings_frame, text="Cancel Highest Price Order", 
                      variable=self.cancel_highest_price_var).grid(row=1, column=2, columnspan=2, padx=5, pady=5, sticky="w")
        
        # Action buttons
        action_frame = ttk.Frame(self.root)
        action_frame.pack(fill="x", padx=10, pady=5)
        
        ttk.Button(action_frame, text="Generate CSV", command=self.generate_csv).pack(side="left", padx=5, pady=5)
        ttk.Button(action_frame, text="Load CSV", command=self.load_csv).pack(side="left", padx=5, pady=5)
        ttk.Button(action_frame, text="Start Simulation", command=self.start_simulation).pack(side="left", padx=5, pady=5)
        ttk.Button(action_frame, text="Stop Simulation", command=self.stop_simulation).pack(side="left", padx=5, pady=5)
        ttk.Button(action_frame, text="Clear Plots", command=self.clear_plots).pack(side="left", padx=5, pady=5)
        ttk.Button(action_frame, text="Pause/Resume Order Book", command=self.toggle_orderbook_updates).pack(side="left", padx=5, pady=5)
        
        # Notebook for different views
        self.notebook = ttk.Notebook(self.root)
        self.notebook.pack(fill="both", expand=True, padx=10, pady=5)
        
        # Sent packets tab
        sent_tab = ttk.Frame(self.notebook)
        self.notebook.add(sent_tab, text="Sent Packets")
        
        self.sent_text = scrolledtext.ScrolledText(sent_tab)
        self.sent_text.pack(fill="both", expand=True)
        
        # Received packets tab
        received_tab = ttk.Frame(self.notebook)
        self.notebook.add(received_tab, text="Received Packets")
        
        self.received_text = scrolledtext.ScrolledText(received_tab)
        self.received_text.pack(fill="both", expand=True)
        
        # Order book tab
        orderbook_tab = ttk.Frame(self.notebook)
        self.notebook.add(orderbook_tab, text="Order Book")
        
        # Use a monospace font for the order book to ensure proper column alignment
        self.orderbook_text = scrolledtext.ScrolledText(orderbook_tab, font=("Courier", 10))
        self.orderbook_text.pack(fill="both", expand=True)
        
        # Real-time plots tab
        plots_tab = ttk.Frame(self.notebook)
        self.notebook.add(plots_tab, text="Real-time Plots")
        
        # Initialize the real-time plotter
        self.plotter = RealTimePlotter(plots_tab, max_points=100)
        
        # Status bar
        self.status_var = tk.StringVar(value="Ready")
        status_bar = ttk.Label(self.root, textvariable=self.status_var, relief="sunken", anchor="w")
        status_bar.pack(side="bottom", fill="x")
        
        # Set up periodic UI updates
        self.root.after(100, self.update_ui)
    
    def toggle_orderbook_updates(self):
        """Toggle the order book updates on/off."""
        self.orderbook_updating = not self.orderbook_updating
        if self.orderbook_updating:
            self.status_var.set("Order book updates resumed")
        else:
            self.status_var.set("Order book updates paused - You can now scroll freely")
    
    def clear_plots(self):
        """Clear all plots and reinitialize the plotter."""
        plots_tab = self.notebook.winfo_children()[3]  # Get the plots tab
        
        # First clear existing plots in the current plotter if it exists
        if hasattr(self, 'plotter'):
            self.plotter.clear_plots()
        
        # Then recreate the plotter
        for widget in plots_tab.winfo_children():
            widget.destroy()
        self.plotter = RealTimePlotter(plots_tab, max_points=100)
        self.status_var.set("Plots cleared")
    
    def save_config(self):
        # Update CONFIG with current values
        CONFIG["packet_delay"] = self.delay_var.get()
        CONFIG["num_packets"] = self.num_packets_var.get()
        CONFIG["cancel_probability"] = self.cancel_prob_var.get()
        CONFIG["buy_orders_only"] = self.buy_orders_only_var.get()
        CONFIG["cancel_highest_price"] = self.cancel_highest_price_var.get()
        
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
            
            # Update CONFIG with current settings
            CONFIG["cancel_probability"] = self.cancel_prob_var.get()
            CONFIG["buy_orders_only"] = self.buy_orders_only_var.get()
            CONFIG["cancel_highest_price"] = self.cancel_highest_price_var.get()
            
            packets = generate_market_data(num_packets, CONFIG)
            
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
                    # Handle potential empty or missing values
                    try:
                        packet = {
                            'type': row['type'],
                            'stock_id': int(row.get('stock_id', 0)),
                            'order_id': int(row.get('order_id', 0)),
                            'is_buy': str(row.get('is_buy', '')).lower() == 'true',
                            'price': float(row['price']) if row.get('price', '') != '' else None,
                            'quantity': int(row['quantity']) if row.get('quantity', '') != '' else None
                        }
                        packets.append(packet)
                    except (ValueError, KeyError) as e:
                        self.status_var.set(f"Warning: Could not parse row in CSV: {str(e)}")
                        continue
            
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
            # No packets loaded, generate them on the fly
            num_packets = self.num_packets_var.get()
            CONFIG["cancel_probability"] = self.cancel_prob_var.get()
            CONFIG["buy_orders_only"] = self.buy_orders_only_var.get()
            CONFIG["cancel_highest_price"] = self.cancel_highest_price_var.get()
            packets = generate_market_data(num_packets, CONFIG)
            
            for packet in packets:
                self.packet_queue.put(packet)
            
            self.status_var.set(f"Generated {num_packets} packets for simulation")
        
        # Start the transmitter thread
        self.running = True
        self.tx_thread = threading.Thread(target=self.send_packets)
        self.tx_thread.daemon = True
        self.tx_thread.start()
        
        self.status_var.set("Simulation started")
    
    def stop_simulation(self):
        self.running = False
        self.status_var.set("Simulation stopped")
    
    def get_highest_price_for_stock(self, stock_id):
        """
        Get the highest price in the order book for a specific stock.
        
        Parameters:
        - stock_id: Stock identifier
        
        Returns:
        - The highest price or None if no orders exist
        """
        # Get all orders for this stock
        buy_orders = self.stock_book.buy_orders.get(stock_id, [])
        
        # Return the highest price if buy orders exist
        if buy_orders:
            # Buy orders are sorted by price descending, so the first one has the highest price
            return buy_orders[0]["price"]
        
        return None
    
    def send_packets(self):
        delay = self.delay_var.get()
        self.sent_text.insert(tk.END, "Starting packet transmission\n")
        
        while self.running and not self.packet_queue.empty():
            packet_data = self.packet_queue.get()
            
            if packet_data['type'] == 'ADD':
                binary_packet = create_add_order_packet(
                    packet_data['stock_id'], 
                    packet_data['order_id'], 
                    packet_data['price'], 
                    packet_data['quantity'], 
                    packet_data['is_buy']
                )
            else:  # CANCEL
                binary_packet = create_cancel_order_packet(
                    packet_data['stock_id'], 
                    packet_data['order_id'], 
                    packet_data['quantity'] if packet_data['quantity'] is not None else 0
                )
            
            # Send the packet
            try:
                self.serial_port.write(binary_packet)
                
                # Update the packet queue display
                packet_str = f"\n[{datetime.now().strftime('%H:%M:%S.%f')[:-3]}] "
                packet_str += f"Sent {packet_data['type']} - Stock: {packet_data['stock_id']}, "
                packet_str += f"Order: {packet_data['order_id']}"
                
                if packet_data['type'] == 'ADD':
                    packet_str += f", {'Buy' if packet_data['is_buy'] else 'Sell'}"
                    if packet_data['price'] is not None:
                        packet_str += f", Price: {packet_data['price']:.2f}"
                    if packet_data['quantity'] is not None:
                        packet_str += f", Qty: {packet_data['quantity']}"
                
                packet_str += "\n"
                
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
                    
                    # Get the highest price in order book for this stock after adding
                    highest_price = self.get_highest_price_for_stock(packet_data['stock_id'])
                    
                    # Update the plotter with the highest price in the order book
                    if highest_price is not None:
                        self.plotter.add_highest_order_price(
                            packet_data['stock_id'],
                            highest_price
                        )
                        
                else:  # CANCEL
                    self.stock_book.remove_order(packet_data['order_id'])
                    
                    # Get the highest price in order book for this stock after cancellation
                    highest_price = self.get_highest_price_for_stock(packet_data['stock_id'])
                    
                    # Update the plotter with the highest price in the order book
                    if highest_price is not None:
                        self.plotter.add_highest_order_price(
                            packet_data['stock_id'],
                            highest_price
                        )
                
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

                    # Print the raw data in hex format
                    hex_data = ' '.join([f"{b:02x}" for b in data])
                    self.received_text.insert(tk.END, f"\n[{datetime.now().strftime('%H:%M:%S.%f')[:-3]}] RAW HEX: {hex_data}\n")
                    self.received_text.see(tk.END)

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
                        parsed_packet = parse_fpga_response_packet(packet)
                        if parsed_packet:
                            self.rx_queue.put({
                                'timestamp': datetime.now(),
                                'length': parsed_packet['length'],
                                'stock_id': parsed_packet['stock_id'],
                                'is_buy': parsed_packet['is_buy'],
                                'quantity': parsed_packet['quantity'],
                                'price': parsed_packet['price']
                            })
                
                time.sleep(0.01)  # Short delay to prevent CPU hogging
                
            except Exception as e:
                self.status_var.set(f"Receiver error: {str(e)}")
                break
    
    def update_ui(self):
        # Update received packets display
        while not self.rx_queue.empty():
            packet = self.rx_queue.get()
            
            try:
                packet_str = f"[{packet['timestamp'].strftime('%H:%M:%S.%f')[:-3]}] "
                packet_str += f"Received - Stock_id: {packet['stock_id']}, "
                packet_str += f"{'Buy' if packet['is_buy'] else 'Sell'}, "
                packet_str += f"Qty: {packet['quantity']} "
                packet_str += f"Price: {packet['price']:.2f},\n"
                
                self.received_text.insert(tk.END, packet_str)
                self.received_text.see(tk.END)
                
                # Update the real-time plot with the new received data point
                self.plotter.add_data_point(
                    packet['stock_id'],
                    packet['price'],
                    packet['quantity']
                )
            except (KeyError, ValueError, TypeError) as e:
                self.status_var.set(f"Warning: Error processing received packet: {str(e)}")
                continue
        
        # Update order book display only if not paused
        if self.orderbook_updating:
            self.update_orderbook_display()
        
        # Schedule the next update
        self.root.after(100, self.update_ui)
    
    def update_orderbook_display(self):
        # Clear the order book display
        self.orderbook_text.delete(1.0, tk.END)
        
        # Create a fixed-width format for consistent column sizing
        column_width = 30
        
        # Create headers for all stocks side by side
        header_row = ""
        separator_row = ""
        
        for stock_id in range(CONFIG["num_stocks"]):
            header = f"Stock {stock_id} Order Book"
            # Pad the header to the column width
            header_row += header.ljust(column_width)
            separator_row += "-" * column_width
        
        # Add the headers to the display
        self.orderbook_text.insert(tk.END, header_row + "\n")
        self.orderbook_text.insert(tk.END, separator_row + "\n\n")
        
        # Determine the maximum number of sell orders across all stocks
        max_sell_orders = 0
        max_buy_orders = 0
        for stock_id in range(CONFIG["num_stocks"]):
            sell_orders = self.stock_book.sell_orders.get(stock_id, [])
            buy_orders = self.stock_book.buy_orders.get(stock_id, [])
            max_sell_orders = max(max_sell_orders, len(sell_orders))
            max_buy_orders = max(max_buy_orders, len(buy_orders))
        
        # Display sell orders (highest to lowest for each stock, side by side)
        self.orderbook_text.insert(tk.END, "SELL ORDERS:\n")
        
        # For each row of sell orders across all stocks
        for i in range(max_sell_orders):
            row = ""
            for stock_id in range(CONFIG["num_stocks"]):
                sell_orders = sorted(self.stock_book.sell_orders.get(stock_id, []), 
                                   key=lambda x: x["price"])
                
                if i < len(sell_orders):
                    order = sell_orders[i]
                    cell = f"  #{order['order_id']}: {order['quantity']} @ ${order['price']:.2f}"
                else:
                    cell = "  "
                    
                row += cell.ljust(column_width)
                
            self.orderbook_text.insert(tk.END, row + "\n")
        
        # Add a separator between sell and buy orders
        self.orderbook_text.insert(tk.END, "\n")
        
        # Display buy orders (highest to lowest for each stock, side by side)
        self.orderbook_text.insert(tk.END, "BUY ORDERS:\n")
        
        # For each row of buy orders across all stocks
        for i in range(max_buy_orders):
            row = ""
            for stock_id in range(CONFIG["num_stocks"]):
                buy_orders = sorted(self.stock_book.buy_orders.get(stock_id, []), 
                                  key=lambda x: x["price"], reverse=True)
                
                if i < len(buy_orders):
                    order = buy_orders[i]
                    cell = f"  #{order['order_id']}: {order['quantity']} @ ${order['price']:.2f}"
                else:
                    cell = "  "
                    
                row += cell.ljust(column_width)
                
            self.orderbook_text.insert(tk.END, row + "\n")

# Main entry point
if __name__ == "__main__":
    root = tk.Tk()
    app = ExchangeSimulator(root)
    root.mainloop()