## Verification Plan

The asynchronous FIFO verification is implemented using UVM (Universal Verification Methodology) along with SystemVerilog assertions to monitor the **full**, **empty**, **almost full**, and **almost empty** flags. The UVM testbench architecture for the FIFO is depicted below.

![UVM Asynchronous FIFO Verification](https://github.com/user-attachments/assets/11e97a05-d995-4c39-8846-422ab5515029)

### UVM Architecture
- **Write Agent**: Handles data transmission into the FIFO, toggles the write enable signal, and monitors the **full** and **almost full** flags.
- **Read Agent**: Toggles the read enable signal, monitors the output data, and observes the **empty** and **almost empty** flags.
- **Reference Model**: A SystemVerilog queue that mimics the FIFO's behavior, serving as an intermediary between the scoreboard and the write agent. It stores data written by the write agent and compares it with the data read by the read agent using the scoreboard to validate correctness.

### Test Cases
The verification includes five key scenarios:
1. **Read Only**  
2. **Write Only**  
3. **Simultaneous Read and Write**  
4. **Write Until Full and Continue Writing**  
5. **Read Until Empty and Continue Reading**  

#### Test Case Descriptions
- **Test Case 0**:  
  Simulates simultaneous read and write operations. Write and read enable signals are toggled with a 70% probability, allowing randomized iterations of read/write operations.

- **Test Case 1**:  
  Covers independent read and write operations. Data is first written into the FIFO, followed by a separate phase of reading data.

- **Test Case 2**:  
  Tests boundary conditions:
  - Writing data until the FIFO is full and continuing to write.  
  - Reading data until the FIFO is empty and continuing to read.  

