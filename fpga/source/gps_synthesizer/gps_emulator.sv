// gps_emulator.sv
// This block provides a gps emulator that can be instantiated inside
// an FPGA to provide a well controlled signal source for receiver development.

module gps_emulator #(
    parameter int Nsat = 4
)(
    input  logic        clk,   // this is the system clock, 102.3MHz.
    input  logic        enable,
    input  logic[31:0]  freq        [Nsat-1:0], // the doppler frequency for each satellite.
    input  logic[15:0]  gain        [Nsat-1:0], // the gain of each satellite
    input  logic[5:0]   ca_sel      [Nsat-1:0], // the C/A sequence of each satellite 0-35 corresponds to SV 1-36. SV 37 not supported.
    input  logic[15:0]  noise_gain,             // gain of noise added to combined signal.
    // quantized baseband
    output logic[7:0]  real_out,  imag_out
);

    // here is the logic to generate the c/a sequences.
    // We generate all 36 c/a codes in phase. Each sat chan can select one to use and (eventually) add delay.
    localparam integer samp_per_chip = 4;
    logic [9:0]   ca_addr;
    logic [6:0]   ca_chip_count;
    always_ff @(posedge clk) begin
        if (0 == enable) begin
            ca_addr <= 0;
            ca_chip_count <= 0;
        end else begin
            if ((samp_per_chip-1) == ca_chip_count) begin
                ca_chip_count <= 0;
                if (1022 == ca_addr) begin
                    ca_addr <= 0;
                end else begin
                    ca_addr <= ca_addr+1;
                end
            end else begin
                ca_chip_count <= ca_chip_count+1;
            end
        end
    end
    logic [35:0]  ca_seq;
    ca_rom ca_rom_inst (.clka(clk), .addra(ca_addr), .douta(ca_seq));
    
    
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
            .ca_sel(ca_sel[sat]),
            .ca_seq(ca_seq),
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
        temp_real_reg <= temp_real; 
        temp_imag_reg <= temp_imag;
        temp_real_reg_reg <= temp_real_reg; 
        temp_imag_reg_reg <= temp_imag_reg;
    end
    

    // instantiate the noise source.
    // The noise is a very good approximation to Gaussian with standard deviation = 1.0 using 16.11 fixed point interpretation.
    logic signed [15:0] noise_real, noise_imag;
    gng_cmplx gng_cmplx_inst (.clk(clk), .rstn(enable), .ce(1'b1), .valid_out(), .real_out(noise_real), .imag_out(noise_imag));
    // set the noise level
    logic signed [31:0] noise_scaled_real, noise_scaled_imag;
    always_ff @(posedge clk) begin
        noise_scaled_real <= $signed(noise_real)*$signed({1'b0, noise_gain});  
        noise_scaled_imag <= $signed(noise_imag)*$signed({1'b0, noise_gain});
    end

    // Add the Gaussian noise source
    logic[15:0] dither_real, dither_imag;
    assign dither_real = noise_scaled_real[31-:16];
    assign dither_imag = noise_scaled_imag[31-:16];
    logic[15:0] bb_with_noise_real, bb_with_noise_imag;
    always_ff @(posedge clk) begin
        bb_with_noise_real <= dither_real + temp_real_reg_reg;  // We should have saturation logic here.
        bb_with_noise_imag <= dither_imag + temp_imag_reg_reg;
    end

    // Let's put an ILA core here to observe the synthesized signal before quantization.
    // This will also prevent all logic being synthesized away when nothing is on the output.
    bb_ila bb_ila_inst (.clk(clk), .probe0({bb_with_noise_real, bb_with_noise_imag})); // 16+16
    

    // Quantize down to emulate commercial GPS RF front end chips like the MAX2769.
    // This should include rounding and saturation at desired levels.
    // For now let's just map to the most significant bits.
    always_ff @(posedge clk) begin
        real_out <= bb_with_noise_real[15-:8];
        imag_out <= bb_with_noise_imag[15-:8];
    end

endmodule

