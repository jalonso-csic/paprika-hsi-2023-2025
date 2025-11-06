%% ------------------------------------------------------------------------
% File: fx10_supervised_hsi_nestedcv_refactor_v2.m
% Title: SUPERVISED HYPERSPECTRAL ANALYSIS (FX10) — Refactored Version v2
%
% PURPOSE:
%   - Supervised HSI analysis for FX10 using repeated nested cross-validation.
%   - Models: PLS-DA (with/without VIP), SVM (linear/RBF, VIP), optional PCA+SVM baseline.
%
% DESCRIPTION:
%   - Fixed MATLAB Code Analyzer warnings.
%   - Improved performance via preallocation and parfor optimization.
%
% OUTPUTS:
%   - Excel report per sheet: Analysis_Info, Summary_Metrics, Paired_Tests, VIP_Stability,
%     PerFold_Results, and CM_<best_model>.
%   - Figures: boxplot of balanced accuracy; VIP stability bar plot (.png and .fig).
%
% DEPENDENCIES:
%   - Statistics and Machine Learning Toolbox, Parallel Computing Toolbox.
%   - Helper functions on MATLAB path: eval_plsda_once, eval_svm_once, eval_pca_svm_once,
%     select_setting_inner_cv, compute_vip_on_train, make_selection_mask, summarize_metrics,
%     paired_tests, build_stability_table, long_metrics_table, collect_field.
%
% AUTHOR: J. Alonso
% DATE: 16-Aug-2025
%% ------------------------------------------------------------------------

%% ------------------------------------------------------------------------
clear; clc; close all;

%% Reproducibility & Appearance
rng(42, 'twister');
set(groot, 'defaultFigureColor', 'w', 'defaultAxesColor', 'w', ...
    'defaultAxesXColor', 'k', 'defaultAxesYColor', 'k', 'defaultAxesZColor', 'k', ...
    'defaultTextColor', 'k', 'defaultFigureInvertHardcopy', 'off', ...
    'defaultAxesFontName', 'Times New Roman', 'defaultTextFontName', 'Times New Roman');
try
    set(groot, 'DefaultAxesToolbarVisible', 'off');
catch
end

%% ---------------------------- CONFIGURATION -----------------------------
% --- General Parameters ---
% Cambia esta línea:
cfg.data_file = 'Datos_Preprocesados_FX10.xlsx';
cfg.cam_name    = 'FX10';
cfg.sheets_to_process = {'MSC_1_Derivada_Preproc', 'SNV_1_Derivada_Preproc', 'x1_Derivada_SG_Preproc'};

% --- Outputs ---
cfg.output_folder = fullfile(pwd, 'FX10_Results');  % subfolder in current MATLAB folder

% --- Cross-Validation (CV) ---
cfg.k_outer         = 10; % Outer folds
cfg.repetitions     = 10; % CV repetitions
cfg.k_inner         = 5;  % Inner folds for tuning/selection

% --- Models & Feature Selection ---
cfg.max_lvs         = 15;           % PLS-DA: max LVs to explore
cfg.vip_thresholds  = [0.8 1 1.2];  % VIP thresholds to test
cfg.topK_grid       = [20 40];      % Top-K (by VIP) to test
cfg.ensure_minK     = 10;           % Minimum number of variables if filter too strict

% --- SVM-RBF ---
cfg.rbf_eval_budget = 20; % Evaluations for Bayesian optimization

% --- Baseline PCA+SVM ---
cfg.enable_pca_baseline = true;
cfg.pca_k_grid          = [5 10 20 40]; % Number of PCs to test

% --- Utilities ---
% Function to sanitize Excel sheet names (<=31 chars, forbid special chars)
sanSheet = @(s) regexprep(s(1:min(31, numel(s))), '[:\\/*?\[\]]', '_');

%% -------------------------- MAIN PROCESS ---------------------------
if ~exist(cfg.output_folder, 'dir'), mkdir(cfg.output_folder); end
total_tic = tic;

for m = 1:numel(cfg.sheets_to_process)
    sheet_name = cfg.sheets_to_process{m};
    sheet_tic = tic;
    fprintf('\n==========================================================\n');
    fprintf('=== Processing %s - Sheet: %s ===\n', cfg.cam_name, sheet_name);
    fprintf('==========================================================\n');

    % --- Load & prepare data ---
    try
        T_all = readtable(cfg.data_file, 'Sheet', sheet_name, 'VariableNamingRule', 'preserve');
    catch ME
        warning('Failed to read sheet "%s": %s. Skipping.', sheet_name, ME.message);
        continue;
    end

    if ~ismember('camara', T_all.Properties.VariableNames)
        error('Missing "camara" column in sheet %s.', sheet_name);
    end
    T = T_all(strcmp(T_all.camara, cfg.cam_name), :);

    if isempty(T)
        warning('No rows for camera %s in %s. Skipping.', cfg.cam_name, sheet_name);
        continue;
    end

    is_spec = startsWith(T.Properties.VariableNames, 'R_');
    X = table2array(T(:, is_spec));
    band_names = T.Properties.VariableNames(is_spec);
    wavelengths_str = strrep(strrep(band_names, 'R_', ''), '_', '.');
    wavelengths = str2double(wavelengths_str);

    if ismember('Treatment', T.Properties.VariableNames)
        Y = categorical(T.Treatment);
    elseif ismember('Año', T.Properties.VariableNames)
        Y = categorical(T.('Año'));
    elseif ismember('Anio', T.Properties.VariableNames)
        Y = categorical(T.('Anio'));
    else
        error('No valid class column found (Treatment/Año/Anio).');
    end

    bad = any(~isfinite(X), 2) | isundefined(Y);
    if any(bad)
        X = X(~bad, :);
        Y = removecats(Y(~bad));
        T = T(~bad, :);
        fprintf('Removed %d rows with invalid values.\n', sum(bad));
    end

    classes = categories(Y);
    G = numel(classes);
    if G < 2
        warning('Fewer than two classes present. Skipping %s.', sheet_name);
        continue;
    end

    % Adjust k_outer if a class has very few members
    counts = countcats(Y);
    k_eff = min(cfg.k_outer, max(2, min(counts)));
    if k_eff ~= cfg.k_outer
        fprintf('k_outer adjusted to %d due to minority class size.\n', k_eff);
    end

    % ----- NEW, FIXED BLOCK -----
    base_models = { ...
        struct('tag', 'PLS_ALL',     'selector', 'none', 'eval_func', @eval_plsda_once, 'opts', struct('max_lvs', cfg.max_lvs, 'k_inner', cfg.k_inner)), ...
        struct('tag', 'PLS_VIP',     'selector', 'pls',  'eval_func', @eval_plsda_once, 'opts', struct('max_lvs', cfg.max_lvs, 'k_inner', cfg.k_inner)), ...
        struct('tag', 'SVM_LIN_ALL', 'selector', 'none', 'eval_func', @eval_svm_once, 'opts', struct('kernel', 'linear', 'k_inner', cfg.k_inner, 'optcfg', [])), ...
        struct('tag', 'SVM_LIN_VIP', 'selector', 'svm',  'eval_func', @eval_svm_once, 'opts', struct('kernel', 'linear', 'k_inner', cfg.k_inner, 'optcfg', [])), ...
        struct('tag', 'SVM_RBF_VIP', 'selector', 'svm',  'eval_func', @eval_svm_once, 'opts', struct('kernel', 'rbf', 'k_inner', cfg.k_inner, 'optcfg', struct('MaxObjectiveEvaluations', cfg.rbf_eval_budget))) ...
    };
    if cfg.enable_pca_baseline
        pca_model_def = {struct('tag', 'PCA_SVM_LIN', 'selector', 'pca', 'eval_func', @eval_pca_svm_once, 'opts', struct('k_inner', cfg.k_inner, 'pca_k_grid', cfg.pca_k_grid))};
        model_definitions = [base_models, pca_model_def];
    else
        model_definitions = base_models;
    end
    model_tags = cellfun(@(c) c.tag, model_definitions, 'UniformOutput', false);
    M = numel(model_tags);

    % --- Preallocated containers for results ---
    num_folds_total = cfg.repetitions * k_eff;
    all_metrics = struct();
    for i = 1:M
        all_metrics.(model_tags{i}).acc    = nan(num_folds_total, 1);
        all_metrics.(model_tags{i}).balacc = nan(num_folds_total, 1);
    end
    cm_sum_by_model = containers.Map;
    for mt = 1:M
        cm_sum_by_model(model_tags{mt}) = zeros(G, G);
    end
    vip_stability_count = zeros(size(X, 2), 1);
    vip_stability_total = 0;

    % --- Grid for feature selection in inner CV (preallocated) ---
    num_sel_opts = 1 + numel(cfg.vip_thresholds) + numel(cfg.topK_grid);
    sel_grid = cell(1, num_sel_opts);
    idx = 1;
    sel_grid{idx} = struct('mode', 'none', 'desc', 'No selection');
    idx = idx + 1;
    for v = 1:numel(cfg.vip_thresholds)
        sel_grid{idx} = struct('mode', 'vip_thr', 'thr', cfg.vip_thresholds(v), 'desc', sprintf('VIP>=%.2f', cfg.vip_thresholds(v)));
        idx = idx + 1;
    end
    for k = 1:numel(cfg.topK_grid)
        sel_grid{idx} = struct('mode', 'topk', 'topk', cfg.topK_grid(k), 'desc', sprintf('Top-%d (VIP)', cfg.topK_grid(k)));
        idx = idx + 1;
    end

    %% ======================= REPEATED CV (PARALLELIZED) =================
    % Local variables to optimize `parfor` (avoid broadcast)
    p_repetitions = cfg.repetitions;
    p_k_inner = cfg.k_inner;
    p_max_lvs = cfg.max_lvs;
    p_ensure_minK = cfg.ensure_minK;
    p_model_definitions = model_definitions; % send explicit copy
    
    parfor_results = cell(p_repetitions, 1);

    parfor rep = 1:p_repetitions
        fprintf('Starting Repetition %d/%d...\n', rep, p_repetitions);
        rng(1000 + rep, 'twister'); % different seed per repetition
        cv_outer = cvpartition(Y, 'KFold', k_eff, 'Stratify', true);
        
        % Local accumulators for this repetition
        local_metrics = struct();
        local_model_tags = cellfun(@(c) c.tag, p_model_definitions, 'UniformOutput', false);
        for i = 1:numel(local_model_tags)
            local_metrics.(local_model_tags{i}).acc    = nan(k_eff, 1);
            local_metrics.(local_model_tags{i}).balacc = nan(k_eff, 1);
            local_metrics.(local_model_tags{i}).cm     = zeros(G, G, k_eff);
        end
        local_vip_count = zeros(size(X, 2), 1);
        local_vip_total = 0;

        for fold = 1:k_eff
            idx_tr = training(cv_outer, fold);
            idx_te = test(cv_outer, fold);
            Xtr = X(idx_tr, :); Ytr = Y(idx_tr);
            Xte = X(idx_te, :); Yte = Y(idx_te);

            % --- Inner CV for Feature Selection ---
            best_sel_pls = select_setting_inner_cv(Xtr, Ytr, p_k_inner, p_max_lvs, sel_grid, 'PLS');
            best_sel_svm = select_setting_inner_cv(Xtr, Ytr, p_k_inner, p_max_lvs, sel_grid, 'SVM');

            [vip_tr, ~] = compute_vip_on_train(Xtr, Ytr, p_max_lvs, p_k_inner);
            sel_mask_pls = make_selection_mask(vip_tr, best_sel_pls, p_ensure_minK);
            sel_mask_svm = make_selection_mask(vip_tr, best_sel_svm, p_ensure_minK);
            
            if ~strcmp(best_sel_svm.mode, 'none')
                local_vip_count = local_vip_count + double(sel_mask_svm(:));
                local_vip_total = local_vip_total + 1;
            end
            
            % --- Model evaluation loop ---
            for mod_idx = 1:numel(p_model_definitions)
                model = p_model_definitions{mod_idx};
                
                switch model.selector
                    case 'pls'
                        Xtr_s = Xtr(:, sel_mask_pls); Xte_s = Xte(:, sel_mask_pls);
                    case 'svm'
                        Xtr_s = Xtr(:, sel_mask_svm); Xte_s = Xte(:, sel_mask_svm);
                    otherwise % 'none' or 'pca'
                        Xtr_s = Xtr; Xte_s = Xte;
                end
                
                [acc, balacc, cm] = model.eval_func(Xtr_s, Ytr, Xte_s, Yte, model.opts);
                
                local_metrics.(model.tag).acc(fold) = acc;
                local_metrics.(model.tag).balacc(fold) = balacc;
                local_metrics.(model.tag).cm(:, :, fold) = cm;
            end
        end % end fold
        
        parfor_results{rep}.metrics = local_metrics;
        parfor_results{rep}.vip_count = local_vip_count;
        parfor_results{rep}.vip_total = local_vip_total;

    end % end parfor (repetitions)

    % --- Consolidate parallel execution results ---
    for rep = 1:cfg.repetitions
        start_idx = (rep - 1) * k_eff + 1;
        end_idx   = rep * k_eff;
        
        for i = 1:M
            tag = model_tags{i};
            all_metrics.(tag).acc(start_idx:end_idx) = parfor_results{rep}.metrics.(tag).acc;
            all_metrics.(tag).balacc(start_idx:end_idx) = parfor_results{rep}.metrics.(tag).balacc;
            cm_sum_by_model(tag) = cm_sum_by_model(tag) + sum(parfor_results{rep}.metrics.(tag).cm, 3);
        end
        vip_stability_count = vip_stability_count + parfor_results{rep}.vip_count;
        vip_stability_total = vip_stability_total + parfor_results{rep}.vip_total;
    end
    
    %% ==================== SUMMARY & REPORTS =====================
    fprintf('Generating reports and figures for %s...\n', sheet_name);
    
    % --- Summary tables ---
    summary_tbl   = summarize_metrics(all_metrics, model_tags);
    tests_tbl     = paired_tests(all_metrics, model_tags, 'balacc');
    stability_tbl = build_stability_table(band_names, wavelengths, vip_stability_count, vip_stability_total);
    perfold_tbl   = long_metrics_table(all_metrics, model_tags, cfg.repetitions, k_eff);
    
    % --- Best model & Confusion Matrix ---
    [~, best_idx] = max(summary_tbl.Mean_BalAcc);
    best_model_tag = summary_tbl.Model{best_idx};
    best_cm_sum = cm_sum_by_model(best_model_tag);
    cm_tbl = array2table(best_cm_sum, 'RowNames', cellstr(classes), 'VariableNames', cellstr(classes));

    % --- Export to Excel ---
    out_xlsx = fullfile(cfg.output_folder, sprintf('%s_%s_Report.xlsx', cfg.cam_name, sheet_name));
    writetable(table(string(datetime('now')), string(cfg.cam_name), string(sheet_name), cfg.repetitions, k_eff, ...
        'VariableNames', {'Analysis_Date', 'Camera', 'Sheet', 'CV_Repetitions', 'CV_Kfold'}), out_xlsx, 'Sheet', sanSheet('Analysis_Info'));
    writetable(summary_tbl, out_xlsx, 'Sheet', sanSheet('Summary_Metrics'));
    writetable(tests_tbl,   out_xlsx, 'Sheet', sanSheet('Paired_Tests'));
    writetable(stability_tbl, out_xlsx, 'Sheet', sanSheet('VIP_Stability'));
    writetable(perfold_tbl, out_xlsx, 'Sheet', sanSheet('PerFold_Results'));
    writetable(cm_tbl, out_xlsx, 'Sheet', sanSheet(['CM_' best_model_tag]), 'WriteRowNames', true);
    
    % --- Figures ---
    base_title = sprintf('%s - %s', cfg.cam_name, strrep(sheet_name, '_', ' '));
    
    % Boxplot of Balanced Accuracy
    f1 = figure('Visible', 'off');
    boxplot(collect_field(all_metrics, model_tags, 'balacc'), 'Labels', strrep(model_tags, '_', ' '));
    ylabel('Balanced Accuracy'); title(sprintf('%s\nBalanced Accuracy by Model', base_title));
    ax = gca; ax.XTickLabelRotation = 30; ax.FontSize = 10;
    exportgraphics(ax, fullfile(cfg.output_folder, sprintf('%s_%s_boxplot_balacc.png', cfg.cam_name, sheet_name)), 'Resolution', 300);
    savefig(f1, fullfile(cfg.output_folder, sprintf('%s_%s_boxplot_balacc.fig', cfg.cam_name, sheet_name)));
    close(f1);

    % VIP Stability Bar Plot
    f2 = figure('Visible', 'off');
    topN = min(20, height(stability_tbl));
    if topN > 0 && vip_stability_total > 0
        bar(stability_tbl.Selection_Frequency(1:topN));
        ax = gca;
        set(ax, 'XTick', 1:topN, 'XTickLabel', round(stability_tbl.Wavelength_nm(1:topN)), 'XTickLabelRotation', 45);
        xlabel('Wavelength (nm)'); ylabel('Selection Frequency');
        title(sprintf('%s\nVIP Selection Stability (Top-%d)', base_title, topN));
        ax.FontSize = 10;
        exportgraphics(ax, fullfile(cfg.output_folder, sprintf('%s_%s_vip_stability.png', cfg.cam_name, sheet_name)), 'Resolution', 300);
        savefig(f2, fullfile(cfg.output_folder, sprintf('%s_%s_vip_stability.fig', cfg.cam_name, sheet_name)));
    end
    close(f2);

    fprintf('Sheet "%s" analysis completed in %.2f minutes.\n', sheet_name, toc(sheet_tic)/60);
end

fprintf('\nProcess finished in %.2f minutes. Results saved to: %s\n', toc(total_tic)/60, cfg.output_folder);
