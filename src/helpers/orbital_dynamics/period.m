function [T] = period(a,mi)
% PERIOD Calculates the orbital period.
%
% Input Arguments
%   a - Semi-major axis of the orbit.
%     scalar
%   mi - Gravitational parameter of the central body.
%     scalar
%
% Output Arguments
%   T - Orbital period.
%     scalar
arguments (Input)
    a (1,1) double
    mi (1,1) double
end

arguments (Output)
    T (1,1) double
end

T = 2 * pi * sqrt(a^3 / mi);
end