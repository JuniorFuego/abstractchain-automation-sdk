# Contributing to AbstractChain Automation SDK

Thank you for your interest in contributing to the AbstractChain Automation SDK! This document provides guidelines and information for contributors.

## 🚀 Getting Started

### Prerequisites

- Node.js 18 or higher
- npm 9 or higher
- [Foundry](https://getfoundry.sh/) for smart contract development
- Git

### Development Setup

1. **Fork and Clone**
   ```bash
   git clone https://github.com/YOUR_USERNAME/automation-sdk.git
   cd automation-sdk
   ```

2. **Install Dependencies**
   ```bash
   npm install
   cd contracts && forge install && cd ..
   ```

3. **Build the Project**
   ```bash
   npm run build
   ```

4. **Run Tests**
   ```bash
   npm test
   ```

## 📁 Project Structure

```
automation-sdk/
├── packages/sdk/           # TypeScript SDK
├── contracts/             # Smart contracts (Foundry)
├── bundler/              # ERC-4337 Bundler service
├── examples/             # Example applications
├── docs/                 # Documentation
├── .github/              # CI/CD workflows
└── scripts/              # Build and deployment scripts
```

## 🛠️ Development Workflow

### 1. Create a Branch

Create a new branch for your feature or bug fix:

```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/your-bug-fix
```

### 2. Make Changes

- Follow the existing code style and conventions
- Add tests for new functionality
- Update documentation as needed
- Ensure all tests pass

### 3. Commit Guidelines

We use [Conventional Commits](https://conventionalcommits.org/) for commit messages:

```bash
git commit -m "feat(accounts): add session key management"
git commit -m "fix(paymaster): resolve gas estimation issue"
git commit -m "docs(readme): update installation instructions"
```

**Commit Types:**
- `feat`: New features
- `fix`: Bug fixes
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks
- `contracts`: Smart contract changes
- `sdk`: SDK-specific changes
- `bundler`: Bundler service changes

**Scopes:**
- `accounts`: Smart account functionality
- `paymaster`: Gas sponsorship features
- `nft`: NFT minting system
- `tipping`: SocialFi tipping features
- `automation`: Cross-chain automation
- `abstract`: AbstractChain native features
- `bundler`: Bundler service
- `contracts`: Smart contracts
- `sdk`: General SDK changes
- `docs`: Documentation
- `ci`: CI/CD changes

### 4. Testing

Ensure all tests pass before submitting:

```bash
# Run all tests
npm test

# Run specific test suites
npm run test:contracts
npm run test:sdk
cd bundler && npm test

# Run with coverage
npm run test:coverage
```

### 5. Code Quality

Run linting and formatting:

```bash
# Check code style
npm run lint
npm run format:check

# Fix issues automatically
npm run lint:fix
npm run format
```

## 📝 Code Style Guidelines

### TypeScript/JavaScript

- Use TypeScript for all new code
- Follow the existing ESLint configuration
- Use meaningful variable and function names
- Add JSDoc comments for public APIs
- Prefer `const` over `let`, avoid `var`
- Use async/await over Promises where possible

### Solidity

- Follow the [Solidity Style Guide](https://docs.soliditylang.org/en/latest/style-guide.html)
- Use NatSpec comments for all public functions
- Implement comprehensive test coverage
- Follow security best practices
- Use OpenZeppelin contracts where appropriate

### Testing

- Write unit tests for all new functionality
- Include integration tests for complex features
- Use descriptive test names
- Test both success and failure cases
- Aim for >95% code coverage

## 🔒 Security Guidelines

### Smart Contracts

- Follow [ConsenSys Smart Contract Best Practices](https://consensys.github.io/smart-contract-best-practices/)
- Use OpenZeppelin's security patterns
- Implement proper access controls
- Validate all inputs
- Handle edge cases and error conditions
- Use reentrancy guards where needed

### SDK

- Validate all user inputs
- Use secure communication (HTTPS/WSS)
- Handle private keys securely
- Implement proper error handling
- Sanitize error messages to prevent information leakage

## 📚 Documentation

### Code Documentation

- Add JSDoc/NatSpec comments for all public APIs
- Include usage examples in comments
- Document complex algorithms and business logic
- Keep comments up-to-date with code changes

### User Documentation

- Update relevant documentation in the `docs/` directory
- Include code examples for new features
- Update the README if needed
- Add entries to the changelog

## 🧪 Adding New Features

### Smart Contracts

1. Create the contract in `contracts/src/`
2. Add comprehensive tests in `contracts/test/`
3. Update deployment scripts if needed
4. Add integration with the SDK
5. Update documentation

### SDK Modules

1. Create the module in `packages/sdk/src/modules/`
2. Export from the main index file
3. Add unit and integration tests
4. Update the module's package.json exports
5. Add usage examples

### Examples

1. Create a new directory in `examples/`
2. Include a complete working example
3. Add a README with setup instructions
4. Ensure it works with the latest SDK version

## 🚀 Pull Request Process

### Before Submitting

- [ ] All tests pass locally
- [ ] Code follows style guidelines
- [ ] Documentation is updated
- [ ] Commit messages follow conventions
- [ ] Branch is up-to-date with main

### PR Description

Include in your PR description:

- **What**: Brief description of changes
- **Why**: Motivation and context
- **How**: Technical approach taken
- **Testing**: How you tested the changes
- **Breaking Changes**: Any breaking changes
- **Related Issues**: Link to related issues

### Review Process

1. Automated checks must pass (CI/CD)
2. Code review by maintainers
3. Security review for smart contracts
4. Documentation review
5. Final approval and merge

## 🐛 Reporting Issues

### Bug Reports

Use the bug report template and include:

- Clear description of the issue
- Steps to reproduce
- Expected vs actual behavior
- Environment details (OS, Node.js version, etc.)
- Relevant logs or error messages

### Feature Requests

Use the feature request template and include:

- Clear description of the feature
- Use case and motivation
- Proposed implementation approach
- Any alternatives considered

## 💬 Community Guidelines

- Be respectful and inclusive
- Help others learn and grow
- Provide constructive feedback
- Follow the [Code of Conduct](./CODE_OF_CONDUCT.md)

## 📞 Getting Help

- **Discord**: [discord.gg/abstractchain](https://discord.gg/abstractchain)
- **GitHub Discussions**: Use for questions and discussions
- **Issues**: Use for bug reports and feature requests
- **Email**: [dev@abstractchain.com](mailto:dev@abstractchain.com)

## 🏆 Recognition

Contributors will be recognized in:

- README contributors section
- Release notes
- Community highlights
- Annual contributor awards

Thank you for contributing to AbstractChain Automation SDK! 🎉