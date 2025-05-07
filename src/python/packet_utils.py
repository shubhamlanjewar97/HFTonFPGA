import random
from datetime import datetime

# Message types
MSG_ADD_ORDER = 0x82
MSG_CANCEL_ORDER = 0xA1

def create_add_order_packet(stock_id, order_id, price, quantity, is_buy):
    """
    Create an ADD_ORDER packet according to the specification.
    
    Parameters:
    - stock_id: Stock identifier (1-255)
    - order_id: Order reference number (1-255)
    - price: Order price (0-255.xx)
    - quantity: Order quantity (1-255)
    - is_buy: True for buy, False for sell
    
    Returns:
    - Bytearray containing the formatted packet
    """
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
    #stock_id = stock_id - 1
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
    packet.extend(bytes([price_frac,price_int , 6, 6]))
    
    return packet

def create_cancel_order_packet(stock_id, order_id, quantity):
    """
    Create a CANCEL_ORDER packet according to the specification.
    
    Parameters:
    - stock_id: Stock identifier (1-255)
    - order_id: Order reference number (1-255)
    - quantity: Order quantity to cancel (1-255)
    
    Returns:
    - Bytearray containing the formatted packet
    """
    # Create packet
    packet = bytearray()
    
    # Length (1 byte)
    packet.append(24)  # Fixed length for CANCEL_ORDER
    
    # Message Type (1 byte)
    packet.append(MSG_CANCEL_ORDER)
    
    # Stock Locate (2 bytes) - Little endian
    #stock_id = stock_id - 1
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
'''
def parse_fpga_response_packet(packet):
    """
    Parse a response packet from the FPGA.
    
    The expected format is:
    - Length (1 byte)
    - Stock Locate/ID (1 byte)
    - Buy/Sell Indicator (1 byte): 01 for Buy, 00 for Sell
    - Shares/Quantity (2 bytes)
    - Price (2 bytes): 8-bit integer part, 8-bit fractional part
    
    Parameters:
    - packet: Bytearray containing the packet data
    
    Returns:
    - Dictionary with parsed packet data or None if parsing fails
    """
    if len(packet) < 6:
        return None
    
    try:
        length = packet[0]
        stock_id = packet[1]
        is_buy = packet[2] == 1  # 1 for buy, 0 for sell

        quantity = int.from_bytes(packet[3:5], byteorder='little')
        
        # Price is split into integer and fraction parts
        price_int = packet[5]
        price_frac = packet[6] / 256.0 if len(packet) > 6 else 0
        price = price_int + price_frac
        
        return {
            'length': length,
            'stock_id': stock_id,
            'is_buy': is_buy,
            'quantity': quantity,
            'price': price
        }
    
    except Exception as e:
        print(f"Error parsing FPGA packet: {str(e)}")
        return None
'''

def parse_fpga_response_packet(packet):
    """
    Parse a response packet from the FPGA.
    
    The expected format is:
    - Length (1 byte)
    - Stock Locate/ID (1 byte)
    - Buy/Sell Indicator (1 byte): 01 for Buy, 00 for Sell
    - Shares/Quantity (2 bytes)
    - Price (2 bytes): 8-bit integer part, 8-bit fractional part
    
    Parameters:
    - packet: Bytearray containing the packet data
    
    Returns:
    - Dictionary with parsed packet data or None if parsing fails
    """
    if len(packet) < 6:
        return None
    
    try:
        # Print original packet for debugging
        #print(f"Original packet: {' '.join(f'{b:02x}' for b in packet)}")
        
        # First byte stays the same
        length = packet[0]
        
        # Reorder the remaining bytes based on the specific pattern
        if len(packet) > 1:
            # Create corrected packet starting with the length byte
            corrected_packet = bytearray([length])
            
            # Manual reordering based on observed pattern:
            # From: 07 02 04 06 01 03 05
            # To:   07 01 02 03 04 05 06
            
            # The correct positions in the corrected packet:
            # packet[4] goes to position 1 (corrected_packet[1])
            # packet[1] goes to position 2 (corrected_packet[2])
            # packet[5] goes to position 3 (corrected_packet[3])
            # packet[2] goes to position 4 (corrected_packet[4])
            # packet[6] goes to position 5 (corrected_packet[5])
            # packet[3] goes to position 6 (corrected_packet[6])
            
            if len(packet) > 4: corrected_packet.append(packet[4])  # Stock ID
            if len(packet) > 1: corrected_packet.append(packet[1])  # Buy/Sell
            if len(packet) > 5: corrected_packet.append(packet[5])  # Quantity (first byte)
            if len(packet) > 2: corrected_packet.append(packet[2])  # Quantity (second byte)
            if len(packet) > 6: corrected_packet.append(packet[6])  # Price (int part)
            if len(packet) > 3: corrected_packet.append(packet[3])  # Price (frac part)
            
            # Print corrected packet for debugging
            #print(f"Corrected packet: {' '.join(f'{b:02x}' for b in corrected_packet)}")
            
            # Use the corrected packet for parsing
            packet = packet
        
        stock_id = packet[1]
        is_buy = packet[2] == 1  # 1 for buy, 0 for sell

        #quantity = int.from_bytes(packet[3:5], byteorder='little')
        #quantity = int.from_bytes(packet[3:5], byteorder='big')


        # Price is split into integer and fraction parts
        quantity_int = packet[3]
        quantity_frac = packet[4] / 256.0 if len(packet) > 6 else 0
        quantity = quantity_int + quantity_frac

        
        # Price is split into integer and fraction parts
        price_int = packet[5]
        price_frac = packet[6] / 256.0 if len(packet) > 6 else 0
        price = price_int + price_frac
        
        return {
            'length': length,
            'stock_id': stock_id,
            'is_buy': is_buy,
            'quantity': quantity,
            'price': price
        }
    
    except Exception as e:
        print(f"Error parsing FPGA packet: {str(e)}")
        return None

def packet_to_hex_string(packet):
    """
    Convert a packet to a readable hex string.
    
    Parameters:
    - packet: Bytearray containing the packet data
    
    Returns:
    - String with hex representation of the packet
    """
    return ' '.join([f'{b:02X}' for b in packet])