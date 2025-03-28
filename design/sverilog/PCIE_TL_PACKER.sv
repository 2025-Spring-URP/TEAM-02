// Trial
// Wongi Choi (cwg43352@g.skku.edu)

module PCIE_TL_Packer #(
    parameter AXI_ID_WIDTH     = 4,
    parameter AXI_ADDR_WIDTH   = 64,
    parameter MAX_READ_REQ_SIZE = 512,
    parameter MAX_PAYLOAD_SIZE = 128
)
(
    input   wire            clk,
    input   wire            rst_n,

    input   wire [15:0]     config_bdf_i,

    // AXI Write Address Channel
    ref  AXI4_A_IF #(AXI_ID_WIDTH, AXI_ADDR_WIDTH) aw_if,
    // AXI Read Address Channel
    ref  AXI4_A_IF #(AXI_ID_WIDTH, AXI_ADDR_WIDTH) ar_if,
    /*
    modport slave (
        input       avalid, aid, aaddr, alen, asize,
                    aburst, acache, aprot, aqos, aregion,
        output      aready
    );
    */

    input   wire            p_hdr_full_i,
    input   wire            np_hdr_full_i,
    output  PCIE_PKG::tlp_memory_req_hdr_t  p_hdr_o,
    output  PCIE_PKG::tlp_memory_req_hdr_t  np_hdr_o,
    output  logic           p_hdr_wren_o,
    output  logic           np_hdr_wren_o,

    input   wire            tag_valid_i,
    input   wire    [9:0]   tag_allocate_i, // 현재 할당해줄 수 있는 Tag를 지정
    output  logic           tag_wren_o, // 너가 할당한 Tag를 썼다고 알림
    output  logic   [9:0]   tag_length_o, // 현재 header가 얼마만큼의 데이터를 받아야 하는지 기록

    output  wire            writer_wren_o,
    input   wire            writer_full_i

);
    localparam MAX_PAYLOAD_DW = MAX_PAYLOAD_SIZE >> 2;
    localparam MAX_READ_REQ_DW = MAX_READ_REQ_SIZE >> 2;

    typedef enum logic [2:0] {
        IDLE,
        READ,
        WRITE
    } state_t;

    PCIE_PKG::tlp_memory_req_hdr_t aw_gen_tlp_hdr;
    always_comb begin
        aw_gen_tlp_hdr = PCIE_PKG::gen_tlp_memwr_hdr(
            aw_if.aaddr,
            4'hF,       // first_dbe
            4'hF,       // last_dbe
            length,
            10'd0,      // Tag: No Tag
            config_bdf_i
        );
    end

    PCIE_PKG::tlp_memory_req_hdr_t ar_gen_tlp_hdr;
    always_comb begin
        ar_gen_tlp_hdr = PCIE_PKG::gen_tlp_memrd_hdr(
            aaddr,
            4'hF,
            4'hF,
            length,
            tag_allocate_i,
            config_bdf_i
        );
    end

    state_t state, state_n;

    // read: 0, write: 1
    logic [7:0] alen, alen_n; // AXI Burst Transfer Length (2^ASIZE, 8B)
    logic [63:0] aaddr, aaddr_n; // AXI Read/Write Address
    logic [9:0] length; // Wire, PCIe TLP Header Length (DW, 4B)
    logic aready; // AR/AW Ready
    logic p_hdr_wren, np_hdr_wren; // Header FIFO Write Enable
    logic tag_wren; // Read Header ON
    logic writer_wren; // Writer Header ON

    always_ff @(posedge clk)
        if (!rst) begin
            state <= IDLE;
            alen <= 8'd0;
            aaddr <= 64'd0;
        end
        else begin
            state <= state_n;
            alen <= alen_n;
            aaddr <= aaddr_n;
        end
    
    always_comb begin
        state_n = state;
        alen_n = alen;
        aaddr_n = aaddr;

        aready = 1'b0;
        np_hdr_wren = 1'b0;
        p_hdr_wren = 1'b0;
        tag_wren = 1'b0;


        case (state)
        IDLE: begin
            aready = 1'b1;

            if (aw_if.avalid) begin // priority for write
                state_n = WRITE;

                aaddr_n = aw_if.aaddr;
                alen_n = aw_if.alen;
            end
            else if (ar_if.avalid) begin
                state_n = READ;

                aaddr_n = ar_if.aaddr;
                alen_n = aw_if.alen;
            end
        end
        READ: begin
            if ((!np_hdr_full_i) && tag_valid_i) begin
                np_hdr_wren = 1'b1; // Insert hdr on FIFO
                tag_wren = 1'b1; // Use current Tag

                // ((alen + 1) << 1) > ... 방식은 추후 timing reorder가 필요할 수도 있음
                if (((alen + 1) << 1) > MAX_READ_REQ_DW) begin
                    // Exceed Read Req DW
                    length = MAX_READ_REQ_DW;
                    alen_n = alen - (MAX_READ_REQ_DW >> 1);
                end
                else begin
                    length = (alen + 1) << 1;
                    alen_n = 8'd0;

                    // State change
                    aready = 1'b1;
                    if (aw_if.avalid) begin // priority for write
                        state_n = WRITE;

                        aaddr_n = aw_if.aaddr;
                        alen_n = aw_if.alen;
                    end
                    else if (ar_if.avalid) begin
                        state_n = READ;

                        aaddr_n = ar_if.aaddr;
                        alen_n = aw_if.alen;
                    end
                    else begin
                        state_n = IDLE;
                    end
                end
            end
        end
        WRITE: begin
            // writer, p_hdr의 크기를 같게 할 것이기 때문에 모두 비교가 필요할지는 의문
            if (!(p_hdr_full_i || writer_full_i)) begin
                p_hdr_wren = 1'b1; // Insert hdr on FIFO
                writer_wren = 1'b1; // Write current length on writer

                // ((alen + 1) << 1) > ... 방식은 추후 timing reorder가 필요할 수도 있음
                if (((alen + 1) << 1) > MAX_PAYLOAD_DW) begin
                    // Exceed Payload DW
                    length = MAX_PAYLOAD_DW;
                    alen_n = alen - (MAX_PAYLOAD_DW >> 1);
                end
                else begin
                    length = (alen + 1) << 1;
                    alen_n = 8'd0;

                    // State change
                    aready = 1'b1;
                    if (aw_if.avalid) begin // priority for write
                        state_n = WRITE;

                        aaddr_n = aw_if.aaddr;
                        alen_n = aw_if.alen;
                    end
                    else if (ar_if.avalid) begin
                        state_n = READ;

                        aaddr_n = ar_if.aaddr;
                        alen_n = aw_if.alen;
                    end
                    else begin
                        state_n = IDLE;
                    end
                end
            end
        end
        endcase
    end

    assign p_hdr_o = aw_gen_tlp_hdr;
    assign np_hdr_o = ar_gen_tlp_hdr;
    assign p_hdr_wren_o = p_hdr_wren;
    assign np_hdr_wren_o = np_hdr_wren;
    assign tag_wren_o = tag_wren;
    assign writer_wren_o = writer_wren;

endmodule
