#!/bin/bash

VERSION_LIST=$(ls -d sfml/*/ | xargs -n 1 basename)

if [ $# -ne 1 ]; then
    echo "Usage: sudo $0 <version>"
    echo "Available versions: $(echo $VERSION_LIST | tr ' ' ', ')"
    exit 1
fi

VERSION=$1

if [ ! -d "sfml/$VERSION" ]; then
    echo "Error: version '$VERSION' not available."
    echo "Available versions: $(echo $VERSION_LIST | tr ' ' ', ')"
    exit 1
fi

echo "Switching SFML version to $VERSION..."

# Cleanup files
echo "Cleaning up old SFML files..."
rm -rf /usr/lib/cmake/SFML
rm -rf /usr/lib/cmake/CSFML
rm -rf /usr/include/SFML
rm -rf /usr/include/CSFML
rm -rf /usr/lib/libcsfml*.so*
rm -rf /usr/lib/libsfml*.so*
rm -rf /usr/lib/pckgconfig/sfml-*.pc
rm -rf /usr/lib/pckgconfig/csfml-*.pc

# Copy new files
echo "Copying new SFML files..."
cp -Pr sfml/$VERSION/cmake/* /usr/lib/
cp -Pr sfml/$VERSION/include/* /usr/include/
cp -P sfml/$VERSION/lib/* /usr/lib/
cp -P sfml/$VERSION/pkgconfig/* /usr/lib/pkgconfig/

# Reload library cache
ldconfig

echo "Switched SFML version to $VERSION"
