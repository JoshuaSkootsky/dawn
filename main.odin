package main

import "core:fmt"
import "core:os"
import "core:flags"
import odinui "odinui"

Player :: struct {
    name:   string,
    hp:     f32,
    max_hp: f32,
}

Game_State :: struct {
    players: [4]Player,
    selected: int,
}

game := Game_State{
    players = [4]Player{
        {"GingerBill", 100, 100},
        {"Karl",       45,  100},
        {"Demo",       75,  100},
        {"Test",       20,  100},
    },
    selected = 0,
}

CLI_Opts :: struct {
    snapshot: bool `usage:"Save a screenshot to dawn_ui_snapshot.png"`,
    debug:    bool `usage:"Print draw commands to console"`,
}

opts: CLI_Opts

render_name :: proc(player: ^Player, width: f32) {
    odinui.label(player.name)
}

render_hp_bar :: proc(player: ^Player, width: f32) {
    odinui.progress_bar(&player.hp, 0, player.max_hp)
}

ui_proc :: proc() {
    if odinui.begin_container(odinui.hash_ptr(&game), "main") {
        odinui.label("Tournament Standings")
        odinui.ctx.cursor.y += 32 // Manual jump to clear the title zone

        columns := []odinui.Column_Desc(Player){
            {field = nil, width = 150, renderer = render_name, header = "Name"},
            {field = nil, width = 200, renderer = render_hp_bar, header = "HP"},
        }

        odinui.soa_table(Player, game.players[:], columns)

        odinui.end_container()
    }
}

main :: proc() {
    // Parse command line flags
    flags.parse(&opts, os.args)
    
    // Set debug mode if requested (check both -debug and --debug)
    for arg in os.args {
        if arg == "-debug" || arg == "--debug" {
            opts.debug = true
            break
        }
    }
    
    if opts.debug {
        odinui.DEBUG_MODE = true
        fmt.println("=== DEBUG MODE ENABLED ===")
    }
    
    // Run the UI
    if opts.snapshot {
        odinui.run_sokol_with_snapshot(ui_proc, "dawn_ui_snapshot.png")
    } else {
        odinui.run_sokol(ui_proc)
    }
}
