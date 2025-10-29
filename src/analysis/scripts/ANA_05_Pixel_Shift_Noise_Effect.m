function ANA_05_Pixel_Shift_Noise_Effect(options)

% ANA_05_PIXEL_SHIFT_NOISE_EFFECT This script compares the individual
% effects on (u,v) given by different sources of sensor errors to highlight
% which one is more relevant.

arguments (Input)
    options.simulations (1,:) = 1;
    options.data struct = [];
end

script_name = "ANA_05";

%%%%%% LOAD SIMULATION RESULTS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if isempty(options.data)
    data = load_data().results;
else
    fprintf("Simulation data is already loaded.\n")
    data = options.data;
end

%%%%%% PARAMETER INITIALIZATION and PRE-PROCESSING %%%%%%%%%%%%%%%%%%%%%%%%
% Create figures outside the loop
fig1 = figure("Name","U Real vs Sensor");

fig2 = figure("Name","V Real vs Sensor");

fig3 = figure("Name","U Real vs Sensor | difference");

fig4 = figure("Name","V Real vs Sensor | difference");

colors = lines(length(options.simulations));

labels = ["GPS position","GPS velocity","Quaternion","Angular rate"];

% Initialize real values outside loop.
u_real = data(1).simOut.u_real.Data;
v_real = data(1).simOut.v_real.Data;

for k = options.simulations
    t = data(k).t;
    
    u_sensors = data(k).simOut.u_sensors.Data;
    v_sensors = data(k).simOut.v_sensors.Data;

    %%%%%% PERFORM ANALYSIS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    position_gps_ON = data(k).simIn.position_gps_ON;
    velocity_gps_ON = data(k).simIn.velocity_gps_ON;
    quaternion_noise_ON = data(k).simIn.quaternion_noise_ON;
    angular_rate_noise_ON = data(k).simIn.angular_rate_noise_ON;

    indexes = logical([position_gps_ON,velocity_gps_ON,quaternion_noise_ON,angular_rate_noise_ON]);
    label = strjoin(labels(indexes)," - ");

    %%%%%% PLOTTING %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Compare U
    figure(fig1)

    plot(t,u_sensors,'Color',colors(k,:),'DisplayName',label)
    hold on

    % Compare V
    figure(fig2)

    plot(t,v_sensors,'Color',colors(k,:),'DisplayName',label)
    hold on

    % Compare U difference
    figure(fig3)

    plot(t,u_sensors-u_real,'Color',colors(k,:),'DisplayName',label)
    hold on

    % Compare V difference
    figure(fig4)

    plot(t,v_sensors-v_real,'Color',colors(k,:),'DisplayName',label)
    hold on
end

% Finalize figure 1
figure(fig1)

plot(t,u_real,'DisplayName','U real','Color','k')
xlabel("Time [s]")
ylabel("U [px]")
title("U Real vs Sensor")
grid on
legend show
savefig(script_name+"_UPixelNoiseEffect")

% Finalize figure 2
figure(fig2)

plot(t,v_real,'DisplayName','V real','Color','k')
xlabel("Time [s]")
ylabel("V [px]")
title("V Real vs Sensor")
grid on
legend show
savefig(script_name+"_VPixelNoiseEffect")

% Finalize figure 3
figure(fig3)

plot(t,zeros(size(u_real)), 'k--','HandleVisibility','off') % Reference line at zero
xlabel("Time [s]")
ylabel("U_{sensor} - U_{real} [px]")
title("U Real vs Sensor | Difference")
grid on
legend show
savefig(script_name+"_UPixelNoiseEffectDifference")

% Finalize figure 4
figure(fig4)

plot(t,zeros(size(v_real)), 'k--','HandleVisibility','off') % Reference line at zero
xlabel("Time [s]")
ylabel("V_{sensor} - V_{real} [px]")
title("V Real vs Sensor | Difference")
grid on
legend show
savefig(script_name+"_VPixelNoiseEffectDifference")

end