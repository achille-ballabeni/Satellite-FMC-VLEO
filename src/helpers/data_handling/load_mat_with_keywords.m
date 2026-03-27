function data = load_mat_with_keywords(dir_path,varargin)



files = dir(fullfile(dir_path, "*.mat"));
mask = true(size(files))';
for i = 1:numel(varargin)
    mask = mask & contains({files.name}, varargin{i}, "IgnoreCase", true);
end
match = files(mask);

if isempty(match)
    error("No .mat file found containing all keywords in:\n%s", dir_path);
end
if ~isscalar(match)
    error("Multiple .mat files matched all keywords in:\n%s", dir_path);
end

data = load(fullfile(dir_path, match.name));
end