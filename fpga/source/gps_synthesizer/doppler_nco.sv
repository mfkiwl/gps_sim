module doppler_nco (
    input  logic        clk,
    input  logic[31:0]  freq,
    output logic[15:0]  real_out,
    output logic[15:0]  imag_out
);

    doppler_rom doppler_rom_inst (
        .aclk(aclk),                                // input wire aclk
        .s_axis_phase_tvalid(s_axis_phase_tvalid),  // input wire s_axis_phase_tvalid
        .s_axis_phase_tdata(s_axis_phase_tdata),    // input wire [15 : 0] s_axis_phase_tdata
        .m_axis_data_tvalid(m_axis_data_tvalid),    // output wire m_axis_data_tvalid
        .m_axis_data_tdata(m_axis_data_tdata)       // output wire [31 : 0] m_axis_data_tdata
    );

endmodule
