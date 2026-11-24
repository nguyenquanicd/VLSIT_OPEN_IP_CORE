`timescale 1ns/1ps
// t_dir_param_builds: the elaboration check m_usb2_cfgchk for one parameter set (set by defparam lines added by the
// runner); prints its result.
module tb_cfgchk;
  logic err;
  m_usb2_cfgchk dut (.o_cfg_err(err));
  initial begin #1; $display("CFGERR %0d", err); $finish; end
endmodule
