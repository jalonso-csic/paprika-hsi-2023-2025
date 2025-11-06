function plot_confusion_tripanel_fx10_autodetect()
% Tripanel of confusion matrices – FX10 (VIS–NIR)
% Auto-detects the sheet 'CM_<best_model>' or the first available 'CM_*'.
% Publication-style aesthetics: Times (10/12 pt), A/B/C panels, shared colorbar.
%
% Outputs:
%   FX10_confusion_matrices_tripanel.png (600 dpi)
%   FX10_confusion_matrices_tripanel.pdf (vector)

% ------------------ Inputs ------------------
files = { ...
  'FX10_MSC_1_Derivada_Preproc_Report.xlsx', ...
  'FX10_SNV_1_Derivada_Preproc_Report.xlsx', ...
  'FX10_x1_Derivada_SG_Preproc_Report.xlsx' };

titles = { 'MSC + 1st derivative', 'SNV + 1st derivative', 'SG 1st derivative' };
out_png = 'FX10_confusion_matrices_tripanel.png';
out_pdf = 'FX10_confusion_matrices_tripanel.pdf';

% Show row-wise percentages instead of counts (optional)
asPercent = false;

% ------------------ Global appearance ------------------
set(groot,'defaultFigureColor','w', ...
          'defaultAxesFontName','Times New Roman', ...
          'defaultTextFontName','Times New Roman', ...
          'defaultAxesFontSize',10, ...
          'defaultTextColor','k', ...
          'defaultAxesLineWidth',0.8);

% ------------------ Utilities ------------------
getSheets = @(f) get_sheetnames_compat(f); % wrapper for sheetnames/xlsfinfo
stripx = @(s) regexprep(s, '^x', '');      % remove 'x' prefix (x2023 -> 2023)

% ------------------ Load CMs with auto-detection ------------------
CMs = cell(1,3);
rowLabs = cell(1,3);
colLabs = cell(1,3);

for i = 1:3
    f = files{i};
    sheets = getSheets(f);

    % 1) Try to locate best model in Summary_Metrics
    bestSheet = '';
    try
        SM = readtable(f, 'Sheet', 'Summary_Metrics');
        if ismember('Model', SM.Properties.VariableNames) && ismember('Mean_BalAcc', SM.Properties.VariableNames)
            [~, idx] = max(SM.Mean_BalAcc);
            bestTag = SM.Model{idx};
            cand = ['CM_' char(bestTag)];
            hasCand = any(strcmpi(sheets, cand)); % case-insensitive
            if hasCand
                bestSheet = sheets{find(strcmpi(sheets, cand),1,'first')};
            end
        end
    catch
        % no Summary_Metrics, fallback to 2)
    end

    % 2) If no bestSheet, take the first 'CM_*'
    if isempty(bestSheet)
        cmMask = startsWith(lower(sheets), 'cm_');
        if ~any(cmMask)
            error('No "CM_*" sheet found in: %s', f);
        end
        bestSheet = sheets{find(cmMask,1,'first')};
    end

    % Read CM table with row names (classes)
    T = readtable(f, 'Sheet', bestSheet, 'ReadRowNames', true);

    % Extract matrix and labels
    M = T{:,:};
    rNames = T.Properties.RowNames;
    cNames = T.Properties.VariableNames;

    % Clean labels (remove 'x' prefix)
    rNames = cellfun(stripx, rNames, 'UniformOutput', false);
    cNames = cellfun(stripx, cNames, 'UniformOutput', false);

    % Store
    CMs{i}    = M;
    rowLabs{i}= rNames;
    colLabs{i}= cNames;
end

% ------------------ Color range ------------------
if asPercent
    for i = 1:3
        rowsum = sum(CMs{i}, 2);
        CMs{i} = 100 * (CMs{i} ./ max(rowsum,1)); % % per row
    end
    climVals  = [0 100];
    cbarLabel = 'Row-wise %';
else
    maxCount  = max(cellfun(@(M) max(M(:)), CMs));
    climVals  = [0 maxCount];
    cbarLabel = 'Number of samples';
end

% ------------------ Plot ------------------
fig = figure('Units','pixels','Position',[100 100 1300 450]);
tl  = tiledlayout(fig, 1, 3, 'TileSpacing','compact', 'Padding','compact');

for i = 1:3
    ax = nexttile(tl, i);
    M  = CMs{i};
    imagesc(M); set(ax,'YDir','normal'); colormap(ax, parula);
    clim(ax, climVals); axis(ax,'image'); box(ax,'on');

    n = size(M,1);
    xticks(1:n); yticks(1:n);
    if numel(colLabs{i})==n, xticklabels(colLabs{i}); else, xticklabels(1:n); end
    if numel(rowLabs{i})==n, yticklabels(rowLabs{i}); else, yticklabels(1:n); end

    xlabel('Predicted','FontSize',12,'FontName','Times New Roman');
    ylabel('True','FontSize',12,'FontName','Times New Roman');
    title(titles{i},'FontSize',12,'FontWeight','normal');

    % cell annotations
    for r = 1:n
        for c = 1:n
            if asPercent, txt = sprintf('%.1f', M(r,c)); else, txt = sprintf('%d', M(r,c)); end
            text(c, r, txt, 'HorizontalAlignment','center', 'VerticalAlignment','middle', ...
                'FontName','Times New Roman', 'FontSize',10, 'Color','k');
        end
    end

    % panel letters
    text(0.02, 0.96, char('A'+i-1), 'Units','normalized', ...
        'FontName','Times New Roman','FontSize',12,'FontWeight','bold', ...
        'HorizontalAlignment','left','VerticalAlignment','top');
end

% shared colorbar
cb = colorbar(tl, 'Location','eastoutside');
cb.Label.String   = cbarLabel;
cb.Label.FontName = 'Times New Roman';
cb.Label.FontSize = 10;

% ------------------ Export ------------------
exportgraphics(fig, out_png, 'Resolution', 600, 'BackgroundColor','w');
exportgraphics(fig, out_pdf, 'ContentType','vector');

fprintf('OK -> %s\nOK -> %s\n', out_png, out_pdf);
end

% ===== Helper compatible with different MATLAB versions =====
function sheets = get_sheetnames_compat(xfile)
% Returns a cellstr of sheet names (case-preserving if possible)
if exist('sheetnames','file') == 2
    sheets = sheetnames(xfile);
else
    [~, sheets] = xlsfinfo(xfile); % fallback for older versions
end
if isstring(sheets), sheets = cellstr(sheets); end
end
