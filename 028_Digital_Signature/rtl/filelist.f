// filelist.f - RTL of the Digital Signature IP: generated CSR, control block, buffer, AXI4 block, key and random
// blocks, hash stack (arbiter, sequencer, feeder, block-level wrapper of the 019 cores), the three engines
// (elliptic curve, lattice, hash-based) with their generated ROMs, and the structural top m_vlsit_dsig_top.
// Paths are relative to the folder of this file; run tools from that folder.
// Compile order: technology cells, library wrappers, library memory, 019 hash cores, generated CSR, IP blocks.

// Technology cells used by the library wrappers (000_Common/rtl_cells)
../../000_Common/rtl_cells/VLSIT_CELL_SRAM_1W1R.sv
../../000_Common/rtl_cells/VLSIT_CELL_SYNC_DFF_RN.sv
../../000_Common/rtl_cells/VLSIT_CELL_SYNC_DFF_SN.sv
../../000_Common/rtl_cells/VLSIT_CELL_SYNC_2FF_RN.sv
../../000_Common/rtl_cells/VLSIT_CELL_SYNC_2FF_SN.sv
../../000_Common/rtl_cells/VLSIT_CELL_SYNC_3FF_RN.sv
../../000_Common/rtl_cells/VLSIT_CELL_SYNC_3FF_SN.sv
../../000_Common/rtl_cells/VLSIT_CELL_SYNC_4FF_RN.sv
../../000_Common/rtl_cells/VLSIT_CELL_SYNC_4FF_SN.sv

// Library wrappers (000_Common/rtl_lib) and the synchronous FIFO memory (002_SyncFIFO)
../../000_Common/rtl_lib/m_vlsit_sfifo_ram_macro.sv
../../000_Common/rtl_lib/m_vlsit_afifo_cell_sync.sv
../../002_SyncFIFO/rtl/m_vlsit_sfifo_mem.sv

// Hash cores of the IP 019 (SHA-256, SHA-512, Keccak, padder)
../../019_SHA2_SHA3_Hash/rtl/m_vlsit_sha_core256.sv
../../019_SHA2_SHA3_Hash/rtl/m_vlsit_sha_core512.sv
../../019_SHA2_SHA3_Hash/rtl/m_vlsit_sha_keccak.sv
../../019_SHA2_SHA3_Hash/rtl/m_vlsit_sha_pad.sv

// Generated CSR (do not edit; see csr/CSR_GENERATED.md)
csr/m_vlsit_csr_sync.sv
csr/m_vlsit_csr_dsig.sv

// IP blocks
m_vlsit_sha_eng.sv
m_vlsit_dsig_hseq.sv
m_vlsit_dsig_harb.sv
m_vlsit_dsig_hfeed.sv
m_vlsit_dsig_brd.sv
m_vlsit_dsig_bwr.sv
m_vlsit_dsig_mmul.sv
m_vlsit_dsig_ec_rom.sv
m_vlsit_dsig_ec.sv
m_vlsit_dsig_hbs_rom.sv
m_vlsit_dsig_hbs.sv
m_vlsit_dsig_lat_rom.sv
m_vlsit_dsig_lat.sv
m_vlsit_dsig_buf.sv
m_vlsit_dsig_ctl.sv
m_vlsit_dsig_axi.sv
m_vlsit_dsig_key.sv
m_vlsit_dsig_drbg.sv
m_vlsit_dsig_rng.sv
m_vlsit_dsig_top.sv
