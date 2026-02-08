# PAM SSH Agent Auth - Universal Build with Static OpenSSL

## Overview
This directory contains the source code for pam_ssh_agent_auth, configured to build as a universal binary (x86_64 + arm64) for macOS 15 and higher with OpenSSL statically linked.

**Build Status**: ✅ **VALIDATED** (February 8, 2026)
- OpenSSL 3.6.1 statically linked
- Universal binary verified (x86_64 + arm64)
- Module size: ~8.4MB
- No dynamic OpenSSL dependencies

## Build Requirements
- macOS 15.0 or higher
- Xcode Command Line Tools
- No external OpenSSL installation required (built from source)

## Architecture
- **Target Architectures**: x86_64 and arm64 (universal binary)
- **OpenSSL**: Statically linked (embedded within the PAM module)
- **Minimum macOS Version**: 15.0
- **PAM Module Output**: `pam_ssh_agent_auth_universal.so`

## Build Process

### Quick Build
```bash
./build_with_openssl.sh
```

This script will:
1. Download the latest OpenSSL 3.x source code
2. Build OpenSSL as universal static libraries (x86_64 + arm64)
3. Build pam_ssh_agent_auth with OpenSSL statically linked
4. Create a universal binary PAM module

### Manual Build Steps

#### 1. Download and Build OpenSSL
```bash
# Download OpenSSL source
curl -O https://www.openssl.org/source/openssl-3.6.1.tar.gz
tar -xzf openssl-3.6.1.tar.gz

# Build for x86_64
cd openssl-3.6.1
./Configure darwin64-x86_64-cc \
    --prefix=/tmp/pam_ssh_agent_auth/openssl/x86_64 \
    no-shared \
    -mmacosx-version-min=15.0
make clean
make -j$(sysctl -n hw.ncpu)
make install_sw

# Build for arm64
make clean
./Configure darwin64-arm64-cc \
    --prefix=/tmp/pam_ssh_agent_auth/openssl/arm64 \
    no-shared \
    -mmacosx-version-min=15.0
make -j$(sysctl -n hw.ncpu)
make install_sw

# Create universal libraries
mkdir -p /tmp/pam_ssh_agent_auth/openssl/universal/{lib,include}
cp -R /tmp/pam_ssh_agent_auth/openssl/arm64/include/* \
      /tmp/pam_ssh_agent_auth/openssl/universal/include/

lipo -create \
    /tmp/pam_ssh_agent_auth/openssl/x86_64/lib/libcrypto.a \
    /tmp/pam_ssh_agent_auth/openssl/arm64/lib/libcrypto.a \
    -output /tmp/pam_ssh_agent_auth/openssl/universal/lib/libcrypto.a

lipo -create \
    /tmp/pam_ssh_agent_auth/openssl/x86_64/lib/libssl.a \
    /tmp/pam_ssh_agent_auth/openssl/arm64/lib/libssl.a \
    -output /tmp/pam_ssh_agent_auth/openssl/universal/lib/libssl.a
```

#### 2. Build PAM Module
```bash
./build_pam_module.sh
```

## Build Artifacts

### Primary Output
- **pam_ssh_agent_auth_universal.so** - Universal PAM module (x86_64 + arm64)

### Verification
```bash
# Check architecture support
file pam_ssh_agent_auth_universal.so
lipo -info pam_ssh_agent_auth_universal.so

# Check library dependencies (should only show system libraries)
otool -L pam_ssh_agent_auth_universal.so

# Extract symbols
nm -g pam_ssh_agent_auth_universal.so | grep -i openssl
```

## Installation

```bash
# Copy to PAM modules directory
sudo cp pam_ssh_agent_auth_universal.so /usr/local/lib/security/

# Set proper permissions
sudo chmod 644 /usr/local/lib/security/pam_ssh_agent_auth_universal.so
```

## OpenSSL Version Information

The build system automatically downloads the latest OpenSSL 3.x LTS release. 

To update OpenSSL:
1. Run `./build_with_openssl.sh` - it will fetch the latest version
2. Or manually specify version in the script

Current default: OpenSSL 3.6.1

## Build Configuration

### Compiler Flags
- `-arch x86_64 -arch arm64` - Universal binary
- `-mmacosx-version-min=15.0` - Minimum macOS version
- `-fPIC` - Position independent code
- `-fstack-protector-all` - Stack protection
- `-U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0` - Disable fortification (compatibility)

### Linker Flags
- Static linking of libssl.a and libcrypto.a
- Dynamic linking of system PAM library
- Frameworks: CoreFoundation, Security

## Troubleshooting

### Issue: Symbol not found for architecture
**Solution**: Ensure OpenSSL was built for both architectures and universal libraries were created properly.

### Issue: OpenSSL version mismatch
**Solution**: Clean build and rebuild OpenSSL from source.

### Issue: Permission denied on installation
**Solution**: Use sudo for installation to system directories.

### Issue: PAM module not loading
**Solution**: Check file permissions (should be 644) and ownership (root:wheel).

## Directory Structure

```
pam_ssh_agent_auth-pam_ssh_agent_auth-0.10.4/
├── Agents.MD                          # This file
├── build_with_openssl.sh              # Main build script (downloads OpenSSL)
├── build_pam_module.sh                # PAM module build script
├── pam_ssh_agent_auth_universal.so    # Output universal binary
├── openssl-build/                     # Temporary OpenSSL build directory
│   ├── x86_64/                        # x86_64 build
│   ├── arm64/                         # arm64 build
│   └── universal/                     # Universal libraries
└── [source files...]
```

## Notes

- The PAM module is self-contained with OpenSSL statically linked
- No external OpenSSL installation is required on target systems
- The module works on both Intel and Apple Silicon Macs
- OpenSSL symbols are embedded and won't conflict with system OpenSSL

## Build Time

- OpenSSL build (both architectures): ~5-10 minutes
- PAM module build: ~1-2 minutes
- Total: ~6-12 minutes (depending on CPU)

## Security Considerations

- Always use the latest OpenSSL version to include security patches
- Rebuild periodically when new OpenSSL versions are released
- Static linking means you must rebuild the entire module for OpenSSL updates

## References

- OpenSSL: https://www.openssl.org/
- pam_ssh_agent_auth: https://github.com/jbeverly/pam_ssh_agent_auth
- macOS PAM: man pam (on macOS system)
