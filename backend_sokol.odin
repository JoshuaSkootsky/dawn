package odinui

import sg "sokol:gfx"
import sapp "sokol:app"
import "core:mem"
import "core:math/linalg"

Sokol_Backend :: struct {
    pass_action: sg.Pass_Action,
    pip:         sg.Pipeline,
    bind:        sg.Bindings,
    vertices:    []Vertex,
    indices:     []u16,
}

backend: Sokol_Backend

Vertex :: struct {
    pos: [2]f32,
    uv:  [2]f32,
    col: u32,
}

backend_vtable_sokol :: Backend_Vtable {
    init                  = sokol_init,
    cleanup               = sokol_cleanup,
    poll_input            = sokol_poll_input,
    should_close          = sokol_should_close,
    render                = sokol_render,
    submit_semantic_buffer = sokol_submit_semantic,
    needs_swap            = sokol_needs_swap,
}

sokol_init :: proc() {
    backend.pip = sg.make_pipeline(sg.Pipeline_Desc{})
    backend.bind = sg.Bindings{}
    backend.pass_action = sg.Pass_Action{
        colors = {sg.Color_Attachment_Action{load_action = .CLEAR, clear_value = {0.1, 0.1, 0.1, 1.0}}},
    }
}

sokol_cleanup :: proc() {
    sg.destroy_pipeline(backend.pip)
    sg.shutdown()
}

sokol_poll_input :: proc() {
    ctx.mouse_pos = [2]f32{f32(sapp.mouse_x()), f32(sapp.mouse_y())}
    
    ctx.keys = {}
    if sapp.key_down(.LEFT)  || sapp.key_down(.A) { ctx.keys += {.Left} }
    if sapp.key_down(.RIGHT) || sapp.key_down(.D) { ctx.keys += {.Right} }
    if sapp.key_down(.UP)    || sapp.key_down(.W) { ctx.keys += {.Up} }
    if sapp.key_down(.DOWN)  || sapp.key_down(.S) { ctx.keys += {.Down} }
    if sapp.key_down(.ENTER) || sapp.key_down(.SPACE) { ctx.keys += {.Enter} }
    if sapp.key_down(.ESCAPE) { ctx.keys += {.Escape} }
}

sokol_should_close :: proc() -> bool {
    return sapp.should_close()
}

sokol_needs_swap :: proc() -> bool {
    return ctx.dirty_epoch != ctx.last_draw_epoch || ctx.mouse_pos != [2]f32{}
}

to_ndc :: proc(pos, size: [2]f32) -> [4]f32 {
    x0 := pos.x / f32(sapp.width())
    y0 := pos.y / f32(sapp.height())
    x1 := (pos.x + size.x) / f32(sapp.width())
    y1 := (pos.y + size.y) / f32(sapp.height())
    return {x0, 1.0 - y1, x1, 1.0 - y0}
}

push_rect :: proc(pos, size: [2]f32, color: u32) {
    ndc := to_ndc(pos, size)
    
    v0 := Vertex{pos = {ndc.x, ndc.y}, uv = {0, 0}, col = color}
    v1 := Vertex{pos = {ndc.z, ndc.y}, uv = {1, 0}, col = color}
    v2 := Vertex{pos = {ndc.z, ndc.w}, uv = {1, 1}, col = color}
    v3 := Vertex{pos = {ndc.x, ndc.w}, uv = {0, 1}, col = color}
    
    base := u16(len(backend.vertices))
    append(&backend.vertices, v0, v1, v2, v3)
    append(&backend.indices, base+0, base+1, base+2, base+0, base+2, base+3)
}

push_draw_command :: proc(kind: enum {Button, SliderFill, SliderTrack, ProgressBar}, id: Id, bounds: [4]f32, data: rawptr = nil) {
    if ctx.dirty_epoch == ctx.last_draw_epoch && kind != .SliderFill {
        return
    }
    
    pos := [2]f32{bounds.x, bounds.y}
    size := [2]f32{bounds.z, bounds.w}
    
    switch kind {
    case .Button:
        push_rect(pos, size, 0xFF4A90E2)
        
    case .SliderTrack:
        push_rect(pos, size, 0xFF333333)
        
    case .SliderFill:
        push_rect(pos, size, 0xFF00FF00)
        
    case .ProgressBar:
        ptr := (^f32)(data)
        if ptr != nil {
            size.x *= ptr^
        }
        push_rect(pos, size, 0xFFFF0000)
    }
}

sokol_render :: proc(ctx: ^Context) {
    backend.vertices = backend.vertices[:0]
    backend.indices = backend.indices[:0]
    
    ui_proc()
    
    if len(backend.vertices) > 0 {
        sg.begin_pass(backend.pass_action)
        sg.draw(0, len(backend.indices), 1)
        sg.end_pass()
        sg.commit()
    }
}

sokol_submit_semantic :: proc(nodes: []Semantic_Node) {
    fmt.println("Accessibility nodes:", len(nodes))
}

ui_proc: UI_Proc

frame :: proc() {
    sokol_poll_input()
    ctx.last_draw_epoch = ctx.dirty_epoch
    
    if sokol_needs_swap() {
        sokol_render(&ctx)
    }
}

run_sokol :: proc(ui: UI_Proc) {
    ui_proc = ui
    sapp.run(sapp.Desc{
        init_cb = proc() {},
        frame_cb = frame,
        cleanup_cb = sokol_cleanup,
        width = 800,
        height = 600,
        window_title = "Odin UI - Data-Native",
    })
}