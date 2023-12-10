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


module pong_text(
    input clk,
    input [3:0] dig10, dig11,
    input [3:0] dig20, dig21,
    input [9:0] x, y,
    output [3:0] text_on,
    output reg [11:0] text_rgb
    );
    
    // signal declaration
    wire [10:0] rom_addr;
    reg [6:0] char_addr, char_addr_s, char_addr_l, char_addr_r, char_addr_o;
    reg [3:0] row_addr;
    wire [3:0] row_addr_s, row_addr_l, row_addr_r, row_addr_o;
    reg [2:0] bit_addr;
    wire [2:0] bit_addr_s, bit_addr_l, bit_addr_r, bit_addr_o;
    wire [7:0] ascii_word;
    wire ascii_bit, score_on, logo_on, rule_on, over_on;
    wire [7:0] rule_rom_addr;
    
   // instantiate ascii rom
   ascii_rom ascii_unit(.clk(clk), .addr(rom_addr), .data(ascii_word));
   
   // ---------------------------------------------------------------------------
   // score region
   // - display two-digit score and ball # on top left
   // - scale to 16 by 32 text size
   // - line 1, 16 chars: "Score: dd Ball: d"
   // ---------------------------------------------------------------------------
   assign score_on = (y >= 32) && (y < 64) && (x[9:4] < 32);
   assign row_addr_s = y[4:1];
   assign bit_addr_s = x[3:1];
   always @*
    case(x[8:4])
        5'h0 : char_addr_s = 7'h00; 
        5'h1 : char_addr_s = 7'h50;     // P
        5'h2 : char_addr_s = 7'h4C;     // L
        5'h3 : char_addr_s = 7'h41;     // A
        5'h4 : char_addr_s = 7'h59;     // Y
        5'h5 : char_addr_s = 7'h45;     // E
        5'h6 : char_addr_s = 7'h52;     // R
        5'h7 : char_addr_s = 7'h20;     // Space
        5'h8 : char_addr_s = 7'h31;     // 1
        5'h9 : char_addr_s = 7'h3A;     // :
        5'hA : char_addr_s = {3'b011, dig11};    // tens digit
        5'hB : char_addr_s = {3'b011, dig10};    // ones digit
        5'hC : char_addr_s = 7'h00;     //
        5'hD : char_addr_s = 7'h00;     //
        5'hE : char_addr_s = 7'h50;     // P
        5'hF : char_addr_s = 7'h4C;     // L
        5'h10 : char_addr_s = 7'h41;     // A
        5'h11 : char_addr_s = 7'h59;     // Y
        5'h12 : char_addr_s = 7'h45;     // E
        5'h13 : char_addr_s = 7'h52;     // R
        5'h14 : char_addr_s = 7'h20;     // Space
        5'h15 : char_addr_s = 7'h32;     // 2
        5'h16 : char_addr_s = 7'h3A;     // :
        5'h17 : char_addr_s = {3'b011, dig21};    // tens digit
        5'h18 : char_addr_s = {3'b011, dig20};    // ones digit
        5'h19 : char_addr_s = 7'h00;     //
        5'h1A : char_addr_s = 7'h00;     // 
        5'h1B : char_addr_s = 7'h00;     // 
        5'h1C : char_addr_s = 7'h00;     // 
        5'h1D : char_addr_s = 7'h00;     // 
        5'h1E : char_addr_s = 7'h00;     // 
        5'h1F : char_addr_s = 7'h00;
    endcase

   
    // --------------------------------------------------------------------------
    // game over region
    // - display "GAME OVER" at center
    // - scale to 32 by 64 text size
    // --------------------------------------------------------------------------
    assign over_on = (y[9:6] == 3) && (5 <= x[9:5]) && (x[9:5] <= 13);
    assign row_addr_o = y[5:2];
    assign bit_addr_o = x[4:2];
    always @*
        case(x[8:5])
            4'h5 : char_addr_o = 7'h47;     // G
            4'h6 : char_addr_o = 7'h41;     // A
            4'h7 : char_addr_o = 7'h4D;     // M
            4'h8 : char_addr_o = 7'h45;     // E
            4'h9 : char_addr_o = 7'h00;     //
            4'hA : char_addr_o = 7'h4F;     // O
            4'hB : char_addr_o = 7'h56;     // V
            4'hC : char_addr_o = 7'h45;     // E
            default : char_addr_o = 7'h52;  // R
        endcase
    
    // mux for ascii ROM addresses and rgb
    always @* begin
        text_rgb = 12'h0FF;     // aqua background
        
        if(score_on) begin
            char_addr = char_addr_s;
            row_addr = row_addr_s;
            bit_addr = bit_addr_s;
            if(ascii_bit)
                text_rgb = 12'hF00; // red
        end
        
        else begin // game over
            char_addr = char_addr_o;
            row_addr = row_addr_o;
            bit_addr = bit_addr_o;
            if(ascii_bit)
                text_rgb = 12'hF00; // red
        end        
    end
    
    assign text_on = {score_on, logo_on, rule_on, over_on};
    
    // ascii ROM interface
    assign rom_addr = {char_addr, row_addr};
    assign ascii_bit = ascii_word[~bit_addr];
      
endmodule