% Get simulation output
n = size(out.parameters,1);
rho_start = 250000;
rho_0 = rho_start;
rho_hat = zeros(1,n);
P = 1000;
t = out.tout;

for k=1:n
    parameters = out.parameters(k,:);
    uv_of = out.uv_of(k,:);
    
    % Store previous estimate
    rho_prev = rho_0;
    
    % Build param vector
    new_params = parameters;
    new_params(19) = rho_prev;
    new_params(20:21) = uv_of;
    new_params(22) = P;
    
    options = optimoptions('lsqnonlin',"Display","iter","ConstraintTolerance",1e-1);
    Jcost = @(rho) J_cost(rho,new_params);
    nnlcon = @(rho) nonlcon(rho,new_params);
    
    % LSQ nonlin
    [rho0_new, ~, re, ~, ~, ~, Jac] = lsqnonlin(Jcost, rho_0, [], [], [], [], [], [], nnlcon, options);
    rho_hat(k) = rho0_new;
    rho_0 = rho0_new;
    P = Jac'*Jac;
    [~, c] = nnlcon(rho_0);
    constraint(k) = c;
    resiudal(:,k) = re;
end

figure(1)
plot(t,rho_hat)
hold on
plot(t,out.rho_real)
plot(t,out.rho_sensors)
plot(0,rho_start,"o","LineWidth",2)
grid on
legend("rho hat","rho real","rho sensors")

function res = J_cost(rho,parameters)

    % Extract parameters    
    dt = parameters(1);
    Rsat = parameters(2:4);
    Vsat = parameters(5:7);
    LOS_hat = parameters(8:10);
    Wsat = parameters(11:13);
    rho_prev = parameters(19);
    uv_of = parameters(20:21);

    % Compute velocity for backward propagation
    [~, rho_dot] = target_velocity(rho,LOS_hat,Rsat,Vsat,Wsat);

    % Calculate measures from estimate
    uv_from_rho = rhoMF(rho,parameters(1:18));

    % Residuals
    res_state = rho_prev - rho_dot*dt;
    res_meas = uv_of - uv_from_rho;

    % Matrici aggiungere
    R = eye(2)*0.01;
    P = parameters(22);

    lsq_state = sqrt(inv(P))*res_state;
    lsq_meas = sqrt(inv(R))*res_meas;
    lsq_meas_u = lsq_meas(1);
    lsq_meas_v = lsq_meas(2);

    res = [lsq_state;lsq_meas_u;lsq_meas_v];

end

function [c,ceq] = nonlcon(rho,parameters)

    Rsat = parameters(2:4);
    LOS_hat = parameters(8:10);
    LOS = rho*LOS_hat;

    c = [];
    ceq = norm(Rsat+LOS) - 6378e3;
end