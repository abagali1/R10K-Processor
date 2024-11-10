module dispatch #(
    parameter N = `N
)(
    input                                        clock,
    input                                        reset,
    input logic             [$clog2(N+1)-1:0]    rob_open,
    input logic             [$clog2(N+1)-1:0]    rs_open,
    input INST_PACKET       [N-1:0]              insts,
    input logic                                  bs_full,

    output                  [$clog2(N+1)-1:0]    num_dispatch,
    output INST_PACKET      [N-1:0]              out_insts,

);

    logic [$clog2(N+1)-1:0] num_rob_rs; 
    logic [$clog2(N+1)-1:0] num_valid_inst;
    logic br_included;
    
    assign num_rob_rs = rob_open < rs_open ? rob_open : rs_open;
    assign limit = num_valid_inst < num_rob_rs ? num_valid_inst : num_rob_rs;

    DECODED_PACKET [N-1:0] decoded_insts;
    
    decode #(
        .N(N)
    )  
    (
        .clock(clock),           // system clock
        .reset(reset),           // system reset
        .insts(insts),

        .id_packet(decoded_insts)
    );


    always_comb begin
        num_valid_inst = 0;
        for (int i = 0; i < N; i++) begin
            if (inst[i].valid) begin
                num_valid_inst++;
            end
        end
    end

    always_comb begin
        num_dispatch = 0;
        for (int i = 0; i < N; i++) begin
            if (decoded_insts[i].valid & i < limit) begin
                if ((decoded_insts[i].uncond_branch || decoded_insts[i].cond_branch)) begin
                    if (br_included == 0 & i == 0 & bs_full) begin
                        br_included = 1;
                        out_insts[i] = insts[i];
                        num_dispatch++;
                    end else begin
                        break;
                    end
                end else begin
                    out_insts[i] = insts[i];
                    num_dispatch++;
                end                
            end
        end
    end 

endmodule