# Consuming coil-csv

This package is `csv`. `use csv::{parse, stringify, Csv, CsvError}` resolves from `src/csv.hy`. This repo is **private** (`https://github.com/ardax-corp/coil-csv.git`); clone with credentials that can read it. There is no native/FFI dep.

## Depend on it

With [spool](https://github.com/ardax-corp/spool):

```bash
spool add csv --git https://github.com/ardax-corp/coil-csv.git --rev <commit SHA>
```

This repo has no tags, so pin a commit with `--rev`. spool records the dep in `coil.toml`, writes `coil.lock` (`rev` + `content_hash`), links `.spool/deps/csv`, and passes `--root` for it and coil-stdlib to `coil` on `spool build` / `run` / `test`.

Without spool, clone this repo next to your project and pass the roots yourself. coil reads no `coil.toml` and no `coil.lock`.

```bash
coil --root ../coil-csv/src main.hy
```

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
