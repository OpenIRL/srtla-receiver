# Flexible Build System for SRTla Receiver

This repository implements a flexible build system that allows switching between different versions of `srt-live-server` and `srtla`.

## Build Arguments

The Dockerfile supports the following build arguments:

- `SRTLA_BRANCH`: SRTla branch (default: `main`, options: `main`, `next`)
- `SLS_TAG`: srt-live-server tag (default: `latest`, options: `latest`, `next`)

## Version Selection

### Release Workflow
The `release.yml` workflow selects versions based on the release type and optional overrides:

#### Default Behavior
- **Stable Release** (without "Pre-release" flag): SRTla: `main` branch, SLS: `latest` tag
- **Pre-Release** (with "Pre-release" flag): SRTla: `main` branch, SLS: `latest` tag (but overrides required)

#### Custom Configuration
You can override the default behavior using keywords in the release description:

**SRTla Override:**
- `srtla:next` - Uses next branch (only allowed in pre-releases)

**SLS Override:**
- `sls:next` - Uses next tag (only allowed in pre-releases)

#### Validation Rules
- **Stable releases** cannot use `next` components
- **Pre-releases** must use at least one `next` component via overrides
- Build will fail if these rules are violated

#### Release Description Examples

```
# Stable release (main/latest)
Release 1.2.3

# Pre-release with SRTla override (next/latest)
Release 1.2.3-beta
srtla:next

# Pre-release with SLS override (main/next)
Release 1.2.3-beta
sls:next

# Pre-release with both overrides (next/next)
Release 1.2.3-beta
srtla:next
sls:next

# ❌ Pre-release without overrides → Build fails
Release 1.2.3-beta
```

## Creating Releases

1. **Stable Release**:
   - Create a new release on GitHub
   - Remove the "Pre-release" flag
   - No keywords needed → automatically `main` + `latest`

2. **Pre-Release**:
   - Create a new release on GitHub
   - Enable the "Pre-release" flag
   - **Required**: Add at least one keyword to the release description:
     - `srtla:next` (for next branch)
     - `sls:next` (for next tag)

### Automatic Tags
The system automatically creates the following image tags:
- `ghcr.io/openirl/srtla-receiver:{release-tag}` (e.g. `1.2.3`)
- `ghcr.io/openirl/srtla-receiver:latest` (only for stable releases)
- `ghcr.io/openirl/srtla-receiver:next` (only for pre-releases)

## Version Combinations

| Release Type | SRTla Branch | SLS Tag  | Usage                  | Keywords                |
|--------------|--------------|----------|------------------------|-------------------------|
| Stable       | `main`       | `latest` | Production Release     | None                    |
| Pre-Release  | `next`       | `latest` | Testing SRTla features | `srtla:next`            |
| Pre-Release  | `main`       | `next`   | Testing SLS features   | `sls:next`              |
| Pre-Release  | `next`       | `next`   | Testing both features  | `srtla:next` `sls:next` |
