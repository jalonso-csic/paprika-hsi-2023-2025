%% ------------------------------------------------------------------------
% File: metrics_from_preds.m
% Title: Compute accuracy, balanced accuracy, and confusion matrix
%
% PURPOSE:
%   Given ground-truth and predicted categorical labels (aligned to the same
%   class set), compute:
%     - overall accuracy,
%     - balanced accuracy (mean sensitivity across classes),
%     - confusion matrix (rows = true, cols = predicted).
%
% INPUTS:
%   Ytrue   - (n x 1) categorical ground-truth labels
%   Yhat    - (n x 1) categorical predicted labels
%   classes - cellstr or categorical categories defining class order
%
% OUTPUTS:
%   acc     - overall accuracy
%   balacc  - balanced accuracy (mean per-class sensitivity/recall)
%   cm      - confusion matrix (#classes x #classes)
%
% DEPENDENCIES:
%   - Statistics and Machine Learning Toolbox (confusionmat)
%
% NOTES:
%   - Code logic unchanged; comments translated to English only.
%   - Uses setcats to ensure identical class order before confusionmat.
%
% AUTHOR: J. Alonso
% DATE: 16-Aug-2025
% SPDX-License-Identifier: CC-BY-4.0
% Version: 2.0.0 (comments translated; no logic changes)
%% ------------------------------------------------------------------------

function [acc, balacc, cm] = metrics_from_preds(Ytrue, Yhat, classes)
    Ytrue = setcats(Ytrue, classes);
    Yhat  = setcats(Yhat, classes);
    cm = confusionmat(Ytrue, Yhat, 'Order', classes);
    acc = sum(diag(cm)) / max(1, sum(cm(:)));
    sens = diag(cm) ./ max(1, sum(cm, 2));
    balacc = mean(sens, 'omitnan');
end
