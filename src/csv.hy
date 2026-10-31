// Package root. RFC 4180 CSV (comma, quoted fields, `""` escapes, `\n` / `\r\n`).
// No native, no dload, no FFI. Rows are `Vec<Vec<string>>`.
use string::{from_bytes, to_bytes};

/// Why `parse` rejected its input.
///
/// `line` and `column` are 1-based. `column` counts bytes from the start of the
/// line, not characters, so a field after multi-byte text sits further right
/// than it looks.
///
/// # Examples
///
/// ```
/// use csv::{parse, CsvError};
/// # use tests::assert;
/// let ok = match parse("a,b\n\"open") {
///     Result::Ok(_) => false,
///     Result::Err(e) => match e {
///         CsvError::Invalid { line, column, message } => line == 2 && column == 1 && message == "unterminated quoted field",
///         default => false,
///     },
/// };
/// assert!(ok);
/// ```
enum CsvError {
    /// Malformed CSV: an unterminated quoted field, a quote inside an unquoted
    /// field, or text after a closing quote. `message` says which.
    Invalid { line: int, column: int, message: string },
    /// A field whose bytes are not valid UTF-8, at the field's first byte.
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
    while i < b.len() {
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

/// The RFC 4180 codec, as static methods.
///
/// `Csv::parse` and `Csv::stringify` are the same functions as the free
/// `parse` and `stringify`; use whichever reads better. There is no instance to
/// create.
///
/// # Examples
///
/// ```
/// use csv::{Csv};
/// # use tests::assert;
/// let rows = Csv::parse("x,y").unwrap_or(Vec::new());
/// assert!(rows.len() == 1 && rows[0][1] == "y");
/// assert!(Csv::stringify(rows) == "x,y");
/// ```
class Csv {
    _unused: int,
}

impl Parser {
    pub static fn new(Vec<byte> bytes) -> Parser {
        return new Parser(bytes, 0, 1, 1);
    }

    pub fn at_end() -> bool {
        return self.i >= self.bytes.len();
    }

    fn bump() {
        if self.i >= self.bytes.len() {
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

    // Coil `&&` / `||` evaluate both sides; never pair `at_end` with `cur()` in one expr.
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

    // Moves the cursor to `j` (at most the input's end), keeping `line` and
    // `col` as a `bump` per byte would.
    fn advance_to(int j) {
        let b = self.bytes;
        let i = self.i;
        let lines = 0;
        let last = -1;
        while i < j {
            if b[i] == "\n" {
                lines = lines + 1;
                last = i;
            }
            i = i + 1;
        }
        if lines > 0 {
            self.line = self.line + lines;
            self.col = j - last;
        } else {
            self.col = self.col + (j - self.i);
        }
        self.i = j;
    }

    fn parse_unquoted() -> Result<string, CsvError> {
        let start_line = self.line;
        let start_col = self.col;
        let b = self.bytes;
        let start = self.i;
        let out: Vec<byte> = Vec::new();
        let i = start;
        while i < b.len() {
            let c = b[i];
            if c == "," || c == "\n" || c == "\r" || c == "\"" {
                break;
            }
            out.push(c);
            i = i + 1;
        }
        self.advance_to(i);
        if i < b.len() {
            if b[i] == "\"" {
                raise invalid(self.line, self.col, "unescaped quote in unquoted field");
            }
        }
        return bytes_to_s(out, start_line, start_col)?;
    }

    fn parse_quoted() -> Result<string, CsvError> {
        let start_line = self.line;
        let start_col = self.col;
        self.bump();
        let b = self.bytes;
        let out: Vec<byte> = Vec::new();
        while true {
            let i = self.i;
            while i < b.len() {
                let c = b[i];
                if c == "\"" {
                    break;
                }
                out.push(c);
                i = i + 1;
            }
            self.advance_to(i);
            if self.at_end() {
                raise invalid(start_line, start_col, "unterminated quoted field");
            }
            self.bump();
            if self.peek_eq("\"") {
                out.push("\"" as byte);
                self.bump();
                continue;
            }
            break;
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
    while i < b.len() {
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
    while i < b.len() {
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
    /// Parses RFC 4180 CSV text into rows of fields. Same as the free `parse`.
    ///
    /// See `parse` for the accepted syntax and the errors.
    ///
    /// # Examples
    ///
    /// ```
    /// use csv::{Csv};
    /// # use tests::assert;
    /// let rows = Csv::parse("name,qty\r\napple,3\r\n").unwrap_or(Vec::new());
    /// assert!(rows.len() == 2);
    /// assert!(rows[1][0] == "apple" && rows[1][1] == "3");
    /// ```
    pub static fn parse(string s) -> Result<Vec<Vec<string>>, CsvError> {
        let p = Parser::new(to_bytes(s));
        return p.parse_all()?;
    }

    /// Encodes rows as RFC 4180 CSV text. Same as the free `stringify`.
    ///
    /// See `stringify` for the quoting rules.
    ///
    /// # Examples
    ///
    /// ```
    /// use csv::{Csv};
    /// # use tests::assert;
    /// let rows: Vec<Vec<string>> = [["a", "b"], ["1", "2"]];
    /// assert!(Csv::stringify(rows) == "a,b\r\n1,2");
    /// ```
    pub static fn stringify(Vec<Vec<string>> rows) -> string {
        let out: Vec<byte> = Vec::new();
        let r = 0;
        while r < rows.len() {
            if r > 0 {
                out.push("\r" as byte);
                out.push("\n" as byte);
            }
            let row = rows[r];
            let c = 0;
            while c < row.len() {
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

/// Parses RFC 4180 CSV text into rows of fields.
///
/// Fields are separated by `,` and records by `\n` or `\r\n` (a lone `\r`
/// also ends a record). A field wrapped in `"` may hold commas, line breaks and
/// `""` (one literal quote). One trailing line break is ignored, empty input
/// gives no rows, and an empty line in the middle is a row with one empty
/// field. Rows may have different lengths; nothing checks them against the
/// first row, and there is no header handling (the header is just `rows[0]`).
///
/// Returns `CsvError::Invalid` for an unterminated quoted field, a `"` inside
/// an unquoted field, or anything but `,` or a line break after a closing
/// quote. It never panics on bad input.
///
/// # Examples
///
/// ```
/// use csv::{parse};
/// # use tests::assert;
/// let rows = parse("name,note\nada,\"likes \"\"math\"\", a lot\"\n").unwrap_or(Vec::new());
/// assert!(rows.len() == 2);
/// assert!(rows[0][0] == "name");
/// assert!(rows[1][1] == "likes \"math\", a lot");
///
/// assert!(parse("").is_ok());
/// assert!(parse("a\"b").is_err());
/// ```
fn parse(string s) -> Result<Vec<Vec<string>>, CsvError> {
    return Csv::parse(s)?;
}

/// Encodes rows as RFC 4180 CSV text.
///
/// Fields are joined with `,` and records with `\r\n`, with no line break
/// after the last record. A field that holds `,`, `"`, `\r` or `\n` is wrapped
/// in quotes, with each `"` doubled; other fields are written as they are.
/// `parse(stringify(rows))` gives `rows` back, except that a single row with
/// one empty field encodes to `""` and parses back to no rows.
///
/// # Examples
///
/// ```
/// use csv::{parse, stringify};
/// # use tests::assert;
/// let rows: Vec<Vec<string>> = [["id", "text"], ["1", "a, \"b\""]];
/// let text = stringify(rows);
/// assert!(text == "id,text\r\n1,\"a, \"\"b\"\"\"");
/// let back = parse(text).unwrap_or(Vec::new());
/// assert!(back[1][1] == "a, \"b\"");
/// ```
fn stringify(Vec<Vec<string>> rows) -> string {
    return Csv::stringify(rows);
}
