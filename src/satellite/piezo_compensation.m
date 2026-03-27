classdef piezo_compensation < handle

    properties
        
        range   % Maximum travel in one direction in pixels

        % Real data (ideal world)
        dudt_r                  % The real image velocity in px/s
        A_r                     % Amplitude
        f_r                     % Frequency
        T_r                     % Period
        t_r                     % Compensated motion
        pixel_shift_r           % Pixel shift
        piezo_motion_r          % Piezo motion
        compensated_motion_r    % Compensated motion
        zeroed_motion_r         % Zeroed motion
        Texp_r                  % Real exposure time with saturation
        
        % Sensor data
        dudt_s                  % The measured image velocity in px/s
        A_s                     % Amplitude
        f_s                     % Frequency
        T_s                     % Period
        t_s                     % Compensated motion
        pixel_shift_s           % Pixel shift
        piezo_motion_s          % Piezo motion
        compensated_motion_s    % Compensated motion
        zeroed_motion_s         % Zeroed motion
        Texp_s                  % Real exposure time with saturation

        % Optical Flow data
        dudt_of                  % The measured image velocity in px/s
        A_of                     % Amplitude
        f_of                     % Frequency
        T_of                     % Period
        t_of                     % Compensated motion
        pixel_shift_of           % Pixel shift
        piezo_motion_of          % Piezo motion
        compensated_motion_of    % Compensated motion
        zeroed_motion_of         % Zeroed motion
        Texp_of                  % Real exposure time with saturation
    end

    methods
        function obj = piezo_compensation(Vim_real,range,options)
            arguments
                Vim_real (1,1) double
                range (1,1) double
                options.Vim_sensors (1,1) double = NaN
                options.Vim_of (1,1) double = NaN
            end
            obj.dudt_r = Vim_real;
            obj.range = range;
            obj.dudt_s = options.Vim_sensors;
            obj.dudt_of = options.Vim_of;
        end

        function [T, f, A] = optimal_amplitude_frequency(~,m,Texp)
            % Intersection of compensated motion with 0.5 pixel value
            g = @(x) 0.5*m*(x+Texp) + m*x/2/pi*sin(pi/x*(x+Texp)) - m*x/2 - 0.5;
            % Oscillation period: the guess just needs to be positive.
            % Since the results are symmetric both are acceptable provided
            % that the absolute value is considered.
            T = abs(fzero(g,Texp));
            % Frequency
            f = 1/T;
            % Amplitude
            A = m*T/2/pi;
        end

        function [T, f, A] = maximum_travel(obj,m)
            % Amplitude
            A = obj.range;
            % Period
            T = 2*pi*A/m;
            % Frequency
            f = 1/T;
        end

        function [T, f, A] = solve_motion_law(obj,dudt,Texp,method)
            if method == "optimal_amplitude"
                [T, f, A] = obj.optimal_amplitude_frequency(dudt, Texp);
            elseif method == "maximum_travel"
                [T, f, A] = obj.maximum_travel(dudt);
            else
                error("Not a valid method, chose between [optimal_amplitude, maximum_travel]");
            end
        end

        function [t, pixel_shift, piezo_motion, compensated_motion, zeroed_motion, T_exp] = motion_summation(obj,T,f,A,dudt_r)
            t = linspace(0, T, 10000);
            pixel_shift = dudt_r*(t);
            piezo_motion = A*sin(2*pi*f*t);
            piezo_motion = clip(piezo_motion,-obj.range,obj.range);
            compensated_motion = pixel_shift + piezo_motion;
            zeroed_motion = compensated_motion - dudt_r*T/2;
            t = t - T/2;
            T_exp = interp1(zeroed_motion,t,0.5)*2;
        end

        function compute_compensated_motion(obj,Texp,method)
            arguments
                obj
                Texp
                method = "optimal_amplitude"
            end

            % Real data
            [obj.T_r, obj.f_r, obj.A_r] = obj.solve_motion_law(obj.dudt_r,Texp,method);
            [obj.t_r, obj.pixel_shift_r, obj.piezo_motion_r, obj.compensated_motion_r, obj.zeroed_motion_r, obj.Texp_r] = obj.motion_summation(obj.T_r, obj.f_r, obj.A_r, obj.dudt_r);
            
            % Sensor data
            if ~isnan(obj.dudt_s)
                [obj.T_s, obj.f_s, obj.A_s] = obj.solve_motion_law(obj.dudt_s,Texp,method);
                [obj.t_s, obj.pixel_shift_s, obj.piezo_motion_s, obj.compensated_motion_s, obj.zeroed_motion_s, obj.Texp_s] = obj.motion_summation(obj.T_s, obj.f_s, obj.A_s, obj.dudt_r);
            end

            % Optical Flow data
            if ~isnan(obj.dudt_of)
                [obj.T_of, obj.f_of, obj.A_of] = obj.solve_motion_law(obj.dudt_of,Texp,method);
                [obj.t_of, obj.pixel_shift_of, obj.piezo_motion_of, obj.compensated_motion_of, obj.zeroed_motion_of, obj.Texp_of] = obj.motion_summation(obj.T_of, obj.f_of, obj.A_of, obj.dudt_r);
            end
        end

        function plot_compensated_motion(obj)
            
            % Times in milliseconds
            t_shifted_r = (obj.t_r)*10^3;
            t_shifted_s = (obj.t_s)*10^3;
            t_shifted_of = (obj.t_s)*10^3;

            % Colors
            colors = cmap();
            
            % Plot compensated motion | Real
            figure("Name","Global Plot | Real",'Units','centimeters','Position',[0 0 18 12])
            plot(t_shifted_r, obj.pixel_shift_r,"LineWidth",2,"Color",colors(1,:));
            hold on;
            grid on;
            plot(t_shifted_r, obj.piezo_motion_r,"LineWidth",2,"Color",colors(2,:));
            plot(t_shifted_r, obj.compensated_motion_r,"LineWidth",2,"Color",colors(3,:));
            xlabel('Time [ms]', 'FontSize', 13, 'FontWeight', 'bold');
            ylabel('Pixel Shift [px]', 'FontSize', 13, 'FontWeight', 'bold');
            title('Compensated Motion','FontSize', 15, 'FontWeight', 'bold');
            legend('Pixel Shift','Piezo Motion','Compensated Motion','Location', 'northwest', 'FontSize', 12)
            
            % Plot compensated motion | Sensors
            if ~isnan(obj.dudt_s)
                figure("Name","Global Plot | Mesaures",'Units','centimeters','Position',[0 0 18 12])
                plot(t_shifted_s, obj.pixel_shift_s,"LineWidth",2,"Color",colors(1,:));
                hold on;
                grid on;
                plot(t_shifted_s, obj.piezo_motion_s,"LineWidth",2,"Color",colors(2,:));
                plot(t_shifted_s, obj.compensated_motion_s,"LineWidth",2,"Color",colors(3,:));
                xlabel('Time [ms]', 'FontSize', 13, 'FontWeight', 'bold');
                ylabel('Pixel Shift [px]', 'FontSize', 13, 'FontWeight', 'bold');
                title('Compensated Motion','FontSize', 15, 'FontWeight', 'bold');
                legend('Pixel Shift','Piezo Motion','Compensated Motion','Location', 'northwest', 'FontSize', 12)
            end

            % Plot compensated motion | Optical Flow
            if ~isnan(obj.dudt_of)
                figure("Name","Global Plot | Optical Flow",'Units','centimeters','Position',[0 0 18 12])
                plot(t_shifted_of, obj.pixel_shift_of,"LineWidth",2,"Color",colors(1,:));
                hold on;
                grid on;
                plot(t_shifted_of, obj.piezo_motion_of,"LineWidth",2,"Color",colors(2,:));
                plot(t_shifted_of, obj.compensated_motion_of,"LineWidth",2,"Color",colors(3,:));
                xlabel('Time [ms]', 'FontSize', 13, 'FontWeight', 'bold');
                ylabel('Pixel Shift [px]', 'FontSize', 13, 'FontWeight', 'bold');
                title('Compensated Motion','FontSize', 15, 'FontWeight', 'bold');
                legend('Pixel Shift','Piezo Motion','Compensated Motion','Location', 'northwest', 'FontSize', 12)
            end

            % Plot detail of compensated motion | Real
            figure("Name","Compensated Motion | Real",'Units','centimeters','Position',[0 0 18 12])
            plot(t_shifted_r, obj.zeroed_motion_r,"LineWidth",2,"Color",colors(3,:));
            hold on;
            plot(t_shifted_r, obj.pixel_shift_r-obj.T_r*obj.dudt_r/2,"LineWidth",2,"Color",colors(1,:));
            grid on;
            xlabel('Time [ms]', 'FontSize', 13, 'FontWeight', 'bold');
            ylabel('Pixel Shift [px]', 'FontSize', 13, 'FontWeight', 'bold');
            title('Compensated Motion','FontSize', 15, 'FontWeight', 'bold');
            ylim([-0.5,0.5])

            % Plot detail of compensated motion | Sensors
            if ~isnan(obj.dudt_s)
                figure("Name","Compensated Motion | Sensors",'Units','centimeters','Position',[0 0 18 12])
                plot(t_shifted_s, obj.zeroed_motion_s,"LineWidth",2,"Color",colors(3,:));
                grid on;
                xlabel('Time [ms]', 'FontSize', 13, 'FontWeight', 'bold');
                ylabel('Pixel Shift [px]', 'FontSize', 13, 'FontWeight', 'bold');
                title('Compensated Motion','FontSize', 15, 'FontWeight', 'bold');
                ylim([-0.5,0.5])
            end

            % Plot detail of compensated motion | OF
            if ~isnan(obj.dudt_of)
                figure("Name","Compensated Motion | Optical Flow",'Units','centimeters','Position',[0 0 18 12])
                plot(t_shifted_of, obj.zeroed_motion_of,"LineWidth",2,"Color",colors(3,:));
                grid on;
                xlabel('Time [ms]', 'FontSize', 13, 'FontWeight', 'bold');
                ylabel('Pixel Shift [px]', 'FontSize', 13, 'FontWeight', 'bold');
                title('Compensated Motion','FontSize', 15, 'FontWeight', 'bold');
                ylim([-0.5,0.5])
            end

            % Compare the sources
            figure("Name","Compensated Motion | Comparison",'Units','centimeters','Position',[0 0 18 12])
            plot(t_shifted_r, obj.zeroed_motion_r,"LineWidth",2,"DisplayName",'Compensated Motion | Real',"Color",colors(1,:));
            hold on;
            if ~isnan(obj.dudt_s)
                plot(t_shifted_s, obj.zeroed_motion_s,"LineWidth",2,"DisplayName",'Compensated Motion | Sensors',"Color",colors(2,:));
            end
            if ~isnan(obj.dudt_of)
                plot(t_shifted_of, obj.zeroed_motion_of,"LineWidth",2,"DisplayName",'Compensated Motion | Optical Flow',"Color",colors(3,:));
            end
            grid on;
            xlabel('Time [ms]', 'FontSize', 13, 'FontWeight', 'bold');
            ylabel('Pixel Shift [px]', 'FontSize', 13, 'FontWeight', 'bold');
            title('Compensated Motion | Comparison','FontSize', 15, 'FontWeight', 'bold');
            legend('Location', 'northwest', 'FontSize', 12);
            ylim([-0.5,0.5])
        end
    end
end