package main

import "base:intrinsics"
import "core:fmt"
import "core:time"

// ============================================================================
// STRIPPED-DOWN UI CORE (No Graphics, Just Logic)
// ============================================================================

Context :: struct {
    dirty_epoch:   u64,
    last_draw_epoch: u64,
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

slider :: proc(value: ^f32, min, max: f32, id: u64 = 0, delta: f32 = 0) -> bool {
    if delta != 0 {
        old_val := value^
        value^ += delta
        new_val := clamp(value^, min, max)
        value^ = new_val
        if old_val != new_val { 
            mark_dirty(value, size_of(f32))
            return true
        }
    }
    return false
}

Player :: struct {
    hp: f32,
    max_hp: f32,
}

game_state :: struct {
    player: Player,
}

main :: proc() {
    state := game_state{
        player = {
            hp = 50,
            max_hp = 100,
        },
    }
    
    fmt.println("=== Odin UI Logic Test - Data-Native Projection ===")
    fmt.println()
    fmt.println("This simulates slider input changes and shows:")
    fmt.println("1. When health changes, the 'dirty' epoch increments")
    fmt.println("2. When unchanged, we SKIP GPU projection (optimization!)")
    fmt.println()
    
    frame_count := 0
    
    // Simulate user pressing 'D' key 10 times (increase health by +5 each time)
    fmt.println("--- Simulating 10 key presses to INCREASE health ---")
    for i in 1..=10 {
        frame_count += 1
        
        old_hp := state.player.hp
        changed := slider(&state.player.hp, 0, 100, 0, 5)
        
        fmt.printf("Frame %2d: %.1f -> %.1f | ", frame_count, old_hp, state.player.hp)
        
        if changed {
            fmt.printf("[RENDER] Epoch %2d ✓\n", ctx.dirty_epoch)
        } else {
            fmt.println("[SKIP] No change")
        }
        
        time.sleep(50 * time.Millisecond)
    }
    
    fmt.println()
    fmt.println("--- Now health is stable - show SKIP optimization ---")
    fmt.println()
    fmt.println("Watch how we SKIP rendering when values don't change:")
    
    // Simulate 5 frames with no changes
    for i in 1..=5 {
        frame_count += 1
        changed := slider(&state.player.hp, 0, 100)

        fmt.printf("Frame %2d: Health %.1f | ", frame_count, state.player.hp)
        
        if changed {
            fmt.printf("[RENDER] Epoch %2d ✓\n", ctx.dirty_epoch)
        } else {
            fmt.println("[SKIP] No change (optimization!)")
        }
        
        time.sleep(100 * time.Millisecond)
    }
    
    fmt.println()
    fmt.println("--- Simulating 5 key presses to DECREASE health ---")
    fmt.println()
    
    for i in 1..=5 {
        frame_count += 1
        
        old_hp := state.player.hp
        changed := slider(&state.player.hp, 0, 100, 0, -5)

        fmt.printf("Frame %2d: %.1f -> %.1f | ", frame_count, old_hp, state.player.hp)
        
        if changed {
            fmt.printf("[RENDER] Epoch %2d ✓\n", ctx.dirty_epoch)
        } else {
            fmt.println("[SKIP] No change")
        }
        
        time.sleep(50 * time.Millisecond)
    }
    
    fmt.println()
    fmt.println("--- Summary ---")
    fmt.printf("Final health: %.1f / %.1f\n", state.player.hp, state.player.max_hp)
    fmt.printf("Total frames: %d\n", frame_count)
    fmt.printf("Dirty epoch: %d (how many times we needed to re-render)\n", ctx.dirty_epoch)
    fmt.println()
    fmt.println("Key Insight: The Data-Native UI only recalculates/projecs")
    fmt.println("            when the DATA changes. This is the optimization!")
}