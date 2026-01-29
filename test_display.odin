package main

import sapp "sokol:app"
import sg "sokol:gfx"
import sgglue "sokol:glue"
import slog "sokol:log"

pass_action: sg.Pass_Action

init :: proc "c" () {
    sg.setup({
        environment = sgglue.environment(),
        logger = { func = slog.func },
    })
    pass_action.colors[0] = { load_action = .CLEAR, clear_value = {0.3, 0.5, 0.7, 1.0}}
}

test_frame :: proc "c" () {
    sg.begin_pass({ action = pass_action, swapchain = sgglue.swapchain() })
    sg.end_pass()
    sg.commit()
}

cleanup :: proc "c" () {
    sg.shutdown()
}

main :: proc() {
    sapp.run({
        init_cb = init,
        frame_cb = test_frame,
        cleanup_cb = cleanup,
        width = 400,
        height = 300,
        window_title = "WSLg Test",
    })
}