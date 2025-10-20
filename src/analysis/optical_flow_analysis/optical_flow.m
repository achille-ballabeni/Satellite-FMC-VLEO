function [u_est, v_est] = optical_flow(frame1, frame2, precFactor)

% Motion estimation between two frames through cross correlation. This code
% gives the same precision as the FFT upsampled cross correlation in a
% small fraction of the computation time and with reduced memory 
% requirements. It obtains an initial estimate of the crosscorrelation peak
% by an FFT and then refines the shift estimation by upsampling the DFT
% only in a small neighborhood of that estimate by means of a 
% matrix-multiply DFT. With this procedure all the image points are used to
% compute the upsampled crosscorrelation.

%% Preprocessing
f = im2single(im2gray(frame1));
g = im2single(im2gray(frame2));

% winRows    = 240;
% winCols    = 384;
% windowSize = [winRows, winCols];
% C          = SelectRegionEdges(f, windowSize);
% 
% f = im2single(f(C(1):C(1)+winRows-1, C(2):C(2)+winCols-1));
% g = im2single(g(C(1):C(1)+winRows-1, C(2):C(2)+winCols-1));

H1 = hann(size((f), 1));
H2 = hann(size((f), 2));

hannWindow = H1*H2';

f = f.*hannWindow;
g = g.*hannWindow;

img1ft = fft2(f);
img2ft = fft2(g);

%% Start with precFactor == 1 to get an integer shift between images
[nr, nc] = size(f);

Nr = ifftshift(-fix(nr/2):ceil(nr/2)-1);
Nc = ifftshift(-fix(nc/2):ceil(nc/2)-1);

% Calculate the cross correlation function between the two images
crossCorr    = ifft2((img2ft.*conj(img1ft))./abs(img2ft.*conj(img1ft)));
abscrossCorr = abs(crossCorr);

[~, maxIndex] = max(abscrossCorr(:)); % linear index of max
[row_shift, col_shift] = ind2sub(size(abscrossCorr), maxIndex);

% Change shifts so that they represent relative shifts and not indices
row_shift = Nr(row_shift);
col_shift = Nc(col_shift);

%% If precision factor is higher than 1, proceed with subpixel refinement
if precFactor >= 2
    %%% DFT computation %%%
    % Center of output array at dftshift+1
    dftshift = fix(ceil(precFactor*1.5)/2);

    % Matrix multiply DFT around the current shift estimate
    crossCorr = conj(dftups((img1ft.*conj(img2ft)), ...
                            ceil(precFactor*1.5), ...
                            ceil(precFactor*1.5), ...
                            precFactor, ...
                            dftshift - row_shift*precFactor, ...
                            dftshift - col_shift*precFactor));

    % Locate maximum and map back to original pixel grid 
    abscrossCorr = abs(crossCorr);

    [~, maxIndex] = max(abscrossCorr(:));       % linear index of max
    [rloc, cloc] = ind2sub(size(abscrossCorr), maxIndex);
    rloc         = rloc - dftshift - 1;
    cloc         = cloc - dftshift - 1;
    
    % Divide rloc and cloc by precFactor to get back to original unit pixel
    % dimensions and sum to the initial integer estimate
    row_shift = row_shift + rloc/precFactor;
    col_shift = col_shift + cloc/precFactor;
end

%% Image final shifts
u_est = col_shift;
v_est = row_shift;

end

%% Fourier Transform Up-sampling
function out = dftups(in, nor, noc, precFactor, roff, coff)

% Upsampled DFT by matrix multiplies, can compute an upsampled DFT in just
% a small region.
% 
% Inputs:
% - precFactor: Precision factor.
% - nor, noc:   Number of pixels in the output upsampled DFT, in units of 
%               upsampled pixels.
% - roff, coff: Row and column offsets, allow to shift the output array to
%               a region of interest on the DFT.
%
% Receives DC in upper left corner, image center must be in (1, 1) 
%
% This code is intended to provide the same result as if the following
% operations were performed:
%
%   1. Embed the array in an array that is 'precFactor' times larger in 
%      each dimension. ifftshift to bring the center of the image to (1,1).
%   2. Take the FFT of the larger array
%   3. Extract an [nor, noc] region of the result. Starting with the 
%      [roff+1 coff+1] element.
%
% It achieves this result by computing the DFT in the output array without
% the need to zeropad. Much faster and memory efficient than the 
% zero-padded  FFT approach if [nor, noc] are much smaller than 
% [nr*usfac, nc*usfac]

[nr, nc] = size(in);

% Compute kernels and obtain DFT by matrix products
kernc = exp((-1i*2*pi/(nc*precFactor))*(ifftshift(0:nc-1).' - floor(nc/2) )*((0:noc-1) - coff));
kernr = exp((-1i*2*pi/(nr*precFactor))*((0:nor-1).' - roff)*(ifftshift(0:nr-1) - floor(nr/2)));

out = kernr*in*kernc;

end

% %% Select region of interest based on number of edges in the image
% function TopLeftAngle = SelectRegionEdges(img, windowSize)
% 
% edgeMap = edge(img, 'Canny');
% 
% windowRows = windowSize(1);
% windowCols = windowSize(2);
% 
% [imgRows, imgCols] = size(img);
% 
% % Region top left angle in the original image (initialization)
% TopLeftAngle = [1, 1];
% 
% % Edge density initialization
% maxDensity = 0;
% 
% for i = 1:windowRows/2:imgRows - windowRows
%     for j = 1:windowCols/2:imgCols - windowCols
%         % Extract the current window
%         Window = edgeMap(i:i+windowRows-1, j:j+windowCols-1);
% 
%         % Find number of edges in the selected region
%         edgeDensity = sum(Window(:));
% 
%         % Update the region center if the new value is higher than the 
%         % previous computed one
%         if edgeDensity > maxDensity
%             maxDensity = edgeDensity;
%             TopLeftAngle = [i, j];
% 
%         end
%     end
% end
% end
