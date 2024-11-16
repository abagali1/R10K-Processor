module issue (
    
    input  RS_PACKET        [`NUM_FU_BR-1:0]    issued_br,

    output logic            [`NUM_FU_BR-1:0]    br_rd_en,
    output ISSUE_PACKET     [`NUM_FU_BR-1:0]    issued_br,
);


    // branching issuing signals
    always_comb begin    
        issued_br.

        for (int i = 0; i <`NUM_FU_BR; i++) begin
            br_rd_en_vals[i] = issued_br.decoded_vals.valid;
        end
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            br_rd_en <= 0;
        end else if (issued_br.decoded_vals.valid) begin
            
    end
endmodule