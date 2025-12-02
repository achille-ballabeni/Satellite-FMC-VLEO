function GSD = gsd(PXsize,focal_length,altitude)
% GSD Computes the ground sample distance for a given pixel size, focal
% length, and imaging altitude.
%
% Input Arguments
%   PXsize - Physical size of one pixel on the sensor.
%     scalar
%   focal_length - Camera focal length.
%     scalar
%   altitude - Imaging altitude above the target surface.
%     scalar
%
% Output Arguments
%   GSD - Ground sample distance.
%     scalar

arguments (Input)
    PXsize (1,1) double
    focal_length (1,1) double
    altitude (1,1) double
end

arguments (Output)
    GSD (1,1) double
end

GSD = PXsize*altitude/focal_length;

end