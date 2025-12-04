function [noisyImageDN, imageDN] = shot_noise(image, exposureTime, photonFlux, QE, ...
                              fullWell, gain)
arguments (Input)
    image (:,:,:) {mustBeA(image, ["uint8", "uint16"])}
    exposureTime (1,1) double {mustBePositive}
    photonFlux (1,1) double {mustBePositive}
    QE (1,1) double {mustBeGreaterThanOrEqual(QE,0), mustBeLessThanOrEqual(QE,1)}
    fullWell (1,1) double {mustBePositive}
    gain (1,1) double {mustBePositive}
end

arguments (Output)
    noisyImageDN (:,:,:) double
    imageDN (:,:,:) double
end

% --- STEP 1: Normalize image between 0 and 1 ---
imageNormalized = double(image)/double(intmax(class(image)));

% --- STEP 2: Calculate true photon flux ---
photonFlux = imageNormalized .* photonFlux;

% --- STEP 3: Calculate photons collected by each pixel ---
expectedPhotons = photonFlux .* exposureTime;

% --- STEP 4: Expected electrons ---
expectedElectrons = QE .* expectedPhotons;

% --- STEP 5: Poisson electron generation (valid for N>10) ---
noisyElectrons = expectedElectrons + sqrt(expectedElectrons) .* randn(size(expectedElectrons));
%noisyElectrons = poissrnd(expectedElectrons);

% --- STEP 6: Clip electrons to physical limits ---
noisyElectrons(noisyElectrons>fullWell) = fullWell;

% --- STEP 7: Convert electrons to DN ---
imageDN = expectedElectrons .* gain;
noisyImageDN = noisyElectrons .* gain;

end
