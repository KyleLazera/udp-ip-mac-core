# Low-Latency Network Stack Overview
This project is a low-latency network stack implemented on an FPGA, specifically targeting Layers 2, 3, and 4 of the OSI model. It is considered *low-latency* due to its design, which supports operation at clock speeds of up to **333 MHz** for both the IP and UDP stacks.

### Key Features
- **Low Latency Design**  
  - IP/UDP stack introduces only **2 clock cycles of latency per byte**.  
    - At **333 MHz**, this results in approximately **6 ns per byte**.  
  - Ethernet MAC (TX) adds **4 clock cycles of latency per byte**.  
    - At **125 MHz**, this equates to **32 ns per byte**.  
  - Ethernet MAC (RX) adds **7–8 clock cycles of latency per byte**.  
    - At **125 MHz**, this results in **56–64 ns per byte**.
  
- **Ethernet MAC**  
  - Supports data throughputs of up to **1 Gbps**.
  - Allows for last minute IP/UDP header injection.

- **IP Stack**  
  - Prepends and removes IP headers  
  - Computes the IP checksum

- **UDP Stack**  
  - Prepends and removes UDP headers  
  - Computes the UDP checksum

### Future Improvements
This project is still a work in progress and has several areas where enhancements are planned. As development continues, the following improvements are targeted to enhance overall functionality and performance:

1. **Add ARP support** to enable MAC address resolution for IP communication.  
2. **Reduce RX Ethernet latency** to further minimize end-to-end transmission delays.  
3. **Optimize the UDP/IP stack** to operate at clock speeds up to **350 MHz**.  
4. **Implement a TCP module** to interface with the IP layer (*stretch goal*).

### Design Overview

The diagram below illustrates the design and data flow of the network stack. Each OSI layer is implemented as a separate module, and adjacent layers communicate using AXI-Stream interfaces. These interfaces operate bidirectionally, enabling full-duplex communication throughout the stack.

![network stack Block Diagram drawio](https://github.com/user-attachments/assets/fb5a637b-5cee-4597-9964-0fd136d0910a)
