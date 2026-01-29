package main

import "core:fmt"

// Re-export odinui types for local use
using odinui

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

ui_proc :: proc() {
    fmt.println("UI Proc Called")
}

window :: proc(title: string, body: proc()) {
    fmt.println("Window:", title)
    body()
}

main :: proc() {
    ui_proc()
    window("Tournament Standings", ui_proc)
}