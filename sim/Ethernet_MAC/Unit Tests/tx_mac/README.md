## Verification Plan

The TX MAC was verified using UVM to test the functionality of the module, specifically whether the data passed into the module would be correctly encapsulated into an Ethernet packet and transmitted to the RGMII interface. This was achieved using a reference model, which implemented a software version of the TX MAC. 

The reference model received raw data from the driver, pre-pended the preamble sequence, added padding if necessary, calculated, and appended the CRC value. The resulting reference packet was then sent to the scoreboard, which also received the data from the monitor. The monitor's data was compared with the reference model to ensure the Ethernet packet was created correctly. 

Additionally, SystemVerilog assertions were employed to ensure specific signals were raised only under the correct conditions.

### Test Cases

1. **1 Gbps Test:**  
   This test simulates operation at 1 Gbps throughput, where a new byte is transmitted every clock cycle (double data rate).

2. **10/100 Mbps Test:**  
   This test simulates operation at 10/100 Mbps throughput, which uses single data rate transmission.

![Screenshot 2024-12-26 085946](https://github.com/user-attachments/assets/c0d53f78-1bc4-4c98-b59c-489fdfd541f8)
