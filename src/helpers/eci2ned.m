function [Reci2ned] = eci2ned(X)
% ECI2NED Computes rotation matrix from ECI to NED frame.
% Input Arguments
%   X - Position where to compute the NED frame.
%     3-by-1 array
%
% Output Arguments
%   R - Rotation matrix from ECI to NED.
%     3-by-3 matrix

arguments (Input)
    X (3,1) double
end

arguments (Output)
    Reci2ned (3,3) double
end

% Down unit vector
D = -X / norm(X);

% East unit vector
E = cross(D, [0;0;1]);
E = E / norm(E);

% North unit vector
N = cross(E, D);

% Rotation matrix
Rned2eci = [N, E, D];
Reci2ned = Rned2eci';

end