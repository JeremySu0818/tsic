`timescale 1ns / 1ps
`include "hdmi/svo_defines.vh"

module res_overlay #(
	`SVO_DEFAULT_PARAMS
) (
	input clk,
	input resetn,

	input show,
	input [11:0] score_bcd,
	input [11:0] high_score_bcd,

	input in_axis_tvalid,
	output in_axis_tready,
	input [SVO_BITS_PER_PIXEL-1:0] in_axis_tdata,
	input [0:0] in_axis_tuser,

	output out_axis_tvalid,
	input out_axis_tready,
	output [SVO_BITS_PER_PIXEL-1:0] out_axis_tdata,
	output [0:0] out_axis_tuser
);
`SVO_DECLS

localparam [9:0] PANEL_X0 = 10'd128;
localparam [9:0] PANEL_X1 = 10'd512;
localparam [9:0] PANEL_Y0 = 10'd128;
localparam [9:0] PANEL_Y1 = 10'd352;
localparam [9:0] BORDER_T = 10'd4;

localparam [9:0] TITLE_X = 10'd224;
localparam [9:0] TITLE_Y = 10'd152;
localparam [9:0] SCORE_LABEL_X = 10'd176;
localparam [9:0] SCORE_Y = 10'd224;
localparam [9:0] BEST_LABEL_X = 10'd176;
localparam [9:0] BEST_Y = 10'd272;
localparam [9:0] VALUE_X = 10'd352;

localparam TEXT_TIME_UP = 0;
localparam TEXT_SCORE = 1;
localparam TEXT_BEST = 2;

localparam [23:0] COLOR_PANEL  = 24'h000000;
localparam [23:0] COLOR_BORDER = 24'hFFFFFF;
localparam [23:0] COLOR_TEXT   = 24'hFFFFFF;
localparam [23:0] COLOR_TITLE  = 24'h20EAFF;

`ifdef RES_OVERLAY_DIM
localparam DIM_BACKGROUND = 1;
`else
localparam DIM_BACKGROUND = 0;
`endif

reg [`SVO_XYBITS-1:0] hcursor;
reg [`SVO_XYBITS-1:0] vcursor;

wire fire = in_axis_tvalid && in_axis_tready;
wire [`SVO_XYBITS-1:0] pixel_x = in_axis_tuser[0] ? 0 : hcursor;
wire [`SVO_XYBITS-1:0] pixel_y = in_axis_tuser[0] ? 0 : vcursor;

wire in_panel =
	pixel_x >= PANEL_X0 && pixel_x < PANEL_X1 &&
	pixel_y >= PANEL_Y0 && pixel_y < PANEL_Y1;

wire in_border =
	in_panel &&
	(pixel_x < PANEL_X0 + BORDER_T ||
	 pixel_x >= PANEL_X1 - BORDER_T ||
	 pixel_y < PANEL_Y0 + BORDER_T ||
	 pixel_y >= PANEL_Y1 - BORDER_T);

function [23:0] dim_bgr888;
	input [23:0] rgb;
	begin
		dim_bgr888 = {1'b0, rgb[23:17], 1'b0, rgb[15:9], 1'b0, rgb[7:1]};
	end
endfunction

function [4:0] font_row;
	input [5:0] ch;
	input [2:0] row;
	begin
		case (ch)
			6'd0: begin // space
				font_row = 5'b00000;
			end
			6'd1: begin // A
				case (row)
					0: font_row = 5'b01110;
					1: font_row = 5'b10001;
					2: font_row = 5'b10001;
					3: font_row = 5'b11111;
					4: font_row = 5'b10001;
					5: font_row = 5'b10001;
					default: font_row = 5'b10001;
				endcase
			end
			6'd2: begin // B
				case (row)
					0: font_row = 5'b11110;
					1: font_row = 5'b10001;
					2: font_row = 5'b10001;
					3: font_row = 5'b11110;
					4: font_row = 5'b10001;
					5: font_row = 5'b10001;
					default: font_row = 5'b11110;
				endcase
			end
			6'd3: begin // C
				case (row)
					0: font_row = 5'b01111;
					1: font_row = 5'b10000;
					2: font_row = 5'b10000;
					3: font_row = 5'b10000;
					4: font_row = 5'b10000;
					5: font_row = 5'b10000;
					default: font_row = 5'b01111;
				endcase
			end
			6'd4: begin // E
				case (row)
					0: font_row = 5'b11111;
					1: font_row = 5'b10000;
					2: font_row = 5'b10000;
					3: font_row = 5'b11110;
					4: font_row = 5'b10000;
					5: font_row = 5'b10000;
					default: font_row = 5'b11111;
				endcase
			end
			6'd5: begin // I
				case (row)
					0: font_row = 5'b11111;
					1: font_row = 5'b00100;
					2: font_row = 5'b00100;
					3: font_row = 5'b00100;
					4: font_row = 5'b00100;
					5: font_row = 5'b00100;
					default: font_row = 5'b11111;
				endcase
			end
			6'd6: begin // M
				case (row)
					0: font_row = 5'b10001;
					1: font_row = 5'b11011;
					2: font_row = 5'b10101;
					3: font_row = 5'b10001;
					4: font_row = 5'b10001;
					5: font_row = 5'b10001;
					default: font_row = 5'b10001;
				endcase
			end
			6'd7: begin // O
				case (row)
					0: font_row = 5'b01110;
					1: font_row = 5'b10001;
					2: font_row = 5'b10001;
					3: font_row = 5'b10001;
					4: font_row = 5'b10001;
					5: font_row = 5'b10001;
					default: font_row = 5'b01110;
				endcase
			end
			6'd8: begin // P
				case (row)
					0: font_row = 5'b11110;
					1: font_row = 5'b10001;
					2: font_row = 5'b10001;
					3: font_row = 5'b11110;
					4: font_row = 5'b10000;
					5: font_row = 5'b10000;
					default: font_row = 5'b10000;
				endcase
			end
			6'd9: begin // R
				case (row)
					0: font_row = 5'b11110;
					1: font_row = 5'b10001;
					2: font_row = 5'b10001;
					3: font_row = 5'b11110;
					4: font_row = 5'b10100;
					5: font_row = 5'b10010;
					default: font_row = 5'b10001;
				endcase
			end
			6'd10: begin // S
				case (row)
					0: font_row = 5'b01111;
					1: font_row = 5'b10000;
					2: font_row = 5'b10000;
					3: font_row = 5'b01110;
					4: font_row = 5'b00001;
					5: font_row = 5'b00001;
					default: font_row = 5'b11110;
				endcase
			end
			6'd11: begin // T
				case (row)
					0: font_row = 5'b11111;
					1: font_row = 5'b00100;
					2: font_row = 5'b00100;
					3: font_row = 5'b00100;
					4: font_row = 5'b00100;
					5: font_row = 5'b00100;
					default: font_row = 5'b00100;
				endcase
			end
			6'd12: begin // U
				case (row)
					0: font_row = 5'b10001;
					1: font_row = 5'b10001;
					2: font_row = 5'b10001;
					3: font_row = 5'b10001;
					4: font_row = 5'b10001;
					5: font_row = 5'b10001;
					default: font_row = 5'b01110;
				endcase
			end
			default: font_row = 5'b00000;
		endcase
	end
endfunction

function [5:0] text_char;
	input [1:0] text_id;
	input [3:0] idx;
	begin
		text_char = 0;
		case (text_id)
			TEXT_TIME_UP: begin
				case (idx)
					0: text_char = 11; // T
					1: text_char = 5;  // I
					2: text_char = 6;  // M
					3: text_char = 4;  // E
					4: text_char = 0;
					5: text_char = 12; // U
					6: text_char = 8;  // P
					default: text_char = 0;
				endcase
			end
			TEXT_SCORE: begin
				case (idx)
					0: text_char = 10; // S
					1: text_char = 3;  // C
					2: text_char = 7;  // O
					3: text_char = 9;  // R
					4: text_char = 4;  // E
					default: text_char = 0;
				endcase
			end
			TEXT_BEST: begin
				case (idx)
					0: text_char = 2;  // B
					1: text_char = 4;  // E
					2: text_char = 10; // S
					3: text_char = 11; // T
					default: text_char = 0;
				endcase
			end
			default: text_char = 0;
		endcase
	end
endfunction

function text_pixel;
	input [`SVO_XYBITS-1:0] x;
	input [`SVO_XYBITS-1:0] y;
	input [1:0] text_id;
	input [9:0] x0;
	input [9:0] y0;
	input [3:0] scale;
	input [3:0] chars;
	reg [9:0] rel_x;
	reg [9:0] rel_y;
	reg [3:0] char_idx;
	reg [2:0] font_x;
	reg [2:0] font_y;
	reg [5:0] ch;
	reg [4:0] row_bits;
	begin
		text_pixel = 0;
		if (x >= x0 && x < x0 + chars * (6 * scale) &&
			y >= y0 && y < y0 + 7 * scale) begin
			rel_x = x - x0;
			rel_y = y - y0;
			char_idx = rel_x / (6 * scale);
			font_x = (rel_x - char_idx * (6 * scale)) / scale;
			font_y = rel_y / scale;
			ch = text_char(text_id, char_idx);

			if (char_idx < chars && font_x < 5 && font_y < 7 && ch != 0) begin
				row_bits = font_row(ch, font_y);
				text_pixel = row_bits[4 - font_x];
			end
		end
	end
endfunction

function [6:0] digit_seg;
	input [3:0] digit;
	begin
		case (digit)
			4'd0: digit_seg = 7'b1111110;
			4'd1: digit_seg = 7'b0110000;
			4'd2: digit_seg = 7'b1101101;
			4'd3: digit_seg = 7'b1111001;
			4'd4: digit_seg = 7'b0110011;
			4'd5: digit_seg = 7'b1011011;
			4'd6: digit_seg = 7'b1011111;
			4'd7: digit_seg = 7'b1110000;
			4'd8: digit_seg = 7'b1111111;
			4'd9: digit_seg = 7'b1111011;
			default: digit_seg = 7'b0000001;
		endcase
	end
endfunction

function [6:0] scaled_seg_pixel;
	input [5:0] x;
	input [5:0] y;
	input [3:0] scale;
	reg [5:0] w;
	reg [5:0] h;
	reg [5:0] t;
	reg x_mid;
	reg x_left;
	reg x_right;
	reg y_top;
	reg y_mid;
	reg y_bottom;
	reg y_upper;
	reg y_lower;
	begin
		w = 12 * scale;
		h = 20 * scale;
		t = 2 * scale;
		x_mid = x >= t && x < w - t;
		x_left = x < t;
		x_right = x >= w - t;
		y_top = y < t;
		y_mid = y >= h / 2 - t / 2 && y < h / 2 + t / 2;
		y_bottom = y >= h - t;
		y_upper = y >= t && y < h / 2;
		y_lower = y >= h / 2 && y < h - t;

		scaled_seg_pixel[6] = x_mid && y_top;
		scaled_seg_pixel[5] = x_right && y_upper;
		scaled_seg_pixel[4] = x_right && y_lower;
		scaled_seg_pixel[3] = x_mid && y_bottom;
		scaled_seg_pixel[2] = x_left && y_lower;
		scaled_seg_pixel[1] = x_left && y_upper;
		scaled_seg_pixel[0] = x_mid && y_mid;
	end
endfunction

function digit_pixel;
	input [3:0] digit;
	input [5:0] x;
	input [5:0] y;
	input [3:0] scale;
	begin
		digit_pixel = |(digit_seg(digit) & scaled_seg_pixel(x, y, scale));
	end
endfunction

function bcd_number_pixel;
	input [`SVO_XYBITS-1:0] x;
	input [`SVO_XYBITS-1:0] y;
	input [9:0] x0;
	input [9:0] y0;
	input [11:0] bcd;
	input [3:0] scale;
	integer i;
	reg [9:0] digit_left;
	reg [3:0] digit;
	reg [5:0] rel_x;
	reg [5:0] rel_y;
	begin
		bcd_number_pixel = 0;
		if (y >= y0 && y < y0 + 20 * scale) begin
			for (i = 0; i < 3; i = i + 1) begin
				digit_left = x0 + i * (14 * scale);
				case (i)
					0: digit = bcd[11:8];
					1: digit = bcd[7:4];
					default: digit = bcd[3:0];
				endcase

				if (x >= digit_left && x < digit_left + 12 * scale) begin
					rel_x = x - digit_left;
					rel_y = y - y0;
					bcd_number_pixel = digit_pixel(digit, rel_x, rel_y, scale);
				end
			end
		end
	end
endfunction

wire title_pixel = text_pixel(pixel_x, pixel_y, TEXT_TIME_UP, TITLE_X, TITLE_Y, 3, 7);
wire score_label_pixel = text_pixel(pixel_x, pixel_y, TEXT_SCORE, SCORE_LABEL_X, SCORE_Y, 2, 5);
wire best_label_pixel = text_pixel(pixel_x, pixel_y, TEXT_BEST, BEST_LABEL_X, BEST_Y, 2, 4);
wire score_value_pixel = bcd_number_pixel(pixel_x, pixel_y, VALUE_X, SCORE_Y, score_bcd, 2);
wire best_value_pixel = bcd_number_pixel(pixel_x, pixel_y, VALUE_X, BEST_Y, high_score_bcd, 2);

reg [23:0] overlay_data;

always @(*) begin
	overlay_data = in_axis_tdata;

	if (show) begin
		if (DIM_BACKGROUND)
			overlay_data = dim_bgr888(in_axis_tdata);

		if (in_panel)
			overlay_data = COLOR_PANEL;

		if (in_border)
			overlay_data = COLOR_BORDER;

		if (title_pixel)
			overlay_data = COLOR_TITLE;

		if (score_label_pixel || best_label_pixel ||
			score_value_pixel || best_value_pixel)
			overlay_data = COLOR_TEXT;
	end
end

assign in_axis_tready = out_axis_tready;
assign out_axis_tvalid = in_axis_tvalid;
assign out_axis_tdata = overlay_data;
assign out_axis_tuser = in_axis_tuser;

always @(posedge clk) begin
	if (!resetn) begin
		hcursor <= 0;
		vcursor <= 0;
	end else if (fire) begin
		if (in_axis_tuser[0]) begin
			hcursor <= 1;
			vcursor <= 0;
		end else if (hcursor == SVO_HOR_PIXELS - 1) begin
			hcursor <= 0;
			if (vcursor == SVO_VER_PIXELS - 1)
				vcursor <= 0;
			else
				vcursor <= vcursor + 1;
		end else begin
			hcursor <= hcursor + 1;
		end
	end
end

endmodule
