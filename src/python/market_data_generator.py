import random

def generate_market_data(num_packets, config):
    """
    Generate a series of market data packets (ADD and CANCEL orders).
    
    Parameters:
    - num_packets: Number of packets to generate
    - config: Configuration dictionary with settings like prices and quantities
    
    Returns:
    - List of dictionaries representing the generated packets
    """
    packets = []
    # Initialize active orders with stock_ids starting from 0 instead of 1
    active_orders = {stock_id: [] for stock_id in range(config.get("stock_id_start", 0), 
                                                       config.get("stock_id_start", 0) + config["num_stocks"])}
    next_order_id = 1
    
    # Check for buy_orders_only flag in config
    buy_orders_only = config.get("buy_orders_only", False)
    
    # Check for cancel_highest_price flag in config
    cancel_highest_price = config.get("cancel_highest_price", False)
    
    for _ in range(num_packets):
        # Decide whether to add or cancel an order
        if (random.random() < config["cancel_probability"] and 
            any(len(orders) > 0 for orders in active_orders.values())):
            # Find a stock with active orders to cancel
            valid_stocks = [stock_id for stock_id, orders in active_orders.items() if orders]
            if not valid_stocks:
                # No valid stocks to cancel orders from, create a new order instead
                stock_id = random.randint(config.get("stock_id_start", 0), 
                                         config.get("stock_id_start", 0) + config["num_stocks"] - 1)
                
                # Set is_buy based on buy_orders_only flag
                is_buy = True if buy_orders_only else random.random() < 0.5
                
                price = round(random.uniform(config["price_min"], config["price_max"]), 2)
                quantity = random.randint(config["quantity_min"], config["quantity_max"])
                
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
                if len(active_orders[stock_id]) < config["order_book_depth"]:
                    active_orders[stock_id].append({
                        'order_id': next_order_id,
                        'is_buy': is_buy,
                        'price': price,
                        'quantity': quantity
                    })
                
                next_order_id += 1
                if next_order_id > 200:
                    next_order_id = 1  # Reset order ID to stay within 8-bit range
                
                continue
            
            stock_id = random.choice(valid_stocks)
            
            # Choose an order to cancel
            orders = active_orders[stock_id]
            
            if cancel_highest_price:
                # For cancel_highest_price mode, select only buy orders if buy_orders_only is True
                filtered_orders = [o for o in orders if not buy_orders_only or o['is_buy']]
                
                if not filtered_orders:
                    # Skip if no matching orders
                    continue
                
                # Select the highest price order
                order = max(filtered_orders, key=lambda x: x['price'])
            else:
                # Original behavior: prioritize highest buy or lowest sell
                buy_orders = sorted([o for o in orders if o['is_buy']], 
                                   key=lambda x: x['price'], reverse=True)
                sell_orders = sorted([o for o in orders if not o['is_buy']], 
                                    key=lambda x: x['price'])
                
                if buy_orders_only:
                    # Only select from buy orders if buy_orders_only is True
                    if not buy_orders:
                        continue
                    order = buy_orders[0]
                else:
                    # Original mixed behavior
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
            stock_id = random.randint(config.get("stock_id_start", 0), 
                                     config.get("stock_id_start", 0) + config["num_stocks"] - 1)
            
            # Set is_buy based on buy_orders_only flag
            is_buy = True if buy_orders_only else random.random() < 0.5
            
            price = round(random.uniform(config["price_min"], config["price_max"]), 2)
            quantity = random.randint(config["quantity_min"], config["quantity_max"])
            
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
            if len(active_orders[stock_id]) < config["order_book_depth"]:
                active_orders[stock_id].append({
                    'order_id': next_order_id,
                    'is_buy': is_buy,
                    'price': price,
                    'quantity': quantity
                })
            
            next_order_id += 1
            if next_order_id > 200:
                next_order_id = 1  # Reset order ID to stay within 8-bit range
    
    return packets

def generate_realistic_price_movement(start_price, volatility=0.01, trend=0.0):
    """
    Generate a realistic price movement using a random walk with drift.
    
    Parameters:
    - start_price: Starting price
    - volatility: Price volatility (standard deviation)
    - trend: Price trend (drift)
    
    Returns:
    - New price
    """
    # Random component (volatility)
    random_change = random.normalvariate(0, volatility)
    
    # Trend component
    trend_change = trend
    
    # Combine components
    price_change = start_price * (random_change + trend_change)
    new_price = start_price + price_change
    
    # Ensure price doesn't go negative
    if new_price <= 0:
        new_price = start_price * 0.01  # Small positive value
    
    return round(new_price, 2)

def generate_correlated_prices(num_stocks, num_steps, base_prices=None, correlation=0.7, volatility=0.01):
    """
    Generate correlated price movements for multiple stocks.
    
    Parameters:
    - num_stocks: Number of stocks
    - num_steps: Number of time steps
    - base_prices: List of starting prices for each stock (defaults to random values)
    - correlation: Correlation between stocks (0-1)
    - volatility: Price volatility (standard deviation)
    
    Returns:
    - List of price paths for each stock
    """
    if base_prices is None:
        base_prices = [random.uniform(90, 110) for _ in range(num_stocks)]
    
    price_paths = [[] for _ in range(num_stocks)]
    
    for s in range(num_stocks):
        price_paths[s].append(base_prices[s])
    
    for step in range(1, num_steps):
        # Generate market-wide change (common factor)
        market_change = random.normalvariate(0, volatility)
        
        for s in range(num_stocks):
            current_price = price_paths[s][-1]
            
            # Individual stock change
            stock_change = random.normalvariate(0, volatility)
            
            # Combine market and individual changes based on correlation
            combined_change = (correlation * market_change + (1 - correlation) * stock_change)
            price_change = current_price * combined_change
            
            # Apply change
            new_price = current_price + price_change
            
            # Ensure price doesn't go negative
            if new_price <= 0:
                new_price = current_price * 0.01  # Small positive value
            
            price_paths[s].append(round(new_price, 2))
    
    return price_paths