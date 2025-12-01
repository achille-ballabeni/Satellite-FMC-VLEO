function [Xecef] = eci2ecef_vect(utc,Xeci)
% ECI2ECEF_VECT Converts a 2D array from ECI to ECEF.
% This function converts Earth-Centered Inertial (ECI) coordinates to Earth-Centered Earth-Fixed (ECEF) coordinates.
%
% Input Arguments
%   utc - Coordinated Universal Time.
%     m-by-1 datetime array
%   Xeci - Position in ECI frame.
%     m-by-3 matrix
%
% Output Arguments
%   Xecef - Position in ECEF frame.
%     m-by-3 matrix

arguments (Input)
    utc (:,1) datetime
    Xeci (:,3) double
end

arguments (Output)
    Xecef (:,3) double
end
Xecef = zeros(size(Xeci));
for i = 1:numel(utc)
    Xecef(i,:) = eci2ecef(utc(i,1),Xeci(i,:));
end
end