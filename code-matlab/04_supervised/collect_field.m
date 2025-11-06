%% ------------------------------------------------------------------------
% File: collect_field.m
% Title: Collect a metric field across models into a matrix (for boxplot)
%
% PURPOSE:
%   Build a (L x M) numeric matrix from per-model metric vectors so it can
%   be passed directly to boxplot, where columns correspond to models.
%
% INPUTS:
%   all_metrics - struct with fields per model tag; each contains:
%                 .<fieldname> -> vector (length L_i) of metric values
%   model_tags  - cell array of model tag strings (M models)
%   fieldname   - char/string name of the metric field to collect
%
% OUTPUTS:
%   mat - (L x M) numeric matrix with NaN padding for shorter vectors
%
% NOTES:
%   - Code logic unchanged; comments translated to English only.
%   - If models have different vector lengths, trailing entries are NaN.
%
% AUTHOR: J. Alonso
% DATE: 16-Aug-2025
% SPDX-License-Identifier: CC-BY-4.0
% Version: 2.0.0 (comments translated; no logic changes)
%% ------------------------------------------------------------------------

function mat = collect_field(all_metrics, model_tags, fieldname)
    % Return a matrix ready for boxplot
    L = numel(all_metrics.(model_tags{1}).(fieldname));
    M = numel(model_tags);
    mat = nan(L, M);
    for i = 1:M
        data = all_metrics.(model_tags{i}).(fieldname);
        mat(1:numel(data), i) = data;
    end
end
