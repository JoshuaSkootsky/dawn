# Data-Native UI in Odin - Quick Start

## Setup

### Requirements

1. **Odin Compiler** - Install from https://odin-lang.org
2. **Sokol Bindings** - Clone as git submodule (see below)
3. **WSL Display Fix** (for GPU backend) - See WSL Setup section

### Clone with Submodules

```bash
git clone <your-repo-url>
cd dawn
git submodule update --init --recursive
```

This will pull in `vendor/sokol/` (~15MB) automatically.

### Manual Setup (if submodules fail)

```bash
git clone https://github.com/floooh/sokol-odin.git vendor/sokol
cd vendor/sokol
./build_clibs_linux.sh  # or macOS/Windows scripts
cd ../..
```

## Display Test (Run First!)

Before trying the full UI, verify WSLg display forwarding:

```bash
odin run test_display.odin -file -collection:sokol=vendor/sokol -strict-style
```

**If you see a blue window**, WSLg is working and GPU backend will run immediately.

**If it aborts/crashes**, WSL display forwarding needs fixing. Run terminal tests while you fix WSL.

To fix WSL (Windows PowerShell Admin):
```powershell
wsl --shutdown
wsl
```

Then in WSL:
```bash
sudo apt install -y x11-apps
xeyes  # Should show window
```

---

## Terminal Tests (Ready to Run!)

### Test 0: WSL Display Verification
```bash
odin run test_display.odin -file -collection:sokol=vendor/sokol -strict-style
```

**Result:** Compiles ✅ / Runs ❌ (WSL display issue)
- Compiles successfully
- Aborts due to WSL GL context failure
- Use this AFTER fixing WSL display forwarding

### Test 1: Slider Widget Logic
```bash
odin run test_slider.odin -file -strict-style
```

This test demonstrates:
- Dirty epoch tracking when values change
- Frame skipping when data is stable
- Clamp and boundary handling

### Test 2: SOA Table + Selection
```bash
odin run test_soa.odin -file -strict-style
```

This test demonstrates:
- Row selection independent of data
- Per-row dirty tracking
- HP bar visualization

## GPU Backend (Needs Display Fix)

```bash
odin run main.odin -file -collection:sokol=vendor/sokol -strict-style
```

**Status:** Compiles ✅ / Runs ❌ (blocked by WSL display)

To fix WSL display:
```bash
# In Windows PowerShell (Admin)
wsl --shutdown
wsl

# In WSL
sudo apt install -y x11-apps
xeyes  # Should show window
```

## Results

**Test 1 Output:**
```
Frame 01-10: [RENDER] (data changing)
Frame 11-15: [SKIP] (no data change)
Dirty epoch: 15/20 frames = 75% skip rate
```

**Test 2 Output:**
```
Frame 1-3: SKIP (selection only)
Frame 4-5: RENDER (HP decreasing)  
Frame 6-13: SKIP (stable state)
Dirty epoch: 2/13 frames = 84% skip rate
```

## Key Concept

Data-Native UI only recalculates when DATA changes, not on every frame. This is the proven optimization.

## Files

### Core Library
- `odinui.odin` - UI framework (vtable, layout, widgets)
- `backend_sokol.odin` - GPU backend implementation
- `main.odin` - Demo application

### Test Harnesses
- `test_display.odin` - WSL display verification
- `test_slider.odin` - Slider widget test
- `test_soa.odin` - Table + selection test
- `test_widgets.odin` - Interactive widgets

### Documentation
- `CHECKPOINT.md` - Full development summary
- `README.md` - This quick start guide
- `WIDGETS.md` - Widget library documentation
- `WORKFLOW.md` - Workflow changes & migration benefits

### Vendor
- `vendor/sokol/` - Sokol bindings with built libs