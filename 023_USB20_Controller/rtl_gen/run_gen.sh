#!/bin/sh
# Regenerate the CSR integration module and bring it to the layout rules.
cd "$(dirname "$0")" && python gen_regs.py && python fixports.py ../rtl/m_usb2_regs.sv && python rewrap.py ../rtl/m_usb2_regs.sv
