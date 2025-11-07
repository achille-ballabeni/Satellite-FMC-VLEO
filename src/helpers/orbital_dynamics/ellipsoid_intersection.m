function p = ellipsoid_intersection(axes,X0,X)
% ELLIPSOID_INTERSECTION Computes the ellipsoid-line intersection.
% The function finds the parameter "p" corresponding to the intersection of
% a line X0 + pX with an ellipsoid with equation 
% x^2/a^2+y^2/b^2+z^2/c^2 = 1. A single value for the parameter p is
% returned, corresponding to the closest intersection to X0. Returns zero
% if there is no intersection or if it is negative (meaning that the
% intersection is in the wrong direction).
% The formula is taken from https://math.stackexchange.com/questions/3722553/find-intersection-between-line-and-ellipsoid
% 
% Input Arguments
%  axes - Semi-axes of the ellipsoid [x,y,z] respectively.
%    1-by-3 array
%  X0 - Starting point of the line.
%    n-by-3 array
%  X - Direction vector of the line.
%    n-by-3 array

% Output Arguments:
% p - Parameter corresponding to the closest intersection point.
%    n-by-1 array
arguments (Input)
    axes (1,3) double
    X0 (:,3) double
    X (:,3) double
end

arguments (Output)
    p (:,1) double
end

% Unpack semi-axes
a = axes(1);
b = axes(2);
c = axes(3);

% Determine polynomial coefficient p1*p^2 + p2*p + p3 = 0
p1 = (X(:,1).^2)./a^2 + (X(:,2).^2)./b^2 + (X(:,3).^2)./c^2;
p2 = (2*X0(:,1).*X(:,1))./a^2 + (2*X0(:,2).*X(:,2))./b^2 + (2*X0(:,3).*X(:,3))./c^2;
p3 = (X0(:,1).^2)./a^2 + (X0(:,2).^2)./b^2 + (X0(:,3).^2)./c^2-1;

% Iterate over the positions.
for i = size(X0,1):-1:1
    r = roots([p1(i),p2(i),p3(i)]);
    r = r(~imag(r));
    r = min(r);
    r(r<0) = 0;
    p(i,1) = r;
end

end