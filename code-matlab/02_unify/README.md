## How to run
1. Open MATLAB and navigate to the camera results folder: `...\FX10\resultados\` or `...\FX17\resultados\` (must contain `2023`, `2024`, `2025` with per‑sample Excel files).
2. Add this folder to the MATLAB path:
   ```matlab
   addpath('code-matlab/02_unify');
   ```
3. Run:
   ```matlab
   unify_paprika_spectra
   ```

## What it outputs
- **File:** `FX10_PIMENTON_UNIFICADO.xlsx` or `FX17_PIMENTON_UNIFICADO.xlsx` (saved in the current working folder).
- **Columns:** `Año` (Year), `Muestra` (Sample), plus spectral columns formatted as `x####_##` (wavelengths).
- **Content:** Row‑wise union of all valid Excel files found under `2023/`, `2024/`, `2025` (no averaging or additional statistics).
