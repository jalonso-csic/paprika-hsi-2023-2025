# 06_plsr_nestedcv — PLS-R (nested CV) with modern figures

Runs **nested-CV Partial Least Squares Regression** over multiple preprocessings and task-specific spectral windows, optionally **fusing FX10+FX17** by normalized ID. Exports ranked results, per-variant predictions, and a modern scatter figure per task.

---

## Purpose

* **Outer K-Fold** validation with **inner K-Fold** to select the number of latent variables (optional **1-SE rule**).
* **Preprocessing comparison** (RAW, SNV, MSC, 1st/2nd derivatives, baseline) and **window-restricted** variants per target.
* **Camera fusion** (FX10+FX17) by normalized sample ID (row-order fallback if overlap is low).
* **Modern MATLAB figures** (standard tool tabs) for quick export.

---

## Script

```
code-matlab/06_plsr_nestedcv/
└─ run_plsr_nested.m      % main entry point (function: run_plsr_nested)
```

---

## Inputs

Place these Excel files in the **current working directory** (or add their folder to the MATLAB path):

* `Datos_Preprocesados_FX10.xlsx`
* `Datos_Preprocesados_FX17.xlsx`

**Format expectations (auto-detected):**

* Each **sheet = one spectral group** (columns named with wavelengths in nm).
* The first sheet containing targets defines metadata (*ID*, *Year*, **ASTA_D0**, **ASTA_D3**, **Moisture**).
  Column names are normalized (accents & symbols removed) and matched by keywords used in Spanish source files.

> Preprocessed inputs are archived in Zenodo: **10.5281/zenodo.17539563** (see also **10.5281/zenodo.17523082**).

---

## How to run

1. Open MATLAB and `cd` to `code-matlab/06_plsr_nestedcv/` (or to the folder containing the two Excel inputs).
2. Ensure the two input files are reachable (see **Inputs**).
3. Run:

   ```matlab
   run_plsr_nested
   ```

---

## What it produces

Outputs are saved under **`Results_PLSR/`**:

* `Ranking_<Task>.csv` – sorted model leaderboard
  *(columns: Task, Variant, nBands, RMSE, R2, MAE, Bias)*.
* `Pred_<Task>_<Variant>.csv` – per-sample **Observed/Predicted** table (with ID and Year).
* `Scatter_<Task>.fig` – editable modern figure of Observed vs Predicted.

  * Optional exports (`.pdf`, `.png`, `.tif`, `.eps`) can be enabled in `cfg.savePDF/PNG/TIFF/EPS`.

The console also prints the **Top variant** per task (lowest mean RMSE).

---

## Configuration (edit inside the script)

Key options (block `cfg`):

* `validation` = `'KFold'` *(default)* or `'LOYO'` (leave-one-year-out, requires `Year` in metadata).
* `outerK`, `innerK`, `maxLV`, `useOneSE` – nested CV shape & LV selection.
* `zscoreWithinFold` – standardize features within training folds.
* `useWindowsOnly` – compare **Full vs Windowed** (false) or **Windows only** (true).
* Auto-save switches: `saveFIG`, `savePDF`, `savePNG`, `saveTIFF`, `saveEPS`.

Preprocessing detection is **name-based** (patterns for RAW/SNV/MSC/derivatives/baseline).
Target windows (nm) are defined in `WIN.*`. Task list and preprocessing **combos** are in `Combos.*`.

---

## Default tasks

* `ASTA_D0` (FX10)
* `ASTA_D3` (FX10)
* `Moisture` (FX17)
* `Color_Loss` (FUSION FX10+FX17)

Modify the `tasks` table to add/remove analyses.

---

## Troubleshooting

* **File not found** → Ensure the Excel filenames exactly match and are in the **working dir** (or on the MATLAB path).
* **“No valid predictions produced”** → Not enough valid target values or windows yielded `< 2` bands.
* **Fusion warning (“Low ID overlap; fusing by row order”)** → Expected when sample IDs between FX10 and FX17 do not align.
* **`validation = 'LOYO'`** → Requires a valid `Year` column; otherwise use `'KFold'`.

---

## Related artefacts (cross-reference)

* Supervised full reports (step 04): **10.5281/zenodo.17540888**
* Visualization JPG figures (step 05): **10.5281/zenodo.17541484**

> Please cite the **preprocessed data** Zenodo record(s) when using results from this step.
