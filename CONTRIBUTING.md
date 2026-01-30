# Contributing to Azure Billing Classifier

Thank you for your interest in contributing! This project aims to help teams understand their Azure billing structure through automation.

## How to Contribute

### Reporting Issues

If you find a bug or have a feature request:

1. Check existing issues to avoid duplicates
2. Open a new issue with:
   - Clear description of the problem or feature
   - Steps to reproduce (for bugs)
   - Expected vs actual behavior
   - Your Azure environment details (EA/MCA/CSP, without sensitive data)

### Submitting Changes

1. **Fork the repository**
2. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. **Make your changes**
   - Follow existing code style
   - Add comments for complex logic
   - Test your changes with multiple subscription types if possible
4. **Commit with clear messages**
   ```bash
   git commit -m "Add feature: description of what you added"
   ```
5. **Push and create a pull request**
   ```bash
   git push origin feature/your-feature-name
   ```

### Code Style Guidelines

**PowerShell:**
- Use Pascal case for functions: `Get-BillingAccount`
- Use verb-noun naming convention
- Include comment-based help for functions
- Use `$ErrorActionPreference = "Stop"` for robust error handling

**Bash:**
- Use snake_case for functions: `extract_billing_account`
- Include error handling with `set -euo pipefail`
- Add comments for non-obvious logic
- Ensure POSIX compatibility where possible

### Testing

Before submitting:

- Test your script with Azure CLI logged in
- Test with both PowerShell and Bash (if modifying scripts)
- Verify CSV output is valid and complete
- Check that summary statistics are accurate

### Areas for Contribution

We're especially interested in:

- **Edge case handling**: Unusual subscription types, special Azure programs
- **Performance improvements**: Faster API queries, better caching
- **Additional output formats**: JSON, Excel, Power BI templates
- **Documentation**: Better examples, troubleshooting guides
- **Multi-environment support**: Azure Government, Azure China
- **Enhanced detection**: More billing scenarios, better CSP detection

### Questions?

Open an issue with the "question" label or reach out in the discussions section.

## Code of Conduct

- Be respectful and constructive
- Focus on the code and ideas, not individuals
- Help create a welcoming environment for all contributors

Thank you for helping make Azure billing more transparent!
