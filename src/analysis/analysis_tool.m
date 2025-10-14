classdef analysis_tool < handle
    % BatchAnalyzer - Tool for analyzing batch simulation results
    %
    % Usage:
    %   analyzer = BatchAnalyzer();              % Interactive folder selection
    %   analyzer = BatchAnalyzer(batchPath);     % Specify path directly
    %   analyzer.runAllAnalyses();               % Run all analysis scripts
    %   analyzer.ru nAnalysis('analysisName');    % Run specific analysis
    
    properties (Access = private)
        batchPath           % Path to batch folder
        simData             % Cached simulation data from simOut.mat
        isDataLoaded = false % Flag indicating if data is loaded
    end
    
    methods (Access = public)
        function obj = BatchAnalyzer(batchPath)
            % Constructor - initialize analyzer with batch folder path
            %
            % Inputs:
            %   batchPath - (optional) Path to batch folder containing simOut.mat
            
            if nargin < 1 || isempty(batchPath)
                % No path specified, use interactive selection
                batchPath = uigetdir(pwd, 'Select Batch Folder');
                if batchPath == 0
                    error('BatchAnalyzer:NoPath', 'No folder selected');
                end
            end
            
            % Validate path exists
            if ~isfolder(batchPath)
                error('BatchAnalyzer:InvalidPath', 'Path does not exist: %s', batchPath);
            end
            
            obj.batchPath = batchPath;
            fprintf('Batch folder set to: %s\n', batchPath);
        end
        
        function data = getData(obj)
            % Get cached simulation data (auto-loads on first call)
            %
            % Returns:
            %   data - Structure containing all variables from simOut.mat
            
            if ~obj.isDataLoaded
                simOutFile = fullfile(obj.batchPath, 'simOut.mat');
                
                if ~isfile(simOutFile)
                    error('BatchAnalyzer:FileNotFound', 'simOut.mat not found in: %s', obj.batchPath);
                end
                
                fprintf('Loading data from: %s\n', simOutFile);
                obj.simData = load(simOutFile);
                obj.isDataLoaded = true;
                fprintf('Data loaded successfully. Variables: %s\n', strjoin(fieldnames(obj.simData), ', '));
            end
            
            data = obj.simData;
        end
        
        function runAllAnalyses(obj)
            % Run all analysis scripts in the batch folder
            
            fprintf('\n=== Running All Analyses ===\n');
            
            % Find all .m files in batch folder
            scriptFiles = dir(fullfile(obj.batchPath, '*.m'));
            
            if isempty(scriptFiles)
                warning('No analysis scripts (.m files) found in: %s', obj.batchPath);
                return;
            end
            
            % Get data once (cached for all scripts)
            data = obj.getData(); %#ok<NASGU>
            
            % Run each script
            for i = 1:length(scriptFiles)
                scriptName = scriptFiles(i).name;
                fprintf('\n--- Running: %s ---\n', scriptName);
                try
                    % Change to batch folder and run script
                    currentDir = pwd;
                    cd(obj.batchPath);
                    run(scriptName);
                    cd(currentDir);
                catch ME
                    cd(currentDir); % Ensure we return to original directory
                    warning('Script %s failed: %s', scriptName, ME.message);
                end
            end
            
            fprintf('\n=== All Analyses Complete ===\n');
        end
        
        function runAnalysis(obj, scriptName)
            % Run a specific analysis script by name
            %
            % Inputs:
            %   scriptName - Name of script file (with or without .m extension)
            
            % Add .m extension if not present
            if ~endsWith(scriptName, '.m')
                scriptName = [scriptName '.m'];
            end
            
            scriptPath = fullfile(obj.batchPath, scriptName);
            
            % Check if script exists
            if ~isfile(scriptPath)
                error('BatchAnalyzer:ScriptNotFound', 'Script not found: %s', scriptPath);
            end
            
            % Get data (cached)
            data = obj.getData(); %#ok<NASGU>
            
            fprintf('\n--- Running: %s ---\n', scriptName);
            currentDir = pwd;
            try
                cd(obj.batchPath);
                run(scriptName);
                cd(currentDir);
            catch ME
                cd(currentDir);
                rethrow(ME);
            end
        end
        
    methods (Access = public)
        function path = getBatchPath(obj)
            % Get the current batch folder path
            path = obj.batchPath;
        end
        
        function clearCache(obj)
            % Clear cached data to force reload on next getData() call
            obj.simData = [];
            obj.isDataLoaded = false;
            fprintf('Cache cleared.\n');
        end
    end
end