#[cfg(test)]
use crate::engine::{evaluate, format_value};
use crate::{engine::AngleUnit, precise};
use cxx_qt::CxxQtType;
use cxx_qt_lib::QString;
use rug::Integer;
use std::{
    env, fs,
    io::{self, ErrorKind},
    path::PathBuf,
    pin::Pin,
};

const WRAP_HINT: char = '\u{200b}';
const CONFIG_FILE_NAME: &str = "flufflinux-calculator.conf";

fn add_wrap_hints(input: &str) -> String {
    let chars: Vec<char> = input.chars().filter(|c| *c != WRAP_HINT).collect();
    let mut output = String::with_capacity(input.len());

    for (index, character) in chars.iter().copied().enumerate() {
        output.push(character);
        if !matches!(
            character,
            '+' | '-' | '−' | '*' | '×' | '/' | '÷' | '^' | '∧' | '∨' | '⊻'
        ) {
            continue;
        }

        let previous = chars[..index]
            .iter()
            .rposition(|c| !c.is_whitespace())
            .map(|position| (position, chars[position]));
        let next = chars[index + 1..].iter().find(|c| !c.is_whitespace());
        let has_left_operand = previous
            .map(|(_, c)| {
                !matches!(
                    c,
                    '+' | '-' | '−' | '*' | '×' | '/' | '÷' | '^' | '(' | '∧' | '∨' | '⊻'
                )
            })
            .unwrap_or(false);
        let exponent_sign = matches!(character, '+' | '-' | '−')
            && previous
                .map(|(position, c)| {
                    matches!(c, 'e' | 'E')
                        && chars[..position]
                            .iter()
                            .rev()
                            .find(|c| !c.is_whitespace())
                            .is_some_and(|c| c.is_ascii_digit() || *c == '.')
                })
                .unwrap_or(false);

        if has_left_operand && next.is_some() && !exponent_sign {
            output.push(WRAP_HINT);
        }
    }

    output
}

fn group_ascii_number_literals(input: &str) -> String {
    let source: Vec<char> = input
        .chars()
        .filter(|character| *character != WRAP_HINT)
        .collect();
    let plain: Vec<char> = source
        .iter()
        .copied()
        .enumerate()
        .filter_map(|(index, character)| {
            (character != ',' || crate::engine::is_argument_separator(&source, index))
                .then_some(character)
        })
        .collect();
    let mut output = String::with_capacity(plain.len() + plain.len() / 3);
    let mut index = 0;

    while index < plain.len() {
        let starts_number = plain[index].is_ascii_digit()
            || (plain[index] == '.'
                && plain
                    .get(index + 1)
                    .is_some_and(|character| character.is_ascii_digit()));
        if !starts_number {
            output.push(plain[index]);
            index += 1;
            continue;
        }

        let integer_start = index;
        while index < plain.len() && plain[index].is_ascii_digit() {
            index += 1;
        }
        let integer_length = index - integer_start;
        let is_root_degree = index < plain.len()
            && plain[index] == ','
            && crate::engine::is_root_argument_separator(&plain, index);
        if integer_length > 0 {
            let first_group_length = if is_root_degree {
                integer_length
            } else {
                match integer_length % 3 {
                    0 => 3,
                    remainder => remainder,
                }
            };
            for (offset, character) in plain[integer_start..index].iter().enumerate() {
                if offset >= first_group_length && (offset - first_group_length) % 3 == 0 {
                    output.push(',');
                }
                output.push(*character);
            }
        }

        if index < plain.len() && plain[index] == '.' {
            output.push('.');
            index += 1;
            while index < plain.len() && plain[index].is_ascii_digit() {
                output.push(plain[index]);
                index += 1;
            }
        }

        if index < plain.len() && matches!(plain[index], 'e' | 'E') {
            let exponent_marker = index;
            let mut exponent_digits = index + 1;
            if plain
                .get(exponent_digits)
                .is_some_and(|character| matches!(character, '+' | '-' | '−'))
            {
                exponent_digits += 1;
            }
            if plain
                .get(exponent_digits)
                .is_some_and(|character| character.is_ascii_digit())
            {
                output.extend(plain[exponent_marker..exponent_digits].iter().copied());
                index = exponent_digits;
                while index < plain.len() && plain[index].is_ascii_digit() {
                    output.push(plain[index]);
                    index += 1;
                }
            }
        }
    }

    output
}

fn format_expression_for_display(input: &str, grouping_enabled: bool) -> String {
    let unwrapped: String = input
        .chars()
        .filter(|character| *character != WRAP_HINT)
        .collect();
    let displayed = if grouping_enabled {
        group_ascii_number_literals(&unwrapped)
    } else {
        unwrapped
    };
    add_wrap_hints(&displayed)
}

fn reformat_digit_grouping(input: &str, grouping_enabled: bool) -> String {
    let source: Vec<char> = input
        .chars()
        .filter(|character| *character != WRAP_HINT)
        .collect();
    let ungrouped: String = source
        .iter()
        .copied()
        .enumerate()
        .filter_map(|(index, character)| {
            (character != ',' || crate::engine::is_argument_separator(&source, index))
                .then_some(character)
        })
        .collect();
    if grouping_enabled {
        group_ascii_number_literals(&ungrouped)
    } else {
        ungrouped
    }
}

fn format_number_for_display(input: &str, grouping_enabled: bool) -> String {
    if grouping_enabled {
        group_ascii_number_literals(input)
    } else {
        input.to_string()
    }
}

fn is_known_conversion_unit(unit: &str) -> bool {
    unit_factor(unit).is_some() || matches!(unit, "Celsius" | "Fahrenheit" | "Kelvin")
}

const MAX_WINDOW_DIMENSION: i32 = 16_384;
const PROGRAMMER_WORD_BITS: [i32; 10] = [8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096];

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum CalculatorMode {
    Basic,
    Advanced,
    Financial,
    Programming,
    Conversion,
}

impl CalculatorMode {
    const ALL: [Self; 5] = [
        Self::Basic,
        Self::Advanced,
        Self::Financial,
        Self::Programming,
        Self::Conversion,
    ];

    fn from_name(name: &str) -> Option<Self> {
        match name {
            "basic" => Some(Self::Basic),
            "advanced" => Some(Self::Advanced),
            "financial" => Some(Self::Financial),
            "programming" => Some(Self::Programming),
            "conversion" => Some(Self::Conversion),
            _ => None,
        }
    }

    const fn name(self) -> &'static str {
        match self {
            Self::Basic => "basic",
            Self::Advanced => "advanced",
            Self::Financial => "financial",
            Self::Programming => "programming",
            Self::Conversion => "conversion",
        }
    }

    const fn index(self) -> usize {
        match self {
            Self::Basic => 0,
            Self::Advanced => 1,
            Self::Financial => 2,
            Self::Programming => 3,
            Self::Conversion => 4,
        }
    }

    const fn minimum_width(self) -> i32 {
        match self {
            Self::Basic | Self::Programming => 340,
            Self::Conversion => 380,
            Self::Advanced | Self::Financial => 620,
        }
    }

    const fn minimum_height(self) -> i32 {
        match self {
            Self::Programming => 632,
            _ => 540,
        }
    }

    const fn default_window_state(self) -> WindowState {
        WindowState {
            width: match self {
                Self::Basic => 370,
                Self::Conversion => 380,
                Self::Advanced | Self::Financial | Self::Programming => 620,
            },
            height: match self {
                Self::Programming => 632,
                _ => 620,
            },
            maximized: false,
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
struct WindowState {
    width: i32,
    height: i32,
    maximized: bool,
}

impl WindowState {
    fn validated(mode: CalculatorMode, width: i32, height: i32, maximized: bool) -> Self {
        Self {
            width: width.clamp(mode.minimum_width(), MAX_WINDOW_DIMENSION),
            height: height.clamp(mode.minimum_height(), MAX_WINDOW_DIMENSION),
            maximized,
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum WindowStateField {
    Width,
    Height,
    Maximized,
}

fn window_state_field(key: &str) -> Option<(CalculatorMode, WindowStateField)> {
    let (mode, field) = key.split_once("_window_")?;
    let mode = CalculatorMode::from_name(mode)?;
    let field = match field {
        "width" => WindowStateField::Width,
        "height" => WindowStateField::Height,
        "maximized" => WindowStateField::Maximized,
        _ => return None,
    };
    Some((mode, field))
}

fn is_valid_programmer_base(base: i32) -> bool {
    matches!(base, 2 | 8 | 10 | 16)
}

fn is_valid_programmer_word_bits(bits: i32) -> bool {
    PROGRAMMER_WORD_BITS.contains(&bits)
}

#[derive(Clone, Debug, PartialEq)]
struct Preferences {
    result_format: String,
    precision: i32,
    angle_unit: String,
    digit_grouping: bool,
    conversion_from_unit: String,
    conversion_to_unit: String,
    window_states: [WindowState; 5],
    programmer_base: i32,
    programmer_word_bits: i32,
    programmer_bit_panel_enabled: bool,
}

impl Default for Preferences {
    fn default() -> Self {
        Self {
            result_format: "automatic".to_string(),
            precision: 9,
            angle_unit: "degrees".to_string(),
            digit_grouping: true,
            conversion_from_unit: "Celsius".to_string(),
            conversion_to_unit: "Fahrenheit".to_string(),
            window_states: CalculatorMode::ALL.map(CalculatorMode::default_window_state),
            programmer_base: 10,
            programmer_word_bits: 64,
            programmer_bit_panel_enabled: false,
        }
    }
}

fn parse_preferences(text: &str) -> Preferences {
    let mut preferences = Preferences::default();
    let mut legacy_width = None;
    let mut legacy_height = None;
    let mut legacy_maximized = None;
    let mut mode_widths = [None; 5];
    let mut mode_heights = [None; 5];
    let mut mode_maximized = [None; 5];
    for line in text.lines().map(str::trim) {
        if line.is_empty() || line.starts_with('#') || line.starts_with('[') {
            continue;
        }
        let Some((key, value)) = line.split_once('=') else {
            continue;
        };
        let value = value.trim();
        match key.trim() {
            "result_format"
                if matches!(value, "automatic" | "fixed" | "scientific" | "engineering") =>
            {
                preferences.result_format = value.to_string();
            }
            "precision" => {
                if let Ok(precision) = value.parse::<i32>() {
                    preferences.precision = precision.clamp(1, 100);
                }
            }
            "angle_unit" if matches!(value, "degrees" | "radians" | "gradians") => {
                preferences.angle_unit = value.to_string();
            }
            "digit_grouping" => match value {
                "true" => preferences.digit_grouping = true,
                "false" => preferences.digit_grouping = false,
                _ => {}
            },
            "conversion_from_unit" if is_known_conversion_unit(value) => {
                preferences.conversion_from_unit = value.to_string();
            }
            "conversion_to_unit" if is_known_conversion_unit(value) => {
                preferences.conversion_to_unit = value.to_string();
            }
            "window_width" => {
                if let Ok(width) = value.parse::<i32>() {
                    legacy_width = Some(width);
                }
            }
            "window_height" => {
                if let Ok(height) = value.parse::<i32>() {
                    legacy_height = Some(height);
                }
            }
            "window_maximized" => match value {
                "true" => legacy_maximized = Some(true),
                "false" => legacy_maximized = Some(false),
                _ => {}
            },
            "programmer_base" => {
                if let Ok(base) = value.parse::<i32>()
                    && is_valid_programmer_base(base)
                {
                    preferences.programmer_base = base;
                }
            }
            "programmer_word_bits" => {
                if let Ok(bits) = value.parse::<i32>()
                    && is_valid_programmer_word_bits(bits)
                {
                    preferences.programmer_word_bits = bits;
                }
            }
            "programmer_bit_panel_enabled" => match value {
                "true" => preferences.programmer_bit_panel_enabled = true,
                "false" => preferences.programmer_bit_panel_enabled = false,
                _ => {}
            },
            key => {
                let Some((mode, field)) = window_state_field(key) else {
                    continue;
                };
                let index = mode.index();
                match field {
                    WindowStateField::Width => {
                        if let Ok(width) = value.parse::<i32>() {
                            mode_widths[index] = Some(width);
                        }
                    }
                    WindowStateField::Height => {
                        if let Ok(height) = value.parse::<i32>() {
                            mode_heights[index] = Some(height);
                        }
                    }
                    WindowStateField::Maximized => match value {
                        "true" => mode_maximized[index] = Some(true),
                        "false" => mode_maximized[index] = Some(false),
                        _ => {}
                    },
                }
            }
        }
    }

    for mode in CalculatorMode::ALL {
        let index = mode.index();
        let default = mode.default_window_state();
        preferences.window_states[index] = WindowState::validated(
            mode,
            mode_widths[index].or(legacy_width).unwrap_or(default.width),
            mode_heights[index]
                .or(legacy_height)
                .unwrap_or(default.height),
            mode_maximized[index]
                .or(legacy_maximized)
                .unwrap_or(default.maximized),
        );
    }
    preferences
}

fn serialize_preferences(preferences: &Preferences) -> String {
    let basic_window = preferences.window_states[CalculatorMode::Basic.index()];
    let mut output = format!(
        "[Preferences]\nresult_format={}\nprecision={}\nangle_unit={}\ndigit_grouping={}\nconversion_from_unit={}\nconversion_to_unit={}\nwindow_width={}\nwindow_height={}\nwindow_maximized={}\nprogrammer_base={}\nprogrammer_word_bits={}\nprogrammer_bit_panel_enabled={}\n",
        preferences.result_format,
        preferences.precision,
        preferences.angle_unit,
        preferences.digit_grouping,
        preferences.conversion_from_unit,
        preferences.conversion_to_unit,
        basic_window.width,
        basic_window.height,
        basic_window.maximized,
        preferences.programmer_base,
        preferences.programmer_word_bits,
        preferences.programmer_bit_panel_enabled,
    );
    for mode in CalculatorMode::ALL {
        let state = preferences.window_states[mode.index()];
        output.push_str(&format!(
            "{}_window_width={}\n{}_window_height={}\n{}_window_maximized={}\n",
            mode.name(),
            state.width,
            mode.name(),
            state.height,
            mode.name(),
            state.maximized,
        ));
    }
    output
}

fn preferences_path() -> Option<PathBuf> {
    let config_directory = env::var_os("XDG_CONFIG_HOME")
        .filter(|path| !path.is_empty())
        .map(PathBuf::from)
        .or_else(|| env::var_os("HOME").map(|home| PathBuf::from(home).join(".config")))?;
    Some(config_directory.join(CONFIG_FILE_NAME))
}

fn load_preferences() -> Preferences {
    let Some(path) = preferences_path() else {
        return Preferences::default();
    };
    match fs::read_to_string(path) {
        Ok(text) => parse_preferences(&text),
        Err(error) if error.kind() == ErrorKind::NotFound => Preferences::default(),
        Err(error) => {
            eprintln!("Could not read calculator preferences: {error}");
            Preferences::default()
        }
    }
}

fn save_preferences(preferences: &Preferences) -> io::Result<()> {
    let path = preferences_path().ok_or_else(|| {
        io::Error::new(
            ErrorKind::NotFound,
            "HOME and XDG_CONFIG_HOME are not available",
        )
    })?;
    let Some(directory) = path.parent() else {
        return Err(io::Error::new(
            ErrorKind::InvalidInput,
            "the preferences path has no parent directory",
        ));
    };
    fs::create_dir_all(directory)?;
    let temporary_path = path.with_extension("conf.tmp");
    fs::write(&temporary_path, serialize_preferences(preferences))?;
    fs::rename(temporary_path, path)
}

#[derive(Clone, Debug, PartialEq)]
struct CalculatorSnapshot {
    expression: String,
    result: String,
    error: String,
    history: Vec<(String, String)>,
}

fn serialize_history(history: &[(String, String)]) -> String {
    history
        .iter()
        .map(|(expression, result)| format!("{expression}\t{result}"))
        .collect::<Vec<_>>()
        .join("\n")
}

fn reformat_snapshot(snapshot: &mut CalculatorSnapshot, grouping_enabled: bool) {
    snapshot.expression = add_wrap_hints(&reformat_digit_grouping(
        &snapshot.expression,
        grouping_enabled,
    ));
    snapshot.result = reformat_digit_grouping(&snapshot.result, grouping_enabled);
    for (expression, result) in &mut snapshot.history {
        *expression = add_wrap_hints(&reformat_digit_grouping(expression, grouping_enabled));
        *result = reformat_digit_grouping(result, grouping_enabled);
    }
}

#[cxx_qt::bridge]
pub mod qobject {
    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;
    }

    extern "RustQt" {
        #[qobject]
        #[qml_element]
        #[qproperty(QString, expression)]
        #[qproperty(QString, result)]
        #[qproperty(QString, error)]
        #[qproperty(QString, history_data, cxx_name = "historyData")]
        #[qproperty(QString, format)]
        #[qproperty(i32, precision)]
        #[qproperty(QString, angle_unit, cxx_name = "angleUnit")]
        #[qproperty(bool, digit_grouping_enabled, cxx_name = "digitGroupingEnabled")]
        #[qproperty(QString, conversion_from_unit, cxx_name = "conversionFromUnit")]
        #[qproperty(QString, conversion_to_unit, cxx_name = "conversionToUnit")]
        #[qproperty(bool, can_undo, cxx_name = "canUndo")]
        #[qproperty(bool, can_redo, cxx_name = "canRedo")]
        #[qproperty(i32, saved_window_width, cxx_name = "savedWindowWidth")]
        #[qproperty(i32, saved_window_height, cxx_name = "savedWindowHeight")]
        #[qproperty(bool, window_maximized, cxx_name = "windowMaximized")]
        #[qproperty(i32, programmer_base, cxx_name = "programmerBase")]
        #[qproperty(i32, programmer_word_bits, cxx_name = "programmerWordBits")]
        #[qproperty(
            bool,
            programmer_bit_panel_enabled,
            cxx_name = "programmerBitPanelEnabled"
        )]
        type CalculatorBackend = super::CalculatorBackendRust;

        #[qinvokable]
        fn insert(self: Pin<&mut CalculatorBackend>, text: &QString);
        #[qinvokable]
        fn clear(self: Pin<&mut CalculatorBackend>);
        #[qinvokable]
        fn backspace(self: Pin<&mut CalculatorBackend>);
        #[qinvokable]
        fn calculate(self: Pin<&mut CalculatorBackend>);
        #[qinvokable]
        #[cxx_name = "calculateProgrammer"]
        fn calculate_programmer(self: Pin<&mut CalculatorBackend>, base: i32, bits: i32);
        #[qinvokable]
        fn undo(self: Pin<&mut CalculatorBackend>);
        #[qinvokable]
        fn redo(self: Pin<&mut CalculatorBackend>);
        #[qinvokable]
        #[cxx_name = "clearHistory"]
        fn clear_history(self: Pin<&mut CalculatorBackend>);
        #[qinvokable]
        #[cxx_name = "applyExpression"]
        fn apply_expression(self: Pin<&mut CalculatorBackend>, text: &QString);
        #[qinvokable]
        #[cxx_name = "setFormatting"]
        fn set_formatting(self: Pin<&mut CalculatorBackend>, format: &QString, precision: i32);
        #[qinvokable]
        #[cxx_name = "applyAngleUnit"]
        fn apply_angle_unit(self: Pin<&mut CalculatorBackend>, unit: &QString);
        #[qinvokable]
        #[cxx_name = "applyDigitGrouping"]
        fn apply_digit_grouping(self: Pin<&mut CalculatorBackend>, enabled: bool);
        #[qinvokable]
        #[cxx_name = "setDigitGroupingActive"]
        fn set_digit_grouping_active(self: Pin<&mut CalculatorBackend>, enabled: bool);
        #[qinvokable]
        #[cxx_name = "saveConversionUnits"]
        fn save_conversion_units(self: Pin<&mut CalculatorBackend>, from: &QString, to: &QString);
        #[qinvokable]
        #[cxx_name = "saveWindowState"]
        fn save_window_state(
            self: Pin<&mut CalculatorBackend>,
            width: i32,
            height: i32,
            maximized: bool,
        );
        #[qinvokable]
        #[cxx_name = "savedWindowWidthForMode"]
        fn saved_window_width_for_mode(&self, mode: &QString) -> i32;
        #[qinvokable]
        #[cxx_name = "savedWindowHeightForMode"]
        fn saved_window_height_for_mode(&self, mode: &QString) -> i32;
        #[qinvokable]
        #[cxx_name = "windowMaximizedForMode"]
        fn window_maximized_for_mode(&self, mode: &QString) -> bool;
        #[qinvokable]
        #[cxx_name = "saveWindowStateForMode"]
        fn save_window_state_for_mode(
            self: Pin<&mut CalculatorBackend>,
            mode: &QString,
            width: i32,
            height: i32,
            maximized: bool,
        );
        #[qinvokable]
        #[cxx_name = "saveProgrammerState"]
        fn save_programmer_state(
            self: Pin<&mut CalculatorBackend>,
            base: i32,
            word_bits: i32,
            bit_panel_enabled: bool,
        );
        #[qinvokable]
        #[cxx_name = "convertValue"]
        fn convert_value(&self, value: &QString, from: &QString, to: &QString) -> QString;
        #[qinvokable]
        #[cxx_name = "programmerValue"]
        fn programmer_value(
            &self,
            value: &QString,
            from_base: i32,
            to_base: i32,
            bits: i32,
        ) -> QString;
        #[qinvokable]
        #[cxx_name = "programmerValues"]
        fn programmer_values(&self, value: &QString, from_base: i32, bits: i32) -> QString;
        #[qinvokable]
        #[cxx_name = "programmerResizedValue"]
        fn programmer_resized_value(
            &self,
            value: &QString,
            base: i32,
            old_bits: i32,
            new_bits: i32,
        ) -> QString;
        #[qinvokable]
        #[cxx_name = "financialValue"]
        fn financial_value(
            &self,
            operation: &QString,
            principal: &QString,
            rate: &QString,
            periods: &QString,
            payment: &QString,
        ) -> QString;
    }
}

pub struct CalculatorBackendRust {
    expression: QString,
    result: QString,
    error: QString,
    history_data: QString,
    format: QString,
    precision: i32,
    angle_unit: QString,
    digit_grouping_enabled: bool,
    conversion_from_unit: QString,
    conversion_to_unit: QString,
    can_undo: bool,
    can_redo: bool,
    digit_grouping_active: bool,
    saved_window_width: i32,
    saved_window_height: i32,
    window_maximized: bool,
    programmer_base: i32,
    programmer_word_bits: i32,
    programmer_bit_panel_enabled: bool,
    window_states: [WindowState; 5],
    undo_stack: Vec<CalculatorSnapshot>,
    redo_stack: Vec<CalculatorSnapshot>,
    history: Vec<(String, String)>,
}

impl Default for CalculatorBackendRust {
    fn default() -> Self {
        let preferences = load_preferences();
        let basic_window = preferences.window_states[CalculatorMode::Basic.index()];
        Self {
            expression: QString::default(),
            result: "0".into(),
            error: QString::default(),
            history_data: QString::default(),
            format: preferences.result_format.into(),
            precision: preferences.precision,
            angle_unit: preferences.angle_unit.into(),
            digit_grouping_enabled: preferences.digit_grouping,
            conversion_from_unit: preferences.conversion_from_unit.into(),
            conversion_to_unit: preferences.conversion_to_unit.into(),
            can_undo: false,
            can_redo: false,
            digit_grouping_active: preferences.digit_grouping,
            saved_window_width: basic_window.width,
            saved_window_height: basic_window.height,
            window_maximized: basic_window.maximized,
            programmer_base: preferences.programmer_base,
            programmer_word_bits: preferences.programmer_word_bits,
            programmer_bit_panel_enabled: preferences.programmer_bit_panel_enabled,
            window_states: preferences.window_states,
            undo_stack: vec![],
            redo_stack: vec![],
            history: vec![],
        }
    }
}

impl CalculatorBackendRust {
    fn snapshot(&self) -> CalculatorSnapshot {
        CalculatorSnapshot {
            expression: self.expression.to_string(),
            result: self.result.to_string(),
            error: self.error.to_string(),
            history: self.history.clone(),
        }
    }

    fn completed_history_snapshot(&self) -> CalculatorSnapshot {
        let last_result = self
            .history
            .last()
            .map(|(_, result)| result.clone())
            .unwrap_or_else(|| "0".to_string());
        let expression = if self.history.is_empty() {
            String::new()
        } else {
            format_expression_for_display(&last_result, self.digit_grouping_active)
        };
        CalculatorSnapshot {
            expression,
            result: last_result,
            error: String::new(),
            history: self.history.clone(),
        }
    }

    fn checkpoint_history(&mut self) {
        self.undo_stack.push(self.completed_history_snapshot());
        if self.undo_stack.len() > 100 {
            self.undo_stack.remove(0);
        }
        self.abandon_redo();
    }

    fn abandon_redo(&mut self) {
        self.redo_stack.clear();
        self.redo_stack.shrink_to_fit();
    }

    fn history_action_availability(&self) -> (bool, bool) {
        (!self.undo_stack.is_empty(), !self.redo_stack.is_empty())
    }

    fn take_undo_snapshot(&mut self) -> Option<CalculatorSnapshot> {
        let previous = self.undo_stack.pop()?;
        self.redo_stack.push(self.snapshot());
        Some(previous)
    }

    fn take_redo_snapshot(&mut self) -> Option<CalculatorSnapshot> {
        let next = self.redo_stack.pop()?;
        self.undo_stack.push(self.snapshot());
        Some(next)
    }

    fn preferences(&self) -> Preferences {
        Preferences {
            result_format: self.format.to_string(),
            precision: self.precision,
            angle_unit: self.angle_unit.to_string(),
            digit_grouping: self.digit_grouping_enabled,
            conversion_from_unit: self.conversion_from_unit.to_string(),
            conversion_to_unit: self.conversion_to_unit.to_string(),
            window_states: self.window_states,
            programmer_base: self.programmer_base,
            programmer_word_bits: self.programmer_word_bits,
            programmer_bit_panel_enabled: self.programmer_bit_panel_enabled,
        }
    }

    fn window_state_for_mode_name(&self, mode: &str) -> WindowState {
        CalculatorMode::from_name(mode)
            .map(|mode| self.window_states[mode.index()])
            .unwrap_or_else(|| CalculatorMode::Basic.default_window_state())
    }

    fn persist_preferences(&self) {
        if let Err(error) = save_preferences(&self.preferences()) {
            eprintln!("Could not save calculator preferences: {error}");
        }
    }
}

impl qobject::CalculatorBackend {
    fn store_window_state(
        mut self: Pin<&mut Self>,
        mode: CalculatorMode,
        width: i32,
        height: i32,
        maximized: bool,
    ) {
        let state = WindowState::validated(mode, width, height, maximized);
        self.as_mut().rust_mut().window_states[mode.index()] = state;
        if mode == CalculatorMode::Basic {
            self.as_mut().set_saved_window_width(state.width);
            self.as_mut().set_saved_window_height(state.height);
            self.as_mut().set_window_maximized(state.maximized);
        }
        self.rust().persist_preferences();
    }

    fn update_history_action_availability(mut self: Pin<&mut Self>) {
        let (can_undo, can_redo) = self.rust().history_action_availability();
        self.as_mut().set_can_undo(can_undo);
        self.as_mut().set_can_redo(can_redo);
    }

    fn restore_snapshot(mut self: Pin<&mut Self>, snapshot: CalculatorSnapshot) {
        let history_data = serialize_history(&snapshot.history);
        self.as_mut().rust_mut().history = snapshot.history;
        self.as_mut().set_expression(snapshot.expression.into());
        self.as_mut().set_result(snapshot.result.into());
        self.as_mut().set_error(snapshot.error.into());
        self.as_mut().set_history_data(history_data.into());
    }

    fn update_digit_grouping_display(mut self: Pin<&mut Self>, enabled: bool) {
        let expression = add_wrap_hints(&reformat_digit_grouping(
            &self.expression().to_string(),
            enabled,
        ));
        let result = reformat_digit_grouping(&self.result().to_string(), enabled);
        let history_data = {
            let mut rust = self.as_mut().rust_mut();
            rust.digit_grouping_active = enabled;
            for snapshot in &mut rust.undo_stack {
                reformat_snapshot(snapshot, enabled);
            }
            for snapshot in &mut rust.redo_stack {
                reformat_snapshot(snapshot, enabled);
            }
            for (expression, result) in &mut rust.history {
                *expression = add_wrap_hints(&reformat_digit_grouping(expression, enabled));
                *result = reformat_digit_grouping(result, enabled);
            }
            serialize_history(&rust.history)
        };
        self.as_mut().set_expression(expression.into());
        self.as_mut().set_result(result.into());
        self.as_mut().set_history_data(history_data.into());
    }

    pub fn insert(mut self: Pin<&mut Self>, text: &QString) {
        self.as_mut().rust_mut().abandon_redo();
        let mut next = self.expression().to_string();
        next.push_str(&text.to_string());
        let next = format_expression_for_display(&next, self.rust().digit_grouping_active);
        self.as_mut().set_expression(next.into());
        self.as_mut().set_error(QString::default());
        self.as_mut().update_history_action_availability();
    }

    pub fn apply_expression(mut self: Pin<&mut Self>, text: &QString) {
        let text =
            format_expression_for_display(&text.to_string(), self.rust().digit_grouping_active);
        if self.expression().to_string() == text {
            return;
        }
        self.as_mut().rust_mut().abandon_redo();
        self.as_mut().set_expression(text.into());
        self.as_mut().set_error(QString::default());
        self.as_mut().update_history_action_availability();
    }

    pub fn clear(mut self: Pin<&mut Self>) {
        self.as_mut().rust_mut().abandon_redo();
        self.as_mut().set_expression(QString::default());
        self.as_mut().set_result("0".into());
        self.as_mut().set_error(QString::default());
        self.as_mut().update_history_action_availability();
    }

    pub fn backspace(mut self: Pin<&mut Self>) {
        let current = self.expression().to_string();
        if current.is_empty() {
            return;
        }
        self.as_mut().rust_mut().abandon_redo();
        let mut chars: Vec<char> = current.chars().collect();
        chars.pop();
        let text = chars.into_iter().collect::<String>();
        let text = format_expression_for_display(&text, self.rust().digit_grouping_active);
        self.as_mut().set_expression(text.into());
        self.as_mut().update_history_action_availability();
    }

    pub fn calculate(mut self: Pin<&mut Self>) {
        let expression = self.expression().to_string();
        if expression.trim().is_empty() {
            return;
        }
        let angle = AngleUnit::from_name(&self.angle_unit().to_string());
        match crate::complex::evaluate(&expression, angle, *self.precision()) {
            Ok(value) => {
                self.as_mut().rust_mut().checkpoint_history();
                let rendered = crate::complex::format_value(
                    &value,
                    &self.format().to_string(),
                    *self.precision(),
                );
                let rendered =
                    format_number_for_display(&rendered, self.rust().digit_grouping_active);
                self.as_mut().set_result(rendered.clone().into());
                self.as_mut().set_error(QString::default());
                self.as_mut()
                    .rust_mut()
                    .history
                    .push((expression, rendered.clone()));
                let data = serialize_history(&self.rust().history);
                self.as_mut().set_history_data(data.into());
                // Like GNOME Calculator, a completed result becomes the next
                // editable expression so operators can continue from it.
                let next_expression =
                    format_expression_for_display(&rendered, self.rust().digit_grouping_active);
                self.as_mut().set_expression(next_expression.into());
            }
            Err(message) => {
                self.as_mut().rust_mut().abandon_redo();
                self.as_mut().set_error(message.into());
            }
        }
        self.as_mut().update_history_action_availability();
    }

    pub fn calculate_programmer(mut self: Pin<&mut Self>, base: i32, bits: i32) {
        let expression = self.expression().to_string();
        if expression.trim().is_empty() {
            return;
        }
        let angle = AngleUnit::from_name(&self.angle_unit().to_string());
        match programmer_calculation_text(
            &expression,
            base,
            bits,
            angle,
            &self.format().to_string(),
            *self.precision(),
        ) {
            Ok(rendered) => {
                let record_history =
                    !programmer_identity_literal(&expression, &rendered, base, *self.precision());
                if record_history {
                    self.as_mut().rust_mut().checkpoint_history();
                }
                self.as_mut().set_result(rendered.clone().into());
                self.as_mut().set_error(QString::default());
                if record_history {
                    self.as_mut()
                        .rust_mut()
                        .history
                        .push((expression, rendered.clone()));
                    let data = serialize_history(&self.rust().history);
                    self.as_mut().set_history_data(data.into());
                }
                self.as_mut().set_expression(rendered.into());
            }
            Err(message) => {
                self.as_mut().rust_mut().abandon_redo();
                self.as_mut().set_error(message.into());
            }
        }
        self.as_mut().update_history_action_availability();
    }

    pub fn undo(mut self: Pin<&mut Self>) {
        let previous = self.as_mut().rust_mut().take_undo_snapshot();
        if let Some(previous) = previous {
            self.as_mut().restore_snapshot(previous);
        }
        self.as_mut().update_history_action_availability();
    }

    pub fn redo(mut self: Pin<&mut Self>) {
        let next = self.as_mut().rust_mut().take_redo_snapshot();
        if let Some(next) = next {
            self.as_mut().restore_snapshot(next);
        }
        self.as_mut().update_history_action_availability();
    }

    pub fn clear_history(mut self: Pin<&mut Self>) {
        let mut rust = self.as_mut().rust_mut();
        rust.history.clear();
        rust.undo_stack.clear();
        rust.undo_stack.shrink_to_fit();
        rust.abandon_redo();
        self.as_mut().set_history_data(QString::default());
        self.as_mut().update_history_action_availability();
    }

    pub fn set_formatting(mut self: Pin<&mut Self>, format: &QString, precision: i32) {
        self.as_mut().set_format(format.to_string().into());
        self.as_mut().set_precision(precision.clamp(1, 100));
        self.rust().persist_preferences();
    }

    pub fn apply_angle_unit(mut self: Pin<&mut Self>, unit: &QString) {
        self.as_mut().set_angle_unit(unit.to_string().into());
        self.rust().persist_preferences();
    }

    pub fn apply_digit_grouping(mut self: Pin<&mut Self>, enabled: bool) {
        self.as_mut().update_digit_grouping_display(enabled);
        self.as_mut().set_digit_grouping_enabled(enabled);
        self.rust().persist_preferences();
    }

    pub fn set_digit_grouping_active(mut self: Pin<&mut Self>, enabled: bool) {
        self.as_mut().update_digit_grouping_display(enabled);
    }

    pub fn save_conversion_units(mut self: Pin<&mut Self>, from: &QString, to: &QString) {
        let from = from.to_string();
        let to = to.to_string();
        if !is_known_conversion_unit(&from) || !is_known_conversion_unit(&to) {
            return;
        }
        self.as_mut().set_conversion_from_unit(from.into());
        self.as_mut().set_conversion_to_unit(to.into());
        self.rust().persist_preferences();
    }

    pub fn save_window_state(mut self: Pin<&mut Self>, width: i32, height: i32, maximized: bool) {
        self.as_mut()
            .store_window_state(CalculatorMode::Basic, width, height, maximized);
    }

    pub fn saved_window_width_for_mode(&self, mode: &QString) -> i32 {
        self.rust()
            .window_state_for_mode_name(&mode.to_string())
            .width
    }

    pub fn saved_window_height_for_mode(&self, mode: &QString) -> i32 {
        self.rust()
            .window_state_for_mode_name(&mode.to_string())
            .height
    }

    pub fn window_maximized_for_mode(&self, mode: &QString) -> bool {
        self.rust()
            .window_state_for_mode_name(&mode.to_string())
            .maximized
    }

    pub fn save_window_state_for_mode(
        mut self: Pin<&mut Self>,
        mode: &QString,
        width: i32,
        height: i32,
        maximized: bool,
    ) {
        let Some(mode) = CalculatorMode::from_name(&mode.to_string()) else {
            return;
        };
        self.as_mut()
            .store_window_state(mode, width, height, maximized);
    }

    pub fn save_programmer_state(
        mut self: Pin<&mut Self>,
        base: i32,
        word_bits: i32,
        bit_panel_enabled: bool,
    ) {
        if !is_valid_programmer_base(base) || !is_valid_programmer_word_bits(word_bits) {
            return;
        }
        self.as_mut().set_programmer_base(base);
        self.as_mut().set_programmer_word_bits(word_bits);
        self.as_mut()
            .set_programmer_bit_panel_enabled(bit_panel_enabled);
        self.rust().persist_preferences();
    }

    pub fn convert_value(&self, value: &QString, from: &QString, to: &QString) -> QString {
        format_number_for_display(
            &convert_value_precise_text(
                &value.to_string(),
                &from.to_string(),
                &to.to_string(),
                "conversion",
                16,
            ),
            self.rust().digit_grouping_active,
        )
        .into()
    }

    pub fn programmer_value(
        &self,
        value: &QString,
        from_base: i32,
        to_base: i32,
        bits: i32,
    ) -> QString {
        let angle = AngleUnit::from_name(&self.angle_unit().to_string());
        programmer_expression_value_text_with_angle(
            &value.to_string(),
            from_base,
            to_base,
            bits,
            *self.precision(),
            angle,
        )
        .unwrap_or_default()
        .into()
    }

    pub fn programmer_values(&self, value: &QString, from_base: i32, bits: i32) -> QString {
        let angle = AngleUnit::from_name(&self.angle_unit().to_string());
        programmer_expression_values_text_with_angle(
            &value.to_string(),
            from_base,
            bits,
            *self.precision(),
            angle,
        )
        .unwrap_or_default()
        .into()
    }

    pub fn programmer_resized_value(
        &self,
        value: &QString,
        base: i32,
        old_bits: i32,
        new_bits: i32,
    ) -> QString {
        let angle = AngleUnit::from_name(&self.angle_unit().to_string());
        programmer_resized_value_text_with_angle(
            &value.to_string(),
            base,
            old_bits,
            new_bits,
            *self.precision(),
            angle,
        )
        .unwrap_or_default()
        .into()
    }

    pub fn financial_value(
        &self,
        operation: &QString,
        principal: &QString,
        rate: &QString,
        periods: &QString,
        payment: &QString,
    ) -> QString {
        let result = precise::financial_value(
            &operation.to_string(),
            &principal.to_string(),
            &rate.to_string(),
            &periods.to_string(),
            &payment.to_string(),
            &self.format().to_string(),
            *self.precision(),
        )
        .unwrap_or_else(|error| error);
        format_number_for_display(&result, self.rust().digit_grouping_active).into()
    }
}

fn convert_value_precise_text(
    input: &str,
    from: &str,
    to: &str,
    format: &str,
    precision: i32,
) -> String {
    let Ok(mut value) = precise::parse_decimal(input, precision) else {
        return "Invalid value".into();
    };
    let number = |text: &str| precise::parse_decimal(text, precision).expect("valid constant");
    let from_temperature = matches!(from, "Celsius" | "Fahrenheit" | "Kelvin");
    let to_temperature = matches!(to, "Celsius" | "Fahrenheit" | "Kelvin");

    if from_temperature || to_temperature {
        if !(from_temperature && to_temperature) {
            return "Incompatible units".into();
        }
        match from {
            "Celsius" => value += number("273.15"),
            "Fahrenheit" => {
                value -= 32;
                value *= 5;
                value /= 9;
                value += number("273.15");
            }
            "Kelvin" => {}
            _ => unreachable!(),
        }
        match to {
            "Celsius" => value -= number("273.15"),
            "Fahrenheit" => {
                value -= number("273.15");
                value *= 9;
                value /= 5;
                value += 32;
            }
            "Kelvin" => {}
            _ => unreachable!(),
        }
        return if format == "conversion" {
            precise::format_conversion_value(&value)
        } else {
            precise::format_value(&value, format, precision)
        };
    }

    match (unit_factor(from), unit_factor(to)) {
        (Some((from_factor, from_category)), Some((to_factor, to_category)))
            if from_category == to_category =>
        {
            let from_factor = number(&from_factor.to_string());
            let to_factor = number(&to_factor.to_string());
            value *= from_factor;
            value /= to_factor;
            if format == "conversion" {
                precise::format_conversion_value(&value)
            } else {
                precise::format_value(&value, format, precision)
            }
        }
        _ => "Incompatible units".into(),
    }
}

#[cfg(test)]
#[allow(dead_code)]
fn convert_value_text(value: f64, from: &str, to: &str, format: &str, precision: i32) -> String {
    if temperature_to_kelvin(value, from).is_some() && temperature_from_kelvin(0.0, to).is_some() {
        let kelvin = temperature_to_kelvin(value, from).unwrap();
        return format_value(
            temperature_from_kelvin(kelvin, to).unwrap(),
            format,
            precision,
        );
    }
    match (unit_factor(from), unit_factor(to)) {
        (Some((a, category_a)), Some((b, category_b))) if category_a == category_b => {
            format_value(value * a / b, format, precision)
        }
        _ => "Incompatible units".into(),
    }
}

#[cfg(test)]
fn programmer_value_text(value: &str, from_base: i32, to_base: i32, bits: i32) -> String {
    if value.trim().is_empty() {
        return String::new();
    }
    if !matches!(from_base, 2 | 8 | 10 | 16) || !matches!(to_base, 2 | 8 | 10 | 16) {
        return "Invalid base".into();
    }
    let input = value
        .chars()
        .filter(|character| *character != ',' && *character != WRAP_HINT)
        .collect::<String>();
    let Ok(mut number) = Integer::from_str_radix(input.trim(), from_base) else {
        return "Invalid value".into();
    };
    let width = bits.clamp(8, 4096) as u32;
    let modulus = Integer::from(1) << width;
    number %= &modulus;
    if number < 0 {
        number += &modulus;
    }
    if to_base == 10 {
        let sign_bit = Integer::from(1) << (width - 1);
        if number >= sign_bit {
            number -= &modulus;
        }
    }
    let rendered = number.to_string_radix(to_base);
    if to_base == 16 {
        rendered.to_uppercase()
    } else {
        rendered
    }
}

fn wrap_programmer_integer(value: &Integer, bits: i32) -> Integer {
    let width = bits.clamp(8, 4096) as u32;
    let modulus = Integer::from(1) << width;
    let mut wrapped = value.clone();
    wrapped %= &modulus;
    if wrapped < 0 {
        wrapped += &modulus;
    }
    wrapped
}

fn signed_programmer_integer(value: &Integer, bits: i32) -> Integer {
    let width = bits.clamp(8, 4096) as u32;
    let modulus = Integer::from(1) << width;
    let sign_bit = Integer::from(1) << (width - 1);
    let mut signed = wrap_programmer_integer(value, bits);
    if signed >= sign_bit {
        signed -= modulus;
    }
    signed
}

fn render_programmer_integer(value: &Integer, base: i32, bits: i32) -> Result<String, String> {
    if !matches!(base, 2 | 8 | 10 | 16) {
        return Err("Invalid base".into());
    }
    let wrapped = if base == 10 {
        signed_programmer_integer(value, bits)
    } else {
        wrap_programmer_integer(value, bits)
    };
    let rendered = wrapped.to_string_radix(base);
    Ok(if base == 16 {
        rendered.to_uppercase()
    } else {
        rendered
    })
}

fn programmer_expression_value_text_with_angle(
    expression: &str,
    from_base: i32,
    to_base: i32,
    bits: i32,
    precision: i32,
    angle: AngleUnit,
) -> Result<String, String> {
    let value = precise::evaluate_programmer(expression, angle, precision, from_base, bits)?;
    match value {
        precise::ProgrammerValue::Integer(integer) => {
            render_programmer_integer(&integer, to_base, bits)
        }
        precise::ProgrammerValue::Decimal(_) => {
            Err("Bit display requires a whole-number result".to_string())
        }
    }
}

fn programmer_expression_values_text_with_angle(
    expression: &str,
    from_base: i32,
    bits: i32,
    precision: i32,
    angle: AngleUnit,
) -> Result<String, String> {
    let value = precise::evaluate_programmer(expression, angle, precision, from_base, bits)?;
    let integer = match value {
        precise::ProgrammerValue::Integer(integer) => integer,
        precise::ProgrammerValue::Decimal(value) => {
            let decimal = precise::format_value(&value, "automatic", precision);
            return Ok(format!("\t{decimal}\t\t"));
        }
    };
    [16, 10, 8, 2]
        .iter()
        .map(|base| render_programmer_integer(&integer, *base, bits))
        .collect::<Result<Vec<_>, _>>()
        .map(|values| values.join("\t"))
}

fn programmer_resized_value_text_with_angle(
    expression: &str,
    base: i32,
    old_bits: i32,
    new_bits: i32,
    precision: i32,
    angle: AngleUnit,
) -> Result<String, String> {
    let value = precise::evaluate_programmer(expression, angle, precision, base, old_bits)?;
    let precise::ProgrammerValue::Integer(integer) = value else {
        return Err("Word size requires a whole-number result".to_string());
    };
    let signed = signed_programmer_integer(&integer, old_bits);
    render_programmer_integer(&signed, base, new_bits)
}

#[cfg(test)]
fn programmer_expression_value_text(
    expression: &str,
    from_base: i32,
    to_base: i32,
    bits: i32,
    precision: i32,
) -> Result<String, String> {
    programmer_expression_value_text_with_angle(
        expression,
        from_base,
        to_base,
        bits,
        precision,
        AngleUnit::Degrees,
    )
}

#[cfg(test)]
fn programmer_expression_values_text(
    expression: &str,
    from_base: i32,
    bits: i32,
    precision: i32,
) -> Result<String, String> {
    programmer_expression_values_text_with_angle(
        expression,
        from_base,
        bits,
        precision,
        AngleUnit::Degrees,
    )
}

#[cfg(test)]
fn programmer_resized_value_text(
    expression: &str,
    base: i32,
    old_bits: i32,
    new_bits: i32,
    precision: i32,
) -> Result<String, String> {
    programmer_resized_value_text_with_angle(
        expression,
        base,
        old_bits,
        new_bits,
        precision,
        AngleUnit::Degrees,
    )
}

fn programmer_calculation_text(
    expression: &str,
    base: i32,
    bits: i32,
    angle: AngleUnit,
    format: &str,
    precision: i32,
) -> Result<String, String> {
    let value = precise::evaluate_programmer(expression, angle, precision, base, bits)?;
    match value {
        precise::ProgrammerValue::Integer(integer) => {
            render_programmer_integer(&integer, base, bits)
        }
        precise::ProgrammerValue::Decimal(value) if base == 10 => {
            Ok(precise::format_value(&value, format, precision))
        }
        precise::ProgrammerValue::Decimal(_) => {
            Err("Non-decimal bases require a whole-number result".to_string())
        }
    }
}

fn programmer_identity_literal(
    expression: &str,
    rendered: &str,
    base: i32,
    precision: i32,
) -> bool {
    let cleaned: String = expression
        .chars()
        .filter(|character| {
            !character.is_whitespace() && *character != ',' && *character != WRAP_HINT
        })
        .collect();
    let unsigned = cleaned.strip_prefix(['+', '-']).unwrap_or(cleaned.as_str());
    if unsigned.is_empty() {
        return false;
    }

    if base == 10 {
        let plain_decimal = unsigned
            .chars()
            .all(|character| character.is_ascii_digit() || character == '.')
            && unsigned
                .chars()
                .filter(|character| *character == '.')
                .count()
                <= 1;
        if !plain_decimal {
            return false;
        }
        return precise::parse_decimal(&cleaned, precision)
            .ok()
            .zip(precise::parse_decimal(rendered, precision).ok())
            .is_some_and(|(entered, result)| entered == result);
    }

    if !matches!(base, 2 | 8 | 16)
        || !unsigned
            .chars()
            .all(|character| character.is_digit(base as u32))
    {
        return false;
    }
    Integer::from_str_radix(&cleaned, base)
        .ok()
        .zip(Integer::from_str_radix(rendered, base).ok())
        .is_some_and(|(entered, result)| entered == result)
}

#[cfg(test)]
#[allow(dead_code)]
fn financial_value_text(
    operation: &str,
    principal: f64,
    rate: f64,
    periods: f64,
    payment: f64,
    format: &str,
    precision: i32,
) -> String {
    let r = rate / 100.0;
    let value = match operation {
        "Ctrm" => {
            if rate > 0.0 && principal > 0.0 && payment > 0.0 {
                (payment / principal).ln() / (1.0 + r).ln()
            } else {
                f64::NAN
            }
        }
        "Ddb" => {
            if periods > 0.0 {
                principal * (2.0 / periods)
            } else {
                f64::NAN
            }
        }
        "Fv" => {
            principal * (1.0 + r).powf(periods)
                + if r == 0.0 {
                    payment * periods
                } else {
                    payment * ((1.0 + r).powf(periods) - 1.0) / r
                }
        }
        "Gpm" => {
            if principal != 0.0 {
                (principal - payment) / principal * 100.0
            } else {
                f64::NAN
            }
        }
        "Pmt" => {
            if periods <= 0.0 {
                f64::NAN
            } else if r == 0.0 {
                principal / periods
            } else {
                principal * r / (1.0 - (1.0 + r).powf(-periods))
            }
        }
        "Pv" => {
            if r == 0.0 {
                principal - payment * periods
            } else {
                principal / (1.0 + r).powf(periods)
            }
        }
        "Rate" => {
            if principal > 0.0 && payment > 0.0 && periods > 0.0 {
                ((payment / principal).powf(1.0 / periods) - 1.0) * 100.0
            } else {
                f64::NAN
            }
        }
        "Sln" => {
            if periods > 0.0 {
                (principal - payment) / periods
            } else {
                f64::NAN
            }
        }
        "Syd" => {
            if periods > 0.0 {
                (principal - payment) * periods / (periods * (periods + 1.0) / 2.0)
            } else {
                f64::NAN
            }
        }
        "Term" => {
            if payment > 0.0 {
                principal / payment
            } else {
                f64::NAN
            }
        }
        _ => f64::NAN,
    };
    if value.is_finite() {
        format_value(value, format, precision)
    } else {
        "Invalid values".into()
    }
}

fn unit_factor(unit: &str) -> Option<(f64, &'static str)> {
    match unit {
        "Kilometers" => Some((1000.0, "length")),
        "Meters" => Some((1.0, "length")),
        "Centimeters" => Some((0.01, "length")),
        "Millimeters" => Some((0.001, "length")),
        "Miles" => Some((1609.344, "length")),
        "Yards" => Some((0.9144, "length")),
        "Feet" => Some((0.3048, "length")),
        "Inches" => Some((0.0254, "length")),
        "Tonnes" => Some((1000.0, "mass")),
        "Kilograms" => Some((1.0, "mass")),
        "Grams" => Some((0.001, "mass")),
        "Pounds" => Some((0.45359237, "mass")),
        "Ounces" => Some((0.028349523125, "mass")),
        "Square meters" => Some((1.0, "area")),
        "Square kilometers" => Some((1_000_000.0, "area")),
        "Hectares" => Some((10_000.0, "area")),
        "Acres" => Some((4046.8564224, "area")),
        "Square feet" => Some((0.09290304, "area")),
        "Liters" => Some((1.0, "volume")),
        "Milliliters" => Some((0.001, "volume")),
        "Cubic meters" => Some((1000.0, "volume")),
        "Gallons (US)" => Some((3.785411784, "volume")),
        "Cups (US)" => Some((0.2365882365, "volume")),
        "Seconds" => Some((1.0, "time")),
        "Minutes" => Some((60.0, "time")),
        "Hours" => Some((3600.0, "time")),
        "Days" => Some((86400.0, "time")),
        "Weeks" => Some((604800.0, "time")),
        "Meters/second" => Some((1.0, "speed")),
        "Kilometers/hour" => Some((1.0 / 3.6, "speed")),
        "Miles/hour" => Some((0.44704, "speed")),
        "Knots" => Some((0.514444444, "speed")),
        "Bytes" => Some((1.0, "data")),
        "Kilobytes" => Some((1000.0, "data")),
        "Megabytes" => Some((1_000_000.0, "data")),
        "Gigabytes" => Some((1_000_000_000.0, "data")),
        "Kibibytes" => Some((1024.0, "data")),
        "Mebibytes" => Some((1_048_576.0, "data")),
        "Degrees" => Some((std::f64::consts::PI / 180.0, "angle")),
        "Radians" => Some((1.0, "angle")),
        "Gradians" => Some((std::f64::consts::PI / 200.0, "angle")),
        _ => None,
    }
}

#[cfg(test)]
fn temperature_to_kelvin(value: f64, unit: &str) -> Option<f64> {
    match unit {
        "Celsius" => Some(value + 273.15),
        "Fahrenheit" => Some((value - 32.0) * 5.0 / 9.0 + 273.15),
        "Kelvin" => Some(value),
        _ => None,
    }
}
#[cfg(test)]
fn temperature_from_kelvin(value: f64, unit: &str) -> Option<f64> {
    match unit {
        "Celsius" => Some(value - 273.15),
        "Fahrenheit" => Some((value - 273.15) * 9.0 / 5.0 + 32.0),
        "Kelvin" => Some(value),
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn parse_number(text: &str) -> f64 {
        text.parse()
            .unwrap_or_else(|error| panic!("could not parse '{text}': {error}"))
    }

    #[test]
    fn preferences_keep_current_defaults_and_round_trip() {
        let defaults = Preferences::default();
        assert_eq!(defaults.result_format, "automatic");
        assert_eq!(defaults.precision, 9);
        assert_eq!(defaults.angle_unit, "degrees");
        assert!(defaults.digit_grouping);
        assert_eq!(defaults.conversion_from_unit, "Celsius");
        assert_eq!(defaults.conversion_to_unit, "Fahrenheit");
        assert_eq!(
            defaults.window_states,
            [
                WindowState {
                    width: 370,
                    height: 620,
                    maximized: false,
                },
                WindowState {
                    width: 620,
                    height: 620,
                    maximized: false,
                },
                WindowState {
                    width: 620,
                    height: 620,
                    maximized: false,
                },
                WindowState {
                    width: 620,
                    height: 632,
                    maximized: false,
                },
                WindowState {
                    width: 380,
                    height: 620,
                    maximized: false,
                },
            ]
        );
        assert_eq!(defaults.programmer_base, 10);
        assert_eq!(defaults.programmer_word_bits, 64);
        assert!(!defaults.programmer_bit_panel_enabled);
        assert_eq!(CONFIG_FILE_NAME, "flufflinux-calculator.conf");
        assert_eq!(
            parse_preferences(&serialize_preferences(&defaults)),
            defaults
        );
    }

    #[test]
    fn preferences_validate_loaded_values() {
        let preferences = parse_preferences(
            "result_format=bogus\nprecision=99\nangle_unit=radians\n\
             digit_grouping=false\nconversion_from_unit=Yards\n\
             conversion_to_unit=Kelvin\nwindow_width=200\nwindow_height=99999\n\
             window_maximized=true\nprogrammer_base=3\nprogrammer_word_bits=65\n\
             programmer_bit_panel_enabled=maybe\n\
             advanced_window_width=701\nadvanced_window_height=601\n\
             advanced_window_maximized=false\n\
             programming_window_width=-10\nprogramming_window_height=100\n",
        );
        assert_eq!(preferences.result_format, "automatic");
        assert_eq!(preferences.precision, 99);
        assert_eq!(preferences.angle_unit, "radians");
        assert!(!preferences.digit_grouping);
        assert_eq!(preferences.conversion_from_unit, "Yards");
        assert_eq!(preferences.conversion_to_unit, "Kelvin");
        assert_eq!(
            preferences.window_states[CalculatorMode::Basic.index()],
            WindowState {
                width: 340,
                height: 16_384,
                maximized: true,
            }
        );
        assert_eq!(
            preferences.window_states[CalculatorMode::Advanced.index()],
            WindowState {
                width: 701,
                height: 601,
                maximized: false,
            }
        );
        assert_eq!(
            preferences.window_states[CalculatorMode::Programming.index()],
            WindowState {
                width: 340,
                height: 632,
                maximized: true,
            }
        );
        assert_eq!(preferences.programmer_base, 10);
        assert_eq!(preferences.programmer_word_bits, 64);
        assert!(!preferences.programmer_bit_panel_enabled);
    }

    #[test]
    fn legacy_window_state_migrates_to_each_mode() {
        let preferences =
            parse_preferences("window_width=777\nwindow_height=888\nwindow_maximized=true\n");

        for mode in CalculatorMode::ALL {
            assert_eq!(
                preferences.window_states[mode.index()],
                WindowState {
                    width: 777,
                    height: 888,
                    maximized: true,
                },
                "{} window state",
                mode.name()
            );
        }
    }

    #[test]
    fn mode_window_state_overrides_legacy_values_independently() {
        let preferences = parse_preferences(
            "window_width=700\nwindow_height=800\nwindow_maximized=true\n\
             financial_window_width=910\nfinancial_window_maximized=false\n\
             conversion_window_height=730\n",
        );

        assert_eq!(
            preferences.window_states[CalculatorMode::Financial.index()],
            WindowState {
                width: 910,
                height: 800,
                maximized: false,
            }
        );
        assert_eq!(
            preferences.window_states[CalculatorMode::Conversion.index()],
            WindowState {
                width: 700,
                height: 730,
                maximized: true,
            }
        );
        assert_eq!(
            preferences.window_states[CalculatorMode::Basic.index()],
            WindowState {
                width: 700,
                height: 800,
                maximized: true,
            }
        );
    }

    #[test]
    fn programmer_preferences_accept_only_supported_values() {
        let preferences = parse_preferences(
            "programmer_base=16\nprogrammer_word_bits=4096\n\
             programmer_bit_panel_enabled=true\n",
        );
        assert_eq!(preferences.programmer_base, 16);
        assert_eq!(preferences.programmer_word_bits, 4096);
        assert!(preferences.programmer_bit_panel_enabled);

        for base in [2, 8, 10, 16] {
            assert!(is_valid_programmer_base(base));
        }
        for bits in PROGRAMMER_WORD_BITS {
            assert!(is_valid_programmer_word_bits(bits));
        }
        for base in [-1, 0, 3, 9, 12, 17] {
            assert!(!is_valid_programmer_base(base));
        }
        for bits in [-1, 0, 7, 24, 65, 8192] {
            assert!(!is_valid_programmer_word_bits(bits));
        }
    }

    #[test]
    fn result_format_applies_to_decimal_mode_outputs() {
        let cases = [
            ("automatic", "12000"),
            ("fixed", "12000.000000000"),
            ("scientific", "1.200000000e4"),
            ("engineering", "12.000000000e3"),
        ];

        for (format, expected) in cases {
            assert_eq!(
                convert_value_precise_text("12", "Kilometers", "Meters", format, 9),
                expected
            );
            assert_eq!(
                precise::financial_value("Ddb", "60000", "0", "10", "0", format, 9).unwrap(),
                expected
            );
        }
    }

    #[test]
    fn financial_and_conversion_keep_high_precision_inputs() {
        assert_eq!(
            convert_value_precise_text(
                "100000000000000000000000.1",
                "Meters",
                "Millimeters",
                "automatic",
                30,
            ),
            "100000000000000000000000100"
        );
        assert_eq!(
            precise::financial_value(
                "Ddb",
                "100000000000000000000000.5",
                "0",
                "10",
                "0",
                "automatic",
                30,
            )
            .unwrap(),
            "20000000000000000000000.1"
        );
    }

    #[test]
    fn conversion_display_uses_sensible_automatic_precision() {
        let cases = [
            ("100000", "Meters", "Miles", "62.137119"),
            ("1", "Miles", "Kilometers", "1.609344"),
            ("1", "Meters", "Feet", "3.28084"),
            ("1", "Feet", "Yards", "0.333333"),
            ("1", "Millimeters", "Miles", "6.2137119e-7"),
            ("100", "Celsius", "Fahrenheit", "212"),
        ];

        for (value, from, to, expected) in cases {
            assert_eq!(
                convert_value_precise_text(value, from, to, "conversion", 16),
                expected,
                "{value} {from} to {to}"
            );
        }
    }

    #[test]
    fn undo_redo_moves_between_three_completed_history_records() {
        let mut backend = CalculatorBackendRust::default();
        backend.history.clear();
        backend.undo_stack.clear();
        backend.redo_stack.clear();

        for (expression, result) in [("2+2", "4"), ("4+3", "7"), ("7*2", "14")] {
            backend.expression = expression.into();
            backend.checkpoint_history();
            backend.expression = result.into();
            backend.result = result.into();
            backend.error = QString::default();
            backend.history.push((expression.into(), result.into()));
        }
        assert_eq!(backend.undo_stack.len(), 3);

        let previous_record = backend.take_undo_snapshot().unwrap();
        assert_eq!(previous_record.expression, "7");
        assert_eq!(previous_record.result, "7");
        assert_eq!(previous_record.history.len(), 2);
        assert_eq!(previous_record.history[1], ("4+3".into(), "7".into()));
        assert_eq!(backend.redo_stack[0].history.len(), 3);

        backend.expression = previous_record.expression.into();
        backend.result = previous_record.result.into();
        backend.error = previous_record.error.into();
        backend.history = previous_record.history;
        let restored_record = backend.take_redo_snapshot().unwrap();
        assert_eq!(restored_record.expression, "14");
        assert_eq!(restored_record.history.len(), 3);

        backend.redo_stack.push(restored_record);
        backend.abandon_redo();
        assert!(backend.redo_stack.is_empty());
    }

    #[test]
    fn undo_redo_availability_matches_real_stack_state() {
        let mut backend = CalculatorBackendRust::default();
        backend.history.clear();
        backend.undo_stack.clear();
        backend.redo_stack.clear();
        assert_eq!(backend.history_action_availability(), (false, false));

        backend.checkpoint_history();
        backend.history.push(("2+2".into(), "4".into()));
        assert_eq!(backend.history_action_availability(), (true, false));

        let previous = backend.take_undo_snapshot().unwrap();
        backend.history = previous.history;
        assert_eq!(backend.history_action_availability(), (false, true));

        let next = backend.take_redo_snapshot().unwrap();
        backend.history = next.history;
        assert_eq!(backend.history_action_availability(), (true, false));

        backend.abandon_redo();
        backend.undo_stack.clear();
        assert_eq!(backend.history_action_availability(), (false, false));
    }

    #[test]
    fn wrap_hint_matrix_50_cases() {
        let bases = [
            "0",
            "9",
            "99",
            "9999",
            "1234567890",
            "192.168.0.129",
            "123,456,789",
            "-0.000000001",
            "(12345+67890)",
            "999999999999999999999999999999",
        ];
        let tails = ["", "+1", "-22", "*333", "/4444"];
        let mut checked = 0;

        for base in bases {
            for tail in tails {
                let expression = format!("{base}{tail}");
                let hinted = add_wrap_hints(&expression);
                assert_eq!(hinted.replace(WRAP_HINT, ""), expression);
                assert_eq!(add_wrap_hints(&hinted), hinted);
                assert!(!hinted.contains("\u{200b}\u{200b}"));
                assert_eq!(
                    evaluate(&hinted, AngleUnit::Degrees),
                    evaluate(&expression, AngleUnit::Degrees)
                );
                checked += 1;
            }
        }

        assert_eq!(checked, 50);
        assert_eq!(
            add_wrap_hints("192.168.0.129+192.168.0.23453+2121"),
            "192.168.0.129+\u{200b}192.168.0.23453+\u{200b}2121"
        );
        assert_eq!(add_wrap_hints("-12+1e-10"), "-12+\u{200b}1e-10");
    }

    #[test]
    fn automatic_digit_grouping_examples() {
        let cases = [
            ("0", "0"),
            ("999", "999"),
            ("1000", "1,000"),
            ("10000", "10,000"),
            ("100000", "100,000"),
            ("1000000", "1,000,000"),
            ("1,000,000", "1,000,000"),
            ("-1234567.8901", "-1,234,567.8901"),
            ("sqrt(1000000)", "sqrt(1,000,000)"),
            ("1000+20000*300000", "1,000+20,000*300,000"),
            ("1e1000", "1e1000"),
            ("1234e-1000", "1,234e-1000"),
            ("192.168.0.129", "192.168.0.129"),
            ("3000+4000i", "3,000+4,000i"),
            ("root(3,1000)", "root(3,1,000)"),
            ("nthroot(4,10000)", "nthroot(4,10,000)"),
            ("root(1000,2)", "root(1000,2)"),
        ];

        for (input, expected) in cases {
            assert_eq!(group_ascii_number_literals(input), expected);
            assert_eq!(group_ascii_number_literals(expected), expected);
        }
        assert_eq!(
            format_expression_for_display("1000+20000", true),
            "1,000+\u{200b}20,000"
        );
        assert_eq!(
            format_expression_for_display("1,000+20,000", false),
            "1,000+\u{200b}20,000"
        );
        assert_eq!(
            reformat_digit_grouping("1,000+\u{200b}20,000", false),
            "1000+20000"
        );
        assert_eq!(
            reformat_digit_grouping("root(3,1,000)", false),
            "root(3,1000)"
        );
        assert_eq!(
            format_expression_for_display("root(3,1000)", true),
            "root(3,1,000)"
        );
    }

    #[test]
    fn automatic_digit_grouping_matrix_50_cases() {
        let numbers = [
            "0",
            "999",
            "1000",
            "12345",
            "999999",
            "1000000",
            "1234.5",
            "9876543.2109",
            "0.000001",
            "123456789012345",
        ];
        let templates = ["{}", "{}+1", "2*{}", "sqrt({})", "-({})/2"];
        let mut checked = 0;

        for number in numbers {
            for template in templates {
                let expression = template.replace("{}", number);
                let grouped = group_ascii_number_literals(&expression);
                assert_eq!(group_ascii_number_literals(&grouped), grouped);
                let original_value = evaluate(&expression, AngleUnit::Degrees).unwrap();
                let grouped_value = evaluate(&grouped, AngleUnit::Degrees).unwrap();
                assert_eq!(original_value, grouped_value);
                checked += 1;
            }
        }

        assert_eq!(checked, 50);
    }

    #[test]
    fn financial_mode_matrix_100() {
        let operations = [
            "Ctrm", "Ddb", "Fv", "Gpm", "Pmt", "Pv", "Rate", "Sln", "Syd", "Term",
        ];
        let mut checked = 0;

        for operation in operations {
            for scenario in 1..=10 {
                let principal = 1_000.0 + scenario as f64 * 137.0;
                let rate = 1.0 + scenario as f64 * 0.75;
                let periods = scenario as f64 + 2.0;
                let growth = 1.0 + rate / 100.0;
                let payment = match operation {
                    "Ctrm" | "Rate" => principal * growth.powf(periods),
                    "Term" => principal / periods,
                    _ => 25.0 + scenario as f64 * 3.0,
                };
                let r = rate / 100.0;
                let expected = match operation {
                    "Ctrm" => periods,
                    "Ddb" => principal * 2.0 / periods,
                    "Fv" => {
                        principal * growth.powf(periods)
                            + payment * (growth.powf(periods) - 1.0) / r
                    }
                    "Gpm" => (principal - payment) / principal * 100.0,
                    "Pmt" => principal * r / (1.0 - growth.powf(-periods)),
                    "Pv" => principal / growth.powf(periods),
                    "Rate" => rate,
                    "Sln" => (principal - payment) / periods,
                    "Syd" => (principal - payment) * periods / (periods * (periods + 1.0) / 2.0),
                    "Term" => periods,
                    _ => unreachable!(),
                };
                let rendered = precise::financial_value(
                    operation,
                    &principal.to_string(),
                    &rate.to_string(),
                    &periods.to_string(),
                    &payment.to_string(),
                    "automatic",
                    12,
                )
                .unwrap();
                let actual = parse_number(&rendered);
                let tolerance = 1e-9 * expected.abs().max(1.0);
                assert!(
                    (actual - expected).abs() <= tolerance,
                    "{operation} scenario {scenario}: expected {expected}, got {actual}"
                );
                checked += 1;
            }
        }

        assert_eq!(checked, 100);
        assert_eq!(
            precise::financial_value("Pmt", "100", "5", "0", "0", "automatic", 12),
            Err("Invalid values".into())
        );
        assert_eq!(
            precise::financial_value("Unknown", "1", "1", "1", "1", "automatic", 12),
            Err("Invalid values".into())
        );
    }

    #[test]
    fn conversion_mode_matrix_100() {
        let scalar_units = [
            "Kilometers",
            "Meters",
            "Centimeters",
            "Millimeters",
            "Miles",
            "Yards",
            "Feet",
            "Inches",
            "Tonnes",
            "Kilograms",
            "Grams",
            "Pounds",
            "Ounces",
            "Square meters",
            "Square kilometers",
            "Hectares",
            "Acres",
            "Square feet",
            "Liters",
            "Milliliters",
            "Cubic meters",
            "Gallons (US)",
            "Cups (US)",
            "Seconds",
            "Minutes",
            "Hours",
            "Days",
            "Weeks",
            "Meters/second",
            "Kilometers/hour",
            "Miles/hour",
            "Knots",
            "Bytes",
            "Kilobytes",
            "Megabytes",
            "Gigabytes",
            "Kibibytes",
            "Mebibytes",
            "Degrees",
            "Radians",
            "Gradians",
        ];
        let all_units = scalar_units
            .iter()
            .copied()
            .chain(["Celsius", "Fahrenheit", "Kelvin"]);
        let mut checked = 0;

        for (index, unit) in all_units.enumerate() {
            let value = index as f64 * 1.25 - 20.0;
            let actual = parse_number(&convert_value_precise_text(
                &value.to_string(),
                unit,
                unit,
                "automatic",
                12,
            ));
            assert!(
                (actual - value).abs() <= 1e-9,
                "identity conversion for {unit}"
            );
            checked += 1;
        }

        for (index, unit) in scalar_units.iter().enumerate() {
            let (factor, category) = unit_factor(unit).unwrap();
            let reference = scalar_units
                .iter()
                .find(|candidate| unit_factor(candidate).unwrap().1 == category)
                .unwrap();
            let reference_factor = unit_factor(reference).unwrap().0;
            let value = index as f64 + 0.5;
            let expected = value * factor / reference_factor;
            let actual = parse_number(&convert_value_precise_text(
                &value.to_string(),
                unit,
                reference,
                "automatic",
                12,
            ));
            let tolerance = 1e-9 * expected.abs().max(1.0);
            assert!(
                (actual - expected).abs() <= tolerance,
                "{unit} to {reference}"
            );
            checked += 1;
        }

        for from in ["Celsius", "Fahrenheit", "Kelvin"] {
            for to in ["Celsius", "Fahrenheit", "Kelvin"] {
                let value = 37.5;
                let kelvin = temperature_to_kelvin(value, from).unwrap();
                let expected = temperature_from_kelvin(kelvin, to).unwrap();
                let actual = parse_number(&convert_value_precise_text(
                    &value.to_string(),
                    from,
                    to,
                    "automatic",
                    12,
                ));
                assert!((actual - expected).abs() <= 1e-9, "{from} to {to}");
                checked += 1;
            }
        }

        for (from, to) in [
            ("Meters", "Kilograms"),
            ("Seconds", "Liters"),
            ("Bytes", "Degrees"),
            ("Celsius", "Meters"),
            ("Miles/hour", "Ounces"),
            ("Unknown", "Meters"),
        ] {
            assert_eq!(
                convert_value_precise_text("1", from, to, "automatic", 12),
                "Incompatible units"
            );
            checked += 1;
        }

        assert_eq!(checked, 100);
    }

    #[test]
    fn programming_mode_matrix_100() {
        fn radix(value: i64, base: i32) -> String {
            match base {
                2 => format!("{value:b}"),
                8 => format!("{value:o}"),
                10 => value.to_string(),
                16 => format!("{value:X}"),
                _ => unreachable!(),
            }
        }

        let bases = [2, 8, 10, 16];
        let mut checked = 0;
        for value in 0..15 {
            for (index, from_base) in bases.iter().enumerate() {
                let to_base = bases[(index + 1) % bases.len()];
                let source = radix(value, *from_base);
                let expected = radix(value, to_base);
                assert_eq!(
                    programmer_value_text(&source, *from_base, to_base, [8, 16, 32, 64][index]),
                    expected
                );
                checked += 1;
            }
        }

        for round in 1..=2 {
            for operation in 0..20 {
                let a = (round * 6 + operation + 1) as i64;
                let b = (round * 3 + operation % 5 + 1) as i64;
                let (expression, expected) = match operation {
                    0 => (format!("{a}∧{b}"), (a & b) as f64),
                    1 => (format!("{a}∨{b}"), (a | b) as f64),
                    2 => (format!("{a}⊻{b}"), (a ^ b) as f64),
                    3 => (format!("{a}≪2"), a.wrapping_shl(2) as f64),
                    4 => (format!("{a}≫1"), a.wrapping_shr(1) as f64),
                    5 => (format!("¬{a}"), (!a) as f64),
                    6 => (format!("{a} mod {b}"), (a % b) as f64),
                    7 => (format!("twos({a})"), (-a) as f64),
                    8 => {
                        let source = (round as i64) << 56;
                        (format!("swap({source})"), round as f64)
                    }
                    9 => {
                        let power = round + 5;
                        (format!("log2({})", 1_i64 << power), power as f64)
                    }
                    10 => (format!("ceil({a}.25)"), (a + 1) as f64),
                    11 => (format!("floor({a}.75)"), a as f64),
                    12 => (
                        format!("log({})", 10_i64.pow((round + 1) as u32)),
                        (round + 1) as f64,
                    ),
                    13 => {
                        let value = (round as f64).exp();
                        (format!("ln({value})"), round as f64)
                    }
                    14 => (format!("int({a}.75)"), a as f64),
                    15 => (format!("abs(-{a})"), a as f64),
                    16 => (format!("frac(-{a}.25)"), -0.25),
                    17 => {
                        let value = round + 3;
                        let expected = (1..=value).product::<i32>() as f64;
                        (format!("{value}!"), expected)
                    }
                    18 => (format!("{a}^2"), (a * a) as f64),
                    _ => (format!("{a}^{round}"), (a as f64).powi(round)),
                };
                let actual = evaluate(&expression, AngleUnit::Degrees)
                    .unwrap_or_else(|error| panic!("{expression} failed: {error}"));
                let tolerance = 1e-9 * expected.abs().max(1.0);
                assert!((actual - expected).abs() <= tolerance, "{expression}");
                checked += 1;
            }
        }

        assert_eq!(checked, 100);
        assert_eq!(programmer_value_text("1FF", 16, 16, 8), "FF");
        let wide: Integer = (Integer::from(1) << 200) + 1;
        assert_eq!(
            programmer_value_text(&wide.to_string_radix(2), 2, 16, 256),
            wide.to_string_radix(16).to_uppercase()
        );
        let very_wide: Integer = (Integer::from(1) << 4095) + 1;
        assert_eq!(
            programmer_value_text(&very_wide.to_string_radix(16), 16, 16, 4096),
            very_wide.to_string_radix(16).to_uppercase()
        );
        assert_eq!(programmer_value_text("2", 2, 10, 8), "Invalid value");
        assert_eq!(programmer_value_text("10", 10, 3, 8), "Invalid base");
    }

    #[test]
    fn programming_live_preview_matrix_160() {
        let widths = [8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096];
        let bases = [16, 10, 8, 2];
        let mut checked = 0;

        for bits in widths {
            let value = (Integer::from(1) << (bits - 1)) + 37;
            let expected = bases
                .iter()
                .map(|base| render_programmer_integer(&value, *base, bits).unwrap())
                .collect::<Vec<_>>();

            for from_base in bases {
                let source = render_programmer_integer(&value, from_base, bits).unwrap();
                let preview = programmer_expression_values_text(&source, from_base, bits, 20)
                    .unwrap_or_else(|error| {
                        panic!("{bits}-bit base {from_base} preview failed: {error}")
                    });
                let actual = preview.split('\t').collect::<Vec<_>>();
                assert_eq!(actual.len(), 4, "{bits}-bit base {from_base}");
                for (index, expected_value) in expected.iter().enumerate() {
                    assert_eq!(
                        actual[index], *expected_value,
                        "{bits}-bit base {from_base} target {}",
                        bases[index]
                    );
                    checked += 1;
                }
            }
        }

        assert_eq!(checked, 160);
    }

    #[test]
    fn programming_live_preview_examples_and_edges() {
        assert_eq!(
            programmer_expression_values_text("9032", 10, 64, 20).unwrap(),
            "2348\t9032\t21510\t10001101001000"
        );
        assert_eq!(
            programmer_expression_values_text("FF+1", 16, 16, 20).unwrap(),
            "100\t256\t400\t100000000"
        );
        assert_eq!(
            programmer_expression_values_text("FF+1", 16, 8, 20).unwrap(),
            "0\t0\t0\t0"
        );
        assert_eq!(
            programmer_expression_values_text("FF", 16, 8, 20).unwrap(),
            "FF\t-1\t377\t11111111"
        );
        assert_eq!(
            programmer_expression_values_text("7F", 16, 8, 20).unwrap(),
            "7F\t127\t177\t1111111"
        );
        assert_eq!(
            programmer_expression_values_text("80", 16, 8, 20).unwrap(),
            "80\t-128\t200\t10000000"
        );
        assert!(programmer_expression_values_text("", 10, 64, 20).is_err());
        assert!(programmer_expression_values_text("1+", 10, 64, 20).is_err());
        assert!(programmer_expression_values_text("A", 10, 64, 20).is_err());
        assert_eq!(
            programmer_expression_values_text("0.5", 10, 64, 20).unwrap(),
            "\t0.5\t\t"
        );

        let hex = programmer_expression_value_text("10", 10, 16, 64, 20).unwrap();
        let binary = programmer_expression_value_text(&hex, 16, 2, 64, 20).unwrap();
        let octal = programmer_expression_value_text(&binary, 2, 8, 64, 20).unwrap();
        let decimal = programmer_expression_value_text(&octal, 8, 10, 64, 20).unwrap();
        assert_eq!(
            (hex, binary, octal, decimal),
            ("A".into(), "1010".into(), "12".into(), "10".into())
        );

        let radians_preview =
            programmer_expression_values_text_with_angle("sin(1)", 10, 64, 20, AngleUnit::Radians)
                .unwrap();
        let radians_result =
            programmer_calculation_text("sin(1)", 10, 64, AngleUnit::Radians, "automatic", 20)
                .unwrap();
        assert_eq!(
            radians_preview.split('\t').nth(1),
            Some(radians_result.as_str())
        );
    }

    #[test]
    fn programming_word_size_changes_preserve_signed_value() {
        assert_eq!(
            programmer_resized_value_text("FF", 16, 8, 16, 20).unwrap(),
            "FFFF"
        );
        assert_eq!(
            programmer_resized_value_text("81", 16, 8, 16, 20).unwrap(),
            "FF81"
        );
        assert_eq!(
            programmer_resized_value_text("10000001", 2, 8, 16, 20).unwrap(),
            "1111111110000001"
        );
        assert_eq!(
            programmer_resized_value_text("FF81", 16, 16, 8, 20).unwrap(),
            "81"
        );
        assert_eq!(
            programmer_resized_value_text("255", 10, 16, 8, 20).unwrap(),
            "-1"
        );

        let high_bit_and_one = format!("1{}1", "0".repeat(4094));
        assert_eq!(
            programmer_resized_value_text(&high_bit_and_one, 2, 4096, 8, 20).unwrap(),
            "1"
        );
        assert_eq!(
            programmer_resized_value_text(&high_bit_and_one, 2, 4096, 16, 20).unwrap(),
            "1"
        );
    }

    #[test]
    fn programming_decimal_equals_obeys_signed_word_size() {
        let calculate = |expression| {
            programmer_calculation_text(expression, 10, 8, AngleUnit::Degrees, "automatic", 20)
                .unwrap()
        };
        for (expression, expected) in [
            ("127", "127"),
            ("128", "-128"),
            ("255", "-1"),
            ("256", "0"),
            ("-129", "127"),
        ] {
            assert_eq!(calculate(expression), expected, "{expression}");
        }
        assert_eq!(calculate("0.5"), "0.5");
        assert_eq!(calculate("4^(-1)"), "0.25");
        assert_eq!(calculate("-5÷2"), "-2.5");
        assert_eq!(calculate("-5 mod 2"), "-1");
        assert_eq!(calculate("-50%"), "-0.5");
        assert_eq!(calculate("(-50)%"), "-0.5");

        for expression in ["sqrt(-1)", "√-1", "(-1)!"] {
            assert!(
                programmer_calculation_text(
                    expression,
                    10,
                    8,
                    AngleUnit::Degrees,
                    "automatic",
                    20,
                )
                .is_err(),
                "{expression} should reject a negative mathematical operand"
            );
        }
    }

    #[test]
    fn programming_live_preview_rejects_hostile_work() {
        assert!(programmer_expression_values_text("2^1000001", 10, 64, 20).is_err());
        assert!(programmer_expression_values_text("1≫4294967296", 10, 64, 20).is_err());
        let too_long = "1".repeat(crate::precise::MAX_PROGRAMMER_INPUT_CHARS + 1);
        assert!(programmer_expression_values_text(&too_long, 2, 4096, 20).is_err());
    }

    #[test]
    fn programming_exact_fixed_width_arithmetic_keeps_low_bits() {
        for bits in [8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096] {
            let maximum = "F".repeat((bits / 4) as usize);
            for expression in [format!("{maximum}*{maximum}"), format!("({maximum})^2")] {
                assert_eq!(
                    programmer_expression_values_text(&expression, 16, bits, 20).unwrap(),
                    "1\t1\t1\t1",
                    "{bits}-bit {expression}"
                );
            }
        }

        let over_width = format!("1{}1", "0".repeat(1024));
        assert_eq!(
            programmer_expression_values_text(&over_width, 2, 8, 20).unwrap(),
            "1\t1\t1\t1"
        );
        assert_eq!(
            programmer_expression_values_text("100000000≫1", 2, 8, 20).unwrap(),
            "0\t0\t0\t0"
        );
        assert!(programmer_expression_values_text("1÷100", 16, 8, 20).is_err());
        assert!(programmer_expression_values_text("1 mod 100", 16, 8, 20).is_err());

        for (expression, expected) in [
            ("twos(1)", "FF\t-1\t377\t11111111"),
            ("swap(1)", "1\t1\t1\t1"),
            ("abs(-81)", "7F\t127\t177\t1111111"),
            ("floor(101)", "1\t1\t1\t1"),
            ("ceil(101)", "1\t1\t1\t1"),
            ("round(101)", "1\t1\t1\t1"),
            ("int(101)", "1\t1\t1\t1"),
            ("frac(101)", "0\t0\t0\t0"),
            ("5!", "78\t120\t170\t1111000"),
        ] {
            assert_eq!(
                programmer_expression_values_text(expression, 16, 8, 20).unwrap(),
                expected,
                "{expression}"
            );
        }
    }

    #[test]
    fn programming_calculation_matrix_100() {
        fn radix(value: i64, base: i32) -> String {
            match base {
                2 => format!("{value:b}"),
                8 => format!("{value:o}"),
                10 => value.to_string(),
                16 => format!("{value:X}"),
                _ => unreachable!(),
            }
        }

        let mut checked = 0;
        for base in [2, 8, 10, 16] {
            for operation in 0..25 {
                let n = |value| radix(value, base);
                let (expression, expected) = match operation {
                    0 => (format!("{}+{}", n(21), n(13)), 34),
                    1 => (format!("{}-{}", n(34), n(13)), 21),
                    2 => (format!("{}×{}", n(7), n(6)), 42),
                    3 => (format!("{}÷{}", n(84), n(7)), 12),
                    4 => (format!("{} mod {}", n(29), n(6)), 5),
                    5 => (format!("{}∧{}", n(45), n(27)), 9),
                    6 => (format!("{}∨{}", n(45), n(27)), 63),
                    7 => (format!("{}⊻{}", n(45), n(27)), 54),
                    8 => (format!("{}≪{}", n(3), n(4)), 48),
                    9 => (format!("{}≫{}", n(48), n(4)), 3),
                    10 => (format!("¬{}", n(5)), -6),
                    11 => (format!("{}^{}", n(9), n(2)), 81),
                    12 => (format!("{}^{}", n(3), n(4)), 81),
                    13 => (format!("twos({})", n(19)), -19),
                    14 => (format!("swap({})", n(1)), 256),
                    15 => (format!("log2({})", n(16)), 4),
                    16 => (format!("ceil({})", n(5)), 5),
                    17 => (format!("floor({})", n(5)), 5),
                    18 => (format!("log({})", n(100)), 2),
                    19 => (format!("int({})", n(9)), 9),
                    20 => (format!("abs(-{})", n(27)), 27),
                    21 => (format!("ln({})", n(1)), 0),
                    22 => (format!("frac({})", n(5)), 0),
                    23 => (format!("{}!", n(5)), 120),
                    _ => (format!("-({}+{})", n(2), n(3)), -5),
                };
                let actual = programmer_calculation_text(
                    &expression,
                    base,
                    16,
                    AngleUnit::Degrees,
                    "automatic",
                    20,
                )
                .unwrap_or_else(|error| panic!("{expression} failed: {error}"));
                let expected = if base == 10 || expected >= 0 {
                    radix(expected, base)
                } else {
                    radix(65_536 + expected, base)
                };
                assert_eq!(actual, expected.to_uppercase(), "base {base}: {expression}");
                checked += 1;
            }
        }

        assert_eq!(checked, 100);
    }

    #[test]
    fn programming_radix_stress_matrix_400() {
        fn radix(value: i64, base: i32) -> String {
            match base {
                2 => format!("{value:b}"),
                8 => format!("{value:o}"),
                10 => value.to_string(),
                16 => format!("{value:X}"),
                _ => unreachable!(),
            }
        }

        fn expected(value: i64, base: i32) -> String {
            if base == 10 {
                return value.to_string();
            }
            radix(value.rem_euclid(1 << 16), base).to_uppercase()
        }

        for base in [2, 8, 10, 16] {
            let mut checked = 0;
            for case in 0..100 {
                let a = case as i64 + 3;
                let b = (case % 13 + 1) as i64;
                let shift = (case % 4 + 1) as i64;
                let n = |value| radix(value, base);
                let (expression, result) = match case % 10 {
                    0 => (format!("{}+{}", n(a), n(b)), a + b),
                    1 => (format!("{}-{}", n(b), n(a)), b - a),
                    2 => (format!("{}×{}", n(a), n(b)), a * b),
                    3 => (format!("{}÷{}", n(a * b), n(b)), a),
                    4 => (format!("{} mod {}", n(a), n(b)), a % b),
                    5 => (format!("{}∧{}", n(a), n(b)), a & b),
                    6 => (format!("{}∨{}", n(a), n(b)), a | b),
                    7 => (format!("{}⊻{}", n(a), n(b)), a ^ b),
                    8 => (format!("{}≪{}", n(a), n(shift)), a << shift),
                    _ => (format!("{}≫{}", n(a << shift), n(shift)), a),
                };
                let actual = programmer_calculation_text(
                    &expression,
                    base,
                    16,
                    AngleUnit::Degrees,
                    "automatic",
                    20,
                )
                .unwrap_or_else(|error| panic!("base {base} {expression} failed: {error}"));
                assert_eq!(actual, expected(result, base), "base {base}: {expression}");
                checked += 1;
            }
            assert_eq!(checked, 100, "base {base}");
        }
    }

    #[test]
    fn programming_binary_word_size_edges() {
        let calculate = |expression: &str, bits: i32| -> String {
            programmer_calculation_text(expression, 2, bits, AngleUnit::Degrees, "automatic", 20)
                .unwrap_or_else(|error| panic!("{bits}-bit {expression} failed: {error}"))
        };

        assert_eq!(calculate("11111111+1", 8), "0");
        assert_eq!(calculate("¬0", 8), "11111111");
        assert_eq!(calculate("twos(1)", 8), "11111111");
        assert_eq!(calculate("1≪111", 8), "10000000");
        assert_eq!(calculate("10000000≫111", 8), "1");
        assert_eq!(calculate("swap(1)", 16), "100000000");

        for bits in [8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096] {
            let maximum = "1".repeat(bits as usize);
            let expression = format!("{maximum}+1");
            assert_eq!(calculate(&expression, bits), "0", "{bits}-bit wrap");
        }
    }

    #[test]
    fn programming_decimal_only_and_radix_edges() {
        let calculate = |expression, base, bits| {
            programmer_calculation_text(expression, base, bits, AngleUnit::Degrees, "automatic", 20)
        };
        assert_eq!(calculate("50%", 10, 64).unwrap(), "0.5");
        assert_eq!(calculate("4^(-1)", 10, 64).unwrap(), "0.25");
        assert_eq!(calculate("ceil(5.25)", 10, 64).unwrap(), "6");
        assert_eq!(calculate("floor(5.75)", 10, 64).unwrap(), "5");
        assert_eq!(calculate("frac(5.75)", 10, 64).unwrap(), "0.75");
        assert_eq!(calculate("A+B+C+D+E+F", 16, 16).unwrap(), "4B");
        assert_eq!(calculate("FF+1", 16, 8).unwrap(), "0");
        assert_eq!(calculate("swap(1)", 16, 16).unwrap(), "100");

        for (expression, base) in [("2", 2), ("8", 8), ("A", 10), ("G", 16)] {
            assert!(
                calculate(expression, base, 64).is_err(),
                "{expression} should be invalid in base {base}"
            );
        }
    }

    #[test]
    fn programming_history_ignores_unchanged_literals() {
        for (expression, rendered, base) in [
            ("44C", "44C", 16),
            ("cd", "CD", 16),
            ("3E", "3E", 16),
            ("000101", "101", 2),
            ("007", "7", 8),
            ("5.0", "5", 10),
        ] {
            assert!(
                programmer_identity_literal(expression, rendered, base, 20),
                "{expression} should not create a history record"
            );
        }

        for (expression, rendered, base) in [
            ("A+B", "15", 16),
            ("-1", "FF", 16),
            ("11111111+1", "0", 2),
            ("1e3", "1000", 10),
        ] {
            assert!(
                !programmer_identity_literal(expression, rendered, base, 20),
                "{expression} should create a history record"
            );
        }
    }
}
