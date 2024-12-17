module ImageRecog(

    //////////// CLOCK //////////
    input       ref_clk, // 50 MHz

    //////////// SDRAM //////////    
    output  [12:0]        DRAM_ADDR,
    output  [1:0]         DRAM_BA,
    output                DRAM_CAS_N,
    output                DRAM_CKE,
    output                DRAM_CLK,
    output                DRAM_CS_N,
    inout   [15:0]        DRAM_DQ,
    output                DRAM_LDQM,
    output                DRAM_RAS_N,
    output                DRAM_UDQM,
    output                DRAM_WE_N,

    //////////// RST_n ////////
    input                 RST_n,
    //////////// KEY //////////
    input   [2:1]         KEY,

    //////////// LED //////////
    output reg [9:0]      LEDR,
    // output reg            LEDG,

    //////////// SW //////////
    input   [9:0]         SW,

    //////////// VGA //////////
    output                VGA_BLANK_N,
    output  [7:0]         VGA_B,
    output                VGA_CLK,
    output  [7:0]         VGA_G,
    output                VGA_HS,
    output  [7:0]         VGA_R,
    output                VGA_SYNC_N,
    output                VGA_VS,

    //////////// GPIO_0, GPIO_0 connect to D5M - 5M Pixel Camera //////////
    // input   [11:0]        D5M_D,
    // input                 D5M_FVAL,
    // input                 D5M_LVAL,
    // input                 D5M_PIXCLK,
    // output                D5M_RESET_N,
    // output                D5M_SCLK,
    // inout                 D5M_SDATA,
    // input                 D5M_STROBE,
    // output                D5M_TRIGGER,
    // output                D5M_XCLKIN,

    //////////// OV7670 Camera ///////////////////
    input wire OV7670_PCLK,
    output wire OV7670_XCLK,
    input wire OV7670_VSYNC,
    input wire OV7670_HREF,
    input wire [7:0] OV7670_DATA,
    output wire OV7670_SIOC,
    inout wire OV7670_SIOD,
    output wire OV7670_PWDN,
    output wire OV7670_RESET,

    ////////////////////////// TX RX //////////////////////////////////////
    inout                 TX,
    inout                 RX
);

//=======================================================
//  REG/WIRE declarations
//=======================================================
    wire rst_n;                    // synchronized active low reset
    wire [31:0] addr;              // dst_EX_DM, result from ALU
    wire [31:0] rdata;             // exteral data input from the switches, 16'hDEAD if addr != 32'hC001
    wire [31:0] wdata;             // data from cpu that will reflect on LEDs if addr == 32'hC000 during write
    wire [31:0] r_weight;          // weight loaded from weight_rom
    wire [7:0] r_image;            // image pixel from image_mem
    wire update_LED;               // update LED status if addr == 32'hC000 and we is set
    wire [7:0] spart_databus;      // databus for communcation with spart
    wire re, we;                   // read enable and write enable from proc
    wire spart_cs_n;               // active low chip select signal for spart
    wire clk;
    wire compress_start;
    reg  compress_req;             // Turn this on to request compressing the image, it will pull down once the compression is finished. Access it at address C008
    wire [9:0] compress_addr;
    wire [7:0] pix_color_out;
    wire [9:0] echo_addr;
    wire [7:0] echo_pix_color_out;

    //////////////////////////// Camera Interfaces /////////////////////////////
    wire [15:0]  Read_DATA1;
    wire [15:0]  Read_DATA2;

    // wire [11:0]  mCCD_DATA;
    wire [7:0]  mCCD_DATA;
    wire mCCD_DVAL;
    wire mCCD_DVAL_d;
    wire [15:0]  X_Cont;
    wire [15:0]  Y_Cont;
    wire [9:0]   X_ADDR;
    wire [31:0]  Frame_Cont;
    wire DLY_RST_0;
    wire DLY_RST_1;
    wire DLY_RST_2;
    wire DLY_RST_3;
    wire DLY_RST_4;
    wire Read;
    // reg [11:0] rCCD_DATA;
    reg [7:0] rCCD_DATA;
    reg rCCD_LVAL;
    reg rCCD_FVAL;

    // wire [11:0] dCCD_R;
    // wire [11:0] dCCD_G;
    // wire [11:0] dCCD_B;
    wire [7:0] dCCD_R;
    wire [7:0] dCCD_G;
    wire [7:0] dCCD_B;
    wire dCCD_DVAL;

    // wire [11:0] sCCD_R;
    // wire [11:0] sCCD_G;
    // wire [11:0] sCCD_B;
    wire [7:0] sCCD_R;
    wire [7:0] sCCD_G;
    wire [7:0] sCCD_B;
    wire sCCD_DVAL;

    wire sdram_ctrl_clk;
    wire [9:0]  oVGA_R;//    VGA Red[9:0]
    wire [9:0]  oVGA_G;  //    VGA Green[9:0]
    wire [9:0]  oVGA_B;//    VGA Blue[9:0]

    wire [7:0] uncompress_addr_x;
    wire [7:0] uncompress_addr_y;

    //power on start
    wire auto_start;

    wire [16:0] rdaddress;
    wire [16:0] wraddress;
    wire [11:0] wrdata;
    wire wren;
    wire [11:0] rddata;

//=======================================================
//  Structural coding
//=======================================================
    // D5M
    // assign  D5M_TRIGGER  =    1'b1;  // tRIGGER
    // assign  D5M_RESET_N  =    DLY_RST_1;

    // OV7670
    // assign OV7670_XCLK = 1'b1;  // Trigger XCLK signal
    assign OV7670_RESET = DLY_RST_1;  // Reset signal

    assign  VGA_CTRL_CLK = VGA_CLK;

    //fetch the high 8 bits   //Temporary fix
    assign  VGA_R = oVGA_R[9:2];
    assign  VGA_G = oVGA_G[9:2];
    assign  VGA_B = oVGA_B[9:2];

    assign    sCCD_B = sCCD_G;  // Assign blue and red with same value as gray corlor
    assign    sCCD_R = sCCD_G;

    // If no external memory mapped device is used, put 32'hDEAD on rdata
    assign rdata = ((addr == 32'h0000C001) & re) ? {22'h000000, SW} :                   // 32'hC001 maps to switches, only lower 10 bits are used since only 10 SWs
                    (addr == 32'h0000C008 & re) ? {31'h00000000,compress_req} :         // 32'hC008 maps to compress control signal
                    (addr[31:2]==30'h00003001 & re) ? {24'h000000,spart_databus} :      // 16'hC004 - 16'hC007 maps to spart's bidirectional data bus
                    (addr[31:16]==16'h0001 & re) ? {24'h000000,r_image} :
                    (addr[31:17]==15'h0001 & re) ? r_weight :
                    32'h0000DEAD;        
 
    assign spart_databus = (addr[31:2]==32'h00003001 & we) ? wdata[7:0] : 8'hzz;        // spart databus traffic control

    assign spart_cs_n = ~(addr[31:2]==32'h3001 & (we | re));    // enable spart only when addr is correct and either read or write is enabled

    assign update_LED = (addr == 32'h0000C000) & we;            // make testbench more straight forward, LEDs map to 16'hC000

    // Considering LED as a "memory", so picked negedge trigged flops
    always @(negedge clk, negedge rst_n)
        if(!rst_n)
            LEDR <= 10'h000;     // LED output default to all OFF
        else if (update_LED)
            LEDR <= wdata[9:0];  // data is 32 bit, but only have 10 LEDs, use lower bits

    //D5M read 
    // always@(posedge D5M_PIXCLK)
    // begin
    //     rCCD_DATA   <=    D5M_D;
    //     rCCD_LVAL   <=    D5M_LVAL;
    //     rCCD_FVAL   <=    D5M_FVAL;
    // end

    // OV7670 read
    always @(posedge OV7670_PCLK)
    begin
        rCCD_DATA <= OV7670_DATA;   // Capture data from OV7670
        rCCD_LVAL <= OV7670_HREF;   // Horizontal reference signal
        rCCD_FVAL <= OV7670_VSYNC;  // Vertical sync signal
    end

    //auto start when power on,
    assign auto_start = ((rst_n)&&(DLY_RST_3)&&(!DLY_RST_4))? 1'b1:1'b0;

//=======================================================
//  Initialize modules
//=======================================================

    // Instantiation of Address Generator
    Address_Generator Address_Generator_inst (
        .CLK25(VGA_CLK),
        .enable(Read),
        .vsync(VGA_VS),
        .address(rdaddress)
    );

    // controls the timing for compressing image
    compress_request_system CMP_SYS(
        .clk(clk), 
        .rst_n(rst_n), 
        .uncompress_addr_x(uncompress_addr_x), 
        .uncompress_addr_y(uncompress_addr_y), 
        .we(addr == 32'h0000C008 & we), 
        .compress_wdata(wdata[0]), 
        .pause(KEY[2]), 
        .compress_req(compress_req), 
        .compress_start(compress_start));

    // Phase Locked Loop that controls all signals
    // PLL iPLL(
    //     .refclk(ref_clk),
    //     .rst(~RST_n),
    //     .outclk_0(clk),             // 50M
    //     .outclk_1(sdram_ctrl_clk),  // 100M
    //     .outclk_2(DRAM_CLK),        // 100M with phase 7500ps shift
    //     //.outclk_3(D5M_XCLKIN),      //25M
    //     .outclk_3(OV7670_XCLK),     // 25M clock for OV7670
    //     .outclk_4(VGA_CLK),         //25M
    //     .locked(pll_locked)
    // );

    // Instantiate the altera_pll1 module
    altera_pll1 u_altera_pll1 (
        .areset(~RST_n),  // Reset input
        .inclk0(ref_clk),  // Clock input
        .c0(clk),          // Clock output 0
        .c1(sdram_ctrl_clk),          // Clock output 1
        .c2(DRAM_CLK),          // Clock output 2
        .c3(OV7670_XCLK),          // Clock output 3
        .c4(VGA_CLK),          // Clock output 4
        .locked(pll_locked)   // PLL lock status
    );

    // push button input synchronization
    rst_synch irst_synch(
        .RST_n(RST_n),
        .clk(clk),
        .rst_n(rst_n),
        .pll_locked(pll_locked)
    );

    // iCPU
    cpu iCPU(
        .clk(clk),
        .rst_n(rst_n),
        .rdata(rdata),
        .addr(addr),
        .re(re),
        .we(we),
        .wdata(wdata)
    );

    // spart transmittion protocol
    spart iSPART(
        .clk(clk),
        .rst_n(rst_n),
        .iocs_n(spart_cs_n),
        .iorw_n(~we),                  // read on high, write on low
        .tx_q_full(),                  // not used because proc should read status register to "access" this value
        .rx_q_empty(),                 // not used because proc should read status register to "access" this value
        .ioaddr(addr[1:0]),
        .databus(spart_databus),
        .TX(TX),
        .RX(RX)
    );

    // external read only memory stores the weight used in CNN prediction
    weight_rom iWEIGHT_ROM(
        .clk(clk),
        .raddr(addr[15:0]),
        .rdata(r_weight)
    );

    // external 32x32 image ram. Read data from SDRAM (captured by camera in real-time), accessed by cpu for processing
    image_mem iIMAGE_MEM(
        .clk(clk),
        .we(sram_wr),
        .waddr(compress_addr),
        .wdata(pix_color_out),
        .raddr(addr[9:0]),
        .rdata(r_image)
    );

    // a duplicate of image to echo the image back to the screen. VGA_Control request image from here.
    image_mem iIMAGE_ECHO_MEM(
        .clk(clk),
        .we(sram_wr),
        .waddr(compress_addr),
        .wdata(pix_color_out),
        .raddr(echo_addr),
        .rdata(echo_pix_color_out)
    );

    // Compress An image to 28x28, and add 2 padding to all sides, making a 32x32 image.
    image_compressor_x(            // _x for CNN
        .clk(VGA_CLK),
        .rst_n(rst_n),
        .start(compress_start),
        .pix_color_in(oVGA_R[9:2]),
        .pix_haddr(uncompress_addr_x),
        .pix_vaddr(uncompress_addr_y),
        .pix_color_out(pix_color_out),
        .compress_addrx(compress_addr),
        .sram_wr(sram_wr)
    );

    //Reset each module with proper timing, allowing the SDRAM, camera, and the VGA to initialize.
    Reset_Delay iRESET_DELAY(    
        .iCLK(clk),
        .iRST(rst_n),
        .oRST_0(DLY_RST_0),
        .oRST_1(DLY_RST_1),
        .oRST_2(DLY_RST_2),
        .oRST_3(DLY_RST_3),
        .oRST_4(DLY_RST_4)
    );

    //D5M image capture
    // CCD_Capture iCAPTURE(    
    //     .oDATA(mCCD_DATA),
    //     .oDVAL(mCCD_DVAL),
    //     .oX_Cont(X_Cont),
    //     .oY_Cont(Y_Cont),
    //     .oFrame_Cont(Frame_Cont),
    //     .iDATA(rCCD_DATA),
    //     .iFVAL(rCCD_FVAL),
    //     .iLVAL(rCCD_LVAL),
    //     .iSTART(!KEY[3]|auto_start),
    //     .iEND(1'b0 | !KEY[2]), // never ends capturing the image.iEND(!KEY[2]),
    //     .iCLK(~D5M_PIXCLK),
    //     .iRST(DLY_RST_2)
    // );

    // Instantiation of OV7670 Capture Module
    ov7670_capture ov7670_capture_inst (
        .pclk(OV7670_PCLK),
        .vsync(OV7670_VSYNC),
        .href(OV7670_HREF),
        .d(OV7670_DATA),
        .addr(wraddress),
        .dout(wrdata),
        .we(wren)
    );

    // Instantiation of Frame Buffer
    frame_buffer frame_buffer_inst ( // OK
        .data(wrdata), // OK
        .rdaddress(rdaddress), // OK
        .rdclock(VGA_CLK), // OK
        .wraddress(wraddress), // OK
        .wrclock(OV7670_PCLK), // OK
        .wren(wren), // OK
        .q(rddata) // OK
    );

    //D5M raw date convert to RGB data
    // RAW2GRAY iRAW2GRAY(    
    //     .iCLK(D5M_PIXCLK),
    //     .iRST(DLY_RST_1),
    //     .iDATA(mCCD_DATA),
    //     .iDVAL(mCCD_DVAL),
    //     .oGrey(sCCD_G),
    //     .oDVAL(sCCD_DVAL),
    //     .iX_Cont(X_Cont),
    //     .iY_Cont(Y_Cont)
    // );

    // Instantiation of Black and White Filter
    // This module processes data from a frame buffer and outputs filtered data
    do_black_white do_black_white_inst (
        .rst_i(KEY[2]), // MAYBE OK I GUESS?
        .clk_i(VGA_CLK), // OK
        .enable_filter(1'b1), // OK
        .led_done(sCCD_DVAL), // OK
        // .rdaddr_buf2(rdaddr_buf2),
        .din_buf2(rddata), // OK
        // .wraddr_buf2(wraddr_buf2),
        .dout_buf2(sCCD_G), // OK
        // .we_buf2(we_buf2)
    );

    //SDRam Read and Write as Frame Buffer
    Sdram_Control iSDRAM_CTRL(      // HOST Side    
        .RESET_N(rst_n),
        .CLK(sdram_ctrl_clk),

        //    FIFO Write Side 1
        // .WR1_DATA({1'b0,sCCD_G[11:7],sCCD_B[11:2]}),
        .WR1_DATA({7'b000_0000,sCCD_G[7:5],sCCD_B[7:2]}),
        .WR1(sCCD_DVAL),
        .WR1_ADDR(0),
        .WR1_MAX_ADDR(640*480),
        .WR1_LENGTH(8'h50),
        .WR1_LOAD(!DLY_RST_0),
        // .WR1_CLK(~D5M_PIXCLK),
        .WR1_CLK(~OV7670_PCLK),

        //    FIFO Write Side 2 
        // .WR2_DATA({1'b0,sCCD_G[6:2],sCCD_R[11:2]}),
        .WR2_DATA({7'b000_0000,sCCD_G[4:2],sCCD_R[7:2]}),
        .WR2(sCCD_DVAL),
        .WR2_ADDR(23'h100000),
        .WR2_MAX_ADDR(23'h100000+640*480),
        .WR2_LENGTH(8'h50),
        .WR2_LOAD(!DLY_RST_0),    
        // .WR2_CLK(~D5M_PIXCLK),
        .WR2_CLK(~OV7670_PCLK),
        
        //    FIFO Read Side 1
        .RD1_DATA(Read_DATA1),
        .RD1(Read),
        .RD1_ADDR(0),
        .RD1_MAX_ADDR(640*480),
        .RD1_LENGTH(8'h50),
        .RD1_LOAD(!DLY_RST_0),
        .RD1_CLK(~VGA_CTRL_CLK),
        
        //    FIFO Read Side 2
        .RD2_DATA(Read_DATA2),
        .RD2(Read),
        .RD2_ADDR(23'h100000),
        .RD2_MAX_ADDR(23'h100000+640*480),
        .RD2_LENGTH(8'h50),
        .RD2_LOAD(!DLY_RST_0),
        .RD2_CLK(~VGA_CTRL_CLK),

        //    SDRAM Side
        .SA(DRAM_ADDR),
        .BA(DRAM_BA),
        .CS_N(DRAM_CS_N),
        .CKE(DRAM_CKE),
        .RAS_N(DRAM_RAS_N),
        .CAS_N(DRAM_CAS_N),
        .WE_N(DRAM_WE_N),
        .DQ(DRAM_DQ),
        .DQM({DRAM_UDQM,DRAM_LDQM})
    );

    //VGA DISPLAY
    VGA_Controller  iVGA_CONTROL(    //    Host Side
        .oRequest(Read),
        .echo_pix(echo_pix_color_out),
        .echo_addr(echo_addr),
        .iRed(Read_DATA2[9:0]),
        .iGreen({Read_DATA1[14:10],Read_DATA2[14:10]}),
        .iBlue(Read_DATA1[9:0]),
        //    VGA Side
        .oVGA_R(oVGA_R),
        .oVGA_G(oVGA_G),
        .oVGA_B(oVGA_B),
        .oVGA_H_SYNC(VGA_HS),
        .oVGA_V_SYNC(VGA_VS),
        .oVGA_SYNC(VGA_SYNC_N),
        .oVGA_BLANK(VGA_BLANK_N),
        //    Control Signal
        .iCLK(VGA_CTRL_CLK),
        .iRST_N(DLY_RST_2),
        .iZOOM_MODE_SW(SW[9]),
        .uncmpr_x(uncompress_addr_x),
        .uncmpr_y(uncompress_addr_y)
    );

    //D5M I2C control
    // I2C_CCD_Config iI2C_CONFIG(   //Host Side
    //     .iCLK(clk),
    //     .iRST_N(DLY_RST_2),
    //     .iEXPOSURE_ADJ(KEY[1]),
    //     .iEXPOSURE_DEC_p(SW[0]),
    //     .iZOOM_MODE_SW(SW[9]),
    //     //    I2C Side
    //     .I2C_SCLK(D5M_SCLK),
    //     .I2C_SDAT(D5M_SDATA)
    // );

    // Instantiate the VHDL entity `ov7670_controller`
    ov7670_controller inst_ov7670_controller (
        .clk(clk),                  // 50MHz Clock input
        .resend(KEY[1]),            // Resend signal
        .config_finished(LEDG), // Configuration finished signal
        .sioc(OV7670_SIOC),                // SIOC output
        .siod(OV7670_SIOD),                // SIOD bidirectional line
        // .reset(OV7670_RESET),              // Reset output
        .pwdn(OV7670_PWDN),                // Power down output
        // .xclk(OV7670_XCLK)                 // XCLK output
    );

endmodule