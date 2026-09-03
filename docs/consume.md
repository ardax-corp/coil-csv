# Consuming coil-csv

This package is `csv`. `use csv::{parse, stringify, Csv, CsvError}` resolves from `src/csv.hy`. This repo is **private** (`https://github.com/ardax-corp/coil-csv.git`); clone with credentials that can read it. There is no native/FFI dep.

Coil-to-Coil deps will be spool-owned once a public `spool` CLI exists. Until then `{ git }` parses and the pin is `coil.lock` `rev` + `content_hash`.

## Sibling checkout

Clone this repo next to your project. In the consumer `coil.toml`:

```toml
[module]
roots = ["./src", "../coil-csv/src"]
```

`roots` is what loads `src/csv.hy`. The compiler does not follow path deps for discovery.

## Git dep and coil.lock

`{ git }` is the parseable form. `version` is optional schema, not a tag. `rev` on the dep is stored only. Do not run `spool add`. There is no public spool CLI.

```toml
[dependencies]
csv = { git = "https://github.com/ardax-corp/coil-csv.git" }

[module]
roots = ["./src", "./.spool/deps/csv/src"]
```

This repo has no tags. The pin is `coil.lock` `rev` + `content_hash`. Omit `tag`. Use sibling checkout until spool materializes `.spool/deps`. The compiler does not read `coil.lock` and does not inject roots.

```
# spool lockfile v1
[[package]]
name = 'csv'
git = 'https://github.com/ardax-corp/coil-csv.git'
rev = '<commit SHA>'
content_hash = '<tree SHA>'
```

`rev` is the commit. `content_hash` is that commit's git tree (`git rev-parse 'HEAD^{tree}'`). Replace both when you move the pin.

## Call parse / stringify

Signatures are in [`src/csv.hy`](../src/csv.hy). Call patterns are in [`tests/rfc4180.hy`](../tests/rfc4180.hy).

```coil
use csv::{parse, stringify, Csv, CsvError};

let rows = parse("a,\"b,c\"\n1,2")?;
let text = stringify(rows);
let also = Csv::parse("x,y")?;
```

`parse` takes `string` and returns `Result<Vec<Vec<string>>, CsvError>`. `stringify` takes `Vec<Vec<string>>` and returns `string` (infallible for `string` fields). Records use `\n` or `\r\n`. Fields use comma; quoted fields and `""` escapes follow RFC 4180.

There is no header/`parse_maps` helper. First-row-as-keys would need HashMap or generic methods; keep keys in the first `Vec<string>` of the parse result.

### CsvError

```coil
enum CsvError {
    Invalid { line: int, column: int, message: string },
    Utf8 { line: int, column: int },
}
```

Malformed input returns `CsvError`, not a panic.

```coil
match parse("\"open") {
    Result::Ok(_) => false,
    Result::Err(e) => match e {
        CsvError::Invalid { line, column, message } => line >= 1 && column >= 1 && message != "",
        default => false,
    },
}
```
