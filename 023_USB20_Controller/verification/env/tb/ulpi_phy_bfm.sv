`timescale 1ns/1ps
// ulpi_phy_bfm: ULPI 1.1 PHY side (8-bit SDR) between the DUT link wrapper and the generic harness of tb_usb2_utmi_axim.sv.
// AI-generated candidate (R-117). Written from the ULPI 1.1 text (REF-007): TX CMD handshake on NXT, STP at the end, RX CMD
// and data with DIR turn-around, register write and read. The harness side is "virtual UTMI+": the BFM converts the packets of
// the harness (rxactive, rxvalid, datain, linestate and VBUS pins) into RX CMD and data bytes, and the transmit stream of the
// link into txvalid/dataout/txready pulses, so that the monitors and operations of the harness are used unchanged. The mode
// pins (XcvrSelect, TermSelect, OpMode, SuspendM, pull-downs, DrvVbus) are decoded from the PHY registers that the link writes.
module ulpi_phy_bfm (
  input  logic       clk, input logic rst_n,
  // ULPI pins (PHY view)
  output logic       dir, output logic nxt, input logic stp, input logic [7:0] data_from_link, output logic [7:0] data_to_link,
  // virtual UTMI+ from the harness
  input  logic       v_rxactive, input logic v_rxvalid, input logic v_rxerror, input logic [7:0] v_datain, input logic [1:0] v_linestate,
  input  logic       v_vbusvalid, input logic v_hostdisc, input logic v_iddig,
  // virtual UTMI+ to the harness
  output logic       v_txvalid, output logic [7:0] v_dataout, output logic v_txready,
  output logic [1:0] v_opmode, output logic [1:0] v_xcvrsel, output logic v_termsel, output logic v_suspend_n,
  output logic       v_dppd, output logic v_dmpd, output logic v_drvvbus,
  input  int         nxt_low_pct,           // percentage of cycles in which NXT is held low during a transmit
  input  logic       link_oe,               // output enable of the link data bus (bus rules)
  output int         n_chk, output int n_viol, output int viol_id,
  input  bit         abort_req,             // pulse: arm one abort (the value of abort_after is taken at the pulse)
  input  int         abort_after,           // >= 0: DIR rises after that many transmit data bytes were taken; -1: the next register write is aborted
  output int         n_regw, output int n_regr, output int n_abort
);
  typedef enum {S_IDLE, S_TXWAIT, S_TX0, S_TX, S_REGW1, S_REGW2, S_REGW3, S_REGW4, S_TURN, S_RX} st_t;
  st_t st;
  logic [7:0] reg_func = 8'h41, reg_otg = 8'h06;
  logic [7:0] txcmd; logic [5:0] raddr; bit is_rx_pkt;
  // RX sequencer: items {kind, byte}: kind 0 = RX CMD (nxt 0), 1 = data (nxt 1), 2 = register data (nxt 0)
  typedef struct packed { logic [1:0] kind; logic [7:0] b; } item_t;
  item_t q[$];
  logic v_rxactive_d = 0, v_rxvalid_d = 0; logic [1:0] ls_d = 2'b01; logic vbus_d = 0, hd_d = 0, id_d = 1;
  int txwait; int cnt_b = 0; bit aborted; int up_cnt = 0;
  bit ta = 0; bit abort_pend = 0; int abort_cnt = 0; int txbytes = 0; bit abort_req_d = 0;
  assign v_opmode = reg_func[4:3]; assign v_xcvrsel = reg_func[1:0]; assign v_termsel = reg_func[2]; assign v_suspend_n = reg_func[6];
  assign v_dppd = reg_otg[1]; assign v_dmpd = reg_otg[2]; assign v_drvvbus = reg_otg[5];

  function automatic logic [7:0] rxcmd(input logic active, input logic err = 1'b0);
    return {1'b0, v_iddig, (v_hostdisc ? 2'b10 : (err ? 2'b11 : (active ? 2'b01 : 2'b00))), (v_vbusvalid ? 2'b11 : 2'b00), v_linestate};
  endfunction

  // ---- ULPI 1.1 bus rules checked in every cycle (a_ulpi_bus, a_ulpi_lp); a violation is counted in n_viol, rule number in viol_id
  //  1 the link drives the data bus while DIR was high in the two last cycles
  //  2 STP is high for more than one cycle, unless the pulse began in low-power mode (wake request, held until the PHY answers)
  //  3 STP is high while no transmit or register write is in progress (outside low-power mode)
  //  4 the data bus carries a reserved value (bits 7:6 = 00 but not 00h) in an idle cycle
  //  5 the link drives a command while the PHY is in low power and has not been woken (a_ulpi_lp)
  //  6 STP is still high more than 24 cycles after the wake DIR of the PHY ended (a_ulpi_lp)
  logic lp_awake = 0, fn6_d = 1; int since_dir = 0;
  logic dir_d1 = 0, stp_d1 = 0, stp_lp = 0;       // stp_lp: the present STP pulse began while the PHY was in low power (a wake request may last)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin n_chk = 0; n_viol = 0; viol_id = 0; dir_d1 <= 0; stp_d1 <= 0; end
    else begin
      dir_d1 <= dir; stp_d1 <= stp;
      if (stp && !stp_d1) stp_lp <= !reg_func[6];
      if (up_cnt >= 8) begin
        n_chk++;
        if (dir && dir_d1 && link_oe) begin n_viol++; viol_id = 1; end
        if (stp && stp_d1 && reg_func[6] && !stp_lp) begin n_viol++; viol_id = 2; end
        if (stp && reg_func[6] && st == S_IDLE) begin n_viol++; viol_id = 3; end
        if (!dir && !dir_d1 && st == S_IDLE && !ta && data_from_link[7:6] == 2'b00 && data_from_link != 8'h00) begin n_viol++; viol_id = 4; end
        // low power (a_ulpi_lp): the PHY is woken by STP and answers with DIR and an RX CMD (REF-007 3.9); until then the link sends no command
        fn6_d <= reg_func[6];
        if (fn6_d && !reg_func[6]) lp_awake <= 0;
        if (dir && !dir_d1 && !reg_func[6]) lp_awake <= 1;
        since_dir <= dir ? 0 : (since_dir < 1000 ? since_dir + 1 : since_dir);
        if (!reg_func[6] && !lp_awake && !dir && st == S_IDLE && data_from_link != 8'h00) begin n_viol++; viol_id = 5; end
        if (!reg_func[6] && lp_awake && stp && st == S_IDLE && since_dir > 24) begin n_viol++; viol_id = 6; end
      end
    end
  end

  bit dbg; initial dbg = $test$plusargs("ulpidbg");
  always @(posedge clk) if (dbg && rst_n && (dir || nxt || stp || data_from_link != 0 || st != S_IDLE))
    $display("ULPI %0t st=%s dir=%b nxt=%b stp=%b link=%02x phy=%02x q=%0d", $time, st.name(), dir, nxt, stp, data_from_link, data_to_link, q.size());
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      dir <= 0; nxt <= 0; data_to_link <= 0; st <= S_IDLE; v_txvalid <= 0; v_txready <= 0; v_dataout <= 0; q.delete();
      abort_pend = 0; abort_req_d = 0; txbytes = 0; ta = 0;
      n_regw = 0; n_regr = 0; n_abort = 0; up_cnt = 0; reg_func <= 8'h41; reg_otg <= 8'h06;
    end else begin
      v_txready <= 0;
      abort_req_d <= abort_req;
      if (abort_req && !abort_req_d) begin abort_pend = 1; abort_cnt = abort_after; end
      // ---- harness events become RX items (only when no transmit owns the bus the item is delivered)
      // after reset the PHY reports its status once (RX CMD with line state, VBUS state and ID)
      if (up_cnt < 8) begin up_cnt++; if (up_cnt == 8) q.push_back('{2'd0, rxcmd(1'b0)}); end
      v_rxactive_d <= v_rxactive; v_rxvalid_d <= v_rxvalid; ls_d <= v_linestate; vbus_d <= v_vbusvalid; hd_d <= v_hostdisc; id_d <= v_iddig;
      if (stp && !stp_d1 && !reg_func[6] && st == S_IDLE) q.push_back('{2'd0, rxcmd(1'b0)});   // wake: STP in low power makes the PHY assert DIR with an RX CMD
      if (v_rxactive && !v_rxactive_d) q.push_back('{2'd0, rxcmd(1'b1)});
      if (v_rxerror && v_rxactive) q.push_back('{2'd0, rxcmd(1'b1, 1'b1)});       // RxError is an RX CMD inside the packet
      if (v_rxvalid && v_rxactive) q.push_back('{2'd1, v_datain});
      if (!v_rxactive && v_rxactive_d) q.push_back('{2'd0, rxcmd(1'b0)});
      else if (!v_rxactive && (v_linestate != ls_d || v_vbusvalid != vbus_d || v_hostdisc != hd_d || v_iddig != id_d)) q.push_back('{2'd0, rxcmd(1'b0)});
      case (st)
        S_IDLE: begin
          nxt <= 0; dir <= 0; data_to_link <= 0;
          if (ta) ta = 0;                                                // turn-around cycle after DIR fell: the bus is not sampled (ULPI 1.1)
          else if (data_from_link[7:6] == 2'b01 && !dir) begin               // TX CMD
            txcmd = data_from_link; st <= S_TXWAIT; txwait = 1; aborted = 0; txbytes = 0;
          end else if (data_from_link[7:6] == 2'b10 && !dir) begin       // REGW
            raddr = data_from_link[5:0]; st <= S_REGW1; txwait = 1;
          end else if (data_from_link[7:6] == 2'b11 && !dir) begin       // REGR
            raddr = data_from_link[5:0]; nxt <= 1; st <= S_TURN; n_regr++;
          end else if (q.size() != 0) begin dir <= 1; st <= S_RX; end    // turn-around cycle
        end
        S_TXWAIT: begin
          // the PHY has seen the command; it accepts it by NXT
          if (abort_pend && abort_cnt == 0) begin dir <= 1; nxt <= 0; st <= S_RX; n_abort++; aborted = 1; abort_pend = 0; end
          else if (txwait > 0) txwait--; else begin nxt <= 1; st <= S_TX0; end
        end
        S_TX0: begin                                                  // the link sees NXT = 1 at this edge: the TX CMD is accepted
          if (txcmd[3:0] != 4'd0) begin v_txvalid <= 1; v_txready <= 1; v_dataout <= {~txcmd[3:0], txcmd[3:0]}; end   // NOPID: no PID byte, the stream starts with the data
          nxt <= ($urandom_range(0, 99) >= nxt_low_pct); st <= S_TX;
        end
        S_TX: begin
          nxt <= ($urandom_range(0, 99) >= nxt_low_pct);
          if (abort_pend && abort_cnt > 0 && txbytes >= abort_cnt) begin dir <= 1; nxt <= 0; st <= S_RX; v_txvalid <= 0; n_abort++; abort_pend = 0; end
          else if (stp) begin st <= S_IDLE; nxt <= 0; v_txvalid <= 0; end
          else begin v_txvalid <= 1; v_dataout <= data_from_link; v_txready <= nxt; if (nxt) txbytes++; end   // the byte on the bus is consumed when NXT is high
        end
        S_REGW1: begin
          if (abort_pend && abort_cnt < 0) begin dir <= 1; nxt <= 0; st <= S_RX; n_abort++; abort_pend = 0; end   // DIR rises before the command is accepted
          else if (txwait > 0) txwait--; else begin nxt <= 1; st <= S_REGW2; end
        end
        S_REGW2: begin nxt <= 1; st <= S_REGW3; end                  // the command is accepted at this edge; the data byte follows
        S_REGW3: begin
          if (nxt) begin
            n_regw++;
            if (raddr == 6'h04) reg_func <= data_from_link;
            if (raddr == 6'h04 && data_from_link[4:3] == 2'b11) begin n_viol++; viol_id = 7; end   // OpMode 11b: optional, not implemented (USB3320 6.2.4.5, TUSB1210 7.5.5)
            if (raddr == 6'h0A) reg_otg <= data_from_link;
            nxt <= 0; st <= S_REGW4;
          end
        end
        S_REGW4: begin nxt <= 0; if (stp) st <= S_IDLE; end
        S_TURN: begin                                                 // REGR: accept the command, then drive the data
          nxt <= 0; dir <= 1; st <= S_RX;
          q.push_front('{2'd2, (raddr == 6'h04) ? reg_func : (raddr == 6'h0A) ? reg_otg : 8'h00});
        end
        S_RX: begin
          if (q.size() != 0) begin
            item_t it; it = q.pop_front();
            nxt <= (it.kind == 2'd1); data_to_link <= it.b;
          end else begin dir <= 0; nxt <= 0; st <= S_IDLE; data_to_link <= 0; ta = 1; end
        end
        default: st <= S_IDLE;
      endcase
    end
  end
endmodule
