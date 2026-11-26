//      // verilator_coverage annotation
        // tb_axi.sv - test of m_vlsit_dsig_axi together with m_vlsit_dsig_buf (specification REQ-IF-002, REQ-IF-004,
        // section 6.3; AXI4 rules of IHI 0022). A shadow memory that is updated only from the expected AXI
        // semantics (byte lanes from the address, wstrb, INCR burst, legality rules of the block) is compared
        // with every read and with the final content of the buffer. Prints RESULT: PASS or RESULT: FAIL.
        `timescale 1ns/1ps
        module tb_axi;
          localparam int BUFB = 1024;
 002861   reg clk = 0; always #5 clk = ~clk;
 000001   reg rst_n = 0;
 000001   reg busy = 0, ctrl_en = 0, resvld = 0, dma_in_ack = 0, dma_out_ack = 0;
          // AXI master side
 000001   reg awvalid = 0; wire awready; reg [3:0] awid = 0; reg [15:0] awaddr = 0; reg [7:0] awlen = 0; reg [2:0] awsize = 0; reg [1:0] awburst = 1;
 000001   reg wvalid = 0; wire wready; reg [63:0] wdata = 0; reg [7:0] wstrb = 0; reg wlast = 0;
 000001   wire bvalid; reg bready = 0; wire [3:0] bid; wire [1:0] bresp;
 000001   reg arvalid = 0; wire arready; reg [3:0] arid = 0; reg [15:0] araddr = 0; reg [7:0] arlen = 0; reg [2:0] arsize = 0; reg [1:0] arburst = 1;
 000001   wire rvalid; reg rready = 0; wire [3:0] rid; wire [63:0] rdata; wire [1:0] rresp; wire rlast;
          // buffer port
          wire b_wr_en; wire [6:0] b_wr_addr; wire [63:0] b_wr_data; wire [7:0] b_wr_strb; wire b_wr_rej;
          wire b_rd_en; wire [6:0] b_rd_addr; wire [63:0] b_rd_data; wire b_rd_valid, b_rd_rej;
          wire dma_in_req, dma_out_req, err_buserr;
          wire win_addr_we; wire [16:0] win_addr_wdata; wire [31:0] win_rd_data; wire err_ovf, err_busy;
        
          m_vlsit_dsig_axi #(.PARA_BUF_BYTES(BUFB), .PARA_AXI_DW(64), .PARA_AXI_IDW(4), .PARA_AXI_AW(16)) dut (
            .i_clk_core(clk), .i_rst_n_core(rst_n),
            .i_axi_awvalid(awvalid), .o_axi_awready(awready), .i_axi_awid(awid), .i_axi_awaddr(awaddr), .i_axi_awlen(awlen), .i_axi_awsize(awsize), .i_axi_awburst(awburst),
            .i_axi_wvalid(wvalid), .o_axi_wready(wready), .i_axi_wdata(wdata), .i_axi_wstrb(wstrb), .i_axi_wlast(wlast),
            .o_axi_bvalid(bvalid), .i_axi_bready(bready), .o_axi_bid(bid), .o_axi_bresp(bresp),
            .i_axi_arvalid(arvalid), .o_axi_arready(arready), .i_axi_arid(arid), .i_axi_araddr(araddr), .i_axi_arlen(arlen), .i_axi_arsize(arsize), .i_axi_arburst(arburst),
            .o_axi_rvalid(rvalid), .i_axi_rready(rready), .o_axi_rid(rid), .o_axi_rdata(rdata), .o_axi_rresp(rresp), .o_axi_rlast(rlast),
            .o_buf_wr_en(b_wr_en), .o_buf_wr_addr(b_wr_addr), .o_buf_wr_data(b_wr_data), .o_buf_wr_strb(b_wr_strb), .i_buf_wr_rej(b_wr_rej),
            .o_buf_rd_en(b_rd_en), .o_buf_rd_addr(b_rd_addr), .i_buf_rd_data(b_rd_data), .i_buf_rd_valid(b_rd_valid), .i_buf_rd_rej(b_rd_rej),
            .i_busy(busy), .i_ctrl_en(ctrl_en), .i_resvld(resvld),
            .o_dma_in_req(dma_in_req), .i_dma_in_ack(dma_in_ack), .o_dma_out_req(dma_out_req), .i_dma_out_ack(dma_out_ack), .o_err_buserr(err_buserr));
        
          m_vlsit_dsig_buf #(.PARA_BUF_BYTES(BUFB), .PARA_AXI_DW(64)) ubuf (
            .i_clk_core(clk), .i_rst_n_core(rst_n),
            .i_axi_wr_en(b_wr_en), .i_axi_wr_addr(b_wr_addr), .i_axi_wr_data(b_wr_data), .i_axi_wr_strb(b_wr_strb), .o_axi_wr_rej(b_wr_rej),
            .i_axi_rd_en(b_rd_en), .i_axi_rd_addr(b_rd_addr), .o_axi_rd_data(b_rd_data), .o_axi_rd_valid(b_rd_valid), .o_axi_rd_rej(b_rd_rej),
            .i_reg_wr_en(1'b0), .i_reg_wr_addr(16'd0), .i_reg_rd_en(1'b0), .i_reg_rd_addr(16'd0), .i_win_wr_data(32'd0), .i_win_addr(17'd0),
            .o_win_addr_we(win_addr_we), .o_win_addr_wdata(win_addr_wdata), .o_win_rd_data(win_rd_data),
            .i_eng_rd_en(1'b0), .i_eng_rd_addr(7'd0), .o_eng_rd_data(), .o_eng_rd_valid(),
            .i_eng_wr_en(1'b0), .i_eng_wr_addr(7'd0), .i_eng_wr_data(64'd0), .i_eng_wr_strb(8'd0),
            .i_busy(busy), .o_err_ovf(err_ovf), .o_err_busy(err_busy));
        
          reg [7:0] shadow [0:BUFB-1];
 000001   integer nfail = 0, ncheck = 0, nbad = 0, buserr_cnt = 0, seed = 1;
          integer i, k, t;
 000566   task automatic check(input integer cond, input [8*72-1:0] what);
~000566     begin ncheck = ncheck + 1; if (!cond) begin nfail = nfail + 1; $display("FAIL: %0s (time %0t)", what, $time); end end
          endtask
 001431   always @(posedge clk) if (rst_n && err_buserr) buserr_cnt = buserr_cnt + 1;
        
 000914   function integer rnd(input integer m); begin seed = seed * 1103515245 + 12345; rnd = ((seed >>> 8) & 32'h7fffff) % m; end endfunction
        
 000033   function integer legal(input integer addr, input integer len, input integer size, input integer burst, input integer isbusy);
 000033     begin legal = (burst == 1) && (size <= 3) && ((addr + ((len + 1) << size)) <= BUFB) && !isbusy; end
          endfunction
        
          // Write burst. mode bit 0: strobes randomly thinned; bit 1: send W before AW; bit 2: delay bready.
 000017   task automatic axi_write(input integer addr, input integer len, input integer size, input integer burst, input integer id, input integer mode);
 000017     integer beat, sb, a, lo, hi, lane, exp_bad, wdelay;
 000017     reg [63:0] d; reg [7:0] s; reg [7:0] smask;
 000017     begin
 000017       sb = 1 << size; exp_bad = !legal(addr, len, size, burst, busy);
 000017       wdelay = (mode & 2) ? 3 : 0;
 000016       if (!(mode & 2)) begin
 000016         @(posedge clk); #1 awvalid = 1; awid = id; awaddr = addr; awlen = len; awsize = size; awburst = burst;
~000016         t = 0; while (!awready && t < 100) begin @(posedge clk); #1 t = t + 1; end
 000016         @(posedge clk); #1 awvalid = 0;
              end
 000103       for (beat = 0; beat <= len; beat = beat + 1) begin
 000103         a = (beat == 0) ? addr : ((addr / sb) * sb + beat * sb);
 000103         lo = a % 8; hi = (((a / sb) + 1) * sb - 1) % 8;
 000645         smask = 0; for (lane = lo; lane <= hi; lane = lane + 1) smask[lane] = 1;
 000103         s = smask;
 000077         if (mode & 1) begin s = smask & rnd(256); end
 000824         for (lane = 0; lane < 8; lane = lane + 1) d[8*lane +: 8] = rnd(256);
 000632         if (!exp_bad) for (lane = 0; lane < 8; lane = lane + 1) if (s[lane]) shadow[(a / 8) * 8 + lane] = d[8*lane +: 8];
 000102         if (beat == 0 && (mode & 2)) begin
 000001           @(posedge clk); #1 wvalid = 1; wdata = d; wstrb = s; wlast = (len == 0);
 000003           repeat (wdelay) begin @(posedge clk); #1; end
 000001           awvalid = 1; awid = id; awaddr = addr; awlen = len; awsize = size; awburst = burst;
~000001           t = 0; while (!awready && t < 100) begin @(posedge clk); #1 t = t + 1; end
 000001           @(posedge clk); #1 awvalid = 0;
~000001           t = 0; while (!wready && t < 100) begin @(posedge clk); #1 t = t + 1; end
 000001           @(posedge clk); #1 wvalid = 0; wlast = 0;
 000102         end else begin
 000102           @(posedge clk); #1 wvalid = 1; wdata = d; wstrb = s; wlast = (beat == len);
~000102           t = 0; while (!wready && t < 100) begin @(posedge clk); #1 t = t + 1; end
 000102           @(posedge clk); #1 wvalid = 0; wlast = 0;
                end
              end
 000016       if (mode & 4) repeat (5) begin @(posedge clk); #1; end
 000017       bready = 1;
 000017       t = 0; while (!bvalid && t < 100) begin @(posedge clk); #1 t = t + 1; end
 000017       check(bvalid, "write: bvalid after the last beat");
 000017       check(bid == id, "write: bid equals awid");
 000017       check(bresp == (exp_bad ? 2'b10 : 2'b00), "write: bresp");
 000017       @(posedge clk); #1 bready = 0;
 000011       if (exp_bad) nbad = nbad + 1;
            end
          endtask
        
 000016   task automatic axi_read(input integer addr, input integer len, input integer size, input integer burst, input integer id, input integer slow);
 000016     integer beat, sb, a, lo, hi, lane, exp_bad, ok;
 000016     begin
 000016       sb = 1 << size; exp_bad = !legal(addr, len, size, burst, busy);
 000016       @(posedge clk); #1 arvalid = 1; arid = id; araddr = addr; arlen = len; arsize = size; arburst = burst;
~000016       t = 0; while (!arready && t < 100) begin @(posedge clk); #1 t = t + 1; end
 000016       @(posedge clk); #1 arvalid = 0;
 000099       for (beat = 0; beat <= len; beat = beat + 1) begin
 000099         a = (beat == 0) ? addr : ((addr / sb) * sb + beat * sb);
 000099         lo = a % 8; hi = (((a / sb) + 1) * sb - 1) % 8;
 000078         if (slow) repeat (slow) begin @(posedge clk); #1; end
 000099         rready = 1;
 000137         t = 0; while (!rvalid && t < 100) begin @(posedge clk); #1 t = t + 1; end
 000099         check(rvalid, "read: rvalid");
 000099         check(rid == id, "read: rid equals arid");
 000099         check(rlast == (beat == len), "read: rlast on the last beat only");
 000099         check(rresp == (exp_bad ? 2'b10 : 2'b00), "read: rresp");
 000099         ok = 1;
 000083         if (exp_bad) begin
~000016           if (rdata != 64'd0) ok = 0;
 000083         end else begin
~000489           for (lane = lo; lane <= hi; lane = lane + 1) if (rdata[8*lane +: 8] != shadow[(a / 8) * 8 + lane]) ok = 0;
                end
 000099         check(ok, "read: data of the beat");
 000099         @(posedge clk); #1 rready = 0;
              end
 000011       if (exp_bad) nbad = nbad + 1;
 000032       repeat (2) begin @(posedge clk); #1; end
            end
          endtask
        
          // Eight-beat write and read bursts at byte 600; the busy input rises after beat 3, with idle cycles around the change so
          // that the boundary does not depend on the pipeline of the block.
 000001   task automatic mid_burst_busy;
 000001     integer beat, lane, ok;
 000001     reg [63:0] d;
 000001     begin
 000001       @(posedge clk); #1 awvalid = 1; awid = 5; awaddr = 600; awlen = 7; awsize = 3; awburst = 1;
~000001       t = 0; while (!awready && t < 100) begin @(posedge clk); #1 t = t + 1; end
 000001       @(posedge clk); #1 awvalid = 0;
 000008       for (beat = 0; beat <= 7; beat = beat + 1) begin
 000007         if (beat == 4) begin
 000004           repeat (4) begin @(posedge clk); #1; end
 000001           busy = 1;
 000002           repeat (2) begin @(posedge clk); #1; end
                end
 000064         for (lane = 0; lane < 8; lane = lane + 1) d[8*lane +: 8] = rnd(256);
 000032         if (beat < 4) for (lane = 0; lane < 8; lane = lane + 1) shadow[600 + 8 * beat + lane] = d[8*lane +: 8];
 000008         @(posedge clk); #1 wvalid = 1; wdata = d; wstrb = 8'hFF; wlast = (beat == 7);
~000008         t = 0; while (!wready && t < 100) begin @(posedge clk); #1 t = t + 1; end
 000008         @(posedge clk); #1 wvalid = 0; wlast = 0;
              end
 000001       bready = 1;
 000001       t = 0; while (!bvalid && t < 100) begin @(posedge clk); #1 t = t + 1; end
 000001       check(bvalid && bid == 5, "mid-burst busy write: response with bid");
 000001       check(bresp == 2'b10, "mid-burst busy write: SLVERR after the buffer became busy");
 000001       @(posedge clk); #1 bready = 0;
 000001       nbad = nbad + 1;
 000002       busy = 0; repeat (2) begin @(posedge clk); #1; end
              // read: beats 0 to 3 while idle, then busy
 000001       @(posedge clk); #1 arvalid = 1; arid = 6; araddr = 600; arlen = 7; arsize = 3; arburst = 1;
~000001       t = 0; while (!arready && t < 100) begin @(posedge clk); #1 t = t + 1; end
 000001       @(posedge clk); #1 arvalid = 0;
 000008       for (beat = 0; beat <= 7; beat = beat + 1) begin
 000008         rready = 1;
 000010         t = 0; while (!rvalid && t < 100) begin @(posedge clk); #1 t = t + 1; end
 000008         ok = rvalid && rid == 6 && rlast == (beat == 7);
 000004         if (beat < 4) begin
 000004           ok = ok && rresp == 2'b00;
~000032           for (lane = 0; lane < 8; lane = lane + 1) if (rdata[8*lane +: 8] != shadow[600 + 8 * beat + lane]) ok = 0;
                end else
 000004           ok = ok && rresp == 2'b10 && rdata == 64'd0;
 000008         check(ok, beat < 4 ? "mid-burst busy read: OKAY and data before busy" : "mid-burst busy read: SLVERR, zero data after busy");
 000008         @(posedge clk); #1 rready = 0;
 000007         if (beat == 3) busy = 1;
              end
 000001       nbad = nbad + 1;
 000002       busy = 0; repeat (2) begin @(posedge clk); #1; end
            end
          endtask
        
 000001   task automatic compare_all;
 000001     integer n, mism;
 000001     begin
 000001       mism = 0;
 000128       for (n = 0; n < BUFB / 8; n = n + 1) begin
 000128         @(posedge clk); #1;
 000128         force_read(n);
~001024         for (k = 0; k < 8; k = k + 1) if (rdata_cap[8*k +: 8] != shadow[8*n + k]) mism = mism + 1;
              end
 000001       check(mism == 0, "buffer content equals the shadow after the whole test");
            end
          endtask
          reg [63:0] rdata_cap;
 000128   task automatic force_read(input integer widx);
 000128     begin
 000128       axi_single_read(widx * 8);
            end
          endtask
 000128   task automatic axi_single_read(input integer addr);
 000128     begin
 000128       @(posedge clk); #1 arvalid = 1; arid = 0; araddr = addr; arlen = 0; arsize = 3; arburst = 1;
~000128       t = 0; while (!arready && t < 100) begin @(posedge clk); #1 t = t + 1; end
 000128       @(posedge clk); #1 arvalid = 0; rready = 1;
 000256       t = 0; while (!rvalid && t < 100) begin @(posedge clk); #1 t = t + 1; end
 000128       rdata_cap = rdata;
 000128       @(posedge clk); #1 rready = 0;
            end
          endtask
        
 000001   initial begin : main
 001024     for (i = 0; i < BUFB; i = i + 1) shadow[i] = 8'd0;
 000004     repeat (4) @(posedge clk); #1 rst_n = 1; repeat (2) @(posedge clk); #1;
            // Full-width bursts, narrow transfers, unaligned starts, thinned strobes, W before AW, slow bready
 000001     axi_write(0, 0, 3, 1, 1, 0);
 000001     axi_write(8, 3, 3, 1, 2, 0);
 000001     axi_write(64, 7, 3, 1, 3, 1);
 000001     axi_write(100, 5, 2, 1, 4, 0);       // 32-bit beats from an unaligned address
 000001     axi_write(130, 9, 1, 1, 5, 1);       // 16-bit beats
 000001     axi_write(201, 12, 0, 1, 6, 0);      // byte beats
 000001     axi_write(512, 15, 3, 1, 7, 2);      // W before AW
 000001     axi_write(640, 3, 3, 1, 8, 4);       // delayed bready
 000001     axi_write(1016, 0, 3, 1, 9, 0);      // the last word of the window
 000001     axi_write(960, 7, 3, 1, 10, 1);      // ends exactly at the window end
 000001     axi_read(0, 0, 3, 1, 1, 0);
 000001     axi_read(8, 3, 3, 1, 2, 0);
 000001     axi_read(64, 7, 3, 1, 3, 2);
 000001     axi_read(100, 5, 2, 1, 4, 0);
 000001     axi_read(130, 9, 1, 1, 5, 0);
 000001     axi_read(201, 12, 0, 1, 6, 1);
 000001     axi_read(512, 15, 3, 1, 7, 0);
 000001     axi_read(1016, 0, 3, 1, 9, 0);
 000001     axi_read(960, 7, 3, 1, 10, 0);
            // Errors: FIXED, WRAP, size larger than the bus, burst past the window end: no byte is written
 000001     axi_write(256, 3, 3, 0, 11, 0);
 000001     axi_write(256, 3, 3, 2, 12, 0);
 000001     axi_write(256, 1, 4, 1, 13, 0);
 000001     axi_write(1016, 1, 3, 1, 14, 0);
 000001     axi_write(1000, 7, 3, 1, 15, 0);
 000001     axi_read(256, 3, 3, 0, 11, 0);
 000001     axi_read(256, 3, 3, 2, 12, 0);
 000001     axi_read(256, 1, 4, 1, 13, 0);
 000001     axi_read(1016, 1, 3, 1, 14, 0);
            // Access while the control block is busy is refused and writes no byte
 000002     busy = 1; repeat (2) @(posedge clk); #1;
 000001     axi_write(300, 3, 3, 1, 1, 0);
 000001     axi_read(300, 3, 3, 1, 1, 0);
 000002     busy = 0; repeat (2) @(posedge clk); #1;
            // The buffer becomes busy in the middle of a burst (REQ-IF-002, ERR-007, ASM-027): the beats before stay written, the
            // later beats write no byte, the burst ends with SLVERR and one buserr pulse; a read gives SLVERR and zero data after it
 000001     mid_burst_busy;
            // A write and a read at the same time on different words
 000001     fork
 000001       axi_write(400, 7, 3, 1, 2, 0);
 000001       begin : rd_side
 000003         repeat (3) @(posedge clk);
 000001         axi_read(64, 7, 3, 1, 3, 0);
              end
            join
 000001     axi_read(400, 7, 3, 1, 4, 0);
 000001     compare_all;
            // Error pulse: one per refused burst
 000001     check(buserr_cnt == nbad, "o_err_buserr: one pulse per burst answered with SLVERR");
            // DMA handshake
 000001     ctrl_en = 1; busy = 0; resvld = 0; #1;
 000001     check(dma_in_req && !dma_out_req, "dma: input request when enabled, idle and no result");
 000001     @(posedge clk); #1 dma_in_ack = 1; @(posedge clk); #1 dma_in_ack = 0; #1;
 000001     check(!dma_in_req, "dma: input request dropped by the acknowledge");
 000003     repeat (3) begin @(posedge clk); #1; end
 000001     check(!dma_in_req, "dma: input request stays low until the next operation starts");
 000002     busy = 1; repeat (2) begin @(posedge clk); #1; end
 000001     check(!dma_in_req, "dma: no input request while busy");
 000001     busy = 0; resvld = 1; #1;
 000001     check(dma_out_req && !dma_in_req, "dma: output request with a valid result");
 000001     @(posedge clk); #1 dma_out_ack = 1; @(posedge clk); #1 dma_out_ack = 0; #1;
 000001     check(!dma_out_req, "dma: output request dropped by the acknowledge");
 000002     resvld = 0; repeat (2) begin @(posedge clk); #1; end
 000001     check(dma_in_req, "dma: input request again after the operation was started and the result cleared");
 000001     ctrl_en = 0; #1;
 000001     check(!dma_in_req, "dma: no input request while the IP is disabled");
 000001     $display("tb_axi: %0d checks, %0d failed", ncheck, nfail);
~000001     if (nfail == 0) $display("RESULT: PASS"); else $display("RESULT: FAIL");
 000001     $finish;
          end
        endmodule
        
