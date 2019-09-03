// This module provides the signal from an individual Space Vehicle (SV).
// Multiple SV outputs are combined with noise at the next level.
module sat_chan (
    input  logic            clk,
    input  logic            reset,
    input  logic            dv_in,
    input  logic[31:0]      dop_freq,  // (2^32)*(Fdop/Fs)
    input  logic[31:0]      code_freq, // The code rate = (base code rate = 1.023Mbps) + (doppler frequency)/1540. (2^32)*(code rate)/Fs
    input  logic[15:0]      gain,
    input  logic[5:0]       ca_sel,
    output logic            dv_out,
    output logic[15:0]      real_out,
    output logic[15:0]      imag_out
);

    // Doppler NCO
    logic [5:0] dop_nco_real, dop_nco_imag;    
    doppler_nco doppler_nco_inst ( .clk(clk), .reset(reset), .dv_in(dv_in), .freq(dop_freq), .dv_out(), .real_out(dop_nco_real), .imag_out(dop_nco_imag) );


    // Code NCO
    logic sat_ca;
    code_nco code_nco_inst (.clk(clk), .reset(reset), .ca_sel(ca_sel), .dv_in(dv_in), .freq(code_freq), .dv_out(), .q(sat_ca));


    // Change the sign on the doppler based on the CA sequence.
    logic [5:0] bpsk_imag, bpsk_real;
    always_ff @(posedge clk) begin
        if (1 == sat_ca) begin
            mult_out_imag <= -$signed(dop_nco_imag);
        end else begin
            mult_out_imag <= +$signed(dop_nco_imag);
        end        
        mult_out_real <= dop_nco_real; // Leave real part unmodified (no P code).
    end

    
    // Now let's scale the output by the gain.
    logic [22:0] scaled_real, scaled_imag;
    always_ff @(posedge clk) begin
        scaled_real <= $signed(mult_out_real)*$signed({1'b0, gain});
        scaled_imag <= $signed(mult_out_imag)*$signed({1'b0, gain});
    end
    assign real_out = scaled_real[22-:16];
    assign imag_out = scaled_imag[22-:16];

    // Data valid
    always_ff @(posedge clk) dv_out <= dv_in;

    
endmodule


