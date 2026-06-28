# Contributing to SeaJson

Thank you for your interest in contributing to SeaJson!

## Development Setup

### Prerequisites

- Cangjie SDK 1.1.0 or later
- stdx standard library

### Install Cangjie SDK

1. Download from [nightly builds](https://gitcode.com/Cangjie/nightly_build/releases)
2. Extract and configure environment:

```bash
export CANGJIE_HOME=/path/to/cangjie
export PATH=$CANGJIE_HOME/bin:$CANGJIE_HOME/tools/bin:$PATH
export CANGJIE_STDX_PATH=/path/to/stdx
export LD_LIBRARY_PATH=$CANGJIE_HOME/runtime/lib/linux_x86_64_cjnative:$LD_LIBRARY_PATH
```

3. Verify installation:

```bash
cjpm --version   # Should show: Cangjie Project Manager: 1.x.x
```

### Build and Test

```bash
# Build the library
cjpm build

# Run tests
cjpm test

# Expected output: current snapshot is 191/191 passed; the exact count may grow as features land
```

## Project Structure

```
seajson/
├── src/
│   ├── seajson.cj           # Package entry, version info
│   ├── native_reader.cj     # JSON parser
│   ├── native_writer.cj     # JSON writer
│   ├── json_value.cj        # DOM representation
│   ├── json_text.cj         # String escaping
│   ├── json_builder.cj      # Simple builders
│   ├── json_decode_error.cj # Error handling
│   ├── json_feature.cj      # Feature flags
│   ├── contract.cj          # Interfaces
│   ├── json_stream_backend.cj # stdx adapter
│   └── tests/               # Unit tests
├── _helper/                 # Internal development docs
├── cjpm.toml
└── README.md
```

## Coding Guidelines

### Code Style

- Follow Cangjie naming conventions
- Use meaningful variable names
- Keep functions focused and small
- Add comments for public APIs

### Design Principles

1. **Backend-neutral**: Public contracts should not expose stdx types
2. **Streaming-first**: Prefer streaming writer over DOM for encoding
3. **RFC 8259 compliant**: Default behavior must be spec-compliant
4. **Detailed errors**: Include path and position in error messages

### Commit Messages

- Use clear, descriptive commit messages
- Reference issues when applicable
- Keep commits atomic and focused

## Testing

- All new features must have tests
- All bug fixes must have regression tests
- Run `cjpm test` before submitting PRs

## Adding New Features

1. Check existing code for similar patterns
2. Add the implementation in the appropriate file
3. Add tests in `src/tests/`
4. Update documentation in code comments
5. Update README.md if API changes

## Reporting Issues

Please include:
- Cangjie SDK version
- Minimal code example
- Expected vs actual behavior
- Error messages (if any)

## License

By contributing, you agree that your contributions will be licensed under the Apache License 2.0.
