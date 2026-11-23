### Hierarchy (top-down)

| Level | Instance path | Module | Count at this level | Count basis | Source |
| --- | --- | --- | --- | --- | --- |
| 0 | m_dvp_controller | m_dvp_controller | 1 | top module | rtl/m_dvp_controller.sv:12 |
| 1 | u_rst_sync_apb | m_vlsit_rst_sync | 1 |  | rtl/m_dvp_controller.sv:86 |
| 1 | u_rst_sync_dvp | m_vlsit_rst_sync | 1 |  | rtl/m_dvp_controller.sv:93 |
| 1 | u_dvp_capture | m_dvp_capture | 1 |  | rtl/m_dvp_controller.sv:100 |
| 1 | u_dvp_apb_service | m_dvp_apb_service | 1 |  | rtl/m_dvp_controller.sv:123 |
| 2 | u_dvp_apb_service.u_apb_decode | m_dvp_apb_decode | 1 |  | rtl/m_dvp_apb_service.sv:105 |
| 2 | u_dvp_apb_service.u_tie_protect | m_vlsit_tie | 1 |  | rtl/m_dvp_apb_service.sv:130 |
| 2 | u_dvp_apb_service.u_tie_slverr | m_vlsit_tie | 1 |  | rtl/m_dvp_apb_service.sv:137 |
| 2 | u_dvp_apb_service.u_csr | m_vlsit_csr_dvp | 1 |  | rtl/m_dvp_apb_service.sv:145 |
| 3 | u_dvp_apb_service.u_csr.u_rd_ack_sync | m_vlsit_csr_sync | 1 | if(PARA_ASYNCHRONOUS == 32'd1) conditional | rtl/csr/m_vlsit_csr_dvp.sv:210 |
| 4 | u_dvp_apb_service.u_csr.u_rd_ack_sync.u_sync | m_vlsit_afifo_cell_sync | 1 |  | rtl/csr/m_vlsit_csr_sync.sv:33 |
| 3 | u_dvp_apb_service.u_csr.u_wr_ack_sync | m_vlsit_csr_sync | 1 | if(PARA_ASYNCHRONOUS == 32'd1) conditional | rtl/csr/m_vlsit_csr_dvp.sv:233 |
| 4 | u_dvp_apb_service.u_csr.u_wr_ack_sync.u_sync | m_vlsit_afifo_cell_sync | 1 |  | rtl/csr/m_vlsit_csr_sync.sv:33 |
| 3 | u_dvp_apb_service.u_csr.u_rd_req_sync | m_vlsit_csr_sync | 1 | if(PARA_ASYNCHRONOUS == 32'd1) conditional | rtl/csr/m_vlsit_csr_dvp.sv:254 |
| 4 | u_dvp_apb_service.u_csr.u_rd_req_sync.u_sync | m_vlsit_afifo_cell_sync | 1 |  | rtl/csr/m_vlsit_csr_sync.sv:33 |
| 3 | u_dvp_apb_service.u_csr.u_wr_req_sync | m_vlsit_csr_sync | 1 | if(PARA_ASYNCHRONOUS == 32'd1) conditional | rtl/csr/m_vlsit_csr_dvp.sv:272 |
| 4 | u_dvp_apb_service.u_csr.u_wr_req_sync.u_sync | m_vlsit_afifo_cell_sync | 1 |  | rtl/csr/m_vlsit_csr_sync.sv:33 |
| 2 | u_dvp_apb_service.u_apb_data | m_dvp_apb_data | 1 |  | rtl/m_dvp_apb_service.sv:180 |
| 2 | u_dvp_apb_service.u_dvp_buf | m_dvp_buffer | 1 |  | rtl/m_dvp_apb_service.sv:199 |
| 3 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo | m_dvp_afifo | 1 |  | rtl/m_dvp_buffer.sv:136 |
| 4 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_tie_sw_rst | m_vlsit_tie | 1 |  | rtl/m_dvp_afifo.sv:80 |
| 4 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_wr | m_vlsit_afifo_wr | 1 |  | rtl/m_dvp_afifo.sv:88 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_wr.u_sync_rd_gray | m_vlsit_afifo_sync | 1 |  | rtl/m_vlsit_afifo_wr.sv:233 |
| 6 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_wr.u_sync_rd_gray.u_vlsit_afifo_cell_sync | m_vlsit_afifo_cell_sync | 4 | for(gen_bit < PARA_AFIFO_SYNC_W) | rtl/m_vlsit_afifo_sync.sv:47 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_wr.u_sync_ack | m_vlsit_afifo_sync | 1 |  | rtl/m_vlsit_afifo_wr.sv:245 |
| 6 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_wr.u_sync_ack.u_vlsit_afifo_cell_sync | m_vlsit_afifo_cell_sync | 1 | for(gen_bit < PARA_AFIFO_SYNC_W) | rtl/m_vlsit_afifo_sync.sv:47 |
| 4 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_rd | m_dvp_afifo_rd | 1 |  | rtl/m_dvp_afifo.sv:113 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_rd.u_sync_wr_gray | m_vlsit_afifo_sync | 1 |  | rtl/m_dvp_afifo_rd.sv:209 |
| 6 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_rd.u_sync_wr_gray.u_vlsit_afifo_cell_sync | m_vlsit_afifo_cell_sync | 4 | for(gen_bit < PARA_AFIFO_SYNC_W) | rtl/m_vlsit_afifo_sync.sv:47 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_rd.u_sync_req | m_vlsit_afifo_sync | 1 |  | rtl/m_dvp_afifo_rd.sv:221 |
| 6 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_rd.u_sync_req.u_vlsit_afifo_cell_sync | m_vlsit_afifo_cell_sync | 1 | for(gen_bit < PARA_AFIFO_SYNC_W) | rtl/m_vlsit_afifo_sync.sv:47 |
| 4 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_mem | m_vlsit_afifo_mem | 1 |  | rtl/m_dvp_afifo.sv:140 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_mem.u_vlsit_afifo_ram_macro | m_vlsit_afifo_ram_macro | 1 | else conditional | rtl/m_vlsit_afifo_mem.sv:75 |
| 3 | u_dvp_apb_service.u_dvp_buf.u_tie_sfifo_rst | m_vlsit_tie | 1 |  | rtl/m_dvp_buffer.sv:162 |
| 3 | u_dvp_apb_service.u_dvp_buf.u_afifo_overflow_sync | m_vlsit_event_sync | 1 |  | rtl/m_dvp_buffer.sv:170 |
| 4 | u_dvp_apb_service.u_dvp_buf.u_afifo_overflow_sync.u_vlsit_afifo_cell_sync_0 | m_vlsit_afifo_cell_sync | 1 | for(gen_event_idx < PARA_EVENT_SYNC_W) | rtl_lib/m_vlsit_event_sync.sv:48 |
| 4 | u_dvp_apb_service.u_dvp_buf.u_afifo_overflow_sync.u_vlsit_afifo_cell_sync_1 | m_vlsit_afifo_cell_sync | 1 | for(gen_event_idx < PARA_EVENT_SYNC_W) | rtl_lib/m_vlsit_event_sync.sv:58 |
| 3 | u_dvp_apb_service.u_dvp_buf.u_dvp_gate_bridge | m_dvp_gate_bridge | 1 |  | rtl/m_dvp_buffer.sv:183 |
| 3 | u_dvp_apb_service.u_dvp_buf.u_dvp_sfifo | m_vlsit_sfifo_top | 1 |  | rtl/m_dvp_buffer.sv:201 |
| 4 | u_dvp_apb_service.u_dvp_buf.u_dvp_sfifo.u_vlsit_sfifo_wr | m_vlsit_sfifo_wr | 1 |  | rtl/m_vlsit_sfifo_top.sv:81 |
| 4 | u_dvp_apb_service.u_dvp_buf.u_dvp_sfifo.u_vlsit_sfifo_rd | m_vlsit_sfifo_rd | 1 |  | rtl/m_vlsit_sfifo_top.sv:106 |
| 4 | u_dvp_apb_service.u_dvp_buf.u_dvp_sfifo.u_vlsit_sfifo_mem | m_vlsit_sfifo_mem | 1 |  | rtl/m_vlsit_sfifo_top.sv:128 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_dvp_sfifo.u_vlsit_sfifo_mem.u_vlsit_sfifo_ram_macro | m_vlsit_sfifo_ram_macro | 1 | else conditional | rtl/m_vlsit_sfifo_mem.sv:75 |
| 2 | u_dvp_apb_service.u_dma_req | m_dvp_dma_req | 1 |  | rtl/m_dvp_apb_service.sv:230 |

### Instance totals under the top

| Module | Total instances under the top | Parent modules | Source |
| --- | --- | --- | --- |
| m_dvp_afifo | 1 | m_dvp_buffer | rtl/m_dvp_afifo.sv:13 |
| m_dvp_afifo_rd | 1 | m_dvp_afifo | rtl/m_dvp_afifo_rd.sv:18 |
| m_dvp_apb_data | 1 | m_dvp_apb_service | rtl/m_dvp_apb_data.sv:12 |
| m_dvp_apb_decode | 1 | m_dvp_apb_service | rtl/m_dvp_apb_decode.sv:12 |
| m_dvp_apb_service | 1 | m_dvp_controller | rtl/m_dvp_apb_service.sv:12 |
| m_dvp_buffer | 1 | m_dvp_apb_service | rtl/m_dvp_buffer.sv:12 |
| m_dvp_capture | 1 | m_dvp_controller | rtl/m_dvp_capture.sv:12 |
| m_dvp_dma_req | 1 | m_dvp_apb_service | rtl/m_dvp_dma_req.sv:12 |
| m_dvp_gate_bridge | 1 | m_dvp_buffer | rtl/m_dvp_gate_bridge.sv:12 |
| m_vlsit_afifo_cell_sync | 16 | m_vlsit_afifo_sync, m_vlsit_csr_sync, m_vlsit_event_sync | rtl_lib/m_vlsit_afifo_cell_sync.sv:25 |
| m_vlsit_afifo_mem | 1 | m_dvp_afifo | rtl/m_vlsit_afifo_mem.sv:17 |
| m_vlsit_afifo_ram_macro | 1 | m_vlsit_afifo_mem | rtl_lib/m_vlsit_afifo_ram_macro.sv:16 |
| m_vlsit_afifo_sync | 4 | m_dvp_afifo_rd, m_vlsit_afifo_wr | rtl/m_vlsit_afifo_sync.sv:17 |
| m_vlsit_afifo_wr | 1 | m_dvp_afifo | rtl/m_vlsit_afifo_wr.sv:18 |
| m_vlsit_csr_dvp | 1 | m_dvp_apb_service | rtl/csr/m_vlsit_csr_dvp.sv:15 |
| m_vlsit_csr_sync | 4 | m_vlsit_csr_dvp | rtl/csr/m_vlsit_csr_sync.sv:17 |
| m_vlsit_event_sync | 1 | m_dvp_buffer | rtl_lib/m_vlsit_event_sync.sv:14 |
| m_vlsit_rst_sync | 2 | m_dvp_controller | rtl_lib/m_vlsit_rst_sync.sv:23 |
| m_vlsit_sfifo_mem | 1 | m_vlsit_sfifo_top | rtl/m_vlsit_sfifo_mem.sv:17 |
| m_vlsit_sfifo_ram_macro | 1 | m_vlsit_sfifo_mem | rtl_lib/m_vlsit_sfifo_ram_macro.sv:18 |
| m_vlsit_sfifo_rd | 1 | m_vlsit_sfifo_top | rtl/m_vlsit_sfifo_rd.sv:21 |
| m_vlsit_sfifo_top | 1 | m_dvp_buffer | rtl/m_vlsit_sfifo_top.sv:18 |
| m_vlsit_sfifo_wr | 1 | m_vlsit_sfifo_top | rtl/m_vlsit_sfifo_wr.sv:19 |
| m_vlsit_tie | 4 | m_dvp_afifo, m_dvp_apb_service, m_dvp_buffer | rtl_lib/m_vlsit_tie.sv:17 |

Modules not reachable from the top: m_vlsit_afifo_rd, m_vlsit_afifo_top, m_vlsit_clk_inv

Instances of modules outside the scanned tree:

| Parent | Instance | Module | Source |
| --- | --- | --- | --- |
| m_vlsit_afifo_cell_sync | u_dont_touch_dff_0 | VLSIT_CELL_SYNC_DFF_RN | rtl_lib/m_vlsit_afifo_cell_sync.sv:61 |
| m_vlsit_afifo_cell_sync | u_dont_touch_dff_1 | VLSIT_CELL_SYNC_DFF_RN | rtl_lib/m_vlsit_afifo_cell_sync.sv:62 |
| m_vlsit_afifo_cell_sync | u_dont_touch_dff_0 | VLSIT_CELL_SYNC_DFF_SN | rtl_lib/m_vlsit_afifo_cell_sync.sv:64 |
| m_vlsit_afifo_cell_sync | u_dont_touch_dff_1 | VLSIT_CELL_SYNC_DFF_SN | rtl_lib/m_vlsit_afifo_cell_sync.sv:65 |
| m_vlsit_afifo_cell_sync | u_dont_touch_sync2ff | VLSIT_CELL_SYNC_2FF_RN | rtl_lib/m_vlsit_afifo_cell_sync.sv:70 |
| m_vlsit_afifo_cell_sync | u_dont_touch_sync2ff | VLSIT_CELL_SYNC_2FF_SN | rtl_lib/m_vlsit_afifo_cell_sync.sv:72 |
| m_vlsit_afifo_cell_sync | u_dont_touch_sync3ff | VLSIT_CELL_SYNC_3FF_RN | rtl_lib/m_vlsit_afifo_cell_sync.sv:77 |
| m_vlsit_afifo_cell_sync | u_dont_touch_sync3ff | VLSIT_CELL_SYNC_3FF_SN | rtl_lib/m_vlsit_afifo_cell_sync.sv:79 |
| m_vlsit_afifo_cell_sync | u_dont_touch_sync4ff | VLSIT_CELL_SYNC_4FF_RN | rtl_lib/m_vlsit_afifo_cell_sync.sv:84 |
| m_vlsit_afifo_cell_sync | u_dont_touch_sync4ff | VLSIT_CELL_SYNC_4FF_SN | rtl_lib/m_vlsit_afifo_cell_sync.sv:86 |
| m_vlsit_afifo_ram_macro | u_dont_touch_sram | VLSIT_CELL_SRAM_1W1R | rtl_lib/m_vlsit_afifo_ram_macro.sv:41 |
| m_vlsit_clk_inv | u_dont_touch_ckinv | VLSIT_CELL_CKINV | rtl_lib/m_vlsit_clk_inv.sv:27 |
| m_vlsit_rst_sync | u_dont_touch_tieh | VLSIT_CELL_TIEH | rtl_lib/m_vlsit_rst_sync.sv:47 |
| m_vlsit_rst_sync | u_dont_touch_dff_0 | VLSIT_CELL_SYNC_DFF_RN | rtl_lib/m_vlsit_rst_sync.sv:52 |
| m_vlsit_rst_sync | u_dont_touch_dff_1 | VLSIT_CELL_SYNC_DFF_RN | rtl_lib/m_vlsit_rst_sync.sv:53 |
| m_vlsit_rst_sync | u_dont_touch_sync2ff | VLSIT_CELL_SYNC_2FF_RN | rtl_lib/m_vlsit_rst_sync.sv:56 |
| m_vlsit_rst_sync | u_dont_touch_sync3ff | VLSIT_CELL_SYNC_3FF_RN | rtl_lib/m_vlsit_rst_sync.sv:59 |
| m_vlsit_rst_sync | u_dont_touch_sync4ff | VLSIT_CELL_SYNC_4FF_RN | rtl_lib/m_vlsit_rst_sync.sv:62 |
| m_vlsit_sfifo_ram_macro | u_dont_touch_sram | VLSIT_CELL_SRAM_1W1R | rtl_lib/m_vlsit_sfifo_ram_macro.sv:43 |
| m_vlsit_tie | u_dont_touch_tieh | VLSIT_CELL_TIEH | rtl_lib/m_vlsit_tie.sv:36 |
| m_vlsit_tie | u_dont_touch_tiel | VLSIT_CELL_TIEL | rtl_lib/m_vlsit_tie.sv:38 |

### Module interfaces

#### `m_dvp_controller` (rtl/m_dvp_controller.sv:12)

| Parameter | Default | Kind |
| --- | --- | --- |
| `PARA_DVP_DATA_W` | `32'd8` | parameter |
| `PARA_DVP_SAMPLE_EDGE` | `32'd0` | parameter |
| `PARA_DVP_VSYNC_ACTIVE` | `32'd1` | parameter |
| `PARA_DVP_HREF_ACTIVE` | `32'd1` | parameter |
| `PARA_FIFO_DEPTH` | `32'd8` | parameter |
| `PARA_AFIFO_CELL_TYPE` | `32'd2` | parameter |
| `PARA_AFIFO_MEM_USE_MACRO` | `32'd0` | parameter |
| `PARA_FIFO_DATA_ADDR` | `32'h0000_0100` | parameter |

| Port | Direction | Width | Type | Function (fill from the source) | Line |
| --- | --- | --- | --- | --- | --- |
| `i_clk_apb` | input | 1 | wire | <fill> | 45 |
| `i_rst_n_sys` | input | 1 | wire | <fill> | 45 |
| `i_clk_dvp` | input | 1 | wire | <fill> | 45 |
| `i_dvp_data` | input | [PARA_DVP_DATA_W-1:0] | wire | <fill> | 45 |
| `i_dvp_vsync` | input | 1 | wire | <fill> | 45 |
| `i_dvp_href` | input | 1 | wire | <fill> | 45 |
| `i_paddr` | input | [15:0] | wire | <fill> | 45 |
| `i_psel` | input | 1 | wire | <fill> | 45 |
| `i_penable` | input | 1 | wire | <fill> | 45 |
| `i_pwrite` | input | 1 | wire | <fill> | 45 |
| `i_pwdata` | input | [31:0] | wire | <fill> | 45 |
| `i_pstrb` | input | [3:0] | wire | <fill> | 45 |
| `i_pprot` | input | [2:0] | wire | <fill> | 45 |
| `o_pready` | output | 1 | logic | <fill> | 45 |
| `o_prdata` | output | [31:0] | logic | <fill> | 45 |
| `o_pslverr` | output | 1 | logic | <fill> | 45 |
| `i_dma_ack` | input | 1 | wire | <fill> | 45 |
| `o_dma_req` | output | 1 | logic | <fill> | 45 |

#### `m_dvp_afifo` (rtl/m_dvp_afifo.sv:13)

| Parameter | Default | Kind |
| --- | --- | --- |
| `PARA_FIFO_DEPTH` | `32'd8` | parameter |
| `PARA_DATA_W` | `32'd8` | parameter |
| `PARA_CELL_TYPE` | `32'd2` | parameter |
| `PARA_MEM_USE_MACRO` | `32'd0` | parameter |
| `LPARA_ADDR_W` | `$clog2(PARA_FIFO_DEPTH)` | parameter |
| `LPARA_PTR_W` | `LPARA_ADDR_W + 32'd1` | parameter |
| `LPARA_OCC_W` | `$clog2(PARA_FIFO_DEPTH + 32'd1)` | parameter |

| Port | Direction | Width | Type | Function (fill from the source) | Line |
| --- | --- | --- | --- | --- | --- |
| `i_clk_wr` | input | 1 | wire | <fill> | 33 |
| `i_rst_n_wr` | input | 1 | wire | <fill> | 33 |
| `i_wr_en` | input | 1 | wire | <fill> | 33 |
| `i_wr_data` | input | [PARA_DATA_W-1:0] | wire | <fill> | 33 |
| `o_full` | output | 1 | logic | <fill> | 33 |
| `o_overflow` | output | 1 | logic | <fill> | 33 |
| `i_clk_rd` | input | 1 | wire | <fill> | 33 |
| `i_rst_n_rd` | input | 1 | wire | <fill> | 33 |
| `i_rd_en` | input | 1 | wire | <fill> | 33 |
| `o_rd_data` | output | [PARA_DATA_W-1:0] | logic | <fill> | 33 |
| `o_empty` | output | 1 | logic | <fill> | 33 |
| `o_underflow` | output | 1 | logic | <fill> | 33 |
| `o_occupancy` | output | [LPARA_OCC_W-1:0] | logic | <fill> | 33 |

#### `m_dvp_afifo_rd` (rtl/m_dvp_afifo_rd.sv:18)

| Parameter | Default | Kind |
| --- | --- | --- |
| `PARA_AFIFO_DEPTH` | `8` | parameter |
| `PARA_AFIFO_DATA_W` | `32` | parameter |
| `PARA_AFIFO_CELL_TYPE` | `2` | parameter |
| `LPARA_ADDR_W` | `$clog2(PARA_AFIFO_DEPTH)` | parameter |
| `LPARA_PTR_W` | `LPARA_ADDR_W + 32'd1` | parameter |
| `LPARA_OCC_W` | `$clog2(PARA_AFIFO_DEPTH + 1)` | parameter |

| Port | Direction | Width | Type | Function (fill from the source) | Line |
| --- | --- | --- | --- | --- | --- |
| `i_clk_rd` | input | 1 | wire | <fill> | 36 |
| `i_rst_n_rd` | input | 1 | wire | <fill> | 36 |
| `i_rd_en` | input | 1 | wire | <fill> | 36 |
| `i_empty_thr` | input | [LPARA_PTR_W-1:0] | wire | <fill> | 36 |
| `o_rd_data` | output | [PARA_AFIFO_DATA_W-1:0] | logic | <fill> | 36 |
| `o_empty` | output | 1 | logic | <fill> | 36 |
| `o_empty_thr` | output | 1 | logic | <fill> | 36 |
| `o_underflow` | output | 1 | logic | <fill> | 36 |
| `o_occupancy` | output | [LPARA_OCC_W-1:0] | logic | <fill> | 36 |
| `i_req_wr` | input | 1 | wire | <fill> | 36 |
| `o_ack_rd` | output | 1 | logic | <fill> | 36 |
| `i_wr_gray` | input | [LPARA_PTR_W-1:0] | wire | <fill> | 36 |
| `o_rd_gray` | output | [LPARA_PTR_W-1:0] | logic | <fill> | 36 |
| `o_mem_rd_addr` | output | [LPARA_ADDR_W-1:0] | logic | <fill> | 36 |
| `i_mem_rd_data` | input | [PARA_AFIFO_DATA_W-1:0] | wire | <fill> | 36 |

#### `m_dvp_apb_data` (rtl/m_dvp_apb_data.sv:12)

| Parameter | Default | Kind |
| --- | --- | --- |
| `PARA_DATA_W` | `32'd8` | parameter |
| `LPARA_BUS_W` | `32'd32` | parameter |

| Port | Direction | Width | Type | Function (fill from the source) | Line |
| --- | --- | --- | --- | --- | --- |
| `i_clk_apb` | input | 1 | wire | <fill> | 18 |
| `i_rst_n_apb` | input | 1 | wire | <fill> | 18 |
| `i_psel` | input | 1 | wire | <fill> | 18 |
| `i_penable` | input | 1 | wire | <fill> | 18 |
| `i_pwrite` | input | 1 | wire | <fill> | 18 |
| `i_fifo_aligned` | input | 1 | wire | <fill> | 18 |
| `i_timeout_cycles` | input | [31:0] | wire | <fill> | 18 |
| `i_fifo_data` | input | [PARA_DATA_W-1:0] | wire | <fill> | 18 |
| `i_fifo_empty` | input | 1 | wire | <fill> | 18 |
| `o_fifo_rd_en` | output | 1 | logic | <fill> | 18 |
| `o_pready` | output | 1 | logic | <fill> | 18 |
| `o_prdata` | output | [31:0] | logic | <fill> | 18 |
| `o_pslverr` | output | 1 | logic | <fill> | 18 |

#### `m_dvp_apb_decode` (rtl/m_dvp_apb_decode.sv:12)

| Parameter | Default | Kind |
| --- | --- | --- |
| `PARA_FIFO_DATA_ADDR` | `32'h0000_0100` | parameter |

| Port | Direction | Width | Type | Function (fill from the source) | Line |
| --- | --- | --- | --- | --- | --- |
| `i_psel` | input | 1 | wire | <fill> | 17 |
| `i_paddr` | input | [15:0] | wire | <fill> | 17 |
| `o_csr_sel` | output | 1 | logic | <fill> | 17 |
| `o_fifo_sel` | output | 1 | logic | <fill> | 17 |
| `o_fifo_aligned` | output | 1 | logic | <fill> | 17 |

#### `m_dvp_apb_service` (rtl/m_dvp_apb_service.sv:12)

| Parameter | Default | Kind |
| --- | --- | --- |
| `PARA_FIFO_DEPTH` | `32'd8` | parameter |
| `PARA_DATA_W` | `32'd8` | parameter |
| `PARA_VSYNC_ACTIVE` | `32'd1` | parameter |
| `PARA_AFIFO_CELL_TYPE` | `32'd2` | parameter |
| `PARA_AFIFO_MEM_USE_MACRO` | `32'd0` | parameter |
| `PARA_FIFO_DATA_ADDR` | `32'h0000_0100` | parameter |
| `LPARA_VERSION_MAJOR` | `32'd1` | parameter |
| `LPARA_VERSION_MINOR` | `32'd0` | parameter |
| `LPARA_CSR_CTRL_ADDR` | `32'h0000_0004` | parameter |

| Port | Direction | Width | Type | Function (fill from the source) | Line |
| --- | --- | --- | --- | --- | --- |
| `i_clk_apb` | input | 1 | wire | <fill> | 40 |
| `i_rst_n_apb` | input | 1 | wire | <fill> | 40 |
| `i_clk_dvp` | input | 1 | wire | <fill> | 40 |
| `i_rst_n_dvp` | input | 1 | wire | <fill> | 40 |
| `i_dvp_vsync` | input | 1 | wire | <fill> | 40 |
| `i_afifo_wr_en` | input | 1 | wire | <fill> | 40 |
| `i_afifo_wr_data` | input | [PARA_DATA_W-1:0] | wire | <fill> | 40 |
| `i_pixel_toggle` | input | 1 | wire | <fill> | 40 |
| `i_gated_data` | input | [PARA_DATA_W-1:0] | wire | <fill> | 40 |
| `i_cont_frame_active` | input | 1 | wire | <fill> | 40 |
| `i_capture_quiescent` | input | 1 | wire | <fill> | 40 |
| `i_paddr` | input | [15:0] | wire | <fill> | 40 |
| `i_psel` | input | 1 | wire | <fill> | 40 |
| `i_penable` | input | 1 | wire | <fill> | 40 |
| `i_pwrite` | input | 1 | wire | <fill> | 40 |
| `i_pwdata` | input | [31:0] | wire | <fill> | 40 |
| `i_pstrb` | input | [3:0] | wire | <fill> | 40 |
| `i_pprot` | input | [2:0] | wire | <fill> | 40 |
| `i_dma_ack` | input | 1 | wire | <fill> | 40 |
| `o_pready` | output | 1 | logic | <fill> | 40 |
| `o_prdata` | output | [31:0] | logic | <fill> | 40 |
| `o_pslverr` | output | 1 | logic | <fill> | 40 |
| `o_capture_en` | output | 1 | logic | <fill> | 40 |
| `o_pclk_mode` | output | 1 | logic | <fill> | 40 |
| `o_dma_req` | output | 1 | logic | <fill> | 40 |

#### `m_dvp_buffer` (rtl/m_dvp_buffer.sv:12)

| Parameter | Default | Kind |
| --- | --- | --- |
| `PARA_FIFO_DEPTH` | `32'd8` | parameter |
| `PARA_DATA_W` | `32'd8` | parameter |
| `PARA_AFIFO_CELL_TYPE` | `32'd2` | parameter |
| `PARA_AFIFO_MEM_USE_MACRO` | `32'd0` | parameter |
| `PARA_VSYNC_ACTIVE` | `32'd1` | parameter |
| `LPARA_OCC_W` | `$clog2(PARA_FIFO_DEPTH + 32'd1)` | parameter |
| `LPARA_EVT_CELL` | `32'd2` | parameter |
| `LPARA_BUS_W` | `32'd32` | parameter |

| Port | Direction | Width | Type | Function (fill from the source) | Line |
| --- | --- | --- | --- | --- | --- |
| `i_clk_apb` | input | 1 | wire | <fill> | 36 |
| `i_rst_n_apb` | input | 1 | wire | <fill> | 36 |
| `i_clk_dvp` | input | 1 | wire | <fill> | 36 |
| `i_rst_n_dvp` | input | 1 | wire | <fill> | 36 |
| `i_capture_en` | input | 1 | wire | <fill> | 36 |
| `i_pclk_mode` | input | 1 | wire | <fill> | 36 |
| `i_dvp_vsync` | input | 1 | wire | <fill> | 36 |
| `i_cont_frame_active` | input | 1 | wire | <fill> | 36 |
| `i_afifo_wr_en` | input | 1 | wire | <fill> | 36 |
| `i_afifo_wr_data` | input | [PARA_DATA_W-1:0] | wire | <fill> | 36 |
| `i_pixel_toggle` | input | 1 | wire | <fill> | 36 |
| `i_gated_data` | input | [PARA_DATA_W-1:0] | wire | <fill> | 36 |
| `i_capture_quiescent` | input | 1 | wire | <fill> | 36 |
| `i_rd_en` | input | 1 | wire | <fill> | 36 |
| `o_rd_data` | output | [PARA_DATA_W-1:0] | logic | <fill> | 36 |
| `o_empty` | output | 1 | logic | <fill> | 36 |
| `o_full` | output | 1 | logic | <fill> | 36 |
| `o_occupancy` | output | [31:0] | logic | <fill> | 36 |
| `o_active` | output | 1 | logic | <fill> | 36 |
| `o_overflow_event` | output | 1 | logic | <fill> | 36 |
| `o_mode_change_safe` | output | 1 | logic | <fill> | 36 |

#### `m_dvp_capture` (rtl/m_dvp_capture.sv:12)

| Parameter | Default | Kind |
| --- | --- | --- |
| `PARA_DATA_W` | `32'd8` | parameter |
| `PARA_SAMPLE_EDGE` | `32'd0` | parameter |
| `PARA_VSYNC_ACTIVE` | `32'd1` | parameter |
| `PARA_HREF_ACTIVE` | `32'd1` | parameter |

| Port | Direction | Width | Type | Function (fill from the source) | Line |
| --- | --- | --- | --- | --- | --- |
| `i_clk_dvp` | input | 1 | wire | <fill> | 29 |
| `i_rst_n_dvp` | input | 1 | wire | <fill> | 29 |
| `i_rst_n_gated` | input | 1 | wire | <fill> | 29 |
| `i_dvp_data` | input | [PARA_DATA_W-1:0] | wire | <fill> | 29 |
| `i_dvp_vsync` | input | 1 | wire | <fill> | 29 |
| `i_dvp_href` | input | 1 | wire | <fill> | 29 |
| `i_capture_en` | input | 1 | wire | <fill> | 29 |
| `i_pclk_mode` | input | 1 | wire | <fill> | 29 |
| `o_afifo_wr_en` | output | 1 | logic | <fill> | 29 |
| `o_afifo_wr_data` | output | [PARA_DATA_W-1:0] | logic | <fill> | 29 |
| `o_gated_data` | output | [PARA_DATA_W-1:0] | logic | <fill> | 29 |
| `o_valid_toggle` | output | 1 | logic | <fill> | 29 |
| `o_cont_frame_active` | output | 1 | logic | <fill> | 29 |
| `o_capture_quiescent` | output | 1 | logic | <fill> | 29 |

#### `m_dvp_dma_req` (rtl/m_dvp_dma_req.sv:12)

| Parameter | Default | Kind |
| --- | --- | --- |
| `PARA_FIFO_DEPTH` | `32'd8` | parameter |

| Port | Direction | Width | Type | Function (fill from the source) | Line |
| --- | --- | --- | --- | --- | --- |
| `i_clk_apb` | input | 1 | wire | <fill> | 17 |
| `i_rst_n_apb` | input | 1 | wire | <fill> | 17 |
| `i_occupancy` | input | [31:0] | wire | <fill> | 17 |
| `i_watermark` | input | [31:0] | wire | <fill> | 17 |
| `i_dma_ack` | input | 1 | wire | <fill> | 17 |
| `o_dma_req` | output | 1 | logic | <fill> | 17 |

#### `m_dvp_gate_bridge` (rtl/m_dvp_gate_bridge.sv:12)

| Parameter | Default | Kind |
| --- | --- | --- |
| `PARA_DATA_W` | `32'd8` | parameter |
| `PARA_VSYNC_ACTIVE` | `32'd1` | parameter |

| Port | Direction | Width | Type | Function (fill from the source) | Line |
| --- | --- | --- | --- | --- | --- |
| `i_clk_apb` | input | 1 | wire | <fill> | 21 |
| `i_rst_n_apb` | input | 1 | wire | <fill> | 21 |
| `i_dvp_vsync` | input | 1 | wire | <fill> | 21 |
| `i_pixel_data` | input | [PARA_DATA_W-1:0] | wire | <fill> | 21 |
| `i_pixel_toggle` | input | 1 | wire | <fill> | 21 |
| `i_capture_en` | input | 1 | wire | <fill> | 21 |
| `i_pclk_mode` | input | 1 | wire | <fill> | 21 |
| `o_frame_active` | output | 1 | logic | <fill> | 21 |
| `o_sfifo_wr_en` | output | 1 | logic | <fill> | 21 |
| `o_sfifo_wr_data` | output | [PARA_DATA_W-1:0] | logic | <fill> | 21 |
| `o_path_quiescent` | output | 1 | logic | <fill> | 21 |

#### `m_vlsit_afifo_cell_sync` (rtl_lib/m_vlsit_afifo_cell_sync.sv:25)

| Parameter | Default | Kind |
| --- | --- | --- |
| `PARA_AFIFO_CELL_RST_VAL` | `0` | parameter |
| `PARA_AFIFO_CELL_TYPE` | `2` | parameter |
| `LPARA_TYPE_BYPASS` | `32'd0` | parameter |
| `LPARA_TYPE_DFF2` | `32'd1` | parameter |
| `LPARA_TYPE_SYNC2` | `32'd2` | parameter |
| `LPARA_TYPE_SYNC3` | `32'd3` | parameter |
| `SIM_STAGE` | `(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) ? 2 : (PARA_AFIFO_CELL_TYPE > 32'd4) ? 4 : int'(PARA_AFIFO_CELL_TYPE)` | localparam |

| Port | Direction | Width | Type | Function (fill from the source) | Line |
| --- | --- | --- | --- | --- | --- |
| `i_clk_dst` | input | 1 | wire | <fill> | 40 |
| `i_rst_n_dst` | input | 1 | wire | <fill> | 40 |
| `i_d` | input | 1 | wire | <fill> | 40 |
| `o_q` | output | 1 | logic | <fill> | 40 |

#### `m_vlsit_afifo_mem` (rtl/m_vlsit_afifo_mem.sv:17)

| Parameter | Default | Kind |
| --- | --- | --- |
| `PARA_AFIFO_DEPTH` | `8` | parameter |
| `PARA_AFIFO_DATA_W` | `32` | parameter |
| `PARA_AFIFO_MEM_USE_MACRO` | `0` | parameter |
| `LPARA_ADDR_W` | `$clog2(PARA_AFIFO_DEPTH)` | parameter |

| Port | Direction | Width | Type | Function (fill from the source) | Line |
| --- | --- | --- | --- | --- | --- |
| `i_clk_wr` | input | 1 | wire | <fill> | 31 |
| `i_wr_en` | input | 1 | wire | <fill> | 31 |
| `i_wr_addr` | input | [LPARA_ADDR_W-1:0] | wire | <fill> | 31 |
| `i_wr_data` | input | [PARA_AFIFO_DATA_W-1:0] | wire | <fill> | 31 |
| `i_clk_rd` | input | 1 | wire | <fill> | 31 |
| `i_rd_addr` | input | [LPARA_ADDR_W-1:0] | wire | <fill> | 31 |
| `o_rd_data` | output | [PARA_AFIFO_DATA_W-1:0] | logic | <fill> | 31 |

#### `m_vlsit_afifo_ram_macro` (rtl_lib/m_vlsit_afifo_ram_macro.sv:16)

| Parameter | Default | Kind |
| --- | --- | --- |
| `PARA_AFIFO_DEPTH` | `8` | parameter |
| `PARA_AFIFO_DATA_W` | `32` | parameter |
| `LPARA_ADDR_W` | `$clog2(PARA_AFIFO_DEPTH)` | parameter |

| Port | Direction | Width | Type | Function (fill from the source) | Line |
| --- | --- | --- | --- | --- | --- |
| `i_clk_wr` | input | 1 | wire | <fill> | 26 |
| `i_wr_en_n` | input | 1 | wire | <fill> | 26 |
| `i_wr_addr` | input | [LPARA_ADDR_W-1:0] | wire | <fill> | 26 |
| `i_wr_data` | input | [PARA_AFIFO_DATA_W-1:0] | wire | <fill> | 26 |
| `i_clk_rd` | input | 1 | wire | <fill> | 26 |
| `i_rd_en_n` | input | 1 | wire | <fill> | 26 |
| `i_rd_addr` | input | [LPARA_ADDR_W-1:0] | wire | <fill> | 26 |
| `o_rd_data` | output | [PARA_AFIFO_DATA_W-1:0] | logic | <fill> | 26 |

#### `m_vlsit_afifo_sync` (rtl/m_vlsit_afifo_sync.sv:17)

| Parameter | Default | Kind |
| --- | --- | --- |
| `PARA_AFIFO_SYNC_W` | `1` | parameter |
| `PARA_AFIFO_SYNC_RST_VAL` | `0` | parameter |
| `PARA_AFIFO_CELL_TYPE` | `2` | parameter |

| Port | Direction | Width | Type | Function (fill from the source) | Line |
| --- | --- | --- | --- | --- | --- |
| `i_clk_dst` | input | 1 | wire | <fill> | 33 |
| `i_rst_n_dst` | input | 1 | wire | <fill> | 33 |
| `i_data` | input | [PARA_AFIFO_SYNC_W-1:0] | wire | <fill> | 33 |
| `o_data` | output | [PARA_AFIFO_SYNC_W-1:0] | logic | <fill> | 33 |

#### `m_vlsit_afifo_wr` (rtl/m_vlsit_afifo_wr.sv:18)

| Parameter | Default | Kind |
| --- | --- | --- |
| `PARA_AFIFO_DEPTH` | `8` | parameter |
| `PARA_AFIFO_DATA_W` | `32` | parameter |
| `PARA_AFIFO_CELL_TYPE` | `2` | parameter |
| `LPARA_ADDR_W` | `$clog2(PARA_AFIFO_DEPTH)` | parameter |
| `LPARA_PTR_W` | `LPARA_ADDR_W + 32'd1` | parameter |
| `LPARA_FULL_MSK` | `32'd3 << (LPARA_PTR_W - 32'd2)` | parameter |

| Port | Direction | Width | Type | Function (fill from the source) | Line |
| --- | --- | --- | --- | --- | --- |
| `i_clk_wr` | input | 1 | wire | <fill> | 36 |
| `i_rst_n_wr` | input | 1 | wire | <fill> | 36 |
| `i_wr_en` | input | 1 | wire | <fill> | 36 |
| `i_wr_data` | input | [PARA_AFIFO_DATA_W-1:0] | wire | <fill> | 36 |
| `i_full_thr` | input | [LPARA_PTR_W-1:0] | wire | <fill> | 36 |
| `o_full` | output | 1 | logic | <fill> | 36 |
| `o_full_thr` | output | 1 | logic | <fill> | 36 |
| `o_overflow` | output | 1 | logic | <fill> | 36 |
| `i_rst_n_sw` | input | 1 | wire | <fill> | 36 |
| `o_sw_rst_busy` | output | 1 | logic | <fill> | 36 |
| `o_req_wr` | output | 1 | logic | <fill> | 36 |
| `i_ack_rd` | input | 1 | wire | <fill> | 36 |
| `i_rd_gray` | input | [LPARA_PTR_W-1:0] | wire | <fill> | 36 |
| `o_wr_gray` | output | [LPARA_PTR_W-1:0] | logic | <fill> | 36 |
| `o_mem_wr_en` | output | 1 | logic | <fill> | 36 |
| `o_mem_wr_addr` | output | [LPARA_ADDR_W-1:0] | logic | <fill> | 36 |
| `o_mem_wr_data` | output | [PARA_AFIFO_DATA_W-1:0] | logic | <fill> | 36 |

#### `m_vlsit_csr_dvp` (rtl/csr/m_vlsit_csr_dvp.sv:15)

| Parameter | Default | Kind |
| --- | --- | --- |
| `PARA_ASYNCHRONOUS` | `32'd0` | parameter |
| `LPARA_ADDR_W` | `32'd16` | parameter |
| `LPARA_DATA_W` | `32'd32` | parameter |
| `LPARA_STRB_W` | `32'd4` | parameter |
| `LPARA_SYNC_STAGES` | `32'd2` | parameter |
| `LPARA_DVP_VERSION_OFFSET` | `32'h0000` | parameter |
| `LPARA_DVP_CTRL_OFFSET` | `32'h0004` | parameter |
| `LPARA_DVP_WMARK_OFFSET` | `32'h0008` | parameter |
| `LPARA_DVP_TIMEOUT_OFFSET` | `32'h000c` | parameter |
| `LPARA_DVP_FIFO_STS_OFFSET` | `32'h0010` | parameter |
| `LPARA_DVP_FIFO_LEVEL_OFFSET` | `32'h0014` | parameter |

| Port | Direction | Width | Type | Function (fill from the source) | Line |
| --- | --- | --- | --- | --- | --- |
| `i_clk_apb` | input | 1 | wire | <fill> | 30 |
| `i_rst_n_apb` | input | 1 | wire | <fill> | 30 |
| `i_clk_reg` | input | 1 | wire | <fill> | 30 |
| `i_rst_n_reg` | input | 1 | wire | <fill> | 30 |
| `i_apb_psel` | input | 1 | wire | <fill> | 30 |
| `i_apb_penable` | input | 1 | wire | <fill> | 30 |
| `i_apb_pwrite` | input | 1 | wire | <fill> | 30 |
| `i_apb_paddr` | input | [LPARA_ADDR_W-1:0] | wire | <fill> | 30 |
| `i_apb_pwdata` | input | [LPARA_DATA_W-1:0] | wire | <fill> | 30 |
| `i_apb_pstrb` | input | [LPARA_STRB_W-1:0] | wire | <fill> | 30 |
| `i_apb_pprot` | input | [2:0] | wire | <fill> | 30 |
| `o_apb_pready` | output | 1 | logic | <fill> | 30 |
| `o_apb_pslverr` | output | 1 | logic | <fill> | 30 |
| `o_apb_prdata` | output | [LPARA_DATA_W-1:0] | logic | <fill> | 30 |
| `i_protect_en` | input | 1 | wire | <fill> | 30 |
| `i_slverr_en` | input | 1 | wire | <fill> | 30 |
| `i_dvp_version_major` | input | [15:0] | wire | <fill> | 30 |
| `i_dvp_version_minor` | input | [15:0] | wire | <fill> | 30 |
| `o_dvp_ctrl_pclk_mode` | output | 1 | logic | <fill> | 30 |
| `o_dvp_ctrl_capture_en` | output | 1 | logic | <fill> | 30 |
| `o_dvp_wmark_level` | output | [31:0] | logic | <fill> | 30 |
| `o_dvp_timeout_cycles` | output | [31:0] | logic | <fill> | 30 |
| `o_dvp_fifo_sts_ovf` | output | 1 | logic | <fill> | 30 |
| `i_hw_wdata_dvp_fifo_sts_ovf` | input | 1 | wire | <fill> | 30 |
| `i_hw_we_dvp_fifo_sts_ovf` | input | 1 | wire | <fill> | 30 |
| `i_dvp_fifo_sts_full` | input | 1 | wire | <fill> | 30 |
| `i_dvp_fifo_sts_empty` | input | 1 | wire | <fill> | 30 |
| `i_dvp_fifo_sts_active` | input | 1 | wire | <fill> | 30 |
| `i_dvp_fifo_level_count` | input | [31:0] | wire | <fill> | 30 |

#### `m_vlsit_csr_sync` (rtl/csr/m_vlsit_csr_sync.sv:17)

| Parameter | Default | Kind |
| --- | --- | --- |
| `PARA_LEVELS` | `2` | parameter |

| Port | Direction | Width | Type | Function (fill from the source) | Line |
| --- | --- | --- | --- | --- | --- |
| `i_clk_dst` | input | 1 | wire | <fill> | 22 |
| `i_rst_n_dst` | input | 1 | wire | <fill> | 22 |
| `i_d` | input | 1 | wire | <fill> | 22 |
| `o_q` | output | 1 | logic | <fill> | 22 |

#### `m_vlsit_event_sync` (rtl_lib/m_vlsit_event_sync.sv:14)

| Parameter | Default | Kind |
| --- | --- | --- |
| `PARA_EVENT_SYNC_W` | `32'd1` | parameter |
| `PARA_EVENT_SYNC_CELL_TYPE` | `32'd2` | parameter |

| Port | Direction | Width | Type | Function (fill from the source) | Line |
| --- | --- | --- | --- | --- | --- |
| `i_clk_src` | input | 1 | wire | <fill> | 24 |
| `i_rst_n_src` | input | 1 | wire | <fill> | 24 |
| `i_clk_dst` | input | 1 | wire | <fill> | 24 |
| `i_rst_n_dst` | input | 1 | wire | <fill> | 24 |
| `i_event_src` | input | [PARA_EVENT_SYNC_W-1:0] | wire | <fill> | 24 |
| `o_event_dst` | output | [PARA_EVENT_SYNC_W-1:0] | logic | <fill> | 24 |

#### `m_vlsit_rst_sync` (rtl_lib/m_vlsit_rst_sync.sv:23)

| Parameter | Default | Kind |
| --- | --- | --- |
| `PARA_RST_SYNC_TYPE` | `2` | parameter |
| `LPARA_TYPE_DFF2` | `32'd1` | parameter |
| `LPARA_TYPE_SYNC2` | `32'd2` | parameter |
| `LPARA_TYPE_SYNC3` | `32'd3` | parameter |
| `SIM_STAGE` | `(PARA_RST_SYNC_TYPE == 32'd1) ? 2 : (PARA_RST_SYNC_TYPE > 32'd4) ? 4 : int'(PARA_RST_SYNC_TYPE)` | localparam |

| Port | Direction | Width | Type | Function (fill from the source) | Line |
| --- | --- | --- | --- | --- | --- |
| `i_clk_dst` | input | 1 | wire | <fill> | 32 |
| `i_rst_n_src` | input | 1 | wire | <fill> | 32 |
| `o_rst_n_dst` | output | 1 | logic | <fill> | 32 |

#### `m_vlsit_sfifo_mem` (rtl/m_vlsit_sfifo_mem.sv:17)

| Parameter | Default | Kind |
| --- | --- | --- |
| `PARA_SFIFO_DEPTH` | `8` | parameter |
| `PARA_SFIFO_DATA_W` | `32` | parameter |
| `PARA_SFIFO_MEM_USE_MACRO` | `0` | parameter |
| `LPARA_ADDR_W` | `$clog2(PARA_SFIFO_DEPTH)` | parameter |

| Port | Direction | Width | Type | Function (fill from the source) | Line |
| --- | --- | --- | --- | --- | --- |
| `i_clk_wr` | input | 1 | wire | <fill> | 31 |
| `i_wr_en` | input | 1 | wire | <fill> | 31 |
| `i_wr_addr` | input | [LPARA_ADDR_W-1:0] | wire | <fill> | 31 |
| `i_wr_data` | input | [PARA_SFIFO_DATA_W-1:0] | wire | <fill> | 31 |
| `i_clk_rd` | input | 1 | wire | <fill> | 31 |
| `i_rd_addr` | input | [LPARA_ADDR_W-1:0] | wire | <fill> | 31 |
| `o_rd_data` | output | [PARA_SFIFO_DATA_W-1:0] | logic | <fill> | 31 |

#### `m_vlsit_sfifo_ram_macro` (rtl_lib/m_vlsit_sfifo_ram_macro.sv:18)

| Parameter | Default | Kind |
| --- | --- | --- |
| `PARA_SFIFO_DEPTH` | `8` | parameter |
| `PARA_SFIFO_DATA_W` | `32` | parameter |
| `LPARA_ADDR_W` | `$clog2(PARA_SFIFO_DEPTH)` | parameter |

| Port | Direction | Width | Type | Function (fill from the source) | Line |
| --- | --- | --- | --- | --- | --- |
| `i_clk_wr` | input | 1 | wire | <fill> | 28 |
| `i_wr_en_n` | input | 1 | wire | <fill> | 28 |
| `i_wr_addr` | input | [LPARA_ADDR_W-1:0] | wire | <fill> | 28 |
| `i_wr_data` | input | [PARA_SFIFO_DATA_W-1:0] | wire | <fill> | 28 |
| `i_clk_rd` | input | 1 | wire | <fill> | 28 |
| `i_rd_en_n` | input | 1 | wire | <fill> | 28 |
| `i_rd_addr` | input | [LPARA_ADDR_W-1:0] | wire | <fill> | 28 |
| `o_rd_data` | output | [PARA_SFIFO_DATA_W-1:0] | logic | <fill> | 28 |

#### `m_vlsit_sfifo_rd` (rtl/m_vlsit_sfifo_rd.sv:21)

| Parameter | Default | Kind |
| --- | --- | --- |
| `PARA_SFIFO_DEPTH` | `8` | parameter |
| `PARA_SFIFO_DATA_W` | `32` | parameter |
| `PARA_SFIFO_PTR_RETIME` | `0` | parameter |
| `LPARA_ADDR_W` | `$clog2(PARA_SFIFO_DEPTH)` | parameter |
| `LPARA_PTR_W` | `$clog2(2 * PARA_SFIFO_DEPTH)` | parameter |
| `LPARA_OCC_W` | `$clog2(PARA_SFIFO_DEPTH + 1)` | parameter |
| `LPARA_PTR_MOD` | `2 * PARA_SFIFO_DEPTH` | parameter |
| `LPARA_ARITH_W` | `32` | parameter |

| Port | Direction | Width | Type | Function (fill from the source) | Line |
| --- | --- | --- | --- | --- | --- |
| `i_clk_rd` | input | 1 | wire | <fill> | 39 |
| `i_rst_n_rd` | input | 1 | wire | <fill> | 39 |
| `i_rd_en` | input | 1 | wire | <fill> | 39 |
| `i_empty_thr` | input | [LPARA_OCC_W-1:0] | wire | <fill> | 39 |
| `o_rd_data` | output | [PARA_SFIFO_DATA_W-1:0] | logic | <fill> | 39 |
| `o_empty` | output | 1 | logic | <fill> | 39 |
| `o_empty_thr` | output | 1 | logic | <fill> | 39 |
| `o_underflow` | output | 1 | logic | <fill> | 39 |
| `i_req_wr` | input | 1 | wire | <fill> | 39 |
| `o_ack_rd` | output | 1 | logic | <fill> | 39 |
| `i_wr_ptr` | input | [LPARA_PTR_W-1:0] | wire | <fill> | 39 |
| `o_rd_ptr` | output | [LPARA_PTR_W-1:0] | logic | <fill> | 39 |
| `o_mem_rd_addr` | output | [LPARA_ADDR_W-1:0] | logic | <fill> | 39 |
| `i_mem_rd_data` | input | [PARA_SFIFO_DATA_W-1:0] | wire | <fill> | 39 |

#### `m_vlsit_sfifo_top` (rtl/m_vlsit_sfifo_top.sv:18)

| Parameter | Default | Kind |
| --- | --- | --- |
| `PARA_SFIFO_DEPTH` | `8` | parameter |
| `PARA_SFIFO_DATA_W` | `32` | parameter |
| `PARA_SFIFO_PTR_RETIME` | `0` | parameter |
| `PARA_SFIFO_MEM_USE_MACRO` | `0` | parameter |
| `LPARA_ADDR_W` | `$clog2(PARA_SFIFO_DEPTH)` | parameter |
| `LPARA_PTR_W` | `$clog2(2 * PARA_SFIFO_DEPTH)` | parameter |
| `LPARA_OCC_W` | `$clog2(PARA_SFIFO_DEPTH + 1)` | parameter |

| Port | Direction | Width | Type | Function (fill from the source) | Line |
| --- | --- | --- | --- | --- | --- |
| `i_clk_wr` | input | 1 | wire | <fill> | 39 |
| `i_rst_n_wr` | input | 1 | wire | <fill> | 39 |
| `i_wr_en` | input | 1 | wire | <fill> | 39 |
| `i_wr_data` | input | [PARA_SFIFO_DATA_W-1:0] | wire | <fill> | 39 |
| `i_full_thr` | input | [LPARA_OCC_W-1:0] | wire | <fill> | 39 |
| `o_full` | output | 1 | logic | <fill> | 39 |
| `o_full_thr` | output | 1 | logic | <fill> | 39 |
| `o_overflow` | output | 1 | logic | <fill> | 39 |
| `i_rst_n_sw` | input | 1 | wire | <fill> | 39 |
| `o_sw_rst_busy` | output | 1 | logic | <fill> | 39 |
| `i_clk_rd` | input | 1 | wire | <fill> | 39 |
| `i_rst_n_rd` | input | 1 | wire | <fill> | 39 |
| `i_rd_en` | input | 1 | wire | <fill> | 39 |
| `i_empty_thr` | input | [LPARA_OCC_W-1:0] | wire | <fill> | 39 |
| `o_rd_data` | output | [PARA_SFIFO_DATA_W-1:0] | logic | <fill> | 39 |
| `o_empty` | output | 1 | logic | <fill> | 39 |
| `o_empty_thr` | output | 1 | logic | <fill> | 39 |
| `o_underflow` | output | 1 | logic | <fill> | 39 |

#### `m_vlsit_sfifo_wr` (rtl/m_vlsit_sfifo_wr.sv:19)

| Parameter | Default | Kind |
| --- | --- | --- |
| `PARA_SFIFO_DEPTH` | `8` | parameter |
| `PARA_SFIFO_DATA_W` | `32` | parameter |
| `PARA_SFIFO_PTR_RETIME` | `0` | parameter |
| `LPARA_ADDR_W` | `$clog2(PARA_SFIFO_DEPTH)` | parameter |
| `LPARA_PTR_W` | `$clog2(2 * PARA_SFIFO_DEPTH)` | parameter |
| `LPARA_OCC_W` | `$clog2(PARA_SFIFO_DEPTH + 1)` | parameter |
| `LPARA_PTR_MOD` | `2 * PARA_SFIFO_DEPTH` | parameter |
| `LPARA_ARITH_W` | `32` | parameter |

| Port | Direction | Width | Type | Function (fill from the source) | Line |
| --- | --- | --- | --- | --- | --- |
| `i_clk_wr` | input | 1 | wire | <fill> | 37 |
| `i_rst_n_wr` | input | 1 | wire | <fill> | 37 |
| `i_wr_en` | input | 1 | wire | <fill> | 37 |
| `i_wr_data` | input | [PARA_SFIFO_DATA_W-1:0] | wire | <fill> | 37 |
| `i_full_thr` | input | [LPARA_OCC_W-1:0] | wire | <fill> | 37 |
| `o_full` | output | 1 | logic | <fill> | 37 |
| `o_full_thr` | output | 1 | logic | <fill> | 37 |
| `o_overflow` | output | 1 | logic | <fill> | 37 |
| `i_rst_n_sw` | input | 1 | wire | <fill> | 37 |
| `o_sw_rst_busy` | output | 1 | logic | <fill> | 37 |
| `o_req_wr` | output | 1 | logic | <fill> | 37 |
| `i_ack_rd` | input | 1 | wire | <fill> | 37 |
| `i_rd_ptr` | input | [LPARA_PTR_W-1:0] | wire | <fill> | 37 |
| `o_wr_ptr` | output | [LPARA_PTR_W-1:0] | logic | <fill> | 37 |
| `o_mem_wr_en` | output | 1 | logic | <fill> | 37 |
| `o_mem_wr_addr` | output | [LPARA_ADDR_W-1:0] | logic | <fill> | 37 |
| `o_mem_wr_data` | output | [PARA_SFIFO_DATA_W-1:0] | logic | <fill> | 37 |

#### `m_vlsit_tie` (rtl_lib/m_vlsit_tie.sv:17)

| Parameter | Default | Kind |
| --- | --- | --- |
| `PARA_TIE_WIDTH` | `1` | parameter |
| `PARA_TIE_VALUE` | `0` | parameter |

| Port | Direction | Width | Type | Function (fill from the source) | Line |
| --- | --- | --- | --- | --- | --- |
| `o_tie` | output | [PARA_TIE_WIDTH-1:0] | logic | <fill> | 27 |

