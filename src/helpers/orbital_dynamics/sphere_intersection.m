function p = sphere_intersection(R,X0,X)
% SPHERE_INTERSECTION Computes the sphere-line intersection.
% The function finds the parameter "p" corresponding to the intersection of
% a line X0 + pX with a sphere of radius R centered in the origin. A single
% value for the parameter p is returned, corresponding to the closest
% intersection to X0. Returns zero if there is no intersection or if it is
% negative (meaning it is inside the sphere).
% 
% Input Arguments
%  R - Radius of the sphere.
%    scalar
%  X0 - Starting point of the line.
%    n-by-3 array
%  X - Direction vector of the line.
%    n-by-3 array

% Output Arguments:
% p - Parameter corresponding to the closest intersection point.
%    n-by-1 array
arguments (Input)
    R (1,1) double
    X0 (:,3) double
    X (:,3) double
end

arguments (Output)
    p (:,1) double
end

% Compute intersection
p = -dot(X,X0,2) - sqrt((dot(X,X0,2)).^2 - vecnorm(X0,2,2).^2 + R^2);
% Keep only real-valued intersections
p(imag(p) ~= 0) = 0;
% Discard intersections behind the starting point (negative p)
p(p<0) = 0;

end