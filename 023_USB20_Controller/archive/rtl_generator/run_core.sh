#!/bin/sh
# Regenerate the core and the four wrappers, then bring them to the layout rules.
cd "$(dirname "$0")" && python gen_core.py && python fixports.py ../../rtl/m_usb2_core.sv ../../rtl/m_usb2_top_*.sv && python rewrap.py ../../rtl/m_usb2_core.sv ../../rtl/m_usb2_top_*.sv
