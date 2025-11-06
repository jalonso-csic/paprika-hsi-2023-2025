# 04_supervised — Supervised HSI (Paprika; FX10 & FX17)

> MATLAB pipelines for **nested cross‑validation** models (PLS‑DA / SVM) over paprika (Capsicum annuum) hyperspectral data captured with **Specim FX10 (VIS–NIR)** and **FX17 (SWIR)**.

---

## Contents

```
code-matlab/04_supervised/
├─ fx10_supervised_hsi_nestedcv_refactor_v2.m   # main script for FX10
├─ fx17_supervised_hsi_nestedcv_refactor_v2.m   # main script for FX17
├─ build_stability_table.m
├─ collect_field.m
├─ compute_vip_on_train.m
├─ eval_pca_svm_once.m
├─ eval_plsda_once.m
├─ eval_svm_once.m
├─ long_metrics_table.m
├─ make_selection_mask.m
├─ metrics_from_preds.m
├─ optimize_pls_components.m
├─ paired_tests.m
├─ select_setting_inner_cv.m
├─ summarize_metrics.m
└─ (this) README_04_supervised.md
```

---

## Inputs

* **Preprocessed tables (X, y)**:

  * `Datos_Preprocesados_FX10.xlsx`
  * `Datos_Preprocesados_FX17.xlsx`
    These are published at Zenodo: **10.5281/zenodo.17539563** (see also 10.5281/zenodo.17523082).
* Each workbook contains multiple sheets, e.g.:
  `MSC_1_Derivada_Preproc`, `SNV_1_Derivada_Preproc`, `x1_Derivada_SG_Preproc`.
* Spectral columns follow the `R_<wavelength>` convention (e.g., `R_720_0`).

> **Label column**: the scripts auto‑detect a class column from `Treatment`, `Año`, `Anio` (extend if needed).

---

## Quick start

1. Open **MATLAB** and `cd` into `code-matlab/04_supervised`.
2. Ensure toolboxes: *Statistics and Machine Learning*, *Parallel Computing*.
3. Run **one** of the main scripts:

   * **FX10**: open `fx10_supervised_hsi_nestedcv_refactor_v2.m` and run.

     * The script expects `cfg.data_file = 'Datos_Preprocesados_FX10.xlsx'`.
   * **FX17**: open `fx17_supervised_hsi_nestedcv_refactor_v2.m` and run.

     * The script expects `cfg.data_file = 'Datos_Preprocesados_FX17.xlsx'`.

> **Working directory**: results are saved under `fullfile(pwd, '<CAM>_Results')`. Run the script **from this folder** if you want outputs to stay here.

---

## Default CV & model settings

* Outer CV: `k_outer = 10`; repetitions: `10`; Inner CV: `k_inner = 5`.
* PLS‑DA latent variables: `max_lvs = 15`.
* VIP filters evaluated in inner CV: thresholds `[0.8 1.0 1.2]` and Top‑K `[20 40]` (minimum kept features: 10).
* SVM: linear and RBF (Bayesian optimization budget: 20 evaluations).
* Optional baseline: `PCA + SVM (linear)` with PCs grid `[5 10 20 40]`.
* Reproducibility: `rng(42,'twister')` + per‑repetition seeds.

---

## Outputs

For each processed sheet, the script writes to `<CAM>_Results/` (relative to **pwd**):

* **Excel report**: `<CAM>_<Sheet>_Report.xlsx` with sheets:
  `Analysis_Info`, `Summary_Metrics`, `Paired_Tests`, `VIP_Stability`, `PerFold_Results`, `CM_<best_model>`.
* **Figures** (PNG + FIG): `..._boxplot_balacc.*`, `..._vip_stability.*`.

> Previous runs may appear as `<CAM>_<Sheet>_Full_Report.xlsx`. Both denote the consolidated final report for that sheet.

A curated set of final reports is published at Zenodo: **10.5281/zenodo.17540000**.

---

## Post‑hoc (optional)

If present in the repo, `04_supervised_posthoc_eval.m` produces:

* global/per‑class metrics tables, row‑normalized confusion‑matrix heatmaps, and VIP stability plots with bootstrap CIs from per‑fold VIP matrices.

---

## Reproducibility & citation

* **Inputs** (preprocessed tables): Zenodo **10.5281/zenodo.17539563** (see also 10.5281/zenodo.17523082).
* **Supervised results (Full Reports)**: Zenodo **10.5281/zenodo.17540000**.

Please cite both datasets when using these scripts.

---

## Troubleshooting

* *File not found*: ensure the XLSX filenames match exactly (`Datos_Preprocesados_FX10.xlsx` / `Datos_Preprocesados_FX17.xlsx`) and that you run from `04_supervised/`.
* *Not enough samples per class*: the script auto‑reduces `k_outer` to the smallest class count.
* *Parfor issues*: start a pool manually (`parpool('threads')`), or disable parallelization if needed.

---

## License

Code is released under the project’s repository license. Data files keep their own Zenodo licenses (recommended **CC BY 4.0**).

---

*Nota breve (ES):* este README describe cómo ejecutar los **scripts de supervisado** para FX10/FX17 desde `04_supervised`, usando como entrada los Excel preprocesados y generando los **Report.xlsx** (o **Full_Report.xlsx**) por hoja de preprocesado.
