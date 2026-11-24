#!/bin/bash
# usage: runtop.sh PFX DW SA SP AADL MSGL DIR NIN NOUT EXP_TAGERR [HOLD] [QN RC CN PA] [AXI_HALF APB_HALF CORE_HALF]
export PATH="/c/Tools/oss-cad-suite/bin:/c/Tools/oss-cad-suite/lib:$PATH"
SRC=$(cat srctop.txt | tr '\n' ' ')
tag="top_$1_$2_$3_$4_${12:-4}_${13:-1}_${14:-1}_${15:-1}"
iverilog -g2012 -DVLSIT_SYNTHESIS -o $tag.vvp -P tb_top.PFX=\"$1\" -P tb_top.DW=$2 -P tb_top.SA=$3 -P tb_top.SP=$4 -P tb_top.AADL=$5 -P tb_top.MSGL=$6 \
  -P tb_top.DIR=$7 -P tb_top.NIN=$8 -P tb_top.NOUT=$9 -P tb_top.EXP_TAGERR=${10} -P tb_top.HOLD=${11:-1} -P tb_top.QN=${12:-4} -P tb_top.RC=${13:-1} \
  -P tb_top.CN=${14:-1} -P tb_top.PA=${15:-1} -P tb_top.AXI_HALF=${16:-6} -P tb_top.APB_HALF=${17:-8} -P tb_top.CORE_HALF=${18:-5} -P tb_top.OUTD=${OUTD:-256} -P tb_top.DMA=${DMA:-0} -P tb_top.WM=${WM:-4} -P tb_top.TAIL=${TAIL:-0} -P tb_top.PC=${PC:-0} -P tb_top.PP=${PP:-0} -P tb_top.PI=${PI:-0} tb_top.sv $SRC 2>&1 | grep -v "sorry" | head -8
vvp $tag.vvp | grep -v "finish\|WARNING" | head -${LINES_MAX:-12}
rm -f $tag.vvp
