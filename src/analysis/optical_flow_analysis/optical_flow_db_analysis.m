clc, clear

u = -155.2630; % Mean values from simulation, nadir pointing, SSO orbit
v = 8.9959; % Mean values from simulation, nadir pointing, SSO orbit
exposure_time = 1/1000;
dt = 0.1;

blur_vec       = [false,false,true,true];
continuity_vec = [false,true,true,false];
resolution = [[2560,2560];
              [1440,2560];
              [1080,1920];
              [540,960];
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

                        
% Preload all images: this is bad practise if the datased it very large, it
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
    imaging(i).exposure_time = exposure_time;
    imaging(i).dt = dt;

    % Loop through settings
    for h = 1:m
        % Set settings
        blur = blur_vec(h);
        cont = continuity_vec(h);
        % Save settings
        imaging(i).data(h).blur = blur;
        imaging(i).data(h).continuity = cont;
        fprintf("BLUR: %s - CONTINUITY: %s ", string(blur), string(cont))
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
        [s_u, m_u] = std(u_est);
        [s_v, m_v] = std(v_est);
        merror_u = abs(m_u-u);
        merror_v = abs(m_v-v);
        fps = nImages/time;
        % Save data
        imaging(i).data(h).u_est = u_est;
        imaging(i).data(h).v_est = v_est;
        imaging(i).data(h).mae_u = merror_u;
        imaging(i).data(h).mae_v = merror_v;
        imaging(i).data(h).std_u = s_u;
        imaging(i).data(h).std_v = s_v;
        imaging(i).data(h).time = time;
        imaging(i).data(h).fps = fps;
    end
end

% Export results as .mat and .json
save(fullfile(fileparts(mfilename("fullpath")),"optical_flow_results"),"imaging")
jsonStr = jsonencode(imaging, 'PrettyPrint', true);
fid = fopen('OF_results.json', 'w');
if fid == -1, error('Cannot create JSON file.'); end
fwrite(fid, jsonStr, 'char');
fclose(fid);
