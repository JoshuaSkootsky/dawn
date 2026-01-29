# Contributing

## Development Workflow

### Prerequisites

- Odin compiler installed
- Git and Git LFS (for vendor/sokol)
- WSL display forwarding for GPU testing (optional)

### Running Tests

```bash
# Test all core functionality
odin run test_slider.odin -file -strict-style
odin run test_soa.odin -file -strict-style
odin run test_widgets.odin -file -strict-style

# Verify display setup (after WSL fixes)
odin run test_display.odin -file -collection:sokol=vendor/sokol -strict-style
```

### Code Style

- Use `-strict-style` flag when building
- Follow Odin naming conventions
- Include documentation for new widgets
- Run tests before committing

### Adding New Widgets

1. Implement widget in `odinui.odin`
2. Add test case to `test_widgets.odin`
3. Update `WIDGETS.md` with documentation
4. Verify 84% skip rate in tests

### Adding New Backends

1. Create `backend_<name>.odin`
2. Implement `Backend_Vtable` functions
3. Add to `backend_vtable_<name>` export
4. Update `WORKFLOW.md` with integration steps

### Repository Structure

```
dawn/
├── odinui.odin           # Core library (editable)
├── backend_sokol.odin    # GPU backend (editable)
├── main.odin              # Demo app (editable)
├── test_*.odin           # Test harnesses (preserve)
├── vendor/sokol/         # Submodule (DO NOT EDIT)
├── .gitignore            # Git ignore rules (editable)
└── docs/
    ├── README.md         # Start here
    ├── WIDGETS.md        # Widget documentation
    ├── WORKFLOW.md       # Migration guide
    └── CHECKPOINT.md     # Development history
```

### Submitting Changes

1. Fork the repository
2. Create feature branch
3. Add tests for new features
4. Run full test suite
5. Update documentation
6. Submit pull request

### License

This project is licensed under the Zlib License - see LICENSE file for details.