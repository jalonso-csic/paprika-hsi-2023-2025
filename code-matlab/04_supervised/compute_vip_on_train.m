%% ------------------------------------------------------------------------
% File: compute_vip_on_train.m
% Title: Compute VIP on training set after inner-CV optimization of #LVs
%
% PURPOSE:
%   Optimize the number of PLS components (LVs) via inner cross-validation
%   on the training data, then compute Variable Importance in Projection
%   (VIP) scores on the full training set using the selected #LVs.
%
% INPUTS:
%   Xtr      - (n_train x p) training spectra
%   Ytr      - (n_train x 1) categorical labels
%   max_lvs  - maximum number of latent variables to explore
%   k_inner  - requested inner CV folds
%
% OUTPUTS:
%   vip_tr     - (p x 1) VIP scores computed on the full training set
%   opt_ncomp  - selected optimal number of components (LVs)
%
% DEPENDENCIES:
%   - optimize_pls_components (select optimal #LVs via inner CV)
%   - Statistics and Machine Learning Toolbox (plsregress, dummyvar)
%
% NOTES:
%   - Code logic unchanged; comments translated to English only.
%   - If explained variance of Y is near zero, returns zeros for VIP.
%
% AUTHOR: J. Alonso
% DATE: 16-Aug-2025
% SPDX-License-Identifier: CC-BY-4.0
% Version: 2.0.0 (comments translated; no logic changes)
%% ------------------------------------------------------------------------

function [vip_tr, opt_ncomp] = compute_vip_on_train(Xtr, Ytr, max_lvs, k_inner)
    % Optimize ncomp via inner CV and return VIP on the full train (Xtr)
    k_inner_eff = min(k_inner, max(2, min(countcats(Ytr))));
    opt_ncomp = optimize_pls_components(Xtr, Ytr, max_lvs, k_inner_eff);
    [~,~,~,~,~,PCTVAR,~,stats] = plsregress(Xtr, dummyvar(Ytr), opt_ncomp);
    p = size(Xtr,2);
    q = sum(PCTVAR(2,:));
    if q > 1e-6
        vip_sq = p * sum(bsxfun(@times, stats.W.^2, PCTVAR(2,:)), 2) / q;
        vip_tr = sqrt(vip_sq);
    else
        vip_tr = zeros(p,1);
    end
end
