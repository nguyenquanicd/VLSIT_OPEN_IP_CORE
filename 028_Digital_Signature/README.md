# 028 Digital Signature

## English

Feature research for hardware digital-signature IP: the Ed* family (Ed25519, Ed25519ctx, Ed25519ph, Ed448), ECDSA/RSA, and post-quantum signatures (ML-DSA, SLH-DSA, LMS/XMSS), with attention to side-channel and fault-attack protection.

Status: research, draft specification, and RTL of all blocks of the hierarchy. The research report and source manifest are under `research/`; the draft hardware design specification, CSR workbook and figures are under `spec/`. `rtl/` holds the generated CSR, the control block, the buffer, the AXI4 block, the key and random blocks, the hash stack, the three engines (elliptic curve: Ed25519, Ed25519ctx/ph, Ed448, Ed448ph, ECDSA P-256/P-384/P-521/secp256k1; lattice: ML-DSA-44/65/87; hash-based: SLH-DSA, LMS/HSS, XMSS/XMSS^MT) and the structural top `m_vlsit_dsig_top`; rule check and Verilator lint are clean. Simulation against independent references (RFC vectors, OpenSSL, hashlib) is described in `verification/docs/ENGINES.md`; the LMS and XMSS paths are checked only against signers written for the test. Ed25519ph and Ed448ph take the digest from software; ECDSA has the deterministic nonce of RFC 6979 (SHA-2); ML-DSA and SLH-DSA have their pre-hash forms. Not built: DPA masking, the internal random generator (section 14.2.2 of the specification). No coverage, formal, CDC/RDC, SDC or synthesis run yet.

Layout follows the repository rules in `../README.md`: `spec/` (with `spec/figures/`), `rtl/` (sole `filelist.f`), `lint/`, `cdc/`, `rdc/`, `sdc/`, `syn/`, `research/`, `verification/{docs,tests,models,env,sim}`, `review/reference/`, `archive/`. Third-party documents under `research/vlsit_sources/` are kept locally for research and are not redistributed.

## Tiếng Việt

Nghiên cứu tính năng cho IP chữ ký số phần cứng: họ Ed* (Ed25519, Ed25519ctx, Ed25519ph, Ed448), ECDSA/RSA và chữ ký hậu lượng tử (ML-DSA, SLH-DSA, LMS/XMSS), chú trọng chống side-channel và fault attack.

Trạng thái: nghiên cứu, bản nháp đặc tả và RTL của mọi khối trong phân cấp. `rtl/` có CSR sinh tự động, khối điều khiển, bộ đệm, khối AXI4, khối key và random, chồng hash, ba engine (đường cong elliptic: Ed25519, Ed25519ctx/ph, Ed448, Ed448ph, ECDSA P-256/P-384/P-521/secp256k1; lưới: ML-DSA-44/65/87; dựa trên hash: SLH-DSA, LMS/HSS, XMSS/XMSS^MT) và top cấu trúc `m_vlsit_dsig_top`; qua kiểm tra rule và lint Verilator. Mô phỏng so với tham chiếu độc lập (vector RFC, OpenSSL, hashlib) mô tả trong `verification/docs/ENGINES.md`; đường LMS và XMSS chỉ so với bộ ký tự viết cho bài test. Ed25519ph và Ed448ph nhận digest từ phần mềm; ECDSA có nonce tất định RFC 6979 (SHA-2); ML-DSA và SLH-DSA có dạng prehash. Chưa xây: che DPA, bộ sinh ngẫu nhiên nội bộ (mục 14.2.2 của đặc tả). Chưa đo coverage, chưa chạy formal, CDC/RDC, SDC, tổng hợp.

Cấu trúc theo quy tắc ở `../README.md`. Tài liệu bên thứ ba trong `research/vlsit_sources/` chỉ lưu cục bộ để nghiên cứu, không phân phối lại.
