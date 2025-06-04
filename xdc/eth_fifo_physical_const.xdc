# To improve timing with higher clock speeds for IP/UDP modules, the rx and tx FIFO are constrained to
# specific areas of the design in addition to the timing constraints placed on them in the cdc_fifo_signals.xdc
# file. This was needed because even with the timing constraints, the P&R tool would place cells in areas that
# would end up leading to net delays > 1ns, and lead to tiing failures.
# This was used when the input clock used to drive the system that interacts with teh ethernet MAC is greater
# than or equal to 200MHz.

# Create a PBlock for the RX FIFO
#create_pblock pblock_rx_fifo
#add_cells_to_pblock [get_pblocks pblock_rx_fifo] [get_cells -quiet [list ethernet_mac/rx_fifo]]
#resize_pblock [get_pblocks pblock_rx_fifo] -add {SLICE_X6Y60:SLICE_X11Y74}
#resize_pblock [get_pblocks pblock_rx_fifo] -add {RAMB18_X0Y24:RAMB18_X0Y29}
#resize_pblock [get_pblocks pblock_rx_fifo] -add {RAMB36_X0Y12:RAMB36_X0Y14}
#
## Create a PBlock for the TX FIFO
#create_pblock pblock_tx_fifo
#add_cells_to_pblock [get_pblocks pblock_tx_fifo] [get_cells -quiet [list ethernet_mac/tx_fifo]]
#resize_pblock [get_pblocks pblock_tx_fifo] -add {SLICE_X6Y54:SLICE_X11Y59}
#resize_pblock [get_pblocks pblock_tx_fifo] -add {RAMB18_X0Y22:RAMB18_X0Y23}
#resize_pblock [get_pblocks pblock_tx_fifo] -add {RAMB36_X0Y11:RAMB36_X0Y11}


