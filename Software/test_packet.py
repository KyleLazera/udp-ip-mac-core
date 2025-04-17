from scapy.all import *  # Import everything
from scapy.all import wrpcap
from scapy.layers.l2 import Ether  # Explicitly import Ether

iface = "enxc8a362a81bc2"

# Message to repeat

base_message = "This is a testing packet of size 1500 bytes"

# Calculate how many times to repeat it to reach ~1492 bytes (Ethernet MTU - 8 byte header overhead)
repeat_count = 1492 // len(base_message)
payload = (base_message * repeat_count)[:1492]  # trim in case of rounding

# Build Ethernet packet
packet = Ether(dst="ff:ff:ff:ff:ff:ff", type=0x1234) / payload.encode()
#packet = Ether(dst="ff:ff:ff:ff:ff:ff", type=0x1234) / "This is a sample packet for testing."
packets = packet*1000000

# Send the packet 
#sendp(packets, iface=iface, verbose=False)

sendpfast(packets, iface=iface, file_cache=True, loop=1, verbose=True)
print("Complete Script")