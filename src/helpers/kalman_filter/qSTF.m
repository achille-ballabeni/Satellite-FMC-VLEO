function [Qeci2bodyk] = qSTF(Qeci2body,noise,parameters)
% RHOSTF State transition function of the Line-of-Sight modulus.
%
% Input Arguments
%  Qeci2body - Attitude quaternion at timestep k, in this case it the state
%      of the KF.
%    scalar
%  parameters - Parameters for the state transition function: [dt,Rsat_eci,Vsat_eci,LOS_hat,W_sat_eci,Qeci2body,K_optics]
%    17-by-1 array
%
% Output Arguments
%  Qeci2bodyk - Attitude quaternion at timestep k+1.
%    scalar

arguments (Input)
    Qeci2body (4,1) double
    noise (4,1) double
    parameters (17,1) double
end

arguments (Output)
    Qeci2bodyk (4,1) double
end

% Normalize state
Qeci2body = Qeci2body./norm(Qeci2body);

% Extract parameters
dt = parameters(1);
Wsat_body = parameters(14:16);

% Quaternion kinematics
OMEGA = W_matrix(Wsat_body);
Qeci2bodyk = Qeci2body + 1/2*OMEGA*dt*Qeci2body;

% Force unit norm
Qeci2bodyk = Qeci2bodyk ./ norm(Qeci2bodyk);

end

function OMEGA = W_matrix(W)

OMEGA = [   0      -W(1)  -W(2)  -W(3);
         W(1)      0       W(3)  -W(2);
         W(2)  -W(3)      0       W(1);
         W(3)   W(2)  -W(1)      0    ];

end