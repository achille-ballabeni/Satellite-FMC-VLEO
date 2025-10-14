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
        simOut % Simulink simulation output object
        t % Time vector from simulation output
        Rsat % Satellite position in ECI [m]
        Vsat % Satellite velocity in ECI [m]
        Qeci2body % Attitude quaternion (inertial to body)
        Qbody2eci % Attitude quaternion (body to inertial)
        Rlos % Line of sight position (from satellite to earth) [m]
        Rtar % Target position [m]
        Vtar % Target velocity [m]
        Wsat_b % Satellite angular velocity [rad/s]
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

            % Store the satellite position and attitude in ECI.
            % NOTE: All these parameters will be removed once the
            % post-processing is moved to analysis tools.
            obj.Rsat = obj.results(options.iteration).simOut.yout{1}.Values.Data;
            obj.Vsat = obj.results(options.iteration).simOut.yout{2}.Values.Data;
            obj.Qeci2body = obj.results(options.iteration).simOut.yout{4}.Values.Data;
            obj.Wsat_b = obj.results(options.iteration).simOut.yout{5}.Values.Data;
            obj.Qbody2eci = quatinv(obj.Qeci2body);

        end

        function obj = export_results(obj,options)
            % EXPORT_RESULTS Saves simulation data to corresponding batch
            % folder.
            %
            % Input Arguments
            %   destination - Path to the folder where simulation data is saved.
            %   string

            arguments
                obj
                options.destination (1,1) string = "..\results"
            end
            
            timestamp = string(datetime('now','Format','uuuu-MM-dd_HH-mm-ss'));
            batch_folder = options.destination + "\" + timestamp;
            mkdir(batch_folder);
            results_file = batch_folder + "\" + "simout.mat";
            results = obj.results;
            save(results_file, "results")

        end

        function play_scenario(obj,los_gt,options)
            % PLAY_SCENARIO Play the simulation in a satelliteScenario.
            % Set simulation duration to equivalent Simulink duration.
            %
            % Input Arguments
            %   los_gt - Geographic coordinates (lat,lon,alt) of the LOS intersection.
            %     n-by-3 array
            %   sampleTime - Timestep of satellite scenario simulation (defaults to 60s).
            %     scalar
            %   Name - Name displayed in the simulation (CubeSat by default).
            %     string

            arguments
                obj
                los_gt (:,3) double
                options.sampleTime (1,1) double = 60
                options.Name (1,1) string = "CubeSat"
                
            end

            % Extract timeseries values
            Rsat_ts = obj.results(end).simOut.yout{1}.Values;
            Qeci2body_ts = obj.results(end).simOut.yout{4}.Values;
            
            % Setup satellite scenario object
            stopTime = obj.startTime + seconds(obj.simLength);
            sc = satelliteScenario(obj.startTime,stopTime,options.sampleTime);
            numericalPropagator(sc,"GravitationalPotentialModel","point-mass", ...
                "IncludeAtmosDrag",false, ...
                "IncludeSRP",false, ...
                "IncludeThirdBodyGravity",false);
            
            % Add satellite
            sat = satellite(sc,Rsat_ts,"Name",options.Name);
            pointAt(sat,Qeci2body_ts,"ExtrapolationMethod","fixed"); %TODO: understand why the attitude does not span the whole simulation time
            groundTrack(sat);
            sat.Visual3DModel = "bus.glb";
            coordinateAxes(sat);

            % Add conical sensor
            los_sensor = conicalSensor(sat,"MaxViewAngle",1);
            fieldOfView(los_sensor);

            % LOS intersection
            platform(sc,timeseries(los_gt,obj.t),"Name","LOS_intersection");
            
            % Play scenario
            satelliteScenarioViewer(sc,"CameraReferenceFrame","Inertial");
        end

        function LOS(obj,options)
            % LOS Find the Line-of-Sight vector.
            % The LOS vector is defined as the vector spanning from the
            % satellite origin to its intersection with the earth surface.
            % Its direction is considered as exiting from the x axis of the
            % satellite.
            %
            % Input Arguments
            %   model - "sphere" (default) or "WGS84", Earth model.
            %     string

            arguments
                obj 
                options.model (1,1) string = "sphere" 
            end

            % Find direction of line of sight, considered as exiting from 
            % the z axis of the satellite.
            LOS_hat = quatrotate(obj.Qbody2eci,[0,0,1]);

            if options.model == "sphere"
                % Intersection between line of sight and earth surface
                rho = sphere_intersection(obj.Re,obj.Rsat,LOS_hat);
            elseif options.model == "WGS84"
                % Insersection between line of sight and the WGS84
                % ellipsoid https://en.wikipedia.org/wiki/World_Geodetic_System#WGS84
                a = 6378137.0;
                b = a;
                c = 6356752.314245;
                rho = ellipsoid_intersection([a,b,c],obj.Rsat,LOS_hat);
            else
                error("The type %s is unknown for the LOS calculation", options.model)
            end

            % Find the LOS vector and target position vector
            obj.Rlos = rho.*LOS_hat; 
            obj.Rtar = obj.Rsat + obj.Rlos;

            % Angular velocity in inertial frame
            Wsat_eci = quatrotate(obj.Qbody2eci,obj.Wsat_b);

            % Target velocity
            obj.Vtar = target_velocity(rho,LOS_hat,obj.Rsat,obj.Vsat,Wsat_eci);
        end

        function [Rgt,LLA_gt] = ground_track(obj, options)
            % GROUND_TRACK Computes the ground track vector of the
            % satellite or the LOS.
            %
            % Input Arguments
            %   type - "satellite" or "los". Defaults to "satellite".
            %     string
            %   frame - "eci" or "ecef". Defaults to "eci".
            %     string
            %   model - "sphere" (default) or "WGS84", Earth model.
            %     string

            arguments
                obj 
                options.type (1,1) string = "satellite"
                options.frame (1,1) string = "eci"
                options.model (1,1) string = "sphere"
            end
            
            % Compute corresponding ground track
            if options.type == "satellite"
                % Find ground track of satellite
                Rgt = obj.Rsat .* (obj.Re ./ vecnorm(obj.Rsat, 2, 2));
            elseif options.type == "los"
                % Find ground track of the LOS
                indexes = any(obj.Rlos ~= 0, 2);
                Rgt = obj.Rtar;
                Rgt(~indexes,:) = 0;
            else
                error("The type of groundtrack %s is unknown", type)
            end
            
            if options.frame == "ecef"
                % Find the timetsamps in UTC
                t_utc = obj.startTime + seconds(obj.t);

                % Convert to ECEF
                Rgt = eci2ecef_vect(t_utc,Rgt);
            end

            % Convert to find Latitude, Longitude and Altitude
            if options.model == "WGS84"
                LLA_gt = ecef2lla(Rgt,options.model);
            else
                LLA_gt = ecef2lla(Rgt,0,obj.Re);
            end
            
        end
    end
end