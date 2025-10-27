function ANA_04_EKF_rho(options)
% ANA_04_EKF_rho This script implements the EKF using rho as state and
% (u,v) as measurements. It can also run a tuning of the parameters and 
arguments (Input)
    options.simulations (1,:) = 1;
    options.data struct = [];
end
script_name = "ANA_04";

%%%%%% LOAD SIMULATION RESULTS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if isempty(options.data)
    data = load_data().results;
else
    fprintf("Simulation data is already loaded.\n")
    data = options.data;
end

%%%%%% PARAMETER INITIALIZATION and PRE-PROCESSING %%%%%%%%%%%%%%%%%%%%%%%%
% Create figures outside the loop
fig1 = figure("Name","Estimated vs Real State - RHO");

fig2 = figure("Name","U Estimated vs Real");

fig3 = figure("Name","V Estimated vs Real");

fig4 = figure("Name","U Estimated vs Real | Error");

fig5 = figure("Name","V Estimated vs Real | Error");

colors = lines(length(options.simulations));

for k = options.simulations
    % Time
    t = data.t;

    % Earth rotation
    We = [0,0,data.simIn.Omega_E];

    % Filter state
    rho_real = data.simOut.rho_real.Data;
    rho_sensors = data.simOut.rho_sensors.Data;
    rho_0 = rho_sensors(1);
    rho = zeros(size(t));

    % Filter measurements
    u_real = data.simOut.u_real.Data;
    v_real = data.simOut.v_real.Data;
    u_of = data.simOut.u_OF.Data;
    v_of = data.simOut.v_OF.Data;
    u_sensors = data.simOut.u_sensors.Data;
    v_sensors = data.simOut.v_sensors.Data;
    z = [u_of,v_of];

    % Filter inputs
    dt = data.simIn.timeStep;
    Rsat_GPS = data.simOut.X_eci_GPS.Data;
    Vsat_GPS = data.simOut.V_eci_GPS.Data;
    LOS_hat_eci_sensors = data.simOut.LOS_hat_eci_sensors.Data;
    W_sat_eci_sensors = data.simOut.Wsat_eci_sensors.Data;
    Q_eci2body_sensors = data.simOut.Q_eci2body_sensors.Data;
    K_optics = data.simIn.K_optics;

    % Filter tuning
    Q = 1;
    P = 20;
    R = eye(2)*0.1;
    
    % EKF object
    filter = extendedKalmanFilter(@rhoSTF,@rhoMF,rho_0);
    filter.ProcessNoise = Q;
    filter.StateCovariance = P;
    filter.MeasurementNoise = R;

    %%%%%% PERFORM ANALYSIS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    for i = 1:length(t)
        filter_inputs = [dt,Rsat_GPS(i,:),Vsat_GPS(i,:),LOS_hat_eci_sensors(i,:),W_sat_eci_sensors(i,:),Q_eci2body_sensors(i,:),K_optics];
        correct(filter,z(i,:),filter_inputs);
        predict(filter,filter_inputs);
        rho(i) = filter.State;
    end
    
    Rtar_eci = Rsat_GPS + rho.*LOS_hat_eci_sensors;
    Vtar_eci = target_velocity(rho,LOS_hat_eci_sensors,Rsat_GPS,Vsat_GPS,W_sat_eci_sensors);
    Vim_eci = Vtar_eci - cross(We.*ones(size(t)),Rtar_eci);
    Vim_body = quatrotate(Q_eci2body_sensors,Vim_eci);
    Vim_body = Vim_body(:,1:2);
    uv = K_optics.*Vim_body./rho;

    %%%%%% PLOTTING %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    figure(fig1)
    plot(t,rho_real,"Color",colors(k,:))
    hold on
    plot(t,rho,"x","LineWidth",1.5,"Color",colors(k,:))

    figure(fig2)
    plot(t,u_real,"Color",colors(k,:))
    hold on
    plot(t,u_of,"x","LineWidth",1.5,"Color",colors(k,:))
    plot(t,uv(:,1),"--","LineWidth",1.5,"Color",colors(k,:))

    figure(fig3)
    plot(t,v_real,"Color",colors(k,:))
    hold on
    plot(t,v_of,"x","LineWidth",1.5,"Color",colors(k,:))
    plot(t,uv(:,2),"--","LineWidth",1.5,"Color",colors(k,:))

    figure(fig4)
    plot(t,u_real-u_of,"-","Color",colors(k,:))
    hold on
    plot(t,u_real-u_of,"o","Color",colors(k,:),"LineWidth",1.5)
    plot(t,u_real-uv(:,1),":","Color",colors(k,:))
    plot(t,u_real-uv(:,1),"x","Color",colors(k,:),"LineWidth",1.5)
    plot(t,u_real-u_sensors,"--","Color",colors(k,:))
    plot(t,u_real-u_sensors,"square","Color",colors(k,:),"LineWidth",1.5)

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
p1 = plot(nan, nan,'Color','k','LineStyle','-');
p2 = plot(nan, nan,'x','Color','k','LineWidth',1.5);
legend([p1,p2],{"Real","Estimate"});
xlabel("Time [s]")
ylabel("Rho [m]")
title("RHO Estimate vs Real")
grid on
savefig(script_name+"_EstimatedRealRHO")

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