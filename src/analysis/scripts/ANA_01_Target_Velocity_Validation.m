function ANA_01_Target_Velocity_Validation(options)

% ANA_01_TARGET_VELOCITY_VALIDATION This scripts compares the Target
% Velocity obtained from the analytical formulation with the one computed
% numerically.

arguments (Input)
    options.iteration (1,1) = 1;
    options.data struct = [];
end

script_name = "ANA_01";

%% LOAD SIMULATION RESULTS
if isempty(options.data)
    data = load_data().results;
else
    fprintf("Simulation data is already loaded.\n")
    data = options.data;
end

%% PARAMETER INITIALIZATION and PRE-PROCESSING
Re = data(options.iteration).Re;
t = data(options.iteration).t;
Rsat = data(options.iteration).simOut.yout{1}.Values.Data;
Vsat = data(options.iteration).simOut.yout{2}.Values.Data;
Qeci2body = data(options.iteration).simOut.yout{4}.Values.Data;
Wsat_body = data(options.iteration).simOut.yout{5}.Values.Data;

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

% Angular velocity in inertial frame
Wsat_eci = quatrotate(Qbody2eci,Wsat_body);

% Target velocity
Vtar = target_velocity(rho,LOS_hat,Rsat,Vsat,Wsat_eci);

% Find numerical derivative
[Vtar_numerical,t_der,idx] = derivative(Rtar,t,method="edgepoint");

% Calculate the relative error
Vtar_diff = abs(Vtar(idx,:) - Vtar_numerical)./Vtar(idx,:);

%% PLOTTING
% Compare velocities
figure("Name","Velocity components vs Time")
plot(ones(size(Vtar)).*t,Vtar)
hold on
plot(ones(size(Vtar_numerical)).*t_der,Vtar_numerical,"x","LineWidth",1)
legend("u - analytic","v - analytic","w - analytic","u - numerical","v - numerical","w - numerical")
xlabel("Time [s]")
ylabel("Velocity [m/s]")
title("Velocity components vs Time")
grid on
savefig(script_name+"_VelocityComponents")

% Velocity relative errors
figure("Name","Analytic vs Numerical Derivatives - Relative Errors")
% Subplot 1: Difference in u component
subplot(3,1,1)
plot(t_der,Vtar_diff(:,1),"x","LineWidth",1.5)
hold on
plot(t_der,zeros(size(Vtar_diff(:,1))), 'r--') % Reference line at zero
title('Relative error - u component')
xlabel('Time [s]')
ylabel('Relative error')
grid on

% Subplot 2: Difference in v component
subplot(3,1,2)
plot(t_der,Vtar_diff(:,2),"x","LineWidth",1.5)
hold on
plot(t_der,zeros(size(Vtar_diff(:,2))), 'r--') % Reference line at zero
title('Relative error - v component')
xlabel('Time [s]')
ylabel('Relative error')
grid on

% Subplot 3: Difference in w component
subplot(3,1,3)
plot(t_der,Vtar_diff(:,3),"x","LineWidth",1.5)
hold on
plot(t_der,zeros(size(Vtar_diff(:,3))), 'r--') % Reference line at zero
title('Relative error - w component')
xlabel('Time [s]')
ylabel('Relative error')
grid on

% Adjust layout
sgtitle("Analytic vs Numerical Derivatives - Relative Errors")
savefig(script_name+"_VelocityRelativeErrors")

end