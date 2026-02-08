#!/bin/bash
set -e

# Build script for pam_ssh_agent_auth with statically linked OpenSSL
# This script downloads OpenSSL source, builds it for both architectures,
# and creates a universal PAM module with OpenSSL embedded

echo "======================================================================"
echo "PAM SSH Agent Auth - Universal Build with Static OpenSSL"
echo "======================================================================"
echo ""

# Configuration
OPENSSL_VERSION="${OPENSSL_VERSION:-3.6.1}"
OPENSSL_URL="https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz"
MIN_MACOS="15.0"
BUILD_DIR="/tmp/pam_ssh_agent_auth"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NUM_CPUS=$(sysctl -n hw.ncpu)

# Derived paths
OPENSSL_BUILD="${BUILD_DIR}/openssl"
OPENSSL_SRC="${BUILD_DIR}/openssl-${OPENSSL_VERSION}"
OPENSSL_ARCHIVE="${BUILD_DIR}/openssl-${OPENSSL_VERSION}.tar.gz"

echo "Configuration:"
echo "  OpenSSL Version: ${OPENSSL_VERSION}"
echo "  Build Directory: ${BUILD_DIR}"
echo "  Source Directory: ${SCRIPT_DIR}"
echo "  CPU Cores: ${NUM_CPUS}"
echo "  Minimum macOS: ${MIN_MACOS}"
echo ""

# Create build directories
echo "Creating build directories..."
mkdir -p "${BUILD_DIR}"
mkdir -p "${OPENSSL_BUILD}"/{x86_64,arm64,universal}/{lib,include}

# Download OpenSSL if not already present
if [ -f "${OPENSSL_ARCHIVE}" ]; then
    echo "OpenSSL archive already exists: ${OPENSSL_ARCHIVE}"
else
    echo "Downloading OpenSSL ${OPENSSL_VERSION}..."
    curl -L "${OPENSSL_URL}" -o "${OPENSSL_ARCHIVE}"
    echo "Download complete."
fi

# Extract OpenSSL
if [ -d "${OPENSSL_SRC}" ]; then
    echo "Removing existing OpenSSL source directory..."
    rm -rf "${OPENSSL_SRC}"
fi

echo "Extracting OpenSSL source..."
tar -xzf "${OPENSSL_ARCHIVE}" -C "${BUILD_DIR}"

# Build OpenSSL for x86_64
echo ""
echo "======================================================================"
echo "Building OpenSSL for x86_64..."
echo "======================================================================"
cd "${OPENSSL_SRC}"

./Configure darwin64-x86_64-cc \
    --prefix="${OPENSSL_BUILD}/x86_64" \
    --openssldir="${OPENSSL_BUILD}/x86_64" \
    no-shared \
    no-tests \
    -mmacosx-version-min=${MIN_MACOS}

echo "Compiling OpenSSL (x86_64) using ${NUM_CPUS} cores..."
make clean > /dev/null 2>&1 || true
make -j${NUM_CPUS}

echo "Installing OpenSSL (x86_64)..."
make install_sw > /dev/null

echo "OpenSSL x86_64 build complete."

# Verify x86_64 build
if [ ! -f "${OPENSSL_BUILD}/x86_64/lib/libcrypto.a" ]; then
    echo "ERROR: x86_64 libcrypto.a not found!"
    exit 1
fi

lipo -info "${OPENSSL_BUILD}/x86_64/lib/libcrypto.a"

# Build OpenSSL for arm64
echo ""
echo "======================================================================"
echo "Building OpenSSL for arm64..."
echo "======================================================================"
cd "${OPENSSL_SRC}"

make clean > /dev/null 2>&1 || true

./Configure darwin64-arm64-cc \
    --prefix="${OPENSSL_BUILD}/arm64" \
    --openssldir="${OPENSSL_BUILD}/arm64" \
    no-shared \
    no-tests \
    -mmacosx-version-min=${MIN_MACOS}

echo "Compiling OpenSSL (arm64) using ${NUM_CPUS} cores..."
make -j${NUM_CPUS}

echo "Installing OpenSSL (arm64)..."
make install_sw > /dev/null

echo "OpenSSL arm64 build complete."

# Verify arm64 build
if [ ! -f "${OPENSSL_BUILD}/arm64/lib/libcrypto.a" ]; then
    echo "ERROR: arm64 libcrypto.a not found!"
    exit 1
fi

lipo -info "${OPENSSL_BUILD}/arm64/lib/libcrypto.a"

# Create universal libraries
echo ""
echo "======================================================================"
echo "Creating universal (fat) OpenSSL libraries..."
echo "======================================================================"

# Copy headers from arm64 (they should be identical)
echo "Copying OpenSSL headers..."
cp -R "${OPENSSL_BUILD}/arm64/include/"* "${OPENSSL_BUILD}/universal/include/"

# Create universal libcrypto.a
echo "Creating universal libcrypto.a..."
lipo -create \
    "${OPENSSL_BUILD}/x86_64/lib/libcrypto.a" \
    "${OPENSSL_BUILD}/arm64/lib/libcrypto.a" \
    -output "${OPENSSL_BUILD}/universal/lib/libcrypto.a"

# Create universal libssl.a
echo "Creating universal libssl.a..."
lipo -create \
    "${OPENSSL_BUILD}/x86_64/lib/libssl.a" \
    "${OPENSSL_BUILD}/arm64/lib/libssl.a" \
    -output "${OPENSSL_BUILD}/universal/lib/libssl.a"

# Verify universal libraries
echo ""
echo "Verifying universal libraries:"
echo "  libcrypto.a:"
lipo -info "${OPENSSL_BUILD}/universal/lib/libcrypto.a"
echo "  libssl.a:"
lipo -info "${OPENSSL_BUILD}/universal/lib/libssl.a"

# Get library sizes
CRYPTO_SIZE=$(du -h "${OPENSSL_BUILD}/universal/lib/libcrypto.a" | cut -f1)
SSL_SIZE=$(du -h "${OPENSSL_BUILD}/universal/lib/libssl.a" | cut -f1)
echo ""
echo "Library sizes:"
echo "  libcrypto.a: ${CRYPTO_SIZE}"
echo "  libssl.a: ${SSL_SIZE}"

# Configure and build PAM module
echo ""
echo "======================================================================"
echo "Configuring PAM SSH Agent Auth..."
echo "======================================================================"

cd "${SCRIPT_DIR}"

# Configure is broken on modern macOS, so we'll create files from templates
echo "Creating configuration files from templates (configure is broken on modern macOS)..."

# Create base files from templates
cp config.h.in config.h
cp Makefile.in Makefile
cp openbsd-compat/Makefile.in openbsd-compat/Makefile

# Fix config.h for macOS - only define things that exist on macOS
echo "Configuring for macOS..."

# Type sizes (critical for defines.h)
cat >> config.h << 'MACOSCONFIG'

/* macOS type sizes */
#define SIZEOF_CHAR 1
#define SIZEOF_SHORT_INT 2  
#define SIZEOF_INT 4
#define SIZEOF_LONG_INT 8
#define SIZEOF_LONG_LONG_INT 8

/* macOS has these types */
#define HAVE_U_INT 1
#define HAVE_INTXX_T 1
#define HAVE_U_INTXX_T 1
#define HAVE_INT64_T 1
#define HAVE_U_INT64_T 1
#define HAVE_U_CHAR 1
#define HAVE_SIZE_T 1
#define HAVE_SSIZE_T 1
#define HAVE_CLOCK_T 1
#define HAVE_SA_FAMILY_T 1
#define HAVE_PID_T 1
#define HAVE_MODE_T 1
#define SIG_ATOMIC_T 1

/* macOS system structures */
#define HAVE_STRUCT_ADDRINFO 1
#define HAVE_STRUCT_IN6_ADDR 1
#define HAVE_STRUCT_SOCKADDR_IN6 1
#define HAVE_STRUCT_SOCKADDR_STORAGE 1
#define HAVE_STRUCT_TIMESPEC 1
#define HAVE_STRUCT_TIMEVAL 1

/* macOS system functions */
#define HAVE_SNPRINTF 1
#define HAVE_VSNPRINTF 1
#define HAVE_STRLCPY 1
#define HAVE_STRLCAT 1
#define HAVE_SETENV 1
#define HAVE_UNSETENV 1
#define HAVE_UTIMES 1
#define HAVE_GETGROUPLIST 1
#define HAVE_RRESVPORT_AF 1
#define HAVE_TRUNCATE 1
#define HAVE_NANOSLEEP 1
#define HAVE_TCGETPGRP 1
#define HAVE_TCSENDBREAK 1

/* macOS system headers */
#define HAVE_SYS_UN_H 1
#define HAVE_FCNTL_H 1
#define HAVE_UNISTD_H 1
#define HAVE_INET_NTOP 1
#define HAVE_VA_COPY 1
#define HAVE_SECURITY_PAM_APPL_H 1

/* SSH and PAM configuration */
#define SSH_RAND_HELPER "/dev/urandom"
MACOSCONFIG

# macOS-specific features
sed -i '' 's/#undef HAVE_ATTRIBUTE__NONNULL__/#define HAVE_ATTRIBUTE__NONNULL__ 1/g' config.h
sed -i '' 's/#undef HAVE_BUNDLE/#define HAVE_BUNDLE 1/g' config.h
sed -i '' 's/#undef SETEUID_BREAKS_SETUID/#define SETEUID_BREAKS_SETUID 1/g' config.h
sed -i '' 's/#undef BROKEN_SETREUID/#define BROKEN_SETREUID 1/g' config.h
sed -i '' 's/#undef BROKEN_SETREGID/#define BROKEN_SETREGID 1/g' config.h
sed -i '' 's/#undef BROKEN_GLOB/#define BROKEN_GLOB 1/g' config.h

# Clone ed25519-donna submodule if not present
if [ ! -d "${SCRIPT_DIR}/ed25519-donna/.git" ] && [ ! -f "${SCRIPT_DIR}/ed25519-donna/ed25519.c" ]; then
    echo "Cloning ed25519-donna..."
    rm -rf "${SCRIPT_DIR}/ed25519-donna"
    git clone https://github.com/floodyberry/ed25519-donna.git "${SCRIPT_DIR}/ed25519-donna"
fi

# Update Makefile with correct paths and flags
sed -i '' "s|^CPPFLAGS=.*|CPPFLAGS=-I. -I\$(srcdir) -I./ed25519-donna -I${OPENSSL_BUILD}/universal/include -DHAVE_CONFIG_H|g" Makefile
sed -i '' "s|^LDFLAGS=.*|LDFLAGS=-L. -Lopenbsd-compat/ -L${OPENSSL_BUILD}/universal/lib -arch x86_64 -arch arm64 -mmacosx-version-min=${MIN_MACOS}|g" Makefile
sed -i '' "s|^CFLAGS=.*|CFLAGS=-arch x86_64 -arch arm64 -mmacosx-version-min=${MIN_MACOS} -Wno-implicit-function-declaration -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0 -fPIC -Wall -Wno-deprecated-declarations|g" Makefile
sed -i '' "s|^LIBS=.*|LIBS=${OPENSSL_BUILD}/universal/lib/libssl.a ${OPENSSL_BUILD}/universal/lib/libcrypto.a -lpam|g" Makefile

# Update openbsd-compat Makefile  
sed -i '' "s|^CPPFLAGS=.*|CPPFLAGS=-I. -I.. -I\$(srcdir) -I\$(srcdir)/.. -I../ed25519-donna -I${OPENSSL_BUILD}/universal/include -DHAVE_CONFIG_H|g" openbsd-compat/Makefile
sed -i '' "s|^CFLAGS=.*|CFLAGS=-arch x86_64 -arch arm64 -mmacosx-version-min=${MIN_MACOS} -Wno-implicit-function-declaration -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0 -fPIC -Wall -Wno-deprecated-declarations|g" openbsd-compat/Makefile

echo "Configuration complete."

echo ""
echo "======================================================================"
echo "Building PAM SSH Agent Auth module..."
echo "======================================================================"

if [ ! -f "./build_pam_module.sh" ]; then
    echo "ERROR: build_pam_module.sh not found in ${SCRIPT_DIR}"
    exit 1
fi

chmod +x ./build_pam_module.sh
./build_pam_module.sh

# Final verification
echo ""
echo "======================================================================"
echo "Build Complete!"
echo "======================================================================"
echo ""

if [ -f "${SCRIPT_DIR}/pam_ssh_agent_auth_universal.so" ]; then
    echo "✓ PAM module created: pam_ssh_agent_auth_universal.so"
    echo ""
    echo "Architecture information:"
    file "${SCRIPT_DIR}/pam_ssh_agent_auth_universal.so"
    lipo -info "${SCRIPT_DIR}/pam_ssh_agent_auth_universal.so"
    
    echo ""
    echo "Library dependencies:"
    otool -L "${SCRIPT_DIR}/pam_ssh_agent_auth_universal.so"
    
    MODULE_SIZE=$(du -h "${SCRIPT_DIR}/pam_ssh_agent_auth_universal.so" | cut -f1)
    echo ""
    echo "Module size: ${MODULE_SIZE}"
    
    echo ""
    echo "Installation:"
    echo "  sudo cp pam_ssh_agent_auth_universal.so /usr/local/lib/security/"
    echo "  sudo chmod 644 /usr/local/lib/security/pam_ssh_agent_auth_universal.so"
else
    echo "ERROR: PAM module build failed!"
    exit 1
fi

echo ""
echo "Build artifacts preserved in: ${BUILD_DIR}"
echo "To clean up: rm -rf ${BUILD_DIR}"
