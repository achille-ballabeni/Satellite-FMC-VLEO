clc, clear
%% Get saturation time and pixel velocity
im = image_processing( ...
    "altitude",250000, ...
    "optics","triscape100", ...
    "sensor","cmv12000", ...
    "beta_angle",22.5, ...
    "latitude",45);

u = abs(im.Vpixel(1));

%% Compute compensated motion (saturating at maximum piezo range)
piezo_range = 50*10^-6/im.sensor.px;
fmc = piezo_compensation(u,piezo_range,"Vim_sensors",0.98*u);
fmc.compute_compensated_motion(im.Tsaturation)

%% Plot compensated motion and display amplitudes
fmc.plot_compensated_motion()

A_r = fmc.A_r*im.sensor.px*10^6;
A_s = fmc.A_s*im.sensor.px*10^6;

fprintf("Amplitude | Ideal world:  %.2f um\n",A_r)
fprintf("Amplitude | Measurements: %.2f um\n",A_s)
