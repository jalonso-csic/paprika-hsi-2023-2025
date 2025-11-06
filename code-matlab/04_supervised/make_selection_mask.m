%% ------------------------------------------------------------------------
% File: make_selection_mask.m
% Title: Build boolean mask from a feature-selection setting (VIP-based)
%
% PURPOSE:
%   Create a logical mask of selected variables according to the provided
%   selection policy:
%     - 'none'   : keep all variables
%     - 'vip_thr': select VIP >= threshold; enforce a minimum K if too strict
%     - 'topk'   : select the Top-K variables by VIP
%
% INPUTS:
%   vip          - (p x 1) VIP scores
%   setting      - struct describing the policy:
%                  .mode  -> 'none' | 'vip_thr' | 'topk'
%                  .thr   -> (if 'vip_thr') numeric threshold
%                  .topk  -> (if 'topk') integer Top-K
%   ensure_minK  - minimum number of variables to keep when 'vip_thr' yields too few
%
% OUTPUTS:
%   mask - (p x 1) logical vector indicating selected variables
%
% NOTES:
%   - Code logic unchanged; comments translated to English only.
%   - Ties in sorting follow MATLAB's default behavior.
%
% AUTHOR: J. Alonso
% DATE: 16-Aug-2025
% SPDX-License-Identifier: CC-BY-4.0
% Version: 2.0.0 (comments translated; no logic changes)
%% ------------------------------------------------------------------------

function mask = make_selection_mask(vip, setting, ensure_minK)
    p = numel(vip);
    switch setting.mode
        case 'none'
            mask = true(p,1);
        case 'vip_thr'
            mask = (vip >= setting.thr);
            if sum(mask) < ensure_minK
                [~,ord] = sort(vip, 'descend');
                mask = false(p,1);
                mask(ord(1:min(ensure_minK, p))) = true;
            end
        case 'topk'
            [~,ord] = sort(vip, 'descend');
            k = min(setting.topk, p);
            mask = false(p,1);
            mask(ord(1:k)) = true;
        otherwise
            mask = true(p,1);
    end
end
