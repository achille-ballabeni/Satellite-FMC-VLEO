classdef image_plotting < handle

    properties
        resultsPath % Results filepath
        results % Results file
    end

    methods (Access = public)
        function obj = image_plotting(options)
            % IMAGE_PLOTTING Initializes image-plotting object and loads
            % result file.
            %
            % Input Arguments
            %   options.results_path - Path to the results file.
            %     string
            %
            % Output Arguments
            %   obj - Initialized image-plotting object with results path.
            %     object

            arguments
                options.path string = "";
            end

            if options.path == ""
                % No path specified, use interactive selection
                [file, location] = uigetfile;
                obj.resultsPath = fullfile(location,file);
            else
                obj.resultsPath = options.path;
            end

            % Validate path exists
            if ~isfile(obj.resultsPath)
                error("Path does not exist: %s", obj.resultsPath);
            end

            % Assign batch path
            fprintf('Results path set to: %s\n', obj.resultsPath);

            % Load data
            obj.results = load(obj.resultsPath).output;
            
            % Set plot font
            set(groot, 'defaultAxesFontName', 'CMU Serif');
            set(groot, 'defaultTextFontName', 'CMU Serif');
            set(groot, 'defaultLegendFontName', 'CMU Serif');
        end

        function plot_inference_time_analysis(obj,options)
            % PLOT_INFERENCE_TIME_ANALYSIS Plots error metrics versus
            % inference time for different resolutions and settings.
            %
            % Input Arguments
            %   obj - Object containing results and metadata.
            %     object
            %   options.relative_error - If true, errors are expressed as
            %       relative percentages rather than absolute pixel errors.
            %     logical scalar, default false
            %   options.scatter - If true, individual estimation samples
            %       are plotted as scatter points behind the main error
            %       curves.
            %     logical scalar, default false
            %
            % Output Arguments
            %   None - This function generates figures but does not return
            %       data.

            arguments (Input)
                obj
                options.relative_error (1,1) logical = false
                options.scatter (1,1) logical = false
            end

            % Define colors for different resolutions
            colors = lines(length(obj.results));
            
            % Y label
            ylabel_str = obj.iif(options.relative_error,"Mean Relative Error [%]","Mean Absolute Error [px]");

            % Loop through settings
            for k = 1:length(obj.results(1).data)
                % Extract and label settings
                d = obj.results(1).data(k);
                blur_label = obj.iif(d.blur == 1, 'true', 'false');
                cont_label = obj.iif(d.continuity == 1, 'true', 'false');
                noise_label = obj.iif(d.noise == 1, 'true', 'false');

                figure("Name","b=" + blur_label + ", c=" + cont_label + ", n=" + noise_label + ", e=" + string(d.exposure));

                for sp = 1:2  % Loop through U and V subplots
                    subplot(1, 2, sp);
                    hold on; grid on;
                    
                    % Loop through resolutions
                    for i = 1:length(obj.results)
                        % Extract data
                        fps_vals = obj.results(i).data(k).fps;
                        time_vals = 1 ./ fps_vals * 1000;

                        if sp == 1
                            err_vals = obj.iif(options.relative_error, [obj.results(i).data(k).mae_u]./abs(obj.results(i).u_real)*100, [obj.results(i).data(k).mae_u]);
                            title_str = 'U Errors vs Time per Image';
                            xlabel_str = 'Time per Image [ms]';
                        else
                            err_vals = obj.iif(options.relative_error, [obj.results(i).data(k).mae_v]./abs(obj.results(i).v_real)*100, [obj.results(i).data(k).mae_v]);
                            title_str = 'V Errors vs Time per Image';
                            xlabel_str = 'Time per Image [ms]';
                        end

                        % Plot scatter if enabled
                        if options.scatter
                            est_vals = obj.iif(sp==1, obj.results(i).data(k).u_est, obj.results(i).data(k).v_est);
                            real_val = obj.iif(sp==1, obj.results(i).u_real, obj.results(i).v_real);
                            for est = est_vals
                                errors = obj.iif(options.relative_error, abs(real_val - est)./abs(real_val)*100, abs(real_val - est));
                                time_rep = repmat(time_vals(1), size(errors));
                                scatter(time_rep(:), errors(:), 20, colors(i,:), 'filled', ...
                                    'MarkerFaceAlpha', 0.15, 'HandleVisibility', 'off');
                            end
                        end

                        % Plot main line
                        res_label = sprintf('%dx%d', obj.results(i).resolution(1), obj.results(i).resolution(2));
                        plot(time_vals, err_vals, '-o', 'LineWidth', 2.5, 'MarkerSize', 10, ...
                            'Color', colors(i,:), 'DisplayName', res_label, 'MarkerFaceColor', colors(i,:));
                    end

                    xlabel(xlabel_str, 'FontSize', 12, 'FontWeight', 'bold');
                    ylabel(ylabel_str, 'FontSize', 12, 'FontWeight', 'bold');
                    title(title_str, 'FontSize', 14, 'FontWeight', 'bold');
                    legend('Location', 'best', 'FontSize', 10);
                    hold off;
                end

                sgtitle(sprintf('Errors vs Time per Image | Blur: %s, Continuity: %s, Exposure Time: %s, Noise: %s', ...
                    blur_label, cont_label, string(d.exposure), string(noise_label)), 'FontSize', 16, 'FontWeight', 'bold');
                set(gcf, 'Color', 'w');
            end
        end

        function plot_OF_sensitivity_analysis(obj, options)
            % PLOT_OF_SENSITIVITY_ANALYSIS Plots error metrics for
            % different settings and compares them by resolution.
            %
            % Input Arguments
            %   obj - Object containing results and metadata.
            %   options.relative_error - If true, errors are expressed as
            %       relative percentages rather than absolute pixel errors.
            %     logical scalar, default false
            %
            % Output Arguments
            %   None - Generates figures but does not return data.

            arguments (Input)
                obj
                options.relative_error (1,1) logical = false
            end

            % Get unique exposure times
            exposures = unique([obj.results(1).data.exposure]);
            n_exposures = length(exposures);
            n_resolutions = length(obj.results);

            % Y label
            ylabel_str = obj.iif(options.relative_error, "Mean Relative Error [%]", "Mean Absolute Error [px]");

            % Colors for different resolutions
            colors = lines(n_resolutions);

            % Loop through exposure times
            for exp_idx = 1:n_exposures
                exp_val = exposures(exp_idx);

                % Count settings for this exposure
                data_idx_first = find([obj.results(1).data.exposure] == exp_val);
                n_settings = length(data_idx_first);

                figure('Name', sprintf('e=%s', string(exp_val)));

                % Loop through resolutions (rows of subplots)
                for res_idx = 1:n_resolutions
                    res_label = sprintf('%dx%d', obj.results(res_idx).resolution(1), obj.results(res_idx).resolution(2));

                    % Extract settings for this exposure
                    data_idx = find([obj.results(res_idx).data.exposure] == exp_val);

                    % Preallocate error matrices
                    err_u = zeros(1, n_settings);
                    err_v = zeros(1, n_settings);
                    setting_labels = cell(1, n_settings);

                    % Extract errors for all settings
                    for s = 1:n_settings
                        d = obj.results(res_idx).data(data_idx(s));

                        % Build setting label
                        setting_labels{s} = sprintf('B:%s C:%s N:%s', ...
                            obj.iif(d.blur == 1, 'T', 'F'), ...
                            obj.iif(d.continuity == 1, 'T', 'F'), ...
                            obj.iif(d.noise == 1, 'T', 'F'));

                        % Calculate errors
                        err_u(s) = obj.iif(options.relative_error, d.mae_u / abs(obj.results(res_idx).u_real) * 100, d.mae_u);
                        err_v(s) = obj.iif(options.relative_error, d.mae_v / abs(obj.results(res_idx).v_real) * 100, d.mae_v);
                    end

                    % U subplot (left column)
                    subplot(n_resolutions, 2, 2*res_idx - 1);
                    bar(1:n_settings, err_u, 'FaceColor', colors(res_idx, :));
                    if res_idx == n_resolutions
                        set(gca, 'XTick', 1:n_settings, 'XTickLabel', setting_labels, 'XTickLabelRotation', 45);
                        set(gca().XAxis, 'FontWeight', 'bold');
                        set(gca().XAxis, 'FontSize', 12);
                        set(gca().XAxis, 'TickLength', [0,0]);
                    else 
                        set(gca, 'XTickLabel', []);
                        set(gca().XAxis, 'TickLength', [0,0]);
                    end
                    title(sprintf('%s', res_label), 'FontSize', 12, 'FontWeight', 'bold');
                    grid on;

                    % Only show y-label on middle subplot of left column
                    if res_idx == ceil(n_resolutions/2)
                        ylabel(ylabel_str, 'FontSize', 12, 'FontWeight', 'bold');
                    end

                    % V subplot (right column)
                    subplot(n_resolutions, 2, 2*res_idx);
                    bar(1:n_settings, err_v, 'FaceColor', colors(res_idx, :));
                    if res_idx == n_resolutions
                        set(gca, 'XTick', 1:n_settings, 'XTickLabel', setting_labels, 'XTickLabelRotation', 45);
                        set(gca().XAxis, 'FontWeight', 'bold');
                        set(gca().XAxis, 'FontSize', 12);
                        set(gca().XAxis, 'TickLength', [0,0]);
                    else
                        set(gca, 'XTickLabel', []);
                        set(gca().XAxis, 'TickLength', [0,0]);
                    end
                    title(sprintf('%s', res_label), 'FontSize', 12, 'FontWeight', 'bold');
                    grid on;
                end

                sgtitle(sprintf('Errors vs Setting  | Exposure Time: %s', string(exp_val)), 'FontSize', 14, 'FontWeight', 'bold');
                set(gcf, 'Color', 'w');
            end
        end

        function plot_exposure_time_analysis(obj,options)
            % PLOT_EXPOSURE_TIME_ANALYSIS Plots U and V error metrics as a
            % function of exposure time for different resolutions and test
            % conditions.
            %
            % Input Arguments
            %   obj - Object containing results and metadata.
            %     object
            %   options.relative_error - If true, errors are expressed as
            %       relative percentages rather than absolute pixel errors.
            %     logical scalar, default false
            %
            % Output Arguments
            %   None - Generates figures but does not return data.

            arguments (Input)
                obj 
                options.relative_error (1,1) logical = false
            end
            % Define colors for different resolutions
            colors = lines(length(obj.results));
            
            % Y label
            ylabel_str = obj.iif(options.relative_error,"Mean Relative Error [%]","Mean Absolute Error [px]");

            % Settings of interest
            b = 1; c = 0; n = 1;

            figure("Name","Exposure Time Analysis");

            % Get unique exposure values once
            all_exp = [];
            for i = 1:length(obj.results)
                idx = ([obj.results(i).data.blur] == b) & ([obj.results(i).data.continuity] == c);
                if any(idx)
                    all_exp = [all_exp, obj.results(i).data(idx).exposure];
                end
            end

            % Loop through U and V subplots
            for sp = 1:2
                subplot(1, 2, sp);
                hold on; grid on;

                % Loop through resolutions
                for i = 1:length(obj.results)
                    % Plot no-blur no-noise reference line
                    idx_noblur = ([obj.results(i).data.blur] == 0) & ([obj.results(i).data.continuity] == c) & ...
                        ([obj.results(i).data.noise] == 0) & ([obj.results(i).data.exposure] == "any");
                    if any(idx_noblur)
                        real_val = obj.iif(sp==1, obj.results(i).u_real, obj.results(i).v_real);
                        mae_val = obj.iif(sp==1, obj.results(i).data(find(idx_noblur, 1)).mae_u, ...
                            obj.results(i).data(find(idx_noblur, 1)).mae_v);
                        mean_noblur = obj.iif(options.relative_error, mae_val/abs(real_val)*100, mae_val);
                        yline(mean_noblur, '--', 'Color', colors(i,:), 'LineWidth', 1.5, 'HandleVisibility', 'off');
                    end

                    % Plot main data
                    idx = ([obj.results(i).data.blur] == b) & ([obj.results(i).data.continuity] == c) & ([obj.results(i).data.noise] == n);
                    if any(idx)
                        exp_vals = [obj.results(i).data(idx).exposure];
                        real_val = obj.iif(sp==1, obj.results(i).u_real, obj.results(i).v_real);
                        mae_vals = obj.iif(sp==1, [obj.results(i).data(idx).mae_u], [obj.results(i).data(idx).mae_v]);
                        err_vals = obj.iif(options.relative_error, mae_vals./abs(real_val)*100, mae_vals);

                        res_label = sprintf('%dx%d', obj.results(i).resolution(1), obj.results(i).resolution(2));
                        plot(exp_vals*10^6, err_vals, '-o', 'LineWidth', 2.5, 'MarkerSize', 10, ...
                            'Color', colors(i,:), 'DisplayName', res_label, 'MarkerFaceColor', colors(i,:));
                    end
                end

                xlabel('Exposure Time [\mus]', 'FontSize', 12, 'FontWeight', 'bold');
                ylabel(ylabel_str, 'FontSize', 12, 'FontWeight', 'bold');
                title(obj.iif(sp==1, 'U Errors vs Exposure Time', 'V Errors vs Exposure Time'), ...
                    'FontSize', 14, 'FontWeight', 'bold');
                legend('Location', 'best', 'FontSize', 10);
                xticks(exp_vals*10^6)
                hold off;
            end
            set(gcf, 'Color', 'w');
        end

        function plot_saturation_time_geometry_analysis(obj)

            % Initialize variables
            n = length(obj.results.beta);
            colors = lines(n);
            
            % Plot mesh with saturation time
            figure('Name','Saturation Time Analysis','Units','centimeters','Position',[0 0 18 13])
            mesh(obj.results.latitudes,obj.results.beta,obj.results.Tsaturation*10^3)
            xlabel('Latitude [deg]', 'FontSize', 12, 'FontWeight', 'bold');
            ylabel('Beta Angle [deg]', 'FontSize', 12, 'FontWeight', 'bold');
            zlabel('Saturation time [ms]', 'FontSize', 12, 'FontWeight', 'bold');
            title('Saturation Time Analysis', 'FontSize', 14, 'FontWeight', 'bold')

            % Plot all beta angles in one figure
            figure('Name','All beta','Units','centimeters','Position',[0 0 18 13])
            hold on

            for i = 1:n
                semilogy(obj.results.latitudes, obj.results.Tsaturation(i,:)*1e3, ...
                    'LineWidth',1.5, ...
                    'Color',colors(i,:), ...
                    'DisplayName',sprintf('T_{sat} β=%.2f°',obj.results.beta(i)))
            end

            xlabel('Latitude [deg]','FontSize',13,'FontWeight','bold')
            title(obj.results.optics.name + " | Saturation Time vs Latitude", ...
                'FontSize',15,'FontWeight','bold')
            legend('Location','northwest','FontSize',12,'Orientation','horizontal','NumColumns',2)
            grid on

            % Left axis ticks (log decades with 1–9)
            Tsat_max = max(obj.results.Tsaturation,[],"all")*1e3;
            Tsat_min = min(obj.results.Tsaturation,[],"all")*1e3;
            dmax    = floor(log10(Tsat_max));

            ticks = [];
            for d = 0:dmax
                ticks = [ticks, (1:9)*10^d];
            end
            ticks = ticks(ticks <= ceil(Tsat_max/10)*10);
            ticks = [ticks,150];

            yyaxis left
            set(gca,'YScale','log','YMinorTick','off')
            ylabel('Time [ms]','FontSize',13,'FontWeight','bold')
            yticks(ticks)
            ylim([0.9*Tsat_min ticks(end)])

            % Right axis (normalized)
            max_sat_normalized = obj.results.Tsaturation(end,end)/obj.results.Tblur(1,1);
            factor = max_sat_normalized / Tsat_max;
            normalized_ticks = ticks * factor;

            yyaxis right
            set(gca,'YScale','log','YColor','k','YMinorTick','off')
            ylabel('T_{sat}/T_{blur}','FontSize',13,'FontWeight','bold')
            yticks(normalized_ticks)
            ylim([0.9*Tsat_min*factor normalized_ticks(end)])
            ytickformat('%.1f')

            % Plot saturation time vs blur for each latitude
            for i = 1:n
                % Extract data
                beta = obj.results.beta(i);
                latitudes = obj.results.latitudes;
                Tsaturation = obj.results.Tsaturation(i,:);
                Tblur = obj.results.Tblur(i,:);

                % Plot saturation and blur
                figure('Name',sprintf('Beta %.2f',beta),'Units','centimeters','Position',[0 0 18 13])
                plot(Tsaturation*10^3,latitudes,'LineWidth',1.5,'Color',colors(i,:))
                hold on
                plot(Tblur*10^3,latitudes,'LineWidth',1.5,'Color',colors(i,:),'LineStyle','--')

                xlabel('Time [ms]', 'FontSize', 12, 'FontWeight', 'bold');
                ylabel('Latitude [deg]', 'FontSize', 12, 'FontWeight', 'bold');
                title('Saturation Time vs Latitude', 'FontSize', 14, 'FontWeight', 'bold')
                legend('Saturation time','Blur time','Location', 'best', 'FontSize', 10);
                grid on

                % Plot range between blur and saturation
                figure('Name',sprintf('Beta %.2f - Range',beta),'Units','centimeters','Position',[0 0 18 13])
                for j = 1:length(latitudes)
                    plot([Tblur(j)*10^3, Tsaturation(j)*10^3], [latitudes(j), latitudes(j)], ...
                        'Color',colors(i,:), 'LineWidth', 1.5)
                    hold on
                    plot([Tblur(j)*10^3, Tblur(j)*10^3], latitudes(j) + [-1.5, 1.5], 'Color', colors(i,:), 'LineWidth', 1.5)
                    plot([Tsaturation(j)*10^3, Tsaturation(j)*10^3], latitudes(j) + [-1.5, 1.5], 'Color', colors(i,:), 'LineWidth', 1.5)
                end
                xlabel('Time [ms]', 'FontSize', 12, 'FontWeight', 'bold');
                ylabel('Latitude [deg]', 'FontSize', 12, 'FontWeight', 'bold');
                title('Exposure Time Range (Blur → Saturation)', 'FontSize', 14, 'FontWeight', 'bold')
                grid on
            end
        end
    end

    methods (Static, Access = private)
        function result = iif(condition, true_val, false_val)
            % IIF Inline if condition.
            %
            % Input Arguments
            %   condition - Logical expression to evaluate.
            %     logical scalar
            %   true_val - Value returned when condition is true.
            %     any
            %   false_val - Value returned when condition is false.
            %     any
            %
            % Output Arguments
            %   result - Selected output value based on the evaluated
            %       condition.
            %     any

            arguments (Input)
                condition (1,1) logical
                true_val
                false_val
            end

            arguments (Output)
                result
            end

            if condition
                result = true_val;
            else
                result = false_val;
            end
        end
    end
end