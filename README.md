# Fluff Linux Calculator

A native Qt 6 calculator built for Fluff Linux

## Calculator modes

### Basic

Basic mode provides a familiar keypad for everyday arithmetic, percentages, parentheses, keyboard input, history, undo, and redo.

### Advanced

Advanced mode adds powers, roots, factorials, logarithms, trigonometric functions, rounding functions, constants, complex numbers, and degree, radian, or gradian angle units.

Expressions support convenient notation such as `2pi`, `2(3+4)`, `√9`, `∛8`, `⁵√32`, and `root(5,32)`.

### Financial

Financial mode includes compound term, depreciation, future value, present value, payment, rate, margin, and term calculations.

### Programming

Programming mode includes:

- Hexadecimal, decimal, octal, and binary input with live previews
- Signed word sizes from 8 bits through 4096 bits
- Boolean operations, shifts, rotations, byte swapping, and integer functions
- A clickable bit field with rows of eight bits
- A programmer keypad with hexadecimal digits
- A side history panel
- Remembered keypad or bit field selection

### Conversion

Conversion mode supports length, mass, area, volume, temperature, time, speed, data size, and angle units.

## Calculation features

- Arbitrary precision real, integer, and complex calculations using Rug, GMP, MPFR, and MPC
- At least 1024 bits of internal precision
- Automatic, fixed, scientific, and engineering output formats
- Up to 100 decimal places
- Optional digit grouping
- Calculator style percentages such as `100-50% = 50`
- Implicit multiplication
- Typed expressions and pasted Unicode multiplication or division symbols
- High precision complex roots, powers, logarithms, and trigonometric functions
- Per mode window size and maximized state memory
- Theme aware Qt Quick Controls interface

## Build

### Requirements

The project requires Rust, CMake, Ninja, a C++ compiler, Qt 6 Base, Qt 6 Declarative, Qt 6 Wayland, GMP, MPFR, and MPC.

On Arch Linux or Fluff Linux, install the build dependencies with:

```sh
sudo pacman -S --needed base-devel rust cmake ninja qt6-base qt6-declarative qt6-wayland gmp mpfr libmpc
```

Build the release binary:

```sh
cargo build --release --locked
```

Run it directly:

```sh
./target/release/flufflinux-calculator
```

## Tests

Run the Rust test suite:

```sh
cargo test --locked
```

Run the QML interface tests:

```sh
QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/qml -import qml
```

Validate every translation catalog and desktop entry locale:

```sh
make check-translations
```

## Packaging

Build the release binary and create a ready to package filesystem tree:

```sh
make fakeroot
```

The generated tree contains the executable, desktop entry, application icon, AppStream metadata, licenses, and compiled language catalogs under their final `/usr` paths.

Run the staged application without installing it:

```sh
./fakeroot/usr/bin/flufflinux-calculator
```

Create a pacman package archive:

```sh
bsdtar --zstd -cf flufflinux-calculator-2026.09-2-x86_64.pkg.tar.zst -C fakeroot .PKGINFO usr
```

Package build systems can install into their own staging directory:

```sh
make build
make DESTDIR="$pkgdir" install
```

## Translating

Translation sources are stored in `translations`. Qt Linguist can be used to edit an existing `.ts` catalog.

```sh
linguist translations/flufflinux-calculator_de.ts
```

After changing visible QML text or adding a language, update the catalogs:

```sh
make update-translations
```

Compile and validate them:

```sh
make translations
make check-translations
```

Test a specific language locally:

```sh
LANGUAGE=de ./target/release/flufflinux-calculator
```

See [TRANSLATING.md](TRANSLATING.md) for the complete editing, testing, and new language workflow.

## Settings

Preferences and window state are stored in `$XDG_CONFIG_HOME/flufflinux-calculator.conf`, or `~/.config/flufflinux-calculator.conf` when `XDG_CONFIG_HOME` is not set.

## License

Fluff Linux Calculator is distributed under the GNU General Public License v3.0 or later. See [LICENSE](LICENSE).
