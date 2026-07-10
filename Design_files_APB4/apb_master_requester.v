`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 18.06.2026 19:03:32
// Design Name: 
// Module Name: apb_master
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module apb_master_requester( // moore maching, ask gpt about this desgin, if my style is valid
	input [2:0] prot_from_bridge,
	input [3:0] strb_from_bridge,
	input transfer_from_bridge,
	input [31:0] wdata_from_bridge,
	
	input [9:0] addr_from_bridge,
	input write_from_bridge,
	input PCLK,
	input PRESETn, // It is the reset signal and is active-LOW.
	//PRESETn is normally connected directly to the system bus reset signal.
	input [31:0] PRDATA, // data to be read from slave/peripheral/completer
	input PSLVERR, // indicates if there is any error in the transaction during the access/data phase and so it warns master in advance that it needs to skip/redo this transaction 
	input PREADY, 
	output reg [31:0] PWDATA,
	output reg PWRITE,
	output reg [9:0] PADDR, // for synthesis: I limited the number of destination registers
	output reg PSELx,
	output reg PENABLE,
	output reg [2:0] PPROT,
	output reg [3:0] PSTRB,
	output reg error // for cpu in case of error
    );
    parameter data_width_bits = 32; parameter data_width_bytes = data_width_bits >> 3;
    parameter idle = 2'b00; parameter setup = 2'b01; parameter access = 2'b11; // 0->1->3 to decrease activity factor.
    parameter address_bits = 10;
    reg [1:0] ns;
    reg [1:0] ps;
    reg [data_width_bits-1:0] read_data_from_RDATA; // to be transferred to cpu through a fifo.
    
    
    always @(posedge PCLK) begin // mealy maching or it can be called hybrid
    	if (PRESETn == 1'b0) begin // Active-low signal
    		ps <= #1 idle;
    		end
    	else 
    		begin
    		ps <= #1 ns;
    	end
    end
	always @(ps or transfer_from_bridge or PSLVERR or PRDATA or PREADY or wdata_from_bridge or addr_from_bridge)// next state logic depends on both present state and inputs
	begin
    		case (ps)
    			idle: begin
    				if (transfer_from_bridge == 1'b1) begin
    					ns =  setup; // setup is also called address phase
    				end
    				else begin
    					ns = idle;
    				end
    			end
    			setup: begin
    				ns = access;
    			end
    			access: begin
    				if(PREADY == 1'b0) begin
    					ns = access;
    				end
    				else if (PREADY == 1'b1 && transfer_from_bridge == 1'b1) begin // back to back transfer
    					ns = setup;
    				end
    				else if(PREADY == 1'b1 && transfer_from_bridge == 1'b0) begin // no back to back transfer
    					ns = idle;
    				end
    				else begin
    					ns = idle;
    				end
    			end
    			default: begin
    				ns = idle;
    			end
			endcase
	end
	
	
	always @(posedge PCLK) begin // output logic
		if (PRESETn == 1'b0) begin
			// reest all output signals to a value that you think they should be after one transfer is completed.
			PSELx <= #1 1'b0;
			error <= #1 1'b0;
			PSTRB <= #1 1'b0;
		end
		else begin
			case(ps)
				idle: begin
					error <= #1 1'b0;
					if(ns == setup) begin
						
						PSELx <= #1 1'b1;
						PENABLE <= #1 1'b0;
						PADDR <= #1 addr_from_bridge;
						PWRITE <= #1 write_from_bridge;
						if(write_from_bridge == 1'b1) begin  
							PWDATA <= #1 wdata_from_bridge; 
							PSTRB <= #1 strb_from_bridge;
					    end
					    else begin
					    	PSTRB <= #1 4'b0000;
					    end
						PPROT <= #1 prot_from_bridge; 
						
					end
					else begin
						PSELx <= #1 1'b0;
					end
				end
			
				setup: begin
					error <= #1 1'b0;
					PENABLE <= #1 1'b1;
					PSELx <= #1 1'b1;
				end
			
				access: begin /// remember to do pselx = 0 && others if going back to idle state
				// if PPROT[1] == 1'b1 then  Non-secure master so no don't read or write data at all.
				// For PSTRB
					if (ns == setup) begin // remember: within this single edge, state changes and final output is given out
					// change all the output signals as per idle state
						PSELx <= #1 1'b1;
						PENABLE <= #1 1'b0;
						PADDR <= #1 addr_from_bridge;
						PWRITE <= #1 write_from_bridge;
						if(write_from_bridge == 1'b1) begin  
							PWDATA <= #1 wdata_from_bridge; 
							PSTRB <= #1 strb_from_bridge;
					    end
					    else begin
					    	PSTRB <= #1 4'b0000;
					    end
						PPROT <= #1 prot_from_bridge; 
						if (PWRITE == 1'b1) begin 
							if(PSLVERR == 1'b1) begin
								error <= #1 1'b1;
							end
							else begin 
								error <= #1 1'b0;
							end
							// no need to do anything else
						end
						else begin // system is in read mode:
							if(PSLVERR == 1'b1 || PPROT[1] ==  1'b1) begin
								error <= #1 1'b1;
							end
							else begin
								error <= #1 1'b0;	
								read_data_from_RDATA <= #1 PRDATA;
							end					
						end					
					end

					else if (ns == idle) begin
						PSELx <= #1 1'b0;
						PENABLE <= #1 1'b0;


						if (PWRITE == 1'b1) begin 
							if(PSLVERR == 1'b1) begin
								error <= #1 1'b1;
							end
						
							else begin 
								error <= #1 1'b0;
							end
							// no need to do anything else
						end
						else begin // system is in read mode:
							if(PSLVERR == 1'b1 || PPROT[1] ==  1'b1) begin
								error <= #1 1'b1;
							end
							else begin
								error <= #1 1'b0;	
								read_data_from_RDATA <= #1 PRDATA;
							end					
						end					
					end
					
					else begin // if ns == access
						// no need to do anything here.
					end
				end
			
			endcase
		end
	end
endmodule
