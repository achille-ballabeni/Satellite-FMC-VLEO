classdef image_processing < handle

    properties
        images % Image database
        imgFiles % Image filelist
        nImages % Number of images
        sensor % Imaging sensor selection
        scenario % Orbital scenario
        optics % Imaging payload optics
        Vpixel % Pixel velocity
        Tblur % Maximum exposure time before blur
        Tsaturation % Maximum exposure time before saturation
        base_dir % Root directory of project

        OFout % Output results for optical flow analysis
        SNRout % Output results for SNR analysis
        GEOout % Output results for geometrical analysis
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
            %   options.optics - Name of the payload optics to use.
            %     string, default "TriScape100"
            %   options.sensor - Name of the sensor to use.
            %     string, default "CMV12000"
            %
            % Output Arguments
            %   obj - Initialized image-processing object with loaded image
            %       files, sensor parameters, and scenario configuration.
            %     object

            arguments (Input)
                options.db_path string = "default"
                options.optics string = "TriScape100"
                options.sensor string = "CMV12000"
            end

            % Project root folder
            obj.base_dir = matlab.project.currentProject().RootFolder;

            % Initialize python
            obj.py_init()

            % Select database folder
            if options.db_path == "default"
                path = fullfile(obj.base_dir,'src','media','test_db','*.jpg');
            elseif isfolder(options.db_path)
                path = fullfile(options.db_path,'*.jpg');
            else
                error("%s is not a folder", options.db_path)
            end

            % Find images
            obj.imgFiles = dir(path);

            if isempty(obj.imgFiles)
                error("No files in %s", path)
            end

            % Initialize parameters
            obj.set_optics('optics',options.optics);
            obj.set_sensor('sensor',options.sensor);
            obj.set_scenario();
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

        function set_optics(obj,options)
            % SET_OPTICS Initializes the payload optics model used by the
            % object.
            %
            % Input Arguments
            %   obj - Object whose optics configuration will be updated.
            %     object
            %   options.optics - Name of the payload optics to use.
            %     string, default "triscape100"

            arguments (Input)
                obj
                options.optics string = "triscape100"
            end

            obj.optics = payload_optics(options.optics);

            % Update saturation and blur when optics is changed
            if ~isempty(obj.scenario) && ~isempty(obj.sensor)
                obj.electron_flux();
                obj.saturation();
                obj.Vshift();
            end
        end

        function set_sensor(obj,options)
            % SET_SENSOR Initializes the sensor model used by the object.
            %
            % Input Arguments
            %   obj - Object whose sensor configuration will be updated.
            %     object
            %   options.sensor - Name of the sensor model to load.
            %     string, default "CMV12000"

            arguments (Input)
                obj
                options.sensor string = "CMV12000"
            end

            obj.sensor = sensors(options.sensor);

            % Update saturation and blur when sensor is changed
            if ~isempty(obj.scenario) && ~isempty(obj.optics)
                obj.electron_flux();
                obj.saturation();
                obj.Vshift();
            end
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
            %   options.month - Month to use for the 6SV simulation.
            %     scalar double, default 1
            %   options.latitude - Latitude of the satellite.
            %     scalar double, default 0
            %   options.beta_angle - Sun-Earth-Satellite angle.
            %     scalar double, default 1

            arguments (Input)
                obj
                options.altitude (1,1) double = 250000
                options.month (1,1) double = 1
                options.latitude (1,1) double = 0
                options.beta_angle (1,1) double = 0
            end

            % Set altitude
            obj.scenario.altitude = options.altitude;
            obj.scenario.month = options.month;
            obj.scenario.latitude = options.latitude;
            obj.scenario.beta_angle = options.beta_angle;

            % Update saturation and blur when scenario is changed
            if ~isempty(obj.sensor) && ~isempty(obj.optics)
                obj.electron_flux();
                obj.saturation();
                obj.Vshift();
            end
        end

        function electron_flux(obj)
            % ELECTRON_FLUX Runs 6SV simulation based on sensor, scenario and
            % optics. Saves results in obj.scenario.electron_rate.

            % sixsV1.1 path
            radiative_transfer_path = fullfile(obj.base_dir,"src","analysis","radiative_transfer");
            radiative_transfer_py = fullfile(radiative_transfer_path,"transfer.py");
            sixs_path = fullfile(radiative_transfer_path,"6SV1.1","sixsV1.1");

            % Run radiative transfer model to obtain electron flux
            file_with_arguments = radiative_transfer_py ...
                + " --sixs_path " + sixs_path ...
                + " --sensor " + obj.sensor.name ...
                + " --month " + obj.scenario.month ...
                + " --beta_angle " + obj.scenario.beta_angle ...
                + " --latitude " + obj.scenario.latitude;
            fprintf("Running 6SV simulation with beta = %.2f | latitude = %.2f | month = %d ...\n",obj.scenario.beta_angle,obj.scenario.latitude,obj.scenario.month)
            outvar = pyrunfile(file_with_arguments,"matlab_output");

            % Extract results and compute maximum electron rate
            dict_list = cell(outvar);
            colors = cellfun(@(d) string(d{"color"}), dict_list);
            electron_flux = cellfun(@(d) double(d{"electron_flux"}), dict_list);
            deltaL = cellfun(@(d) double(d{"integrated_filter_function"}), dict_list);
            electron_rate = electron_flux .* deltaL * pi ./ 4 .* (obj.optics.D / obj.optics.f) .^ 2 .* obj.sensor.px^2 .* obj.optics.tau;
            [m,i] = max(electron_rate);
            obj.scenario.electron_rate = m;
            obj.scenario.max_rate_band = colors(i);
            obj.scenario.integrated_filter_function = deltaL(i);
        end

        function runOF_ANALYSIS(obj,options)
            % RUNOF_ANALYSIS Executes an optical flow (OF) performance
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
                'optics', struct, ...
                'data', substruct), ...
                n, 1);

            % Unpack true shifts
            Vpx = obj.Vpixel;
            Tb = obj.Tblur;
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
                obj.OFout(i).Tsaturation = obj.Tsaturation;
                obj.OFout(i).scenario = obj.scenario;
                obj.OFout(i).sensor = obj.sensor;
                obj.OFout(i).optics = obj.optics;

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
                                    [original_img, ~] = shot_noise(original_img,exposure_time,obj.scenario.electron_rate,obj.sensor.full_well,obj.sensor.gain);
                                    [shifted_img, ~] = shot_noise(shifted_img,exposure_time,obj.scenario.electron_rate,obj.sensor.full_well,obj.sensor.gain);
                                end

                            else
                                image = imcrop(image, r);
                                [original_img, shifted_img] = img_shift(image, u, v);
                                % Save padding pixels where no image is present due to
                                % shift
                                padded_mask = (shifted_img == 0) & (original_img ~= 0);

                                % Add shot noise to image
                                if noise
                                    [original_img, ~] = shot_noise(original_img,exposure_time,obj.scenario.electron_rate,1,obj.sensor.full_well,obj.sensor.gain);
                                    [shifted_img, ~] = shot_noise(shifted_img,exposure_time,obj.scenario.electron_rate,1,obj.sensor.full_well,obj.sensor.gain);
                                    % Remove noise from padded values
                                    shifted_img(padded_mask) = 0;
                                end
                            end
                            % Quantize
                            original_img = uint8(original_img);
                            shifted_img = uint8(shifted_img);

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
            obj.SNRout = struct( ...
                'optics', obj.optics,...
                'sensor', obj.sensor, ...
                'scenario', obj.scenario, ...
                'blur', options.blur, ...
                'noise', options.noise, ...
                'Tblur', obj.Tblur, ...
                'Tsaturation', obj.Tsaturation, ...
                'data', struct);
            data = repmat( ...
                struct( ...
                'exposure', [], ...
                'mean_SNR',[], ...
                'SNR',[]), ...
                n, 1);

            snr = zeros(1,obj.nImages);

            for i = 1:n
                time = options.exposures(i);

                % Compute pixel shift and blur time
                Vpx = obj.Vpixel;

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
                        [image, ~] = shot_noise(image,time,obj.scenario.electron_rate,1,obj.sensor.full_well,obj.sensor.gain);
                        % TODO: improve computations. This is already
                        % computed inside shot noise. Maybe make a class to
                        % contain all methods related to the image
                        % processing.
                        ref = obj.scenario.electron_rate*time*double(ref)./255*obj.sensor.gain;
                    end

                    % Compute SNR
                    denom = sqrt(mean((double(image)-double(ref)).^2,[1,2]));
                    SNR = mean(mean(double(ref),[1,2])./denom);
                    snr(k) = SNR;

                    % Display progress bar
                    progressbar(k, obj.nImages)
                end
                mean_SNR = mean(snr,"all");

                % Save data
                data(i).exposure = time;
                data(i).mean_SNR = mean_SNR;
                data(i).SNR = snr;
            end

            % Prepare results
            obj.SNRout.data = data;

            % Export results
            if options.blur
                name = obj.sensor.name + "_" + obj.optics.name + "_blur_" + "SNR_results";
            else
                name = obj.sensor.name + "_" + obj.optics.name + "_SNR_results";
            end
            out = obj.SNRout;
            obj.export_results(name,out)
        end

        function runGEOMETRY(obj,options)
            % RUNGEOMETRY Computes exposure and blur times for various beta
            % angles and latitudes.
            %
            % Input Arguments
            %   obj - Object containing images, sensor, and scenario
            %       parameters.
            %     object
            %   options.latitudes - Array of latitudes to test.
            %     1-by-n double, default 45
            %   options.beta - Array of beta angles to test.
            %     1-by-m double, default 22.5
            %   options.saturation - Flag to compute 20% saturation time.
            %     scalar logica, default false

            arguments (Input)
                obj
                options.latitudes (1,:) double = 45
                options.beta (1,:) double = 22.5
                options.saturation (1,1) logical = false
            end

            % Number of beta/latitude simulations
            n = length(options.beta);
            m = length(options.latitudes);

            % Initialize output variables
            obj.GEOout = struct( ...
                'sensor', obj.sensor, ...
                'optics', obj.optics, ...
                'integrated_filter_function', obj.scenario.integrated_filter_function, ...
                'max_rate_band', obj.scenario.max_rate_band, ...
                'month', obj.scenario.month, ...
                'latitudes', options.latitudes, ...
                'beta', options.beta, ...
                'Tsaturation', [], ...
                'Tblur', [], ...
                'electron_rate', [], ...
                'Tsaturation_20perc', []);

            saturation_data = zeros(n,m);
            blur_data = zeros(n,m);
            electron_rate_data = zeros(n,m);
            saturation_percentile_data = zeros(n,m);

            % Loop beta angles
            for i = 1:n
                beta = options.beta(i);
                % Loop latitudes
                for k = 1:m
                    lat = options.latitudes(k);
                    obj.set_scenario("beta_angle",beta,"latitude",lat)
                    saturation_data(i,k) = obj.Tsaturation;
                    blur_data(i,k) = obj.Tblur;
                    electron_rate_data(i,k) = obj.scenario.electron_rate;
                    % Compute average 20% pixel saturation time
                    if options.saturation
                        p = zeros(length(obj.nImages));
                        for j = 1:obj.nImages
                            p(j) = prctile(obj.images{j}(:),80)-1;
                        end
                        Tsat_perc = mean(255./p.*obj.Tsaturation);
                        saturation_percentile_data(i,k) = Tsat_perc;
                    end
                end
            end
            % Prepare reuslts
            obj.GEOout.Tsaturation = saturation_data;
            obj.GEOout.Tblur = blur_data;
            obj.GEOout.electron_rate = electron_rate_data;
            obj.GEOout.Tsaturation_20perc = saturation_percentile_data;

            % Export results
            name = obj.sensor.name + "_" + obj.optics.name + "_GEO_results";
            out = obj.GEOout;
            obj.export_results(name,out)
        end

        function [Vpx,Tb] = Vshift(obj)
            % VSHIFT Computes the pixel velocity and blur time for given
            % sensor and scenario.
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
            Vearth = We*Re*cosd(obj.scenario.latitude);
            % Ground sampling distance
            GSD = gsd(obj.sensor.px,obj.optics.f,obj.scenario.altitude);
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
            obj.Tsaturation = obj.sensor.full_well/obj.scenario.electron_rate;
            Tsat = obj.Tsaturation;
        end

        function export_results(obj,name,output)
            % EXPORT_RESULTS Saves the specified output data to .mat and
            % .json files with a timestamped filename.
            %
            % Input Arguments
            %   name - Base name for the exported file.
            %     string
            %   output - Data to be saved.
            %     any

            arguments (Input)
                obj
                name
                output
            end

            % Define path
            timestamp = string(datetime('now','Format','uuuu-MM-dd_HH-mm-ss'));
            filename = timestamp + "_" + name;
            savedir = fullfile(obj.base_dir,"IM_results");
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

    methods (Access = private)
        function py_init(obj)
            % PY_INIT Initializes Python so it can be run from MATLAB.

            % Load Python env if not loaded
            if pyenv().Status == "NotLoaded"
                envpath = fullfile(obj.base_dir,"env","Scripts","python.exe");
                pyenv("Version",envpath);
            end

            radiative_transfer_path = fullfile(obj.base_dir,"src","analysis","radiative_transfer");

            % Add module path
            if ~any(string(py.sys.path) == radiative_transfer_path)
                insert(py.sys.path, int32(0), radiative_transfer_path);
            end
        end
    end
end