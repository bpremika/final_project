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

module pong_graph(
    input clk,    
    input reset,    
    input [3:0] btn,        // btn[0] = up player 1, btn[1] = down player 1, btn[2] = up player 2, btn[3] = down player 2
    input gra_still,        // still graphics - new game, game over states
    input video_on,
    input [9:0] x,
    input [9:0] y,
    output graph_on,
    output reg hit_player1, miss_player1, hit_player2, miss_player2,   // ball hit or miss
    output reg [11:0] graph_rgb
    );
    
    // maximum x, y values in display area
    parameter X_MAX = 639;
    parameter Y_MAX = 479;
    
    // create 60Hz refresh tick
    wire refresh_tick;
    assign refresh_tick = ((y == 481) && (x == 0)) ? 1 : 0; // start of vsync (vertical retrace)
    
    // PADDLES
    // player 1 paddle horizontal boundaries
    parameter X_PAD1_L = 20;
    parameter X_PAD1_R = 23;    // 4 pixels wide
    // player 2 paddle horizontal boundaries
    parameter X_PAD2_L = 616;
    parameter X_PAD2_R = 619;   // 4 pixels wide
    // paddle vertical boundary signals
    wire [9:0] y_pad1_t, y_pad1_b, y_pad2_t, y_pad2_b;
    parameter PAD_HEIGHT = 72;  // 72 pixels high
    // registers to track top boundary and buffer for both paddles
    reg [9:0] y_pad1_reg = 204;  // Paddle 1 starting position
    reg [9:0] y_pad2_reg = 204;  // Paddle 2 starting position
    reg [9:0] y_pad1_next, y_pad2_next;
    // paddle moving velocity when a button is pressed
    parameter PAD_VELOCITY = 3; // change to speed up or slow down paddle movement
    
    // BALL
    // square rom boundaries
    parameter BALL_SIZE = 8;
    // ball horizontal boundary signals
    wire [9:0] x_ball_l, x_ball_r;
    // ball vertical boundary signals
    wire [9:0] y_ball_t, y_ball_b;
    // registers to track top left position
    reg [9:0] y_ball_reg, x_ball_reg;
    // signals for register buffer
    wire [9:0] y_ball_next, x_ball_next;
    // registers to track ball speed and buffers
    reg [9:0] x_delta_reg, x_delta_next;
    reg [9:0] y_delta_reg, y_delta_next;
    // positive or negative ball velocity
    parameter BALL_VELOCITY_POS = 2;  // ball speed positive pixel direction (down, right)
    parameter BALL_VELOCITY_NEG = -2; // ball speed negative pixel direction (up, left)
    // round ball from square image
    wire [2:0] rom_addr, rom_col;     // 3-bit rom address and rom column
    reg [7:0] rom_data;               // data at current rom address
    wire rom_bit;                     // signify when rom data is 1 or 0 for ball rgb control
    
    // Register Control
    always @(posedge clk or posedge reset)
        if(reset) begin
            y_pad1_reg <= 204;
            y_pad2_reg <= 204;
            x_ball_reg <= 0;
            y_ball_reg <= 0;
            x_delta_reg <= 10'h002;
            y_delta_reg <= 10'h002;
        end
        else begin
            y_pad1_reg <= y_pad1_next;
            y_pad2_reg <= y_pad2_next;
            x_ball_reg <= x_ball_next;
            y_ball_reg <= y_ball_next;
            x_delta_reg <= x_delta_next;
            y_delta_reg <= y_delta_next;
        end
    
    // ball rom
    always @*
        case(rom_addr)
            3'b000 : rom_data = 8'b00111100; //   ****  
            3'b001 : rom_data = 8'b01111110; //  ******
            3'b010 : rom_data = 8'b11111111; // ********
            3'b011 : rom_data = 8'b11111111; // ********
            3'b100 : rom_data = 8'b11111111; // ********
            3'b101 : rom_data = 8'b11111111; // ********
            3'b110 : rom_data = 8'b01111110; //  ******
            3'b111 : rom_data = 8'b00111100; //   ****
        endcase
    
    // OBJECT STATUS SIGNALS
    wire pad1_on, pad2_on, sq_ball_on, ball_on;
    wire [11:0] pad1_rgb, pad2_rgb, ball_rgb, bg_rgb;
    
    // paddle 1
    assign y_pad1_t = y_pad1_reg;                                   // paddle 1 top position
    assign y_pad1_b = y_pad1_t + PAD_HEIGHT - 1;                   // paddle 1 bottom position
    assign pad1_on = (X_PAD1_L <= x) && (x <= X_PAD1_R) &&         // pixel within paddle 1 boundaries
                     (y_pad1_t <= y) && (y <= y_pad1_b);
    
    // paddle 2
    assign y_pad2_t = y_pad2_reg;                                   // paddle 2 top position
    assign y_pad2_b = y_pad2_t + PAD_HEIGHT - 1;                   // paddle 2 bottom position
    assign pad2_on = (X_PAD2_L <= x) && (x <= X_PAD2_R) &&         // pixel within paddle 2 boundaries
                     (y_pad2_t <= y) && (y <= y_pad2_b);
    
    // assign object colors
    assign pad1_rgb  = 12'h00F;    // blue paddle 1
    assign pad2_rgb  = 12'h0F0;    // green paddle 2
    assign ball_rgb  = 12'hF00;    // red ball
    assign bg_rgb    = 12'h0FF;    // aqua background
    
    // Paddle Control
    always @* begin
        y_pad1_next = y_pad1_reg;     // no move for paddle 1
        y_pad2_next = y_pad2_reg;     // no move for paddle 2
        
        if(refresh_tick) begin
            if(btn[1] & (y_pad1_b < (Y_MAX - 1 - PAD_VELOCITY)))
                y_pad1_next = y_pad1_reg + PAD_VELOCITY;  // move paddle 1 down
            else if(btn[0] & (y_pad1_t > 0))
                y_pad1_next = y_pad1_reg - PAD_VELOCITY;  // move paddle 1 up
            
            if(btn[3] & (y_pad2_b < (Y_MAX - 1 - PAD_VELOCITY)))
                y_pad2_next = y_pad2_reg + PAD_VELOCITY;  // move paddle 2 down
            else if(btn[2] & (y_pad2_t > 0))
                y_pad2_next = y_pad2_reg - PAD_VELOCITY;  // move paddle 2 up
        end
    end
    
    // rom data square boundaries
    assign x_ball_l = x_ball_reg;
    assign y_ball_t = y_ball_reg;
    assign x_ball_r = x_ball_l + BALL_SIZE - 1;
    assign y_ball_b = y_ball_t + BALL_SIZE - 1;
    
    // pixel within rom square boundaries
    assign sq_ball_on = (x_ball_l <= x) && (x <= x_ball_r) &&
                        (y_ball_t <= y) && (y <= y_ball_b);
    
    // map current pixel location to rom addr/col
    assign rom_addr = y[2:0] - y_ball_t[2:0];   // 3-bit address
    assign rom_col = x[2:0] - x_ball_l[2:0];    // 3-bit column index
    assign rom_bit = rom_data[rom_col];         // 1-bit signal rom data by column
    
    // pixel within round ball
    assign ball_on = sq_ball_on & rom_bit;      // within square boundaries AND rom data bit == 1
    
    // new ball position
    assign x_ball_next = (gra_still) ? X_MAX / 2 :
                         (refresh_tick) ? x_ball_reg + x_delta_reg : x_ball_reg;
    assign y_ball_next = (gra_still) ? Y_MAX / 2 :
                         (refresh_tick) ? y_ball_reg + y_delta_reg : y_ball_reg;
    
    // change ball direction after collision
    always @* begin
        hit_player1 = 1'b0;
        miss_player1 = 1'b0;
        hit_player2 = 1'b0;
        miss_player2 = 1'b0;
        x_delta_next = x_delta_reg;
        y_delta_next = y_delta_reg;
        
        if(gra_still) begin
            x_delta_next = BALL_VELOCITY_NEG;
            y_delta_next = BALL_VELOCITY_POS;
        end
        
        else if(y_ball_t < 0)                      // reach top
            y_delta_next = BALL_VELOCITY_POS;     // move down
        
        else if(y_ball_b > (Y_MAX - 1))            // reach bottom
            y_delta_next = BALL_VELOCITY_NEG;     // move up
        
        else if(x_ball_l <= X_PAD1_R &&            // collide with paddle 1
                (y_pad1_t <= y_ball_b) && (y_ball_t <= y_pad1_b)) begin
            x_delta_next = BALL_VELOCITY_POS;
            hit_player1 = 1'b1;
        end
        
        else if(x_ball_r >= X_PAD2_L &&            // collide with paddle 2
                (y_pad2_t <= y_ball_b) && (y_ball_t <= y_pad2_b)) begin
            x_delta_next = BALL_VELOCITY_NEG;
            hit_player2 = 1'b1;
        end
        
        else if(x_ball_r > X_MAX)
            miss_player1 = 1'b1;
        
        else if(x_ball_l < 0)
            miss_player2 = 1'b1;
    end
    
    // output status signal for graphics 
    assign graph_on = pad1_on | pad2_on | ball_on;
    
    // rgb multiplexing circuit
    always @*
        if(~video_on)
            graph_rgb = 12'h000;      // no value, blank
        else if(pad1_on)
            graph_rgb = pad1_rgb;     // paddle 1 color
        else if(pad2_on)
            graph_rgb = pad2_rgb;     // paddle 2 color
        else if(ball_on)
            graph_rgb = ball_rgb;     // ball color
        else
            graph_rgb = bg_rgb;       // background
       
endmodule
