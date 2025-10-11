# Swift & SwiftUI Coding Standards

## Swift Language Standards

### Naming Conventions
- Use `UpperCamelCase` for types (classes, structs, enums, protocols)
- Use `lowerCamelCase` for functions, variables, and properties
- Use descriptive names that communicate intent
- Prefix boolean properties with `is`, `has`, `should`, or `can`
- Avoid abbreviations unless universally understood

### Code Organization
- Group related functionality with `// MARK: -` comments
- Order declarations: properties → initializers → lifecycle methods → public methods → private methods
- Keep file size manageable (under 400 lines preferred)
- One type per file unless they're tightly coupled

### Type Safety & Optionals
- Prefer non-optional types when possible
- Use guard statements for early returns
- Avoid force unwrapping (`!`) unless absolutely certain
- Use optional chaining (`?.`) and nil coalescing (`??`)
- Prefer `if let` or `guard let` for safe unwrapping

### Error Handling
- Use Swift's native error handling (do-try-catch)
- Create custom error enums that conform to `Error`
- Provide meaningful error messages
- Log errors appropriately for debugging
- Never silently ignore errors

### Closures & Functions
- Use trailing closure syntax when it improves readability
- Prefer explicit parameter names for clarity
- Keep closures short; extract complex logic into separate functions
- Use `[weak self]` to avoid retain cycles when capturing self
- Document side effects and asynchronous behavior

## SwiftUI Standards

### View Organization
- Keep views small and composable
- Extract subviews when body contains more than 10 lines of complex logic
- Use view modifiers in a consistent order: layout → appearance → behavior
- Group related views in separate files

### State Management
- Use `@State` for view-local state only
- Use `@StateObject` for view-owned observable objects
- Use `@ObservedObject` for externally-owned observable objects
- Use `@EnvironmentObject` for app-wide shared state
- Use `@Binding` to pass mutable state to child views
- Keep state as close to where it's used as possible

### View Models
- Use `@MainActor` for classes that update UI
- Conform to `ObservableObject` for reactive state
- Publish only necessary properties with `@Published`
- Keep business logic separate from view code
- Make view models testable

### Async/Await
- Use async/await for asynchronous operations
- Use `Task` for fire-and-forget operations
- Handle cancellation appropriately
- Update UI on `@MainActor` when needed
- Avoid nested completion handlers

## Security Standards

### Sensitive Data
- Never hardcode credentials, API keys, or secrets
- Use Keychain for storing sensitive information
- Implement proper data encryption for sensitive user data
- Clear sensitive data from memory when no longer needed
- Use secure communication protocols (HTTPS, TLS)

### API Security
- Validate all input from external sources
- Sanitize user input before processing
- Implement proper authentication and authorization
- Use token-based authentication with expiration
- Handle API rate limiting gracefully

### Privacy
- Request minimum necessary permissions
- Clearly explain why permissions are needed
- Respect user privacy preferences
- Implement proper data retention policies
- Comply with privacy regulations (GDPR, CCPA)

### Code Security
- Avoid SQL injection with parameterized queries
- Validate file paths to prevent directory traversal
- Use secure random number generation
- Keep dependencies updated for security patches
- Never log sensitive information

### Version Control & Repository Security
- **NEVER commit credentials or secrets to version control**
  - No API keys, tokens, passwords, or private keys
  - No `.env` files with real credentials
  - No hardcoded database connection strings
  - No OAuth secrets or client credentials
- **Add sensitive files to .gitignore IMMEDIATELY**
  ```
  # .gitignore must include:
  *.pem
  *.key
  *.p12
  *.mobileprovision
  .env
  .env.local
  credentials.json
  secrets.json
  Config.xcconfig  # if contains secrets
  ```
- **Use environment variables or Keychain for configuration**
  - Development: Use `.env.example` as template (without real values)
  - Production: Use Keychain Services or secure configuration
- **Scan repository before first commit**
  - Check for accidentally included secrets
  - Use tools like `git-secrets` or `gitleaks`
  - Review `.gitignore` completeness
- **If secrets are accidentally committed**
  - IMMEDIATELY rotate/revoke the exposed credentials
  - Don't just delete the file - it's still in git history
  - Consider using `git filter-branch` or BFG Repo-Cleaner
  - Notify security team if applicable

### Privacy & User Data
- **Never log sensitive user information**
  - No passwords, tokens, or API keys in logs
  - No personally identifiable information (PII)
  - No credit card or payment information
  - Sanitize logs in production builds
- **Be cautious with error messages**
  - Don't expose system internals in user-facing errors
  - Don't reveal file paths or database structure
  - Generic messages for authentication failures
- **Data minimization**
  - Only collect data that's absolutely necessary
  - Don't store data longer than needed
  - Implement data deletion/export features
- **Third-party services**
  - Review privacy policies before integration
  - Understand what data is shared
  - Use data processing agreements where required
  - Minimize data sent to analytics services

## Testing Standards

### Unit Tests
- Write tests for business logic and view models
- Use descriptive test names: `test_methodName_condition_expectedResult`
- Follow Arrange-Act-Assert pattern
- Mock external dependencies
- Aim for high coverage of critical paths

### Integration Tests
- Test component interactions
- Verify data flow between layers
- Test error handling paths
- Use realistic test data

## Performance Standards

### Memory Management
- Profile for memory leaks regularly
- Use weak references to break retain cycles
- Release large resources when not needed
- Be mindful of image and data caching

### Rendering Performance
- Avoid heavy computations in view body
- Use lazy stacks for large lists
- Implement proper list item identity
- Profile with Instruments for performance bottlenecks

## Documentation

### Code Comments
- Document complex algorithms and business logic
- Explain "why" not "what" in comments
- Keep comments up to date with code changes
- Use `///` for documentation comments
- Document public APIs with examples

### Documentation Structure
```swift
/// Brief description of what this does
///
/// More detailed explanation if needed
///
/// - Parameters:
///   - parameter1: Description
///   - parameter2: Description
/// - Returns: Description of return value
/// - Throws: Types of errors that can be thrown
```

## Example Structure

```swift
// MARK: - Type Definition
final class ExampleManager: ObservableObject {
    // MARK: - Properties
    @Published private(set) var items: [Item] = []
    private let service: ServiceProtocol

    // MARK: - Initialization
    init(service: ServiceProtocol) {
        self.service = service
    }

    // MARK: - Public Methods
    func fetchItems() async throws {
        items = try await service.fetchItems()
    }

    // MARK: - Private Methods
    private func processItem(_ item: Item) -> ProcessedItem {
        // Implementation
    }
}
```
