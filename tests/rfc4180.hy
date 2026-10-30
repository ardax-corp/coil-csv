// RFC 4180 parse/stringify: quotes, commas in quotes, empty fields, round-trip.
// Test bodies use assert's string error; CSV Results are matched, not `?`.
use tests::assert;
use csv::{parse, stringify, CsvError};

fn must_parse(string s) -> Vec<Vec<string>> {
    return match parse(s) {
        Result::Ok(v) => v,
        Result::Err(_) => panic "parse failed",
    };
}

fn must_stringify(Vec<Vec<string>> rows) -> string {
    return stringify(rows);
}

fn eq_row(Vec<string> a, Vec<string> b) -> bool {
    if a.len() != b.len() {
        return false;
    }
    let i = 0;
    while i < a.len() {
        if a[i] != b[i] {
            return false;
        }
        i = i + 1;
    }
    return true;
}

fn eq_rows(Vec<Vec<string>> a, Vec<Vec<string>> b) -> bool {
    if a.len() != b.len() {
        return false;
    }
    let i = 0;
    while i < a.len() {
        if !eq_row(a[i], b[i]) {
            return false;
        }
        i = i + 1;
    }
    return true;
}

fn row2(string a, string b) -> Vec<string> {
    let r: Vec<string> = Vec::new();
    r.push(a);
    r.push(b);
    return r;
}

fn row3(string a, string b, string c) -> Vec<string> {
    let r: Vec<string> = Vec::new();
    r.push(a);
    r.push(b);
    r.push(c);
    return r;
}

fn is_invalid(Result<Vec<Vec<string>>, CsvError> r) -> bool {
    return match r {
        Result::Ok(_) => false,
        Result::Err(e) => match e {
            CsvError::Invalid { line, column, message } => line >= 1 && column >= 1 && message != "",
            default => false,
        },
    };
}

test("simple comma fields") {
    let rows = must_parse("a,b,c");
    assert!(rows.len() == 1, "one record");
    assert!(eq_row(rows[0], row3("a", "b", "c")), "a,b,c");
}

test("quoted field") {
    let rows = must_parse("\"hello\"");
    assert!(rows.len() == 1 && rows[0].len() == 1, "one field");
    assert!(rows[0][0] == "hello", "quoted hello");
}

test("comma inside quotes") {
    let rows = must_parse("\"a,b\",c");
    assert!(eq_row(rows[0], row2("a,b", "c")), "comma in quotes");
}

test("escaped quotes") {
    let rows = must_parse("\"a\"\"b\"");
    assert!(rows.len() == 1 && rows[0][0] == "a\"b", "doubled quote");
}

test("empty fields") {
    let rows = must_parse("a,,c");
    assert!(eq_row(rows[0], row3("a", "", "c")), "middle empty");
    let ends = must_parse(",b,");
    assert!(eq_row(ends[0], row3("", "b", "")), "edge empty");
}

test("lf and crlf records") {
    let lf = must_parse("a,b\nc,d");
    assert!(lf.len() == 2, "lf two records");
    assert!(eq_row(lf[0], row2("a", "b")) && eq_row(lf[1], row2("c", "d")), "lf rows");
    let crlf = must_parse("a,b\r\nc,d");
    assert!(crlf.len() == 2, "crlf two records");
    assert!(eq_row(crlf[0], row2("a", "b")) && eq_row(crlf[1], row2("c", "d")), "crlf rows");
}

test("quoted newline in field") {
    let rows = must_parse("\"a\nb\",c");
    assert!(rows.len() == 1, "one record");
    assert!(eq_row(rows[0], row2("a\nb", "c")), "newline in quotes");
}

test("empty input") {
    let rows = must_parse("");
    assert!(rows.len() == 0, "no records");
}

test("trailing newline does not add a row") {
    let rows = must_parse("a,b\n");
    assert!(rows.len() == 1 && eq_row(rows[0], row2("a", "b")), "one record");
}

test("round-trip quotes commas empty") {
    let src: Vec<Vec<string>> = Vec::new();
    src.push(row3("a", "b,c", ""));
    let q: Vec<string> = Vec::new();
    q.push("say \"hi\"");
    q.push("x");
    src.push(q);
    let encoded = must_stringify(src);
    let back = must_parse(encoded);
    assert!(eq_rows(src, back), "parse(stringify) rows");
}

test("stringify quotes comma and quote") {
    let rows: Vec<Vec<string>> = Vec::new();
    rows.push(row2("a,b", "c\"d"));
    let s = must_stringify(rows);
    assert!(s == "\"a,b\",\"c\"\"d\"", "quoted encode");
}

test("unterminated quote is CsvError") {
    assert!(is_invalid(parse("\"abc")), "unterminated");
}

test("unescaped quote is CsvError") {
    assert!(is_invalid(parse("a\"b")), "bare quote");
}

test("error is not panic") {
    let r = parse("\"open");
    assert!(match r {
        Result::Ok(_) => false,
        Result::Err(e) => match e {
            CsvError::Invalid { line, column, message } => line == 1 && column == 1 && message != "",
            default => false,
        },
    }, "Invalid at 1,1");
}

fn error_at(string s) -> (int, int) {
    return match parse(s) {
        Result::Ok(_) => (0, 0),
        Result::Err(e) => match e {
            CsvError::Invalid { line, column, message } => (line, column),
            default => (0, 0),
        },
    };
}

test("error position after a multi-line quoted field") {
    let (l1, c1) = error_at("\"a\nbc\",x\"y");
    assert!(l1 == 2 && c1 == 6, "quote after a two-line field at 2,6");
    let (l2, c2) = error_at("a,b\r\n\"q\nq\",z\"");
    assert!(l2 == 3 && c2 == 5, "quote after CRLF and a two-line field at 3,5");
    let (l3, c3) = error_at("\"a\n\nb\r\ncc\"\"d\",e\nf,\"unterminated\nx");
    assert!(l3 == 5 && c3 == 3, "unterminated field reported where it starts");
}
