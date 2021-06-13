# jaz

**Ja**va in **Z**ig.

Parses Java class files and bytecode.

## Taking it for a spin

To try out jaz for yourself, install jvm 16, then run the following commands:
```bash
# Compiles Java source
javac test/src/jaztest/*.java

# Adds user path to javastd
echo "pub const conf = .{.javastd_path = \"/path/to/javastd\"};" > src/conf.zig

# Runs demo
zig build run
```
