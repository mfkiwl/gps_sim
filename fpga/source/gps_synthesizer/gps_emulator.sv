// gps_emulator.sv
// This block provides a gps emulator that can be instantiated inside
// an FPGA to provide a well controlled signal source for receiver development.

module gps_emulator #(
    parameter int Nsat = 4
)(
    input  logic        clk,
    input  logic        enable,
    input  logic[31:0]  freq        [Nsat-1:0], // the doppler frequency for each satellite.
    input  logic[15:0]  gain        [Nsat-1:0], // the gain of each satellite
    input  logic[5:0]   ca_sel      [Nsat-1:0], // the C/A sequence of each satellite 0-35 corresponds to SV 1-36. SV 37 not supported.
    input  logic[15:0]  noise_gain,             // gain of noise added to combined signal.
    // quantized baseband
    output logic[2:0]  real_out,  
    output logic[2:0]  imag_out
);

    logic[35:0]  ca_seq         [Nsat-1:0];
    logic[15:0]  sat_real_out   [Nsat-1:0];
    logic[15:0]  sat_imag_out   [Nsat-1:0];
    
    // generate the individual satellite channel blocks.
    genvar sat;
    generate for (sat=0; sat<Nsat; sat++) begin
        sat_chan sat_chan_inst (
            .clk(clk),
            .enable(enable),
            .freq(freq[sat]),
            .gain(gain[sat]),
            .ca_seq(ca_seq[sat]),
            .real_out(sat_real_out[sat]),
            .imag_out(sat_imag_out[sat])
        );
    end endgenerate

    // sum the Nsat satellite outputs.
    // It is a parameterized number of inputs so let's do it with a for loop.
    logic[15:0] temp_real, temp_imag;
    always_comb begin
        temp_real = 0;
        temp_imag = 0;
        for (int i=0; i<Nsat; i++) begin
            temp_real += sat_real_out[i];
            temp_imag += sat_imag_out[i];
        end
    end

    // Here are some registers to allow synthesis pipeline rebalancing.
    logic[15:0] temp_real_reg, temp_imag_reg;
    logic[15:0] temp_real_reg_reg, temp_imag_reg_reg;
    always_ff @(posedge clk) begin
        temp_real_reg <= temp_real; temp_imag_reg <= temp_imag;
        temp_real_reg_reg <= temp_real_reg; temp_imag_reg_reg <= temp_imag_reg;
    end
    

    // instantiate the noise source.
    logic[15:0] noise_real, noise_imag;
    logic[15:0] noise_scaled_real, noise_scaled_imag;

    // Add the Gaussian noise source
    logic[15:0] bb_with_noise_real, bb_with_noise_imag;
    always_ff @(posedge clk) begin
        bb_with_noise_real <= noise_scaled_real + temp_real_reg_reg;
        bb_with_noise_imag <= noise_scaled_imag + temp_imag_reg_reg;
    end
    

    // Quantize down to emulate commercial GPS RF front end chips like the MAX2769.

endmodule

