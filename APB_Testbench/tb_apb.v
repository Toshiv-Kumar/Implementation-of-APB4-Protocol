`timescale 1ns / 1ps


   /// time_unit: Base unit for delays (1s, 1ms, 1us, 1ns, 1ps, 1fs)

    /// time_precision: Smallest resolvable time (must be ≤ time_unit)


module tb_apb;

  // signals for apb_master_requester
  reg  [2:0]  prot_from_bridge;
  reg  [3:0]  strb_from_bridge;
  reg         transfer_from_bridge;
  reg  [31:0] wdata_from_bridge;
  reg  [9:0] addr_from_bridge;
  reg         write_from_bridge;
  reg         PCLK;
  reg         PRESETn; // from_bridge signal, active low
  reg  [31:0] PRDATA;
  reg         PSLVERR;
  reg         PREADY;

  wire [31:0] PWDATA;
  wire        PWRITE;
  wire [9:0]  PADDR;
  wire        PSELx;
  wire        PENABLE;
  wire [2:0]  PPROT;
  wire [3:0]  PSTRB;
  wire        error; // this signal goes to the cpu
  parameter data_width_bits = 32; parameter data_width_bytes = data_width_bits >> 3;
  parameter idle = 2'b00; parameter setup = 2'b01; parameter access = 2'b11; // 0->1->3 to decrease activity factor.
  parameter address_bits = 10; parameter address_locations = 1<<10;
  reg [data_width_bits-1 : 0] slave_storage [0: address_locations-1]; // as we have 10 address bits
   reg [1:0]j;
  // instantiate master (named association)
  apb_master_requester uut_master (
    .prot_from_bridge(prot_from_bridge),
    .strb_from_bridge(strb_from_bridge),
    .transfer_from_bridge(transfer_from_bridge),
    .wdata_from_bridge(wdata_from_bridge),
    .addr_from_bridge(addr_from_bridge),
    .write_from_bridge(write_from_bridge),
    .PCLK(PCLK),
    .PRESETn(PRESETn),
    .PRDATA(PRDATA),
    .PSLVERR(PSLVERR),
    .PREADY(PREADY),
    .PWDATA(PWDATA),
    .PWRITE(PWRITE),
    .PADDR(PADDR),
    .PSELx(PSELx),
    .PENABLE(PENABLE),
    .PPROT(PPROT),
    .PSTRB(PSTRB),
    .error(error)
  );

always #5 PCLK = ~PCLK;
initial begin
    PREADY = 0;
    PSLVERR = 0;
    PRDATA = 0;

    transfer_from_bridge = 0;
    prot_from_bridge = 0;
    strb_from_bridge = 0;
    wdata_from_bridge = 0;
    addr_from_bridge = 0;
    write_from_bridge = 0;
end
integer i;
initial begin
  for (i = 0; i < address_locations; i = i + 1) begin
    slave_storage[i] = i;
  end
end

initial begin // to initialize ahb to apb transfers/from cpu transfers
	PCLK = 0;

	PRESETn = 1'b0;
	#6 PRESETn = 1'b1;
	// add reset randomly
	# 200 PRESETn = 1'b0;
	# 16 PRESETn = 1'b1;
	# 2000 $finish;
end

always @(posedge PCLK) begin  // These are the signals from our bridge ckt
	
	if (PRESETn == 1'b0) begin
	
	end
	else begin
		if (transfer_from_bridge == 1'b1) begin
			transfer_from_bridge <= #1 1'b0;
		end
		if(uut_master.ps == idle || uut_master.ps == setup) begin
			transfer_from_bridge <= #1 $urandom();
    		prot_from_bridge <= #1 $urandom();
			strb_from_bridge <= #1 4'b1111;
			
			wdata_from_bridge <= #1 $urandom();
			addr_from_bridge <= #1 $urandom();
			write_from_bridge <= #1 $urandom();			
		end
		
	
	end
	
end


initial begin
	forever begin
		
		wait (PREADY == 1'b1);
		PSLVERR = PPROT[1]? 1'b1: $urandom();
		if( PWRITE == 1'b0 && PSLVERR == 1'b0) begin
			PRDATA = slave_storage[PADDR];
		end	
		
		wait (PREADY != 1'b1);		
	
	end

end
always @(posedge PCLK) begin // our slave design
	if (PREADY == 1'b1) begin
		PREADY <= #1 1'b0;
		PSLVERR <= #1 1'b0;
		if( PWRITE == 1'b1 && PPROT[1] ==  1'b0) begin
			if (PSTRB[0]) slave_storage[PADDR][7:0]   <= #1 PWDATA[7:0];
			if (PSTRB[1]) slave_storage[PADDR][15:8]  <= #1 PWDATA[15:8];
			if (PSTRB[2]) slave_storage[PADDR][23:16] <= #1 PWDATA[23:16];
			if (PSTRB[3]) slave_storage[PADDR][31:24] <= #1 PWDATA[31:24];
		end		
	end
	
	else if (uut_master.ps == setup || uut_master.ps == access) begin
		PREADY <= #1 $urandom();
	end
	
end

endmodule


