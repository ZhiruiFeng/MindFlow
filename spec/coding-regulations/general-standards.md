# General Coding Standards

## Core Principles

All code in this project must adhere to these fundamental principles:

### 1. Clean Code
- Write self-documenting code with clear, descriptive names
- Keep functions small and focused on a single responsibility
- Avoid code duplication (DRY principle)
- Remove dead code and unused imports
- Keep nesting levels shallow (max 3-4 levels)

### 2. Modularization
- Break down complex systems into smaller, independent modules
- Each module should have a clear, well-defined purpose
- Use proper separation of concerns (business logic, data access, presentation)
- Keep module interfaces simple and minimal
- Design modules to be independently testable

### 3. Reusability
- Write generic, parameterized code where appropriate
- Extract common patterns into shared utilities
- Use composition over inheritance
- Design APIs that can serve multiple use cases
- Document reusable components with usage examples

### 4. Consistency
- Follow established project patterns and conventions
- Use consistent naming conventions across the codebase
- Maintain consistent code formatting and style
- Apply the same architectural patterns throughout
- Keep API designs consistent within the same layer

### 5. Maintainability
- Write code that is easy to understand and modify
- Add comments only when the "why" is not obvious from code
- Refactor continuously to prevent technical debt
- Keep dependencies up to date and minimal
- Design for change and extensibility

### 6. Documentation
- Document all public APIs with clear descriptions
- Include type definitions and parameter descriptions
- Provide usage examples for complex functionality
- Document architectural decisions and trade-offs
- Keep documentation close to the code it describes
- Update documentation when code changes

## Code Review Checklist

Before submitting code, verify:
- [ ] Code follows the core principles above
- [ ] Language/framework-specific regulations are followed
- [ ] All functions and classes have clear, descriptive names
- [ ] Complex logic includes explanatory comments
- [ ] Tests are included and pass
- [ ] No hardcoded values that should be configurable
- [ ] Error handling is appropriate and informative
- [ ] Performance implications have been considered
