# coil-csv

Userland RFC 4180 CSV for [coil](https://github.com/ardax-corp/coil-lang). Package name is `csv`, so `use csv::{parse, stringify, Csv, CsvError}` resolves here.

This repo is **private**. There is no native library and no `[ffi]` / dload.

## API

```coil
use csv::{parse, stringify, CsvError};

let rows = parse("a,\"b,c\"\n1,2")?;
let text = stringify(rows);
```

`parse` is comma-separated records with quoted fields and `""` escapes. `stringify` emits `\r\n` between records and quotes fields that need it. Bad input returns `CsvError`, not a panic.

| Function | Role |
|----------|------|
| `parse` | RFC 4180 decode (`string` → `Vec<Vec<string>>`) |
| `stringify` | RFC 4180 encode |
| `Csv::parse` / `Csv::stringify` | Same, as methods |

## Layout

| Path | Role |
|------|------|
| `src/csv.hy` | `Csv`, `CsvError`, parse/stringify |
| `coil.toml` | `[package] name = "csv"` so `use csv::{…}` resolves |

## Consume

Sibling checkout, or a git dep plus `coil.lock` pin. See [docs/consume.md](docs/consume.md).

```toml
[dependencies]
csv = { git = "https://github.com/ardax-corp/coil-csv.git" }
```

`{ git }` is the parseable form. `version` is optional schema, not a tag. The pin is `coil.lock` `rev` + `content_hash`. The compiler does not follow path deps; put `../coil-csv/src` on `[module] roots`.

## License

MIT. See [LICENSE](LICENSE).
