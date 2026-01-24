# Drift Analysis: simple_lsp

Generated: 2026-01-23
Method: Research docs (7S-01 to 7S-07) vs ECF + implementation

## Research Documentation

| Document | Present |
|----------|---------|
| 7S-01-SCOPE | Y |
| 7S-02-STANDARDS | Y |
| 7S-03-SOLUTIONS | Y |
| 7S-04-SIMPLE-STAR | Y |
| 7S-05-SECURITY | Y |
| 7S-06-SIZING | Y |
| 7S-07-RECOMMENDATION | Y |

## Implementation Metrics

| Metric | Value |
|--------|-------|
| Eiffel files (.e) | 24 |
| Facade class | SIMPLE_LSP |
| Features marked Complete | 0
0 |
| Features marked Partial | 0
0 |

## Dependency Drift

### Claimed in 7S-04 (Research)
- simple_doc
- simple_json
- simple_oracle
- simple_sql
- simple_test
- simple_ucf

### Actual in ECF
- simple_datetime
- simple_eiffel_parser
- simple_file
- simple_json
- simple_lsp_exe
- simple_lsp_tests
- simple_process
- simple_sql
- simple_testing
- simple_toml
- simple_ucf
- simple_xml

### Drift
Missing from ECF: simple_doc simple_oracle simple_test | In ECF not documented: simple_datetime simple_eiffel_parser simple_file simple_lsp_exe simple_lsp_tests simple_process simple_testing simple_toml simple_xml

## Summary

| Category | Status |
|----------|--------|
| Research docs | 7/7 |
| Dependency drift | FOUND |
| **Overall Drift** | **MEDIUM** |

## Conclusion

**simple_lsp has medium drift.** Research docs should be updated to match implementation.
