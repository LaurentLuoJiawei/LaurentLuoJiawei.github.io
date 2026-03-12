# Inspecting Data-Juicer (dj-analyze) Configuration & CLI Parameters

This page explains how to quickly find which configuration keys and CLI parameters
are available in the [Data-Juicer](https://github.com/modelscope/data-juicer) project,
with a focus on the memory-protection / batch-control options that affect processing
throughput and safety.

---

## 1. Why this matters

When running `dj-analyze` (or the `python tools/analyze.py` entry-point) against a
large dataset you can hit out-of-memory errors unless you tune the right parameters.
The relevant knobs are scattered across several source files; the sections below show
you exactly where to look.

---

## 2. Key parameters to search for

| Parameter | Purpose |
|---|---|
| `batch_size` | Number of samples processed per batch by operators |
| `read_batch_size` | Number of rows read from disk at a time |
| `block_size` | Arrow / Parquet block size used when reading files |
| `target_max_block_size` | Maximum Arrow block size target (huggingface `datasets`) |
| `prefetch_batches` | How many batches to pre-fetch into memory |
| `streaming` | Enable HuggingFace `datasets` streaming mode (avoids full load) |
| `streaming_read` | Alias / variant used in some Data-Juicer YAML configs |

---

## 3. GitHub code search (no local clone needed)

You can use GitHub's built-in search to inspect the current source without cloning:

### 3a. Search the whole repo

Open the following URLs in your browser (replace the keyword as needed):

```
https://github.com/search?q=repo%3Amodelscope%2Fdata-juicer+batch_size&type=code
https://github.com/search?q=repo%3Amodelscope%2Fdata-juicer+read_batch_size&type=code
https://github.com/search?q=repo%3Amodelscope%2Fdata-juicer+block_size&type=code
https://github.com/search?q=repo%3Amodelscope%2Fdata-juicer+target_max_block_size&type=code
https://github.com/search?q=repo%3Amodelscope%2Fdata-juicer+prefetch_batches&type=code
https://github.com/search?q=repo%3Amodelscope%2Fdata-juicer+streaming&type=code
```

### 3b. Direct links to likely source files

| File | What it contains |
|---|---|
| [`data_juicer/config/config.py`](https://github.com/modelscope/data-juicer/blob/main/data_juicer/config/config.py) | Top-level YAML / CLI argument definitions |
| [`data_juicer/core/executor.py`](https://github.com/modelscope/data-juicer/blob/main/data_juicer/core/executor.py) | Batch execution loop, `batch_size` usage |
| [`data_juicer/core/analyzer.py`](https://github.com/modelscope/data-juicer/blob/main/data_juicer/core/analyzer.py) | `dj-analyze` entry logic |
| [`data_juicer/utils/dataset_utils.py`](https://github.com/modelscope/data-juicer/blob/main/data_juicer/utils/dataset_utils.py) | Dataset loading helpers, `streaming`, `block_size` |
| [`configs/`](https://github.com/modelscope/data-juicer/tree/main/configs) | Example YAML configs with commented parameter listings |

---

## 4. Local grep commands (for a checked-out clone)

If you have cloned `https://github.com/modelscope/data-juicer` locally, run the
following commands from the repo root.

### 4a. Find every occurrence of the memory-protection parameters

```bash
grep -rn \
  -e 'batch_size' \
  -e 'read_batch_size' \
  -e 'block_size' \
  -e 'target_max_block_size' \
  -e 'prefetch_batches' \
  -e 'streaming' \
  --include='*.py' \
  --include='*.yaml' \
  --include='*.yml' \
  .
```

### 4b. Find only CLI / argparse definitions

```bash
grep -rn \
  -e 'add_argument.*batch_size' \
  -e 'add_argument.*block_size' \
  -e 'add_argument.*streaming' \
  -e "Field\(.*batch_size" \
  -e "Field\(.*block_size" \
  -e "Field\(.*streaming" \
  --include='*.py' \
  .
```

### 4c. Find only YAML config keys

```bash
grep -rn \
  -e '^\s*batch_size:' \
  -e '^\s*read_batch_size:' \
  -e '^\s*block_size:' \
  -e '^\s*target_max_block_size:' \
  -e '^\s*prefetch_batches:' \
  -e '^\s*streaming:' \
  -e '^\s*streaming_read:' \
  --include='*.yaml' \
  --include='*.yml' \
  .
```

### 4d. Automated script

A ready-to-run shell script is provided in [`scripts/search_dj_params.sh`](../scripts/search_dj_params.sh).
Point it at your local clone and it will print all matches with context:

```bash
bash scripts/search_dj_params.sh /path/to/data-juicer
```

---

## 5. Understanding where each parameter is used

### `batch_size`

- Defined in `data_juicer/config/config.py` as a top-level field (e.g. `batch_size: 1000`).
- Passed to `datasets.Dataset.map(..., batch_size=batch_size)` in operator wrappers.
- Reducing this value lowers peak memory at the cost of throughput.

### `read_batch_size` / `block_size`

- Used in dataset loading utilities (`dataset_utils.py`).
- Controls how many rows are loaded from Arrow/Parquet files in one shot.
- `block_size` is a `datasets.load_dataset` argument and maps to
  `datasets.builder.DEFAULT_MAX_BATCH_SIZE`.

### `target_max_block_size`

- A HuggingFace `datasets` internal constant that can be overridden via
  environment variable `HF_DATASETS_MAX_BLOCK_SIZE` (in bytes).
- Alternatively some Data-Juicer versions expose this in their config directly.

### `prefetch_batches`

- Controls the number of batches pre-fetched into RAM during streaming.
- Set to `0` or `1` when memory is very constrained.

### `streaming` / `streaming_read`

- When `streaming: true` is set in the YAML config (or `--streaming` on the CLI),
  Data-Juicer uses `datasets` streaming mode, which never loads the full dataset
  into memory.
- `streaming_read` is a variant key used in some operator-level configs to enable
  streaming at a finer granularity.

---

## 6. Example minimal YAML config with memory-protection settings

```yaml
# dj_analyze_safe.yaml
project_name: my_project
dataset_path: /data/my_dataset.jsonl

# --- Memory protection ---
batch_size: 200            # lower = less peak RAM
read_batch_size: 500
streaming: false           # set true to never load full dataset

# --- Optional advanced knobs ---
# target_max_block_size: 20971520   # 20 MB Arrow block cap
# prefetch_batches: 2

process:
  - language_id_score_filter:
      lang: en
      min_score: 0.8
```

Run with:

```bash
dj-analyze --config dj_analyze_safe.yaml
# or equivalently:
python tools/analyze.py --config dj_analyze_safe.yaml
```

---

## 7. References

- [Data-Juicer GitHub repository](https://github.com/modelscope/data-juicer)
- [Data-Juicer documentation](https://github.com/modelscope/data-juicer/blob/main/README.md)
- [HuggingFace `datasets` — memory mapping & streaming](https://huggingface.co/docs/datasets/en/about_mapstyle_vs_iterable)
- [HuggingFace `datasets` — batch processing](https://huggingface.co/docs/datasets/en/process#batch-processing)
