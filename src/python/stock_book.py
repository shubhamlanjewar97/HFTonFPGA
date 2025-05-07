class StockBook:
    """
    Maintains a record of active orders for multiple stocks.
    
    This class keeps track of buy and sell orders for different stocks,
    allowing for efficient retrieval of the highest buy and lowest sell
    prices, and maintaining proper order book state.
    """
    
    def __init__(self):
        """Initialize an empty stock book."""
        self.orders = {}  # order_id -> order_details
        self.buy_orders = {}  # stock_id -> list of buy orders
        self.sell_orders = {}  # stock_id -> list of sell orders
    
    def add_order(self, order_id, stock_id, is_buy, price, quantity):
        """
        Add a new order to the book.
        
        Parameters:
        - order_id: Unique identifier for the order
        - stock_id: Identifier for the stock
        - is_buy: True for buy order, False for sell order
        - price: Order price
        - quantity: Order quantity
        """
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
        """
        Remove an order from the book.
        
        Parameters:
        - order_id: Identifier of the order to remove
        
        Returns:
        - True if the order was found and removed, False otherwise
        """
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
        """
        Get the highest buy order for a stock.
        
        Parameters:
        - stock_id: Identifier for the stock
        
        Returns:
        - The highest buy order or None if no buy orders exist
        """
        if stock_id in self.buy_orders and self.buy_orders[stock_id]:
            return self.buy_orders[stock_id][0]  # Already sorted
        return None
    
    def get_lowest_sell(self, stock_id):
        """
        Get the lowest sell order for a stock.
        
        Parameters:
        - stock_id: Identifier for the stock
        
        Returns:
        - The lowest sell order or None if no sell orders exist
        """
        if stock_id in self.sell_orders and self.sell_orders[stock_id]:
            return self.sell_orders[stock_id][0]  # Already sorted
        return None
    
    def get_order_count(self, stock_id):
        """
        Get the total number of orders for a stock.
        
        Parameters:
        - stock_id: Identifier for the stock
        
        Returns:
        - The total number of buy and sell orders for the stock
        """
        buy_count = len(self.buy_orders.get(stock_id, []))
        sell_count = len(self.sell_orders.get(stock_id, []))
        return buy_count + sell_count
    
    def get_max_orders_count(self, is_buy=True):
        """
        Get the maximum number of orders (buy or sell) across all stocks.
        
        Parameters:
        - is_buy: If True, count buy orders, otherwise count sell orders
        
        Returns:
        - The maximum count
        """
        orders_dict = self.buy_orders if is_buy else self.sell_orders
        if not orders_dict:
            return 0
        return max(len(orders) for orders in orders_dict.values()) if orders_dict else 0
    
    def get_all_orders_for_stock(self, stock_id):
        """
        Get all orders for a specific stock.
        
        Parameters:
        - stock_id: Identifier for the stock
        
        Returns:
        - Dictionary with 'buy' and 'sell' keys containing lists of orders
        """
        buy = self.buy_orders.get(stock_id, [])
        sell = self.sell_orders.get(stock_id, [])
        return {
            'buy': sorted(buy, key=lambda x: x["price"], reverse=True),
            'sell': sorted(sell, key=lambda x: x["price"])
        }
    
    def get_all_stocks(self):
        """
        Get a list of all stock IDs in the book.
        
        Returns:
        - List of unique stock IDs
        """
        stocks = set()
        for order in self.orders.values():
            stocks.add(order["stock_id"])
        return sorted(list(stocks))