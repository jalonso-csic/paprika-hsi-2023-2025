%% ------------------------------------------------------------------------
% File: eval_pca_svm_once.m
% Title: Evaluate PCA + linear SVM on one train/test split (with inner CV for #PCs)
%
% PURPOSE:
%   Select the optimal number of principal components (PCs) via inner
%   cross-validation on the training set, then train a linear SVM on the
%   PCA scores and evaluate on the test set. Returns accuracy, balanced
%   accuracy, and the confusion matrix.
%
% INPUTS:
%   Xtr  - (n_train x p) training spectra
%   Ytr  - (n_train x 1) categorical labels for training
%   Xte  - (n_test  x p) test spectra
%   Yte  - (n_test  x 1) categorical labels for test
%   opts - struct with fields:
%          .k_inner     -> inner CV folds for model selection
%          .pca_k_grid  -> vector of candidate #PCs to evaluate
%
% OUTPUTS:
%   acc    - overall accuracy on test set
%   balacc - balanced accuracy on test set
%   cm     - confusion matrix (#classes x #classes)
%
% DEPENDENCIES:
%   - Statistics and Machine Learning Toolbox (pca, cvpartition)
%   - eval_svm_once (linear SVM training/evaluation)
%
% NOTES:
%   - Linear SVM is used in both inner-CV and final training.
%   - Code logic unchanged; only comments/strings translated to English.
%
% AUTHOR: J. Alonso
% DATE: 16-Aug-2025
% SPDX-License-Identifier: CC-BY-4.0
% Version: 2.0.0 (comments translated; no logic changes)
%% ------------------------------------------------------------------------

function [acc, balacc, cm] = eval_pca_svm_once(Xtr, Ytr, Xte, Yte, opts)
    k_inner_eff = min(opts.k_inner, max(2, min(countcats(Ytr))));
    cv_in = cvpartition(Ytr, 'KFold', k_inner_eff);
    mean_scores = zeros(numel(opts.pca_k_grid), 1);
    
    for g = 1:numel(opts.pca_k_grid)
        K = opts.pca_k_grid(g);
        fold_sc = zeros(cv_in.NumTestSets, 1);
        for i = 1:cv_in.NumTestSets
            idtr = training(cv_in, i);
            idva = test(cv_in, i);
            [coeff, ~, ~, ~, ~, mu] = pca(Xtr(idtr,:));
            Kc = min(K, size(coeff, 2));
            Xtr_p = (Xtr(idtr,:) - mu) * coeff(:,1:Kc);
            Xva_p = (Xtr(idva,:) - mu) * coeff(:,1:Kc);
            svm_opts = struct('kernel', 'linear', 'k_inner', 3, 'optcfg', []);
            [~, bal] = eval_svm_once(Xtr_p, Ytr(idtr), Xva_p, Ytr(idva), svm_opts);
            fold_sc(i) = bal;
        end
        mean_scores(g) = mean(fold_sc, 'omitnan');
    end
    
    [~, iBest] = max(mean_scores);
    Kbest = opts.pca_k_grid(iBest);
    
    [coeff, ~, ~, ~, ~, mu] = pca(Xtr);
    Kc = min(Kbest, size(coeff, 2));
    Xtr_p = (Xtr - mu) * coeff(:,1:Kc);
    Xte_p = (Xte - mu) * coeff(:,1:Kc);
    
    svm_opts_final = struct('kernel', 'linear', 'k_inner', k_inner_eff, 'optcfg', []);
    [acc, balacc, cm] = eval_svm_once(Xtr_p, Ytr, Xte_p, Yte, svm_opts_final);
end
