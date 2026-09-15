use crate::{engine::AngleUnit, precise};
use rug::{Complex, Float, Integer, float::Constant, integer::Order, ops::Pow};

pub fn evaluate(input: &str, angle: AngleUnit, precision: i32) -> Result<Complex, String> {
    let bits = precise::precision_bits(precision);
    let normalized = crate::engine::normalize_input(input)?;
    let mut parser = Parser {
        chars: normalized.chars().collect(),
        pos: 0,
        angle,
        bits,
    };
    let value = parser.bit_or()?;
    parser.space();
    if parser.pos != parser.chars.len() {
        return Err(format!("Unexpected '{}'", parser.chars[parser.pos]));
    }
    if value.number.real().is_nan() || value.number.imag().is_nan() {
        Err("Result is not a number".into())
    } else if value.number.real().is_infinite() || value.number.imag().is_infinite() {
        Err("Overflow: the result is too large".into())
    } else {
        Ok(value.number)
    }
}

pub fn format_value(value: &Complex, format: &str, precision: i32) -> String {
    let real_text = precise::format_value(value.real(), format, precision);
    let imaginary_negative = *value.imag() < 0;
    let imaginary_absolute = value.imag().clone().abs();
    let imaginary_text = precise::format_value(&imaginary_absolute, format, precision);
    let real_is_zero = formatted_is_zero(&real_text);
    let imaginary_is_zero = formatted_is_zero(&imaginary_text);

    if imaginary_is_zero {
        return real_text;
    }

    let coefficient = if imaginary_absolute == 1 {
        String::new()
    } else {
        imaginary_text
    };
    if real_is_zero {
        return format!(
            "{}{}i",
            if imaginary_negative { "-" } else { "" },
            coefficient
        );
    }

    format!(
        "{real_text} {} {coefficient}i",
        if imaginary_negative { "-" } else { "+" }
    )
}

fn formatted_is_zero(text: &str) -> bool {
    text.split_once('e')
        .map_or(text, |(mantissa, _)| mantissa)
        .chars()
        .all(|character| matches!(character, '+' | '-' | '.' | '0'))
}

#[derive(Clone)]
struct ParsedValue {
    number: Complex,
    percentage: bool,
}

impl ParsedValue {
    fn plain(number: Complex) -> Self {
        Self {
            number,
            percentage: false,
        }
    }
}

struct Parser {
    chars: Vec<char>,
    pos: usize,
    angle: AngleUnit,
    bits: u32,
}

impl Parser {
    fn real<T>(&self, value: T) -> Complex
    where
        Float: rug::Assign<T>,
    {
        Complex::with_val(self.bits, (Float::with_val(self.bits, value), 0))
    }

    fn imaginary_unit(&self) -> Complex {
        Complex::with_val(self.bits, (0, 1))
    }

    fn canonical_real_axis(&self, value: Complex) -> Complex {
        if value.imag() == &0 {
            Complex::with_val(self.bits, (value.real(), 0))
        } else {
            value
        }
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
                || matches!(*character, '√' | '∛' | '∜')
                || crate::engine::superscript_digit(*character).is_some()
                || character.is_alphabetic()
                || *character == '_'
        })
    }

    fn root_degree(&self, value: &Complex) -> Result<u32, String> {
        let degree = self.whole_number(value, "Root degree")?;
        if degree < 2 {
            return Err("Root degree must be at least 2".into());
        }
        if degree > 1_000_000 {
            return Err("Root degree is too large".into());
        }
        Ok(degree.to_u32_wrapping())
    }

    fn nth_root(&self, degree: u32, value: Complex) -> Complex {
        if value == 0 {
            return self.real(0);
        }

        let mut reciprocal = Float::with_val(self.bits, 1);
        reciprocal /= degree;
        let exponent = self.real(reciprocal);
        if degree % 2 == 1
            && value.imag() == &0
            && value.real().is_sign_negative()
            && value.real() != &0
        {
            return -self.real(-value.real().clone()).pow(exponent);
        }
        self.canonical_real_axis(value).pow(exponent)
    }

    fn take_superscript_root_degree(&mut self) -> Result<Option<u32>, String> {
        self.space();
        let start = self.pos;
        while self
            .chars
            .get(self.pos)
            .is_some_and(|character| crate::engine::superscript_digit(*character).is_some())
        {
            self.pos += 1;
        }
        if self.pos == start || self.chars.get(self.pos) != Some(&'√') {
            self.pos = start;
            return Ok(None);
        }

        let mut degree = 0u32;
        for character in &self.chars[start..self.pos] {
            let digit = crate::engine::superscript_digit(*character).unwrap();
            degree = degree
                .checked_mul(10)
                .and_then(|value| value.checked_add(digit))
                .ok_or_else(|| "Root degree is too large".to_string())?;
        }
        self.pos += 1;
        if degree < 2 {
            return Err("Root degree must be at least 2".into());
        }
        if degree > 1_000_000 {
            return Err("Root degree is too large".into());
        }
        Ok(Some(degree))
    }

    fn whole_number(&self, value: &Complex, operation: &str) -> Result<Integer, String> {
        if value.imag() != &0 || !value.real().is_integer() {
            return Err(format!("{operation} requires a real whole number"));
        }
        value
            .real()
            .to_integer()
            .ok_or_else(|| "Integer is outside the supported range".into())
    }

    fn integer(&self, value: &Complex) -> Result<Integer, String> {
        self.whole_number(value, "Bitwise operation")
    }

    fn real_component(&self, value: &Complex, operation: &str) -> Result<Float, String> {
        if value.imag() != &0 {
            return Err(format!("{operation} requires a real number"));
        }
        Ok(value.real().clone())
    }

    fn bit_or(&mut self) -> Result<ParsedValue, String> {
        let mut value = self.bit_xor()?;
        while self.take('|') {
            let right = self.bit_xor()?;
            value = ParsedValue::plain(
                self.real(self.integer(&value.number)? | self.integer(&right.number)?),
            );
        }
        Ok(value)
    }

    fn bit_xor(&mut self) -> Result<ParsedValue, String> {
        let mut value = self.bit_and()?;
        while self.take('@') {
            let right = self.bit_and()?;
            value = ParsedValue::plain(
                self.real(self.integer(&value.number)? ^ self.integer(&right.number)?),
            );
        }
        Ok(value)
    }

    fn bit_and(&mut self) -> Result<ParsedValue, String> {
        let mut value = self.shift()?;
        while self.take('&') {
            let right = self.shift()?;
            value = ParsedValue::plain(
                self.real(self.integer(&value.number)? & self.integer(&right.number)?),
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
            let amount = self.integer(&right.number)?.to_u32_wrapping();
            if amount > 1_000_000 {
                return Err("Shift is too large".into());
            }
            let integer = self.integer(&value.number)?;
            value = ParsedValue::plain(self.real(if left {
                integer << amount
            } else {
                integer >> amount
            }));
        }
    }

    fn expression(&mut self) -> Result<ParsedValue, String> {
        let mut value = self.term()?;
        loop {
            if self.take('+') {
                let right = self.term()?;
                if right.percentage && !value.percentage {
                    let mut change = value.number.clone();
                    change *= &right.number;
                    value.number += change;
                } else {
                    value.number += right.number;
                }
                value.percentage = value.percentage && right.percentage;
            } else if self.take('-') {
                let right = self.term()?;
                if right.percentage && !value.percentage {
                    let mut change = value.number.clone();
                    change *= &right.number;
                    value.number -= change;
                } else {
                    value.number -= right.number;
                }
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
                value.number *= right.number;
            } else if self.take('/') {
                let right = self.unary()?;
                if right.number == 0 {
                    return Err("Division by zero is undefined".into());
                }
                value.number /= right.number;
                value.percentage = value.percentage && !right.percentage;
            } else if self.take_str("mod") {
                let right = self.unary()?;
                let mut left_real = self.real_component(&value.number, "Modulo")?;
                let right_real = self.real_component(&right.number, "Modulo")?;
                if right_real == 0 {
                    return Err("Modulo by zero is undefined".into());
                }
                left_real %= right_real;
                value = ParsedValue::plain(self.real(left_real));
            } else if self.starts_primary() {
                value.number *= self.unary()?.number;
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
        Ok(ParsedValue::plain(
            self.canonical_real_axis(value.number).pow(exponent.number),
        ))
    }

    fn unary(&mut self) -> Result<ParsedValue, String> {
        if self.take('-') {
            let mut value = self.unary()?;
            value.number = -value.number;
            Ok(value)
        } else if self.take('+') {
            self.unary()
        } else if self.take('~') {
            let value = self.unary()?;
            Ok(ParsedValue::plain(self.real(!self.integer(&value.number)?)))
        } else if self.take('√') {
            let value = self.unary()?;
            Ok(ParsedValue::plain(
                self.canonical_real_axis(value.number).sqrt(),
            ))
        } else if self.take('∛') {
            let value = self.unary()?;
            Ok(ParsedValue::plain(self.nth_root(3, value.number)))
        } else if self.take('∜') {
            let value = self.unary()?;
            Ok(ParsedValue::plain(self.nth_root(4, value.number)))
        } else if let Some(degree) = self.take_superscript_root_degree()? {
            let value = self.unary()?;
            Ok(ParsedValue::plain(self.nth_root(degree, value.number)))
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
        if self
            .chars
            .get(self.pos)
            .is_some_and(|character| character.is_ascii_digit() || *character == '.')
        {
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
            let parsed = Float::parse(&text).map_err(|_| "Invalid number")?;
            return self.postfix(ParsedValue::plain(self.real(parsed)));
        }
        let start = self.pos;
        while self.pos < self.chars.len()
            && (self.chars[self.pos].is_alphanumeric() || self.chars[self.pos] == '_')
        {
            self.pos += 1;
        }
        let name: String = self.chars[start..self.pos].iter().collect();
        if name == "pi" {
            return self.postfix(ParsedValue::plain(self.real(Constant::Pi)));
        }
        if name == "e" {
            return self.postfix(ParsedValue::plain(self.real(1).exp()));
        }
        if matches!(name.as_str(), "i" | "I") {
            return self.postfix(ParsedValue::plain(self.imaginary_unit()));
        }
        if name.is_empty() {
            return Err("Expected a number".into());
        }
        if !self.take('(') {
            return Err(format!("Unknown function: {name}"));
        }
        let argument = self.bit_or()?;
        let second_argument = if self.take(',') {
            Some(self.bit_or()?)
        } else {
            None
        };
        if !self.take(')') {
            return Err("Expected closing parenthesis".into());
        }
        let value = if matches!(name.as_str(), "root" | "nthroot") {
            let radicand =
                second_argument.ok_or_else(|| "Root requires a degree and value".to_string())?;
            let degree = self.root_degree(&argument.number)?;
            self.nth_root(degree, radicand.number)
        } else {
            if second_argument.is_some() {
                return Err(format!("{name} accepts one value"));
            }
            self.function(&name, argument.number)?
        };
        self.postfix(ParsedValue::plain(value))
    }

    fn function(&self, name: &str, value: Complex) -> Result<Complex, String> {
        let pi = || Float::with_val(self.bits, Constant::Pi);
        let to_radians = |mut number: Complex| {
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
        let from_radians = |mut number: Complex| {
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
            "asin" => from_radians(self.canonical_real_axis(value).asin()),
            "acos" => from_radians(self.canonical_real_axis(value).acos()),
            "atan" => from_radians(self.canonical_real_axis(value).atan()),
            "sinh" => value.sinh(),
            "cosh" => value.cosh(),
            "tanh" => value.tanh(),
            "asinh" => self.canonical_real_axis(value).asinh(),
            "acosh" => self.canonical_real_axis(value).acosh(),
            "atanh" => self.canonical_real_axis(value).atanh(),
            "sqrt" => self.canonical_real_axis(value).sqrt(),
            "cbrt" => self.nth_root(3, value),
            "ln" => self.canonical_real_axis(value).ln(),
            "log" | "log10" => {
                let mut result = self.canonical_real_axis(value).ln();
                result /= Float::with_val(self.bits, 10).ln();
                result
            }
            "log2" => {
                let mut result = self.canonical_real_axis(value).ln();
                result /= Float::with_val(self.bits, 2).ln();
                result
            }
            "abs" => value.abs(),
            "exp" => value.exp(),
            "conj" => value.conj(),
            "arg" => from_radians(value.arg()),
            "re" | "real" => self.real(value.real().clone()),
            "im" | "imag" => self.real(value.imag().clone()),
            "floor" => self.real(self.real_component(&value, "Floor")?.floor()),
            "ceil" => self.real(self.real_component(&value, "Ceiling")?.ceil()),
            "round" => self.real(self.real_component(&value, "Rounding")?.round()),
            "trunc" | "int" => self.real(self.real_component(&value, "Truncation")?.trunc()),
            "frac" => {
                let mut real = self.real_component(&value, "Fractional part")?;
                let truncated = real.clone().trunc();
                real -= truncated;
                self.real(real)
            }
            "twos" => -value,
            "swap" => {
                let integer = self.whole_number(&value, "Byte swap")?;
                if integer < 0 {
                    return Err("Byte swap requires a non-negative whole number".into());
                }
                let byte_count = integer.significant_bits().div_ceil(8).max(8) as usize;
                let mut bytes = integer.to_digits::<u8>(Order::Lsf);
                bytes.resize(byte_count, 0);
                bytes.reverse();
                self.real(Integer::from_digits(&bytes, Order::Lsf))
            }
            _ => return Err(format!("Unknown function: {name}")),
        };
        Ok(result)
    }

    fn postfix(&mut self, mut value: ParsedValue) -> Result<ParsedValue, String> {
        loop {
            if self.take('%') {
                value.number /= 100;
                value.percentage = true;
            } else if self.take('!') {
                let integer = self.whole_number(&value.number, "Factorial")?;
                if integer < 0 {
                    return Err("Factorial requires a non-negative whole number".into());
                }
                let Some(number) = integer.to_u32() else {
                    return Err("Factorial input is too large".into());
                };
                if number > 100_000 {
                    return Err("Factorial input is limited to 100,000".into());
                }
                value = ParsedValue::plain(self.real(Integer::from(Integer::factorial(number))));
            } else {
                return Ok(value);
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn automatic(expression: &str) -> String {
        let value = evaluate(expression, AngleUnit::Radians, 20).unwrap();
        format_value(&value, "automatic", 20)
    }

    #[test]
    fn imaginary_literals_and_basic_arithmetic() {
        let cases = [
            ("i", "i"),
            ("I", "i"),
            ("3+4ⅈ", "3 + 4i"),
            ("2i+3i", "5i"),
            ("3+4i", "3 + 4i"),
            ("i^2", "-1"),
            ("i^3", "-i"),
            ("i^4", "1"),
            ("(1+i)*(1-i)", "2"),
            ("(1+i)/(1-i)", "i"),
            ("2(i+1)", "2 + 2i"),
            ("50i%", "0.5i"),
        ];
        for (expression, expected) in cases {
            assert_eq!(automatic(expression), expected, "{expression}");
        }
    }

    #[test]
    fn complex_roots_powers_and_functions() {
        let cases = [
            ("√81", "9"),
            ("sqrt(81)", "9"),
            ("2√9", "6"),
            ("∛8", "2"),
            ("∛-8", "-2"),
            ("cbrt(27)", "3"),
            ("∜16", "2"),
            ("root(3,8)", "2"),
            ("root(3,1,000)", "10"),
            ("nthroot(4,16)", "2"),
            ("²√81", "9"),
            ("⁵√32", "2"),
            ("⁵√-32", "-2"),
            ("¹⁰√1024", "2"),
            ("2⁵√32", "4"),
            ("√-1", "i"),
            ("sqrt(-9)", "3i"),
            ("(-1)^0.5", "i"),
            ("abs(3+4i)", "5"),
            ("conj(3+4i)", "3 - 4i"),
            ("re(3+4i)", "3"),
            ("real(3+4i)", "3"),
            ("im(3+4i)", "4"),
            ("imag(3+4i)", "4"),
            ("arg(i)", "1.57079632679489661923"),
        ];
        for (expression, expected) in cases {
            assert_eq!(automatic(expression), expected, "{expression}");
        }
    }

    #[test]
    fn complex_transcendental_identities() {
        assert_eq!(automatic("exp(i*pi)"), "-1");
        assert_eq!(automatic("ln(-1)"), "3.14159265358979323846i");
        assert_eq!(automatic("i^i"), "0.20787957635076190855");

        let sine = evaluate("sin(i)", AngleUnit::Radians, 30).unwrap();
        let expected = Float::with_val(sine.imag().prec(), 1).sinh();
        let tolerance = Float::with_val(
            sine.imag().prec(),
            Float::parse("1e-25").expect("valid tolerance"),
        );
        assert_eq!(sine.real(), &0);
        assert!((sine.imag() - expected).abs() < tolerance);

        let cosine = evaluate("cos(i)", AngleUnit::Radians, 30).unwrap();
        let expected = Float::with_val(cosine.real().prec(), 1).cosh();
        let tolerance = Float::with_val(
            cosine.real().prec(),
            Float::parse("1e-25").expect("valid tolerance"),
        );
        assert_eq!(cosine.imag(), &0);
        assert!((cosine.real() - expected).abs() < tolerance);
    }

    #[test]
    fn complex_domain_errors_are_specific() {
        let cases = [
            ("i/0", "Division by zero is undefined"),
            ("i mod 2", "Modulo requires a real number"),
            ("i!", "Factorial requires a real whole number"),
            ("i&1", "Bitwise operation requires a real whole number"),
            ("floor(i)", "Floor requires a real number"),
            ("root(1,8)", "Root degree must be at least 2"),
            ("root(2.5,8)", "Root degree requires a real whole number"),
            ("root(2+i,8)", "Root degree requires a real whole number"),
            ("root(1000001,8)", "Root degree is too large"),
            ("root(3)", "Root requires a degree and value"),
            ("⁰√1", "Root degree must be at least 2"),
            ("¹√1", "Root degree must be at least 2"),
        ];
        for (expression, expected) in cases {
            assert_eq!(
                evaluate(expression, AngleUnit::Radians, 20).unwrap_err(),
                expected,
                "{expression}"
            );
        }
    }

    #[test]
    fn one_hundred_complex_multiplication_cases() {
        for index in 0..100 {
            let a = index % 11 - 5;
            let b = index % 7 - 3;
            let c = index % 9 - 4;
            let d = index % 5 - 2;
            let expression = format!("({a}+({b})i)*({c}+({d})i)");
            let value = evaluate(&expression, AngleUnit::Radians, 30).unwrap();
            assert_eq!(value.real(), &(a * c - b * d));
            assert_eq!(value.imag(), &(a * d + b * c));
        }
    }

    #[test]
    fn one_hundred_powers_of_i_follow_the_four_value_cycle() {
        for exponent in 0..100 {
            let expected = match exponent % 4 {
                0 => "1",
                1 => "i",
                2 => "-1",
                _ => "-i",
            };
            assert_eq!(automatic(&format!("i^{exponent}")), expected);
        }
    }

    #[test]
    fn one_hundred_negative_roots_use_the_positive_principal_value() {
        for number in 1..=100 {
            let value = evaluate(
                &format!("sqrt(-{})", number * number),
                AngleUnit::Radians,
                30,
            )
            .unwrap();
            assert_eq!(value.real(), &0);
            assert_eq!(value.imag(), &number);
        }
    }

    #[test]
    fn one_hundred_exact_custom_roots() {
        let tolerance = Float::with_val(256, Float::parse("1e-50").unwrap());
        let mut checked = 0;
        for degree in 2u32..=11 {
            for base in 1u32..=10 {
                let radicand = Integer::from(base).pow(degree);
                let value = evaluate(
                    &format!("root({degree},{radicand})"),
                    AngleUnit::Radians,
                    60,
                )
                .unwrap();
                assert_eq!(value.imag(), &0, "degree {degree}, base {base}");
                let error = Float::with_val(value.real().prec(), value.real() - base).abs();
                assert!(
                    error < tolerance,
                    "degree {degree}, base {base}, result {}",
                    value.real()
                );
                checked += 1;
            }
        }
        assert_eq!(checked, 100);
    }

    #[test]
    fn complex_results_respect_every_result_format() {
        let value = evaluate("3000+4000i", AngleUnit::Radians, 30).unwrap();
        let cases = [
            ("automatic", "3000 + 4000i"),
            ("fixed", "3000.000 + 4000.000i"),
            ("scientific", "3.000e3 + 4.000e3i"),
            ("engineering", "3.000e3 + 4.000e3i"),
        ];
        for (format, expected) in cases {
            assert_eq!(format_value(&value, format, 3), expected, "{format}");
        }
    }
}
