use crate::engine::AngleUnit;
use rug::{Float, Integer, float::Constant, integer::Order, ops::Pow};

const MIN_PRECISION_BITS: u32 = 1024;
pub(crate) const MAX_PROGRAMMER_INPUT_CHARS: usize = 16_384;
const MAX_PROGRAMMER_EXPONENT: i32 = 1_000_000;
const MAX_PROGRAMMER_RESULT_BITS: i32 = 65_536;
const PROGRAMMER_ARGUMENT_SEPARATOR: char = '\u{e000}';

fn is_programmer_binary_function(name: &str) -> bool {
    matches!(name, "nand" | "nor" | "rol" | "ror" | "ashr" | "lshr")
}

fn normalize_programmer_commas(input: &str) -> String {
    let chars: Vec<char> = input.chars().collect();
    let mut function_stack = Vec::new();
    let mut output = String::with_capacity(input.len());

    for (index, character) in chars.iter().copied().enumerate() {
        match character {
            '(' => {
                let mut name_end = index;
                while name_end > 0 && chars[name_end - 1].is_whitespace() {
                    name_end -= 1;
                }
                let mut name_start = name_end;
                while name_start > 0
                    && (chars[name_start - 1].is_alphanumeric() || chars[name_start - 1] == '_')
                {
                    name_start -= 1;
                }
                let name: String = chars[name_start..name_end].iter().collect();
                function_stack.push((is_programmer_binary_function(&name), false));
                output.push(character);
            }
            ')' => {
                let _ = function_stack.pop();
                output.push(character);
            }
            ',' => {
                if let Some((true, separator_seen)) = function_stack.last_mut()
                    && !*separator_seen
                {
                    *separator_seen = true;
                    output.push(PROGRAMMER_ARGUMENT_SEPARATOR);
                } else {
                    output.push(character);
                }
            }
            _ => output.push(character),
        }
    }

    output
}

pub fn precision_bits(decimal_places: i32) -> u32 {
    MIN_PRECISION_BITS.max(decimal_places.clamp(1, 100) as u32 * 4 + 64)
}

pub fn parse_decimal(input: &str, precision: i32) -> Result<Float, String> {
    let cleaned = input.replace([',', '\u{200b}'], "");
    let parsed = Float::parse(cleaned.trim()).map_err(|_| "Invalid number".to_string())?;
    Ok(Float::with_val(precision_bits(precision), parsed))
}

fn pow_float(base: Float, exponent: Float) -> Result<Float, String> {
    if exponent.is_integer() {
        let integer = exponent
            .to_integer()
            .ok_or_else(|| "Exponent is outside the supported range".to_string())?;
        let Some(power) = integer.to_i32() else {
            return Err("Exponent is too large".into());
        };
        Ok(base.pow(power))
    } else {
        if base < 0 {
            return Err("Fractional powers of negative values are not real".into());
        }
        let mut result = base.ln();
        result *= exponent;
        Ok(result.exp())
    }
}

pub fn financial_value(
    operation: &str,
    principal: &str,
    rate: &str,
    periods: &str,
    payment: &str,
    format: &str,
    precision: i32,
) -> Result<String, String> {
    let principal = parse_decimal(principal, precision)?;
    let mut rate = parse_decimal(rate, precision)?;
    let periods = parse_decimal(periods, precision)?;
    let payment = parse_decimal(payment, precision)?;
    rate /= 100;
    let mut growth = Float::with_val(precision_bits(precision), 1);
    growth += &rate;

    let value = match operation {
        "Ctrm" if rate > 0 && principal > 0 && payment > 0 => {
            let ratio = Float::with_val(principal.prec(), &payment / &principal).ln();
            ratio / growth.ln()
        }
        "Ddb" if periods > 0 => {
            let mut value = principal;
            value *= 2;
            value / periods
        }
        "Fv" => {
            let compound = pow_float(growth, periods.clone())?;
            let mut value = Float::with_val(principal.prec(), &principal * &compound);
            if rate == 0 {
                value += payment * periods;
            } else {
                let mut annuity = compound;
                annuity -= 1;
                annuity /= rate;
                value += payment * annuity;
            }
            value
        }
        "Gpm" if principal != 0 => {
            let mut value = Float::with_val(principal.prec(), &principal - payment);
            value /= principal;
            value *= 100;
            value
        }
        "Pmt" if periods > 0 => {
            if rate == 0 {
                principal / periods
            } else {
                let discount = pow_float(growth, -periods)?;
                let mut denominator = Float::with_val(principal.prec(), 1);
                denominator -= discount;
                let mut value = principal;
                value *= rate;
                value / denominator
            }
        }
        "Pv" => {
            if rate == 0 {
                let mut value = principal;
                value -= payment * periods;
                value
            } else {
                principal / pow_float(growth, periods)?
            }
        }
        "Rate" if principal > 0 && payment > 0 && periods > 0 => {
            let ratio = Float::with_val(principal.prec(), payment / principal);
            let reciprocal = Float::with_val(periods.prec(), 1) / periods;
            let mut value = pow_float(ratio, reciprocal)?;
            value -= 1;
            value *= 100;
            value
        }
        "Sln" if periods > 0 => (principal - payment) / periods,
        "Syd" if periods > 0 => {
            let mut denominator = Float::with_val(periods.prec(), &periods + 1);
            denominator *= &periods;
            denominator /= 2;
            let mut value = principal - payment;
            value *= periods;
            value / denominator
        }
        "Term" if payment > 0 => principal / payment,
        _ => return Err("Invalid values".into()),
    };
    if !value.is_finite() {
        return Err("Invalid values".into());
    }
    Ok(format_value(&value, format, precision))
}

#[cfg(test)]
pub fn evaluate(input: &str, angle: AngleUnit, precision: i32) -> Result<Float, String> {
    let value = crate::complex::evaluate(input, angle, precision)?;
    if value.imag() != &0 {
        Err("Result is not a real number".into())
    } else {
        Ok(value.real().clone())
    }
}

pub(crate) enum ProgrammerValue {
    Integer(Integer),
    Decimal(Float),
}

pub(crate) fn evaluate_programmer(
    input: &str,
    angle: AngleUnit,
    precision: i32,
    base: i32,
    word_bits: i32,
) -> Result<ProgrammerValue, String> {
    if !matches!(base, 2 | 8 | 10 | 16) {
        return Err("Invalid base".into());
    }
    if input.chars().count() > MAX_PROGRAMMER_INPUT_CHARS {
        return Err("Programmer expression is too long".into());
    }
    // Normalize digit grouping while the real argument comma is still
    // visible. This lets the shared normalizer distinguish the first
    // top-level comma from grouped digits in the second argument.
    let normalized = crate::engine::normalize_input(input)?;
    let value = parse_with_options(
        &normalize_programmer_commas(&normalized),
        angle,
        precision,
        base as u32,
        Some(word_bits.clamp(8, 4096) as u32),
    )?;
    if value
        .number
        .get_exp()
        .is_some_and(|exponent| exponent > MAX_PROGRAMMER_RESULT_BITS)
    {
        return Err("Programmer result is too large".into());
    }
    if let Some(integer) = value.exact_integer {
        Ok(ProgrammerValue::Integer(integer))
    } else {
        Ok(ProgrammerValue::Decimal(value.number))
    }
}

fn parse_with_options(
    input: &str,
    angle: AngleUnit,
    precision: i32,
    radix: u32,
    programmer_bits: Option<u32>,
) -> Result<ParsedValue, String> {
    let bits = precision_bits(precision).max(programmer_bits.unwrap_or(0) + 64);
    let normalized = crate::engine::normalize_input(input)?;
    let mut parser = Parser {
        chars: normalized.chars().collect(),
        pos: 0,
        angle,
        bits,
        radix,
        programmer_bits,
    };
    let value = parser.bit_or()?;
    parser.space();
    if parser.pos != parser.chars.len() {
        return Err(format!("Unexpected '{}'", parser.chars[parser.pos]));
    }
    if value.number.is_nan() {
        Err("Result is not a real number".into())
    } else if value.number.is_infinite() {
        Err("Overflow: the result is too large".into())
    } else {
        Ok(value)
    }
}

pub fn format_value(value: &Float, format: &str, precision: i32) -> String {
    let places = precision.clamp(1, 100) as usize;
    let value = if value == &0 {
        Float::with_val(value.prec(), 0)
    } else {
        value.clone()
    };
    let mut text = match format {
        "fixed" => fixed(&value, places),
        "scientific" => scientific(&value, places),
        "engineering" => engineering(&value, places),
        _ => fixed(&value, places),
    };
    if format == "automatic" && text.contains('.') {
        text = text.trim_end_matches('0').trim_end_matches('.').to_string();
    }
    normalize_exponent(text)
}

pub fn format_conversion_value(value: &Float) -> String {
    if value == &0 {
        return "0".into();
    }

    let (_, _, decimal_exponent) = value.to_sign_string_exp(10, Some(1));
    let order = decimal_exponent.unwrap_or(1) - 1;
    if !(-3..=11).contains(&order) {
        let mut text = scientific(value, 7);
        if let Some((mantissa, exponent)) = text.split_once('e') {
            let mantissa = mantissa.trim_end_matches('0').trim_end_matches('.');
            text = format!("{mantissa}e{exponent}");
        }
        return normalize_exponent(text);
    }

    let places = (7 - order).clamp(0, 6) as usize;
    let mut text = fixed(value, places);
    if text.contains('.') {
        text = text.trim_end_matches('0').trim_end_matches('.').to_string();
    }
    normalize_exponent(text)
}

fn fixed(value: &Float, places: usize) -> String {
    let factor = Float::with_val(
        value.prec(),
        Float::parse(format!("1e{places}")).expect("valid decimal scale"),
    );
    let mut scaled = Float::with_val(value.prec(), value * factor);
    scaled.round_mut();
    let integer = scaled.to_integer().unwrap_or_default();
    let negative = integer < 0;
    let mut digits = integer.abs().to_string();
    if places == 0 {
        return format!("{}{digits}", if negative { "-" } else { "" });
    }
    if digits.len() <= places {
        digits.insert_str(0, &"0".repeat(places + 1 - digits.len()));
    }
    let point = digits.len() - places;
    digits.insert(point, '.');
    format!("{}{digits}", if negative { "-" } else { "" })
}

fn scientific(value: &Float, places: usize) -> String {
    if value == &0 {
        return format!("0.{}e0", "0".repeat(places));
    }
    let (negative, mut digits, exponent) =
        value.to_sign_string_exp(10, Some(places.saturating_add(1)));
    while digits.len() < places + 1 {
        digits.push('0');
    }
    digits.insert(1, '.');
    format!(
        "{}{digits}e{}",
        if negative { "-" } else { "" },
        exponent.unwrap_or(1) - 1
    )
}

fn engineering(value: &Float, places: usize) -> String {
    if value == &0 {
        return "0".into();
    }
    let (_, _, decimal_exponent) = value.to_sign_string_exp(10, Some(1));
    let exponent = (decimal_exponent.unwrap_or(1) - 1).div_euclid(3) * 3;
    let digits_before_point = (decimal_exponent.unwrap_or(1) - exponent) as usize;
    let (negative, mut digits, _) =
        value.to_sign_string_exp(10, Some(digits_before_point + places));
    while digits.len() < digits_before_point + places {
        digits.push('0');
    }
    digits.insert(digits_before_point, '.');
    format!("{}{digits}e{exponent}", if negative { "-" } else { "" })
}

fn normalize_exponent(text: String) -> String {
    let Some((mantissa, exponent)) = text.split_once('e') else {
        return text;
    };
    let negative = exponent.starts_with('-');
    let digits = exponent
        .trim_start_matches(['+', '-'])
        .trim_start_matches('0');
    let digits = if digits.is_empty() { "0" } else { digits };
    format!("{mantissa}e{}{digits}", if negative { "-" } else { "" })
}

#[derive(Clone)]
struct ParsedValue {
    number: Float,
    exact_integer: Option<Integer>,
    mathematical_integer: Option<Integer>,
    percentage: bool,
}

impl ParsedValue {
    fn plain(number: Float) -> Self {
        Self {
            number,
            exact_integer: None,
            mathematical_integer: None,
            percentage: false,
        }
    }
}

struct Parser {
    chars: Vec<char>,
    pos: usize,
    angle: AngleUnit,
    bits: u32,
    radix: u32,
    programmer_bits: Option<u32>,
}

impl Parser {
    fn number<T>(&self, value: T) -> Float
    where
        Float: rug::Assign<T>,
    {
        Float::with_val(self.bits, value)
    }

    fn reduce_programmer_integer(&self, mut value: Integer) -> Integer {
        if let Some(bits) = self.programmer_bits {
            let modulus = Integer::from(1) << bits;
            value %= &modulus;
            if value < 0 {
                value += modulus;
            }
        }
        value
    }

    fn signed_programmer_integer(&self, value: &Integer) -> Integer {
        let mut signed = self.reduce_programmer_integer(value.clone());
        if let Some(bits) = self.programmer_bits {
            let sign_bit = Integer::from(1) << (bits - 1);
            if signed >= sign_bit {
                signed -= Integer::from(1) << bits;
            }
        }
        signed
    }

    fn exact_value(&self, value: Integer, reduce: bool) -> ParsedValue {
        let mathematical_integer = self.programmer_bits.map(|_| value.clone());
        let value = if reduce {
            self.reduce_programmer_integer(value)
        } else {
            value
        };
        ParsedValue {
            number: self.number(&value),
            exact_integer: self.programmer_bits.map(|_| value),
            mathematical_integer,
            percentage: false,
        }
    }

    fn fixed_value(&self, value: Integer, reduce: bool) -> ParsedValue {
        let mut value = self.exact_value(value, reduce);
        value.mathematical_integer = value.exact_integer.clone();
        value
    }

    fn parsed_integer(&self, value: &ParsedValue) -> Result<Integer, String> {
        value
            .exact_integer
            .clone()
            .map(Ok)
            .unwrap_or_else(|| self.integer(&value.number))
    }

    fn space(&mut self) {
        while self.pos < self.chars.len() && self.chars[self.pos].is_whitespace() {
            self.pos += 1;
        }
    }

    fn take(&mut self, character: char) -> bool {
        self.space();
        if self.chars.get(self.pos) == Some(&character) {
            self.pos += 1;
            true
        } else {
            false
        }
    }

    fn take_str(&mut self, token: &str) -> bool {
        self.space();
        let token: Vec<char> = token.chars().collect();
        if self.chars.get(self.pos..self.pos + token.len()) == Some(token.as_slice()) {
            self.pos += token.len();
            true
        } else {
            false
        }
    }

    fn starts_primary(&self) -> bool {
        let mut pos = self.pos;
        while pos < self.chars.len() && self.chars[pos].is_whitespace() {
            pos += 1;
        }
        self.chars.get(pos).is_some_and(|character| {
            character.is_ascii_digit()
                || *character == '.'
                || *character == '('
                || *character == '√'
                || character.is_alphabetic()
                || *character == '_'
        })
    }

    fn named_function_at_cursor(&self) -> bool {
        let mut end = self.pos;
        while end < self.chars.len()
            && (self.chars[end].is_alphanumeric() || self.chars[end] == '_')
        {
            end += 1;
        }
        let name: String = self.chars[self.pos..end].iter().collect();
        while end < self.chars.len() && self.chars[end].is_whitespace() {
            end += 1;
        }
        self.chars.get(end) == Some(&'(')
            && matches!(
                name.as_str(),
                "sin"
                    | "cos"
                    | "tan"
                    | "asin"
                    | "acos"
                    | "atan"
                    | "sinh"
                    | "cosh"
                    | "tanh"
                    | "asinh"
                    | "acosh"
                    | "atanh"
                    | "sqrt"
                    | "ln"
                    | "log"
                    | "log10"
                    | "log2"
                    | "abs"
                    | "exp"
                    | "floor"
                    | "ceil"
                    | "round"
                    | "trunc"
                    | "int"
                    | "frac"
                    | "twos"
                    | "swap"
                    | "nand"
                    | "nor"
                    | "rol"
                    | "ror"
                    | "ashr"
                    | "lshr"
            )
    }

    fn starts_radix_number(&self) -> bool {
        let Some(character) = self.chars.get(self.pos).copied() else {
            return false;
        };
        if self.radix == 10 {
            return character.is_ascii_digit() || character == '.';
        }
        character.is_ascii_digit()
            || (self.radix == 16
                && character.is_ascii_hexdigit()
                && !self.named_function_at_cursor())
    }

    fn integer(&self, value: &Float) -> Result<Integer, String> {
        if !value.is_integer() {
            return Err("Bitwise operations require whole numbers".into());
        }
        value
            .to_integer()
            .ok_or_else(|| "Integer is outside the supported range".into())
    }

    fn bit_or(&mut self) -> Result<ParsedValue, String> {
        let mut value = self.bit_xor()?;
        while self.take('|') {
            let right = self.bit_xor()?;
            value = self.fixed_value(
                self.parsed_integer(&value)? | self.parsed_integer(&right)?,
                true,
            );
        }
        Ok(value)
    }

    fn bit_xor(&mut self) -> Result<ParsedValue, String> {
        let mut value = self.bit_and()?;
        while self.take('@') {
            let right = self.bit_and()?;
            value = self.fixed_value(
                self.parsed_integer(&value)? ^ self.parsed_integer(&right)?,
                true,
            );
        }
        Ok(value)
    }

    fn bit_and(&mut self) -> Result<ParsedValue, String> {
        let mut value = self.shift()?;
        while self.take('&') {
            let right = self.shift()?;
            value = self.fixed_value(
                self.parsed_integer(&value)? & self.parsed_integer(&right)?,
                true,
            );
        }
        Ok(value)
    }

    fn shift(&mut self) -> Result<ParsedValue, String> {
        let mut value = self.expression()?;
        loop {
            let left = if self.take_str("<<") {
                true
            } else if self.take_str(">>") {
                false
            } else {
                return Ok(value);
            };
            let right = self.expression()?;
            let amount = self
                .parsed_integer(&right)?
                .to_u32()
                .ok_or_else(|| "Shift count must be a non-negative whole number".to_string())?;
            if amount > 1_000_000 {
                return Err("Shift is too large".into());
            }
            let integer = self.reduce_programmer_integer(self.parsed_integer(&value)?);
            value = self.fixed_value(
                if self
                    .programmer_bits
                    .is_some_and(|word_bits| amount >= word_bits)
                {
                    Integer::new()
                } else if left {
                    integer << amount
                } else {
                    integer >> amount
                },
                true,
            );
        }
    }

    fn expression(&mut self) -> Result<ParsedValue, String> {
        let mut value = self.term()?;
        loop {
            if self.take('+') {
                let right = self.term()?;
                if !right.percentage
                    && !value.percentage
                    && let (Some(left), Some(right)) = (
                        value.mathematical_integer.as_ref(),
                        right.mathematical_integer.as_ref(),
                    )
                {
                    value = self.exact_value(Integer::from(left + right), true);
                    continue;
                }
                if right.percentage && !value.percentage {
                    let change = self.number(&value.number * &right.number);
                    value.number += change;
                } else {
                    value.number += right.number;
                }
                value.exact_integer = None;
                value.mathematical_integer = None;
                value.percentage = value.percentage && right.percentage;
            } else if self.take('-') {
                let right = self.term()?;
                if !right.percentage
                    && !value.percentage
                    && let (Some(left), Some(right)) = (
                        value.mathematical_integer.as_ref(),
                        right.mathematical_integer.as_ref(),
                    )
                {
                    value = self.exact_value(Integer::from(left - right), true);
                    continue;
                }
                if right.percentage && !value.percentage {
                    let change = self.number(&value.number * &right.number);
                    value.number -= change;
                } else {
                    value.number -= right.number;
                }
                value.exact_integer = None;
                value.mathematical_integer = None;
                value.percentage = value.percentage && right.percentage;
            } else {
                return Ok(value);
            }
        }
    }

    fn term(&mut self) -> Result<ParsedValue, String> {
        let mut value = self.unary()?;
        loop {
            if self.take('*') {
                let right = self.unary()?;
                if !value.percentage
                    && !right.percentage
                    && let (Some(left), Some(right)) = (
                        value.mathematical_integer.as_ref(),
                        right.mathematical_integer.as_ref(),
                    )
                {
                    value = self.exact_value(Integer::from(left * right), true);
                    continue;
                }
                value.number *= right.number;
                value.exact_integer = None;
                value.mathematical_integer = None;
            } else if self.take('/') {
                let right = self.unary()?;
                let signed_right = right
                    .exact_integer
                    .as_ref()
                    .map(|integer| self.signed_programmer_integer(integer));
                let right_is_zero = signed_right
                    .as_ref()
                    .map_or_else(|| right.number == 0, Integer::is_zero);
                if right_is_zero {
                    return Err("Division by zero is undefined".into());
                }
                if !value.percentage
                    && !right.percentage
                    && let (Some(left), Some(right)) = (value.exact_integer.as_ref(), signed_right)
                {
                    let left = self.signed_programmer_integer(left);
                    let remainder = Integer::from(&left % &right);
                    if remainder == 0 {
                        value = self.exact_value(left / right, true);
                        continue;
                    }
                    value.number = self.number(left);
                    value.number /= self.number(right);
                    value.exact_integer = None;
                    value.mathematical_integer = None;
                    value.percentage = false;
                    continue;
                }
                value.number /= right.number;
                value.exact_integer = None;
                value.mathematical_integer = None;
                value.percentage = value.percentage && !right.percentage;
            } else if self.take_str("mod") {
                let right = self.unary()?;
                let right_integer = self.signed_programmer_integer(&self.parsed_integer(&right)?);
                let right_is_zero = right_integer.is_zero();
                if right_is_zero {
                    return Err("Modulo by zero is undefined".into());
                }
                value = self.exact_value(
                    self.signed_programmer_integer(&self.parsed_integer(&value)?) % right_integer,
                    true,
                );
            } else if self.starts_primary() {
                let right = self.unary()?;
                if !value.percentage
                    && !right.percentage
                    && let (Some(left), Some(right)) = (
                        value.mathematical_integer.as_ref(),
                        right.mathematical_integer.as_ref(),
                    )
                {
                    value = self.exact_value(Integer::from(left * right), true);
                    continue;
                }
                value.number *= right.number;
                value.exact_integer = None;
                value.mathematical_integer = None;
            } else {
                return Ok(value);
            }
        }
    }

    fn power(&mut self) -> Result<ParsedValue, String> {
        let value = self.primary()?;
        if !self.take('^') {
            return Ok(value);
        }
        let exponent = self.unary()?;
        let signed_exact_exponent = exponent
            .exact_integer
            .as_ref()
            .map(|integer| self.signed_programmer_integer(integer));
        let exponent_number = signed_exact_exponent
            .as_ref()
            .map_or_else(|| exponent.number.clone(), |integer| self.number(integer));
        if self.programmer_bits.is_some()
            && (exponent_number > self.number(MAX_PROGRAMMER_EXPONENT)
                || exponent_number < self.number(-MAX_PROGRAMMER_EXPONENT))
        {
            return Err("Programmer exponent is too large".into());
        }
        if let (Some(base), Some(power), Some(word_bits)) = (
            value.exact_integer.as_ref(),
            signed_exact_exponent.as_ref(),
            self.programmer_bits,
        ) && power >= &0
        {
            let modulus = Integer::from(1) << word_bits;
            let mut base = base.clone();
            base %= &modulus;
            if base < 0 {
                base += &modulus;
            }
            let result = base
                .pow_mod(power, &modulus)
                .map_err(|_| "Invalid programmer power".to_string())?;
            return Ok(self.exact_value(result, false));
        }
        let result = pow_float(value.number, exponent_number)?;
        Ok(ParsedValue::plain(result))
    }

    fn unary(&mut self) -> Result<ParsedValue, String> {
        if self.take('-') {
            let mut value = self.unary()?;
            value.number = -value.number;
            if let Some(integer) = value.mathematical_integer.take() {
                return Ok(self.exact_value(-integer, true));
            }
            Ok(value)
        } else if self.take('+') {
            self.unary()
        } else if self.take('~') {
            let value = self.unary()?;
            Ok(self.fixed_value(!self.parsed_integer(&value)?, true))
        } else if self.take('√') {
            let value = self.unary()?;
            let exact_integer = value
                .exact_integer
                .as_ref()
                .map(|integer| self.signed_programmer_integer(integer));
            let number = exact_integer
                .as_ref()
                .map_or_else(|| value.number.clone(), |integer| self.number(integer));
            if number < 0 {
                Err("Square root is undefined for negative values".into())
            } else if exact_integer
                .as_ref()
                .is_some_and(Integer::is_perfect_square)
            {
                Ok(self.exact_value(
                    Integer::from(exact_integer.as_ref().unwrap().sqrt_ref()),
                    true,
                ))
            } else {
                Ok(ParsedValue::plain(number.sqrt()))
            }
        } else {
            self.power()
        }
    }

    fn primary(&mut self) -> Result<ParsedValue, String> {
        self.space();
        if self.take('(') {
            let value = self.bit_or()?;
            if !self.take(')') {
                return Err("Expected closing parenthesis".into());
            }
            return self.postfix(value);
        }
        if self.starts_radix_number() {
            if self.radix != 10 {
                let start = self.pos;
                while self.pos < self.chars.len() && self.chars[self.pos].is_digit(self.radix) {
                    self.pos += 1;
                }
                if self.pos == start {
                    let invalid = self.chars[self.pos];
                    return Err(format!(
                        "Digit '{invalid}' is not valid in base {}",
                        self.radix
                    ));
                }
                if self.chars.get(self.pos).is_some_and(|character| {
                    character.is_ascii_digit()
                        || (character.is_ascii_alphabetic() && !matches!(character, 'm' | 'M'))
                }) {
                    let invalid = self.chars[self.pos];
                    return Err(format!(
                        "Digit '{invalid}' is not valid in base {}",
                        self.radix
                    ));
                }
                let text: String = self.chars[start..self.pos].iter().collect();
                let integer = Integer::from_str_radix(&text, self.radix as i32)
                    .map_err(|_| format!("Invalid base-{} number", self.radix))?;
                return self.postfix(self.exact_value(integer, false));
            }
            let start = self.pos;
            while self.pos < self.chars.len()
                && (self.chars[self.pos].is_ascii_digit() || self.chars[self.pos] == '.')
            {
                self.pos += 1;
            }
            if self.pos < self.chars.len() && matches!(self.chars[self.pos], 'e' | 'E') {
                let exponent_marker = self.pos;
                self.pos += 1;
                if self.pos < self.chars.len() && matches!(self.chars[self.pos], '+' | '-') {
                    self.pos += 1;
                }
                let exponent_start = self.pos;
                while self.pos < self.chars.len() && self.chars[self.pos].is_ascii_digit() {
                    self.pos += 1;
                }
                if self.pos == exponent_start {
                    self.pos = exponent_marker;
                }
            }
            let text: String = self.chars[start..self.pos].iter().collect();
            if !text.contains(['.', 'e', 'E']) {
                let integer =
                    Integer::from_str_radix(&text, 10).map_err(|_| "Invalid number".to_string())?;
                return self.postfix(self.exact_value(integer, false));
            }
            let parsed = Float::parse(&text).map_err(|_| "Invalid number")?;
            let number = Float::with_val(self.bits, parsed);
            return self.postfix(ParsedValue::plain(number));
        }
        let start = self.pos;
        while self.pos < self.chars.len()
            && (self.chars[self.pos].is_alphanumeric() || self.chars[self.pos] == '_')
        {
            self.pos += 1;
        }
        let name: String = self.chars[start..self.pos].iter().collect();
        if name == "pi" {
            return self.postfix(ParsedValue::plain(self.number(Constant::Pi)));
        }
        if name == "e" {
            return self.postfix(ParsedValue::plain(self.number(1).exp()));
        }
        if name.is_empty() {
            return Err("Expected a number".into());
        }
        if !self.take('(') {
            return Err(format!("Unknown function: {name}"));
        }
        let argument = self.bit_or()?;
        let value = if self.take(PROGRAMMER_ARGUMENT_SEPARATOR) {
            let second_argument = self.bit_or()?;
            if !self.take(')') {
                return Err("Expected closing parenthesis".into());
            }
            self.binary_function(&name, argument, second_argument)?
        } else {
            if !self.take(')') {
                return Err("Expected closing parenthesis".into());
            }
            self.function(&name, argument)?
        };
        self.postfix(value)
    }

    fn exact_programmer_argument(
        &self,
        name: &str,
        argument: &ParsedValue,
    ) -> Result<Integer, String> {
        if self.programmer_bits.is_none() {
            return Err(format!("{name} is only available in Programmer mode"));
        }
        self.parsed_integer(argument)
            .map_err(|_| format!("{name} requires whole-number arguments"))
    }

    fn programmer_count(&self, name: &str, argument: &ParsedValue) -> Result<Integer, String> {
        let exact_count = self.exact_programmer_argument(name, argument)?;
        let count = argument.mathematical_integer.clone().unwrap_or(exact_count);
        if count < 0 {
            return Err(format!("{name} count must be non-negative"));
        }
        Ok(count)
    }

    fn binary_function(
        &self,
        name: &str,
        left: ParsedValue,
        right: ParsedValue,
    ) -> Result<ParsedValue, String> {
        if !is_programmer_binary_function(name) {
            return Err(format!("{name} does not accept two arguments"));
        }
        let bits = self
            .programmer_bits
            .ok_or_else(|| format!("{name} is only available in Programmer mode"))?;
        let modulus = Integer::from(1) << bits;
        let mask = Integer::from(&modulus - 1);
        let value = self.reduce_programmer_integer(self.exact_programmer_argument(name, &left)?);

        let result = match name {
            "nand" | "nor" => {
                let right =
                    self.reduce_programmer_integer(self.exact_programmer_argument(name, &right)?);
                let combined = if name == "nand" {
                    Integer::from(&value & &right)
                } else {
                    Integer::from(&value | &right)
                };
                Integer::from(&mask ^ combined)
            }
            "rol" | "ror" => {
                let count = self.programmer_count(name, &right)?;
                let count = Integer::from(count % Integer::from(bits))
                    .to_u32()
                    .expect("rotation count modulo word width fits in u32");
                if count == 0 {
                    value
                } else if name == "rol" {
                    Integer::from(
                        (Integer::from(&value << count) | Integer::from(&value >> (bits - count)))
                            & &mask,
                    )
                } else {
                    Integer::from(
                        (Integer::from(&value >> count) | Integer::from(&value << (bits - count)))
                            & &mask,
                    )
                }
            }
            "lshr" => {
                let count = self.programmer_count(name, &right)?;
                if count >= bits {
                    Integer::new()
                } else {
                    value >> count.to_u32().expect("count below word width fits in u32")
                }
            }
            "ashr" => {
                let count = self.programmer_count(name, &right)?;
                let sign_bit = Integer::from(1) << (bits - 1);
                let negative = value >= sign_bit;
                if count >= bits {
                    if negative { mask } else { Integer::new() }
                } else {
                    let mut signed = value;
                    if negative {
                        signed -= modulus;
                    }
                    signed >>= count.to_u32().expect("count below word width fits in u32");
                    self.reduce_programmer_integer(signed)
                }
            }
            _ => unreachable!(),
        };
        Ok(self.fixed_value(result, true))
    }

    fn function(&self, name: &str, argument: ParsedValue) -> Result<ParsedValue, String> {
        if is_programmer_binary_function(name) {
            return Err(format!("{name} requires two arguments"));
        }
        if let Some(raw_integer) = argument.exact_integer.as_ref() {
            let signed_integer;
            let integer = if matches!(name, "twos" | "swap") {
                raw_integer
            } else {
                signed_integer = self.signed_programmer_integer(raw_integer);
                &signed_integer
            };
            let exact = match name {
                "sqrt" if integer >= &0 && integer.is_perfect_square() => {
                    Some(Integer::from(integer.sqrt_ref()))
                }
                "log2" if integer > &0 && integer.is_power_of_two() => {
                    Some(Integer::from(integer.significant_bits() - 1))
                }
                "log" | "log10" if integer > &0 => {
                    let mut value = integer.clone();
                    let mut exponent = 0_u32;
                    while Integer::from(&value % 10) == 0 {
                        value /= 10;
                        exponent += 1;
                    }
                    (value == 1).then(|| Integer::from(exponent))
                }
                "ln" if integer == &1 => Some(Integer::new()),
                "exp" if integer == &0 => Some(Integer::from(1)),
                "abs" => Some(self.signed_programmer_integer(integer).abs()),
                "floor" | "ceil" | "round" | "trunc" | "int" => Some(integer.clone()),
                "frac" => Some(Integer::new()),
                "twos" => Some(-integer.clone()),
                "swap" => {
                    if integer < &0 {
                        return Err("Byte swap requires a non-negative whole number".into());
                    }
                    let mut integer = integer.clone();
                    let byte_count = if let Some(bits) = self.programmer_bits {
                        let modulus = Integer::from(1) << bits;
                        integer %= modulus;
                        bits.div_ceil(8) as usize
                    } else {
                        integer.significant_bits().div_ceil(8).max(8) as usize
                    };
                    let mut bytes = integer.to_digits::<u8>(Order::Lsf);
                    bytes.resize(byte_count, 0);
                    bytes.reverse();
                    Some(Integer::from_digits(&bytes, Order::Lsf))
                }
                _ => None,
            };
            if let Some(integer) = exact {
                return Ok(self.exact_value(integer, true));
            }
        }

        let mut value = argument.exact_integer.as_ref().map_or_else(
            || argument.number,
            |integer| self.number(self.signed_programmer_integer(integer)),
        );
        let pi = || self.number(Constant::Pi);
        let to_radians = |mut number: Float| {
            match self.angle {
                AngleUnit::Degrees => {
                    number *= pi();
                    number /= 180;
                }
                AngleUnit::Gradians => {
                    number *= pi();
                    number /= 200;
                }
                AngleUnit::Radians => {}
            }
            number
        };
        let from_radians = |mut number: Float| {
            match self.angle {
                AngleUnit::Degrees => {
                    number *= 180;
                    number /= pi();
                }
                AngleUnit::Gradians => {
                    number *= 200;
                    number /= pi();
                }
                AngleUnit::Radians => {}
            }
            number
        };
        let result = match name {
            "sin" => to_radians(value).sin(),
            "cos" => to_radians(value).cos(),
            "tan" => to_radians(value).tan(),
            "asin" => from_radians(value.asin()),
            "acos" => from_radians(value.acos()),
            "atan" => from_radians(value.atan()),
            "sinh" => value.sinh(),
            "cosh" => value.cosh(),
            "tanh" => value.tanh(),
            "asinh" => value.asinh(),
            "acosh" => value.acosh(),
            "atanh" => value.atanh(),
            "sqrt" => {
                if value < 0 {
                    return Err("Square root is undefined for negative values".into());
                }
                value.sqrt()
            }
            "ln" => value.ln(),
            "log" | "log10" => value.log10(),
            "log2" => value.log2(),
            "abs" => value.abs(),
            "exp" => value.exp(),
            "floor" => value.floor(),
            "ceil" => value.ceil(),
            "round" => value.round(),
            "trunc" | "int" => value.trunc(),
            "frac" => {
                let truncated = value.clone().trunc();
                value -= truncated;
                value
            }
            "twos" => -value,
            "swap" => {
                let mut integer = self.integer(&value)?;
                if integer < 0 {
                    return Err("Byte swap requires a non-negative whole number".into());
                }
                let byte_count = if let Some(bits) = self.programmer_bits {
                    let modulus = Integer::from(1) << bits;
                    integer %= modulus;
                    bits.div_ceil(8) as usize
                } else {
                    integer.significant_bits().div_ceil(8).max(8) as usize
                };
                let mut bytes = integer.to_digits::<u8>(Order::Lsf);
                bytes.resize(byte_count, 0);
                bytes.reverse();
                self.number(Integer::from_digits(&bytes, Order::Lsf))
            }
            _ => return Err(format!("Unknown function: {name}")),
        };
        if matches!(name, "floor" | "ceil" | "round" | "trunc" | "int") {
            if result
                .get_exp()
                .is_some_and(|exponent| exponent > MAX_PROGRAMMER_RESULT_BITS)
            {
                return Err("Programmer result is too large".into());
            }
            let integer = result
                .to_integer()
                .ok_or_else(|| "Programmer result is outside the supported range".to_string())?;
            return Ok(self.exact_value(integer, true));
        }
        Ok(ParsedValue::plain(result))
    }

    fn postfix(&mut self, mut value: ParsedValue) -> Result<ParsedValue, String> {
        loop {
            if self.take('%') {
                if let Some(integer) = value.exact_integer.take() {
                    let integer = self.signed_programmer_integer(&integer);
                    if Integer::from(&integer % 100) == 0 {
                        let quotient: Integer = integer / 100;
                        value = self.exact_value(quotient.clone(), true);
                        value.number = self.number(quotient);
                    } else {
                        value.number = self.number(integer);
                        value.number /= 100;
                        value.exact_integer = None;
                        value.mathematical_integer = None;
                    }
                } else {
                    value.number /= 100;
                }
                value.percentage = true;
            } else if self.take('!') {
                let integer = match value.exact_integer.as_ref() {
                    Some(integer) => self.signed_programmer_integer(integer),
                    None => self.parsed_integer(&value)?,
                };
                if integer < 0 {
                    return Err("Factorial is undefined for negative values".into());
                }
                let Some(number) = integer.to_u32() else {
                    return Err("Factorial input is too large".into());
                };
                if number > 100_000 {
                    return Err("Factorial input is limited to 100,000".into());
                }
                if let Some(bits) = self.programmer_bits {
                    let modulus = Integer::from(1) << bits;
                    let mut factorial = Integer::from(1);
                    for factor in 2..=number {
                        factorial *= factor;
                        factorial %= &modulus;
                        if factorial == 0 {
                            break;
                        }
                    }
                    value = self.fixed_value(factorial, false);
                } else {
                    value =
                        ParsedValue::plain(self.number(Integer::from(Integer::factorial(number))));
                }
            } else {
                return Ok(value);
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn programmer_integer_with_base(expression: &str, base: i32, bits: i32) -> Integer {
        match evaluate_programmer(expression, AngleUnit::Degrees, 20, base, bits).unwrap() {
            ProgrammerValue::Integer(value) => value,
            ProgrammerValue::Decimal(_) => panic!("expected an exact Programmer integer"),
        }
    }

    fn programmer_integer(expression: &str, bits: i32) -> Integer {
        programmer_integer_with_base(expression, 10, bits)
    }

    fn word_mask(bits: i32) -> Integer {
        (Integer::from(1) << bits) - 1
    }

    #[test]
    fn preserves_integer_digits_beyond_f64() {
        let value = evaluate("999999999999999999999999+1", AngleUnit::Degrees, 30).unwrap();
        assert_eq!(
            format_value(&value, "automatic", 30),
            "1000000000000000000000000"
        );
    }

    #[test]
    fn high_precision_decimal_arithmetic() {
        let value = evaluate("0.1+0.2", AngleUnit::Degrees, 50).unwrap();
        assert_eq!(format_value(&value, "automatic", 50), "0.3");
    }

    #[test]
    fn large_factorial_is_supported() {
        let value = evaluate("100!", AngleUnit::Degrees, 100).unwrap();
        assert_eq!(format_value(&value, "automatic", 100).len(), 158);

        let value = evaluate("171!", AngleUnit::Degrees, 100).unwrap();
        assert!(format_value(&value, "scientific", 20).starts_with("1.24101807021766782342e309"));
    }

    #[test]
    fn values_beyond_f64_range_are_supported() {
        let value = evaluate("1e309", AngleUnit::Degrees, 20).unwrap();
        assert_eq!(format_value(&value, "scientific", 4), "1.0000e309");

        let value = evaluate("exp(1000)", AngleUnit::Degrees, 20).unwrap();
        assert!(format_value(&value, "scientific", 8).ends_with("e434"));
    }

    #[test]
    fn byte_swap_preserves_arbitrary_precision() {
        let value = evaluate("swap(72057594037927936)", AngleUnit::Degrees, 20).unwrap();
        assert_eq!(format_value(&value, "automatic", 20), "1");

        let large = Integer::from(1) << 248;
        let value = evaluate(&format!("swap({large})"), AngleUnit::Degrees, 100).unwrap();
        assert_eq!(format_value(&value, "automatic", 100), "1");
    }

    #[test]
    fn programmer_float_only_integrals_are_not_promoted_to_exact() {
        for expression in ["5.0", "0.5+0.5", "1e2000", "sin(90)"] {
            assert!(
                matches!(
                    evaluate_programmer(expression, AngleUnit::Degrees, 20, 10, 4096).unwrap(),
                    ProgrammerValue::Decimal(_)
                ),
                "{expression}"
            );
        }
    }

    #[test]
    fn programmer_nand_and_nor_are_exact_at_every_supported_width() {
        for bits in [8, 64, 128, 4096] {
            let mask = word_mask(bits);
            let modulus = Integer::from(1) << bits;
            assert_eq!(programmer_integer("nand(0,0)", bits), mask);
            assert_eq!(programmer_integer(&format!("nand({mask},{mask})"), bits), 0);
            assert_eq!(programmer_integer("nor(0,0)", bits), mask);
            assert_eq!(programmer_integer(&format!("nor({mask},0)"), bits), 0);

            let over_width = modulus + 5;
            assert_eq!(
                programmer_integer(&format!("nand({over_width},5)"), bits),
                Integer::from(&mask ^ 5)
            );
            assert_eq!(
                programmer_integer("nand(rol(1,1),nor(0,0))", bits),
                Integer::from(&mask ^ 2)
            );
        }

        assert_eq!(programmer_integer("lshr((1,000),3)", 64), 125);
        assert_eq!(programmer_integer("lshr(8,1,000)", 64), 0);
        assert_eq!(programmer_integer("nand(3,1,001)", 64), word_mask(64) ^ 1);
        assert_eq!(programmer_integer_with_base("nand(FF,0)", 16, 8), 255);
    }

    #[test]
    fn programmer_rotations_are_width_aware_and_accept_huge_counts() {
        let huge_count = (Integer::from(1) << 5000) + 3;
        for bits in [8, 64, 128, 4096] {
            let high_bit = Integer::from(1) << (bits - 1);
            let modulus = Integer::from(1) << bits;
            let over_width = Integer::from(&modulus + 1);
            assert_eq!(programmer_integer("rol(1,1)", bits), 2);
            assert_eq!(programmer_integer("ror(1,1)", bits), high_bit);
            assert_eq!(programmer_integer(&format!("rol({over_width},1)"), bits), 2);
            assert_eq!(programmer_integer(&format!("rol(1,{})", bits + 1), bits), 2);
            assert_eq!(
                programmer_integer(&format!("ror(rol(147,17),17)"), bits),
                Integer::from(147) % modulus
            );
            assert_eq!(programmer_integer(&format!("rol(1,{huge_count})"), bits), 8);
        }
    }

    #[test]
    fn programmer_logical_and_arithmetic_right_shift_are_distinct() {
        let huge_count = (Integer::from(1) << 5000) + 1;
        for bits in [8, 64, 128, 4096] {
            let high_bit = Integer::from(1) << (bits - 1);
            let two_high_bits = Integer::from(3) << (bits - 2);
            let mask = word_mask(bits);
            let over_width = (Integer::from(1) << bits) + 1;
            assert_eq!(
                programmer_integer(&format!("lshr({over_width},0)"), bits),
                1
            );
            assert_eq!(
                programmer_integer(&format!("lshr({high_bit},1)"), bits),
                Integer::from(1) << (bits - 2)
            );
            assert_eq!(
                programmer_integer(&format!("ashr({high_bit},1)"), bits),
                two_high_bits
            );
            assert_eq!(
                programmer_integer(&format!("{high_bit}>>1"), bits),
                Integer::from(1) << (bits - 2)
            );
            assert_eq!(
                programmer_integer(&format!("lshr({high_bit},{huge_count})"), bits),
                0
            );
            assert_eq!(
                programmer_integer(&format!("ashr({mask},{huge_count})"), bits),
                mask
            );
            assert_eq!(
                programmer_integer(&format!("ashr(1,{huge_count})"), bits),
                0
            );
        }
    }

    #[test]
    fn programmer_binary_functions_reject_invalid_arguments() {
        for expression in [
            "nand(1)",
            "nor(1,2,3)",
            "rol(1,-1)",
            "rol(1,0-1)",
            "ror(1,-1)",
            "ror(1,-1+0)",
            "ashr(1,-1)",
            "ashr(8,0-1)",
            "lshr(1,-1)",
            "lshr(8,-2+1)",
            "1,00",
            "abs(1,2)",
        ] {
            assert!(
                evaluate_programmer(expression, AngleUnit::Degrees, 20, 10, 64).is_err(),
                "{expression}"
            );
        }
        assert_eq!(programmer_integer("nand(5.0,3)", 64), word_mask(64) ^ 1);
        assert_eq!(programmer_integer("rol(1,0.0)", 64), 1);
        assert_eq!(programmer_integer("rol(1,-1+2)", 64), 2);
        assert_eq!(programmer_integer("lshr(8.0,1)", 64), 4);
    }

    #[test]
    fn programmer_huge_positive_count_expressions_do_not_wrap_early() {
        let huge_count = Integer::from(1) << 5000;
        for bits in [8, 64, 128, 4096] {
            assert_eq!(
                programmer_integer(&format!("rol(1,({huge_count}+3))"), bits),
                8
            );
            assert_eq!(
                programmer_integer(&format!("lshr({},({huge_count}+1))", word_mask(bits)), bits,),
                0
            );
        }
    }
}
