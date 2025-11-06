%% ------------------------------------------------------------------------
% File: long_metrics_table.m
% Title: Build long-format table of per-fold metrics for each model
%
% PURPOSE:
%   Convert per-model vectors of Accuracy and Balanced Accuracy into a
%   single long-format table with columns: Model, Rep, Fold, Acc, BalAcc.
%   The number of folds per model is inferred from vector length.
%
% INPUTS:
%   all_metrics   - struct with fields per model tag:
%                   .acc    -> vector of accuracies
%                   .balacc -> vector of balanced accuracies
%   model_tags    - cell array of model tag strings
%   ~             - (unused) placeholder for repetitions (kept for signature)
%   k_outer       - nominal #outer folds (used to derive Rep/Fold indices)
%
% OUTPUTS:
%   T - table with columns: Model, Rep, Fold, Acc, BalAcc
%
% NOTES:
%   - Code logic unchanged; comments translated to English only.
%   - Uses actual vector length per model (may be < repetitions*k_outer).
%   - Rows with missing Model (if any) are removed before returning.
%
% AUTHOR: J. Alonso
% DATE: 16-Aug-2025
% SPDX-License-Identifier: CC-BY-4.0
% Version: 2.0.0 (comments translated; no logic changes)
%% ------------------------------------------------------------------------

function T = long_metrics_table(all_metrics, model_tags, ~, k_outer)
    % Replace 'repetitions' with '~' because it is no longer used in the code.
    num_models = numel(model_tags);
    % Use the actual size of the results vector, which may be smaller than rep*k
    num_folds_per_model = numel(all_metrics.(model_tags{1}).acc);
    total_rows = num_models * num_folds_per_model;

    % Preallocation
    Model = repmat("", total_rows, 1);
    Rep = nan(total_rows, 1);
    Fold = nan(total_rows, 1);
    Acc = nan(total_rows, 1);
    BalAcc = nan(total_rows, 1);
    
    current_pos = 1;
    for i = 1:num_models
        tag = model_tags{i};
        vecA = all_metrics.(tag).acc;
        vecB = all_metrics.(tag).balacc;
        
        L = numel(vecA); % Actual number of results for this model
        
        end_pos = current_pos + L - 1;
        
        Model(current_pos:end_pos) = string(tag);
        
        rep_idx = ceil((1:L)' / k_outer);
        fold_idx = mod((1:L)' - 1, k_outer) + 1;
        
        Rep(current_pos:end_pos) = rep_idx;
        Fold(current_pos:end_pos) = fold_idx;
        Acc(current_pos:end_pos) = vecA;
        BalAcc(current_pos:end_pos) = vecB;
        
        current_pos = end_pos + 1;
    end
    
    % Remove unused rows if any run had fewer folds
    valid_rows = ~ismissing(Model);
    T = table(Model(valid_rows), Rep(valid_rows), Fold(valid_rows), Acc(valid_rows), BalAcc(valid_rows), ...
        'VariableNames', {'Model', 'Rep', 'Fold', 'Acc', 'BalAcc'});
end
