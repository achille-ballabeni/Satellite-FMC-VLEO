function SNR_FMC_geometry_analysis(optics,sensor,full_dataset)

arguments
    optics = "TriScape100"
    sensor = "CMV12000"
    full_dataset = false
end

%%%%%% LOAD RESULTS FROM LOOKUP TABLES %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
root_path = matlab.project.currentProject().RootFolder;
lookup_dir = fullfile(root_path, "src", "analysis", "radiative_transfer", "lookups");
results = load_mat_with_keywords(lookup_dir,optics,sensor).output;

%%%%%% SETUP ANALYSIS PARAMETERS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Select one beta angle
beta_idx = 3;

% Piezo travel for saturation
piezo_range = 50e-6/results.sensor.px;
% Using 2 step size because 8 latitudes are enough, the lookup table is
% with 15 values
lats = results.latitudes(1:2:end);
beta = results.beta;
Tblur = results.Tblur(beta_idx,1);
Tsat = results.Tsaturation(beta_idx,1:2:end);
electron_rate_ref = results.electron_rate(beta_idx,1:2:end);

% Find maximum saturation exposure time with FMC compensation
u = 1/Tblur;
fmc = piezo_compensation(u, piezo_range);

% Preallocate FMC exposure times
fmc_exposures = zeros(length(lats),1);

% Loop through latitudes to compute maximum compensation time with saturation
for k = 1:length(lats)
    fmc.compute_compensated_motion(Tsat(k));
    fmc_exposures(k) = fmc.Texp_r;
end

%%%%%% PERFORM SNR ANALYSIS FOR GEOMETRY %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Number of samples per latitude
n_samples = 8:15;

% Preallocate exposure and electron_rate vectors
exposures = zeros(sum(n_samples), 1);
electron_rate = zeros(sum(n_samples), 1);

% Create linspace vectors for each latitude
for k = 1:length(lats)
    n = n_samples(k);
    idx_start = sum(n_samples(1:k)) - sum(n_samples(k)) + 1;
    idx_end = sum(n_samples(1:k));
    exposures(idx_start:idx_end) = linspace(Tblur,fmc_exposures(k),n);
    
    % Repeat electron_rate for this latitude
    electron_rate(idx_start:idx_end) = electron_rate_ref(k);
end

% Run SNR analysis
if full_dataset
    im = image_processing("optics",results.optics.name,"sensor",results.sensor.name);
else
    path = fullfile(root_path,"src","media","single_image");
    im = image_processing("optics",results.optics.name,"sensor",results.sensor.name,"db_path",path);
end
im.load_images();
im.runSNR('exposures', exposures, 'noise', true, 'electron_rate', electron_rate);

% Load SNR results
data = im.SNRout.data;
snr = [data(:).mean_SNR];

%%%%%% RESULTS PLOTTING %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Plot SNR vs Exposure Time for all latitudes
n = length(lats);
colors = cmap();

figure('Name','SNR vs Exposure Time','Units','centimeters','Position',[0 0 18 12])
hold on
for k = 1:n
    idx_start = sum(n_samples(1:k)) - sum(n_samples(k)) + 1;
    idx_end = sum(n_samples(1:k));
    if abs(Tsat(k)-exposures(idx_end))>0.01*Tsat(k)
        x = [exposures(idx_start:idx_end); Tsat(k)]*1e3;
        y = [snr(idx_start:idx_end) snr(idx_end)];
    else
        x = exposures(idx_start:idx_end) * 1e3;
        y = snr(idx_start:idx_end);
    end
    plot(x, y, ...
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

%%%%%% EXPORT PLOT AS FIG %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
saveas(gcf, fullfile(root_path, "IM_results", 'SNR_vs_ExposureTime.fig'));

end