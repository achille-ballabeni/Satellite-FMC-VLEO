clc, clear
load optical_flow_results.mat

% Plot MAE_U and MAE_V vs FPS for each resolution
% Creates separate figures for each blur/continuity combination
% Assumes 'imaging' struct array is already loaded in workspace

% Define colors for different resolutions
colors = lines(length(imaging));

% Get unique combinations of blur and continuity
blur_vals = unique([imaging(1).data.blur]);
cont_vals = unique([imaging(1).data.continuity]);

%% Figure 1
% Create a figure for each combination
for b = blur_vals
    for c = cont_vals
        % Convert to true/false labels
        blur_label = iif(b == 1, 'true', 'false');
        cont_label = iif(c == 1, 'true', 'false');
        
        % Create new figure
        figure(1);
        
        % Subplot 1: MAE_U vs FPS with individual errors
        subplot(1, 2, 1);
        hold on;
        grid on;
        
        for i = 1:length(imaging)
            % Find indices matching this blur/continuity combination
            idx = ([imaging(i).data.blur] == b) & ([imaging(i).data.continuity] == c);
            
            if any(idx)
                % Extract fps and calculate time per image
                fps_vals = [imaging(i).data(idx).fps];
                time_vals = 1 ./ fps_vals;
                mae_u_vals = [imaging(i).data(idx).mae_u];
                
                % Plot individual errors (lighter)
                for j = find(idx)
                    errors_u = abs(imaging(i).u_real - imaging(i).data(j).u_est)./abs(imaging(i).u_real)*100;
                    time_rep = repmat(1/imaging(i).data(j).fps, size(errors_u));
                    scatter(time_rep(:), errors_u(:), 20, colors(i,:), 'filled', ...
                           'MarkerFaceAlpha', 0.15, 'HandleVisibility', 'off');
                end
                
                % Create resolution label
                res_label = sprintf('%dx%d', imaging(i).resolution(1), imaging(i).resolution(2));
                
                % Plot MAE with markers (darker, on top)
                plot(time_vals, mae_u_vals, '-o', 'LineWidth', 2.5, ...
                     'MarkerSize', 10, 'Color', colors(i,:), ...
                     'DisplayName', res_label, 'MarkerFaceColor', colors(i,:));
            end
        end
        
        xlabel('Time per Image [s]', 'FontSize', 12, 'FontWeight', 'bold');
        ylabel('Mean Relative Error [%]', 'FontSize', 12, 'FontWeight', 'bold');
        title('U Errors vs Time per Image', 'FontSize', 14, 'FontWeight', 'bold');
        legend('Location', 'best', 'FontSize', 10);
        hold off;
        
        % Subplot 2: MAE_V vs FPS with individual errors
        subplot(1, 2, 2);
        hold on;
        grid on;
        
        for i = 1:length(imaging)
            % Find indices matching this blur/continuity combination
            idx = ([imaging(i).data.blur] == b) & ([imaging(i).data.continuity] == c);
            
            if any(idx)
                % Extract fps and calculate time per image
                fps_vals = [imaging(i).data(idx).fps];
                time_vals = 1 ./ fps_vals;
                mae_v_vals = [imaging(i).data(idx).mae_v];
                
                % Plot individual errors (lighter)
                for j = find(idx)
                    errors_v = abs(imaging(i).v_real - imaging(i).data(j).v_est)/abs(imaging(i).v_real)*100;
                    time_rep = repmat(1/imaging(i).data(j).fps, size(errors_v));
                    scatter(time_rep(:), errors_v(:), 20, colors(i,:), 'filled', ...
                           'MarkerFaceAlpha', 0.15, 'HandleVisibility', 'off');
                end
                
                % Create resolution label
                res_label = sprintf('%dx%d', imaging(i).resolution(1), imaging(i).resolution(2));
                
                % Plot MAE with markers (darker, on top)
                plot(time_vals, mae_v_vals, '-o', 'LineWidth', 2.5, ...
                     'MarkerSize', 10, 'Color', colors(i,:), ...
                     'DisplayName', res_label, 'MarkerFaceColor', colors(i,:));
            end
        end
        
        xlabel('Time per Image [s]', 'FontSize', 12, 'FontWeight', 'bold');
        ylabel('Mean Relative Error [%]', 'FontSize', 12, 'FontWeight', 'bold');
        title('V Errors vs Time per Image', 'FontSize', 14, 'FontWeight', 'bold');
        legend('Location', 'best', 'FontSize', 10);
        hold off;
        
        % Add overall title with blur/continuity info
        % sgtitle(sprintf('Errors vs Time per Image'), ...
        %         'FontSize', 16, 'FontWeight', 'bold');
        
        % Adjust layout
        set(gcf, 'Color', 'w');
    end
end

%% Figure 2
% Create figure showing effect of blur and continuity for each resolution
figure(2);

% Create grouped bar data for blur/continuity combinations
blur_cont_combinations = {'B:F C:F', 'B:F C:T', 'B:T C:F', 'B:T C:T'};

for i = 1:length(imaging)
    % Subplot for MAE_U
    subplot(length(imaging), 2, 2*i-1);
    hold on;
    grid on;
    mae_u_means = zeros(1, 4);
    idx = 1;
    for b = [0, 1]
        for c = [0, 1]
            mask = ([imaging(i).data.blur] == b) & ([imaging(i).data.continuity] == c);
            if any(mask)
                mae_u_means(idx) = mean([imaging(i).data(mask).mae_u]);
            end
            idx = idx + 1;
        end
    end
    bar(1:4, mae_u_means, 'FaceColor', colors(i,:));
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
        ylabel('Mean Relative Error [%]', 'FontSize', 12, 'FontWeight', 'bold');
    end
    
    title(sprintf('%dx%d', imaging(i).resolution(1), imaging(i).resolution(2)), ...
        'FontSize', 11, 'FontWeight', 'bold');
    hold off;
    
    % Subplot for MAE_V
    subplot(length(imaging), 2, 2*i);
    hold on;
    grid on;
    mae_v_means = zeros(1, 4);
    idx = 1;
    for b = [0, 1]
        for c = [0, 1]
            mask = ([imaging(i).data.blur] == b) & ([imaging(i).data.continuity] == c);
            if any(mask)
                mae_v_means(idx) = mean([imaging(i).data(mask).mae_v]);
            end
            idx = idx + 1;
        end
    end
    bar(1:4, mae_v_means, 'FaceColor', colors(i,:));
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

sgtitle('Effect of Blur and Continuity on Mean Relative Error', ...
    'FontSize', 16, 'FontWeight', 'bold');
set(gcf, 'Color', 'w');
%% Figure 3 - Exposure Time Analysis
b = 1;  % blur = true
c = 0;  % continuity = false

figure(3);

% Subplot 1: U Errors vs Exposure Time
subplot(1, 2, 1);
hold on;
grid on;

for i = 1:length(imaging)
    % Plot no-blur reference line for this resolution
    idx_noblur = ([imaging(i).data.blur] == 0) & ([imaging(i).data.continuity] == c);
    if any(idx_noblur)
        mean_u_noblur = imaging(i).data(find(idx_noblur, 1)).mae_u;
        yline(mean_u_noblur, '--', 'Color', colors(i,:), 'LineWidth', 1.5, ...
              'HandleVisibility', 'off');
    end
    
    % Plot blur data
    idx = ([imaging(i).data.blur] == b) & ([imaging(i).data.continuity] == c);
    
    if any(idx)
        exp_vals = [imaging(i).data(idx).exposure];
        mae_u_vals = [imaging(i).data(idx).mae_u];
        
        % Plot individual errors (lighter)
        for j = find(idx)
            errors_u = abs(imaging(i).u_real - imaging(i).data(j).u_est)./abs(imaging(i).u_real)*100;
            exp_rep = repmat(imaging(i).data(j).exposure, size(errors_u));
            scatter(exp_rep(:), errors_u(:), 20, colors(i,:), 'filled', ...
                   'MarkerFaceAlpha', 0.15, 'HandleVisibility', 'off');
        end
        
        res_label = sprintf('%dx%d', imaging(i).resolution(1), imaging(i).resolution(2));
        plot(exp_vals, mae_u_vals, '-o', 'LineWidth', 2.5, ...
             'MarkerSize', 10, 'Color', colors(i,:), ...
             'DisplayName', res_label, 'MarkerFaceColor', colors(i,:));
    end
end

xlabel('Exposure Time [s]', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Mean Relative Error [%]', 'FontSize', 12, 'FontWeight', 'bold');
title('U Errors vs Exposure Time', 'FontSize', 14, 'FontWeight', 'bold');
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
        mean_v_noblur = imaging(i).data(find(idx_noblur, 1)).mae_v;
        yline(mean_v_noblur, '--', 'Color', colors(i,:), 'LineWidth', 1.5, ...
              'HandleVisibility', 'off');
    end
    
    % Plot blur data
    idx = ([imaging(i).data.blur] == b) & ([imaging(i).data.continuity] == c);
    
    if any(idx)
        exp_vals = [imaging(i).data(idx).exposure];
        mae_v_vals = [imaging(i).data(idx).mae_v];
        
        % Plot individual errors (lighter)
        for j = find(idx)
            errors_v = abs(imaging(i).v_real - imaging(i).data(j).v_est)/abs(imaging(i).v_real)*100;
            exp_rep = repmat(imaging(i).data(j).exposure, size(errors_v));
            scatter(exp_rep(:), errors_v(:), 20, colors(i,:), 'filled', ...
                   'MarkerFaceAlpha', 0.15, 'HandleVisibility', 'off');
        end
        
        res_label = sprintf('%dx%d', imaging(i).resolution(1), imaging(i).resolution(2));
        plot(exp_vals, mae_v_vals, '-o', 'LineWidth', 2.5, ...
             'MarkerSize', 10, 'Color', colors(i,:), ...
             'DisplayName', res_label, 'MarkerFaceColor', colors(i,:));
    end
end

xlabel('Exposure Time [s]', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Mean Relative Error [%]', 'FontSize', 12, 'FontWeight', 'bold');
title('V Errors vs Exposure Time', 'FontSize', 14, 'FontWeight', 'bold');
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