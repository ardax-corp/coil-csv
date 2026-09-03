// Package root. RFC 4180 CSV (comma, quoted fields, `""` escapes, `\n` / `\r\n`).
// No native, no dload, no FFI. Rows are `Vec<Vec<string>>`.
use string::{from_bytes, to_bytes};

/// Parse/stringify failure. `line` and `column` are 1-based (column counts bytes in the line).
enum CsvError {
    Invalid { line: int, column: int, message: string },
    Utf8 { line: int, column: int },
}

fn invalid(int line, int column, string message) -> CsvError {
    return CsvError::Invalid { line: line, column: column, message: message };
}

fn utf8_err(int line, int column) -> CsvError {
    return CsvError::Utf8 { line: line, column: column };
}

fn bytes_to_s(Vec<byte> b, int line, int column) -> Result<string, CsvError> {
    return match from_bytes(b) {
        Result::Ok(s) => s,
        Result::Err(_) => raise utf8_err(line, column),
    };
}

fn append_bytes(Vec<byte> out, Vec<byte> b) {
    let i = 0;
    while i < len(b) {
        out.push(b[i]);
        i = i + 1;
    }
}

class Parser {
    bytes: Vec<byte>,
    i: int,
    pub line: int,
    pub col: int,
}

/// RFC 4180 codec. `parse` / `stringify` are also free functions.
class Csv {
    _unused: int,
}

impl Parser {
    pub static fn new(Vec<byte> bytes) -> Parser {
        return new Parser(bytes, 0, 1, 1);
    }

    pub fn at_end() -> bool {
        return self.i >= len(self.bytes);
    }

    fn bump() {
        if self.i >= len(self.bytes) {
            return;
        }
        let c = self.bytes[self.i];
        self.i = self.i + 1;
        if c == "\n" {
            self.line = self.line + 1;
            self.col = 1;
        } else {
            if c == "\r" {
                self.col = self.col + 1;
            } else {
                self.col = self.col + 1;
            }
        }
    }

    fn cur() -> byte {
        return self.bytes[self.i];
    }

    /// Coil `&&` / `||` evaluate both sides; never pair `at_end` with `cur()` in one expr.
    fn peek_eq(byte c) -> bool {
        if self.at_end() {
            return false;
        }
        return self.cur() == c;
    }

    fn at_record_end() -> bool {
        if self.peek_eq("\n") {
            return true;
        }
        return self.peek_eq("\r");
    }

    fn consume_record_end() -> Result<(), CsvError> {
        if self.peek_eq("\r") {
            self.bump();
            if self.peek_eq("\n") {
                self.bump();
            }
            return ();
        }
        if self.peek_eq("\n") {
            self.bump();
            return ();
        }
        raise invalid(self.line, self.col, "expected record separator");
    }

    fn parse_unquoted() -> Result<string, CsvError> {
        let start_line = self.line;
        let start_col = self.col;
        let out: Vec<byte> = Vec::new();
        while !self.at_end() {
            let c = self.cur();
            if c == "," {
                break;
            }
            if c == "\n" {
                break;
            }
            if c == "\r" {
                break;
            }
            if c == "\"" {
                raise invalid(self.line, self.col, "unescaped quote in unquoted field");
            }
            out.push(c);
            self.bump();
        }
        return bytes_to_s(out, start_line, start_col)?;
    }

    fn parse_quoted() -> Result<string, CsvError> {
        let start_line = self.line;
        let start_col = self.col;
        self.bump();
        let out: Vec<byte> = Vec::new();
        while true {
            if self.at_end() {
                raise invalid(start_line, start_col, "unterminated quoted field");
            }
            let c = self.cur();
            if c == "\"" {
                self.bump();
                if self.peek_eq("\"") {
                    out.push("\"" as byte);
                    self.bump();
                    continue;
                }
                break;
            }
            out.push(c);
            self.bump();
        }
        return bytes_to_s(out, start_line, start_col)?;
    }

    fn parse_field() -> Result<string, CsvError> {
        if self.peek_eq("\"") {
            return self.parse_quoted()?;
        }
        return self.parse_unquoted()?;
    }

    fn parse_record() -> Result<Vec<string>, CsvError> {
        let row: Vec<string> = Vec::new();
        row.push(self.parse_field()?);
        while self.peek_eq(",") {
            self.bump();
            row.push(self.parse_field()?);
        }
        return row;
    }

    pub fn parse_all() -> Result<Vec<Vec<string>>, CsvError> {
        let rows: Vec<Vec<string>> = Vec::new();
        if self.at_end() {
            return rows;
        }
        while true {
            rows.push(self.parse_record()?);
            if self.at_end() {
                break;
            }
            self.consume_record_end()?;
            if self.at_end() {
                break;
            }
        }
        return rows;
    }
}

fn field_needs_quote(string s) -> bool {
    let b = to_bytes(s);
    let i = 0;
    while i < len(b) {
        let c = b[i];
        if c == "," {
            return true;
        }
        if c == "\"" {
            return true;
        }
        if c == "\n" {
            return true;
        }
        if c == "\r" {
            return true;
        }
        i = i + 1;
    }
    return false;
}

fn append_field(Vec<byte> out, string s) {
    let b = to_bytes(s);
    if !field_needs_quote(s) {
        append_bytes(out, b);
        return;
    }
    out.push("\"" as byte);
    let i = 0;
    while i < len(b) {
        let c = b[i];
        if c == "\"" {
            out.push("\"" as byte);
            out.push("\"" as byte);
        } else {
            out.push(c);
        }
        i = i + 1;
    }
    out.push("\"" as byte);
}

impl Csv {
    /// Parse RFC 4180 CSV. Comma separator; quoted fields; `""` escape; `\n` or `\r\n` records.
    pub static fn parse(string s) -> Result<Vec<Vec<string>>, CsvError> {
        let p = Parser::new(to_bytes(s));
        return p.parse_all()?;
    }

    /// Encode rows as RFC 4180 CSV (`\r\n` between records). Quotes fields that need it.
    pub static fn stringify(Vec<Vec<string>> rows) -> string {
        let out: Vec<byte> = Vec::new();
        let r = 0;
        while r < len(rows) {
            if r > 0 {
                out.push("\r" as byte);
                out.push("\n" as byte);
            }
            let row = rows[r];
            let c = 0;
            while c < len(row) {
                if c > 0 {
                    out.push("," as byte);
                }
                append_field(out, row[c]);
                c = c + 1;
            }
            r = r + 1;
        }
        return match from_bytes(out) {
            Result::Ok(s) => s,
            Result::Err(_) => panic "csv stringify utf8",
        };
    }
}

/// Parse RFC 4180 CSV text into rows of fields.
fn parse(string s) -> Result<Vec<Vec<string>>, CsvError> {
    return Csv::parse(s)?;
}

/// Encode rows as RFC 4180 CSV text. Infallible for `string` fields.
fn stringify(Vec<Vec<string>> rows) -> string {
    return Csv::stringify(rows);
}
