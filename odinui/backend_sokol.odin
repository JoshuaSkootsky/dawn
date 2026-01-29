package odinui

import sg "../vendor/sokol/sokol/gfx"
import sapp "../vendor/sokol/sokol/app"
import sglue "../vendor/sokol/sokol/glue"
import sdtx "../vendor/sokol/sokol/debugtext"
import "core:fmt"
import "core:strings"
import "core:mem"
import "core:os"
import "base:runtime"

Vertex :: struct {
    pos: [2]f32,
    col: u32, // Now at offset 8, right after position (no uv padding)
}

Sokol_Backend :: struct {
    pass_action: sg.Pass_Action,
    pip:         sg.Pipeline,
    shader:      sg.Shader,
    bind:        sg.Bindings,
    vertices:    [dynamic]Vertex,
    indices:     [dynamic]u16,
}

backend: Sokol_Backend

ui_proc: UI_Proc

_key_state: map[sapp.Keycode]bool

backend_vtable_sokol :: Backend_Vtable {
    init           = sokol_init,
    cleanup        = sokol_cleanup,
    poll_input     = sokol_poll_input,
    should_close   = sokol_should_close,
    render         = sokol_render,
    needs_swap     = sokol_needs_swap,
}

// Vertex attribute indices for shader
ATTR_position :: 0

vs_source := []u8 {
    0x23,0x76,0x65,0x72,0x73,0x69,0x6f,0x6e,0x20,0x34,0x33,0x30,0x0a,0x0a,0x6c,0x61,
    0x79,0x6f,0x75,0x74,0x28,0x6c,0x6f,0x63,0x61,0x74,0x69,0x6f,0x6e,0x20,0x3d,0x20,
    0x30,0x29,0x20,0x69,0x6e,0x20,0x76,0x65,0x63,0x34,0x20,0x70,0x6f,0x73,0x69,0x74,
    0x69,0x6f,0x6e,0x3b,0x0a,0x6c,0x61,0x79,0x6f,0x75,0x74,0x28,0x6c,0x6f,0x63,0x61,
    0x74,0x69,0x6f,0x6e,0x20,0x3d,0x20,0x31,0x29,0x20,0x69,0x6e,0x20,0x76,0x65,0x63,
    0x34,0x20,0x63,0x6f,0x6c,0x6f,0x72,0x30,0x3b,0x0a,0x0a,0x76,0x6f,0x69,0x64,0x20,
    0x6d,0x61,0x69,0x6e,0x28,0x29,0x0a,0x7b,0x0a,0x20,0x20,0x20,0x20,0x67,0x6c,0x5f,
    0x50,0x6f,0x73,0x69,0x74,0x69,0x6f,0x6e,0x20,0x3d,0x20,0x70,0x6f,0x73,0x69,0x74,
    0x69,0x6f,0x6e,0x3b,0x0a,0x20,0x20,0x20,0x20,0x63,0x6f,0x6c,0x6f,0x72,0x20,0x3d,
    0x20,0x63,0x6f,0x6c,0x6f,0x72,0x30,0x3b,0x7d,0x0a,0x0a,0x00,
}

fs_source := []u8 {
    0x23,0x76,0x65,0x72,0x73,0x69,0x6f,0x6e,0x20,0x34,0x33,0x30,0x0a,0x0a,0x6c,0x61,
    0x79,0x6f,0x75,0x74,0x28,0x6c,0x6f,0x63,0x61,0x74,0x69,0x6f,0x6e,0x20,0x3d,0x20,
    0x30,0x29,0x20,0x6f,0x75,0x74,0x20,0x76,0x65,0x63,0x34,0x20,0x66,0x72,0x61,0x67,
    0x5f,0x63,0x6f,0x6c,0x6f,0x72,0x3b,0x0a,0x6c,0x61,0x79,0x6f,0x75,0x74,0x28,0x6c,
    0x6f,0x63,0x61,0x74,0x69,0x6f,0x6e,0x20,0x3d,0x20,0x30,0x29,0x20,0x69,0x6e,0x20,
    0x76,0x65,0x63,0x34,0x20,0x63,0x6f,0x6c,0x6f,0x72,0x3b,0x0a,0x0a,0x76,0x6f,0x69,
    0x64,0x20,0x6d,0x61,0x69,0x6e,0x28,0x29,0x0a,0x7b,0x0a,0x20,0x20,0x20,0x20,0x66,
    0x72,0x61,0x67,0x5f,0x63,0x6f,0x6c,0x6f,0x72,0x20,0x3d,0x20,0x63,0x6f,0x6c,0x6f,
    0x72,0x3b,0x7d,0x0a,0x0a,0x00,
}

ui_shader_desc :: proc(backend_type: sg.Backend) -> sg.Shader_Desc {
    desc: sg.Shader_Desc
    desc.label = "ui_shader"

    #partial switch backend_type {
    case .GLCORE:
        desc.vertex_func.source = transmute(cstring)raw_data(vs_source[:])
        desc.vertex_func.entry = "main"
        desc.fragment_func.source = transmute(cstring)raw_data(fs_source[:])
        desc.fragment_func.entry = "main"
        desc.attrs[0].base_type = .FLOAT
        desc.attrs[0].glsl_name = "position"
        desc.attrs[1].base_type = .FLOAT
        desc.attrs[1].glsl_name = "color0"
    }
    return desc
}

sokol_init :: proc() {
    sg.setup({
        environment = sglue.environment(),
    })

    sdtx.setup({
        fonts = {
            0 = sdtx.font_kc853(),
        },
    })

    backend.shader = sg.make_shader(ui_shader_desc(sg.query_backend()))
    if backend.shader.id == 0 {
        fmt.println("ERROR: Shader compilation failed!")
        return
    }
    fmt.println("Shader compiled successfully!")

    pip_desc: sg.Pipeline_Desc
    pip_desc.shader = backend.shader
    pip_desc.layout.attrs[0].format = .FLOAT2 // Position
    pip_desc.layout.attrs[1].format = .UBYTE4N // Color (matches u32 ABGR format)
    pip_desc.index_type = .UINT16
    pip_desc.cull_mode = .NONE

    backend.pip = sg.make_pipeline(pip_desc)
    if backend.pip.id == 0 {
        fmt.println("ERROR: Pipeline creation failed!")
        return
    }
    fmt.println("Pipeline created successfully!")

    backend.bind.vertex_buffers[0] = sg.make_buffer({
        size = 1000 * size_of(Vertex),
        usage = { vertex_buffer = true, dynamic_update = true },
    })
    backend.bind.index_buffer = sg.make_buffer({
        size = 2000 * size_of(u16),
        usage = { index_buffer = true, dynamic_update = true },
    })
    fmt.println("Buffers created!")

    backend.vertices = make([dynamic]Vertex, 0, 1024)
    backend.indices = make([dynamic]u16, 0, 1024)
}

sokol_cleanup :: proc() {
    sdtx.shutdown()
    sg.destroy_pipeline(backend.pip)
    sg.destroy_shader(backend.shader)
    sg.destroy_buffer(backend.bind.vertex_buffers[0])
    sg.destroy_buffer(backend.bind.index_buffer)
    sg.shutdown()
}

sokol_event_cb :: proc "c" (e: ^sapp.Event) {
    context = runtime.default_context()

    #partial switch e.type {
    case .KEY_DOWN:
        _key_state[e.key_code] = true
    case .KEY_UP:
        _key_state[e.key_code] = false
    case .MOUSE_MOVE:
        ctx.mouse_pos = {e.mouse_x, e.mouse_y}
    }
}

sokol_poll_input :: proc() {
    ctx.keys = {}
    if _key_state[.A] || _key_state[.LEFT] { ctx.keys += {.Left} }
    if _key_state[.D] || _key_state[.RIGHT] { ctx.keys += {.Right} }
    if _key_state[.W] || _key_state[.UP] { ctx.keys += {.Up} }
    if _key_state[.S] || _key_state[.DOWN] { ctx.keys += {.Down} }
    if _key_state[.ENTER] || _key_state[.SPACE] { ctx.keys += {.Enter} }
    if _key_state[.ESCAPE] { ctx.keys += {.Escape} }
}

sokol_should_close :: proc() -> bool {
    return false
}

sokol_needs_swap :: proc() -> bool {
    if ctx.last_draw_epoch == 0 { return true }
    return ctx.dirty_epoch != ctx.last_draw_epoch || ctx.mouse_pos != [2]f32{}
}

sokol_render :: proc(c: ^Context) {
    clear(&backend.vertices)
    clear(&backend.indices)

    ui_proc()

    // Console Mirror: Print draw commands for debugging
    if DEBUG_MODE {
        fmt.println("\n=== DRAW COMMANDS ===")
        fmt.printf("Total commands: %d\n", len(draw_commands))
    }
    
    for cmd, i in draw_commands {
        // Debug output
        if DEBUG_MODE {
            kind_str := "?"
            #partial switch cmd.kind {
            case .Rect:  kind_str = "RECT"
            case .Text:  kind_str = "TEXT"
            }
            fmt.printf("[%2d] %4s | X:%6.1f Y:%6.1f | W:%6.1f H:%6.1f | %s\n", 
                i, kind_str, cmd.bounds.x, cmd.bounds.y, cmd.bounds.z, cmd.bounds.w,
                cmd.text if cmd.kind == .Text else "")
        }
        
        // Render
        if cmd.kind == .Rect {
            color: u32 = (cmd.id % 2 == 0) ? 0xFF3C3C3C : 0xFF333333
            add_rect(cmd.bounds, color)
        } else if cmd.kind == .Text {
            // Canvas scale is 0.5x, debugtext font is 8px per cell
            // Divide by 8.0 to align pixel coordinates with character grid
            sdtx.pos(cmd.bounds.x / 8.0, cmd.bounds.y / 8.0)

            if strings.contains(cmd.text, "Tournament") {
                sdtx.color3b(255, 215, 0)
            } else {
                sdtx.color3b(255, 255, 255)
            }

            text_buf: [256]u8
            for j in 0..<min(len(cmd.text), 255) {
                text_buf[j] = cmd.text[j]
            }
            text_buf[min(len(cmd.text), 255)] = 0
            sdtx.puts(cstring(&text_buf[0]))
        }
    }
    
    if DEBUG_MODE {
        fmt.println("=== END COMMANDS ===\n")
    }
    clear(&draw_commands)

    if len(backend.vertices) > 0 {
        sg.update_buffer(backend.bind.vertex_buffers[0], {
            ptr = &backend.vertices[0],
            size = len(backend.vertices) * size_of(Vertex),
        })
        sg.update_buffer(backend.bind.index_buffer, {
            ptr = &backend.indices[0],
            size = len(backend.indices) * size_of(u16),
        })
    }

    pass: sg.Pass
    pass.action.colors[0].load_action = .CLEAR
    pass.action.colors[0].clear_value = {0.11, 0.11, 0.11, 1.0}
    pass.swapchain = sglue.swapchain()

    sg.begin_pass(pass)
    sg.apply_pipeline(backend.pip)
    sg.apply_bindings(backend.bind)
    sg.draw(0, len(backend.indices), 1)

    sdtx.canvas(f32(sapp.width()) * 0.5, f32(sapp.height()) * 0.5)
    sdtx.origin(4.0, 4.0)
    sdtx.draw()

    sg.end_pass()
    sg.commit()
}

add_rect :: proc(bounds: [4]f32, color: u32) {
    x0, y0, w, h := bounds.x, bounds.y, bounds.z, bounds.w

    base := u16(len(backend.vertices))

    // Dynamic NDC conversion based on actual window dimensions
    scale_x := 2.0 / f32(sapp.width())
    scale_y := 2.0 / f32(sapp.height())

    x0_ndc := x0 * scale_x - 1.0
    y0_ndc := 1.0 - y0 * scale_y
    x1_ndc := (x0 + w) * scale_x - 1.0
    y1_ndc := 1.0 - (y0 + h) * scale_y

    append(&backend.vertices,
        Vertex{pos = {x0_ndc, y0_ndc}, col = color}, // TL
        Vertex{pos = {x1_ndc, y0_ndc}, col = color}, // TR
        Vertex{pos = {x1_ndc, y1_ndc}, col = color}, // BR
        Vertex{pos = {x0_ndc, y1_ndc}, col = color}, // BL
    )

    append(&backend.indices,
        base + 0, base + 1, base + 2,
        base + 0, base + 2, base + 3,
    )
}

run_sokol :: proc(ui: UI_Proc) {
    ui_proc = ui

    sapp.run({
        init_cb = proc "c" () {
            context = runtime.default_context()
            sokol_init()
        },
        frame_cb = proc "c" () {
            context = runtime.default_context()
            sokol_poll_input()
            ctx.last_draw_epoch = ctx.dirty_epoch
            if sokol_needs_swap() {
                sokol_render(&ctx)
            }
        },
        cleanup_cb = proc "c" () {
            context = runtime.default_context()
            sokol_cleanup()
        },
        event_cb = sokol_event_cb,
        width = 800,
        height = 600,
        window_title = "Dawn UI",
    })
}

// run_sokol_with_snapshot renders one frame and saves it to a PNG file
run_sokol_with_snapshot :: proc(ui: UI_Proc, filename: string) {
    ui_proc = ui
    snapshot_filename = filename
    take_snapshot = true
    
    sapp.run({
        init_cb = proc "c" () {
            context = runtime.default_context()
            sokol_init()
        },
        frame_cb = proc "c" () {
            context = runtime.default_context()
            sokol_poll_input()
            ctx.last_draw_epoch = ctx.dirty_epoch
            sokol_render(&ctx)
            
            // After rendering, save snapshot and exit
            if take_snapshot {
                save_snapshot()
                take_snapshot = false
                sapp.request_quit()
            }
        },
        cleanup_cb = proc "c" () {
            context = runtime.default_context()
            sokol_cleanup()
        },
        width = 800,
        height = 600,
        window_title = "Dawn UI - Snapshot",
    })
}

snapshot_filename: string
take_snapshot: bool = false

save_snapshot :: proc() {
    width := sapp.width()
    height := sapp.height()
    
    // Allocate buffer for RGBA pixels
    buffer_size := width * height * 4
    pixels := make([]u8, buffer_size)
    defer delete(pixels)
    
    // Read pixels from default framebuffer
    // Note: This requires backend-specific implementation
    // For now, we'll write a placeholder PPM format file
    
    fmt.printf("Saving snapshot to %s (%dx%d)\n", snapshot_filename, width, height)
    
    // Write simple PPM header (portable pixmap)
    ppm_filename := strings.concatenate([]string{snapshot_filename, ".ppm"})
    fd, err := os.open(ppm_filename, os.O_WRONLY | os.O_CREATE | os.O_TRUNC)
    if err != 0 {
        fmt.printf("Failed to open %s for writing\n", ppm_filename)
        return
    }
    defer os.close(fd)
    
    // Write PPM header
    header := fmt.tprintf("P6\n%d %d\n255\n", width, height)
    os.write(fd, transmute([]u8)header)
    
    // Write placeholder gradient (since we can't read GPU framebuffer easily)
    for y in 0..<height {
        for x in 0..<width {
            r := u8(100 + (x * 50) / width)
            g := u8(100 + (y * 50) / height)
            b := u8(150)
            os.write(fd, []u8{r, g, b})
        }
    }
    
    fmt.printf("Snapshot saved to %s\n", ppm_filename)
    fmt.println("Note: Full GPU framebuffer reading requires backend-specific implementation")
}
