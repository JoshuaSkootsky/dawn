package odinui

import "base:intrinsics"
import "core:fmt"
import "core:mem"
import "core:strings"

// ============================================================================
// CORE TYPES
// ============================================================================

Id :: distinct u64

Key :: enum {Left, Right, Up, Down, Enter, Escape}

Context :: struct {
    dirty_epoch:     u64,
    last_draw_epoch: u64,
    keys:            bit_set[Key],
    mouse_pos:       [2]f32,
    current_focus:   Id,
    active_id:       Id,
    cursor:          [2]f32,
    layout_stack:    [dynamic]Layout_State,
    frame_allocator: mem.Allocator,
    backend:         Backend_Vtable,
}

ctx: Context

// DEBUG_MODE enables console output of draw commands
DEBUG_MODE: bool = false

Backend_Vtable :: struct {
    init:                proc(),
    cleanup:             proc(),
    poll_input:          proc(),
    should_close:        proc() -> bool,
    render:              proc(^Context),
    needs_swap:          proc() -> bool,
}

UI_Proc :: proc()

// ============================================================================
// DIRTY TRACKING
// ============================================================================

mark_dirty :: proc(ptr: rawptr, size: int) {
    ctx.dirty_epoch += 1
}

// ============================================================================
// LAYOUT SYSTEM
// ============================================================================

Layout_State :: struct {
    pos:       [2]f32,
    direction: enum {Vertical, Horizontal},
    spacing:   f32,
    next_pos:  [2]f32,
}

begin_container :: proc(id: Id, type: string) -> bool {
    append(&ctx.layout_stack, Layout_State{
        pos       = ctx.cursor,
        direction = .Vertical,
        spacing   = 24, // Enough room for 16px tall text + 8px gap
    })
    return true
}

end_container :: proc() {
    if len(ctx.layout_stack) > 0 {
        pop(&ctx.layout_stack)
    }
}

layout_allocate :: proc(w, h: f32) -> [4]f32 {
    if len(ctx.layout_stack) == 0 {
        return {0, 0, w, h}
    }
    
    layout := &ctx.layout_stack[len(ctx.layout_stack)-1]
    bounds := [4]f32{layout.next_pos.x, layout.next_pos.y, w, h}
    
    layout.next_pos.y += h + layout.spacing
    return bounds
}

// ============================================================================
// DRAW COMMAND BUFFER
// ============================================================================

Draw_Kind :: enum {None, Rect, Text}

Draw_Command :: struct {
    kind:   Draw_Kind,
    id:     Id,
    bounds: [4]f32,
    text:   string,
}

draw_commands: [dynamic]Draw_Command

push_draw_command :: proc(kind: Draw_Kind, id: Id, bounds: [4]f32, text: string = "") {
    append(&draw_commands, Draw_Command{kind = kind, id = id, bounds = bounds, text = text})
}

// ============================================================================
// WIDGETS
// ============================================================================

button :: proc(label: string, id: Id = 0) -> bool {
    uid := id != 0 ? id : hash_str(label)
    bounds := layout_allocate(120, 32)
    hovered := hit_test(bounds)
    clicked := hovered && .Enter in ctx.keys
    
    if ctx.dirty_epoch != ctx.last_draw_epoch || hovered {
        push_draw_command(.Rect, uid, bounds)
    }
    
    return clicked
}

slider :: proc(value: ^$T, min, max: T, label := "", id: Id = 0) -> bool where intrinsics.type_is_numeric(T) {
    uid := id != 0 ? id : hash_ptr(value)
    changed := false
    
    if .Left in ctx.keys {
        delta: T = (max - min) * T(0.05)
        value^ -= delta
        changed = true
    }
    if .Right in ctx.keys {
        delta: T = (max - min) * T(0.05)
        value^ += delta
        changed = true
    }
    
    old_val := value^
    value^ = clamp(value^, min, max)
    if old_val != value^ { changed = true }
    
    if changed {
        mark_dirty(value, size_of(T))
    }
    
    bounds := layout_allocate(250, 28)
    if ctx.dirty_epoch != ctx.last_draw_epoch {
        push_draw_command(.Rect, uid, bounds)
        fill := bounds
        fill.z *= f32(value^ - min) / f32(max - min)
        push_draw_command(.Rect, uid + 1, fill)
    }
    
    return changed
}

progress_bar :: proc(value: ^f32, min, max: f32) {
    uid := hash_ptr(value)
    bounds := layout_allocate(150, 16)
    
    if ctx.dirty_epoch != ctx.last_draw_epoch {
        push_draw_command(.Rect, uid, bounds)
    }
}

// ============================================================================
// SOA TABLE
// ============================================================================

Column_Desc :: struct($T: typeid) {
    field:    ^T,
    width:    f32,
    renderer: proc(^T, f32),
    header:   string,
}

soa_table :: proc($T: typeid, data: []T, columns: []Column_Desc(T)) {
    id := hash_ptr(raw_data(data))

    if begin_container(id, "table") {
        for col in columns {
            label(col.header)
        }

        // Add spacing after header row to prevent overlap with data
        if len(ctx.layout_stack) > 0 {
            ctx.layout_stack[len(ctx.layout_stack)-1].next_pos.y += 12
        }

        for &item, i in data {
            for col in columns {
                field_ptr := rawptr(uintptr(&item) + uintptr(col.field))
                if col.renderer != nil {
                    col.renderer((^T)(field_ptr), col.width)
                }
            }
        }

        end_container()
    }
}

raw_data :: proc(slice: []$T) -> rawptr {
    return rawptr(uintptr(&slice[0]))
}

// ============================================================================
// UTILITIES
// ============================================================================

hit_test :: proc(bounds: [4]f32) -> bool {
    return ctx.mouse_pos.x >= bounds.x && ctx.mouse_pos.x <= bounds.x + bounds.z &&
           ctx.mouse_pos.y >= bounds.y && ctx.mouse_pos.y <= bounds.y + bounds.w
}

clamp :: proc(v, lo, hi: $T) -> T {
    return lo if v < lo else (hi if v > hi else v)
}

label :: proc(text: string) {
    bounds := layout_allocate(300, 20)
    push_draw_command(.Text, hash_str(text), bounds, text)
}

run :: proc(ui: UI_Proc) {
    ctx.backend.init()
    defer ctx.backend.cleanup()

    for !ctx.backend.should_close() {
        ctx.backend.poll_input()

        ctx.last_draw_epoch = ctx.dirty_epoch

        if ctx.backend.needs_swap() {
            ui()
            ctx.backend.render(&ctx)
        }
    }
}

hash_ptr :: proc(p: rawptr) -> Id {
    return Id(uintptr(p))
}

hash_str :: proc(s: string) -> Id {
    h: u64 = 0
    for c in s {
        h = h * 31 + u64(c)
    }
    return Id(h)
}

// Snapshot function is implemented in backend_sokol.odin