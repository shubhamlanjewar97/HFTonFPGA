# FPGA-Based High-Frequency Trading System

## Overview
This repository contains the implementation of an FPGA-based High-Frequency Trading (HFT) system designed and developed as a course project for Digital System Design with FPGAs (E3-231) at the Indian Institute of Science, Bangalore. The system demonstrates how FPGAs can be leveraged for ultra-low latency trading applications, achieving microsecond-level response times.

## Team Members
- Andavarapu Rakesh (rakesha@iisc.ac.in)
- Shubham Lanjewar (shubhaml@iisc.ac.in)
- Alamuru Pavan Kumar Reddy (kpavan@iisc.ac.in)
- Jaideep M (jaideepm@iisc.ac.in)

Guided by: Prof. Debayan Das

## Key Features
- Complete end-to-end HFT system with UART communication, market data parsing, order book management, and trading logic
- Support for NASDAQ ITCH protocol message parsing
- Efficient order book implementation for multiple stocks
- Multiple trading strategies with varying complexity
- Python-based exchange simulator for testing
- Ultra-low latency (approximately 3.2 μs per order)
- Throughput of 400 orders per second

## System Architecture
The system consists of the following key components:

1. **UART Communication Module**: Handles serial communication with the market simulator
2. **Parser Module**: Decodes NASDAQ ITCH protocol messages and extracts relevant fields
3. **Order Book Module**: Maintains the current market state for multiple stocks
4. **Trading Logic Module**: Implements multiple trading strategies to make buy/sell decisions
5. **Deparser Module**: Formats trading decisions into messages for transmission
6. **Python-Based Exchange Simulator**: Simulates market conditions for testing

## Target Specifications
- **Target Platform**: Basys3 (Artix-7 35T FPGA)
- **Target Orders/Second**: 400 orders/second
- **Message Format**: NASDAQ ITCH and Custom format
- **Message Types**: ADD / EXECUTE messages
- **UART Baud Rate**: 115200 bps
- **Processing Latency**: ≈ 3 μs per order

## Implemented Trading Strategies
1. **Equal-Weight Allocation**: Divides available capital equally among all stocks
2. **Momentum-Based (Moving Average)**: Uses historical price data to make trading decisions
3. **Minimum Variance Portfolio (MVP)**: Aims to minimize overall portfolio risk (simulation only)

## Hardware Implementation
### Resource Utilization (Basys3 FPGA)
| Resource | Used | Utilization (%) |
|----------|------|----------------|
| LUTs     | 5,440 | 26% |
| LUTRAM   | 366  | 4%  |
| Flip-Flops| 8,159 | 20% |
| BRAM     | 3    | 6%  |
| IO       | 4    | 4%  |

### Performance Metrics
| Metric | Value |
|--------|-------|
| Fmax   | 104 MHz |
| Throughput | 400 orders/sec |
| Latency (avg) | 3.2 μs |
| Power Consumption | 0.135 W |
| UART Baud Rate | 115200 bps |

## Repository Structure
```
├── src/
│   ├── hdl/
│   │   ├── uart/             # UART RX and TX modules
│   │   ├── parser/           # NASDAQ ITCH protocol parser
│   │   ├── order_book/       # Order book implementation
│   │   ├── trading_logic/    # Trading strategies implementation
│   │   ├── deparser/         # Message formatting for transmission
│   │   └── top.v             # Top-level design
│   ├── testbench/            # Testbenches for verification
│   └── constraints/          # Timing and pin constraints
├── python/
│   └── market_simulator/     # Python-based exchange simulator
├── docs/
│   ├── presentation/         # Project presentation
│   └── report/               # Detailed project report
└── scripts/                  # Utility scripts
```

## Getting Started
### Prerequisites
- Vivado Design Suite (2019.2 or later)
- Basys3 FPGA board
- Python 3.7+ with the following packages:
  - PySerial
  - NumPy
  - Matplotlib
  - tkinter

### Building the Project
1. Clone this repository
```
git clone https://github.com/shubhamlanjewar97/HFTonFPGA.git
cd HFTonFPGA
```

2. Open the project in Vivado
```
vivado -open project/hft_fpga.xpr
```

3. Run synthesis, implementation, and generate bitstream

4. Program the Basys3 FPGA board

### Running the Market Simulator
1. Navigate to the Python simulator directory
```
cd python/market_simulator
```

2. Run the simulator
```
python market_simulator.py
```

3. Configure the simulator settings and connect to the FPGA board

## Future Work
1. Ethernet Interface: Full network stack development including Network Layer
2. Buy/Sell Support: Add capability to handle both buy and sell orders
3. NSE/BSE Formats: Support additional exchange data formats
4. More Message Types: Handle cancellations, modifications, and other actions
5. More Stock IDs: Scale system to track additional securities simultaneously
6. Advanced Trading Strategies: Implement various algorithmic strategies including complete MVP
7. Reduced Latency: Further optimize critical paths in hardware design
8. Adaptive Strategies: Add AI-based adaptive strategy adjustments


## License
[MIT License](LICENSE)

## References
1. NASDAQ, "NASDAQ TotalView-ITCH 5.0 Specification," Technical Document, 2020.
2. Kahssay, N., Kahssay, E., & Wang, Z. (2019). "An HFT (High Frequency Trading) Accelerator," IEEE Transactions on FPGA Implementation.
3. Leber, C., Geib, B., & Litz, H. (2011). "High frequency trading acceleration using FPGAs," In 2011 21st International Conference on Field Programmable Logic and Applications (pp. 317-322). IEEE.
4. Xilinx Inc., "Artix-7 FPGA Family Data Sheet," DS181 (v1.10), 2019.
5. Digilent Inc., "Basys 3 FPGA Board Reference Manual," 2019.
6. Jain, S. (2025). "High Frequency Trading: A Cutting-Edge Application of FPGA," IEEE Talk on HFT.
