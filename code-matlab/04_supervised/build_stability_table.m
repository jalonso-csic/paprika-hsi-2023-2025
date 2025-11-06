%% ------------------------------------------------------------------------
% File: build_stability_table.m
% Title: Assemble VIP selection stability table for spectral bands
%
% PURPOSE:
%   Build a table summarizing how frequently each spectral band was selected
%   across inner-CV trials, including absolute counts and normalized
%   selection frequency, then sort by frequency (descending).
%
% INPUTS:
%   band_names   - cellstr or string array of band variable names (e.g., 'R_720_5')
%   wavelengths  - (p x 1) numeric vector of wavelengths (nm)
%   count_vec    - (p x 1) integer counts of how many times each band was selected
%   total_trials - scalar, total number of selection trials (denominator)
%
% OUTPUTS:
%   T - table with columns:
%       Band_Name, Wavelength_nm, Selection_Frequency, Selection_Count
%       (sorted by Selection_Frequency in descending order)
%
% NOTES:
%   - Code logic unchanged; comments translated to English only.
%   - If total_trials <= 0, frequencies are returned as zeros.
%
% AUTHOR: J. Alonso
% DATE: 16-Aug-2025
% SPDX-License-Identifier: CC-BY-4.0
% Version: 2.0.0 (comments translated; no logic changes)
%% ------------------------------------------------------------------------

function T = build_stability_table(band_names, wavelengths, count_vec, total_trials)
    if total_trials <= 0
        freq = zeros(numel(band_names), 1);
    else
        freq = count_vec / total_trials;
    end
    T = table(band_names(:), wavelengths(:), freq(:), count_vec(:), ...
        'VariableNames', {'Band_Name', 'Wavelength_nm', 'Selection_Frequency', 'Selection_Count'});
    T = sortrows(T, 'Selection_Frequency', 'descend');
end
