// Formal harness of t_fml_crc (OB: REQ-FUNC-003, properties a_crc5, a_crc16). AI-generated candidate (R-117).
// The reference functions are the bit-serial definition of USB 2.0 section 8.3.5 (same text as sim/models/usb2_crc.py);
// they are not derived from the RTL. Port conventions assumed for the two modules (interface facts, to be reviewed):
//   m_usb2_crc5 : o_crc is the CRC field as it sits above the data in the token word, so o_crc[0] is sent first.
//   m_usb2_crc16: i_crc/o_crc_nxt hold the remainder of the standard (high-order bit = bit 15); i_data[7:0] is the first
//                 byte, i_data[15:8] the second byte when i_high_en = 1 and two bytes are processed per cycle;
//                 o_tx_lo and o_tx_hi are the two CRC bytes on the bus for the remainder i_crc (inverted, high-order
//                 bit sent first, each byte LSB first); o_residual_ok is 1 when i_crc is the residual 800Dh.
// SEL = 0 checks CRC5, SEL = 1 checks CRC16, so that one failing property does not hide the other.
module fml_crc #(parameter int W = 11, parameter int BYTES = 1, parameter int SEL = 0) (
  input logic [W-1:0] tok,
  input logic [15:0]  rem,
  input logic [15:0]  dat,
  input logic         high_en
);
  function automatic logic [4:0] ref5(input logic [18:0] v, input int n);
    logic [4:0] r; logic x;
    r = 5'h1F;
    for (int i = 0; i < n; i++) begin
      x = v[i] ^ r[4];
      r = {r[3:0], 1'b0};
      if (x) r = r ^ 5'b00101;
    end
    return r;
  endfunction
  function automatic logic [15:0] ref16(input logic [15:0] r0, input logic [7:0] b);
    logic [15:0] r; logic x;
    r = r0;
    for (int i = 0; i < 8; i++) begin
      x = b[i] ^ r[15];
      r = {r[14:0], 1'b0};
      if (x) r = r ^ 16'h8005;
    end
    return r;
  endfunction

  logic [4:0]  crc5, exp5, r5;
  logic [15:0] nxt, exp16;
  logic        res_ok;
  logic [7:0]  tx_lo, tx_hi, exp_lo, exp_hi;

  m_usb2_crc5  #(.PARA_USB2_CRC5_W(W)) u5 (.i_data(tok), .o_crc(crc5));
  m_usb2_crc16 #(.PARA_USB2_CRC_BYTES(BYTES)) u16 (.i_crc(rem), .i_data(dat), .i_high_en(high_en),
                                                 .o_crc_nxt(nxt), .o_residual_ok(res_ok), .o_tx_lo(tx_lo), .o_tx_hi(tx_hi));
  always_comb begin
    r5 = ~ref5(19'(tok), W);
    for (int i = 0; i < 5; i++) exp5[i] = r5[4-i];
    for (int i = 0; i < 8; i++) begin exp_lo[i] = ~rem[15-i]; exp_hi[i] = ~rem[7-i]; end
    exp16 = ref16(rem, dat[7:0]);
    if ((BYTES == 2) && high_en) exp16 = ref16(exp16, dat[15:8]);
    if (SEL == 0) begin
      a_crc5:  assert (crc5 == exp5);
      c_crc5_all:  cover (crc5 == 5'b10101);
    end else begin
      a_crc16: assert (nxt == exp16);
      a_crc16_tx: assert ((tx_lo == exp_lo) && (tx_hi == exp_hi));
      a_crc16_res: assert (res_ok == (rem == 16'h800D));
      c_crc16_all: cover (nxt == 16'h800D);
    end
  end
endmodule
