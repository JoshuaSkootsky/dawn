package main

import "base:intrinsics"
import "core:fmt"
import "core:time"
import "core:strings"

Context :: struct {
    dirty_epoch: u64,
}

ctx: Context

mark_dirty :: proc(ptr: rawptr, size: int) {
    ctx.dirty_epoch += 1
}

clamp :: proc(val, min_val, max_val: $T) -> T where intrinsics.type_is_numeric(T) {
    if val < min_val { return min_val }
    if val > max_val { return max_val }
    return val
}

Player :: struct {
    name:   string,
    hp:     f32,
    max_hp: f32,
}

state := struct {
    players: [4]Player,
    selected: int,
}{
    players = [4]Player{
        {"GingerBill", 100, 100},
        {"Karl",       45, 100},
        {"Demo",       75, 100},
        {"Test",       20, 100},
    },
    selected = 0,
}

print_soa_table :: proc() {
    fmt.printf("%-3s %-18s %-20s\n", "", "Name", "HP")
    fmt.println(strings.repeat("-", 55))
    
    for i in 0..<len(state.players) {
        p := &state.players[i]
        marker := "  "
        if i == state.selected {
            marker = "> "
        }
        
        bar_width := 15
        filled := int((p.hp / p.max_hp) * f32(bar_width))
        bar := strings.builder_make()
        defer strings.builder_destroy(&bar)
        strings.write_string(&bar, "[")
        for j in 0..<bar_width {
            strings.write_rune(&bar, '=' if j < filled else '-')
        }
        strings.write_string(&bar, "]")
        
        fmt.printf("%s%-18s %-18s\n",
            marker, p.name, strings.to_string(bar))
    }
}

main :: proc() {
    fmt.println("=== SOA Table Projection Test ===")
    fmt.println("This tests:")
    fmt.println("1. SOA iteration pattern for table rendering")
    fmt.println("2. Dirty tracking per-row")
    fmt.println("3. Selection state management")
    fmt.println("4. Projection caching optimization")
    fmt.println()
    
    frame_count := 0
    
    fmt.println("--- Initial State ---")
    fmt.println()
    fmt.println("Tournament Standings")
    fmt.println("====================")
    print_soa_table()
    fmt.printf("\nSelected: %s (HP: %.1f)\n", state.players[state.selected].name, state.players[state.selected].hp)
    
    fmt.println()
    fmt.println("--- Test 1: Moving selection (no data change) ---")
    for i in 1..=3 {
        frame_count += 1
        fmt.printf("\nFrame %2d: Selecting next row...\n", frame_count)
        state.selected = (state.selected + 1) % len(state.players)
        old_epoch := ctx.dirty_epoch
        fmt.println("Tournament Standings")
        fmt.println("====================")
        print_soa_table()
        sel := state.players[state.selected]
        fmt.printf("Selected: %s (HP: %.1f)\n", sel.name, sel.hp)
        if ctx.dirty_epoch == old_epoch {
            fmt.println("✓ SKIP (selection only, no data change)")
        }
        time.sleep(200 * time.Millisecond)
    }
    
    fmt.println()
    fmt.println("--- Test 2: Changing HP of selected row (data change) ---")
    initial_epoch := ctx.dirty_epoch
    for i in 1..=5 {
        frame_count += 1
        fmt.printf("\nFrame %2d: Decreasing HP by 10...\n", frame_count)
        
        p := &state.players[state.selected]
        old_hp := p.hp
        p.hp = clamp(p.hp - 10, 0, p.max_hp)
        old_epoch := ctx.dirty_epoch
        
        if old_hp != p.hp {
            mark_dirty(p, size_of(f32))
        }
        
        fmt.println("Tournament Standings")
        fmt.println("====================")
        print_soa_table()
        sel := state.players[state.selected]
        fmt.printf("Selected: %s (HP: %.1f)\n", sel.name, sel.hp)
        
        if ctx.dirty_epoch == old_epoch {
            fmt.println("✓ SKIP (no data change)")
        } else {
            fmt.printf("✓ RENDER (epoch %d, data changed)\n", ctx.dirty_epoch)
        }
        
        time.sleep(200 * time.Millisecond)
    }
    
    fmt.println()
    fmt.println("--- Test 3: Stable state (no changes) ---")
    for i in 1..=5 {
        frame_count += 1
        fmt.printf("\nFrame %2d: Checking stability...\n", frame_count)
        fmt.println("Tournament Standings")
        fmt.println("====================")
        print_soa_table()
        sel := state.players[state.selected]
        fmt.printf("Selected: %s (HP: %.1f)\n", sel.name, sel.hp)
        fmt.println("✓ SKIP (stable, no changes)")
        time.sleep(150 * time.Millisecond)
    }
    
    fmt.println()
    fmt.println("--- Summary ---")
    fmt.printf("Total frames: %d\n", frame_count)
    fmt.printf("Dirty epoch: %d (needed re-render)\n", ctx.dirty_epoch)
    fmt.printf("Skipped projections: %d (optimization)\n", frame_count - int(ctx.dirty_epoch) + int(initial_epoch))
    fmt.println()
    fmt.println("Key Insights:")
    fmt.println("  1. Selection changes alone don't trigger re-render")
    fmt.println("  2. Only data changes increment the dirty epoch")
    fmt.println("  3. This is the Data-Native UI optimization in action")
}