### Hierarchy (top-down)

| Level | Instance path | Module | Count at this level | Count basis | Source |
| --- | --- | --- | --- | --- | --- |
| 0 | m_dvp_controller | m_dvp_controller | 1 | top module | rtl/m_dvp_controller.sv:12 |
| 1 | u_rst_sync_apb | m_vlsit_rst_sync | 1 |  | rtl/m_dvp_controller.sv:87 |
| 2 | u_rst_sync_apb.u_dont_touch_tieh | VLSIT_CELL_TIEH | 1 |  | rtl_lib/m_vlsit_rst_sync.sv:47 |
| 2 | u_rst_sync_apb.u_dont_touch_dff_0 | VLSIT_CELL_SYNC_DFF_RN | 1 | if(PARA_RST_SYNC_TYPE == LPARA_TYPE_DFF2) conditional | rtl_lib/m_vlsit_rst_sync.sv:52 |
| 2 | u_rst_sync_apb.u_dont_touch_dff_1 | VLSIT_CELL_SYNC_DFF_RN | 1 | if(PARA_RST_SYNC_TYPE == LPARA_TYPE_DFF2) conditional | rtl_lib/m_vlsit_rst_sync.sv:53 |
| 2 | u_rst_sync_apb.u_dont_touch_sync2ff | VLSIT_CELL_SYNC_2FF_RN | 1 | if(LSIT_CELL_SYNC_DFF_RN u_dont_touch_dff_1 (.CK (i_clk_dst), .RN (i_rst_n_src), .D (w_mid), .Q (o_rst_n_dst)); end else if (PARA_RST_SYNC_TYPE == LPARA_TYPE_SYNC2) conditional | rtl_lib/m_vlsit_rst_sync.sv:56 |
| 2 | u_rst_sync_apb.u_dont_touch_sync3ff | VLSIT_CELL_SYNC_3FF_RN | 1 | if(CELL_SYNC_2FF_RN u_dont_touch_sync2ff (.CK (i_clk_dst), .RN (i_rst_n_src), .D (w_tie_hi), .Q (o_rst_n_dst)); end else if (PARA_RST_SYNC_TYPE == LPARA_TYPE_SYNC3) conditional | rtl_lib/m_vlsit_rst_sync.sv:59 |
| 2 | u_rst_sync_apb.u_dont_touch_sync4ff | VLSIT_CELL_SYNC_4FF_RN | 1 | else conditional | rtl_lib/m_vlsit_rst_sync.sv:62 |
| 1 | u_rst_sync_dvp | m_vlsit_rst_sync | 1 |  | rtl/m_dvp_controller.sv:94 |
| 2 | u_rst_sync_dvp.u_dont_touch_tieh | VLSIT_CELL_TIEH | 1 |  | rtl_lib/m_vlsit_rst_sync.sv:47 |
| 2 | u_rst_sync_dvp.u_dont_touch_dff_0 | VLSIT_CELL_SYNC_DFF_RN | 1 | if(PARA_RST_SYNC_TYPE == LPARA_TYPE_DFF2) conditional | rtl_lib/m_vlsit_rst_sync.sv:52 |
| 2 | u_rst_sync_dvp.u_dont_touch_dff_1 | VLSIT_CELL_SYNC_DFF_RN | 1 | if(PARA_RST_SYNC_TYPE == LPARA_TYPE_DFF2) conditional | rtl_lib/m_vlsit_rst_sync.sv:53 |
| 2 | u_rst_sync_dvp.u_dont_touch_sync2ff | VLSIT_CELL_SYNC_2FF_RN | 1 | if(LSIT_CELL_SYNC_DFF_RN u_dont_touch_dff_1 (.CK (i_clk_dst), .RN (i_rst_n_src), .D (w_mid), .Q (o_rst_n_dst)); end else if (PARA_RST_SYNC_TYPE == LPARA_TYPE_SYNC2) conditional | rtl_lib/m_vlsit_rst_sync.sv:56 |
| 2 | u_rst_sync_dvp.u_dont_touch_sync3ff | VLSIT_CELL_SYNC_3FF_RN | 1 | if(CELL_SYNC_2FF_RN u_dont_touch_sync2ff (.CK (i_clk_dst), .RN (i_rst_n_src), .D (w_tie_hi), .Q (o_rst_n_dst)); end else if (PARA_RST_SYNC_TYPE == LPARA_TYPE_SYNC3) conditional | rtl_lib/m_vlsit_rst_sync.sv:59 |
| 2 | u_rst_sync_dvp.u_dont_touch_sync4ff | VLSIT_CELL_SYNC_4FF_RN | 1 | else conditional | rtl_lib/m_vlsit_rst_sync.sv:62 |
| 1 | u_dvp_capture | m_dvp_capture | 1 |  | rtl/m_dvp_controller.sv:101 |
| 1 | u_dvp_apb_service | m_dvp_apb_service | 1 |  | rtl/m_dvp_controller.sv:125 |
| 2 | u_dvp_apb_service.u_apb_decode | m_dvp_apb_decode | 1 |  | rtl/m_dvp_apb_service.sv:115 |
| 2 | u_dvp_apb_service.u_tie_protect | m_vlsit_tie | 1 |  | rtl/m_dvp_apb_service.sv:159 |
| 3 | u_dvp_apb_service.u_tie_protect.u_dont_touch_tieh | VLSIT_CELL_TIEH | 1 | for(gv_bit < PARA_TIE_WIDTH) if(PARA_TIE_VALUE[gv_bit]) conditional | rtl_lib/m_vlsit_tie.sv:36 |
| 3 | u_dvp_apb_service.u_tie_protect.u_dont_touch_tiel | VLSIT_CELL_TIEL | 1 | for(gv_bit < PARA_TIE_WIDTH) else conditional | rtl_lib/m_vlsit_tie.sv:38 |
| 2 | u_dvp_apb_service.u_tie_slverr | m_vlsit_tie | 1 |  | rtl/m_dvp_apb_service.sv:166 |
| 3 | u_dvp_apb_service.u_tie_slverr.u_dont_touch_tieh | VLSIT_CELL_TIEH | 1 | for(gv_bit < PARA_TIE_WIDTH) if(PARA_TIE_VALUE[gv_bit]) conditional | rtl_lib/m_vlsit_tie.sv:36 |
| 3 | u_dvp_apb_service.u_tie_slverr.u_dont_touch_tiel | VLSIT_CELL_TIEL | 1 | for(gv_bit < PARA_TIE_WIDTH) else conditional | rtl_lib/m_vlsit_tie.sv:38 |
| 2 | u_dvp_apb_service.u_csr | m_vlsit_csr_dvp | 1 |  | rtl/m_dvp_apb_service.sv:174 |
| 3 | u_dvp_apb_service.u_csr.u_rd_ack_sync | m_vlsit_csr_sync | 1 | if(PARA_ASYNCHRONOUS == 32'd1) conditional | rtl/csr/m_vlsit_csr_dvp.sv:220 |
| 4 | u_dvp_apb_service.u_csr.u_rd_ack_sync.u_sync | m_vlsit_afifo_cell_sync | 1 |  | rtl/csr/m_vlsit_csr_sync.sv:33 |
| 5 | u_dvp_apb_service.u_csr.u_rd_ack_sync.u_sync.u_dont_touch_dff_0 | VLSIT_CELL_SYNC_DFF_RN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_BYPASS) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) if(S) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) begin : gen_dff2 logic w_mid; if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:61 |
| 5 | u_dvp_apb_service.u_csr.u_rd_ack_sync.u_sync.u_dont_touch_dff_1 | VLSIT_CELL_SYNC_DFF_RN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_BYPASS) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) if(S) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) begin : gen_dff2 logic w_mid; if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:62 |
| 5 | u_dvp_apb_service.u_csr.u_rd_ack_sync.u_sync.u_dont_touch_dff_0 | VLSIT_CELL_SYNC_DFF_SN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_BYPASS) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:64 |
| 5 | u_dvp_apb_service.u_csr.u_rd_ack_sync.u_sync.u_dont_touch_dff_1 | VLSIT_CELL_SYNC_DFF_SN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_BYPASS) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:65 |
| 5 | u_dvp_apb_service.u_csr.u_rd_ack_sync.u_sync.u_dont_touch_sync2ff | VLSIT_CELL_SYNC_2FF_RN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC2) if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC2) begin : gen_sync2 if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:70 |
| 5 | u_dvp_apb_service.u_csr.u_rd_ack_sync.u_sync.u_dont_touch_sync2ff | VLSIT_CELL_SYNC_2FF_SN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC2) else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:72 |
| 5 | u_dvp_apb_service.u_csr.u_rd_ack_sync.u_sync.u_dont_touch_sync3ff | VLSIT_CELL_SYNC_3FF_RN | 1 | if( VLSIT_CELL_SYNC_2FF_SN u_dont_touch_sync2ff (.CK (i_clk_dst), .SN (i_rst_n_dst), .D (i_d), .Q (o_q)); end end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC3) if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC3) begin : gen_sync3 if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:77 |
| 5 | u_dvp_apb_service.u_csr.u_rd_ack_sync.u_sync.u_dont_touch_sync3ff | VLSIT_CELL_SYNC_3FF_SN | 1 | if( VLSIT_CELL_SYNC_2FF_SN u_dont_touch_sync2ff (.CK (i_clk_dst), .SN (i_rst_n_dst), .D (i_d), .Q (o_q)); end end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC3) else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:79 |
| 5 | u_dvp_apb_service.u_csr.u_rd_ack_sync.u_sync.u_dont_touch_sync4ff | VLSIT_CELL_SYNC_4FF_RN | 1 | else if(L_SYNC_3FF_SN u_dont_touch_sync3ff (.CK (i_clk_dst), .SN (i_rst_n_dst), .D (i_d), .Q (o_q)); end end else begin : gen_sync4 if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:84 |
| 5 | u_dvp_apb_service.u_csr.u_rd_ack_sync.u_sync.u_dont_touch_sync4ff | VLSIT_CELL_SYNC_4FF_SN | 1 | else else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:86 |
| 3 | u_dvp_apb_service.u_csr.u_wr_ack_sync | m_vlsit_csr_sync | 1 | if(PARA_ASYNCHRONOUS == 32'd1) conditional | rtl/csr/m_vlsit_csr_dvp.sv:243 |
| 4 | u_dvp_apb_service.u_csr.u_wr_ack_sync.u_sync | m_vlsit_afifo_cell_sync | 1 |  | rtl/csr/m_vlsit_csr_sync.sv:33 |
| 5 | u_dvp_apb_service.u_csr.u_wr_ack_sync.u_sync.u_dont_touch_dff_0 | VLSIT_CELL_SYNC_DFF_RN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_BYPASS) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) if(S) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) begin : gen_dff2 logic w_mid; if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:61 |
| 5 | u_dvp_apb_service.u_csr.u_wr_ack_sync.u_sync.u_dont_touch_dff_1 | VLSIT_CELL_SYNC_DFF_RN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_BYPASS) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) if(S) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) begin : gen_dff2 logic w_mid; if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:62 |
| 5 | u_dvp_apb_service.u_csr.u_wr_ack_sync.u_sync.u_dont_touch_dff_0 | VLSIT_CELL_SYNC_DFF_SN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_BYPASS) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:64 |
| 5 | u_dvp_apb_service.u_csr.u_wr_ack_sync.u_sync.u_dont_touch_dff_1 | VLSIT_CELL_SYNC_DFF_SN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_BYPASS) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:65 |
| 5 | u_dvp_apb_service.u_csr.u_wr_ack_sync.u_sync.u_dont_touch_sync2ff | VLSIT_CELL_SYNC_2FF_RN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC2) if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC2) begin : gen_sync2 if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:70 |
| 5 | u_dvp_apb_service.u_csr.u_wr_ack_sync.u_sync.u_dont_touch_sync2ff | VLSIT_CELL_SYNC_2FF_SN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC2) else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:72 |
| 5 | u_dvp_apb_service.u_csr.u_wr_ack_sync.u_sync.u_dont_touch_sync3ff | VLSIT_CELL_SYNC_3FF_RN | 1 | if( VLSIT_CELL_SYNC_2FF_SN u_dont_touch_sync2ff (.CK (i_clk_dst), .SN (i_rst_n_dst), .D (i_d), .Q (o_q)); end end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC3) if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC3) begin : gen_sync3 if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:77 |
| 5 | u_dvp_apb_service.u_csr.u_wr_ack_sync.u_sync.u_dont_touch_sync3ff | VLSIT_CELL_SYNC_3FF_SN | 1 | if( VLSIT_CELL_SYNC_2FF_SN u_dont_touch_sync2ff (.CK (i_clk_dst), .SN (i_rst_n_dst), .D (i_d), .Q (o_q)); end end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC3) else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:79 |
| 5 | u_dvp_apb_service.u_csr.u_wr_ack_sync.u_sync.u_dont_touch_sync4ff | VLSIT_CELL_SYNC_4FF_RN | 1 | else if(L_SYNC_3FF_SN u_dont_touch_sync3ff (.CK (i_clk_dst), .SN (i_rst_n_dst), .D (i_d), .Q (o_q)); end end else begin : gen_sync4 if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:84 |
| 5 | u_dvp_apb_service.u_csr.u_wr_ack_sync.u_sync.u_dont_touch_sync4ff | VLSIT_CELL_SYNC_4FF_SN | 1 | else else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:86 |
| 3 | u_dvp_apb_service.u_csr.u_rd_req_sync | m_vlsit_csr_sync | 1 | if(PARA_ASYNCHRONOUS == 32'd1) conditional | rtl/csr/m_vlsit_csr_dvp.sv:264 |
| 4 | u_dvp_apb_service.u_csr.u_rd_req_sync.u_sync | m_vlsit_afifo_cell_sync | 1 |  | rtl/csr/m_vlsit_csr_sync.sv:33 |
| 5 | u_dvp_apb_service.u_csr.u_rd_req_sync.u_sync.u_dont_touch_dff_0 | VLSIT_CELL_SYNC_DFF_RN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_BYPASS) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) if(S) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) begin : gen_dff2 logic w_mid; if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:61 |
| 5 | u_dvp_apb_service.u_csr.u_rd_req_sync.u_sync.u_dont_touch_dff_1 | VLSIT_CELL_SYNC_DFF_RN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_BYPASS) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) if(S) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) begin : gen_dff2 logic w_mid; if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:62 |
| 5 | u_dvp_apb_service.u_csr.u_rd_req_sync.u_sync.u_dont_touch_dff_0 | VLSIT_CELL_SYNC_DFF_SN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_BYPASS) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:64 |
| 5 | u_dvp_apb_service.u_csr.u_rd_req_sync.u_sync.u_dont_touch_dff_1 | VLSIT_CELL_SYNC_DFF_SN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_BYPASS) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:65 |
| 5 | u_dvp_apb_service.u_csr.u_rd_req_sync.u_sync.u_dont_touch_sync2ff | VLSIT_CELL_SYNC_2FF_RN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC2) if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC2) begin : gen_sync2 if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:70 |
| 5 | u_dvp_apb_service.u_csr.u_rd_req_sync.u_sync.u_dont_touch_sync2ff | VLSIT_CELL_SYNC_2FF_SN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC2) else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:72 |
| 5 | u_dvp_apb_service.u_csr.u_rd_req_sync.u_sync.u_dont_touch_sync3ff | VLSIT_CELL_SYNC_3FF_RN | 1 | if( VLSIT_CELL_SYNC_2FF_SN u_dont_touch_sync2ff (.CK (i_clk_dst), .SN (i_rst_n_dst), .D (i_d), .Q (o_q)); end end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC3) if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC3) begin : gen_sync3 if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:77 |
| 5 | u_dvp_apb_service.u_csr.u_rd_req_sync.u_sync.u_dont_touch_sync3ff | VLSIT_CELL_SYNC_3FF_SN | 1 | if( VLSIT_CELL_SYNC_2FF_SN u_dont_touch_sync2ff (.CK (i_clk_dst), .SN (i_rst_n_dst), .D (i_d), .Q (o_q)); end end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC3) else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:79 |
| 5 | u_dvp_apb_service.u_csr.u_rd_req_sync.u_sync.u_dont_touch_sync4ff | VLSIT_CELL_SYNC_4FF_RN | 1 | else if(L_SYNC_3FF_SN u_dont_touch_sync3ff (.CK (i_clk_dst), .SN (i_rst_n_dst), .D (i_d), .Q (o_q)); end end else begin : gen_sync4 if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:84 |
| 5 | u_dvp_apb_service.u_csr.u_rd_req_sync.u_sync.u_dont_touch_sync4ff | VLSIT_CELL_SYNC_4FF_SN | 1 | else else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:86 |
| 3 | u_dvp_apb_service.u_csr.u_wr_req_sync | m_vlsit_csr_sync | 1 | if(PARA_ASYNCHRONOUS == 32'd1) conditional | rtl/csr/m_vlsit_csr_dvp.sv:282 |
| 4 | u_dvp_apb_service.u_csr.u_wr_req_sync.u_sync | m_vlsit_afifo_cell_sync | 1 |  | rtl/csr/m_vlsit_csr_sync.sv:33 |
| 5 | u_dvp_apb_service.u_csr.u_wr_req_sync.u_sync.u_dont_touch_dff_0 | VLSIT_CELL_SYNC_DFF_RN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_BYPASS) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) if(S) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) begin : gen_dff2 logic w_mid; if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:61 |
| 5 | u_dvp_apb_service.u_csr.u_wr_req_sync.u_sync.u_dont_touch_dff_1 | VLSIT_CELL_SYNC_DFF_RN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_BYPASS) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) if(S) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) begin : gen_dff2 logic w_mid; if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:62 |
| 5 | u_dvp_apb_service.u_csr.u_wr_req_sync.u_sync.u_dont_touch_dff_0 | VLSIT_CELL_SYNC_DFF_SN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_BYPASS) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:64 |
| 5 | u_dvp_apb_service.u_csr.u_wr_req_sync.u_sync.u_dont_touch_dff_1 | VLSIT_CELL_SYNC_DFF_SN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_BYPASS) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:65 |
| 5 | u_dvp_apb_service.u_csr.u_wr_req_sync.u_sync.u_dont_touch_sync2ff | VLSIT_CELL_SYNC_2FF_RN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC2) if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC2) begin : gen_sync2 if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:70 |
| 5 | u_dvp_apb_service.u_csr.u_wr_req_sync.u_sync.u_dont_touch_sync2ff | VLSIT_CELL_SYNC_2FF_SN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC2) else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:72 |
| 5 | u_dvp_apb_service.u_csr.u_wr_req_sync.u_sync.u_dont_touch_sync3ff | VLSIT_CELL_SYNC_3FF_RN | 1 | if( VLSIT_CELL_SYNC_2FF_SN u_dont_touch_sync2ff (.CK (i_clk_dst), .SN (i_rst_n_dst), .D (i_d), .Q (o_q)); end end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC3) if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC3) begin : gen_sync3 if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:77 |
| 5 | u_dvp_apb_service.u_csr.u_wr_req_sync.u_sync.u_dont_touch_sync3ff | VLSIT_CELL_SYNC_3FF_SN | 1 | if( VLSIT_CELL_SYNC_2FF_SN u_dont_touch_sync2ff (.CK (i_clk_dst), .SN (i_rst_n_dst), .D (i_d), .Q (o_q)); end end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC3) else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:79 |
| 5 | u_dvp_apb_service.u_csr.u_wr_req_sync.u_sync.u_dont_touch_sync4ff | VLSIT_CELL_SYNC_4FF_RN | 1 | else if(L_SYNC_3FF_SN u_dont_touch_sync3ff (.CK (i_clk_dst), .SN (i_rst_n_dst), .D (i_d), .Q (o_q)); end end else begin : gen_sync4 if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:84 |
| 5 | u_dvp_apb_service.u_csr.u_wr_req_sync.u_sync.u_dont_touch_sync4ff | VLSIT_CELL_SYNC_4FF_SN | 1 | else else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:86 |
| 2 | u_dvp_apb_service.u_apb_data | m_dvp_apb_data | 1 |  | rtl/m_dvp_apb_service.sv:213 |
| 2 | u_dvp_apb_service.u_dvp_buf | m_dvp_buffer | 1 |  | rtl/m_dvp_apb_service.sv:232 |
| 3 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo | m_dvp_afifo | 1 |  | rtl/m_dvp_buffer.sv:211 |
| 4 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_wr | m_vlsit_afifo_wr | 1 |  | rtl/m_dvp_afifo.sv:80 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_wr.u_sync_rd_gray | m_vlsit_afifo_sync | 1 |  | rtl/m_vlsit_afifo_wr.sv:233 |
| 6 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_wr.u_sync_rd_gray.u_vlsit_afifo_cell_sync | m_vlsit_afifo_cell_sync | 4 | for(gen_bit < PARA_AFIFO_SYNC_W) | rtl/m_vlsit_afifo_sync.sv:47 |
| 7 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_wr.u_sync_rd_gray.u_vlsit_afifo_cell_sync.u_dont_touch_dff_0 | VLSIT_CELL_SYNC_DFF_RN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_BYPASS) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) if(S) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) begin : gen_dff2 logic w_mid; if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:61 |
| 7 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_wr.u_sync_rd_gray.u_vlsit_afifo_cell_sync.u_dont_touch_dff_1 | VLSIT_CELL_SYNC_DFF_RN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_BYPASS) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) if(S) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) begin : gen_dff2 logic w_mid; if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:62 |
| 7 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_wr.u_sync_rd_gray.u_vlsit_afifo_cell_sync.u_dont_touch_dff_0 | VLSIT_CELL_SYNC_DFF_SN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_BYPASS) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:64 |
| 7 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_wr.u_sync_rd_gray.u_vlsit_afifo_cell_sync.u_dont_touch_dff_1 | VLSIT_CELL_SYNC_DFF_SN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_BYPASS) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:65 |
| 7 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_wr.u_sync_rd_gray.u_vlsit_afifo_cell_sync.u_dont_touch_sync2ff | VLSIT_CELL_SYNC_2FF_RN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC2) if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC2) begin : gen_sync2 if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:70 |
| 7 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_wr.u_sync_rd_gray.u_vlsit_afifo_cell_sync.u_dont_touch_sync2ff | VLSIT_CELL_SYNC_2FF_SN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC2) else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:72 |
| 7 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_wr.u_sync_rd_gray.u_vlsit_afifo_cell_sync.u_dont_touch_sync3ff | VLSIT_CELL_SYNC_3FF_RN | 1 | if( VLSIT_CELL_SYNC_2FF_SN u_dont_touch_sync2ff (.CK (i_clk_dst), .SN (i_rst_n_dst), .D (i_d), .Q (o_q)); end end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC3) if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC3) begin : gen_sync3 if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:77 |
| 7 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_wr.u_sync_rd_gray.u_vlsit_afifo_cell_sync.u_dont_touch_sync3ff | VLSIT_CELL_SYNC_3FF_SN | 1 | if( VLSIT_CELL_SYNC_2FF_SN u_dont_touch_sync2ff (.CK (i_clk_dst), .SN (i_rst_n_dst), .D (i_d), .Q (o_q)); end end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC3) else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:79 |
| 7 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_wr.u_sync_rd_gray.u_vlsit_afifo_cell_sync.u_dont_touch_sync4ff | VLSIT_CELL_SYNC_4FF_RN | 1 | else if(L_SYNC_3FF_SN u_dont_touch_sync3ff (.CK (i_clk_dst), .SN (i_rst_n_dst), .D (i_d), .Q (o_q)); end end else begin : gen_sync4 if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:84 |
| 7 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_wr.u_sync_rd_gray.u_vlsit_afifo_cell_sync.u_dont_touch_sync4ff | VLSIT_CELL_SYNC_4FF_SN | 1 | else else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:86 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_wr.u_sync_ack | m_vlsit_afifo_sync | 1 |  | rtl/m_vlsit_afifo_wr.sv:245 |
| 6 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_wr.u_sync_ack.u_vlsit_afifo_cell_sync | m_vlsit_afifo_cell_sync | 1 | for(gen_bit < PARA_AFIFO_SYNC_W) | rtl/m_vlsit_afifo_sync.sv:47 |
| 7 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_wr.u_sync_ack.u_vlsit_afifo_cell_sync.u_dont_touch_dff_0 | VLSIT_CELL_SYNC_DFF_RN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_BYPASS) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) if(S) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) begin : gen_dff2 logic w_mid; if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:61 |
| 7 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_wr.u_sync_ack.u_vlsit_afifo_cell_sync.u_dont_touch_dff_1 | VLSIT_CELL_SYNC_DFF_RN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_BYPASS) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) if(S) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) begin : gen_dff2 logic w_mid; if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:62 |
| 7 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_wr.u_sync_ack.u_vlsit_afifo_cell_sync.u_dont_touch_dff_0 | VLSIT_CELL_SYNC_DFF_SN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_BYPASS) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:64 |
| 7 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_wr.u_sync_ack.u_vlsit_afifo_cell_sync.u_dont_touch_dff_1 | VLSIT_CELL_SYNC_DFF_SN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_BYPASS) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:65 |
| 7 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_wr.u_sync_ack.u_vlsit_afifo_cell_sync.u_dont_touch_sync2ff | VLSIT_CELL_SYNC_2FF_RN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC2) if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC2) begin : gen_sync2 if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:70 |
| 7 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_wr.u_sync_ack.u_vlsit_afifo_cell_sync.u_dont_touch_sync2ff | VLSIT_CELL_SYNC_2FF_SN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC2) else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:72 |
| 7 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_wr.u_sync_ack.u_vlsit_afifo_cell_sync.u_dont_touch_sync3ff | VLSIT_CELL_SYNC_3FF_RN | 1 | if( VLSIT_CELL_SYNC_2FF_SN u_dont_touch_sync2ff (.CK (i_clk_dst), .SN (i_rst_n_dst), .D (i_d), .Q (o_q)); end end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC3) if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC3) begin : gen_sync3 if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:77 |
| 7 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_wr.u_sync_ack.u_vlsit_afifo_cell_sync.u_dont_touch_sync3ff | VLSIT_CELL_SYNC_3FF_SN | 1 | if( VLSIT_CELL_SYNC_2FF_SN u_dont_touch_sync2ff (.CK (i_clk_dst), .SN (i_rst_n_dst), .D (i_d), .Q (o_q)); end end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC3) else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:79 |
| 7 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_wr.u_sync_ack.u_vlsit_afifo_cell_sync.u_dont_touch_sync4ff | VLSIT_CELL_SYNC_4FF_RN | 1 | else if(L_SYNC_3FF_SN u_dont_touch_sync3ff (.CK (i_clk_dst), .SN (i_rst_n_dst), .D (i_d), .Q (o_q)); end end else begin : gen_sync4 if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:84 |
| 7 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_wr.u_sync_ack.u_vlsit_afifo_cell_sync.u_dont_touch_sync4ff | VLSIT_CELL_SYNC_4FF_SN | 1 | else else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:86 |
| 4 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_rd | m_dvp_afifo_rd | 1 |  | rtl/m_dvp_afifo.sv:105 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_rd.u_sync_wr_gray | m_vlsit_afifo_sync | 1 |  | rtl/m_dvp_afifo_rd.sv:209 |
| 6 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_rd.u_sync_wr_gray.u_vlsit_afifo_cell_sync | m_vlsit_afifo_cell_sync | 4 | for(gen_bit < PARA_AFIFO_SYNC_W) | rtl/m_vlsit_afifo_sync.sv:47 |
| 7 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_rd.u_sync_wr_gray.u_vlsit_afifo_cell_sync.u_dont_touch_dff_0 | VLSIT_CELL_SYNC_DFF_RN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_BYPASS) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) if(S) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) begin : gen_dff2 logic w_mid; if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:61 |
| 7 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_rd.u_sync_wr_gray.u_vlsit_afifo_cell_sync.u_dont_touch_dff_1 | VLSIT_CELL_SYNC_DFF_RN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_BYPASS) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) if(S) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) begin : gen_dff2 logic w_mid; if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:62 |
| 7 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_rd.u_sync_wr_gray.u_vlsit_afifo_cell_sync.u_dont_touch_dff_0 | VLSIT_CELL_SYNC_DFF_SN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_BYPASS) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:64 |
| 7 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_rd.u_sync_wr_gray.u_vlsit_afifo_cell_sync.u_dont_touch_dff_1 | VLSIT_CELL_SYNC_DFF_SN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_BYPASS) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:65 |
| 7 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_rd.u_sync_wr_gray.u_vlsit_afifo_cell_sync.u_dont_touch_sync2ff | VLSIT_CELL_SYNC_2FF_RN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC2) if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC2) begin : gen_sync2 if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:70 |
| 7 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_rd.u_sync_wr_gray.u_vlsit_afifo_cell_sync.u_dont_touch_sync2ff | VLSIT_CELL_SYNC_2FF_SN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC2) else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:72 |
| 7 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_rd.u_sync_wr_gray.u_vlsit_afifo_cell_sync.u_dont_touch_sync3ff | VLSIT_CELL_SYNC_3FF_RN | 1 | if( VLSIT_CELL_SYNC_2FF_SN u_dont_touch_sync2ff (.CK (i_clk_dst), .SN (i_rst_n_dst), .D (i_d), .Q (o_q)); end end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC3) if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC3) begin : gen_sync3 if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:77 |
| 7 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_rd.u_sync_wr_gray.u_vlsit_afifo_cell_sync.u_dont_touch_sync3ff | VLSIT_CELL_SYNC_3FF_SN | 1 | if( VLSIT_CELL_SYNC_2FF_SN u_dont_touch_sync2ff (.CK (i_clk_dst), .SN (i_rst_n_dst), .D (i_d), .Q (o_q)); end end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC3) else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:79 |
| 7 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_rd.u_sync_wr_gray.u_vlsit_afifo_cell_sync.u_dont_touch_sync4ff | VLSIT_CELL_SYNC_4FF_RN | 1 | else if(L_SYNC_3FF_SN u_dont_touch_sync3ff (.CK (i_clk_dst), .SN (i_rst_n_dst), .D (i_d), .Q (o_q)); end end else begin : gen_sync4 if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:84 |
| 7 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_rd.u_sync_wr_gray.u_vlsit_afifo_cell_sync.u_dont_touch_sync4ff | VLSIT_CELL_SYNC_4FF_SN | 1 | else else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:86 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_rd.u_sync_req | m_vlsit_afifo_sync | 1 |  | rtl/m_dvp_afifo_rd.sv:221 |
| 6 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_rd.u_sync_req.u_vlsit_afifo_cell_sync | m_vlsit_afifo_cell_sync | 1 | for(gen_bit < PARA_AFIFO_SYNC_W) | rtl/m_vlsit_afifo_sync.sv:47 |
| 7 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_rd.u_sync_req.u_vlsit_afifo_cell_sync.u_dont_touch_dff_0 | VLSIT_CELL_SYNC_DFF_RN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_BYPASS) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) if(S) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) begin : gen_dff2 logic w_mid; if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:61 |
| 7 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_rd.u_sync_req.u_vlsit_afifo_cell_sync.u_dont_touch_dff_1 | VLSIT_CELL_SYNC_DFF_RN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_BYPASS) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) if(S) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) begin : gen_dff2 logic w_mid; if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:62 |
| 7 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_rd.u_sync_req.u_vlsit_afifo_cell_sync.u_dont_touch_dff_0 | VLSIT_CELL_SYNC_DFF_SN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_BYPASS) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:64 |
| 7 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_rd.u_sync_req.u_vlsit_afifo_cell_sync.u_dont_touch_dff_1 | VLSIT_CELL_SYNC_DFF_SN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_BYPASS) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:65 |
| 7 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_rd.u_sync_req.u_vlsit_afifo_cell_sync.u_dont_touch_sync2ff | VLSIT_CELL_SYNC_2FF_RN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC2) if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC2) begin : gen_sync2 if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:70 |
| 7 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_rd.u_sync_req.u_vlsit_afifo_cell_sync.u_dont_touch_sync2ff | VLSIT_CELL_SYNC_2FF_SN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC2) else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:72 |
| 7 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_rd.u_sync_req.u_vlsit_afifo_cell_sync.u_dont_touch_sync3ff | VLSIT_CELL_SYNC_3FF_RN | 1 | if( VLSIT_CELL_SYNC_2FF_SN u_dont_touch_sync2ff (.CK (i_clk_dst), .SN (i_rst_n_dst), .D (i_d), .Q (o_q)); end end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC3) if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC3) begin : gen_sync3 if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:77 |
| 7 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_rd.u_sync_req.u_vlsit_afifo_cell_sync.u_dont_touch_sync3ff | VLSIT_CELL_SYNC_3FF_SN | 1 | if( VLSIT_CELL_SYNC_2FF_SN u_dont_touch_sync2ff (.CK (i_clk_dst), .SN (i_rst_n_dst), .D (i_d), .Q (o_q)); end end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC3) else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:79 |
| 7 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_rd.u_sync_req.u_vlsit_afifo_cell_sync.u_dont_touch_sync4ff | VLSIT_CELL_SYNC_4FF_RN | 1 | else if(L_SYNC_3FF_SN u_dont_touch_sync3ff (.CK (i_clk_dst), .SN (i_rst_n_dst), .D (i_d), .Q (o_q)); end end else begin : gen_sync4 if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:84 |
| 7 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_rd.u_sync_req.u_vlsit_afifo_cell_sync.u_dont_touch_sync4ff | VLSIT_CELL_SYNC_4FF_SN | 1 | else else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:86 |
| 4 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_mem | m_vlsit_afifo_mem | 1 |  | rtl/m_dvp_afifo.sv:132 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_mem.u_vlsit_afifo_ram_macro | m_vlsit_afifo_ram_macro | 1 | else conditional | rtl/m_vlsit_afifo_mem.sv:75 |
| 6 | u_dvp_apb_service.u_dvp_buf.u_dvp_afifo.u_afifo_mem.u_vlsit_afifo_ram_macro.u_dont_touch_sram | VLSIT_CELL_SRAM_1W1R | 1 |  | rtl_lib/m_vlsit_afifo_ram_macro.sv:41 |
| 3 | u_dvp_apb_service.u_dvp_buf.u_afifo_flush_req_sync | m_vlsit_afifo_sync | 1 |  | rtl/m_dvp_buffer.sv:239 |
| 4 | u_dvp_apb_service.u_dvp_buf.u_afifo_flush_req_sync.u_vlsit_afifo_cell_sync | m_vlsit_afifo_cell_sync | 1 | for(gen_bit < PARA_AFIFO_SYNC_W) | rtl/m_vlsit_afifo_sync.sv:47 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_flush_req_sync.u_vlsit_afifo_cell_sync.u_dont_touch_dff_0 | VLSIT_CELL_SYNC_DFF_RN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_BYPASS) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) if(S) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) begin : gen_dff2 logic w_mid; if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:61 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_flush_req_sync.u_vlsit_afifo_cell_sync.u_dont_touch_dff_1 | VLSIT_CELL_SYNC_DFF_RN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_BYPASS) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) if(S) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) begin : gen_dff2 logic w_mid; if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:62 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_flush_req_sync.u_vlsit_afifo_cell_sync.u_dont_touch_dff_0 | VLSIT_CELL_SYNC_DFF_SN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_BYPASS) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:64 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_flush_req_sync.u_vlsit_afifo_cell_sync.u_dont_touch_dff_1 | VLSIT_CELL_SYNC_DFF_SN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_BYPASS) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:65 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_flush_req_sync.u_vlsit_afifo_cell_sync.u_dont_touch_sync2ff | VLSIT_CELL_SYNC_2FF_RN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC2) if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC2) begin : gen_sync2 if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:70 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_flush_req_sync.u_vlsit_afifo_cell_sync.u_dont_touch_sync2ff | VLSIT_CELL_SYNC_2FF_SN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC2) else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:72 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_flush_req_sync.u_vlsit_afifo_cell_sync.u_dont_touch_sync3ff | VLSIT_CELL_SYNC_3FF_RN | 1 | if( VLSIT_CELL_SYNC_2FF_SN u_dont_touch_sync2ff (.CK (i_clk_dst), .SN (i_rst_n_dst), .D (i_d), .Q (o_q)); end end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC3) if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC3) begin : gen_sync3 if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:77 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_flush_req_sync.u_vlsit_afifo_cell_sync.u_dont_touch_sync3ff | VLSIT_CELL_SYNC_3FF_SN | 1 | if( VLSIT_CELL_SYNC_2FF_SN u_dont_touch_sync2ff (.CK (i_clk_dst), .SN (i_rst_n_dst), .D (i_d), .Q (o_q)); end end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC3) else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:79 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_flush_req_sync.u_vlsit_afifo_cell_sync.u_dont_touch_sync4ff | VLSIT_CELL_SYNC_4FF_RN | 1 | else if(L_SYNC_3FF_SN u_dont_touch_sync3ff (.CK (i_clk_dst), .SN (i_rst_n_dst), .D (i_d), .Q (o_q)); end end else begin : gen_sync4 if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:84 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_flush_req_sync.u_vlsit_afifo_cell_sync.u_dont_touch_sync4ff | VLSIT_CELL_SYNC_4FF_SN | 1 | else else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:86 |
| 3 | u_dvp_apb_service.u_dvp_buf.u_afifo_flush_busy_sync | m_vlsit_afifo_sync | 1 |  | rtl/m_dvp_buffer.sv:250 |
| 4 | u_dvp_apb_service.u_dvp_buf.u_afifo_flush_busy_sync.u_vlsit_afifo_cell_sync | m_vlsit_afifo_cell_sync | 1 | for(gen_bit < PARA_AFIFO_SYNC_W) | rtl/m_vlsit_afifo_sync.sv:47 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_flush_busy_sync.u_vlsit_afifo_cell_sync.u_dont_touch_dff_0 | VLSIT_CELL_SYNC_DFF_RN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_BYPASS) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) if(S) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) begin : gen_dff2 logic w_mid; if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:61 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_flush_busy_sync.u_vlsit_afifo_cell_sync.u_dont_touch_dff_1 | VLSIT_CELL_SYNC_DFF_RN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_BYPASS) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) if(S) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) begin : gen_dff2 logic w_mid; if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:62 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_flush_busy_sync.u_vlsit_afifo_cell_sync.u_dont_touch_dff_0 | VLSIT_CELL_SYNC_DFF_SN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_BYPASS) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:64 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_flush_busy_sync.u_vlsit_afifo_cell_sync.u_dont_touch_dff_1 | VLSIT_CELL_SYNC_DFF_SN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_BYPASS) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:65 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_flush_busy_sync.u_vlsit_afifo_cell_sync.u_dont_touch_sync2ff | VLSIT_CELL_SYNC_2FF_RN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC2) if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC2) begin : gen_sync2 if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:70 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_flush_busy_sync.u_vlsit_afifo_cell_sync.u_dont_touch_sync2ff | VLSIT_CELL_SYNC_2FF_SN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC2) else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:72 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_flush_busy_sync.u_vlsit_afifo_cell_sync.u_dont_touch_sync3ff | VLSIT_CELL_SYNC_3FF_RN | 1 | if( VLSIT_CELL_SYNC_2FF_SN u_dont_touch_sync2ff (.CK (i_clk_dst), .SN (i_rst_n_dst), .D (i_d), .Q (o_q)); end end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC3) if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC3) begin : gen_sync3 if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:77 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_flush_busy_sync.u_vlsit_afifo_cell_sync.u_dont_touch_sync3ff | VLSIT_CELL_SYNC_3FF_SN | 1 | if( VLSIT_CELL_SYNC_2FF_SN u_dont_touch_sync2ff (.CK (i_clk_dst), .SN (i_rst_n_dst), .D (i_d), .Q (o_q)); end end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC3) else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:79 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_flush_busy_sync.u_vlsit_afifo_cell_sync.u_dont_touch_sync4ff | VLSIT_CELL_SYNC_4FF_RN | 1 | else if(L_SYNC_3FF_SN u_dont_touch_sync3ff (.CK (i_clk_dst), .SN (i_rst_n_dst), .D (i_d), .Q (o_q)); end end else begin : gen_sync4 if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:84 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_flush_busy_sync.u_vlsit_afifo_cell_sync.u_dont_touch_sync4ff | VLSIT_CELL_SYNC_4FF_SN | 1 | else else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:86 |
| 3 | u_dvp_apb_service.u_dvp_buf.u_afifo_overflow_sync | m_vlsit_event_sync | 1 |  | rtl/m_dvp_buffer.sv:262 |
| 4 | u_dvp_apb_service.u_dvp_buf.u_afifo_overflow_sync.u_vlsit_afifo_cell_sync_0 | m_vlsit_afifo_cell_sync | 1 | for(gen_event_idx < PARA_EVENT_SYNC_W) | rtl_lib/m_vlsit_event_sync.sv:48 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_overflow_sync.u_vlsit_afifo_cell_sync_0.u_dont_touch_dff_0 | VLSIT_CELL_SYNC_DFF_RN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_BYPASS) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) if(S) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) begin : gen_dff2 logic w_mid; if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:61 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_overflow_sync.u_vlsit_afifo_cell_sync_0.u_dont_touch_dff_1 | VLSIT_CELL_SYNC_DFF_RN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_BYPASS) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) if(S) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) begin : gen_dff2 logic w_mid; if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:62 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_overflow_sync.u_vlsit_afifo_cell_sync_0.u_dont_touch_dff_0 | VLSIT_CELL_SYNC_DFF_SN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_BYPASS) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:64 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_overflow_sync.u_vlsit_afifo_cell_sync_0.u_dont_touch_dff_1 | VLSIT_CELL_SYNC_DFF_SN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_BYPASS) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:65 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_overflow_sync.u_vlsit_afifo_cell_sync_0.u_dont_touch_sync2ff | VLSIT_CELL_SYNC_2FF_RN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC2) if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC2) begin : gen_sync2 if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:70 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_overflow_sync.u_vlsit_afifo_cell_sync_0.u_dont_touch_sync2ff | VLSIT_CELL_SYNC_2FF_SN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC2) else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:72 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_overflow_sync.u_vlsit_afifo_cell_sync_0.u_dont_touch_sync3ff | VLSIT_CELL_SYNC_3FF_RN | 1 | if( VLSIT_CELL_SYNC_2FF_SN u_dont_touch_sync2ff (.CK (i_clk_dst), .SN (i_rst_n_dst), .D (i_d), .Q (o_q)); end end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC3) if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC3) begin : gen_sync3 if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:77 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_overflow_sync.u_vlsit_afifo_cell_sync_0.u_dont_touch_sync3ff | VLSIT_CELL_SYNC_3FF_SN | 1 | if( VLSIT_CELL_SYNC_2FF_SN u_dont_touch_sync2ff (.CK (i_clk_dst), .SN (i_rst_n_dst), .D (i_d), .Q (o_q)); end end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC3) else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:79 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_overflow_sync.u_vlsit_afifo_cell_sync_0.u_dont_touch_sync4ff | VLSIT_CELL_SYNC_4FF_RN | 1 | else if(L_SYNC_3FF_SN u_dont_touch_sync3ff (.CK (i_clk_dst), .SN (i_rst_n_dst), .D (i_d), .Q (o_q)); end end else begin : gen_sync4 if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:84 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_overflow_sync.u_vlsit_afifo_cell_sync_0.u_dont_touch_sync4ff | VLSIT_CELL_SYNC_4FF_SN | 1 | else else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:86 |
| 4 | u_dvp_apb_service.u_dvp_buf.u_afifo_overflow_sync.u_vlsit_afifo_cell_sync_1 | m_vlsit_afifo_cell_sync | 1 | for(gen_event_idx < PARA_EVENT_SYNC_W) | rtl_lib/m_vlsit_event_sync.sv:58 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_overflow_sync.u_vlsit_afifo_cell_sync_1.u_dont_touch_dff_0 | VLSIT_CELL_SYNC_DFF_RN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_BYPASS) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) if(S) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) begin : gen_dff2 logic w_mid; if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:61 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_overflow_sync.u_vlsit_afifo_cell_sync_1.u_dont_touch_dff_1 | VLSIT_CELL_SYNC_DFF_RN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_BYPASS) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) if(S) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) begin : gen_dff2 logic w_mid; if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:62 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_overflow_sync.u_vlsit_afifo_cell_sync_1.u_dont_touch_dff_0 | VLSIT_CELL_SYNC_DFF_SN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_BYPASS) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:64 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_overflow_sync.u_vlsit_afifo_cell_sync_1.u_dont_touch_dff_1 | VLSIT_CELL_SYNC_DFF_SN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_BYPASS) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:65 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_overflow_sync.u_vlsit_afifo_cell_sync_1.u_dont_touch_sync2ff | VLSIT_CELL_SYNC_2FF_RN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC2) if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC2) begin : gen_sync2 if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:70 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_overflow_sync.u_vlsit_afifo_cell_sync_1.u_dont_touch_sync2ff | VLSIT_CELL_SYNC_2FF_SN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC2) else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:72 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_overflow_sync.u_vlsit_afifo_cell_sync_1.u_dont_touch_sync3ff | VLSIT_CELL_SYNC_3FF_RN | 1 | if( VLSIT_CELL_SYNC_2FF_SN u_dont_touch_sync2ff (.CK (i_clk_dst), .SN (i_rst_n_dst), .D (i_d), .Q (o_q)); end end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC3) if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC3) begin : gen_sync3 if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:77 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_overflow_sync.u_vlsit_afifo_cell_sync_1.u_dont_touch_sync3ff | VLSIT_CELL_SYNC_3FF_SN | 1 | if( VLSIT_CELL_SYNC_2FF_SN u_dont_touch_sync2ff (.CK (i_clk_dst), .SN (i_rst_n_dst), .D (i_d), .Q (o_q)); end end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC3) else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:79 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_overflow_sync.u_vlsit_afifo_cell_sync_1.u_dont_touch_sync4ff | VLSIT_CELL_SYNC_4FF_RN | 1 | else if(L_SYNC_3FF_SN u_dont_touch_sync3ff (.CK (i_clk_dst), .SN (i_rst_n_dst), .D (i_d), .Q (o_q)); end end else begin : gen_sync4 if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:84 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_overflow_sync.u_vlsit_afifo_cell_sync_1.u_dont_touch_sync4ff | VLSIT_CELL_SYNC_4FF_SN | 1 | else else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:86 |
| 3 | u_dvp_apb_service.u_dvp_buf.u_afifo_frame_start_sync | m_vlsit_event_sync | 1 |  | rtl/m_dvp_buffer.sv:275 |
| 4 | u_dvp_apb_service.u_dvp_buf.u_afifo_frame_start_sync.u_vlsit_afifo_cell_sync_0 | m_vlsit_afifo_cell_sync | 1 | for(gen_event_idx < PARA_EVENT_SYNC_W) | rtl_lib/m_vlsit_event_sync.sv:48 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_frame_start_sync.u_vlsit_afifo_cell_sync_0.u_dont_touch_dff_0 | VLSIT_CELL_SYNC_DFF_RN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_BYPASS) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) if(S) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) begin : gen_dff2 logic w_mid; if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:61 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_frame_start_sync.u_vlsit_afifo_cell_sync_0.u_dont_touch_dff_1 | VLSIT_CELL_SYNC_DFF_RN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_BYPASS) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) if(S) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) begin : gen_dff2 logic w_mid; if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:62 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_frame_start_sync.u_vlsit_afifo_cell_sync_0.u_dont_touch_dff_0 | VLSIT_CELL_SYNC_DFF_SN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_BYPASS) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:64 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_frame_start_sync.u_vlsit_afifo_cell_sync_0.u_dont_touch_dff_1 | VLSIT_CELL_SYNC_DFF_SN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_BYPASS) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:65 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_frame_start_sync.u_vlsit_afifo_cell_sync_0.u_dont_touch_sync2ff | VLSIT_CELL_SYNC_2FF_RN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC2) if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC2) begin : gen_sync2 if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:70 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_frame_start_sync.u_vlsit_afifo_cell_sync_0.u_dont_touch_sync2ff | VLSIT_CELL_SYNC_2FF_SN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC2) else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:72 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_frame_start_sync.u_vlsit_afifo_cell_sync_0.u_dont_touch_sync3ff | VLSIT_CELL_SYNC_3FF_RN | 1 | if( VLSIT_CELL_SYNC_2FF_SN u_dont_touch_sync2ff (.CK (i_clk_dst), .SN (i_rst_n_dst), .D (i_d), .Q (o_q)); end end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC3) if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC3) begin : gen_sync3 if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:77 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_frame_start_sync.u_vlsit_afifo_cell_sync_0.u_dont_touch_sync3ff | VLSIT_CELL_SYNC_3FF_SN | 1 | if( VLSIT_CELL_SYNC_2FF_SN u_dont_touch_sync2ff (.CK (i_clk_dst), .SN (i_rst_n_dst), .D (i_d), .Q (o_q)); end end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC3) else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:79 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_frame_start_sync.u_vlsit_afifo_cell_sync_0.u_dont_touch_sync4ff | VLSIT_CELL_SYNC_4FF_RN | 1 | else if(L_SYNC_3FF_SN u_dont_touch_sync3ff (.CK (i_clk_dst), .SN (i_rst_n_dst), .D (i_d), .Q (o_q)); end end else begin : gen_sync4 if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:84 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_frame_start_sync.u_vlsit_afifo_cell_sync_0.u_dont_touch_sync4ff | VLSIT_CELL_SYNC_4FF_SN | 1 | else else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:86 |
| 4 | u_dvp_apb_service.u_dvp_buf.u_afifo_frame_start_sync.u_vlsit_afifo_cell_sync_1 | m_vlsit_afifo_cell_sync | 1 | for(gen_event_idx < PARA_EVENT_SYNC_W) | rtl_lib/m_vlsit_event_sync.sv:58 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_frame_start_sync.u_vlsit_afifo_cell_sync_1.u_dont_touch_dff_0 | VLSIT_CELL_SYNC_DFF_RN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_BYPASS) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) if(S) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) begin : gen_dff2 logic w_mid; if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:61 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_frame_start_sync.u_vlsit_afifo_cell_sync_1.u_dont_touch_dff_1 | VLSIT_CELL_SYNC_DFF_RN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_BYPASS) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) if(S) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) begin : gen_dff2 logic w_mid; if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:62 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_frame_start_sync.u_vlsit_afifo_cell_sync_1.u_dont_touch_dff_0 | VLSIT_CELL_SYNC_DFF_SN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_BYPASS) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:64 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_frame_start_sync.u_vlsit_afifo_cell_sync_1.u_dont_touch_dff_1 | VLSIT_CELL_SYNC_DFF_SN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_BYPASS) begin : gen_bypass assign o_q = i_d; end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_DFF2) else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:65 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_frame_start_sync.u_vlsit_afifo_cell_sync_1.u_dont_touch_sync2ff | VLSIT_CELL_SYNC_2FF_RN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC2) if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC2) begin : gen_sync2 if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:70 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_frame_start_sync.u_vlsit_afifo_cell_sync_1.u_dont_touch_sync2ff | VLSIT_CELL_SYNC_2FF_SN | 1 | if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC2) else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:72 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_frame_start_sync.u_vlsit_afifo_cell_sync_1.u_dont_touch_sync3ff | VLSIT_CELL_SYNC_3FF_RN | 1 | if( VLSIT_CELL_SYNC_2FF_SN u_dont_touch_sync2ff (.CK (i_clk_dst), .SN (i_rst_n_dst), .D (i_d), .Q (o_q)); end end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC3) if(PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC3) begin : gen_sync3 if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:77 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_frame_start_sync.u_vlsit_afifo_cell_sync_1.u_dont_touch_sync3ff | VLSIT_CELL_SYNC_3FF_SN | 1 | if( VLSIT_CELL_SYNC_2FF_SN u_dont_touch_sync2ff (.CK (i_clk_dst), .SN (i_rst_n_dst), .D (i_d), .Q (o_q)); end end else if (PARA_AFIFO_CELL_TYPE == LPARA_TYPE_SYNC3) else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:79 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_frame_start_sync.u_vlsit_afifo_cell_sync_1.u_dont_touch_sync4ff | VLSIT_CELL_SYNC_4FF_RN | 1 | else if(L_SYNC_3FF_SN u_dont_touch_sync3ff (.CK (i_clk_dst), .SN (i_rst_n_dst), .D (i_d), .Q (o_q)); end end else begin : gen_sync4 if (PARA_AFIFO_CELL_RST_VAL == 32'd0) conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:84 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_afifo_frame_start_sync.u_vlsit_afifo_cell_sync_1.u_dont_touch_sync4ff | VLSIT_CELL_SYNC_4FF_SN | 1 | else else conditional | rtl_lib/m_vlsit_afifo_cell_sync.sv:86 |
| 3 | u_dvp_apb_service.u_dvp_buf.u_dvp_gate_bridge | m_dvp_gate_bridge | 1 |  | rtl/m_dvp_buffer.sv:288 |
| 3 | u_dvp_apb_service.u_dvp_buf.u_dvp_sfifo | m_vlsit_sfifo_top | 1 |  | rtl/m_dvp_buffer.sv:307 |
| 4 | u_dvp_apb_service.u_dvp_buf.u_dvp_sfifo.u_vlsit_sfifo_wr | m_vlsit_sfifo_wr | 1 |  | rtl/m_vlsit_sfifo_top.sv:81 |
| 4 | u_dvp_apb_service.u_dvp_buf.u_dvp_sfifo.u_vlsit_sfifo_rd | m_vlsit_sfifo_rd | 1 |  | rtl/m_vlsit_sfifo_top.sv:106 |
| 4 | u_dvp_apb_service.u_dvp_buf.u_dvp_sfifo.u_vlsit_sfifo_mem | m_vlsit_sfifo_mem | 1 |  | rtl/m_vlsit_sfifo_top.sv:128 |
| 5 | u_dvp_apb_service.u_dvp_buf.u_dvp_sfifo.u_vlsit_sfifo_mem.u_vlsit_sfifo_ram_macro | m_vlsit_sfifo_ram_macro | 1 | else conditional | rtl/m_vlsit_sfifo_mem.sv:75 |
| 6 | u_dvp_apb_service.u_dvp_buf.u_dvp_sfifo.u_vlsit_sfifo_mem.u_vlsit_sfifo_ram_macro.u_dont_touch_sram | VLSIT_CELL_SRAM_1W1R | 1 |  | rtl_lib/m_vlsit_sfifo_ram_macro.sv:43 |
| 2 | u_dvp_apb_service.u_dma_req | m_dvp_dma_req | 1 |  | rtl/m_dvp_apb_service.sv:268 |

### Instance totals under the top

| Module | Total instances under the top | Parent modules | Source |
| --- | --- | --- | --- |
| VLSIT_CELL_SRAM_1W1R | 2 | m_vlsit_afifo_ram_macro, m_vlsit_sfifo_ram_macro | rtl_cells/VLSIT_CELL_SRAM_1W1R.sv:24 |
| VLSIT_CELL_SYNC_2FF_RN | 22 | m_vlsit_afifo_cell_sync, m_vlsit_rst_sync | rtl_cells/VLSIT_CELL_SYNC_2FF_RN.sv:19 |
| VLSIT_CELL_SYNC_2FF_SN | 20 | m_vlsit_afifo_cell_sync | rtl_cells/VLSIT_CELL_SYNC_2FF_SN.sv:19 |
| VLSIT_CELL_SYNC_3FF_RN | 22 | m_vlsit_afifo_cell_sync, m_vlsit_rst_sync | rtl_cells/VLSIT_CELL_SYNC_3FF_RN.sv:19 |
| VLSIT_CELL_SYNC_3FF_SN | 20 | m_vlsit_afifo_cell_sync | rtl_cells/VLSIT_CELL_SYNC_3FF_SN.sv:19 |
| VLSIT_CELL_SYNC_4FF_RN | 22 | m_vlsit_afifo_cell_sync, m_vlsit_rst_sync | rtl_cells/VLSIT_CELL_SYNC_4FF_RN.sv:19 |
| VLSIT_CELL_SYNC_4FF_SN | 20 | m_vlsit_afifo_cell_sync | rtl_cells/VLSIT_CELL_SYNC_4FF_SN.sv:19 |
| VLSIT_CELL_SYNC_DFF_RN | 44 | m_vlsit_afifo_cell_sync, m_vlsit_rst_sync | rtl_cells/VLSIT_CELL_SYNC_DFF_RN.sv:18 |
| VLSIT_CELL_SYNC_DFF_SN | 40 | m_vlsit_afifo_cell_sync | rtl_cells/VLSIT_CELL_SYNC_DFF_SN.sv:18 |
| VLSIT_CELL_TIEH | 4 | m_vlsit_rst_sync, m_vlsit_tie | rtl_cells/VLSIT_CELL_TIEH.sv:16 |
| VLSIT_CELL_TIEL | 2 | m_vlsit_tie | rtl_cells/VLSIT_CELL_TIEL.sv:16 |
| m_dvp_afifo | 1 | m_dvp_buffer | rtl/m_dvp_afifo.sv:13 |
| m_dvp_afifo_rd | 1 | m_dvp_afifo | rtl/m_dvp_afifo_rd.sv:18 |
| m_dvp_apb_data | 1 | m_dvp_apb_service | rtl/m_dvp_apb_data.sv:12 |
| m_dvp_apb_decode | 1 | m_dvp_apb_service | rtl/m_dvp_apb_decode.sv:12 |
| m_dvp_apb_service | 1 | m_dvp_controller | rtl/m_dvp_apb_service.sv:12 |
| m_dvp_buffer | 1 | m_dvp_apb_service | rtl/m_dvp_buffer.sv:13 |
| m_dvp_capture | 1 | m_dvp_controller | rtl/m_dvp_capture.sv:13 |
| m_dvp_dma_req | 1 | m_dvp_apb_service | rtl/m_dvp_dma_req.sv:12 |
| m_dvp_gate_bridge | 1 | m_dvp_buffer | rtl/m_dvp_gate_bridge.sv:13 |
| m_vlsit_afifo_cell_sync | 20 | m_vlsit_afifo_sync, m_vlsit_csr_sync, m_vlsit_event_sync | rtl_lib/m_vlsit_afifo_cell_sync.sv:25 |
| m_vlsit_afifo_mem | 1 | m_dvp_afifo | rtl/m_vlsit_afifo_mem.sv:17 |
| m_vlsit_afifo_ram_macro | 1 | m_vlsit_afifo_mem | rtl_lib/m_vlsit_afifo_ram_macro.sv:16 |
| m_vlsit_afifo_sync | 6 | m_dvp_afifo_rd, m_dvp_buffer, m_vlsit_afifo_wr | rtl/m_vlsit_afifo_sync.sv:17 |
| m_vlsit_afifo_wr | 1 | m_dvp_afifo | rtl/m_vlsit_afifo_wr.sv:18 |
| m_vlsit_csr_dvp | 1 | m_dvp_apb_service | rtl/csr/m_vlsit_csr_dvp.sv:15 |
| m_vlsit_csr_sync | 4 | m_vlsit_csr_dvp | rtl/csr/m_vlsit_csr_sync.sv:17 |
| m_vlsit_event_sync | 2 | m_dvp_buffer | rtl_lib/m_vlsit_event_sync.sv:14 |
| m_vlsit_rst_sync | 2 | m_dvp_controller | rtl_lib/m_vlsit_rst_sync.sv:23 |
| m_vlsit_sfifo_mem | 1 | m_vlsit_sfifo_top | rtl/m_vlsit_sfifo_mem.sv:17 |
| m_vlsit_sfifo_ram_macro | 1 | m_vlsit_sfifo_mem | rtl_lib/m_vlsit_sfifo_ram_macro.sv:18 |
| m_vlsit_sfifo_rd | 1 | m_vlsit_sfifo_top | rtl/m_vlsit_sfifo_rd.sv:21 |
| m_vlsit_sfifo_top | 1 | m_dvp_buffer | rtl/m_vlsit_sfifo_top.sv:18 |
| m_vlsit_sfifo_wr | 1 | m_vlsit_sfifo_top | rtl/m_vlsit_sfifo_wr.sv:19 |
| m_vlsit_tie | 2 | m_dvp_apb_service | rtl_lib/m_vlsit_tie.sv:17 |

Modules not reachable from the top: VLSIT_CELL_AND2, VLSIT_CELL_AND3, VLSIT_CELL_AND4, VLSIT_CELL_AO21, VLSIT_CELL_AO22, VLSIT_CELL_AOI21, VLSIT_CELL_AOI211, VLSIT_CELL_AOI22, VLSIT_CELL_BUF, VLSIT_CELL_CKAND2, VLSIT_CELL_CKBUF, VLSIT_CELL_CKINV, VLSIT_CELL_CKMUX2, VLSIT_CELL_DFF, VLSIT_CELL_DFFE, VLSIT_CELL_DFFE_RN, VLSIT_CELL_DFFN, VLSIT_CELL_DFFN_RN, VLSIT_CELL_DFF_RN, VLSIT_CELL_DFF_RSN, VLSIT_CELL_DFF_SN, VLSIT_CELL_FA, VLSIT_CELL_HA, VLSIT_CELL_ICG, VLSIT_CELL_INV, VLSIT_CELL_LAT_H, VLSIT_CELL_LAT_L, VLSIT_CELL_MUX2, VLSIT_CELL_MUX4, VLSIT_CELL_MUXI2, VLSIT_CELL_NAND2, VLSIT_CELL_NAND3, VLSIT_CELL_NAND4, VLSIT_CELL_NOR2, VLSIT_CELL_NOR3, VLSIT_CELL_NOR4, VLSIT_CELL_OA21, VLSIT_CELL_OA22, VLSIT_CELL_OAI21, VLSIT_CELL_OAI211, VLSIT_CELL_OAI22, VLSIT_CELL_OR2, VLSIT_CELL_OR3, VLSIT_CELL_OR4, VLSIT_CELL_SDFF, VLSIT_CELL_SDFF_RN, VLSIT_CELL_XNOR2, VLSIT_CELL_XNOR3, VLSIT_CELL_XOR2, VLSIT_CELL_XOR3, m_vlsit_afifo_rd, m_vlsit_afifo_top, m_vlsit_clk_inv

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

#### `VLSIT_CELL_SRAM_1W1R` (rtl_cells/VLSIT_CELL_SRAM_1W1R.sv:24)

| Parameter | Default | Kind |
| --- | --- | --- |
| `ADDR_W` | `3` | parameter |
| `DATA_W` | `8` | parameter |
| `LPARA_DEPTH` | `32'd1 << ADDR_W` | parameter |

| Port | Direction | Width | Type | Function (fill from the source) | Line |
| --- | --- | --- | --- | --- | --- |
| `CLKW` | input | 1 | wire | <fill> | 35 |
| `WEB` | input | 1 | wire | <fill> | 35 |
| `AW` | input | [ADDR_W-1:0] | wire | <fill> | 35 |
| `DW` | input | [DATA_W-1:0] | wire | <fill> | 35 |
| `BWEB` | input | [DATA_W-1:0] | wire | <fill> | 35 |
| `CLKR` | input | 1 | wire | <fill> | 35 |
| `REB` | input | 1 | wire | <fill> | 35 |
| `AR` | input | [ADDR_W-1:0] | wire | <fill> | 35 |
| `QR` | output | [DATA_W-1:0] | logic | <fill> | 35 |

#### `VLSIT_CELL_SYNC_2FF_RN` (rtl_cells/VLSIT_CELL_SYNC_2FF_RN.sv:19)

| Parameter | Default | Kind |
| --- | --- | --- |
| `LPARA_CELL_STAGE` | `2` | parameter |

| Port | Direction | Width | Type | Function (fill from the source) | Line |
| --- | --- | --- | --- | --- | --- |
| `CK` | input | 1 | wire | <fill> | 21 |
| `RN` | input | 1 | wire | <fill> | 21 |
| `D` | input | 1 | wire | <fill> | 21 |
| `Q` | output | 1 | logic | <fill> | 21 |

#### `VLSIT_CELL_SYNC_2FF_SN` (rtl_cells/VLSIT_CELL_SYNC_2FF_SN.sv:19)

| Parameter | Default | Kind |
| --- | --- | --- |
| `LPARA_CELL_STAGE` | `2` | parameter |

| Port | Direction | Width | Type | Function (fill from the source) | Line |
| --- | --- | --- | --- | --- | --- |
| `CK` | input | 1 | wire | <fill> | 21 |
| `SN` | input | 1 | wire | <fill> | 21 |
| `D` | input | 1 | wire | <fill> | 21 |
| `Q` | output | 1 | logic | <fill> | 21 |

#### `VLSIT_CELL_SYNC_3FF_RN` (rtl_cells/VLSIT_CELL_SYNC_3FF_RN.sv:19)

| Parameter | Default | Kind |
| --- | --- | --- |
| `LPARA_CELL_STAGE` | `3` | parameter |

| Port | Direction | Width | Type | Function (fill from the source) | Line |
| --- | --- | --- | --- | --- | --- |
| `CK` | input | 1 | wire | <fill> | 21 |
| `RN` | input | 1 | wire | <fill> | 21 |
| `D` | input | 1 | wire | <fill> | 21 |
| `Q` | output | 1 | logic | <fill> | 21 |

#### `VLSIT_CELL_SYNC_3FF_SN` (rtl_cells/VLSIT_CELL_SYNC_3FF_SN.sv:19)

| Parameter | Default | Kind |
| --- | --- | --- |
| `LPARA_CELL_STAGE` | `3` | parameter |

| Port | Direction | Width | Type | Function (fill from the source) | Line |
| --- | --- | --- | --- | --- | --- |
| `CK` | input | 1 | wire | <fill> | 21 |
| `SN` | input | 1 | wire | <fill> | 21 |
| `D` | input | 1 | wire | <fill> | 21 |
| `Q` | output | 1 | logic | <fill> | 21 |

#### `VLSIT_CELL_SYNC_4FF_RN` (rtl_cells/VLSIT_CELL_SYNC_4FF_RN.sv:19)

| Parameter | Default | Kind |
| --- | --- | --- |
| `LPARA_CELL_STAGE` | `4` | parameter |

| Port | Direction | Width | Type | Function (fill from the source) | Line |
| --- | --- | --- | --- | --- | --- |
| `CK` | input | 1 | wire | <fill> | 21 |
| `RN` | input | 1 | wire | <fill> | 21 |
| `D` | input | 1 | wire | <fill> | 21 |
| `Q` | output | 1 | logic | <fill> | 21 |

#### `VLSIT_CELL_SYNC_4FF_SN` (rtl_cells/VLSIT_CELL_SYNC_4FF_SN.sv:19)

| Parameter | Default | Kind |
| --- | --- | --- |
| `LPARA_CELL_STAGE` | `4` | parameter |

| Port | Direction | Width | Type | Function (fill from the source) | Line |
| --- | --- | --- | --- | --- | --- |
| `CK` | input | 1 | wire | <fill> | 21 |
| `SN` | input | 1 | wire | <fill> | 21 |
| `D` | input | 1 | wire | <fill> | 21 |
| `Q` | output | 1 | logic | <fill> | 21 |

#### `VLSIT_CELL_SYNC_DFF_RN` (rtl_cells/VLSIT_CELL_SYNC_DFF_RN.sv:18)

| Port | Direction | Width | Type | Function (fill from the source) | Line |
| --- | --- | --- | --- | --- | --- |
| `CK` | input | 1 | wire | <fill> | 18 |
| `RN` | input | 1 | wire | <fill> | 18 |
| `D` | input | 1 | wire | <fill> | 18 |
| `Q` | output | 1 | logic | <fill> | 18 |

#### `VLSIT_CELL_SYNC_DFF_SN` (rtl_cells/VLSIT_CELL_SYNC_DFF_SN.sv:18)

| Port | Direction | Width | Type | Function (fill from the source) | Line |
| --- | --- | --- | --- | --- | --- |
| `CK` | input | 1 | wire | <fill> | 18 |
| `SN` | input | 1 | wire | <fill> | 18 |
| `D` | input | 1 | wire | <fill> | 18 |
| `Q` | output | 1 | logic | <fill> | 18 |

#### `VLSIT_CELL_TIEH` (rtl_cells/VLSIT_CELL_TIEH.sv:16)

| Port | Direction | Width | Type | Function (fill from the source) | Line |
| --- | --- | --- | --- | --- | --- |
| `Z` | output | 1 | logic | <fill> | 16 |

#### `VLSIT_CELL_TIEL` (rtl_cells/VLSIT_CELL_TIEL.sv:16)

| Port | Direction | Width | Type | Function (fill from the source) | Line |
| --- | --- | --- | --- | --- | --- |
| `Z` | output | 1 | logic | <fill> | 16 |

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
| `i_rst_n_sw` | input | 1 | wire | <fill> | 33 |
| `o_sw_rst_busy` | output | 1 | logic | <fill> | 33 |
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
| `LPARA_VERSION_MINOR` | `32'd1` | parameter |
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
| `i_cont_frame_start` | input | 1 | wire | <fill> | 40 |
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

#### `m_dvp_buffer` (rtl/m_dvp_buffer.sv:13)

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
| `i_clk_apb` | input | 1 | wire | <fill> | 37 |
| `i_rst_n_apb` | input | 1 | wire | <fill> | 37 |
| `i_clk_dvp` | input | 1 | wire | <fill> | 37 |
| `i_rst_n_dvp` | input | 1 | wire | <fill> | 37 |
| `i_capture_en` | input | 1 | wire | <fill> | 37 |
| `i_pclk_mode` | input | 1 | wire | <fill> | 37 |
| `i_dvp_vsync` | input | 1 | wire | <fill> | 37 |
| `i_cont_frame_active` | input | 1 | wire | <fill> | 37 |
| `i_cont_frame_start` | input | 1 | wire | <fill> | 37 |
| `i_afifo_wr_en` | input | 1 | wire | <fill> | 37 |
| `i_afifo_wr_data` | input | [PARA_DATA_W-1:0] | wire | <fill> | 37 |
| `i_pixel_toggle` | input | 1 | wire | <fill> | 37 |
| `i_gated_data` | input | [PARA_DATA_W-1:0] | wire | <fill> | 37 |
| `i_capture_quiescent` | input | 1 | wire | <fill> | 37 |
| `i_flush_req` | input | 1 | wire | <fill> | 37 |
| `i_rd_en` | input | 1 | wire | <fill> | 37 |
| `o_rd_data` | output | [PARA_DATA_W-1:0] | logic | <fill> | 37 |
| `o_empty` | output | 1 | logic | <fill> | 37 |
| `o_full` | output | 1 | logic | <fill> | 37 |
| `o_occupancy` | output | [31:0] | logic | <fill> | 37 |
| `o_active` | output | 1 | logic | <fill> | 37 |
| `o_overflow_event` | output | 1 | logic | <fill> | 37 |
| `o_mode_change_safe` | output | 1 | logic | <fill> | 37 |
| `o_frame_start` | output | 1 | logic | <fill> | 37 |
| `o_flush_busy` | output | 1 | logic | <fill> | 37 |
| `o_flush_done` | output | 1 | logic | <fill> | 37 |

#### `m_dvp_capture` (rtl/m_dvp_capture.sv:13)

| Parameter | Default | Kind |
| --- | --- | --- |
| `PARA_DATA_W` | `32'd8` | parameter |
| `PARA_SAMPLE_EDGE` | `32'd0` | parameter |
| `PARA_VSYNC_ACTIVE` | `32'd1` | parameter |
| `PARA_HREF_ACTIVE` | `32'd1` | parameter |

| Port | Direction | Width | Type | Function (fill from the source) | Line |
| --- | --- | --- | --- | --- | --- |
| `i_clk_dvp` | input | 1 | wire | <fill> | 30 |
| `i_rst_n_dvp` | input | 1 | wire | <fill> | 30 |
| `i_rst_n_gated` | input | 1 | wire | <fill> | 30 |
| `i_dvp_data` | input | [PARA_DATA_W-1:0] | wire | <fill> | 30 |
| `i_dvp_vsync` | input | 1 | wire | <fill> | 30 |
| `i_dvp_href` | input | 1 | wire | <fill> | 30 |
| `i_capture_en` | input | 1 | wire | <fill> | 30 |
| `i_pclk_mode` | input | 1 | wire | <fill> | 30 |
| `o_afifo_wr_en` | output | 1 | logic | <fill> | 30 |
| `o_afifo_wr_data` | output | [PARA_DATA_W-1:0] | logic | <fill> | 30 |
| `o_gated_data` | output | [PARA_DATA_W-1:0] | logic | <fill> | 30 |
| `o_valid_toggle` | output | 1 | logic | <fill> | 30 |
| `o_cont_frame_active` | output | 1 | logic | <fill> | 30 |
| `o_cont_frame_start` | output | 1 | logic | <fill> | 30 |
| `o_capture_quiescent` | output | 1 | logic | <fill> | 30 |

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

#### `m_dvp_gate_bridge` (rtl/m_dvp_gate_bridge.sv:13)

| Parameter | Default | Kind |
| --- | --- | --- |
| `PARA_DATA_W` | `32'd8` | parameter |
| `PARA_VSYNC_ACTIVE` | `32'd1` | parameter |

| Port | Direction | Width | Type | Function (fill from the source) | Line |
| --- | --- | --- | --- | --- | --- |
| `i_clk_apb` | input | 1 | wire | <fill> | 22 |
| `i_rst_n_apb` | input | 1 | wire | <fill> | 22 |
| `i_dvp_vsync` | input | 1 | wire | <fill> | 22 |
| `i_pixel_data` | input | [PARA_DATA_W-1:0] | wire | <fill> | 22 |
| `i_pixel_toggle` | input | 1 | wire | <fill> | 22 |
| `i_capture_en` | input | 1 | wire | <fill> | 22 |
| `i_pclk_mode` | input | 1 | wire | <fill> | 22 |
| `o_frame_active` | output | 1 | logic | <fill> | 22 |
| `o_frame_start` | output | 1 | logic | <fill> | 22 |
| `o_sfifo_wr_en` | output | 1 | logic | <fill> | 22 |
| `o_sfifo_wr_data` | output | [PARA_DATA_W-1:0] | logic | <fill> | 22 |
| `o_path_quiescent` | output | 1 | logic | <fill> | 22 |

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
| `LPARA_DVP_FRAME_COUNT_OFFSET` | `32'h0018` | parameter |

| Port | Direction | Width | Type | Function (fill from the source) | Line |
| --- | --- | --- | --- | --- | --- |
| `i_clk_apb` | input | 1 | wire | <fill> | 31 |
| `i_rst_n_apb` | input | 1 | wire | <fill> | 31 |
| `i_clk_reg` | input | 1 | wire | <fill> | 31 |
| `i_rst_n_reg` | input | 1 | wire | <fill> | 31 |
| `i_apb_psel` | input | 1 | wire | <fill> | 31 |
| `i_apb_penable` | input | 1 | wire | <fill> | 31 |
| `i_apb_pwrite` | input | 1 | wire | <fill> | 31 |
| `i_apb_paddr` | input | [LPARA_ADDR_W-1:0] | wire | <fill> | 31 |
| `i_apb_pwdata` | input | [LPARA_DATA_W-1:0] | wire | <fill> | 31 |
| `i_apb_pstrb` | input | [LPARA_STRB_W-1:0] | wire | <fill> | 31 |
| `i_apb_pprot` | input | [2:0] | wire | <fill> | 31 |
| `o_apb_pready` | output | 1 | logic | <fill> | 31 |
| `o_apb_pslverr` | output | 1 | logic | <fill> | 31 |
| `o_apb_prdata` | output | [LPARA_DATA_W-1:0] | logic | <fill> | 31 |
| `i_protect_en` | input | 1 | wire | <fill> | 31 |
| `i_slverr_en` | input | 1 | wire | <fill> | 31 |
| `i_dvp_version_major` | input | [15:0] | wire | <fill> | 31 |
| `i_dvp_version_minor` | input | [15:0] | wire | <fill> | 31 |
| `o_dvp_ctrl_pclk_mode` | output | 1 | logic | <fill> | 31 |
| `o_dvp_ctrl_fifo_flush` | output | 1 | logic | <fill> | 31 |
| `i_hw_wdata_dvp_ctrl_fifo_flush` | input | 1 | wire | <fill> | 31 |
| `i_hw_we_dvp_ctrl_fifo_flush` | input | 1 | wire | <fill> | 31 |
| `o_dvp_ctrl_capture_en` | output | 1 | logic | <fill> | 31 |
| `o_dvp_wmark_level` | output | [31:0] | logic | <fill> | 31 |
| `o_dvp_timeout_cycles` | output | [31:0] | logic | <fill> | 31 |
| `o_dvp_fifo_sts_ovf` | output | 1 | logic | <fill> | 31 |
| `i_hw_wdata_dvp_fifo_sts_ovf` | input | 1 | wire | <fill> | 31 |
| `i_hw_we_dvp_fifo_sts_ovf` | input | 1 | wire | <fill> | 31 |
| `i_dvp_fifo_sts_full` | input | 1 | wire | <fill> | 31 |
| `i_dvp_fifo_sts_empty` | input | 1 | wire | <fill> | 31 |
| `i_dvp_fifo_sts_active` | input | 1 | wire | <fill> | 31 |
| `i_dvp_fifo_level_count` | input | [31:0] | wire | <fill> | 31 |
| `i_dvp_frame_count_count` | input | [31:0] | wire | <fill> | 31 |

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

