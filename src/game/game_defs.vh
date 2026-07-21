`define GAME_X0 10'd64
`define UI_TOP 10'd416
// The foreground grass begins at source row 32 of the 80x50 background tile:
// 16 + 32 * 8 = screen Y 272.  Sprite Y coordinates refer to their top edge.
`define GROUND_Y 10'd272
`define OBJ_W 10'd32
`define OBJ_H 10'd32
`define PLAYER_W 10'd64
`define PLAYER_H 10'd64
`define PLAYER_Y (`GROUND_Y - `PLAYER_H)
`define PLAYER_GROUND_Y (`GROUND_Y - `PLAYER_H)
