%% --- PREPROCESSING ANALYSIS AND PCA SCORES (FINAL VERSION, LIGHT THEME) ---
%
% OBJECTIVE:
% Perform a comparative preprocessing analysis, generate PCA score plots
% with white background, and leave all figures open for editing.
%
clear; clc; close all;

%% 1) ANALYSIS CONFIGURATION
filename = 'FX17_con_bioquimicos_PUBLIC.xlsx';   % <— cleaned file without EMPRESA
ncomp_pls = 5;

% Preprocessing parameters
sg_poly_order = 2;
sg_window_size = 11;
baseline_order = 3;

%% 2) PLOTTING CONFIGURATION
font_config.GlobalFontName  = 'Times New Roman';
font_config.TitleFontSize   = 14;
font_config.LabelFontSize   = 12;
font_config.AxisFontSize    = 10;
font_config.LegendFontSize  = 10;
font_config.TitleFontWeight = 'bold';
font_config.LabelFontWeight = 'normal';

% Force light theme by default (figures and axes)
set(0, 'DefaultFigureColor','w', ...
       'DefaultAxesColor','w', ...
       'DefaultAxesXColor','k', ...
       'DefaultAxesYColor','k', ...
       'DefaultAxesGridColor',[0.5 0.5 0.5]);

%% 3) FILES AND DATA PREPARATION
output_folder = 'Resultados_PCA_Finales_FX17';
XLS_Preproc = fullfile(output_folder, 'Datos_Preprocesados_FX17.xlsx');
XLS_Summary = fullfile(output_folder, 'Resumen_Resultados.xlsx');
figdir_pca = fullfile(output_folder, 'Figuras_PCA_Scores');

fprintf('Loading data from "%s"...\n', filename);
if ~exist(output_folder,'dir'), mkdir(output_folder); end
if ~exist(figdir_pca,'dir'), mkdir(figdir_pca); end

T = readtable(filename, 'VariableNamingRule', 'preserve');

is_spec = startsWith(T.Properties.VariableNames, 'R_');
assert(any(is_spec), 'No spectral columns with prefix "R_" were found');
spectral_col_names = T.Properties.VariableNames(is_spec);
X_raw = table2array(T(:, is_spec));
metadata = T(:, ~is_spec);
fprintf('%d samples and %d spectral bands loaded.\n', size(X_raw,1), size(X_raw,2));

% Grouping column (prioritize Año as before)
grouping_col_cands = {'Año', 'Anio', 'Year', 'Tratamiento'};
grouping_col = '';
for k=1:numel(grouping_col_cands)
    if ismember(grouping_col_cands{k}, T.Properties.VariableNames)
        grouping_col = grouping_col_cands{k};
        break;
    end
end
assert(~isempty(grouping_col), 'No valid grouping column found (e.g., "Año").');
Y = T.(grouping_col);
classNames = unique(Y);
Y_categorical = categorical(Y, classNames);
fprintf('Classification column is "%s" with %d classes.\n\n', grouping_col, numel(classNames));

%% 4) METHODS AND FUNCTIONS DEFINITION
snv = @(x) (x - mean(x,2)) ./ std(x,0,2);
preproc_list = {
    'Raw Reflectance',        @(x) x;
    'SNV',                    @(x) snv(x);
    'MSC (Corrected)',        @(x) msc_corrected(x);
    'Mean Centering',         @(x) x - mean(x, 1);
    'Baseline (Poly)',        @(x) baseline_corrected(x, baseline_order);
    '1st Derivative (SG)',    @(x) diff(sgolayfilt(x,sg_poly_order,sg_window_size),1,2);
    '2nd Derivative (SG)',    @(x) diff(sgolayfilt(x,sg_poly_order,sg_window_size),2,2);
    'SNV + 1st Derivative',   @(x) diff(sgolayfilt(snv(x),sg_poly_order,sg_window_size),1,2);
    'MSC + 1st Derivative',   @(x) diff(sgolayfilt(msc_corrected(x),sg_poly_order,sg_window_size),1,2);
    'SNV + 2nd Derivative',   @(x) diff(sgolayfilt(snv(x),sg_poly_order,sg_window_size),2,2);
    'MSC + 2nd Derivative',   @(x) diff(sgolayfilt(msc_corrected(x),sg_poly_order,sg_window_size),2,2);
};

%% 5) MAIN COMPARATIVE ANALYSIS LOOP
% (EXCLUSIVE) Increase to 7 columns to add Silhouette_Overall
results = cell(size(preproc_list,1), 7);
fprintf('Starting comparative analysis...\n');

% Clean/create output Excel files
if exist(XLS_Preproc,'file'), delete(XLS_Preproc); end
if exist(XLS_Summary,'file'), delete(XLS_Summary); end

for i = 1:size(preproc_list,1)
    method = preproc_list{i,1};
    method_clean = matlab.lang.makeValidName(method);
    fprintf('Processing: %s...\n', method);
    
    X_proc = preproc_list{i,2}(X_raw);

    % Align band names for derivatives
    if contains(method, '2nd')
        wl_names_use = spectral_col_names(3:end);
    elseif contains(method, '1st')
        wl_names_use = spectral_col_names(2:end);
    else
        wl_names_use = spectral_col_names;
    end
    
    % Save preprocessed data (safe sheet name)
    T_proc = array2table(X_proc, 'VariableNames', wl_names_use);
    writetable([metadata, T_proc], XLS_Preproc, ...
        'Sheet', safe_sheet(method,'Preproc'), 'WriteMode','overwritesheet');
    
    % PCA (centering by default)
    [~, score, ~, ~, explained] = pca(X_proc);
    pc1var = explained(1);
    pc2var = explained(2);

    % ====== (EXCLUSIVE) SEPARATION METRIC: SILHOUETTE (PC1–PC2) ======
    try
        s_vals = silhouette(score(:,1:2), Y_categorical);   % requires Statistics Toolbox
        sil_overall = mean(s_vals);
    catch
        sil_overall = NaN;
    end
    % =================================================================
    
    plot_gname = strrep(grouping_col, 'Año', 'Year');
    outpath_base_pca = fullfile(figdir_pca, ['PCA_' method_clean]);
    pca_scores_plot(score, explained, Y_categorical, plot_gname, method, outpath_base_pca, font_config);

    % Quick outliers (chi2 in PC1–PC2)
    alpha = 0.05;
    [~, p] = size(score(:,1:2));
    chi2val = chi2inv(1-alpha, p);
    mahal_dist = mahal(score(:,1:2), score(:,1:2));
    outlier_idx = mahal_dist > chi2val;

    outlier_indices = find(outlier_idx);
    if isempty(outlier_indices)
        outliers_str = '-';
    else
        outlier_details = arrayfun(@(id, year) sprintf('%d (%d)', id, year), outlier_indices, Y(outlier_indices), 'UniformOutput', false);
        outliers_str = strjoin(outlier_details, ', ');
    end
    
    % Quick PLS-DA (as before)
    X_pls = X_proc(~outlier_idx,:);
    Y_pls = Y_categorical(~outlier_idx);
    Y_dummy = dummyvar(Y_pls);

    cv = cvpartition(length(Y_pls),'LeaveOut');
    acc = zeros(cv.NumTestSets,1);
    for k = 1:cv.NumTestSets
        Xtrain = X_pls(cv.training(k),:);
        Ytrain = Y_dummy(cv.training(k),:);
        Xtest = X_pls(cv.test(k),:);
        Ytest = Y_dummy(cv.test(k),:);
        [~,~,~,~,BETA] = plsregress(Xtrain, Ytrain, ncomp_pls);
        Ypred = [ones(size(Xtest,1),1) Xtest]*BETA;
        [~,idx_true] = max(Ytest,[],2);
        [~,idx_pred] = max(Ypred,[],2);
        acc(k) = (idx_true == idx_pred);
    end
    acc_pct = 100*mean(acc);
    
    % (EXCLUSIVE) Save results with Silhouette_Overall as the last column
    results{i,1} = method;
    results{i,2} = pc1var;
    results{i,3} = pc2var;
    results{i,4} = acc_pct;
    results{i,5} = sum(outlier_idx);
    results{i,6} = outliers_str;
    results{i,7} = sil_overall;   % NEW
end

%% 6) PRINTING AND EXPORTING RESULTS
results_table = cell2table(results, 'VariableNames', ...
    {'Preprocessing', 'PC1_Var_Pct', 'PC2_Var_Pct', 'PLS_DA_Acc_Pct', 'Num_Outliers', 'ID_Outliers', 'Silhouette_Overall'});

results_table = sortrows(results_table, 'PLS_DA_Acc_Pct', 'descend');
writetable(results_table, XLS_Summary);

fprintf('\n\n--- RESULTS TABLE ---\n');
disp(results_table);
fprintf('\nAnalysis completed.\n');
fprintf('Preprocessed data saved to: %s\n', XLS_Preproc);
fprintf('Summary saved to: %s\n', XLS_Summary);
fprintf('PCA figures (.jpg and .fig) saved to: %s\n', figdir_pca);
fprintf('All .fig figures have been opened for editing.\n');

%% 7) AUXILIARY FUNCTIONS
function X_msc = msc_corrected(X)
    ref_spec = mean(X, 1);
    X_msc = zeros(size(X));
    for i = 1:size(X, 1)
        p = polyfit(ref_spec, X(i,:), 1);
        X_msc(i,:) = (X(i,:) - p(2)) / p(1);
    end
end

function X_bc = baseline_corrected(X, order)
    X_bc = zeros(size(X));
    x_axis = 1:size(X,2);
    for i = 1:size(X,1)
        p = polyfit(x_axis, X(i,:), order);
        baseline = polyval(p, x_axis);
        X_bc(i,:) = X(i,:) - baseline;
    end
end

% --- PLOTTING FUNCTIONS ---
function pca_scores_plot(score, expl, groups, gname, mname, outpath_base, font_config)
    f = figure('Color','w', 'Visible', 'off');
    ax = gca;
    set(ax, 'Color','w', 'XColor','k', 'YColor','k', 'GridColor',[0.5 0.5 0.5], 'GridAlpha',0.2);
    hold(ax,'on'); grid(ax,'on'); box(ax,'on');
    
    cats = categories(groups);
    cmap = lines(numel(cats)); 
    marker_size = 60;
    
    for i=1:numel(cats)
        idx = (groups==cats{i});
        scatter(score(idx,1), score(idx,2), marker_size, cmap(i,:), 'filled');
    end
    axis tight;
    
    legend_labels = strrep(cats, '_', ' ');
    h_leg = legend(ax, legend_labels,'Location','best');
    h_leg.Title.String = gname;

    set(h_leg, 'Color','w', 'EdgeColor',[0.7 0.7 0.7], ...
               'FontSize', font_config.LegendFontSize, ...
               'FontName', font_config.GlobalFontName, ...
               'TextColor','k');
    h_leg.Title.Color = 'k';

    xlabel(sprintf('PC1 (%.2f%%)', expl(1)));
    ylabel(sprintf('PC2 (%.2f%%)', expl(2)));
    title(sprintf('PCA Scores - %s', mname), 'Interpreter', 'none', 'Color', 'k');
    
    set(ax, 'FontName', font_config.GlobalFontName, 'FontSize', font_config.AxisFontSize);
    ax.Title.FontSize = font_config.TitleFontSize;
    ax.Title.FontWeight = font_config.TitleFontWeight;
    ax.XLabel.FontSize = font_config.LabelFontSize;
    ax.XLabel.FontWeight = font_config.LabelFontWeight;
    ax.YLabel.FontSize = font_config.LabelFontSize;
    ax.YLabel.FontWeight = font_config.LabelFontWeight;
    
    clean_export(f, outpath_base);
end

function clean_export(f, pathout_base)
    drawnow;
    exportgraphics(f, [pathout_base '.jpg'], 'Resolution', 300);
    savefig(f, [pathout_base '.fig']);
    set(f, 'Visible', 'on'); % Leave figure open for editing
end

function sheet = safe_sheet(baseLabel, suffixLabel)
    persistent usedSheets
    if isempty(usedSheets)
        usedSheets = containers.Map('KeyType','char','ValueType','logical');
    end

    MAXLEN = 31;
    base = matlab.lang.makeValidName(char(baseLabel));
    sfx  = matlab.lang.makeValidName(char(suffixLabel));
    name = [base '_' sfx];

    name = regexprep(name, '[\\/:?*\[\]]', '');
    name = regexprep(name, '_+', '_');

    if isempty(name), name = 'Sheet'; end
    if numel(name) > MAXLEN, name = name(1:MAXLEN); end

    cand = name; k = 1;
    while isKey(usedSheets, cand)
        suf = ['_' num2str(k)];
        baseLen = MAXLEN - numel(suf);
        baseLen = max(1, min(baseLen, numel(name)));
        cand = [name(1:baseLen) suf];
   	    k = k + 1;
    end

    usedSheets(cand) = true;
    sheet = cand;
end
