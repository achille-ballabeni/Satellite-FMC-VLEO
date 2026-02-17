clc, clear;
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
% Select one beta angle
beta_idx = 3;
% Piezo travel for saturation
piezo_range = 50e-6;
lats = results.latitudes;
beta = results.beta;

% Preallocate
fmc_exposures = zeros(length(lats));

% Loop through latitudes to get the max compensation time from fmc with
% saturation
for k = 1:length(lats)
    u = 1/results.Tblur(beta_idx,k);
    fmc = piezo_compensation(u, piezo_range/results.sensor.px);
    fmc.compute_compensated_motion(results.Tsaturation(beta_idx,k));
    fmc_exposures(k) = fmc.Texp_r;
end

%% Perform SNR analysis for the given beta angle, using the FMC exposure values
% Number of samples per latitude
n_samples = 8:15;
% Preallocate exposure and electron_rate vectors
exposures = zeros(sum(n_samples), 1);
exposures_nominal = zeros(sum(n_samples), 1);
electron_rate = zeros(sum(n_samples), 1);

% Create linspace vectors for each latitude
for k = 1:length(lats)
    idx_start = sum(n_samples(1:k)) - sum(n_samples(k)) + 1;
    idx_end = sum(n_samples(1:k));
    
    % Linspace from Tblur to Tsaturation
    exposures_nominal(idx_start:idx_end) = linspace(results.Tblur(beta_idx,k), ...
                                                    results.Tsaturation(beta_idx,k), ...
                                                    n_samples(k))';
    
    % Actual exposure: min(nominal, fmc_compensated)
    exposures(idx_start:idx_end) = min(exposures_nominal(idx_start:idx_end), ...
                                       fmc_exposures(k));
    
    % Repeat electron_rate for this latitude
    electron_rate(idx_start:idx_end) = results.electron_rate(beta_idx,k);
end

% Finally, run SNR analysis
path = fullfile(matlab.project.currentProject().RootFolder,"src","media","single_image");
im = image_processing("optics",results.optics.name,"sensor",results.sensor.name,"db_path",path);
im.load_images();
im.runSNR('exposures', exposures, 'noise', true, 'electron_rate', electron_rate);

%% Use results to plot SNR trend
data = im.SNRout.data;
snr = [data(:).mean_SNR];

% Plot SNR vs Exposure Time for all latitudes
n = length(lats);
colors = lines(n);

figure('Name','SNR vs Exposure Time','Units','centimeters','Position',[0 0 18 12])
hold on
for k = 1:n
    idx_start = sum(n_samples(1:k)) - sum(n_samples(k)) + 1;
    idx_end = sum(n_samples(1:k));
    plot(exposures_nominal(idx_start:idx_end)*1e3, snr(idx_start:idx_end), ...
        'LineWidth', 2, ...
        'Color', colors(k,:), ...
        'DisplayName', sprintf('λ = %.2f°', lats(k)))
end
xlabel('Target Exposure Time [ms]', 'FontSize', 13, 'FontWeight', 'bold')
ylabel('SNR', 'FontSize', 13, 'FontWeight', 'bold')
title(sprintf('%s | SNR | β = %.2f°', results.optics.name, beta(beta_idx)), ...
    'FontSize', 15, 'FontWeight', 'bold')
legend('Location', 'southeast', 'FontSize', 12, 'Orientation', 'horizontal', 'NumColumns', 3)
grid on