classdef satellite_simulation < handle
    % SATELLITE Satellite class to initialize, simulate, perform analysis and
    % visualize the orbit of a satellite.

    properties (Constant)
        Re = 6378e3; % [m]
        mi = 398600.418e9; % [m^3/s^2]
    end

    properties
        orbital_parameters % Initial orbital parameters [a,e,i,raan,aop,ta]
        initial_attitude % Initial attitude-defining quaternion
        initial_angular_velocity % Initial angular velocity vector (ECI frame) [rad/s]
        startTime % Start time of the simulation [datetime]
        simLength % Duration of the simulation [s]
        simIn % Simulink simulation input object
        t % Time vector from simulation output
        results % Results of the simulations
    end

    methods
        function obj = satellite_simulation(orbital_parameters, attitude, angular_velocity, startTime)
            % SATELLITE Initialize the satellite class with initial
            % conditions.
            %
            % Input Arguments
            %   orbital_parameters - Orbital parameters [semimajor-axis, eccentricity, inclination, right ascension, arguement of pericenter, true anomaly] in meters and degrees.
            %     6-by-1 array
            %   attitude - Quaternion obtained from a XYZ rotation wrt to the ECI frame.
            %     4-by-1 array
            %   angular_velocity - Initial angular velocity vector in deg/s (ECI frame).
            %     3-by-1 array
            %   startTime - Start time of the simulation.
            %     datetime

            arguments
                orbital_parameters (6,1) double
                attitude (4,1) double
                angular_velocity (3,1) double
                startTime (1,1) datetime
            end

            obj.orbital_parameters = orbital_parameters;
            obj.initial_attitude = attitude;
            obj.initial_angular_velocity = angular_velocity;
            obj.startTime = startTime;
        end

        function obj = set_model_parameters(obj,varargin)
            % SET_MODEL_PARAMETERS Initializes simulink model with initial conditions.
            % Converts and extract class inputs to initial values for the 
            % simulink model.
            % 
            % Input Arguments
            %   model_path - Path to the Simulink model as a string.
            %     string scalar
            %   param_path - Path to Simulink model parameter file.
            %     string scalar
            %   duration - Duration of the simulation in seconds. If not
            %     provided, the function will calculate the period based on
            %     the semi-major axis.
            %     1-by-1 double
            %   timestep - Timestep to use for the simulation.
            %     scalar
            %   [param_name] - Any valid model parameter name with its override value.
            
            % Parse inputs to separate options from parameter overrides
            p = inputParser;
            p.KeepUnmatched = true;  % This allows us to capture parameter overrides
            
            % Define expected options
            addParameter(p, 'model_path', "TargetPosVel", @(x) isstring(x) || ischar(x));
            addParameter(p, 'param_path', "ModelParameters", @(x) isstring(x) || ischar(x));
            addParameter(p, 'duration', [], @(x) isempty(x) || isnumeric(x));
            addParameter(p, 'timestep', 1, @isnumeric);
            
            % Parse the inputs
            parse(p, varargin{:});
            options = p.Results;
            paramUpdates = p.Unmatched;

            % Load additional parameters
            params = model_parameters( ...
                options.timestep, ...
                obj.orbital_parameters, ...
                obj.initial_attitude, ...
                obj.initial_angular_velocity, ...
                obj.startTime);
            
            % Get valid parameter names
            validParamNames = fieldnames(params);

            % Process parameter overrides
            if ~isempty(fieldnames(paramUpdates))
                updateNames = fieldnames(paramUpdates);
                for i = 1:numel(updateNames)
                    paramName = updateNames{i};
                    paramValue = paramUpdates.(paramName);
                    
                    % Check if parameter exists in the model
                    if ismember(paramName, validParamNames)
                        % Update the parameter value
                        params.(paramName) = paramValue;
                        fprintf('Parameter "%s" updated to %f.\n', paramName, paramValue);
                    else
                        % Warn if parameter doesn't exist
                        warning('Parameter "%s" is not a valid model parameter and will be ignored.', paramName);
                    end
                end
            end

            % Define simulation duration
            if ~isempty(options.duration)
                obj.simLength = options.duration;
            else
                obj.simLength = params.orbPeriod;
            end

            % Setup simulation parameters
            obj.simIn = Simulink.SimulationInput(options.model_path);
            obj.simIn = obj.simIn.setModelParameter( ...
                "StopTime", num2str(obj.simLength), ...
                "Solver","ode4", ...
                "FixedStep", num2str(options.timestep), ...
                "AbsTol","1e-8", ...
                "RelTol","1e-8");
            
            % Set variables in Simulink
            paramNames = fieldnames(params);
            for k = 1:numel(paramNames)
                obj.simIn = obj.simIn.setVariable(paramNames{k}, params.(paramNames{k}));
            end
        end

        function obj = simulate(obj,options)
            % RUN Run a single simulation of the Simulink model.
            %
            % Input Arguments
            %   iteration - Iteration number/ID under which store results.
            %     scalar

            arguments
                obj 
                options.iteration (1,1) int8 = 1
            end

            obj.results(options.iteration).simOut = sim(obj.simIn);
            obj.results(options.iteration).t = obj.results(options.iteration).simOut.tout;
            obj.results(options.iteration).Re = obj.Re;
            obj.results(options.iteration).startTime = obj.startTime;
            obj.results(options.iteration).simLength = obj.simLength;
            obj.t = obj.results(options.iteration).t;
        end

        function batch_folder = export_results(obj,options)
            % EXPORT_RESULTS Saves simulation data to corresponding batch
            % folder.
            %
            % Input Arguments
            %   destination - Path to the folder where simulation data is
            %       saved.
            %     string
            %
            % Output Arguments
            %   batch_folder - Path to the folder where the simulation data
            %       was saved.
            %     string

            arguments
                obj
                options.destination (1,1) string = "..\results"
            end
            
            timestamp = string(datetime('now','Format','uuuu-MM-dd_HH-mm-ss'));
            batch_folder = fullfile(options.destination,timestamp);
            mkdir(batch_folder);
            results_file = batch_folder + "\" + "simout.mat";
            results = obj.results;
            save(results_file, "results")
        end
    end
end