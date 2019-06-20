module doppler_nco (
    input  logic        clk,
    input  logic[31:0]  freq,
    output logic[9:0]   real_out,
    output logic[9:0]   imag_out
);

    // Let's use 32 bit accummulators for the DDS.
    logic [31:0] phase;
    always_ff @(posedge clk) begin
        if (enable = 1) then
            phase <= phase + freq;
        else
            phase <= 0;
        end if
    end

    logic [31:0] m_axis_data_tdata;
    doppler_rom doppler_rom_inst (
        .aclk(clk),                                // input wire aclk
        .s_axis_phase_tvalid('1'),  // input wire s_axis_phase_tvalid
        .s_axis_phase_tdata(phase),    // input wire [15 : 0] s_axis_phase_tdata
        .m_axis_data_tvalid(),    // output wire m_axis_data_tvalid
        .m_axis_data_tdata(m_axis_data_tdata)       // output wire [31 : 0] m_axis_data_tdata
    );
    assign imag_out = m_axis_data_tdata[16 +: 9];
    assign real_out = m_axis_data_tdata[ 0 +: 9];

endmodule
