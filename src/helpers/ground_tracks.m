function [Rgt,LLA_gt] = ground_tracks(R, Re, options)
% GROUND_TRACK Computes the ground track vector of the
% satellite or the LOS.
%
% Input Arguments
%   R - Satellite position vector OR target position vector depending on
%       options.type.
%     n-by-3 array
%   Re - Earth radius.
%     scalar
%   options.Rlos - Line-of-Sight (LOS) vector, only used when type is
%       "los".
%     n-by-3 array
%   options.type - Defines the type of ground track to compute.
%       "satellite" (default): Computes ground track of the satellite.
%       "los"                : Computes ground track of the LOS.
%     string
%   options.frame - Reference frame of the input vectors.
%       "eci"  (default): Earth-Centered Inertial frame.
%       "ecef"          : Earth-Centered Earth-Fixed frame.
%     string
%   options.model - Earth model used for conversion to latitude, longitude,
%       and altitude.
%       "sphere" (default): Spherical Earth model with radius Re.
%       "WGS84"           : WGS84 reference ellipsoid model.
%     string
%
% Output Arguments
%   Rgt - Ground track position vectors in ECI or ECEF depending on type.
%     n-by-3
%   LLA_gt - Geodetic coordinates:
%       [latitude (deg), longitude (deg), altitude (m)]
%     n-by-3

arguments (Input)
    R (:,3) double
    Re (1,1) double
    options.Rlos (:,3) double
    options.type (1,1) string = "satellite"
    options.frame (1,1) string = "eci"
    options.model (1,1) string = "sphere"
end

arguments (Output)
    Rgt (:,3) double
    LLA_gt (:,3) double
end

% Compute corresponding ground track
if options.type == "satellite"
    % Find ground track of satellite
    Rgt = R .* (Re ./ vecnorm(R, 2, 2));
elseif options.type == "los"
    % Find ground track of the LOS
    indexes = any(options.Rlos ~= 0, 2);
    Rgt = R;
    Rgt(~indexes,:) = 0;
else
    error("The type of groundtrack %s is unknown", type)
end

if options.frame == "ecef"
    % Find the timetsamps in UTC
    t_utc = startTime + seconds(t);

    % Convert to ECEF
    Rgt = eci2ecef_vect(t_utc,Rgt);
end

% Convert to find Latitude, Longitude and Altitude
if options.model == "WGS84"
    LLA_gt = ecef2lla(Rgt,options.model);
else
    LLA_gt = ecef2lla(Rgt,0,Re);
end
    
end