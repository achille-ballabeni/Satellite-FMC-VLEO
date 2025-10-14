function [results] = load_data()
%LOAD_DATA Load simulation results for standard 

arguments (Output)
    results
end

batchPath = string(uigetdir('Select Batch Folder containing simOut.mat'));

% Load simulation results.
try
    results = load(string(batchPath) + '\simout.mat');
    fprintf('Loaded data (standalone mode)...\n');
catch
    error('File simout.mat not found in %s.', batchPath);
end

end