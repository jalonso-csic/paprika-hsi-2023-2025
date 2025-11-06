%% ------------------------------------------------------------------------
% File: eval_plsda_once.m
% Title: Evaluate a single PLS-DA model on one train/test split
%
% PURPOSE:
%   Train a PLS-DA classifier (multiclass via dummy coding) selecting the
%   optimal number of latent variables (LVs) by inner cross-validation, and
%   evaluate it on the test split returning accuracy, balanced accuracy,
%   and the confusion matrix.
%
% INPUTS:
%   Xtr  - (n_train x p) training spectra
%   Ytr  - (n_train x 1) categorical labels for training
%   Xte  - (n_test  x p) test spectra
%   Yte  - (n_test  x 1) categorical labels for test
%   opts - struct with fields:
%          .max_lvs  -> maximum #LVs to explore
%          .k_inner  -> inner CV folds for LV selection
%
% OUTPUTS:
%   acc    - overall accuracy on test set
%   balacc - balanced accuracy on test set
%   cm     - confusion matrix (size = #classes x #classes)
%
% DEPENDENCIES:
%   - optimize_pls_components (inner-CV selection of #LVs)
%   - metrics_from_preds      (compute acc/balacc/confusion matrix)
%   - Statistics and Machine Learning Toolbox (plsregress, dummyvar)
%
% NOTES:
%   - Code logic unchanged; comments and user-facing text only.
%   - Multiclass handled via dummy coding + argmax on predicted scores.
%
% AUTHOR: J. Alonso
% DATE: 16-Aug-2025
% SPDX-License-Identifier: CC-BY-4.0
% Version: 2.0.0 (comments translated; no logic changes)
%% ------------------------------------------------------------------------

function [acc, balacc, cm] = eval_plsda_once(Xtr, Ytr, Xte, Yte, opts)
    classes = categories(Ytr);
    k_inner_eff = min(opts.k_inner, max(2, min(countcats(Ytr))));
    opt_n = optimize_pls_components(Xtr, Ytr, opts.max_lvs, k_inner_eff);
    Ydum = dummyvar(Ytr);
    [~,~,~,~,BETA] = plsregress(Xtr, Ydum, opt_n);
    Yscores = [ones(size(Xte,1),1) Xte]*BETA;
    [~,idx] = max(Yscores,[],2);
    Yhat = categorical(classes(idx), classes);
    [acc, balacc, cm] = metrics_from_preds(Yte, Yhat, classes);
end
