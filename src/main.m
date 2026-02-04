clear, clc

%% Orbital parameters and inital conditions
a = 6378e3 + 250e3; % [m]
e = 0;
i = 0;                      % [deg]
raan = 237.3113;            % [deg]
aop = 0;                    % [deg]
ta = 0;                     % [deg]
op = [a;e;i;raan;aop;ta];   % orbital parameters
w0 = [0;0;0];               % initial angular velocity
startTime = datetime(2025,1,1,12,0,0);

% Initial nadir-poining attitude: x-axis opposet to velocity and z-axis
% nadir
% R3(raan)->R1(i)->R3(aop+ta)
eci2orb = angle2quat(deg2rad(op(4)),deg2rad(op(3)),deg2rad(op(6)+op(5)),"ZXZ");
% R3(270)->R2(0)->R1(90): Yaw->Pitch->Roll
orb2body = angle2quat(deg2rad(270),0,deg2rad(90),"ZYX");
initial_attitude = quatmultiply(eci2orb,orb2body);

%% Run simulation
timestep = 0.1;
duration = 10;
cubesat = satellite_simulation();
cubesat.set_model_parameters(op, ...
    true, ...
    initial_attitude, ...
    w0, ...
    startTime, ...
    duration=duration, ...
    timestep=timestep, ...
    estimation_filter="off");
cubesat.simulate();
batch_path = cubesat.export_results();

%% Perform Analysis
analysis = analysis_tool("batchPath",batch_path);
analysis.runAllAnalyses()