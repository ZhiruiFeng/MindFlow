# Documentation & Project Structure Standards

## Documentation Organization

### Directory Structure

All documentation must follow this standardized structure:

```
MindFlow/
├── README.md                    # Project overview (root only)
├── LICENSE                      # Legal (root only)
├── .gitignore                  # Git config (root only)
│
├── docs/                        # All documentation
│   ├── README.md               # Documentation index
│   │
│   ├── guides/                 # User and developer guides
│   │   ├── quick-start.md     # Getting started guide
│   │   ├── setup-guide.md     # Development setup
│   │   └── *.md               # Other guides
│   │
│   ├── reference/              # Technical reference
│   │   ├── api-integration.md # API documentation
│   │   ├── project-structure.md # Code organization
│   │   └── *.md               # Other references
│   │
│   ├── architecture/           # Design and architecture
│   │   ├── design-plan.md     # System design
│   │   ├── implementation-summary.md # Dev summary
│   │   └── *.md               # Other architecture docs
│   │
│   └── troubleshooting/        # Problem-solving guides
│       ├── build-fixes.md     # Build issues
│       ├── permission-fixes.md # Permission issues
│       └── *.md               # Other troubleshooting
│
├── spec/                        # Specifications (NOT documentation)
│   └── coding-regulations/     # Coding standards
│       ├── general-standards.md
│       ├── swift-swiftui-standards.md
│       └── documentation-standards.md (this file)
│
└── MindFlow/                   # Source code
```

### Principles

1. **Separation of Concerns**
   - User guides → `docs/guides/`
   - Technical references → `docs/reference/`
   - Architecture docs → `docs/architecture/`
   - Troubleshooting → `docs/troubleshooting/`
   - Specifications → `spec/`

2. **Root Directory Cleanliness**
   - Keep ONLY essential files in root: README.md, LICENSE, .gitignore
   - Move ALL other documentation to `docs/`
   - Never clutter root with multiple markdown files

3. **Progressive Disclosure**
   - Root README: High-level overview with links
   - docs/README.md: Complete documentation index
   - Category folders: Detailed content
   - Maximum depth: 3 levels

## Naming Conventions

### File Naming

**Use kebab-case for all documentation files:**

```
✅ Good:
quick-start.md
api-integration.md
build-fixes.md
design-plan.md

❌ Bad:
QUICK_START.md          # Screaming snake case
QuickStart.md           # Pascal case
quick_start.md          # Snake case
quickstart.md           # No separator
```

**Exception**: `README.md` (universal convention)

### Rationale
- More readable
- Easier to type (no Shift key)
- Case-insensitive filesystem friendly
- Better URL slug conversion
- Industry standard

## Documentation Types

### 1. User Documentation

**Location**: `docs/guides/`

**Purpose**: Help users get started and use the application

**Examples**:
- `quick-start.md` - 5-minute getting started
- `installation.md` - Installation instructions
- `user-guide.md` - Complete user manual

**Requirements**:
- Write for non-technical users
- Include screenshots/examples
- Step-by-step instructions
- Clear, simple language

### 2. Developer Documentation

**Location**: `docs/guides/` or `docs/reference/`

**Purpose**: Help developers set up and understand the codebase

**Examples**:
- `setup-guide.md` - Development environment setup
- `contributing.md` - Contribution guidelines
- `api-integration.md` - API usage details

**Requirements**:
- Include code examples
- Specify versions and dependencies
- Document edge cases
- Provide troubleshooting tips

### 3. Architecture Documentation

**Location**: `docs/architecture/`

**Purpose**: Explain system design and architectural decisions

**Examples**:
- `design-plan.md` - Overall system design
- `implementation-summary.md` - What was built and why
- `adr/` - Architecture Decision Records

**Requirements**:
- Document the "why" not just the "what"
- Include diagrams where helpful
- Explain trade-offs
- Keep updated with major changes

### 4. Reference Documentation

**Location**: `docs/reference/`

**Purpose**: Technical reference material

**Examples**:
- `project-structure.md` - Code organization
- `api-reference.md` - API endpoints
- `configuration.md` - Config options

**Requirements**:
- Accurate and complete
- Updated with code changes
- Include examples
- Link to related docs

### 5. Troubleshooting Documentation

**Location**: `docs/troubleshooting/`

**Purpose**: Help solve common problems

**Examples**:
- `build-fixes.md` - Build error solutions
- `permission-fixes.md` - Permission issues
- `faq.md` - Frequently asked questions

**Requirements**:
- Problem → Solution format
- Include error messages
- Provide step-by-step fixes
- Link to related resources

## Documentation Index

### docs/README.md

**Every project MUST have a `docs/README.md` that serves as a documentation hub.**

Required sections:
1. **Getting Started** - Links to guides
2. **Architecture** - Links to design docs
3. **Reference** - Links to technical docs
4. **Troubleshooting** - Links to help docs
5. **Documentation Map** - Visual structure

Example structure:
```markdown
# Project Documentation

## Getting Started
- [Quick Start](./guides/quick-start.md)
- [Setup Guide](./guides/setup-guide.md)

## Architecture
- [Design Plan](./architecture/design-plan.md)

## Reference
- [Project Structure](./reference/project-structure.md)

## Troubleshooting
- [Build Fixes](./troubleshooting/build-fixes.md)
```

## Cross-Referencing

### Relative Links

**ALWAYS use relative links for internal documentation:**

```markdown
✅ Good:
[Quick Start](./docs/guides/quick-start.md)
[Design Plan](../architecture/design-plan.md)
[README](../../README.md)

❌ Bad:
[Quick Start](/docs/guides/quick-start.md)  # Absolute path
[Design Plan](https://github.com/.../design-plan.md)  # External URL
```

### Link Format

Use descriptive link text:
```markdown
✅ Good:
See the [Quick Start Guide](./guides/quick-start.md) for details.

❌ Bad:
See [here](./guides/quick-start.md) for details.
Click [this link](./guides/quick-start.md).
```

### Anchor Links

For linking to sections within documents:
```markdown
[See Installation](#installation)
[API Reference](./api-integration.md#authentication)
```

## Markdown Standards

### Headers

```markdown
# H1 - Document Title (one per file)

## H2 - Major Section

### H3 - Subsection

#### H4 - Sub-subsection
```

**Rules**:
- Only one H1 per file (document title)
- Don't skip levels (H1 → H3)
- Use sentence case, not Title Case
- No punctuation at end

### Code Blocks

Always specify language:
````markdown
```swift
func example() {
    print("Hello")
}
```

```bash
npm install
```
````

### Lists

Use consistent formatting:
```markdown
Unordered:
- Item one
- Item two
  - Nested item

Ordered:
1. First step
2. Second step
   - Sub-step
3. Third step
```

### Tables

```markdown
| Header 1 | Header 2 |
|----------|----------|
| Cell 1   | Cell 2   |
| Cell 3   | Cell 4   |
```

### Emphasis

```markdown
**Bold** for emphasis
*Italic* for terms
`Code` for inline code
```

## Documentation Maintenance

### Version Control

**Use `git mv` for moving/renaming files:**
```bash
✅ Good:
git mv OLD_NAME.md new-name.md

❌ Bad:
mv OLD_NAME.md new-name.md
git add new-name.md
```

### Update Checklist

When adding/moving documentation:
- [ ] Use `git mv` to preserve history
- [ ] Update all internal links
- [ ] Update `docs/README.md` index
- [ ] Update root `README.md` if needed
- [ ] Verify all links work
- [ ] Follow naming conventions

### Link Verification

Before committing documentation changes:

```bash
# Check for broken links (if you have markdown-link-check)
npx markdown-link-check README.md
npx markdown-link-check docs/**/*.md
```

## Documentation Quality Standards

### Clarity
- Write in clear, concise language
- Use active voice
- Avoid jargon unless necessary
- Define technical terms

### Completeness
- Include all necessary information
- Provide examples
- Cover edge cases
- Link to related docs

### Accuracy
- Keep documentation synchronized with code
- Test all examples
- Verify all links
- Update version numbers

### Usability
- Use proper formatting
- Include table of contents for long docs
- Add visual aids (diagrams, screenshots)
- Provide quick links

## Enforcement

### Code Review Checklist

Reviewers must verify:
- [ ] New docs in correct directory
- [ ] Proper naming convention (kebab-case)
- [ ] `docs/README.md` updated if needed
- [ ] All links use relative paths
- [ ] No markdown files added to root (except README.md)
- [ ] Links tested and working
- [ ] Proper markdown formatting

### Automated Checks

Consider adding to CI/CD:
- Link checker (markdown-link-check)
- Markdown linter (markdownlint)
- Spelling checker
- Dead link detector

## Examples

### Good Documentation Structure

```
docs/
├── README.md
├── guides/
│   ├── quick-start.md
│   ├── installation.md
│   └── configuration.md
├── reference/
│   ├── api-reference.md
│   ├── cli-reference.md
│   └── project-structure.md
├── architecture/
│   ├── design-plan.md
│   ├── data-flow.md
│   └── adr/
│       ├── 001-use-swiftui.md
│       └── 002-api-choice.md
└── troubleshooting/
    ├── build-issues.md
    ├── common-errors.md
    └── faq.md
```

### Bad Documentation Structure

```
❌ Root clutter:
INSTALL.md
SETUP.md
GUIDE.md
ARCHITECTURE.md
README.md

❌ Inconsistent naming:
docs/Quick_Start.md
docs/setupGuide.md
docs/API-REFERENCE.MD

❌ Poor organization:
docs/everything.md
docs/misc/
docs/stuff/
```

## Benefits

Following these standards provides:

1. **Maintainability** - Easy to find and update docs
2. **Consistency** - Uniform structure across project
3. **Discoverability** - Logical organization aids navigation
4. **Scalability** - Structure grows with project
5. **Professionalism** - Clean, organized appearance
6. **Collaboration** - Clear where to add new docs

## References

- [General Coding Standards](./general-standards.md)
- [Swift/SwiftUI Standards](./swift-swiftui-standards.md)
- [Markdown Guide](https://www.markdownguide.org/)
- [GitHub Flavored Markdown](https://github.github.com/gfm/)
