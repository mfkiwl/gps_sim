// This module provides the signal from an individual Space Vehicle (SV).
// Multiple SV outputs are combined with noise at the next level.
module sat_chan (
    input  logic            clk,
    input  logic            enable,
    input  logic[31:0]      freq,
    input  logic[15:0]      gain,
    input  logic[5:0]       ca_sel,
    input  logic[35:0]      ca_seq,
    output logic[15:0]      real_out,
    output logic[15:0]      imag_out
);

    // Here is the Doppler NCO.
    logic [8:0] nco_real, nco_imag;    
    doppler_nco doppler_nco_inst ( .clk(clk), .enable(enable), .freq(freq), .real_out(nco_real), .imag_out(nco_imag) );

    // modulate the doppler by the c/a code.
    // The c/a goes on the quadrature (imaginary) part of the signal.
    // A '1' corresponds to a multiplication by -1. '0' corresponds to +1.
    logic sat_ca;
    assign sat_ca = ca_seq[ca_sel];  // pick which of the 36 ca sequences to use.
    logic [8:0] pre_scaled_real, pre_scaled_imag;
    always_ff @(posedge clk) begin
        if (1 == sat_ca) begin
            pre_scaled_imag <= -255;
        end else begin
            pre_scaled_imag <= +255;
        end        
        pre_scaled_real <= 0; // +180;  // P-code not implemented yet. 180~=255/sqrt(2).
    end
    
    // Let's instantiate a Xilinx core for the complex multiplier. This could be changed to something portable without much trouble. 
    logic [31:0] mult_s_axis_a_tdata, mult_s_axis_b_tdata;
//    assign mult_s_axis_a_tdata[16+:9] = pre_scaled_imag;
//    assign mult_s_axis_a_tdata[ 0+:9] = pre_scaled_real;
//    assign mult_s_axis_b_tdata[16+:9] = nco_imag;
//    assign mult_s_axis_b_tdata[ 0+:9] = nco_real;
    assign mult_s_axis_a_tdata = { {7{1'b0}}, pre_scaled_imag, {7{1'b0}}, pre_scaled_real };
    assign mult_s_axis_b_tdata = { {7{1'b0}},        nco_imag, {7{1'b0}},        nco_real };
    logic [47:0] mult_m_axis_dout_tdata;
    doppler_mult doppler_mult_inst (
        .aclk(clk),
        .s_axis_a_tvalid    (1'b1),        // input wire s_axis_a_tvalid
        .s_axis_a_tdata     (mult_s_axis_a_tdata),          // input wire [31 : 0] s_axis_a_tdata
        .s_axis_b_tvalid    (1'b1),        // input wire s_axis_b_tvalid
        .s_axis_b_tdata     (mult_s_axis_b_tdata),          // input wire [31 : 0] s_axis_b_tdata
        .m_axis_dout_tvalid (),  // output wire m_axis_dout_tvalid
        .m_axis_dout_tdata  (mult_m_axis_dout_tdata)    // output wire [47 : 0] m_axis_dout_tdata
    );
    logic [15:0] mult_out_real, mult_out_imag;
    assign mult_out_imag = mult_m_axis_dout_tdata[25+:16];
    assign mult_out_real = mult_m_axis_dout_tdata[ 1+:16];    
    
    // Now let's scale the output by the gain.
    logic [31:0] scaled_real, scaled_imag;
    always_ff @(posedge clk) begin
        scaled_real <= $signed(mult_out_real)*$signed({1'b0, gain});
        scaled_imag <= $signed(mult_out_imag)*$signed({1'b0, gain});
    end
    assign real_out = scaled_real[31-:16];
    assign imag_out = scaled_imag[31-:16];
    
endmodule


