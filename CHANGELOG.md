# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-01-30

### Added
- Initial release of Azure Billing Classifier
- PowerShell script (`Classify-AzureBilling.ps1`) for Windows environments
- Bash script (`classify-azure-billing.sh`) for Linux/macOS environments
- Comprehensive README with quick start guide
- Detection of Enterprise Agreement (EA) billing accounts
- Detection of Microsoft Customer Agreement (MCA) billing accounts
- Cloud Solution Provider (CSP) detection via multiple indicators
- Microsoft Azure Consumption Commitment (MACC) detection
- CSV export functionality for all classification results
- Summary statistics showing counts by agreement type
- Caching mechanism to reduce API calls
- Detailed and summary output modes
- Examples directory with usage scenarios
- Contributing guidelines
- MIT License

### Features
- Automatic subscription enumeration
- Billing scope analysis
- Agreement type identification
- CSP relationship detection
- MACC commitment tracking
- Unique billing account summary
- Color-coded console output (PowerShell)
- Error handling and validation
- Verbose logging support
- Multiple output format options

### API Versions Used
- Billing API: 2024-04-01
- Subscription API: 2020-01-01
- Consumption API: 2024-08-01

## Future Releases

### Planned for [1.1.0]
- JSON output format option
- Excel export with formatting
- Power BI template file
- Enhanced error messages with remediation steps
- Support for Azure Government and Azure China
- Multi-tenant batch processing
- Comparison reports (current vs previous runs)

### Planned for [1.2.0]
- Web-based dashboard
- Historical tracking database
- Alert notifications for billing changes
- Cost data integration
- Reserved Instance and Savings Plan detection
- Commitment expiration tracking

### Planned for [2.0.0]
- REST API wrapper
- Automated remediation suggestions
- Integration with Azure DevOps pipelines
- Terraform/Bicep deployment templates
- Docker container support
- Kubernetes operator

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for information on how to suggest features or report issues.
