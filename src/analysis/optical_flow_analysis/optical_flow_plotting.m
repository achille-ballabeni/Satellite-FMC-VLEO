clc, clear
load optical_flow_results.mat

% Scatter
plot_scatter = false;

% Relative error settings
relative_error = false;
label = iif(relative_error,"Mean Relative Error [%]","Mean Absolute Error [px]");

% Define colors for different resolutions
colors = lines(length(imaging));

% Get unique combinations of blur and continuity
blur_vals = unique([imaging(1).data.blur]);
cont_vals = unique([imaging(1).data.continuity]);
exposure_vals = unique([imaging(1).data.exposure]);

%% Figure 1
% Create a figure for each combination
for e = exposure_vals
    for b = blur_vals
        for c = cont_vals
            % Convert to true/false labels
            blur_label = iif(b == 1, 'true', 'false');
            cont_label = iif(c == 1, 'true', 'false');

            % Create new figure
            figure("Name","b=" + blur_label + ", c=" + cont_label + ", e=1/" + string(1/e));

            % Subplot 1: U Error vs Time per Image with individual errors
            subplot(1, 2, 1);
            hold on;
            grid on;

            for i = 1:length(imaging)
                % Find indices matching this blur/continuity combination
                idx = ([imaging(i).data.blur] == b) & ([imaging(i).data.continuity] == c) & ([imaging(i).data.exposure] == e);

                if any(idx)
                    % Extract fps and calculate time per image
                    fps_vals = [imaging(i).data(idx).fps];
                    time_vals = 1 ./ fps_vals;
                    err_u_vals = iif(relative_error,[imaging(i).data(idx).mae_u]./abs(imaging(i).u_real)*100,[imaging(i).data(idx).mae_u]);

                    if plot_scatter
                        % Plot individual errors (lighter)
                        for j = find(idx)
                            errors_u = iif(relative_error,abs(imaging(i).u_real - imaging(i).data(j).u_est)./abs(imaging(i).u_real)*100,abs(imaging(i).u_real - imaging(i).data(j).u_est));
                            time_rep = repmat(1/imaging(i).data(j).fps, size(errors_u));
                            scatter(time_rep(:), errors_u(:), 20, colors(i,:), 'filled', ...
                                'MarkerFaceAlpha', 0.15, 'HandleVisibility', 'off');
                        end
                    end

                    % Create resolution label
                    res_label = sprintf('%dx%d', imaging(i).resolution(1), imaging(i).resolution(2));

                    % Plot errors with markers (darker, on top)
                    plot(time_vals, err_u_vals, '-o', 'LineWidth', 2.5, ...
                        'MarkerSize', 10, 'Color', colors(i,:), ...
                        'DisplayName', res_label, 'MarkerFaceColor', colors(i,:));
                end
            end

            xlabel('Time per Image [s]', 'FontSize', 12, 'FontWeight', 'bold');
            ylabel(label, 'FontSize', 12, 'FontWeight', 'bold');
            title('U Errors vs Time per Image', 'FontSize', 14, 'FontWeight', 'bold');
            legend('Location', 'best', 'FontSize', 10);
            hold off;

            % Subplot 2: V Error vs Time per Image with individual errors
            subplot(1, 2, 2);
            hold on;
            grid on;

            for i = 1:length(imaging)
                % Find indices matching this blur/continuity combination
                idx = ([imaging(i).data.blur] == b) & ([imaging(i).data.continuity] == c) & ([imaging(i).data.exposure] == e);

                if any(idx)
                    % Extract fps and calculate time per image
                    fps_vals = [imaging(i).data(idx).fps];
                    time_vals = 1 ./ fps_vals;
                    err_v_vals = iif(relative_error,[imaging(i).data(idx).mae_v]./abs(imaging(i).v_real)*100,[imaging(i).data(idx).mae_v]);

                    if plot_scatter
                        % Plot individual errors (lighter)
                        for j = find(idx)
                            errors_v = iif(relative_error,abs(imaging(i).v_real - imaging(i).data(j).v_est)./abs(imaging(i).v_real)*100,abs(imaging(i).v_real - imaging(i).data(j).v_est));
                            time_rep = repmat(1/imaging(i).data(j).fps, size(errors_v));
                            scatter(time_rep(:), errors_v(:), 20, colors(i,:), 'filled', ...
                                'MarkerFaceAlpha', 0.15, 'HandleVisibility', 'off');
                        end
                    end

                    % Create resolution label
                    res_label = sprintf('%dx%d', imaging(i).resolution(1), imaging(i).resolution(2));

                    % Plot errors with markers (darker, on top)
                    plot(time_vals, err_v_vals, '-o', 'LineWidth', 2.5, ...
                        'MarkerSize', 10, 'Color', colors(i,:), ...
                        'DisplayName', res_label, 'MarkerFaceColor', colors(i,:));
                end
            end

            xlabel('Time per Image [s]', 'FontSize', 12, 'FontWeight', 'bold');
            ylabel(label, 'FontSize', 12, 'FontWeight', 'bold');
            title('V Errors vs Time per Image', 'FontSize', 14, 'FontWeight', 'bold');
            legend('Location', 'best', 'FontSize', 10);
            hold off;

            % Add overall title with blur/continuity info
            sgtitle(sprintf('Errors vs Time per Image | Blur: %s, Continuity: %s, Exposure Time: 1/%d', blur_label, cont_label, 1/e), ...
                'FontSize', 16, 'FontWeight', 'bold');

            % Adjust layout
            set(gcf, 'Color', 'w');
        end
    end
end

%% Figure 2 - Exposure - Blur - Resolution Effect
% Create grouped bar data for blur/continuity combinations
blur_cont_combinations = {'B:F C:F', 'B:F C:T', 'B:T C:F', 'B:T C:T'};

for e = exposure_vals
    % Create figure showing effect of blur and continuity for each resolution
    figure("Name", "e=1/" + string(1/e));
    for i = 1:length(imaging)
        % Subplot for U errors
        subplot(length(imaging), 2, 2*i-1);
        hold on;
        grid on;
        err_u_means = zeros(1, 4);
        idx = 1;
        for b = [0, 1]
            for c = [0, 1]
                mask = ([imaging(i).data.blur] == b) & ([imaging(i).data.continuity] == c) & ([imaging(i).data.exposure] == e);
                if any(mask)
                    err_u_means(idx) = iif(relative_error,imaging(i).data(mask).mae_u/abs(imaging(i).u_real)*100,imaging(i).data(mask).mae_u);
                end
                idx = idx + 1;
            end
        end
        bar(1:4, err_u_means, 'FaceColor', colors(i,:));
        set(gca, 'XTick', 1:4);

        % Only show x-labels on bottom row
        if i == length(imaging)
            set(gca, 'XTickLabel', blur_cont_combinations, 'XTickLabelRotation', 45);
            set(gca, 'XTickLabelRotation', 45);
            ax = gca;
            ax.XAxis.FontSize = 12;
            ax.XAxis.FontWeight = 'bold';
        else
            set(gca, 'XTickLabel', []);
        end

        % Only show y-label on middle subplot of left column
        if i == ceil(length(imaging)/2)
            ylabel(label, 'FontSize', 12, 'FontWeight', 'bold');
        end

        title(sprintf('%dx%d', imaging(i).resolution(1), imaging(i).resolution(2)), ...
            'FontSize', 11, 'FontWeight', 'bold');
        hold off;

        % Subplot for V errors
        subplot(length(imaging), 2, 2*i);
        hold on;
        grid on;
        err_v_means = zeros(1, 4);
        idx = 1;
        for b = [0, 1]
            for c = [0, 1]
                mask = ([imaging(i).data.blur] == b) & ([imaging(i).data.continuity] == c) & ([imaging(i).data.exposure] == e);
                if any(mask)
                    err_v_means(idx) = iif(relative_error,imaging(i).data(mask).mae_v/abs(imaging(i).v_real)*100,imaging(i).data(mask).mae_v);
                end
                idx = idx + 1;
            end
        end
        bar(1:4, err_v_means, 'FaceColor', colors(i,:));
        set(gca, 'XTick', 1:4);

        % Only show x-labels on bottom row
        if i == length(imaging)
            set(gca, 'XTickLabel', blur_cont_combinations, 'XTickLabelRotation', 45);
            ax = gca;
            ax.XAxis.FontSize = 12;
            ax.XAxis.FontWeight = 'bold';
        else
            set(gca, 'XTickLabel', []);
        end

        title(sprintf('%dx%d', imaging(i).resolution(1), imaging(i).resolution(2)), ...
            'FontSize', 11, 'FontWeight', 'bold');
        hold off;
    end

    sgtitle('Effect of Blur and Continuity on ' + label, ...
        'FontSize', 16, 'FontWeight', 'bold');
    set(gcf, 'Color', 'w');
end
%% Figure 3 - Exposure Time Analysis
% We are only interested in these settings for this analysis.
b = 1; % blur = true
c = 0; % continuity = false
figure("Name","Exposure Time Analysis");
% Subplot 1: U Errors vs Exposure Time
subplot(1, 2, 1);
hold on;
grid on;
for i = 1:length(imaging)
    % Plot no-blur reference line for this resolution
    idx_noblur = ([imaging(i).data.blur] == 0) & ([imaging(i).data.continuity] == c);
    if any(idx_noblur)
        mean_u_noblur = iif(relative_error,imaging(i).data(find(idx_noblur, 1)).mae_u/abs(imaging(i).u_real)*100,imaging(i).data(find(idx_noblur, 1)).mae_u);
        yline(mean_u_noblur, '--', 'Color', colors(i,:), 'LineWidth', 1.5, ...
            'HandleVisibility', 'off');
    end
    % Plot blur data
    idx = ([imaging(i).data.blur] == b) & ([imaging(i).data.continuity] == c);
    if any(idx)
        exp_vals = [imaging(i).data(idx).exposure];
        err_u_vals = iif(relative_error,[imaging(i).data(idx).mae_u]./abs(imaging(i).u_real)*100,[imaging(i).data(idx).mae_u]);
        res_label = sprintf('%dx%d', imaging(i).resolution(1), imaging(i).resolution(2));
        plot(exp_vals, err_u_vals, '-o', 'LineWidth', 2.5, ...
            'MarkerSize', 10, 'Color', colors(i,:), ...
            'DisplayName', res_label, 'MarkerFaceColor', colors(i,:));
    end
end
xlabel('Exposure Time [s]', 'FontSize', 12, 'FontWeight', 'bold');
ylabel(label, 'FontSize', 12, 'FontWeight', 'bold');
title('U Errors vs Exposure Time', 'FontSize', 14, 'FontWeight', 'bold');
xscale log
% Get unique exposure values and format as fractions
all_exp = [];
for i = 1:length(imaging)
    idx = ([imaging(i).data.blur] == b) & ([imaging(i).data.continuity] == c);
    if any(idx)
        all_exp = [all_exp, imaging(i).data(idx).exposure];
    end
end
unique_exp = unique(all_exp);
xticks(unique_exp);
xticklabels(arrayfun(@(x) sprintf('1/%d', round(1/x)), unique_exp, 'UniformOutput', false));
legend('Location', 'best', 'FontSize', 10);
hold off;
% Subplot 2: V Errors vs Exposure Time
subplot(1, 2, 2);
hold on;
grid on;
for i = 1:length(imaging)
    % Plot no-blur reference line for this resolution
    idx_noblur = ([imaging(i).data.blur] == 0) & ([imaging(i).data.continuity] == c);
    if any(idx_noblur)
        mean_v_noblur = iif(relative_error,imaging(i).data(find(idx_noblur, 1)).mae_v/abs(imaging(i).v_real)*100,imaging(i).data(find(idx_noblur, 1)).mae_v);
        yline(mean_v_noblur, '--', 'Color', colors(i,:), 'LineWidth', 1.5, ...
            'HandleVisibility', 'off');
    end
    % Plot blur data
    idx = ([imaging(i).data.blur] == b) & ([imaging(i).data.continuity] == c);
    if any(idx)
        exp_vals = [imaging(i).data(idx).exposure];
        err_v_vals = iif(relative_error,[imaging(i).data(idx).mae_v]./abs(imaging(i).v_real)*100,[imaging(i).data(idx).mae_v]);
        res_label = sprintf('%dx%d', imaging(i).resolution(1), imaging(i).resolution(2));
        plot(exp_vals, err_v_vals, '-o', 'LineWidth', 2.5, ...
            'MarkerSize', 10, 'Color', colors(i,:), ...
            'DisplayName', res_label, 'MarkerFaceColor', colors(i,:));
    end
end
xlabel('Exposure Time [s]', 'FontSize', 12, 'FontWeight', 'bold');
ylabel(label, 'FontSize', 12, 'FontWeight', 'bold');
title('V Errors vs Exposure Time', 'FontSize', 14, 'FontWeight', 'bold');
xscale log
xticks(unique_exp);
xticklabels(arrayfun(@(x) sprintf('1/%d', round(1/x)), unique_exp, 'UniformOutput', false));
legend('Location', 'best', 'FontSize', 10);
hold off;
set(gcf, 'Color', 'w');
%%
% Helper function for inline if
function result = iif(condition, true_val, false_val)
    if condition
        result = true_val;
    else
        result = false_val;
    end
end