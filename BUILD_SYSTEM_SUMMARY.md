# PAM SSH Agent Auth - Build System Summary

## Overview

This directory contains a complete, production-ready build system for creating universal (x86_64 + arm64) PAM SSH Agent Auth modules with statically linked OpenSSL for macOS 15+.

## What Was Created

### 1. Documentation Files
- **Agents.MD** - Complete technical documentation and reference
- **README_BUILD.md** - Quick start guide
- **BUILD_SYSTEM_SUMMARY.md** - This file

### 2. Build Scripts
- **build_with_openssl.sh** - Main build script (downloads and builds everything)
- **build_pam_module.sh** - PAM module compilation script

### 3. Key Features
- ✅ Downloads and builds OpenSSL from source (currently 3.6.1)
- ✅ Creates universal binaries (x86_64 + arm64)
- ✅ Statically links OpenSSL (self-contained, no dependencies)
- ✅ Bypasses broken configure script (works on modern macOS)
- ✅ Configurable OpenSSL version via environment variable
- ✅ Suitable for long-term maintenance

## Why Configure Was Bypassed

The original `./configure` script fails on modern macOS due to:
1. Compiler sanity checks that don't work with modern Xcode toolchains
2. Hardcoded assumptions about macOS SDK paths
3. Compatibility issues with macOS 15+ system headers

**Solution**: The build system creates configuration files directly from templates and applies macOS-specific patches. This is:
- More reliable than fixing the ancient autoconf configure script
- Easier to maintain
- Works consistently across different macOS versions

## Future Usage

### Basic Build (Most Common)
```bash
./build_with_openssl.sh
```

This downloads OpenSSL 3.6.1, builds it for both architectures, and creates the universal PAM module.

### Custom OpenSSL Version
```bash
OPENSSL_VERSION=3.7.0 ./build_with_openssl.sh
```

### Rebuild PAM Module Only (OpenSSL already built)
```bash
./build_pam_module.sh
```

### Update to Latest OpenSSL

When a new OpenSSL version is released:

1. Edit `build_with_openssl.sh` and update line 14:
   ```bash
   OPENSSL_VERSION="${OPENSSL_VERSION:-3.X.Y}"
   ```

2. Run the build:
   ```bash
   ./build_with_openssl.sh
   ```

3. Update documentation (`Agents.MD` and `README_BUILD.md`) with the new version number

## Build Output

### Location
`pam_ssh_agent_auth_universal.so` - Created in this directory

### Verification
```bash
# Check architecture support
file pam_ssh_agent_auth_universal.so
lipo -info pam_ssh_agent_auth_universal.so

# Verify static OpenSSL (should only show system libraries, NO OpenSSL)
otool -L pam_ssh_agent_auth_universal.so
```

### Expected Dependencies
The module should only depend on:
- System libraries (libc, libSystem)
- PAM library (libpam)
- macOS frameworks (CoreFoundation, Security)

**NO** OpenSSL libraries should appear in dependencies - they're statically linked.

## Installation

```bash
# Copy to PAM modules directory
sudo cp pam_ssh_agent_auth_universal.so /usr/local/lib/security/

# Set correct permissions
sudo chmod 644 /usr/local/lib/security/pam_ssh_agent_auth_universal.so
sudo chown root:wheel /usr/local/lib/security/pam_ssh_agent_auth_universal.so
```

## Maintenance Tasks

### Regular Updates
- **Check for OpenSSL updates**: Every 2-3 months or when security advisories are released
- **Rebuild after updates**: Always rebuild the PAM module when updating OpenSSL
- **Test after rebuilding**: Verify the module loads and functions correctly

### OpenSSL Security Advisories
Monitor: https://www.openssl.org/news/vulnerabilities.html

When a security update is released:
1. Update the version in `build_with_openssl.sh`
2. Run the build
3. Deploy the new module to all systems

## Build Artifacts

### Temporary Files (in /tmp)
```
/tmp/pam_ssh_agent_auth/
├── openssl-3.6.1/          # OpenSSL source code
├── openssl-3.6.1.tar.gz    # Downloaded archive
└── openssl/
    ├── x86_64/             # x86_64 OpenSSL build
    ├── arm64/              # arm64 OpenSSL build
    └── universal/          # Universal (fat) libraries
        ├── lib/
        │   ├── libcrypto.a # Universal libcrypto
        │   └── libssl.a    # Universal libssl
        └── include/        # OpenSSL headers
```

### Cleanup
```bash
# Remove build artifacts (keeps only the final .so module)
rm -rf /tmp/pam_ssh_agent_auth

# Clean local build files
make clean
rm -f *.o openbsd-compat/*.o *.a openbsd-compat/*.a
```

## Troubleshooting

### Build fails with "symbol not found"
**Cause**: OpenSSL libraries weren't built for both architectures  
**Solution**: Clean and rebuild: `rm -rf /tmp/pam_ssh_agent_auth && ./build_with_openssl.sh`

### Module doesn't load
**Cause**: Wrong architecture or missing dependencies  
**Solution**: Verify with `lipo -info` and `otool -L`

### OpenSSL download fails
**Cause**: Version doesn't exist or network issue  
**Solution**: Check https://www.openssl.org/source/ for available versions

### Compilation errors
**Cause**: Modified source files or incompatible Xcode version  
**Solution**: 
1. Ensure Xcode Command Line Tools are installed: `xcode-select --install`
2. Try with a clean source tree

## Technical Details

### Configuration Approach
Instead of using `./configure`, the build system:
1. Copies template files (`*.in` → final names)
2. Applies macOS-specific `#define` statements to `config.h`
3. Updates Makefile variables with correct paths and flags
4. Uses universal architecture flags throughout

### macOS-Specific Defines
The build system automatically configures these for macOS:
- `HAVE_SNPRINTF` - Use system snprintf
- `HAVE_VSNPRINTF` - Use system vsnprintf  
- `HAVE_BUNDLE` - macOS bundles support
- `HAVE_SECURITY_PAM_APPL_H` - PAM headers location
- `SETEUID_BREAKS_SETUID` - macOS security behavior
- `BROKEN_SETREUID` / `BROKEN_SETREGID` - macOS quirks

### Compiler Flags
- `-arch x86_64 -arch arm64` - Universal binary
- `-mmacosx-version-min=15.0` - Minimum macOS version
- `-Wno-deprecated-declarations` - Suppress OpenSSL 3.x deprecation warnings
- `-U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0` - Disable fortification for compatibility

## Long-Term Sustainability

This build system is designed for:
- ✅ **Easy updates**: Just change version number
- ✅ **Reproducible builds**: Same inputs = same output
- ✅ **No external dependencies**: Downloads everything needed
- ✅ **Self-documenting**: Comprehensive documentation included
- ✅ **Future-proof**: Doesn't rely on broken configure script

### Version Control
If using git, commit these files:
- `Agents.MD`
- `README_BUILD.md`
- `BUILD_SYSTEM_SUMMARY.md`
- `build_with_openssl.sh`
- `build_pam_module.sh`

**Do NOT commit**:
- `pam_ssh_agent_auth_universal.so` (binary output)
- `config.h`, `Makefile` (generated files)
- `*.o`, `*.a` (build artifacts)

## Success Criteria

A successful build produces:
1. ✅ File `pam_ssh_agent_auth_universal.so` exists
2. ✅ Contains both x86_64 and arm64 architectures
3. ✅ Size approximately 1-2 MB
4. ✅ No OpenSSL dynamic library dependencies
5. ✅ Module loads without errors

## Support

For issues or questions:
1. Check this documentation first
2. Review `Agents.MD` for detailed information
3. Verify OpenSSL version exists at https://www.openssl.org/source/
4. Ensure Xcode Command Line Tools are up to date

## Summary

You now have a complete, production-ready build system that:
- Downloads and compiles the latest OpenSSL (3.6.1)
- Creates universal binaries for both Intel and Apple Silicon
- Produces self-contained PAM modules with no external dependencies
- Bypasses the broken configure script for reliable builds on modern macOS
- Is easy to maintain and update for years to come

**Next Steps**: Run `./build_with_openssl.sh` to create your first build!
