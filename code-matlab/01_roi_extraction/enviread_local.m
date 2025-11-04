function cube = enviread_local(info, rawfile)
fid = fopen(rawfile, 'r');
switch info.data_type
    case 1;  dtype = 'uint8';
    case 2;  dtype = 'int16';
    case 3;  dtype = 'int32';
    case 4;  dtype = 'single';
    case 5;  dtype = 'double';
    case 12; dtype = 'uint16';
    otherwise; error('Unsupported data type');
end
total = info.samples * info.lines * info.bands;
raw = fread(fid, total, dtype);
fclose(fid);
if numel(raw) ~= total
    error('Data size mismatch when reading the file.');
end
switch lower(info.interleave)
    case 'bsq'
        cube = reshape(raw, [info.samples, info.lines, info.bands]);
    case 'bil'
        cube = reshape(raw, [info.samples, info.bands, info.lines]);
        cube = permute(cube, [1 3 2]);
    case 'bip'
        cube = reshape(raw, [info.samples, info.bands, info.lines]);
        cube = permute(cube, [1 3 2]);
    otherwise
        error('Unknown interleave format');
end
cube = permute(cube, [2 1 3]);  % Para que quede en formato [filas, columnas, bandas]
end
