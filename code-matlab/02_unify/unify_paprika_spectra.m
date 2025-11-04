function unify_paprika_spectra()
% Unified spectra (paprika) from the 2023/2024/2025 subfolders
% of the current folder (pwd) into a single Excel file.
% Usage: move to ...\FX10\resultados\ (or ...\FX17\resultados\) and run.

%% ======== AUTO-CONFIGURATION BASED ON CURRENT FOLDER ========
rootDir = pwd;
subyears = {'2023','2024','2025'};
carpetas = cellfun(@(s) fullfile(rootDir, s), subyears, 'UniformOutput', false);

% Detect camera from current path (FX10/FX17). If not found, set to GEN.
if contains(lower(rootDir), 'fx10'), etiqueta = 'FX10';
elseif contains(lower(rootDir), 'fx17'), etiqueta = 'FX17';
else, etiqueta = 'GEN';
end

archivo_salida = fullfile(rootDir, sprintf('%s_PIMENTON_UNIFICADO.xlsx', etiqueta));

fprintf('Current folder: %s\n', rootDir);
fprintf('Subfolders: %s\n', strjoin(subyears, ', '));
fprintf('Output: %s\n', archivo_salida);

%% ======== UNIFICATION ========
unify_by_camera_paprika(carpetas, archivo_salida, etiqueta);
disp('✅ Unification completed.');
end


%% ================= AUXILIARY FUNCTIONS =================

function unify_by_camera_paprika(lista_carpetas, archivo_salida, etiqueta)
    if ~iscell(lista_carpetas) || isempty(lista_carpetas)
        error('lista_carpetas must be a non-empty cell array with paths.');
    end
    if ~ischar(archivo_salida) && ~isstring(archivo_salida)
        error('archivo_salida must be char or string.');
    end
    if ~ischar(etiqueta) && ~isstring(etiqueta)
        error('etiqueta must be char or string.');
    end

    meta_cols = {'Muestra','Anio'}; % work without accent
    tabla_final = table();

    % Collect files (non-recursive)
    files_all = [];
    patrones = {'espectros_*.xlsx','espectro_*.xlsx','*.xlsx'};
    for c = 1:numel(lista_carpetas)
        folder = lista_carpetas{c};
        if ~isfolder(folder)
            warning('Folder not found: %s', folder);
            continue;
        end
        encontrado = false;
        for p = 1:numel(patrones)
            dd = dir(fullfile(folder, patrones{p}));
            if ~isempty(dd)
                dd = addFolderPath(dd, folder);
                files_all = [files_all; dd]; %#ok<AGROW>
                encontrado = true;
                break;
            end
        end
        if ~encontrado
            warning('(%s) No Excel files in folder: %s', etiqueta, folder);
        end
    end

    if isempty(files_all)
        warning('(%s) No Excel files found in the provided folders. No output generated.', etiqueta);
        return;
    end

    % Process files
    for k = 1:numel(files_all)
        fpath = fullfile(files_all(k).folder, files_all(k).name);
        try
            T = leer_excel_pimiento(fpath);
        catch ME
            warning('Could not read %s (%s). Skipping.', fpath, ME.message);
            continue;
        end

        if ~all(ismember({'Muestra','Anio'}, T.Properties.VariableNames))
            warning('Missing columns Muestra/Anio in %s. Skipping.', fpath);
            continue;
        end

        tabla_final = union_vertcat(tabla_final, T, meta_cols);
    end

    if isempty(tabla_final)
        warning('(%s) No valid table obtained. No file saved.', etiqueta);
        return;
    end

    % --- Sort by Anio and Muestra (if convertible to numeric) ---
    Tout = tabla_final;
    if iscell(Tout.Muestra) || isstring(Tout.Muestra)
        nums = str2double(string(Tout.Muestra));
        if all(~isnan(nums))
            Tout.Muestra = nums;
        end
    end
    if ismember('Anio', Tout.Properties.VariableNames) && ismember('Muestra', Tout.Properties.VariableNames)
        try
            Tout = sortrows(Tout, {'Anio','Muestra'});
        catch
            % If sortrows fails, leave unsorted.
        end
    end

    % (Optional) Rename header 'Anio' -> 'Año' only in the output file
    vn = Tout.Properties.VariableNames;
    iAnio = find(strcmp(vn,'Anio'),1);
    if ~isempty(iAnio)
        vn{iAnio} = 'Año';
        Tout.Properties.VariableNames = vn;
    end

    % Write
    writetable(Tout, char(archivo_salida));
    fprintf('✅ (%s) Saved: %s\n', etiqueta, archivo_salida);
end


function T = leer_excel_pimiento(fpath)
% Read spectra Excel with columns Muestra and Año/Anio + spectral columns

    % First attempt: readtable
    T = readtable(fpath, 'PreserveVariableNames', true);
    vnames = T.Properties.VariableNames;

    % Normalize 'Año'->'Anio' if present
    if any(strcmp(vnames,'Año')) && ~any(strcmp(vnames,'Anio'))
        T.Properties.VariableNames{strcmp(vnames,'Año')} = 'Anio';
        vnames = T.Properties.VariableNames;
    end

    % Detect meta and spectral columns
    is_meta = ismember(vnames, {'Muestra','Anio'});
    is_x = startsWith(vnames, 'x','IgnoreCase',true);

    is_numeric_header = false(size(vnames));
    for i = 1:numel(vnames)
        is_numeric_header(i) = ~isnan(str2double(strrep(vnames{i},',','.')));
    end

    spectral_mask = (is_x | is_numeric_header) & ~is_meta;

    if any(spectral_mask) && all(ismember({'Muestra','Anio'}, vnames))
        % Normalize numeric headers to x####.##
        for i = find(is_numeric_header)
            wl = str2double(strrep(vnames{i},',','.'));
            if ~isnan(wl)
                vnames{i} = sprintf('x%s', strrep(sprintf('%.2f', wl),'.','_'));
            end
        end
        T.Properties.VariableNames = vnames;

        % Ensure double dtype in spectral columns
        T = convertir_espectrales_a_double(T, spectral_mask);

        % Put meta first
        T = mover_meta_primero(T, {'Muestra','Anio'});
        return;
    end

    % Second attempt: structure with header in row 1 (wavelengths from col2)
    raw = readcell(fpath);
    if size(raw,1) < 2 || size(raw,2) < 3
        error('Unexpected structure in: %s', fpath);
    end

    hdr = string(raw(1,:));
    idxM = find(strcmpi(hdr,'Muestra'), 1);
    idxA = find(strcmpi(hdr,'Año') | strcmpi(hdr,'Anio'), 1);

    if isempty(idxM) || isempty(idxA)
        error('Columns Muestra/Anio not found in: %s', fpath);
    end

    spectral_idx = setdiff(1:size(raw,2), [idxM idxA]);
    wl_vals = raw(1, spectral_idx);
    wl_num = cellfun(@(x) tryNum(x), wl_vals);

    v_spec = arrayfun(@(x) sprintf('x%s', strrep(sprintf('%.2f', x),'.','_')), wl_num, 'UniformOutput', false);

    dat = raw(2:end, :);
    Muestra = dat(:, idxM);
    Anio    = dat(:, idxA);
    Data    = dat(:, spectral_idx);

    DataN = cellfun(@(x) tryNum(x), Data);

    T = array2table(DataN, 'VariableNames', v_spec);
    T.Muestra = Muestra;
    T.Anio    = Anio;
    T = mover_meta_primero(T, {'Muestra','Anio'});
end


function T = convertir_espectrales_a_double(T, mask)
    v = T.Properties.VariableNames;
    for i = find(mask)
        col = T.(v{i});
        if ~isnumeric(col)
            T.(v{i}) = toDouble(col);
        end
    end
end


function arr = toDouble(c)
    if isnumeric(c), arr = double(c); return; end
    if iscell(c)
        arr = nan(size(c));
        for i=1:numel(c)
            arr(i) = tryNum(c{i});
        end
    elseif isstring(c) || ischar(c)
        arr = str2double(strrep(string(c),',','.'));
    else
        arr = nan(size(c));
    end
end


function x = tryNum(v)
% Convert a value (num/char/string/cell) to double. NaN if not applicable.

    if isnumeric(v)
        x = double(v);
        return
    end

    if isstring(v) || ischar(v)
        s = strrep(string(v), ',', '.');   % decimal separator handling
        x = str2double(s);
        return
    end

    if iscell(v)
        if isempty(v)
            x = NaN;
            return
        end
        % If cell, try first element
        x = tryNum(v{1});
        return
    end

    x = NaN;  % default case
end


function T = mover_meta_primero(T, meta_cols)
    metas = intersect(meta_cols, T.Properties.VariableNames, 'stable');
    T = movevars(T, metas, 'Before', 1);
end


function S = addFolderPath(files, folder)
    for i=1:numel(files), files(i).folder = folder; end
    S = files;
end


function Tout = union_vertcat(Ta, Tb, meta_cols)
% Union of columns by name; missing filled with NaN (spectral) or '' (meta)
    if isempty(Ta), Tout = Tb; return; end
    if isempty(Tb), Tout = Ta; return; end

    all_vars = union(Ta.Properties.VariableNames, Tb.Properties.VariableNames, 'stable');
    Ta = add_missing_vars(Ta, all_vars, meta_cols);
    Tb = add_missing_vars(Tb, all_vars, meta_cols);

    Ta = Ta(:, all_vars);
    Tb = Tb(:, all_vars);

    Tout = [Ta; Tb];
end


function T = add_missing_vars(T, all_vars, meta_cols)
    cur = T.Properties.VariableNames;
    faltan = setdiff(all_vars, cur, 'stable');
    for i=1:numel(faltan)
        vn = faltan{i};
        if ismember(vn, meta_cols)
            T.(vn) = repmat({''}, height(T), 1);
        else
            T.(vn) = NaN(height(T), 1);
        end
    end
end
