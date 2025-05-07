import random
import csv
import math
from collections import deque

def generate_realistic_market_data(number_of_stocks=4, rows_per_stock=1250):
    """
    Generate realistic market data for HFT simulation with more microstructure.
    
    Parameters:
    - number_of_stocks: Number of different stock IDs to generate
    - rows_per_stock: Number of ADD orders per stock
    
    Returns:
    - List of dictionaries representing market data rows
    """
    data = []
    order_books = {}  # To track active orders per stock
    order_prices = {}  # To track prices of orders for each stock
    last_best_prices = {}  # To track the best (lowest) price for each stock for buy orders
    has_order = {}  # To track if each stock has at least one order
    
    # Set different baseline prices for each stock
    baseline_prices = {
        0: 100,
        1: 50,
        2: 200,
        3: 80
    }
    
    # Initialize order tracking
    for i in range(number_of_stocks):
        order_books[i] = set()
        order_prices[i] = {}  # order_id -> price
        last_best_prices[i] = baseline_prices[i]
        has_order[i] = False
    
    global_order_id = 1
    
    # Pre-generate price paths with realistic microstructure
    price_paths = {}
    tick_sizes = {
        0: 0.01,  # 1 cent tick for stock 0
        1: 0.01,  # 1 cent tick for stock 1
        2: 0.01,  # 1 cent tick for stock 2
        3: 0.01   # 1 cent tick for stock 3
    }
    
    # Generate synthetic price paths with realistic microstructure
    for stock_id in range(number_of_stocks):
        base_price = baseline_prices[stock_id]
        tick = tick_sizes[stock_id]
        
        # Parameters for price path
        volatility = 0.003 * base_price  # Increased volatility for more price variation
        mean_reversion = 0.05  # Reduced mean reversion to allow more wandering
        price_path = []
        
        # Start with baseline price
        current_price = base_price
        
        # Generate price path with microstructure
        for _ in range(rows_per_stock * 3):  # Generate more points for smoother path
            # Random component
            random_component = random.normalvariate(0, 1) * volatility
            
            # Mean reversion component (weaker)
            reversion_component = mean_reversion * (base_price - current_price)
            
            # Jumps (more frequent but smaller)
            jump = 0
            if random.random() < 0.01:  # 1% chance of a jump
                jump = random.choice([-1, 1]) * random.uniform(0.01, 0.1) * base_price
            
            # Combine components
            price_change = random_component + reversion_component + jump
            
            # Update price
            current_price += price_change
            
            # Ensure price is positive and snap to tick size
            current_price = max(current_price, tick)
            current_price = round(current_price / tick) * tick
            
            # Store in path
            price_path.append(round(current_price, 2))
        
        price_paths[stock_id] = price_path
    
    # Function to get the best (lowest) price for buy orders in the order book
    def get_best_price(stock_id):
        if not order_prices[stock_id]:
            return None
        return min(order_prices[stock_id].values())
    
    # Use the generated price paths to create a mix of orders
    path_indices = {stock_id: 0 for stock_id in range(number_of_stocks)}
    
    for i in range(number_of_stocks * rows_per_stock):
        stock_id = i % number_of_stocks
        
        # Get next price from path
        path_index = path_indices[stock_id]
        if path_index < len(price_paths[stock_id]):
            target_price = price_paths[stock_id][path_index]
            path_indices[stock_id] += 1
        else:
            # If we run out of pre-generated prices, use the last one
            target_price = price_paths[stock_id][-1]
        
        # Decide whether to add or cancel based on current best price
        current_best = get_best_price(stock_id)
        
        # Add order logic
        if current_best is None or random.random() < 0.7:  # Higher chance to add orders
            # Generate a price near the target but with more variation
            # Use a wider range for price variation to create more diverse prices
            price_variation = random.uniform(-0.1, 0.1) * target_price
            new_price = max(round(target_price + price_variation, 2), 0.01)
            
            # Ensure we generate some orders with prices below current best
            # This is crucial for best price movement
            if current_best is not None and random.random() < 0.3:
                # Generate a price below current best (but not too far)
                max_discount = 0.02 * current_best  # Max 2% below current best
                discount = random.uniform(0.001, max_discount)
                new_price = max(round(current_best - discount, 2), 0.01)
            
            # Generate a realistic quantity
            base_quantity = int(10 + random.random() * 490)  # Between 10 and 500
            
            # Add the ADD order
            new_order_id = global_order_id
            global_order_id += 1
            order_books[stock_id].add(new_order_id)
            order_prices[stock_id][new_order_id] = new_price
            
            data.append({
                "type": "ADD",
                "stock_id": stock_id,
                "order_id": new_order_id,
                "is_buy": True,
                "price": new_price,
                "quantity": base_quantity
            })
            
            # Mark that this stock has at least one order now
            has_order[stock_id] = True
            
        # Cancel order logic - always cancel the highest price
        elif has_order[stock_id] and len(order_books[stock_id]) > 0:
            # Find the order with the highest price to cancel
            highest_price = max(order_prices[stock_id].values())
            # Find all orders with this price
            highest_price_orders = [oid for oid, price in order_prices[stock_id].items() 
                               if price == highest_price]
            
            # Select one of these orders to cancel
            if highest_price_orders:
                order_to_cancel = random.choice(highest_price_orders)
                order_books[stock_id].remove(order_to_cancel)
                del order_prices[stock_id][order_to_cancel]
                
                data.append({
                    "type": "CANCEL",
                    "stock_id": stock_id,
                    "order_id": order_to_cancel,
                    "is_buy": True,
                    "price": None,
                    "quantity": None
                })
    
    return data

def save_to_csv(data, filename):
    """
    Save the generated market data to a CSV file.
    
    Parameters:
    - data: List of dictionaries with market data
    - filename: Output CSV filename
    """
    fields = ["type", "stock_id", "order_id", "is_buy", "price", "quantity"]
    
    with open(filename, 'w', newline='') as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=fields)
        writer.writeheader()
        
        for row in data:
            # Convert None values to empty strings and booleans to 'true'/'false'
            formatted_row = {}
            for field in fields:
                value = row.get(field)
                if value is None:
                    formatted_row[field] = ""
                elif isinstance(value, bool):
                    formatted_row[field] = "true" if value else "false"
                else:
                    formatted_row[field] = value
            
            writer.writerow(formatted_row)
    
    print(f"Saved {len(data)} rows to {filename}")

def main():
    """
    Main function to generate and save market data.
    """
    print("Generating enhanced realistic market data...")
    market_data = generate_realistic_market_data(number_of_stocks=4, rows_per_stock=1250)
    
    # Analyze the data
    add_orders = [row for row in market_data if row["type"] == "ADD"]
    cancel_orders = [row for row in market_data if row["type"] == "CANCEL"]
    
    print(f"Generated {len(market_data)} total rows:")
    print(f"- ADD orders: {len(add_orders)}")
    print(f"- CANCEL orders: {len(cancel_orders)}")
    
    # Print price ranges for each stock
    for stock_id in range(4):
        stock_data = [row for row in add_orders if row["stock_id"] == stock_id]
        prices = [row["price"] for row in stock_data]
        if prices:
            print(f"Stock {stock_id} price range: {min(prices):.2f} to {max(prices):.2f}")
    
    # Save to CSV
    save_to_csv(market_data, "book_data_rand.csv")
    print("Data generation complete.")

if __name__ == "__main__":
    main()