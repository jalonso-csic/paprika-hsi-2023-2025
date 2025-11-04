# 03_preprocessing — Comparative preprocessing & PCA scores (FX10 / FX17)

## How to run
1. Prepare the input Excel tables in your working folder:
   - `FX10_con_bioquimicos_PUBLIC.xlsx`
   - `FX17_con_bioquimicos_PUBLIC.xlsx`
2. In MATLAB, add this folder to the path:
   ```matlab
   addpath('code-matlab/03_preprocessing');
   ```
3. Run the desired script:
   ```matlab
   % For VIS–NIR (FX10)
   preprocessing_pca_fx10
   % For NIR–SWIR (FX17)
   preprocessing_pca_fx17
   ```

## What the scripts do
- Load spectra tables and detect spectral columns by prefix `R_`.
- Apply a comparative set of preprocessing options (SNV, MSC, mean centering, polynomial baseline, Savitzky–Golay 1st/2nd derivatives, and chained variants).
- Perform PCA on each preprocessed matrix and export score plots (light theme, .jpg + .fig).
- Compute quick diagnostics: PC1/PC2 variance, Leave-One-Out PLS‑DA accuracy, Mahalanobis outlier count (PC1–PC2), and overall silhouette (PC1–PC2).
- Export a per-method preprocessed table (one sheet per method) and a summary table.

## Inputs (expected)
- `FX10_con_bioquimicos_PUBLIC.xlsx`  — cleaned VIS–NIR table.
- `FX17_con_bioquimicos_PUBLIC.xlsx`  — cleaned NIR–SWIR table.


## Outputs
- `Resultados_PCA_Finales_FX10/` (from `preprocessing_pca_fx10.m`)
- `Resultados_PCA_Finales_FX17/` (from `preprocessing_pca_fx17.m`)
  - `Datos_Preprocesados.xlsx` — one sheet per preprocessing method.
  - `Resumen_Resultados.xlsx` — metrics sorted by PLS‑DA accuracy.
  - `Figuras_PCA_Scores/*.jpg` and `*.fig` — all figures left open for editing.

## Notes
- No hard‑coded paths; scripts operate in the current working folder.
- Grouping column is auto‑detected in this order: `Año`, `Anio`, `Year`, `Tratamiento`.
- Excel sheet names are sanitized (<=31 chars); writing uses overwrite‑by‑sheet.
- Default fonts and colors enforce a white (light) theme for publication‑ready figures.
