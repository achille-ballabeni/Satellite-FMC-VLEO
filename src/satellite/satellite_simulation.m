classdef satellite_simulation < handle
    % SATELLITE Satellite class to initialize, simulate, perform analysis and
    % visualize the orbit of a satellite.

    properties (Constant)
        Re = earthRadius; % [m]
        mi = 398600.418e9; % [m^3/s^2]
    end

    properties
        orbital_parameters % Initial orbital parameters
        initial_attitude % Initial Euler rotation angles in the order XYZ
        initial_angular_velocity % Initial angular velocity vector (ECI frame)
        startTime % Start time of the simulation
        simLength % Duration of the simulation [s]
        simIn % Simulink simulation input object
        simOut % Simulink simulation output object
        t % Time vector from simulation output
        Rsat % Satellite position in ECI
        Vsat % Satellite velocity in ECI
        Qeci2body % Attitude quaternion (inertial to body)
        Qbody2eci % Attitude quaternion (body to inertial)
        Rlos % Line of sight position (from satellite to earth)
        Rtar % Target position
        Vtar % Target velocity
        Wsat_b % Satellite angular velocity
    end

    methods
        function obj = satellite_simulation(orbital_parameters, attitude, angular_velocity, startTime)
            % SATELLITE Initialize the satellite class with initial
            % conditions.
            %
            % Input Arguments
            %   orbital_parameters - Orbital parameters [semimajor-axis, eccentricity, inclination, right ascension, arguement of pericenter, true anomaly] in meters and degrees.
            %     6-by-1 array
            %   attitude - Euler rotation angles with in the order XYZ in degrees.
            %     3-by-1 array
            %   angular_velocity - Initial angular velocity vector in deg/s (ECI frame).
            %     3-by-1 array
            %   startTime - Start time of the simulation.
            %     datetime

            arguments
                orbital_parameters (6,1) double
                attitude (3,1) double
                angular_velocity (3,1) double
                startTime (1,1) datetime
            end

            obj.orbital_parameters = orbital_parameters;
            obj.initial_attitude = attitude;
            obj.initial_angular_velocity = angular_velocity;
            obj.startTime = startTime;
        end

        function obj = initialize_model(obj,model_path,options)
            % INITIALIZE_MODEL Initializes simulink model with initial conditions.
            % Converts and extract class inputs to initial values for the 
            % simulink model.
            % 
            % Input Arguments
            %   model_path - Path to the Simulink model as a string.
            %     1-by-1 string
            %   duration - Duration of the simulation in seconds. If not
            %     provided, the function will calculate the period based on
            %     the semi-major axis.
            %     1-by-1 double
            
            arguments
                obj
                model_path (1,1) string
                options.duration = []
                options.timestep double = 1
            end
            
            % Convert to Julian date
            startTimeJD = juliandate(obj.startTime);

            % Unpack orbital parameters
            a = obj.orbital_parameters(1); % Semi-major axis
            e = obj.orbital_parameters(2); % Eccentricity
            i = obj.orbital_parameters(3); % Inclination
            raan = obj.orbital_parameters(4); % Right Ascension of Ascending Node
            aop = obj.orbital_parameters(5); % Argument of Perigee
            ta = obj.orbital_parameters(6); % True Anomaly

            % Define simulation duration
            if options.duration
                obj.simLength = options.duration;
            else
                T = period(a,obj.mi);
                obj.simLength = T;
            end

            % Convert attiude to quaternion (assuming ZYX rotation)
            theta1 = deg2rad(obj.initial_attitude(1));
            theta2 = deg2rad(obj.initial_attitude(2));
            theta3 = deg2rad(obj.initial_attitude(3));
            q0 = angle2quat(theta3,theta2,theta1,"ZYX");

            % Initial angular velocity
            w0 = obj.initial_angular_velocity;

            % Setup simulation parameters
            obj.simIn = Simulink.SimulationInput(model_path);
            obj.simIn = obj.simIn.setModelParameter("StopTime", num2str(obj.simLength), ...
                "Solver","ode4", ...
                "FixedStep", num2str(options.timestep), ...
                "AbsTol","1e-8", ...
                "RelTol","1e-8");
            obj.simIn = obj.simIn.setBlockParameter("satellite_propagator/Spacecraft Dynamics", "startDate", num2str(startTimeJD));
            obj.simIn = obj.simIn.setBlockParameter("satellite_propagator/Spacecraft Dynamics", "semiMajorAxis", num2str(a));
            obj.simIn = obj.simIn.setBlockParameter("satellite_propagator/Spacecraft Dynamics", "eccentricity", num2str(e));
            obj.simIn = obj.simIn.setBlockParameter("satellite_propagator/Spacecraft Dynamics", "inclination", num2str(i));
            obj.simIn = obj.simIn.setBlockParameter("satellite_propagator/Spacecraft Dynamics", "raan", num2str(raan));
            obj.simIn = obj.simIn.setBlockParameter("satellite_propagator/Spacecraft Dynamics", "argPeriapsis", num2str(aop));
            obj.simIn = obj.simIn.setBlockParameter("satellite_propagator/Spacecraft Dynamics", "trueAnomaly", num2str(ta));
            obj.simIn = obj.simIn.setBlockParameter("satellite_propagator/Spacecraft Dynamics", "attitude", mat2str(q0));
            obj.simIn = obj.simIn.setBlockParameter("satellite_propagator/Spacecraft Dynamics", "attitudeRate", mat2str(w0));

        end

        function obj = simulate(obj)
            % RUN Runs the simulink model.

            obj.simOut = sim(obj.simIn);
            obj.t = obj.simOut.tout;

            % Save the satellite position and attitude in ECI.
            obj.Rsat = obj.simOut.yout{1}.Values.Data;
            obj.Vsat = obj.simOut.yout{2}.Values.Data;
            obj.Qeci2body = obj.simOut.yout{4}.Values.Data;
            obj.Wsat_b = deg2rad(obj.simOut.yout{5}.Values.Data);
            obj.Qbody2eci = quatinv(obj.Qeci2body);

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
            Rsat_ts = obj.simOut.yout{1}.Values;
            Qin2body_ts = obj.simOut.yout{4}.Values;
            
            % Setup satellite scenario object
            stopTime = obj.startTime + seconds(obj.simLength);
            sc = satelliteScenario(obj.startTime,stopTime,options.sampleTime);
            numericalPropagator(sc,"GravitationalPotentialModel","point-mass", ...
                "IncludeAtmosDrag",false, ...
                "IncludeSRP",false, ...
                "IncludeThirdBodyGravity",false);
            
            % Add satellite
            sat = satellite(sc,Rsat_ts,"Name",options.Name);
            pointAt(sat,Qin2body_ts,"ExtrapolationMethod","fixed"); %TODO: understand why the attitude does not span the whole simulation time
            groundTrack(sat);
            sat.Visual3DModel = "bus.glb";
            coordinateAxes(sat);

            % Add conical sensor
            los_sensor = conicalSensor(sat,"MaxViewAngle",1,"MountingAngles",[0,-90,0]);
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
            % the x axis of the satellite.
            LOS_hat = quatrotate(obj.Qbody2eci,[-1,0,0]);

            if options.model == "sphere"
                % Intersection between line of sight and earth surface
                rho = sphere_intersection(obj.Re,obj.Rsat,LOS_hat);
            elseif options.model == "WGS84"
                % Insersection between line of sight and the WGS84
                % ellispoid https://en.wikipedia.org/wiki/World_Geodetic_System#WGS84
                a = 6378137.0;
                b = a;
                c = 6356752.314245;
                rho = ellipsoid_intersection([a,b,c],obj.Rsat,LOS_hat);
            else
                error("The type %s is unknown for the LOS calculation", options.type)
            end

            % Find the LOS vector and target position vector
            obj.Rlos = rho.*LOS_hat; 
            obj.Rtar = obj.Rsat + obj.Rlos;

            % Angular velocity in inertial frame
            Wsat_eci = quatrotate(obj.Qbody2eci,obj.Wsat_b);

            % Target velocity
            obj.Vtar = obj.Vsat - (dot(obj.Rlos,obj.Vsat,2) + dot(obj.Rsat,cross(Wsat_eci,obj.Rlos),2))./(dot(obj.Rsat,LOS_hat,2) + rho).*LOS_hat + cross(Wsat_eci,obj.Rlos);
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