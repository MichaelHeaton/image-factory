# Git Rules

## Branch Management

* Always lint code before committing
* Always use branches for changes (never commit directly to main)
* Always add meaningful comments to code
* Always create Pull Requests with detailed notes describing changes
* Default branch should be `Main`

## Branch Naming

* Unless there is a ticket number, branches should be named in the format: `YYYY-MM-DD-description`
  * Example: `2024-11-21-update-storage-config`
  * Example: `2024-11-21-add-security-hardening`
* If a ticket number exists, use: `ticket-XXXX-description`
  * Example: `ticket-1234-fix-authentication`

## Pull Request Guidelines

* PR title should be descriptive and concise
* PR description should include:
  * What changed
  * Why it changed
  * How to test (if applicable)
  * Any breaking changes
* Link to related tickets/issues if applicable
* Request review from appropriate team members

## Commit Messages

* Use clear, descriptive commit messages
* Follow conventional commit format when possible:
  * `feat: add new feature`
  * `fix: resolve bug`
  * `docs: update documentation`
  * `refactor: restructure code`
  * `test: add or update tests`

