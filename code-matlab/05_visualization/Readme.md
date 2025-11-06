Common layout & style: Times New Roman (10/12 pt), compact `tiledlayout`.

---

## Inputs (from step 04)

Place the **normalized reports** in the working folder (`pwd`):

**FX10**
- `FX10_MSC_1_Derivada_Preproc_Report.xlsx`  
- `FX10_SNV_1_Derivada_Preproc_Report.xlsx`  
- `FX10_x1_Derivada_SG_Preproc_Report.xlsx`

**FX17**
- `FX17_MSC_1_Derivada_Preproc_Report.xlsx`  
- `FX17_SNV_1_Derivada_Preproc_Report.xlsx`  
- `FX17_x1_Derivada_SG_Preproc_Report.xlsx`

> Full Reports archived on Zenodo (**v2**): **10.5281/zenodo.17540888**.  
> Preprocessed tables used by step 04: **10.5281/zenodo.17539563**.

---

## Outputs

Saved to the **current directory**:

- **Confusion tri-panel**: `FX<cam>_confusion_matrices_tripanel.png` (600 dpi) and `.pdf` (vector).  
- **VIP profiles**: displayed on screen (edit the script if you want to export files).

**Dissemination JPGs (600 dpi)**
- `FX10_confusion_matrices_tripanel.jpg`
- `FX17_confusion_matrices_tripanel.jpg`
- `FX10_VIP_stability_profiles.jpg`
- `FX17_VIP_stability_profiles.jpg`

> The four JPGs are archived on Zenodo: **10.5281/zenodo.17541484**.

---

## How to run
1. Open MATLAB and `cd` to `code-matlab/05_visualization` (or to the folder holding the reports).  
2. Run the functions with no arguments:
   - FX10 confusion: `plot_confusion_tripanel_fx10_autodetect`  
   - FX17 confusion: `plot_confusion_tripanel_fx17_autodetect`  
   - FX10 VIP: `plot_vip_stability_profiles_fx10`  
   - FX17 VIP: `plot_vip_stability_profiles_fx17`

---

## Behaviour and key parameters

### Confusion tri-panel
- **Auto-detection:** read `Summary_Metrics` → highest `Mean_BalAcc` → `CM_<best_model>`. If not present, use the first `CM_*` sheet.
- `asPercent`: `true` shows row-wise percentages; `false` shows absolute counts.
- Class labels are cleaned from prefixes like `x2023 → 2023`.

### VIP profiles
- Reads `VIP_Stability` (`Wavelength_nm`, `Selection_Frequency`).
- Converts to **%** if provided in [0,1].
- Smooths with **Savitzky–Golay** (`sgolayfilt`) or `movmean`.
- Panel A: three profiles with legend. Panel B: **mean ± range** with optional peaks (`findpeaks` if available).
- Adjustable at the top: `ylims`, `ytick_step`, `guide_lines`, `sgolay_ord`, `sgolay_win`, `min_prom`, `min_dist`, `show_peaks`.

---

## Requirements
- MATLAB R2021a+ (tested). No mandatory toolboxes for the figures.  
- Optional: **Signal Processing Toolbox** (`sgolayfilt`, `findpeaks`).

---

## Common issues
- **File not found:** check exact names `*_Report.xlsx` (Zenodo v2) or run from their folder.
- **No `CM_*` sheets:** step 04 must have produced confusion-matrix sheets; if missing, rerun supervised scripts.
- **`x2023` labels:** scripts already strip the `x` prefix; use the “clean” variant only if you need to lock a specific sheet.

---

## Citation
- **Dissemination JPG figures (this step):** **10.5281/zenodo.17541484**  
- **Supervised Full Reports (inputs for this step):** **10.5281/zenodo.17540888** (v2)  
- **Preprocessed tables (used in step 04):** **10.5281/zenodo.17539563**

Please cite these records when using the figures.
