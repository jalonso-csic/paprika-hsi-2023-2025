# FX10 Supervised HSI (Nested CV, PLS-DA/SVM, VIP)

Supervised hyperspectral analysis for **Specim FX10 (400–1000 nm)** with **repeated nested cross-validation**.  
Models: **PLS-DA** (with/without VIP), **SVM** (linear/RBF, VIP), optional **PCA+SVM** baseline.  
Exports **Excel reports** and **figures** (balanced accuracy boxplots, VIP stability).

> **Note:** Only comments and user-facing strings are in English. **No code logic was changed** from the validated Spanish versions.

---

## Contents

Main orchestrator:
- `fx10_supervised_hsi_nestedcv_refactor_v2.m`

Helpers (same folder, auto-discoverable by MATLAB):
- `eval_plsda_once.m` — PLS-DA per split (inner-CV for #LVs)
- `eval_svm_once.m` — ECOC SVM (linear/RBF) with hyperparameter optimization
- `eval_pca_svm_once.m` — PCA → linear SVM (inner-CV for #PCs)
- `select_setting_inner_cv.m` — Choose feature selection policy (none/VIP≥thr/Top-K)
- `compute_vip_on_train.m` — VIP on training set after optimizing #LVs
- `optimize_pls_components.m` — Inner-CV selection of #LVs (PLS)
- `make_selection_mask.m` — Build boolean mask from VIP/Top-K policy
- `metrics_from_preds.m` — Accuracy, balanced accuracy, confusion matrix
- `summarize_metrics.m` — Summary stats (mean/SD + P05/P50/P95 of BalAcc)
- `paired_tests.m` — Paired t-test & Wilcoxon for model comparisons
- `build_stability_table.m` — VIP selection stability per band
- `long_metrics_table.m` — Long-format metrics by repetition/fold
- `collect_field.m` — Assemble metric matrix for boxplots

---

## Requirements

- MATLAB **R2023a+** recommended
- **Statistics and Machine Learning Toolbox**
- **Parallel Computing Toolbox** (for `parfor` and parallel HPO)

---

## Expected input

Excel file (default: `Datos_Preprocesados.xlsx`) with **one or more sheets**.  
Each sheet must contain:

- Column **`camara`** (e.g., `FX10`)
- **Class column** (first one found in this order): `Treatment` → `Año` → `Anio`
- **Spectral bands** with headers like `R_720_5`, `R_721_5`, … (prefix `R_`)

**Sheet examples** used in the paper:
- `MSC_1_Derivada_Preproc`
- `SNV_1_Derivada_Preproc`
- `x1_Derivada_SG_Preproc`

---

## Quick start

1. Open `fx10_supervised_hsi_nestedcv_refactor_v2.m` and edit:
   ```matlab
   cfg.data_file        = 'Datos_Preprocesados.xlsx';
   cfg.cam_name         = 'FX10';
   cfg.sheets_to_process = {'MSC_1_Derivada_Preproc','SNV_1_Derivada_Preproc','x1_Derivada_SG_Preproc'};
   cfg.output_folder    = 'C:\Resultados_Pimenton\FX10_Resultados';
