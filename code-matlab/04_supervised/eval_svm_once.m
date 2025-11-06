%% ------------------------------------------------------------------------
% File: eval_svm_once.m
% Title: Evaluate an SVM (linear/RBF) via ECOC on one train/test split
%
% PURPOSE:
%   Train a multiclass SVM classifier using ECOC (one-vs-all) with
%   hyperparameter optimization by inner cross-validation, then evaluate
%   on the test split to return accuracy, balanced accuracy, and the
%   confusion matrix.
%
% INPUTS:
%   Xtr  - (n_train x p) training spectra
%   Ytr  - (n_train x 1) categorical labels for training
%   Xte  - (n_test  x p) test spectra
%   Yte  - (n_test  x 1) categorical labels for test
%   opts - struct with fields:
%          .kernel   -> 'linear' or 'rbf'
%          .k_inner  -> inner CV folds for HPO
%          .optcfg   -> (optional) struct with HPO options
%                       e.g., .MaxObjectiveEvaluations for bayesopt
%
% OUTPUTS:
%   acc    - overall accuracy on test set
%   balacc - balanced accuracy on test set
%   cm     - confusion matrix (#classes x #classes)
%
% DEPENDENCIES:
%   - Statistics and Machine Learning Toolbox (fitcecoc, templateSVM)
%   - metrics_from_preds (compute acc/balacc/confusion matrix)
%
% NOTES:
%   - Multiclass handled with ECOC ('onevsall').
%   - RBF kernel optimizes BoxConstraint and KernelScale; linear only BoxConstraint.
%   - Attempts to use parallel HPO if available.
%   - Code logic unchanged; only comments/strings translated to English.
%
% AUTHOR: J. Alonso
% DATE: 16-Aug-2025
% SPDX-License-Identifier: CC-BY-4.0
% Version: 2.0.0 (comments translated; no logic changes)
%% ------------------------------------------------------------------------

function [acc, balacc, cm] = eval_svm_once(Xtr, Ytr, Xte, Yte, opts)
    classes = categories(Ytr);
    t = templateSVM('KernelFunction', opts.kernel, 'Standardize', true);
    Kcv = min(opts.k_inner, max(2, min(countcats(Ytr))));
    hpOpts = struct('KFold', Kcv, 'ShowPlots', false, 'Verbose', 0);
    
    if strcmpi(opts.kernel, 'rbf')
        hp = {'BoxConstraint', 'KernelScale'};
        if ~isempty(opts.optcfg) && isfield(opts.optcfg, 'MaxObjectiveEvaluations')
            hpOpts.MaxObjectiveEvaluations = opts.optcfg.MaxObjectiveEvaluations;
        end
    else
        hp = {'BoxConstraint'};
    end
    
    try % Try to enable parallelism if available
        hpOpts.UseParallel = true;
    catch
        hpOpts.UseParallel = false;
    end
    
    mdl = fitcecoc(Xtr, Ytr, 'Learners', t, 'Coding', 'onevsall', ...
        'OptimizeHyperparameters', hp, ...
        'HyperparameterOptimizationOptions', hpOpts);
    
    Yhat = predict(mdl, Xte);
    [acc, balacc, cm] = metrics_from_preds(Yte, Yhat, classes);
end
