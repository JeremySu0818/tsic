`timescale 1ns / 1ps
`include "game/game_defs.vh"

module game_ctrl #(
	parameter MAX_OBJ = 16,
	parameter LANE_BITS = 4,
	parameter XOFF_BITS = 4,
	parameter OBJ_TYPE_BITS = 4,
	parameter OBJ_Y_BITS = 10,
	parameter FALL_SPEED = 2,
	parameter SPAWN_PERIOD_FRAMES = 24,
	parameter PLAYER_HIT_TOP_PAD = 16,
	parameter PLAYER_START_X = 288,
	parameter PLAYER_SPEED_START = 8,
	parameter TIMER_START = 60,
	parameter TIME_BONUS = 3,
	parameter FPS = 60,
	parameter SKILL_CHARGE_MAX = 5,
	parameter SKILL_ENABLE = 0,
	parameter SKILL_DURATION = 0
)(
	input clk,
	input resetn,
	input frame_tick,

	input btn_left,
	input btn_right,
	input btn_start,
	input btn_skill,
	input btn_jump,

	output reg [9:0] player_x,
	output reg [9:0] player_y,
	output reg [5:0] player_speed,
	output reg player_dir,

	output reg [MAX_OBJ              -1:0] obj_valid_bus,
	output reg [MAX_OBJ*OBJ_Y_BITS   -1:0] obj_xpos_bus,
	output reg [MAX_OBJ*OBJ_Y_BITS   -1:0] obj_ypos_bus,
	output reg [MAX_OBJ*OBJ_TYPE_BITS-1:0] obj_type_bus,
	output reg turtle_valid,
	output reg [9:0] turtle_x,
	output reg turtle_dir,

	output reg [7:0] timer,
	output reg [9:0] score,
	output [11:0] timer_bcd,
	output [11:0] score_bcd,
	output reg [11:0] high_score_bcd,
	output reg [2:0] skill_charge,
	output [7:0] skill_timer,
	output skill_on,
	output magnet_on,
	output gravity_flip_on,
	output coin_rain_on,
	output game_over,
	output [1:0] game_state,
	output reg [7:0] combo,
	output [7:0] combo_bcd,
	output reg [1:0] difficulty_level,
	output reg [1:0] hit_feedback
);
localparam S_TITLE = 0;
localparam S_PLAY = 1;
localparam S_OVER = 2;
localparam S_PAUSE = 3;

localparam TYPE_COIN_1 = 0;
localparam TYPE_COIN_3 = 1;
localparam TYPE_COIN_5 = 2;
localparam TYPE_MINUS3 = 3;
localparam TYPE_MINUS5 = 4;
localparam TYPE_TIME = 5;
localparam TYPE_CHARGE = 6;
localparam TYPE_MAGNET = 7;
localparam TYPE_MYSTERY = 8;

localparam MAGNET_DURATION = 8;
localparam MAGNET_RANGE = 96;
localparam [2:0] MAGNET_SPEED_MAX = 3'd7;

localparam [9:0] SCREEN_W = 640;
localparam [9:0] OBJ_GROUND_Y = `GROUND_Y - `OBJ_H;
localparam [9:0] PLAYER_MAX_X = SCREEN_W - `PLAYER_W;
// Turtle art is rendered at 4x source size (64x64); its opaque body occupies
// the lower 24 pixels, so the collision area stays tight to the ground.
localparam [9:0] TURTLE_RENDER_W = 10'd64;
localparam [9:0] TURTLE_HIT_H = 10'd24;
localparam [9:0] TURTLE_MAX_X = SCREEN_W - TURTLE_RENDER_W;
localparam [9:0] TURTLE_Y = `GROUND_Y - TURTLE_HIT_H;
localparam [3:0] TURTLE_SPEED = 4'd3;
localparam [7:0] TURTLE_SPAWN_MIN = FPS * 2;

reg [OBJ_Y_BITS   -1:0] obj_xpos [0:MAX_OBJ-1];
reg [OBJ_TYPE_BITS-1:0] obj_type [0:MAX_OBJ-1];
reg [OBJ_Y_BITS   -1:0] obj_ypos [0:MAX_OBJ-1];
reg [2:0] obj_xspeed [0:MAX_OBJ-1];
reg [4:0] obj_count;
reg [1:0] state;

reg [7:0] frame_cnt;
reg [7:0] spawn_cnt;
reg btn_start_q;
reg [7:0] spawn_period;
reg signed [6:0] jump_velocity;
reg jump_armed;
reg [3:0] feedback_timer;
reg [3:0] magnet_timer;
reg [3:0] gravity_flip_timer;
reg [3:0] coin_rain_timer;
reg [7:0] turtle_spawn_cnt;

wire btn_start_rise = btn_start && !btn_start_q;
wire game_restart = btn_start_rise && (state == S_TITLE || state == S_OVER);
wire skill_start;
wire skill_btn_active = btn_skill && state == S_PLAY;
wire can_left = player_x > player_speed;
wire can_right = player_x + player_speed < PLAYER_MAX_X;

wire [11:0] spawn_data;
wire spawn_fifo_empty;
wire obj_has_room = obj_count < MAX_OBJ;
wire remove_valid;
wire spawn_pop = frame_tick && state == S_PLAY &&
				  spawn_cnt == 0 && !spawn_fifo_empty &&
				  (obj_has_room || remove_valid);
wire game_step = frame_tick && state == S_PLAY;
wire timer_tick = frame_cnt == FPS - 1;
wire sec_tick = game_step && timer_tick;
wire [2:0] fall_speed_eff = (timer <= 20) ? 3'd4 :
								 (timer <= 40) ? 3'd3 : 3'd2;
wire signed [11:0] player_y_signed = $signed({1'b0, player_y});
wire signed [11:0] player_ground_y_signed = $signed({1'b0, `PLAYER_GROUND_Y});
wire signed [11:0] jump_next_y = player_y_signed + jump_velocity;

assign game_over = state == S_OVER;
assign game_state = state;
assign magnet_on = magnet_timer != 0;
assign gravity_flip_on = gravity_flip_timer != 0;
assign coin_rain_on = coin_rain_timer != 0;

wire turtle_hit = game_step && turtle_valid &&
	player_x < turtle_x + `OBJ_W && player_x + `PLAYER_W > turtle_x &&
	player_y + PLAYER_HIT_TOP_PAD < TURTLE_Y + `OBJ_H &&
	player_y + `PLAYER_H > TURTLE_Y;
wire turtle_spawn_fire = game_step && !turtle_valid && turtle_spawn_cnt == 0;
wire [31:0] turtle_rnd;

lfsr32 #(
	.SEED(32'h7A11_E123)
) u_turtle_lfsr (
	.clk(clk),
	.resetn(resetn),
	.en(turtle_spawn_fire),
	.rnd(turtle_rnd)
);

skill_slot #(
	.ENABLE(SKILL_ENABLE),
	.DURATION(SKILL_DURATION),
	.CHARGE_MAX(SKILL_CHARGE_MAX)
) u_skill_slot (
	.clk(clk),
	.resetn(resetn),
	.sec_tick(sec_tick),
	.restart(game_restart),
	.btn_skill(skill_btn_active),
	.skill_charge(skill_charge),
	.skill_timer(skill_timer),
	.skill_on(skill_on),
	.skill_start(skill_start)
);

spawn_queue u_spawn_queue (
	.clk(clk),
	.resetn(resetn),
	.enable(state == S_PLAY),
	.pop(spawn_pop),
	.spawn_data(spawn_data),
	.empty(spawn_fifo_empty)
);

wire [LANE_BITS-1:0] spawn_lane_raw = spawn_data[11:8];
wire [XOFF_BITS-1:0] spawn_xoff_raw = spawn_data[7:4];
wire [OBJ_TYPE_BITS-1:0] spawn_type_raw = spawn_data[3:0];
wire [LANE_BITS-1:0] spawn_lane;
wire [XOFF_BITS-1:0] spawn_xoff;
wire [OBJ_TYPE_BITS-1:0] spawn_type;
// A coin-rain event must only produce score coins.  Use the queued random
// type bits as the source so the distribution continues to vary per spawn.
wire [OBJ_TYPE_BITS-1:0] spawn_type_eff = coin_rain_on ?
	(spawn_type_raw[1:0] == 2'd3 ? TYPE_COIN_1 : {2'b00, spawn_type_raw[1:0]}) :
	spawn_type;

spawn_postprocess #(
	.LANE_BITS(LANE_BITS),
	.XOFF_BITS(XOFF_BITS),
	.OBJ_TYPE_BITS(OBJ_TYPE_BITS)
) u_spawn_postprocess (
	.clk(clk),
	.resetn(resetn),
	.fire(spawn_pop),
	.raw_lane(spawn_lane_raw),
	.raw_xoff(spawn_xoff_raw),
	.raw_type(spawn_type_raw),
	.out_lane(spawn_lane),
	.out_xoff(spawn_xoff),
	.out_type(spawn_type)
);

integer hit_i;
reg hit_valid;
reg [4:0] hit_idx;
reg [9:0] hit_obj_x;
reg hit_in_normal_range;
wire [10:0] hit_player_t = player_y + PLAYER_HIT_TOP_PAD;
wire [10:0] hit_player_b = player_y + `PLAYER_H;

function [9:0] obj_x;
	input [LANE_BITS-1:0] lane;
	input [XOFF_BITS-1:0] xoff;
	begin obj_x = `GAME_X0 + ({6'd0, lane} << 5) + {6'd0, xoff}; end
endfunction

always @(*) begin
	hit_valid = 0;
	hit_idx = 0;
	hit_obj_x = 0;
	hit_in_normal_range = 0;

	for (hit_i = 0; hit_i < MAX_OBJ; hit_i = hit_i + 1) begin
		hit_obj_x = obj_xpos[hit_i];
		hit_in_normal_range = player_x < hit_obj_x + `OBJ_W &&
			player_x + `PLAYER_W > hit_obj_x;
		if (!hit_valid && hit_i < obj_count &&
			hit_in_normal_range &&
			hit_player_t < obj_ypos[hit_i] + `OBJ_H &&
			hit_player_b > obj_ypos[hit_i]) begin
			hit_valid = 1;
			hit_idx = hit_i[4:0];
		end
	end
end

integer attract_i;
reg [OBJ_Y_BITS-1:0] obj_xpos_step [0:MAX_OBJ-1];
reg [OBJ_Y_BITS-1:0] obj_ypos_step [0:MAX_OBJ-1];
reg [2:0] obj_xspeed_step [0:MAX_OBJ-1];
reg [MAX_OBJ-1:0] obj_magnet_scoped;
reg [9:0] attract_target_x;
reg [9:0] attract_scope_l;
reg [9:0] attract_scope_r;

always @(*) begin
	attract_target_x = player_x + (`PLAYER_W - `OBJ_W) / 2;
	attract_scope_l = player_x > MAGNET_RANGE ? player_x - MAGNET_RANGE : 0;
	attract_scope_r = player_x + `PLAYER_W + MAGNET_RANGE;
	obj_magnet_scoped = 0;

	for (attract_i = 0; attract_i < MAX_OBJ; attract_i = attract_i + 1) begin
		obj_xpos_step[attract_i] = obj_xpos[attract_i];
		obj_ypos_step[attract_i] = obj_ypos[attract_i] + fall_speed_eff;
		obj_xspeed_step[attract_i] = 0;

		if (magnet_on && attract_i < obj_count &&
			obj_type[attract_i] <= TYPE_COIN_5 &&
			obj_xpos[attract_i] + `OBJ_W > attract_scope_l &&
			obj_xpos[attract_i] < attract_scope_r) begin
			obj_magnet_scoped[attract_i] = 1;
			if (obj_xspeed[attract_i] < MAGNET_SPEED_MAX)
				obj_xspeed_step[attract_i] = obj_xspeed[attract_i] + 1'b1;
			else
				obj_xspeed_step[attract_i] = MAGNET_SPEED_MAX;

			if (obj_xpos[attract_i] < attract_target_x) begin
				if (obj_xpos[attract_i] + obj_xspeed_step[attract_i] >= attract_target_x)
					obj_xpos_step[attract_i] = attract_target_x[OBJ_Y_BITS-1:0];
				else
					obj_xpos_step[attract_i] = obj_xpos[attract_i] + obj_xspeed_step[attract_i];
			end else if (obj_xpos[attract_i] > attract_target_x) begin
				if (obj_xpos[attract_i] <= attract_target_x + obj_xspeed_step[attract_i])
					obj_xpos_step[attract_i] = attract_target_x[OBJ_Y_BITS-1:0];
				else
					obj_xpos_step[attract_i] = obj_xpos[attract_i] - obj_xspeed_step[attract_i];
			end

			// Keep the normal downward fall. At ground height, perform the final
			// horizontal pull so the next frame catches the reward normally.
			if (obj_ypos[attract_i] + fall_speed_eff >= OBJ_GROUND_Y)
				obj_xpos_step[attract_i] = attract_target_x;
		end
	end
end

wire mystery_hit = game_step && hit_valid && obj_type[hit_idx] == TYPE_MYSTERY;
wire coin_rain_start = mystery_hit && !event_rnd[0];
wire [31:0] event_rnd;

lfsr32 #(
	.SEED(32'hC0DE_1234)
) u_event_lfsr (
	.clk(clk),
	.resetn(resetn),
	.en(mystery_hit),
	.rnd(event_rnd)
);

wire ground_valid = (obj_count != 0) && (obj_ypos[0] >= OBJ_GROUND_Y) &&
	!obj_magnet_scoped[0];
assign remove_valid = hit_valid || ground_valid;
wire [4:0] remove_idx = hit_valid ? hit_idx : 0;

reg [9:0] next_score;
reg [7:0] next_timer;
reg [2:0] next_charge;
reg signed [5:0] score_delta;
reg signed [6:0] score_delta_eff;
reg signed [10:0] score_sum;
reg [7:0] next_combo;
wire [9:0] final_score = (hit_valid || turtle_hit) ? next_score : score;
always @(*) begin
	next_score = score;
	next_timer = timer;
	next_charge = skill_charge;
	score_delta = 0;
	score_delta_eff = 0;
	score_sum = score;
	next_combo = combo;

	if (turtle_hit) begin
		next_score = score > 10 ? score - 10 : 0;
		next_timer = timer > 10 ? timer - 10 : 0;
		next_combo = 0;
	end else if (hit_valid) begin
		case (obj_type[hit_idx])
			TYPE_COIN_1: score_delta = 1;
			TYPE_COIN_3: score_delta = 3;
			TYPE_COIN_5: score_delta = 5;
			TYPE_MINUS3: score_delta = -3;
			TYPE_MINUS5: score_delta = -5;
			TYPE_TIME: next_timer = timer + TIME_BONUS;
			TYPE_CHARGE:
				if (skill_charge < SKILL_CHARGE_MAX)
					next_charge = skill_charge + 1;
			TYPE_MAGNET: begin
				next_timer = timer;
			end
			TYPE_MYSTERY:
				case (event_rnd[2:0])
					3'd0: score_delta = 1;
					3'd1: score_delta = 3;
					3'd2: score_delta = 5;
					3'd3: score_delta = -3;
					3'd4: score_delta = -5;
					3'd5: next_timer = timer + TIME_BONUS;
					3'd6:
						if (skill_charge < SKILL_CHARGE_MAX)
							next_charge = skill_charge + 1;
					default: next_timer = timer;
				endcase
			default: begin
				next_timer = timer;
				next_charge = skill_charge;
			end
		endcase

		// The fire skill converts hazards into rewards. Combo then multiplies
		// positive catches: x2 at 5, x3 at 10.
		if (skill_on && score_delta < 0)
			score_delta_eff = -score_delta;
		else
			score_delta_eff = score_delta;

		if (score_delta_eff > 0) begin
			if (combo >= 10)
				score_delta_eff = score_delta_eff * 3;
			else if (combo >= 5)
				score_delta_eff = score_delta_eff * 2;
			if (combo < 99)
				next_combo = combo + 1;
		end else if (score_delta_eff < 0) begin
			next_combo = 0;
		end
		score_sum = $signed({1'b0, score}) + score_delta_eff;
		if (score_sum < 0)
			next_score = 0;
		else
			next_score = score_sum[9:0];
	end
end

wire game_ending = sec_tick && next_timer <= 1;
wire new_high_score = score_bcd > high_score_bcd;

wire high_score_will_update = game_ending && new_high_score;

bin2bcd #(
	.BIN_BITS(10)
) u_score_bcd (
	.bin(final_score),
	.bcd(score_bcd)
);

bin2bcd #(
	.BIN_BITS(8)
) u_timer_bcd (
	.bin(timer),
	.bcd(timer_bcd)
);

wire [11:0] combo_bcd_full;
assign combo_bcd = combo_bcd_full[7:0];

bin2bcd #(
	.BIN_BITS(8)
) u_combo_bcd (
	.bin(combo),
	.bcd(combo_bcd_full)
);

integer pack_i;

always @(*) begin
	obj_valid_bus = 0;
	obj_xpos_bus = 0;
	obj_ypos_bus = 0;
	obj_type_bus = 0;

	for (pack_i = 0; pack_i < MAX_OBJ; pack_i = pack_i + 1) begin
		if (pack_i < obj_count) begin
			obj_valid_bus[pack_i] = 1;
			obj_xpos_bus[pack_i*OBJ_Y_BITS    +: OBJ_Y_BITS]    = obj_xpos[pack_i];
			obj_ypos_bus[pack_i*OBJ_Y_BITS    +: OBJ_Y_BITS]    = obj_ypos[pack_i];
			obj_type_bus[pack_i*OBJ_TYPE_BITS +: OBJ_TYPE_BITS] = obj_type[pack_i];
		end
	end
end

integer i;

always @(posedge clk) begin
	if (!resetn) begin
		player_x <= PLAYER_START_X;
		player_y <= `PLAYER_GROUND_Y;
		player_speed <= PLAYER_SPEED_START;
		player_dir <= 1;
		spawn_period <= SPAWN_PERIOD_FRAMES;
		obj_count <= 0;
		timer <= TIMER_START;
		score <= 0;
		high_score_bcd <= 12'h000;
		skill_charge <= 0;
		state <= S_TITLE;
		frame_cnt <= 0;
		spawn_cnt <= SPAWN_PERIOD_FRAMES;
		btn_start_q <= 0;
		jump_velocity <= 0;
		jump_armed <= 1;
		combo <= 0;
		difficulty_level <= 0;
		hit_feedback <= 0;
		feedback_timer <= 0;
		magnet_timer <= 0;
		gravity_flip_timer <= 0;
		coin_rain_timer <= 0;
		turtle_valid <= 0;
		turtle_x <= 0;
		turtle_dir <= 1;
		turtle_spawn_cnt <= TURTLE_SPAWN_MIN;

		for (i = 0; i < MAX_OBJ; i = i + 1) begin
			obj_xpos[i] <= 0;
			obj_ypos[i] <= 0;
			obj_type[i] <= 0;
			obj_xspeed[i] <= 0;
		end
	end else begin
		btn_start_q <= btn_start;
		if (!btn_jump)
			jump_armed <= 1'b1;

		if (btn_start_rise) begin
			if (state == S_PLAY) begin
				state <= S_PAUSE;
			end else if (state == S_PAUSE) begin
				state <= S_PLAY;
			end else begin
				player_x <= PLAYER_START_X;
				player_y <= `PLAYER_GROUND_Y;
				player_speed <= PLAYER_SPEED_START;
				player_dir <= 1;
				jump_velocity <= 0;
				jump_armed <= !btn_jump;
				spawn_period <= SPAWN_PERIOD_FRAMES;
				obj_count <= 0;
				timer <= TIMER_START;
				score <= 0;
				combo <= 0;
				difficulty_level <= 0;
				hit_feedback <= 0;
				feedback_timer <= 0;
				magnet_timer <= 0;
				gravity_flip_timer <= 0;
				coin_rain_timer <= 0;
				turtle_valid <= 0;
				turtle_x <= 0;
				turtle_dir <= 1;
				turtle_spawn_cnt <= TURTLE_SPAWN_MIN;
				skill_charge <= 0;
				state <= S_PLAY;
				frame_cnt <= 0;
				spawn_cnt <= SPAWN_PERIOD_FRAMES;

				for (i = 0; i < MAX_OBJ; i = i + 1) begin
					obj_xpos[i] <= 0;
					obj_ypos[i] <= 0;
					obj_type[i] <= 0;
					obj_xspeed[i] <= 0;
				end
			end
		end else begin
			if (frame_tick && state == S_PLAY) begin
				// A ground hazard periodically slides in from a random screen edge.
				// It disappears after a hit or after crossing the whole playfield.
				if (turtle_hit) begin
					turtle_valid <= 0;
					turtle_spawn_cnt <= TURTLE_SPAWN_MIN + {1'b0, turtle_rnd[6:0]};
				end else if (turtle_valid) begin
					if (turtle_dir) begin
						if (turtle_x >= TURTLE_MAX_X) begin
							turtle_valid <= 0;
							turtle_spawn_cnt <= TURTLE_SPAWN_MIN + {1'b0, turtle_rnd[6:0]};
						end else
							turtle_x <= turtle_x + TURTLE_SPEED;
					end else begin
						if (turtle_x < TURTLE_SPEED) begin
							turtle_valid <= 0;
							turtle_spawn_cnt <= TURTLE_SPAWN_MIN + {1'b0, turtle_rnd[6:0]};
						end else
							turtle_x <= turtle_x - TURTLE_SPEED;
					end
				end else if (turtle_spawn_cnt == 0) begin
					turtle_valid <= 1;
					turtle_dir <= turtle_rnd[0];
					turtle_x <= turtle_rnd[0] ? 0 : TURTLE_MAX_X;
				end else begin
					turtle_spawn_cnt <= turtle_spawn_cnt - 1'b1;
				end
				if (sec_tick && magnet_timer != 0)
					magnet_timer <= magnet_timer - 1'b1;
				if (sec_tick && gravity_flip_timer != 0)
					gravity_flip_timer <= gravity_flip_timer - 1'b1;
				if (sec_tick && coin_rain_timer != 0)
					coin_rain_timer <= coin_rain_timer - 1'b1;
				// Three-stage difficulty ramp keeps the last 20 seconds frantic.
				if (timer <= 20) begin
					difficulty_level <= 2;
					spawn_period <= 12;
				end else if (timer <= 40) begin
					difficulty_level <= 1;
					spawn_period <= 18;
				end else begin
					difficulty_level <= 0;
					spawn_period <= SPAWN_PERIOD_FRAMES;
				end

				// One-button jump with gravity. A release rearms the next jump,
				// preventing bunny-hop repeats while the button is held.
				if (player_y == `PLAYER_GROUND_Y && btn_jump && jump_armed) begin
					jump_velocity <= -7'sd20;
					player_y <= `PLAYER_GROUND_Y - 10'd20;
					jump_armed <= 1'b0;
				end else if (player_y < `PLAYER_GROUND_Y) begin
					if (jump_next_y >= player_ground_y_signed) begin
						player_y <= `PLAYER_GROUND_Y;
						jump_velocity <= 0;
					end else if (jump_next_y < 0) begin
						player_y <= 0;
						jump_velocity <= jump_velocity + 2;
					end else begin
						player_y <= jump_next_y[9:0];
						jump_velocity <= jump_velocity + 2;
					end
				end

				if (feedback_timer != 0) begin
					feedback_timer <= feedback_timer - 1'b1;
					if (feedback_timer == 1)
						hit_feedback <= 0;
				end

				// Direction control
				if (btn_left && !btn_right) begin
					if (can_left)
						player_x <= player_x - player_speed;
					else
						player_x <= 0;
					player_dir <= 0;
				end else if (btn_right && !btn_left) begin
					if (can_right)
						player_x <= player_x + player_speed;
					else
						player_x <= PLAYER_MAX_X;
					player_dir <= 1;
				end

				// Hit effect update
				if (turtle_hit) begin
					score <= next_score;
					timer <= next_timer;
					combo <= 0;
					feedback_timer <= 8;
					hit_feedback <= 2;
					if (next_timer == 0) begin
						state <= S_OVER;
						if (score_bcd > high_score_bcd)
							high_score_bcd <= score_bcd;
					end
				end else if (hit_valid) begin
					score <= next_score;
					timer <= next_timer;
					skill_charge <= next_charge;
					combo <= next_combo;
					feedback_timer <= 8;
					if (obj_type[hit_idx] == TYPE_MAGNET ||
						(obj_type[hit_idx] == TYPE_MYSTERY && event_rnd[2:0] == 3'd7))
						magnet_timer <= MAGNET_DURATION;
					if (mystery_hit) begin
						if (event_rnd[0]) begin
							gravity_flip_timer <= MAGNET_DURATION;
							coin_rain_timer <= 0;
						end else begin
							coin_rain_timer <= MAGNET_DURATION;
							gravity_flip_timer <= 0;
							// Coin rain is a reward event: turn on the same eight-second
							// magnet window as soon as it starts, not one frame later.
							magnet_timer <= MAGNET_DURATION;
						end
					end
					if (obj_type[hit_idx] == TYPE_TIME || obj_type[hit_idx] == TYPE_CHARGE ||
						obj_type[hit_idx] == TYPE_MAGNET || obj_type[hit_idx] == TYPE_MYSTERY)
						hit_feedback <= 3;
					else if (score_delta_eff > 0)
						hit_feedback <= 1;
					else
						hit_feedback <= 2;
				end else if (ground_valid &&
					(obj_type[0] <= TYPE_COIN_5 || obj_type[0] == TYPE_TIME ||
					 obj_type[0] == TYPE_CHARGE || obj_type[0] == TYPE_MAGNET ||
					 obj_type[0] == TYPE_MYSTERY)) begin
					combo <= 0;
				end

				// Object falling and spawning
				if (remove_valid) begin
					for (i = 0; i < MAX_OBJ-1; i = i + 1) begin
						if (i < obj_count - 1) begin
							if (i < remove_idx) begin
								obj_xpos[i] <= obj_xpos_step[i];
								obj_xspeed[i] <= obj_xspeed_step[i];
								obj_ypos[i] <= obj_ypos_step[i];
							end else begin
								obj_xpos[i] <= obj_xpos_step[i+1];
								obj_type[i] <= obj_type[i+1];
								obj_xspeed[i] <= obj_xspeed_step[i+1];
								obj_ypos[i] <= obj_ypos_step[i+1];
							end
						end
					end

					if (spawn_pop) begin
						obj_xpos[obj_count - 1] <= obj_x(spawn_lane, spawn_xoff);
						obj_type[obj_count - 1] <= spawn_type_eff;
						obj_ypos[obj_count - 1] <= 0;
						obj_xspeed[obj_count - 1] <= 0;
						obj_count <= obj_count;
					end else begin
						obj_count <= obj_count - 1;
					end
				end else begin
					for (i = 0; i < MAX_OBJ; i = i + 1) begin
						if (i < obj_count) begin
							obj_xpos[i] <= obj_xpos_step[i];
							obj_xspeed[i] <= obj_xspeed_step[i];
							obj_ypos[i] <= obj_ypos_step[i];
						end
					end

					if (spawn_pop) begin
						obj_xpos[obj_count] <= obj_x(spawn_lane, spawn_xoff);
						obj_type[obj_count] <= spawn_type_eff;
						obj_ypos[obj_count] <= 0;
						obj_xspeed[obj_count] <= 0;
						obj_count <= obj_count + 1;
					end
				end

				if (coin_rain_start)
					// Start the dense stream immediately on the next game frame.
					spawn_cnt <= 0;
				else if (coin_rain_on && spawn_pop)
					spawn_cnt <= 8'd5;
				else if (spawn_pop)
					spawn_cnt <= spawn_period - 1;
				else if (spawn_cnt != 0)
					spawn_cnt <= spawn_cnt - 1;

				if (timer_tick) begin
					frame_cnt <= 0;

					if (next_timer > 1) begin
						timer <= next_timer - 1;
					end else begin
						timer <= 0;
						state <= S_OVER;
						if (high_score_will_update) begin
							high_score_bcd <= score_bcd;
						end
					end
				end else begin
					frame_cnt <= frame_cnt + 1;
				end
			end
		end

		if (SKILL_ENABLE && skill_start)
			skill_charge <= 0;
	end
end
endmodule
