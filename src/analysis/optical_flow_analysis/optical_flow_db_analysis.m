clc, clear

% Steady state values from simulation, nadir pointing, SSO orbit
u = -156.63;
v = 8.74;
dt = 0.5;

exposure_times = [1/15, 1/30, 1/60, 1/125, 1/250, 1/500, 1/1000];
blur_vec       = [false,false,true,true];
continuity_vec = [false,true,true,false];
resolution = [[2560,2560];
              [1440,2560];
              [1080,1920];
              [720,1280];
              [540,960];
              [360,640];
              [270,480]];

n = size(resolution, 1);
m = length(blur_vec);

substruct = repmat(struct('blur', [], ...
                          'continuity', [], ...
                          'u_est', [], ...
                          'v_est', [], ...
                          'mae_u', [], ...
                          'mae_v', [], ...
                          'std_u', [], ...
                          'std_v', [], ...
                          'time', [], ...
                          'fps', []), m, 1);
imaging = repmat(struct('resolution', [], ...
                        'u_real', [], ...
                        'v_real', [], ...
                        'exposure_time', [], ...
                        'dt', [], ...
                        'data', substruct), n, 1);

                        
% Preload all images: this is bad practice if the dataset it very large, it
% would be more convenient to load one image at a time and process it with
% the different settings. That would require a change in the logic of the
% current script and I don't think it's worth it at the moment. If larger
% databases are used, a change is required.
imgFiles = dir(fullfile(fileparts(mfilename("fullpath")),'..\..\media\test_db','*.jpg'));
nImages = length(imgFiles);
images = cell(1, nImages);
fprintf("Loading images ")
for k = 1:nImages
    img_path = fullfile(imgFiles(k).folder, imgFiles(k).name);
    images{k} = imread(img_path);
    progressbar(k,nImages)
end

% Loop through resolutions
for i = 1:n
    fprintf("#### Resolution: %dx%d #### \n", resolution(i,2), resolution(i,1))
    imaging(i).resolution = resolution(i,:);
    imaging(i).u_real = u;
    imaging(i).v_real = v;
    imaging(i).dt = dt;

    for j = 1:length(exposure_times)
        exposure_time = exposure_times(j);

        % Loop through settings
        for h = 1:m
            index = h+(j-1)*m;
            % Set settings
            blur = blur_vec(h);
            cont = continuity_vec(h);
            % Save settings
            imaging(i).data(index).blur = blur;
            imaging(i).data(index).continuity = cont;
            imaging(i).data(index).exposure = exposure_time;
            fprintf("BLUR: %s - CONTINUITY: %s - EXPOSURE TIME: %f ", string(blur), string(cont), string(exposure_time))
            % Preallocate
            u_est = zeros(nImages,1);
            v_est = zeros(nImages,1);
            time = 0;
            for k = 1:nImages
                % Get image from preloaded cell array
                image = images{k};
                % Cropping rectangle
                r = centerCropWindow2d(size(image), resolution(i,:));
                if blur
                    blur_len = sqrt(u^2+v^2)*exposure_time/dt;
                    blur_angle = rad2deg(atan(v/u));
                    H = fspecial("motion", blur_len, blur_angle);
                    image = imfilter(image, H, "replicate");
                end
                if cont
                    [original_img, shifted_img] = img_shift(image, u, v);
                    original_img = imcrop(original_img, r);
                    shifted_img = imcrop(shifted_img, r);
                else
                    image = imcrop(image, r);
                    [original_img, shifted_img] = img_shift(image, u, v);
                end
                tic
                [u_est(k), v_est(k)] = optical_flow(original_img, shifted_img, 10);
                t = toc;
                time = time + t;
                progressbar(k, nImages)
            end
            fprintf("\n")
            % Exclude outliers from the error computation.
            out_u = abs(u_est-u)<5;
            out_v = abs(v_est-v)<5;
            [s_u, m_u] = std(u_est(out_u));
            [s_v, m_v] = std(v_est(out_v));
            merror_u = abs(m_u-u);
            merror_v = abs(m_v-v);
            fps = nImages/time;
            % Save data
            imaging(i).data(index).u_est = u_est;
            imaging(i).data(index).v_est = v_est;
            imaging(i).data(index).mae_u = merror_u;
            imaging(i).data(index).mae_v = merror_v;
            imaging(i).data(index).std_u = s_u;
            imaging(i).data(index).std_v = s_v;
            imaging(i).data(index).time = time;
            imaging(i).data(index).fps = fps;
        end
    end
end

% Export results as .mat and .json
save(fullfile(fileparts(mfilename("fullpath")),"optical_flow_results"),"imaging")
jsonStr = jsonencode(imaging, 'PrettyPrint', true);
fid = fopen('OF_results.json', 'w');
if fid == -1, error('Cannot create JSON file.'); end
fwrite(fid, jsonStr, 'char');
fclose(fid);
