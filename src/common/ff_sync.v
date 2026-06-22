`timescale 1ns / 1ps

module ff_sync (
	input clk,
	input resetn,
	input in,
	output reg out
);
reg in_r;

always @(posedge clk) begin
	if (!resetn) begin
		in_r <= 0;
		out  <= 0;
	end else begin
		in_r <= in;
		out  <= in_r;
	end
end
endmodule
