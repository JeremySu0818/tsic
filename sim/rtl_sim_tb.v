`timescale 1ns / 1ps

// Functional board simulator for the project I/O boundary.
// It runs the real game_core RTL, drives all five buttons/reset from io.txt,
// and writes the HDMI pixel stream as packed BGR888 frames for the viewer.
module rtl_sim_tb;
`ifdef RTL_SIM_FAST
    localparam integer WIDTH = 80;
    localparam integer HEIGHT = 60;
`else
    localparam integer WIDTH = 640;
    localparam integer HEIGHT = 480;
`endif
    localparam integer PIXELS = WIDTH * HEIGHT;

    reg clk = 0;
    reg resetn = 0;
    reg btn_left = 0;
    reg btn_right = 0;
    reg btn_start = 0;
    reg btn_skill = 0;
    reg btn_jump = 0;
    reg quit_requested = 0;

    wire out_axis_tvalid;
    wire [23:0] out_axis_tdata;
    wire [0:0] out_axis_tuser;

    integer state_fd;
    integer io_fd;
    integer scan_count;
    integer pixel_count = 0;
    integer frame_count = 0;
    integer max_frames = 0;
    integer io_resetn;
    integer io_left;
    integer io_right;
    integer io_start;
    integer io_skill;
    integer io_jump;
    integer io_quit;
    reg [1023:0] frame_path;
    reg [1023:0] state_path;
    reg [23:0] framebuffer [0:PIXELS-1];

    always #1 clk = ~clk;

    game_core #(
        .SVO_MODE("640x480V")
    ) dut (
        .clk(clk),
        .resetn(resetn),
        .btn_left(btn_left),
        .btn_right(btn_right),
        .btn_start(btn_start),
        .btn_skill(btn_skill),
        .btn_jump(btn_jump),
        .out_axis_tvalid(out_axis_tvalid),
        .out_axis_tready(1'b1),
        .out_axis_tdata(out_axis_tdata),
        .out_axis_tuser(out_axis_tuser)
    );

    task read_io;
        begin
            io_fd = $fopen("sim/runtime/io.txt", "r");
            if (io_fd != 0) begin
                scan_count = $fscanf(io_fd, "%d %d %d %d %d %d %d",
                    io_resetn, io_left, io_right, io_start,
                    io_skill, io_jump, io_quit);
                $fclose(io_fd);
                if (scan_count == 7) begin
                    resetn = io_resetn != 0;
                    btn_left = io_left != 0;
                    btn_right = io_right != 0;
                    btn_start = io_start != 0;
                    btn_skill = io_skill != 0;
                    btn_jump = io_jump != 0;
                    quit_requested = io_quit != 0;
                end
            end
        end
    endtask

    task write_state;
        begin
            $sformat(state_path, "sim/runtime/state_%08d.txt", frame_count);
            state_fd = $fopen(state_path, "w");
            $fwrite(state_fd,
                "frame=%0d\nstate=%0d\nscore=%0d\ntimer=%0d\nplayer_x=%0d\nplayer_y=%0d\ncharge=%0d\nskill_on=%0d\nskill_timer=%0d\ncombo=%0d\ndifficulty=%0d\n",
                frame_count, dut.game_state, dut.score, dut.timer,
                dut.player_x, dut.player_y, dut.skill_charge,
                dut.skill_on, dut.skill_timer, dut.combo,
                dut.difficulty_level);
            $fclose(state_fd);
        end
    endtask

    initial begin
        if (!$value$plusargs("MAX_FRAMES=%d", max_frames))
            max_frames = 0;
        repeat (8) @(posedge clk);
        read_io();
    end

    always @(posedge clk) begin
        if (out_axis_tvalid) begin
            if (out_axis_tuser[0]) begin
                pixel_count = 0;
            end

            if (pixel_count < PIXELS) begin
                framebuffer[pixel_count] = out_axis_tdata;
                pixel_count = pixel_count + 1;

                if (pixel_count == PIXELS) begin
                    // One bulk write is much faster in Icarus than 921,600
                    // individual binary $fwrite operations.
                    $sformat(frame_path, "sim/runtime/frame_%08d.hex", frame_count);
                    $writememh(frame_path, framebuffer);
                    write_state();
                    frame_count = frame_count + 1;
                    read_io();
                    if (quit_requested || (max_frames > 0 && frame_count >= max_frames)) begin
                        $display("Simulation completed after %0d frame(s).", frame_count);
                        $finish;
                    end
                end
            end
        end
    end
endmodule
