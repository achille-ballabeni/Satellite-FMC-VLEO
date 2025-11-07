function [data] = load_data()
%LOAD_DATA Load simulation results for standard analysis script execution.

arguments (Output)
    data
end

batchPath = uigetdir('Select Batch Folder containing simOut.mat');
filepath = fullfile(batchPath,"simout.mat");

% Load simulation results.
try
    data = load(filepath);
    fprintf('Loaded data (standalone mode)...\n');
catch
    error('File simout.mat not found in %s.', batchPath);
end

end