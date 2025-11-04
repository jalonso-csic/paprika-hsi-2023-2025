function extract_spectra_fx10
% extract_spectra_fx10
% Portable FX10 ROI extractor for paprika (3 years).
% - Data are expected to be downloaded from Zenodo and unzipped locally.
% - On first run, you will be asked to select the local data folder; this
%   path is cached for future runs.
% - Results are written inside the repository at results/FX10/resultados/<YEAR>/.
%
% MATLAB R2025a; requires Image Processing Toolbox for drawcircle/viscircles/imadjust.
%
% Author: J. Alonso
% Repository: https://github.com/jalonso-csic/paprika-hsi-2023-2025

clear; close all; clc;

%% ---------- PORTABLE PATHS (repo-relative results + user-selected data) ----------
% 1) Detect repository root from this file location:
thisFile = mfilename('fullpath');
% .../repo/code-matlab/01_roi_extraction/extract_spectra_fx10.m -> repo
repoRoot = fileparts(fileparts(fileparts(thisFile)));

% 2) Results base (always inside the repo):
resultsBase_FX10 = fullfile(repoRoot, 'results', 'FX10');
if ~exist(resultsBase_FX10, 'dir'), mkdir(resultsBase_FX10); end

% 3) Resolve data root (once): ask user where the Zenodo dataset (FX10) was unzipped
cfgPath = fullfile(resultsBase_FX10, 'fx10_data_path.mat');  % tiny cache file
ruta_principal = '';

if exist(cfgPath, 'file')
    S = load(cfgPath, 'ruta_principal');
    if isfield(S,'ruta_principal') && isfolder(S.ruta_principal)
        ruta_principal = S.ruta_principal;
    end
end

if isempty(ruta_principal)
    uiwait(warndlg( ...
        ['Select the LOCAL folder that contains FX10 samples unzipped from Zenodo.', char(10), ...
         'Expected structure: FX10_YYYY_.../capture/*.hdr, *.raw, WHITEREF_*, DARKREF_*'], ...
        'Select FX10 data root (Zenodo)'));
    ruta_principal = uigetdir(repoRoot, 'Select FX10 data root (folder containing FX10_*/capture)');
    assert(ischar(ruta_principal) && ruta_principal~=0, 'No data folder selected.');
    save(cfgPath, 'ruta_principal');  % cache for future runs
end

addpath(ruta_principal); % optional

%% ---------- SEARCH FOR SAMPLES ----------
d = dir(ruta_principal);
isSample = @(x) x.isdir && startsWith(x.name, 'FX10_') && ~contains(lower(x.name), 'resultado');
carpetas_muestra = d(arrayfun(isSample, d));

fprintf('Found %d samples to process in:\n  %s\n', numel(carpetas_muestra), ruta_principal);
for k = 1:numel(carpetas_muestra)
    fprintf('  %s\n', carpetas_muestra(k).name);
end

%% ---------- ANALYSIS PARAMETERS ----------
R = input('Enter circular ROI radius (in pixels): ');
Nfrutos = input('How many fruits do you want to analyze per image? ');

%% ---------- MAIN PROCESSING LOOP ----------
for k = 1:numel(carpetas_muestra)
    close all;
    nombre_muestra = carpetas_muestra(k).name;
    ruta_captura = fullfile(ruta_principal, nombre_muestra, 'capture');

    fprintf('\n>> Processing sample: %s\n', nombre_muestra);

    % --- LOAD & CALIBRATE IMAGES ---
    hdr_muestra = fullfile(ruta_captura, [nombre_muestra, '.hdr']);
    raw_muestra = fullfile(ruta_captura, [nombre_muestra, '.raw']);
    hdr_white   = fullfile(ruta_captura, ['WHITEREF_', nombre_muestra, '.hdr']);
    raw_white   = fullfile(ruta_captura, ['WHITEREF_', nombre_muestra, '.raw']);
    hdr_dark    = fullfile(ruta_captura, ['DARKREF_',  nombre_muestra, '.hdr']);
    raw_dark    = fullfile(ruta_captura, ['DARKREF_',  nombre_muestra, '.raw']);

    info  = enviinfo_local(hdr_muestra);   cube  = enviread_local(info,  raw_muestra);
    infoW = enviinfo_local(hdr_white);     white = enviread_local(infoW, raw_white);
    infoD = enviinfo_local(hdr_dark);      dark  = enviread_local(infoD, raw_dark);

    % Harmonize spatial/spectral dimensions across sample/WHITE/DARK
    nrow = min([size(cube,1), size(white,1), size(dark,1)]);
    ncol = min([size(cube,2), size(white,2), size(dark,2)]);
    nb   = min([size(cube,3), size(white,3), size(dark,3)]);

    cube  = cube(1:nrow, 1:ncol, 1:nb);
    white = white(1:nrow, 1:ncol, 1:nb);
    dark  = dark(1:nrow, 1:ncol, 1:nb);

    % Reflectance calibration (clipped to [0,1] as a safe range)
    cube_cal = (double(cube) - double(dark)) ./ (double(white) - double(dark));
    cube_cal = max(0, min(cube_cal, 1));

    % --- READ WAVELENGTHS (fixed & preallocated) ---
    lambda = [];
    fid = fopen(hdr_muestra, 'r');  assert(fid>0,'HDR could not be opened.');
    while ~feof(fid)
        tline = fgetl(fid);
        if ischar(tline) && contains(lower(tline), 'wavelength')
            idx1 = strfind(tline, '{');
            if isempty(idx1), continue; end

            % Preallocate a large cell to avoid dynamic growth while reading multi-line wavelengths
            parts = cell(1,200);
            parts{1} = tline(idx1+1:end);
            nParts = 1;

            while ~contains(parts{nParts}, '}')
                if feof(fid), error('Closing "}" for wavelengths not found.'); end
                nxt = fgetl(fid);
                if ~ischar(nxt), break; end
                nParts = nParts + 1;
                parts{nParts} = nxt;
            end
            full_text = strjoin(parts(1:nParts), '');

            idx2 = strfind(full_text, '}');
            vals = full_text(1:idx2-1);
            lambda = sscanf(vals, '%f,');
            break;
        end
    end
    fclose(fid);

    % Fallback if wavelengths are missing or shorter than nb
    if isempty(lambda) || numel(lambda) < nb
        warning('Wavelengths not found. A numeric sequence will be used.');
        lambda = 1:nb;
    else
        lambda = lambda(1:nb);
    end

    % --- RGB QUICKLOOK (index triplet approx. to B/G/R) ---
    idxB = min(40, nb); idxG = min(70, nb); idxR = min(113, nb);
    rgb = cat(3, cube_cal(:,:,idxR), cube_cal(:,:,idxG), cube_cal(:,:,idxB));
    rgb = rgb - min(rgb(:)); rgb = rgb ./ max(rgb(:));
    rgb = imadjust(rgb, stretchlim(rgb, [0.01 0.99]));

    % --- ROI SELECTION (click → zoom → translate circle until accept) ---
    hfig = figure('Name', nombre_muestra, 'WindowState', 'maximized');
    imshow(rgb);
    title(sprintf('%s\nClick near the center of each fruit to zoom', nombre_muestra));
    hold on;
    spectra = zeros(Nfrutos, nb);
    centros = zeros(Nfrutos,2);

    for i=1:Nfrutos
        aceptado_fruto = false;
        while ~aceptado_fruto
            figure(hfig);
            disp(['Select the approximate center of fruit ', num2str(i)]);
            [x0, y0, ~] = ginput(1);

            % Define zoom window around the click based on ROI radius
            zoom_factor = 5;
            half_win = round(R * zoom_factor);
            xmin = max(round(x0) - half_win, 1); xmax = min(round(x0) + half_win, ncol);
            ymin = max(round(y0) - half_win, 1); ymax = min(round(y0) + half_win, nrow);

            aceptar_roi = false;
            while ~aceptar_roi
                hfig_zoom = figure('Name',sprintf('Fine adjustment — Fruit %d',i));
                imshow(rgb(ymin:ymax, xmin:xmax, :));
                title(sprintf('Fine ROI adjustment %d. [A]=Accept, [R]=Repeat', i));
                hold on;

                % Draw a movable circle; only translation is allowed (fixed R)
                circ = drawcircle('Center',[x0-xmin+1, y0-ymin+1],'Radius',R,...
                    'Color','g','LineWidth',1.5,'InteractionsAllowed','translate');

                disp('Adjust the circle. When ready, press [A] to accept or [R] to repeat.');

                repetir_click = false;
                while true
                    w = waitforbuttonpress;
                    if w == 1
                        key = lower(get(hfig_zoom,'CurrentCharacter'));
                        if strcmp(key,'a')
                            aceptar_roi = true; break;
                        elseif strcmp(key,'r')
                            repetir_click = true; break;
                        end
                    end
                end

                if aceptar_roi
                    % Map circle center from zoomed view back to full image
                    pos = circ.Center; close(hfig_zoom);
                    x = xmin + pos(1) - 1;  y = ymin + pos(2) - 1;

                    % Draw accepted ROI and label on the main figure
                    figure(hfig);
                    viscircles([x, y], R, 'EdgeColor', 'r', 'LineWidth', 1.5);
                    text(x, y, num2str(i), 'Color', 'y', 'FontWeight', 'bold', 'FontSize', 14, 'HorizontalAlignment', 'center');

                    % Build circular mask and extract mean spectrum
                    centros(i,:) = [x, y];
                    [xx,yy] = meshgrid(1:ncol, 1:nrow);
                    mask = (xx-x).^2 + (yy-y).^2 <= R^2;
                    pixs = reshape(cube_cal,[],nb);
                    pixs_roi = pixs(mask(:),:);
                    spectra(i,:) = mean(pixs_roi,1);

                    aceptado_fruto = true;
                elseif repetir_click
                    close(hfig_zoom);
                    break; % Ask the user to click again on the main figure
                end
            end
        end
    end
    hold off;

    % --- EXTRACT YEAR & SAMPLE FROM NAME (e.g., FX10_2023_10_...) ---
    tok = regexp(nombre_muestra, '^[A-Za-z0-9]+_(\d{4})_(\d+)_', 'tokens', 'once');
    if isempty(tok)
        anio_str = '';
        muestra_str = '';
        warning('Could not extract YEAR and SAMPLE from "%s".', nombre_muestra);
    else
        anio_str    = tok{1};   % '2023'
        muestra_str = tok{2};   % '10'
    end

    % --- YEAR OUTPUT FOLDER (repo-relative) ---
    carpeta_salida = fullfile(resultsBase_FX10, 'resultados', anio_str);
    if ~exist(carpeta_salida,'dir'), mkdir(carpeta_salida); end

    % --- NORMALIZED SAVE NAME (lowercase, ASCII, single underscores) ---
    nombre_guardar = lower(nombre_muestra);
    nombre_guardar = regexprep(nombre_guardar, '[áéíóúñ]', {'a','e','i','o','u','n'});
    nombre_guardar = regexprep(nombre_guardar, '[^\w-]', '_');
    nombre_guardar = regexprep(nombre_guardar, '_+', '_');

    % --- SAVE ROI IMAGE (overview with all accepted circles) ---
    img_out_path = fullfile(carpeta_salida, ['ROIs_', nombre_guardar, '.png']);
    saveas(hfig, img_out_path);
    disp(['ROI image saved at: ', img_out_path]);

    % --- OUTPUT TABLE: Sample | Year | λ1 ... λnb ---
    tabla_out = cell(Nfrutos + 1, nb + 2);
    tabla_out(1,1:2) = {'Muestra','Año'};
    for j = 1:nb, tabla_out{1, j+2} = lambda(j); end
    for i = 1:Nfrutos
        tabla_out{i+1,1} = muestra_str;
        tabla_out{i+1,2} = anio_str;
        tabla_out(i+1, 3:nb+2) = num2cell(spectra(i,:));
    end

    % Excel export per sample/year
    excel_out_path = fullfile(carpeta_salida, ['espectros_', nombre_guardar, '.xlsx']);
    writecell(tabla_out, excel_out_path);
    disp(['Spectra exported to: ', excel_out_path]);
end

% --- FINAL MESSAGE ---
disp('>> PROCESS COMPLETED for all FX10 PAPRIKA samples (3 YEARS).');

end
