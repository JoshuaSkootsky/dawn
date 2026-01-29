

# Data-Oriented Widget Null-architecture

## Data-Native UI in Odin

A UI framework that only recalculates when changes, not on every frame.

## Quick Start

### Requirements

1. **Odin Compiler** - Install from https://odin-lang.org
2. **Sokol Bindings** - Clone as git submodule

### Setup

```bash
git clone <your-repo-url>
cd dawn
git submodule update --init --recursive

# Build Sokol C libraries
cd vendor/sokol/sokol
./build_clibs_linux.sh
cd ../../..
```

Or manually:
```bash
git clone https://github.com/floooh/sokol-odin.git vendor/sokol
cd vendor/sokol/sokol
./build_clibs_linux.sh
cd ../..
```

### Run the Demo

```bash
odin run main.odin -file -collection:sokol=vendor/sokol/sokol -strict-style
```

## Testing Infrastructure

This project includes a comprehensive three-tier testing system that allows you to verify UI behavior without needing a GPU or display.

### 1. Unit Tests (Headless - No GPU Required)

Test layout logic, spacing calculations, and command generation without any graphics dependencies.

```bash
# Run all unit tests
odin test tests/ -collection:sokol=vendor/sokol

# Run with verbose output
odin test tests/ -collection:sokol=vendor/sokol -v
```

**What's Tested:**
- Layout spacing calculations (ensures 24px gaps between elements)
- Container nesting behavior
- Draw command generation
- Coordinate math verification

**Example Test Output:**
```
✓ Layout test passed: First at Y=0.000, Second at Y=24.000 (spacing: 24.000)
✓ Nested container test: 4 commands generated
```

**Why It's Useful:**
- CI/CD friendly - runs on headless servers
- Fast feedback loop (< 1ms per test)
- Catches coordinate math bugs before visual testing
- Validates data-to-command pipeline

### 2. Console Mirror (Live Debug Output)

Run the UI with real-time command logging to see exactly what's being rendered.

```bash
# Run with debug output
./dawn_ui -debug

# Or
./dawn_ui --debug
```

**Output Format:**
```
=== DRAW COMMANDS ===
Total commands: 7
[00] TEXT | X:   0.0 Y:   0.0 | W: 300.0 H:  20.0 | Tournament Standings
[01] TEXT | X:   0.0 Y:   0.0 | W: 300.0 H:  20.0 | Name
[02] TEXT | X:   0.0 Y:  44.0 | W: 300.0 H:  20.0 | HP
...
=== END COMMANDS ===
```

**Why It's Useful:**
- See exact X/Y coordinates for every element
- Detect overlaps immediately (two items with same Y)
- Verify rectangle commands are generated
- Debug layout issues without screenshots
- Works with the actual GPU renderer

### 3. Snapshot Testing (Golden Master)

Capture the rendered output for visual regression testing.

```bash
# Save a snapshot
./dawn_ui --snapshot

# Output saved to: dawn_ui_snapshot.png.ppm
```

**How It Works:**
- Renders one frame
- Saves pixel data to PPM format (portable pixmap)
- Can be converted to PNG or compared directly
- Useful for catching visual regressions

**Why It's Useful:**
- Automated visual regression testing
- Compare against "golden" reference images
- Detect rendering artifacts
- CI/CD integration for UI consistency

### 4. Traditional Terminal Tests (No GPU)

Simple console-based tests for core logic.

```bash
odin run test_slider.odin -file -strict-style
odin run test_soa.odin -file -strict-style
```

### 5. GPU Integration Tests (Require Display)

Full rendering tests that require a display.

```bash
odin run test_display.odin -file -collection:sokol=vendor/sokol/sokol -strict-style
```

## Test-Driven UI Development Workflow

1. **Write Unit Test First** - Define expected layout behavior in `tests/layout_test.odin`
2. **Run Headless** - `odin test tests/` to verify coordinate math
3. **Console Mirror** - `./dawn_ui -debug` to see live command output
4. **Visual Verify** - Run actual UI to confirm rendering
5. **Snapshot** - `./dawn_ui --snapshot` to save reference image

This approach catches layout bugs at the data level before they become visual glitches.

## Key Concept

Data-Native UI uses dirty epoch tracking to skip rendering when data hasn't changed, dramatically reducing CPU/GPU usage.

## Test Files

- `tests/layout_test.odin` - Unit tests for layout spacing and command generation
- `main.odin` - Supports `-debug` and `--snapshot` flags for testing
- `test_*.odin` - Traditional test harnesses

## Quick Test Reference

```bash
# 1. Unit tests (fastest, no GPU)
odin test tests/ -collection:sokol=vendor/sokol

# 2. Console mirror (see live commands)
./dawn_ui -debug

# 3. Snapshot capture (visual regression)
./dawn_ui --snapshot

# 4. Full run (visual verification)
./dawn_ui
```

## Debugging UI Issues

When you see "Mamenament Standings" (overlapping text) or missing rectangles:

1. **Run with debug flag**: `./dawn_ui -debug`
2. **Check console output**: Look for duplicate Y coordinates
3. **Verify command types**: Should see both TEXT and RECT commands
4. **Fix in unit test**: Add regression test to `tests/layout_test.odin`
5. **Verify fix**: Run unit tests + debug mode again

## Files

- `odinui/` - Core UI framework
- `main.odin` - Demo application
- `test_*.odin` - Test harnesses
- `vendor/sokol/` - Sokol bindings
