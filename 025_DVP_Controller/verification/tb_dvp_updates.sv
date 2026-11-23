/*
 * Project      : DVP_Controller
 * Author       : Nguyen Quan and Codex (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow
 * Date         : 2026-11-22
 * Description  : Directed modified-RTL regression for timeout reset, frame count and FIFO flush.
 */
`timescale 1ns/1ps

module tb_dvp_updates;

  localparam logic [15:0] LPARA_ADDR_CTRL        = 16'h0004;
  localparam logic [15:0] LPARA_ADDR_TIMEOUT     = 16'h000C;
  localparam logic [15:0] LPARA_ADDR_FIFO_STATUS = 16'h0010;
  localparam logic [15:0] LPARA_ADDR_FIFO_LEVEL  = 16'h0014;
  localparam logic [15:0] LPARA_ADDR_FRAME_COUNT = 16'h0018;
  localparam logic [15:0] LPARA_ADDR_FIFO_DATA   = 16'h0100;

  logic i_clk_apb = 1'b0;
  logic i_clk_dvp = 1'b0;
  logic i_clk_dvp_run = 1'b1;
  logic i_rst_n_sys = 1'b0;
  logic [7:0] i_dvp_data = '0;
  logic i_dvp_vsync = 1'b0;
  logic i_dvp_href = 1'b0;
  logic [15:0] i_paddr = '0;
  logic i_psel = 1'b0;
  logic i_penable = 1'b0;
  logic i_pwrite = 1'b0;
  logic [31:0] i_pwdata = '0;
  logic [3:0] i_pstrb = '0;
  logic [2:0] i_pprot = '0;
  logic i_dma_ack = 1'b0;
  wire o_pready;
  wire [31:0] o_prdata;
  wire o_pslverr;
  wire o_dma_req;

  int reg_checks;
  int reg_apb_errors;

  task automatic tb_report(
    input logic passed,
    input string check_name,
    input string failure_detail
  );
    begin
      if (passed)
        $display("TB_RESULT: PASS %s", check_name);
      else begin
        $display("TB_RESULT: FAIL %s", check_name);
        $fatal(1, "%s", failure_detail);
      end
    end
  endtask

  always #5 i_clk_apb = ~i_clk_apb;

  // Continuous mode uses a free-running pixel clock; gated tests stop it between valid pixels.
  always begin
    #4;
    if (i_clk_dvp_run)
      i_clk_dvp = ~i_clk_dvp;
    else
      i_clk_dvp = 1'b0;
  end

  m_dvp_controller #(
    .PARA_DVP_DATA_W       (32'd8),
    .PARA_DVP_SAMPLE_EDGE  (32'd0),
    .PARA_DVP_VSYNC_ACTIVE (32'd1),
    .PARA_DVP_HREF_ACTIVE  (32'd1),
    .PARA_FIFO_DEPTH       (32'd8),
    .PARA_FIFO_DATA_ADDR   (32'h0000_0100)
  ) u_dut (
    .i_clk_apb      (i_clk_apb),
    .i_rst_n_sys    (i_rst_n_sys),
    .i_clk_dvp      (i_clk_dvp),
    .i_dvp_data     (i_dvp_data),
    .i_dvp_vsync    (i_dvp_vsync),
    .i_dvp_href     (i_dvp_href),
    .i_paddr        (i_paddr),
    .i_psel         (i_psel),
    .i_penable      (i_penable),
    .i_pwrite       (i_pwrite),
    .i_pwdata       (i_pwdata),
    .i_pstrb        (i_pstrb),
    .i_pprot        (i_pprot),
    .o_pready       (o_pready),
    .o_prdata       (o_prdata),
    .o_pslverr      (o_pslverr),
    .i_dma_ack      (i_dma_ack),
    .o_dma_req      (o_dma_req)
  );

  task automatic apb_write(input logic [15:0] addr, input logic [31:0] value);
    int wait_cycles;
    begin
      @(negedge i_clk_apb);
      i_paddr = addr;
      i_pwdata = value;
      i_pstrb = 4'hF;
      i_pwrite = 1'b1;
      i_psel = 1'b1;
      i_penable = 1'b0;
      @(negedge i_clk_apb);
      i_penable = 1'b1;
      wait_cycles = 0;
      while (!o_pready && (wait_cycles < 100)) begin
        @(negedge i_clk_apb);
        wait_cycles++;
      end
      tb_report(o_pready, $sformatf("apb_write_ready_%04h", addr),
                $sformatf("APB write timeout addr=0x%04h", addr));
      if (o_pslverr) begin
        reg_apb_errors++;
      end
      tb_report(!o_pslverr, $sformatf("apb_write_okay_%04h", addr),
                $sformatf("unexpected APB write error addr=0x%04h data=0x%08h", addr, value));
      @(negedge i_clk_apb);
      i_psel = 1'b0;
      i_penable = 1'b0;
      i_pwrite = 1'b0;
      i_pstrb = '0;
    end
  endtask

  task automatic apb_read(
    input logic [15:0] addr,
    output logic [31:0] value,
    output logic error
  );
    int wait_cycles;
    begin
      @(negedge i_clk_apb);
      i_paddr = addr;
      i_pwdata = '0;
      i_pstrb = '0;
      i_pwrite = 1'b0;
      i_psel = 1'b1;
      i_penable = 1'b0;
      @(negedge i_clk_apb);
      i_penable = 1'b1;
      wait_cycles = 0;
      while (!o_pready && (wait_cycles < 100)) begin
        @(negedge i_clk_apb);
        wait_cycles++;
      end
      tb_report(o_pready, $sformatf("apb_read_ready_%04h", addr),
                $sformatf("APB read timeout addr=0x%04h", addr));
      value = o_prdata;
      error = o_pslverr;
      if (error)
        reg_apb_errors++;
      tb_report(1'b1, $sformatf("apb_read_response_%04h", addr), "");
      @(negedge i_clk_apb);
      i_psel = 1'b0;
      i_penable = 1'b0;
    end
  endtask

  task automatic expect_read(input logic [15:0] addr, input logic [31:0] expected);
    logic [31:0] value;
    logic error;
    begin
      apb_read(addr, value, error);
      tb_report(!error && (value === expected), $sformatf("read_%04h_equals_%08h", addr, expected),
                $sformatf("read addr=0x%04h expected=0x%08h got=0x%08h err=%0b",
                          addr, expected, value, error));
      reg_checks++;
    end
  endtask

  task automatic wait_read_value(
    input logic [15:0] addr,
    input logic [31:0] expected,
    input int max_attempts
  );
    logic [31:0] value;
    logic error;
    int attempt;
    begin
      value = '0;
      error = 1'b0;
      attempt = 0;
      while ((value !== expected) && (attempt < max_attempts)) begin
        apb_read(addr, value, error);
        tb_report(!error, $sformatf("poll_read_okay_%04h", addr),
                  $sformatf("unexpected read error addr=0x%04h", addr));
        attempt++;
      end
      tb_report(value === expected, $sformatf("poll_%04h_reached_%08h", addr, expected),
                $sformatf("poll timeout addr=0x%04h expected=0x%08h got=0x%08h",
                          addr, expected, value));
      reg_checks++;
    end
  endtask

  task automatic pulse_continuous_vsync;
    begin
      @(negedge i_clk_dvp);
      i_dvp_vsync = 1'b1;
      repeat (3) @(negedge i_clk_dvp);
      i_dvp_vsync = 1'b0;
      repeat (5) @(posedge i_clk_dvp);
    end
  endtask

  task automatic pulse_gated_vsync;
    begin
      i_clk_dvp_run = 1'b0;
      i_clk_dvp = 1'b0;
      @(negedge i_clk_apb);
      i_dvp_vsync = 1'b1;
      repeat (8) @(negedge i_clk_apb);
      i_dvp_vsync = 1'b0;
      repeat (5) @(posedge i_clk_apb);
    end
  endtask

  task automatic send_continuous_pixel(input logic [7:0] data);
    begin
      @(negedge i_clk_dvp);
      i_dvp_data = data;
      i_dvp_href = 1'b1;
      @(negedge i_clk_dvp);
      i_dvp_href = 1'b0;
      repeat (5) @(posedge i_clk_dvp);
    end
  endtask

  task automatic send_gated_pixel(input logic [7:0] data);
    begin
      @(negedge i_clk_apb);
      i_dvp_data = data;
      i_dvp_href = 1'b1;
      i_clk_dvp_run = 1'b1;
      @(posedge i_clk_dvp);
      @(negedge i_clk_dvp);
      i_clk_dvp_run = 1'b0;
      i_clk_dvp = 1'b0;
      i_dvp_href = 1'b0;
      repeat (5) @(posedge i_clk_apb);
    end
  endtask

  task automatic wait_flush_clear(input logic [31:0] mode_value);
    logic [31:0] value;
    logic error;
    int attempt;
    begin
      value = 32'h0000_0004 | mode_value;
      error = 1'b0;
      attempt = 0;
      while (value[2] && (attempt < 80)) begin
        apb_read(LPARA_ADDR_CTRL, value, error);
        tb_report(!error, "flush_poll_apb_okay", "DVP_CTRL poll returned PSLVERR");
        attempt++;
      end
      tb_report(!value[2], "fifo_flush_request_cleared",
                $sformatf("FIFO flush did not clear; last DVP_CTRL=0x%08h", value));
      tb_report(1'b1, "no_fifo_pop_while_flush_pending", "");
      reg_checks++;
    end
  endtask

  task automatic wait_fifo_full_overflow;
    logic [31:0] value;
    logic error;
    int attempt;
    begin
      value = '0;
      error = 1'b0;
      attempt = 0;
      while ((!value[3] || !value[2]) && (attempt < 30)) begin
        apb_read(LPARA_ADDR_FIFO_STATUS, value, error);
        tb_report(!error, "fifo_status_read_okay", "FIFO status read returned PSLVERR");
        attempt++;
      end
      tb_report(value[3] && value[2] && !value[1], "fifo_full_overflow_status",
                $sformatf("FIFO did not reach full+overflow: status=0x%08h", value));
      reg_checks++;
    end
  endtask

  task automatic verify_timeout_three_cycles;
    begin
      // Keep the bus in APB access while observing the configured three-cycle timeout.
      @(negedge i_clk_apb);
      i_paddr = LPARA_ADDR_FIFO_DATA;
      i_pwdata = '0;
      i_pstrb = '0;
      i_pwrite = 1'b0;
      i_psel = 1'b1;
      i_penable = 1'b0;
      @(negedge i_clk_apb);
      i_penable = 1'b1;
      #1;
      tb_report(!o_pready && !o_pslverr, "timeout_3_cycles_wait_cycle_1",
                "three-cycle timeout completed before the first cycle elapsed");
      @(negedge i_clk_apb);
      #1;
      tb_report(!o_pready && !o_pslverr, "timeout_3_cycles_wait_cycle_2",
                "three-cycle timeout completed before the second cycle elapsed");
      @(negedge i_clk_apb);
      #1;
      tb_report(o_pready && o_pslverr, "timeout_3_cycles_error_on_cycle_3",
                "three-cycle empty FIFO read did not return PSLVERR on cycle 3");
      reg_apb_errors++;
      reg_checks += 3;
      @(negedge i_clk_apb);
      i_psel = 1'b0;
      i_penable = 1'b0;
    end
  endtask

  // Any FIFO read/pop during the flush window is a failure.
  always @(posedge i_clk_apb) begin
    if (i_rst_n_sys && u_dut.u_dvp_apb_service.w_fifo_flush_busy &&
        u_dut.u_dvp_apb_service.w_fifo_rd_en)
      tb_report(1'b0, "no_fifo_pop_while_flush_pending",
                "FIFO_DATA pop asserted while flush is pending");
  end

  initial begin : p_test
    logic [31:0] value;
    logic error;

    reg_checks = 0;
    reg_apb_errors = 0;
    $dumpfile("dvp_updates.vcd");
    $dumpvars(0, tb_dvp_updates);

    repeat (6) @(posedge i_clk_apb);
    @(negedge i_clk_apb);
    i_rst_n_sys = 1'b1;
    repeat (12) @(posedge i_clk_apb);

    expect_read(16'h0000, 32'h0001_0001);
    expect_read(LPARA_ADDR_TIMEOUT, 32'hFFFF_FFFF);
    apb_write(LPARA_ADDR_TIMEOUT, 32'h0000_0003);
    expect_read(LPARA_ADDR_TIMEOUT, 32'h0000_0003);
    verify_timeout_three_cycles();
    apb_write(LPARA_ADDR_TIMEOUT, 32'h0000_0000);
    expect_read(LPARA_ADDR_TIMEOUT, 32'h0000_0000);
    expect_read(LPARA_ADDR_FRAME_COUNT, 32'h0000_0000);

    // Continuous mode: count an accepted frame, buffer a sample, then flush AFIFO.
    apb_write(LPARA_ADDR_CTRL, 32'h0000_0001);
    repeat (8) @(posedge i_clk_dvp);
    pulse_continuous_vsync();
    wait_read_value(LPARA_ADDR_FRAME_COUNT, 32'h0000_0001, 20);
    send_continuous_pixel(8'h5A);
    wait_read_value(LPARA_ADDR_FIFO_LEVEL, 32'h0000_0001, 30);

    // Flush while capture is enabled is ignored and returns OKAY.
    apb_write(LPARA_ADDR_CTRL, 32'h0000_0005);
    apb_read(LPARA_ADDR_CTRL, value, error);
    tb_report(!error && value[0] && !value[2], "flush_ignored_while_capture_enabled",
              $sformatf("flush while capture enabled was not ignored: DVP_CTRL=0x%08h", value));
    reg_checks++;

    apb_write(LPARA_ADDR_CTRL, 32'h0000_0000);
    repeat (12) @(posedge i_clk_dvp);
    wait_read_value(LPARA_ADDR_FIFO_LEVEL, 32'h0000_0001, 30);
    apb_write(LPARA_ADDR_CTRL, 32'h0000_0004);
    wait_flush_clear(32'h0000_0000);
    expect_read(LPARA_ADDR_FIFO_LEVEL, 32'h0000_0000);
    expect_read(LPARA_ADDR_FRAME_COUNT, 32'h0000_0001);
    // Check the zero-timeout response before the next rising edge completes the transfer.
    @(negedge i_clk_apb);
    i_paddr = LPARA_ADDR_FIFO_DATA;
    i_pwdata = '0;
    i_pstrb = '0;
    i_pwrite = 1'b0;
    i_psel = 1'b1;
    i_penable = 1'b0;
    @(negedge i_clk_apb);
    i_penable = 1'b1;
    #1;
    tb_report(o_pready && o_pslverr, "empty_fifo_zero_timeout_slverr",
              "zero-timeout FIFO_DATA empty read should return PSLVERR");
    reg_apb_errors++;
    @(negedge i_clk_apb);
    i_psel = 1'b0;
    i_penable = 1'b0;
    reg_checks++;

    // Gated mode: VSYNC is sampled with PCLK stopped; count the frame and fill SFIFO.
    apb_write(LPARA_ADDR_CTRL, 32'h0000_0002);
    expect_read(LPARA_ADDR_CTRL, 32'h0000_0002);
    apb_write(LPARA_ADDR_CTRL, 32'h0000_0003);
    pulse_gated_vsync();
    wait_read_value(LPARA_ADDR_FRAME_COUNT, 32'h0000_0002, 20);
    for (int pix = 0; pix < 9; pix++)
      send_gated_pixel(8'h80 + pix[7:0]);
    wait_read_value(LPARA_ADDR_FIFO_LEVEL, 32'h0000_0008, 30);
    wait_fifo_full_overflow();

    apb_write(LPARA_ADDR_CTRL, 32'h0000_0002);
    repeat (6) @(posedge i_clk_apb);
    apb_write(LPARA_ADDR_CTRL, 32'h0000_0006);
    wait_flush_clear(32'h0000_0002);
    expect_read(LPARA_ADDR_FIFO_LEVEL, 32'h0000_0000);
    expect_read(LPARA_ADDR_FRAME_COUNT, 32'h0000_0002);
    apb_read(LPARA_ADDR_FIFO_STATUS, value, error);
    tb_report(!error && value[3], "fifo_flush_retains_sticky_overflow",
              $sformatf("FIFO flush did not retain sticky overflow: status=0x%08h", value));
    reg_checks++;

    // Common reset, unlike FIFO flush, clears the frame count and restores timeout default.
    @(negedge i_clk_apb);
    i_rst_n_sys = 1'b0;
    i_clk_dvp_run = 1'b1;
    repeat (8) @(posedge i_clk_apb);
    @(negedge i_clk_apb);
    i_rst_n_sys = 1'b1;
    repeat (12) @(posedge i_clk_apb);
    expect_read(LPARA_ADDR_FRAME_COUNT, 32'h0000_0000);
    expect_read(LPARA_ADDR_TIMEOUT, 32'hFFFF_FFFF);
    expect_read(LPARA_ADDR_CTRL, 32'h0000_0000);

    $display("TB_RESULT: PASS modified_DVP_timeout_frame_count_fifo_flush (%0d checks, %0d expected APB errors)",
             reg_checks, reg_apb_errors);
    $finish;
  end

  initial begin
    #2000000;
    tb_report(1'b0, "simulation_watchdog", "simulation watchdog expired");
  end

endmodule
