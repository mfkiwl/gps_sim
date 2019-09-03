// code_nco.sv - first cut at NCO for the CA code generator. This is needed for code tracking in the receiver.
// The code rom must receive a modulo 1023 count. This means that the top bits of a phase accumlator cannot just be used as the address.
// Instead, a 32 bit frequency accumulator provides a carry out bit to increment a modulo 1023 address counter.
// The 32 bit frequency is the code bit rate frequency, ie., the chipping rate.

// TODO: We probably need loadable code state, phase and frequency. For now, just reset everything.
// TODO: Also, probably, we need a clock enable.

module code_nco (
    input  logic            clk,
    input  logic            reset,
    input  logic[5:0]       ca_sel,
    input  logic            dv_in,
    input  logic[31:0]      freq,  // phase increment (frequency).
    output logic            dv_out,
    output logic            q
);

    // phase accumulator - when this rolls-over the code address counter is incremented.
    logic[32:0] presum;
    logic cout;
    logic[31:0] phase;
    assign presum = phase + freq;
    always_ff @(posedge clk) begin
        if (1 == reset) begin
            phase <= 0;
            cout <= 0;
        end else begin
            if (1==dv_in) begin
                phase <= presum[31:0];
                cout  <= presum[32];  // carry out bit to the code address counter.
            end else begin
                cout  <= 0;
            end
        end
    end

    // code address counter
    logic[9:0] ca_addr;
    always_ff @(posedge clk) begin
        if (1==reset) begin
            ca_addr <= 0;
        end else begin
            if (1==cout) begin
                if(1023==ca_addr) begin // modulo 1023
                    ca_addr <= 0;
                end else begin
                    ca_addr <= ca_addr + 1;
                end
            end
        end
    end

    // the block rom core.
    logic [35:0]  ca_seq;
    ca_rom ca_rom_inst (.clka(clk), .addra(ca_addr), .douta(ca_seq));

    // selet the particular space vehicle code.
    always_ff @(posedge clk) begin
        q <= ca_seq[ca_sel];
    end

    // pipeline the dv.
    localparam integer Npipe = 6;
    logic[Npipe-1:0] dv_pipe;
    assign dv_pipe[0] = dv_in;
    always_ff @(posedge clk) begin
        dv_pipe[Npipe-1:1] <= dv_pipe[Npipe-2:0];
    end
    assign dv_out = dv_pipe[Npipe-1];

endmodule


