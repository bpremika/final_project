`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Reference book: "FPGA Prototyping by Verilog Examples"
//                      "Xilinx Spartan-3 Version"
// Written by: Dr. Pong P. Chu
// Published by: Wiley, 2008
//
// Adapted for Basys 3 by David J. Marion aka FPGA Dude
//
//////////////////////////////////////////////////////////////////////////////////

module pong_top(
    input clk,              // 100MHz
    input reset,            // btnR
    input [3:0] btn,        // btnD, btnU
//    input PS2Data,          // USB HID (PS/2) Keyboard Data
//    input PS2Clk,           // USB HID (PS/2) Keyboard Clock
    input wire RsRx, //uart
//    output wire RsTx, //uart
    output hsync,           // to VGA Connector
    output vsync,           // to VGA Connector
    output [11:0] rgb,       // to DAC, to VGA Connector
    output [15:0] led
    );
    
    // state declarations for 4 states
    parameter newgame = 2'b00;
    parameter play    = 2'b01;
    parameter newball = 2'b10;
    parameter over    = 2'b11;
           
        
    // signal declaration
    reg [1:0] state_reg, state_next;
    wire [9:0] w_x, w_y;
    wire [2:0] graph_on;
    wire w_vid_on, w_p_tick, hit1, hit2, miss1, miss2;
    wire [3:0] text_on;
    wire [11:0] graph_rgb, text_rgb;
    reg [11:0] rgb_reg, rgb_next;
    wire [3:0] dig0, dig1, dig2, dig3;
    
    reg gra_still, d1_inc, d2_inc, d_clr, timer_start;
    wire timer_tick, timer_up;
//    reg [1:0] ball_reg, ball_next;

//    wire [15:0] keycode;
//    wire oflag;
//    reg  [ 2:0] bcount=0;
//    reg         cn=0;
//    reg  [15:0] keycodev=0;
//    reg         start=0;

    reg [3: 0] keyboardInput;
    
    reg en, last_rec;
    reg [7:0] data_in;
    wire [7:0] data_out;
    wire sent, received, baud;
    
    baudrate_gen baudrate_gen(clk, baud);
    uart_rx receiver(baud, RsRx, received, data_out);
    
    always @(posedge baud) begin
        if (en) en = 0;
        if (~last_rec & received) begin
            data_in = data_out + 8'h01;
            if (data_in <= 8'h7A && data_in >= 8'h41) en = 1;
            
            // Map UART input to button inputs
            case (data_in)
                8'h72: keyboardInput = 4'b0001; // 'q'
                8'h62: keyboardInput = 4'b0010; // 'a'
                8'h70: keyboardInput = 4'b0100; // 'o'
                8'h6C: keyboardInput = 4'b1000; // 'k'
                default: keyboardInput = 4'b0000;
            endcase
        end
        last_rec = received;
    end
//    // Instantiate the PS/2 receiver
//    PS2Receiver receiver (
//        .clk(clk),
//        .kclk(PS2Clk),
//        .kdata(PS2Data),
//        .keycode(keycode),
//        .oflag(oflag)
//    );
    
//    always@(keycode)
//        if (keycode[7:0] == 8'hf0) begin
//            cn <= 1'b0;
//            bcount <= 3'd0;
//        end else if (keycode[15:8] == 8'hf0) begin
//            cn <= keycode != keycodev;
//            bcount <= 3'd5;
//        end else begin
//            cn <= keycode[7:0] != keycodev[7:0] || keycodev[15:8] == 8'hf0;
//            bcount <= 3'd2;
//        end
    
//    always@(posedge clk)
//        if (oflag == 1'b1 && cn == 1'b1) begin
//            start <= 1'b1;
//            keycodev <= keycode;
//        end else
//            start <= 1'b0;

//    // Replace keyboardInput with keyboard inputs
//    assign keyboardInput[0] = (oflag && keycodev[3:0] == 4'b0101) ? 1'b1 : 1'b0; // 'q' for btn U
//    assign keyboardInput[1] = (oflag && keycodev[3:0] == 4'b1100) ? 1'b1 : 1'b0; // 'a' for btnL
//    assign keyboardInput[2] = (oflag && keycodev[3:0] == 4'b1101) ? 1'b1 : 1'b0; // 'p' for btnC
//    assign keyboardInput[3] = (oflag && keycodev[3:0] == 4'b1011) ? 1'b1 : 1'b0; // 'l' for btnD
////    assign led = btn;
//    assign led = keycodev;
//    assign led[15] = oflag;

    // Module Instantiations
    vga_controller vga_unit(
        .clk_100MHz(clk),
        .reset(reset),
        .video_on(w_vid_on),
        .hsync(hsync),
        .vsync(vsync),
        .p_tick(w_p_tick),
        .x(w_x),
        .y(w_y));
    
    pong_text text_unit(
        .clk(clk),
        .x(w_x),
        .y(w_y),
        .dig10(dig0),
        .dig11(dig1),
        .dig20(dig2),
        .dig21(dig3),
        .text_on(text_on),
        .text_rgb(text_rgb));
    
//     pong_graphic m2 //control logic for any graphs on the game
//	(
//		.clk(clk),
//		.rst_n(reset),
//		.video_on(w_vid_on),
//		.gra_still(gra_still), //return to default screen with no motion
//		.btn(btn), //key[1:0] for player 1 and key[3:2] for player 2
//		.pixel_x(w_x),
//		.pixel_y(w_y),
//		.rgb(graph_rgb),
//		.graph_on(graph_on),
//		.miss1(miss1),
//		.miss2(miss2), //miss1=player 1 misses  , miss2=player2 misses
//	    .led(led)
//    );
    pong_graph graph_unit(
        .clk(clk),
        .reset(reset),
        .btn(keyboardInput),
        .gra_still(gra_still),
        .video_on(w_vid_on),
        .x(w_x),
        .y(w_y),
        .hit_player1(hit1),
        .miss_player1(miss1),
        .hit_player2(hit2),
        .miss_player2(miss2),
        .graph_on(graph_on),
        .graph_rgb(graph_rgb),
        .led(led));
        
    
    // 60 Hz tick when screen is refreshed
    assign timer_tick = (w_x == 0) && (w_y == 0);
    timer timer_unit(
        .clk(clk),
        .reset(reset),
        .timer_tick(timer_tick),
        .timer_start(timer_start),
        .timer_up(timer_up));
    
    m100_counter counter_unit(
        .clk(clk),
        .reset(reset),
        .d_inc(d1_inc),
        .d_clr(d_clr),
        .dig0(dig0),
        .dig1(dig1));
    
    m100_counter counter_unit2(
        .clk(clk),
        .reset(reset),
        .d_inc(d2_inc),
        .d_clr(d_clr),
        .dig0(dig2),
        .dig1(dig3));
    
    // FSMD state and registers
    always @(posedge clk or posedge reset)
        if(reset) begin
            state_reg <= newgame;
//            ball_reg <= 0;
            rgb_reg <= 0;
        end
    
        else begin
            state_reg <= state_next;
//            ball_reg <= ball_next;
          
            if(w_p_tick)
                rgb_reg <= rgb_next;
        end
    
    // FSMD next state logic
    always @* begin
        gra_still = 1'b1;
        timer_start = 1'b0;
        d1_inc = 1'b0;
        d2_inc = 1'b0;
        d_clr = 1'b0;
        state_next = state_reg;
//        ball_next = ball_reg;
        
        case(state_reg)
            newgame: begin
//                ball_next = 2'b11;          // three balls
                d_clr = 1'b1;               // clear score
          
                if(keyboardInput != 2'b00) begin      // button pressed
                    state_next = play;
//                    ball_next = ball_reg - 1;    
                end
            end
            
            play: begin
                gra_still = 1'b0;   // animated screen
                //if(hit1) d1_inc = 1'b1;
                //else if(hit2) d2_inc = 1'b1;
                
                if(miss1 ||miss2) begin
                    if (miss1)
                        d2_inc = 1'b1;
                    else 
                        d1_inc = 1'b1; 
                    
                    if((dig1 == 9 && dig0 == 9) ||(dig3 == 9 && dig2 == 9))
                        state_next = over;
                        
//                    if(ball_reg == 0)
//                        state_next = over;
                    
                    else
                        state_next = newball;
                    
                    timer_start = 1'b1;     // 2 sec timer
//                    ball_next = ball_reg - 1;
                end
            end
            
            newball: // wait for 2 sec and until button pressed
            if(timer_up && (keyboardInput != 2'b00))
                state_next = play;
                
            over:   // wait 2 sec to display game over
                if(timer_up)
                    state_next = newgame;
        endcase           
    end
    
    // rgb multiplexing
    always @*
        if(~w_vid_on)
            rgb_next = 12'h000; // blank
        
        else
            if(text_on[3] || ((state_reg == newgame) && text_on[1]) || ((state_reg == over) && text_on[0]))
                rgb_next = text_rgb;    // colors in pong_text
            
            else if(graph_on)
                rgb_next = graph_rgb;   // colors in graph_text
                
            else if(text_on[2])
                rgb_next = text_rgb;    // colors in pong_text
                
            else
                rgb_next = graph_rgb;     //  background
    
    // output
    assign rgb = rgb_reg;
endmodule