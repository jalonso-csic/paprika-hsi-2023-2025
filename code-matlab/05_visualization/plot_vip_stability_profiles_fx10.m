function plot_vip_stability_profiles_fx10()
% VIP stability profiles – FX10 (VIS–NIR), publication layout (no export)
% Panel A: profiles (MSC+1st, SNV+1st, SG 1st) with legend
% Panel B: mean ± range (min–max) with annotated peaks
% Panel letters: A (top) and B (bottom). No internal titles.

% --------- Files and labels ---------
files = { ...
  'FX10_MSC_1_Derivada_Preproc_Report.xlsx', ...
  'FX10_SNV_1_Derivada_Preproc_Report.xlsx', ...
  'FX10_x1_Derivada_SG_Preproc_Report.xlsx' };
names = {'MSC + 1st derivative','SNV + 1st derivative','SG 1st derivative'};
sheet = 'VIP_Stability';

% --------- Figure parameters ---------
ylims       = [70 100];   % Y-axis range (%)
ytick_step  = 5;          % Y-axis tick step (5 or 10)
guide_lines = [75 90];    % horizontal reference lines (%)
sgolay_ord  = 3;          % Savitzky–Golay order
sgolay_win  = 11;         % Savitzky–Golay window (odd)
min_prom    = 2;          % minimum peak prominence (for annotations)
min_dist    = 15;         % minimum distance between peaks (nm)
show_peaks  = true;       % annotate peaks in Panel B if findpeaks is available

% --------- Global appearance ---------
set(groot,'defaultFigureColor','w', ...
          'defaultAxesFontName','Times New Roman', ...
          'defaultTextFontName','Times New Roman', ...
          'defaultAxesFontSize',10, ...
          'defaultTextColor','k', ...
          'defaultAxesLineWidth',0.8);

% --------- Read and normalize to % ---------
T = cell(1,3);
for i = 1:3
    Ti = readtable(files{i}, 'Sheet', sheet);
    assert(ismember('Wavelength_nm', Ti.Properties.VariableNames), ...
        'No "Wavelength_nm" in %s', files{i});
    assert(ismember('Selection_Frequency', Ti.Properties.VariableNames), ...
        'No "Selection_Frequency" in %s', files{i});

    % Convert to percent if provided in [0,1]
    if max(Ti.Selection_Frequency) <= 1.2
        Ti.Selection_Frequency = 100 * Ti.Selection_Frequency;
    end
    Ti = sortrows(Ti(:, {'Wavelength_nm','Selection_Frequency'}), 'Wavelength_nm');

    % Rename for suffix-free joins
    switch i
        case 1, Ti.Properties.VariableNames = {'wl','MSC'};
        case 2, Ti.Properties.VariableNames = {'wl','SNV'};
        case 3, Ti.Properties.VariableNames = {'wl','SG'};
    end
    T{i} = Ti;
end

% --------- Join by wavelength (common intersection) ---------
J = innerjoin(T{1}, T{2}, 'Keys','wl');   % wl, MSC, SNV
J = innerjoin(J,   T{3}, 'Keys','wl');   % wl, MSC, SNV, SG

wl   = J.wl;
Fmsc = J.MSC;  Fsnv = J.SNV;  Fsg  = J.SG;

% --------- Smoothing (Savitzky–Golay or movmean) ---------
if exist('sgolayfilt','file')
    Fmsc_s = sgolayfilt(Fmsc, sgolay_ord, sgolay_win);
    Fsnv_s = sgolayfilt(Fsnv, sgolay_ord, sgolay_win);
    Fsg_s  = sgolayfilt(Fsg,  sgolay_ord, sgolay_win);
else
    Fmsc_s = movmean(Fmsc, sgolay_win);
    Fsnv_s = movmean(Fsnv, sgolay_win);
    Fsg_s  = movmean(Fsg,  sgolay_win);
end

% --------- Colors (colorblind-friendly) ---------
cMSC  = [0.00 0.45 0.74];   % blue
cSNV  = [0.85 0.33 0.10];   % orange
cSG   = [0.93 0.69 0.13];   % yellow
cMean = [0.10 0.10 0.10];   % soft black
cRng  = [0.25 0.25 0.25];   % dark gray (range)

% --------- Figure and panels ---------
figure('Units','pixels','Position',[80 80 1200 520]);
tl = tiledlayout(2,1,'TileSpacing','compact','Padding','compact');

% Utility: shade spectral bands + axes
    function shade(ax)
        hold(ax,'on');
        % Approx. spectral bands
        patch(ax,[430 470 470 430],[ylims fliplr(ylims)], [0.85 0.85 0.85], 'EdgeColor','none'); % carotenoids
        patch(ax,[700 740 740 700],[ylims fliplr(ylims)], [0.92 0.92 0.92], 'EdgeColor','none'); % red-edge
        patch(ax,[960 980 980 960],[ylims fliplr(ylims)], [0.92 0.92 0.92], 'EdgeColor','none'); % H2O overtone
        % Guide lines
        for g = guide_lines
            yline(ax, g, 'k:', 'HandleVisibility','off');
        end
        xlim(ax, [min(wl) max(wl)]);
        ylim(ax, ylims);
        yticks(ax, ylims(1):ytick_step:ylims(2));
        xlabel(ax,'Wavelength (nm)','FontSize',12);
        ylabel(ax,'Selection frequency (%)','FontSize',12);
    end

% --------- Panel A: three profiles (no title; with 'A') ---------
ax1 = nexttile(1); hold(ax1,'on'); shade(ax1);
p1 = plot(ax1, wl, Fmsc_s, '-',  'Color', cMSC, 'LineWidth', 1.8);
p2 = plot(ax1, wl, Fsnv_s, '--', 'Color', cSNV, 'LineWidth', 1.8);
p3 = plot(ax1, wl, Fsg_s,  ':',  'Color', cSG,  'LineWidth', 1.8);
legA = legend(ax1, [p1 p2 p3], names, 'Location','southoutside','Orientation','horizontal'); %#ok<NASGU>
set(legA,'Box','off');
text(ax1, 0.01, 0.98, 'A', 'Units','normalized', 'FontName','Times New Roman', ...
     'FontSize',12, 'FontWeight','bold', 'HorizontalAlignment','left', 'VerticalAlignment','top');

% --------- Panel B: mean ± range + peaks (no title; with 'B') ---------
ax2 = nexttile(2); hold(ax2,'on'); shade(ax2);
F     = [Fmsc_s, Fsnv_s, Fsg_s];
Fmin  = min(F, [], 2);
Fmax  = max(F, [], 2);
Fmean = mean(F, 2);

% Range band (min–max) + edges + mean
fill(ax2, [wl; flipud(wl)], [Fmin; flipud(Fmax)], cRng, ...
     'FaceAlpha', 0.28, 'EdgeColor', 'none');
plot(ax2, wl, Fmin,'-', 'Color', cRng, 'LineWidth', 0.9);
plot(ax2, wl, Fmax,'-', 'Color', cRng, 'LineWidth', 0.9);
plot(ax2, wl, Fmean,'-', 'Color', cMean,'LineWidth', 2.2);

% Annotate peaks of the mean profile if findpeaks is available
if show_peaks && exist('findpeaks','file')
    [pk, loc] = findpeaks(Fmean, wl, 'MinPeakProminence', min_prom, 'MinPeakDistance', min_dist);
    topK = min(6, numel(pk));
    [~, idx] = maxk(pk, topK);
    for k = 1:topK
        xk = loc(idx(k)); yk = pk(idx(k));
        plot(ax2, xk, yk, 'ko', 'MarkerFaceColor', 'w', 'MarkerSize', 4);
        text(ax2, xk, yk + 1.2, sprintf('%.0f', xk), ...
            'HorizontalAlignment','center','FontSize',9,'Color',[0.2 0.2 0.2]);
    end
end
text(ax2, 0.01, 0.98, 'B', 'Units','normalized', 'FontName','Times New Roman', ...
     'FontSize',12, 'FontWeight','bold', 'HorizontalAlignment','left', 'VerticalAlignment','top');

end
