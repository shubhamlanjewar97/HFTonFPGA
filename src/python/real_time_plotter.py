import tkinter as tk
from tkinter import ttk
import matplotlib.pyplot as plt
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg
from matplotlib.figure import Figure
import matplotlib.animation as animation
from collections import deque
import time

class RealTimePlotter:
    def __init__(self, parent, max_points=100):
        """
        Initialize the real-time plotter.
        
        Parameters:
        - parent: Tkinter parent widget
        - max_points: Maximum number of points to show in the plots
        """
        self.parent = parent
        self.max_points = max_points
        
        # Data structures for received data
        self.stock_data = {}  # stock_id -> {'time': list, 'price': list, 'quantity': list}
        
        # Data structures for highest value in order book per stock
        self.highest_order_data = {}  # stock_id -> {'time': list, 'price': list}
        
        self.figures = {}  # stock_id -> {'price': Figure, 'quantity': Figure}
        self.canvases = {}  # stock_id -> {'price': FigureCanvasTkAgg, 'quantity': FigureCanvasTkAgg}
        self.start_time = None  # Will be set when first data is received
        self.plotting_active = False  # Flag to indicate if plotting has started
        self.initialized_stocks = set()  # Keep track of which stocks have been initialized
        
        # Create notebook for multiple plots
        self.notebook = ttk.Notebook(parent)
        self.notebook.pack(fill="both", expand=True)
        
        # Tabs for each stock and plot type
        self.tabs = {}  # stock_id -> {'price': Frame, 'quantity': Frame}
    
    def initialize_stock(self, stock_id):
        """
        Initialize data structures and plots for a new stock.
        
        Parameters:
        - stock_id: Stock identifier
        """
        print(f"Initializing stock {stock_id}, existing tabs: {list(self.tabs.keys())}")
        
        # Check if this stock has already been initialized
        if stock_id in self.initialized_stocks:
            print(f"Stock {stock_id} already initialized, skipping")
            return
            
        self.initialized_stocks.add(stock_id)
        
        # Create data structures for both received and highest order data
        self.stock_data[stock_id] = {
            'time': [],
            'price': [],
            'quantity': []
        }
        
        self.highest_order_data[stock_id] = {
            'time': [],
            'price': []
        }
        
        # Initialize dictionaries for this stock
        if stock_id not in self.tabs:
            self.tabs[stock_id] = {}
        if stock_id not in self.figures:
            self.figures[stock_id] = {}
        if stock_id not in self.canvases:
            self.canvases[stock_id] = {}
        
        # Create price tab and plot
        if 'price' not in self.tabs[stock_id]:
            self.tabs[stock_id]['price'] = ttk.Frame(self.notebook)
            self.notebook.add(self.tabs[stock_id]['price'], text=f"Stock {stock_id} - Price")
            
            # Create price figure
            price_fig = Figure(figsize=(10, 6), dpi=100)
            self.figures[stock_id]['price'] = price_fig
            
            # Price plot
            price_ax = price_fig.add_subplot(111)  # Single plot takes up entire figure
            price_ax.set_title(f"Stock {stock_id} - Price")
            price_ax.set_xlabel("Time (s)")
            price_ax.set_ylabel("Price")
            
            # Create two separate lines: blue for received data, red for highest order price
            price_ax.plot([], [], 'b-', label='Received')
            price_ax.plot([], [], 'r-', label='Highest Order')
            price_ax.legend()
            
            price_fig.tight_layout()
            
            # Create price canvas
            price_canvas = FigureCanvasTkAgg(price_fig, master=self.tabs[stock_id]['price'])
            price_canvas.draw()
            price_canvas.get_tk_widget().pack(fill=tk.BOTH, expand=True)
            self.canvases[stock_id]['price'] = price_canvas
        
        # Create quantity tab and plot
        if 'quantity' not in self.tabs[stock_id]:
            self.tabs[stock_id]['quantity'] = ttk.Frame(self.notebook)
            self.notebook.add(self.tabs[stock_id]['quantity'], text=f"Stock {stock_id} - Quantity")
            
            # Create quantity figure
            qty_fig = Figure(figsize=(10, 6), dpi=100)
            self.figures[stock_id]['quantity'] = qty_fig
            
            # Quantity plot
            qty_ax = qty_fig.add_subplot(111)  # Single plot takes up entire figure
            qty_ax.set_title(f"Stock {stock_id} - Quantity")
            qty_ax.set_xlabel("Time (s)")
            qty_ax.set_ylabel("Quantity")
            
            # Create only one line for received data
            qty_ax.plot([], [], 'g-', label='Received')
            qty_ax.legend()
            
            qty_fig.tight_layout()
            
            # Create quantity canvas
            qty_canvas = FigureCanvasTkAgg(qty_fig, master=self.tabs[stock_id]['quantity'])
            qty_canvas.draw()
            qty_canvas.get_tk_widget().pack(fill=tk.BOTH, expand=True)
            self.canvases[stock_id]['quantity'] = qty_canvas
    
    def add_data_point(self, stock_id, price, quantity):
        """
        Add a new received data point for a stock.
        
        Parameters:
        - stock_id: Stock identifier
        - price: Latest price
        - quantity: Latest quantity
        """
        # Initialize time tracking if this is the first data point
        if not self.plotting_active:
            self.start_time = time.time()
            self.plotting_active = True
        
        # Initialize stock if needed
        if stock_id not in self.initialized_stocks:
            self.initialize_stock(stock_id)
        
        # Add data points for received data
        current_time = time.time() - self.start_time
        self.stock_data[stock_id]['time'].append(current_time)
        self.stock_data[stock_id]['price'].append(price)
        self.stock_data[stock_id]['quantity'].append(quantity)
        
        # Update plots
        self.update_plot(stock_id)
    
    def add_highest_order_price(self, stock_id, highest_price):
        """
        Add a new highest order price data point for a stock.
        
        Parameters:
        - stock_id: Stock identifier
        - highest_price: Highest price in the order book for this stock
        """
        # Only add data points if plotting has been activated (received data has arrived)
        if not self.plotting_active:
            return
        
        # Initialize stock if needed
        if stock_id not in self.initialized_stocks:
            self.initialize_stock(stock_id)
        
        # Add data points for highest order price
        current_time = time.time() - self.start_time
        self.highest_order_data[stock_id]['time'].append(current_time)
        self.highest_order_data[stock_id]['price'].append(highest_price)
        
        # Update plots
        self.update_plot(stock_id)
    
    def update_plot(self, stock_id):
        """
        Update the plots for a specific stock.
        
        Parameters:
        - stock_id: Stock identifier
        """
        # Make sure the figure exists for this stock_id
        if stock_id not in self.initialized_stocks:
            self.initialize_stock(stock_id)
        
        # Get received data
        rec_times = list(self.stock_data[stock_id]['time'])
        rec_prices = list(self.stock_data[stock_id]['price'])
        rec_quantities = list(self.stock_data[stock_id]['quantity'])
        
        # Get highest order data
        highest_times = list(self.highest_order_data.get(stock_id, {'time': []})['time'])
        highest_prices = list(self.highest_order_data.get(stock_id, {'price': []})['price'])
        
        if not rec_times and not highest_times:
            return
        
        # Update price plot
        price_fig = self.figures[stock_id]['price']
        price_ax = price_fig.axes[0]
        price_ax.clear()
        price_ax.set_title(f"Stock {stock_id} - Price")
        price_ax.set_xlabel("Time (s)")
        price_ax.set_ylabel("Price")
        
        # Plot both received and highest order data for price
        if rec_times:
            price_ax.plot(rec_times, rec_prices, 'b-', label='Received')
        if highest_times:
            price_ax.plot(highest_times, highest_prices, 'r-', label='Highest Order')
        
        price_ax.legend()
        
        # Set y-limits with some padding, considering both datasets
        all_prices = rec_prices + highest_prices
        if all_prices:
            min_price = min(all_prices) * 0.95
            max_price = max(all_prices) * 1.05
            price_ax.set_ylim(min_price, max_price)
        
        # Redraw price plot
        price_fig.tight_layout()
        self.canvases[stock_id]['price'].draw()
        
        # Update quantity plot
        qty_fig = self.figures[stock_id]['quantity']
        qty_ax = qty_fig.axes[0]
        qty_ax.clear()
        qty_ax.set_title(f"Stock {stock_id} - Quantity")
        qty_ax.set_xlabel("Time (s)")
        qty_ax.set_ylabel("Quantity")
        
        # Plot only received data for quantity
        if rec_times:
            qty_ax.plot(rec_times, rec_quantities, 'g-', label='Received')
        
        qty_ax.legend()
        
        # Set y-limits with some padding, only considering received quantities
        if rec_quantities:
            min_qty = min(rec_quantities) * 0.95
            max_qty = max(rec_quantities) * 1.05
            qty_ax.set_ylim(min_qty, max_qty)
        
        # Redraw quantity plot
        qty_fig.tight_layout()
        self.canvases[stock_id]['quantity'].draw()
    
    def update_all_plots(self):
        """Update all plots."""
        all_stock_ids = self.initialized_stocks
        for stock_id in all_stock_ids:
            self.update_plot(stock_id)
    
    def clear_plots(self):
        """Clear all plot data."""
        self.stock_data = {}
        self.highest_order_data = {}
        self.plotting_active = False
        self.start_time = None
        
        # Clear all existing plots
        for stock_id in list(self.figures.keys()):
            for plot_type in ['price', 'quantity']:
                if stock_id in self.figures and plot_type in self.figures[stock_id]:
                    ax = self.figures[stock_id][plot_type].axes[0]
                    ax.clear()
                    ax.set_title(f"Stock {stock_id} - {plot_type.capitalize()}")
                    ax.set_xlabel("Time (s)")
                    ax.set_ylabel(plot_type.capitalize())
                    
                    if plot_type == 'price':
                        # For price plots, include both lines
                        ax.plot([], [], 'b-', label='Received')
                        ax.plot([], [], 'r-', label='Highest Order')
                    else:
                        # For quantity plots, only include received line
                        ax.plot([], [], 'g-', label='Received')
                    
                    ax.legend()
                    self.figures[stock_id][plot_type].tight_layout()
                    self.canvases[stock_id][plot_type].draw()
        
        # Reset the initialized stocks set
        self.initialized_stocks = set()