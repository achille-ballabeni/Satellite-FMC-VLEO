function SNR_FMC_max_value_analysis(optics,sensor,full_dataset)

arguments
    optics = "TriScape100"
    sensor = "CMV12000"
    full_dataset = false
end

%%%%%% LOAD RESULTS FROM LOOKUP TABLES %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
root_path = matlab.project.currentProject().RootFolder;
lookup_dir = fullfile(root_path, "src", "analysis", "radiative_transfer", "lookups");
results = load_mat_with_keywords(lookup_dir,optics,sensor).output;

%%%%%% PROCESS EXPOSURE TIMES WITH PIEZO SATURATION %%%%%%%%%%%%%%%%%%%%%%%
lats = results.latitudes;
beta = results.beta;
electron_rate = results.electron_rate;
Tsat = results.Tsaturation;

% Find maximum exposure time
u = 1/results.Tblur(1,1);
range = 50e-6/results.sensor.px;
fmc = piezo_compensation(u, range);
fmc.compute_compensated_motion(0.1);
Texp_max = fmc.Texp_r;

% Preallocate plot data structure
plot_data = repmat(struct( ...
    'exposures', [], ...
    'new_erate', [], ...
    'lats', [] ...
    ), 1, 8);

% Loop through beta and lats to get exposure times
for i = 1:length(beta)
    F_lat = griddedInterpolant(Tsat(i,:),lats,"spline");

    % No piezo saturation
    if all(Tsat(i,:) < Texp_max)
        plot_data(i).lats = [lats(1) lats(end)];
        plot_data(i).exposures = [Tsat(i,1) Tsat(i,end)];
        plot_data(i).new_erate = [electron_rate(i,1) electron_rate(i,end)];
    % Always piezo saturation
    elseif all(Tsat(i,:) > Texp_max)
        plot_data(i).lats = lats;
        plot_data(i).exposures = Texp_max*ones(1,length(lats));
        plot_data(i).new_erate = [electron_rate(i,:)];
    % Sometimes piezo saturation
    else
        lat_Texp_max = F_lat(Texp_max);
        saturation_idx = lats > lat_Texp_max;
        % No piezo saturation values until lat_Texp_max, hence SNR will be
        % constant. Any point between lat(1) and this lat can be used.
        plot_data(i).lats = [lats(1), lat_Texp_max];
        plot_data(i).exposures = [Tsat(i,1), Tsat(i,1)];
        plot_data(i).new_erate = [electron_rate(i,1), electron_rate(i,1)];
        % Saturated values
        saturated_lats = lats(saturation_idx);
        n_saturated = length(saturated_lats);
        plot_data(i).lats = [plot_data(i).lats saturated_lats];
        plot_data(i).exposures = [plot_data(i).exposures ones(1,n_saturated)*Texp_max];
        plot_data(i).new_erate = [plot_data(i).new_erate electron_rate(i,saturation_idx)];
    end
end

%%%%%%% PERFORM SNR ANALYSIS FOR BETA AND LATITUDES %%%%%%%%%%%%%%%%%%%%%%%
% Create column vector for SNR processing
all_exposures = [plot_data.exposures];
all_rates = [plot_data.new_erate];

% Run SNR analysis
if full_dataset
    im = image_processing("optics",results.optics.name,"sensor",results.sensor.name);
else
    path = fullfile(root_path,"src","media","single_image");
    im = image_processing("optics",results.optics.name,"sensor",results.sensor.name,"db_path",path);
end
im.load_images();
im.runSNR('exposures', all_exposures, 'noise', true, 'electron_rate', all_rates);

% Load SNR results
data = im.SNRout.data;
snr = [data(:).mean_SNR];

%%%%%% RESULTS PLOTTING %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Plot SNR vs Latitude for all beta
n = length(beta);
colors = cmap();
figure('Name','SNR vs Latitude','Units','centimeters','Position',[0 0 18 12])
hold on
j = 1;
for i = 1:n
    lats = plot_data(i).lats;
    m = length(lats);
    plot(lats, snr(j:j+m-1), ...
        'LineWidth', 2, ...
        'Color', colors(i,:), ...
        'DisplayName', sprintf('β=%.2f°', beta(i)))
    j = j + m;
end
xlabel('Latitude [deg]', 'FontSize', 13, 'FontWeight', 'bold')
ylabel('SNR', 'FontSize', 13, 'FontWeight', 'bold')
title(results.optics.name + " | SNR vs Latitude", ...
    'FontSize', 15, 'FontWeight', 'bold')
legend('Location', 'southwest', 'FontSize', 12, 'Orientation', 'horizontal', 'NumColumns', 2)
grid on

%%%%%% EXPORT PLOT AS FIG %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
saveas(gcf, fullfile(root_path, "IM_results", 'SNR_vs_Latitude.fig'));

end