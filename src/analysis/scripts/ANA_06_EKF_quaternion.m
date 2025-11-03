function ANA_06_EKF_quaternion(options)
% ANA_06_EKF_quaternion This script implements the EKF using the quaternion
% as state and (u,v) as measurements.
arguments (Input)
    options.simulations (1,:) = 1;
    options.data struct = [];
end
script_name = "ANA_06";

%%%%%% LOAD SIMULATION RESULTS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if isempty(options.data)
    data = load_data().results;
else
    fprintf("Simulation data is already loaded.\n")
    data = options.data;
end

%%%%%% PARAMETER INITIALIZATION and PRE-PROCESSING %%%%%%%%%%%%%%%%%%%%%%%%
% Create figures outside the loop
fig1 = figure("Name","Q Estimated vs Real");

fig2 = figure("Name","U Estimated vs Real");

fig3 = figure("Name","V Estimated vs Real");

fig4 = figure("Name","U Estimated vs Real | Error");

fig5 = figure("Name","V Estimated vs Real | Error");

colors = lines(length(options.simulations));

for k = options.simulations
    % Time
    t = data(k).t;

    % Earth rotation
    We = [0,0,data(k).simIn.Omega_E];
    R_E = data(k).simIn.R_E;

    % Filter state
    Q_eci2body_real = data(k).simOut.Q_eci2body.Data;
    Q_eci2body_sensors = data(k).simOut.Q_eci2body_sensors.Data;
    Q_eci2body_0 = Q_eci2body_sensors(1,:);
    Q_eci2body = zeros(size(Q_eci2body_real));

    % Filter measurements
    u_real = data(k).simOut.u_real.Data;
    v_real = data(k).simOut.v_real.Data;
    u_of = data(k).simOut.u_OF.Data;
    v_of = data(k).simOut.v_OF.Data;
    u_sensors = data(k).simOut.u_sensors.Data;
    v_sensors = data(k).simOut.v_sensors.Data;
    z = [u_of,v_of];

    % Filter inputs
    dt = data(k).simIn.timeStep;
    Rsat_GPS = data(k).simOut.X_eci_GPS.Data;
    Vsat_GPS = data(k).simOut.V_eci_GPS.Data;
    LOS_hat_eci_sensors = data(k).simOut.LOS_hat_eci_sensors.Data;
    W_sat_eci_sensors = data(k).simOut.Wsat_eci_sensors.Data;
    W_sat_body_sensors = data(k).simOut.Wsat_body_sensors.Data;
    K_optics = data(k).simIn.K_optics;

    % Filter tuning (values obtained from automatic tuning using fmincon)
    Q = eye(4).*[0.4876, 0.5041, 0.5041, 0.5041];
    P = eye(4).*mean((Q_eci2body_real-Q_eci2body_sensors).^2,1);
    R = eye(2).*[0.1372, 0.0299];
    
    % EKF object
    filter = extendedKalmanFilter(@qSTF,@qMF,Q_eci2body_0,"HasAdditiveProcessNoise",false);
    filter.ProcessNoise = Q;
    filter.StateCovariance = P;
    filter.MeasurementNoise = R;

    %%%%%% PERFORM ANALYSIS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    for i = 1:length(t)
        filter_inputs = [dt,Rsat_GPS(i,:),Vsat_GPS(i,:),LOS_hat_eci_sensors(i,:),W_sat_eci_sensors(i,:),W_sat_body_sensors(i,:),K_optics];
        correct(filter,z(i,:),filter_inputs);        
        predict(filter,filter_inputs);
        Q_eci2body(i,:) = filter.State;
    end

    rho = sphere_intersection(R_E,Rsat_GPS,LOS_hat_eci_sensors);
    
    Rtar_eci = Rsat_GPS + rho.*LOS_hat_eci_sensors;
    Vtar_eci = target_velocity(rho,LOS_hat_eci_sensors,Rsat_GPS,Vsat_GPS,W_sat_eci_sensors);
    Vim_eci = Vtar_eci - cross(We.*ones(size(t)),Rtar_eci);
    Vim_body = quatrotate(Q_eci2body,Vim_eci);
    Vim_body = Vim_body(:,1:2);
    uv = K_optics.*Vim_body./rho;

    %%%%%% PLOTTING %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Compare state quaternion estimates
    figure(fig1)

    % Subplot 1: Scalar component
    subplot(4,1,1)
    plot(t,Q_eci2body_real(:,1),"Color",colors(k,:))
    hold on
    plot(t,Q_eci2body_sensors(:,1),"x","LineWidth",1.5,"Color",colors(k,:))
    plot(t,Q_eci2body(:,1),"o","LineWidth",1.5,"Color",colors(k,:))

    % Subplot 2: First component
    subplot(4,1,2)
    plot(t,Q_eci2body_real(:,2),"Color",colors(k,:))
    hold on
    plot(t,Q_eci2body_sensors(:,2),"x","LineWidth",1.5,"Color",colors(k,:))
    plot(t,Q_eci2body(:,2),"o","LineWidth",1.5,"Color",colors(k,:))

    % Subplot 3: Second component
    subplot(4,1,3)
    plot(t,Q_eci2body_real(:,3),"Color",colors(k,:))
    hold on
    plot(t,Q_eci2body_sensors(:,3),"x","LineWidth",1.5,"Color",colors(k,:))
    plot(t,Q_eci2body(:,3),"o","LineWidth",1.5,"Color",colors(k,:))

    % Subplot 4: Third component
    subplot(4,1,4)
    plot(t,Q_eci2body_real(:,4),"Color",colors(k,:))
    hold on
    plot(t,Q_eci2body_sensors(:,4),"x","LineWidth",1.5,"Color",colors(k,:))
    plot(t,Q_eci2body(:,4),"o","LineWidth",1.5,"Color",colors(k,:))
    
    % Compare U estimates
    figure(fig2)
    plot(t,u_real,"Color",colors(k,:))
    hold on
    plot(t,u_of,"x","LineWidth",1.5,"Color",colors(k,:))
    plot(t,uv(:,1),"--","LineWidth",1.5,"Color",colors(k,:))
    
    % Compare V estimates
    figure(fig3)
    plot(t,v_real,"Color",colors(k,:))
    hold on
    plot(t,v_of,"x","LineWidth",1.5,"Color",colors(k,:))
    plot(t,uv(:,2),"--","LineWidth",1.5,"Color",colors(k,:))
    
    % Compare U errors
    figure(fig4)
    plot(t,u_real-u_of,"-","Color",colors(k,:))
    hold on
    plot(t,u_real-u_of,"o","Color",colors(k,:),"LineWidth",1.5)
    plot(t,u_real-uv(:,1),":","Color",colors(k,:))
    plot(t,u_real-uv(:,1),"x","Color",colors(k,:),"LineWidth",1.5)
    plot(t,u_real-u_sensors,"--","Color",colors(k,:))
    plot(t,u_real-u_sensors,"square","Color",colors(k,:),"LineWidth",1.5)
    
    % Compare V errors
    figure(fig5)
    plot(t,v_real-v_of,"-","Color",colors(k,:))
    hold on
    plot(t,v_real-v_of,"o","Color",colors(k,:),"LineWidth",1.5)
    plot(t,v_real-uv(:,2),":","Color",colors(k,:))
    plot(t,v_real-uv(:,2),"x","Color",colors(k,:),"LineWidth",1.5)
    plot(t,v_real-v_sensors,"--","Color",colors(k,:))
    plot(t,v_real-v_sensors,"square","Color",colors(k,:),"LineWidth",1.5)
    
end

% Finalize figure 1
figure(fig1)

subplot(4,1,1)
p1 = plot(nan, nan,'Color','k','LineStyle','-');
p2 = plot(nan, nan,'x','Color','k','LineWidth',1.5);
p3 = plot(nan, nan,'o','Color','k','LineWidth',1.5);
legend([p1,p2,p3],{"Real","Sensors","Estimate"});
xlabel("Time [s]")
ylabel("Q_{0}")
title("Scalar component")
grid on

subplot(4,1,2)
xlabel("Time [s]")
ylabel("Q_{1}")
title("First component")
grid on

subplot(4,1,3)
xlabel("Time [s]")
ylabel("Q_{2}")
title("Second component")
grid on

subplot(4,1,4)
xlabel("Time [s]")
ylabel("Q_{3}")
title("Third component")
grid on

sgtitle("Real vs Sensors vs Estimate - Quaternion Components")
savefig(script_name+"_QuaternionComponentsEstimates")

% Finalize figure 2
figure(fig2)
p1 = plot(nan, nan,'Color','k','LineStyle','-');
p2 = plot(nan, nan,'x','Color','k','LineWidth',1.5);
p3 = plot(nan, nan,'--','Color','k','LineWidth',1.5);
legend([p1,p2,p3],{"Real","Optical Flow","Estimate"});
xlabel("Time [s]")
ylabel("u [px]")
title("U Estimate vs Real")
grid on
savefig(script_name+"_EstimatedRealU")

% Finalize figure 3
figure(fig3)
p1 = plot(nan, nan,'Color','k','LineStyle','-');
p2 = plot(nan, nan,'x','Color','k','LineWidth',1.5);
p3 = plot(nan, nan,'--','Color','k','LineWidth',1.5);
legend([p1,p2,p3],{"Real","Optical Flow","Estimate"});
xlabel("Time [s]")
ylabel("v [px]")
title("V Estimate vs Real")
grid on
savefig(script_name+"_EstimatedRealV")

% Finalize figure 4
figure(fig4)
p1 = plot(nan, nan,'-o','Color','k','LineWidth',1.5);
p2 = plot(nan, nan,':x','Color','k','LineWidth',1.5);
p3 = plot(nan, nan,'--square','Color','k','LineWidth',1.5);
legend([p1,p2,p3],{"Error OF","Error filter","Error sensors"});
xlabel("Time [s]")
ylabel("U_{real} - U_{est} [px]")
title("U error")
grid on
savefig(script_name+"_ErrorU")

% Finalize figure 5
figure(fig5)
p1 = plot(nan, nan,'-o','Color','k','LineWidth',1.5);
p2 = plot(nan, nan,':x','Color','k','LineWidth',1.5);
p3 = plot(nan, nan,'--square','Color','k','LineWidth',1.5);
legend([p1,p2,p3],{"Error OF","Error filter","Error sensors"});
xlabel("Time [s]")
ylabel("V_{real} - V_{est} [px]")
title("V error")
grid on
savefig(script_name+"_ErrorV")

end