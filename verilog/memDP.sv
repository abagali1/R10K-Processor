///////////////////////////////////////////////////////////
// 
// Module:  memDP
// Purpose: Generic dual-ported memory
//          Optionally add multiple read ports
// 
///////////////////////////////////////////////////////////

module memDP
  #(parameter WIDTH      = 32,
    parameter DEPTH      = 32,
    parameter PORTS      = 1,
    parameter BYPASS_EN  = 0   // 0: Read data will update at positive edge
                               // 1: Read data will update combinationally if
                               //    write to same address
   )
   (// ------------------------------------------------------------ //
    //                      Clock and Reset                         //
    // ------------------------------------------------------------ //
    input                                            clock,
    input                                            reset,

    // ------------------------------------------------------------ //
    //                      Read interface                          //
    // ------------------------------------------------------------ //
    input        [PORTS-1:0]                        re,     // Read enable
    input        [PORTS-1:0][$clog2(DEPTH)-1:0]     raddr,  // Read address
    output logic [PORTS-1:0][WIDTH        -1:0]     rdata,  // Read data

    // ------------------------------------------------------------ //
    //                      Write interface                         //
    // ------------------------------------------------------------ //
    input        [PORTS-1:0]                        we,     // Write enable
    input        [PORTS-1:0][$clog2(DEPTH)-1:0]     waddr,  // Write address
    input        [PORTS-1:0][WIDTH        -1:0]     wdata,  // Write data
   );

logic [DEPTH-1:0][WIDTH-1:0]  memData;
genvar i, j;

///////////////////////////////////////////////////////////////////
////////////////////////// Read Logic /////////////////////////////
///////////////////////////////////////////////////////////////////

generate
    for (i = 0; i < PORTS; i++) begin
        always_comb begin
            if (BYPASS_EN != 0) begin : bypass_path
                if (re[i]) begin
                    rdata[i] = memData[raddr[i]];
                    for (j = 0; j < PORTS; j++) begin
                        if (we[j] && (raddr[i] == waddr[j]))
                            rdata[i] = wdata[j];
                    end     
                end else begin
                    rdata[i] = '0;
                end
            end else begin : non_bypass_path
                rdata[i] = re[i] ? memData[raddr[i]] : '0;
            end
        end
    end
endgenerate
 
///////////////////////////////////////////////////////////////////
////////////////////////// Write Logic ////////////////////////////
///////////////////////////////////////////////////////////////////

always_ff @(posedge clock) begin
    if (reset) begin
        memData        <= '0;
    end else if (we) begin
        for (j = 0; j < PORTS; j++) begin
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
        if      (reset) valid        <= '0;
        else if (we)    valid[waddr] <= 1'b1;       
    end

    // ---------- Verify Write Interface ---------- 
    generate
        for (i = 0; i < PORTS; i++) begin
            clocking cb_port @(posedge clock);
                property raddr_valid;
                    re[i] |-> raddr[i] < DEPTH;
                endproperty

                property waddr_valid;
                    we[i] |-> waddr[i] < DEPTH;
                endproperty

                property read_valid_data;
                    re[i] |-> valid[raddr[i]];
                endproperty
            endclocking

            validRaddr:    assert property(cb_port.raddr_valid);
            validWaddr:    assert property(cb_port.waddr_valid);
            validRdData:   assert property(cb_port.read_valid_data);
        end
    endgenerate
`endif

endmodule
