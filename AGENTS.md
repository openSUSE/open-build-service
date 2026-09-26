# Repository Agent Instructions

## Git Commit Disclosure
Per `CONTRIBUTING.md`, all AI-assisted commits must disclose generative AI usage using the `Assisted-by:` trailer in commit messages:

```
Assisted-by: opencode:gemini-3.6-flash
```

## Mandatory Pre-Push Requirements
**ALWAYS** run the linter and relevant tests before pushing changes to production or submitting code.

1. **Run Linter (Mandatory)**:
   ```bash
   docker compose run --rm frontend bundle exec rake dev:lint:all
   ```

2. **Run Tests (Mandatory)**:
   Run relevant specs or test files for any changed features or bug fixes to verify work.

## Testing Reference & Commands

> For full testing documentation (mobile specs, VCR, debugging, troubleshooting), see the
> [Development Environment Tips & Tricks Wiki](https://github.com/openSUSE/open-build-service/wiki/Development-Environment-Tips-&-Tricks#test-suites).

### Database Prerequisites
Seed the test database if needed before running specs:
```bash
docker compose exec frontend bash -c "RAILS_ENV=test bundle exec rake db:seed"
```
To reset and re-seed:
```bash
docker compose exec frontend bash -c "RAILS_ENV=test bundle exec rake db:reset db:seed"
```

> Note: Use `docker compose exec frontend ...` when services are running, or `docker compose run --rm frontend ...` for a one-off container.

### Running RSpec

- **Run all specs**:
  ```bash
  docker compose run --rm frontend bundle exec rspec
  ```
- **Run a single spec file**:
  ```bash
  docker compose run --rm frontend bundle exec rspec <path_to_spec>
  ```

### Running Minitest

- **Install backend packages (once per environment)**:
  ```bash
  docker compose run --rm frontend bash -c "rake dev:minitest:install_backend"
  ```
- **Run all Minitests**:
  ```bash
  docker compose run --rm frontend bundle exec rake test
  ```
- **Run a single Minitest file**:
  ```bash
  docker compose run --rm frontend bundle exec ruby <path_to_test>
  ```
