function plot_vip_stability_profiles_fx17()
% VIP stability profiles – FX17 (NIR–SWIR), publication (no export)
% Panel A: profiles (MSC+1st, SNV+1st, SG 1st) with legend
% Panel B: mean ± range (min–max) with annotated peaks
% Panel letters: A (top) and B (bottom)

% --------- Files and labels ---------
files = { ...
  'FX17_MSC_1_Derivada_Preproc_1_Report.xlsx', ...
  'FX17_SNV_1_Derivada_Preproc_1_Report.xlsx', ...
  'FX17_x1_Derivada_SG_Preproc_1_Report.xlsx' };
names = {'MSC + 1st derivative','SNV + 1st derivative','SG 1st derivative'};
sheet = 'VIP_Stability';

% --------- Figure parameters (range 50–100 %) ---------
ylims       = [50 100];   % Y-axis in %
ytick_step  = 5;          % tick step (5% for finer detail)
guide_lines = [75 90];    % guide lines
sgolay_ord  = 3;          % Savitzky–Golay order
sgolay_win  = 11;         % odd window size
min_prom    = 2;          % minimum peak prominence
min_dist    = 20;         % minimum peak distance (nm)
show_peaks  = true;

% Typical NIR–SWIR bands (shaded if they fall within wl range)
nir_bands = [ ...
    950  980;   % H2O overtone
   1100 1160;   % combination band
   1200 1260;   % combination band
   1400 1520;   % H2O band (broad)
   1660 1690];  % C–H overtone
band_labels = {'H_2O overtone','Combination band','Combination band','H_2O band','C–H overtone'};

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
    if max(Ti.Selection_Frequency) <= 1.2
        Ti.Selection_Frequency = 100 * Ti.Selection_Frequency;
    end
    Ti = sortrows(Ti(:, {'Wavelength_nm','Selection_Frequency'}), 'Wavelength_nm');
    switch i
        case 1, Ti.Properties.VariableNames = {'wl','MSC'};
        case 2, Ti.Properties.VariableNames = {'wl','SNV'};
        case 3, Ti.Properties.VariableNames = {'wl','SG'};
    end
    T{i} = Ti;
end

% --------- Join by wavelength ---------
J = innerjoin(T{1}, T{2}, 'Keys','wl');
J = innerjoin(J,   T{3}, 'Keys','wl');
wl   = J.wl;
Fmsc = J.MSC;  Fsnv = J.SNV;  Fsg  = J.SG;

% --------- Smoothing ---------
if exist('sgolayfilt','file')
    Fmsc_s = sgolayfilt(Fmsc, sgolay_ord, sgolay_win);
    Fsnv_s = sgolayfilt(Fsnv, sgolay_ord, sgolay_win);
    Fsg_s  = sgolayfilt(Fsg , sgolay_ord, sgolay_win);
else
    Fmsc_s = movmean(Fmsc, sgolay_win);
    Fsnv_s = movmean(Fsnv, sgolay_win);
    Fsg_s  = movmean(Fsg , sgolay_win);
end

% --------- Colors ---------
cMSC  = [0.00 0.45 0.74];   % blue
cSNV  = [0.85 0.33 0.10];   % orange
cSG   = [0.93 0.69 0.13];   % yellow
cMean = [0.10 0.10 0.10];   % soft black
cRng  = [0.25 0.25 0.25];   % dark gray

% --------- Figure and panels ---------
figure('Units','pixels','Position',[80 80 1200 520]);
tl = tiledlayout(2,1,'TileSpacing','compact','Padding','compact');

% Utility: shade NIR–SWIR bands + axes setup
    function shade(ax)
        hold(ax,'on');
        xlo = min(wl); xhi = max(wl);
        for b = 1:size(nir_bands,1)
            L = nir_bands(b,1); R = nir_bands(b,2);
            if R < xlo || L > xhi, continue; end
            Lc = max(L,xlo); Rc = min(R,xhi);
            patch(ax,[Lc Rc Rc Lc],[ylims fliplr(ylims)], ...
                  [0.92 0.92 0.92], 'EdgeColor','none');
            text(ax, (Lc+Rc)/2, ylims(2)-1.5, band_labels{b}, ...
                'HorizontalAlignment','center','VerticalAlignment','top', ...
                'FontSize',9,'Color',[0.25 0.25 0.25]);
        end
        for g = guide_lines
            yline(ax, g, 'k:', 'HandleVisibility','off');
        end
        xlim(ax,[xlo xhi]);
        ylim(ax, ylims);
        yticks(ax, ylims(1):ytick_step:ylims(2));
        xlabel(ax,'Wavelength (nm)','FontSize',12);
        ylabel(ax,'Selection frequency (%)','FontSize',12);
    end

% --------- Panel A ---------
ax1 = nexttile(1); hold(ax1,'on'); shade(ax1);
p1 = plot(ax1, wl, Fmsc_s, '-',  'Color', cMSC, 'LineWidth', 1.8);
p2 = plot(ax1, wl, Fsnv_s, '--', 'Color', cSNV, 'LineWidth', 1.8);
p3 = plot(ax1, wl, Fsg_s , ':',  'Color', cSG,  'LineWidth', 1.8);
legA = legend(ax1, [p1 p2 p3], names, 'Location','southoutside','Orientation','horizontal');
legA.Box = 'off';
text(ax1, 0.01, 0.98, 'A', 'Units','normalized', ...
     'FontName','Times New Roman','FontSize',12,'FontWeight','bold', ...
     'HorizontalAlignment','left','VerticalAlignment','top');

% --------- Panel B ---------
ax2 = nexttile(2); hold(ax2,'on'); shade(ax2);
F     = [Fmsc_s, Fsnv_s, Fsg_s];
Fmin  = min(F,[],2); Fmax = max(F,[],2); Fmean = mean(F,2);
fill(ax2, [wl; flipud(wl)], [Fmin; flipud(Fmax)], cRng, 'FaceAlpha',0.28, 'EdgeColor','none');
plot(ax2, wl, Fmin, '-', 'Color', cRng, 'LineWidth', 0.9);
plot(ax2, wl, Fmax, '-', 'Color', cRng, 'LineWidth', 0.9);
plot(ax2, wl, Fmean,'-', 'Color', cMean,'LineWidth', 2.2);

if show_peaks && exist('findpeaks','file')
    [pk, loc] = findpeaks(Fmean, wl, 'MinPeakProminence', min_prom, 'MinPeakDistance', min_dist);
    topK = min(6, numel(pk)); [~, idx] = maxk(pk, topK);
    for k = 1:topK
        xk = loc(idx(k)); yk = pk(idx(k));
        plot(ax2, xk, yk, 'ko', 'MarkerFaceColor','w','MarkerSize',4);
        text(ax2, xk, yk + 1.2, sprintf('%.0f', xk), ...
            'HorizontalAlignment','center','FontSize',9,'Color',[0.2 0.2 0.2]);
    end
end
text(ax2, 0.01, 0.98, 'B', 'Units','normalized', ...
     'FontName','Times New Roman','FontSize',12,'FontWeight','bold', ...
     'HorizontalAlignment','left','VerticalAlignment','top');

end
