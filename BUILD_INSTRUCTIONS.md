# Build Instructions

## Integration into OpenWrt Build System

To properly integrate this LuCI application into the OpenWrt build system, follow these steps:

### Method 1: Using Symbolic Link (Recommended for Development)

```bash
# Clone or download OpenWrt source
git clone https://github.com/openwrt/openwrt.git
cd openwrt

# Update and install feeds
./scripts/feeds update -a
./scripts/feeds install -a

# Create symbolic link to luci-app-tvgate
ln -s /absolute/path/to/luci-app-tvgate feeds/luci/applications/luci-app-tvgate

# Update feeds
./scripts/feeds update luci
./scripts/feeds install luci-app-tvgate
```

### Method 2: Copy to Feeds Directory

```bash
# Clone or download OpenWrt source
git clone https://github.com/openwrt/openwrt.git
cd openwrt

# Update and install feeds
./scripts/feeds update -a
./scripts/feeds install -a

# Copy luci-app-tvgate to feeds directory
cp -r /absolute/path/to/luci-app-tvgate feeds/luci/applications/

# Update feeds
./scripts/feeds update luci
./scripts/feeds install luci-app-tvgate
```

## Configuration

After integration, configure the firmware:

```bash
# Open configuration menu
make menuconfig

# Navigate to:
# -> LuCI
#   -> Applications
#     -> luci-app-tvgate <*>
```

## Compilation

Compile the package or full firmware:

```bash
# Compile only luci-app-tvgate
make package/luci-app-tvgate/compile V=s

# Or compile the whole firmware (if built-in)
make V=s
```

## Troubleshooting

If you encounter the error:
```
make[1]: *** No rule to make target 'package/luci-app-tvgate/download'. Stop.
```

This means the package is not properly integrated into the build system. Ensure that:

1. The package is located in `feeds/luci/applications/luci-app-tvgate/`
2. Feeds have been updated with `./scripts/feeds update luci`
3. The package has been installed with `./scripts/feeds install luci-app-tvgate`

The error occurs because the build system is looking for the package in the main `package/` directory rather than in the `feeds/luci/applications/` directory where LuCI applications belong.

If you encounter kernel module related errors like:
```
make[2]: *** No rule to make target '/root/lede/build_dir/.../linux-6.12.61/.config'
```

These are usually unrelated to LuCI applications and indicate issues with the build environment or kernel configuration. Try these solutions:

1. Clean your build directory:
   ```bash
   make clean
   ./scripts/feeds update -a
   ./scripts/feeds install -a
   ```

2. Ensure kernel configuration is properly set:
   ```bash
   make defconfig
   ```

3. If using a custom LEDE/OpenWrt tree, make sure all submodules are properly initialized:
   ```bash
   git submodule update --init --recursive
   ```