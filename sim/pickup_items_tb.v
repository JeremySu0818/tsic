`timescale 1ns / 1ps
`include "game/game_defs.vh"

module pickup_items_tb;
reg clk = 0;
reg resetn = 0;
reg frame_tick = 0;
reg btn_left = 0;
reg btn_right = 0;
reg btn_start = 0;
reg btn_skill = 0;
reg btn_jump = 0;

wire [9:0] player_x;
wire [9:0] player_y;
wire [5:0] player_speed;
wire player_dir;
wire [7:0] obj_valid_bus;
wire [79:0] obj_xpos_bus;
wire [79:0] obj_ypos_bus;
wire [31:0] obj_type_bus;
wire turtle_valid;
wire [9:0] turtle_x;
wire turtle_dir;
wire [7:0] timer;
wire [9:0] score;
wire [11:0] timer_bcd;
wire [11:0] score_bcd;
wire [11:0] high_score_bcd;
wire [2:0] skill_charge;
wire [7:0] skill_timer;
wire skill_on;
wire magnet_on;
wire game_over;
wire [1:0] game_state;
wire [7:0] combo;
wire [7:0] combo_bcd;
wire [1:0] difficulty_level;
wire [1:0] hit_feedback;
integer min_jump_y;

always #5 clk = ~clk;

game_ctrl #(
	.MAX_OBJ(8),
	.OBJ_TYPE_BITS(4)
) dut (
	.clk(clk), .resetn(resetn), .frame_tick(frame_tick),
	.btn_left(btn_left), .btn_right(btn_right), .btn_start(btn_start),
	.btn_skill(btn_skill), .btn_jump(btn_jump),
	.player_x(player_x), .player_y(player_y), .player_speed(player_speed),
	.player_dir(player_dir), .obj_valid_bus(obj_valid_bus),
	.obj_xpos_bus(obj_xpos_bus),
	.obj_ypos_bus(obj_ypos_bus), .obj_type_bus(obj_type_bus),
	.turtle_valid(turtle_valid), .turtle_x(turtle_x), .turtle_dir(turtle_dir),
	.timer(timer), .score(score), .timer_bcd(timer_bcd),
	.score_bcd(score_bcd), .high_score_bcd(high_score_bcd),
	.skill_charge(skill_charge), .skill_timer(skill_timer),
	.skill_on(skill_on), .magnet_on(magnet_on), .game_over(game_over),
	.game_state(game_state), .combo(combo), .combo_bcd(combo_bcd),
	.difficulty_level(difficulty_level), .hit_feedback(hit_feedback)
);

task pulse_frame;
	begin
		frame_tick = 1;
		@(posedge clk); #1;
		frame_tick = 0;
		@(posedge clk); #1;
	end
endtask

task place_item;
	input [3:0] item_type;
	input [3:0] lane;
	begin
		dut.obj_count = 1;
		dut.obj_type[0] = item_type;
		dut.obj_xpos[0] = 64 + lane * 32;
		dut.obj_xspeed[0] = 0;
		dut.obj_ypos[0] = `PLAYER_GROUND_Y;
		dut.spawn_cnt = 100;
	end
endtask

task check_result;
	input condition;
	input [8*80-1:0] message;
	begin
		if (!condition) begin
			$display("FAIL: %0s", message);
			$fatal(1);
		end
	end
endtask

initial begin
	repeat (3) @(posedge clk);
	resetn = 1;
	@(posedge clk);
	btn_start = 1;
	@(posedge clk); #1;
	btn_start = 0;
	@(posedge clk); #1;
	check_result(game_state == 1, "game enters play state");

	// The raised launch speed reaches at least 127 pixels above ground.
	btn_jump = 1;
	pulse_frame();
	btn_jump = 0;
	min_jump_y = player_y;
	repeat (12) begin
		pulse_frame();
		if (player_y < min_jump_y) min_jump_y = player_y;
	end
	check_result(min_jump_y <= `PLAYER_GROUND_Y - 10'd127,
		"higher jump reaches the intended apex");
	dut.player_y = `PLAYER_GROUND_Y; dut.jump_velocity = 0; dut.jump_armed = 1;

	// Magnet is caught at the player's normal position and lasts eight seconds.
	place_item(4'd7, 4'd7);
	pulse_frame();
	check_result(magnet_on && dut.magnet_timer == 8, "magnet activates for eight seconds");

	// Lane 4 is outside the normal player box but inside the 96-pixel magnet scope.
	place_item(4'd0, 4'd4);
	dut.obj_ypos[0] = 240;
	pulse_frame();
	check_result(dut.obj_xpos[0] > 192 && dut.obj_xspeed[0] == 1 &&
		dut.obj_ypos[0] > 240,
		"nearby coin accelerates horizontally while continuing to fall");
	repeat (20) pulse_frame();
	check_result(score == 1 && dut.obj_count == 0,
		"scoped coin remains catchable and reaches the player");

	place_item(4'd0, 4'd11);
	dut.obj_ypos[0] = 240;
	pulse_frame();
	check_result(dut.obj_xpos[0] < 416 && dut.obj_xspeed[0] == 1,
		"coin on the right accelerates left toward the player");
	repeat (20) pulse_frame();
	check_result(score == 2 && dut.obj_count == 0,
		"right-side scoped coin also reaches the player");

	// The same expanded range must not collect hazards or non-score pickups.
	place_item(4'd3, 4'd4);
	pulse_frame();
	check_result(score == 2 && dut.obj_count == 1 && dut.obj_xpos[0] == 192,
		"magnet leaves nearby negative items alone");

	dut.obj_count = 0;
	dut.frame_cnt = 59;
	pulse_frame();
	check_result(dut.magnet_timer == 7, "magnet timer counts down once per second");

	// Exercise all eight object effects copied by the mystery pickup.
	dut.score = 0; dut.combo = 0; dut.timer = 60; dut.frame_cnt = 0;
	dut.u_event_lfsr.rnd = 32'h0000_0000;
	place_item(4'd8, 4'd7);
	pulse_frame();
	check_result(score == 1, "mystery copies the +1 effect");

	dut.score = 0; dut.combo = 0;
	dut.u_event_lfsr.rnd = 32'h0000_0001;
	place_item(4'd8, 4'd7);
	pulse_frame();
	check_result(score == 3, "mystery copies the +3 effect");

	dut.score = 0; dut.combo = 0;
	dut.u_event_lfsr.rnd = 32'h0000_0002;
	place_item(4'd8, 4'd7);
	pulse_frame();
	check_result(score == 5, "mystery copies the +5 effect");

	dut.score = 10; dut.combo = 0;
	dut.u_event_lfsr.rnd = 32'h0000_0003;
	place_item(4'd8, 4'd7);
	pulse_frame();
	check_result(score == 7, "mystery copies the -3 effect");

	dut.score = 10; dut.combo = 0;
	dut.u_event_lfsr.rnd = 32'h0000_0004;
	place_item(4'd8, 4'd7);
	pulse_frame();
	check_result(score == 5, "mystery copies the -5 effect");

	dut.timer = 60;
	dut.u_event_lfsr.rnd = 32'h0000_0005;
	place_item(4'd8, 4'd7);
	pulse_frame();
	check_result(timer == 63, "mystery copies the time effect");

	dut.skill_charge = 0;
	dut.u_event_lfsr.rnd = 32'h0000_0006;
	place_item(4'd8, 4'd7);
	pulse_frame();
	check_result(skill_charge == 1, "mystery copies the charge effect");

	dut.magnet_timer = 0;
	dut.u_event_lfsr.rnd = 32'h0000_0007;
	place_item(4'd8, 4'd7);
	pulse_frame();
	check_result(dut.magnet_timer == 8, "mystery copies the magnet effect");

	// Turtle spawn direction and ground sliding come from its independent RNG.
	dut.turtle_valid = 0; dut.turtle_spawn_cnt = 0;
	dut.u_turtle_lfsr.rnd = 32'h0000_0001;
	pulse_frame();
	check_result(turtle_valid && turtle_dir && turtle_x == 0,
		"turtle randomly spawns at the left edge facing right");
	pulse_frame();
	check_result(turtle_x == 3, "turtle slides three pixels per frame");

	// A high jump clears the ground-height collision box.
	dut.score = 15; dut.timer = 30; dut.player_y = `PLAYER_GROUND_Y - 10'd112;
	dut.turtle_x = player_x;
	pulse_frame();
	check_result(score == 15 && timer == 30 && turtle_valid,
		"jumping above the turtle avoids its penalty");
	dut.player_y = `PLAYER_GROUND_Y;

	// The sliding turtle always deducts 10 points and 10 seconds, then despawns.
	dut.score = 15; dut.timer = 30; dut.combo = 6;
	dut.turtle_valid = 1; dut.turtle_x = player_x;
	pulse_frame();
	check_result(score == 5 && timer == 20 && combo == 0 && !turtle_valid,
		"turtle deducts score and time, resets combo, and despawns");

	dut.score = 4; dut.timer = 8;
	dut.turtle_valid = 1; dut.turtle_x = player_x;
	pulse_frame();
	check_result(score == 0 && timer == 0 && game_over,
		"turtle penalties clamp at zero and end the game");

	$display("PASS: pickup, magnet, mystery, and sliding turtle behavior");
	$finish;
end
endmodule
