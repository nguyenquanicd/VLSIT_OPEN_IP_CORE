// tb_chk.svh - common table of clocked assertions (include inside a module).
// Written as clocked checks because the simulator (Icarus Verilog) has no concurrent assertions
// (guide section 3). Each assertion has an id, a name that carries the standard clause or the
// requirement ID, a hit counter (the antecedent was true) and a fail counter (the consequent
// failed). The run fails when an assertion failed or has no hit (R-025).
integer      as_hit [0:127];
integer      as_bad [0:127];
reg [8*88-1:0] as_nm [0:127];
integer      as_n;
integer      as_i;

initial begin
  as_n = 0;
  for (as_i = 0; as_i < 128; as_i = as_i + 1) begin
    as_hit[as_i] = 0;
    as_bad[as_i] = 0;
    as_nm[as_i]  = "";
  end
end

task as_reg;
  input integer id;
  input [8*88-1:0] name;
  begin
    as_nm[id] = name;
    if (id >= as_n) as_n = id + 1;
  end
endtask

task as_chk;
  input integer id;
  input         ante;   // antecedent: the assertion is active
  input         cons;   // consequent: what must hold
  begin
    if (ante === 1'b1) begin
      as_hit[id] = as_hit[id] + 1;
      if (cons !== 1'b1) begin
        as_bad[id] = as_bad[id] + 1;
        if (as_bad[id] <= 5)
          $display("ASSERT FAIL @%0t: %0s", $time, as_nm[id]);
      end
    end
  end
endtask

task as_report;
  input [8*16-1:0] tag;
  output integer   nfail;
  output integer   nnever;
  integer k;
  begin
    nfail  = 0;
    nnever = 0;
    for (k = 0; k < as_n; k = k + 1) begin
      if (as_nm[k] != "") begin
        $display("ASSERTION %0s %0s id=%0d hits=%0d fails=%0d  %0s", tag,
                 (as_bad[k] != 0) ? "FAIL " : ((as_hit[k] == 0) ? "NEVER" : "ok   "),
                 k, as_hit[k], as_bad[k], as_nm[k]);
        if (as_bad[k] != 0) nfail = nfail + 1;
        if (as_hit[k] == 0) nnever = nnever + 1;
      end
    end
  end
endtask
