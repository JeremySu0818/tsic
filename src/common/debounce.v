`timescale 1ns / 1ps

module debounce #(
	parameter DEBOUNCE_CYCLES = 200000,
	parameter CNT_BITS = $clog2(DEBOUNCE_CYCLES)
) (
	input clk,
	input resetn,
	input in,
	output reg out
);

reg [CNT_BITS-1:0] cnt;

wire in_active = ~in;
wire cnt_done = (cnt == DEBOUNCE_CYCLES - 1);

always @(posedge clk) begin
	if (!resetn) begin
		out <= 0;
		cnt <= 0;
	end else begin
		if (in_active == out) begin
			cnt <= 0;
		end else if (cnt_done) begin
			out <= in_active;
			cnt <= 0;
		end else begin
			cnt <= cnt + 1;
		end
	end
end

endmodule