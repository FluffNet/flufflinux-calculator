#[derive(Clone, Copy)]
pub enum AngleUnit {
    Degrees,
    Radians,
    Gradians,
}

#[allow(dead_code)]
impl AngleUnit {
    pub fn from_name(name: &str) -> Self {
        match name {
            "radians" => Self::Radians,
            "gradians" => Self::Gradians,
            _ => Self::Degrees,
        }
    }
    fn radians(self, x: f64) -> f64 {
        match self {
            Self::Degrees => x.to_radians(),
            Self::Radians => x,
            Self::Gradians => x * std::f64::consts::PI / 200.0,
        }
    }
    fn convert_from_radians(self, x: f64) -> f64 {
        match self {
            Self::Degrees => x.to_degrees(),
            Self::Radians => x,
            Self::Gradians => x * 200.0 / std::f64::consts::PI,
        }
    }
}

pub(crate) fn normalize_input(input: &str) -> Result<String, String> {
    let input = input.trim();
    let input = input.strip_suffix('=').unwrap_or(input);
    let grouped = normalize_grouping(&input.replace('\u{200b}', ""))?;
    let normalized = normalize_superscript_powers(&normalize_shift_aliases(&grouped))
        .replace("**", "^")
        .replace("⁻¹", "^(-1)")
        .replace(['×', '·', '⋅', '∙'], "*")
        .replace(['÷', '⁄', '∕'], "/")
        .replace('−', "-")
        .replace('π', "pi")
        .replace('ⅈ', "i")
        .replace('∧', "&")
        .replace('∨', "|")
        .replace('⊻', "@")
        .replace('¬', "~")
        .replace("≪", "<<")
        .replace("≫", ">>");
    Ok(normalized)
}

fn normalize_shift_aliases(input: &str) -> String {
    let mut output = String::with_capacity(input.len() + 2);
    let mut characters = input.chars().peekable();
    while let Some(character) = characters.next() {
        if character == '<' || character == '>' {
            output.push(character);
            if characters.peek() == Some(&character) {
                output.push(characters.next().unwrap_or(character));
            } else {
                output.push(character);
            }
        } else {
            output.push(character);
        }
    }
    output
}

pub(crate) fn superscript_digit(character: char) -> Option<u32> {
    match character {
        '⁰' => Some(0),
        '¹' => Some(1),
        '²' => Some(2),
        '³' => Some(3),
        '⁴' => Some(4),
        '⁵' => Some(5),
        '⁶' => Some(6),
        '⁷' => Some(7),
        '⁸' => Some(8),
        '⁹' => Some(9),
        _ => None,
    }
}

fn normalize_superscript_powers(input: &str) -> String {
    let chars: Vec<char> = input.chars().collect();
    let mut output = String::with_capacity(input.len());
    let mut index = 0;
    while index < chars.len() {
        if superscript_digit(chars[index]).is_none() {
            output.push(chars[index]);
            index += 1;
            continue;
        }

        let start = index;
        while index < chars.len() && superscript_digit(chars[index]).is_some() {
            index += 1;
        }
        if chars.get(index) == Some(&'√') {
            output.extend(chars[start..index].iter());
            continue;
        }
        for character in &chars[start..index] {
            match character {
                '²' => output.push_str("^2"),
                '³' => output.push_str("^3"),
                _ => output.push(*character),
            }
        }
    }
    output
}

#[cfg(test)]
pub fn evaluate(input: &str, angle: AngleUnit) -> Result<f64, String> {
    crate::precise::evaluate(input, angle, 15).map(|value| value.to_f64())
}

fn normalize_grouping(input: &str) -> Result<String, String> {
    let chars: Vec<char> = input.chars().collect();
    let mut output = String::with_capacity(input.len());
    let mut i = 0;
    while i < chars.len() {
        if chars[i].is_ascii_digit() {
            let start = i;
            while i < chars.len()
                && (chars[i].is_ascii_digit()
                    || chars[i] == '.'
                    || (chars[i] == ',' && !is_argument_separator(&chars, i)))
            {
                i += 1;
            }
            let token: String = chars[start..i].iter().collect();
            if token.contains(',') {
                let mut decimal_parts = token.split('.');
                let integer = decimal_parts.next().unwrap_or("");
                let fraction = decimal_parts.next();
                let groups: Vec<&str> = integer.split(',').collect();
                if groups[0].is_empty()
                    || groups[0].len() > 3
                    || !groups[0].chars().all(|c| c.is_ascii_digit())
                    || groups
                        .iter()
                        .skip(1)
                        .any(|g| g.len() != 3 || !g.chars().all(|c| c.is_ascii_digit()))
                    || fraction.is_some_and(|digits| digits.contains(','))
                    || decimal_parts.next().is_some()
                {
                    return Err("Invalid thousands separator placement".into());
                }
            }
            output.extend(token.chars().filter(|c| *c != ','));
        } else {
            output.push(chars[i]);
            i += 1;
        }
    }
    Ok(output)
}

fn is_named_argument_separator(
    chars: &[char],
    comma_index: usize,
    function_names: &[&str],
) -> bool {
    if chars.get(comma_index) != Some(&',') {
        return false;
    }

    let mut nesting = 0usize;
    for opening_index in (0..comma_index).rev() {
        match chars[opening_index] {
            ')' => nesting += 1,
            '(' if nesting > 0 => nesting -= 1,
            '(' => {
                let mut name_end = opening_index;
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
                if !function_names.contains(&name.as_str()) {
                    return false;
                }

                let mut inner_nesting = 0usize;
                for character in &chars[opening_index + 1..comma_index] {
                    match character {
                        '(' => inner_nesting += 1,
                        ')' if inner_nesting > 0 => inner_nesting -= 1,
                        ',' if inner_nesting == 0 => return false,
                        _ => {}
                    }
                }
                return true;
            }
            _ => {}
        }
    }
    false
}

pub(crate) fn is_argument_separator(chars: &[char], comma_index: usize) -> bool {
    is_named_argument_separator(
        chars,
        comma_index,
        &[
            "root", "nthroot", "nand", "nor", "rol", "ror", "ashr", "lshr",
        ],
    )
}

pub(crate) fn is_root_argument_separator(chars: &[char], comma_index: usize) -> bool {
    is_named_argument_separator(chars, comma_index, &["root", "nthroot"])
}

#[cfg(test)]
pub fn format_value(value: f64, format: &str, precision: i32) -> String {
    let value = if value == 0.0 { 0.0 } else { value };
    let p = precision.clamp(1, 15) as usize;
    let text = match format {
        "fixed" => format!("{value:.p$}"),
        "scientific" => format!("{value:.p$e}"),
        "engineering" => {
            if value == 0.0 {
                "0".into()
            } else {
                let e = (value.abs().log10().floor() as i32).div_euclid(3) * 3;
                format!("{:.p$}e{e}", value / 10f64.powi(e))
            }
        }
        _ => format!("{value:.p$}"),
    };
    let text = if format == "automatic" && text.contains('.') {
        text.trim_end_matches('0').trim_end_matches('.').to_string()
    } else {
        text
    };
    if text.starts_with('-')
        && text
            .parse::<f64>()
            .ok()
            .is_some_and(|rendered| rendered == 0.0)
    {
        text[1..].to_string()
    } else {
        text
    }
}

#[allow(dead_code)]
struct Parser {
    chars: Vec<char>,
    pos: usize,
    angle: AngleUnit,
}

#[allow(dead_code)]
#[derive(Clone, Copy)]
struct ParsedValue {
    number: f64,
    percentage: bool,
}

#[allow(dead_code)]
impl ParsedValue {
    fn plain(number: f64) -> Self {
        Self {
            number,
            percentage: false,
        }
    }
}

#[allow(dead_code)]
impl Parser {
    fn space(&mut self) {
        while self.pos < self.chars.len() && self.chars[self.pos].is_whitespace() {
            self.pos += 1;
        }
    }
    fn take(&mut self, c: char) -> bool {
        self.space();
        if self.chars.get(self.pos) == Some(&c) {
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
        self.chars.get(pos).is_some_and(|c| {
            c.is_ascii_digit()
                || *c == '.'
                || *c == '('
                || *c == '√'
                || c.is_alphabetic()
                || *c == '_'
        })
    }
    fn bit_or(&mut self) -> Result<ParsedValue, String> {
        let mut x = self.bit_xor()?;
        while self.take('|') {
            let y = self.bit_xor()?;
            x = ParsedValue::plain(((x.number as i64) | (y.number as i64)) as f64);
        }
        Ok(x)
    }
    fn bit_xor(&mut self) -> Result<ParsedValue, String> {
        let mut x = self.bit_and()?;
        while self.take('@') {
            let y = self.bit_and()?;
            x = ParsedValue::plain(((x.number as i64) ^ (y.number as i64)) as f64);
        }
        Ok(x)
    }
    fn bit_and(&mut self) -> Result<ParsedValue, String> {
        let mut x = self.shift()?;
        while self.take('&') {
            let y = self.shift()?;
            x = ParsedValue::plain(((x.number as i64) & (y.number as i64)) as f64);
        }
        Ok(x)
    }
    fn shift(&mut self) -> Result<ParsedValue, String> {
        let mut x = self.expression()?;
        loop {
            if self.take_str("<<") {
                let y = self.expression()?;
                x = ParsedValue::plain((x.number as i64).wrapping_shl(y.number as u32) as f64);
            } else if self.take_str(">>") {
                let y = self.expression()?;
                x = ParsedValue::plain((x.number as i64).wrapping_shr(y.number as u32) as f64);
            } else {
                return Ok(x);
            }
        }
    }
    fn expression(&mut self) -> Result<ParsedValue, String> {
        let mut x = self.term()?;
        loop {
            if self.take('+') {
                let y = self.term()?;
                if x.percentage && y.percentage {
                    x.number += y.number;
                } else if y.percentage {
                    x.number += x.number * y.number;
                    x.percentage = false;
                } else {
                    x.number += y.number;
                    x.percentage = false;
                }
            } else if self.take('-') {
                let y = self.term()?;
                if x.percentage && y.percentage {
                    x.number -= y.number;
                } else if y.percentage {
                    x.number -= x.number * y.number;
                    x.percentage = false;
                } else {
                    x.number -= y.number;
                    x.percentage = false;
                }
            } else {
                return Ok(x);
            }
        }
    }
    fn term(&mut self) -> Result<ParsedValue, String> {
        let mut x = self.unary()?;
        loop {
            if self.take('*') {
                let y = self.unary()?;
                x.number *= y.number;
            } else if self.take('/') {
                let y = self.unary()?;
                if y.number == 0.0 {
                    return Err("Division by zero is undefined".into());
                }
                x.number /= y.number;
                x.percentage = x.percentage && !y.percentage;
            } else if self.take_str("mod") {
                let y = self.unary()?;
                if y.number == 0.0 {
                    return Err("Modulo by zero is undefined".into());
                }
                x.number %= y.number;
                x.percentage = false;
            } else if self.starts_primary() {
                let y = self.unary()?;
                x.number *= y.number;
            } else {
                return Ok(x);
            }
        }
    }
    fn power(&mut self) -> Result<ParsedValue, String> {
        let x = self.primary()?;
        if self.take('^') {
            let y = self.unary()?;
            Ok(ParsedValue::plain(x.number.powf(y.number)))
        } else {
            Ok(x)
        }
    }
    fn unary(&mut self) -> Result<ParsedValue, String> {
        if self.take('-') {
            let mut x = self.unary()?;
            x.number = -x.number;
            Ok(x)
        } else if self.take('+') {
            self.unary()
        } else if self.take('~') {
            let x = self.unary()?;
            Ok(ParsedValue::plain((!(x.number as i64)) as f64))
        } else if self.take('√') {
            let x = self.unary()?;
            if x.number < 0.0 {
                Err("Square root is undefined for negative values".into())
            } else {
                Ok(ParsedValue::plain(x.number.sqrt()))
            }
        } else {
            self.power()
        }
    }
    fn primary(&mut self) -> Result<ParsedValue, String> {
        self.space();
        if self.take('(') {
            let x = self.bit_or()?;
            if !self.take(')') {
                return Err("Expected closing parenthesis".into());
            }
            return self.postfix(x);
        }
        if self.pos < self.chars.len()
            && (self.chars[self.pos].is_ascii_digit() || self.chars[self.pos] == '.')
        {
            let start = self.pos;
            while self.pos < self.chars.len()
                && (self.chars[self.pos].is_ascii_digit() || self.chars[self.pos] == '.')
            {
                self.pos += 1
            }
            if self.pos < self.chars.len()
                && (self.chars[self.pos] == 'e' || self.chars[self.pos] == 'E')
            {
                let exponent_marker = self.pos;
                self.pos += 1;
                if self.pos < self.chars.len()
                    && (self.chars[self.pos] == '+' || self.chars[self.pos] == '-')
                {
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
            let s: String = self.chars[start..self.pos].iter().collect();
            return self.postfix(ParsedValue::plain(s.parse().map_err(|_| "Invalid number")?));
        }
        let start = self.pos;
        while self.pos < self.chars.len()
            && (self.chars[self.pos].is_alphanumeric() || self.chars[self.pos] == '_')
        {
            self.pos += 1
        }
        let name: String = self.chars[start..self.pos].iter().collect();
        if name == "pi" {
            return self.postfix(ParsedValue::plain(std::f64::consts::PI));
        }
        if name == "e" {
            return self.postfix(ParsedValue::plain(std::f64::consts::E));
        }
        if name.is_empty() {
            return Err("Expected a number".into());
        }
        if !self.take('(') {
            return Err(format!("Unknown function: {name}"));
        }
        let x = self.bit_or()?;
        if !self.take(')') {
            return Err("Expected closing parenthesis".into());
        }
        let y = match name.as_str() {
            "sin" => self.angle.radians(x.number).sin(),
            "cos" => self.angle.radians(x.number).cos(),
            "tan" => self.angle.radians(x.number).tan(),
            "asin" => self.angle.convert_from_radians(x.number.asin()),
            "acos" => self.angle.convert_from_radians(x.number.acos()),
            "atan" => self.angle.convert_from_radians(x.number.atan()),
            "sinh" => x.number.sinh(),
            "cosh" => x.number.cosh(),
            "tanh" => x.number.tanh(),
            "asinh" => x.number.asinh(),
            "acosh" => x.number.acosh(),
            "atanh" => x.number.atanh(),
            "sqrt" => {
                if x.number < 0.0 {
                    return Err("Square root is undefined for negative values".into());
                } else {
                    x.number.sqrt()
                }
            }
            "ln" => x.number.ln(),
            "log" | "log10" => x.number.log10(),
            "log2" => x.number.log2(),
            "abs" => x.number.abs(),
            "exp" => x.number.exp(),
            "floor" => x.number.floor(),
            "ceil" => x.number.ceil(),
            "round" => x.number.round(),
            "trunc" | "int" => x.number.trunc(),
            "frac" => x.number.fract(),
            "twos" => (!(x.number as i64)).wrapping_add(1) as f64,
            "swap" => (x.number as i64).swap_bytes() as f64,
            _ => return Err(format!("Unknown function: {name}")),
        };
        self.postfix(ParsedValue::plain(y))
    }
    fn postfix(&mut self, mut x: ParsedValue) -> Result<ParsedValue, String> {
        loop {
            if self.take('%') {
                x.number /= 100.0;
                x.percentage = true;
            } else if self.take('!') {
                if x.number < 0.0 || x.number.fract() != 0.0 || x.number > 170.0 {
                    return Err(
                        "Factorial is only defined for non-negative integers up to 170".into(),
                    );
                }
                let mut n = 1.0;
                for i in 2..=x.number as u64 {
                    n *= i as f64
                }
                x = ParsedValue::plain(n);
            } else {
                return Ok(x);
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn arithmetic() {
        assert_eq!(evaluate("6/(3*2)", AngleUnit::Degrees).unwrap(), 1.0);
        assert_eq!(evaluate("10/3*3", AngleUnit::Degrees).unwrap(), 10.0)
    }
    #[test]
    fn grouped_numbers() {
        assert_eq!(
            evaluate("1,000 + 23,456.75", AngleUnit::Degrees).unwrap(),
            24456.75
        );
        assert!(evaluate("1,00 + 2", AngleUnit::Degrees).is_err());
        assert_eq!(normalize_input("root(3,1,000)").unwrap(), "root(3,1000)");
        assert_eq!(normalize_input("nthroot(4,16)").unwrap(), "nthroot(4,16)");
        assert_eq!(normalize_input("x²+2³").unwrap(), "x^2+2^3");
        assert_eq!(normalize_input("⁵√32").unwrap(), "⁵√32");
        assert_eq!(normalize_input("¹⁰√1024").unwrap(), "¹⁰√1024");
        assert!(normalize_input("root(3,1,00)").is_err());
    }
    #[test]
    fn whole_number_formatting() {
        assert_eq!(format_value(1000.0, "automatic", 9), "1000");
        assert_eq!(format_value(12.3400, "automatic", 9), "12.34");
    }
    #[test]
    fn result_formatting_modes() {
        let cases = [
            ("automatic", "12000"),
            ("fixed", "12000.000000000"),
            ("scientific", "1.200000000e4"),
            ("engineering", "12.000000000e3"),
        ];

        for (mode, expected) in cases {
            let rendered = format_value(12000.0, mode, 9);
            assert_eq!(rendered, expected, "unexpected {mode} rendering");
            assert_eq!(
                evaluate(&format!("{rendered}+1"), AngleUnit::Degrees).unwrap(),
                12001.0,
                "a {mode} result must remain usable in the next calculation"
            );
        }
    }
    #[test]
    fn negative_zero_is_normalized() {
        let cases = [
            ("automatic", "0"),
            ("fixed", "0.000000000"),
            ("scientific", "0.000000000e0"),
            ("engineering", "0"),
        ];

        for (mode, expected) in cases {
            assert_eq!(format_value(-0.0, mode, 9), expected);
        }

        assert_eq!(format_value(-0.0000000001, "automatic", 9), "0");
        assert_eq!(format_value(-0.0000000001, "fixed", 9), "0.000000000");

        let result = evaluate("-4999768768765344940229132288*0", AngleUnit::Degrees).unwrap();
        assert_eq!(format_value(result, "automatic", 9), "0");
    }

    #[test]
    fn functions() {
        assert!((evaluate("sin(30)^2+cos(30)^2", AngleUnit::Degrees).unwrap() - 1.0).abs() < 1e-12);
        assert_eq!(evaluate("5!", AngleUnit::Degrees).unwrap(), 120.0)
    }
    #[test]
    fn errors() {
        assert!(
            evaluate("5/0", AngleUnit::Degrees)
                .unwrap_err()
                .contains("zero")
        );
        assert!(
            evaluate("√-1", AngleUnit::Degrees)
                .unwrap_err()
                .contains("real number")
        );
    }
    #[test]
    fn programmer_operators() {
        assert_eq!(evaluate("12 ∧ 10", AngleUnit::Degrees).unwrap(), 8.0);
        assert_eq!(evaluate("5 ≪ 2", AngleUnit::Degrees).unwrap(), 20.0);
        assert_eq!(evaluate("5 < 2", AngleUnit::Degrees).unwrap(), 20.0);
        assert_eq!(evaluate("16 > 2", AngleUnit::Degrees).unwrap(), 4.0);
        assert_eq!(normalize_input("5 << 2").unwrap(), "5 << 2");
        assert_eq!(normalize_input("16 >> 2").unwrap(), "16 >> 2");
        assert_eq!(evaluate("12 ⊻ 10", AngleUnit::Degrees).unwrap(), 6.0);
    }

    #[test]
    fn basic_mode_matrix_100() {
        let cases: [(&str, f64); 100] = [
            ("2+2", 4.0),
            ("0+0", 0.0),
            ("123+456", 579.0),
            ("1,000+2,500", 3500.0),
            ("0.1+0.2", 0.3),
            ("-5+12", 7.0),
            ("10-3", 7.0),
            ("3-10", -7.0),
            ("1,000-250", 750.0),
            ("5.5-2.25", 3.25),
            ("-8-2", -10.0),
            ("42-42", 0.0),
            ("6*7", 42.0),
            ("0*999", 0.0),
            ("-4*8", -32.0),
            ("-3*-9", 27.0),
            ("2.5*4", 10.0),
            ("1,200*3", 3600.0),
            ("8/2", 4.0),
            ("7/2", 3.5),
            ("-12/3", -4.0),
            ("12/-3", -4.0),
            ("1/4", 0.25),
            ("1,000/25", 40.0),
            ("25%", 0.25),
            ("200*15%", 30.0),
            ("50+10%", 55.0),
            ("80/20%", 400.0),
            ("1,000*2.5%", 25.0),
            ("2+3*4", 14.0),
            ("20/5+6", 10.0),
            ("18-2*5", 8.0),
            ("8/2*3", 12.0),
            ("2*3+4*5", 26.0),
            ("100-20/4", 95.0),
            ("5+6/3*2", 9.0),
            ("(2+3)*4", 20.0),
            ("20/(2+3)", 4.0),
            ("10-(3+2)", 5.0),
            ("(1.5+2.5)*3", 12.0),
            ("-(4+6)", -10.0),
            ("((2+3)*2)-1", 9.0),
            (" 12 + 8 ", 20.0),
            ("9×9", 81.0),
            ("81÷9", 9.0),
            ("12−5", 7.0),
            ("1,234.5+765.5", 2000.0),
            ("12,345/5", 2469.0),
            (".5+.25", 0.75),
            ("3--2", 5.0),
            ("1+2+3+4+5", 15.0),
            ("1000000-1", 999999.0),
            ("999*999", 998001.0),
            ("144/12", 12.0),
            ("2.75+3.125", 5.875),
            ("10.5-0.75", 9.75),
            ("0.125*8", 1.0),
            ("5/8", 0.625),
            ("-0.5+0.25", -0.25),
            ("--12", 12.0),
            ("2+-3", -1.0),
            ("2- -3", 5.0),
            ("(8)", 8.0),
            ("((8))", 8.0),
            ("(2+3)*(7-4)", 15.0),
            ("100/(5*4)", 5.0),
            ("18/(3+3)", 3.0),
            ("2*(3+4*5)", 46.0),
            ("(2+3)*(4+5)", 45.0),
            ("1000/(10/2)", 200.0),
            ("10%+20%", 0.3),
            ("100+20%-10%", 108.0),
            ("100-20%+10%", 88.0),
            ("50*50%", 25.0),
            ("25/50%", 50.0),
            ("999+1%", 1008.99),
            ("250-12%", 220.0),
            ("1,000+0.5%", 1005.0),
            ("12.5%*80", 10.0),
            ("0.5%", 0.005),
            ("1,000,000+1", 1000001.0),
            ("12,345.67-345.67", 12000.0),
            ("9,999*0.1", 999.9),
            ("100,000/0.5", 200000.0),
            (".001*1000", 1.0),
            ("1.+2.", 3.0),
            ("00012+0003", 15.0),
            ("1e3+2", 1002.0),
            ("2e-3*1000", 2.0),
            ("6·7", 42.0),
            ("8∕4", 2.0),
            ("9⁄3", 3.0),
            ("5−−2", 7.0),
            ("+7", 7.0),
            ("-(-(-2))", -2.0),
            ("3(4+1)", 15.0),
            ("(2+1)4", 12.0),
            ("2(3)(4)", 24.0),
            ("100 mod 9", 1.0),
            ("17 mod 5+2", 4.0),
        ];

        for (expression, expected) in cases {
            let actual = evaluate(expression, AngleUnit::Degrees)
                .unwrap_or_else(|error| panic!("{expression} failed: {error}"));
            let tolerance = 1e-10 * expected.abs().max(1.0);
            assert!(
                (actual - expected).abs() <= tolerance,
                "{expression}: expected {expected}, got {actual}"
            );
        }

        assert_eq!(evaluate("10 mod 3", AngleUnit::Degrees).unwrap(), 1.0);
    }

    #[test]
    fn advanced_mode_matrix_100() {
        let direct_cases = [
            ("sin(30)", AngleUnit::Degrees, 0.5),
            ("cos(60)", AngleUnit::Degrees, 0.5),
            ("tan(45)", AngleUnit::Degrees, 1.0),
            ("asin(0.5)", AngleUnit::Degrees, 30.0),
            ("acos(0.5)", AngleUnit::Degrees, 60.0),
            ("atan(1)", AngleUnit::Degrees, 45.0),
            ("sinh(1)", AngleUnit::Degrees, 1.0_f64.sinh()),
            ("cosh(1)", AngleUnit::Degrees, 1.0_f64.cosh()),
            ("tanh(1)", AngleUnit::Degrees, 1.0_f64.tanh()),
            ("asinh(1)", AngleUnit::Degrees, 1.0_f64.asinh()),
            ("acosh(2)", AngleUnit::Degrees, 2.0_f64.acosh()),
            ("atanh(0.5)", AngleUnit::Degrees, 0.5_f64.atanh()),
            ("sqrt(144)", AngleUnit::Degrees, 12.0),
            ("ln(e)", AngleUnit::Degrees, 1.0),
            ("log(1000)", AngleUnit::Degrees, 3.0),
            ("log2(1024)", AngleUnit::Degrees, 10.0),
            ("abs(-12.5)", AngleUnit::Degrees, 12.5),
            ("floor(-2.1)", AngleUnit::Degrees, -3.0),
            ("ceil(-2.9)", AngleUnit::Degrees, -2.0),
            ("round(2.6)", AngleUnit::Degrees, 3.0),
            ("int(-2.9)", AngleUnit::Degrees, -2.0),
            ("frac(4.25)", AngleUnit::Degrees, 0.25),
            ("6!", AngleUnit::Degrees, 720.0),
            ("pi", AngleUnit::Degrees, std::f64::consts::PI),
            ("e", AngleUnit::Degrees, std::f64::consts::E),
        ];
        let mut checked = 0;

        for (expression, angle, expected) in direct_cases {
            let actual = evaluate(expression, angle)
                .unwrap_or_else(|error| panic!("{expression} failed: {error}"));
            let tolerance = 1e-10 * expected.abs().max(1.0);
            assert!((actual - expected).abs() <= tolerance, "{expression}");
            checked += 1;
        }

        for index in 0..25 {
            let degrees = index as f64 * 7.0;
            let (angle, input) = match index % 3 {
                0 => (AngleUnit::Degrees, degrees),
                1 => (AngleUnit::Radians, degrees.to_radians()),
                _ => (AngleUnit::Gradians, degrees * 10.0 / 9.0),
            };
            let expression = format!("sin({input})^2+cos({input})^2");
            let actual = evaluate(&expression, angle).unwrap();
            assert!((actual - 1.0).abs() <= 1e-10, "{expression}");
            checked += 1;
        }

        for index in 0..25 {
            let value = index as f64 / 3.0 - 4.25;
            let expression =
                format!("floor({value})+ceil({value})+round({value})+int({value})+frac({value})");
            let expected =
                value.floor() + value.ceil() + value.round() + value.trunc() + value.fract();
            let actual = evaluate(&expression, AngleUnit::Degrees).unwrap();
            assert!((actual - expected).abs() <= 1e-10, "{expression}");
            checked += 1;
        }

        for number in 1..=25 {
            let value = number as f64;
            let expression = format!("{number}^2+{number}^(-1)");
            let expected = value.powi(2) + value.recip();
            let actual = evaluate(&expression, AngleUnit::Degrees).unwrap();
            assert!((actual - expected).abs() <= 1e-10, "{expression}");
            checked += 1;
        }

        assert_eq!(checked, 100);
    }

    #[test]
    fn calculator_percentages() {
        let cases: [(&str, f64); 20] = [
            ("50%", 0.5),
            ("100-50%", 50.0),
            ("100+50%", 150.0),
            ("200+10%", 220.0),
            ("200-10%", 180.0),
            ("200*15%", 30.0),
            ("80/20%", 400.0),
            ("100+10%+10%", 121.0),
            ("100-10%-10%", 81.0),
            ("(10%+5%)", 0.15),
            ("200+(10%+5%)", 230.0),
            ("200+(10%-5%)", 210.0),
            ("100+10%*2", 120.0),
            ("100+2*10%", 100.2),
            ("100+10%/2", 105.0),
            ("200*15%+10%", 33.0),
            ("100+sqrt(25%)", 100.5),
            ("100+(50%)", 150.0),
            ("50%+25%", 0.75),
            ("1,000-2.5%", 975.0),
        ];

        for (expression, expected) in cases {
            let actual = evaluate(expression, AngleUnit::Degrees)
                .unwrap_or_else(|error| panic!("{expression} failed: {error}"));
            let tolerance = 1e-10 * expected.abs().max(1.0);
            assert!(
                (actual - expected).abs() <= tolerance,
                "{expression}: expected {expected}, got {actual}"
            );
        }
    }

    #[test]
    fn typed_expression_matrix() {
        let cases: &[(&str, f64)] = &[
            ("2^2", 4.0),
            ("2^3^2", 512.0),
            ("(2^3)^2", 64.0),
            ("2^-3", 0.125),
            ("-2^2", -4.0),
            ("(-2)^2", 4.0),
            ("9^0.5", 3.0),
            ("4**3", 64.0),
            ("5!", 120.0),
            ("0!", 1.0),
            ("3!+2", 8.0),
            ("50%", 0.5),
            ("100-25%", 75.0),
            ("100+25%", 125.0),
            ("200*12.5%", 25.0),
            ("40/20%", 200.0),
            ("10 mod 3", 1.0),
            ("~5", -6.0),
            ("2*(3+4)", 14.0),
            ("2e", 2.0 * std::f64::consts::E),
            ("2(3+4)", 14.0),
            ("(2+3)(4+1)", 25.0),
            ("2pi", 2.0 * std::f64::consts::PI),
            ("3sqrt(16)", 12.0),
            ("sqrt(81)", 9.0),
            ("√(81)", 9.0),
            ("abs(-12)", 12.0),
            ("floor(2.9)", 2.0),
            ("ceil(2.1)", 3.0),
            ("round(2.49)", 2.0),
            ("round(2.5)", 3.0),
            ("round(-2.5)", -3.0),
            ("trunc(-2.9)", -2.0),
            ("int(4.9)", 4.0),
            ("frac(4.25)", 0.25),
            ("sin(30)", 0.5),
            ("cos(60)", 0.5),
            ("tan(45)", 1.0),
            ("asin(0.5)", 30.0),
            ("ln(e)", 1.0),
            ("log(1000)", 3.0),
            ("exp(1)", std::f64::consts::E),
            ("pi", std::f64::consts::PI),
            ("π*2", std::f64::consts::PI * 2.0),
            ("1e3+5", 1005.0),
            ("2.5e-2", 0.025),
            ("1,234.5+65.5", 1300.0),
            ("9×8", 72.0),
            ("81÷9", 9.0),
            ("12−7", 5.0),
            ("1 + 2 * 3 ^ 2", 19.0),
            ("2+2=", 4.0),
            ("6·7", 42.0),
            ("6⋅7", 42.0),
            ("6∙7", 42.0),
            ("8∕2", 4.0),
            ("8⁄2", 4.0),
            ("3²", 9.0),
            ("2³", 8.0),
            ("4⁻¹", 0.25),
            ("√9", 3.0),
            ("√9+7", 10.0),
            ("2√9", 6.0),
            ("√(9+7)", 4.0),
            ("√√16", 2.0),
            ("√9^2", 9.0),
            ("√0.25", 0.5),
        ];

        for &(expression, expected) in cases {
            let actual = evaluate(expression, AngleUnit::Degrees)
                .unwrap_or_else(|error| panic!("{expression} failed: {error}"));
            let tolerance = 1e-10 * expected.abs().max(1.0);
            assert!(
                (actual - expected).abs() <= tolerance,
                "{expression}: expected {expected}, got {actual}"
            );
        }
    }

    #[test]
    fn extreme_edge_case_matrix_100() {
        let cases: [(&str, Option<f64>); 100] = [
            ("0", Some(0.0)),
            ("-0", Some(0.0)),
            ("--5", Some(5.0)),
            ("++5", Some(5.0)),
            ("+-5", Some(-5.0)),
            ("-(-5)", Some(5.0)),
            ("1+2*3", Some(7.0)),
            ("(1+2)*3", Some(9.0)),
            ("100/10/2", Some(5.0)),
            ("100/(10/2)", Some(20.0)),
            ("7 mod 4", Some(3.0)),
            ("0.1+0.2", Some(0.3)),
            ("1--2", Some(3.0)),
            ("(2+3)(4-1)", Some(15.0)),
            ("2(3)(4)", Some(24.0)),
            ("2^0", Some(1.0)),
            ("0^0", Some(1.0)),
            ("2^-10", Some(1.0 / 1024.0)),
            ("(-2)^3", Some(-8.0)),
            ("-2^4", Some(-16.0)),
            ("2^3^2", Some(512.0)),
            ("16^0.25", Some(2.0)),
            ("4**0.5", Some(2.0)),
            ("√0", Some(0.0)),
            ("√.00000001", Some(0.0001)),
            ("√(2^2+3^2)", Some(13.0_f64.sqrt())),
            ("3√16", Some(12.0)),
            ("√√81", Some(3.0)),
            ("3²+4²", Some(25.0)),
            ("16⁻¹", Some(0.0625)),
            ("0%", Some(0.0)),
            ("100%", Some(1.0)),
            ("100+100%", Some(200.0)),
            ("100-100%", Some(0.0)),
            ("100+200%", Some(300.0)),
            ("100-200%", Some(-100.0)),
            ("100*0%", Some(0.0)),
            ("100/0%", None),
            ("100+10%+10%+10%", Some(133.1)),
            ("100-10%-10%-10%", Some(72.9)),
            ("10%+20%", Some(0.3)),
            ("10%-20%", Some(-0.1)),
            ("0!", Some(1.0)),
            ("10!", Some(3_628_800.0)),
            ("100001!", None),
            ("abs(-0)", Some(0.0)),
            ("abs(-123.456)", Some(123.456)),
            ("floor(-2.1)", Some(-3.0)),
            ("ceil(-2.9)", Some(-2.0)),
            ("round(2.4999)", Some(2.0)),
            ("round(2.5001)", Some(3.0)),
            ("round(-2.5)", Some(-3.0)),
            ("trunc(-2.999)", Some(-2.0)),
            ("frac(-2.25)", Some(-0.25)),
            ("sin(0)", Some(0.0)),
            ("sin(90)", Some(1.0)),
            ("cos(180)", Some(-1.0)),
            ("tan(45)", Some(1.0)),
            ("asin(1)", Some(90.0)),
            ("acos(-1)", Some(180.0)),
            ("atan(1)", Some(45.0)),
            ("ln(1)", Some(0.0)),
            ("log(0.001)", Some(-3.0)),
            ("exp(0)", Some(1.0)),
            ("sqrt(4)²", Some(4.0)),
            ("1e0", Some(1.0)),
            ("1E3", Some(1000.0)),
            ("1e-3", Some(0.001)),
            ("1e+3", Some(1000.0)),
            ("1,000e3", Some(1_000_000.0)),
            ("999,999.999+0.001", Some(1_000_000.0)),
            ("0,000", Some(0.0)),
            ("12,345,678", Some(12_345_678.0)),
            ("12,34", None),
            ("1,,000", None),
            ("1,234.5,678", None),
            ("1.2.3", None),
            ("6·7+8÷4", Some(44.0)),
            ("6⋅7−2", Some(40.0)),
            ("8∕2+8⁄4", Some(6.0)),
            ("2pi", Some(2.0 * std::f64::consts::PI)),
            ("(1+1)pi", Some(2.0 * std::f64::consts::PI)),
            ("2e", Some(2.0 * std::f64::consts::E)),
            ("3sqrt(16)", Some(12.0)),
            ("sin(30)cos(60)", Some(0.25)),
            (" \n\t2 + 3\r ", Some(5.0)),
            ("2+2=", Some(4.0)),
            ("1\u{200b}+\u{200b}2", Some(3.0)),
            ("pi^2", Some(std::f64::consts::PI.powi(2))),
            ("e^ln(2)", Some(2.0)),
            ("√-1", None),
            ("(-1)^0.5", None),
            ("0^-1", None),
            ("ln(0)", None),
            ("ln(-1)", None),
            ("asin(2)", None),
            ("acos(-2)", None),
            ("atanh(1)", None),
            ("sqrt(-4)", None),
            ("1e+", None),
        ];

        for (expression, expected) in cases {
            match expected {
                Some(expected) => {
                    let actual = evaluate(expression, AngleUnit::Degrees)
                        .unwrap_or_else(|error| panic!("{expression} failed: {error}"));
                    let tolerance = 1e-10 * expected.abs().max(1.0);
                    assert!(
                        (actual - expected).abs() <= tolerance,
                        "{expression}: expected {expected}, got {actual}"
                    );
                }
                None => assert!(
                    evaluate(expression, AngleUnit::Degrees).is_err(),
                    "{expression} should fail"
                ),
            }
        }
    }
}
