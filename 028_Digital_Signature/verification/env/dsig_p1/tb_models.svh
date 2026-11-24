// tb_models.svh - behavioral models of the blocks that are not written yet: engines, key block,
// random block, verify-after-sign block and secret zeroization. They follow section 10.1 (states
// ENUM_ST_KEY, RNG, RUN, VAS, CLEAR), section 10.2 (operations) and section 11.3 (timeouts in units
// of 1024 core clocks, secrets cleared within 100 core clocks) of the specification. Their behavior
// is chosen by the knobs below, set by the tests. Included inside module tb_dsig_p1.

  // Knobs
  integer k_eng_lat;       // engine latency in core clocks
  integer k_eng_words;     // result words (64 bit) written by a signing or key generation run
  reg     k_eng_err;       // the engine reports an error
  reg [11:0] k_eng_err_flags; // error class flags that go with the engine error pulse
  reg     k_eng_sigok;     // result of a verification
  integer k_key_lat;
  reg     k_key_hang;      // the key block never answers: timeout after dsig_tmo.key * 1024
  integer k_rng_lat;
  reg     k_rng_hang;
  integer k_vas_lat;
  reg     k_vas_ok;
  integer k_zero_lat;      // clocks between the zeroization request and the cleared level
  reg     k_zero_hang;     // the secrets are never reported as cleared

  initial begin
    k_eng_lat = 12; k_eng_words = 4; k_eng_err = 1'b0; k_eng_err_flags = 12'h0; k_eng_sigok = 1'b1;
    k_key_lat = 6;  k_key_hang = 1'b0;
    k_rng_lat = 6;  k_rng_hang = 1'b0;
    k_vas_lat = 5;  k_vas_ok = 1'b1;
    k_zero_lat = 8; k_zero_hang = 1'b0;
    eng_rd_en = 1'b0; eng_wr_en = 1'b0; eng_rd_addr = 7'h0; eng_wr_addr = 7'h0;
    eng_wr_data = 64'h0; eng_wr_strb = 8'h0;
    eng_done = 1'b0; eng_err = 1'b0; eng_sigok = 1'b0; eng_err_flags = 12'h0;
    key_done = 1'b0; key_tmo = 1'b0; rng_done = 1'b0; rng_tmo = 1'b0; vas_done = 1'b0;
    vas_ok = 1'b0; rng_due = 1'b0; rng_ready = 1'b1; rng_reseed_clr = 1'b0;
  end

  // Operation snapshot seen by the models (the CSR values at the start pulse)
  reg [3:0]  m_alg;
  reg [1:0]  m_op;
  reg [16:0] m_off_res;
  reg [16:0] m_off_msg;

  // Event counters of the monitors (reset by the tests at the start of an operation)
  integer n_eng_start0, n_eng_start1, n_eng_start2, n_key_start, n_rng_start, n_vas_start;
  integer n_zero_req;
  integer eng_words_written;

  initial begin
    n_eng_start0 = 0; n_eng_start1 = 0; n_eng_start2 = 0; n_key_start = 0; n_rng_start = 0;
    n_vas_start = 0; n_zero_req = 0; eng_words_written = 0;
  end

  task clear_counters;
    begin
      n_eng_start0 = 0; n_eng_start1 = 0; n_eng_start2 = 0; n_key_start = 0; n_rng_start = 0;
      n_vas_start = 0; n_zero_req = 0; eng_words_written = 0;
    end
  endtask

  wire w_abort_taken = dut.w_cmd_abort_clr;   // the control block took the abort command
  reg  zero_req_q;

  always @(posedge clk_core or negedge rst_n_core) begin
    if (!rst_n_core) zero_req_q <= 1'b0;
    else             zero_req_q <= zero_req;
  end

  always @(posedge clk_core) begin
    if (eng_start[0]) n_eng_start0 = n_eng_start0 + 1;
    if (eng_start[1]) n_eng_start1 = n_eng_start1 + 1;
    if (eng_start[2]) n_eng_start2 = n_eng_start2 + 1;
    if (key_start)    n_key_start  = n_key_start + 1;
    if (rng_start)    n_rng_start  = n_rng_start + 1;
    if (vas_start)    n_vas_start  = n_vas_start + 1;
    if (zero_req & ~zero_req_q) n_zero_req = n_zero_req + 1;
  end

  // ----------------------------------------------------------------------------------------
  // Engine model: latency, then (signing, key generation) result words written through the engine
  // port, then done with the verification result, or an error pulse
  // ----------------------------------------------------------------------------------------
  integer e_state;   // 0 idle, 1 latency, 2 writing, 3 finishing
  integer e_cnt;
  integer e_wi;

  always @(posedge clk_core or negedge rst_n_core) begin
    if (!rst_n_core) begin
      e_state <= 0; e_cnt <= 0; e_wi <= 0;
      eng_done <= 1'b0; eng_err <= 1'b0; eng_sigok <= 1'b0; eng_err_flags <= 12'h0;
      eng_wr_en <= 1'b0; eng_rd_en <= 1'b0;
    end else begin
      eng_done <= 1'b0; eng_err <= 1'b0; eng_wr_en <= 1'b0; eng_rd_en <= 1'b0; eng_wr_strb <= 8'h00;
      if (w_abort_taken) begin
        e_state <= 0;
      end else begin
        case (e_state)
          0: begin
            if (|eng_start) begin
              m_alg     = dut.w_run_alg;
              m_op      = dut.w_run_op;
              m_off_res = dut.u_ctl.o_run_off_res;
              m_off_msg = dut.u_ctl.o_run_off_msg;
              e_cnt <= k_eng_lat;
              e_wi  <= 0;
              e_state <= 1;
              // Read the first message word through the engine port (engine read path)
              eng_rd_en   <= 1'b1;
              eng_rd_addr <= m_off_msg[9:3];
            end
          end
          1: begin
            if (e_cnt > 0) e_cnt <= e_cnt - 1;
            else if (k_eng_err) begin
              eng_err <= 1'b1; eng_err_flags <= k_eng_err_flags; e_state <= 0;
            end else if (m_op != 2'd2 && k_eng_words > 0) begin
              e_state <= 2;
            end else begin
              e_state <= 3;
            end
          end
          2: begin
            eng_wr_en   <= 1'b1;
            eng_wr_addr <= m_off_res[9:3] + e_wi[6:0];
            eng_wr_data <= {16'hA55A, 16'(m_alg), 16'(m_op), 16'(e_wi)};
            eng_wr_strb <= 8'hFF;
            eng_wr_en   <= 1'b1;
            eng_words_written <= e_wi + 1;
            e_wi <= e_wi + 1;
            if (e_wi + 1 >= k_eng_words) e_state <= 3;
          end
          3: begin
            eng_done  <= 1'b1;
            eng_sigok <= k_eng_sigok;
            e_state   <= 0;
          end
          default: e_state <= 0;
        endcase
      end
    end
  end

  // ----------------------------------------------------------------------------------------
  // Key block model: answers after k_key_lat, or never (timeout after dsig_tmo.key * 1024 clocks)
  // ----------------------------------------------------------------------------------------
  integer kb_cnt;
  reg     kb_act;

  always @(posedge clk_core or negedge rst_n_core) begin
    if (!rst_n_core) begin
      kb_cnt <= 0; kb_act <= 1'b0; key_done <= 1'b0; key_tmo <= 1'b0;
    end else begin
      key_done <= 1'b0; key_tmo <= 1'b0;
      if (w_abort_taken) begin
        kb_act <= 1'b0;
      end else if (key_start) begin
        kb_act <= 1'b1;
        kb_cnt <= k_key_hang ? (tmo_key * 1024) : k_key_lat;
      end else if (kb_act) begin
        if (kb_cnt > 1) kb_cnt <= kb_cnt - 1;
        else begin
          kb_act <= 1'b0;
          if (k_key_hang) key_tmo <= 1'b1; else key_done <= 1'b1;
        end
      end
    end
  end

  // ----------------------------------------------------------------------------------------
  // Random block model: answers after k_rng_lat, or never (timeout after dsig_tmo.ent * 1024)
  // ----------------------------------------------------------------------------------------
  integer rb_cnt;
  reg     rb_act;

  always @(posedge clk_core or negedge rst_n_core) begin
    if (!rst_n_core) begin
      rb_cnt <= 0; rb_act <= 1'b0; rng_done <= 1'b0; rng_tmo <= 1'b0;
    end else begin
      rng_done <= 1'b0; rng_tmo <= 1'b0;
      if (w_abort_taken) begin
        rb_act <= 1'b0;
      end else if (rng_start) begin
        rb_act <= 1'b1;
        rb_cnt <= k_rng_hang ? (tmo_ent * 1024) : k_rng_lat;
      end else if (rb_act) begin
        if (rb_cnt > 1) rb_cnt <= rb_cnt - 1;
        else begin
          rb_act <= 1'b0;
          if (k_rng_hang) rng_tmo <= 1'b1; else rng_done <= 1'b1;
        end
      end
    end
  end

  // Reseed command of the random block: taken one cycle after the request
  always @(posedge clk_core or negedge rst_n_core) begin
    if (!rst_n_core) rng_reseed_clr <= 1'b0;
    else             rng_reseed_clr <= rng_reseed;
  end

  // ----------------------------------------------------------------------------------------
  // Verify-after-sign model
  // ----------------------------------------------------------------------------------------
  integer vb_cnt;
  reg     vb_act;

  always @(posedge clk_core or negedge rst_n_core) begin
    if (!rst_n_core) begin
      vb_cnt <= 0; vb_act <= 1'b0; vas_done <= 1'b0; vas_ok <= 1'b0;
    end else begin
      vas_done <= 1'b0;
      if (w_abort_taken) begin
        vb_act <= 1'b0;
      end else if (vas_start) begin
        vb_act <= 1'b1; vb_cnt <= k_vas_lat;
      end else if (vb_act) begin
        if (vb_cnt > 1) vb_cnt <= vb_cnt - 1;
        else begin
          vb_act <= 1'b0; vas_done <= 1'b1; vas_ok <= k_vas_ok;
        end
      end
    end
  end

  // ----------------------------------------------------------------------------------------
  // Secret state: set when the key block runs, cleared k_zero_lat clocks after the zeroization
  // request. The level is high while the model state and the key words of the CSR are zero.
  // ----------------------------------------------------------------------------------------
  reg     secret_model;
  integer zr_cnt;
  wire    w_keys_nz = |{dut.w_key[0], dut.w_key[1], dut.w_key[2], dut.w_key[3], dut.w_key[4],
                        dut.w_key[5], dut.w_key[6], dut.w_key[7], dut.w_key[8], dut.w_key[9],
                        dut.w_key[10], dut.w_key[11], dut.w_key[12], dut.w_key[13],
                        dut.w_key[14], dut.w_key[15], dut.w_key[16]};

  always @(posedge clk_core or negedge rst_n_core) begin
    if (!rst_n_core) begin
      secret_model <= 1'b0; zr_cnt <= 0;
    end else begin
      if (key_start) secret_model <= 1'b1;
      if (zero_req) begin
        if (zr_cnt < k_zero_lat) zr_cnt <= zr_cnt + 1;
        else if (!k_zero_hang)   secret_model <= 1'b0;
      end else begin
        zr_cnt <= 0;
      end
    end
  end

  assign zero_done = ~secret_model & ~w_keys_nz;

  // Engine read path: capture of the data that the buffer returns to the engine
  reg [63:0] m_rd_cap;
  reg        m_rd_got;
  initial begin m_rd_cap = 64'h0; m_rd_got = 1'b0; end
  always @(posedge clk_core) begin
    if (eng_rd_valid === 1'b1) begin
      m_rd_cap = eng_rd_data;
      m_rd_got = 1'b1;
    end
  end
