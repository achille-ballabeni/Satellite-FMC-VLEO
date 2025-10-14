%% ANA_03_Satellite_Scenario

% This scripts computes the ground track vector of the satellite or the
% LOS.

script_name = "ANA03";

%% LOAD SIMULATION RESULTS
if ~exist('data', 'var')
    data = load_data().results;
else
    fprintf("Simulation data is already loaded.\n")
end

%% PARAMETER INITIALIZATION and PRE-PROCESSING
Re = data(1).Re;
t = data(1).t;
startTime = data(1).startTime;
simLength = data(1).simLength;
Rsat = data(1).simOut.yout{1}.Values.Data;
Vsat = data(1).simOut.yout{2}.Values.Data;
Qeci2body = data(1).simOut.yout{4}.Values.Data;
Wsat_body = data(1).simOut.yout{5}.Values.Data;

% Extract timeseries values
Rsat_ts = data(1).simOut.yout{1}.Values;
Qeci2body_ts = data(1).simOut.yout{4}.Values;

Qbody2eci = quatinv(Qeci2body);
LOS_hat = quatrotate(Qbody2eci,[0,0,1]);

earth_model = "sphere";
sampleTime = 0.1;
satName = "CubeSat";

%% PERFORM ANALYSIS
% Find direction of line of sight, considered as exiting from 
% the z axis of the satellite.

if earth_model == "sphere"
    % Intersection between line of sight and earth surface
    rho = sphere_intersection(Re,Rsat,LOS_hat);
elseif earth_model == "WGS84"
    % Insersection between line of sight and the WGS84
    % ellipsoid https://en.wikipedia.org/wiki/World_Geodetic_System#WGS84
    a = 6378137.0;
    b = a;
    c = 6356752.314245;
    rho = ellipsoid_intersection([a,b,c],Rsat,LOS_hat);
else
    error("The type %s is unknown for the LOS calculation", model)
end

% Find the LOS vector and target position vector
Rlos = rho.*LOS_hat; 
Rtar = Rsat + Rlos;

% Find ground tracks in ECEF
[~, lla_tar] = ground_tracks(Rtar,Re, ...
    "type","los", ...
    "frame","ecef", ...
    "model","sphere", ...
    "Rlos",Rlos, ...
    "t",t, ...
    "startTime",startTime);

% Latitude and longitude
lla_tar(:,3) = 0;

% Setup satellite scenario object
stopTime = startTime + seconds(simLength);
sc = satelliteScenario(startTime,stopTime,sampleTime);
numericalPropagator(sc, ...
    "GravitationalPotentialModel","point-mass", ...
    "IncludeAtmosDrag",false, ...
    "IncludeSRP",false, ...
    "IncludeThirdBodyGravity",false);

% Add satellite
sat = satellite(sc,Rsat_ts,"Name",satName);
pointAt(sat,Qeci2body_ts,"ExtrapolationMethod","fixed"); %TODO: understand why the attitude does not span the whole simulation time
groundTrack(sat);
sat.Visual3DModel = "SmallSat.glb";
coordinateAxes(sat);

% Add conical sensor
los_sensor = conicalSensor(sat,"MaxViewAngle",1);
fieldOfView(los_sensor);

% LOS intersection
platform(sc,timeseries(lla_tar,t),"Name","LOS_intersection");



%% VISUALIZE
% Play scenario
v = satelliteScenarioViewer(sc,"CameraReferenceFrame","Inertial");
camtarget(v,sat);