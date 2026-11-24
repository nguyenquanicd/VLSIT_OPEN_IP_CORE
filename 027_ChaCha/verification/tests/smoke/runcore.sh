#!/bin/bash
# usage: runcore.sh PFX DW Q R N PA AADL MSGL DIR NIN NOUT EXP_TAGERR [HOLD] [KD] [PUSHDLY] [CG]
export PATH="/c/Tools/oss-cad-suite/bin:/c/Tools/oss-cad-suite/lib:$PATH"
SRC=$(cat srclist.txt)
tag="$1_$2_$3_$4_$5_$6"
iverilog -g2012 -o tb_$tag.vvp -P tb_core.PFX=\"$1\" -P tb_core.DW=$2 -P tb_core.QN=$3 -P tb_core.RC=$4 -P tb_core.CN=$5 -P tb_core.PA=$6 \
  -P tb_core.AADL=$7 -P tb_core.MSGL=$8 -P tb_core.DIR=$9 -P tb_core.NIN=${10} -P tb_core.NOUT=${11} -P tb_core.EXP_TAGERR=${12} \
  -P tb_core.HOLD=${13:-1} -P tb_core.KD=${14:-1} -P tb_core.PUSHDLY=${15:-1} -P tb_core.CG=${16:-1} tb_core.sv $SRC 2>&1 | grep -v "sorry" | head -5
vvp tb_$tag.vvp | grep -v "finish\|WARNING"
rm -f tb_$tag.vvp
