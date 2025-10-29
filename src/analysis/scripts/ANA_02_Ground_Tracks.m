function ANA_02_Ground_Tracks(options)
% ANA_02_GROUND_TRACKS This script computes the ground track vector of
% the satellite or the LOS.
arguments (Input)
    options.simulations (1,:) = 1;
    options.data struct = [];
end
script_name = "ANA_02";

%%%%%% LOAD SIMULATION RESULTS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if isempty(options.data)
    data = load_data().results;
else
    fprintf("Simulation data is already loaded.\n")
    data = options.data;
end

%%%%%% PARAMETER INITIALIZATION and PRE-PROCESSING %%%%%%%%%%%%%%%%%%%%%%%%
% Create figures outside the loop
fig1 = figure("Name","ECEF Ground Tracks");
geobasemap("satellite")
hold on

fig2 = figure("Name","ECI Ground Tracks");
ax2 = axes(fig2);
hold(ax2, 'on')
grid(ax2, 'on')
view(ax2, 3)  % Set 3D view

for k = options.simulations
    Re = data(k).Re;
    t = data(k).t;
    startTime = data(k).startTime;
    Rsat = data(k).simOut.X_eci.Data;
    Qeci2body = data(k).simOut.Q_eci2body.Data;
    Qbody2eci = quatinv(Qeci2body);
    LOS_hat = quatrotate(Qbody2eci,[0,0,1]);
    earth_model = "sphere";
    
    %%%%%% PERFORM ANALYSIS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Find direction of line of sight, considered as exiting from
    % the z axis of the satellite.
    if earth_model == "sphere"
        % Intersection between line of sight and earth surface
        rho = sphere_intersection(Re,Rsat,LOS_hat);
    elseif earth_model == "WGS84"
        % Intersection between line of sight and the WGS84
        % ellipsoid https://en.wikipedia.org/wiki/World_Geodetic_System#WGS84
        a = 6378137.0;
        b = a;
        c = 6356752.314245;
        rho = ellipsoid_intersection([a,b,c],Rsat,LOS_hat);
    else
        error("The type %s is unknown for the LOS calculation", earth_model)
    end
    
    % Find the LOS vector and target position vector
    Rlos = rho.*LOS_hat;
    Rtar = Rsat + Rlos;
    
    % Find ground tracks in ECI
    [R_gt_sat_eci, ~] = ground_tracks(Rsat,Re, ...
        "type","satellite", ...
        "frame","eci", ...
        "model","sphere");
    [R_gt_tar_eci, ~] = ground_tracks(Rtar,Re, ...
        "type", "los", ...
        "frame", "eci", ...
        "model", "sphere", ...
        "Rlos", Rlos);
    
    % Find ground tracks in ECEF
    [~, lla_sat] = ground_tracks(Rsat,Re, ...
        "type","satellite", ...
        "frame","ecef", ...
        "model","sphere", ...
        "t",t, ...
        "startTime",startTime);
    [~, lla_tar] = ground_tracks(Rtar,Re, ...
        "type", "los", ...
        "frame", "ecef", ...
        "model", "sphere", ...
        "Rlos",Rlos, ...
        "t",t, ...
        "startTime",startTime);
    
    % Latitude and longitude
    ll_sat = lla_sat(:,1:2);
    ll_tar = lla_tar(:,1:2);
    
    %%%%%% PLOTTING %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Plot ground tracks in ECEF
    figure(fig1)
    geoplot(ll_sat(:,1),ll_sat(:,2),'DisplayName',sprintf('Satellite - Sim %d',k))
    geoplot(ll_tar(:,1),ll_tar(:,2),'DisplayName',sprintf('LoS - Sim %d',k))
    
    % Plot ground tracks in ECI
    figure(fig2)
    plot3(ax2, Rsat(:,1),Rsat(:,2),Rsat(:,3),'DisplayName',sprintf('Satellite - Sim %d',k))
    plot3(ax2, R_gt_sat_eci(:,1), R_gt_sat_eci(:,2), R_gt_sat_eci(:,3),'DisplayName',sprintf('Sat GT - Sim %d',k))
    plot3(ax2, R_gt_tar_eci(:,1),R_gt_tar_eci(:,2),R_gt_tar_eci(:,3),'DisplayName',sprintf('LoS GT - Sim %d',k))
end

% Finalize figure 1
figure(fig1)
legend("show","Location","best")
title("ECEF Ground Tracks")
savefig(script_name+"_GtECEF")

% Finalize figure 2
figure(fig2)
axis(ax2, 'equal')
legend(ax2, "show","Location","best")
xlabel(ax2, "x [m]")
ylabel(ax2, "y [m]")
zlabel(ax2, "z [m]")
title(ax2, "ECI Ground Tracks")
savefig(script_name+"_GtECI")

end