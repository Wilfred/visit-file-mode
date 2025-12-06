# visit-file-mode

visit-file-mode is an Emacs minor mode that allows you to jump to a
file based on a path, line and column.

For example, given a buffer containing an OCaml stack trace:

```
Raised at Stdlib__List.assoc in file "src/list.ml", line 191, characters 10-25
```

or a Rust stack trace:

```
   9: garden::main
             at ./src/main.rs:473:13
  10: core::ops::function::FnOnce::call_once
             at /home/wilfred/.rustup/toolchains/nightly-x86_64-unknown-linux-gnu/lib/rustlib/src/rust/library/core/src/ops/function.rs:250:5
```

We can visit this file (list.ml, function.rs) on this exact line and
column. If the path is relative, we open the file relative to
`default-directory`.

## UI Features

When the minor mode is active, occurrences in the buffer of patterns
that visit-file-mode understands are highlighted.
