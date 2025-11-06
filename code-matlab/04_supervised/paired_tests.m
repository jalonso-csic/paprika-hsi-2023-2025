%% ------------------------------------------------------------------------
% File: paired_tests.m
% Title: Paired comparisons between model metrics (t-test & Wilcoxon)
%
% PURPOSE:
%   For all pairs of models, perform paired statistical tests on a chosen
%   metric vector (e.g., 'balacc' or 'acc') across identical folds/repeats.
%   Returns a table of model pairs with p-values from:
%     - Paired t-test (ttest)
%     - Wilcoxon signed-rank test (signrank)
%
% INPUTS:
%   all_metrics - struct with fields per model tag; each contains vectors:
%                 .<fieldname> -> metric per fold/repetition (same length)
%   model_tags  - cell array of model tag strings (field names in all_metrics)
%   fieldname   - char/string name of the metric field to compare
%
% OUTPUTS:
%   T - table with columns:
%       Model_A, Model_B, p_ttest_paired, p_wilcoxon_paired
%
% DEPENDENCIES:
%   - Statistics and Machine Learning Toolbox (ttest, signrank)
%
% NOTES:
%   - Code logic unchanged; comments translated to English only.
%   - NaNs are removed pairwise before testing.
%   - If tests fail (e.g., due to insufficient data), p-values remain NaN.
%
% AUTHOR: J. Alonso
% DATE: 16-Aug-2025
% SPDX-License-Identifier: CC-BY-4.0
% Version: 2.0.0 (comments translated; no logic changes)
%% ------------------------------------------------------------------------

function T = paired_tests(all_metrics, model_tags, fieldname)
    n_models = numel(model_tags);
    num_pairs = nchoosek(n_models, 2);
    
    % Preallocation
    pairsA = cell(num_pairs, 1);
    pairsB = cell(num_pairs, 1);
    p_ttest = nan(num_pairs, 1);
    p_wilcoxon = nan(num_pairs, 1);
    
    pair_idx = 1;
    for i = 1:n_models
        for j = i + 1:n_models
            x = all_metrics.(model_tags{i}).(fieldname);
            y = all_metrics.(model_tags{j}).(fieldname);
            
            valid_idx = ~isnan(x) & ~isnan(y);
            x = x(valid_idx);
            y = y(valid_idx);
            
            p1 = NaN; p2 = NaN;
            if numel(x) > 1
                try
                    [~,p1] = ttest(x, y);
                catch
                    % Ignore error if ttest fails
                end
                try
                    p2 = signrank(x, y);
                catch
                    % Ignore error if signrank fails
                end
            end
            
            pairsA{pair_idx} = model_tags{i};
            pairsB{pair_idx} = model_tags{j};
            p_ttest(pair_idx) = p1;
            p_wilcoxon(pair_idx) = p2;
            
            pair_idx = pair_idx + 1;
        end
    end
    T = table(pairsA, pairsB, p_ttest, p_wilcoxon, ...
        'VariableNames', {'Model_A', 'Model_B', 'p_ttest_paired', 'p_wilcoxon_paired'});
end
