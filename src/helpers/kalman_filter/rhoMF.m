function [z] = rhoMF(rho,parameters)
% RHOMF Measurements function of the Line-of-Sight modulus.
% 
% Input Arguments
%  rho - LOS modulus at timestep k, in this case it the state of the KF.
%    scalar
%  parameters - Parameters for the measurements function: [dt,Rsat,Vsat,LOS_hat,W_sat,Qeci2body]
%    18-by-1 array
%
% Output Arguments
%  z - Pixel shifts [u,v] at timestep k.
%    2-by-1 array

arguments (Input)
    rho (1,1) double
    parameters (18,1) double
end

arguments (Output)
    z (2,1) double
end

Omega_E = 7.2921159e-5;

% Extract parameters
Rsat = parameters(2:4);
Vsat = parameters(5:7);
LOS_hat = parameters(8:10);
Wsat = parameters(11:13);
Qeci2body = parameters(14:17);
K_optics = parameters(18);

% Target position
Rtar = Rsat + LOS_hat.*rho;

% Measurement model
Rtar_dot = target_velocity(rho,LOS_hat',Rsat',Vsat',Wsat');
Vim_eci = Rtar_dot' - cross([0;0;Omega_E],Rtar);
Vim_cam = qrot(Qeci2body,Vim_eci);
z = K_optics./rho.*Vim_cam;

% Remove third component
z = z(1:2);

end

% quatorotate is not supported for code generation, a custom function is
% required.
% Reference: https://uk.mathworks.com/help/aerotbx/ug/quatrotate.html#mw_2ebe648e-7e8e-4ce6-9bd5-a693da88b99b
function v = qrot(q,vector)

    q0 = q(1);
    q1 = q(2);
    q2 = q(3);
    q3 = q(4);
    
    % Compute the direction cosine matrix (DCM) from quaternion
    DCM = [1-2*q2^2-2*q3^2, 2*(q1*q2+q0*q3), 2*(q1*q3-q0*q2);
           2*(q1*q2-q0*q3), (1-2*q1^2-2*q3^2), 2*(q2*q3+q0*q1);
           2*(q1*q3+q0*q2), 2*(q2*q3-q0*q1), (1-2*q1^2-2*q2^2)];

    % Rotate the vector
    v = DCM*vector;
end