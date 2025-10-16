% 1920x1080 a 960x540 –> 480x270.
%
% Spero quanto sopra sia d'aiuto.
clc, clear

u = -155.2630; % Mean values from simulation, nadir pointing, SSO orbit
v = 8.9959; % Mean values from simulation, nadir pointing, SSO orbit
exposure_time = 1/1000;
dt = 0.1;

blur_vec       = [false,false,true,true];
continuity_vec = [false,true,true,false];
resolution = [[2560,2560];
              [1440,2560];
              [1920,1080];
              [960,540];
              [480,270]];

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
                        'data', substruct), n, 1);

                        

imgFiles = dir(fullfile("D:\AKO\UNI_AERO\Tesi_Magistrale\VLEO_numerical_simulator\src\media\test_db",'*.jpg'));

% Loop through resolutions
for i = 1:n
    fprintf("#### Resolution: %dx%d #### \n",resolution(i,2),resolution(i,1))
    imaging(i).resolution = resolution(i,:);
    imaging(i).u_real = u;
    imaging(i).v_real = v;
    
    % Loop through settings
    for h = 1:m
        % Set settings
        blur = blur_vec(h);
        cont = continuity_vec(h);

        % Save settings
        imaging(i).data(h).blur = blur;
        imaging(i).data(h).continuity = cont;

        fprintf("blur: %s - continuity: %s | [", string(blur), string(cont))
        % Preallocate
        u_est = zeros(length(imgFiles),1);
        v_est = zeros(length(imgFiles),1);
        time = 0;

        for k = 1:length(imgFiles)
            % Find images
            img_name = imgFiles(k).name;
            img_path = fullfile(imgFiles(k).folder,img_name);
            image = imread(img_path);

            % Cropping rectangle
            r = centerCropWindow2d(size(image),resolution(i,:));

            if blur
                blur_len = sqrt(u^2+v^2)*exposure_time/dt;
                blur_angle = rad2deg(atan(v/u));
                H = fspecial("motion",blur_len,blur_angle);
                image = imfilter(image,H,"replicate");
            end

            if cont
                [original_img, shifted_img] = img_shift(image,u,v);
                original_img = imcrop(original_img,r);
                shifted_img = imcrop(shifted_img,r);
            else
                image = imcrop(image,r);
                [original_img, shifted_img] = img_shift(image,u,v);
            end
            tic
            [u_est(k),v_est(k)] = OF(original_img,shifted_img,10);
            t = toc;
            time = time + t;
            fprintf('.');
        end

        fprintf("]\n")
        [s_u, m_u] = std(u_est);
        [s_v, m_v] = std(v_est);
        merror_u = abs(m_u-u);
        merror_v = abs(m_v-v);
        fps = time/length(imgFiles);

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
save(fullfile(fileparts(mfilename("fullpath")),"OF_reuslts"),"imaging")
jsonStr = jsonencode(imaging, 'PrettyPrint', true);
fid = fopen('data.json', 'w');
if fid == -1, error('Cannot create JSON file.'); end
fwrite(fid, jsonStr, 'char');
fclose(fid);
