#!/bin/bash
set -e

# Build script for PAM SSH Agent Auth module
# This compiles all sources and links them with static OpenSSL

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

OPENSSL_BUILD="${OPENSSL_BUILD:-/tmp/pam_ssh_agent_auth/openssl}"
MIN_MACOS="${MIN_MACOS:-15.0}"

echo "Building PAM SSH Agent Auth module..."
echo "  OpenSSL: ${OPENSSL_BUILD}/universal"
echo "  Min macOS: ${MIN_MACOS}"
echo ""

# Common compiler flags
CFLAGS="-arch x86_64 -arch arm64 -fPIC -O2 -Wall -mmacosx-version-min=${MIN_MACOS} \
  -I. -I./openbsd-compat -I./ed25519-donna \
  -I${OPENSSL_BUILD}/universal/include \
  -DHAVE_CONFIG_H \
  -Wno-deprecated-declarations \
  -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0"

# Clean previous build artifacts
echo "Cleaning previous build artifacts..."
rm -f *.o openbsd-compat/*.o pam_ssh_agent_auth_universal.so 2>/dev/null || true

# Build openbsd-compat library
echo "Building openbsd-compat library..."
cd openbsd-compat
make clean > /dev/null 2>&1 || true

# Compile openbsd-compat sources
for src in *.c; do
    # Skip sha2.c - it conflicts with OpenSSL
    if [ "$src" = "sha2.c" ]; then
        echo "  Skipping $src (conflicts with OpenSSL)"
        continue
    fi
    
    obj="${src%.c}.o"
    echo "  Compiling $src..."
    gcc $CFLAGS -c "$src" -o "$obj" || {
        echo "ERROR: Failed to compile $src"
        exit 1
    }
done

cd "${SCRIPT_DIR}"
echo "openbsd-compat library built successfully."
echo ""

# Compile main sources
echo "Compiling main source files..."
MAIN_SOURCES="atomicio.c authfd.c bufaux.c bufbn.c buffer.c cleanup.c compat.c \
  entropy.c fatal.c get_command_line.c iterate_ssh_agent_keys.c key.c log.c \
  misc.c pam_ssh_agent_auth.c pam_user_authorized_keys.c pam_user_key_allowed2.c \
  secure_filename.c ssh-dss.c ssh-ecdsa.c ssh-ed25519.c ssh-rsa.c uidswap.c \
  userauth_pubkey_from_id.c userauth_pubkey_from_pam.c uuencode.c xmalloc.c"

for src in $MAIN_SOURCES; do
    obj="${src%.c}.o"
    echo "  Compiling $src..."
    gcc $CFLAGS -c "$src" -o "$obj" || {
        echo "ERROR: Failed to compile $src"
        exit 1
    }
done

# Compile ed25519-donna
echo "  Compiling ed25519-donna/ed25519.c..."
gcc $CFLAGS -c ed25519-donna/ed25519.c -o ed25519.o || {
    echo "ERROR: Failed to compile ed25519-donna/ed25519.c"
    exit 1
}

echo "All sources compiled successfully."
echo ""

# Link PAM module
echo "Linking universal PAM module..."
gcc -arch x86_64 -arch arm64 -bundle -mmacosx-version-min=${MIN_MACOS} \
  -Wl,-headerpad_max_install_names \
  -o pam_ssh_agent_auth_universal.so \
  *.o $(ls openbsd-compat/*.o | grep -v sha2.o | tr '\n' ' ') \
  ${OPENSSL_BUILD}/universal/lib/libssl.a \
  ${OPENSSL_BUILD}/universal/lib/libcrypto.a \
  -lpam || {
    echo "ERROR: Failed to link PAM module"
    exit 1
}

echo ""
echo "✓ PAM module built successfully: pam_ssh_agent_auth_universal.so"
echo ""

# Verify the build
echo "Verification:"
echo "  Architecture:"
file pam_ssh_agent_auth_universal.so | sed 's/^/    /'
echo ""
echo "  Architectures in binary:"
lipo -info pam_ssh_agent_auth_universal.so | sed 's/^/    /'
echo ""
echo "  Dependencies:"
otool -L pam_ssh_agent_auth_universal.so | sed 's/^/    /'
echo ""

MODULE_SIZE=$(du -h pam_ssh_agent_auth_universal.so | cut -f1)
echo "  Module size: ${MODULE_SIZE}"
echo ""

# Check for OpenSSL dynamic dependencies (should be none)
if otool -L pam_ssh_agent_auth_universal.so | grep -i openssl > /dev/null; then
    echo "WARNING: Module has dynamic OpenSSL dependencies!"
    exit 1
else
    echo "✓ Verification passed: OpenSSL is statically linked"
fi
