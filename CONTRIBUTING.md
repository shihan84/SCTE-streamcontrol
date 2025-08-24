# Contributing Guidelines

Thank you for your interest in contributing to the Self-Hosted Media Server with SCTE-35 and SSAI project! This document provides guidelines and instructions for contributors.

## Table of Contents
- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Coding Standards](#coding-standards)
- [Testing Guidelines](#testing-guidelines)
- [Documentation](#documentation)
- [Pull Request Process](#pull-request-process)
- [Issue Reporting](#issue-reporting)

## Code of Conduct

This project adheres to the Contributor Covenant Code of Conduct. Please read [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) for more details.

## Getting Started

### Prerequisites
- Node.js 18 or higher
- Git
- FFmpeg (for media processing)
- Basic knowledge of TypeScript, React, and Next.js

### Setup
1. Fork the repository
2. Clone your fork locally
```bash
git clone https://github.com/your-username/media-server-scte35.git
cd media-server-scte35
```

3. Add the original repository as upstream
```bash
git remote add upstream https://github.com/original-username/media-server-scte35.git
```

4. Install dependencies
```bash
npm install
```

5. Create a development branch
```bash
git checkout -b feature/your-feature-name
```

## Development Workflow

### 1. Choose an Issue
- Browse existing [issues](https://github.com/original-username/media-server-scte35/issues)
- Pick an issue to work on or create a new one
- Assign the issue to yourself
- Ask questions if anything is unclear

### 2. Create a Branch
Use the following branching conventions:
- Features: `feature/feature-name`
- Bug fixes: `fix/bug-description`
- Documentation: `docs/documentation-update`
- Tests: `test/test-addition`

```bash
git checkout -b feature/your-feature-name
```

### 3. Make Changes
- Write clean, modular code
- Follow the coding standards outlined below
- Add tests for new functionality
- Update relevant documentation

### 4. Test Your Changes
```bash
# Run linting
npm run lint

# Run tests
npm test

# Run specific test suites
node test-monitoring.js
node test-ssai.js
node test-scte35-comprehensive.js
```

### 5. Commit Changes
Use conventional commit messages:
```
feat: add new SSAI targeting feature
fix: resolve SCTE-35 event timing issue
docs: update API documentation
test: add monitoring system tests
refactor: improve stream management code
```

Example:
```bash
git add .
git commit -m "feat: add real-time ad performance metrics"
```

### 6. Push and Create Pull Request
```bash
git push origin feature/your-feature-name
```

Then create a pull request on GitHub with:
- Clear title and description
- References to related issues
- Testing instructions
- Screenshots if applicable

## Coding Standards

### TypeScript
- Use TypeScript for all new code
- Provide proper type definitions
- Avoid `any` type when possible
- Use interfaces for object shapes

```typescript
// Good
interface StreamConfig {
  name: string;
  bitrate: number;
  resolution: string;
}

// Bad
const config: any = { name: 'test', bitrate: 5000 };
```

### React/Next.js
- Use functional components with hooks
- Prefer custom hooks for complex logic
- Use TypeScript interfaces for props
- Follow Next.js App Router conventions

```typescript
// Good
interface VideoPlayerProps {
  src: string;
  autoPlay?: boolean;
  onTimeUpdate?: (time: number) => void;
}

export const VideoPlayer: React.FC<VideoPlayerProps> = ({ 
  src, 
  autoPlay = false,
  onTimeUpdate 
}) => {
  // Component logic
};
```

### File Organization
- Use kebab-case for file names
- Group related files in folders
- Keep components small and focused
- Use index files for exports

```
src/
├── components/
│   ├── ui/
│   ├── monitoring/
│   └── streaming/
├── lib/
│   ├── media-server/
│   └── utils/
└── app/
    ├── api/
    └── page.tsx
```

### Naming Conventions
- **Components**: PascalCase (`VideoPlayer`, `StreamMonitor`)
- **Functions**: camelCase (`getStreamMetrics`, `handleSCTE35Event`)
- **Variables**: camelCase (`streamConfig`, `scte35Events`)
- **Constants**: UPPER_SNAKE_CASE (`MAX_STREAM_DURATION`, `SCTE35_PID`)
- **Files**: kebab-case (`video-player.tsx`, `stream-monitor.ts`)

### Error Handling
- Use proper error boundaries
- Provide meaningful error messages
- Log errors appropriately
- Handle edge cases

```typescript
// Good
try {
  const stream = await startStream(config);
  return stream;
} catch (error) {
  console.error('Failed to start stream:', error);
  throw new Error(`Stream startup failed: ${error.message}`);
}

// Bad
const stream = await startStream(config);
return stream;
```

### Performance
- Use React.memo for expensive components
- Implement proper loading states
- Optimize re-renders with useCallback/useMemo
- Use virtualization for large lists

```typescript
// Good
const ExpensiveComponent = React.memo(({ data }) => {
  const processedData = useMemo(() => {
    return heavyProcessing(data);
  }, [data]);
  
  return <div>{processedData}</div>;
});
```

## Testing Guidelines

### Test Structure
- Unit tests for individual functions
- Integration tests for components
- End-to-end tests for user flows
- Performance tests for critical paths

### Test Files
- Name test files after the files they test: `component.test.ts`
- Place tests in `__tests__` directory or alongside source files
- Use descriptive test names

```typescript
// Good
describe('StreamMonitor', () => {
  it('should collect metrics correctly', () => {
    // Test implementation
  });
  
  it('should handle stream errors gracefully', () => {
    // Test implementation
  });
});
```

### Test Coverage
- Aim for 80%+ code coverage
- Test all critical paths
- Include edge cases and error conditions
- Test both success and failure scenarios

### API Testing
- Use the provided test scripts
- Test all API endpoints
- Validate response formats
- Test error handling

```bash
# Run API tests
node test-monitoring.js
node test-ssai.js
node test-scte35-comprehensive.js
```

## Documentation

### Code Documentation
- Use JSDoc comments for functions and classes
- Document parameters and return values
- Include usage examples
- Explain complex algorithms

```typescript
/**
 * Starts a new media stream with the specified configuration
 * @param config - Stream configuration object
 * @returns Promise that resolves to the created stream
 * @throws Error if stream creation fails
 */
export async function startStream(config: StreamConfig): Promise<Stream> {
  // Implementation
}
```

### README Updates
- Update README.md for new features
- Include installation and usage instructions
- Add API documentation
- Provide examples and screenshots

### API Documentation
- Keep API reference up to date
- Document all endpoints and parameters
- Include request/response examples
- Note any breaking changes

## Pull Request Process

### Before Submitting
1. **Code Quality**
   - Run `npm run lint` and fix all issues
   - Format code consistently
   - Remove unused imports and variables

2. **Testing**
   - Run all tests and ensure they pass
   - Add tests for new functionality
   - Update existing tests if needed

3. **Documentation**
   - Update relevant documentation
   - Add comments for complex code
   - Update README and API docs

4. **Local Testing**
   - Test your changes locally
   - Verify the application builds successfully
   - Test all affected features

### Pull Request Template
```markdown
## Description
Brief description of the changes made.

## Type of Change
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update

## Checklist
- [ ] My code follows the style guidelines of this project
- [ ] I have performed a self-review of my own code
- [ ] I have commented my code, particularly in hard-to-understand areas
- [ ] I have made corresponding changes to the documentation
- [ ] My changes generate no new warnings
- [ ] I have added tests that prove my fix is effective or that my feature works
- [ ] New and existing unit tests pass locally with my changes
- [ ] Any dependent changes have been merged and published in downstream modules

## Testing
Describe the testing performed and how to verify the changes.

## Screenshots (if applicable)
Add screenshots to help understand the changes.

## Related Issues
Closes #123
Related to #456
```

### Review Process
1. **Automated Checks**: CI/CD pipeline runs automatically
2. **Peer Review**: At least one maintainer must review
3. **Testing Changes**: Address review feedback
4. **Approval**: Maintainer approves and merges
5. **Deployment**: Changes are deployed automatically

## Issue Reporting

### Bug Reports
When reporting bugs, please include:
- Clear description of the issue
- Steps to reproduce
- Expected behavior
- Actual behavior
- Environment details (OS, Node.js version, etc.)
- Relevant logs or error messages
- Screenshots if applicable

### Feature Requests
For feature requests, please provide:
- Clear description of the desired feature
- Use case and motivation
- Proposed implementation (if known)
- Alternative solutions considered

### Issue Template
```markdown
## Issue Type
- [ ] Bug
- [ ] Feature Request
- [ ] Documentation
- [ ] Question

## Description
Clear and concise description of the issue.

## Steps to Reproduce (for bugs)
1. Go to '...'
2. Click on '....'
3. Scroll down to '....'
4. See error

## Expected Behavior
Description of what you expected to happen.

## Actual Behavior
Description of what actually happened.

## Environment
- OS: [e.g. Ubuntu 20.04]
- Node.js version: [e.g. 18.0.0]
- Browser: [e.g. Chrome 96.0]
- Application version: [e.g. 1.0.0]

## Additional Context
Any other context, screenshots, or information about the problem.
```

## Getting Help

### Resources
- [Documentation](STEP_BY_STEP_GUIDE.md)
- [API Reference](API_REFERENCE.md)
- [Issues](https://github.com/original-username/media-server-scte35/issues)
- [Discussions](https://github.com/original-username/media-server-scte35/discussions)

### Communication
- **GitHub Issues**: For bug reports and feature requests
- **GitHub Discussions**: For general questions and discussions
- **Email**: For private communications with maintainers
- **Discord**: For real-time chat (if available)

### Code Review Guidelines
When reviewing code, please:
- Check for adherence to coding standards
- Verify tests are comprehensive
- Ensure documentation is updated
- Consider performance implications
- Check for security vulnerabilities
- Provide constructive feedback

## Recognition

Contributors will be recognized in:
- README.md contributors section
- Release notes
- Project documentation
- GitHub contributor statistics

Thank you for contributing to this project! Your efforts help make this software better for everyone.