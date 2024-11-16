///////////////////////////////////////////////////////////
// 
// Module:  memDP
// Purpose: Generic dual-ported memory
//          Optionally add multiple read ports
// 
///////////////////////////////////////////////////////////

module memDP
  #(parameter WIDTH      = 32,
    parameter DEPTH      = `PHYS_REG_SZ_R10K,
    parameter READ_PORTS = 1,
    parameter WRITE_PORTS = 1,
    parameter BYPASS_EN  = 0   // 0: Read data will update at positive edge
                               // 1: Read data will update combinationally if
                               //    write to same address
   )
   (// ------------------------------------------------------------ //
    //                      Clock and Reset                         //
    // ------------------------------------------------------------ //
    input                                              clock,
    input                                              reset,

    // ------------------------------------------------------------ //
    //                      Read interface                          //
    // ------------------------------------------------------------ //
    input               [READ_PORTS-1:0]                     re,     // Read enable
    input  PHYS_REG_IDX [READ_PORTS-1:0]                     raddr,  // Read address
    output DATA         [READ_PORTS-1:0]                     rdata,  // Read data

    // ------------------------------------------------------------ //
    //                      Write interface                         //
    // ------------------------------------------------------------ //
    input                   [WRITE_PORTS-1:0]                    we,     // Write enable
    input PHYS_REG_IDX      [WRITE_PORTS-1:0]                    waddr,  // Write address
    input DATA              [WRITE_PORTS-1:0]                    wdata   // Write data
   );

DATA [DEPTH-1:0]  memData;
logic found_bypass;

///////////////////////////////////////////////////////////////////
////////////////////////// Read Logic /////////////////////////////
///////////////////////////////////////////////////////////////////

always_comb begin
    for (int i = 0; i < READ_PORTS; i++) begin
        if (BYPASS_EN != 0) begin : bypass_path
            if (re[i]) begin
                found_bypass = 0;
                for (int j = 0; j < WRITE_PORTS; j++) begin
                    if (we[j] && (raddr[i] == waddr[j])) begin
                        rdata[i] = wdata[j];
                        found_bypass = 1;
                        break;
                    end
                end
                if (!found_bypass) begin
                    rdata[i] = memData[raddr[i]];
                end
            end else begin
                rdata[i] = '0;
            end
        end else begin : non_bypass_path
            rdata[i] = re[i] ? memData[raddr[i]] : '0;
        end
    end
end

 
///////////////////////////////////////////////////////////////////
////////////////////////// Write Logic ////////////////////////////
///////////////////////////////////////////////////////////////////

always_ff @(posedge clock) begin
    if (reset) begin
        memData <= '0;
    end else begin
        for (int j = 0; j < WRITE_PORTS; j++) begin
            if (we[j]) begin
                memData[waddr[j]] <= wdata[j];
            end
        end
    end
end

///////////////////////////////////////////////////////////////////
////////////////////////// Assertions /////////////////////////////
///////////////////////////////////////////////////////////////////

`ifdef GEN_ASSERT
    logic [DEPTH-1:0] valid;
    
    // Track which entries are valid
    always_ff @(posedge clock) begin
        for (int i = 0; i < WRITE_PORTS; i++) begin
            if      (reset) valid        <= '0;
            else if (we[i])    valid[waddr[i]] <= 1'b1; 
        end      
    end

    // ---------- Verify Write Interface ---------- 
    generate
        for (int i = 0; i < WRITE_PORTS; i++) begin
            clocking cb_read @(posedge clock);
                property waddr_valid;
                    we[i] |-> waddr[i] < DEPTH;
                endproperty
            endclocking

            validWaddr:    assert property(cb_read.waddr_valid);
        end
    endgenerate
    
    // ---------- Verify Read Interface ---------- 
    generate
        for (i = 0; i < READ_PORTS; i++) begin
            clocking cb_write @(posedge clock);
                property raddr_valid;
                    re[i] |-> raddr[i] < DEPTH;
                endproperty

                property read_valid_data;
                    re[i] |-> valid[raddr[i]];
                endproperty
            endclocking

            validRaddr:    assert property(cb_write.raddr_valid);
            validRdData:   assert property(cb_write.read_valid_data);
        end
    endgenerate
`endif

endmodule