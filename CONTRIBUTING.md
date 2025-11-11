# Contributing to NDI Webcam App

Thank you for your interest in contributing to the NDI Webcam App! This document provides guidelines and instructions for contributing.

## Code of Conduct

- Be respectful and inclusive
- Welcome newcomers and help them get started
- Focus on constructive feedback
- Keep discussions professional and on-topic

## How to Contribute

### Reporting Bugs

Before creating bug reports, please check existing issues to avoid duplicates. When creating a bug report, include:

- **Clear title and description**
- **Steps to reproduce** the issue
- **Expected behavior** vs actual behavior
- **Screenshots** if applicable
- **Device information** (OS version, device model)
- **App version** and Flutter version

### Suggesting Enhancements

Enhancement suggestions are welcome! Please provide:

- **Clear description** of the enhancement
- **Use case** - why is this useful?
- **Examples** from other apps if applicable
- **Implementation ideas** if you have any

### Pull Requests

1. **Fork the repository** and create a branch from `main`
2. **Make your changes** following the coding standards
3. **Test thoroughly** on both Android and iOS if possible
4. **Update documentation** if needed
5. **Commit with clear messages** following our commit style
6. **Submit a pull request** with detailed description

## Development Setup

1. Install Flutter SDK (3.0.0+)
2. Clone your fork: `git clone https://github.com/YOUR_USERNAME/ndi-webcam-app.git`
3. Install dependencies: `flutter pub get`
4. Create a branch: `git checkout -b feature/your-feature-name`

## Coding Standards

### Dart/Flutter Code Style

- Follow the [official Dart style guide](https://dart.dev/guides/language/effective-dart)
- Use `flutter format` to format your code
- Run `flutter analyze` before committing
- Keep functions small and focused
- Use meaningful variable and function names
- Add comments for complex logic

### File Organization

```
lib/
  ├── main.dart              # App entry point
  ├── screens/               # Screen widgets
  ├── services/              # Business logic
  ├── widgets/               # Reusable widgets
  └── utils/                 # Helper functions
```

### Commit Message Format

```
type: short description

Longer description if needed.

Fixes #issue_number
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

Examples:
```
feat: add exposure control slider
fix: camera not releasing on app minimize
docs: update installation instructions
```

## Testing Guidelines

### Before Submitting

- [ ] Code compiles without errors
- [ ] App runs on at least one platform
- [ ] No new warnings from `flutter analyze`
- [ ] Code is formatted with `flutter format`
- [ ] New features are documented
- [ ] Existing functionality still works

### Testing Checklist

- [ ] Test on physical device (not just emulator)
- [ ] Test camera switching
- [ ] Test quality changes
- [ ] Test permissions flow
- [ ] Test app backgrounding/foregrounding
- [ ] Test with different screen sizes
- [ ] Check for memory leaks

## Areas for Contribution

### High Priority

- Native NDI SDK integration
- Portrait/Bokeh mode implementation
- Network device discovery
- Performance optimization

### Medium Priority

- Manual camera controls (focus, exposure)
- Audio level monitoring
- Recording functionality
- Settings persistence

### Low Priority / Good First Issues

- Dark mode support
- Additional quality presets
- UI improvements
- Documentation updates
- Unit tests
- Example screenshots

## Questions?

Feel free to:
- Open an issue for questions
- Start a discussion in GitHub Discussions
- Reach out to maintainers

## Recognition

Contributors will be:
- Listed in CHANGELOG.md for their contributions
- Mentioned in release notes
- Added to a contributors list (if we create one)

Thank you for contributing! 🎉
