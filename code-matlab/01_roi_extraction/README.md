\# 01 · ROI extraction (FX10 \& FX17)



Interactive ROI selection for paprika HSI (3 campaigns). This folder contains portable MATLAB scripts to draw circular ROIs on RGB quicklooks and export mean spectra per fruit to Excel, plus an overview PNG with all ROIs.



\## Scripts

\- \*\*extract\_spectra\_fx10.m\*\* — VIS–NIR (Specim FX10)

\- \*\*extract\_spectra\_fx17.m\*\* — NIR–SWIR (Specim FX17)

\- \*\*enviinfo\_local.m\*\*, \*\*enviread\_local.m\*\* — local ENVI helpers (kept here for portability)



\## Requirements

\- MATLAB R2025a (tested)

\- Image Processing Toolbox (for `drawcircle`, `viscircles`, `imadjust`)

\- Data downloaded from Zenodo (full dataset), unzipped locally



\## Data

Download and unzip the FX10/FX17 folders from Zenodo:

\- \*\*Dataset DOI:\*\* `https://doi.org/10.5281/zenodo.XXXXXXX`  ← \*(replace with your dataset DOI)\*



Expected local structure (after unzip, anywhere on your disk):



