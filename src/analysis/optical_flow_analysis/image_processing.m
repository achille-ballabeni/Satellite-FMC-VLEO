classdef image_processing < handle

    properties
        images % Image database
        imgFiles % Image filelist
        nImages % Number of images
        sensor % Imaging sensor selection
        scenario % Orbital scenario
        Vpixel % Pixel velocity
        Tblur % Maximum exposure time before blur
        Tsaturation % Maximum exposure time before saturation

        OFout % Output results for optical flow analysis
        SNRout % Output results for SNR analysis
    end

    methods
        function obj = image_processing(options)
            % IMAGE_PROCESSING Initializes image-processing object and
            % loads database files.
            %
            % Input Arguments
            %   options.db_path - Path to the image database folder. If
            %       "default", loads the internal test database.
            %     string, default "default"
            %
            % Output Arguments
            %   obj - Initialized image-processing object with loaded image
            %       files, sensor parameters, and scenario configuration.
            %     object

            arguments (Input)
                options.db_path string = "default"
                options.sensor string = "TriScape100"
            end

            % Select database folder
            if options.db_path == "default"
                path = fullfile(fileparts(mfilename("fullpath")),'..','..','media','test_db','*.jpg');
            elseif isfolder(options.db_path)
                path = options.db_path;
            else
                error("%s is not a folder", options.db_path)
            end

            % Find images
            obj.imgFiles = dir(path);

            if isempty(obj.imgFiles)
                error("No files in %s", path)
            end

            % Initialize parameters
            obj.set_sensor('sensor',options.sensor);
            obj.set_scenario();
            obj.Vshift();
            obj.saturation();
        end

        function load_images(obj)
            % LOAD_IMAGES Loads all images listed in the object's imgFiles
            % property.

            obj.nImages = length(obj.imgFiles);
            obj.images = cell(1, obj.nImages);
            fprintf("Loading images ")
            for k = 1:obj.nImages
                img_path = fullfile(obj.imgFiles(k).folder, obj.imgFiles(k).name);
                obj.images{k} = imread(img_path);
                progressbar(k,obj.nImages)
            end
        end

        function set_sensor(obj,options)
            % SET_SENSOR Initializes the sensor model used by the object.
            %
            % Input Arguments
            %   obj - Object whose sensor configuration will be updated.
            %     object
            %   options.sensor - Name of the sensor model to load.
            %     string, default "triscape100"

            arguments (Input)
                obj
                options.sensor string = "triscape100"
            end

            obj.sensor = sensors(options.sensor);
        end

        function set_scenario(obj,options)
            % SET_SCENARIO Configures scenario parameters such as altitude
            % and photon flux.
            %
            % Input Arguments
            %   obj - Object whose scenario parameters will be configured.
            %     object
            %   options.altitude - Scenario altitude value.
            %     scalar double, default 250000
            %   options.photon_flux - Incoming photon flux level.
            %     scalar double, default 1.8e7

            arguments (Input)
                obj
                options.altitude (1,1) double = 250000
                options.photon_flux (1,1) double = 1.8e7
            end

            obj.scenario.altitude = options.altitude;
            obj.scenario.photon_flux = options.photon_flux;
        end

        function run_OF_analysis(obj,options)
            % RUN_OF_ANALYSIS Executes an optical flow (OF) performance
            % analysis across multiple resolutions and imaging conditions.
            %
            % - Runs optical flow estimation using pixel-shifted image
            % pairs. - Tests combinations of blur, noise, continuity,
            % resolution,
            %   and exposure time.
            % - Computes MAE, STD, FPS, and stores full estimated flow
            % sequences.
            %
            % Input Arguments
            %   obj - Class instance containing sensor, scenario, images,
            %       and methods.
            %     object
            %   options.resolutions - Image resolutions to test [height,
            %       width].
            %     n-by-2 array, default [[1080,1920]]
            %   options.exposures - Exposure times used when blur or noise
            %       is enabled.
            %     1-by-m double, default 600microseconds
            %   options.blur - Flag to enable motion blur per
            %       configuration.
            %     1-by-m logical, default [false]
            %   options.noise - Flag to enable photon shot noise per
            %       configuration.
            %     1-by-m logical, default [false]
            %   options.continuity - Flag to enable continuity in image
            %   cropping.
            %     1-by-m logical, default [false]
            %   options.dt - Time difference between frames.
            %     scalar double, default 0.05

            arguments (Input)
                obj
                options.resolutions (:,2) double = [[1080,1920]]
                options.exposures (1,:) double = 600*10^-6
                options.blur (1,:) logical = [false]
                options.noise (1,:) logical = [false]
                options.continuity (1,:) logical = [false]
                options.dt (1,1) double = 0.05
            end

            n = size(options.resolutions, 1);
            m = length(options.blur);

            % Initialize output variables
            substruct = repmat( ...
                struct( ...
                'blur', [], ...
                'continuity', [], ...
                'exposure', [], ...
                'noise', [], ...
                'u_est', [], ...
                'v_est', [], ...
                'mae_u', [], ...
                'mae_v', [], ...
                'std_u', [], ...
                'std_v', [], ...
                'time', [], ...
                'fps', []), ...
                m, 1);
            obj.OFout = repmat( ...
                struct( ...
                'resolution', [], ...
                'u_real', [], ...
                'v_real', [], ...
                'dt', [], ...
                'Tblur', [], ...
                'Tsaturation', [], ...
                'scenario', struct, ...
                'sensor', struct, ...
                'data', substruct), ...
                n, 1);

            % Unpack true shifts
            [Vpx, Tb] = obj.Vshift();
            uv = Vpx*options.dt;
            u = uv(1);
            v = uv(2);

            % Loop through resolutions
            for i = 1:n
                fprintf("#### Resolution: %dx%d #### \n", options.resolutions(i,2), options.resolutions(i,1))
                obj.OFout(i).resolution = options.resolutions(i,:);
                obj.OFout(i).u_real = u;
                obj.OFout(i).v_real = v;
                obj.OFout(i).dt = options.dt;
                obj.OFout(i).Tblur = Tb;
                obj.OFout(i).Tsaturation = obj.saturation();
                obj.OFout(i).scenario = obj.scenario();
                obj.OFout(i).sensor = obj.sensor;

                % Set index per each combination in resolution
                index = 1;

                % Loop through settings
                for h = 1:m
                    % Set settings
                    blur = options.blur(h);
                    cont = options.continuity(h);
                    noise = options.noise(h);
                    % Exclude non time-dependent combinations
                    if blur || noise
                        exp_loop = options.exposures;
                    else
                        exp_loop = "any";
                    end
                    % Loop through exposures
                    for exposure_time = exp_loop
                        % Save settings
                        obj.OFout(i).data(index).blur = blur;
                        obj.OFout(i).data(index).continuity = cont;
                        obj.OFout(i).data(index).exposure = exposure_time;
                        obj.OFout(i).data(index).noise = noise;
                        fprintf("\nBLUR: %s - CONTINUITY: %s - NOISE: %s - EXPOSURE TIME: %s ", string(blur), string(cont), string(noise), string(exposure_time))
                        % Preallocate
                        u_est = zeros(obj.nImages,1);
                        v_est = zeros(obj.nImages,1);
                        time = 0;
                        for k = 1:obj.nImages
                            % Get image from preloaded cell array
                            image = obj.images{k};

                            % Add motion blur
                            if blur
                                % Compute blur shift
                                blur_shift = Vpx.*exposure_time;
                                image = motion_blur(image,blur_shift);
                            end

                            % Cropping rectangle
                            r = centerCropWindow2d(size(image), options.resolutions(i,:));
                            if cont
                                [original_img, shifted_img] = img_shift(image, u, v);
                                original_img = imcrop(original_img, r);
                                shifted_img = imcrop(shifted_img, r);

                                % Add shot noise to image
                                if noise
                                    [original_img, ~] = shot_noise(original_img,exposure_time,obj.scenario.photon_flux,1,obj.sensor.full_well,obj.sensor.gain);
                                    [shifted_img, ~] = shot_noise(shifted_img,exposure_time,obj.scenario.photon_flux,1,obj.sensor.full_well,obj.sensor.gain);
                                end

                            else
                                image = imcrop(image, r);
                                [original_img, shifted_img] = img_shift(image, u, v);
                                % Save padding pixels where no image is present due to
                                % shift
                                padded_mask = (shifted_img == 0) & (original_img ~= 0);

                                % Add shot noise to image
                                if noise
                                    [original_img, ~] = shot_noise(original_img,exposure_time,obj.scenario.photon_flux,1,obj.sensor.full_well,obj.sensor.gain);
                                    [shifted_img, ~] = shot_noise(shifted_img,exposure_time,obj.scenario.photon_flux,1,obj.sensor.full_well,obj.sensor.gain);
                                    % Remove noise from padded values
                                    shifted_img(padded_mask) = 0;
                                end
                            end

                            % Time optical flow
                            tic
                            [u_est(k), v_est(k)] = optical_flow(original_img, shifted_img, 10);
                            t = toc;
                            time = time + t;

                            % Display progress bar
                            progressbar(k, obj.nImages)
                        end

                        % Exclude outliers from the error computation.
                        out_u = abs(u_est-u)<5;
                        out_v = abs(v_est-v)<5;
                        [s_u, m_u] = std(u_est(out_u));
                        [s_v, m_v] = std(v_est(out_v));
                        merror_u = abs(m_u-u);
                        merror_v = abs(m_v-v);
                        fps = obj.nImages/time;

                        % Save data
                        obj.OFout(i).data(index).u_est = u_est;
                        obj.OFout(i).data(index).v_est = v_est;
                        obj.OFout(i).data(index).mae_u = merror_u;
                        obj.OFout(i).data(index).mae_v = merror_v;
                        obj.OFout(i).data(index).std_u = s_u;
                        obj.OFout(i).data(index).std_v = s_v;
                        obj.OFout(i).data(index).time = time;
                        obj.OFout(i).data(index).fps = fps;

                        index = index + 1;
                    end
                end
            end

            % Export results
            name = "optical_flow_results";
            out = obj.OFout;
            obj.export_results(name,out)
        end

        function runSNR(obj,options)
            % RUNSNR Computes the signal-to-noise ratio (SNR) for a set of
            % images under different exposure times and optional blur.
            %
            % Input Arguments
            %   obj - Object containing images, sensor, and scenario
            %       parameters.
            %     object
            %   options.exposures - Array of exposure times to test.
            %     1-by-n double, default 600e-6
            %   options.blur - Flag indicating whether motion blur is
            %       applied.
            %     scalar logical, default false

            arguments (Input)
                obj
                options.exposures (1,:) double = 600*10^-6
                options.blur (1,1) double = false
                options.noise (1,1) double = false
            end

            % Validate blur and noise
            if ~options.blur && ~options.noise
                warning("Simulation is useless! At least one between noise and blur should be true!")
            end

            n = length(options.exposures);

            % Initialize output variables
            obj.OFout = repmat( ...
                struct( ...
                'exposure', [], ...
                'blur', [], ...
                'noise', [], ...
                'scenario', struct, ...
                'sensor', struct, ...
                'Tblur', [], ...
                'Tsaturation', [], ...
                'mean_SNR', [], ...
                'SNR', []), ...
                n, 1);
            snr = zeros(1,obj.nImages);

            for i = 1:n
                time = options.exposures(i);

                % Compute pixel shift and blur time
                [Vpx, Tb] = obj.Vshift();

                % Begin main cycle
                fprintf("Exposure time: %f ", time)
                for k = 1:obj.nImages
                    % Get image from preloaded cell array
                    image = obj.images{k};
                    ref = image;

                    % Add motion blur
                    if options.blur
                        blur_shift = Vpx.*time;
                        [image, ~] = motion_blur(image,blur_shift);
                    end

                    % Add noise
                    if options.noise
                        [image, ~] = shot_noise(image,time,obj.scenario.photon_flux,1,obj.sensor.full_well,obj.sensor.gain);
                        % TODO: improve computations. This is already
                        % computed inside shot noise. Maybe make a class to
                        % contain all methods related to the image
                        % processing.
                        ref = uint8(obj.scenario.photon_flux*time*double(ref)./255*obj.sensor.gain);
                    end

                    % Greyscale conversion
                    ref = im2gray(ref);
                    image = im2gray(image);

                    % Compute SNR
                    denom = sqrt(mean((double(image)-double(ref)).^2,"all"));
                    SNR = mean(double(ref)./denom,"all");
                    snr(k) = SNR;

                    % Display progress bar
                    progressbar(k, obj.nImages)
                end
                mean_SNR = mean(snr,"all");

                % Save data
                obj.SNRout(i).exposure = time;
                obj.SNRout(i).blur = options.blur;
                obj.SNRout(i).noise = options.noise;
                obj.SNRout(i).scenario = obj.scenario;
                obj.SNRout(i).sensor = obj.sensor;
                obj.SNRout(i).Tblur = Tb;
                obj.SNRout(i).Tsaturation = obj.saturation;
                obj.SNRout(i).mean_SNR = mean_SNR;
                obj.SNRout(i).SNR = snr;
            end

            % Export results
            name = "SNR_results";
            out = obj.SNRout;
            obj.export_results(name,out)
        end

        function [Vpx,Tb] = Vshift(obj)
            % VSHIFT Computes the pixel velocity for given sensor and
            % scenario.
            %
            % Output Arguments:
            %   Vpixel - Pixel velocity in camera frame.
            %     1-by-2 array
            %   Tblur - Exposure time before blur occurrs. Nadir pointing
            %       SSO scenario at equator with moving earth.
            %     scalar

            arguments (Input)
                obj
            end

            arguments (Output)
                Vpx (1,2) double
                Tb (1,1) double
            end

            % Earth parameters
            Re = 6378*10^3;
            mi = 3.986004418e14;
            We = 7.2921159e-5;
            dOmega_dt = 0.19910213e-6;
            J2 = 1.082635854e-3;
            sma = Re+obj.scenario.altitude;
            inc_SSO = acos(-2/3*dOmega_dt/J2*(sma/Re)^2*sqrt(sma^3/mi)); %TODO: where should I move this calculation?
            Vearth = We*Re;
            % Ground sampling distance
            GSD = gsd(obj.sensor.px,obj.sensor.f,obj.scenario.altitude);
            % Orbital velocity
            Vorb = sqrt(mi/(Re+obj.scenario.altitude));
            % Pixel velocity
            Vx = -Vorb + Vearth*cos(inc_SSO);
            Vy = -Vearth*sin(inc_SSO);
            obj.Vpixel = [Vx, Vy]/GSD;
            % Best case blur time
            obj.Tblur = 1/max(abs(obj.Vpixel));
            % Outputs
            Vpx = obj.Vpixel;
            Tb = obj.Tblur;
        end

        function Tsat = saturation(obj)
            % TEXPOSURE Computes the maximum exposure time before
            % saturation
            %
            % Output Arguments:
            %   Tsat - Exposure time .
            %     scalar

            arguments (Input)
                obj
            end

            arguments (Output)
                Tsat (1,1) double
            end

            % Compute the saturation time
            obj.Tsaturation = obj.sensor.full_well/obj.scenario.photon_flux;
            Tsat = obj.Tsaturation;
        end
    end

    methods (Static)
        function export_results(name,output)
            % EXPORT_RESULTS Saves the specified output data to .mat and
            % .json files with a timestamped filename.
            %
            % Input Arguments
            %   name - Base name for the exported file.
            %     string
            %   output - Data to be saved.
            %     any

            arguments (Input)
                name
                output
            end

            % Define path
            timestamp = string(datetime('now','Format','uuuu-MM-dd_HH-mm-ss'));
            filename = timestamp + "_" + name;
            current_dir = fileparts(mfilename("fullpath"));
            savedir = fullfile(current_dir,"..","..","..","IM_results");
            mkdir(savedir)
            savepath = fullfile(savedir,filename);

            % Export results as .mat and .json
            save(savepath,"output")
            jsonStr = jsonencode(output, 'PrettyPrint', true);
            fid = fopen(savepath + ".json", 'w');
            if fid == -1
                error('Cannot create JSON file.');
            end
            fwrite(fid, jsonStr, 'char');
            fclose(fid);
        end
    end
end