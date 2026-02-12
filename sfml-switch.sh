#!/bin/bash

SFML_DIRECTORY=$HOME/my_scripts/sfml
VERSION_LIST=$(ls -d "$SFML_DIRECTORY"/*/ | xargs -n 1 basename)

if [ $# -ne 1 ]; then
    echo "Usage: sudo $0 <version>"
    echo "Available versions: $(echo $VERSION_LIST | tr ' ' ', ')"
    exit 1
fi

VERSION=$1

if [ ! -d "$SFML_DIRECTORY/$VERSION" ]; then
    echo "Error: version '$VERSION' not available."
    echo "Available versions: $(echo $VERSION_LIST | tr ' ' ', ')"
    exit 1
fi

echo "Switching SFML version to $VERSION..."

# Cleanup files
echo "Cleaning up old SFML files..."
sudo rm -rf /usr/lib/cmake/SFML
sudo rm -rf /usr/lib/cmake/CSFML
sudo rm -rf /usr/include/SFML
sudo rm -rf /usr/include/CSFML
sudo rm -rf /usr/lib/libcsfml*.so*
sudo rm -rf /usr/lib/libsfml*.so*
sudo rm -rf /usr/lib/pckgconfig/sfml-*.pc
sudo rm -rf /usr/lib/pckgconfig/csfml-*.pc

# Copy new files
echo "Copying new SFML files..."
sudo cp -Pr $SFML_DIRECTORY/$VERSION/cmake/* /usr/lib/
sudo cp -Pr $SFML_DIRECTORY/$VERSION/include/* /usr/include/
sudo cp -P $SFML_DIRECTORY/$VERSION/lib/* /usr/lib/
sudo cp -P $SFML_DIRECTORY/$VERSION/pkgconfig/* /usr/lib/pkgconfig/

# Reload library cache
sudo ldconfig

echo "Switched SFML version to $VERSION"
