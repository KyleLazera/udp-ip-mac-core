## Table of Contents
- [Overview](#overview)
  - [Limitations & Future Improvements](#limitations-and-future-improvements)
- [Top Level Design](#top-level-design)
  - [RGMII Interface](#rgmii-interface)
  - [Input Delay](#introducing-delay-for-receiver)
  - [Asynch FIFO](#asynch-fifo)
    - [Double Flop Synchronizers](#double-flop-synchronizers)
  - [CRC32 Computation](#crc32-computation)
    - [Sarwates Algorithm](#sarwates-algorithm)

# Overview
This project is a custom Tri-mode Ethernet MAC (TEMAC) core that interfaces with RGMII, designed in Verilog and tested on the Nexys Video (Artix-7 200T) FPGA.
Supported Features
  - Tri-Speed Operation – Supports 10/100 Mbps and 1 Gbps transmission speeds.
  - Packet Integrity Verification – Drops packets with invalid CRCs or corrupted data.
  - Full-Duplex Communication – Enables simultaneous transmission and reception.
  - Ethernet Frame Encapsulation – Formats raw data according to the IEEE 802.3 Ethernet standard.
  - De-Encapsulation – Extracts payload data before passing it to the user.
  - Custom Auto-Negotiation Logic – Determines link speed dynamically.
  - Hardware CRC Calculation – Computes and appends CRC checksums on outgoing packets.
  - AXI-Stream Interface – Provides a high-speed, standardized interface to external modules.
  - FIFO Buffering – Implements internal FIFO queues to buffer incoming and outgoing packets, reducing latency.

### Limitations And Future Improvements
  - No MDIO Module – Does not currently implement MDIO (Management Data Input/Output) for PHY configuration.
  - No Pause Frame/Flow Control Support
  - No Jumbo Frame Support – Limited to standard Ethernet frame sizes (≤1518 bytes).
  - Mid-Transaction Link speed changes are not permitted.
## Top Level Design
![ethernet mac toplevel drawio](https://github.com/user-attachments/assets/84526e21-ca9c-4880-a2b3-7d130f369dc7)
The Ethernet MAC top level architecture is displayed above. In the image above, the arrow colors indicate different clock domains. The description for each color is as follows:
  - Green: 100MHz Source Clock Domain 
  - Blue: 125MHz tx_clk domain 
  - Orange: This is the rx clock domain and can range between 2.5MHz (10mbps), 25MHz (100mbps) or 125MHz  (1gbps)
  - Purple: This is the output tx clock domain and  can range between 2.5MHz (10mbps), 25MHz (100mbps) or 125MHz  (1gbps)
It should also be noted that each unit is connected via AXI-Stream along with any additional signals needed.

## RGMII Interface
The RGMII interface is a 12 wire interface that reduces the total number of wires required for operation when compared to MII or GMII. It does this by reducing the total number of data wires to 4 and utilizing double data rate for 1gbps. RGMII supports 10/100 mbps and 1gbps all through the same interface. The image below displays the RGMII interface with the Artix-7 FPGA on the Nexys Video development board.
![Screenshot 2025-03-15 142555](https://github.com/user-attachments/assets/23814329-503a-47e2-84d9-fb43fbc31047) 

When operating at 10/100mbps, RGMII transmits and receives data on a rising edge of the clock. Because it utilizes 4 lines of data, it takes 2 full clock cycles to form a byte of data. 

![rgmii_tx_timing](https://github.com/user-attachments/assets/aa7950fa-0838-4958-9d1f-54cc1101d38b)

When operationg at 1gbps however, the RGMII utilizes Double Data rate mode. It transmits a new nibble of data on every rising and falling edge as depicted below.

![rgmii_rx_timing](https://github.com/user-attachments/assets/e4b12e20-35a1-4516-8b2c-e28428ca4816)

Additionally, as can be seen by the image and is specified by the RGMII standard, data must be transmitted in-phase with the sending clock. It is then up to the receiver to implement a 90 degree phase shift between the receiving clock and the received data. This is necessary to ensure that the data is being correctly sampled and is not violating any timing constraints. The image below depicts what this phase shift does.

![Screenshot 2025-03-15 143634](https://github.com/user-attachments/assets/86ce95ea-de53-4be7-ad6d-ffeb2a676fea)

## Introducing Delay for Receiver

An important aspect with RGMII is ensuring that the received clock and data have a 90 degree phase shift (at double data rate), allowing each rising and falling edge to be centered to the data (like in the image above). There are many ways that this delay can be implemented,such as via PCB traces external to the FPGA, in the receiving PHY or in the FPGA itself. In this project, the delays were implemented in the MAC using a series of IDELAY2 primitives only on the rxd lines. These delays lead to approximately a 90 degree phase shift (2ns delay) of the data lines only, therefore, the clock and data lines were aligned as expected. The basic architecture of how this was implemented is shown below.

![Screenshot 2025-03-18 200215](https://github.com/user-attachments/assets/192b20ea-14ef-4f33-8948-5015a2b8d55e)

As can be seen in the image, each data line is driven first through an IDELAY2 and then into an IDDR. The IDDR is necessary specifically for 1gbps operation, however, to also sample at SDR (single data rate) for 10/100mbps there was extra logic implemented in the rgmii_phy_if module. The received clock is simply passed through a BUFIO and drives the IDDR’s. Additionally, not shown here, the received clock is also passed through a BUFG and then fed to the RX MAC as the main clock.

## Asynch FIFO

There are 2 asynchronous FIFO’s used in the design. These FIFO’s serve 2 purposes: To buffer packets so the receiving side can read out full packets and to cross data from the system clock domain (100MHz) into the Ethernet MAC domain. The Asynch FIFO was designed based on the paper “Simulation and Synthesis Techniques for Asynchronous FIFO Design” by Sunburst Design, with a few changes such as implementing logic to drop bad packets and adding almost full/empty flags. The block diagram of the FIFO is displayed below.

![Asynch FIFO drawio](https://github.com/user-attachments/assets/333ce1c6-dc18-4d97-a9fe-4dc4e75f6a69)

### Double Flop Synchronizers:

The double flop synchronizers are used to pass the grey coded read and write pointers between clock domains (read and write) to avoid the risk of metastability. Grey code is used because, rather than binary, there is only a 1 bit difference between each incremental value which can help avoid the possibility of a glitch occurring when passing the data across the clock domain. To see more information on this, see the “Simulation and Synthesis Techniques for Asynchronous FIFO Design.” It should be noted that these double flop synchronizers are specifically targeted by timing constraints. More specifically, they are more tightly constrained specifically on the input flip flop to ensure there is sufficient time for the data to settle before the setup time occurs. The first FF in the synchronizer is constrained to a max delay of 1.8ns, meaning data must propagate and settle within this 1.8ns.

### CRC32 Computation:

CRC32 plays a critical role in both the transmission and reception of Ethernet frames, ensuring data integrity and reliability. There are multiple ways to implement the CRC32 algorithm, ranging from serial to parallel approaches. 
Serial Implementation
A serial CRC32 implementation processes data one bit at a time by shifting each bit through a 32-bit register while applying XOR operations based on the CRC polynomial. Each incoming bit affects specific register positions, ensuring that the final CRC value accurately represents the entire data stream. While this method is simple to implement, it introduces a significant bottleneck: it cannot achieve the required 1 Gbps throughput. At 1 Gbps, the system must process 8 bits per clock cycle at a 125 MHz clock frequency, which a serial implementation cannot support. To overcome this limitation, various parallelized CRC32 implementations take advantage of the linearity property of CRC:
CRC(A ⊕ B) = CRC(A )⊕ CRC(B)
This property allows CRC computations to be broken into smaller parts and processed in parallel, enabling high-speed operation. For this project, I implemented Sarwate’s Algorithm, which efficiently computes the CRC32 value at the required throughput. By precomputing CRC values for all possible 8-bit inputs and storing them in a lookup table, this method allows the system to process one byte per clock cycle with minimal hardware complexity, ensuring optimal performance for 1 Gbps Ethernet communication.

### Sarwates Algorithm

Sarwate’s algorithm relies on precomputed CRC values, making it highly efficient for high-speed applications. My goal was to process one byte per clock cycle at 125 MHz to achieve a 1 Gbps throughput. To accomplish this, I precomputed CRC values for all possible 8-bit inputs and stored them in a lookup table (LUT) that is 32 bits wide and 256 entries deep. This can be easily implemented using a Block RAM (BRAM). The precomputed CRC values are generated in software and loaded into the LUT upon FPGA initialization. This approach allows each received byte to index the LUT and update the CRC with minimal additional logic, making the implementation highly efficient.
I selected this method over a fully combinational implementation, which calculates the CRC update using multiple XOR operations for each bit of the 32-bit CRC. While a combinational approach can also achieve a one-cycle latency per byte, it would introduce significant fan-out due to the extensive XOR network. This could lead to increased resource utilization and routing congestion, negatively impacting the design.

