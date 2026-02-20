function FMC_amplitude_analysis(optics,sensor)

arguments
    optics = "TriScape100"
    sensor = "CMV12000"
end

%%%%%% LOAD RESULTS FROM LOOKUP TABLES %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
root_path = matlab.project.currentProject().RootFolder;
lookup_dir = fullfile(root_path, "src", "analysis", "radiative_transfer", "lookups");
results = load_mat_with_keywords(lookup_dir,optics,sensor).output;

%%%%%% PERFORM AMPLITUDE ANALYSIS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
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

%%%%%% PLOT RESULTS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
n = length(betas);
colors = cmap();

figure('Name','All beta','Units','centimeters','Position',[0 0 18 12])
hold on
for i = 1:n
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
grid on
end