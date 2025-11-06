%% ------------------------------------------------------------------------
% File: optimize_pls_components.m
% Title: Select optimal number of PLS components via inner cross-validation
%
% PURPOSE:
%   Determine the optimal number of PLS components (LVs) that minimizes
%   cross-validated misclassification error using stratified K-fold CV.
%
% INPUTS:
%   X           - (n x p) spectra matrix
%   Y           - (n x 1) categorical labels
%   max_ncomp   - maximum number of components to evaluate
%   kfold_eff   - effective number of folds for inner CV (already adjusted)
%
% OUTPUTS:
%   opt_ncomp   - optimal number of PLS components (argmin CV error)
%
% DEPENDENCIES:
%   - Statistics and Machine Learning Toolbox (cvpartition, plsregress, dummyvar)
%
% NOTES:
%   - Multiclass handled via dummy coding + argmax on predicted scores.
%   - Code logic unchanged; only comments/strings translated to English.
%
% AUTHOR: J. Alonso
% DATE: 16-Aug-2025
% SPDX-License-Identifier: CC-BY-4.0
% Version: 2.0.0 (comments translated; no logic changes)
%% ------------------------------------------------------------------------

function opt_ncomp = optimize_pls_components(X, Y, max_ncomp, kfold_eff)
    % Return only the optimal ncomp (min CV error)
    cv = cvpartition(Y, 'KFold', kfold_eff, 'Stratify', true);
    misclass = zeros(max_ncomp, kfold_eff);
    classes = categories(Y);
    for i = 1:kfold_eff
        Xtr = X(training(cv,i),:); Ytr = Y(training(cv,i));
        Xte = X(test(cv,i),:);    Yte = Y(test(cv,i));
        Ydum = dummyvar(Ytr);
        for j = 1:max_ncomp
            [~,~,~,~,BETA] = plsregress(Xtr, Ydum, j);
            Yscores = [ones(size(Xte,1),1) Xte]*BETA;
            [~,idx] = max(Yscores,[],2);
            Yhat = categorical(classes(idx), classes);
            misclass(j,i) = sum(Yhat ~= Yte) / numel(Yte);
        end
    end
    mean_err = mean(misclass, 2);
    [~, opt_ncomp] = min(mean_err);
end
