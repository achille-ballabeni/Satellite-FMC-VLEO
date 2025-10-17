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
cubesat.set_model_parameters(duration=duration,timestep=timestep);
cubesat.simulate();
batch_path = cubesat.export_results("destination","..\results");

%% Perform Analysis
analysis = analysis_tool("batchPath",batch_path);
analysis.runAllAnalyses()