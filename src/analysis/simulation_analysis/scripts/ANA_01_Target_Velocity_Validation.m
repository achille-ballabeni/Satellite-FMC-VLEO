function ANA_01_Target_Velocity_Validation(options)

% ANA_01_TARGET_VELOCITY_VALIDATION This script compares the Target
% Velocity obtained from the analytic formulation with the one computed
% numerically.

arguments (Input)
    options.simulations (1,:) = 1;
    options.data struct = [];
end

script_name = "ANA_01";

%%%%%% LOAD SIMULATION RESULTS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if isempty(options.data)
    data = load_data().results;
else
    fprintf("Simulation data is already loaded.\n")
    data = options.data;
end

%%%%%% PARAMETER INITIALIZATION and PRE-PROCESSING %%%%%%%%%%%%%%%%%%%%%%%%
% Create figures outside the loop
fig1 = figure("Name","Velocity components vs Time",'Units','centimeters','Position',[0 0 18 18]);

fig2 = figure("Name","Analytic vs Numerical Derivatives - Relative Errors",'Units','centimeters','Position',[0 0 18 18]);

colors = lines(options.simulations);

for k = options.simulations
    Re = data(k).Re;
    t = data(k).t;
    Rsat = data(k).simOut.X_eci.Data;
    Vsat = data(k).simOut.V_eci.Data;
    Qeci2body = data(k).simOut.Q_eci2body.Data;
    Wsat_body = data(k).simOut.Wsat_body.Data;
    Qbody2eci = quatinv(Qeci2body);
    LOS_hat = quatrotate(Qbody2eci,[0,0,1]);
    earth_model = "sphere";

    %%%%%% PERFORM ANALYSIS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Find direction of line of sight, considered as exiting from
    % the z axis of the satellite.
    if earth_model == "sphere"
        % Intersection between line of sight and earth surface
        rho = sphere_intersection(Re,Rsat,LOS_hat);
    elseif earth_model == "WGS84"
        % Intersection between line of sight and the WGS84
        % ellipsoid https://en.wikipedia.org/wiki/World_Geodetic_System#WGS84
        a = 6378137.0;
        b = a;
        c = 6356752.314245;
        rho = ellipsoid_intersection([a,b,c],Rsat,LOS_hat);
    else
        error("The type %s is unknown for the LOS calculation", earth_model)
    end

    % Find the LOS vector and target position vector
    Rlos = rho.*LOS_hat;
    Rtar = Rsat + Rlos;

    % Angular velocity in inertial frame
    Wsat_eci = quatrotate(Qbody2eci,Wsat_body);

    % Target velocity
    Vtar = target_velocity(rho,LOS_hat,Rsat,Vsat,Wsat_eci);

    % Find numerical derivative
    [Vtar_numerical,t_der,idx] = derivative(Rtar,t,method="edgepoint");

    % Calculate the relative error
    Vtar_RE = abs(Vtar(idx,:) - Vtar_numerical)./vecnorm(Vtar(idx,:),2,2);

    %%%%%% PLOTTING %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Compare velocities
    figure(fig1)

    % Subplot 1: u component
    subplot(3,1,1)
    plot(t,Vtar(:,1),"Color",colors(k,:))
    hold on
    plot(t_der,Vtar_numerical(:,1),"x","LineWidth",1.5,"Color",colors(k,:))

    % Subplot 2: v component
    subplot(3,1,2)
    plot(t,Vtar(:,2),"Color",colors(k,:))
    hold on
    plot(t_der,Vtar_numerical(:,2),"x","LineWidth",1.5,"Color",colors(k,:))

    % Subplot 3: w component
    subplot(3,1,3)
    plot(t,Vtar(:,3),"Color",colors(k,:))
    hold on
    plot(t_der,Vtar_numerical(:,3),"x","LineWidth",1.5,"Color",colors(k,:))

    % Velocity relative errors
    figure(fig2)

    % Subplot 1: Difference in u component
    subplot(3,1,1)
    plot(t_der,Vtar_RE(:,1),"x","LineWidth",1)
    hold on

    % Subplot 2: Difference in v component
    subplot(3,1,2)
    plot(t_der,Vtar_RE(:,2),"x","LineWidth",1)
    hold on

    % Subplot 3: Difference in w component
    subplot(3,1,3)
    plot(t_der,Vtar_RE(:,3),"x","LineWidth",1)
    hold on
end

% Finalize figure 1
figure(fig1)

subplot(3,1,1)
p1 = plot(nan, nan,'Color','k','LineStyle','-');
p2 = plot(nan, nan,'x','Color','k','LineWidth',1.5);
legend([p1,p2],{"Analytic","Numerical"},'FontSize', 11, 'FontWeight', 'bold');
xlabel("Time [s]",'FontSize', 13, 'FontWeight', 'bold')
ylabel("u [m/s]",'FontSize', 13, 'FontWeight', 'bold')
grid on

subplot(3,1,2)
xlabel("Time [s]",'FontSize', 13, 'FontWeight', 'bold')
ylabel("v [m/s]",'FontSize', 13, 'FontWeight', 'bold')
grid on

subplot(3,1,3)
xlabel("Time [s]",'FontSize', 13, 'FontWeight', 'bold')
ylabel("w [m/s]",'FontSize', 13, 'FontWeight', 'bold')
grid on

sgtitle("Analytic vs Numerical V_{im} | Velocity Components",'FontSize', 15, 'FontWeight', 'bold')
savefig(script_name+"_VelocityComponents")

% Finalize figure 2
figure(fig2)

subplot(3,1,1)
xlabel('Time [s]','FontSize', 13)
ylabel('$\displaystyle\frac{|u_{AN} - u_{NUM}|}{\|\overline{V}_{im,NUM}\|}$','Interpreter','latex','FontSize',15)
grid on

subplot(3,1,2)
xlabel('Time [s]','FontSize', 13)
ylabel('$\displaystyle\frac{|v_{AN} - v_{NUM}|}{\|\overline{V}_{im,NUM}\|}$','Interpreter','latex','FontSize',15)
grid on

subplot(3,1,3)
xlabel('Time [s]','FontSize', 13)
ylabel('$\displaystyle\frac{|w_{AN} - w_{NUM}|}{\|\overline{V}_{im,NUM}\|}$','Interpreter','latex','FontSize',15)
grid on

sgtitle("Analytic vs Numerical V_{im} | Relative Error",'FontSize', 15, 'FontWeight', 'bold')
savefig(script_name+"_VelocityRelativeErrors")

end