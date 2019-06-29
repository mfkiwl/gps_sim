module sat_chan (
    input  logic        clk,
    input  logic        enable,
    input  logic[31:0]  freq,
    input  logic[15:0]  gain,
    input  logic[5:0]   ca_sel,
    input  logic[35:0]  ca_seq,
    output logic  signed [15:0]  real_out,
    output logic  signed [15:0]  imag_out
);

    // Here is the Doppler NCO.
    logic signed [8:0] nco_real, nco_imag;    
    doppler_nco doppler_nco_inst ( .clk(clk), .enable(enable), .freq(freq), .real_out(nco_real), .imag_out(nco_imag) );

    // we need to scale the imaginary part of the NCO output by 1/sqrt(2) ~ 0.7
    localparam int p_scale = (2.0**8)/$sqrt(2.0);                            // supposedly this automatically rounds from float to int.
    logic [15:0] scaled_nco_real, scaled_nco_imag;
    logic signed [2*9-1:0] real_scale_var;
    logic signed [8:0] imag_scale_var;
    always_ff @(posedge clk) begin
        real_scale_var <= p_scale*nco_real;
        imag_scale_var <= nco_imag;
        scaled_nco_imag <= {{7{nco_imag[8]}},        imag_scale_var};              // note sign extension to 16 bits.
        scaled_nco_real <= {{7{real_scale_var[16]}}, real_scale_var[16-:9]}; // we should round here instead of just truncating.
    end

    // modulate the doppler by the c/a code.
    // The c/a goes on the quadrature (imaginary) part of the signal.
    // A '1' corresponds to a multiplication by -1. '0' corresponds to +1.
    logic sat_ca;
    assign sat_ca = ca_seq[ca_sel];
    logic signed [15:0] pre_scaled_real, pre_scaled_imag;
    always_ff @(posedge clk) begin
        if (1 == sat_ca) begin
            pre_scaled_imag <= -scaled_nco_imag;
        end else begin
            pre_scaled_imag <= +scaled_nco_imag;
        end        
        pre_scaled_real <= +scaled_nco_real;  // P-code not implemented yet.
    end
    
    // Now let's scale the output by the gain.
    logic signed [31:0] scaled_real, scaled_imag;
    always_ff @(posedge clk) begin
        scaled_real <= pre_scaled_real*gain;
        scaled_imag <= pre_scaled_imag*gain;
    end
    assign real_out = scaled_real[30-:16];
    assign imag_out = scaled_imag[30-:16];
    
    
endmodule


