clc, clear
%% Run analysis for to find exposure and blur time for each beta
%  Skip to the next section if there is already a result file

% Simulation settings
betas = linspace(0,78.75,8);
latitudes = linspace(0,78.75,15);
sensor = "cmv12000";
optics = "triscape100";

% Run simulation using the image_processing class
im = image_processing("sensor",sensor,"optics",optics);
im.runGEOMETRY("beta",betas,"latitudes",latitudes)

%% Load results of previous simulation
[file, location] = uigetfile;
results = load(fullfile(location,file)).output;

%% Perform amplitude analysis
piezo_range = 50e-6;
betas = results.beta;
latitudes = results.latitudes;
% Preallocate
A = zeros(length(betas), length(latitudes));

% Loop through beta and latitudes
for i = 1:length(betas)
    for k = 1:length(latitudes)
        u = 1/results.Tblur(i,k);
        fmc = piezo_compensation(u, piezo_range/results.sensor.px);
        fmc.compute_compensated_motion(results.Tsaturation(i,k));
        A(i,k) = fmc.A_r*results.sensor.px*10^6;
    end
end

%% Plot results
n = length(betas);
colors = lines(n);

figure('Name','All beta','Units','centimeters','Position',[0 0 18 12])
hold on
for i = 1:2:n
    plot(latitudes, A(i,:), ...
        'LineWidth', 2, ...
        'Color', colors(i,:), ...
        'DisplayName', sprintf('β=%.2f°', betas(i)))
    
end
xlabel('Latitude [deg]', 'FontSize', 13, 'FontWeight', 'bold')
ylabel('Amplitude [\mum]', 'FontSize', 13, 'FontWeight', 'bold')
title(results.optics.name + " | Amplitude vs Latitude", 'FontSize', 15, 'FontWeight', 'bold')
legend('Location', 'northwest', 'FontSize', 12, 'Orientation', 'horizontal', 'NumColumns', 2)
set(gca, 'YScale', 'log')
yticklabels(["1","10","100","1000"])
grid on