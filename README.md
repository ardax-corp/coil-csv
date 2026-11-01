# coil-csv

RFC 4180 CSV for [coil](https://github.com/ardax-corp/coil-lang), written in plain Coil (no native library, no FFI). The package name is `csv`: `use csv::{parse, stringify, Csv, CsvError}`.

Rows are `Vec<Vec<string>>`: one `Vec<string>` of fields per record.

## Example

```coil
use csv::{parse, stringify, CsvError};
use io::sync::{println};
use string::{format};

fn main() {
    let text = "name,qty\napple,3\n\"pear, green\",5\n";
    let rows = match parse(text) {
        Result::Ok(rows) => rows,
        Result::Err(e) => match e {
            CsvError::Invalid { line, column, message } => panic format("line %i, column %i: %s", line, column, message),
            CsvError::Utf8 { line, column } => panic format("bad UTF-8 at line %i, column %i", line, column),
        },
    };
    for row in rows {
        println(format("%s: %s", row[0], row[1]))?;
    }

    rows.push(["plum", "2"]);
    println(stringify(rows))?;
}
```

```bash
coil --root ../coil-stdlib/src --root ../coil-csv/src main.coil
```

## API

| Item | Role |
|------|------|
| `parse(string)` | Decode CSV text into rows. Returns `Result<Vec<Vec<string>>, CsvError>` |
| `stringify(Vec<Vec<string>>)` | Encode rows as CSV text (`\r\n` between records, quotes only fields that need it) |
| `Csv::parse` / `Csv::stringify` | The same two functions as static methods |
| `CsvError` | `Invalid { line, column, message }` or `Utf8 { line, column }`; 1-based, `column` in bytes |

`parse` reads comma-separated fields, `\n` or `\r\n` records, quoted fields and `""` escapes. One trailing line break is ignored. Rows may differ in length, and there is no header handling: the header is `rows[0]`. Bad input returns a `CsvError`, never a panic.

Every public item has `///` docs with examples in [`src/csv.coil`](src/csv.coil).

## Layout

| Path | Role |
|------|------|
| `src/csv.coil` | The whole package: `parse`, `stringify`, `Csv`, `CsvError` |
| `tests/` | `coil test` suites (RFC 4180 cases, method spellings) |
| `coil.toml` | spool manifest (`[package] name = "csv"`); coil itself does not read it |

## Use it

```bash
spool add csv --git https://github.com/ardax-corp/coil-csv.git --rev <commit SHA>
```

There are no tags yet, so pin a commit with `--rev`. Without spool, clone this repo next to your project and pass `--root ../coil-csv/src` to `coil`. See [docs/consume.md](docs/consume.md).

## Test

```bash
coil test --root ../coil-stdlib/src          # tests/
coil test --root ../coil-stdlib/src src      # doc examples
```

## License

MIT. See [LICENSE](LICENSE).
