function [Vtar, rho_dot] = target_velocity(rho,LOS_hat,Rsat,Vsat,Wsat)
% TARGET_VELOCITY Computes the velocity of the line of sight intersection
% wrt to the ECI frame.
%
% Input Arguments
%   rho - Line of Sight modulus.
%     n-by-1 array
%   LOS_hat - Line of Sight unit vector.
%     n-by-3 array
%   Rsat - Position of the satellite.
%     n-by-3 array
%   Vsat - Velocity of the satellite.
%     n-by-3 array
%   Wsat - Angular velocity of the satellite.
%     n-by-3 array
%
% Output Arguments
%   Vtar - Target velocity vector in the ECI frame.
%     n-by-3 array
%   rho_dot - Rate of change of the line of sight modulus.
%     n-by-1 array

arguments (Input)
    rho (:,1) double
    LOS_hat (:,3) double
    Rsat (:,3) double
    Vsat (:,3) double
    Wsat (:,3) double
end

arguments (Output)
    Vtar (:,3) double
    rho_dot (:,1) double
end

rho_dot = - rho.*(dot(LOS_hat,Vsat,2) + dot(Rsat,cross(Wsat,LOS_hat),2))./(dot(Rsat,LOS_hat,2) + rho);


Vtar = Vsat + rho_dot.*LOS_hat + rho.*cross(Wsat,LOS_hat);

end