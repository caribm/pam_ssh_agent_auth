# PAM SSH Agent Auth - Universal Build System

## Quick Start

To build a universal PAM module with statically linked OpenSSL:

```bash
./build_with_openssl.sh
```

This single command will:
1. Download OpenSSL 3.6.1 source code
2. Build OpenSSL for x86_64 architecture
3. Build OpenSSL for arm64 architecture  
4. Create universal (fat) OpenSSL libraries
5. Build the PAM module with OpenSSL statically linked
6. Create `pam_ssh_agent_auth_universal.so` - a universal binary

## Build Time

Approximately 6-12 minutes depending on your CPU.

## Requirements

- macOS 15.0 or higher
- Xcode Command Line Tools
- Internet connection (to download OpenSSL)

## Custom OpenSSL Version

To use a different OpenSSL version:

```bash
OPENSSL_VERSION=3.5.0 ./build_with_openssl.sh
```

## Output

The build creates:
- `pam_ssh_agent_auth_universal.so` - Universal PAM module (x86_64 + arm64)
- Build artifacts in `/tmp/pam_ssh_agent_auth/`

## Installation

```bash
sudo cp pam_ssh_agent_auth_universal.so /usr/local/lib/security/
sudo chmod 644 /usr/local/lib/security/pam_ssh_agent_auth_universal.so
```

## Verification

```bash
# Check architecture support
file pam_ssh_agent_auth_universal.so
lipo -info pam_ssh_agent_auth_universal.so

# Verify OpenSSL is statically linked (no OpenSSL in dependencies)
otool -L pam_ssh_agent_auth_universal.so
```

## Documentation

See `Agents.MD` for complete documentation including:
- Detailed build process
- Manual build steps
- Troubleshooting
- Configuration options
- Security considerations

## Build Scripts

- `build_with_openssl.sh` - Main build script (downloads and builds everything)
- `build_pam_module.sh` - PAM module build script (called by main script)
- `Agents.MD` - Complete documentation

## Clean Build

To force a fresh build:

```bash
rm -rf /tmp/pam_ssh_agent_auth
./build_with_openssl.sh
```

## Notes

- OpenSSL is compiled from source and statically linked
- No external OpenSSL installation required
- Module works on both Intel and Apple Silicon Macs
- Target systems need macOS 15.0 or higher
