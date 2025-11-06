function run_plsr_nested
%% PHASE 3 – PLS-R (nested CV) with MODERN figures and integrated tools
% - External K-Fold + internal K-Fold (optional 1-SE rule)
% - Comparison of preprocessings + target-specific windows
% - FX10+FX17 fusion by normalized ID (row-order fallback if overlap is low)
% - Modern standard figures with FIGURE, FORMAT, TOOLS tabs, etc.

rng(42,'twister');

% =================== Configuration ===================
cfg.outDir           = 'Results_PLSR';
cfg.validation       = 'KFold';   % 'KFold' or 'LOYO'
cfg.outerK           = 5;
cfg.innerK           = 5;
cfg.maxLV            = 20;
cfg.useOneSE         = true;
cfg.zscoreWithinFold = true;
cfg.useWindowsOnly   = false;     % true → windows only

% Automatic export
cfg.saveFIG = true;     % save editable .fig
cfg.savePDF = false;
cfg.savePNG = false;
cfg.saveTIFF= false;
cfg.saveEPS = false;

if ~exist(cfg.outDir,'dir'), mkdir(cfg.outDir); end

% -------- Name patterns (preprocessing detection) -------------
patterns = struct();
patterns.raw        = ["reflectancia","cruda","raw","refl","r"];
patterns.snv        = ["snv"];
patterns.msc        = ["msc","msc_corregido","msc corregido"];
patterns.baseline   = ["baseline","polynomial","poly","baseline_polynomial","baseline polynomial","baseline_poly"];
patterns.der1       = ["x1","1st","1 der","1_der","derivada 1","1ª","der1","first","primera","sg 1","1 derivada","1_derivada","1derivada","_1_derivada_"];
patterns.der2       = ["x2","2nd","2 der","2_der","derivada 2","2ª","der2","second","sg 2","2 derivada","2_derivada","2derivada","_2_derivada_"];

% ---------------- Target-specific windows (nm) ---------------------------
WIN = struct();
WIN.ASTA_D0   = [450 520; 560 590; 620 720];
WIN.ASTA_D3   = [700 740];
WIN.ColorLoss = [695 710; 500 560];
WIN.Moisture  = [980 1015; 1190 1230; 1420 1470; 1530 1550];

% ---------------- Combos per target ----------------------------------
Combos = struct();
Combos.ASTA_D0   = { {'raw'}, {'baseline'}, {'snv'}, {'msc'}, {'snv','der1'}, {'msc','der1'} };
Combos.ASTA_D3   = { {'raw'}, {'snv','der2'}, {'msc','der2'}, {'snv','der1'}, {'baseline'} };
Combos.Moisture  = { {'raw'}, {'snv','der1'}, {'msc','der1'}, {'snv','der2'}, {'msc','der2'}, {'baseline'} };
Combos.ColorLoss = { {'raw'}, {'snv','der2'}, {'msc','der2'}, {'snv','der1'} };

% ---------------- Data loading ---------------------------------------
fx10 = pbt_load_camera('Datos_Preprocesados_FX10.xlsx');
fx17 = pbt_load_camera('Datos_Preprocesados_FX17.xlsx');

% ---------------- Tasks ------------------------------------------------
tasks = {
    'ASTA_D0',   'FX10',   'ASTA_D0',    WIN.ASTA_D0,   Combos.ASTA_D0;
    'ASTA_D3',   'FX10',   'ASTA_D3',    WIN.ASTA_D3,   Combos.ASTA_D3;
    'Moisture',  'FX17',   'Moisture',   WIN.Moisture,  Combos.Moisture;
    'ColorLoss', 'FUSION', 'Color_Loss', WIN.ColorLoss, Combos.ColorLoss
};

for t = 1:size(tasks,1)
    name  = tasks{t,1};
    cam   = tasks{t,2};
    yname = tasks{t,3};
    win   = tasks{t,4};
    combos= tasks{t,5};

    fprintf('\n=== Task: %s ===\n', name);

    switch cam
        case 'FX10',  D = fx10;
        case 'FX17',  D = fx17;
        case 'FUSION',D = pbt_fuse_fx10_fx17(fx10, fx17);
        otherwise,    error('Camera not recognized.');
    end
    if isempty(D.meta) || ~ismember(yname, D.meta.Properties.VariableNames)
        warning('Target %s not found; skipping.', yname); continue
    end

    y = D.meta.(yname);
    valid = isfinite(y);
    if nnz(valid) < 12
        warning('Not enough valid samples for %s', name); continue
    end

    years = []; if ismember('Year', D.meta.Properties.VariableNames), years = D.meta.Year; end
    outerFolds = pbt_build_outer_folds(valid, years, cfg);

    availableGroups = fieldnames(D.groups);
    fprintf('Available groups: %s\n', strjoin(availableGroups,', '));

    modelRank = table();
    best.rmse = inf; best.variant = ""; best.pred = []; best.y_valid = y(valid);

    for cc = 1:numel(combos)
        need = combos{cc};
        gsel = pbt_select_groups(availableGroups, patterns, need);
        if isempty(gsel)
            fprintf('  Combo %s → no matching groups; skipped.\n', strjoin(need,'+')); continue
        end

        [Xfull, wfull] = pbt_build_X_from_groups(D.groups, gsel);
        if isempty(Xfull) || size(Xfull,2) < 2
            fprintf('  Combo %s → <2 bands; skipped.\n', strjoin(need,'+')); continue
        end
        Xwin = pbt_restrict_windows(Xfull, wfull, win);

        if cfg.useWindowsOnly
            variants = struct('name',{'Windows'}, 'X',{Xwin});
        else
            variants = struct('name',{'Full','Windows'}, 'X',{Xfull,Xwin});
        end

        for v = 1:numel(variants)
            varName = sprintf('%s_%s', strjoin(need,'+'), variants(v).name);
            Xall = variants(v).X; if isempty(Xall) || size(Xall,2)<2, continue, end

            [rmse, mae, r2, bias, yhat] = pbt_nested_plsr(Xall, y, valid, outerFolds, cfg);

            row = table(string(name), string(varName), size(Xall,2), ...
                        mean(rmse,'omitnan'), mean(r2,'omitnan'), ...
                        mean(mae,'omitnan'), mean(bias,'omitnan'), ...
                        'VariableNames',{'Task','Variant','nBands','RMSE','R2','MAE','Bias'});
            modelRank = [modelRank; row]; %#ok<AGROW>

            idcol = D.idcol;
            if ismember(idcol, D.meta.Properties.VariableNames), ID = D.meta.(idcol); else, ID = (1:height(D.meta))'; end
            Tpred = table(ID, D.meta.Year, y, yhat, ...
                          'VariableNames', {'ID','Year','Observed','Predicted'});
            writetable(Tpred, fullfile(cfg.outDir, sprintf('Pred_%s_%s.csv', name, varName)));

            rmseMean = mean(rmse,'omitnan');
            if isfinite(rmseMean) && rmseMean < best.rmse && nnz(isfinite(yhat(valid)))>=2
                best.rmse   = rmseMean;
                best.variant= string(varName);
                best.pred   = yhat(valid);
            end
        end
    end

    if ~isempty(modelRank)
        [~,ix] = sort(modelRank.RMSE);
        writetable(modelRank(ix,:), fullfile(cfg.outDir, sprintf('Ranking_%s.csv', name)));
        fprintf('Top variant for %s: %s (RMSE=%.3f, R2=%.3f)\n', ...
            name, modelRank.Variant(ix(1)), modelRank.RMSE(ix(1)), modelRank.R2(ix(1)));
    end

    if ~isempty(best.pred)
        create_scatter_plot(y(valid), best.pred, name, cfg);
    else
        warning('No valid predictions produced for %s.', name);
    end
end

fprintf('\n>> Finished. Results in %s\n', cfg.outDir);
end

%% ====================== SUBFUNCTIONS ======================
function create_scatter_plot(y, yhat, name, cfg)
% Creates a scatter plot using MATLAB's modern figure interface (with toolbar tabs).
    mask = isfinite(y) & isfinite(yhat);
    if nnz(mask) < 2, warning('Not enough points to plot %s', name); return, end

    base = fullfile(cfg.outDir, ['Scatter_' name]);

    % --- Modern standard figure with tool tabs ---
    fig = figure('Color','w','NumberTitle','off','Name',['Scatter – ' char(name)]);
    ax  = axes('Parent',fig,'Box','on');
    hold(ax,'on');

    % --- Plot content ---
    scatter(ax, y(mask), yhat(mask), 60, 'filled', 'MarkerFaceColor', [0.10 0.45 0.85]);

    mn = min([y(mask); yhat(mask)]); mx = max([y(mask); yhat(mask)]);
    line(ax,[mn mx],[mn mx],'LineStyle','--','Color',[0.3 0.3 0.3]);
    xlabel(ax,'Observed');
    ylabel(ax,'Predicted');
    title(ax,['PLS-R Nested CV – ' name]);
    grid(ax,'on');
    xlim(ax,[mn mx]);
    ylim(ax,[mn mx]);
    ax.FontSize = 11;
    ax.FontWeight = 'bold';
    ax.LineWidth = 1.2;

    % --- Metrics ---
    rmse = sqrt(mean((yhat(mask) - y(mask)).^2,'omitnan'));
    r    = NaN; if nnz(mask) >= 3, r = corr(yhat(mask),y(mask),'rows','complete'); end
    text_content = sprintf('RMSE = %.3f | r = %.3f',rmse,r);
    text(ax, mn+0.05*(mx-mn), mx-0.1*(mx-mn), text_content, 'FontSize',11, 'FontWeight','bold');
    
    hold(ax,'off');

    % --- Auto-save if requested ---
    % Export tools are integrated in the modern figure
    if cfg.saveFIG,  savefig(fig,[base '.fig']); end
    if cfg.savePDF,  exportgraphics(ax,[base '.pdf'],'ContentType','vector','BackgroundColor','white'); end
    if cfg.savePNG,  exportgraphics(ax,[base '.png'],'Resolution',600,'BackgroundColor','white'); end
    if cfg.saveTIFF, print(fig,[base '.tif'],'-dtiff','-r600'); end
    if cfg.saveEPS,  print(fig,[base '.eps'],'-depsc'); end
end

function S = pbt_load_camera(xlsx)
% Each sheet = one group. The first sheet with targets defines meta.
    S.meta = table(); S.groups = struct(); S.idcol = 'ID';
    if ~isfile(xlsx), warning('File not found: %s', xlsx); return, end
    sh = sheetnames(xlsx);
    metaSet = false;

    for s = 1:numel(sh)
        T = readtable(xlsx,'Sheet',sh{s},'PreserveVariableNames',true,'TextType','string');
        if isempty(T), continue, end

        vn = string(T.Properties.VariableNames);
        norm = lower(vn);
        norm = replace(norm, ["_","-","(",")","%"], " ");
        repFrom = {'á','é','í','ó','ú','ü','ñ'};
        repTo   = {'a','e','i','o','u','u','n'};
        for k=1:numel(repFrom), norm = strrep(norm, repFrom{k}, repTo{k}); end
        for ii=1:numel(norm), norm(ii) = regexprep(norm(ii),'\s+',' '); end

        iID  = pbt_find_first(norm,'muestra');
        iYear= pbt_find_first(norm,'ano');
        iD0  = pbt_find_first(norm,'color asta d0');
        iD3  = pbt_find_first(norm,'color asta d3');
        iHum = pbt_find_first(norm,'hdad 100 ss');

        if ~metaSet && (~isempty(iD0) || ~isempty(iD3) || ~isempty(iHum))
            D0 = pbt_col2num(T, iD0);
            D3 = pbt_col2num(T, iD3);
            ColorLoss = nan(size(D0));
            ok = isfinite(D0) & D0>0 & isfinite(D3);
            ColorLoss(ok) = 100*(1 - D3(ok)./D0(ok));

            S.meta = table();
            if ~isempty(iID),  S.meta.ID = string(T{:,iID}); else, S.meta.ID = string((1:height(T))'); end
            if ~isempty(iYear),S.meta.Year = pbt_col2num(T,iYear); else, S.meta.Year = nan(height(T),1); end
            if ~isempty(iD0), S.meta.ASTA_D0 = D0; else, S.meta.ASTA_D0 = nan(height(T),1); end
            if ~isempty(iD3), S.meta.ASTA_D3 = D3; else, S.meta.ASTA_D3 = nan(height(T),1); end
            if ~isempty(iHum),S.meta.Moisture = pbt_col2num(T,iHum); else, S.meta.Moisture = nan(height(T),1); end
            S.meta.Color_Loss = ColorLoss;
            S.meta.ID_norm = pbt_normalize_id(S.meta.ID);
            S.idcol = 'ID';
            metaSet = true;
        end

        G = pbt_detect_preproc_groups(norm);
        fn = fieldnames(G);
        if isempty(fn), continue, end

        useSheetName = true;
        if numel(fn) > 1
            useSheetName = false;
        elseif numel(fn)==1
            p = fn{1};
            if ~strcmpi(p,'r') && ~strcmpi(p,'raw') && ~isempty(p), useSheetName = false; end
        end

        if useSheetName
            p = fn{1};
            w = G.(p).wavelength; X = double(T{:,G.(p).idx});
            [w,ord] = sort(w); X = X(:,ord);
            groupName = pbt_sanitize_name(sh{s});
            S.groups.(groupName).w = w; S.groups.(groupName).X = X;
        else
            for k = 1:numel(fn)
                p = fn{k};
                w = G.(p).wavelength; X = double(T{:,G.(p).idx});
                [w,ord] = sort(w); X = X(:,ord);
                groupName = [pbt_sanitize_name(sh{s}) '_' pbt_sanitize_name(p)];
                S.groups.(groupName).w = w; S.groups.(groupName).X = X;
            end
        end
    end
end

function outerFolds = pbt_build_outer_folds(valid, Year, cfg)
    idxValid = find(valid);
    outerFolds = {};
    switch lower(cfg.validation)
        case 'loyo'
            uy = unique(Year(valid)); uy = uy(isfinite(uy));
            for i=1:numel(uy)
                te = false(size(valid));
                te(valid & Year==uy(i)) = true;
                if nnz(te) >= 2 && nnz(valid & ~te) >= 8
                    outerFolds{end+1} = te; %#ok<AGROW>
                end
            end
            if isempty(outerFolds)
                Kouter = min(cfg.outerK, max(2, floor(numel(idxValid)/5)));
                cvo    = cvpartition(numel(idxValid), 'KFold', Kouter);
                for k=1:cvo.NumTestSets
                    te = false(size(valid));
                    te(idxValid(test(cvo,k))) = true;
                    outerFolds{end+1} = te; %#ok<AGROW>
                end
            end
        otherwise
            Kouter = min(cfg.outerK, max(2, floor(numel(idxValid)/5)));
            cvo    = cvpartition(numel(idxValid), 'KFold', Kouter);
            for k=1:cvo.NumTestSets
                te = false(size(valid));
                te(idxValid(test(cvo,k))) = true;
                outerFolds{end+1} = te; %#ok<AGROW>
            end
    end
end

function gsel = pbt_select_groups(allGroups, patterns, need)
    mask = false(size(allGroups));
    for i=1:numel(allGroups)
        g = lower(allGroups{i}); ok = true;
        for j=1:numel(need)
            pats = patterns.(lower(need{j})); hit = false;
            for p = 1:numel(pats)
                if contains(g, lower(string(pats(p)))), hit = true; break, end
            end
            if ~hit, ok=false; break, end
        end
        mask(i) = ok;
    end
    gsel = allGroups(mask);
end

function [X, w] = pbt_build_X_from_groups(G, names)
    X=[]; w=[];
    for i=1:numel(names)
        if ~isfield(G,names{i}), continue, end
        w = [w; G.(names{i}).w(:)]; %#ok<AGROW>
        X = [X, G.(names{i}).X];    %#ok<AGROW>
    end
    if ~isempty(w)
        [w,ord] = sort(w); X = X(:,ord);
        [w, ia] = unique(round(w,3),'stable'); X = X(:,ia);
    end
end

function Xw = pbt_restrict_windows(X, w, WIN)
    if isempty(X), Xw = []; return, end
    keep = false(size(w));
    for k=1:size(WIN,1), keep = keep | (w>=WIN(k,1) & w<=WIN(k,2)); end
    Xw = X(:,keep);
end

function idn = pbt_normalize_id(ID)
    s = lower(string(ID)); s = regexprep(s,'\s+',''); s = regexprep(s,'[^a-z0-9]','');
    idn = s;
end

function [rmse, mae, r2, bias, yhat_out] = pbt_nested_plsr(X, y, valid, outerFolds, cfg)
    rmse = nan(numel(outerFolds),1);
    mae  = nan(numel(outerFolds),1);
    r2   = nan(numel(outerFolds),1);
    bias = nan(numel(outerFolds),1);
    yhat_out = nan(size(y));
    for k = 1:numel(outerFolds)
        te = outerFolds{k};
        tr = valid & ~te;
        if nnz(tr)<8 || nnz(te)<2, continue, end

        Xtr = X(tr,:); ytr = y(tr);
        Xte = X(te,:); yte = y(te);

        % Median imputation
        for j = 1:size(Xtr,2)
            m = nanmedian(Xtr(:,j)); if ~isfinite(m), m = 0; end
            if any(~isfinite(Xtr(:,j))), Xtr(~isfinite(Xtr(:,j)), j) = m; end
            if any(~isfinite(Xte(:,j))), Xte(~isfinite(Xte(:,j)), j) = m; end
        end

        % Within-fold z-score
        if cfg.zscoreWithinFold
            [Xtr, mu, sig] = zscore(Xtr,0,1);
            sig(sig==0) = 1; Xte = (Xte - mu) ./ sig;
        end

        % Inner CV for LV
        Kinner = min(cfg.innerK, max(2, floor(numel(ytr)/5)));
        cvi    = cvpartition(numel(ytr),'KFold',Kinner);
        maxLV  = min(cfg.maxLV, max(1, rank(Xtr)-1));
        rmseLV = nan(maxLV,1);

        for a = 1:maxLV
            rss = nan(cvi.NumTestSets,1);
            for j = 1:cvi.NumTestSets
                idxTeIn = test(cvi,j); idxTrIn = training(cvi,j);
                [~,~,~,~,beta] = plsregress(Xtr(idxTrIn,:), ytr(idxTrIn), a);
                ypred = [ones(sum(idxTeIn),1) Xtr(idxTeIn,:)]*beta;
                rss(j) = sqrt(mean((ypred - ytr(idxTeIn)).^2,'omitnan'));
            end
            rmseLV(a) = mean(rss,'omitnan');
        end

        [~, bestLV] = min(rmseLV);
        if cfg.useOneSE
            se  = std(rmseLV,'omitnan')/sqrt(nnz(~isnan(rmseLV)));
            cand = find(rmseLV <= rmseLV(bestLV) + se, 1, 'first');
            if ~isempty(cand), bestLV = cand; end
        end

        [~,~,~,~,beta] = plsregress(Xtr, ytr, bestLV);
        ypred = [ones(sum(te),1) Xte]*beta;

        yhat_out(te) = ypred;
        rmse(k) = sqrt(mean((ypred - yte).^2,'omitnan'));
        mae(k)  = mean(abs(ypred - yte),'omitnan');
        r2(k)   = 1 - sum((ypred - yte).^2,'omitnan')/sum((yte - mean(yte,'omitnan')).^2,'omitnan');
        bias(k) = mean(ypred - yte,'omitnan');
    end
end

function idx = pbt_find_first(norm, pat)
    idx = find(norm==pat | contains(norm,pat), 1, 'first'); if isempty(idx), idx = []; end
end

function x = pbt_col2num(T, idx)
    if isempty(idx), x = nan(height(T),1); return, end
    v = T{:,idx}; if isnumeric(v), x = double(v); else, x = str2double(string(v)); end
end

function G = pbt_detect_preproc_groups(norm)
    G = struct();
    for k=1:numel(norm)
        s = norm(k); tok = regexp(s,'(\d+(\.\d+)?)','tokens','once'); if isempty(tok), continue, end
        wl = str2double(tok{1}); if ~(wl>=300 && wl<=2500), continue, end
        fd = regexp(s,'\d','once');
        if isempty(fd), pref = 'raw';
        else
            pref = strtrim(extractBefore(s,fd)); pref = strrep(pref,'nm',''); pref = regexprep(pref,'\s+',' ');
            if isempty(pref), pref='raw'; end
        end
        if ~isfield(G,pref), G.(pref).wavelength=[]; G.(pref).idx=[]; end
        G.(pref).wavelength(end+1,1)=wl; G.(pref).idx(end+1,1)=k;
    end
end

function Dfuse = pbt_fuse_fx10_fx17(F10,F17)
    Dfuse = struct(); Dfuse.idcol = 'ID';
    if isempty(F10.meta) || isempty(F17.meta), warning('Fusion: missing meta; using available.'); end
    if ismember('ID_norm', F10.meta.Properties.VariableNames) && ismember('ID_norm', F17.meta.Properties.VariableNames)
        [~, idx10, idx17] = intersect(F10.meta.ID_norm, F17.meta.ID_norm, 'stable');
    else
        idx10 = []; idx17 = [];
    end
    if numel(idx10) < min(height(F10.meta), height(F17.meta))*0.6
        warning('Low ID overlap; fusing by row order as fallback.')
        n = min(height(F10.meta), height(F17.meta)); idx10 = 1:n; idx17 = 1:n;
    end
    Dfuse.meta = F10.meta(idx10,:);
    if ismember('Moisture', F17.meta.Properties.VariableNames)
        Dfuse.meta.Moisture = F17.meta.Moisture(idx17);
    end
    fn10 = fieldnames(F10.groups);
    for i=1:numel(fn10), Dfuse.groups.( ['fx10_' fn10{i}] ) = F10.groups.(fn10{i}); end
    fn17 = fieldnames(F17.groups);
    for i=1:numel(fn17), Dfuse.groups.( ['fx17_' fn17{i}] ) = F17.groups.(fn17{i}); end
end

function safe = pbt_sanitize_name(s)
    s = string(s); s = lower(s);
    s = regexprep(s,'\s+','_');
    s = regexprep(s,'[^a-z0-9_\-]','');
    if strlength(s)==0, s = "preproc"; end
    safe = s;
end
