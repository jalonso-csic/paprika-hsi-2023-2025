%% ------------------------------------------------------------------------
% File: select_setting_inner_cv.m
% Title: Select best feature-selection setting via inner cross-validation
%
% PURPOSE:
%   Given a grid of feature-selection policies (none / VIP thresholds / Top-K),
%   pick the one that maximizes mean balanced accuracy in an inner CV loop,
%   conditioned on the target model family (PLS or SVM).
%
% INPUTS:
%   Xtr         - (n_train x p) training spectra
%   Ytr         - (n_train x 1) categorical labels (training)
%   k_inner     - requested inner CV folds
%   max_lvs     - maximum #LVs to explore for PLS-based VIP computation
%   sel_grid    - cell array of structs describing selection settings
%   targetModel - 'PLS' or 'SVM' (case-insensitive)
%
% OUTPUTS:
%   best_setting - the selection-setting struct with highest mean bal. accuracy
%
% DEPENDENCIES:
%   - compute_vip_on_train (VIP on training set)
%   - make_selection_mask  (boolean mask from selection-setting)
%   - eval_plsda_once      (PLS-DA evaluation)
%   - eval_svm_once        (SVM evaluation)
%
% NOTES:
%   - Code logic unchanged; comments translated to English only.
%   - Uses stratified K-fold inner CV with a safe adjustment for minority classes.
%
% AUTHOR: J. Alonso
% DATE: 16-Aug-2025
% SPDX-License-Identifier: CC-BY-4.0
% Version: 2.0.0 (comments translated; no logic changes)
%% ------------------------------------------------------------------------

function best_setting = select_setting_inner_cv(Xtr, Ytr, k_inner, max_lvs, sel_grid, targetModel)
    % Select the best pre-selection setting via inner CV
    best_setting = sel_grid{1};  % default: none
    best_score = -Inf;
    
    k_inner_eff = min(k_inner, max(2, min(countcats(Ytr))));
    cv_inner = cvpartition(Ytr, 'KFold', k_inner_eff, 'Stratify', true);

    for s = 1:numel(sel_grid)
        setting = sel_grid{s};
        scores = zeros(k_inner_eff, 1);
        for i = 1:k_inner_eff
            idtr = training(cv_inner, i);
            idva = test(cv_inner, i);
            Xtr_in = Xtr(idtr,:); Ytr_in = Ytr(idtr);
            Xva_in = Xtr(idva,:); Yva_in = Ytr(idva);
            
            k_fold_in = max(3, min(k_inner_eff - 1, 5)); % for nested optimization
            
            [vip_in, ~] = compute_vip_on_train(Xtr_in, Ytr_in, max_lvs, k_fold_in);
            sel_mask = make_selection_mask(vip_in, setting, 10);
            
            Xtr_sel = Xtr_in(:, sel_mask);
            Xva_sel = Xva_in(:, sel_mask);
            
            switch upper(targetModel)
                case 'PLS'
                    opts = struct('max_lvs', max_lvs, 'k_inner', k_fold_in);
                    [~, balacc] = eval_plsda_once(Xtr_sel, Ytr_in, Xva_sel, Yva_in, opts);
                otherwise % 'SVM'
                    opts = struct('kernel', 'linear', 'k_inner', k_fold_in, 'optcfg', []);
                    [~, balacc] = eval_svm_once(Xtr_sel, Ytr_in, Xva_sel, Yva_in, opts);
            end
            scores(i) = balacc;
        end
        sc = mean(scores, 'omitnan');
        if sc > best_score
            best_score = sc;
            best_setting = setting;
        end
    end
end
