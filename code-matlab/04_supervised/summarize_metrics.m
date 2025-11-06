%% ------------------------------------------------------------------------
% File: summarize_metrics.m
% Title: Build summary table of model performance statistics
%
% PURPOSE:
%   Aggregate per-fold metrics across models and return a summary table with:
%   - Mean/SD of accuracy,
%   - Mean/SD of balanced accuracy,
%   - Percentiles (P05, P50, P95) of balanced accuracy.
%
% INPUTS:
%   all_metrics - struct with fields per model tag, each containing:
%                 .acc    -> vector of accuracies across folds/repetitions
%                 .balacc -> vector of balanced accuracies across folds/reps
%   model_tags  - cell array of model tag strings (field names in all_metrics)
%
% OUTPUTS:
%   T - table with columns:
%       Model, Mean_Acc, SD_Acc, Mean_BalAcc, SD_BalAcc, P05_BalAcc, P50_BalAcc, P95_BalAcc
%
% NOTES:
%   - Code logic unchanged; comments translated to English only.
%   - Uses mean/std with 'omitnan' and percentiles on balanced accuracy.
%
% AUTHOR: J. Alonso
% DATE: 16-Aug-2025
% SPDX-License-Identifier: CC-BY-4.0
% Version: 2.0.0 (comments translated; no logic changes)
%% ------------------------------------------------------------------------

function T = summarize_metrics(all_metrics, model_tags)
    mu = zeros(numel(model_tags), 1);
    sd = zeros(numel(model_tags), 1);
    p5 = zeros(numel(model_tags), 1);
    p50 = zeros(numel(model_tags), 1);
    p95 = zeros(numel(model_tags), 1);
    muA = zeros(numel(model_tags), 1);
    sdA = zeros(numel(model_tags), 1);
    for i=1:numel(model_tags)
        b = all_metrics.(model_tags{i}).balacc;
        a = all_metrics.(model_tags{i}).acc;
        mu(i) = mean(b, 'omitnan'); sd(i) = std(b, 'omitnan');
        p5(i) = prctile(b, 5); p50(i) = prctile(b, 50); p95(i) = prctile(b, 95);
        muA(i) = mean(a, 'omitnan'); sdA(i) = std(a, 'omitnan');
    end
    T = table(model_tags(:), muA, sdA, mu, sd, p5, p50, p95, ...
        'VariableNames', {'Model', 'Mean_Acc', 'SD_Acc', 'Mean_BalAcc', 'SD_BalAcc', 'P05_BalAcc', 'P50_BalAcc', 'P95_BalAcc'});
end
