`timescale 1ns / 1ps

module game_ctrl #(
	parameter MAX_OBJ = 16,
	parameter LANE_BITS = 4,
	parameter X_BIAS_BITS = 4,
	parameter OBJ_TYPE_BITS = 2,
	parameter OBJ_Y_BITS = 10,
	parameter FALL_SPEED = 2,
	parameter SPAWN_PERIOD_FRAMES = 24,
	parameter PLAYER_WIDTH = 64,
	parameter PLAYER_HEIGHT = 64,
	parameter PLAYER_START_X = 288,
	parameter PLAYER_SPEED_START = 8,
	parameter TIMER_START = 30,
	parameter HIGH_SCORE_START = 0
)(
	input clk,
	input resetn,
	input frame_tick,

	input btn_left,
	input btn_right,
	input btn_start,

	output spawn_valid,

	output reg [9:0] player_x,
	output reg [5:0] player_speed,
	output reg player_facing_right,

	output reg [MAX_OBJ-1:0] obj_active_bus,
	output reg [MAX_OBJ*LANE_BITS-1:0] obj_lane_bus,
	output reg [MAX_OBJ*X_BIAS_BITS-1:0] obj_x_bias_bus,
	output reg [MAX_OBJ*OBJ_Y_BITS-1:0] obj_y_bus,
	output reg [MAX_OBJ*OBJ_TYPE_BITS-1:0] obj_type_bus,

	output reg [9:0] timer,
	output reg [13:0] score,
	output reg [13:0] high_score,
	output reg [1:0] state
);
localparam GAME_PLAYING = 1;
localparam GAME_GAMEOVER = 2;

localparam TYPE_COIN_1 = 0;
localparam TYPE_COIN_3 = 1;
localparam TYPE_COIN_5 = 2;
localparam TYPE_MINUS5 = 3;

localparam [9:0] SCREEN_W = 640;
localparam [9:0] GAME_X0 = 64;
localparam [9:0] UI_TOP = 416;
localparam [9:0] OBJ_W = 32;
localparam [9:0] OBJ_H = 32;
localparam [9:0] OBJ_GROUND_Y = UI_TOP - OBJ_H;
localparam [9:0] PLAYER_Y = 352;
localparam [9:0] PLAYER_MAX_X = SCREEN_W - PLAYER_WIDTH;

reg [LANE_BITS-1:0] obj_lane [0:MAX_OBJ-1];
reg [X_BIAS_BITS-1:0] obj_x_bias [0:MAX_OBJ-1];
reg [OBJ_TYPE_BITS-1:0] obj_type [0:MAX_OBJ-1];
reg [OBJ_Y_BITS-1:0] obj_y [0:MAX_OBJ-1];
reg [4:0] obj_count;

reg [5:0] frame_count;
reg [7:0] spawn_timer;
reg btn_start_q;

wire btn_start_rise = btn_start && !btn_start_q;
wire player_can_move_left = player_x > player_speed;
wire player_can_move_right = player_x + player_speed < PLAYER_MAX_X;

wire [9:0] spawn_packet;
wire spawn_fifo_empty;
wire obj_queue_ready = obj_count < MAX_OBJ;
wire remove_valid;
wire spawn_fire = frame_tick && state == GAME_PLAYING &&
					spawn_timer == 0 && !spawn_fifo_empty &&
					(obj_queue_ready || remove_valid);

assign spawn_valid = obj_queue_ready;

spawn_queue u_spawn_queue (
	.clk(clk),
	.resetn(resetn),
	.enable(state == GAME_PLAYING),
	.pop(spawn_fire),
	.packet(spawn_packet),
	.empty(spawn_fifo_empty)
);

integer hit_i;
reg hit_valid;
reg [4:0] hit_idx;
reg [9:0] hit_obj_x;

function [9:0] obj_x;
	input [LANE_BITS-1:0] lane;
	input [X_BIAS_BITS-1:0] x_bias;
	begin
		obj_x = GAME_X0 + ({6'd0, lane} << 5) + {6'd0, x_bias};
	end
endfunction

always @(*) begin
	hit_valid = 0;
	hit_idx = 0;
	hit_obj_x = 0;

	for (hit_i = 0; hit_i < MAX_OBJ; hit_i = hit_i + 1) begin
		hit_obj_x = obj_x(obj_lane[hit_i], obj_x_bias[hit_i]);
		if (!hit_valid && hit_i < obj_count &&
			player_x < hit_obj_x + OBJ_W &&
			player_x + PLAYER_WIDTH > hit_obj_x &&
			PLAYER_Y < obj_y[hit_i] + OBJ_H &&
			PLAYER_Y + PLAYER_HEIGHT > obj_y[hit_i]) begin
			hit_valid = 1;
			hit_idx = hit_i[4:0];
		end
	end
end

wire ground_valid = obj_count != 0 && obj_y[0] >= OBJ_GROUND_Y;
assign remove_valid = hit_valid || ground_valid;
wire [4:0] remove_idx = hit_valid ? hit_idx : 0;

reg [13:0] score_after_hit;
wire [13:0] score_for_gameover = hit_valid ? score_after_hit : score;

always @(*) begin
	score_after_hit = score;
	if (hit_valid) begin
		case (obj_type[hit_idx])
			TYPE_COIN_1: score_after_hit = score + 1;
			TYPE_COIN_3: score_after_hit = score + 3;
			TYPE_COIN_5: score_after_hit = score + 5;
			TYPE_MINUS5: score_after_hit = score >= 5 ? score - 5 : 0;
			default: score_after_hit = score;
		endcase
	end
end

integer pack_i;

always @(*) begin
	obj_active_bus = 0;
	obj_lane_bus = 0;
	obj_x_bias_bus = 0;
	obj_y_bus = 0;
	obj_type_bus = 0;

	for (pack_i = 0; pack_i < MAX_OBJ; pack_i = pack_i + 1) begin
		if (pack_i < obj_count) begin
			obj_active_bus[pack_i] = 1;
			obj_lane_bus[pack_i*LANE_BITS +: LANE_BITS] = obj_lane[pack_i];
			obj_x_bias_bus[pack_i*X_BIAS_BITS +: X_BIAS_BITS] = obj_x_bias[pack_i];
			obj_y_bus[pack_i*OBJ_Y_BITS +: OBJ_Y_BITS] = obj_y[pack_i];
			obj_type_bus[pack_i*OBJ_TYPE_BITS +: OBJ_TYPE_BITS] = obj_type[pack_i];
		end
	end
end

integer i;

always @(posedge clk) begin
	if (!resetn) begin
		player_x <= PLAYER_START_X;
		player_speed <= PLAYER_SPEED_START;
		player_facing_right <= 1;
		obj_count <= 0;
		timer <= TIMER_START;
		score <= 0;
		high_score <= HIGH_SCORE_START;
		state <= GAME_PLAYING;
		frame_count <= 0;
		spawn_timer <= SPAWN_PERIOD_FRAMES;
		btn_start_q <= 0;

		for (i = 0; i < MAX_OBJ; i = i + 1) begin
			obj_lane[i] <= 0;
			obj_x_bias[i] <= 0;
			obj_y[i] <= 0;
			obj_type[i] <= 0;
		end
	end else begin
		btn_start_q <= btn_start;

		if (btn_start_rise) begin
			player_x <= PLAYER_START_X;
			player_speed <= PLAYER_SPEED_START;
			player_facing_right <= 1;
			obj_count <= 0;
			timer <= TIMER_START;
			score <= 0;
			state <= GAME_PLAYING;
			frame_count <= 0;
			spawn_timer <= SPAWN_PERIOD_FRAMES;

			for (i = 0; i < MAX_OBJ; i = i + 1) begin
				obj_lane[i] <= 0;
				obj_x_bias[i] <= 0;
				obj_y[i] <= 0;
				obj_type[i] <= 0;
			end
		end else if (frame_tick) begin
			if (state == GAME_PLAYING) begin
				if (btn_left && !btn_right) begin
					if (player_can_move_left)
						player_x <= player_x - player_speed;
					else
						player_x <= 0;
					player_facing_right <= 0;
				end else if (btn_right && !btn_left) begin
					if (player_can_move_right)
						player_x <= player_x + player_speed;
					else
						player_x <= PLAYER_MAX_X;
					player_facing_right <= 1;
				end

				if (hit_valid) begin
					score <= score_after_hit;
				end

				if (remove_valid) begin
					for (i = 0; i < MAX_OBJ-1; i = i + 1) begin
						if (i < obj_count - 1) begin
							if (i < remove_idx) begin
								obj_y[i] <= obj_y[i] + FALL_SPEED;
							end else begin
								obj_lane[i] <= obj_lane[i+1];
								obj_x_bias[i] <= obj_x_bias[i+1];
								obj_type[i] <= obj_type[i+1];
								obj_y[i] <= obj_y[i+1] + FALL_SPEED;
							end
						end
					end

					if (spawn_fire) begin
						obj_lane[obj_count - 1] <= spawn_packet[9:6];
						obj_x_bias[obj_count - 1] <= spawn_packet[5:2];
						obj_type[obj_count - 1] <= spawn_packet[1:0];
						obj_y[obj_count - 1] <= 0;
						obj_count <= obj_count;
					end else begin
						obj_count <= obj_count - 1;
					end
				end else begin
					for (i = 0; i < MAX_OBJ; i = i + 1) begin
						if (i < obj_count)
							obj_y[i] <= obj_y[i] + FALL_SPEED;
					end

					if (spawn_fire) begin
						obj_lane[obj_count] <= spawn_packet[9:6];
						obj_x_bias[obj_count] <= spawn_packet[5:2];
						obj_type[obj_count] <= spawn_packet[1:0];
						obj_y[obj_count] <= 0;
						obj_count <= obj_count + 1;
					end
				end

				if (spawn_fire)
					spawn_timer <= SPAWN_PERIOD_FRAMES - 1;
				else if (spawn_timer != 0)
					spawn_timer <= spawn_timer - 1;

				if (frame_count == 59) begin
					frame_count <= 0;

					if (timer > 1) begin
						timer <= timer - 1;
					end else begin
						timer <= 0;
						state <= GAME_GAMEOVER;
						if (score_for_gameover > high_score)
							high_score <= score_for_gameover;
					end
				end else begin
					frame_count <= frame_count + 1;
				end
			end
		end
	end
end
endmodule
