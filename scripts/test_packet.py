from scapy.all import *  # Import everything
from scapy.all import IP, UDP
from scapy.all import wrpcap
from scapy.layers.l2 import Ether  # Explicitly import Ether

iface = "enxc8a362a81bc2"

# Message to repeat

base_message = "This is a testing packet of size 1500 bytes"

# Calculate how many times to repeat it to reach ~1492 bytes (Ethernet MTU - 8 byte header overhead)
repeat_count = 1492 // len(base_message)
payload = (base_message * repeat_count)[:1492]  # trim in case of rounding

# Build Ethernet packet
eth_packet = Ether(dst="ff:ff:ff:ff:ff:ff", type=0x0800)
ip_packet = IP(dst="10.0.0.0", src="127.0.0.1")
udp_packet = UDP(sport=1234, dport=5678)
payload = Raw(load="This is a test IP packet!")
packets = eth_packet / ip_packet / udp_packet / payload

# Send the packet 
sendpfast(packets, iface=iface, file_cache=True, loop=10000)
print("Complete Script")