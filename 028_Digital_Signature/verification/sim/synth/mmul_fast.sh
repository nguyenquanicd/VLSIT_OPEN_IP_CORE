export PATH="/c/Tools/oss-cad-suite/bin:/c/Tools/oss-cad-suite/lib:$PATH"
R=../../../rtl
rm -f mmul_fast_done.txt
for w in 32 64; do
  timeout 1500 yosys -q -l mmul${w}_fast.log -p "read_verilog -sv $R/m_vlsit_dsig_mmul.sv; chparam -set PARA_MUL_W $w m_vlsit_dsig_mmul; synth -top m_vlsit_dsig_mmul -flatten -noabc; abc -g AND,NAND,OR,NOR,XOR,XNOR,MUX -script +strash;map; opt -fast; clean; stat" > /dev/null 2>&1
  echo "w=$w exit=$?" >> mmul_fast_done.txt
done
