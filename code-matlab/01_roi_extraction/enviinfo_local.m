function info = enviinfo_local(hdrfile)
% Lee metadatos básicos de un .hdr ENVI
assert(exist(hdrfile,'file')==2, 'No existe el HDR: %s', hdrfile);
txt = fileread(hdrfile);

info = struct();
info.filename = hdrfile;

% Campos numéricos
info.samples = str2double( get_token(txt, 'samples\s*=\s*([0-9]+)') );
info.lines   = str2double( get_token(txt, 'lines\s*=\s*([0-9]+)') );
info.bands   = str2double( get_token(txt, 'bands\s*=\s*([0-9]+)') );
dt           = get_token(txt, 'data\s*type\s*=\s*([0-9]+)');
assert(~isempty(dt), 'Falta "data type" en %s', hdrfile);
info.data_type = str2double(dt);

% Campos de texto / opcionales
intr = get_token(txt, 'interleave\s*=\s*([^\r\n]+)');
if isempty(intr), intr = 'bsq'; end
info.interleave = lower(strtrim(intr));

bo = get_token(txt, 'byte\s*order\s*=\s*([01])');
if isempty(bo), bo = '0'; end
info.byte_order = str2double(bo); % 0=little, 1=big

% Longitudes de onda (opcional)
w = regexp(txt, 'wavelength\s*=\s*{\s*([^}]*)\s*}', 'tokens', 'once');
if ~isempty(w)
    info.wavelength = sscanf(w{1}, '%f,');
else
    info.wavelength = [];
end
end

% ------------ subfunción auxiliar ------------
function tok = get_token(txt, pattern)
m = regexp(txt, pattern, 'tokens', 'once');
if isempty(m), tok = ''; else, tok = m{1}; end
end
