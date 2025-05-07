import os
import configparser

# Default configuration settings
DEFAULT_CONFIG = {
    "baud_rate": 115200,
    "packet_delay": 0.1,  # seconds between packets
    "num_packets": 1500,  # number of packets to generate
    "num_stocks": 4,      # number of different stocks
    "order_book_depth": 256,  # maximum orders per stock
    "price_min": 50.0,    # minimum price
    "price_max": 100.0,   # maximum price
    "quantity_min": 1,    # minimum quantity
    "quantity_max": 255,  # maximum quantity
    "cancel_probability": 0.3,  # probability of generating a cancel order
    "buy_orders_only": False,  # if True, generate only buy orders
    "cancel_highest_price": False,  # if True, always cancel the highest price order
}

def load_config(config_file='config.ini'):
    """
    Load configuration from the config file.
    
    Parameters:
    - config_file: Path to the configuration file
    
    Returns:
    - Dictionary containing the configuration settings
    """
    config = DEFAULT_CONFIG.copy()
    
    if os.path.exists(config_file):
        parser = configparser.ConfigParser()
        parser.read(config_file)
        if 'Settings' in parser:
            settings = parser['Settings']
            for key in config:
                if key in settings:
                    # Convert value to appropriate type
                    if isinstance(config[key], int):
                        #config[key] = parser.getint('Settings', key)
                        try:
                            config[key] = parser.getint('Settings', key)
                        except ValueError:
                            # Handle boolean values that might be stored as strings
                            if settings[key].lower() == 'false':
                                config[key] = False
                            elif settings[key].lower() == 'true':
                                config[key] = True
                            else:
                                # Keep the original string value
                                config[key] = settings[key]
                    elif isinstance(config[key], float):
                        config[key] = parser.getfloat('Settings', key)
                    elif isinstance(config[key], bool):
                        # Handle boolean values by converting the string to a boolean
                        value = settings[key].lower()
                        config[key] = value == 'true' or value == '1'
                    else:
                        config[key] = settings[key]
    
    return config

def save_config(config, config_file='config.ini'):
    """
    Save configuration to the config file.
    
    Parameters:
    - config: Dictionary containing the configuration settings
    - config_file: Path to the configuration file
    """
    parser = configparser.ConfigParser()
    parser['Settings'] = {str(k): str(v) for k, v in config.items()}
    with open(config_file, 'w') as f:
        parser.write(f)

def create_default_config(config_file='config.ini'):
    """
    Create a default configuration file if it doesn't exist.
    
    Parameters:
    - config_file: Path to the configuration file
    """
    if not os.path.exists(config_file):
        save_config(DEFAULT_CONFIG, config_file)