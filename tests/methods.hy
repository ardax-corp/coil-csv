// Csv::parse / Csv::stringify (same as free functions).
use tests::assert;
use csv::{Csv};

fn row2(string a, string b) -> Vec<string> {
    let r: Vec<string> = Vec::new();
    r.push(a);
    r.push(b);
    return r;
}

fn eq_row(Vec<string> a, Vec<string> b) -> bool {
    if len(a) != len(b) {
        return false;
    }
    let i = 0;
    while i < len(a) {
        if a[i] != b[i] {
            return false;
        }
        i = i + 1;
    }
    return true;
}

test("Csv methods") {
    let rows = match Csv::parse("x,y") {
        Result::Ok(v) => v,
        Result::Err(_) => panic "Csv::parse",
    };
    assert!(eq_row(rows[0], row2("x", "y")), "method parse");
    assert!(Csv::stringify(rows) == "x,y", "method stringify");
}
