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
lat = results.latitudes;
beta = results.beta;
electron_rate = results.electron_rate';
electron_rate = [electron_rate(:)];

% Preallocate
exposures_matrix = zeros(length(beta), length(lat));

% Loop through beta and lat to get exposure times
for i = 1:length(beta)
    for k = 1:length(lat)
        u = 1/results.Tblur(i,k);
        range = 50e-6/results.sensor.px;
        fmc = piezo_compensation(u, range);
        fmc.compute_compensated_motion(results.Tsaturation(i,k));
        exposures_matrix(i,k) = fmc.Texp_r;
    end
end

%% Perform the SNR analysis for all beta angles and latitudes

% Create column vector from exposure matrix:
% beta1 (lat1->latn) -> beta2 (lat1->latn) -> ... -> betam (lat1->latn)
exposures = exposures_matrix';
exposures = exposures(:);

% Run SNR analysis
path = fullfile(matlab.project.currentProject().RootFolder,"src","media","single_image");
im = image_processing("optics",results.optics.name,"sensor",results.sensor.name,"db_path",path);
im.load_images();
im.runSNR('exposures', exposures, 'noise', true, 'electron_rate', electron_rate);

% Load SNR results
data = im.SNRout.data;
snr = [data(:).mean_SNR];

% Reshape SNR to match beta x lat dimensions
SNR = reshape(snr, length(lat), length(beta))';

%% Plot results
% Plot SNR vs Latitude for all beta
n = length(beta);
colors = lines(n);
figure('Name','SNR vs Latitude','Units','centimeters','Position',[0 0 18 12])
hold on
for i = 1:n
    plot(lat, SNR(i,:), ...
        'LineWidth', 2, ...
        'Color', colors(i,:), ...
        'DisplayName', sprintf('β=%.2f°', beta(i)))
end
xlabel('Latitude [deg]', 'FontSize', 13, 'FontWeight', 'bold')
ylabel('SNR', 'FontSize', 13, 'FontWeight', 'bold')
title(results.optics.name + " | SNR vs Latitude", ...
    'FontSize', 15, 'FontWeight', 'bold')
legend('Location', 'southwest', 'FontSize', 12, 'Orientation', 'horizontal', 'NumColumns', 2)
grid on