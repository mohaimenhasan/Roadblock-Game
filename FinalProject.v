module FinalProject	(
		CLOCK_50,						//	On Board 50 MHz
		// Your inputs and outputs here
		// The ports below are for the VGA output.  Do not change.
		KEY,
		SW,
		LEDR,
		VGA_CLK,   						//	VGA Clock
		VGA_HS,							//	VGA H_SYNC
		VGA_VS,							//	VGA V_SYNC
		VGA_BLANK_N,						//	VGA BLANK
		VGA_SYNC_N,						//	VGA SYNC
		VGA_R,   						//	VGA Red[9:0]
		VGA_G,	 						//	VGA Green[9:0]
		VGA_B,   						//	VGA Blue[9:0]

	);

	input			CLOCK_50;				//	50 MHz
	// Declare your inputs and outputs here
	// Do not change the following outputs
	input [3:0] KEY; 
	input [9:0] SW;
	input [9:0] LEDR;
	output			VGA_CLK;   				//	VGA Clock
	output			VGA_HS;					//	VGA H_SYNC
	output			VGA_VS;					//	VGA V_SYNC
	output		VGA_BLANK_N;				// VGA BLANK
	output			VGA_SYNC_N;				//	VGA SYNC
	output	[9:0]	VGA_R;   				//	VGA Red[9:0]
	output	[9:0]	VGA_G;	 				//	VGA Green[9:0]
	output	[9:0]	VGA_B;   				//	VGA Blue[9:0]
	
	wire resetn;
	assign resetn = KEY[0];
	wire load = KEY[3];
	// Create the colour, x, y and writeEn wires that are inputs to the controller
	wire [2:0] colour = 3'b0;
	//port list problems
	wire [7:0] x;
	wire [1:0] user_data;
	wire [6:0] y;
	assign user_data = SW[1:0];
	wire load_x,load_y,load_white,load_plot;	
	wire [4:0] counter;	
	wire [3:0] colour_out;
	wire [12:0] whiteCounterOut;
	wire [12:0] whiteCounter;
	wire load_clear;
	wire writeEn;
	wire enableP;
	assign enableP = KEY[1];
	wire resetCounter;
	wire loadblock;
	wire resetblock_x;
	wire clearblock, drawblock, eraseblock;
   wire [4:0]blockcounter;
	wire [25:0]count1;
	wire [25:0]count2;
	wire div, div2;
	wire signal, signal2;
	// Create an Instance of a VGA controller - there can be only one!
	// Define the number of colours as well as the initial background
	// image file (.MIF) for the controller.
	Counter26Bit a1(CLOCK_50, div, count1[25:0], signal);
	Counter26Bit2 b1(CLOCK_50, div2, count2[25:0], signal2);
	RateDivider2 (count2[25:0], div2);
	RateDivider (count1[25:0], div);
	control c1 (CLOCK_50, resetn, load, enableP, load_x,load_plot, writeEn, load_clear, loadblock, resetblock_x, clearvalue, counter, clearblock, drawblock, eraseblock, blockcounter, signal, signal2);
	datapath d1 (CLOCK_50, resetn, user_data, colour, load_clear, load_x, clearvalue, load_plot, resetblock_x, x, y, colour_out, counter, loadblock, clearblock, drawblock, eraseblock, blockcounter);
	vga_adapter VGA(
			.resetn(resetn),
			.clock(CLOCK_50),
			.colour(colour_out),
			.x(x),
			.y(y),
			.plot(writeEn),
			.VGA_R(VGA_R),
			.VGA_G(VGA_G),
			.VGA_B(VGA_B),
			.VGA_HS(VGA_HS),
			.VGA_VS(VGA_VS),
			.VGA_BLANK(VGA_BLANK_N),
			.VGA_SYNC(VGA_SYNC_N),
			.VGA_CLK(VGA_CLK));
			
		defparam VGA.RESOLUTION = "160x120";
		defparam VGA.MONOCHROME = "FALSE";
		defparam VGA.BITS_PER_COLOUR_CHANNEL = 3;
		defparam VGA.BACKGROUND_IMAGE = "background.mif";
		//defparam VGA.BITS_PER_COLOUR_CHANNEL = 3;
			
	// Put your code here. Your code should produce signals x,y,colour and writeEn
	// for the VGA controller, in addition to any other functionality your design may require.	
	
endmodule
	
module control (clock,resetn,load,plot, load_x,load_plot, writeEn, load_clear, loadblock, resetblock_x, clearvalue, counter, clearblock, drawblock, eraseblock, blockcounter, blockloader, blockplot);
	reg [1:0] firstcount;
	wire [25:0] count1;
	wire div1sec;
	wire divHalfsec;
	wire resetclock;
	input blockloader;
	input blockplot;
	input clock,resetn,plot,load;
	
	input [4:0] counter;
	output reg load_x,load_plot, writeEn, load_clear, loadblock, clearvalue, clearblock, drawblock, eraseblock, resetblock_x;
	reg [5:0] current_state, next_state;
	input [4:0]blockcounter;
	
	 localparam  S_LOAD_X        = 7'd0,
                S_LOAD_X_WAIT   = 7'd1,
                S_PLOT    		  = 7'd2,
					 S_LOAD_BLOCK    = 7'd3,
					 S_DRAW_BLOCK    = 7'd4,
					 S_BLOCK_WAIT   =  7'd5,
					 S_RESET_BLOCK_X = 7'd6;
	

	always@(*)
   
		begin: state_table 
       
			case (current_state)
            S_LOAD_BLOCK: next_state = blockloader? S_LOAD_BLOCK: S_BLOCK_WAIT;
				S_BLOCK_WAIT: next_state = blockplot? S_DRAW_BLOCK: S_BLOCK_WAIT;
				S_DRAW_BLOCK: next_state = (blockcounter[4:0] >= 5'b10000)? S_RESET_BLOCK_X: S_DRAW_BLOCK;
				S_RESET_BLOCK_X: next_state = S_LOAD_BLOCK;
				S_LOAD_X: next_state = load ? S_LOAD_X : S_LOAD_X_WAIT ; // Loop in current state until value is input
				S_LOAD_X_WAIT: next_state=plot? S_LOAD_X_WAIT:S_PLOT;
				S_PLOT: next_state = (counter[4:0] >= 5'b10000)? S_LOAD_X: S_PLOT;
				default: next_state = S_LOAD_X;
			
			endcase
	end
 
// Output logic aka all of our datapath control signals
   
	always @(*)
  
		begin: enable_signals
       // By default make all our signals 0
      
		load_x=1'b0;
		loadblock = 1'b0;
		load_clear = 1'b0;
		load_plot=1'b0;
		writeEn = 1'b0;
		clearvalue =1'b0;
		clearblock = 1'b0;
		drawblock = 1'b0;
		eraseblock = 1'b0;
		resetblock_x = 1'b0;
      
		case (current_state)
         S_LOAD_BLOCK:
			begin
				loadblock = 1'b1;
			end
			S_BLOCK_WAIT:
			begin
				clearblock = 1'b1;
				writeEn = 1'b1;
			end
			S_DRAW_BLOCK:
			begin 
				drawblock =1'b1;
				writeEn = 1'b1;
				eraseblock = 1'b1;
			end
			S_LOAD_X: 
			begin
				load_x = 1'b1;
			end
			
			S_LOAD_X_WAIT:
			begin
			load_clear = 1'b1;
			writeEn = 1'b1;
			end
			
			S_RESET_BLOCK_X:
			begin
			resetblock_x = 1'b1;
			end
			
			S_PLOT: 
			begin
				load_plot=1'b1;
				writeEn = 1'b1;
				clearvalue= 1'b1;
			end
			
		endcase
		
	end

// current_state registers
  
	always@(posedge clock)
  
		begin: state_FFs
     
			if(!resetn)       
				current_state <= S_LOAD_X; 
 	   
			else            
				current_state <= next_state;
				
		end // state_FFS

endmodule


module datapath(clk, resetn, user_data, colour, load_clear, load_x, clearvalue, load_plot, resetblock_x, X, Y, colour_out, counter_out, loadblock, clearblock, drawblock, eraseblock, blockcounter);
	
	 
	 output reg [7:0] X;
	 output reg [6:0] Y;
	 reg [7:0] Xorig;
	 reg [6:0] Yorig;
	 reg [7:0] xclear;
	 reg [6:0] yclear;
	 input [1:0]user_data;
	 input [2:0]colour;
	 output reg [2:0] colour_out;
	 input clk, resetn, load_x, load_plot, clearvalue, load_clear, loadblock, clearblock, drawblock, eraseblock, resetblock_x;
	 reg [4:0] counter;
	 output [4:0] counter_out;
	 assign counter_out[4:0] = counter[4:0];
    // Registers a, b, c, with respectilve input logic
	 reg [3:0]move;
    reg [4:0]clearcount;
	 reg [7:0]Xblock1;
	 reg [6:0]Yblock1;
	 reg [7:0]Xblock1clear;
	 reg [6:0]Yblock1clear;
	 reg [2:0]blockmove;
	 reg [4:0]blockclearcounter;
	 output reg [4:0]blockcounter;
    always@(posedge clk) begin

        if(!resetn) begin
				Xblock1 = 8'd27;
				Yblock1 = 7'd51;
				Xorig = 8'd75;
            Yorig = 7'd106;
				counter <= 5'd0;
				move = 3'b0;                                                          
				colour_out <= 3'd111;
				move = 3'b0;
				blockmove = 2'b0;
				clearcount <= 5'd0;
        end

        else begin

            if(load_x) 
				begin
					if(user_data == 2'b01)
					begin
					if (move < 3'b100)
						begin
							Xorig <= Xorig + 8'b00000010;
							Yorig <= 8'b01100100;
							move = move + 1'b1;
						end
					end
					else if(user_data == 2'b10)
					begin
						if (move < 3'b100)
						begin
							Xorig <= Xorig - 8'b00000010;
							Yorig <= 8'b01100100;
							move = move + 1'b1;
						end
					end
					counter <= 5'd0;
				end
				
				if(load_clear)
				begin
					if(clearcount<5'b10000)
					begin
						X <= xclear[7:0] + clearcount[1:0];
						Y <= yclear[6:0] + clearcount[3:2];
					end
					clearcount <= clearcount + 1'b1;
					colour_out <= 3'b111;
					counter <= 5'b0;
				end
				
				if(load_plot)	
				begin
					move<=3'b0;
					X <= Xorig[7:0] + counter[1:0];
					Y <= Yorig[6:0] + counter[3:2];
					counter <= counter + 1'b1;
					colour_out <= colour;
					clearcount <= 5'b0;
				end
				
				if(clearvalue)
				begin
					xclear <= Xorig;
					yclear <= Yorig;
					clearcount <= 5'b0;
				end
				
				if(loadblock)
				begin
				if(blockmove < 2'b10)
					begin
						Xblock1 <= Xblock1+1'b1;
						Yblock1 <= Yblock1+1'b1;
						blockmove = blockmove + 1'b1;
					end
				end
				if(eraseblock)
				begin
					Xblock1clear <= Xblock1;
					Yblock1clear <= Yblock1;
					blockclearcounter <= 5'd0;
				end
				if(clearblock)
				begin
					if(blockclearcounter < 5'b10000)
					begin
						X <= Xblock1clear[7:0] + blockclearcounter[1:0];
						Y <= Yblock1clear[6:0] + blockclearcounter[3:2];
					end
					blockclearcounter <= blockclearcounter + 1'b1;
					colour_out <= 3'b111;
					blockcounter <= 5'b0;
				end
				if(resetblock_x)
					begin
						Xblock1 <= 8'd27;
					end
				if(drawblock)
				begin
					blockmove<=2'b0;
					X <= Xblock1[7:0] + blockcounter[1:0];
					Y <= Yblock1[6:0] + blockcounter[3:2];
					blockcounter <= blockcounter + 1'b1;
					colour_out <= 3'd255;
					blockclearcounter <= 5'b0;
				end
        end

    end
	 
endmodule

module Counter26Bit (input CLOCK, input div,  output reg [25:0] count1, output reg blah); // counts up at 25MHz
	

	always @(posedge CLOCK) // triggered every time clock rises	
	begin
		
		if (div == 1)
		begin
		count1 <= 0;
		blah <= ~blah;
		end
		else
		count1 <= count1 + 1;	
		
		
	end
	
endmodule

module RateDivider (input [25:0] count1, output div); //div = 1 when it counts to designated value


		assign div = (count1 == 26'd50000000) ? 1'b1 : 1'b0;
			
		
endmodule

module RateDivider2 (input [25:0]count2, output div2);

	assign div2 = (count2 == 26'd25000000) ? 1'b1: 1'b0;

endmodule



module Counter26Bit2 (input CLOCK, input div2,  output reg [25:0] count2, output reg blah); // counts up at 25MHz
	

	always @(posedge CLOCK) // triggered every time clock rises	
	begin
		
		if (div2 == 1)
		begin
		count2 <= 0;
		blah <= ~blah;
		end
		else
		count2 <= count2 + 1;	
		
		
	end
	
endmodule
