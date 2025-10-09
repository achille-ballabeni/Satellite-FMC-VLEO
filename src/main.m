clear

%% Orbital parameters and inital conditions
a = 6378e3 + 250e3; % [m]
e = 0;
i = 0;
raan = 237.3113; % [deg]
orbital_parameters = [a;0;0;raan;0;0];
initial_attitude = [0.6387; -0.3737; 0.6003; 0.3034];
initial_angular_velocity = [0;0;0];
startTime = datetime(2025,1,1,12,0,0);

%% Run simulation
timestep = 0.1;
duration = 10;
cubesat = satellite_simulation(orbital_parameters,initial_attitude,initial_angular_velocity,startTime);
cubesat.initialize_model(duration=duration,timestep=timestep);
cubesat.simulate();

%% Perform LOS analysis
cubesat.LOS();
% Ground track vectors in ECI
[R_gt_sat_eci, ~]  = cubesat.ground_track(type="satellite",frame="eci",model="sphere");
[R_gt_tar_eci, ~] = cubesat.ground_track(type="los",frame="eci",model="sphere");
% Ground track vectors in ECEF
[R_gt_sat_ecef, lla_sat] = cubesat.ground_track(type="satellite",frame="ecef",model="sphere");
[R_gt_tar_ecef, lla_tar] = cubesat.ground_track(type="los",frame="ecef",model="sphere");

% Latitude and longitude
ll_sat = lla_sat(:,1:2);
ll_tar = lla_tar(:,1:2);

% Find numerical derivative
[Vtar_numerical,t_der,idx] = derivative(cubesat.Rtar,cubesat.t,method="edgepoint");
Vtar = cubesat.Vtar;
% Calculate the relative error
Vtar_diff = abs(Vtar(idx,:) - Vtar_numerical)./Vtar(idx,:);

%% Plotting
% Plot ground tracks in ECEF
figure(1)
geoplot(ll_sat(:,1),ll_sat(:,2))
hold on
geoplot(ll_tar(:,1),ll_tar(:,2))
legend("Satellite","LoS")
geobasemap("satellite")
title("ECEF Ground Tracks")

% Plot ground tracks in ECI
figure(2)
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

% Compare velocities
figure(3)
plot(ones(size(Vtar)).*cubesat.t,Vtar)
hold on
plot(ones(size(Vtar_numerical)).*t_der,Vtar_numerical,"x","LineWidth",1)
legend("u - analytic","v - analytic","w - analytic","u - numerical","v - numerical","w - numerical")
xlabel("Time [s]")
ylabel("Velocity [m/s]")
title("Velocity components vs Time")
grid on

% Velocity relative errors
figure(4)
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
sgtitle('Analytic vs Numerical Derivatives')

%% Play satellite scenario
% Clean coordinates from negative altitudes
lla_tar(:,3) = 0;
cubesat.play_scenario(lla_tar,sampleTime=1);