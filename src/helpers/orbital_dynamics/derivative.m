function [y,tout,idx] = derivative(x,t,options)
% DERIVATIVE Computes the approximate numerical derivative.
% Computes the approximate numerical derivative of a vector x using the
% timestamps given in t. It can use three different methods:
% - standard: computes the difference between two adjacent points in x and
%   divides by the corresponding time difference.
%
% - midpoint: computes the derivative in the interval
%   [...,Xk-1,Xk,Xk+1,...] by using only the edge points. The derivative is
%   then assigned to the timestamp tk. As a result, the output vectors will
%   be half the size of the input.
% 
% - edgepoint: computes the derivative at point tk as the average of the
%   derivatives of the adjacent intervals.
%
% Input Arguments
%   x - The vector to differentiate.
%     n-by-m array
%   t - The timestamps.
%     n-by-1 array
%   method - "standard", "midpoint", "edgepoint". Defaults to "standard".
%     string
%
% Output Arguments
%   y - The derivative vector.
%     k-by-m array
%   tout - Output time.
%     k-by-1 array
%   idx - indexes of x corresponding to the derivative calculation.

arguments (Input)
    x (:,:) double
    t (:,1) double
    options.method (1,1) string = "standard"
end

arguments (Output)
    y (:,:) double
    tout (:,1) double
    idx (1,:) double
end

if options.method == "standard"
    y = diff(x,1,1) ./ diff(t,1,1); % Compute the derivative
    tout = t(1:end-1); % Corresponding timestamps for the derivative
    idx = 1:size(y,1);

elseif options.method == "edgepoint"
    y = diff(x,1,1) ./ diff(t,1,1); % Compute the derivative
    y = 0.5*(y(1:end-1,:)+y(2:end,:)); % Average the derivative over two intervals
    tout = t(2:end-1); % Reassign time vector
    idx = 2:size(y,1)+1;

elseif options.method == "midpoint"
    t_der = t(1:2:end); % Time vector skipping intermediate point
    x = x(1:2:end,:); % Value vector skipping intermediate point
    y = diff(x,1,1)./diff(t_der); % Compute the derivative
    tout = t(2:2:end-1); % Reassign time vector
    idx = 2:2:size(t,1)-1;
end
end