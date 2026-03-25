# AGENTS.md - helipad-flake

> "Simple is the opposite of complex."

## Context

Nix Flake packaging [helipad](https://github.com/Podcastindex-org/helipad) — a simple LND poller and web front-end to see and read boosts and boostagrams.

Uses source building with Rust's cargo via `rustPlatform.buildRustPackage`. The build requires protobuf for gRPC communication with LND.

### Deployment Context

This flake is designed to work standalone and alongside [nix-bitcoin](https://github.com/fort-nix/nix-bitcoin) — a NixOS framework for Bitcoin/Lightning nodes. Several of our systems run nix-bitcoin, so the module should integrate cleanly with that ecosystem.

**nix-bitcoin conventions to align with (where they don't conflict with nixpkgs):**

- Hardening via `defaultHardening` attrset (`ProtectSystem`, `MemoryDenyWriteExecute`, `SystemCallFilter`, etc.) — more comprehensive than our current hardening
- Explicit user/group with `isSystemUser = true` (nix-bitcoin doesn't use `DynamicUser`)
- `tmpfiles.rules` for data directory management
- Integration with `config.nix-bitcoin.operator.groups` for CLI access
- Services depend on upstream services (e.g., lnd) via `requires`/`after`
- Config files generated with `pkgs.writeText` (nix-bitcoin uses raw text generation, not `pkgs.formats`)

**Our module doesn't need to be a nix-bitcoin module**, but it should be easy to import into a nix-bitcoin setup and shouldn't conflict with their conventions.

| Binary | What it does |
|--------|-------------|
| `helipad` | Rust application — polls LND gRPC API for boosts/boostagrams and serves web frontend |

### Build Dependencies

| Dependency | Purpose |
|------------|---------|
| `rustPlatform` | Rust build system via cargo |
| `pkg-config` | Finds system libraries |
| `protobuf` | gRPC/protobuf compilation for LND API |
| `openssl` | TLS/SSL support for HTTPS connections |
| `sqlite` | Database for storing boost data |

### Project Structure

```
helipad.nix              # Main package definition using rustPlatform.buildRustPackage
module.nix               # NixOS module: services.helipad
Cargo.lock.patch         # Patched Cargo.lock for nix compatibility
```

---

## Project Layout

```
flake.nix                       # Thin orchestrator — flake-parts, perSystem packages
flake.lock                      # nixpkgs + flake-parts pins
helipad.nix                     # Package definition: version, hashes, rustPlatform.buildRustPackage
module.nix                      # NixOS module: services.helipad
Cargo.lock.patch                # Patched Cargo.lock for nix compatibility
README.md                       # Project documentation and TODOs
```

---

## Research-First Workflow

Before implementing, ALWAYS:

### 1. "Does this already exist?"

- Search upstream for existing solutions
- Check nixpkgs for the package
- Look at similar flakes for patterns

### 2. Research Phase

1. Read the existing codebase to understand current patterns
2. Check upstream release notes and changelogs
3. Verify assumptions about binary structure, dependencies, file layouts
4. Web search for known issues (e.g., libstdc++ on NixOS)

### 3. Specify Phase

Write before coding:

- What exists, what needs building
- Acceptance criteria
- Edge cases (tarball structure, hash format, platform differences)

### 4. Break Into Branches

- Small, focused branches
- Each independently testable
- `nix flake check` must pass after every branch

---

## How To Do Good Changes

### Branch Workflow

1. Create branch from `main` (or the branch it depends on)
2. Make changes in small logical commits
3. Run validation after every change (see below)
4. Merge when ready

### Validation Gate (Run After Every Change)

```bash
# Always run before committing:
nix fmt                  # Format nix files
nix flake check          # Eval + formatting check + NixOS module check
nix build .#boltz-client # Build succeeds
./result/bin/boltzd --version    # Binary works
./result/bin/boltzcli --version  # Both binaries work
```

If `nix flake check` fails, fix it. Don't commit broken checks.

### Commit Messages

```
<type>: <subject>

<optional body>
```

Types: `feat`, `fix`, `refactor`, `chore`, `docs`, `ci`

Examples:
```
feat: add NixOS module for boltzd

- services.boltz-client.settings: Nix attrs -> TOML passthrough
- DynamicUser, hardened systemd service

ci: add auto-update workflow

Runs twice daily, validates build before pushing.
```

### Updating Upstream Version

```bash
# Check upstream for latest release
curl -s https://api.github.com/repos/Podcastindex-org/helipad/releases/latest

# Update version and hash in helipad.nix
nix-prefetch-url --unpack "https://github.com/Podcastindex-org/helipad/archive/refs/tags/v<version>.tar.gz"
nix hash to-sri --type sha256 <hash>
# Edit helipad.nix: version + hashes
nix build .#helipad
./result/bin/helipad --version  # Verify
```

---

## Nix Style Conventions

### Flake Structure

- **Thin flake.nix** — no package logic, just `callPackage` dispatcher
- **Self-contained packages** — version, hashes, build in one file per package
- **`forAllPkgs` pattern** — `lib.getAttrs` + `lib.mapAttrs`, no flake-utils
- **treefmt-nix** for formatting (alejandra), not bare `pkgs.alejandra`

### Package Derivations

- `rustPlatform.buildRustPackage` for Rust projects
- `nativeBuildInputs`: `pkg-config`, `protobuf` for gRPC compilation
- `buildInputs`: `openssl`, `sqlite` for runtime dependencies
- `cargoHash` for reproducible Rust builds
- `cargoPatches` for patching Cargo.lock if needed
- `meta` block: description, homepage, license, platforms

### NixOS Modules

- `settings` option with `pkgs.formats.toml` type — passthrough, don't enumerate options
- `preStart` copies generated config to mutable dataDir
- `DynamicUser = true` — no manual user/group management
- `environment.systemPackages = [cfg.package]` — make CLI tools available
- Hardened systemd: `ProtectSystem = "strict"`, `NoNewPrivileges`, `PrivateTmp`
- Align with nix-bitcoin hardening (`defaultHardening` attrset) where possible without breaking standalone usage

### Formatting

- Alejandra via treefmt-nix
- Run `nix fmt` before committing
- `nix flake check` enforces formatting

---

## Anti-Patterns

- **Don't `cp -r $src/* $out`** — use `install -Dm755` for explicit binary targets
- **Don't enumerate NixOS options you don't own** — passthrough via `settings` attrset
- **Don't skip `nix flake check`** — it catches eval errors, formatting issues, module problems
- **Don't commit without testing both binaries** — `boltzd` and `boltzcli` have different dependency profiles
- **Don't forget `stdenv.cc.cc.lib`** — libstdc++ crash is a known gotcha for CGO Go binaries on NixOS
- **Don't build from source when precompiled works** — upstream build uses Docker, uniffi-bindgen-go, cargo; a nixified build is on the roadmap but precompiled is pragmatic for now
- **Don't pin to stable nixpkgs without reason** — we track upstream closely, unstable is fine
- **Don't pin to stable nixpkgs without reason** — we track upstream closely, unstable is fine

---

## Debugging

### Binary Won't Start

```bash
# Check interpreter path
readelf -l ./result/bin/helipad | grep interpreter

# Check dynamic dependencies
readelf -d ./result/bin/helipad | grep NEEDED

# Verify autoPatchelfHook worked — interpreter should be in /nix/store/
# NOT /lib64/ld-linux-x86-64.so.2
```

### Hash Mismatch

```bash
# Get new hash for updated version
nix hash to-sri --type sha256 $(nix-prefetch-url --unpack "<new-url>")
```

### Flake Check Fails on Formatting

```bash
nix fmt       # Fix formatting
git add -A    # Stage formatted files (flake check sees git-tracked files only)
nix flake check
```

### Nix Flakes Only See Git-Tracked Files

Always `git add` new files before `nix build` or `nix flake check`. Nix flakes ignore untracked files.

---

## The Most Important Lesson

> "AI coding tools make you fast at building. They don't make you fast at knowing what to build."

**Always research first:**
1. Check if upstream already solved it
2. Check nixpkgs for existing patterns
3. Check if other flakes have the same problem
4. Read the code before changing it

**When to research vs. build:**

| Build it | Research first |
|----------|---------------|
| Version bumps | New packaging approaches |
| Hash updates | NixOS module design |
| Bug fixes in code you wrote | New CI workflows |
| Formatting fixes | Dependency management |
| | Upstream API changes |
