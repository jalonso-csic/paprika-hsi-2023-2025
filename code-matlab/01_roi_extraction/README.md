\# 01 · ROI extraction (FX10 \& FX17)



Interactive ROI selection for paprika HSI (3 campaigns).  

This folder contains portable MATLAB scripts to draw \*\*circular ROIs\*\* on RGB quicklooks and export \*\*mean spectra per fruit\*\* to Excel, plus an overview PNG with all ROIs.



\## Scripts

\- \*\*extract\_spectra\_fx10.m\*\* — VIS–NIR (Specim FX10)

\- \*\*extract\_spectra\_fx17.m\*\* — NIR–SWIR (Specim FX17)

\- \*\*enviinfo\_local.m\*\*, \*\*enviread\_local.m\*\* — local ENVI helpers (kept here for portability)



\## Requirements

\- MATLAB \*\*R2025a\*\* (tested)

\- \*\*Image Processing Toolbox\*\* (`drawcircle`, `viscircles`, `imadjust`)

\- Local copies of the data (full dataset or the mini dataset for a quick test)



\## Data

\- \*\*Mini dataset (for quick test):\*\* https://doi.org/10.5281/zenodo.17520710  

\- \*\*Full dataset:\*\* \*(add DOI here when available)\*



After unzipping, point the scripts to the \*\*FX10\*\* or \*\*FX17\*\* root folder (can be anywhere on your disk).



\### Expected local structure (example)



<your\_data\_root>/

├─ FX10/

│ └─ FX10\_2023\_1\_0009/

│ └─ capture/

│ ├─ FX10\_2023\_1\_0009.hdr

│ ├─ FX10\_2023\_1\_0009.raw

│ ├─ WHITEREF\_FX10\_2023\_1\_0009.hdr

│ ├─ WHITEREF\_FX10\_2023\_1\_0009.raw

│ ├─ DARKREF\_FX10\_2023\_1\_0009.hdr

│ └─ DARKREF\_FX10\_2023\_1\_0009.raw

└─ FX17/

└─ FX17\_2023\_1\_0149/

└─ capture/

├─ FX17\_2023\_1\_0149.hdr

├─ FX17\_2023\_1\_0149.raw

├─ WHITEREF\_FX17\_2023\_1\_0149.hdr

├─ WHITEREF\_FX17\_2023\_1\_0149.raw

├─ DARKREF\_FX17\_2023\_1\_0149.hdr

└─ DARKREF\_FX17\_2023\_1\_0149.raw





\## How to run (portable)

1\. Open MATLAB and \*\*add `code-matlab/` to the path\*\*.

2\. Run \*\*`extract\_spectra\_fx10`\*\* \*or\* \*\*`extract\_spectra\_fx17`\*\*.

3\. On first run, when prompted, \*\*select the camera root folder\*\* (e.g. `<your\_data\_root>\\FX10` or `FX17`).  

&nbsp;  The script scans subfolders like `FX10\_YYYY\_\* / capture`.

4\. Enter \*\*ROI radius (pixels)\*\* and \*\*number of fruits\*\* to sample per image.

5\. For each fruit: click the centre, adjust the \*\*circular ROI\*\* and \*\*press A to accept\*\* (or \*\*R to repeat\*\*).  

&nbsp;  The script calibrates (WHITE/DARK), extracts mean spectra per ROI and saves outputs.



\## Outputs

\- `results/FX10/resultados/<YEAR>/ROIs\_<normalized\_sample\_name>.png` — overview with all ROIs

\- `results/FX10/resultados/<YEAR>/espectros\_<normalized\_sample\_name>.xlsx` — table: `Sample | Year | λ1 … λN`

\- `results/FX17/resultados/<YEAR>/ROIs\_<normalized\_sample\_name>.png`

\- `results/FX17/resultados/<YEAR>/spectra\_<normalized\_sample\_name>.xlsx`



> Filenames are normalized to ASCII and safe (`\_` instead of spaces/accents).



\## Notes

\- The ENVI helpers (`enviinfo\_local.m`, `enviread\_local.m`) are kept \*\*in this folder\*\* so the scripts run from any working directory without external dependencies.

\- FX10/FX17 scripts share the same workflow; only the spectral range and RGB quicklook bands differ.

\- Wavelengths are parsed from the HDR; if missing, a numeric sequence is used as a fallback.

\- Sample/WHITE/DARK are spatially/spectrally aligned by trimming to the minimum common size.

\- The ROI radius is fixed; interaction allows translation only (protocol consistency).



\## Citation

Please cite the \*\*software\*\* and the \*\*data\*\*:

\- Software (this repository / concept DOI): \*(add when available)\*  

\- Mini dataset (runnable example): https://doi.org/10.5281/zenodo.17520710



\*\*License:\*\* Code MIT; Docs/Figures CC BY 4.0.





