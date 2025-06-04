# To improve timing with higher clock speeds for IP/UDP modules, the rx and tx FIFO are constrained to
# specific areas of the design in addition to the timing constraints placed on them in the cdc_fifo_signals.xdc
# file. This was needed because even with the timing constraints, the P&R tool would place cells in areas that
# would end up leading to net delays > 1ns, and lead to tiing failures.
# This was used when the input clock used to drive the system that interacts with teh ethernet MAC is greater
# than or equal to 200MHz.

create_pblock pblock_rx_fifo
add_cells_to_pblock [get_pblocks pblock_rx_fifo] [get_cells -quiet [list ethernet_mac/rx_fifo]]
resize_pblock [get_pblocks pblock_rx_fifo] -add {SLICE_X4Y70:SLICE_X13Y85}
resize_pblock [get_pblocks pblock_rx_fifo] -add {DSP48_X0Y28:DSP48_X0Y33}
resize_pblock [get_pblocks pblock_rx_fifo] -add {RAMB18_X0Y28:RAMB18_X0Y33}
resize_pblock [get_pblocks pblock_rx_fifo] -add {RAMB36_X0Y14:RAMB36_X0Y16}
create_pblock pblock_tx_fifo
add_cells_to_pblock [get_pblocks pblock_tx_fifo] [get_cells -quiet [list ethernet_mac/tx_fifo]]
resize_pblock [get_pblocks pblock_tx_fifo] -add {SLICE_X4Y53:SLICE_X13Y69}
resize_pblock [get_pblocks pblock_tx_fifo] -add {DSP48_X0Y22:DSP48_X0Y27}
resize_pblock [get_pblocks pblock_tx_fifo] -add {RAMB18_X0Y22:RAMB18_X0Y27}
resize_pblock [get_pblocks pblock_tx_fifo] -add {RAMB36_X0Y11:RAMB36_X0Y13}


