function [blurred_image,image] = motion_blur(image,shift)
% BLUR Add motion blur to images.
%
% Input Arguments
%   image - Original image to apply motion blur to.
%   shift - Pixel shift that causes the blur.
%     1-by-2 array

% Output Arguments:
%   image - Original unaltered image.
%   blurred_image - Blurred image

arguments (Input)
    image
    shift (1,2) double
end

arguments (Output)
    blurred_image
    image
end

blur_length = norm(shift);
blur_angle = rad2deg(atan2(shift(2),shift(1)));
H = fspecial("motion", blur_length, blur_angle);
blurred_image = imfilter(image, H, "replicate");
end