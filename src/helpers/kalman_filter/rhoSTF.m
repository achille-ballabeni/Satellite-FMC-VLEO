function [rhok] = rhoSTF(rho,parameters)
% RHOSTF State transition function of the Line-of-Sight modulus.
% 
% Input Arguments
%  rho - LOS modulus at timestep k, in this case it the state of the KF.
%    scalar
%  parameters - Parameters for the state transition function: [dt,Rsat,Vsat,LOS_hat,W_sat_eci,Qeci2body,K_optics,Omega_E]
%    19-by-1 array
%
% Output Arguments
%  rhok - LOS modulus at timestep k+1.
%    scalar

arguments (Input)
    rho (1,1) double
    parameters (19,1) double
end

arguments (Output)
    rhok (1,1) double
end

% Extract parameters    
dt = parameters(1);
Rsat = parameters(2:4);
Vsat = parameters(5:7);
LOS_hat = parameters(8:10);
Wsat = parameters(11:13);

[~, rho_dot] = target_velocity(rho,LOS_hat',Rsat',Vsat',Wsat');

rhok = rho + dt*rho_dot;
end