`ifndef _TX_MAC_ENV
`define _TX_MAC_ENV

`include "tx_mac_gen.sv"
`include "tx_mac_driver.sv"
`include "tax_mac_monitor.sv"
`include "tx_mac_scb.sv"

class tx_mac_env;
    //Instantiate each of the classes
    tx_mac_gen      gen;
    tx_mac_driver   drv;
    tx_mac_monitor  mon;
    tx_mac_scb      scb;
    //Init mailboxes and events
    mailbox drv_mbx, scb_mbx;
    event drv_done, scb_done;
    //Virtual Intf
    virtual tx_mac_if vif;
    //Tag for debugging
    string TAG = "Environment";
    
    //Constructor - Init all individual components
    function new(virtual tx_mac_if _vif);
        //Pass through virtual interface
        vif = _vif;
        //Init the mailboxes and events for the modules
        drv_mbx = new();
        scb_mbx = new();
        //Components
        gen = new(drv_mbx, drv_done, scb_done);
        drv = new(drv_mbx, drv_done);
        mon = new(scb_mbx);
        scb = new(scb_mbx, scb_done);
    endfunction : new
    
    task main();
    $display("[%s] Starting...", TAG);
    
    //Assign virtual interface
    drv.vif = vif;
    mon.vif = vif;
    
    //Fork each component 
    fork
        gen.main();
        drv.main();
        mon.main();
        scb.main();
    join_any
    
    endtask : main
    
endclass : tx_mac_env

`endif