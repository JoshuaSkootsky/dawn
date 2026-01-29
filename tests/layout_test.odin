package tests

import "core:testing"
import "core:fmt"
import odinui "../odinui"

@(test)
test_ui_layout_projection :: proc(t: ^testing.T) {
    using odinui
    
    // Setup a mock context
    ctx.layout_stack = make([dynamic]Layout_State, 0, 10, context.temp_allocator)
    ctx.cursor = {0, 0}
    draw_commands = make([dynamic]Draw_Command, 0, 100, context.temp_allocator)
    
    // Run a mock UI
    begin_container(1, "test")
    label("Hello")
    label("World")
    end_container()
    
    // Assertions: Verify commands were generated
    testing.expect_value(t, len(draw_commands), 2)
    
    if len(draw_commands) >= 2 {
        first_y := draw_commands[0].bounds.y
        second_y := draw_commands[1].bounds.y
        spacing := second_y - first_y
        
        // Verify spacing is at least 24px (container spacing)
        testing.expect(t, spacing >= 24, 
            fmt.tprintf("Expected spacing >= 24, got %f", spacing))
        
        fmt.printf("✓ Layout test passed: First at Y=%f, Second at Y=%f (spacing: %f)\n", 
            first_y, second_y, spacing)
    }
}

@(test)
test_container_nesting :: proc(t: ^testing.T) {
    using odinui
    
    // Reset state
    ctx.layout_stack = make([dynamic]Layout_State, 0, 10, context.temp_allocator)
    ctx.cursor = {0, 0}
    clear(&draw_commands)
    
    // Test nested containers
    begin_container(1, "outer")
    label("Outer Label")
    
    begin_container(2, "inner")
    label("Inner Label 1")
    label("Inner Label 2")
    end_container()
    
    label("After Inner")
    end_container()
    
    // Should have 4 labels
    testing.expect_value(t, len(draw_commands), 4)
    
    fmt.printf("✓ Nested container test: %d commands generated\n", len(draw_commands))
}
