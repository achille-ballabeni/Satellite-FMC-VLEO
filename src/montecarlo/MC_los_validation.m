clear, clc

%% Number of simulations
N = 50;
seed = 1088; % Same seed for repeatability

%% Orbital parameters and inital conditions
h = 250e3 + (500e3 - 250e3) * rand([1,N]);                  % [m]
a = 6378e3 + h;                                             % [m]
e = 0;
i = 180 * rand([1,N]);                                      % [deg]
raan = 360 * rand([1,N]);                                    % [deg]
aop = 0;                                                    % [deg]
ta = 360 * rand([1,N]);                                     % [deg]
initial_angular_velocity = deg2rad(-2 + 4 * rand([3,N]));   % [rad/s]
startTime = datetime(2025,1,1,12,0,0);

%% Run simulation
timestep = 0.2;
duration = 5;
cubesat = satellite_simulation();
for k = 1:N
    op = [a(k);e;i(k);raan(k);aop;ta(k)];
    w0 = initial_angular_velocity(:,k);

    % Initial nadir-poining attitude: x-axis opposet to velocity and z-axis
    % nadir
    % R3(raan)->R1(i)->R3(aop+ta)
    eci2orb = angle2quat(deg2rad(op(4)),deg2rad(op(3)),deg2rad(op(6)+op(5)),"ZXZ");
    % R3(270)->R2(0)->R1(90): Yaw->Pitch->Roll
    orb2body = angle2quat(deg2rad(270),0,deg2rad(90),"ZYX");                        
    initial_attitude = quatmultiply(eci2orb,orb2body);

    cubesat.set_model_parameters(op,false,initial_attitude,w0,startTime,duration=duration,timestep=timestep,estimation_filter="off");
    cubesat.simulate("iteration",k);
end

%% Export results
batch_path = cubesat.export_results();

%% Perform Analysis
analysis = analysis_tool("batchPath",batch_path);
analysis.runSingleAnalysis("01")