`timescale 1ns / 1ps

module skill_slot (
	input clk,
	input resetn,
	input tick,
	input restart,
	input btn_skill,
	input [2:0] skill_charge,

	output [7:0] skill_timer
);
// Base branch has no skill behavior. Skill patches replace or extend this slot.
assign skill_timer = 0;

endmodule
