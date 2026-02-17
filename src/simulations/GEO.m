clc, clear;
%% Run analysis for to find exposure and blur time for each beta

% Simulation settings
betas = linspace(0,78.75,15);
latitudes = linspace(0,78.75,15);
sensor = "cmv12000";
optics = "triscape100";

% Run simulation using the image_processing class
im = image_processing("sensor",sensor,"optics",optics);
im.runGEOMETRY("beta",betas,"latitudes",latitudes)
export_path = im.export_path;

%% Plot analysis results
ip = image_plotting("path",export_path);
ip.plot_saturation_time_geometry_analysis();