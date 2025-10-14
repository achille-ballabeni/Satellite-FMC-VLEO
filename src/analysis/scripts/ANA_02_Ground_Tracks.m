%% ANA_02_Ground_Tracks

% This scripts computes the ground track vector of the satellite or the
% LOS.

script_name = "ANA02";

%% LOAD SIMULATION RESULTS
if ~exist('data', 'var')
    data = load_data().results;
else
    fprintf("Simulation data is already loaded.\n")
end

%% PARAMETER INITIALIZATION and PRE-PROCESSING
Re = data(1).Re;
t = data(1).t;
Rsat = data(1).simOut.yout{1}.Values.Data;
Vsat = data(1).simOut.yout{2}.Values.Data;
Qeci2body = data(1).simOut.yout{4}.Values.Data;
Wsat_body = data(1).simOut.yout{5}.Values.Data;

Qbody2eci = quatinv(Qeci2body);
LOS_hat = quatrotate(Qbody2eci,[0,0,1]);

earth_model = "sphere";

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

% Find ground tracks in ECI
[R_gt_sat_eci, ~] = ground_tracks(Rsat,Re,"type","satellite","frame","eci","model","sphere");
[R_gt_tar_eci, ~] = ground_tracks(Rtar,Re,"type","los","frame","eci","model","sphere","Rlos",Rlos);

% Find ground tracks in ECEF
[R_gt_sat_ecef, lla_sat] = ground_tracks(Rsat,Re,"type","satellite","frame","eci","model","sphere");
[R_gt_tar_ecef, lla_tar] = ground_tracks(Rtar,Re,"type","los","frame","eci","model","sphere","Rlos",Rlos);

% Latitude and longitude
ll_sat = lla_sat(:,1:2);
ll_tar = lla_tar(:,1:2);

%% PLOTTING
% Plot ground tracks in ECEF
figure("Name","ECEF Ground Tracks")
geoplot(ll_sat(:,1),ll_sat(:,2))
hold on
geoplot(ll_tar(:,1),ll_tar(:,2))
legend("Satellite","LoS")
geobasemap("satellite")
title("ECEF Ground Tracks")
savefig(script_name+"_GtECEF")

% Plot ground tracks in ECI
figure("Name","ECI Ground Tracks")
plot3(cubesat.Rsat(:,1),cubesat.Rsat(:,2),cubesat.Rsat(:,3))
hold on
plot3(R_gt_sat_eci(:,1), R_gt_sat_eci(:,2), R_gt_sat_eci(:,3))
plot3(R_gt_tar_eci(:,1),R_gt_tar_eci(:,2),R_gt_tar_eci(:,3))
axis equal
grid on
legend("Satellite","Satellite ground track","LoS")
xlabel("x [m]")
ylabel("y [m]")
zlabel("z [m]")
title("ECI Ground Tracks")
savefig(script_name+"_GtECI")