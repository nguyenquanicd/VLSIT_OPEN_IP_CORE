#!/bin/bash
# usage: runperf.sh CFG KD   (CFG = LP | BASE | HP); runs every row of perf_plan.txt for the data width of CFG
export PATH="/c/Tools/oss-cad-suite/bin:/c/Tools/oss-cad-suite/lib:$PATH"
SRC=$(cat srclist.txt)
case $1 in
  LP)   DW=32;  Q=1; R=1; N=1; PA=0; OUTD=512 ;;
  BASE) DW=64;  Q=4; R=1; N=1; PA=1; OUTD=256 ;;
  HP)   DW=128; Q=4; R=2; N=2; PA=2; OUTD=128 ;;
esac
KD=${2:-2}
while read tag dw a m nin nout; do
  [ "$dw" = "$DW" ] || continue
  iverilog -g2012 -o perf_$1.vvp -P tb_perf.PFX=\"$tag\" -P tb_perf.DW=$DW -P tb_perf.QN=$Q -P tb_perf.RC=$R -P tb_perf.CN=$N -P tb_perf.PA=$PA \
    -P tb_perf.AADL=$a -P tb_perf.MSGL=$m -P tb_perf.DIR=0 -P tb_perf.NIN=$nin -P tb_perf.NOUT=$nout -P tb_perf.EXP_TAGERR=0 -P tb_perf.KD=$KD \
    -P tb_perf.OUTD=$OUTD -P tb_perf.PRELOAD=1 -P tb_perf.PC=${PC:-0} -P tb_perf.PP=${PP:-0} -P tb_perf.PI=${PI:-0} tb_perf.sv $SRC 2>&1 | grep -v sorry | head -3
  vvp perf_$1.vvp | grep RESULT | sed "s/RESULT /AAD=$a MSG=$m /"
done < perf_plan.txt
rm -f perf_$1.vvp
