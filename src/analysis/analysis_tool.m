classdef analysis_tool < handle
    % ANALYSIS_TOOL Class for managing and running batch simulation
    %               analyses.
    %
    % This class provides methods to load simulation results from a batch
    % folder and run analysis scripts on the data. It supports caching
    % loaded data and allows running all or individual analysis scripts
    % with all or a subset of simulations.
    
    properties (Access = private)
        batchPath % Path to batch folder
        simData % Cached simulation data from simout.mat
        isDataLoaded = false % Flag indicating if data is loaded
    end
    
    methods (Access = public)
        function obj = analysis_tool(options)
            % ANALYSIS_TOOL Initialize the Analysis Tool class with path to
            % batch folder and simulation ID to run.
            %
            % Input Arguments
            %   options.batchPath - The path to the batch folder. UI opens
            %       if not assigned.
            %     string

            arguments
                options.batchPath string = "";
            end
            
            if options.batchPath == ""
                % No path specified, use interactive selection
                batchPath = string(uigetdir(pwd, 'Select Batch Folder'));
            else
                batchPath = options.batchPath;
            end

            % Validate path exists
            if ~isfolder(batchPath)
                error("Path does not exist: %s", batchPath);
            end
            
            % Assign batch path
            obj.batchPath = batchPath;
            fprintf('Batch folder set to: %s\n', obj.batchPath);
        end
        
        function data = getData(obj)
            % GETDATA Load simulation data from simout.mat if not cached.
            
            if ~obj.isDataLoaded
                simOutFile = fullfile(obj.batchPath, "simout.mat");
                try
                    obj.simData = load(simOutFile).results;
                    obj.isDataLoaded = true;
                    fprintf('Loaded data from %s \n', simOutFile);
                catch
                    error('File simout.mat not found in %s.', obj.batchPath);
                end
            else
                fprintf("Simulation data is already loaded. \n")
            end
            data = obj.simData;
        end
        
        function runAllAnalyses(obj,options)
            % RUNALLANALYSES Run all analysis scripts in the batch folder
            %
            % Input Arguments
            %   options.simID - Simulation number used to run the analysis,
            %       all simulations are run if not assigned.
            %     scalar || 1D-array

            arguments
                obj 
                options.simID int8 = 0
            end

            % Load simout data
            obj.getData();
            
            % Set which simulations to run
            if options.simID == 0
                simulations = 1:length(obj.simData);
            else
                simulations = option.simID;
            end
            
            % Run all analysis scripts in the batch folder
            fprintf('\n=== Running All Analyses ===\n');
            
            % Find all .m files in batch folder
            basePath = fileparts(mfilename("fullpath"));
            scriptFiles = dir(fullfile(basePath,"scripts",'ANA_*.m'));
            
            if isempty(scriptFiles)
                warning('No analysis scripts (.m files) found in: %s', obj.batchPath);
                return;
            end
            
            % Run each script
            for k = 1:length(scriptFiles)
                % Strip extension from filename
                [~, scriptName] = fileparts(scriptFiles(k).name);
                fprintf('\n--- Running: %s ---\n', scriptName);

                try
                    feval(string(scriptName), ...
                        "data",obj.simData, ...
                        "simulations",simulations)
                catch ME
                    warning('Script %s failed: %s', scriptName, ME.message);
                end
            end
            
            fprintf('\n=== All Analyses Complete ===\n');
        end
        
        function runSingleAnalysis(obj, scriptNumber, options)
            % RUNSINGLEANALYSIS Run a single analysis script.
            %
            % Input Arguments
            %   scriptNumber - Identifier of analysis script to run.
            %     string
            %   options.simID - Simulation number used to run the analysis,
            %       all simulations are run if not assigned.
            %     scalar

            arguments
                obj 
                scriptNumber string
                options.simID int8 = 0
            end

            % Load simout data
            obj.getData();
            
            % Set which simulations to run
            if options.simID == 0
                simulations = 1:length(obj.simData);
            else
                simulations = options.simID;
            end
            
            basePath = fileparts(mfilename("fullpath"));
            scriptFile = dir(fullfile(basePath,"scripts",strcat("ANA_",scriptNumber,"_*.m")));
            [~, scriptName] = fileparts(scriptFile.name);
            
            fprintf('\n--- Running: %s ---\n', scriptName);
            try
                feval(scriptName, ...
                    "data",obj.simData, ...
                    "simulations",simulations)
            catch ME
                warning('Script %s failed: %s', scriptName, ME.message);
            end
        end
    end
        
    methods (Access = public)
        function path = getBatchPath(obj)
            % GETBATCHPATH Get the current batch folder path.
            path = obj.batchPath;
        end
        
        function clearCache(obj)
            % CLEARCACHE Clear cached data to force reload on next
            %            getData() call.
            obj.simData = [];
            obj.isDataLoaded = false;
            fprintf('Cache cleared.\n');
        end
    end
end