## Table of Contents
- [Overview](#overview)
  - [Key Features](#key-features)
  - [Limitations & Future Improvements](#limitations-and-future-improvements)
  - [Design Overview](#design-overview)
- [Ethernet MAC Design](#top-level-design)
  - [Signals Description](#signals-description)
  - [RGMII Interface](#rgmii-interface)
  - [Input Delay](#introducing-delay-for-receiver)
  - [Double Flop Synchronizers](#double-flop-synchronizers)
  - [CRC32 Computation](#crc32-computation)
    - [Sarwates Algorithm](#sarwates-algorithm)

# Overview
This project is a low-latency network stack implemented on an FPGA, specifically targeting Layers 2, 3, and 4 of the OSI model. The stack includes a custom Tri-mode Ethernet MAC (TEMAC) with RGMII interface and supports full IP/UDP protocol functionality. It is designed for high-speed communication with support for up to 1 Gbps Ethernet and has optimizations to reduce latency. The IP/UDP stack operates at clock speeds up to **333 MHz**, enabling high-throughput, low-latency data handling.

### Key Features
- **Low Latency UDP/IP Stack** 
The IP/UDP stack was implemented with a focus on minimizing buffering and reducing end-to-end latency. While maintaining full protocol compliance, the design includes optimizations to reduce the number of cycles a packet must spend traversing the stack.
  - Introduces only **2 clock cycles of latency per byte**.
  - Closed timing at **333MHz** leading to **6ns latency per byte**.
- **Ethernet MAC Performance**
The Ethernet MAC was not designed with the sole purpose of being low-latency, however, does have optimization that improve its overall performance. In addition, it still maintains sligghtly better latency measurements when compared to other commercial 1Gbit Ethernet MAC IP's.
  - **Tx Path** has 4 clock cycles of latency per byte (~32ns)
  - **Rx Path** has 7 clock cycles of latency per bytes (~56ns)
  - The MAC supports customized **IP/UDP header & Checksum Injection** to improve overall path latency.  

### Limitations and Future Improvements
Although the main goal of the project has been achieved, there are still several improvements and additions that could enhance its overall functionality:

1. **Add ARP support** to enable MAC address resolution for IP communication.    
2. **Optimize the UDP/IP stack** to operate at clock speeds up to **350 MHz**.  
3. **Implement a TCP module** to interface with the IP layer (*stretch goal*).


### Design Overview

The diagram below illustrates the design and data flow of the network stack. Each OSI layer is implemented as a separate module, and adjacent layers communicate using AXI-Stream interfaces. These interfaces operate bidirectionally, enabling full-duplex communication throughout the stack. There are
additional signals present in between modules not shown in this diagram that are used to achieve tighter integration and optimzations.

![network stack Block Diagram drawio](https://github.com/user-attachments/assets/fb5a637b-5cee-4597-9964-0fd136d0910a)

## Ethernet MAC Design
![ethernet mac toplevel drawio](https://github.com/user-attachments/assets/84526e21-ca9c-4880-a2b3-7d130f369dc7)
The ethernet MAC was a major learning curve and took a significant amount of time to implement in this project, as it exposed me to a variety of
different areas such as floorplanning, Clock domain crossing technqiues, timing closure and more. he Ethernet MAC top level architecture is displayed above. In the image above, the arrow colors indicate different clock domains. The description for each color is as follows:
  - Green: 100MHz Source Clock Domain 
  - Blue: 125MHz tx_clk domain 
  - Orange: This is the rx clock domain and can range between 2.5MHz (10mbps), 25MHz (100mbps) or 125MHz  (1gbps)
  - Purple: This is the output tx clock domain and  can range between 2.5MHz (10mbps), 25MHz (100mbps) or 125MHz  (1gbps)
It should also be noted that each unit is connected via AXI-Stream along with any additional signals needed.

### Signals Description 

The Ethernet MAC receives data in the format of AXI-Stream packets and follows the AXI-Stream protocol. The AXI-Stream interface is a unidirectional, high-speed data transfer protocol commonly used for streaming data between modules. It uses a simple handshake mechanism involving `tvalid` and `tready` signals:

- `tvalid`: Asserted by the sender to indicate valid data is present on the `tdata` lines.
- `tready`: Asserted by the receiver to indicate it is ready to accept data.

Data is transferred only when both`tvalid` and `tready` are high on teh same clock cycle. The `tlast` signal is used to indicate teh final data word in a packet, marking the end of a transmission.
Data Transferred via AXI-Stream to the Ethernet MAC module should be in the following format: 

------------------------------------------------------------------------------
|   Destination MAC Address |  Source MAC Address  | Ethernet Type | Payload |
------------------------------------------------------------------------------

The MAC is responsible for prepending the preamble sequence, adding padding if necessary, and calculating and appending the CRC32 checksum to complete the Ethernet frame.

| Signal              | Direction | Description                                                                                      |
|---------------------|-----------|--------------------------------------------------------------------------------------------------|
| i_clk               | Input     | System clock used to read data from RX and TX FIFOs (100 MHz).                                   |
| clk_125             | Input     | 125 MHz clock used to drive the TX MAC and RGMII interface.                                     |
| clk90_125           | Input     | 125 MHz clock with a 90° phase shift, used to transmit RGMII signals and apply skew between clock and data lines. |
| i_reset_n           | Input     | Active-low synchronous reset.                                                                   |
| rgmii_phy_rxc       | Input     | Received Ethernet clock signal from PHY (can be 2.5 MHz, 25 MHz, or 125 MHz depending on link speed). |
| rgmii_phy_rxd       | Input     | Data received from PHY. Operates in DDR (1 Gbps) or SDR (10/100 Mbps) modes based on link speed. |
| rgmii_phy_rxctl     | Input     | Control signal from PHY.                                                               |
| rgmii_phy_txc       | Output    | Transmit clock signal to PHY (2.5 MHz, 25 MHz, or 125 MHz depending on link speed).             |
| rgmii_phy_txd       | Output    | Transmit Ethernet data to PHY. Operates in DDR (1 Gbps) or SDR (10/100 Mbps) mode.              |
| rgmii_phy_txctl     | Output    | Transmit control signal to PHY.                                                        |
| s_tx_axis_tdata     | Input     | AXI-Stream TX data to be transmitted via Ethernet.                                               |
| s_tx_axis_tvalid    | Input     | AXI-Stream signal indicating that `tdata` contains valid data.                                   |
| s_tx_axis_tlast     | Input     | AXI-Stream signal indicating the final byte of the current packet.                              |
| m_tx_axis_trdy      | Output    | Indicates the TX FIFO is ready to accept more data (not full).                                  |
| m_rx_axis_tdata     | Output    | AXI-Stream RX data received from the RX FIFO.                                                    |
| m_rx_axis_tvalid    | Output    | Indicates that the RX FIFO has valid data available & that teh data on `tdata` line is valid.                                             |
| m_rx_axis_tlast     | Output    | Indicates the final byte of the current RX packet.                                               |
| s_rx_axis_trdy      | Input     | Read enable signal for the RX FIFO; indicates the slave is ready to receive data.               |


### RGMII Interface
The RGMII interface is a 12 wire interface that reduces the total number of wires required for operation when compared to MII or GMII. It does this by reducing the total number of data wires to 4 and utilizing double data rate for 1gbps. RGMII supports 10/100 mbps and 1gbps all through the same interface. The image below displays the RGMII interface with the Artix-7 FPGA on the Nexys Video development board.
![Screenshot 2025-03-15 142555](https://github.com/user-attachments/assets/23814329-503a-47e2-84d9-fb43fbc31047) 

When operating at 10/100mbps, RGMII transmits and receives data on a rising edge of the clock. Because it utilizes 4 lines of data, it takes 2 full clock cycles to form a byte of data. 

![rgmii_tx_timing](https://github.com/user-attachments/assets/aa7950fa-0838-4958-9d1f-54cc1101d38b)

When operationg at 1gbps however, the RGMII utilizes Double Data rate mode. It transmits a new nibble of data on every rising and falling edge as depicted below.

![rgmii_rx_timing](https://github.com/user-attachments/assets/e4b12e20-35a1-4516-8b2c-e28428ca4816)

Additionally, as can be seen by the image and is specified by the RGMII standard, data must be transmitted in-phase with the sending clock. It is then up to the receiver to implement a 90 degree phase shift between the receiving clock and the received data. This is necessary to ensure that the data is being correctly sampled and is not violating any timing constraints. The image below depicts what this phase shift does.

![Screenshot 2025-03-15 143634](https://github.com/user-attachments/assets/86ce95ea-de53-4be7-ad6d-ffeb2a676fea)

### Introducing Delay for Receiver

An important aspect with RGMII is ensuring that the received clock and data have a 90 degree phase shift (at double data rate), allowing each rising and falling edge to be centered to the data (like in the image above). There are many ways that this delay can be implemented,such as via PCB traces external to the FPGA, in the receiving PHY or in the FPGA itself. In this project, the delays were implemented in the MAC using a series of IDELAY2 primitives only on the rxd lines. These delays lead to approximately a 90 degree phase shift (2ns delay) of the data lines only, therefore, the clock and data lines were aligned as expected. The basic architecture of how this was implemented is shown below.

![Screenshot 2025-03-18 200215](https://github.com/user-attachments/assets/192b20ea-14ef-4f33-8948-5015a2b8d55e)

As can be seen in the image, each data line is driven first through an IDELAY2 and then into an IDDR. The IDDR is necessary specifically for 1gbps operation, however, to also sample at SDR (single data rate) for 10/100mbps there was extra logic implemented in the rgmii_phy_if module. The received clock is simply passed through a BUFIO and drives the IDDR’s. Additionally, not shown here, the received clock is also passed through a BUFG and then fed to the RX MAC as the main clock.

### CRC32 Computation:

CRC32 plays a critical role in both the transmission and reception of Ethernet frames, ensuring data integrity and reliability. There are multiple ways to implement the CRC32 algorithm, ranging from serial to parallel approaches. 
Serial Implementation
A serial CRC32 implementation processes data one bit at a time by shifting each bit through a 32-bit register while applying XOR operations based on the CRC polynomial. Each incoming bit affects specific register positions, ensuring that the final CRC value accurately represents the entire data stream. While this method is simple to implement, it introduces a significant bottleneck: it cannot achieve the required 1 Gbps throughput. At 1 Gbps, the system must process 8 bits per clock cycle at a 125 MHz clock frequency, which a serial implementation cannot support. To overcome this limitation, various parallelized CRC32 implementations take advantage of the linearity property of CRC:
CRC(A ⊕ B) = CRC(A )⊕ CRC(B)
This property allows CRC computations to be broken into smaller parts and processed in parallel, enabling high-speed operation. For this project, I implemented Sarwate’s Algorithm, which efficiently computes the CRC32 value at the required throughput. By precomputing CRC values for all possible 8-bit inputs and storing them in a lookup table, this method allows the system to process one byte per clock cycle with minimal hardware complexity, ensuring optimal performance for 1 Gbps Ethernet communication.

#### Sarwates Algorithm

Sarwate’s algorithm relies on precomputed CRC values, making it highly efficient for high-speed applications. My goal was to process one byte per clock cycle at 125 MHz to achieve a 1 Gbps throughput. To accomplish this, I precomputed CRC values for all possible 8-bit inputs and stored them in a lookup table (LUT) that is 32 bits wide and 256 entries deep. This can be easily implemented using a Block RAM (BRAM). The precomputed CRC values are generated in software and loaded into the LUT upon FPGA initialization. This approach allows each received byte to index the LUT and update the CRC with minimal additional logic, making the implementation highly efficient.
I selected this method over a fully combinational implementation, which calculates the CRC update using multiple XOR operations for each bit of the 32-bit CRC. While a combinational approach can also achieve a one-cycle latency per byte, it would introduce significant fan-out due to the extensive XOR network. This could lead to increased resource utilization and routing congestion, negatively impacting the design.


